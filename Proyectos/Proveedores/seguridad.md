# Seguridad del Portal de Proveedores

Este documento agrupa **todas las reglas anti-hacking** que el portal
respeta. La mayoría ya están definidas en Kumi — aquí solo se
**referencian** las existentes (no se redefinen) y se listan las
**extensiones específicas** del portal.

## Reglas heredadas de Kumi (lectura obligatoria)

Antes de tocar código, **lee estas 3 fuentes**:

1. `../../INFRA/seguridad/SEGURIDAD.md` — RLS, CORS, security headers,
   checklist de producción.
2. `ttpngas/CLAUDE.md` sección **"Seguridad"** — webhooks HMAC,
   rack-attack, `params.permit!` prohibido, `business_unit_id`
   server-side, RLS.
3. `ttpngas/CLAUDE.md` sección **"Reglas de seguridad que no se
   negocian"** — checklist mínimo no negociable.

Estas reglas aplican al portal **al 100 %**. Si una regla se rompe en
el portal, se rompe en Kumi entero.

### Resumen de lo más crítico (no exhaustivo)

| Regla | Dónde se aplica en el portal |
|---|---|
| `params.permit!` prohibido | Todo controller `Api::V1::Portal::*` debe usar whitelist explícita |
| `business_unit_id` se asigna server-side, nunca en params | Aplica también a `SupplierUser.business_unit_id` (heredado del Supplier) |
| Datos sensibles fuera de logs/URLs | JWT, passwords, tokens de reset nunca en query params ni en `Rails.logger.info` |
| Rate limiting siempre activo | Throttle adicional para `/api/v1/portal/auth/*` |
| HSTS + force_ssl en producción | Ya configurado, no tocar |
| API Keys con scope mínimo necesario | La key del portal solo tiene permisos sobre recursos del portal |

## Extensiones específicas del portal

### 1. Autenticación

#### Passwords

- **Hash con `bcrypt`** (Rails 7 default `cost: 12`). NUNCA almacenar
  password en claro.
- **`has_secure_password`** built-in de ActiveRecord — no usar
  alternativas raras.
- **Mínimo 12 caracteres**, 1 mayúscula, 1 número, 1 símbolo
  (validación en modelo + en FE).
- **Password temporal** generado por el admin al crear el usuario:
  `SecureRandom.alphanumeric(16)`. Se envía por email y se obliga a
  cambio al primer login (`force_password_change = true`).

#### JWT del SupplierUser

- TTL **12 horas** (`exp: 12.hours.from_now`).
- Claim **`jti` (UUID)** — se almacena en `supplier_users.jti`.
- **Logout** o **revocación** rota el `jti` (genera uno nuevo). Cualquier
  JWT viejo queda inválido automáticamente.
- Decode con `Rails.application.secret_key_base`, algoritmo `HS256`.
- **NO usar refresh tokens** en MVP (TTL de 12h es suficiente para
  sesión laboral; el usuario re-loguea al siguiente día).

#### Lockable (anti-brute-force)

- 5 intentos fallidos → `locked_at = now`, `unlock_token = SecureRandom.urlsafe_base64`.
- Auto-unlock en **1 hora**, o desbloqueo manual por admin.
- Cada bloqueo genera un `SupplierAuditEvent` con IP + user agent.
- El usuario bloqueado recibe un email avisándole.

#### Tokens de confirmación y reset

- **Almacenar SHA256 digest, NUNCA en claro**:

  ```ruby
  raw_token = SecureRandom.urlsafe_base64(32)
  token_digest = Digest::SHA256.hexdigest(raw_token)
  SupplierUserToken.create!(
    supplier_user_id: user.id,
    token_digest: token_digest,
    purpose: 'confirmation',
    expires_at: 72.hours.from_now
  )
  # Enviar raw_token al usuario via email; jamás guardarlo en BD.
  ```

- **TTL**:
  - Confirmación: 72 horas (3 días).
  - Reset password: 1 hora.
