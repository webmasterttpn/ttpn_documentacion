# N8N en Local — Guía de Setup

## Objetivo

Levantar N8N localmente integrado con el stack Kumi TTPN Admin V2 via Docker Compose.

---

## Prerequisitos

- [ ] Docker Desktop corriendo
- [ ] Red Docker `kumi_network` creada (`docker network create kumi_network`)
- [ ] Repo `kumi-admin-n8n` clonado en `./ttpn_n8n`
- [ ] Archivo `./ttpn_n8n/.env` configurado (ver abajo)

---

## Paso 1 — Configurar Variables de Entorno

```bash
cp ttpn_n8n/.env.example ttpn_n8n/.env
```

Editar `ttpn_n8n/.env`:

### Variables de N8N

| Variable                      | Valor local                                                                                   |
|-------------------------------|-----------------------------------------------------------------------------------------------|
| `N8N_ENCRYPTION_KEY`          | Generar con `openssl rand -hex 24` — **guardar este valor**, se necesita igual en producción  |
| `N8N_HOST`                    | `localhost`                                                                                   |
| `WEBHOOK_URL`                 | `http://localhost:5678/`                                                                      |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE`| `false`                                                                                       |

### Variables de integración (usadas por los workflows)

| Variable        | Valor local                                    |
|-----------------|------------------------------------------------|
| `API_BASE_URL`  | `http://kumi_api:3000`                         |
| `KUMI_API_KEY`  | `Bearer <token-de-api-key-tipo-n8n-local>`     |
| `GROQ_API_KEY`  | `Bearer <tu-groq-api-key>`                     |

> **CRITICO:** El `N8N_ENCRYPTION_KEY` local debe ser el mismo que configures en Railway. Si difieren, las credenciales no se pueden descifrar al pasar a producción.
> **Nota:** `API_BASE_URL` usa `http://kumi_api:3000` en local (nombre del contenedor Docker) y la URL de Railway en producción — el workflow no cambia, solo la variable.

---

## Paso 2 — Levantar N8N

```bash
# Desde la raíz del monorepo
docker compose --profile n8n up -d

# O con el setup interactivo
./setup.sh   # seleccionar N8N cuando pregunte
```

N8N queda disponible en: **http://localhost:5678**

---

## Paso 3 — Primer Acceso

1. Abrir http://localhost:5678
2. Crear cuenta de administrador (solo se pide la primera vez)
3. N8N guarda los datos en `./ttpn_n8n/data/` (gitignored)

---

## Paso 4 — Importar el Workflow

1. En N8N → **Workflows → Import from file**
2. Seleccionar: `./ttpn_n8n/workflows/kumi-chat.json`
3. Activar el workflow con el toggle

> **Importante:** Cada vez que hagas cambios en el workflow desde la UI de N8N, expórtalo y reemplaza el JSON del repo antes de hacer push:
> - N8N → menú del workflow (⋯) → **Download**
> - Copiar el archivo descargado a `ttpn_n8n/workflows/kumi-chat.json`

---

## Paso 5 — Conectar con la API de Kumi

### Crear API Key en el panel admin

1. En el panel admin de Kumi → **Configuración → API Keys**
2. Click **Nueva clave**
3. Datos:
   - Nombre: `N8N Local`
   - Tipo: `n8n`
4. **Copiar el token** (solo se muestra una vez)
5. Pegarlo en `ttpn_n8n/.env` como `KUMI_API_KEY=Bearer <token>`

> **Nota:** El workflow usa `$env.KUMI_API_KEY` directamente — no se necesita configurar una credencial en N8N. Para que funcione, `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` debe estar en `.env`.

### URL base de la API (local)

La API corre en Docker en la misma red `kumi_network`. La variable `API_BASE_URL=http://kumi_api:3000` en `.env` apunta al contenedor automáticamente.

> No usar `localhost:3000` dentro de N8N — los contenedores se comunican por nombre de servicio, no por localhost.

---

## Paso 6 — Verificar

```bash
# Verificar que N8N responde
curl http://localhost:5678/healthz
# Respuesta esperada: {"status":"ok"}

# Ver logs en tiempo real
docker compose logs -f n8n
```

---

## Comandos útiles

```bash
# Levantar solo N8N + Redis
docker compose --profile n8n up -d

# Bajar N8N
docker compose --profile n8n down

# Ver logs
docker compose logs -f n8n

# Reiniciar N8N
docker compose restart n8n
```

---

## Troubleshooting

### N8N no puede conectar a la API (`kumi_api`)
- Verificar que ambos contenedores estén en la red `kumi_network`
- Verificar que el API esté corriendo: `docker compose ps`
- Usar `http://kumi_api:3000` — nunca `http://localhost:3000` desde N8N

### Los cambios del workflow no se guardan en el repo
- Exportar desde la UI: menú del workflow → Download
- Reemplazar `ttpn_n8n/workflows/kumi-chat.json` con el archivo descargado
- Hacer commit y push

### Credenciales no válidas en producción
- Verificar que `N8N_ENCRYPTION_KEY` sea el mismo en local y en Railway
