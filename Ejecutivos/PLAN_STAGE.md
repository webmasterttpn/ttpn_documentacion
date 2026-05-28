# Plan — Levantar entorno de Staging (stage.ttpn.com.mx)

> **Estado:** **PAUSADO.** Documento de plan listo para ejecutar más adelante.
> Primero priorizamos arreglar bugs y completar features en producción.
>
> **Avances ya aplicados a prod** (no hay que rehacerlos):
>
> - ✅ FE: `quasar.config.js` env-driven (respeta `process.env.API_URL` siempre).
> - ✅ FE: `netlify.toml` creado (PWA build + env por contexto production/stage).
> - ✅ FE: switch del repo en Netlify de GitLab → GitHub (2026-05-28).
>   El FE ahora solo necesita push a `github main`.
> - ✅ BE: `system_maintenance#run_tasks` protegido con `X-Maintenance-Token`.
> - ✅ BE: Sidekiq Web con HTTP Basic Auth (SIDEKIQ_USER/PASSWORD).
> - ✅ BE: ruta `/api/v1/system_maintenance/run_tasks` corregida (apuntaba mal).
> - ✅ Env vars de hardening (MAINTENANCE_TOKEN, SIDEKIQ_USER, SIDEKIQ_PASSWORD)
>   configuradas en Railway de prod (api + sidekiq).
> - ✅ Doc `PASOS_TRAS_MIGRACION.md` con header `X-Maintenance-Token` en los cURL.

## 1. Contexto y objetivo

Hoy todo (Supabase + Netlify + Railway) es producción: `kumi.ttpn.com.mx`. Queremos
un **stage aislado en la nube** para:

- Probar cambios antes de subirlos a producción.
- Que un colega desarrolle un repo PHP que apunte a una **DB de stage**, sin riesgo
  de tocar prod.
- Tener una copia restaurada del respaldo de prod para validar migraciones y QA.

El plan está dividido en **lo que hace Claude (código + git)** y **lo que hace el
usuario en dashboards** (Supabase, Railway, Netlify, DNS). Está diseñado para que
cuando llegue el día solo sea: ejecutar Parte A/B/C automáticas, seguir el runbook
del Anexo en los dashboards, y subir el respaldo.

## 2. Decisiones acordadas

- **Stage FE**: `stage.ttpn.com.mx` (Netlify nuevo).
- **Stage API**: URL de Railway directamente (`kumi-admin-api-staging.up.railway.app`),
  sin DNS propio por ahora.
- **Stage DB**: proyecto **Supabase aparte** (instancia aislada).
- **Git**: `main` = producción (Railway prod deploya de `main` cuando esté listo).
  Rama `stage` = staging (Railway/Netlify de stage deployan de `stage`).
- **Filtrado del código**: dejar el código *env-driven* para que la misma rama sirva
  prod o stage solo cambiando variables de entorno.

## 3. Hallazgo clave del análisis

El código actual **hardcodea URLs de producción** en 4 lugares; sin arreglarlos, un
deploy de stage apuntaría a la API de prod o bloquearía el WebSocket:

1. `ttpngas/config/application.rb` — `allowed_request_origins` de ActionCable es una
   lista fija con `kumi.ttpn.com.mx`. Hay que volverla env-driven (lee `FRONTEND_URL`
   + `FRONTEND_URL_EXTRA`).
2. `ttpngas/config/environments/production.rb` — `config.hosts` whitelist incluye
   solo `kumi.ttpn.com.mx` + el dominio Railway de prod. Hay que agregar
   `config.hosts << ENV['RAILWAY_PUBLIC_DOMAIN']` (Railway lo provee).
3. `ttpn-frontend/quasar.config.js` — el build de prod **ignora** `process.env.API_URL`
   y usa una constante `PROD_API_URL`. Hay que cambiarlo a
   `process.env.API_URL || (ctx.prod ? PROD_API_URL : 'http://localhost:3000')` para
   que stage pueda fijar `API_URL` distinto sin tocar código.
