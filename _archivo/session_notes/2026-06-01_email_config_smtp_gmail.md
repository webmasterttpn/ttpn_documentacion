# 2026-06-01 — Configuración SMTP/Gmail con alias `noreply@ttpn.com.mx`

## Contexto

El usuario configuró un alias `noreply@ttpn.com.mx` en la cuenta Gmail
`webmaster@ttpn.com.mx` (con App Password de 16 dígitos) y necesita que el
backend pueda mandar correos desde ese alias en local y en producción.

Antes del cambio:

- `config/environments/development.rb` tenía SMTP de Gmail configurado
  directamente con `smtp_settings = { ... }`.
- `config/environments/production.rb` **NO** tenía configuración de
  ActionMailer (solo `perform_caching = false`). En producción, cualquier
  intento de envío hubiera fallado o caído al mailer null.
- El `from:` estaba hardcodeado a `info@ttpn.com.mx` en **4 lugares**:
  - `app/mailers/application_mailer.rb:4`
  - `app/mailers/client_user_mailer.rb:4`
  - `app/mailers/asignation_mailer.rb` (inline en el `mail()` call)
  - `config/initializers/devise.rb:26` (`mailer_sender`)
- `.env.example` tenía `GMAIL_USER`/`GMAIL_PASSWORD` pero también un bloque
  de "Ejemplo conceptual" (`HOST = "smtp.gmail.com"`, `FROM = '"..." <...>'`)
  sin `#` que parecía variables reales y confundía.

## Cambios aplicados

### 1. Initializer único `config/initializers/action_mailer.rb` (nuevo)

Lee todo de ENV. Activo para development y production; se salta test.
Identidad del negocio (alias, nombre, dominio, link host) **sin defaults
hardcodeados** — fail loud si falta una var. Solo SMTP_HOST y SMTP_PORT
conservan default técnico (`smtp.gmail.com` y `587`).

### 2. `config/environments/development.rb`

Eliminado el bloque `config.action_mailer.smtp_settings = { ... }` y todo lo
asociado (líneas 44-62 de la versión vieja). Solo queda `ENV['FRONTEND_URL']
||= 'http://localhost:9000'` para los links del FE.

### 3. `app/mailers/application_mailer.rb`

`default from: -> { %("#{ENV.fetch('MAIL_FROM_NAME')}" <#{ENV.fetch('MAIL_FROM')}>) }`.

Lambda para que `ENV` se evalúe por mail enviado (no al cargar la clase).
Sin segundo argumento en `fetch` — si la var falta, `KeyError` claro al
primer mail.

### 4. `app/mailers/client_user_mailer.rb`

Quitado `default from: 'info@ttpn.com.mx'`. Hereda de `ApplicationMailer`.

### 5. `app/mailers/asignation_mailer.rb`

Quitado `from: 'info@ttpn.com.mx'` del `mail()` call. Hereda. La lista de
destinatarios se reformateó en líneas separadas para legibilidad.

### 6. `config/initializers/devise.rb`

`config.mailer_sender = -> { ENV.fetch('MAIL_FROM') }`. Lambda para lectura
lazy de ENV — Devise resuelve el lambda al mandar el mail, no al cargar el
initializer.

### 7. `ttpngas/.env.example`

Reemplazado el bloque confuso de "Ejemplo conceptual" con la lista limpia
de vars: `GMAIL_USER`, `GMAIL_PASSWORD`, `MAIL_FROM`, `MAIL_FROM_NAME`,
`SMTP_DOMAIN`, `MAIL_LINK_HOST` (todas obligatorias). `SMTP_HOST`/`SMTP_PORT`
comentadas con sus defaults.

### 8. `setup.sh` (monorepo)

`configure_env_be()` ahora pregunta interactivamente por las 6 vars de
correo cuando crea un `.env` desde el `.env.example`.

### 9. Documentación

- `Documentacion/Backend/dominio/configuracion/integraciones/email.md` —
  doc completa: stack, vars, cómo generar App Password, cómo configurar
  alias en Gmail, mailers existentes, smoke test, troubleshooting.
- Esta nota de sesión.

## Pendiente para que producción mande correos

En Railway → `kumi-admin-api` (prod y stage por separado) → Variables:

| Variable | Valor |
| --- | --- |
| `GMAIL_USER` | `webmaster@ttpn.com.mx` |
| `GMAIL_PASSWORD` | App Password de 16 dígitos (generar en Google) |
| `MAIL_FROM` | `noreply@ttpn.com.mx` |
| `MAIL_FROM_NAME` | `Kumi TTPN` |
| `SMTP_DOMAIN` | `ttpn.com.mx` |
| `MAIL_LINK_HOST` | `kumi.ttpn.com.mx` (prod) / `kumi-stage.netlify.app` (stage) |

**Importante**: pegar valores sin `\r\n` al final (lección del incidente del
KUMI_API_KEY del 31-may — un newline en el secret rompe el header
`Authorization` y el server devuelve 422 confuso).

## Verificación

- [ ] RuboCop verde en archivos tocados.
- [ ] Smoke test local: `bundle exec rails runner 'ActionMailer::Base.mail(to: "ing.castean@gmail.com", subject: "test", body: "ok").deliver_now'`.
- [ ] Stage: configurar vars Railway + smoke test ssh.
- [ ] Prod: smoke test ssh tras configurar vars.
- [ ] FE: solicitar reset de contraseña real desde la pantalla de login → el
      correo llega con `From: "Kumi TTPN" <noreply@ttpn.com.mx>`.

## Decisión clave

El usuario explícitamente pidió "nada hardcodeado, ni el alias". Por eso:

- Sin defaults para `MAIL_FROM`, `MAIL_FROM_NAME`, `SMTP_DOMAIN`,
  `MAIL_LINK_HOST`. Estos son **identidad** del negocio.
- Defaults solo para `SMTP_HOST`/`SMTP_PORT` que son **infra** de Gmail (no
  identidad de TTPN).

Si quieres también esos dos sin default en el futuro, basta con cambiar
`ENV.fetch('SMTP_HOST', 'smtp.gmail.com')` a `ENV.fetch('SMTP_HOST', nil)`
y exigirla explícitamente.
