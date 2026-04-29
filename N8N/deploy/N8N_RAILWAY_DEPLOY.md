# N8N en Railway — Guía de Despliegue

## Objetivo

Desplegar la instancia N8N de Kumi TTPN Admin en Railway, con auto-deploy desde GitHub y persistencia de datos via Railway Volume.

---

## Prerequisitos

- [ ] Cuenta Railway con proyecto existente (`kumi-ttpn`)
- [ ] Repo `webmasterttpn/kumi-admin-n8n` creado y con commits en `master`
- [ ] Railway CLI instalado (opcional, se puede hacer todo desde el dashboard)

---

## Paso 1 — Crear nuevo servicio en Railway

1. Ir a [railway.app](https://railway.app) → proyecto `kumi-ttpn`
2. Click **+ New Service**
3. Seleccionar **Deploy from GitHub repo**
4. Autorizar acceso y seleccionar: `webmasterttpn/kumi-admin-n8n`
5. Branch: `main`
6. Railway detecta el `Dockerfile` del repo y construye la imagen automáticamente.

> **Nota:** El `Dockerfile` es un wrapper mínimo sobre `docker.n8n.io/n8nio/n8n:latest`. Para cambiar la versión de N8N, editar el tag en el `Dockerfile` y hacer push.

---

## Paso 2 — Configurar Variables de Entorno

En el servicio N8N → pestaña **Variables**, agregar:

| Variable | Valor |
|----------|-------|
| `N8N_ENCRYPTION_KEY` | `<mismo valor del .env local>` — **no regenerar** o se pierden las credenciales |
| `N8N_HOST` | `<subdominio>.up.railway.app` (Railway lo genera, ver Paso 4) |
| `N8N_PORT` | `5678` |
| `N8N_PROTOCOL` | `https` |
| `NODE_ENV` | `production` |
| `WEBHOOK_URL` | `https://<subdominio>.up.railway.app/` |
| `N8N_RUNNERS_ENABLED` | `true` |

> **CRITICO:** `N8N_ENCRYPTION_KEY` debe ser el mismo valor que tienes en `.env` local. Si lo cambias, N8N no podrá descifrar credenciales ya guardadas.

---

## Paso 3 — Configurar Volumen Persistente

N8N guarda workflows y credenciales en `/home/node/.n8n`. Sin volumen persistente, **se pierden en cada redeploy**.

1. En el servicio N8N → pestaña **Volumes**
2. Click **+ Add Volume**
3. Configuración:
   - **Mount Path:** `/home/node/.n8n`
   - **Size:** 1 GB (suficiente para workflows y credenciales)
4. Click **Create Volume**

---

## Paso 4 — Configurar Puerto y Dominio

1. En el servicio N8N → pestaña **Settings** → **Networking**
2. Click **Generate Domain** (o usar dominio personalizado si tienes uno)
3. Railway asigna algo como: `kumi-admin-n8n-production.up.railway.app`
4. **Actualizar las variables** con el dominio real:
   - `N8N_HOST` → `kumi-admin-n8n-production.up.railway.app`
   - `WEBHOOK_URL` → `https://kumi-admin-n8n-production.up.railway.app/`
5. En **Port**, asegurarse que apunta a `5678`

---

## Paso 5 — Primer Deploy

1. Railway debería detectar el nuevo servicio y hacer deploy automático
2. Si no, click **Deploy** manual
3. Verificar logs: debe aparecer `n8n ready on 0.0.0.0, port 5678`
4. Acceder a `https://<subdominio>.up.railway.app`
5. Crear cuenta de administrador de N8N (primer acceso)

---

## Paso 6 — Configurar Auto-Deploy desde GitHub

Railway ya configura auto-deploy por defecto al conectar el repo. Para verificar:

1. Servicio N8N → **Settings** → **Deploy**
2. Confirmar que **Auto-Deploy** está activado en branch `master`
3. Cualquier push a `master` en `kumi-admin-n8n` dispara un redeploy

> El redeploy solo reinicia el contenedor con la nueva imagen — los datos en el volumen `/home/node/.n8n` se conservan.

---

## Paso 7 — Conectar N8N con la API de Kumi

### Crear API Key en el panel admin

1. En el panel admin de Kumi → **Configuración → API Keys**
2. Click **Nueva clave**
3. Datos:
   - Nombre: `N8N Automation`
   - Tipo: `n8n` (o `service`)
   - Descripción: `Integración N8N → API Kumi`
4. **Copiar el token** (solo se muestra una vez)

### Configurar credencial en N8N

1. En N8N → **Credentials → Add Credential**
2. Tipo: **HTTP Request → Header Auth**
3. Datos:
   - Name: `Kumi API`
   - Header Name: `Authorization`
   - Header Value: `Bearer <token_copiado>`
4. Guardar

### URL base de la API

- **Producción:** `https://<dominio-railway-del-api>.up.railway.app/api/v1`
- **Local (para testing):** `http://host.docker.internal:3000/api/v1`

---

## Verificación Final

```bash
# Verificar que N8N responde
curl https://<subdominio>.up.railway.app/healthz

# Debe responder: {"status":"ok"}
```

---

## Troubleshooting

### N8N no arranca / Error de encriptación
- Verificar que `N8N_ENCRYPTION_KEY` sea exactamente igual al valor local
- Revisar logs en Railway → servicio N8N → **Logs**

### Webhooks no funcionan
- Asegurarse que `WEBHOOK_URL` incluye el trailing slash: `https://dominio.railway.app/`
- `N8N_PROTOCOL` debe ser `https` en producción

### Datos perdidos después de redeploy
- Confirmar que el volumen está montado en `/home/node/.n8n`
- Verificar en Railway → **Volumes** que el volumen está activo

### N8N no puede conectar a la API
- Verificar que la API Key no expiró
- Confirmar que la URL de la API es la correcta en Railway (no localhost)
- Revisar que el servicio API en Railway esté corriendo

---

## Actualización de N8N (nueva versión)

1. Editar `Dockerfile` en `kumi-admin-n8n`:

   ```dockerfile
   FROM docker.n8n.io/n8nio/n8n:1.x.x   # ← cambiar el tag
   ```

2. Hacer commit y push a `main`
3. Railway redeploya automáticamente

> **Recomendación:** Usar versión fija (ej. `1.68.0`) en producción en lugar de `latest`. Actualizar manualmente después de probar en local.

---

## Estructura de Costos Railway

| Recurso | Estimado |
|---------|----------|
| Servicio N8N (RAM ~512MB) | ~$5-10/mes |
| Volumen 1GB | ~$0.25/mes |
| **Total** | ~$5-10/mes |

Railway cobra por uso real (CPU + RAM + transfer). N8N en idle consume poco.
