# 🚀 PROMPT COMPLETO: Python + Rails (Opción 1)
## Copia esto y pásalo a Claude para que genere TODOS los archivos

---

# CONTEXTO DEL PROYECTO

```
Proyecto: TTPN Kumi Admin
Ubicación: ~/Documentos/Ruby/Kumi TTPN Admin V2/

Estructura actual:
├─ Kumi TTPN Admin V2/
│  ├─ docker-compose.yml (maestro, con profiles)
│  ├─ CLAUDE.md (reglas del monorepo)
│  │
│  ├─ ttpngas/
│  │  ├─ CLAUDE.md (reglas Rails)
│  │  ├─ Dockerfile (solo Ruby actualmente)
│  │  ├─ Gemfile
│  │  ├─ app/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ jobs/
│  │  │  └─ services/
│  │  ├─ spec/
│  │  ├─ db/
│  │  └─ config/
│  │
│  └─ ttpn-frontend/
│     └─ ... (Vue/Quasar)
```

---

# OBJETIVO

Integrar **Python dentro del mismo Dockerfile de Rails** (Opción 1) para que:

1. Sidekiq pueda ejecutar scripts Python directamente
2. Scripts Python lean/escriban en Supabase (misma BD que Rails)
3. Reportes automáticos generados por Python en 2do plano
4. TODO en un solo container Docker (sin servicios separados)

---

# ARCHIVOS A MODIFICAR/CREAR

## ARCHIVOS A CREAR (Nuevos)

```
ttpngas/scripts/
├─ __init__.py                         (vacío, marca como package Python)
├─ requirements.txt                    (dependencias Python)
├─ conftest.py                         (pytest config)
├─ main.py                             (entry point opcional, no usado aquí)
│
├─ utils/
│  ├─ __init__.py
│  ├─ db.py                            (Cliente Supabase para Python)
│  ├─ logger.py                        (Logging setup)
│  └─ decorators.py                    (Helpers)
│
├─ reportes/
│  ├─ __init__.py
│  ├─ contables.py                     (Script: generar reporte contable)
│  └─ test_contables.py                (Tests pytest)
│
├─ analisis/
│  ├─ __init__.py
│  ├─ rentabilidad.py                  (Script: análisis rentabilidad)
│  └─ test_rentabilidad.py
│
└─ integraciones/
   ├─ __init__.py
   └─ whatsapp.py                      (Script: WhatsApp automático)

Documentacion/scripts/
├─ reportes_contables.md               (Documentación del script)
├─ analizar_rentabilidad.md
└─ README.md                           (Guía de scripts)
```

## ARCHIVOS A MODIFICAR (Existentes)

```
ttpngas/
├─ Dockerfile                          (Agregar Python)
├─ Gemfile                             (Agregar httparty si no está)
├─ CLAUDE.md                           (Agregar sección Python)
├─ .env.example                        (Agregar variables Python)
└─ config/
   └─ sidekiq.yml                      (Ya existe, verificar queues)

app/jobs/
├─ ejecutar_script_python_job.rb       (NUEVO: Job para ejecutar scripts)

Kumi TTPN Admin V2/
├─ docker-compose.yml                 (NO MODIFICAR, Python va dentro de Rails)
└─ CLAUDE.md                           (Agregar referencia a Python)
```

---

# REQUISITOS TÉCNICOS

## Backend (Rails)
- Rails 7.1 API
- Ruby 3.3
- Sidekiq para jobs
- Redis para queue
- Supabase como BD

## Python (Nuevo)
- Python 3.11
- Librerías: dotenv, requests, pandas, supabase-py, pytest
- Mismo .env que Rails (SUPABASE_URL, SUPABASE_KEY)
- Estructura: módulos reutilizables