4. `ttpn-frontend/public/_headers` — CSP `connect-src` hardcodea solo la API de
   prod. Hay que agregar la API/WS de stage.

### Restricción del plan gratuito de Netlify (importante)

El plan gratuito de Netlify **NO permite crear env vars en el dashboard** (es
feature de team / planes de pago). Por eso el FE de stage NO puede fijar `API_URL`
desde el panel. La solución es **`netlify.toml` con env por contexto**, que sí
funciona en gratis (es build-time, no team feature):

```toml
# ttpn-frontend/netlify.toml — root del repo
[build]
  command = "npm ci && npm run build"
  publish = "dist/spa"

[context.production.environment]
  API_URL = "https://kumi-admin-api-production.up.railway.app"
  VITE_WS_URL = "wss://kumi-admin-api-production.up.railway.app"

[context.stage.environment]
  API_URL = "https://kumi-admin-api-staging.up.railway.app"
  VITE_WS_URL = "wss://kumi-admin-api-staging.up.railway.app"
```

Netlify inyecta `process.env.API_URL` durante el build según el contexto (`main` →
production, rama `stage` → context "stage"). Combinado con el blindaje del
`quasar.config.js`, cada sitio queda apuntando correctamente sin tocar dashboard.

### Hardening de prod (ya implementado en código — solo falta env vars)

Ambos están **aplicados en el código** (commits separados); para que entren en vigor
en prod, configurar las env vars en Railway:

- **`MAINTENANCE_TOKEN`**: el endpoint `POST /system_maintenance/run_tasks` exige el
  header `X-Maintenance-Token: <valor>`. Si la env está vacía en prod → el endpoint
  responde 503. Sin coincidencia → 401. Los cURL del runbook
  `PASOS_TRAS_MIGRACION.md` ya están actualizados con el header.
- **`SIDEKIQ_USER` / `SIDEKIQ_PASSWORD`**: Sidekiq Web (`/sidekiq`) ahora usa HTTP
  Basic Auth con `Rack::Auth::Basic` (`secure_compare`). El intento de proteger con
  `authenticate :user, sadmin?` (Devise) **no funcionaba** porque la app es
  `api_only = true` (sin sessions Devise). Sin las env en prod, Basic Auth deniega
  TODO acceso.

⚠️ **Tras desplegar este hardening, configurar de inmediato las 3 env vars en el
servicio API de Railway de PROD**: `MAINTENANCE_TOKEN`, `SIDEKIQ_USER`,
`SIDEKIQ_PASSWORD`. Para stage, las mismas (o distintas) cuando se levante.

## 4. Plan ejecutable (cuando se reanude)

### Parte A — Blindaje de código (Claude lo hace, en commits separados por tema)

**Backend (`ttpngas`):**

- `config/application.rb`: ActionCable `allowed_request_origins` env-driven
  (lee `FRONTEND_URL` + `FRONTEND_URL_EXTRA` + mantiene defaults actuales).
- `config/environments/production.rb`: agregar
  `config.hosts << ENV['RAILWAY_PUBLIC_DOMAIN'] if ENV['RAILWAY_PUBLIC_DOMAIN']`.
- `app/controllers/api/v1/system_maintenance_controller.rb`: proteger con header
  `X-Maintenance-Token` comparado contra `ENV['MAINTENANCE_TOKEN']` (si la env no
  está, se mantiene el comportamiento abierto — backward compatible).
- `.env.example`: documentar las variables nuevas.

**Frontend (`ttpn-frontend`):**

- ✅ `quasar.config.js`: env-driven (ya aplicado en commit `72c51ad`).
- ✅ `netlify.toml`: env por contexto production/stage (ya aplicado, igual commit).
- ⏳ `public/_headers`: agregar `https://kumi-admin-api-staging.up.railway.app` y
  su `wss://...` al `connect-src` del CSP (pendiente cuando levantemos stage).
