# N8N — Credenciales, Testing y Despliegue en Railway
## Guía completa paso a paso

---

## Parte 1 — ¿Cómo funciona el sistema de credenciales en N8N?

### La pregunta clave: ¿las credenciales van en el .env?

**No.** Las credenciales en N8N funcionan diferente a lo que estás acostumbrado.

Hay dos tipos de configuración separados:

| Tipo | Dónde va | Qué contiene |
|------|----------|--------------|
| **Variables de sistema** | `.env` | Cómo arranca N8N: puerto, host, clave de cifrado |
| **Credenciales de integraciones** | Dentro de N8N (UI) | Tokens de API, contraseñas de DB, llaves de WhatsApp, etc. |

**Analogía:** el `.env` es la llave del edificio. Las credenciales son las cajas fuertes dentro del edificio — las configuras tú una vez que entras.

### ¿Cómo guarda N8N las credenciales?

N8N toma cada credencial que le das (token, password, etc.), la **cifra usando tu `N8N_ENCRYPTION_KEY`** del `.env`, y la guarda en la carpeta `ttpn_n8n/data/`. Nunca se guardan en texto plano.

```
ttpn_n8n/
├── .env                    ← solo la clave de cifrado y config del servidor
└── data/                   ← N8N guarda AQUÍ todo (workflows + credenciales cifradas)
    ├── database.sqlite
    └── ...
```

**Conclusión:** solo necesitas ingresar las credenciales **una vez** en la interfaz de N8N. Después quedan guardadas y disponibles para todos tus workflows.

---

## Parte 2 — Configurar credencial de la API de Kumi (Rails)

Esta credencial se usa cuando N8N necesita **crear o modificar datos** en tu sistema (bookings, rutas, importaciones).

### Paso 1 — Obtener el token de la API

1. Abre el panel admin de Kumi en tu navegador: `http://localhost:9000`
2. Ve a **Configuración → API Keys** (o el menú equivalente)
3. Click en **Nueva clave** / **New API Key**
4. Llena los datos:
   - **Nombre:** `N8N Automation`
   - **Descripción:** `Acceso M2M para workflows de N8N`
5. Click **Crear**
6. **COPIA EL TOKEN QUE APARECE** — solo se muestra esta única vez
   - Se ve algo así: `kumi_live_abc123xyz789...`
   - Guárdalo temporalmente en un bloc de notas

> ⚠️ Si cierras la pantalla sin copiarlo, tendrás que generar uno nuevo.

### Paso 2 — Agregar la credencial en N8N

1. Abre N8N: `http://localhost:5678`
2. En el menú izquierdo, click en **Credentials** (ícono de llave 🔑)
3. Click en el botón **+ Add credential** (esquina superior derecha)
4. En el buscador escribe: `Header Auth`
5. Selecciona **Header Auth**
6. Llena el formulario:
   - **Credential Name:** `Kumi API Local`
   - **Name:** `Authorization`
   - **Value:** `Bearer kumi_live_abc123xyz789...` (tu token con "Bearer " adelante)
7. Click **Save**

N8N muestra ✅ verde si se guardó correctamente.

### Paso 3 — Probar que funciona

Vamos a crear un workflow de prueba rápido:

1. En N8N → menú izquierdo → **Workflows** → **+ New Workflow**
2. Click en el área central en **+** para agregar un nodo
3. Busca: `HTTP Request` → selecciónalo
4. Configura el nodo:
   - **Method:** `GET`
   - **URL:** `http://kumi_api:3000/api/v1/vehicles`
     > ⚠️ Usa `kumi_api` (nombre del contenedor Docker), NO `localhost`
     > Dentro de Docker, los contenedores se hablan por nombre
   - **Authentication:** `Predefined Credential Type`... espera, busca abajo **Generic Credential Type** → selecciona `Header Auth`
   - **Credential:** selecciona `Kumi API Local` (la que acabas de crear)
5. Click **Execute node** (botón ▶️ dentro del nodo)
6. Resultado esperado en el panel derecho:
   ```json
   [
     { "id": 1, "clv": "ABC-001", "nombre": "Camión 1" },
     { "id": 2, "clv": "ABC-002", "nombre": "Camión 2" },
     ...
   ]
   ```
7. Si ves los datos ✅ — la conexión funciona
8. Si ves error 401 — el token es incorrecto
9. Si ves error de conexión — verifica que `kumi_api` esté corriendo: `docker ps`

---

## Parte 3 — Configurar credencial de la Base de Datos (Supabase/PostgreSQL)

Esta credencial se usa cuando N8N necesita **leer datos** para reportes, alertas y notificaciones — sin pasar por Rails.

