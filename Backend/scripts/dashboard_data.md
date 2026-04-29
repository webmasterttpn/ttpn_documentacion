# dashboard/dashboard_data.py

**Ejercicio de comparación Python vs Ruby**

Script Python equivalente a `app/services/dashboard_data_service.rb`.
Corre el mismo SQL, misma lógica, directamente sobre PostgreSQL.

---

## Propósito

Validar si una versión Python de `DashboardDataService` tiene menor latencia
que la versión Rails. El FE no cambia — solo el backend decide qué implementación
usar. La versión Ruby se mantiene intacta.

---

## Uso

```bash
# Manual (local)
python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 \
    --to   2026-04-28

# Con período comparativo
python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 --to 2026-04-28 \
    --compare-from 2025-01-01 --compare-to 2025-04-28

# Con filtro de Business Unit
python3 scripts/dashboard/dashboard_data.py \
    --from 2026-01-01 --to 2026-04-28 \
    --bu-id 2
```

## Parámetros

| Parámetro | Requerido | Default | Descripción |
| --- | --- | --- | --- |
| `--from` | No | 1 Ene año actual | Fecha inicio período principal |
| `--to` | No | Hoy | Fecha fin período principal |
| `--bu-id` | No | None (ve todo) | ID Business Unit (sadmin ve todo) |
| `--compare-from` | No | None | Fecha inicio período comparativo |
| `--compare-to` | No | None | Fecha fin período comparativo |

---

## Salida

```json
{
  "status": "success",
  "period": {
    "from": "2026-01-01",
    "to":   "2026-04-28",
    "data": [
      {
        "clv":          "C001",
        "razon_social": "Empresa Ejemplo SA",
        "planta":       "Planta Norte",
        "mes":          "2026-01",
        "vehicle_type": "Autobús",
        "trips":        45,
        "money":        67500.0
      }
    ]
  },
  "compare": { ... }
}
```

---

## Diferencias con la versión Ruby

| Aspecto | Ruby (`DashboardDataService`) | Python (`dashboard_data.py`) |
| --- | --- | --- |
| Conexión BD | ActiveRecord (`exec_query`) | `psycopg2` directo |
| SQL | Heredoc con interpolación Ruby | f-string `{bu_filter}` |
| LIKE placeholder | `'U%'` normal | `'U%%'` (psycopg2 escapa `%`) |
| Progress callback | `progress.call(n, msg)` | Logging interno (`@timed`) |
| Ejecución | Síncrona en el request | Via `EjecutarScriptPythonJob` (Sidekiq) |

---

## Cómo comparar tiempos

```bash
# Ruby (medir en Rails console)
time_start = Time.now
DashboardDataService.new({from: '2026-01-01', to: '2026-04-28'}, current_user, nil).call
puts "#{Time.now - time_start}s"

# Python (medir con @timed — aparece en logs)
python3 scripts/dashboard/dashboard_data.py --from 2026-01-01 --to 2026-04-28
# Ver: "[INFO] DashboardDataService.call completed in X.XXXs"
```

---

## Dependencias

- `utils/db.py` → `PostgresClient`
- `utils/logger.py` → `get_logger`
- `utils/decorators.py` → `@timed`, `@script_entrypoint`
- PostgreSQL con tablas: `ttpn_bookings`, `clients`, `vehicles`, `vehicle_types`,
  `ttpn_booking_passengers`, `client_branch_offices`, `client_ttpn_services`,
  `cts_increments`, `cts_increment_details`, `ttpn_service_prices`
- Función custom: `cobro_fact(base_price, incremento)`

---

## Tests

```bash
PYTHONPATH=scripts pytest scripts/dashboard/ -v
```

6 tests — cubren: happy path, período comparativo, sin compare, resultado vacío,
casteo de tipos, filtro Business Unit.