- ⏳ `.env.example`: documentar `API_URL` y `VITE_WS_URL` (pendiente).

Cada cambio preserva el comportamiento actual de prod (defaults). Tras pushear,
verificar manualmente que `kumi.ttpn.com.mx` sigue funcionando idéntico.

### Parte B — Reestructura de git (Claude)

- **ttpngas**:
  - Fast-forward `main` ← `transform_to_api` (main está 0 commits adelante, así que
    es ff limpio).
  - Push `main` a github.
  - Crear rama `stage` desde `main` y push.
  - Dejar `transform_to_api` por ahora (se retira más tarde, cuando Railway prod
    deploye de `main`).
  - Checkout local a `main` para trabajo futuro.
- **ttpn-frontend**:
  - Crear rama `stage` desde `main` y push a **origin (GitLab)** + **github**.
  - El sitio Netlify de stage construirá de la rama `stage` de GitLab.

### Parte C — Deploy + verificación de PROD (Claude)

- Push de los cambios de blindaje al canal actual.
- Verificar que `kumi.ttpn.com.mx` no regresiona: carga, login, WebSocket de alertas,
  sin errores en consola.
- **Acción manual del usuario** (Railway dashboard): apuntar el servicio de prod a
  la rama `main` (hoy toma `transform_to_api`). Confirmar también que Netlify prod
  toma de GitLab `origin/main` (Site settings → Build & deploy → Production branch).

### Parte D — Runbook STAGE (usuario + colega, ver Anexo)

Crear los recursos cloud y conectarlos. **Sin código nuevo**: solo dashboards y
DNS. Ver Anexo abajo.

## 5. Resumen de archivos a tocar (Claude, al reanudar)

| Repo | Archivo | Cambio |
|---|---|---|
| ttpngas | `config/application.rb` | ActionCable origins env-driven |
| ttpngas | `config/environments/production.rb` | hosts += RAILWAY_PUBLIC_DOMAIN |
| ttpngas | `app/controllers/api/v1/system_maintenance_controller.rb` | ✅ **Ya hecho**: header `X-Maintenance-Token` |
| ttpngas | `config/routes.rb` | ✅ **Ya hecho**: Sidekiq Web via HTTP Basic Auth (SIDEKIQ_USER/PASSWORD) |
| ttpngas | `.env.example` | Documentar `FRONTEND_URL_EXTRA`, `MAINTENANCE_TOKEN`, `SIDEKIQ_USER`, `SIDEKIQ_PASSWORD` |
| ttpn-frontend | `quasar.config.js` | apiUrl/wsUrl respetan env en prod |
| ttpn-frontend | `netlify.toml` (nuevo) | Env por contexto (production / stage) — sustituye dashboard |
| ttpn-frontend | `public/_headers` | CSP allow stage API/WS |
| ttpn-frontend | `.env.example` | Documentar variables |
| Documentación | `Documentacion/INFRA/migracion/SETUP_STAGE.md` | Copiar Anexo de abajo como guía operativa |
| Documentación | `Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md` | ✅ **Ya hecho**: cURL con `X-Maintenance-Token: $MAINT_TOKEN` |

## 6. Verificación

- **Prod (tras Parte C)**: `kumi.ttpn.com.mx` carga, login OK, WebSocket OK, sin
  regresiones. RuboCop 0, ESLint 0, build limpio.
- **Stage (cuando se ejecute el runbook)**: el FE de stage carga contra la API de
  stage, login y WS OK, escrituras del PHP del colega caen en la DB de stage, prod
  intacta (DB y almacenamiento separados).

---

# Anexo — Runbook detallado de levantamiento de STAGE (cero supuestos)

