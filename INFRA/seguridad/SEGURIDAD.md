# Seguridad — Kumi TTPN Admin

Inventario completo de todas las capas de seguridad implementadas en el proyecto.
Última actualización: 2026-04-29

---

## Estado General

| Capa | Estado | Archivo |
| --- | --- | --- |
| **CORS — Origins explícitos + env var** | ✅ Implementado | `ttpngas/config/initializers/cors.rb` |
| **CORS — Bloque separado para webhooks** | ✅ Implementado | `ttpngas/config/initializers/cors.rb` |
| **CORS — ActionCable WebSocket** | ✅ Implementado | `ttpngas/config/application.rb` |
| **Security Headers Rails** | ✅ Implementado | `ttpngas/config/initializers/security_headers.rb` |
| **Permissions-Policy Rails** | ✅ Implementado | `ttpngas/config/initializers/permissions_policy.rb` |
| **HSTS (force_ssl + preload)** | ✅ Implementado | `ttpngas/config/environments/production.rb` |
| **CSP (API-only — intencionalmente omitido)** | ✅ Documentado | `ttpngas/config/initializers/content_security_policy.rb` |
| **Security Headers + CSP Frontend (Netlify)** | ✅ Implementado | `ttpn-frontend/public/_headers` |
| **Rate Limiting (rack-attack)** | ✅ Implementado | `ttpngas/config/initializers/rack_attack.rb` |
| **Request Timeout (rack-timeout)** | ✅ Implementado | `ttpngas/config/initializers/rack_timeout.rb` |
| **Autenticación JWT + JTI revocation** | ✅ Implementado | `ttpngas/app/controllers/api/v1/base_controller.rb` |
| **Devise Lockable (account lockout)** | ✅ Implementado | `ttpngas/config/initializers/devise.rb` + model |
| **API Keys M2M con scopes y expiración** | ✅ Implementado | `ttpngas/app/models/api_key.rb` |
| **Webhooks HMAC (WhatsApp + genérico)** | ✅ Implementado | `ttpngas/app/controllers/api/v1/webhooks_controller.rb` |
| **SQL Injection — queries parametrizadas** | ✅ Auditado (sin vulnerabilidades) | Todos los controllers |
| **Command Injection — args como Array** | ✅ Corregido | `backfill_clvs`, `EjecutarScriptPythonJob` |
| **IDOR — scopes de Business Unit** | ✅ Corregido | `vehicle_checks`, `employee_appointments`, `employee_vacations`, `employee_deductions` |
| **Whitelist de parámetros** | ✅ Implementado | Todos los controllers |
| **filter_parameter_logging ampliado** | ✅ Implementado | `ttpngas/config/initializers/filter_parameter_logging.rb` |
| **Gem CVE scanning (bundler-audit)** | ✅ Agregado | `Gemfile` (dev/test) |
| **Pre-commit hook anti-secrets** | ✅ Instalado | `.githooks/pre-commit` |
| **Business Unit isolation (filtro datos)** | ✅ Implementado | `BaseController#set_business_unit_id` |
| **RLS — SQL listo para ejecutar** | ⏳ Pendiente ejecución en Supabase | `Documentacion/INFRA/seguridad/rls_policies.sql` |

---

## 1. CORS

### Backend (`ttpngas/config/initializers/cors.rb`)

**Origins de la API principal:**

- `FRONTEND_URL` (env var obligatoria en producción, default: `https://kumi.ttpn.com.mx`)
- `https://ttpn.com.mx` (hardcodeado como dominio corporativo)
- `FRONTEND_URL_EXTRA` (lista separada por comas para apps adicionales: portales, móvil)
- En non-production: `localhost:9000`, `localhost:9200`, `localhost:8080`, `*.devtunnels.ms`, `*.netlify.app`

Headers expuestos: `Content-Disposition`, `Authorization` (necesario para que el FE lea el JWT del header de respuesta).

**Bloque webhooks (bloque separado con `origins '*'`):**

Los endpoints `/api/v1/webhooks/*` aceptan cualquier origen porque los sistemas externos (WhatsApp, GPS) no tienen un origen fijo. La verificación de integridad la hace la firma HMAC, no CORS.

**Variables requeridas en producción (Railway):**

```bash
FRONTEND_URL=https://kumi.ttpn.com.mx
# FRONTEND_URL_EXTRA=https://portal.cliente.com,https://app.movil.com  (opcional)
```

### ActionCable WebSocket (`ttpngas/config/application.rb`)

