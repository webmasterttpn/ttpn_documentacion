# Manual CERO — Setup de Docker y entorno

> **Audiencia**: dev que nunca ha usado Docker, Rails ni Quasar.
> **Resultado al terminar**: tu computadora corre Kumi local con
> backend (`localhost:3000`), admin (`localhost:9000`) y el portal nuevo
> (`localhost:9001`) hablando entre sí.
> **Tiempo estimado**: 90-120 minutos la primera vez.

---

## Paso 1 — Pre-requisitos del sistema

### Por qué

Necesitas Docker (para correr todo sin instalar Ruby ni Node a mano),
Git (para clonar los repos), y Node 20+ (para correr comandos como
`npm install` localmente cuando se requiera).

### Comando(s)

```bash
docker --version
git --version
node --version
```

### Salida esperada

```text
Docker version 24.0.6, build ed223bc
git version 2.39.3 (Apple Git-145)
v20.10.0
```

(las versiones pueden ser distintas, pero **mayores** a las indicadas)

### Si falla

- **`command not found: docker`** → instala **Docker Desktop**:
  - Mac: <https://www.docker.com/products/docker-desktop/> → descarga
    e instala. Ábrelo desde Aplicaciones para que arranque el daemon.
  - Win: descarga e instala. Habilita WSL 2 si te lo pide.
  - Linux: sigue <https://docs.docker.com/engine/install/> según
    distribución.
- **`command not found: git`** → Mac: `brew install git`. Win:
  <https://git-scm.com/download/win>. Linux: `sudo apt install git`.
