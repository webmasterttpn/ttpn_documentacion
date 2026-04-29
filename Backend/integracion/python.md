# 07 — Integración Python dentro de Rails

**Para leer con calma. Sin conocimiento previo de Python.**

---

## ¿Por qué Python dentro de Rails?

Rails es excelente para CRUD, auth, endpoints y lógica de negocio.
Pero tiene limitaciones cuando necesitas:

- Análisis de datos complejos (Pandas, numpy)
- Scripts que procesan miles de filas y calculan estadísticas
- Librerías de ciencia de datos que no existen en Ruby

La solución elegida fue **Opción 1: Python dentro del mismo container Docker**.
Python vive literalmente dentro del mismo proceso del container que Rails y Sidekiq.

```
┌──────────────────────────────────────────────┐
│           Container: kumi_api / kumi_sidekiq  │
│                                              │
│  Ruby 3.3 + Rails 7.1                        │
│  Python 3.11       ← nuevo                   │
│  pip deps (pandas, psycopg2...)  ← nuevo      │
│                                              │
│  Mismos archivos, misma BD, mismo .env       │
└──────────────────────────────────────────────┘
```

No hay un contenedor Python separado. No hay HTTP entre Ruby y Python.
Sidekiq levanta Python como un proceso hijo y captura su salida.

---

## Estructura de carpetas creada

```
ttpngas/
├── scripts/                          ← carpeta raíz de Python
│   ├── __init__.py                   ← marca la carpeta como paquete Python (vacío)
│   ├── requirements.txt              ← dependencias pip (como Gemfile)
│   ├── conftest.py                   ← configuración de pytest (como spec_helper.rb)
│   ├── main.py                       ← lista los scripts disponibles (informativo)
│   │
│   ├── utils/                        ← módulos compartidos por todos los scripts
│   │   ├── __init__.py               ← (vacío)
│   │   ├── db.py                     ← cliente PostgreSQL directo (como ActiveRecord)
│   │   ├── logger.py                 ← configuración de logs
│   │   └── decorators.py             ← helpers @timed, @script_entrypoint
│   │
│   ├── dashboard/                    ← scripts del dashboard
│   │   ├── __init__.py               ← (vacío)
│   │   ├── dashboard_data.py         ← ⭐ mirror Python de DashboardDataService
│   │   └── test_dashboard_data.py    ← tests pytest
│   │
│   ├── reportes/                     ← scripts de reportes
│   │   ├── __init__.py
│   │   ├── contables.py              ← reporte contable diario por usuario
│   │   └── test_contables.py         ← tests pytest
│   │
│   ├── analisis/                     ← scripts de análisis con Pandas
│   │   ├── __init__.py
│   │   ├── rentabilidad.py           ← análisis mensual + exporta CSV
│   │   └── test_rentabilidad.py
│   │
│   └── integraciones/                ← integraciones externas
│       ├── __init__.py
│       └── whatsapp.py               ← envío automático WhatsApp (placeholder)
│
└── app/
    └── jobs/
        └── ejecutar_script_python_job.rb   ← ⭐ puente Ruby→Python (Sidekiq)
```

### ¿Para qué sirve `__init__.py`?

En Python, un directorio se convierte en un **paquete** (similar a un módulo Ruby)
cuando contiene un archivo `__init__.py`. Aunque esté vacío, su presencia le dice
a Python: "esta carpeta es importable". Sin él, no funciona `from utils.db import ...`.

### ¿Para qué sirve `requirements.txt`?

Es el equivalente del `Gemfile` en Python. Lista las dependencias y sus versiones.
Pip (el gestor de paquetes Python) lo lee para instalar todo de una vez.

```
python-dotenv==1.0.0    ← leer .env (como dotenv en Ruby)
requests==2.31.0        ← hacer llamadas HTTP
psycopg2-binary==2.9.9  ← conectar a PostgreSQL directamente
pandas==2.2.3           ← análisis de datos / DataFrames
pytest==7.4.0           ← framework de tests (como RSpec)
pytest-cov==4.1.0       ← cobertura de tests (como SimpleCov)
```