Origins permitidos explícitamente en `config.action_cable.allowed_request_origins`. Si se agrega un nuevo dominio frontend, debe agregarse también aquí.

---

## 2. Security Headers

### Rails API (`ttpngas/config/initializers/security_headers.rb`)

Aplicados en **todas** las respuestas vía `config.action_dispatch.default_headers`:

| Header | Valor configurado | Protege contra |
| --- | --- | --- |
| `X-Frame-Options` | `DENY` | Clickjacking — impide embeber la app en iframes |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing — el browser respeta el Content-Type declarado |
| `X-XSS-Protection` | `1; mode=block` | XSS en browsers legacy (IE, Chrome < 78) |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Fuga de URL completa en header Referer cross-origin |
| `Permissions-Policy` | ver abajo | Acceso no autorizado a periféricos del dispositivo |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Downgrade HTTPS — configurado en `production.rb` vía `force_ssl` |

**Permissions-Policy** (`ttpngas/config/initializers/permissions_policy.rb`):

```text
camera=()  microphone=()  geolocation=()  usb=()  gyroscope=()  payment=()
fullscreen=(self)
```

**CSP**: Intencionalmente no configurado en la API. Solo aplica en respuestas HTML — este proyecto devuelve únicamente JSON. Ver `content_security_policy.rb` para la explicación documentada.

### Frontend — Netlify (`ttpn-frontend/public/_headers`)

Aplica a todas las rutas (`/*`). Incluye todos los headers del API más:

| Header | Valor clave | Protege contra |
| --- | --- | --- |
| `Content-Security-Policy` | ver abajo | XSS, inyección de recursos externos |
| `frame-ancestors 'none'` | (en CSP) | Clickjacking en browsers modernos |
| `object-src 'none'` | (en CSP) | Plugins Flash/Java |
| `base-uri 'self'` | (en CSP) | Inyección de tag `<base>` |

**CSP Frontend (directivas activas):**

```text
default-src 'self'
script-src  'self'
style-src   'self' 'unsafe-inline'
img-src     'self' data: blob: https:
font-src    'self' data:
connect-src 'self'
            https://kumi-admin-api-production.up.railway.app
            wss://kumi-admin-api-production.up.railway.app
            https://kumi.ttpn.com.mx
            wss://kumi.ttpn.com.mx
frame-ancestors 'none'
object-src  'none'
base-uri    'self'
```

> `script-src`: `'unsafe-inline'` y `'unsafe-eval'` eliminados (2026-04-29). Vue 3 + Vite pre-compila templates — no usa `eval()` en producción y no inyecta scripts inline.
> `style-src`: `'unsafe-inline'` se mantiene — requerido por los `:style` bindings dinámicos de Quasar (drawer widths, dialog positioning, temas).

**Si cambias el dominio de la API en Railway**, actualizar `connect-src` en `_headers`.

---

## 3. Rate Limiting (`rack-attack`)

Archivo: `ttpngas/config/initializers/rack_attack.rb`
Backend: Redis (mismo `REDIS_URL` de Sidekiq, namespace `rack_attack`, DB 1).

### Throttles

| Nombre | Ruta / Condición | Límite | Período | Discriminador |
| --- | --- | --- | --- | --- |
| Login interno | `POST /auth/login` | 5 req | 20 s | IP |
| Login portal clientes | `POST /client_auth/login` | 5 req | 20 s | IP |
| Login Devise legacy | `POST /users/sign_in` | 5 req | 20 s | IP |
| API general | `/api/`, `/auth/`, `/client_auth/` | 300 req | 5 min | IP |
| API autenticada | Cualquier ruta con header `Authorization` | 600 req | 5 min | Token (JWT o API Key) |

### Blocklist automático

Si una IP supera **20 intentos** en cualquier endpoint de login en un período de **5 minutos**, queda bloqueada durante **1 hora** (via `Rack::Attack::Allow2Ban`).

### Safelists

- `/health` y `/up` — nunca throttlear (health check del load balancer)
- `127.0.0.1` y `::1` — localhost (desarrollo y tests)

### Respuesta al throttlear

```text
HTTP 429 Too Many Requests
Content-Type: application/json
Retry-After: <segundos hasta reset>

{ "error": "Too many requests. Retry after N seconds." }
```

Blocklist responde con `"Too many failed login attempts. Try again in 1 hour."`.

### Tests

