# 2026-06-01 — Flujo de activación de usuarios + reset + multi-BU + timeout 1h

## Contexto

El sistema viejo de creación de usuarios tenía huecos:

- Admin elegía la password directamente al crear → password compartida o
  trivial.
- Form pedía `business_unit_id` aunque el admin ya tiene una activa (no se
  inferí­a).
- Validación de complejidad de password solo existía en
  `sessions#change_password` (regex inline 117-125), no en create ni en
  flujos nuevos.
- Login no bloqueaba por `is_active=false` ni por "no activado".
- JWT vivía 24h sin importar actividad — usuarios olvidaban sesión abierta
  en cyber/computadora prestada.
- "Olvidé contraseña" en LoginPage era `<a href="#">` (sin endpoint).
- Listado no mostraba quién había activado su cuenta — admin no sabía si
  alguien estaba pendiente.
- Form de Crear usuario tenía botón `+` para crear BU desde el contexto del
  user form (UI antipatron).

## Cambios

### Backend

- 2 migrations:
  - `CreateUserOperableBusinessUnits` (HABTM, idéntico patrón a vehicles).
  - `AddActivationStateToUsers` (`activation_token`, `activation_sent_at`,
    `activated_at`, `needs_password_reset`). Backfilea `activated_at = NOW()`
    para usuarios existentes (cutover-safe).
- Concern `PasswordStrength` (regex + generador). Reemplaza la validación
  inline de sessions_controller.
- `User` modelo: HABTM `operable_business_units`, scopes, métodos
  `activated?`/`needs_activation?`/`generate_activation_token!`/`activation_token_expired?`.
  `business_unit_filter` actualizado para usar la pivote.
- `UserMailer` + 2 templates (activation_email, reset_password_email).
  Layout unificado TTPN/Kumi. Password temporal en texto plano en body.
- `Api::V1::UsersController`: create genera temp + manda correo + admin
  nunca elige. update con `request_password_reset:true` re-dispara flujo.
  `resend_activation` nuevo endpoint.
- `AccountActivationsController` (nuevo) + `PasswordResetsController` (nuevo)
  comparten `AccountActivationFlow` concern. 422 en errores (no 401, porque
  son endpoints públicos y el interceptor del FE redirige login en 401).
- `SessionsController#create`: bloquea con códigos `NEEDS_ACTIVATION`,
  `NEEDS_PASSWORD_RESET`, `INACTIVE`. `#heartbeat` para renovar JWT vía
  `X-Renewed-Token`. `#change_password` adopta `PasswordStrength`.
- JWT exp: 24h → `SESSION_INACTIVITY_TIMEOUT = 1.hour`.
- 4 spec files nuevos. Suite: **1842 ej, 0 failures, 80.13% coverage**.

### Frontend

- 3 pages nuevas (públicas, sin layout):
  - `AccountActivationPage` (`/activate` y `/reset` reusan misma componente).
  - `ForgotPasswordPage` (`/forgot-password`).
- `PasswordRules.vue`: componente con 5 checkmarks en vivo + exporta
  `passwordIsStrong()` para validators. Mismo regex que el BE.
- `UsersPage.vue` refactor:
  - Form CREATE: campos password disabled con icono ? + tooltip.
    Banner "se asignará tu BU actual". Sin botón `+` de BU.
  - Form EDIT: campos password disabled + botón "Cambiar contraseña" que
    dispara flujo admin reset (BE re-genera + correo).
  - Multi-select `operable_business_unit_ids` (mismo patrón que vehículos).
  - Tabla: columna Estado con chip dinámico (4 estados). Acción
    "Reenviar correo de activación" cuando aplica.
  - Notify tras crear: "Correo de activación enviado a x@y.com".
- `LoginPage.vue`: link "¿Olvidé contraseña?" navega a /forgot-password.
  Manejo de códigos `NEEDS_ACTIVATION` / `NEEDS_PASSWORD_RESET` / `INACTIVE`.
- `UserProfileDialog.vue`: reemplaza chips inline con `PasswordRules.vue`.
- `useSessionTimeout` composable: cierra sesión tras 1h sin actividad.
  Montado en MainLayout.
- `boot/axios.js`: interceptor response lee `X-Renewed-Token` y actualiza JWT
  en cada response.
- `services/users.service.js`: + `resendActivation`, `triggerPasswordReset`,
  `accountActivationService`, `passwordResetService`.
- `router/routes.js`: 3 rutas públicas nuevas.

## Pendiente para mañana (cutover 2-jun)

- Configurar smoke test en stage con `ing.castean@gmail.com` rol Coordinador
  (ya no Sistemas — decisión del 2026-06-01).
- Validar visualmente las 3 pages auth en stage.
- Validar bloqueo de login + correos de activación end-to-end.
- PR stage → main.

## Riesgos identificados

- **Password en correo (texto plano)**: archivo del correo. Mitigación:
  invalidación inmediata del token al primer uso + force change.
- **JWT 1h vs hábito 24h**: usuarios pueden quejarse del logout más agresivo.
  Mitigación: heartbeat invisible renueva en cada request real, el usuario
  no nota el cambio mientras esté trabajando.
- **Race condition reset**: dos requests simultáneos generan dos tokens. El
  último gana. Aceptable.
- **Email no llega (spam)**: cubierto en sesión previa (SPF + DKIM). Botón
  reenviar en el listado para el admin.

## Branch + PR

`feature/user-activation-flow-and-multi-bu` (BE + FE). Es `feature/`
(bumpea minor → V2.0.x → V2.1.0). Pusheada a stage. PR → stage → smoke test
→ PR stage → main.