- **Un solo uso**: al validar, marca `used_at` y rechaza siguientes
  intentos con el mismo token.
- Si caduca, el usuario pide otro (no se reactiva).

### 2. Rate limiting (rack-attack)

Agregar en `config/initializers/rack_attack.rb`:

```ruby
# Login del portal: 5 req / 20 s por IP
Rack::Attack.throttle('portal_login/ip', limit: 5, period: 20.seconds) do |req|
  req.ip if req.path == '/api/v1/portal/auth/login' && req.post?
end

# Forgot/reset password: 3 req / 60 s por IP
Rack::Attack.throttle('portal_forgot/ip', limit: 3, period: 60.seconds) do |req|
  req.ip if req.path.start_with?('/api/v1/portal/auth/forgot_password',
                                 '/api/v1/portal/auth/reset_password') && req.post?
end

# Blocklist: 10 logins fallidos en 5 min → bloquear IP 1 hora
Rack::Attack.blocklist('portal_brute_force/ip') do |req|
  Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 5.minutes, bantime: 1.hour) do
    req.path == '/api/v1/portal/auth/login' && req.post?
  end
end
```

### 3. CORS

NUNCA editar el bloque principal de `config/initializers/cors.rb`.
En su lugar, agregar el dominio del portal a la variable de entorno
`FRONTEND_URL_EXTRA` en Railway:

```bash
FRONTEND_URL_EXTRA=https://kumi-admin.netlify.app,https://portal-proveedores.netlify.app
```

El `cors.rb` ya lee esa variable.

### 4. Auditoría — `SupplierAuditEvent`

Cada evento crítico se persiste con IP + user_agent. Esto es **no
negociable** para anti-hacking y para trazabilidad ante el SAT.

| event_type | Cuándo se registra |
|---|---|
| `login_success` | Login exitoso |
| `login_failed` | Login fallido (password incorrecta o usuario bloqueado) |
| `logout` | Logout explícito |
| `password_changed` | Cambio de password (forzado o voluntario) |
| `password_reset_requested` | Usuario pide reset |
| `password_reset_completed` | Usuario completa reset y entra |
| `confirmation_sent` | Admin manda confirmación (alta o reenvío) |
| `confirmation_used` | Usuario activa cuenta |
| `account_locked` | 5 intentos fallidos → bloqueo |
| `account_unlocked` | Auto-unlock (1 h) o admin unlock |
| `forced_password_change` | Primer cambio obligatorio |
| `invoice_uploaded` | Proveedor sube factura |
| `invoice_cancelled` | Proveedor cancela su factura en pending_match |
| `complement_uploaded` | Proveedor sube complemento PPD |

Estructura del modelo:

```ruby
create_table :supplier_audit_events do |t|
  t.references :supplier_user, foreign_key: true # nullable (e.g. login_failed sin user)
  t.references :supplier, foreign_key: true
  t.string :event_type, null: false
  t.inet :ip
  t.string :user_agent
  t.jsonb :metadata, default: {}
  t.datetime :created_at, null: false
end
add_index :supplier_audit_events, :event_type
add_index :supplier_audit_events, :created_at
```

### 5. Validación de archivos subidos a Supabase

Antes de subir cualquier archivo:

| Validación | Regla |
|---|---|
| Content-Type | Solo `application/pdf`, `application/xml`, `text/xml` |
| Tamaño máximo por archivo | 10 MB |
| Archivos por bulk upload | Máximo 40 |
| Tamaño total por bulk | Máximo 200 MB |
| Filename | Sanitizar: `Pathname.new(name).basename.to_s.gsub(/[^\w.\-]/, '_')` |
| Hash de contenido | Calcular SHA256 y guardar en `supplier_documents.sha256` — si ya existe un doc con ese hash para ese supplier, rechazar como duplicado |

Cualquier archivo que falle validación se rechaza con HTTP 422 y
mensaje claro. **No se sube nada a Supabase si la validación falla**
(no genera archivos huérfanos).

### 6. Headers de autenticación

