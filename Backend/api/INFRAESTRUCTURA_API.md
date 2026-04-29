# Infraestructura API — Kumi como Base de Datos Maestra

**Fecha:** 2026-04-25  
**Aplica a:** Todo sistema externo que se conecte a la BD o API de Kumi TTPN Admin

---

## Concepto: Kumi como Master Hub

Kumi TTPN Admin es la **fuente de verdad** para clientes, proveedores, empleados y vehículos. Sistemas satélite (portal de clientes, portal de proveedores, software de mantenimiento, app móvil de choferes) **no gestionan sus propios catálogos** — los consumen de Kumi vía API.

```
┌─────────────────────────────────────────────────────────┐
│                    PostgreSQL (Supabase)                 │
│                                                         │
│  clients / employees / vehicles / users                 │
│  client_users / supplier_users / api_keys               │
└────────────────────────┬────────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              │   Kumi Rails API    │  ← fuente de verdad
              └──┬──────┬──────┬───┘
                 │      │      │
         ┌───────┘  ┌───┘  ┌───┘
         ▼          ▼      ▼
   Portal       Portal   Software
   Clientes   Proveedores Mantenimiento
  (client_    (supplier_  (api_key con
   users)      users)     scope limitado)
```

---

## Autenticación de Sistemas Externos — API Keys

### Cuándo usar API Key vs JWT de usuario

| Caso | Mecanismo |
|---|---|
| Usuario humano (admin, coordinador) | JWT vía Devise (`/api/v1/auth/sign_in`) |
| Portal de clientes (client_users) | JWT propio del portal + API Key del sistema |
| Portal de proveedores (supplier_users) | JWT propio del portal + API Key del sistema |
| Sistema a sistema (sin usuario) | API Key con scope |
| App móvil choferes | JWT de employee (ADR-003) |

### Modelo `ApiKey`

```ruby
# app/models/api_key.rb
# Campos: token (hashed), name, scope (array), system_name, expires_at,
#         active, last_used_at, created_by_id
```

**Scopes disponibles:**

| Scope | Acceso |
|---|---|
| `read:clients` | GET /api/v1/clients, /api/v1/client_branch_offices |
| `read:employees` | GET /api/v1/employees (sin datos sensibles) |
| `read:vehicles` | GET /api/v1/vehicles |
| `write:bookings` | POST /api/v1/ttpn_bookings |
| `manage:client_users` | CRUD /api/v1/client_users |
| `manage:supplier_users` | CRUD /api/v1/supplier_users |
| `full` | Solo para sistemas internos Kumi |

### Autenticación en el Controller

```ruby
# app/controllers/api/v1/base_controller.rb

before_action :authenticate_request!

private

def authenticate_request!
  if request.headers['X-API-Key'].present?
    authenticate_with_api_key!
  else
    authenticate_user!   # JWT normal de Devise
  end
end

def authenticate_with_api_key!
  key = ApiKey.active.find_by_token(request.headers['X-API-Key'])
  return render_unauthorized unless key&.valid_for?(required_scope)
  key.touch(:last_used_at)
  @current_api_key = key
end

def required_scope
  nil   # los controllers que requieren scope lo sobreescriben
end
```

### Uso desde sistema externo

```http
GET /api/v1/clients
X-API-Key: kumi_live_xxxxxxxxxxxxxxxxxxxx
Content-Type: application/json
```

---

## Portal de Clientes — `client_users`

### Qué es

Sistema separado (repo independiente) que permite a los clientes de TTPN:
- Ver sus viajes/bookings
- Capturar solicitudes de ruta
- Consultar facturas
- Gestionar sus contactos

### Modelo `ClientUser`

```ruby
# Campos: client_id, client_branch_office_id, email, nombre, cargo,
#         encrypted_password, jti (JWT), status, last_sign_in_at
# Asociaciones: belongs_to :client, belongs_to :client_branch_office
```

### Flujo de autenticación