`spec/support/rack_attack.rb` reemplaza el cache por `MemoryStore` y llama `Rack::Attack.reset!` antes de cada ejemplo para aislar el estado (sin dependencia de Redis en tests).

---

## 4. Command Injection — Corregido (2026-04-29)

### Vulnerabilidades encontradas y corregidas

**`ttpn_bookings_controller.rb#backfill_clvs`**

```ruby
# ❌ Antes — params[:days] sin validar dentro de string de shell
system("DAYS=#{days} bin/rails cuadre:backfill_ttpn_bookings")

# ✅ Después — ENV hash + args como array, sin shell expansion
days = params[:days].to_i.clamp(1, 365)
system({ 'DAYS' => days.to_s }, 'bin/rails', 'cuadre:backfill_ttpn_bookings')
```

**`EjecutarScriptPythonJob#build_command`**

```ruby
# ❌ Antes — string pasado como argumento único a Open3.capture3 (pasa por shell)
"#{PYTHON_BIN} #{script_path} #{args.join(' ')}"
Open3.capture3({ 'PYTHONPATH' => SCRIPTS_ROOT }, cmd)

# ✅ Después — array de args + validación de path traversal
[PYTHON_BIN, script_path] + args   # sin shell
Open3.capture3({ 'PYTHONPATH' => SCRIPTS_ROOT }, *cmd)
```

Además se añadió `safe_script_path!` que verifica que el script esté dentro de `scripts/` (previene path traversal).

---

## 5. IDOR — Insecure Direct Object Reference (Corregido 2026-04-29)

Los `set_` privados que hacían `Model.find(params[:id])` sin scope de Business Unit permiten que un usuario autenticado de la BU 1 acceda a registros de la BU 2 adivinando el ID numérico.

**Correcciones aplicadas:**

| Controller | Método corregido | Scope aplicado |
| --- | --- | --- |
| `vehicle_checks_controller.rb` | `set_vehicle_check` + `index` | `joins(:vehicle).where(vehicles: { business_unit_id: })` |
| `employee_appointments_controller.rb` | `set_appointment` | `where(business_unit_id: @business_unit_id)` |
| `employee_vacations_controller.rb` | `set_employee_vacation` | `joins(:employee).where(employees: { business_unit_id: })` |
| `employee_deductions_controller.rb` | `by_employee` + `index` | `Employee.where(business_unit_id: @business_unit_id)` |

**Patrón estándar para nuevos `set_` en controllers con datos operativos:**

```ruby
def set_recurso
  scope = Recurso
  scope = scope.where(business_unit_id: @business_unit_id) if @business_unit_id
  @recurso = scope.find(params[:id])
rescue ActiveRecord::RecordNotFound
  render json: { error: ERR_NOT_FOUND }, status: :not_found
end
```

Si el modelo no tiene `business_unit_id` directo pero pertenece a `Employee` o `Vehicle`:

```ruby
scope = scope.joins(:employee).where(employees: { business_unit_id: @business_unit_id }) if @business_unit_id
```

SuperAdmin (`@business_unit_id = nil`) no tiene scope → ve todos los registros. Esto es intencional.

---

## 6. Autenticación

### JWT (usuarios internos y portal clientes)

Implementado en `ttpngas/app/controllers/api/v1/base_controller.rb`.

**Flujo de autenticación por request:**

1. Leer header `Authorization: Bearer <token>`
2. Decodificar JWT con `HS256` y `SECRET_KEY_BASE`
3. Buscar usuario por `decoded['user_id']`
4. Verificar `decoded['jti'] == user.jti` — **protección contra tokens revocados**
5. Establecer `Current.user = user` para el request

**JTI Revocation:** cada usuario tiene un campo `jti` único en BD. Al hacer logout se rota el `jti` → todos los tokens anteriores dejan de ser válidos aunque no hayan expirado. Sin necesidad de lista negra.

**Errores que devuelve:**

| Error | Código | Mensaje |
| --- | --- | --- |
| Sin token o formato incorrecto | 401 | `"Sesión expirada o inválida"` |
| Token expirado | 401 | `"Token expirado"` |
| Token mal firmado | 401 | `"Token inválido"` |
| JTI revocado | 401 | `"Token revocado"` |
| Usuario no existe | 401 | `"Usuario no encontrado"` |

### API Keys M2M (machine-to-machine)

Modelo: `ttpngas/app/models/api_key.rb`

Para conexiones entre aplicaciones (N8N → Rails, scripts Python, portales externos). Si el `Bearer` token no decodifica como JWT válido, se intenta como API Key.