---

## Cómo se modificó el Dockerfile

El `Dockerfile` de `ttpngas/` tiene 4 stages: `base`, `dependencies`, `development`, `production`.

Se modificó **solo el stage `base`** para instalar Python al construir la imagen:

```dockerfile
# Stage 1: Base (MODIFICADO)
FROM ruby:3.3-bookworm AS base

RUN apt-get update -qq && apt-get install -y \
  build-essential libpq-dev nodejs postgresql-client yarn curl git \
  python3 \            ← NUEVO
  python3-pip \        ← NUEVO (gestor de paquetes Python)
  python3-venv \       ← NUEVO (entornos virtuales, opcional)
  && rm -rf /var/lib/apt/lists/*
```

Y en **el stage `development`**, después de copiar el código:

```dockerfile
# Stage 3: Development (MODIFICADO)
COPY . .

# Instalar dependencias Python  ← NUEVO
RUN pip3 install --no-cache-dir --break-system-packages -r scripts/requirements.txt
```

**Resultado:** Al hacer `docker compose build`, la imagen incluye Ruby Y Python.
No se toca `docker-compose.yml`. No hay servicios nuevos.

---

## Los archivos que hacen el trabajo real

### `scripts/utils/db.py` — El cliente de base de datos

Este es el equivalente Python de `ActiveRecord::Base.connection.exec_query`.

```python
class PostgresClient:
    """Conecta a PostgreSQL directamente con psycopg2."""

    def query(self, sql: str, params=None) -> list[dict]:
        # Abre conexión, ejecuta SQL, retorna lista de diccionarios
        # Equivalente Ruby: ActiveRecord::Base.connection.exec_query(sql)

    def execute(self, sql: str, params=None) -> int:
        # Para INSERT/UPDATE/DELETE que no retornan filas

    def insert(self, table: str, data: dict):
        # INSERT INTO tabla (col1, col2) VALUES (val1, val2) RETURNING id

    def upsert(self, table: str, data: dict, conflict_col: str):
        # INSERT ... ON CONFLICT DO UPDATE (como upsert en Rails)
```

**¿Por qué psycopg2 y no Supabase API?**
Porque los scripts necesitan ejecutar SQL complejo con CTEs (WITH ...) y funciones
custom de PostgreSQL (`cobro_fact()`). La API REST de Supabase (PostgREST) no
soporta SQL arbitrario, solo endpoints de tabla. psycopg2 se conecta directo
al motor PostgreSQL.

**¿Cómo sabe a qué BD conectar?**
Lee del mismo `.env` que Rails. Primero busca `DATABASE_URL` (producción en Railway),
y si no existe usa las variables locales `LOCAL_DB_HOST`, `LOCAL_DB_USER`, etc.

```python
def get_connection():
    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        conn = psycopg2.connect(database_url, ...)  # Railway/Supabase
    else:
        conn = psycopg2.connect(                     # Local
            host=os.environ.get("LOCAL_DB_HOST", "localhost"),
            user=os.environ.get("LOCAL_DB_USER", "postgres"),
            password=os.environ.get("LOCAL_DB_PSW", ""),
            dbname=os.environ.get("LOCAL_DB_NAME", "ttpngas_development"),
        )
```

---

### `scripts/utils/logger.py` — Logs

```python
def get_logger(name: str) -> logging.Logger:
    # Crea un logger que escribe a stdout con formato:
    # [2026-04-28 12:00:00] [INFO] dashboard.dashboard_data: Período principal: ...
```

Los logs de Python aparecen en los mismos logs de Docker que Rails:

```bash
docker compose logs -f kumi_sidekiq
```

---

### `scripts/utils/decorators.py` — Helpers

