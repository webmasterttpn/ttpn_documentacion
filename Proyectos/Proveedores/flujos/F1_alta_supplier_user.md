# F1 — Alta de SupplierUser

## Objetivo

Un admin de Finanzas en Kumi captura el correo de un proveedor para
darle acceso al Portal. El proveedor recibe email con contraseña
temporal, activa la cuenta, y al primer login cambia el password.

## Actores

- **Admin Finanzas** (User en Kumi con privilegio `supplier_portal_users`)
- **SupplierUser** (nuevo, sin acceso aún)
- **Sistema** (Rails API + LetterOpener en dev / SMTP en prod)

## Pasos

### 1. Admin captura email y nombre

UI: `/finanzas/proveedores/portal-usuarios` → botón "+ Nuevo usuario"
en el row del proveedor.

```text
POST /api/v1/suppliers/:supplier_id/users
{
  "supplier_user": {
    "email": "ana@proveedor.com",
    "nombre": "Ana López"
  }
}
```

Backend:

1. Crea el `SupplierUser` con:
   - `password = SecureRandom.alphanumeric(16)` (temporal)
   - `force_password_change = true`
   - `active = false`
   - `confirmed_at = nil`
   - `jti = SecureRandom.uuid`
2. Crea un `SupplierUserToken` purpose=`confirmation` con
   `SHA256(raw_token)` y `expires_at = 72.hours.from_now`.
3. Manda `Portal::SupplierMailer.confirmation(user, raw_token, temp_password).deliver_later`.
4. Registra `SupplierAuditEvent(event_type: 'confirmation_sent')`.

### 2. Proveedor recibe email

Contenido del email:

- Saludo "Bienvenido <nombre>"
- Botón "Activar cuenta" (link a `https://portal.../confirmar?token=<raw>`)
- Password temporal en bloque monospace destacado
- Advertencia: "Al primer login se te pedirá cambiar la contraseña"
- TTL: "El link expira en 72 horas"

### 3. Proveedor activa la cuenta

Click al link → `https://portal.../confirmar?token=<raw>`.

FE (`ConfirmAccountPage.vue`):

```text
POST /api/v1/portal/auth/confirm
{ "token": "<raw>" }
```

Backend:

1. `SupplierUserToken.consume!(raw, purpose: 'confirmation')` — valida
   hash + no usado + no expirado, marca `used_at`.
2. `supplier_user.confirm!` — setea `confirmed_at` y `active = true`.
3. Registra `SupplierAuditEvent(event_type: 'confirmation_used')`.
4. Responde 200 OK.

FE muestra "Cuenta activada, ya puedes iniciar sesión" → botón a `/login`.

### 4. Primer login con password temporal

```text
POST /api/v1/portal/auth/login
{ "email": "ana@proveedor.com", "password": "<temp>" }
```

Respuesta:

```json
{
  "jwt": "...",
  "supplier_user": { ..., "force_password_change": true },
  "must_change_password": true
}
```

FE (`LoginPage.vue` post-login):

```js
if (auth.mustChangePassword) router.push('/cambiar-password')
```

### 5. Cambio forzado de password

`ChangePasswordPage.vue` — el guard `requiresAuth +
!allowDuringForcedChange` impide salir de esta pantalla hasta cambiar.

```text
PATCH /api/v1/portal/me/password
{ "current_password": "<temp>", "new_password": "MiPwd2026!!" }
```

Backend:

1. `user.authenticate(current_password)` → si OK:
2. `user.password = new_password; user.force_password_change = false;
   user.save!`
3. Registra `SupplierAuditEvent(event_type: 'password_changed')` y
   también `'forced_password_change'` (primer cambio).
4. Responde 200.

FE: redirige a `/facturas`.

## Casos de error

| Caso | Respuesta |
|---|---|
| Email ya existe en `supplier_users` | 422 `{ errors: ["Email ya está registrado"] }` |
| Admin sin privilegio | 403 `{ error: "Sin privilegio" }` |
| Token de confirmación expirado | 401 `{ error: "Token inválido o expirado" }` |
| Token ya usado | 401 idem |
| Password actual incorrecto en el cambio forzado | 422 `{ error: "Password actual incorrecta" }` |

## Verificación end-to-end con LetterOpener

1. Admin entra a Kumi → `/finanzas/proveedores/portal-usuarios`.
2. Crea usuario `ana@proveedor.com`.
3. Abre `localhost:3000/letter_opener` → ve el email.
4. Copia el password temporal (visible en el HTML del email).
5. Click al link "Activar cuenta" → abre el portal en otro tab.
6. Va a `/login` → entra con email + password temporal.
7. Es redirigido a `/cambiar-password`.
8. Cambia password → llega a `/facturas`.
9. Verifica en DB: `confirmed_at`, `active=true`,
   `force_password_change=false`.
10. Verifica `SupplierAuditEvent`: 4 eventos al menos
    (`confirmation_sent`, `confirmation_used`, `login_success`,
    `password_changed`).