```
Portal cliente → POST /api/v1/portal/auth/sign_in
               → { email, password }
               ← { token: "jwt...", client_user: { ... } }

Requests autenticados:
               → GET /api/v1/portal/bookings
               → Authorization: Bearer <jwt_client_user>
```

**Controllers del portal** heredan de `Api::V1::Portal::BaseController`:

```ruby
class Api::V1::Portal::BaseController < ApplicationController
  before_action :authenticate_client_user!
  before_action :set_client_scope

  private

  def set_client_scope
    # Todos los queries filtran automáticamente por client_id del usuario autenticado
    @client_id = current_client_user.client_id
  end
end
```

**Regla crítica:** Ningún endpoint del portal puede devolver datos de otro cliente. El filtro `client_id` es obligatorio en todo query.

---

## Portal de Proveedores — `supplier_users`

Mismo patrón que `client_users`, tabla separada `supplier_users`.

```ruby
# Campos: supplier_id, email, nombre, encrypted_password, jti, status
# Permite: ver órdenes de servicio, confirmar disponibilidad de vehículos,
#          subir facturas
```

Controllers bajo `Api::V1::SupplierPortal::BaseController` con scope automático de `supplier_id`.

---

## Software de Mantenimiento (u otros sistemas)

Sistema de mantenimiento de flotilla que necesita:
- Leer vehículos de Kumi
- Crear órdenes de mantenimiento (tabla propia)
- Actualizar status de vehículos en Kumi

### Conexión

```bash
# En el sistema de mantenimiento (.env)
KUMI_API_URL=https://api.kumi.ttpn.com.mx
KUMI_API_KEY=kumi_live_xxxxxxxxxxxx   # scope: read:vehicles, write:vehicle_status
```

```ruby
# Ejemplo de sincronización desde sistema externo
response = HTTP.headers('X-API-Key' => ENV['KUMI_API_KEY'])
               .get("#{ENV['KUMI_API_URL']}/api/v1/vehicles")
vehicles = response.parse[:data]
```

### Base de Datos Compartida (opción avanzada)

Para sistemas internos de TTPN con acceso directo a BD (sin pasar por API):

- Usar el mismo Supabase, **schema separado**: `public` (Kumi), `mantenimiento`, `portal`
- El sistema externo tiene usuario de BD con permisos limitados a su schema + SELECT en tablas de Kumi
- Nunca escritura directa en tablas de Kumi desde un sistema externo — siempre via API

```sql
-- Usuario de BD para sistema de mantenimiento
CREATE ROLE mantenimiento_app LOGIN PASSWORD '...';
GRANT USAGE ON SCHEMA public TO mantenimiento_app;
GRANT SELECT ON vehicles, employees TO mantenimiento_app;
GRANT ALL ON SCHEMA mantenimiento TO mantenimiento_app;
```

---

## Crear una API Key Nueva

```bash
# Desde Rails console en producción
key = ApiKey.create!(
  name: 'Portal Clientes v1',
  system_name: 'portal_clientes',
  scope: ['read:clients', 'manage:client_users', 'write:bookings'],
  expires_at: 6.months.from_now,
  created_by: User.find_by(email: 'admin@ttpn.com.mx')
)
puts key.raw_token   # mostrar una sola vez — el BE solo guarda el hash
```

**Rotación:** cada 6 meses o ante sospecha de compromiso. El sistema externo debe soportar rotación sin downtime (aceptar key vieja y nueva durante 24h de transición).

---

## Reglas de Integración

1. **Nunca** exponer datos de un cliente a otro — filtro por `client_id` siempre
2. **Nunca** escritura directa a BD de Kumi desde sistema externo — solo via API
3. API Keys con **scope mínimo** necesario — principio de menor privilegio
4. Todas las llamadas autenticadas se registran en `api_key_logs` (ip, endpoint, timestamp)
5. Rate limiting: 1000 req/hora por API Key (configurar en `config/initializers/rack_attack.rb`)
6. Los endpoints del portal **no son los mismos** que los de admin — namespaces separados
7. JWT de `client_users` y `supplier_users` no son válidos en endpoints de admin y viceversa