### Paso 1 — Obtener los datos de conexión

Están en el archivo `.env` de tu backend:

```bash
# Ver los datos de conexión del backend
cat "/Users/ttpn_acl/Documents/Ruby/Kumi TTPN Admin V2/ttpngas/.env" | grep -E "DB_|DATABASE"
```

Busca algo como:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ttpngas_development
DB_USER=postgres
DB_PASSWORD=tu_password
```

### Paso 2 — Agregar la credencial en N8N

1. En N8N → **Credentials** → **+ Add credential**
2. Busca: `Postgres` → selecciona **Postgres**
3. Llena el formulario:
   - **Credential Name:** `Kumi DB Local`
   - **Host:** `host.docker.internal`
     > ⚠️ NO uses `localhost` aquí. Desde dentro de Docker, `localhost` apunta al contenedor, no a tu Mac. `host.docker.internal` es la forma de llegar a tu Mac desde Docker.
   - **Port:** `5432`
   - **Database:** el nombre de tu DB (ej. `ttpngas_development`)
   - **User:** tu usuario de PostgreSQL
   - **Password:** tu contraseña de PostgreSQL
   - **SSL:** `Disable` (en desarrollo local)
4. Click **Test connection** — debe aparecer ✅ Connection tested successfully
5. Click **Save**

### Paso 3 — Probar una consulta

1. Crea un nuevo workflow o usa el anterior
2. Agrega un nodo **Postgres**
3. Configura:
   - **Credential:** `Kumi DB Local`
   - **Operation:** `Execute Query`
   - **Query:**
     ```sql
     SELECT count(*) as total_bookings FROM ttpn_bookings
     ```
4. Click **Execute node**
5. Resultado esperado:
   ```json
   [{ "total_bookings": "1234" }]
   ```

---

## Parte 4 — Despliegue en Railway (paso a paso desde cero)

### ¿Qué vamos a hacer?

Subir tu N8N local a Railway para que corra 24/7 en internet, con auto-deploy cuando hagas push a GitHub.

### Prerequisito — Tener cuenta en Railway

1. Ve a `https://railway.app`
2. Click **Login** → **Login with GitHub**
3. Autoriza con tu cuenta `webmasterttpn`
4. Si no tienes proyecto creado, click **New Project**

---

### Paso 1 — Crear el servicio N8N en Railway

1. Dentro de tu proyecto en Railway, click **+ New**
2. Selecciona **Empty Service**
3. Se crea un servicio en blanco — click en él para abrirlo
4. Ve a la pestaña **Settings**
5. Cambia el nombre del servicio a: `n8n`

---

### Paso 2 — Conectar la imagen de Docker

N8N no tiene código que compilar — usa una imagen pública. Así se configura:

1. Dentro del servicio `n8n` → pestaña **Settings**
2. Busca la sección **Source** → click **Configure**
3. Selecciona **Docker Image**
4. En el campo de imagen escribe:
   ```
   docker.n8n.io/n8nio/n8n:latest
   ```
5. Click **Save** / **Deploy**

> Railway descargará la imagen y arrancará N8N. Tardará ~2-3 minutos la primera vez.

---

### Paso 3 — Agregar el volumen persistente

**Este paso es crítico.** Sin volumen, cada vez que Railway reinicie el servicio, **perderás todos tus workflows y credenciales**.

1. Dentro del servicio `n8n` → pestaña **Volumes**
2. Click **+ Add Volume**
3. Configura:
   - **Mount Path:** `/home/node/.n8n`
   - **Size:** `1 GB`
4. Click **Add**

Railway crea el volumen y lo monta en el contenedor. Desde ahora N8N guarda todo ahí.

---

### Paso 4 — Configurar las variables de entorno

1. Dentro del servicio `n8n` → pestaña **Variables**
2. Click **+ New Variable** para cada una:

| Variable | Valor | Nota |
|----------|-------|------|
| `N8N_ENCRYPTION_KEY` | `ab960f7fee0e07ef6d0377dc6bce8e759a35eae5faa3ece9` | **Exactamente igual que tu .env local** |
| `N8N_PORT` | `5678` | Puerto interno |
| `N8N_PROTOCOL` | `https` | En Railway siempre es https |
| `NODE_ENV` | `production` | |
| `N8N_RUNNERS_ENABLED` | `true` | Mejora el rendimiento |

> ⚠️ `N8N_HOST` y `WEBHOOK_URL` los agregas **después** del Paso 5, cuando ya tengas el dominio.

---

### Paso 5 — Generar el dominio público

