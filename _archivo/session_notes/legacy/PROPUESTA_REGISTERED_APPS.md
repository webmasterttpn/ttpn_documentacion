# Propuesta — Control de Aplicaciones Externas Conectadas a Kumi

**Fecha:** 2026-04-10  
**Estado:** Propuesta para revisión  
**Módulo relacionado:** API Access (actual) → extensión hacia App Registry  
**Infraestructura:** Railway Pro + Supabase Pro + Netlify (ver `INFRAESTRUCTURA_RAILWAY_NETLIFY_SUPABASE.md`)

---

## 0. Contexto de infraestructura

El stack donde viven estas apps:

| Servicio | Plataforma | Rol |
| --- | --- | --- |
| Rails API + Sidekiq | **Railway Pro** | Backend principal — ya migrado |
| Redis | Railway add-on | Sidekiq + caché |
| N8N | **Railway** (mismo proyecto) | Automatización de procesos — en planeación |
| PostgreSQL | **Supabase Pro** | Base de datos principal |
| Frontend Kumi Admin | **Netlify** | Panel administrativo |
| App Móvil (PWA/Capacitor) | **Netlify** | App para choferes — Fase 2 |
| PHP proxy | Heroku (temporal) | Eliminar en Fase 2 |

**N8N en Railway** se conecta al BE via `api_keys` (flujo M2M) — automatiza procesos como envío de reportes, sincronización de datos externos, alertas programadas. No requiere `registered_apps` porque no hay usuario humano.

---

## 1. Problema actual

Hoy el sistema tiene:

- `api_users` + `api_keys` → autenticación **máquina a máquina** (PHP, N8N, scripts). No hay usuario humano, solo una key que hace requests al BE.
- `client_auth` → login para usuarios de clientes en portales externos. Autenticado, pero sin registro del origen de la app que hace el request.

**Lo que no existe:**

- Registro de qué aplicaciones PWA están autorizadas a conectarse al BE.
- Control de qué módulos puede usar cada app.
- Sesiones de usuario vinculadas a una app específica (saber que el usuario X inició sesión desde la App "Portal Captura Clientes" y no desde Kumi Admin).
- Auditoría por app (cuántas sesiones, desde dónde, qué usuario).
- Un administrador que pueda activar/desactivar una app completa sin tocar a los usuarios.

---

## 2. Propuesta: dos capas complementarias

```
┌─────────────────────────────────────────────────────────────┐
│                    KUMI ADMIN (Administrador)                │
│                                                             │
│  Módulo "Aplicaciones Registradas"                          │
│  ├── Alta/baja de apps                                      │
│  ├── Asignar módulos permitidos por app                     │
│  └── Ver sesiones activas por app                          │
└─────────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────────┐  ┌──────────────────────────────┐
│  api_users + api_keys   │  │  registered_apps (NUEVO)     │
│  (M2M — sin usuario)    │  │  (PWA con login de usuario)  │
│                         │  │                              │
│  PHP, N8N, scripts      │  │  Portal Captura, App Móvil,  │
│  → usan API key         │  │  Portal Clientes, etc.       │
│  → no hay sesión humana │  │  → usuario real hace login   │
└─────────────────────────┘  └──────────────────────────────┘
```

### Diferencia clave

| Concepto | `api_users` / `api_keys` (actual) | `registered_apps` (nuevo) |
| --- | --- | --- |
| ¿Quién se autentica? | La máquina/sistema | Un usuario humano |
| ¿Hay sesión? | No (key estática) | Sí (JWT por usuario + app) |
| ¿Para qué sirve? | Integraciones backend-backend | PWAs, portales, apps móviles |
| ¿Módulo en Kumi Admin? | Acceso API (ya existe) | Aplicaciones (nuevo) |

---

## 3. Tablas nuevas

### 3.1 `registered_apps` — Registro de aplicaciones

```ruby
create_table :registered_apps do |t|
  t.string  :name,        null: false           # "Portal Captura Clientes"
  t.string  :slug,        null: false           # "portal-captura" (URL-safe, único)
  t.string  :description
  t.string  :url                                # URL del frontend (para CORS y auditoría)
  t.string  :app_key,     null: false           # Clave pública de identificación
  t.string  :app_secret_digest, null: false     # Secreto hasheado (bcrypt)
  t.boolean :active,      default: true, null: false
  t.jsonb   :allowed_modules, default: []       # ["employees", "clients", "travel_counts"]
  t.jsonb   :settings,    default: {}           # Configuración extra por app
  t.bigint  :business_unit_id, null: false
  t.bigint  :created_by_id
  t.bigint  :updated_by_id
  t.timestamps
end

add_index :registered_apps, :slug,        unique: true
add_index :registered_apps, :app_key,     unique: true
add_index :registered_apps, :business_unit_id
add_index :registered_apps, :active
```