Todos los endpoints `/api/v1/portal/*` requieren **AMBOS** headers:

```text
X-API-Key: <key del portal, generada por Antonio en Kumi Admin>
Authorization: Bearer <jwt del supplier_user, obtenido al login>
```

Excepciones (solo X-API-Key, sin JWT):

- `POST /api/v1/portal/auth/login`
- `POST /api/v1/portal/auth/forgot_password`
- `POST /api/v1/portal/auth/reset_password`
- `POST /api/v1/portal/auth/confirm`

Si falta `X-API-Key` o es inválida → **HTTP 401** (NUNCA 403, no
revelar existencia del endpoint).

Si JWT falta o es inválido en endpoint que lo requiere → **HTTP 401**
con `{ error: "Sesión expirada o inválida" }`.

### 7. Logging seguro

- **NUNCA** loguear: passwords, JWTs completos, tokens de reset,
  API Keys completas.
- **SÍ loguear**: `supplier_user_id`, IP, user_agent, event_type.
- Para debug local de JWT, loguear solo `header.payload`, no la
  signature.

### 8. Checklist antes de cada PR

Copia esto a la descripción del PR:

- [ ] `params.permit!` no aparece en ningún controller nuevo
- [ ] `business_unit_id` no está en ningún `permit(...)`
- [ ] Todo endpoint nuevo `/portal/*` tiene `before_action :require_api_key!`
- [ ] Endpoints autenticados (no auth/*) tienen `before_action :authenticate_supplier_user!`
- [ ] Auditoría: cada acción crítica genera un `SupplierAuditEvent`
- [ ] Tokens de confirmación/reset se almacenan como SHA256, no en claro
- [ ] Bcrypt cost ≥ 12
- [ ] Rate limit en `rack_attack.rb` para nuevos endpoints sensibles
- [ ] CORS no se edita el bloque principal — solo `FRONTEND_URL_EXTRA`
- [ ] Validación de archivos: tipo + tamaño + duplicado SHA256
- [ ] Nada sensible en logs (passwords, JWT completos, tokens en claro)
- [ ] Tests RSpec cubren: 401 sin X-API-Key, 401 sin JWT, 401 con JWT expirado, 423 cuenta bloqueada

## Modelo de amenazas (resumen)

| Amenaza | Mitigación primaria | Defensa en profundidad |
|---|---|---|
| Brute force al login | rack-attack throttle + lockable (5 fallos) | Audit log + alerta a admin |
| Robo de JWT | TTL 12 h + jti rotable + HTTPS | Logout invalida jti viejo |
| Replay de token reset | Token de un solo uso + TTL 1 h + SHA256 en BD | Cada uso marca `used_at` |
| Enumeración de usuarios | `forgot_password` siempre responde 204 (no revela si existe) | 401 genérico ("credenciales inválidas") en login |
| Inyección por filename | Sanitización al subir a Supabase | Bucket privado (URLs signed) |
| Acceso cross-supplier | `current_supplier_user.supplier.invoices` (scope obligatorio) | RLS en Postgres (futuro) |
| Subida de malware (XML/PDF) | Validación content-type + tamaño + extensión | Análisis fuera de alcance MVP (Fase 2) |
| Exfiltración por SQL injection | Active Record + params permitidos | RLS (futuro) |
| CSRF | API Rails-mode no usa sesiones; protección via SameSite del cookie de auth Admin (no aplica al portal — JWT en localStorage) | Headers explícitos `X-API-Key` + JWT en Authorization |

## Si detectas una vulnerabilidad

1. **NO hagas un PR público**.
2. Reporta directo a Antonio por canal privado (WhatsApp / mensaje
   directo).
3. Antonio decide si requiere rotación de keys, deploy hotfix, etc.

## Referencias

- OWASP API Security Top 10 (2023): <https://owasp.org/API-Security/editions/2023/en/0x11-t10/>
- CFDI 4.0 (SAT México) — anexo 20: <http://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20.htm>
- Rails Security Guide: <https://guides.rubyonrails.org/security.html>