Python tiene **decoradores** — funciones que envuelven a otras funciones.
Son como `before_action` o `around_action` en Rails pero para métodos individuales.

```python
@timed
def call(self) -> dict:
    # Automáticamente loguea cuánto tardó el método
    # "[INFO] DashboardDataService.call completed in 0.342s"

@script_entrypoint
def main():
    # Captura cualquier excepción no manejada y la convierte en:
    # {"status": "error", "error": "mensaje del error"}
    # Luego llama sys.exit(1) para que Ruby sepa que falló
```

---

## El script principal: `dashboard/dashboard_data.py`

Este es el **ejercicio de comparación** — el mismo query SQL que hace
`DashboardDataService` en Ruby, pero ejecutado desde Python.

### Estructura del script

```python
#!/usr/bin/env python3
"""Descripción del script."""
import argparse, json, sys
from pathlib import Path

# Agregar scripts/ al PYTHONPATH para poder importar utils/
sys.path.insert(0, str(Path(__file__).parent.parent))

# Cargar variables de entorno desde el .env de Rails
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent.parent.parent / ".env")

from utils.db import PostgresClient
from utils.decorators import script_entrypoint, timed
from utils.logger import get_logger

logger = get_logger(__name__)

# El SQL es idéntico al heredoc de Ruby — mismas CTEs, mismas joins
_TRIPS_SQL = """
WITH booking_main_plant AS ( ... ),
IncrementoInfo AS ( ... ),
Cobros AS ( ... )
SELECT c.clv, c.razon_social, ...
FROM ttpn_bookings tb
...
"""
# Nota: En psycopg2, los parámetros van como %(nombre)s (no :nombre como en Rails)
# Nota: LIKE 'U%' se escribe como LIKE 'U%%' (psycopg2 usa % como marcador de parámetro)

class DashboardDataService:
    def __init__(self, from_date, to_date, bu_id=None, ...):
        self.db = PostgresClient()

    @timed
    def call(self) -> dict:
        period_data = self._query_trips(self.from_date, self.to_date)
        return {"period": {"from": ..., "to": ..., "data": period_data}}

    def _query_trips(self, from_date, to_date) -> list[dict]:
        bu_filter = "AND c.business_unit_id = %(bu_id)s" if self.bu_id else ""
        sql = _TRIPS_SQL.format(bu_filter=bu_filter)   # inyección del filtro
        rows = self.db.query(sql, {"from_date": from_date, ...})
        return [{"clv": r["clv"], "trips": int(r["trips"]), ...} for r in rows]

@script_entrypoint          # captura excepciones → JSON error
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="from_date", ...)
    parser.add_argument("--to",   dest="to_date", ...)
    parser.add_argument("--bu-id", dest="bu_id", ...)
    args = parser.parse_args()

    svc = DashboardDataService(from_date=args.from_date, ...)
    result = svc.call()
    print(json.dumps({"status": "success", **result}))  # ← stdout JSON

if __name__ == "__main__":
    main()
```

### Diferencias técnicas respecto a la versión Ruby

| Detalle | Ruby (`dashboard_data_service.rb`) | Python (`dashboard_data.py`) |
|---|---|---|
| Parámetros SQL | `:from`, `:to` (symbol notation) | `%(from_date)s` (psycopg2 notation) |
| LIKE en SQL | `LIKE 'U%'` | `LIKE 'U%%'` (escapar el %) |
| Filtro BU | Interpolación Ruby `#{"AND ..." if @bu_id}` | `.format(bu_filter=...)` en f-string |
| Callback de progreso | `progress.call(20, "msg")` | Logging con `@timed` |
| Ejecución | Síncrono en el request HTTP | Via Sidekiq (async), o CLI directo |
| Conexión BD | ActiveRecord → PostgreSQL | psycopg2 → PostgreSQL (mismo servidor) |

El SQL es **exactamente el mismo**. Mismas CTEs, mismas JOINs, misma función `cobro_fact()`.

---