**Características:**

- Scopes por recurso con permisos granulares (`can_read`, `can_create`, `can_edit`, `can_delete`, `can_export`)
- Fecha de expiración opcional (`expires_at`)
- `active` flag para desactivación inmediata sin borrar
- Registro de `last_used_at` y contador `requests_count` por key
- Asociada a `ApiUser` con `business_unit_id` propio
- Hashing seguro del token (nunca se guarda en claro después de la creación)

**Rotación:** semestral obligatoria. Panel Admin → API Keys.

---

## 7. Webhooks HMAC

Archivo: `ttpngas/app/controllers/api/v1/webhooks_controller.rb`

Los endpoints de webhooks **no llevan JWT** (`skip_before_action :authenticate_request!`). La verificación de integridad se hace por firma criptográfica:

### WhatsApp Business Cloud API

```text
Header verificado: X-Hub-Signature-256
Algoritmo: HMAC-SHA256
Secret: ENV['WHATSAPP_WEBHOOK_SECRET']
Comparación: ActiveSupport::SecurityUtils.secure_compare (timing-safe)
```

Formato esperado: `sha256=<hexdigest>`.

Regla: siempre responder `200 OK` inmediatamente. El procesamiento va en `WhatsappEventJob` (Sidekiq).

### Webhook genérico (pruebas / sistemas internos)

```text
Header verificado: X-Webhook-Token
Secret: ENV['WEBHOOK_SECRET_GENERIC']
Comparación: ActiveSupport::SecurityUtils.secure_compare (timing-safe)
```

### Variables de entorno requeridas

```bash
WHATSAPP_WEBHOOK_SECRET=<secret configurado en Meta Developer Console>
WHATSAPP_VERIFY_TOKEN=<token de verificación inicial>
WEBHOOK_SECRET_GENERIC=<openssl rand -hex 32>
```

---

## 8. SQL Injection

**Auditoría realizada:** 2026-04-29. Alcance: todos los archivos con `.where`, `.joins`, `.find_by`, `.order`, `ILIKE` en `ttpngas/app/`.

**Resultado: sin vulnerabilidades encontradas.**

Todas las queries con valores de usuario usan placeholder `?` (forma de array):

```ruby
# ✅ Correcto — binding paramétrico
where("nombre ILIKE ?", "%#{term}%")
where("CONCAT(nombre, ' ', apaterno) ILIKE ?", "%#{term}%")
where("fecha >= ? AND fecha <= ?", from, to)

# ❌ Vulnerable — interpolación directa (NO existe en el codebase)
where("nombre ILIKE '%#{term}%'")
```

No se encontró interpolación `#{}` dentro de strings de SQL ni `.order()` controlado por input de usuario.

**Patrón obligatorio si se agrega ordenamiento dinámico en el futuro:**

```ruby
SORTABLE_COLUMNS = %w[nombre created_at updated_at].freeze
col   = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
dir   = params[:sort_dir] == 'asc' ? 'ASC' : 'DESC'
scope.order(Arel.sql("#{col} #{dir}"))
```

---

## 9. Whitelist de Parámetros

**Regla:** `params.permit!` está prohibido. Todos los controllers usan whitelist explícita.

```ruby
# ✅ Obligatorio — whitelist explícita
def employee_params
  params.require(:employee).permit(:nombre, :apaterno, :email, :status)
end

# ❌ Prohibido — nunca en ningún controller
params.permit!
```

Verificado por RuboCop (`Rails/ParamPermit`). Si se detecta `permit!`, es bloqueante antes de merge.

`business_unit_id`, `created_by_id` y `updated_by_id` **nunca** van en `permit()` — se asignan server-side desde `Current.business_unit` / `current_user.id`.

---

## 10. Business Unit Isolation (filtro de datos)

**Capa de seguridad a nivel de aplicación** (complementaria a RLS a nivel de BD).

`BaseController#set_business_unit_id` establece `@business_unit_id` antes de cada request:

- **SuperAdmin / Sistemas:** puede ver todas las BUs o filtrar por `params[:business_unit_id]`
- **Usuario normal:** siempre amarra a su propia `business_unit_id`
- **API Key:** usa la `business_unit_id` del `ApiUser` asociado

Todos los controllers que devuelven datos operativos deben aplicar el filtro:

```ruby
# Con scope (preferido):
Employee.business_unit_filter  # el scope lee @business_unit_id del contexto

# Sin scope:
scope = scope.where(business_unit_id: @business_unit_id) if @business_unit_id
```