> Esta es la guía operativa que ejecuta el usuario (con/sin Claude) en los
> dashboards de Supabase, Railway y Netlify. Pensada para que la siga alguien que
> **no conoce** git, Supabase, Railway o Netlify. Copiar + pegar.

## A.0 Glosario rápido

- **Producción (prod)**: lo que tus usuarios ven hoy en `kumi.ttpn.com.mx`.
- **Stage**: copia de prod en otra base de datos y otros servidores, para probar.
  Vivirá en `stage.ttpn.com.mx`.
- **Supabase**: aloja la base de datos PostgreSQL.
- **Railway**: corre la API de Rails + Sidekiq + Redis.
- **Netlify**: sirve el sitio web (frontend Vue/Quasar).
- **GitHub / GitLab**: donde vive el código. Railway lee de GitHub; Netlify lee de
  GitLab.
- **Rama (branch) de git**: una "línea" del código. `main` = producción; `stage`
  = staging.
- **Env var (variable de entorno)**: un valor (texto) que cada servicio guarda
  fuera del código.

## A.1 Pre-requisitos (Claude ya hizo esto si se ejecutó Parte A/B/C)

- En GitHub `webmasterttpn/kumi-admin-api` ves dos ramas: `main` y `stage`.
- En GitHub `webmasterttpn/kumi-admin-frontend` ves dos ramas: `main` y `stage`.
- En GitLab `TTPN_Antonio/ttpn-frontend` ves dos ramas: `main` y `stage`.

Si no, ejecutar Partes A + B + C antes.

## A.2 Crear el proyecto de Supabase (stage)

1. Abrir <https://supabase.com/dashboard>.
2. Seleccionar la **organización** donde está el proyecto de prod.
3. Clic en **New project**.
4. Formulario:
   - **Name**: `ttpngas-stage`.
   - **Database password**: generar fuerte (botón "Generate"). **Guardar en gestor
     de contraseñas.**
   - **Region**: misma que prod.
   - **Pricing plan**: el más bajo (Free).
5. Clic en **Create new project**. Tarda 1–2 minutos.
6. **Project Settings → Database**.
7. **Connection string → tab URI → modo Transaction** (pooler con pgbouncer,
   compatible con Rails).
8. Copiar la URL. Va a verse como:
   `postgresql://postgres.xxxxx:[YOUR-PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres`
   - Reemplazar `[YOUR-PASSWORD]` por la contraseña real.
   - Guardar como `DATABASE_URL_STAGE` en el gestor de contraseñas.
9. **NO subir el respaldo todavía** — primero los servicios para que cuando llegue
   el restore todo apunte correctamente.

## A.3 Crear el proyecto de Railway (stage)

Railway correrá 3 cosas: la **API de Rails**, **Sidekiq** y **Redis**.

### A.3.1 Crear proyecto y servicio de la API

1. Abrir <https://railway.app/dashboard>.
2. Clic en **New Project → Deploy from GitHub repo**.
3. Autorizar la organización si pide.
4. Seleccionar **`webmasterttpn/kumi-admin-api`**.
5. Railway crea el proyecto. Renombrarlo:
   - **Project Settings → Name** → `kumi-stage`.
   - Sobre el servicio → ⚙ Settings → **Service Name** → `api`.
6. Configurar rama:
   - **Settings → Source → Branch**: `stage`.

### A.3.2 Agregar Redis

1. En el canvas, **+ Add a service → Database → Add Redis**.
2. Railway le crea una variable `REDIS_URL` privada al proyecto.

### A.3.3 Agregar servicio de Sidekiq

Sidekiq usa la MISMA imagen Docker que la API, pero con otro comando.

1. **+ → GitHub Repo → `webmasterttpn/kumi-admin-api`** otra vez.
2. Renombrar a **`sidekiq`**.
3. **Settings → Source → Branch**: `stage`.
4. **Settings → Deploy → Custom Start Command**:
   `bundle exec sidekiq -C config/sidekiq.yml`
