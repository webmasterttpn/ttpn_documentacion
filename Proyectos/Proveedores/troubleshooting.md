# Troubleshooting — Portal de Proveedores

FAQ de errores comunes durante el desarrollo. **Consulta primero
aquí antes de pingear a Antonio.**

---

## Docker

### `Cannot connect to the Docker daemon`

Docker Desktop no está corriendo. Ábrelo (ícono ballena en la barra)
y espera a que aparezca verde.

### `port is already allocated`

Otro proceso usa el puerto. Identifícalo y mátalo:

```bash
lsof -ti:<puerto> | xargs kill -9
```

### `docker compose up` se queda en "Building" eterno

- Verifica conexión a internet (descarga imágenes).
- Cancela (Ctrl+C) y reintenta — a veces hay errores transitorios.
- Si persiste: `docker system prune -af` (BORRA imágenes no usadas
  — solo si tienes confianza).

### El contenedor `kumi_api` reinicia constantemente

```bash
docker compose logs --tail=100 kumi_api
```

Causas comunes:

- **`PG::ConnectionBad`** → PostgreSQL local no corre o credenciales
  mal en `.env`.
- **`Secret key was already initialized`** → reinicia limpio:
  `docker compose down && docker compose up -d`.
- **`Mysql2::Error::ConnectionError`** → no aplica a Kumi, pero si
  ves esto revisa que el `.env` apunte al adapter correcto
  (`postgresql`).

---

## Rails / Backend

### `Could not find gem '<X>' in any of the sources`

Después de tocar `Gemfile`:

```bash
docker compose exec kumi_api bundle install
docker compose restart kumi_api
```

### `Migration version conflict`

Otro dev creó una migration con timestamp similar. Soluciones:

- Re-genera tu migration: borra el archivo y corre
  `rails generate migration <NombreOriginal>` — toma timestamp nuevo.
- Si ya commiteaste: pídele a Antonio que pause su PR mientras
  resuelven (estos conflicts son raros en branches feature).

### `PG::UndefinedColumn` después de cambiar una migration

Las migrations son inmutables una vez aplicadas. Pasos:

```bash
docker compose exec kumi_api bundle exec rails db:rollback
# edita la migration con el cambio
docker compose exec kumi_api bundle exec rails db:migrate
```

Si la migration ya está en `main` (de otra branch), no la modifiques
— crea una migration nueva que altere la tabla.

### `NoMethodError: undefined method 'has_secure_password'`

Falta `bcrypt` en el Gemfile. Está en el `Gemfile` de Kumi por
default — si no está, agrega `gem 'bcrypt'` y bundle install.

### JWT no se decodifica

- Verifica que `Rails.application.secret_key_base` esté configurado.
- En dev se autogenera al primer arranque, pero si lo perdiste:
  `rails secret` y pégalo en `.env`.

---

## Supabase

### 401 al subir un archivo

- ¿Estás usando la `service_role` key? La `anon` da 401.
- Reveal de nuevo desde el dashboard y compárala con tu `.env`.

### 403 al subir

La policy del bucket no incluye `service_role`. Vuelve al
[manual_supabase.md](manual_supabase.md) Paso 3.

### El URL signed expira muy rápido

TTL default es 5 minutos. Si necesitas más para una descarga lenta,
ajusta en el código:

```ruby
signed_download_url(path, ttl: 15.minutes)
```

### Subo PDF pero descargo XML (o viceversa)

Probablemente confundiste el `kind` al construir el path. Verifica:

```ruby
SupplierDocument.create!(kind: 'pdf', ...) # NO 'xml'
```

---

## LetterOpener

### `localhost:3000/letter_opener` da 404

- Verifica que `mount LetterOpenerWeb::Engine, at: '/letter_opener'`
  está dentro del `if Rails.env.development?` en `routes.rb`.
- Reinicia el contenedor: `docker compose restart kumi_api`.

### El correo se manda en lugar de aparecer en la UI

`config.action_mailer.delivery_method = :letter_opener_web` debe
estar en `development.rb`, NO en `production.rb`. Revisa.

### `deliver_later` no muestra nada

Sidekiq procesa `deliver_later` en background. Revisa los logs:

```bash
docker compose logs -f kumi_sidekiq
```

Si Sidekiq no está corriendo, el correo queda en cola. Para tests
manuales usa `deliver_now`.

---

## Quasar / Frontend

### `npm run dev` da `EACCES`

Permisos de la carpeta `node_modules`. Borra y reinstala:

```bash
rm -rf node_modules package-lock.json
npm install
```

### CORS error en el navegador

