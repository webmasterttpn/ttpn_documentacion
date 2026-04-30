# 2026-04-29 — Auditoría de Seguridad Completa y Hardening

## Resumen ejecutivo

Sesión de auditoría de seguridad completa sobre el monorepo. Se implementaron 8 capas de protección nuevas, se corrigieron vulnerabilidades reales (command injection, IDOR, brute force) y se completó la documentación de seguridad. Adicionalmente se resolvieron problemas de CSP y PWA en el frontend.

---

## 1. Rate Limiting — rack-attack

### Archivos creados / modificados

| Archivo | Cambio |
| --- | --- |
| `ttpngas/Gemfile` | `gem 'rack-attack'` en sección AUTH & LOGIC |
| `ttpngas/config/initializers/rack_attack.rb` | Inicializador nuevo |
| `ttpngas/config/environments/production.rb` | Redis como cache store (`redis_cache_store`) |
| `ttpngas/config/application.rb` | `config.middleware.use Rack::Attack` |
| `ttpngas/spec/support/rack_attack.rb` | MemoryStore + `Rack::Attack.reset!` antes de cada test |

### Throttles configurados

| Throttle | Límite | Período | Discriminador |
| --- | --- | --- | --- |
| Login interno / portal / legacy | 5 req | 20 s | IP |
| API general (`/api/`, `/auth/`, `/client_auth/`) | 300 req | 5 min | IP |
| API autenticada (header `Authorization`) | 600 req | 5 min | Token |
| Blocklist brute force | >20 intentos | 5 min | IP bloqueada 1 hora |

Safelists: `/health`, `/up`, `127.0.0.1`, `::1`.  
Respuesta: `429 Too Many Requests` + `Retry-After` + body JSON `{ "error": "..." }`.  
Backend: Redis namespace `rack_attack`. En tests: `MemoryStore`.

---

## 2. Rack Timeout — rack-timeout (fix de API)

### Problema encontrado

El initializer usaba la API de rack-timeout 0.5.x (`Rack::Timeout.timeout=`) que fue eliminada en 0.7.x. Causaba `NoMethodError` al arrancar en Railway.

### Solución

rack-timeout 0.7.x no tiene setters de clase. El Railtie auto-inserta el middleware y lee configuración desde env vars. El initializer fue reescrito como documentación.

Variables configuradas en Railway:

- `RACK_TIMEOUT_SERVICE_TIMEOUT=25`
- `RACK_TIMEOUT_WAIT_TIMEOUT=30`

| Archivo | Cambio |
| --- | --- |
| `ttpngas/Gemfile` | `gem 'rack-timeout'` |
| `ttpngas/config/initializers/rack_timeout.rb` | Reescrito — solo documentación, sin código |

---

## 3. Auditoría SQL Injection

### Resultado

**Sin vulnerabilidades encontradas.**

- Todos los `WHERE` / `ILIKE` usan placeholder `?` — binding paramétrico.
- No hay interpolación `#{}` dentro de strings SQL.
- `.order()` usa símbolos o strings hardcodeados — ninguno acepta input de usuario sin whitelist.
- `params.permit!` no aparece en ningún controller activo.

---

## 4. Command Injection — corregido

### `ttpngas/app/controllers/api/v1/ttpn_bookings_controller.rb`

Método `backfill_clvs`. El valor de `params[:days]` se interpolaba directamente en el comando.

```ruby
# Antes — inyectable
system("bin/rails cuadre:backfill_ttpn_bookings DAYS=#{params[:days]}")

# Después — seguro
days = params[:days].to_i.clamp(1, 365)
days = 30 if days.zero?
Thread.new { system({ 'DAYS' => days.to_s }, 'bin/rails', 'cuadre:backfill_ttpn_bookings') }
```

### `ttpngas/app/jobs/ejecutar_script_python_job.rb`

- `Open3.capture3` recibía un string → pasaba por shell (inyectable).
- No había validación de path traversal en el nombre del script.

