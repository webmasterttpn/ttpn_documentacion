# Workshop Ops KPIs (Python) — `scripts/mtto/workshop_ops_kpis.py`

## Qué hace

Devuelve KPIs operativos del taller para el Dashboard de Viabilidad:

- `vehicles_per_week` — vehículos distintos de la flota TTPN atendidos por
  semana ISO (`YYYY-Www`). Excluye OTs externas.
- `top_services` — top 5 servicios más solicitados (conteo de OTs).
- `services_per_vehicle` — top 10 vehículos de la flota con más servicios.
- `mechanics` — horas y OTs y servicios por mecánico (incluye internas y
  externas).
- `top_overdue` — top 10 OTs completadas donde `actual_minutes` excedió
  `estimated_total_minutes`, ordenado por exceso descendente.

## Por qué Python (no Ruby)

Estándar Kumi (ttpngas/CLAUDE.md sección "Regla NO negociable —
Dashboards y cálculos estadísticos en Python + async"): toda agregación
estadística que alimente un dashboard se implementa en Python para soportar
rangos de 1+ año sin saturación de memoria del web worker. El GROUP BY ocurre
100% en Postgres; el script solo serializa.

## Patrón de invocación

```ruby
# desde controller — responde 202 Accepted con job_id
job_id = Mtto::OpsKpisJob.perform_async(
  current_user.id, current_business_unit_id, from_date, to_date
)
render json: { job_id: job_id, status: 'queued' }, status: :accepted
```

El `Mtto::OpsKpisJob` ejecuta el script vía `EjecutarScriptPythonJob` (Open3),
parsea el JSON de stdout y hace broadcast:

```ruby
ActionCable.server.broadcast(
  "job_status_#{user_id}",
  { type: 'job_done', job_id: jid, kind: 'mtto_ops_kpis', data: result }
)
```

El FE se suscribe a `JobStatusChannel` filtrando por `job_id` (ver
`src/composables/Finance/useWorkshopOpsKpis.js`). Polling prohibido.

## Parámetros (CLI)

| Flag | Tipo | Default |
|---|---|---|
| `--from` | YYYY-MM-DD | hoy - 6 meses |
| `--to` | YYYY-MM-DD | hoy |
| `--business-unit-id` | int | requerido |

## Estructura del JSON devuelto

```text
{
  "status": "success",
  "range": { "from": "2026-01-01", "to": "2026-05-21" },
  "vehicles_per_week": { "2026-W18": 3, "2026-W19": 2, ... },
  "top_services": [
    { "service_id": 1, "service_name": "Cambio aceite y filtros", "count": 12 }
  ],
  "services_per_vehicle": [
    { "vehicle_id": 1, "label": "T035 · ABC-123", "services_count": 4 }
  ],
  "mechanics": [
    { "mechanic_id": 10, "name": "Juan Pérez", "hours": 12.5,
      "ot_count": 6, "services_count": 9 }
  ],
  "top_overdue": [
    { "work_order_id": 42, "work_order_number": "OT-2026-042",
      "vehicle_label": "T010 · XYZ-789", "mechanic_name": "Pedro López",
      "estimated_minutes": 60, "actual_minutes": 150,
      "excess_minutes": 90, "excess_pct": 150.0,
      "completed_at": "2026-05-18T14:30:00" }
  ]
}
```

## Tests

`scripts/mtto/test_workshop_ops_kpis.py` — 9 tests con `pytest`,
`PostgresClient` mockeado. Sin BD real.

```bash
docker exec kumi_api bash -lc 'cd /app && PYTHONPATH=scripts python3 -m pytest scripts/mtto/'
```

## Dependencias

- `utils/db.py` (PostgresClient con psycopg2)
- `utils/decorators.py` (`@script_entrypoint`, `@timed`)
- `utils/logger.py`
- Tablas: `mtto_work_orders`, `mtto_work_order_services`, `mtto_services`,
  `mtto_inventory_transfer_items`, `vehicles`, `employees`.

## Migración del Ruby service

El service Ruby `Mtto::WorkshopOpsKpisService` se borró en favor de este
script Python. No retrofitear servicios legacy a menos que se modifique
sustancialmente; esto era código nuevo y debía nacer en Python.
