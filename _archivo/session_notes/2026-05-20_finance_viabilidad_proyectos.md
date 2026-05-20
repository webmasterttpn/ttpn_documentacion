# 2026-05-20 — Módulo Finanzas / Viabilidad de Proyectos

## Contexto

El taller arranca como proyecto nuevo con inversión inicial y gastos
fijos. Necesitaba reportería para medir ROI / break-even sin contaminar el
módulo de Mantenimiento (que se llevó la peor parte en sesiones previas).

Diseñado **multi-tenant a nivel proyecto**: cada negocio independiente
(Taller, Refacciones a Terceros, Capacitación) es un `Finance::Project`
con su propia inversión, gastos y revenue. Mismo schema, mismo reporte —
solo cambia el `project_id`.

## Decisiones clave

1. **No reusar Recepciones de Mantenimiento** para inversión/gastos —
   ensuciaría `average_cost` y rompería el modelo de inventario.
2. **3 tablas nuevas**: `finance_projects`, `finance_concepts`,
   `finance_entries`. Las dos últimas FK al proyecto.
3. **Catálogo de conceptos por proyecto** (Luz, Renta, Compra de
   compresor) que se reusan mes con mes. Las entries son los valores
   reales por periodo.
4. **Unique index (concept, period)** — evita capturar dos veces la luz
   del mismo mes.
5. **Revenue automático opt-in** vía `auto_revenue_source` en el proyecto.
   El proyecto Taller arranca con `mtto_work_orders` → suma `line_cost`
   de OTs `completed` como revenue (mide ahorro vs taller externo).
6. **`dependent: :restrict_with_error`** en project→concepts y
   concept→entries para no perder datos financieros por borrado
   accidental.

## Cambios

### Backend (ttpngas)

- 2 migrations:
  - `20260520215329_create_finance_projects_and_entries`
  - `20260520215508_seed_finance_privileges_and_project`
- Namespace `app/models/finance.rb`
- Modelos: `Finance::Project`, `Finance::Concept`, `Finance::Entry`
- Service: `Finance::DashboardCalculator`
- Controllers: `Projects`, `Concepts`, `Entries`, `Dashboard`
  (`Api::V1::Finance::*`)
- Routes en `config/routes/finance.rb`, montadas bajo `/api/v1/finance/*`
- Factories `spec/factories/finance.rb`
- Specs: `project_spec`, `concept_spec`, `entry_spec`,
  `dashboard_calculator_spec` → **21 examples, 0 failures**

### Frontend (ttpn-frontend)

- Service `src/services/finance.service.js` (4 recursos)
- Composables `src/composables/Finance/` (useFinanceCrud, useProjectsData,
  useConceptsData, useEntriesData, useDashboard)
- Páginas:
  - `Finance/ProjectsPage.vue` — CRUD de proyectos (Settings)
  - `Finance/ProjectViabilityPage.vue` — orquestador con tabs
    Dashboard / Conceptos / Movimientos + selector de proyecto + rango
- Componentes:
  - `DashboardPanel.vue` (4 KPI cards + ApexCharts líneas + breakdown
    por concepto + indicador break-even)
  - `ConceptsPanel.vue` + `ConceptForm.vue`
  - `EntriesPanel.vue` + `EntryForm.vue` (autocompleta monto con
    `default_amount` del concepto)
  - `KpiCard.vue` reutilizable
- Sidebar: agregadas entradas "Proyectos" y "Viabilidad de Proyectos"
  bajo Finanzas TTPN
- Rutas: `/settings/finance/projects` y `/finanzas/viabilidad`

### Privilegios

- `finance_projects` (Configuración) — `/settings/finance/projects`
- `finance_project_viability` (Finanzas TTPN) — `/finanzas/viabilidad`

Asignar a los administrativos que requieran visibilidad.

### Documentación

- `Documentacion/Backend/dominio/finanzas/viabilidad/viabilidad_proyectos.md`
- Capturas iniciales en `Documentacion/Manuales/finanzas/img/`

## Validación

- Migración aplicada localmente, seed creó "Taller Mecánico TTPN" con
  `auto_revenue_source: 'mtto_work_orders'`.
- Dashboard detecta los $340 de revenue auto provenientes del OUT-2026-001
  preexistente — verificado en pantalla.
- RuboCop 0 offenses · 21/21 specs Finance passing.
- ESLint 0 warnings en archivos nuevos.

## Próximos pasos sugeridos

- Capturar inversión inicial y gastos fijos del taller para que el
  dashboard tenga datos completos.
- Job mensual (Sidekiq) que cree entries pendientes para conceptos
  `monthly` el día 1 (no MVP).
- Vincular OTs a proyecto específico (`mtto_work_orders.project_id`)
  cuando aparezca un segundo proyecto que consuma OTs.
- Asignar privilegios `finance_project_viability` a los administrativos.