## El puente: `EjecutarScriptPythonJob` (Ruby → Python)

Este es el archivo más importante de la integración. Vive en:
`ttpngas/app/jobs/ejecutar_script_python_job.rb`

### ¿Qué hace línea por línea?

```ruby
class EjecutarScriptPythonJob < ApplicationJob
  queue_as :default                    # cola de Sidekiq donde se encola
  SCRIPTS_ROOT = Rails.root.join('scripts').to_s  # /app/scripts (dentro del container)
  PYTHON_BIN   = ENV.fetch('PYTHON_BIN', 'python3')  # configurable por .env
  retry_on StandardError, wait: :polynomially_longer, attempts: 3  # reintentos automáticos

  def perform(script_name, script_params = {})
    script_path = File.join(SCRIPTS_ROOT, script_name)
    # Ejemplo: /app/scripts/dashboard/dashboard_data.py

    raise ArgumentError, "Script no encontrado" unless File.exist?(script_path)

    cmd = build_command(script_path, script_params)
    # Construye: "python3 /app/scripts/dashboard/dashboard_data.py --from=2026-01-01 --to=2026-04-28"

    stdout, stderr, status = Open3.capture3(
      { 'PYTHONPATH' => SCRIPTS_ROOT },  # le dice a Python dónde buscar 'utils'
      cmd
    )
    # Open3.capture3: ejecuta el comando y ESPERA a que termine
    # stdout = lo que imprimió el script (el JSON)
    # stderr = errores (si los hay)
    # status = código de salida (0 = éxito, 1 = error)

    unless status.success?
      raise "Python script falló: #{stderr}"  # Sidekiq reintentará
    end

    result = parse_output(stdout, script_name)
    # Convierte el JSON string en un Hash Ruby:
    # '{"status":"success","period":{...}}' → { "status" => "success", "period" => {...} }
    result
  end

  private

  def build_command(script_path, params)
    args = params.map { |key, value| "--#{key.to_s.tr('_', '-')}=#{value}" }
    # { user_id: 123, fecha: '2026-04-27' } → ["--user-id=123", "--fecha=2026-04-27"]
    "#{PYTHON_BIN} #{script_path} #{args.join(' ')}"
  end

  def parse_output(stdout, script_name)
    JSON.parse(stdout.strip)
  rescue JSON::ParserError
    { 'status' => 'ok', 'raw' => stdout.strip }  # fallback si el script no imprime JSON
  end
end
```

### ¿Qué es Open3?

`Open3` es una librería estándar de Ruby que permite ejecutar procesos externos
y capturar su salida. Es la forma segura de "hablar" con otro lenguaje:

```
Ruby (Sidekiq) ──Open3──► python3 script.py --param=valor
                           └── ejecuta el script
                           └── espera a que termine
                           └── captura todo lo que imprimió
Ruby (Sidekiq) ◄──────── '{"status":"success","data":[...]}'
```

---

## El flujo completo de punta a punta

### Escenario: FE solicita datos del dashboard

```
1. FE (Vue/Quasar)
   │  GET /api/v1/dashboard?from=2026-01-01&to=2026-04-28
   │
   ▼
2. Rails Controller
   │  DashboardsController#show
   │  ↓ llama al servicio Ruby (sin cambios)
   │  result = DashboardDataService.new(params, current_user, @bu_id).call
   │
   ▼
3. Ruby DashboardDataService
   │  Ejecuta el SQL complejo directamente
   │  Retorna: { period: { data: [...] } }
   │
   ▼
4. Rails Controller
   │  render json: { data: result }
   │
   ▼
5. FE recibe JSON y muestra el dashboard
```

**El FE no sabe ni le importa si Rails usó Ruby puro o llamó a Python.**
La respuesta es siempre el mismo JSON del controller Rails.

---

### Escenario: Comparar Python vs Ruby (el ejercicio)

Para el benchmark, el flujo alternativo sería:

```
1. Rails console / Sidekiq job
   │
   ▼
2. EjecutarScriptPythonJob.perform_later(
     'dashboard/dashboard_data.py',
     { from: '2026-01-01', to: '2026-04-28', bu_id: 5 }
   )
   │
   ▼
3. Sidekiq encola el job en Redis

4. Sidekiq worker toma el job y llama perform():
   │  cmd = "python3 /app/scripts/dashboard/dashboard_data.py --from=2026-01-01 --to=2026-04-28 --bu-id=5"
   │  stdout, stderr, status = Open3.capture3({'PYTHONPATH'=>'/app/scripts'}, cmd)
   │
   ▼
5. Python ejecuta dashboard_data.py:
   │  - Carga .env (mismas variables que Rails)
   │  - PostgresClient.query(SQL complejo con CTEs)
   │  - Conecta a la misma BD que Rails
   │  - Calcula resultados
   │  - print('{"status":"success","period":{...}}')
   │
   ▼
6. Open3 captura el stdout de Python

7. Ruby hace JSON.parse(stdout)
   │  result = { "status" => "success", "period" => { "data" => [...] } }
   │
   ▼
8. (Opcional) Guardar en caché, enviar por WebSocket, comparar con Ruby, etc.
```

---

### Escenario: Reporte contable automático (Sidekiq + cron)

```
Sidekiq Cron (cada noche a las 23:00)
   │
   ▼
EjecutarScriptPythonJob.perform_later(
  'reportes/contables.py',
  { user_id: user.id, fecha: Date.today.to_s }
)
   │
   ▼
Python contables.py:
  1. Conecta a BD
  2. SELECT tipo, monto FROM transacciones WHERE user_id=X AND fecha=Y
  3. Calcula: ingresos=850, gastos=200, ganancia=650, impuestos=195
  4. INSERT INTO reportes_diarios (...) ON CONFLICT DO UPDATE
  5. print('{"status":"success","reporte":{...}}')
   │
   ▼
Ruby recibe el JSON → puede:
  - Enviar email al usuario (ActionMailer)
  - Notificar por WebSocket (ActionCable)
  - Guardar en caché
   │
   ▼
FE (en cualquier momento):
  GET /api/v1/reportes/diarios?fecha=2026-04-27
  ← { data: { ingresos: 850, gastos: 200, ... } }
  (datos ya están en BD, Rails los sirve normalmente)
```

---

## Respuestas JSON — el contrato

**Todo script Python DEBE imprimir a stdout un JSON con esta estructura:**

### Éxito
```json
{
  "status": "success",
  "datos_del_script": "..."
}
```

### Error
```json
{
  "status": "error",
  "error": "mensaje descriptivo del error"
}
```

El decorador `@script_entrypoint` se encarga automáticamente del caso de error:

```python
@script_entrypoint
def main():
    # Si cualquier cosa falla aquí con una excepción no capturada:
    # → imprime {"status": "error", "error": "..."}
    # → llama sys.exit(1)
    # → Open3 en Ruby detecta exit code 1
    # → Sidekiq captura la excepción y reintenta el job
```

### Ejemplos reales de respuesta

**dashboard_data.py:**
```json
{
  "status": "success",
  "period": {
    "from": "2026-01-01",
    "to": "2026-04-28",
    "data": [
      {
        "clv": "C001",
        "razon_social": "Empresa Ejemplo SA de CV",
        "planta": "Planta Norte",
        "mes": "2026-01",
        "vehicle_type": "Autobús",
        "trips": 45,
        "money": 67500.0
      }
    ]
  }
}
```

**contables.py:**
```json
{
  "status": "success",
  "reporte": {
    "user_id": "123",
    "fecha": "2026-04-27",
    "ingresos": 850.00,
    "gastos": 200.00,
    "ganancia": 650.00,
    "impuestos": 195.00
  }
}
```

---

## Cómo Ruby lee la respuesta Python