5. **Settings → Networking**: dejarlo **privado** (sin dominio público). Sidekiq no
   recibe HTTP.

### A.3.4 Variables de entorno (API y Sidekiq, las mismas)

Para cada servicio: clic → tab **Variables** → **+ New Variable** (o RAW Editor).

```env
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5

SECRET_KEY_BASE=<generar 64 bytes hex; ver abajo>
RAILS_MASTER_KEY=<el master.key del repo; copiarlo del local, NO subirlo a git>

DATABASE_URL=<el DATABASE_URL_STAGE de Supabase, paso A.2>
REDIS_URL=${{Redis.REDIS_URL}}

FRONTEND_URL=https://stage.ttpn.com.mx
FRONTEND_URL_EXTRA=

AWS_ACCESS_KEY_ID=<IAM del bucket S3 de stage>
AWS_SECRET_ACCESS_KEY=<IAM secret>
AWS_REGION=us-east-2
AWS_BUCKET=ttpngas-staging

GMAIL_USER=<vacío o buzón de pruebas>
GMAIL_PASSWORD=<vacío o App Password del buzón de pruebas>

N8N_WEBHOOK_URL=<vacío o n8n de stage cuando exista>

WHATSAPP_API_URL=
WHATSAPP_API_TOKEN=
WHATSAPP_WEBHOOK_SECRET=
WHATSAPP_VERIFY_TOKEN=

MAINTENANCE_TOKEN=<generar 32 bytes hex; ver abajo>
SIDEKIQ_USER=admin
SIDEKIQ_PASSWORD=<generar 24 bytes hex; ver abajo>

PYTHON_BIN=python3
LOG_LEVEL=INFO
```

**Cómo generar SECRET_KEY_BASE / MAINTENANCE_TOKEN / SIDEKIQ_PASSWORD:**

```bash
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'  # SECRET_KEY_BASE
ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'  # MAINTENANCE_TOKEN
ruby -rsecurerandom -e 'puts SecureRandom.hex(24)'  # SIDEKIQ_PASSWORD
```

**Notas:**

- `RAILS_MASTER_KEY`: copiar literal de `ttpngas/config/master.key` del local. Es
  el mismo de prod — generar uno nuevo rompería el descifrado de `credentials.yml.enc`.
- `DATABASE_URL`: el de Supabase **stage** (A.2), NUNCA el de prod.
- `REDIS_URL=${{Redis.REDIS_URL}}` es referencia al servicio Redis del proyecto.
- `AWS_BUCKET`: idealmente crear `ttpngas-staging` aparte (ver A.4). Si por urgencia
  reutilizas el de prod, los archivos se mezclan.
- `FRONTEND_URL=https://stage.ttpn.com.mx`: aunque el dominio aún no apunte a
  Netlify (A.6), igual ponerlo — CORS y ActionCable lo necesitan al arrancar.

### A.3.5 Verificar que la API levantó

1. Servicio `api` → **Deployments**. Debe pasar a "Active".
2. **Settings → Networking → Public Networking** → **Generate Domain**. Anotar la
   URL (algo como `kumi-admin-api-staging.up.railway.app`).
3. Abrir esa URL `/up`. Debe responder `200`.
4. Las tablas ya existen (el contenedor corre `db:prepare` al arrancar). El respaldo
   se sube en A.7.

## A.4 (Opcional) S3 bucket de stage

1. Abrir <https://s3.console.aws.amazon.com>.
2. **Create bucket** → `ttpngas-staging`, misma región que prod, bloqueos públicos
   activados.
3. Crear usuario IAM nuevo con permisos solo sobre ese bucket
   (`s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`).
4. Pegar `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` en las variables de Railway.

Si no se hace ahora, dejar `AWS_BUCKET` apuntando a prod temporalmente, asumiendo
la mezcla.

## A.5 Crear el sitio de Netlify (stage)

