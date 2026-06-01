# 2026-06-01 — Unificación visual de los correos (templates + layout)

## Contexto

Tras dejar funcionando el SMTP con alias `noreply@ttpn.com.mx`
(`session_notes/2026-06-01_email_config_smtp_gmail.md`), el usuario pidió que
**todos los correos tengan el mismo look**: el patrón que ya tenía
`AsignationMailer` (header rojo TTPN con logo + body blanco + leyenda).

Estado previo:

- `AsignationMailer/send_asignation_mail.html.erb`: HTML autocontenido con CSS
  en `<style>` head (que muchos email clients ignoran). Logo apuntando a
  `http://www.ttpn.com.mx/assets/logo_trazo.png` (HTTP plano, sin verificar) y
  link a `https://admin.ttpn.com.mx` (dominio que no es el real —
  `kumi.ttpn.com.mx`).
- `ClientUserMailer`: solo `activation_email.html.erb` tenía contenido (con su
  propio CSS aparte); los otros 5 eran un único `<p>Hola @client_user.nombre,</p>`
  truncado — los correos llegaban sin cuerpo.
- `Devise::Mailer`: 5 templates por defecto en inglés (`Hello user!`, etc.) sin
  estilo, hereda de `ActionMailer::Base` (no de `ApplicationMailer`).
- Layout `app/views/layouts/mailer.html.erb`: vacío (solo `<%= yield %>`).
- Archivo basura: `send_asignation_mail.html.erb.zip` (backup de 2020).

## Cambios

### 1. Helper compartido `app/helpers/mailer_helper.rb` (nuevo)

Expone a los views:

- `mail_logo_url` → default `https://<MAIL_LINK_HOST>/ttpn_logo.png`. Override
  con `ENV['MAIL_LOGO_URL']`.
- `mail_app_url` → `https://<MAIL_LINK_HOST>`. Para los botones "abrir la app".

Ambos leen de ENV — nada hardcodeado del dominio del negocio.

### 2. `ApplicationMailer` incluye el helper

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: -> { %("#{ENV.fetch('MAIL_FROM_NAME')}" <#{ENV.fetch('MAIL_FROM')}>) }
  helper MailerHelper
  layout 'mailer'
end
```

### 3. Layout `app/views/layouts/mailer.html.erb` (rediseño)

Estructura tipo "card centrado":

- **Header rojo TTPN** (`#DB0D15`, color de marca) con logo centrado en blanco.
- **Body blanco** con padding 32px — aquí va el `<%= yield %>`.
- **Footer azul Kumi** (`#1a237e`) con "Kumi TTPN — Sistema de gestión / Este
  correo se generó automáticamente. No respondas a este mensaje".
- CSS 100% inline en cada `<td>` y `<a>` — compatibilidad universal con email
  clients (Gmail web, Outlook web/desktop, Apple Mail, mobiles).

### 4. Refactor de 12 templates con el mismo patrón

- `AsignationMailer/send_asignation_mail.html.erb` — limpio, sin CSS huge en
  head, link corregido a `mail_app_url` (no `admin.ttpn.com.mx`).
- 6 templates de `ClientUserMailer`:
  - `activation_email.html.erb` (link "Activar mi cuenta" en rojo, info box azul).
  - `activation_confirmed_email.html.erb` (botón "Iniciar sesión").
  - `reset_password_email.html.erb` (botón "Restablecer contraseña").
  - `password_reset_confirmed_email.html.erb` (notif + advertencia).
  - `account_locked_email.html.erb` (advertencia roja + contacto soporte).
  - `account_unlocked_email.html.erb` (botón "Iniciar sesión").
- 5 templates de `Devise::Mailer` (traducidos al español + look unificado):
  - `reset_password_instructions.html.erb`.
  - `unlock_instructions.html.erb`.
  - `password_change.html.erb`.
  - `email_changed.html.erb`.
  - `confirmation_instructions.html.erb` (no se usa hoy — User no tiene
    `:confirmable` — pero queda listo si se activa).

Todos usan el mismo título `h1` azul Kumi (`#1a237e`), botón rojo TTPN con
`border-radius: 6px`, texto secundario gris (`#666`).

### 5. Devise hereda de ApplicationMailer

`config/initializers/devise.rb`:

```ruby
config.parent_mailer = 'ApplicationMailer'
```

Antes era `ActionMailer::Base`. Cambiar el parent hace que `Devise::Mailer`
adopte automáticamente:

- El `default from:` lambda (FROM con alias `noreply@`).
- El `layout 'mailer'` (header + footer).
- El `helper MailerHelper` (mail_logo_url, mail_app_url).

### 6. Cleanup

- Eliminado `app/views/asignation_mailer/send_asignation_mail.html.erb.zip`
  (backup obsoleto de 2020).
- `.env.example`: agregada doc del `MAIL_LOGO_URL` opcional.

## Verificación

Smoke test stage:

```bash
railway environment stage
railway service kumi-admin-api
railway ssh 'bundle exec rails runner "
class SmokeTestMailer < ApplicationMailer
  def smoke(to)
    @unidad = %q(T013); @empleado = %q(Smoke Tester)
    mail(to: to, subject: %q(Smoke test layout), template_name: %q(send_asignation_mail), template_path: %q(asignation_mailer))
  end
end
SmokeTestMailer.smoke(%q(ing.castean@gmail.com)).deliver_now
puts %q(sent)
"'
```

Debe llegar con:

- Header rojo TTPN con logo.
- Título "Nueva asignación de camioneta" azul.
- Link al dominio correcto (`kumi-stage.netlify.app` en stage,
  `kumi.ttpn.com.mx` en prod).
- Footer azul.

## Riesgos y mitigaciones

- **Logo no carga en algunos clients**: si Gmail/Outlook bloquea la imagen
  externa por privacidad, el destinatario ve un placeholder. Es comportamiento
  estándar y el correo se sigue leyendo bien. Si crítico, embebir como base64
  inline (fuera de scope).
- **El logo cambia de URL si cambia `MAIL_LINK_HOST`**: ya está atado al FE.
  Si Netlify cambia su dominio, hay que actualizar `MAIL_LINK_HOST` en Railway.
- **Devise.parent_mailer requiere reiniciar el server**: en local hacer
  `Spring stop && bundle exec rails s` la primera vez tras pull.

## Branch + PR

`fix/mailer-templates-unify` parte de `stage` (no de main) porque incluye el
PR #15 (smtp config) como base. Se mergea a `stage`, se valida con smoke test,
y luego `stage → main`.