En `EjecutarScriptPythonJob#parse_output`:

```ruby
result = JSON.parse(stdout.strip)
# result es ahora un Hash Ruby:
# {
#   "status" => "success",
#   "period" => {
#     "from" => "2026-01-01",
#     "data" => [{"clv"=>"C001", "trips"=>45, ...}]
#   }
# }

# Acceder a los datos:
result["period"]["data"].each do |row|
  puts row["razon_social"]  # "Empresa Ejemplo SA de CV"
  puts row["trips"]         # 45
end
```

---

## Cómo el FE lee los datos

El FE **nunca llama a Python directamente**. El FE siempre habla con Rails.

Cuando el script Python guarda resultados en la BD (como `contables.py` en `reportes_diarios`),
Rails tiene su propio endpoint que sirve esos datos:

```js
// En Vue/Quasar — llamada normal al API Rails
const { data } = await reportesService.getDiario({ fecha: '2026-04-27' })
// Rails sirve: GET /api/v1/reportes/diarios?fecha=2026-04-27
// Rails lee de reportes_diarios (tabla donde Python guardó el resultado)
// FE recibe el JSON de Rails, no sabe que Python lo calculó
```

Para el caso del dashboard (benchmark), el FE sigue llamando al mismo endpoint:
```js
// Sin cambios en el FE
const { data } = await dashboardService.getData({ from, to })
// Rails puede responder con DashboardDataService (Ruby) O con el resultado
// del job Python — eso es decisión de backend, transparente para el FE
```

---

## Variables de entorno relevantes para Python

Todas están en `ttpngas/.env` (el mismo archivo que usa Rails):

```bash
# BD local (Python las lee igual que Rails)
LOCAL_DB_HOST=host.docker.internal
LOCAL_DB_USER=postgres
LOCAL_DB_PSW=tu_password
LOCAL_DB_NAME=ttpngas_development   # NUEVA — agrega al .env

# Producción (si existe, Python la usa en vez de LOCAL_DB_*)
# DATABASE_URL=postgresql://user:pass@db.supabase.co:5432/postgres

# Python específicas
LOG_LEVEL=INFO                      # NUEVA
PYTHON_BIN=python3                  # NUEVA (default si no existe)
WHATSAPP_API_URL=                   # NUEVA (opcional)
WHATSAPP_API_TOKEN=                 # NUEVA (opcional)
```

**Las variables de BD no son nuevas** — Python usa las mismas que Rails.
Solo `LOCAL_DB_NAME` es nueva (Rails la infiere del `database.yml`, Python necesita ser explícita).

---

## Estado de los archivos modificados

### `ttpngas/Dockerfile` ✅ MODIFICADO

```diff
RUN apt-get update -qq && apt-get install -y \
  build-essential libpq-dev nodejs postgresql-client yarn curl git \
+ python3 \
+ python3-pip \
+ python3-venv \
  && rm -rf /var/lib/apt/lists/*

# En el stage development, después de COPY . .
+ RUN pip3 install --no-cache-dir --break-system-packages -r scripts/requirements.txt
```

### `ttpngas/.env.example` ✅ MODIFICADO

Agregadas al final:
```bash
LOG_LEVEL=INFO
PYTHON_BIN=python3
LOCAL_DB_NAME=ttpngas_development
WHATSAPP_API_URL=
WHATSAPP_API_TOKEN=
```

### `ttpngas/CLAUDE.md` ✅ MODIFICADO

Agregada sección completa **"Python Scripts & Automation"** con:
- Tabla cuándo usar Python vs Rails
- Estructura de carpetas
- Cómo Sidekiq ejecuta scripts
- Template de script nuevo
- Comandos de testing
- Reglas específicas de Python

### `docker-compose.yml` ✅ SIN CAMBIOS

Python corre dentro del mismo container que Rails. No se necesita ningún servicio nuevo.

### `setup.sh` ✅ SIN CAMBIOS