**Campos clave:**

| Campo | Descripción |
| --- | --- |
| `slug` | Identificador en URL: `portal-captura`. Inmutable después de crearse. |
| `app_key` | Token público que la app manda en cada request (como `CLIENT_ID` en OAuth). |
| `app_secret_digest` | Secreto hasheado. Solo se muestra en claro al crear (similar a `api_keys`). |
| `allowed_modules` | Array JSONB con las claves de módulos que la app puede consumir del BE. |
| `settings` | Futuro: configuración específica por app (timeout, rate limit, etc.). |

---

### 3.2 `app_sessions` — Sesiones de usuario por app

```ruby
create_table :app_sessions do |t|
  t.bigint  :registered_app_id, null: false
  t.bigint  :user_id,           null: false     # FK a users (tabla interna)
  t.string  :jti,               null: false     # JWT ID único por sesión
  t.string  :ip_address
  t.string  :user_agent
  t.datetime :last_active_at
  t.datetime :expires_at,       null: false
  t.boolean  :revoked,          default: false, null: false
  t.timestamps
end

add_index :app_sessions, :jti,                unique: true
add_index :app_sessions, :registered_app_id
add_index :app_sessions, [:user_id, :registered_app_id]
add_index :app_sessions, :expires_at
add_index :app_sessions, :revoked
```

Una fila por sesión activa. El `jti` es el identificador del JWT — permite revocar tokens individuales sin invalidar toda la sesión del usuario.

---

### 3.3 `app_user_privileges` — Permisos por usuario dentro de una app (opcional fase 2)

Si en el futuro se necesita control granular por usuario dentro de la app:

```ruby
create_table :app_user_privileges do |t|
  t.bigint  :registered_app_id, null: false
  t.bigint  :user_id,           null: false
  t.string  :module_key,        null: false     # "employees"
  t.boolean :can_access,        default: false
  t.boolean :can_create,        default: false
  t.boolean :can_edit,          default: false
  t.boolean :can_delete,        default: false
  t.timestamps
end

add_index :app_user_privileges, [:registered_app_id, :user_id, :module_key], unique: true
```

> Fase 1 usa `allowed_modules` de la app como límite global. Fase 2 agrega control por usuario.

---

## 4. Flujo de autenticación para apps externas

### 4.1 Login desde una app externa

```
App Externa (PWA)
  │
  ├─ POST /api/v1/app_auth/login
  │   {
  │     app_key:    "pk_live_xxx",
  │     app_secret: "sk_live_xxx",
  │     email:      "usuario@ttpn.com",
  │     password:   "password123"
  │   }
  │
  ▼
AppAuth::SessionsController
  │
  ├─ 1. Buscar RegisteredApp por app_key → 401 si no existe o inactiva
  ├─ 2. Verificar app_secret contra app_secret_digest (bcrypt) → 401 si falla
  ├─ 3. Autenticar User por email+password → 401 si falla
  ├─ 4. Verificar que user pertenezca a business_unit de la app → 403 si no
  ├─ 5. Crear AppSession (jti único, expires_at = 8h)
  └─ 6. Generar JWT con payload:
        {
          sub: user.id,
          jti: session.jti,
          app: registered_app.slug,
          scope: "app",
          iat: now,
          exp: expires_at
        }
  │
  ▼
Respuesta al cliente:
  {
    access_token: "eyJ...",
    expires_at:   "2026-04-10T18:00:00Z",
    user: {
      id: 1,
      nombre: "Antonio",
      email: "ing.castean@gmail.com"
    },
    app: {
      slug: "portal-captura",
      name: "Portal Captura Clientes",
      allowed_modules: ["travel_counts", "clients"]
    }
  }
```

### 4.2 Requests autenticados desde la app