## Docker
- UN SOLO Dockerfile con Ruby + Python
- Sin cambios en docker-compose.yml (Python va dentro)
- Scripts ejecutados por Sidekiq usando backticks (`)

---

# ESPECIFICACIONES POR ARCHIVO

## 1️⃣ ttpngas/Dockerfile (MODIFICAR)

**Cambios:**
- Agregar `RUN apt-get install python3 python3-pip`
- Copiar `scripts/requirements.txt`
- Ejecutar `pip3 install -r scripts/requirements.txt`
- TODO en "development" target (ya existe)

**Resultado:** Un Dockerfile que instala Ruby Y Python

---

## 2️⃣ ttpngas/scripts/requirements.txt (CREAR)

**Contenido:**
```
python-dotenv==1.0.0
requests==2.31.0
supabase-py==0.15.0
pandas==2.0.0
pytest==7.4.0
pytest-cov==4.1.0
```

---

## 3️⃣ ttpngas/scripts/utils/db.py (CREAR)

**Qué hace:**
- Cliente Supabase reutilizable para todos los scripts
- Lee SUPABASE_URL y SUPABASE_KEY de .env
- Métodos: query(), insert(), update(), delete()
- Logging de todas las operaciones

**Interfaz:**
```python
from utils.db import SupabaseClient

db = SupabaseClient()
transacciones = db.query('transacciones', filters={...})
db.insert('reportes_diarios', {...})
```

---

## 4️⃣ ttpngas/scripts/utils/logger.py (CREAR)

**Qué hace:**
- Setup de logging para scripts Python
- Logs a stdout (para Docker ver en logs)
- Niveles: DEBUG, INFO, WARNING, ERROR
- Formato: [TIMESTAMP] [LEVEL] mensaje

---

## 5️⃣ ttpngas/scripts/reportes/contables.py (CREAR)

**Qué hace (Script #1):**
- Lee transacciones de Supabase para un usuario y fecha
- Calcula: ingresos, gastos, ganancia, impuestos
- Guarda resultado en tabla `reportes_diarios`
- Puede ejecutarse:
  - Via `python3 scripts/reportes/contables.py --user-id=123 --fecha=2026-04-27`
  - Via Sidekiq: `output = \`python3 scripts/reportes/contables.py --user-id=#{user_id}\``

**Argumentos:**
- `--user-id` (requerido): ID del usuario
- `--fecha` (opcional): Fecha YYYY-MM-DD, default = hoy

**Salida:**
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

**Testing:**
- Tests en `test_contables.py`
- Mock de SupabaseClient
- Casos: happy path, usuario sin datos, error en BD

---

## 6️⃣ ttpngas/scripts/analisis/rentabilidad.py (CREAR - Opcional)

**Qué hace (Script #2):**
- Lee reportes_diarios del mes
- Analiza por categoría usando Pandas
- Identifica servicios más rentables
- Genera CSV exportable

---

## 7️⃣ ttpngas/app/jobs/ejecutar_script_python_job.rb (CREAR)

**Qué hace (Job de Sidekiq):**
- Recibe: nombre del script, parámetros
- Ejecuta: `python3 scripts/{script_name} --param=value`
- Captura output JSON
- Guarda en BD (o notifica usuario)
- Error handling con reintentos

**Uso desde controller:**
```ruby
EjecutarScriptPythonJob.perform_later('reportes/contables.py', {user_id: 123, fecha: '2026-04-27'})
```

---

## 8️⃣ ttpngas/CLAUDE.md (MODIFICAR)

**Agregar al final una nueva sección:**

```markdown
## Python Scripts & Automation

[Copiar la sección completa de: auditoria-claude-md-python.md]

Incluir:
- Cuándo usar Python vs Rails
- Estructura de carpetas
- Cómo Sidekiq ejecuta scripts
- Template de script
- Testing con pytest
- Documentación de scripts
- Comandos útiles
- Checklist actualizado
```

---

## 9️⃣ ttpngas/.env.example (MODIFICAR)

**Agregar variables Python:**
```bash
# Python/Scripts
PYTHON_ENV=development
LOG_LEVEL=INFO
LOG_DIR=./logs
```

---

## 🔟 ttpngas/Gemfile (MODIFICAR)

**Agregar si no está:**
```ruby
gem 'httparty'  # Para llamadas HTTP (opcional, por si future HTTP calls)
```

---

## 1️⃣1️⃣ Documentacion/scripts/README.md (CREAR)

**Qué incluye:**
- Introducción a scripts Python en TTPN
- Cómo ejecutar local
- Cómo agregar nuevo script
- Testing
- Troubleshooting

---

## 1️⃣2️⃣ Documentacion/scripts/reportes_contables.md (CREAR)

**Documentación del script:**
- Propósito
- Uso
- Parámetros
- Resultado esperado
- Cuándo corre (cron, manual, job)
- Dependencias

---

# FLUJO DE EJECUCIÓN (Resumen)

```
1. Usuario POST /api/v1/reportes/generar
   └─ ReportesController#generar
      └─ EjecutarScriptPythonJob.perform_later('reportes/contables.py', {user_id: 123})

2. Sidekiq procesa el job
   └─ Ejecuta: python3 scripts/reportes/contables.py --user-id=123
      └─ Script Python:
         ├─ Lee transacciones de Supabase
         ├─ Calcula
         ├─ Guarda en reportes_diarios
         └─ Retorna JSON

3. Sidekiq recibe resultado
   └─ Notifica usuario (email, Slack, etc)

4. Usuario ve reporte en dashboard (Vue)
```

---

# TESTING

## Local (Sin Docker)

```bash
cd ttpngas/

# Instalar Python deps
pip install -r scripts/requirements.txt

# Ejecutar script manualmente
python3 scripts/reportes/contables.py --user-id=test-user --fecha=2026-04-27

# Tests pytest
pytest scripts/ -v --cov
```

## Con Docker

```bash
docker compose --profile backend up -d

# Ejecutar script dentro del container
docker compose exec kumi_api python3 scripts/reportes/contables.py --user-id=test-user

# Ver logs
docker compose logs -f kumi_api
docker compose logs -f kumi_sidekiq
```

---

# VALIDACIÓN POST-IMPLEMENTACIÓN

## Checklist Técnico

- [ ] Dockerfile contiene `RUN apt-get install python3 python3-pip`
- [ ] Dockerfile copia y instala `scripts/requirements.txt`
- [ ] `/scripts` carpeta existe con estructura correcta
- [ ] `scripts/utils/db.py` conecta a Supabase correctamente
- [ ] `scripts/reportes/contables.py` corre sin errores
- [ ] `EjecutarScriptPythonJob` existe y se puede encolar
- [ ] `pytest scripts/ --cov` da resultado > 85%
- [ ] `docker compose up` levanta sin errores
- [ ] Script ejecuta dentro del container: `docker compose exec kumi_api python3 scripts/...`

## Checklist Documentación

- [ ] CLAUDE.md tiene sección Python
- [ ] `.env.example` tiene variables Python
- [ ] `Documentacion/scripts/` existe con READMEs
- [ ] Cada script tiene docstring
- [ ] Tests documentados

## Checklist Funcional

- [ ] Sidekiq puede encolar `EjecutarScriptPythonJob`
- [ ] Script genera reporte sin errores
- [ ] Reporte se guarda en Supabase
- [ ] Usuario ve reporte en dashboard

---

# NOTAS IMPORTANTES

1. **Todo en UN Dockerfile:** Python NO está en otro servicio. Va dentro del mismo Dockerfile de Rails.

2. **Sin cambios en docker-compose.yml:** El docker-compose.yml del padre NO se modifica. Python se ejecuta dentro del container `kumi_api` (Rails).

3. **Sidekiq es la clave:** Los scripts Python se ejecutan DENTRO de jobs Sidekiq, en 2do plano.

4. **Mismo .env:** Rails y Python comparten el mismo `.env` (copiar variables al container).

5. **Reutilizable:** Cada proyecto (estética, transportista, etc) tendrá sus propios scripts en `/scripts` pero reutilizarán `utils/db.py` y `utils/logger.py`.

---

# PRÓXIMOS PASOS (Después de implementar)

1. **Cron jobs:** Usar Sidekiq-cron para ejecutar scripts automáticamente cada noche
2. **Reportes por email:** Usar ActionMailer para enviar reportes a usuarios
3. **Dashboards:** Mostrar resultados de scripts en Vue (tabla, gráficos)
4. **Escalabilidad:** Si necesitas Python separado, migrar a Opción 2 (HTTP POST)

---

# ARCHIVOS DE REFERENCIA

Ya tienes estos documentos completos:

1. `auditoria-claude-md-python.md` → Copia la sección Python aquí al CLAUDE.md
2. `sidekiq-python-comunicacion-explicado.md` → Referencia técnica
3. `estrategia-python-docker-definitiva.md` → Visión general

---

# INSTRUCCIONES FINALES

**Paso 1: Genera TODOS los archivos**

Pídele a Claude que genere:
- ✅ Dockerfile actualizado
- ✅ Todos los archivos en `/scripts`
- ✅ Job de Sidekiq
- ✅ CLAUDE.md actualizado
- ✅ Documentación en `/Documentacion/scripts/`

**Paso 2: Reemplaza archivos en tu local**

```bash
cd ~/Documentos/Ruby/Kumi\ TTPN\ Admin\ V2/ttpngas/

# Copiar archivos generados
cp <archivos_nuevos> .
```

**Paso 3: Test local**

```bash
# Instalar deps
pip install -r scripts/requirements.txt

# Test script
python3 scripts/reportes/contables.py --user-id=test --fecha=2026-04-27

# Test Docker
docker compose --profile backend up -d
docker compose exec kumi_api python3 scripts/reportes/contables.py --user-id=test
```

**Paso 4: Commit a Git**

```bash
git add .
git commit -m "feat: Add Python scripts integration (Opción 1) - Sidekiq + reportes automáticos"
git push origin main
```

---

**¿Listo? Pasa este prompt a Claude y que genere TODO.** 🚀