`Access-Control-Allow-Origin: <origen> is not allowed`. Causas:

- Antonio no agregó tu URL a `FRONTEND_URL_EXTRA` en Railway (prod) o
  no estás corriendo el portal desde un origen permitido (dev).
- En dev: usa `localhost:9001` directamente, no `127.0.0.1:9001`
  (Rails los trata distinto).

### `import.meta.env.VITE_API_URL` es `undefined`

- La variable debe empezar con `VITE_` para que Vite la exponga al
  cliente.
- Cambios en `.env` requieren reiniciar `npm run dev`.

### Quasar plugins no funcionan (Notify, Dialog)

En `quasar.config.js` → `framework.plugins`, asegúrate de que
estén:

```js
framework: {
  plugins: ['Notify', 'Dialog', 'LocalStorage']
}
```

### El PWA no se instala

Revisa `quasar.config.js` → `pwa.manifest`. Tiene que tener nombre,
íconos y `display: standalone`. Build production:

```bash
npm run build
```

Y sirve `dist/spa/` con `npx serve` para probar PWA real (el dev
server no la activa).

---

## Git / GitHub

### Mi push a `main` fue rechazado

Es lo esperado — `main` está protegida. Crea una branch nueva:

```bash
git checkout -b feature/<descripción>
git push -u origin feature/<descripción>
```

Antonio mergea cuando esté listo.

### Tengo cambios sin commitear y necesito cambiar de branch

```bash
git stash
git checkout <otra-branch>
# trabaja
git checkout <branch-original>
git stash pop
```

### `git pull` con conflictos

NO uses `git push --force`. Lee los conflictos en cada archivo
(buscar `<<<<<<<`), resuelve manualmente, `git add`, `git commit`.

Si no entiendes algo del conflicto, avisa a Antonio antes de
forzar nada.

### "Mi remote dice que no existe"

Configura el remote si te falta:

```bash
git remote -v
# si no aparece 'origin' o 'github':
git remote add origin <URL>
```

---

## Auth (portal)

### Login da 401 con credenciales que sé que son válidas

1. Verifica que el usuario está `confirmed_at IS NOT NULL`:

   ```bash
   docker compose exec kumi_api bundle exec rails runner \
     "u = SupplierUser.find_by(email: '<email>'); puts u.confirmed_at"
   ```

2. Verifica que NO está bloqueado:

   ```bash
   docker compose exec kumi_api bundle exec rails runner \
     "u = SupplierUser.find_by(email: '<email>'); puts u.locked? "
   ```

3. Para destrabar en dev:

   ```ruby
   u.unlock!
   ```

### JWT expira al minuto en lugar de 12h

Revisa `generate_jwt` en `SupplierUser`:

```ruby
def generate_jwt(exp = 12.hours.from_now)
  JWT.encode({ ..., exp: exp.to_i }, ...)
end
```

El `exp` debe ser `to_i` (epoch seconds), no `to_s`.

### `Token revocado` después de login normal

El `jti` del JWT no coincide con el del usuario. Causa común: el
usuario hizo logout (que rota el `jti`) y luego intentó usar el JWT
anterior. **Re-loguea**.

---

## Pruebas

### RSpec falla en CI pero pasa local

- Versión de Ruby / Postgres distinta. Usa el `.ruby-version` del
  repo.
- Diferencias de zona horaria. Configura `config.time_zone = 'UTC'`
  en `application.rb`.
- Tests dependientes del orden. Marca el archivo con
  `RSpec.describe ..., order: :defined` solo si es necesario.

### `letter_opener_web` rompe los tests

En `spec_helper.rb` o `rails_helper.rb`:

```ruby
config.before(:each) do
  ActionMailer::Base.delivery_method = :test
end
```

Los tests usan `:test` que captura los emails en
`ActionMailer::Base.deliveries`.

---

## Cuándo SÍ debes pingear a Antonio

- Vulnerabilidad de seguridad (NO hagas PR público).
- Necesitas acceso a un repo / dashboard / variable de entorno.
- El error que ves NO está en este doc Y ya intentaste lo obvio (Google,
  ChatGPT, etc.) por al menos 30 min.
- Tu PR pasa una semana sin review.
- Sospechas que el manual está mal o tiene un paso roto — esto es
  prioridad alta, lo arreglamos en cuanto avisas.

## Cuándo NO

- "No sé qué hacer". Antes intenta:
  1. Leer el error completo (no solo la primera línea).
  2. Buscar el error textual en Google (95% lo resuelve).
  3. Leer este troubleshooting.
  4. Pedirle a Claude en tu propia consola (te ahorra horas).