```
App Externa
  │
  ├─ GET /api/v1/travel_counts
  │   Headers:
  │     Authorization: Bearer eyJ...   ← JWT de app_session
  │     X-App-Key: pk_live_xxx         ← Identifica la app (opcional, ya está en JWT)
  │
  ▼
AppAuth::BaseController
  ├─ Decodificar JWT
  ├─ Verificar que scope == "app"
  ├─ Buscar AppSession por jti → 401 si revocada o expirada
  ├─ Verificar que el módulo solicitado esté en allowed_modules → 403 si no
  ├─ Actualizar last_active_at de la sesión
  └─ Setear @current_user y @current_app → continuar al controller
```

### 4.3 Logout

```
DELETE /api/v1/app_auth/logout
→ Revocar AppSession (revoked = true)
→ El JWT queda inválido aunque no haya expirado
```

---

## 5. Controladores BE a implementar

### Rutas nuevas

```ruby
# config/routes/app_auth.rb
namespace :app_auth do
  post   'login',   to: 'sessions#create'
  delete 'logout',  to: 'sessions#destroy'
  get    'me',      to: 'sessions#me'
  post   'refresh', to: 'sessions#refresh'
end

# config/routes/administration.rb (agregar)
resources :registered_apps do
  member do
    post :regenerate_secret
    patch :activate
    patch :deactivate
  end
  collection do
    get :sessions   # sesiones activas de todas las apps
  end
  resources :app_sessions, only: [:index, :destroy]  # ver y revocar sesiones
end
```

### Controladores

```
app/controllers/api/v1/
├── app_auth/
│   └── sessions_controller.rb     # login, logout, me, refresh
├── registered_apps_controller.rb  # CRUD admin de apps
└── app_sessions_controller.rb     # ver/revocar sesiones por app
```

### Base controller para apps externas

```ruby
# app/controllers/api/v1/app_auth/base_controller.rb
class Api::V1::AppAuth::BaseController < ActionController::API
  before_action :authenticate_app_request!
  before_action :check_module_access!

  private

  def authenticate_app_request!
    token = request.headers['Authorization']&.split(' ')&.last
    payload = JwtService.decode(token)

    raise ApiErrors::Unauthorized unless payload[:scope] == 'app'

    @app_session = AppSession.find_by(jti: payload[:jti])
    raise ApiErrors::Unauthorized if @app_session.nil? || @app_session.revoked?
    raise ApiErrors::Unauthorized if @app_session.expires_at < Time.current

    @current_user = User.find(payload[:sub])
    @current_app  = @app_session.registered_app
    @app_session.touch(:last_active_at)
  end

  def check_module_access!
    # Cada controller hijo define qué módulo requiere:
    # required_module 'travel_counts'
    return unless respond_to?(:required_module, true)
    mod = send(:required_module)
    unless @current_app.allowed_modules.include?(mod.to_s)
      render json: { error: 'Módulo no autorizado para esta aplicación' }, status: :forbidden
    end
  end
end
```

---

## 6. Modelo `RegisteredApp`

```ruby
class RegisteredApp < ApplicationRecord
  include Auditable

  belongs_to :business_unit
  has_many :app_sessions, dependent: :destroy

  validates :name,       presence: true
  validates :slug,       presence: true, uniqueness: true,
                         format: { with: /\A[a-z0-9\-]+\z/ }
  validates :app_key,    presence: true, uniqueness: true
  validates :business_unit, presence: true

  before_validation :generate_app_key, on: :create

  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def generate_secret!
    raw_secret = SecureRandom.hex(32)
    update!(app_secret_digest: BCrypt::Password.create(raw_secret))
    raw_secret  # se retorna UNA SOLA VEZ al crear/regenerar
  end

  def authenticate_secret(secret)
    BCrypt::Password.new(app_secret_digest) == secret
  end

  def active_sessions
    app_sessions.where(revoked: false).where('expires_at > ?', Time.current)
  end

  def revoke_all_sessions!
    app_sessions.update_all(revoked: true)
  end

  private

  def generate_app_key
    self.app_key ||= "pk_#{SecureRandom.hex(16)}"
  end
end
```

---

## 7. Integración con el módulo API Access actual

El módulo **API Access** en Kumi Admin ya gestiona `api_users` y `api_keys` (integraciones M2M). Se propone extenderlo con una nueva sección dentro del mismo módulo:

```
Módulo "Acceso API" (actual)
├── API Users    → integraciones máquina a máquina (N8N, PHP, scripts)
├── API Keys     → claves por api_user
└── Aplicaciones → [NUEVO] registro de PWAs con autenticación de usuario
    ├── Lista de apps registradas
    ├── Alta/edición de app (nombre, url, módulos permitidos)
    ├── Ver/revocar sesiones activas por app
    └── Regenerar secreto
```

