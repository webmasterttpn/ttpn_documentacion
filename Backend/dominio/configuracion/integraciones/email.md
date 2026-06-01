# Email — Configuración SMTP con Gmail

Cómo está armado el envío de correos en `ttpngas` (Rails API) y qué hay que
configurar para que funcione en local y en producción.

## Stack

- ActionMailer + Net::SMTP (Rails 7.1 default).
- SMTP relay: Gmail (`smtp.gmail.com:587`, STARTTLS).
- Cuenta real: `webmaster@ttpn.com.mx` autentica con App Password.
- Alias remitente visible: `noreply@ttpn.com.mx` (configurado en la cuenta Gmail
  como "Send mail as").

## Archivos clave

| Archivo | Responsabilidad |
| --- | --- |
| `config/initializers/action_mailer.rb` | Config única dev + prod. SMTP, `default_url_options`, lee TODO de ENV. |
| `app/mailers/application_mailer.rb` | `default from:` con lambda → `"Kumi TTPN" <noreply@ttpn.com.mx>` leído de ENV. |
| `app/mailers/*.rb` | Mailers concretos heredan FROM de `ApplicationMailer`. |
| `config/initializers/devise.rb` | `mailer_sender` lambda → lee `MAIL_FROM` de ENV. |

`config/environments/development.rb` y `production.rb` **no** tienen
`config.action_mailer.*` — todo va por el initializer.

## Variables de entorno

Todas obligatorias (sin defaults para identidad del negocio):

| Variable | Valor ejemplo | Descripción |
| --- | --- | --- |
| `GMAIL_USER` | `webmaster@ttpn.com.mx` | Login real de la cuenta Gmail. |
| `GMAIL_PASSWORD` | `abcd efgh ijkl mnop` | App Password de 16 dígitos (NO la del usuario). |
| `MAIL_FROM` | `noreply@ttpn.com.mx` | Alias remitente. Debe estar verificado en la cuenta como "Send mail as". |
| `MAIL_FROM_NAME` | `Kumi TTPN` | Nombre visible en el inbox del destinatario. |
| `SMTP_DOMAIN` | `ttpn.com.mx` | Dominio HELO del handshake SMTP. |
| `MAIL_LINK_HOST` | `kumi.ttpn.com.mx` (prod) / `localhost` (dev) | Host de los URLs dentro del email. |

Opcionales (defaults técnicos Gmail — solo si cambias proveedor):

| Variable | Default | Descripción |
| --- | --- | --- |
| `SMTP_HOST` | `smtp.gmail.com` | Servidor SMTP. |
| `SMTP_PORT` | `587` | Puerto STARTTLS estándar. |

Sin alguna obligatoria, el primer mail tira `KeyError` con el nombre exacto
de la var faltante. No hay fallback hardcodeado al alias de `info@ttpn.com.mx`
ni a ningún otro identificador del negocio — la decisión es **fail loud** para
evitar mandar correos como una identidad equivocada.

## Cómo generar el App Password en Google

1. La cuenta `webmaster@ttpn.com.mx` debe tener **2-Step Verification** activado.
   `https://myaccount.google.com/security` → Verification in 2 steps.
2. En esa misma página, abrir **App passwords**
   (`https://myaccount.google.com/apppasswords`).
3. App name: `Kumi TTPN`. Generar.
4. Copiar los **16 dígitos** (sin espacios o con espacios, ambos funcionan) y
   pegarlos en `GMAIL_PASSWORD` (Railway en prod, `.env` en dev).
5. El App Password es revocable desde la misma UI si se filtra.

## Cómo configurar el alias `noreply@ttpn.com.mx` en Gmail

En la cuenta `webmaster@ttpn.com.mx`:

1. Gmail → **Settings** (engrane) → **See all settings** → **Accounts and Import**.
2. **Send mail as** → **Add another email address**.
3. Name: `Kumi TTPN`. Email: `noreply@ttpn.com.mx`. **Treat as alias**: marcado.
4. Si pide verificación SMTP del alias, usar `smtp.gmail.com:587` con
   las mismas credenciales (la App Password) — Gmail valida que el alias puede
   salir desde la misma cuenta.
5. Google manda un correo de verificación al alias (que en este caso entra al
   mismo buzón vía MX). Hacer clic al link de confirmación.
6. El alias queda listado en "Send mail as". A partir de aquí, ActionMailer
   puede usar el alias en el header `From:`.

Si el alias **no está verificado** Gmail rechaza con `530 5.7.0 Authentication
required` o reemplaza el `From:` por la cuenta real al entregar.

## Mailers existentes

| Mailer | Métodos | Disparado por | Modo |
| --- | --- | --- | --- |
| `ClientUserMailer` | `activation_email`, `activation_confirmed_email`, `reset_password_email`, `password_reset_confirmed_email`, `account_locked_email`, `account_unlocked_email` | Callbacks de `ClientUser` (after_create, etc.) | `deliver_later` (Sidekiq) |
| `AlertMailer` | `alert_notification` | `Services::Alerts::EmailSenderService` | `deliver_now` |
| `AsignationMailer` | `send_asignation_mail` | `VehicleAsignation` callback | `deliver_now!` |
| `Devise::Mailer` | `reset_password_instructions`, etc. | `User#send_reset_password_instructions` | `deliver_now` |

## Smoke test

### Local (`bundle exec rails console`)

```ruby
ActionMailer::Base.mail(
  to: 'ing.castean@gmail.com',
  subject: 'smoke test SMTP dev',
  body: 'Funciona desde dev'
).deliver_now
```

Si las vars están bien, el correo llega con `From: "Kumi TTPN"
<noreply@ttpn.com.mx>` y `Reply-To` igual. Si falta una var, ves un `KeyError`
con el nombre exacto.

### Producción

```bash
railway ssh --service kumi-admin-api 'bundle exec rails runner "
  ActionMailer::Base.mail(
    to: \"ing.castean@gmail.com\",
    subject: \"smoke test prod SMTP\",
    body: \"Email desde Kumi TTPN production\"
  ).deliver_now
  puts \"OK\"
"'
```

## Troubleshooting

| Síntoma | Causa probable | Fix |
| --- | --- | --- |
| `Net::SMTPAuthenticationError 535-5.7.8 Username and Password not accepted` | App Password incorrecto o expirado. | Regenerar en `https://myaccount.google.com/apppasswords` y actualizar `GMAIL_PASSWORD`. |
| `Net::SMTPFatalError 530 5.7.0 Authentication required` | Alias no verificado en "Send mail as". | Verificar el alias en Gmail Settings. |
| El destinatario ve `From: webmaster@ttpn.com.mx` (no el alias) | Gmail reemplazó el header porque el alias no está autorizado. | Marcar "Treat as alias" en Send mail as. |
| `KeyError: key not found: "MAIL_FROM"` (u otra var) | La variable de entorno falta. | Configurar en Railway / `.env`. |
| `ArgumentError: Missing host to link to!` | `MAIL_LINK_HOST` no configurado. | Setear en Railway / `.env`. |
| El correo llega a spam | `noreply@` sin SPF/DKIM válidos para el dominio. | Ajustar registros DNS de `ttpn.com.mx` (SPF incluyendo Google) y configurar DKIM en Google Workspace. Fuera del scope inmediato. |

## Rate limit

Cuentas Gmail personales: ~500 correos/día como remitente.
Cuentas Google Workspace: ~2000/día.
Si el volumen crece, migrar a SendGrid/Postmark — el cambio es solo `SMTP_HOST`,
`SMTP_PORT`, `GMAIL_USER`, `GMAIL_PASSWORD` (y el initializer no requiere
modificación porque ya lee todo de ENV).