> El plan gratuito de Netlify NO permite env vars en el dashboard, **pero no se
> necesita** — el `netlify.toml` (Parte A) las inyecta automáticamente según el
> contexto (rama `stage` → `[context.stage.environment]`).

1. <https://app.netlify.com> → **Add new site → Import an existing project**.
2. **Deploy with GitLab** → autorizar si pide.
3. Seleccionar **`TTPN_Antonio/ttpn-frontend`**.
4. Configuración:
   - **Branch to deploy**: `stage`.
   - **Base directory**: vacío.
   - **Build command**: `npm ci && npm run build`.
   - **Publish directory**: `dist/spa`.
5. **Site settings → General → Site name** → `kumi-stage`.
6. **Deploys → Trigger deploy → Clear cache and deploy site**.

El sitio queda en `https://kumi-stage.netlify.app`. Abrirlo: el login debe cargar y,
al intentar loguearte (con un usuario de la DB de stage que aún no hay datos), debe
hablarle al API de stage (DevTools → Network → la petición a `/auth` sale al
dominio Railway de stage; no a prod).

## A.6 DNS de stage.ttpn.com.mx

1. En Netlify (sitio stage) → **Domain management → Add domain** → `stage.ttpn.com.mx`.
2. Netlify indica el target del CNAME (`kumi-stage.netlify.app` o similar).
3. En tu DNS (Cloudflare, GoDaddy, etc.) **Add record**:
   - Type: **CNAME**
   - Name/Host: `stage`
   - Value/Target: `kumi-stage.netlify.app`
   - TTL: `300` (5 min).
