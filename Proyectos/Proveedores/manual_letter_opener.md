# Manual — LetterOpener para correos en desarrollo

> **Audiencia**: dev que necesita probar flujos de email (confirmación,
> reset password, bloqueo de cuenta) sin tener SMTP configurado.
> **Resultado**: cualquier correo que Rails intente mandar aparece
> automáticamente en `http://localhost:3000/letter_opener` con la UI
> de la gem.
> **Tiempo**: 10 min.

## Por qué LetterOpener

- En **producción** Kumi usará Google Workspace SMTP (o similar) — TBD.
- En **desarrollo** no quieres mandar correos reales a tu cuenta
  personal cada vez que pruebas el flujo de "olvidé mi contraseña".
- `letter_opener_web` intercepta los correos y los muestra como una
  bandeja de entrada en una URL local. **Cero configuración SMTP**,
  cero spam.

## Paso 1 — Agregar la gem al Gemfile

### Por qué

Es una gem solo para development. Producción no la lleva.

### Cambio

`ttpngas/Gemfile`:

```ruby
group :development do
  # ... gems existentes
  gem 'letter_opener_web', '~> 3.0'
end
```

### Reconstruir el bundle

Como las gems viven dentro del contenedor:

```bash
docker compose exec kumi_api bundle install
docker compose restart kumi_api
```

### Salida esperada

```text
Resolving dependencies...
Fetching letter_opener-1.10.0
Installing letter_opener-1.10.0
Fetching letter_opener_web-3.0.0
Installing letter_opener_web-3.0.0
Bundle complete!
```

### Si falla

- **`Could not find gem 'letter_opener_web'`** → revisa el `Gemfile`,
  asegúrate de que esté dentro del bloque `:development`.
- **`Bundler::GemfileNotFound`** → estás corriendo el comando fuera
  del contenedor. Antepón `docker compose exec kumi_api`.

---

## Paso 2 — Configurar ActionMailer en development

### Cambio

`ttpngas/config/environments/development.rb`:

Busca la sección de `action_mailer` (cerca del fondo) o agrega al
final del bloque `Rails.application.configure do`:

```ruby
# Letter Opener — los correos en dev se abren en localhost:3000/letter_opener
config.action_mailer.delivery_method = :letter_opener_web
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
config.action_mailer.raise_delivery_errors = true
```

### Por qué cada línea

| Línea | Qué hace |
|---|---|
| `delivery_method = :letter_opener_web` | Intercepta correos en lugar de mandarlos por SMTP |
| `perform_deliveries = true` | Activa el "envío" (sin esto, ni siquiera intercepta) |
| `default_url_options = { host: 'localhost', port: 3000 }` | Genera URLs absolutas en los emails con `localhost:3000` (en prod cambia a tu dominio) |
| `raise_delivery_errors = true` | Si algo falla en el mailer, levanta excepción visible en logs (no la traga en silencio) |

---

## Paso 3 — Montar la UI de LetterOpener en las rutas

### Cambio

`ttpngas/config/routes.rb`. Agrega al inicio del bloque
`Rails.application.routes.draw do`:

```ruby
Rails.application.routes.draw do
  # Letter Opener en development — bandeja de entrada local
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end

  # ... resto de las rutas existentes ...
end
```

### Reinicia el contenedor

```bash
docker compose restart kumi_api
```

### Verificación

Abre en tu navegador: <http://localhost:3000/letter_opener>

Debes ver una UI vacía con texto "There are no messages yet".

### Si falla

- **`uninitialized constant LetterOpenerWeb`** → la gem no se cargó.
  Repite el Paso 1.
- **404 en `/letter_opener`** → la ruta no se montó (revisa que
  esté dentro del `Rails.application.routes.draw`).
- **500 con `LoadError`** → reinicia el contenedor (a veces no
  detecta gems nuevas hasta el reinicio).

---

## Paso 4 — Probar el flujo con un mailer dummy

### Por qué

Antes de tocar mailers del portal, verifica que LetterOpener
funciona en general.

### Comando

```bash
docker compose exec kumi_api bundle exec rails console
```

Dentro de la consola:

```ruby
ActionMailer::Base.mail(
  from: 'no-reply@kumi.local',
  to: 'test@example.com',
  subject: 'Hola desde LetterOpener',
  body: 'Si ves esto en localhost:3000/letter_opener, está funcionando.'
).deliver_now
```

### Salida esperada

```text
Delivered mail abc123@kumi.local (15.4ms)
=> #<Mail::Message ...>
```

Inmediatamente, abre <http://localhost:3000/letter_opener> en el
navegador — debes ver el correo en la lista.

### Si falla

- **`Net::SMTPAuthenticationError`** → no aplicó la configuración.
  Verifica que `config.action_mailer.delivery_method =
  :letter_opener_web` está en `development.rb` (no en
  `production.rb` por error).
- **La consola dice OK pero no aparece en la UI** → reinicia el
  contenedor y vuelve a la consola.

---

## Paso 5 — Workflow recomendado durante desarrollo

> Mientras desarrollas flujos con email (confirmación, reset, etc.):

1. Ten **dos tabs** del navegador abiertos siempre:
   - Tab A: el flujo que estás probando (ej. el Admin de Kumi creando
     un supplier_user).
   - Tab B: <http://localhost:3000/letter_opener> (la bandeja).
2. Cuando dispares la acción (ej. crear usuario), refresca Tab B —
   el email aparece arriba de la lista.
3. **Click al correo** para ver el HTML renderizado.
4. **Click a los links del email** — abren en tu navegador y prueban
   el flujo completo (ej. el link de confirmación lleva al portal).

### Pro tip — limpiar bandeja

En la UI hay un botón "Clear All" arriba a la derecha. Úsalo entre
tests para no confundirte con correos viejos.

---

## Paso 6 — Producción (TBD)

> **No hagas nada de esto todavía**. Es referencia para cuando
> Antonio decida qué SMTP usar.

Cuando se defina, en `production.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:              ENV.fetch('SMTP_HOST'),
  port:                 ENV.fetch('SMTP_PORT', 587).to_i,
  user_name:            ENV.fetch('SMTP_USERNAME'),
  password:             ENV.fetch('SMTP_PASSWORD'),
  authentication:       :plain,
  enable_starttls_auto: true,
  domain:               ENV.fetch('SMTP_DOMAIN', 'kumi.com')
}
config.action_mailer.default_url_options = {
  host: ENV.fetch('PORTAL_PROVEEDORES_URL').sub(%r{^https?://}, ''),
  protocol: 'https'
}
```

Y en Railway se agregan los secretos (`SMTP_HOST`, `SMTP_USERNAME`,
`SMTP_PASSWORD`, `SMTP_DOMAIN`, `PORTAL_PROVEEDORES_URL`).

LetterOpener se queda **solo en development** — el `if
Rails.env.development?` en `routes.rb` y el config en
`development.rb` lo aíslan.

---

## Checklist final

- [ ] `letter_opener_web` aparece en `Gemfile.lock`
- [ ] `development.rb` tiene los 4 settings de `action_mailer`
- [ ] `routes.rb` monta `LetterOpenerWeb::Engine` dentro del
  `if Rails.env.development?`
- [ ] `http://localhost:3000/letter_opener` carga sin error
- [ ] El correo dummy del Paso 4 aparece en la UI

---

## Siguiente paso

→ [manual_backend.md](manual_backend.md) — construir el backend.
