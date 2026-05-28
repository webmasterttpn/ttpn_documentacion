# 2026-05-28 — Fix Cuadre de Servicios vacío tras cutover (backfill BU incompleto)

## Síntoma
Usuario reporta que la pantalla **Cuadre de Servicios** (`/ttpn-bookings/cuadre`)
carga pero muestra la tabla vacía / con números mal contados en producción
(Railway + Netlify), después del cutover de la BD del legacy.

- FE renderea el page sin error visual.
- `POST /api/v1/cuadre/resumen` responde `202 + job_id`.
- El job Python `Cuadre::ResumenJob` (`scripts/cuadre/resumen_por_planta.py` y
  `resumen_por_chofer.py`) completa exitosamente y emite `job_done` por
  `JobStatusChannel`.
- El payload `data: []` (o subcontado) llega al FE — todo el pipeline funciona,
  pero el SQL no devuelve filas.

## Causa raíz

El SQL del cuadre filtra por business unit:

```sql
AND (%(bu_id)s IS NULL OR tb.business_unit_id = %(bu_id)s)
```

Con un usuario admin normal (no sadmin), `bu_id = 1` (su BU). El cutover trae
todas las filas legacy de `ttpn_bookings` y `travel_counts` con
`business_unit_id = NULL` (la migración
`20260422185129_add_business_unit_to_operational_core_tables.rb` agregó la
columna como nullable porque hacer UPDATE de millones de filas durante la
migración es inviable; el rake `db:post_migration_backfill` se encarga del
relleno post-restore).

**Bug**: el rake solo backfilleaba `business_unit_id` en 4 tablas (Client,
VehicleAsignation, DriverRequest, ServiceAppointment) pero la migración agregó
la columna a 6 tablas críticas más: `vehicles`, `gas_files`, `gas_charges`,
`gasoline_charges`, `ttpn_bookings`, `travel_counts`. Quedaron huérfanas →
cualquier reporte multitenant (cuadre, gasolina, dashboards) las excluía.

## Fix

`lib/tasks/post_migration_backfill.rake` reestructurado con una sola lista
canónica `operational_models` que cubre tanto el backfill de `business_unit_id`
como el de `created_by_id/updated_by_id`. Para cada modelo:

- Si tiene `business_unit_id` y hay filas con NULL → `update_all` a
  `BusinessUnit.first.id`.
- Si tiene `created_by_id` y hay filas con NULL → `update_all` a
  `User.order(id: :asc).first.id` para ambos campos de audit.

Idempotente (la segunda corrida no hace nada).

## Hallazgos de la corrida local

La primera corrida en la DB de desarrollo (que arrastra varios cutovers de
prueba) encontró:

| Tabla | BU NULL | Audit NULL |
| --- | ---: | ---: |
| Vehicle           |     5 |    389 |
| GasCharge         | 77,495 |  — |
| GasFile           | 21,246 |  — |
| GasolineCharge    | 17,019 |  — |
| Employee          |     1 |  1,282 |
| Client            |   — |     71 |
| VehicleAsignation |   — |  8,494 |
| TtpnBooking       |   — | 107,313 |
| Concessionaire    |   — |     97 |

Esto confirma que el bug afectaba a más reportes que solo el cuadre.

## Acción del usuario post-deploy

1. Railway redeploya solo (push a `github transform_to_api` → auto-deploy).
2. Disparar el cURL del paso 1 de `PASOS_TRAS_MIGRACION.md`:

   ```bash
   curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
     -H "Content-Type: application/json" \
     -H "X-Maintenance-Token: $MAINT_TOKEN" \
     -d '{"task": "backfill_tables"}'
   ```

3. Esperar 1–3 minutos (el rake hace `update_all` en lotes grandes).
4. Re-abrir la pantalla de Cuadre y "Generar". Debe mostrar todos los clientes
   con sus programados y capturados.

## Archivos tocados

- `ttpngas/lib/tasks/post_migration_backfill.rake` — reescritura con lista
  canónica.
- `Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md` §1 — nota
  explícita de las tablas cubiertas y advertencia "si ves ceros, falta este
  paso".

## Referencias cruzadas

- Migración: `db/migrate/20260422185129_add_business_unit_to_operational_core_tables.rb`
- SQL del cuadre: `scripts/cuadre/resumen_por_planta.py:43-74` y
  `resumen_por_chofer.py:38-69`
- Controller: `app/controllers/api/v1/cuadre_controller.rb`
- BaseController BU logic: `app/controllers/api/v1/base_controller.rb:122-145`