```ruby
# Solución: build_command retorna Array, capture3 usa splat
def safe_script_path!(script_name)
  path = File.expand_path(File.join(SCRIPTS_ROOT, script_name))
  raise ArgumentError unless path.start_with?("#{File.expand_path(SCRIPTS_ROOT)}/")
  raise ArgumentError unless File.exist?(path)
  path
end

def build_command(script_path, params)
  args = params.map { |k, v| "--#{k.to_s.tr('_', '-')}=#{v}" }
  [PYTHON_BIN, script_path] + args
end
```

---

## 5. IDOR (Insecure Direct Object Reference) — corregido

Cuatro controllers hacían `Model.find(params[:id])` sin filtrar por Business Unit, permitiendo acceder a registros de otras BUs con solo cambiar el ID.

### Patrón aplicado

```ruby
scope = Model.joins(:parent_with_bu)
scope = scope.where(parents: { business_unit_id: @business_unit_id }) if @business_unit_id
@record = scope.find(params[:id])
```

| Controller | Método corregido |
| --- | --- |
| `vehicle_checks_controller.rb` | `set_vehicle_check` — BU via join con `vehicles` |
| `employee_appointments_controller.rb` | `set_appointment` — BU directa |
| `employee_vacations_controller.rb` | `set_employee_vacation` — BU via join con `employees` |
| `employee_deductions_controller.rb` | `by_employee` — BU via scope en `Employee` |

---

## 6. Devise Lockable — brute force en login JWT

Devise Lockable no funciona automáticamente con JWT (requiere Warden). Se implementó manualmente en el sessions controller.

### Archivos

| Archivo | Cambio |
| --- | --- |
| `db/migrate/20260429000001_add_lockable_to_users.rb` | Migración nueva: `failed_attempts`, `locked_at`, `unlock_token` |
| `app/models/user.rb` | `:lockable` en `devise` declaration |
| `config/initializers/devise.rb` | `lock_strategy`, `unlock_strategy`, `maximum_attempts: 10`, `unlock_in: 1.hour` |
| `app/controllers/api/v1/auth/sessions_controller.rb` | Lógica manual: `locked_account?`, `handle_failed_attempt`, `reset_failed_attempts!` |

Migración aplicada en producción Railway el 2026-04-29.

---

## 7. Filter Parameter Logging

Extendida la lista de parámetros filtrados en logs:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :authorization, :api_key, :jwt, :bearer,
  :card_number, :cvv, :expiry, :bank_account, :clabe,
  :webhook_secret, :encryption_key
]
```

---

## 8. bundler-audit — CVE scanning

`gem 'bundler-audit', require: false` añadido al grupo dev/test.  
Pendiente: agregar `bundle exec bundler-audit check` en pipeline de CI.

---

## 9. Pre-commit Hook — detección de secretos

Archivo: `.githooks/pre-commit` (monorepo raíz, versionado).

Detecta antes de cada commit:

- AWS keys (`AKIA...`)
- Claves PEM privadas
- Tokens de Railway / Heroku
- Valores reales en `SECRET_KEY_BASE`, `DEVISE_JWT_SECRET_KEY`, `N8N_ENCRYPTION_KEY`

Activar en repositorio nuevo: `git config core.hooksPath .githooks`

---

## 10. Documentación de Seguridad — SEGURIDAD.md

Reescritura completa de `Documentacion/INFRA/seguridad/SEGURIDAD.md`:

- 10 secciones documentando todas las capas de seguridad implementadas
- Tabla de arquitectura de roles de BD (service_role, postgres, app_user, N8N)
- Corrección de arquitectura N8N: usa API Key HTTP, no conexión directa a BD
- Proceso de rotación semestral en `INFRA/seguridad/rotacion_api_keys.md`

---

## 11. CSP Frontend — Netlify `_headers`

### Problema

`script-src` tenía `'unsafe-inline'` y `'unsafe-eval'` sin necesidad.

### Análisis

- `'unsafe-eval'`: Vue 3 + Vite pre-compila templates — nunca usa `eval()` en producción.
- `'unsafe-inline'` en scripts: Vite bundlea todo en `.js` externos, `index.html` sin scripts inline.
- `'unsafe-inline'` en styles: **se mantiene** — Quasar requiere `:style` bindings dinámicos.

```text
# Antes
script-src 'self' 'unsafe-inline' 'unsafe-eval'

