# 2026-05-20 — Ahorro interno del Taller como revenue del dashboard

## Contexto

El proyecto **Taller Mecánico TTPN** se sembró (migration `20260520215508`)
con `auto_revenue_source: 'none'` porque sumar `materials_cost` de OTs como
revenue era doble conteo: ese material ya se pagó al recibirlo. La meta era
medir el ingreso real del Taller como **ahorro** contra lo que costaría
hacer ese trabajo en un taller externo, una vez que se capturaran:

- `mtto_products.sale_price` — valor unitario del producto si saliera al
  cliente externo equivalente.
- `mtto_services.external_rate` — tarifa de un taller externo por el
  servicio completo (incluye su mano de obra).

Migración `20260520231215` ya había agregado ambos campos como `NULL`-able.

## Cambios

### 1. Endurecimiento de precios — migration `20260521025531_set_default_zero_on_mtto_pricing`

`sale_price` y `external_rate` pasan a **default 0, NOT NULL** (backfill de
nulls a 0). Razón: el cálculo nunca recibe NULL; productos/servicios sin
precio capturado aportan 0 → ROI conservador y honesto, jamás roto. Se usa
`change_table :tabla, bulk: true` para una sola alteración por tabla.

### 2. `Mtto::WorkOrder#internal_market_value` + `#estimated_savings`

```ruby
# Σ (item.quantity_transferred × product.sale_price) en transfers completed
#  +
# Σ (service.external_rate) leído del catálogo mtto_services
def internal_market_value
  parts = inventory_transfers.completed
    .joins(inventory_transfer_items: :product)
    .sum('mtto_inventory_transfer_items.quantity_transferred * mtto_products.sale_price')
  labor = work_order_services.joins(:service).sum('mtto_services.external_rate')
  parts + labor
end

def estimated_savings
  internal_market_value - materials_cost
end
```

Decisiones:

- **`external_rate` no se replica por OT.** Vive solo en el catálogo
  `mtto_services` y se lee desde ahí. Esto fue confirmado por el usuario
  ("ese dato no se puede insertar en cada OT").
- **`quantity_transferred`** (no consumo neto) es la base de la multiplicación,
  por simetría con `materials_cost` (cuyo `line_cost` se basa en lo
  transferido) y por petición explícita del usuario.
- **`estimated_savings` puede ser negativo**: se conserva el signo como
  señal de alerta (tarifa mal capturada o desperdicio en la OT), no se
  fuerza a 0.

### 3. Nueva opción `auto_revenue_source: 'mtto_internal_savings'`

Añadida a `Finance::Project::AUTO_REVENUE_SOURCES`. El
`Finance::DashboardCalculator` ahora:

| `auto_revenue_source`       | Fuente                                                 | Filtro temporal |
|-----------------------------|--------------------------------------------------------|-----------------|
| `none`                      | 0                                                      | —               |
| `mtto_work_orders`          | Σ `line_cost` de transfers `completed`                 | `transfer_date` |
| `mtto_internal_savings`     | Σ `estimated_savings` de OTs `completed`               | `completed_at`  |

El cálculo de `mtto_internal_savings` itera OTs vía `find_each` y suma
`estimated_savings` (decisión KISS: ese método combina dos agregaciones
que no se prestan a un solo GROUP BY; volumen esperado del Taller lo
permite).

### 4. Proyecto Taller **NO se cambia en esta sesión**

Sigue en `auto_revenue_source: 'none'`. Se cambiará a
`'mtto_internal_savings'` **cuando los `sale_price` de productos reales
y los `external_rate` de servicios reales estén capturados**. Hasta
entonces todos los ahorros darían 0 y confundiría al usuario.

## Tests

- `spec/models/mtto/work_order_spec.rb`: 5 nuevos ejemplos para
  `internal_market_value` y `estimated_savings` (caso negativo incluido).
- `spec/services/finance/dashboard_calculator_spec.rb`: nuevo context para
  `mtto_internal_savings` (cálculo, fuera de rango, OT no completed).
- Suite `spec/models/mtto + spec/services/finance`: 56 ejemplos, 0 fallos.

## Gates

- RuboCop sobre los 6 archivos tocados: 0 offenses (ignorando bug interno
  pre-existente del cop `Capybara/RSpec/PredicateMatcher`).
- Migración aplicada en dev (`docker exec kumi_api rails db:migrate`).

## Próximo paso explícito

Cuando se capturen los precios reales:

```ruby
Finance::Project.find_by(slug: 'taller-mecanico-ttpn')
  .update!(auto_revenue_source: 'mtto_internal_savings')
```