O bien, como módulo propio en el sidebar de Kumi Admin bajo **Configuración → Aplicaciones**.

---

## 8. Pantalla de administración en Kumi Admin (FE)

### `RegisteredAppsPage.vue`

```
┌─────────────────────────────────────────────────────────────┐
│ Aplicaciones Registradas                    [+ Nueva App]   │
├──────────────┬──────────────┬─────────┬────────┬───────────┤
│ Nombre       │ URL          │ Módulos │ Status │ Acciones  │
├──────────────┼──────────────┼─────────┼────────┼───────────┤
│ Portal Cap.. │ netlify.app  │ 3       │ Activa │ ✎ ⊘ 👁   │
│ App Móvil    │ —            │ 5       │ Activa │ ✎ ⊘ 👁   │
│ Portal CLI   │ netlify.app  │ 1       │ Inact. │ ✎ ✓ 👁   │
└──────────────┴──────────────┴─────────┴────────┴───────────┘
```

### Dialog de alta / edición

```
┌─────────────────────────────────────────────────────────────┐
│ Nueva Aplicación                                            │
│                                                             │
│ Nombre *         [Portal de Captura Clientes              ] │
│ Slug *           [portal-captura                          ] │
│ Descripción      [App para captura de viajes en campo     ] │
│ URL del Frontend [https://captura.netlify.app             ] │
│                                                             │
│ Módulos permitidos:                                         │
│  ☑ Travel Counts   ☑ Clientes   ☐ Empleados                │
│  ☐ Vehículos       ☑ Catálogos  ☐ Nóminas                  │
│  ☐ Bookings TTPN                                           │
│                                                             │
│                            [Cancelar]  [Crear Aplicación]  │
└─────────────────────────────────────────────────────────────┘
```

Al crear, mostrar el secreto una sola vez:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ Guarda este secreto — no se mostrará de nuevo            │
│                                                             │
│ App Key:    pk_3a8f7b2c1d9e4f5a                             │
│ App Secret: sk_9f2e8c4b1a7d3f6e2c5b9a4d8f1e3c7b          │
│                                                             │
│ Configura estas variables en tu app:                        │
│ APP_KEY=pk_3a8f7b2c1d9e4f5a                               │
│ APP_SECRET=sk_9f2e8c4b1a7d3f6e2c5b9a4d8f1e3c7b          │
│                                                             │
│                                          [Entendido]       │
└─────────────────────────────────────────────────────────────┘
```

### Panel de sesiones activas

```
┌─────────────────────────────────────────────────────────────┐
│ Sesiones Activas — Portal Captura Clientes                  │
├──────────────┬──────────────┬───────────────┬──────────────┤
│ Usuario      │ IP           │ Último acceso │ Acciones     │
├──────────────┼──────────────┼───────────────┼──────────────┤
│ Juan Pérez   │ 192.168.1.5  │ hace 3 min    │ [Revocar]    │
│ Ana Gómez    │ 10.0.0.12    │ hace 1 hora   │ [Revocar]    │
└──────────────┴──────────────┴───────────────┴──────────────┘
                                [Revocar todas las sesiones]
```

---

## 9. Uso desde una app externa nueva

### Variables de entorno en la nueva PWA

```bash
# .env de la nueva app
API_URL=https://backend.railway.app
APP_KEY=pk_3a8f7b2c1d9e4f5a
APP_SECRET=sk_9f2e8c4b1a7d3f6e2c5b9a4d8f1e3c7b
```

### Login en la nueva app

```javascript
// src/stores/auth-store.js (en la nueva app)
async login(email, password) {
  const response = await api.post('/api/v1/app_auth/login', {
    app_key:    import.meta.env.APP_KEY,
    app_secret: import.meta.env.APP_SECRET,
    email,
    password,
  })

  localStorage.setItem('jwt_token', response.data.access_token)
  this.user = response.data.user
  this.allowedModules = response.data.app.allowed_modules
}
```

### Guard de módulos en la nueva app

```javascript
// La app solo ve lo que el admin autorizó
// Si intenta llamar a un módulo no autorizado → BE devuelve 403
// El FE puede consultar allowedModules para esconder rutas no autorizadas:

