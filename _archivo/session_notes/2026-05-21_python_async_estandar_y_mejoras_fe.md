# 2026-05-21 — Estándar Python+async para dashboards + mejoras FE (detalles + KPIs taller)

## Origen

Petición del usuario en sesión:

1. Detalles de Recepción y Salida no visibles al click del renglón
   (folio, productos, fechas, factura) — solo se veía el header.
2. Dashboard de Viabilidad necesita más KPIs operativos: vehículos por
   semana, servicios más atendidos, servicios por vehículo, horas por
   mecánico, servicios por mecánico, mayor atraso.
3. Selector de rango de fechas con calendario (no input con mask).
4. **Decisión arquitectónica nueva**: todo cálculo agregado / dashboard
   / estadístico debe ir en Python con ejecución asíncrona vía Sidekiq,
   con broadcast por ActionCable, para soportar reportes de 1+ año sin
   saturar memoria del web worker.

## Cambios

### Estándar documentado

- `ttpngas/CLAUDE.md` — nueva sección **"Regla NO negociable —
  Dashboards y cálculos estadísticos en Python + async"** con patrón
  obligatorio (202 Accepted, JobStatusChannel, prohibición de polling).
- Memoria persistente: `feedback_python_async_dashboards`.

### Backend

- **Borrado**: `app/services/mtto/workshop_ops_kpis_service.rb` (Ruby) +
  su spec — el código nuevo nació en Python desde el inicio.
- **Nuevo**: `scripts/mtto/workshop_ops_kpis.py` con 5 secciones agregadas
  100% en Postgres (vehicles_per_week, top_services, services_per_vehicle,
  mechanics, top_overdue). 9 tests pytest verde.
- **Nuevo**: `app/jobs/mtto/ops_kpis_job.rb` — ejecuta el script via
  `EjecutarScriptPythonJob` y hace broadcast a `job_status_#{user_id}`.
- **Cambiado**: `GET /api/v1/mtto/work_orders/ops_kpis` ahora responde
  `202 Accepted` con `{ job_id, status: 'queued', range }`. Antes era
  sync con Ruby service.
- **Refactor**: `Finance::DashboardCalculator` ahora acepta
  `from`/`to` como YYYY-MM-DD (preferido) o YYYY-MM (retro-compat),
  filtra `finance_entries` por `entry_date` (granularidad día).
- **Enriquecido**: serializer de `ProductReceiptsController` y
  `InventoryTransfersController` exponen items completos (product_name,
  clv, unit, pack_size_name, lote, fecha caducidad) y usuarios
  (received_by, requested_by, approved_by, transferred_by). Asociaciones
  agregadas a los modelos `Mtto::ProductReceipt` y `Mtto::InventoryTransfer`.

### Frontend

- **Nuevo**: `src/components/DateRangePicker.vue` reutilizable con
  `q-date range`. Sustituye los `q-input` con mask en la página de
  Viabilidad.
- **Nuevo**: `src/composables/Finance/useWorkshopOpsKpis.js` — encola el
  job vía `api.get('/work_orders/ops_kpis')` (202), se suscribe a
  `JobStatusChannel` filtrando por `job_id`. **Sin polling**.
- **Nuevo**: `src/pages/Finance/components/WorkshopOpsPanel.vue` con
  5 widgets dentro del tab Dashboard: gráfica de barras de vehículos
  por semana (ApexCharts), top servicios, servicios por vehículo, horas
  por mecánico, mayor atraso.
- **Nuevo**: `src/pages/Maintenance/components/ReceiptDetails.vue` y
  `TransferDetails.vue` — dialogs con header completo + tabla de items.
- **Cambiado**: `ReceiptsPage` y `TransfersPage` abren el dialog al
  click del renglón o del botón "Detalle". `mttoReceiptsService.find`
  carga el detalle completo.
- **Cambiado**: `ReceiptsTable` y `TransfersTable` muestran columnas
  extra (fecha, factura proveedor, factura fiscal en recepciones; fecha,
  OT en salidas). Mobile lists también.
- **Cambiado**: `ProjectViabilityPage` usa `DateRangePicker` global que
  alimenta todos los tabs. `WorkshopWeeklyTab` ahora recibe `range` por
  prop, ya no tiene sus propios inputs.
- **Extendido**: `AppTable.vue` ahora soporta opt-in `rowClickable` +
  `@row-click` para que se pueda picar el renglón completo, sin romper
  los otros usos.

### Documentación

- `Documentacion/Backend/dominio/mantenimiento/services/WorkshopOpsKpisService.md`
- `Documentacion/Backend/dominio/mantenimiento/controller/endpoints.md`
  (sección ops_kpis async)
- `Documentacion/Frontend/componentes/DateRangePicker.md`

## Verificación

- RuboCop: 0 offenses en archivos tocados.
- RSpec: 22/22 verde (`dashboard_calculator_spec`, `work_orders_spec`).
- Pytest: 9/9 verde (`scripts/mtto/test_workshop_ops_kpis.py`).
- ESLint: limpio en archivos tocados.
- Smoke test contra demo del 2026-05-21: el script Python responde en
  ~88ms con los KPIs esperados (3 OT internas, 2 externas, top servicios
  ordenados, etc.).

## Decisiones no obvias

- **DashboardCalculator NO se portó a Python** aunque sigue siendo
  agregación. Razón: era código legacy (refactor menor de date range,
  no nuevo). El estándar dice retrofitear solo cuando se modifica
  sustancialmente; queda en deuda técnica si el volumen crece.
- **`top_overdue` mide post-mortem**, no monitoreo en vivo. El usuario
  picó la opción "OTs completadas con más exceso vs tiempo estándar".
- **Granularidad día a día** en el dashboard de finanzas: el modelo
  `Finance::Entry` tiene tanto `period` (YYYY-MM varchar derivado) como
  `entry_date` (date real). El refactor usa `entry_date` para queries
  de rango, manteniendo `monthly_series` agrupando por mes para el
  gráfico (los meses se derivan del rango de fechas).
