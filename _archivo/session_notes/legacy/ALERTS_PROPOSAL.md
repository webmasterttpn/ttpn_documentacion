# Propuesta: Sistema de Alertas Kumi

## Índice

1. [Modelo de Datos](#1-modelo-de-datos)
2. [Catálogo de trigger_type](#2-catálogo-de-trigger_type)
3. [Arquitectura BE](#3-arquitectura-be-rails)
4. [Flujo por canal](#4-flujo-por-canal)
5. [Campanita (in-app notifications)](#5-campanita-in-app-notifications)
6. [Rutas BE](#6-rutas-be)
7. [Páginas FE](#7-páginas-fe)
8. [Cron Schedule](#8-cron-schedule)
9. [Push Notifications](#9-push-notifications)
10. [Pendientes antes de implementar](#10-pendientes-antes-de-implementar)
11. [Resumen de migraciones](#11-resumen-de-migraciones)

---

## 1. Modelo de Datos

### Entidades core

| Tabla | Propósito |
|---|---|
| `alert_contacts` | Personas externas que reciben alertas (email) |
| `alert_rules` | Reglas configuradas: qué dispara, a quién, cuándo |
| `alert_rule_recipients` | Join: rule ↔ contact + canal (email / push) |
| `alerts` | Instancias disparadas ("aviso de incidente") |
| `alert_reads` | Registro de qué usuario ya vio cada alerta (para la campanita) |
| `alert_deliveries` | Registro de cada envío externo con status y errores |

> **`device_tokens` eliminado.** Los tokens FCM para push al admin PWA se manejan
> a través del módulo existente `settings/Acceso a API`, que ya gestiona las
> credenciales y acceso por usuario. Los tokens se asocian al `api_access` del usuario.

---

### `alert_contacts`

Personas externas que reciben alertas (email). Equivalente a la pantalla "Contactos de alerta".

```
id
business_unit_id    integer  FK
nombre              string
email               string
active              boolean  default: true
created_at / updated_at
```

---

### `alert_rules`

Cada regla es una configuración: "cuando pase X, notificar a Y por canal Z".

```
id
business_unit_id    integer  FK
titulo              string
trigger_type        enum     (ver catálogo §2)
scope_type          enum     all | vehicle | employee
scope_id            integer  nullable  ← vehicle_id o employee_id concreto
days_before         integer  nullable  ← para vencimientos: "avisar X días antes" (0 = día exacto)
active              boolean  default: true
created_by          integer  FK → users
created_at / updated_at
```

---

### `alert_rule_recipients`

Join table entre regla y contacto externo, con el canal de entrega.

```
id
alert_rule_id       integer  FK
alert_contact_id    integer  FK
channel             enum     email | push | both
```

---

### `alerts`

Instancias reales disparadas. Equivale a "Avisos de incidentes".

```
id
business_unit_id    integer  FK
alert_rule_id       integer  FK nullable  ← nil si viene de DB trigger o app móvil sin regla
trigger_type        enum     (mismo catálogo §2)
origin              enum     cron | record_callback | db_trigger | manual
source_type         string   nullable  ← "Vehicle", "Employee", "EmployeeVacation", etc.
source_id           integer  nullable
titulo              string
descripcion         text
status              enum     active | resolved | auto_resolved
triggered_at        datetime
resolved_at         datetime nullable
resolved_by         integer  nullable FK → users
created_at / updated_at
```

---

### `alert_reads`

Marca qué usuario del sistema ya vio cada alerta. Controla el punto rojo de la campanita.

```
id
alert_id            integer  FK
user_id             integer  FK
read_at             datetime
```

> Índice único en `[alert_id, user_id]` para evitar duplicados.

---

### `alert_deliveries`

Registro de cada intento de envío externo (email / push a contactos). Permite auditar fallos.

```
id
alert_id            integer  FK
alert_contact_id    integer  FK nullable
channel             enum     email | push
status              enum     pending | sent | failed
sent_at             datetime nullable
error_message       text     nullable
created_at
```

---

## 2. Catálogo de `trigger_type`

Los triggers se agrupan por **cómo se originan**, no uno por uno.

---

### Origen: Cron diario (BE automático)

Corren una vez al día y evalúan registros próximos a vencer.

| Valor                    | Descripción                                                                   | Modelo que evalúa  |
| ------------------------ | ----------------------------------------------------------------------------- | ------------------ |
| `vehicle_doc_expiration` | Vencimiento de cualquier doc vehicular (licencia, seguro, tenencia, etc.)     | `VehicleDocument`  |
| `employee_doc_expiration`| Vencimiento de cualquier doc de empleado                                      | `EmployeeDocument` |

> **Nota:** `birthday`, `license_expiration` e `insurance_expiration` como triggers independientes
> se eliminan. Todo queda bajo `vehicle_doc_expiration` y `employee_doc_expiration`,
> ya que birthday y licencias están en los documentos del empleado/vehículo.
> El `titulo` de la alerta especifica el tipo: "Vence licencia de X", "Cumpleaños de Y".

---

### Origen: Callback al guardar un registro (after_create / after_save)

Se disparan automáticamente cuando se crea o actualiza un registro específico.

| Valor                 | Modelo                                      | Cuándo                                              |
| --------------------- | ------------------------------------------- | --------------------------------------------------- |
| `vacation_pending`    | `EmployeeVacation`                          | Al crear una solicitud de vacaciones sin autorizar  |
| `service_requirement` | `ServiceRequirement` (o modelo equivalente) | Al generar un requerimiento de servicio             |
| `new_assignment`      | `VehicleAsignation`                         | Al crear una asignación nueva (notifica al chofer)  |

---

### Origen: DB Trigger (Postgres → BE)

La app móvil escribe directo a la DB sin pasar por el BE. Un trigger de Postgres
inserta en `alerts` o llama un canal de `NOTIFY` que Sidekiq escucha.

| Valor | Descripción |
|---|---|
| `incident` | Incidente capturado desde la app móvil |
| `drowsiness` | Somnolencia detectada |
| `policy_violation` | Incumplimiento de política (cinturón, velocidad, etc.) |
| `disconnected` | Dispositivo desconectado |

> **Estrategia recomendada:** El trigger de Postgres hace `NOTIFY kumi_alerts, '<alert_id>'`.
> Un proceso Sidekiq con `listen/notify` recibe el evento y ejecuta `AlertDispatchJob.perform_later(alert_id)`.
> Alternativa más simple: polling cada 30s con un job que busque `alerts` recientes sin `alert_deliveries`.

---

### Origen: Manual

| Valor | Descripción |
|---|---|
| `manual` | Creado manualmente por un administrador desde el panel |

---

## 3. Arquitectura BE (Rails)

```
app/
├── models/
│   ├── alert_contact.rb
│   ├── alert_rule.rb
│   ├── alert_rule_recipient.rb
│   ├── alert.rb
│   ├── alert_read.rb
│   └── alert_delivery.rb
│
├── controllers/api/v1/
│   ├── alert_contacts_controller.rb     # CRUD contactos externos
│   ├── alert_rules_controller.rb        # CRUD + toggle_active
│   └── alerts_controller.rb            # index, show, resolve, mark_read, summary
│
├── services/alerts/
│   ├── dispatcher_service.rb            # Orquesta: email + push según recipients
│   ├── email_sender_service.rb          # Llama al AlertMailer
│   └── push_sender_service.rb          # FCM (token desde ApiAccess del usuario)
│
├── mailers/
│   └── alert_mailer.rb
│
└── jobs/
    ├── alert_dispatch_job.rb             # Sidekiq: envía una alerta concreta
    ├── doc_expiration_check_job.rb       # Cron diario: vehiculos + empleados docs
    └── alert_db_listener_job.rb          # Escucha NOTIFY de Postgres (opcional)
```

---

## 4. Flujo por canal

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    ORIGEN DE ALERTA                          │
  └───────────────────────────┬─────────────────────────────────┘
          ┌────────────────── │ ──────────────────────┐
          ▼                   ▼                        ▼
     Cron Job         after_create/save           DB Trigger
  (doc expiration)   (vacations, services,      (mobile app escribe
                      assignments)               directo a Postgres)
          │                   │                        │
          └───────────────────┼────────────────────────┘
                              ▼
                   Alert.create! (status: active)
                              │
                   AlertDispatchJob.perform_later(alert.id)
                              │
                   ┌──────────▼──────────┐
                   │   DispatcherService  │
                   │   Lee alert_rule     │
                   │   y recipients       │
                   └──────┬──────┬───────┘
                          │      │
               ┌──────────┘      └──────────┐
               ▼                            ▼
         EmailSender                   PushSender
      (alert_contacts                (FCM → usuarios
       con canal email)               del sistema)
               │                            │
       AlertDelivery                AlertDelivery
       status: sent/failed          status: sent/failed

  ─────────────────────────────────────────────────
  Adicionalmente (siempre, sin importar recipients):
  ─────────────────────────────────────────────────
       alert_reads NO creado → campanita muestra punto rojo
       al visitar /alerts o hacer click → mark_read → punto desaparece
```

---

## 5. Campanita (in-app notifications)

La campanita en el top bar del PWA es independiente de email/push. Funciona con polling o WebSocket.

### Comportamiento

```
1. Al cargar el layout → GET /api/v1/alerts/summary
   Respuesta: { unread_count: 3, latest: [...5 alerts...] }

2. Si unread_count > 0 → mostrar punto rojo con el número

3. Al hacer click en la campanita → desplegar panel con la lista
   Cada item: título, descripción, tiempo relativo, source (vehículo/empleado)
   Si tiene source → es un link que navega a la pantalla del recurso

4. Al abrir el panel → POST /api/v1/alerts/mark_all_read
   Todas las alertas de ese usuario se marcan como leídas (insert en alert_reads)
   → punto rojo desaparece

5. Al hacer click en un item específico → navega a /alerts?id=X o a la fuente
```

### Polling vs WebSocket

| Opción | Ventaja | Desventaja |
|---|---|---|
| **Polling cada 30s** | Simple, sin infra extra | 30s de latencia, requests constantes |
| **ActionCable (WebSocket)** | Tiempo real | Requiere configuración Redis + cable |
| **Polling cada 60s + push FCM** | Balance razonable | Dos mecanismos |

> **Recomendación inicial:** Polling cada 60s al endpoint `summary`. Cuando el sistema
> esté estable se puede migrar a ActionCable si la latencia importa.

### Endpoint `summary`

```json
GET /api/v1/alerts/summary

{
  "unread_count": 3,
  "latest": [
    {
      "id": 42,
      "titulo": "Vence seguro T024",
      "descripcion": "El seguro del vehículo T024 vence en 5 días",
      "trigger_type": "vehicle_doc_expiration",
      "source_type": "Vehicle",
      "source_id": 7,
      "source_path": "/vehicles/7",
      "triggered_at": "2026-04-06T14:00:00Z",
      "read": false
    }
  ]
}
```

### Lógica `read` por usuario

```ruby
# En el modelo Alert
def read_by?(user)
  alert_reads.exists?(user_id: user.id)
end

# Scope para unread del usuario actual
scope :unread_by, ->(user) {
  where.not(id: AlertRead.where(user_id: user.id).select(:alert_id))
}
```

---

## 6. Rutas BE

```ruby
namespace :api do
  namespace :v1 do
    resources :alert_contacts                        # CRUD contactos externos

    resources :alert_rules do
      member { patch :toggle_active }               # Activar/desactivar regla
    end

    resources :alerts, only: [:index, :show, :create] do
      member     { patch :resolve }                 # Marcar como resuelto
      member     { patch :mark_read }               # Marcar como leído (campanita)
      collection { get  :summary }                  # Contadores + últimas para campanita
      collection { post :mark_all_read }            # Limpiar punto rojo
    end
  end
end
```

---

## 7. Páginas FE

### Estructura de rutas

```
/settings/alert-contacts         → CRUD de contactos externos

/alerts                          → Página principal con 2 tabs:
  ?tab=incidents                 → Avisos de incidentes (historial)
  ?tab=rules                     → Reglas configuradas

/alerts/rules/new                → Formulario nueva regla
/alerts/rules/:id/edit           → Formulario editar regla
```

### Campanita — componente global en el Layout

```
AppLayout
  └── TopBar
        └── AlertBell.vue          ← componente nuevo
              ├── q-btn (icon: notifications)
              │     └── q-badge (si unread_count > 0)
              └── q-menu (al hacer click)
                    └── AlertBellPanel.vue
                          ├── Lista de últimas alertas
                          │     cada item: título, tiempo relativo, ícono por tipo
                          │     si tiene source → router-link a la pantalla del recurso
                          └── "Ver todas" → router.push('/alerts')
```

### AlertContactsPage — `/settings/alert-contacts`

- PageHeader + botón "Añadir contacto"
- AppTable: nombre, email, estado, acciones edit/delete
- Dialog: form nombre + email

### AlertsPage — `/alerts`

- PageHeader + botón "Crear regla"
- QTabs: `Avisos de incidentes` | `Reglas configuradas`

**Tab Avisos:**

- FilterPanel: rango de fechas, trigger_type, status (active/resolved)
- AppTable: fuente, título, tipo, timestamp, estado
- Acción por fila: Resolver

**Tab Reglas:**

- Lista de `alert_rules` con toggle activo/inactivo
- Título, trigger_type, scope, destinatarios agrupados por canal
- Botones: Editar, Eliminar

### AlertRuleFormPage — `/alerts/rules/new` y `/edit`

- Campo: título
- Select: `trigger_type` (del catálogo §2)
- Select condicional: scope (todos / vehículo / empleado) — solo para tipos que aplica
- Input condicional: días de anticipación — solo para tipos `*_expiration`
- Multi-select: destinatarios (`alert_contacts`)
- Toggle por destinatario: Email | Push | Ambos

---

## 8. Cron Schedule (sidekiq-cron)

```yaml
# config/schedule.yml
doc_expiration_check:
  cron: "0 6 * * *"    # 6:00am diario
  class: DocExpirationCheckJob
  queue: default
  description: "Evalúa documentos vehiculares y de empleados próximos a vencer"
```

> Un solo job `DocExpirationCheckJob` maneja ambos modelos (vehículos y empleados)
> para evitar proliferación de jobs. Internamente llama a servicios separados.

### Ejemplo: DocExpirationCheckJob

```ruby
class DocExpirationCheckJob < ApplicationJob
  def perform
    check_vehicle_docs
    check_employee_docs
  end

  private

  def check_vehicle_docs
    rules = AlertRule.active.where(trigger_type: 'vehicle_doc_expiration')
    rules.each do |rule|
      days = rule.days_before || 7

      VehicleDocument
        .where(expiracion: Date.current + days.days)
        .find_each do |doc|
          Alert.create!(
            business_unit_id: rule.business_unit_id,
            alert_rule: rule,
            trigger_type: 'vehicle_doc_expiration',
            origin: 'cron',
            source_type: 'VehicleDocument',
            source_id: doc.id,
            titulo: "Vence #{doc.tipo_documento} — #{doc.vehicle&.clv}",
            descripcion: "El documento vence el #{doc.expiracion.strftime('%d/%m/%Y')}.",
            status: 'active',
            triggered_at: Time.current
          ).tap { |a| AlertDispatchJob.perform_later(a.id) }
        end
    end
  end

  def check_employee_docs
    # Misma lógica para EmployeeDocument
  end
end
```

---

## 9. Push Notifications

### Integración con `settings/Acceso a API`

El módulo existente `settings/Acceso a API` ya gestiona credenciales por usuario.
El token FCM del dispositivo se almacena como un atributo adicional del `ApiAccess`
del usuario (o en una tabla `user_push_tokens` ligada al `user_id`), evitando crear
una tabla `device_tokens` independiente.

```
ApiAccess (existente)
  └── fcm_token    string nullable   ← token del dispositivo
      platform     enum   web | ios | android
```

O si se prefiere no tocar el modelo existente:

```
user_push_tokens (tabla nueva, mínima)
  id
  user_id     FK
  fcm_token   string unique
  platform    enum
  active      boolean
```

### Registro del token (FE)

```
1. Al hacer login en el PWA → solicitar permiso de notificaciones
2. FCM SDK retorna el token del dispositivo
3. PATCH /api/v1/settings/api_access  { fcm_token: "...", platform: "web" }
   (reutiliza el endpoint existente de Acceso a API)
```

### Envío desde el BE

```ruby
class Alerts::PushSenderService
  def initialize(alert)
    @alert = alert
  end

  def call
    tokens = User.where(business_unit_id: @alert.business_unit_id)
                 .joins(:api_access)
                 .pluck('api_accesses.fcm_token')
                 .compact

    return if tokens.empty?

    fcm = FCM.new(ENV['FCM_SERVER_KEY'])
    fcm.send(tokens, {
      notification: {
        title: @alert.titulo,
        body: @alert.descripcion
      },
      data: {
        alert_id: @alert.id.to_s,
        trigger_type: @alert.trigger_type,
        source_type: @alert.source_type.to_s,
        source_id: @alert.source_id.to_s
      }
    })
  end
end
```

---

## 10. Pendientes antes de implementar

| # | Pregunta | Impacto |
|---|---|---|
| 1 | ¿El FCM token va en `ApiAccess` o tabla `user_push_tokens` separada? | Afecta migración y endpoint de registro |
| 2 | ¿Deduplicación en crons? (no re-disparar si ya existe alerta para el mismo doc hoy) | Añadir check `Alert.exists?(source_type:, source_id:, triggered_at: Date.current.all_day)` |
| 3 | ¿Los DB triggers de la app móvil usan `NOTIFY`/listen o polling? | Determina si se implementa `alert_db_listener_job` o polling simple |
| 4 | ¿`new_assignment` notifica solo al chofer asignado o también a administradores? | Afecta el `DispatcherService` para este tipo |
| 5 | ¿Quién puede marcar un aviso como resuelto? ¿Cualquier admin o solo el creador? | Afecta autorización en `resolve` |
| 6 | ¿Polling cada 60s para la campanita o implementar ActionCable? | ActionCable requiere configurar cable.yml + Redis channel |
| 7 | ¿Se necesita purga automática de alertas antiguas? | Añadir job de limpieza (ej. `alerts` con más de 6 meses) |
| 8 | ¿`vacation_pending` se dispara al crear o también si sigue pendiente X días después? | Si es lo segundo, se necesita un cron adicional |

---

## 11. Resumen de migraciones

```ruby
create_table :alert_contacts do |t|
  t.references :business_unit, null: false, foreign_key: true
  t.string  :nombre, null: false
  t.string  :email,  null: false
  t.boolean :active, default: true
  t.timestamps
end

create_table :alert_rules do |t|
  t.references :business_unit, null: false, foreign_key: true
  t.string  :titulo,       null: false
  t.string  :trigger_type, null: false
  t.string  :scope_type,   default: 'all'
  t.integer :scope_id
  t.integer :days_before
  t.boolean :active,       default: true
  t.integer :created_by
  t.timestamps
end

create_table :alert_rule_recipients do |t|
  t.references :alert_rule,    null: false, foreign_key: true
  t.references :alert_contact, null: false, foreign_key: true
  t.string :channel, null: false, default: 'email'
  t.timestamps
end

create_table :alerts do |t|
  t.references :business_unit, null: false, foreign_key: true
  t.references :alert_rule,    foreign_key: true
  t.string   :trigger_type, null: false
  t.string   :origin,       null: false
  t.string   :source_type
  t.integer  :source_id
  t.string   :titulo,       null: false
  t.text     :descripcion
  t.string   :status,       default: 'active'
  t.datetime :triggered_at, null: false
  t.datetime :resolved_at
  t.integer  :resolved_by
  t.timestamps
end

create_table :alert_reads do |t|
  t.references :alert, null: false, foreign_key: true
  t.references :user,  null: false, foreign_key: true
  t.datetime   :read_at, null: false
end

create_table :alert_deliveries do |t|
  t.references :alert,         null: false, foreign_key: true
  t.references :alert_contact, foreign_key: true
  t.string  :channel, null: false
  t.string  :status,  default: 'pending'
  t.datetime :sent_at
  t.text     :error_message
  t.timestamps
end

# Índices clave
add_index :alert_rules,      [:business_unit_id, :trigger_type, :active]
add_index :alerts,           [:business_unit_id, :status, :triggered_at]
add_index :alerts,           [:source_type, :source_id]
add_index :alert_reads,      [:alert_id, :user_id], unique: true
add_index :alert_deliveries, [:alert_id, :status]
```

---

*Última revisión: 2026-04-06*