Un `nil` en `@business_unit_id` significa SuperAdmin viendo todo — es intencional.

---

## 11. RLS — Row Level Security (PENDIENTE EJECUCIÓN EN SUPABASE)

### Estado

El SQL está listo en `Documentacion/INFRA/seguridad/rls_policies.sql`. **Aún no se ha ejecutado en Supabase.**

### Arquitectura de roles

| Conexión | Usuario BD | `BYPASSRLS` | Afectado por RLS |
| --- | --- | --- | --- |
| Rails API (producción) | `service_role` vía `DATABASE_URL` | ✅ Sí | No — el ORM filtra por BU |
| Python scripts (`db.py`) | `service_role` vía `DATABASE_URL` (misma var que Rails) | ✅ Sí | No — acceso total igual que Rails |
| Android / PHP (pruebas) | `postgres` vía pooler :6543 | ✅ Sí | No — superusuario |
| N8N | N/A — llama Rails API vía HTTP + API Key | N/A | No aplica — Rails filtra por BU |

### Transaction Pooler (puerto 6543) y SET LOCAL

El puerto 6543 es el Transaction Pooler de Supabase (pgbouncer en modo transacción). `SET LOCAL` solo vive dentro de la transacción actual.

**Patrón obligatorio para Python con el pooler:**

```sql
BEGIN;
SELECT set_config('app.current_business_unit_id', '2', true);
SELECT * FROM employees;  -- ve solo empleados de la BU 2
COMMIT;
```

Si se olvida establecer la BU: `app_user` recibe **0 filas** (falla segura — la policy `USING (business_unit_id = NULL::int)` nunca evalúa a `TRUE`).

### Tablas cubiertas (34 tablas)

```text
alert_contacts, alert_rules, alerts, api_users,
business_units_concessionaires, client_employees, client_users,
clients, coo_travel_employee_requests, coo_travel_requests,
discrepancies, driver_requests, employee_appointment_logs,
employee_appointments, employees, employees_incidences,
gas_charges, gas_files, gas_stations, gasoline_charges,
incidences, invoicings, kumi_settings, labors, payrolls,
roles, scheduled_maintenances, service_appointments, suppliers,
travel_counts, ttpn_bookings, users, vehicle_asignations, vehicles
```

### Tablas sin RLS (catálogos compartidos entre BUs)

```text
vehicle_types, employee_document_types, vehicle_document_types,
ttpn_service_types, ttpn_services, concessionaires,
privileges, role_privileges, versions (PaperTrail)
```

### Cómo ejecutar el SQL

1. Supabase Dashboard → SQL Editor
2. Abrir `Documentacion/INFRA/seguridad/rls_policies.sql`
3. Reemplazar `CAMBIAR_EN_PRODUCCION` con password seguro para `app_user`
4. Ejecutar el script completo
5. Verificar con la query final del script que todas las tablas tienen `rls_enabled = true`

---

## 12. Devise Lockable — Account Lockout

Habilitado en `ttpngas/app/models/user.rb` y configurado en `ttpngas/config/initializers/devise.rb`.

| Config | Valor |
| --- | --- |
| `lock_strategy` | `:failed_attempts` |
| `unlock_strategy` | `:time` (auto-desbloqueo, sin depender de email) |
| `maximum_attempts` | 10 intentos fallidos |
| `unlock_in` | 1 hora |

Integrado en el JWT sessions controller (el login JWT no pasa por Warden, se hace manualmente):

1. Si la cuenta está bloqueada → devuelve `ERR_CREDENTIALS` (mismo error que credenciales incorrectas, no revela el bloqueo)
2. Si la contraseña es incorrecta → incrementa `failed_attempts` y bloquea si supera el límite
3. Si el login es exitoso → llama `reset_failed_attempts!`

**Migración requerida:**

```bash
bundle exec rails db:migrate
# Agrega: failed_attempts (int), unlock_token (string), locked_at (datetime)
```

---

## 13. Request Timeout (rack-timeout)

Archivo: `ttpngas/config/initializers/rack_timeout.rb`

Solo activo en `Rails.env.production?`. En desarrollo no aplica para no interrumpir debugging.

| Variable env | Default | Descripción |
| --- | --- | --- |
| `RACK_TIMEOUT` | `25s` | Tiempo máximo de servicio de la request |
| `RACK_WAIT_TIMEOUT` | `30s` | Tiempo máximo en cola antes de empezar a servir |

