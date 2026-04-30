# ADR-008: Hardening de Seguridad — rack-attack, Lockable y CSP

**Fecha:** 2026-04-29  
**Estado:** Implementado  
**Responsable:** Antonio Castellanos

---

## Contexto

Durante una auditoría de seguridad completa (2026-04-29) se identificaron vulnerabilidades reales y áreas de mejora en el sistema. Los problemas concretos encontrados:

1. **Sin rate limiting** — un atacante podía hacer fuerza bruta al login sin ningún límite
2. **Sin lockout de cuenta** — no había protección contra intentos de login continuos por usuario
3. **Command injection** en `TtpnBookingsController#backfill_clvs` (interpolación directa de `params[:days]` en shell)
4. **Command injection + path traversal** en `EjecutarScriptPythonJob` (string pasado como comando a shell)
5. **IDOR** en 4 controllers que hacían `Model.find(params[:id])` sin scope de BU
6. **CSP permisiva** en el frontend (`script-src 'unsafe-inline' 'unsafe-eval'` innecesarios)
7. **Credenciales expuestas** en git history (`RAILWAY_STAGING_DEPLOYMENT_GUIDE.md` tenía password real de Supabase y AWS keys)
8. **Sin detección de secretos** pre-commit

---

## Alternativas consideradas

### Rate limiting

| Opción | Pros | Contras |
| --- | --- | --- |
| `rack-attack` (elegida) | Estándar Rails, Redis backend, flexible, safelists | Requiere Redis (ya disponible) |
| `throttle` en NGINX | Transparente a Rails | No tenemos NGINX (Railway) |
| Cloudflare WAF | Potente, sin config en Rails | Costo adicional, overhead |

### Account lockout

| Opción | Pros | Contras |
| --- | --- | --- |
| Devise Lockable (elegida, manual) | Nativo a Devise, sin deps extra | Lockable no se integra automáticamente con JWT — requiere implementación manual en SessionsController |
| Redis counter custom | Simple | Duplica lógica que Devise ya tiene |

### CSP

| Opción | Pros | Contras |
| --- | --- | --- |
| Eliminar `unsafe-inline` y `unsafe-eval` de `script-src` (elegida) | Protege contra XSS real | Requiere verificar que Vue 3 + Vite no los necesita |
| Mantener el CSP permisivo | Sin trabajo | Cualquier XSS inyectado puede ejecutar código arbitrario |

---

## Decisiones tomadas

### 1. Rate limiting — rack-attack

`gem 'rack-attack'` con Redis como backend:

| Throttle | Límite | Período | Discriminador |
| --- | --- | --- | --- |
| Login (`/sign_in`) | 5 req | 20 seg | IP |
| API general | 300 req | 5 min | IP |
| API autenticada | 600 req | 5 min | Token |
| Blocklist brute force | >20 intentos | — | IP bloqueada 1h |

Safelists: `/health`, `/up`, `127.0.0.1`, `::1`.

### 2. Devise Lockable (implementación manual)

Lockable no funciona con JWT porque Warden callbacks no se disparan en la autenticación JWT. Se implementó manualmente en `sessions_controller.rb`:

- 10 intentos fallidos → cuenta bloqueada 1 hora
- Campos nuevos en `users`: `failed_attempts`, `locked_at`, `unlock_token`
- Migración: `20260429000001_add_lockable_to_users.rb`
- Respuesta: `423 Locked` con tiempo restante en segundos

### 3. CSP Frontend

Vue 3 + Vite pre-compila todos los templates en tiempo de build — no usa `eval()` en producción y no inyecta scripts inline en el HTML. Por tanto:

- `'unsafe-eval'` eliminado de `script-src` (Vue 3 no lo necesita)
- `'unsafe-inline'` eliminado de `script-src` (Vite bundlea todo en `.js` externos)
- `'unsafe-inline'` **mantenido** en `style-src` — Quasar usa `:style` bindings dinámicos

Resultado en `ttpn-frontend/public/_headers`:
```text
script-src 'self'
style-src 'self' 'unsafe-inline'
```

### 4. Command injection — Array form

