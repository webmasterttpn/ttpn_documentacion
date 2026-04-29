# Scripts Python — Kumi TTPN Admin

Scripts Python que corren dentro del mismo container Docker que Rails,
ejecutados por Sidekiq en 2do plano o manualmente para análisis.

---

## Arquitectura

```
Rails (Sidekiq) → EjecutarScriptPythonJob → python3 scripts/xxx.py --param=value
                                                          ↓
                                              Conecta a misma PostgreSQL (psycopg2)
                                                          ↓
                                              Imprime JSON a stdout → Sidekiq captura
```

---

## Scripts disponibles

| Script | Propósito | Uso |
| --- | --- | --- |
| `dashboard/dashboard_data.py` | Equivalente Python de `DashboardDataService` — benchmark | Manual / comparativo |
| `reportes/contables.py` | Reporte contable diario por usuario | Sidekiq / manual |
| `analisis/rentabilidad.py` | Análisis mensual con Pandas, exporta CSV | Manual / Sidekiq |
| `integraciones/whatsapp.py` | Envío automático WhatsApp | Sidekiq |

---

## Cómo ejecutar local (sin Docker)

```bash
cd ttpngas/

# 1. Instalar dependencias
pip install -r scripts/requirements.txt

# 2. El script lee el .env del directorio raíz de Rails
#    Asegúrate de tener .env con DATABASE_URL o LOCAL_DB_* configurados

# 3. Ejecutar un script
python3 scripts/dashboard/dashboard_data.py --from 2026-01-01 --to 2026-04-28

python3 scripts/reportes/contables.py --user-id 123 --fecha 2026-04-27

python3 scripts/analisis/rentabilidad.py --mes 2026-04 --output /tmp/rentabilidad.csv
```

---

## Cómo ejecutar con Docker

```bash
# Levantar el stack
docker compose --profile backend up -d

# Ejecutar script dentro del container de Rails
docker compose exec kumi_api python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 --to 2026-04-28

docker compose exec kumi_api python3 scripts/reportes/contables.py \
    --user-id 123 --fecha 2026-04-27

# Ver logs de ejecución (cuando lo lanza Sidekiq)
docker compose logs -f kumi_sidekiq
```

---

## Cómo encolar desde Rails (Sidekiq)

```ruby
# Desde un controller o cron job
EjecutarScriptPythonJob.perform_later(
  'dashboard/dashboard_data.py',
  { from: '2026-01-01', to: '2026-04-28', bu_id: current_business_unit_id }
)

EjecutarScriptPythonJob.perform_later(
  'reportes/contables.py',
  { user_id: current_user.id, fecha: Date.today.to_s }
)
```

---

## Testing con pytest

```bash
cd ttpngas/

# Todos los tests
PYTHONPATH=scripts pytest scripts/ -v --cov=scripts --cov-report=term-missing

# Un módulo específico
PYTHONPATH=scripts pytest scripts/dashboard/ -v

# Con threshold (mismo estándar que RSpec: 85%)
PYTHONPATH=scripts pytest scripts/ --cov=scripts --cov-fail-under=85
```

---

## Agregar un script nuevo

1. Crear `scripts/{modulo}/mi_script.py` usando el template en `ttpngas/CLAUDE.md`
2. Crear `scripts/{modulo}/test_mi_script.py` con mocks de `PostgresClient`
3. Si necesita dependencias nuevas: agregar a `scripts/requirements.txt`
4. Documentar en `Documentacion/scripts/mi_script.md`
5. Verificar que imprime JSON válido a stdout

---

## Conexión a la base de datos

Los scripts usan `utils/db.py → PostgresClient` con `psycopg2` para conexión
directa a PostgreSQL. Lee del `.env`:

- `DATABASE_URL` (producción / Railway) — tiene prioridad
- `LOCAL_DB_HOST` + `LOCAL_DB_USER` + `LOCAL_DB_PSW` + `LOCAL_DB_NAME` (desarrollo)

**No** usar ORM ni la API REST de Supabase — las consultas complejas con CTEs
y funciones custom (`cobro_fact`, etc.) requieren SQL directo.

---

## Troubleshooting

| Problema | Causa probable | Solución |
| --- | --- | --- |
| `ModuleNotFoundError: utils` | `PYTHONPATH` no apunta a `scripts/` | Ejecutar con `PYTHONPATH=scripts python3 scripts/...` |
| `psycopg2.OperationalError` | BD no accesible | Verificar `LOCAL_DB_HOST` en `.env` |
| `%%` en SQL genera error | Usar `%` en lugar de `%%` en LIKE | psycopg2 usa `%` como placeholder — doblar: `LIKE 'U%%'` |
| Job Python falla con exit 1 | Error en el script | `docker compose logs kumi_sidekiq` para ver stderr |
| Script no encontrado | Ruta relativa incorrecta | Ruta es relativa a `scripts/`, ej. `'reportes/contables.py'` |
