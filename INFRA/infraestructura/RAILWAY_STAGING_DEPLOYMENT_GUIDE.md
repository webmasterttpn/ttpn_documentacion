# 🚀 Guía de Despliegue en Railway (Staging / Test)

Esta guía detalla el proceso paso a paso para desplegar el backend **Kumi TTPN Admin V2 (ttpngas)** en Railway, conectándolo a tu base de datos externa en Supabase y configurando Redis + Sidekiq para los trabajos en segundo plano (background jobs).

**Entorno Objetivo:** `staging` (test con usuarios reales).
**Rama a Desplegar:** `transform_to_api`.

---

## 🛠 Fase 1: Preparación Inicial y Repositorio

1. **Asegúrate de tener los últimos cambios en GitHub/GitLab:**
   Antes de empezar en Railway, tu código debe estar actualizado en tu repositorio remoto.
   ```bash
   # En tu terminal local (carpeta ttpngas):
   git push origin transform_to_api
   ```
   _Nota:_ Ya hemos configurado tu `Dockerfile` para que ejecute `rails db:prepare` automáticamente antes de iniciar el servidor, y tu `database.yml` para conectarse usando connection pooling compatible con Supabase (`prepared_statements: false`).

---

## ☁️ Fase 2: Creación del Proyecto y la API Web en Railway

1. **Crear el Proyecto:**
   - Inicia sesión en [Railway.app](https://railway.app/).
   - Haz clic en **"New Project"**.
   - Selecciona **"Deploy from GitHub repo"** (o GitLab, dependiendo de dónde esté alojado `ttpngas`).
   - Selecciona tu repositorio.

2. **Configurar la Rama Correcta (Test/Staging):**
   - En cuanto Railway identifique el servicio, haz clic en él (en el rectángulo que aparece en el lienzo).
   - Ve a la pestaña **"Settings"**.
   - En la sección **"Deploy"**, busca **"Deployment Branch"**.
   - Cámbialo de `main` a **`transform_to_api`**. Esto provocará que Railway pause y vuelva a construir la imagen correcta.

3. **Inyectar las Variables de Entorno (Environment Variables):**
   - Ve a la pestaña **"Variables"** del mismo servicio.
   - Haz clic en **"Raw Editor"** (para pegarlas todas de golpe) y pega la siguiente configuración, ajustando el `RAILS_MASTER_KEY` y el `FRONTEND_URL`.
   - _Aseguramos que RAILS_ENV sea `production` para que el código se ejecute optimizado, aunque el propósito lógico sea staging/test._

   ```env
   # --- Configuración Base y Rails ---
   RAILS_ENV=production
   RAILS_MAX_THREADS=5
   # Copia el contenido de tu archivo físico: config/master.key
   RAILS_MASTER_KEY=PEGAR_AQUI_LA_LLAVE_MAESTRA

   # --- Supabase Database (Puerto Pooler 6543) ---
   DATABASE_URL=[Supabase → Project Settings → Database → URI]

   # --- Frontend ---
   # Actualiza esto con la URL de tu Quasar en Railway o Vercel cuando la tengas.
   FRONTEND_URL=https://tu-url-de-frontend.railway.app

   # --- AWS S3 ---
   AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
   AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   AWS_REGION=us-east-2
   AWS_BUCKET_NAME=ttpngas-production
   ```

4. **Publicar (Generar URL):**
   - Ve a la pestaña **"Settings"**.
   - En la sección **"Networking"**, haz clic en **"Generate Domain"**. Railway te dará una URL pública (ej. `kumi-api-staging.up.railway.app`). Esto es lo que conectarás en tu frontend luego.

---

## 🗄 Fase 3: Agregar Redis al Lienzo

Para que Sidekiq funcione y gestione las tareas asíncronas (como correos), necesitas un motor Redis. En Docker Compose lo tenías local, aquí Railway te proporcionará uno dedicado.

1. **Crear el Servicio Redis:**
   - En el panel general de tu proyecto (el lienzo o "Canvas"), haz clic derecho en un área vacía, o haz clic en el botón superior **"New"**.
   - Selecciona **"Database"** ➔ **"Add Redis"**.
   - Railway provisionará el servicio instantáneamente y creará variables internas.

---

## 👷 Fase 4: Desplegar el Worker de Sidekiq

En producción/staging, la aplicación web y los "workers" (Sidekiq) son procesos independientes para que no se asfixien entre sí.

1. **Crear el Servicio para Sidekiq:**
   - En el lienzo de tu proyecto, haz clic en **"New"** ➔ **"GitHub Repo"** (o GitLab).
   - **Vuelve a seleccionar exactamente el mismo repositorio de ttpngas**.
   - Esto creará un _segundo_ rectángulo en tu panel que tiene la misma base de código.

2. **Configurar el Worker:**
   - Haz clic en este segundo servicio recién creado.
   - Ve a **"Settings"** ➔ **"Deploy"** y cambia la rama a **`transform_to_api`** al igual que hiciste con la API.
   - En esa misma pantalla de **"Settings"**, desplázate hacia abajo hasta **"Deploy"** ➔ **"Custom Start Command"** (o simplemente Command).
   - En la caja de texto, escribe lo siguiente. _(Esto anula el comando `rails server` del Dockerfile y le dice que arranque solo a Sidekiq)_:
     ```bash
     bundle exec sidekiq -c 10 -q default -q mailers
     ```

3. **Variables de Entorno para Sidekiq:**
   - Ve a la pestaña **"Variables"** de este servicio Worker.
   - Haz clic en **"Shared Variables"** o cópialas desde el servicio principal y pégalas en el **"Raw Editor"**. Debe tener las mismas conexiones a AWS, Supabase y la MASTER_KEY.
   - **PASO CRÍTICO:** Tienes que crear la variable para conectar este código con el Redis que creaste en el paso anterior. Agrega esto como Nueva Variable:
     - Nombre: `REDIS_URL`
     - Valor: Escribe `${{` y selecciona el autocompletado que dice `Redis.REDIS_URL` (esto enlaza internamente la red de Railway). Terminando así: `${{Redis.REDIS_URL}}`

4. **Conectar la API Web a Redis:**
   - **Importante:** Regresa al servicio principal (el del Paso 2, la API web). Ve a la pestaña **"Variables"** y también agrégale la conexión a Redis para que la aplicación web sepa adónde mandar los trabajos:
     - Variable: `REDIS_URL`
     - Valor: `${{Redis.REDIS_URL}}`

---

## ✅ Resumen del Entorno Final de Railway

Al finalizar estos pasos, tu proyecto en Railway debe verse con 3 componentes (rectángulos):

1. **El servicio de Base de Datos Redis** (Gestionado automáticamente por Railway).
2. **Kumi Web API** (Rama `transform_to_api`, con Dominio Público generado, atado a Supabase y AWS).
3. **Kumi Sidekiq Worker** (Mismo código, misma rama, pero Comando de Inicio modificado para `sidekiq`, sin dominio público).

El despliegue ejecutará las migraciones dentro de Supabase en la primera inicialización gracias al ajuste `db:prepare` en el Dockerfile. ¡Y estarás listopara probar con usuarios reales!
