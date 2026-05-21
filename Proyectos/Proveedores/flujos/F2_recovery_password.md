# F2 — Recovery de password

## Objetivo

El proveedor olvidó su contraseña. La recupera vía email sin
necesidad de contactar a TTPN.

## Pasos

### 1. Proveedor pide recovery

UI: `/login` → "¿Olvidaste tu contraseña?" → `ForgotPasswordPage.vue`.

```text
POST /api/v1/portal/auth/forgot_password
{ "email": "ana@proveedor.com" }
```

Backend (`Portal::PasswordResetService.request_reset`):

1. Busca `SupplierUser.find_by(email: ...)`.
2. **Si NO existe o NO está activo**: NO hace nada, pero responde 204
   igual (anti-enumeración).
3. Si existe: genera `SupplierUserToken` purpose=`reset_password`,
   TTL 1 hora.
4. Manda `Portal::SupplierMailer.reset_password(user, raw_token).deliver_later`.
5. Registra `SupplierAuditEvent(event_type: 'password_reset_requested')`.

FE muestra mensaje neutral: "Si el correo existe, te llegará un link
para recuperar tu contraseña."

### 2. Email de recovery

Contenido:

- "Recibimos una solicitud para cambiar tu contraseña."
- Botón "Cambiar contraseña" → `https://portal.../reset?token=<raw>`
- "Este link expira en 1 hora."
- "Si tú no lo pediste, ignora este correo. Tu cuenta sigue segura."

### 3. Proveedor cambia password

`ResetPasswordPage.vue`. Lee `?token=<raw>` de la URL. Pide nueva
password + confirmación.

```text
POST /api/v1/portal/auth/reset_password
{ "token": "<raw>", "password": "NuevaPwd2026!!" }
```

Backend (`Portal::PasswordResetService.consume_reset`):

1. `SupplierUserToken.consume!(raw, purpose: 'reset_password')` —
   valida hash + no usado + no expirado, marca `used_at`.
2. `user.password = new_password; user.failed_attempts = 0;
   user.locked_at = nil; user.save!` (también desbloquea si estaba).
3. Registra `SupplierAuditEvent('password_reset_completed')`.
4. Devuelve `{ jwt: ..., supplier_user: ... }` para auto-login.

FE: guarda JWT en localStorage, redirige a `/facturas` (sin pasar
por `/login`).

## Casos de error

| Caso | Respuesta |
|---|---|
| Token expirado o ya usado | 401 `{ error: "Token inválido o expirado" }` |
| Nueva password no cumple longitud mínima | 422 `{ errors: ["Password muy corta"] }` |
| Email no existe | 204 (igual, no revela) |

## Anti-abuse

- **Rate limit**: `Rack::Attack.throttle('portal_forgot/ip',
  limit: 3, period: 60.seconds)`.
- **Token de un solo uso**: marcar `used_at` en cuanto se consume.
- **TTL corto**: 1 hora.
- **SHA256 en BD**: el raw token solo está en el email.

## Verificación

1. Logueate con un user → cierra sesión.
2. `/login` → "Olvidé contraseña" → email.
3. Refresca LetterOpener (`localhost:3000/letter_opener`) → email
   nuevo.
4. Click al link → llena nueva password → entras directo a
   `/facturas` (sin pasar por login).
5. En DB:
   `SupplierUserToken.last.used_at` no es nil,
   `SupplierAuditEvent.last(2)` tiene `password_reset_requested` y
   `password_reset_completed`.