Python se instala automáticamente cuando Docker construye la imagen del backend
(`docker compose build api`). El desarrollador no necesita instalar nada extra.

---

## Cambios en el `CLAUDE.md` de infraestructura raíz

El CLAUDE.md raíz (`Kumi TTPN Admin V2/CLAUDE.md`) no necesita cambios profundos.
El único punto a agregar es una nota en la tabla de stack indicando que Python
vive dentro del container de Rails:

```markdown
| Jobs + Scripts | Sidekiq + Python 3.11 | Python dentro de kumi_api/kumi_sidekiq |
```

Sin embargo, **no se modifica el CLAUDE.md raíz** porque el nivel de detalle
de Python corresponde al sub-proyecto `ttpngas/` — y su CLAUDE.md ya fue actualizado.

---

## Checklist antes de levantar local por primera vez

### 1. Variables de entorno

Abre `ttpngas/.env` y verifica/agrega:

```bash
# Ya debería tener estos valores configurados:
LOCAL_DB_HOST=host.docker.internal
LOCAL_DB_USER=postgres
LOCAL_DB_PSW=tu_password_de_postgres

# AGREGAR si no existen:
LOCAL_DB_NAME=ttpngas_development
LOG_LEVEL=INFO
PYTHON_BIN=python3
```

### 2. Reconstruir la imagen Docker

Como se modificó el Dockerfile, **debes reconstruir la imagen** para que Python
quede instalado dentro del container:

```bash
cd "Kumi TTPN Admin V2/"

# Reconstruir la imagen del backend (incluye python3 + pip install)
docker compose --profile backend build api

# También Sidekiq (usa la misma imagen)
docker compose --profile backend build sidekiq
```

Esto tarda 2-5 minutos la primera vez porque descarga la imagen base y
corre `pip3 install`. Las siguientes veces usa caché de Docker y es más rápido.

### 3. Levantar el stack

```bash
docker compose --profile backend up -d
```

### 4. Verificar que Python está disponible

```bash
# Verificar versión de Python dentro del container
docker compose exec kumi_api python3 --version
# Debe mostrar: Python 3.11.x

# Verificar que las dependencias están instaladas
docker compose exec kumi_api pip3 list | grep -E "psycopg2|pandas|dotenv"
# Debe mostrar pandas, psycopg2-binary, python-dotenv
```

### 5. Test rápido del script de dashboard

```bash
# Ejecutar el script directamente dentro del container
docker compose exec kumi_api python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 \
    --to 2026-04-28

# Debe imprimir JSON como:
# {"status": "success", "period": {"from": "2026-01-01", "to": "2026-04-28", "data": [...]}}
```

### 6. Correr los tests Python

```bash
# Desde fuera del container (Python local)
cd ttpngas/
PYTHONPATH=scripts python3 -m pytest scripts/ -v

# Desde dentro del container
docker compose exec kumi_api bash -c "cd /app && PYTHONPATH=scripts python3 -m pytest scripts/ -v"
```

### 7. Probar el job de Sidekiq

Desde Rails console:

```bash
docker compose exec kumi_api bundle exec rails console
```

```ruby
# Encolar un job Python
EjecutarScriptPythonJob.perform_later(
  'dashboard/dashboard_data.py',
  { from: '2026-01-01', to: '2026-04-28' }
)
# Debe mostrar: #<EjecutarScriptPythonJob:... @job_id="...">

# Ver logs de Sidekiq en otra terminal:
# docker compose logs -f kumi_sidekiq
```

---

## Comandos de referencia rápida

