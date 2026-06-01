# Flujo de activación, reset y multi-BU de usuarios

Documenta el flujo completo de creación / activación / cambio de password /
recuperación de password / multi-BU de los `User` del admin (no
`ClientUser`, que es otro flujo separado).

## Principio

**El admin NUNCA elige passwords**. El sistema las genera con `PasswordStrength.generate`
(16 chars que cumplen 8+may+min+num+sym), las manda por correo en texto plano
junto con un link de activación, y el usuario debe completar la activación
ingresando esa password temporal junto con una nueva propia. Hasta entonces la
cuenta queda bloqueada de login.

## Estados de la cuenta

Una cuenta puede estar en uno de 4 estados (campo computed `activation_state`):

| Estado | Condición BD | Login permitido | Aparece en listado |
| --- | --- | --- | --- |
| `active` | `activated_at != NULL && is_active=true && !needs_password_reset` | ✅ | Chip verde |
| `pending_activation` | `activated_at == NULL` | ❌ (`NEEDS_ACTIVATION`) | Chip amber |
| `pending_reset` | `needs_password_reset = true` | ❌ (`NEEDS_PASSWORD_RESET`) | Chip naranja |
| `inactive` | `is_active = false` | ❌ (`INACTIVE`) | Chip gris |

`needs_activation?` agrupa los dos primeros — es lo que consulta
`SessionsController#create`.

## Columnas BD (migration `AddActivationStateToUsers`)

| Campo | Tipo | Uso |
| --- | --- | --- |
| `activation_token` | `string` (UNIQUE) | Token de 43 chars URL-safe; NULL una vez completada. |
| `activation_sent_at` | `datetime` | Para calcular `activation_token_expired?` (24h). |
| `activated_at` | `datetime` | NULL = pendiente, set = activado. |
| `needs_password_reset` | `boolean` (default false) | true bloquea login hasta usar el link. |

La migration backfilea `activated_at = NOW()` para todos los users que tenían
password (cutover-safe — no rompe accesos existentes).

## Tabla pivote multi-BU

`user_operable_business_units` (HABTM), creada por migration
`CreateUserOperableBusinessUnits`. Mismo patrón que
`vehicle_operable_business_units`. El usuario opera en TODAS las BUs que
aparezcan aquí + la BU dueña (`business_unit_id`, FK simple).

`User.business_unit_filter` lee de ambas:

```ruby
where(business_unit_id: bu_id)
  .or(joins(:operable_business_units).where(business_units: { id: bu_id }))
```

## Concern `PasswordStrength`

- `PasswordStrength.valid?(password)` — regex única: `/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}\z/`.
- `PasswordStrength.generate` — 16 chars que cumplen las 4 reglas + 12 chars random.

Usado en `sessions#change_password`, `account_activations#activate`,
`password_resets#confirm`. El FE usa el mismo regex en `passwordIsStrong()`
exportado por `PasswordRules.vue`.

## Endpoints

### Admin (autenticado con JWT)

| Método | Path | Acción |
| --- | --- | --- |
| `POST` | `/api/v1/users` | Crea user; genera temp password, manda correo, `activated_at=nil`. |
| `PUT` | `/api/v1/users/:id` | Update normal de datos. Si llega `user.request_password_reset:true`, re-dispara flujo (admin reset). |
| `POST` | `/api/v1/users/:id/resend_activation` | Genera nuevo token, reenvía correo. Solo si `needs_activation?`. |

### Públicos (sin JWT)

| Método | Path | Acción |
| --- | --- | --- |
| `POST` | `/api/v1/account_activations/check_token` | `{ token }` → `{ valid, email }`. |
| `POST` | `/api/v1/account_activations/activate` | `{ token, temporary_password, new_password, new_password_confirmation }` → activa + devuelve JWT. |
| `POST` | `/api/v1/password_resets` | `{ email }` → si existe, genera temp + manda correo (siempre 200, no leak). |
| `POST` | `/api/v1/password_resets/confirm` | Mismo body que activate (reuso vía `AccountActivationFlow` concern). |

### Sesión

| Método | Path | Acción |
| --- | --- | --- |
| `POST` | `/api/v1/auth/login` | Login. Devuelve 403 + code `NEEDS_ACTIVATION` / `NEEDS_PASSWORD_RESET` / `INACTIVE` si aplica. |
| `POST` | `/api/v1/auth/heartbeat` | Renueva JWT (header `X-Renewed-Token`) ante actividad real del FE. |

Todos los errores del flujo de activación devuelven **422**, no 401, porque el
interceptor de axios del FE redirige a `/login` en cualquier 401 — y las
pantallas de activación/reset son públicas (sin sesión).

## JWT

`SESSION_INACTIVITY_TIMEOUT = 1.hour` en `User`. `generate_jwt(exp = 1.hour.from_now)`.
El FE renueva en cada request exitoso (interceptor lee `X-Renewed-Token`).
Sin actividad por 1h → siguiente request da 401 → redirect a login.
Adicionalmente el composable `useSessionTimeout` del FE detecta inactividad
mouse/teclado/scroll y cierra sesión proactivamente sin esperar el 401.

## Mailers

`UserMailer.activation_email(user, temp_password)` y
`UserMailer.reset_password_email(user, temp_password)`. Templates en
`app/views/user_mailer/`. La password temporal va en `<code>` dentro del body.
Ambos heredan el layout unificado `mailer.html.erb` (header blanco con logo
TTPN + footer azul Kumi).

## Specs

Cubre:

- `password_strength_spec.rb` — validador + generador.
- `user_mailer_spec.rb` — 8 tests (subject, from, body, links).
- `account_activations_spec.rb` — check_token + activate + 422s.
- `password_resets_spec.rb` — create (con/sin email registrado) + confirm.

Suite completa: **1842 ej / 0 failures / 80.13% coverage**.

## Smoke test

```bash
# stage
railway environment stage
railway service kumi-admin-api
railway ssh 'bundle exec rails runner "
  # Simular admin creando un user
  Current.business_unit = BusinessUnit.first
  u = User.new(email: \"test@example.com\", nombre: \"Test\", role: Role.first,
               business_unit: BusinessUnit.first, password: PasswordStrength.generate)
  u.save!
  u.generate_activation_token!
  UserMailer.activation_email(u, \"TempPass1!\").deliver_now
  puts \"sent + token=#{u.activation_token}\"
"'
```

El admin recibe el correo con la password temporal. Va a
`https://kumi-stage.netlify.app/activate?token=...`, ingresa temp + nueva,
queda activado y entra a la app con JWT fresco.
