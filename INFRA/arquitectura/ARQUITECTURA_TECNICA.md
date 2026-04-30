# Arquitectura Técnica — Kumi TTPN Admin V2

**Última actualización:** 2026-04-30

---

## Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Multi-tenancy: Business Units](#2-multi-tenancy-business-units)
3. [Backend — Rails API](#3-backend--rails-api)
4. [Autenticación — Tres Canales Separados](#4-autenticación--tres-canales-separados)
5. [Autorización — CanCan + Privileges](#5-autorización--cancan--privileges)
6. [Jobs en Background — Sidekiq](#6-jobs-en-background--sidekiq)
7. [Tiempo Real — ActionCable](#7-tiempo-real--actioncable)
8. [Almacenamiento — ActiveStorage + AWS S3](#8-almacenamiento--activestorage--aws-s3)
9. [Base de Datos — PostgreSQL vía Supabase](#9-base-de-datos--postgresql-vía-supabase)
10. [Automatización — N8N](#10-automatización--n8n)
11. [Seguridad — Capas Implementadas](#11-seguridad--capas-implementadas)
12. [Frontend — Quasar PWA](#12-frontend--quasar-pwa)
13. [Deployment — Railway + Supabase + Netlify](#13-deployment--railway--supabase--netlify)

---

## 1. Visión General

Kumi TTPN Admin V2 es un sistema de gestión para empresas de transporte de gas LP y servicios de carga. Permite administrar vehículos, empleados, bookings de viaje, nómina, combustible, clientes y alertas, todo bajo un modelo multi-tenant por unidad de negocio.

### Arquitectura general

```text
                        Internet
                           │
              ┌────────────┴────────────┐
              │                         │
      ┌───────▼───────┐        ┌────────▼────────┐
      │  Quasar PWA   │        │  App Móvil       │
      │  (Netlify)    │        │  (Capacitor)     │
      └───────┬───────┘        └────────┬─────────┘
              │                         │
              │   HTTPS + Bearer JWT    │
              └────────────┬────────────┘
                           │
                ┌──────────▼──────────┐
                │   Rails 7.1 API     │  Railway
                │   kumi_admin_api    │
                └──────────┬──────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────▼─────┐  ┌─────▼──────┐  ┌───▼──────┐
     │ PostgreSQL │  │   Redis 7  │  │  AWS S3  │
     │ (Supabase) │  │  (Railway) │  │          │
     └────────────┘  └────────────┘  └──────────┘
                           │
                  ┌────────▼────────┐
                  │ Sidekiq Worker  │  Railway
                  │ kumi_sidekiq   │
                  └─────────────────┘
                           │
                  ┌────────▼────────┐
                  │   N8N           │  Railway
                  │ (Automatización)│
                  └─────────────────┘
```

### Stack

| Capa | Tecnología |
| --- | --- |
| API | Ruby on Rails 7.1 (API mode) + Ruby 3.3 |
| Base de datos | PostgreSQL 15 vía Supabase Pro (pgbouncer en prod) |
| Cache / Cola | Redis 7 |
| Jobs | Sidekiq 8 + sidekiq-cron |
| Autenticación | Devise + devise-jwt + Lockable (manual) |
| Autorización | CanCan (ability.rb) + objeto Privileges en JWT |
| WebSockets | ActionCable |
| Almacenamiento | ActiveStorage → AWS S3 (prod) / local (dev) |
| Rate limiting | rack-attack (Redis backend) |
| Request timeout | rack-timeout (env vars) |
| CVE scanning | bundler-audit |
| API Docs | rswag (Swagger/OpenAPI en `/api-docs`) |
| Frontend | Quasar 2.16 + Vue 3.4 + Vite |
| Deploy BE | Railway (3 servicios: API, Sidekiq, Redis) |
| Deploy FE | Netlify (auto-deploy desde GitLab) |
| Automatización | N8N self-hosted en Railway |

---

## 2. Multi-tenancy: Business Units

**Todos los datos de negocio están scoped por `business_unit_id`.** Nunca se mezclan datos entre Business Units (BUs).

### Cómo funciona

- Cada `User` pertenece a una `BusinessUnit`
- El `BaseController` extrae `@business_unit_id` del JWT en cada request
- Los controllers aplican el scope: `Model.where(business_unit_id: @business_unit_id)`
- Los sadmins (`User.sadmin?`) pueden pasar `?business_unit_id=X` para cambiar de BU
- Los usuarios regulares siempre usan la BU de su JWT — ignoran cualquier param

### Jerarquía de autorización por BU

```text
sadmin          → acceso a todas las BUs + panel de administración global
admin           → su BU únicamente
supervisor      → su BU, permisos según privileges
operador        → su BU, permisos según privileges
```

---

## 3. Backend — Rails API

### Estructura de carpetas clave

```text
ttpngas/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       ├── base_controller.rb         # JWT auth + business_unit_id
│   │       ├── auth/                      # Login/logout de Users
│   │       ├── client_auth/               # Login/logout de Employees (choferes)
│   │       └── [dominio]_controller.rb    # Un controller por recurso
│   │
│   ├── models/                            # ~88 modelos ActiveRecord
│   │
│   ├── services/                          # Lógica de negocio compleja
│   │   ├── dashboard_data_service.rb
│   │   ├── ttpn_data_service.rb
│   │   ├── queue_import.rb
│   │   ├── alerts/
│   │   │   ├── dispatcher_service.rb
│   │   │   ├── email_sender_service.rb
│   │   │   └── push_sender_service.rb
│   │   ├── fuel_performance/
│   │   │   ├── performers_ranker.rb
│   │   │   ├── timeline_builder.rb
│   │   │   └── vehicle_calculator.rb
│   │   └── payroll_svc/
│   │       ├── report_exporter.rb
│   │       ├── report_query.rb
│   │       └── week_calculator.rb
│   │
│   ├── jobs/                              # Sidekiq jobs
│   │   ├── alert_dispatch_job.rb
│   │   ├── dashboard_calculation_job.rb
│   │   ├── dashboard_export_job.rb
│   │   ├── deactivate_expired_versions_job.rb
│   │   ├── doc_expiration_check_job.rb
│   │   ├── ejecutar_script_python_job.rb
│   │   ├── ttpn_booking_import_job.rb
│   │   └── ttpn_calculation_job.rb
│   │
│   ├── mailers/
│   │   ├── alert_mailer.rb
│   │   ├── asignation_mailer.rb
│   │   └── client_user_mailer.rb
│   │
│   └── channels/
│       └── alerts_channel.rb              # WebSocket para notificaciones
│
├── config/
│   ├── routes.rb                          # Solo draw calls
│   └── routes/                            # Un archivo por dominio
│       ├── auth.rb
│       ├── dashboard.rb
│       ├── vehicles.rb
│       ├── employees.rb
│       ├── clients.rb
│       ├── bookings.rb
│       ├── payroll.rb
│       ├── fuel.rb
│       ├── administration.rb
│       └── alerts.rb
│
├── spec/
│   ├── integration/api/v1/               # Specs principales (generan Swagger)
│   ├── requests/api/v1/                  # Specs legacy
│   └── support/
│       ├── factory_bot.rb
│       └── rack_attack.rb                # Reset rack-attack entre tests
│
└── scripts/
    └── utils/db.py                        # Scripts Python (usan DATABASE_URL)
```

### Patrón de Controller

Todos heredan de `Api::V1::BaseController < ActionController::API`.

```ruby
module Api
  module V1
    class VehiclesController < Api::V1::BaseController
      before_action :set_vehicle, only: %i[show update destroy]

      def index
        @vehicles = Vehicle.where(business_unit_id: @business_unit_id)
                           .includes(:vehicle_type)
                           .page(params[:page])
        render json: @vehicles, each_serializer: VehicleSerializer
      end

      def create
        @vehicle = Vehicle.new(vehicle_params.merge(business_unit_id: @business_unit_id))
        if @vehicle.save
          render json: @vehicle, serializer: VehicleSerializer, status: :created
        else
          render json: { errors: @vehicle.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_vehicle
        @vehicle = Vehicle.where(business_unit_id: @business_unit_id).find(params[:id])
      end

      def vehicle_params
        params.require(:vehicle).permit(:plates, :brand, :model, :year, :vehicle_type_id)
      end
    end
  end
end
```

**Reglas de controllers:**

- Nunca lógica de negocio compleja — delegar a services
- `params.permit!` está prohibido — siempre whitelist explícita
- `find(params[:id])` siempre scoped a la BU del usuario (protección IDOR)
- `before_action :authenticate_user!` en BaseController — no se repite en cada controller

### Patrón de Service

Para lógica que involucra múltiples modelos, transacciones o servicios externos:

```ruby
module PayrollSvc
  class WeekCalculator
    def initialize(business_unit_id:, week:)
      @business_unit_id = business_unit_id
      @week = week
    end

    def call
      # Lógica de negocio aquí
      # Puede lanzar excepciones — el controller las rescata
    end
  end
end

# En el controller:
def calculate
  result = PayrollSvc::WeekCalculator.new(
    business_unit_id: @business_unit_id,
    week: params[:week]
  ).call
  render json: result
rescue ArgumentError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

### Auditoría automática

Las tablas principales tienen `created_by_id` y `updated_by_id`. El `BaseController` los asigna automáticamente en cada create/update via concern. No es necesario pasarlos manualmente desde el controller.

---

## 4. Autenticación — Tres Canales Separados

El sistema tiene **tres formas distintas de autenticarse**, cada una con su propio namespace y lógica:

### Canal 1: User JWT (panel admin)

- Ruta: `POST /api/v1/auth/sign_in`
- Modelo: `User` (Devise)
- Token firmado con `DEVISE_JWT_SECRET_KEY`
- Payload incluye: `user_id`, `jti`, `role`, objeto `privileges`
- Expiración: configurable (por defecto 24h)
- Revocación: regenerar `jti` en logout → token anterior queda inválido

### Canal 2: Employee JWT (app móvil de choferes)

- Ruta: `POST /api/v1/client_auth/sign_in`
- Modelo: `Employee`
- Namespace de rutas completamente separado de los Users
- Token **incompatible** con el canal de Users — no funciona en endpoints de admin y viceversa
- Payload incluye: `employee_id`, `jti`, permisos limitados

### Canal 3: API Key (N8N y apps externas)

- Header: `X-Api-Key: <key>`
- Modelos: `ApiUser` + `ApiKey`
- Las keys se crean desde el panel admin en Kumi → Configuración → API Keys
- El `ApiUser` representa la aplicación cliente (N8N, portal externo, etc.)
- Rotación semestral — ver `INFRA/seguridad/rotacion_api_keys.md`

### Brute Force — Devise Lockable (implementación manual)

Devise Lockable no funciona automáticamente con JWT (requiere Warden). Implementado manualmente en el `sessions_controller`:

- 10 intentos fallidos → cuenta bloqueada 1 hora
- Campos en tabla `users`: `failed_attempts`, `locked_at`, `unlock_token`
- Respuesta en cuenta bloqueada: `423 Locked` con tiempo restante

---

## 5. Autorización — CanCan + Privileges

### CanCan (ability.rb)

La autorización a nivel de acción/recurso usa **CanCan**. Las reglas viven en `app/models/ability.rb` y se definen por rol del usuario (sistemas, admin, rh, coordinador, etc.):

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user
    user.role&.nombre.tap do |rol|
      can :manage, :all if user.sadmin?
      can :manage, Vehicle if rol == 'admin'
      # ... resto de reglas por rol
    end
  end
end

# En el controller (cuando se usa authorize!):
authorize! :update, @vehicle
```

### Multi-tenancy — scope de BU en find

La autorización de datos (qué registros puede ver) se hace siempre scoping por `business_unit_id`:

```ruby
@record = Model.where(business_unit_id: @business_unit_id).find(params[:id])
```

Esto previene IDOR — un usuario de BU-A nunca puede acceder a registros de BU-B aunque tenga el ID.

### Objeto Privileges en JWT

El payload del JWT incluye un objeto `privileges` con permisos por módulo:

```json
{
  "user_id": 42,
  "privileges": {
    "vehicles": { "read": true, "create": true, "update": true, "delete": false },
    "payroll":  { "read": true, "create": false, "update": false, "delete": false },
    "employees": { "read": true, "create": true, "update": true, "delete": false }
  }
}
```

El frontend lee este objeto para mostrar/ocultar botones y rutas. El backend también lo verifica antes de operaciones sensibles.

**Regla:** Nunca `role_id` hardcodeado en frontend ni backend. Siempre leer del objeto `privileges`.

---

## 6. Jobs en Background — Sidekiq

### Servicios en Railway

| Servicio | Queues | Start command |
| --- | --- | --- |
| `kumi_sidekiq` | default, payrolls, alerts, mailers | `bundle exec sidekiq -c 10 -q default -q payrolls -q alerts -q mailers` |

### Jobs existentes

| Job | Queue | Propósito |
| --- | --- | --- |
| `AlertDispatchJob` | alerts | Evalúa reglas y crea alertas |
| `DashboardCalculationJob` | default | Precalcula KPIs del dashboard |
| `DashboardExportJob` | default | Exporta dashboard a Excel/PDF |
| `DeactivateExpiredVersionsJob` | default | Desactiva versiones de app vencidas |
| `DocExpirationCheckJob` | default | Verifica documentos vencidos y alerta |
| `EjecutarScriptPythonJob` | default | Ejecuta scripts Python de análisis |
| `TtpnBookingImportJob` | default | Importación masiva de bookings |
| `TtpnCalculationJob` | default | Calcula cuadre de viajes |

### Jobs programados (sidekiq-cron)

Configurados en `config/initializers/sidekiq.rb`. Se ejecutan en el worker `kumi_sidekiq`, no en la API web.

### Patrón de Job

```ruby
class DocExpirationCheckJob < ApplicationJob
  queue_as :default

  def perform(business_unit_id)
    # Procesar documentos de esa BU
    # Si hay error, Sidekiq reintenta automáticamente (3 veces por defecto)
  end
end

# Encolar desde un controller:
DocExpirationCheckJob.perform_later(@business_unit_id)
```

---

## 7. Tiempo Real — ActionCable

Las notificaciones de alertas se entregan via WebSocket usando **ActionCable**.

### Flujo

```text
AlertDispatchJob crea Alert
       │
       └── AlertsChannel.broadcast_to(user, alert_data)
               │
               └── Frontend: cable.subscribe({ channel: 'AlertsChannel' })
                       │
                       └── AlertBell.vue actualiza badge en tiempo real
```

### Autenticación WebSocket

El token JWT se pasa como parámetro en la conexión WebSocket. El `ApplicationCable::Connection` lo valida igual que los controllers HTTP.

```javascript
// src/boot/cable.js
createConsumer(`wss://api.kumi.ttpn.com.mx/cable?token=${jwt}`)
```

---

## 8. Almacenamiento — ActiveStorage + AWS S3

### Configuración

| Entorno | Backend | Configuración |
| --- | --- | --- |
| Desarrollo | Disco local | `config/storage.yml → local` |
| Producción | AWS S3 | bucket `ttpngas-production`, región `us-east-2` |

### Variables de entorno (producción)

```bash
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-2
AWS_BUCKET_NAME=ttpngas-production
```

Las credenciales se rotan semestralmente. Ver `INFRA/seguridad/rotacion_api_keys.md`.

### Uso

```ruby
class VehicleDocument < ApplicationRecord
  has_one_attached :file

  def file_url
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: false)
  end
end
```

---

## 9. Base de Datos — PostgreSQL vía Supabase

### Categorías de modelos

91 tablas en producción. Modelos organizados por dominio:

| Dominio | Modelos |
| --- | --- |
| Tenancy | `BusinessUnit` |
| Auth Admin | `User`, `Role`, `Privilege`, `RolePrivilege` |
| Auth Móvil | `Employee` (Devise) |
| Auth Externo | `ApiUser`, `ApiKey` |
| Vehículos | `Vehicle`, `VehicleType`, `VehicleAsignation`, `VehicleCheck`, `VehicleDocument`, `VehicleDocumentType`, `VehicleTypePrice` |
| Mantenimiento | `VeAsignation`, `VehicleEvent`, `ScheduledMaintenance`, `DriverRequest`, `ServiceAppointment` |
| Empleados | `Employee`, `EmployeeDocument`, `EmployeeDocumentType`, `EmployeeSalary`, `EmployeeMovement`, `EmployeeMovementType`, `EmployeeVacation`, `EmployeeAppointment`, `EmployeeAppointmentLog`, `EmployeeDeduction`, `EmployeesIncidence`, `EmployeeWorkDay`, `EmployeeDriversLevel`, `DriversLevel`, `Labor` |
| Clientes | `Client`, `ClientBranchOffice`, `ClientContact`, `ClientBranchOfficeContact`, `ClientBranchOfficeTtpnContact`, `ClientEmployee`, `ClientUser`, `ClientTtpnService` |
| Viajes TTPN | `TtpnBooking`, `TtpnBookingPassenger`, `TravelCount`, `TtpnService`, `TtpnServiceType`, `TtpnServicePrice`, `TtpnServiceDriverIncrease`, `TtpnForeignDestiny`, `Concessionaire`, `CooTravelRequest`, `CooTravelEmployeeRequest` |
| Precios por Segmento de Pasajeros | `CtsIncrement`, `CtsIncrementDetail`, `CtsDriverIncrement` |
| Nómina | `Payroll`, `PayrollLog`, `Invoicing`, `InvoiceType` |
| Combustible | `GasCharge`, `GasFile`, `GasStation`, `GasolineCharge` |
| Alertas | `Alert`, `AlertRule`, `AlertRuleRecipient`, `AlertDelivery`, `AlertRead`, `AlertContact` |
| Ruteo | `CrDay`, `CrdHr`, `CrdhRoute`, `CrdhrPoint` |
| Configuración del sistema | `KumiSetting` |
| Catálogos globales | `Supplier`, `Discrepancy`, `ReviewPoint`, `Incidence` |
| Auditoría (PaperTrail) | `Version` |

### Configuración del sistema — KumiSetting

`KumiSetting` almacena pares clave-valor por Business Unit. Es la única fuente de configuración mutable en runtime (sin deploy).

```ruby
KumiSetting.get_value(business_unit_id, key, default)
KumiSetting.set_value(business_unit_id, key, value, category:)
```

#### Keys disponibles

| Categoría | Key | Tipo | Valores | Default |
| --- | --- | --- | --- | --- |
| `payroll` | `payroll.dia_pago` | Integer | 0=Dom … 6=Sáb | `4` (Jueves) |
| `payroll` | `payroll.periodo` | String | `semanal`, `quincenal`, `mensual` | `semanal` |
| `payroll` | `payroll.hora_corte` | String HH:MM | e.g. `01:30` | `01:30` |
| `vacations` | `vacations.periodos` | JSON | `{ "1": 12, "2": 14, ... }` | LFT 2023 |

#### Tabla de vacaciones LFT 2023 (default)

| Años trabajados | Días de vacaciones |
| --- | --- |
| 1 | 12 |
| 2 | 14 |
| 3 | 16 |
| 4 | 18 |
| 5 | 20 |
| 6 | 22 |
| 7 | 24 |
| 8 | 26 |
| 9 | 28 |
| 10 | 30 |
| 11+ | +2 días por cada 5 años adicionales |

Inicializar defaults para una BU nueva: `KumiSetting.initialize_defaults(business_unit_id)`

### Funciones PostgreSQL

Las funciones PG encapsulan lógica de cuadre de viajes y son la fuente de verdad:

| Función | Propósito |
| --- | --- |
| `buscar_booking(clv, ventana)` | Busca el TtpnBooking correspondiente a un TravelCount (±15 min) |
| `buscar_nomina(employee_id, fecha)` | Encuentra la Payroll activa que debe absorber un TravelCount |
| `sp_tctb_insert()` | Trigger BEFORE INSERT en travel_counts — calcula cuadre automático |

### Trigger `sp_tctb_insert()`

Se ejecuta en cada INSERT a `travel_counts` (tanto desde Rails como desde PHP legacy):

1. Construye `clv_servicio` si llega NULL (inserts PHP)
2. Defaultea `created_by_id`/`updated_by_id` a `1` si llegan NULL
3. Calcula `viaje_encontrado` y `ttpn_booking_id` via `buscar_booking()`

**No duplicar esta lógica en Ruby** — el trigger es la fuente de verdad.

### Conexión en producción

Railway usa `DATABASE_URL` de Supabase (modo Session de pgbouncer, port 5432). Los scripts Python usan la misma variable.

```bash
DATABASE_URL=postgresql://postgres.[project]:[password]@[host]:5432/postgres
```

---

## 10. Automatización — N8N

N8N está self-hosted en Railway como servicio separado. **No conecta a la base de datos directamente.**

### Flujo de integración

```text
N8N Workflow
     │
     └── HTTP POST https://api.kumi.ttpn.com.mx/api/v1/[endpoint]
             │  Header: X-Api-Key: <api_key>
             │
             └── Rails ApiKey middleware valida la key
                     │
                     └── Controller ejecuta la lógica normal
```

### Cómo crear una integración N8N

1. Kumi Admin → Configuración → API Keys → crear nueva key para "N8N"
2. En N8N: crear credencial tipo "Header Auth" con nombre `X-Api-Key` y el valor de la key
3. En cada nodo HTTP de N8N: usar la credencial creada
4. Las keys se rotan semestralmente desde el panel admin

---

## 11. Seguridad — Capas Implementadas

### Capa 1: Rate Limiting — rack-attack

| Throttle | Límite | Período | Key |
| --- | --- | --- | --- |
| Login (`/sign_in`) | 5 req | 20 seg | IP |
| API general (`/api/`, `/auth/`) | 300 req | 5 min | IP |
| API autenticada (header `Authorization`) | 600 req | 5 min | Token |
| Blocklist brute force | 20+ intentos | — | IP bloqueada 1h |

- Backend: Redis (namespace `rack_attack`)
- En tests: `MemoryStore` + `Rack::Attack.reset!` antes de cada spec
- Respuesta: `429 Too Many Requests` + header `Retry-After` + body JSON

### Capa 2: Request Timeout — rack-timeout

Configuración solo por env vars (rack-timeout 0.7.x eliminó setters de clase):

```bash
RACK_TIMEOUT_SERVICE_TIMEOUT=25   # abort request después de 25s
RACK_TIMEOUT_WAIT_TIMEOUT=30      # abort si request espera >30s en cola
```

### Capa 3: Account Lockout — Devise Lockable

- 10 intentos fallidos → cuenta bloqueada 1 hora
- Implementación manual en `sessions_controller` (Lockable no funciona con JWT automáticamente)
- Campos: `failed_attempts`, `locked_at`, `unlock_token` en tabla `users`

### Capa 4: IDOR Prevention

Todos los `find(params[:id])` están scoped a la BU del usuario:

```ruby
# Nunca hacer:
@record = Model.find(params[:id])

# Siempre:
@record = Model.where(business_unit_id: @business_unit_id).find(params[:id])
# o si el modelo tiene relación indirecta:
@record = Model.joins(:parent).where(parents: { business_unit_id: @business_unit_id }).find(params[:id])
```

### Capa 5: Command Injection Prevention

Los jobs que ejecutan comandos del sistema usan Array form (no string interpolation):

```ruby
# Inseguro:
system("bin/rails task PARAM=#{user_input}")

# Seguro:
system({ 'PARAM' => safe_value }, 'bin/rails', 'task')

# Para scripts Python (Open3):
cmd = [PYTHON_BIN, safe_script_path] + validated_args
Open3.capture3(*cmd)
```

### Capa 6: CSP — Content Security Policy

Configurado en `ttpn-frontend/public/_headers` (Netlify):

```text
script-src 'self'                          # sin unsafe-inline ni unsafe-eval
style-src 'self' 'unsafe-inline'           # Quasar requiere estilos dinámicos
```

`'unsafe-inline'` en scripts fue eliminado: Vue 3 + Vite pre-compila templates, no usa eval en producción.

### Capa 7: Pre-commit Hook

`.githooks/pre-commit` detecta antes de cada commit:

- AWS keys (`AKIA...`)
- Claves PEM privadas
- Tokens Railway / Heroku
- Valores reales en `SECRET_KEY_BASE`, `DEVISE_JWT_SECRET_KEY`, `N8N_ENCRYPTION_KEY`

Activar en repo nuevo: `git config core.hooksPath .githooks`

### Capa 8: Parameter Filtering

`config/application.rb` filtra de logs:

```ruby
config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt,
  :authorization, :api_key, :jwt, :bearer,
  :card_number, :cvv, :clabe, :webhook_secret
]
```

### Capa 9: CVE Scanning — bundler-audit

```bash
bundle exec bundler-audit check   # en CI — detecta gems con CVEs conocidos
```

---

## 12. Frontend — Quasar PWA

### Patrón obligatorio de página

Toda página nueva debe seguir el patrón:

```text
Page (orquestador)
  ├── FilterPanel (composable useFilters)
  ├── AppTable (componente estándar)
  └── Dialog/Form (componente atómico)

Composable (lógica de estado y API)
  └── Service (llamada HTTP pura)
```

```vue
<!-- VehiclesPage.vue — Page orquestador -->
<script setup>
import { useVehiclesOrchestrator } from 'composables/orchestrators/useVehiclesOrchestrator'

const {
  vehicles, loading, filters, pagination,
  fetchVehicles, handleCreate, handleUpdate, handleDelete
} = useVehiclesOrchestrator()
</script>

<template>
  <q-page>
    <FilterPanel :filters="filters" @apply="fetchVehicles" />
    <AppTable :rows="vehicles" :loading="loading" :columns="columns" />
  </q-page>
</template>
```

**El composable** maneja estado, llama al service y expone funciones a la page.  
**El service** es una función pura que solo hace el `api.get/post/patch/delete`.

### Sistema de privilegios en FE

```javascript
// composables/usePrivileges.js
const { canCreate, canEdit, canDelete } = usePrivileges('vehicles')

// En template:
<q-btn v-if="canCreate" @click="openDialog">Nuevo</q-btn>
```

Los privileges vienen del JWT, no de llamadas adicionales a la API.

### Manejo de errores API

**Siempre** usar `notifyApiError(error)`:

```javascript
import { useNotify } from 'composables/useNotify'
const { notifyApiError } = useNotify()

try {
  await vehiclesService.create(form)
} catch (error) {
  notifyApiError(error)  // extrae error.response.data.errors automáticamente
}
```

### Stores Pinia (solo auth y catálogos globales)

Pinia se usa solo para estado verdaderamente global:

| Store | Propósito |
| --- | --- |
| `auth-store.js` | Usuario activo, token JWT, login/logout |
| `privileges-store.js` | Mapa de privileges del JWT |
| `catalogs-store.js` | Catálogos globales cacheados (tipos de vehículo, etc.) |

**No crear stores para estado de páginas** — eso va en composables.

### CSP y PWA

- `_headers`: CSP sin `unsafe-inline` en scripts (Netlify)
- `_redirects`: SPA redirect (todas las rutas → `index.html`)
- `quasar.config.js`: `globIgnores` incluye `_redirects` y `_headers` para que Workbox no los precachee

---

## 13. Deployment — Railway + Supabase + Netlify

### Servicios en producción

| Servicio | Rama | Propósito | Dominio |
| --- | --- | --- | --- |
| `kumi_admin_api` | `transform_to_api` | Rails API web | Sí (público) |
| `kumi_sidekiq` | `transform_to_api` | Worker Sidekiq | No |
| `Redis` | — | Cache + colas | No (interno) |
| `N8N` | — | Automatización | Sí (protegido) |

### Proceso de deploy BE

```bash
# 1. Push a GitHub (Railway escucha este remote)
git push github transform_to_api

# 2. Push a GitLab (mirror)
git push origin transform_to_api

# Railway hace auto-deploy y ejecuta db:prepare via Dockerfile
```

### Proceso de deploy FE

```bash
# Netlify escucha GitLab (origin)
git push origin main

# Netlify ejecuta automáticamente:
quasar build -m pwa
# Output: dist/pwa/
```

### Variables de entorno clave

Ver `ttpngas/.env.example` para la lista completa. Las más críticas:

```bash
DATABASE_URL         → Supabase (Session mode, port 5432)
REDIS_URL            → Redis interno de Railway (${{Redis.REDIS_URL}})
DEVISE_JWT_SECRET_KEY → Firma de JWT (rotar cada 6 meses)
SECRET_KEY_BASE      → Firma de sesiones Rails (rotar cada 6 meses)
AWS_ACCESS_KEY_ID    → S3 (rotar cada 6 meses)
FRONTEND_URL         → https://kumi.ttpn.com.mx (CORS whitelist)
```

### Verificación post-deploy

- [ ] `GET /up` retorna 200
- [ ] Login en frontend funciona
- [ ] Sidekiq procesando jobs (Railway Logs → kumi_sidekiq)
- [ ] ActionCable conecta (WebSockets en consola del browser sin errores)
- [ ] Upload de archivo a S3 funciona

---

## Referencias

- [PRD.md](../PRD.md) — Qué hace cada módulo a nivel de negocio
- [ADR/](ADR/) — Decisiones de arquitectura con contexto y alternativas
- [SEGURIDAD.md](../seguridad/SEGURIDAD.md) — Capas de seguridad, RLS, CORS, checklist
- [operaciones/railway_deployment.md](../operaciones/railway_deployment.md) — Guía detallada de deploy
- [onboarding/onboarding_BE.md](../onboarding/onboarding_BE.md) — Setup local backend
- [onboarding/onboarding_FE.md](../onboarding/onboarding_FE.md) — Setup local frontend
