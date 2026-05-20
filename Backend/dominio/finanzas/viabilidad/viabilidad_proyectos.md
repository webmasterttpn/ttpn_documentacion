# Viabilidad de Proyectos (Finanzas)

Módulo multi-tenant a nivel proyecto. Cada **proyecto** es un negocio
independiente con su propia inversión, gastos y revenue. Permite medir
ROI / break-even / burn rate de cada uno por separado sin duplicar tablas.

## Modelos

### `Finance::Project` (`finance_projects`)

- `name`, `slug` (unique por BU, validación con regex `^[a-z0-9-]+$`).
- `starts_at`, `is_active`.
- `auto_revenue_source` ∈ `{'none', 'mtto_work_orders'}` — si es
  `mtto_work_orders` el Dashboard suma como revenue el `materials_cost` de
  las OTs `completed` de la BU. Útil para proyectos que aún no facturan
  externos (taller interno) pero quieren medir el "ahorro" generado contra
  inversión.
- `has_many :concepts, :entries, dependent: :restrict_with_error` — no se
  destruye un proyecto con movimientos (sería pérdida silenciosa de datos).

Seed inicial (migration `20260520215508`): proyecto **Taller Mecánico TTPN**
con `auto_revenue_source: 'mtto_work_orders'`.

### `Finance::Concept` (`finance_concepts`)

Template/etiqueta dentro de un proyecto: "Luz", "Renta del local", "Compra
del compresor inicial". Define:

- `entry_type` ∈ `{'investment', 'fixed_expense', 'revenue'}`.
- `frequency` ∈ `{'one_time', 'monthly', 'quarterly', 'yearly'}` — solo
  documenta intención; no automatiza generación de entries.
- `default_amount` (opcional, sugerencia que el form prellena).
- `supplier_id` (opcional, reusa `suppliers`).
- `is_active` — los inactivos no aparecen en el dropdown del form de entry.

### `Finance::Entry` (`finance_entries`)

Movimiento real por periodo. Un concepto recurrente como "Luz" tiene una
entry **por mes**, cada una con el monto real de esa factura.

- `period` (YYYY-MM) se deriva del `entry_date` antes de validar.
- `finance_project_id` se asigna desde el concept si falta.
- `amount > 0`, `entry_date` requerido.
- **Unique index** `(finance_concept_id, period)` — un concepto NO puede
  tener dos entries del mismo mes (evita capturas duplicadas).
- Cross-project guard: si el concept y la entry señalan proyectos
  distintos, se rechaza.

## Cálculo del Dashboard

`Finance::DashboardCalculator.new(project, from:, to:).call` devuelve:

```ruby
{
  project: { id, name, slug, starts_at, auto_revenue_source },
  range:   { from, to, months: [...] },
  kpis: {
    investment_lifetime,    # Σ investment desde siempre
    fixed_expense_range,    # Σ gastos fijos del rango
    fixed_expense_lifetime, # Σ gastos fijos desde siempre
    revenue_range,          # Σ revenue manual + auto del rango
    revenue_lifetime,       # Σ revenue manual + auto desde siempre
    net_lifetime,           # revenue - investment - fixed_expense
    roi_pct,                # net/investment * 100 (nil si investment=0)
    break_even_period       # primer YYYY-MM con revenue acumulado ≥ outflow
  },
  monthly_series: [
    { period, investment, fixed_expense, revenue_manual, revenue_auto, revenue }
  ],
  breakdown_by_concept: [
    { concept_id, concept, entry_type, total }
  ]
}
```

### Revenue automático

Cuando `project.auto_revenue_source == 'mtto_work_orders'`, el calculador
suma `mtto_inventory_transfer_items.line_cost` de las salidas `completed`
de la BU cuyo `transfer_date` cae en el rango. Esto vincula el módulo de
Mantenimiento sin acoplamiento explícito (no se modifican modelos mtto).

### Break-even

Itera mes a mes acumulando outflow (inversión + gasto fijo) e inflow
(revenue manual + auto). El primer periodo donde inflow ≥ outflow se
devuelve como `break_even_period`. Si nunca cruza, `nil`.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET / POST | `/api/v1/finance/projects` | Lista / crea proyectos |
| GET / PUT / DELETE | `/api/v1/finance/projects/:id` | CRUD individual |
| GET / POST | `/api/v1/finance/concepts?project_id=X` | Lista / crea conceptos |
| GET / PUT / DELETE | `/api/v1/finance/concepts/:id` | CRUD individual |
| GET / POST | `/api/v1/finance/entries?project_id=X&period=YYYY-MM` | Lista / captura |
| GET / PUT / DELETE | `/api/v1/finance/entries/:id` | CRUD individual |
| GET | `/api/v1/finance/dashboard?project_id=X&from=YYYY-MM&to=YYYY-MM` | KPIs + serie |

## Privilegios

| key | module_group | route |
|---|---|---|
| `finance_projects` | Configuración | `/settings/finance/projects` |
| `finance_project_viability` | Finanzas TTPN | `/finanzas/viabilidad` |

Asignar a los administrativos que requieran visibilidad. Sin esos
privilegios el menú esconde las entradas (gating via `usePrivileges`).

## Decisiones de diseño

1. **No reutilizar Recepciones para gastos/inversión** — ensuciaría
   `average_cost` y rompería el modelo de inventario. Catálogo aparte.
2. **Multi-tenant por proyecto, no por business_unit** — un mismo TTPN
   puede tener N proyectos (taller, refacciones a terceros,
   capacitación). Cada uno mide aparte.
3. **Concept × period unique** — evita el bug clásico de "capturé luz dos
   veces este mes".
4. **`auto_revenue_source` opt-in en el proyecto** — explícito, no mágico.
   Solo el proyecto que lo declare ingiere OTs como revenue.
5. **`dependent: :restrict_with_error`** en project→concepts y
   concept→entries — no se borran cascada datos financieros.

## Próximos pasos sugeridos

- Job nocturno que crea entries pendientes para conceptos `monthly` el día
  1 de cada mes (opcional, MVP no lo necesita).
- Vincular OTs específicas a proyecto vía `mtto_work_orders.project_id`
  cuando aparezca un segundo proyecto que también consuma OTs.
- Exportar Dashboard a PDF / Excel para informes a inversionistas.