El load balancer de Railway tiene 60s de timeout. Usamos 25s para que la app devuelva un 503 controlado antes de que el LB devuelva 504.

---

## 14. Gem Security Scanning (bundler-audit)

`bundler-audit` está en el Gemfile (grupo development/test). Escanea el `Gemfile.lock` contra la base de datos de CVEs de Ruby Advisory Database.

```bash
# Actualizar base de datos de CVEs
bundle exec bundler-audit update

# Escanear (en CI o antes de cada deploy)
bundle exec bundler-audit check

# Si hay vulnerabilidades: actualizar la gem afectada
bundle update <gem_name>
```

**Recomendación:** agregar `bundle exec bundler-audit check` como step en el pipeline de CI antes del deploy.

---

## 15. Pre-commit Hook — Detección de Secrets

Archivo: `.githooks/pre-commit` (monorepo root)  
Estado: **instalado** (`git config core.hooksPath .githooks` ejecutado)

Patrones detectados antes de cada `git commit`:

- AWS Access Key IDs (`AKIA...`)
- Claves privadas PEM
- Tokens Railway/Heroku en variables de entorno
- Valores reales en variables críticas (SECRET_KEY_BASE, DEVISE_JWT_SECRET_KEY, N8N_ENCRYPTION_KEY)

Si hay un falso positivo confirmado: `git commit --no-verify` (usar con criterio).

**Para nuevos desarrolladores que clonen el repo:**

```bash
git config core.hooksPath .githooks
```

---

## 16. Checklist de Verificación en Producción

```bash
# ── Headers de la API ──────────────────────────────────────────────────────
curl -I https://kumi-admin-api-production.up.railway.app/api/v1/health
# Buscar: X-Frame-Options: DENY | X-Content-Type-Options: nosniff
#         Strict-Transport-Security | Permissions-Policy | Referrer-Policy

# ── Headers del Frontend ───────────────────────────────────────────────────
curl -I https://kumi.ttpn.com.mx
# Buscar: Content-Security-Policy | X-Frame-Options | Strict-Transport-Security

# ── CORS — rechazar origen no autorizado ───────────────────────────────────
curl -s -o /dev/null -w "%{http_code}" \
     -H "Origin: https://sitio-malicioso.com" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://kumi-admin-api-production.up.railway.app/api/v1/health
# Debe NO incluir Access-Control-Allow-Origin en la respuesta

# ── Rate Limiting — verificar que 429 funciona ────────────────────────────
for i in {1..7}; do
  curl -s -o /dev/null -w "intento $i: %{http_code}\n" \
    -X POST https://kumi-admin-api-production.up.railway.app/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"wrong"}'
done
# Los primeros 5 deben ser 401, el 6 y 7 deben ser 429

# ── HSTS — verificar preload ───────────────────────────────────────────────
curl -I https://kumi-admin-api-production.up.railway.app | grep -i strict
# Debe incluir: max-age=31536000; includeSubDomains; preload
```

**Herramientas online:**

- Headers: [securityheaders.com](https://securityheaders.com)
- CSP: [csp-evaluator.withgoogle.com](https://csp-evaluator.withgoogle.com)
- SSL: [ssllabs.com/ssltest](https://www.ssllabs.com/ssltest/)

---

## 11. Pendientes

- [ ] **RLS**: Ejecutar `rls_policies.sql` en Supabase (dev y prod)
- [x] **Railway**: ~~Eliminar variable `APP_USER_DATABASE_URL`~~ — eliminada (2026-04-29)
- [x] **CSP Frontend**: `'unsafe-inline'` y `'unsafe-eval'` eliminados de `script-src` (2026-04-29) — `style-src` mantiene `'unsafe-inline'` por requerimiento de Quasar
- [x] **FRONTEND_URL**: Confirmada en Railway — `FRONTEND_URL=https://kumi.ttpn.com.mx` (2026-04-29)
- [x] **ActionCable**: `kumi.ttpn.com.mx` confirmado en `allowed_request_origins` de `application.rb` (2026-04-29)
- [ ] **API Keys**: Establecer proceso formal de rotación semestral (recordatorio en calendario)
- [ ] **Webhooks AWS credentials**: Las credenciales AWS que aparecían en `RAILWAY_STAGING_DEPLOYMENT_GUIDE.md` y `railway_deployment.md` fueron redactadas (2026-04-29). Rotar en AWS IAM si aún no se ha hecho.