# Después
script-src 'self'
```

Archivo: `ttpn-frontend/public/_headers`

---

## 12. PWA Workbox — fix precache `_headers`

### Error detectado

El Service Worker intentaba precachear `/_headers` (archivo de config de Netlify) → `404 Not Found` + error en consola.

### Causa del error

`_redirects` ya estaba en `globIgnores` pero `_headers` no se había añadido al crear el archivo.

### Fix

```js
// quasar.config.js
cfg.globIgnores = [...(cfg.globIgnores || []), '_redirects', '_headers']
```

---

## 13. Aclaraciones de arquitectura documentadas

- **N8N** no conecta directo a la BD — llama al Rails API via HTTP con `ApiKey` (modelo `ApiUser`/`ApiKey`).
- **Scripts Python** (`db.py`) usan `DATABASE_URL` — misma variable que Rails, mismo rol `service_role`, mismo BYPASSRLS.
- **`app_user`** en `rls_policies.sql` es un rol para uso futuro si los scripts Python necesitan aislamiento por BU con RLS.
- `APP_USER_DATABASE_URL` creada por error en Railway → eliminada del dashboard y del `.env.example`.

---

## Commits del día

### ttpngas (branch `transform_to_api`)

| Hash | Descripción |
| --- | --- |
| `3b04156` | security: corregir command injection, IDOR, lockout y rate limiting |
| `361a814` | fix(rack-timeout): usar service_timeout= y wait_timeout= (API 0.7.x) |
| `094ace8` | fix(rack-timeout): reescribir initializer para API 0.7.x basada en env vars |
| `83446ae` | docs(env): agregar APP_USER_DATABASE_URL para rol app_user con RLS |
| `2052889` | docs(env): corregir APP_USER_DATABASE_URL — N8N usa API Key, no BD directa |
| `3c23ff9` | docs(env): eliminar APP_USER_DATABASE_URL — scripts Python usan DATABASE_URL |

### ttpn-frontend (branch `main`)

| Hash | Descripción |
| --- | --- |
| `04b943a` | security(csp): eliminar unsafe-inline y unsafe-eval de script-src |
| `058d863` | fix(pwa): excluir _headers del precache de Workbox |

### ttpn_documentacion (branch `main`)

| Hash | Descripción |
| --- | --- |
| `02bbbc5` | docs(seguridad): corregir arquitectura N8N — usa API Key, no app_user directo |
| `0a304d7` | docs(seguridad): corregir tabla de roles — Python scripts usan DATABASE_URL |
| `672c0b9` | docs(seguridad): actualizar CSP Frontend y pendientes — unsafe removidos |
| `9963160` | docs(seguridad): agregar proceso de rotación semestral de API Keys |
| `9d4c4e6` | docs(seguridad): eliminar sección Pendientes — mover tareas a rotacion_api_keys |

---

## Decisiones tomadas

1. **rack-timeout 0.7.x**: configuración solo por env vars — no hay API de clase.
2. **N8N**: nunca conecta directo a BD — arquitectura confirmada vía revisión de código.
3. **`app_user` DB role**: reservado para futuro si Python scripts necesitan RLS. Hoy no aplica.
4. **`style-src unsafe-inline`**: se mantiene — eliminarla rompe Quasar.
5. **Sección "Pendientes" de SEGURIDAD.md**: eliminada al cerrar todos los ítems. Tareas únicas remanentes (RLS, AWS rotation) movidas a `rotacion_api_keys.md`.