4. Esperar 5–15 min. Netlify emite SSL automático (Let's Encrypt). Verás "✅ HTTPS".
5. Visitar `https://stage.ttpn.com.mx`. Debe cargar.

## A.7 Subir el respaldo a la DB de stage

### A.7.1 Generar el respaldo de prod (solo lectura — no toca prod)

```bash
pg_dump \
  --no-owner --no-privileges \
  --format=custom \
  --file=ttpngas-prod-$(date +%Y%m%d).dump \
  "<DATABASE_URL_DE_PROD>"
```

Reemplazar `<DATABASE_URL_DE_PROD>` por el connection string del Supabase de **prod**.

### A.7.2 Restaurar en stage

```bash
pg_restore \
  --no-owner --no-privileges \
  --clean --if-exists \
  --dbname="<DATABASE_URL_STAGE>" \
  ttpngas-prod-YYYYMMDD.dump
```

Reemplazar `<DATABASE_URL_STAGE>` por el de Supabase **stage**. El `--clean
--if-exists` borra las tablas vacías que `db:prepare` creó al arrancar Railway y
restaura el dump encima.

### A.7.3 Post-restauración (MUY IMPORTANTE)

Las secuencias de PK quedan atrasadas tras el restore. Sincronizar y aplicar
backfills:

```bash
curl -X POST https://<API_STAGE>/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -H "X-Maintenance-Token: <MAINTENANCE_TOKEN>" \
  -d '{"task": "all"}'
```

Reemplazar `<MAINTENANCE_TOKEN>` por el valor que pusiste en Railway (A.3.4) y
`<API_STAGE>` por la URL de Railway de stage (A.3.5).

Esto corre: backfill de tablas con BU/auditoría, separación de nombres de
concesionarios, init de módulos/privilegios v2, y **reset_sequences** al final.

Detalles en `Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md`.

## A.8 Compartir credenciales con el colega del PHP

Por canal seguro (1Password / Bitwarden — **NUNCA email**):

- `DATABASE_URL_STAGE` (de Supabase stage, A.2).
- Advertencia explícita: **el repo PHP nunca debe apuntar a la DB de prod.** Que
  valide la URL antes de cada cambio.

Preferir el **pooler** (`...pooler.supabase.com:6543`) también para el PHP, salvo
que su ORM no soporte pgbouncer.

## A.9 Verificación end-to-end

1. `https://stage.ttpn.com.mx` carga.
2. Login con un usuario real del respaldo.
3. Una pantalla con datos (Vehículos, Empleados, Asignaciones) muestra los registros.
4. Crear una asignación nueva en stage → guarda sin error (las secuencias quedaron
   sincronizadas).
5. DevTools → Network: las peticiones salen al dominio Railway de stage, NUNCA al
   de prod.
6. Abrir `https://kumi.ttpn.com.mx` (prod): idéntico, sin cambios.
7. PHP del colega conecta a stage; INSERT desde PHP aparece en stage (no en prod).

## A.10 Apéndices

### A.10.1 Variables canónicas — API/Sidekiq stage

`RAILS_ENV`, `RAILS_LOG_TO_STDOUT`, `RAILS_MAX_THREADS`, `SECRET_KEY_BASE`,
`RAILS_MASTER_KEY`, `DATABASE_URL`, `REDIS_URL`, `FRONTEND_URL`,
`FRONTEND_URL_EXTRA`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`AWS_BUCKET`, `GMAIL_USER`, `GMAIL_PASSWORD`, `N8N_WEBHOOK_URL`,
`WHATSAPP_API_URL`, `WHATSAPP_API_TOKEN`, `WHATSAPP_WEBHOOK_SECRET`,
`WHATSAPP_VERIFY_TOKEN`, `MAINTENANCE_TOKEN`, `SIDEKIQ_USER`, `SIDEKIQ_PASSWORD`,
`PYTHON_BIN`, `LOG_LEVEL`.

### A.10.1.bis Variables a configurar AHORA en Railway de PROD (urgente)

Tras el deploy del hardening (commit del Sidekiq Basic Auth + token de
mantenimiento), estos 3 deben estar puestos en el servicio `api` (y en `sidekiq`
si tiene su propia env):

- `MAINTENANCE_TOKEN` — generar con `ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'`.
- `SIDEKIQ_USER` — `admin` está bien.
- `SIDEKIQ_PASSWORD` — generar con `ruby -rsecurerandom -e 'puts SecureRandom.hex(24)'`.

Si no se configuran, el endpoint `/system_maintenance/run_tasks` responde 503 y
`/sidekiq` queda inaccesible. Eso es **intencional** (mejor inaccesible que
expuesto). Configurar y reiniciar el servicio.

### A.10.2 Variables — Netlify stage

`API_URL`, `VITE_WS_URL`.

### A.10.3 Troubleshooting común

- **"Blocked host" al abrir la API de stage**: la env `RAILWAY_PUBLIC_DOMAIN` no
  llegó a tiempo. Re-deploy del servicio.
- **CORS error desde `stage.ttpn.com.mx`**: verificar que
  `FRONTEND_URL=https://stage.ttpn.com.mx` sea exacto (sin slash final, https con s).
- **WebSocket no conecta**: revisar `VITE_WS_URL` en Netlify y que `FRONTEND_URL`
  en Railway coincida con el sitio real.
- **`PG::UniqueViolation ... _pkey` al crear desde stage**: el reset_sequences no
  corrió. Repetir el cURL de A.7.3 con `{"task":"reset_sequences"}`.
- **401 al disparar el cURL de mantenimiento**: token mal puesto. Verificar header
  `X-Maintenance-Token` y que coincida con Railway.

### A.10.4 Cuándo retirar la rama `transform_to_api`

Una vez que Railway prod despliegue de `main` y esté estable durante una semana,
borrar `transform_to_api` en GitHub (`git push github :transform_to_api`).

### A.10.5 Cuándo eliminar el concern `SequenceSynchronizable`

Cuando PHP deje de existir y solo Rails escriba en la DB, ya no hace falta
realinear la secuencia en cada create. Ver
`Backend/dominio/concerns/sequence_synchronizable.md`.
