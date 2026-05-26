# Workshop Variable Costs (Python) — `scripts/mtto/workshop_variable_costs.py`

## Qué hace

Calcula el **gasto variable del taller** para el panel "Gasto variable" del
Dashboard de Mantenimiento (tab Taller). Cuatro secciones:

- `spend_by_category` — gasto por categoría de producto de las salidas
  **completadas** en el período (`transfer_date` en rango). Por categoría:
  `amount` (Σ `line_cost`), `quantity` (Σ `quantity_transferred`), `scrap_qty`
  (Σ `quantity_scrapped`) y `scrap_cost` (porción desperdiciada al costo unitario
  efectivo). Incluye salidas departamentales y de OT.
- `internal_vs_external` — OT **internas** completadas en rango: `material_cost`
  (costo a costo promedio = Σ `line_cost`) vs `external_value`
  (`parts_market_value` = Σ `qty × sale_price` + `labor_external_value` =
  Σ `service.external_rate`); `savings` = externo − interno.
- `external_jobs` — OT **externas** completadas: `revenue` (`parts_revenue` =
  Σ `qty × sale_price` + `labor_revenue` = Σ `external_rate`) vs `cost`
  (Σ `line_cost`); `profit` = ingreso − costo.
- `totals` — `material_spend`, `scrap_cost`, `internal_savings`,
  `external_profit`, `total_benefit` (= ahorro interno + profit externo),
  `internal_ot_count`, `external_ot_count`.

## Fórmulas (fuente de verdad)

| Métrica | Fórmula |
|---|---|
| Gasto categoría | `SUM(line_cost)` GROUP BY categoría, transfers `completed` en rango |
| Merma (scrap) | `SUM(quantity_scrapped × line_cost / quantity_transferred)` |
| Ahorro interno (OT internas) | `Σ(qty×sale_price) + Σ(external_rate) − Σ(line_cost)` |
| Profit externo (OT externas) | `Σ(qty×sale_price) + Σ(external_rate) − Σ(line_cost)` |
| Beneficio total | `internal_savings + external_profit` |

`sale_price` y `external_rate` tienen default 0 NOT NULL → un producto/servicio
sin precio aporta 0 (conservador, nunca NULL). Coincide con los métodos del
modelo `Mtto::WorkOrder` (`materials_cost`, `internal_market_value`,
`estimated_savings`), pero agregados en el período vía SQL.

## Errores comunes a evitar

- **No** confundir `unit_cost_charged` con el costo de línea: el costo es
  `line_cost`. La merma usa el costo unitario efectivo `line_cost /
  quantity_transferred`, no `unit_cost_charged`.
- `spend_by_category` se ancla en `transfer_date` (consumo); las secciones
  interno/externo se anclan en `wo.completed_at` (OT cerrada). Es deliberado:
  el gasto es por consumo, el ahorro/profit por OT terminada.

## Patrón de invocación (Python async)

```ruby
# GET /api/v1/mtto/work_orders/variable_costs — responde 202 Accepted
job_id = Mtto::VariableCostsJob.perform_async(
  current_user.id, current_business_unit_id, from_date, to_date
)
render json: { job_id: job_id, status: 'queued' }, status: :accepted
```

`Mtto::VariableCostsJob` corre el script vía `EjecutarScriptPythonJob` (Open3) y
hace broadcast a `job_status_#{user_id}` con `kind: 'mtto_variable_costs'`. El FE
(`src/composables/Finance/useWorkshopVariableCosts.js` →
`WorkshopCostsPanel.vue`) filtra por `job_id`. Polling prohibido.

## Parámetros (CLI)

| Flag | Tipo | Default |
|---|---|---|
| `--from` | YYYY-MM-DD | hoy − 6 meses |
| `--to` | YYYY-MM-DD | hoy |
| `--business-unit-id` | int | requerido |

## Tests

`scripts/mtto/test_workshop_variable_costs.py` — 7 tests con `pytest`,
`PostgresClient` mockeado. Sin BD real.

```bash
docker exec -e PYTHONPATH=scripts kumi_api python3 -m pytest scripts/mtto/test_workshop_variable_costs.py
```

## Dependencias

- `utils/db.py`, `utils/decorators.py`, `utils/logger.py`.
- Tablas: `mtto_inventory_transfer_items`, `mtto_inventory_transfers`,
  `mtto_products`, `mtto_categories`, `mtto_work_orders`,
  `mtto_work_order_services`, `mtto_services`.
- Espejo de `workshop_ops_kpis.py` (mismo job/canal, distinto `kind`).