Todo comando de sistema ahora usa Array form, no interpolación de string:

```ruby
# Antes (inyectable):
system("bin/rails task DAYS=#{params[:days]}")

# Después (seguro):
days = params[:days].to_i.clamp(1, 365)
system({ 'DAYS' => days.to_s }, 'bin/rails', 'task')
```

Para scripts Python (`Open3`): `capture3(*array)` en lugar de `capture3(string)`.

### 5. IDOR — scope de BU en find

Patrón aplicado en todos los controllers:

```ruby
@record = Model.where(business_unit_id: @business_unit_id).find(params[:id])
```

Para modelos con BU indirecta (a través de relación):

```ruby
@record = Model.joins(:parent).where(parents: { business_unit_id: @business_unit_id }).find(params[:id])
```

### 6. Pre-commit hook

`.githooks/pre-commit` versiona en el monorepo y detecta:

- AWS Access Keys (`AKIA[0-9A-Z]{16}`)
- Claves PEM (`BEGIN RSA PRIVATE KEY`)
- Tokens Railway (`railway_token_`)
- Valores reales en `SECRET_KEY_BASE`, `DEVISE_JWT_SECRET_KEY`, `N8N_ENCRYPTION_KEY`

Activar: `git config core.hooksPath .githooks`

### 7. bundler-audit

`gem 'bundler-audit', require: false` en grupo dev/test. Escanea el `Gemfile.lock` contra la base de datos de CVEs conocidos de RubyGems.

Pendiente: integrar `bundle exec bundler-audit check` en el pipeline de CI (`.gitlab-ci.yml`).

---

## Consecuencias

### Positivas
- Eliminadas 4 clases de vulnerabilidades reales (IDOR, command injection, brute force, XSS via CSP)
- Rate limiting previene ataques automatizados sin afectar uso normal
- Pre-commit hook previene que vuelvan a exponerse credenciales en git
- CSP endurecida sin romper ninguna funcionalidad

### A tener en cuenta
- Rotating `SECRET_KEY_BASE` o `DEVISE_JWT_SECRET_KEY` invalida sesiones activas — todos los usuarios deben volver a hacer login
- Lockable: si un admin queda bloqueado, debe esperar 1 hora o ser desbloqueado por sadmin desde el panel
- rack-attack en tests usa `MemoryStore` — resetear con `Rack::Attack.reset!` en `before(:each)` para evitar interferencias entre specs

---

## Archivos creados/modificados

| Archivo | Cambio |
| --- | --- |
| `Gemfile` | `rack-attack`, `rack-timeout`, `bundler-audit` |
| `config/initializers/rack_attack.rb` | Throttles, safelists, blocklist, respuesta 429 |
| `config/environments/production.rb` | Redis como cache store |
| `config/application.rb` | Middleware `Rack::Attack` + filter_parameters extendido |
| `db/migrate/20260429000001_add_lockable_to_users.rb` | Campos Lockable en users |
| `app/models/user.rb` | `:lockable` en devise declaration |
| `config/initializers/devise.rb` | Configuración Lockable |
| `app/controllers/api/v1/auth/sessions_controller.rb` | Lógica manual de lockout |
| `app/controllers/api/v1/ttpn_bookings_controller.rb` | Fix command injection en backfill |
| `app/jobs/ejecutar_script_python_job.rb` | Fix command injection + path traversal |
| `app/controllers/api/v1/vehicle_checks_controller.rb` | Fix IDOR |
| `app/controllers/api/v1/employee_appointments_controller.rb` | Fix IDOR |
| `app/controllers/api/v1/employee_vacations_controller.rb` | Fix IDOR |
| `app/controllers/api/v1/employee_deductions_controller.rb` | Fix IDOR |
| `ttpn-frontend/public/_headers` | CSP: eliminar unsafe-inline/eval de script-src |
| `ttpn-frontend/quasar.config.js` | globIgnores: excluir `_headers` del precache Workbox |
| `spec/support/rack_attack.rb` | MemoryStore + reset en tests |
| `.githooks/pre-commit` | Detección de secrets pre-commit |