```bash
# ── Desarrollo local (sin Docker) ────────────────────────────
cd ttpngas/
pip3 install -r scripts/requirements.txt

# Correr un script
python3 scripts/dashboard/dashboard_data.py --from 2026-01-01 --to 2026-04-28
python3 scripts/reportes/contables.py --user-id test --fecha 2026-04-27
python3 scripts/analisis/rentabilidad.py --mes 2026-04

# Tests con cobertura
PYTHONPATH=scripts python3 -m pytest scripts/ -v --cov=scripts --cov-report=term-missing

# ── Con Docker ───────────────────────────────────────────────
# Reconstruir imagen (necesario tras cambiar Dockerfile o requirements.txt)
docker compose --profile backend build api

# Ejecutar script dentro del container
docker compose exec kumi_api python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 --to 2026-04-28

# Tests dentro del container
docker compose exec kumi_api bash -c \
    "cd /app && PYTHONPATH=scripts python3 -m pytest scripts/ -v"

# Encolar job Python desde Rails console
docker compose exec kumi_api bundle exec rails console
# >> EjecutarScriptPythonJob.perform_later('dashboard/dashboard_data.py', {from:'2026-01-01',to:'2026-04-28'})

# Ver logs en tiempo real
docker compose logs -f kumi_sidekiq   # logs del worker que ejecuta Python
docker compose logs -f kumi_api       # logs del API Rails

# ── Agregar un script nuevo ──────────────────────────────────
# 1. Crear scripts/modulo/mi_script.py (usar el template del CLAUDE.md)
# 2. Crear scripts/modulo/test_mi_script.py
# 3. Si tiene deps nuevas: agregar a scripts/requirements.txt
# 4. Reconstruir imagen Docker: docker compose --profile backend build api
# 5. Documentar en ttpngas/Documentacion/07-integracion_python/
```

---

## Preguntas frecuentes

**¿Por qué no usar una API HTTP entre Ruby y Python?**
Eso sería la Opción 2 (servicio Python separado). Es más compleja: requiere
un nuevo container, endpoints HTTP, manejar timeouts y fallos de red, etc.
La Opción 1 (Python dentro del mismo container) es más simple y funciona igual
de bien cuando el volumen de trabajo no requiere escalar Python independientemente.

**¿Qué pasa si el script Python falla?**
`Open3.capture3` captura el exit code. Si es distinto de 0, el job Ruby
lanza una excepción y Sidekiq lo reintenta automáticamente hasta 3 veces
(con espera polinomial entre intentos). Después de 3 intentos fallidos,
el job queda en la cola de `dead` de Sidekiq y se puede revisar en
`http://localhost:3000/sidekiq`.

**¿Puedo llamar al script Python directamente desde un Controller (sin Sidekiq)?**
Sí, técnicamente con `Open3.capture3` directo en el controller. Pero no se recomienda
porque bloquearía el request HTTP mientras Python termina. Usar siempre `perform_later`
para que Sidekiq lo procese en background.

**¿El FE necesita cambios?**
No. El FE siempre habla con Rails. Si Python guarda en BD, Rails sirve esos datos
con sus endpoints normales. Si Python es solo un benchmark, el FE no se entera.

**¿Se puede usar pandas para análisis en tiempo real?**
Para análisis pesados sí, pero vía Sidekiq (async). Para cosas ligeras, Ruby puro
es suficiente. La regla: si necesitas DataFrames, groupby, correlaciones → Python.
Si es un cálculo simple → Rails.

**¿Qué versión de Python está instalada?**
Python 3.11 (instalado desde el stage base del Dockerfile con `python3` del sistema
Debian Bookworm, que provee Python 3.11).

---

## Archivos de referencia relacionados

- `ttpngas/Documentacion/07-integracion_python/` ← este documento
- `Documentacion/scripts/README.md` ← guía de uso de scripts
- `Documentacion/scripts/dashboard_data.md` ← documentación del ejercicio de benchmark
- `Documentacion/scripts/reportes_contables.md` ← documentación del reporte contable
- `ttpngas/CLAUDE.md` → sección "Python Scripts & Automation"
- `ttpngas/app/jobs/ejecutar_script_python_job.rb` ← el puente Ruby→Python
- `ttpngas/scripts/` ← todos los scripts Python