const allowedModules = response.data.app.allowed_modules
// ['travel_counts', 'clients']

// En el router:
{ path: '/employees', 
  component: EmployeesPage,
  meta: { requiredModule: 'employees' }
}

Router.beforeEach((to) => {
  const mod = to.meta.requiredModule
  if (mod && !allowedModules.includes(mod)) return next('/403')
})
```

---

## 10. Diferencias respecto al auth actual

| Aspecto | `auth` (Kumi Admin) | `client_auth` (portales cliente) | `app_auth` (NUEVO) |
| --- | --- | --- | --- |
| Tabla de usuario | `users` | `client_users` | `users` |
| Scope del JWT | `user` | `client` | `app` |
| Validación extra | rol admin | cliente activo | app registrada + módulo |
| Sesión registrada | Devise JTI en user | No | `app_sessions` |
| Auditoría | Implícita | Mínima | Completa (IP, UA, last_active) |
| Admin controla | Roles/privilegios | Clientes activos | Apps + módulos permitidos |

---

## 11. Plan de implementación por fases

### Fase 1 — Core (estimado: 2-3 días BE + 1 día FE)

```
BE:
  [ ] Migración: registered_apps
  [ ] Migración: app_sessions
  [ ] Modelo RegisteredApp (generate_secret!, authenticate_secret)
  [ ] Modelo AppSession
  [ ] AppAuth::SessionsController (login, logout, me)
  [ ] AppAuth::BaseController (authenticate_app_request!, check_module_access!)
  [ ] RegisteredAppsController (CRUD admin)
  [ ] AppSessionsController (index, destroy)
  [ ] Rutas en config/routes/app_auth.rb
  [ ] Rutas en config/routes/administration.rb
  [ ] Serializers: RegisteredAppSerializer, AppSessionSerializer
  [ ] CORS: aceptar * o whitelist de URLs registradas

FE (Kumi Admin):
  [ ] registered-apps.service.js
  [ ] RegisteredAppsPage.vue (tabla + dialog alta/edición)
  [ ] AppSessionsDrawer.vue (sesiones activas por app)
  [ ] Agregar ruta en routes.js
  [ ] Agregar al sidebar en MainLayout.vue
```

### Fase 2 — Permisos por usuario (estimado: 1-2 días)

```
  [ ] Migración: app_user_privileges
  [ ] Modelo AppUserPrivilege
  [ ] Endpoint para asignar privilegios por usuario dentro de una app
  [ ] FE: panel de gestión de privilegios por usuario
```

### Fase 3 — Observabilidad (estimado: 1 día)

```
  [ ] Dashboard de uso por app (requests/día, usuarios únicos, módulos más usados)
  [ ] Rate limiting por app_key
  [ ] Alertas cuando una app supera X requests/hora
```

---

## 12. Seguridad

| Consideración | Implementación |
| --- | --- |
| `app_secret` nunca en texto plano en DB | BCrypt digest |
| `app_secret` nunca en logs | Filtrar en `config/initializers/filter_parameter_logging.rb` |
| JWT con `scope: "app"` | Evita que tokens de app funcionen en endpoints de Kumi Admin |
| Sesiones revocables | `jti` en `app_sessions` — el token puede invalidarse antes de expirar |
| Módulos como whitelist | El BE valida `allowed_modules` en cada request, no solo al login |
| CORS | Solo el dominio de la app registrada puede hacer requests (header `Origin`) |
| Expiración corta | JWT de app expira en 8h; refresh token para extender sin re-login |

---

## 13. Resumen ejecutivo

| Elemento | Detalle |
| --- | --- |
| Tablas nuevas | `registered_apps`, `app_sessions`, `app_user_privileges` (fase 2) |
| Tablas existentes modificadas | Ninguna — todo es aditivo |
| Endpoints nuevos | `/api/v1/app_auth/*`, `/api/v1/registered_apps/*` |
| Páginas FE nuevas | `RegisteredAppsPage.vue` en Kumi Admin |
| Impacto en apps actuales | Cero — `auth` y `client_auth` no se tocan |
| Impacto en apis actuales | Cero — `api_users`/`api_keys` no se tocan |
| Nueva PWA solo necesita | `APP_KEY` + `APP_SECRET` en `.env` + llamar a `/app_auth/login` |

---

*Propuesta generada el 2026-04-10. Pendiente de revisión y aprobación antes de comenzar implementación.*