1. Dentro del servicio `n8n` → pestaña **Settings**
2. Busca la sección **Networking** → **Public Networking**
3. Click **Generate Domain**
4. Railway asigna un dominio como:
   ```
   n8n-production-xxxx.up.railway.app
   ```
5. **Copia ese dominio**

---

### Paso 6 — Actualizar variables con el dominio real

Vuelve a **Variables** y agrega las dos que faltaban:

| Variable | Valor |
|----------|-------|
| `N8N_HOST` | `n8n-production-xxxx.up.railway.app` (sin https://) |
| `WEBHOOK_URL` | `https://n8n-production-xxxx.up.railway.app/` (con https:// y trailing slash) |

Después de agregar estas variables, Railway hace un redeploy automático.

---

### Paso 7 — Verificar que N8N está corriendo

1. Espera ~1 minuto a que termine el redeploy
2. Ve a la URL de tu dominio en el navegador:
   ```
   https://n8n-production-xxxx.up.railway.app
   ```
3. Debe aparecer la pantalla de **bienvenida de N8N** pidiendo crear una cuenta
4. Crea tu cuenta de administrador:
   - Email: el que uses para el proyecto
   - Password: uno seguro, guárdalo en tu gestor de contraseñas
5. Haz login

Si ves la pantalla de workflows ✅ — N8N está corriendo en Railway.

---

### Paso 8 — Conectar auto-deploy desde GitHub

Esto hace que cada vez que hagas push a `kumi-admin-n8n`, Railway redeploya automáticamente.

1. Dentro del servicio `n8n` → pestaña **Settings** → sección **Source**
2. Click **Connect Repo**
3. Autoriza Railway para acceder a GitHub
4. Busca y selecciona: `webmasterttpn/kumi-admin-n8n`
5. Branch: `main`
6. Click **Connect**

> **¿Por qué conectar el repo si la imagen viene de Docker?**
> El repo actúa como trigger. Cuando haces push, Railway sabe que debe revisar si la imagen de N8N tiene versión nueva. También te permite guardar configuración custom en el futuro (Dockerfile propio, scripts de inicio, etc.)

---

### Paso 9 — Configurar las credenciales en N8N de producción

Las credenciales que creaste en local **no se sincronizan automáticamente** a Railway. Tienes dos opciones:

#### Opción A — Exportar e importar (recomendado si tienes muchas credenciales)

En tu N8N local:
1. **Settings** → **n8n API** → habilitar si no está activo
2. Exportar via API o manualmente cada credencial

> Por ahora, con pocas credenciales, es más fácil la Opción B.

#### Opción B — Ingresar manualmente en producción (más simple)

Repite exactamente los mismos pasos de la **Parte 2** y **Parte 3** de este documento, pero ahora en tu N8N de Railway (`https://n8n-production-xxxx.up.railway.app`).

**Diferencias importantes para producción:**

Para la credencial de la API (Rails):
- La URL cambia: usa la URL de Railway de tu API, no `kumi_api:3000`
- Ejemplo: `https://kumi-api-production.up.railway.app/api/v1/vehicles`

Para la credencial de la DB:
- En producción NO conectes a la DB directa — usa Supabase
- En N8N → **Credentials** → tipo **Supabase**
- Datos: los de tu proyecto Supabase (URL + anon key o service role key)

---

### Paso 10 — Verificación final

Abre en el navegador:
```
https://n8n-production-xxxx.up.railway.app/healthz
```

Debe responder:
```json
{"status":"ok"}
```

✅ N8N está en producción y listo para workflows.

---

## Parte 5 — Sincronizar workflows de local a producción

Los workflows se exportan como archivos JSON e importan en producción.

### Exportar un workflow desde local

1. En tu N8N local → abre el workflow
2. Click en el menú `⋮` (tres puntos) → **Download**
3. Se descarga un archivo `.json`

### Importar en producción

1. En tu N8N de Railway → menú izquierdo → **Workflows**
2. Click **+** → **Import from file**
3. Sube el `.json` descargado
4. Revisa que las credenciales apunten a las correctas de producción
5. Activa el workflow con el toggle

---

## Resumen de URLs

| Servicio | Local | Railway (producción) |
|----------|-------|----------------------|
| N8N UI | `http://localhost:5678` | `https://n8n-xxxx.up.railway.app` |
| API Rails | `http://kumi_api:3000` (dentro de Docker) | `https://kumi-api-xxxx.up.railway.app` |
| DB directa | `host.docker.internal:5432` | Supabase URL |
| Verificar salud | `localhost:5678/healthz` | `n8n-xxxx.up.railway.app/healthz` |