- **Node < 20** → instala con [nvm](https://github.com/nvm-sh/nvm):
  `nvm install 20 && nvm use 20`.

### Aprende esto antes de seguir

- **Docker** corre "contenedores" — pequeñas máquinas virtuales que
  empaquetan una app con todo lo que necesita. Tú no instalas Ruby
  en tu compu, lo corres dentro de un contenedor. Misma idea para
  PostgreSQL, Redis, etc.
- **Docker Desktop** es la app gráfica que necesitas correr para que
  los contenedores tengan dónde vivir. Cuando ves el ícono de la
  ballena en la barra, Docker está corriendo.

---

## Paso 2 — Crear la carpeta raíz del monorepo

### Por qué

Kumi se compone de varios repos hermanos (backend, frontend, n8n,
portal). Vivien todos juntos en una carpeta raíz llamada
**"Kumi TTPN Admin V2"** que contiene el `docker-compose.yml` y el
`setup.sh` que orquesta todo.

### Comando(s)

```bash
mkdir -p ~/Documents/Kumi
cd ~/Documents/Kumi
```

### Salida esperada

Sin salida — el comando solo crea la carpeta y entra a ella.

### Verificación

```bash
pwd
```

Debes ver: `/Users/<tu-usuario>/Documents/Kumi` (o similar).

> El nombre y ubicación exacta los acuerdas con Antonio. Aquí se asume
> `~/Documents/Kumi` por simplicidad.

---

## Paso 3 — Clonar el repo raíz (orquestador Docker)

### Por qué

El **monorepo de orquestación** contiene `docker-compose.yml` y
`setup.sh`. NO contiene el código de las apps — solo cómo
levantarlas juntas.

### Comando(s)

```bash
git clone <URL_DEL_REPO_RAIZ> kumi-orchestrator
cd kumi-orchestrator
ls
```

Antonio te dará el URL. Por convención se llama **"Kumi TTPN Admin V2"**.

### Salida esperada

```text
Cloning into 'kumi-orchestrator'...
remote: Counting objects: ... done.
Receiving objects: 100%, done.
Resolving deltas: 100%, done.

Documentacion/  docker-compose.yml  setup.sh  ...
```

### Si falla

- **`Permission denied (publickey)`** → tu clave SSH no está dada de
  alta en GitHub. Pide acceso a Antonio o usa HTTPS:
  `git clone https://github.com/... kumi-orchestrator`.

---

## Paso 4 — Inspeccionar el `setup.sh`

### Por qué

Antes de correrlo, entiende qué hace.

### Comando(s)

```bash
cat setup.sh | head -50
```

### Qué vas a ver

Un script bash interactivo que:

1. Verifica que tengas Docker, Git, PostgreSQL local.
2. Te pregunta qué proyectos necesitas (backend, frontend, n8n,
   portal).
3. Clona los repos que dijiste sí.
4. Crea `.env` desde `.env.example` y te pide los valores secretos.
5. Levanta los contenedores Docker.

### Aprende esto antes de seguir

- **`.env`** es un archivo de texto con variables de entorno (secretos
  como passwords, API keys). Nunca se versiona — cada dev tiene el
  suyo.
- **`.env.example`** es la plantilla. Esa SÍ se versiona, con valores
  ficticios.

---

## Paso 5 — Correr `./setup.sh` (modo interactivo)

### Por qué

Es la manera estándar de clonar repos y levantar Docker la primera vez.

### Comando(s)

```bash
chmod +x setup.sh
./setup.sh
```

### Salida esperada

```text
╔══════════════════════════════════════════════╗
║        Kumi TTPN  — Setup                    ║
╚══════════════════════════════════════════════╝

── Verificando requisitos del sistema ───────────────

  ✓ Git 2.39.3
  ✓ Docker 24.0.6
  ✓ Docker Desktop está corriendo
  ✓ PostgreSQL 17 instalado
  ✓ PostgreSQL está corriendo y acepta conexiones

✓ Todos los requisitos están listos

¿Qué proyectos necesitas trabajar hoy?

? ¿Necesitas el Backend Rails API (ttpngas)? [S/n]:
```

### Qué responder

| Pregunta | Tu respuesta |
|---|---|
| Backend Rails API | **s** (sí) |
| Kumi Admin PWA | **s** (sí, lo necesitas para hacer cambios admin) |
| Automatización N8N | **n** (no, no aplica al portal de proveedores) |
| Portal Proveedores | **s** (cuando exista la opción — ver Paso 10) |

Te pedirá:

- **Contraseña de PostgreSQL local**: la que pusiste cuando instalaste
  Postgres con Homebrew. Si no le pusiste, da Enter.
- **API_URL del Frontend**: Enter para usar `http://localhost:3000`.

Cuando termine, verás:

```text
✓ Stack levantado

  API Rails: http://localhost:3000
  Sidekiq:   http://localhost:3000/sidekiq
  Swagger:   http://localhost:3000/api-docs
  Kumi Admin: http://localhost:9000
```

### Si falla

- **PostgreSQL no detectado** → instala con:
  - Mac: `brew install postgresql@17 && brew services start postgresql@17`
  - Linux: `sudo apt install postgresql-17`
- **`docker-compose: command not found`** → tu Docker Desktop está
  viejo. Actualízalo (versiones recientes usan `docker compose` sin
  guion). El script ya maneja ambos.
- **`port 3000 already in use`** → algo más está usando el puerto.
  Apágalo o detén tu Rails local si lo tienes corriendo:
  `lsof -ti:3000 | xargs kill -9`.

---

## Paso 6 — Verificar que el stack corre

### Por qué

Antes de tocar código, valida que la base funciona.

### Comando(s)

```bash
docker ps
```

### Salida esperada

```text
CONTAINER ID   IMAGE                ...   PORTS                    NAMES
abc123         redis:7-alpine       ...   0.0.0.0:6379->6379/tcp   kumi_redis
def456         <build>              ...   0.0.0.0:3000->3000/tcp   kumi_api
ghi789         <build>              ...                            kumi_sidekiq
jkl012         <build>              ...   0.0.0.0:9000->9200/tcp   kumi_frontend
```

Tienes que ver **4 contenedores corriendo** (`kumi_redis`, `kumi_api`,
`kumi_sidekiq`, `kumi_frontend`).

### Verificación adicional

Abre en tu navegador:

| URL | Qué debes ver |
|---|---|
| `http://localhost:3000/up` | Página verde con texto "Rails is up" |
| `http://localhost:9000` | Login del Kumi Admin |

### Si falla

- Un contenedor en estado `Restarting` → revisa sus logs:
  `docker compose logs --tail=50 <nombre>`. Errores típicos:
  variable de entorno faltante en `.env`, password de Postgres
  incorrecta.

---

## Paso 7 — Aprender los comandos Docker del día a día

> **Memoriza estos 7 comandos**. Son el 95 % de lo que usarás.

| Comando | Para qué |
|---|---|
| `docker compose ps` | Ver qué contenedores corren ahora mismo |
| `docker compose up -d` | Levantar todo el stack en background |
| `docker compose down` | Apagar todo (no borra datos) |
| `docker compose logs -f kumi_api` | Ver logs del backend en vivo (Ctrl+C para salir) |
| `docker compose exec kumi_api bash` | Entrar al contenedor del API (shell) |
| `docker compose exec kumi_api bundle exec rails console` | Consola interactiva de Rails (para probar código) |
| `docker compose restart kumi_api` | Reiniciar solo el API (útil cuando cambias el `.env`) |

### Aprende esto antes de seguir

- **`-d` significa "detached"** — corre en background, te devuelve el
  prompt. Sin `-d`, el comando se queda mostrando logs y no puedes
  cerrar la terminal sin matarlo.
- **`exec`** ejecuta un comando dentro de un contenedor que YA está
  corriendo. **`run`** crea uno nuevo cada vez (usa `exec`).
- **El nombre del contenedor (`kumi_api`, `kumi_frontend`)** lo
  defines en `docker-compose.yml`. Es como un alias.

---

## Paso 8 — Agregar el servicio `portal_proveedores` al `docker-compose.yml`

### Por qué

El portal de proveedores es una **app nueva**. Para que sea parte del
stack Docker (y para que el `setup.sh` la clone automáticamente), hay
que registrarlo en dos archivos: `docker-compose.yml` y `setup.sh`.

### Comando(s)

Abre `docker-compose.yml` en tu editor (VS Code, Sublime, etc.):

```bash
code docker-compose.yml   # o tu editor preferido
```

### Cambio: agrega ESTE BLOQUE antes de la línea `volumes:` (al final)

Reemplaza el bloque comentado de `portal-captura` que ya existe (líneas
~143-164) o agrégalo nuevo si no está. Pega EXACTAMENTE:

```yaml
  # ============================================
  # PORTAL DE PROVEEDORES — portal-proveedores/
  # Perfil: portal_proveedores
  # Repo independiente: <URL que Antonio te dará>
  # ============================================
  portal_proveedores:
    build:
      context: ./portal-proveedores
      target: development
    container_name: kumi_portal_proveedores
    ports:
      - "9001:9200"
    volumes:
      - ./portal-proveedores:/app
      - /app/node_modules
    env_file:
      - ./portal-proveedores/.env
    environment:
      API_URL: "http://kumi_api:3000"
      NODE_ENV: development
    depends_on:
      - api
    networks:
      - kumi_network
    profiles:
      - portal_proveedores
      - full
```

### Explicación línea por línea

| Línea | Qué hace |
|---|---|
| `build.context: ./portal-proveedores` | Construye la imagen desde la carpeta `portal-proveedores/` (el repo del portal) |
| `build.target: development` | Usa el stage `development` del Dockerfile (con hot reload, no minificado) |
| `container_name: kumi_portal_proveedores` | Nombre fijo del contenedor (sigue la convención `kumi_*`) |
| `ports: 9001:9200` | Mapea el puerto **9200 dentro del contenedor** → **9001 en tu compu**. Quasar usa 9200 internamente |
| `volumes: ./portal-proveedores:/app` | Sincroniza tu carpeta local con `/app` dentro del contenedor (hot reload) |
| `volumes: /app/node_modules` | Volume anónimo para `node_modules` (evita que tu host le pegue con uno vacío) |
| `env_file: ./portal-proveedores/.env` | Lee variables desde el `.env` del portal |
| `API_URL: http://kumi_api:3000` | Dentro de Docker, los contenedores se ven entre sí por nombre. El portal habla con `kumi_api` (no localhost) |
| `depends_on: - api` | Levanta el API primero |
| `networks: - kumi_network` | Todos los contenedores comparten esta red |
| `profiles: portal_proveedores, full` | Solo se levanta si activas uno de esos perfiles |

### Verificación

```bash
docker compose --profile portal_proveedores config 2>&1 | grep portal_proveedores
```

Debes ver el bloque del servicio sin errores de sintaxis YAML.

### Si falla

- **`yaml: line N: did not find expected key`** → revisa la
  indentación. YAML es estricto con espacios (usa 2 espacios, nunca
  tab).

---

## Paso 9 — Agregar el portal al `AVAILABLE_REPOS` del `setup.sh`

### Por qué

Para que `./setup.sh` te pregunte si quieres clonarlo y lo configure
automáticamente, debe estar en el array `AVAILABLE_REPOS`.

### Cambio en `setup.sh`

Abre el archivo y busca la sección:

```bash
declare -a AVAILABLE_REPOS=(
  "be|Backend Rails API (ttpngas)|https://github.com/webmasterttpn/kumi-admin-api.git|ttpngas|backend"
  "fe|Kumi Admin PWA (ttpn-frontend)|https://github.com/webmasterttpn/kumi-admin-frontend.git|ttpn-frontend|frontend"
  "n8n|Automatización N8N|https://github.com/webmasterttpn/kumi-admin-n8n.git|ttpn_n8n|n8n"
  # "portal|Portal Captura Clientes|https://github.com/webmasterttpn/portal-captura.git|portal-captura|portal"
  # Agregar nuevas apps aquí siguiendo el mismo formato
)
```

Agrega esta línea (Antonio te dará la URL real):

```bash
  "pp|Portal de Proveedores|https://github.com/webmasterttpn/portal-proveedores.git|portal-proveedores|portal_proveedores"
```

Queda así:

```bash
declare -a AVAILABLE_REPOS=(
  "be|...|backend"
  "fe|...|frontend"
  "n8n|...|n8n"
  "pp|Portal de Proveedores|https://github.com/webmasterttpn/portal-proveedores.git|portal-proveedores|portal_proveedores"
)
```

### Formato del string (recordatorio)

```text
clave|descripción|url|carpeta_local|perfil_docker
```

### Verificación

```bash
./setup.sh --help
```

En "Proyectos disponibles" debes ver:

```text
  [pp]  Portal de Proveedores  →  ./portal-proveedores
```

---

## Paso 10 — Clonar el repo del portal y levantarlo

> **Antes de este paso, Antonio debe haber creado el repo en GitHub**
> (vacío, solo con `main`). Te dará la URL.

### Comando(s)

```bash
./setup.sh
```

Cuando te pregunte:

```text
? ¿Necesitas el Portal de Proveedores? [S/n]: s
```

Responde **s**. El script clona el repo (vacío todavía, ese es el
trabajo del manual_frontend.md) y queda listo para el siguiente paso.

> Si el repo está vacío y `docker compose` falla al intentar
> construir la imagen, **es esperado**: el manual_frontend.md te
> guiará a inicializar el scaffold Quasar dentro de esa carpeta.

---

## Paso 11 — Git workflow del proyecto

> **Regla de oro**: nunca pushees a `main` directamente. Crea una
> branch de feature y pushea ahí. Antonio revisa antes de mergear.

### Primer commit en una branch nueva

Dentro del repo del portal (`./portal-proveedores/`):

```bash
cd portal-proveedores
git checkout -b feature/initial-scaffold

# ... haces tu trabajo (manual_frontend.md te guía) ...

git add .
git commit -m "feat: scaffold inicial del portal Quasar"
git push -u origin feature/initial-scaffold
```

### Subir más cambios a la misma branch

```bash
git add <archivos específicos>
git commit -m "feat: <qué hiciste>"
git push
```

### Antonio revisa en GitHub

Antonio entra a `https://github.com/webmasterttpn/portal-proveedores`
y compara tu branch contra `main`. Si está OK, mergea. Si no, te
comenta o te lo dice por mensaje directo.

### Cuando Antonio mergeó tu branch

Sincroniza tu local:

```bash
git checkout main
git pull
```

### Nombres de branches por convención

| Tipo | Prefijo | Ejemplo |
|---|---|---|
| Feature nueva | `feature/` | `feature/login-page` |
| Bug fix | `fix/` | `fix/jwt-expiration` |
| Refactor | `refactor/` | `refactor/auth-store` |
| Docs | `docs/` | `docs/api-contract-update` |

### Comandos `git` que NO debes usar sin avisar

- `git push --force` (puede borrar trabajo de otros)
- `git push origin main` (bloqueado)
- `git reset --hard` (puede borrar trabajo tuyo no commiteado)
- `git rebase -i` (solo si Antonio te lo pide)

Si te trabas, **avisa a Antonio antes de hacer estos comandos**.

---

## Paso 12 — Checklist final del setup

Marca cada uno cuando lo verifiques:

- [ ] `docker --version` muestra ≥ 24.x
- [ ] `git --version` muestra ≥ 2.39
- [ ] `node --version` muestra ≥ 20.x
- [ ] Docker Desktop está corriendo (ícono ballena en barra)
- [ ] PostgreSQL local corre (`pg_isready` responde "accepting connections")
- [ ] `./setup.sh --help` lista los 4 proyectos (be, fe, n8n, pp)
- [ ] `docker compose ps` muestra al menos `kumi_redis`, `kumi_api`, `kumi_sidekiq`, `kumi_frontend`
- [ ] `http://localhost:3000/up` responde verde "Rails is up"
- [ ] `http://localhost:9000` muestra el login del Kumi Admin
- [ ] Puedes entrar al Admin con la cuenta que Antonio te dio
- [ ] `docker compose exec kumi_api bundle exec rails db:migrate:status` lista las migraciones sin error
- [ ] Tienes acceso al repo `portal-proveedores` en GitHub (vacío con solo `main`)

**Si los 11 puntos están marcados, estás listo para empezar con el
[manual_backend.md](manual_backend.md).**

---

## Workflow diario (referencia rápida)

Cuando llegues a trabajar cada día:

```bash
# 1. Sincroniza el monorepo orquestador
cd ~/Documents/Kumi/kumi-orchestrator
git pull

# 2. Sincroniza tu trabajo en el portal (si Antonio mergeó algo)
cd portal-proveedores
git checkout main
git pull
git checkout feature/<tu-branch-en-progreso>

# 3. Levanta el stack (si no está corriendo)
cd ..
docker compose --profile backend --profile frontend --profile portal_proveedores up -d

# 4. Verifica
docker compose ps
```

Al final del día (o cuando quieras pausar):

```bash
docker compose down
```

(Los datos de Postgres y Redis quedan persistidos en volúmenes — no
se pierden al apagar.)

---

## Siguiente paso

Cuando este manual esté completo, abre:

→ [manual_supabase.md](manual_supabase.md) — para configurar el
storage de archivos.

Después:

→ [manual_letter_opener.md](manual_letter_opener.md) — para correos
en dev.

Después:

→ [manual_backend.md](manual_backend.md) — construir el backend
paso a paso.
