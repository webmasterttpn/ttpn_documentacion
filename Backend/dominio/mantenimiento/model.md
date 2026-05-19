# Modelos — Dominio Mantenimiento (`Mtto::*`)

Namespace `Mtto` (`app/models/mtto.rb`, `table_name_prefix = 'mtto_'`).
Todos los modelos tenant incluyen `BusinessUnitAssignable` y, salvo los de
detalle/append-only, `Auditable`.

## Mtto::Category

Categoría jerárquica de productos. `belongs_to :parent_category` (opcional),
`has_many :subcategories`, `has_many :products`. Valida `name` (único por BU) y
`code` (único por BU, opcional). Scope `active`.

## Mtto::PackSize

Catálogo de presentaciones de compra, **modelo de dos niveles**:
`unit_size_base` (tamaño del envase en unidad base, ej. 4.9 L para un galón) +
`units_per_pack` (envases por paquete, ej. 6 para caja x6, 1 para suelto).
`base_quantity` = `unit_size_base × units_per_pack` y lo recalcula un
`before_validation` (no se envía desde el cliente; el controller permite solo
los dos campos fuente). Valida `name`, `unit_size_base > 0`, `units_per_pack ≥ 1`.

## Mtto::Product

Producto de taller. `sku` formal + **`clv`** (clave corta de referencia rápida en
taller, distinta del SKU; ambos únicos por BU). `unit_of_measure` = unidad base de
stock/consumo. `after_create` crea su `Mtto::Inventory` (reemplaza el trigger SQL
`create_inventory_record`). Métodos: `stock_status`
(OUT_OF_STOCK/REORDER/OVERSTOCK/OK) y scope `low_stock` (reemplazan la vista
`v_product_stock_status`).

## Mtto::Service

Catálogo de servicios de taller con `standard_time_minutes` (tiempo estándar
estilo agencia), usado por las OT para estimar tiempo total.

## Mtto::SupplierProduct

Relación `Supplier` ↔ `Mtto::Product` con `supplier_price`, `pack_size` (FK
catálogo), único `(supplier_id, product_id)`.

## Mtto::Inventory

Stock por producto (único). Dos cubetas: `quantity_on_hand` (a `average_cost`,
promedio móvil ponderado) y `quantity_recovered` (residuo reutilizable, $0).
`quantity_available` = columna generada (`on_hand + recovered − reserved`).
Método Ruby `available_quantity` (robusto ante stale de columna generada).

## Mtto::InventoryMovement

Libro auditable **append-only** (`before_update`/`before_destroy` →
`ActiveRecord::ReadOnlyRecord`). Tipos: `receipt`, `transfer`, `residue_return`,
`adjustment`, `damage`. `cost_layer` ∈ {`average`, `recovered`}. Scope `recent`
(últimos 30 días, reemplaza `v_recent_movements`).

## Mtto::ProductReceipt / ProductReceiptItem

Recepción de producto. Folio `REC-YYYY-NNN` (`NumberSequenceService`). Las líneas
se capturan en presentaciones; `ReceiveProductService` convierte a unidad base.

## Mtto::WorkOrder / WorkOrderService

Orden de Trabajo. `enum status` (draft/activated/in_progress/paused/completed/
cancelled). `belongs_to :mechanic, class_name: 'Employee'` (un mecánico por OT).
`estimated_total_minutes` = Σ de los servicios. `after_update_commit` →
broadcast `mtto_work_orders_#{bu}`. `WorkOrderService` copia el tiempo estándar
del catálogo al crearse y recalcula el estimado de la OT.

## Mtto::InventoryTransfer / InventoryTransferItem

Salida. `transfer_type` ∈ {`departmental`, `work_order`} (requiere
`work_order_id` si es `work_order`). Folio `OUT-YYYY-NNN`. Las líneas registran
`quantity_consumed_recovered`, `quantity_consumed_average`,
`quantity_residue_returned`, `unit_cost_charged`, `line_cost`.

## Modelos existentes modificados

- `Supplier`: `has_many :supplier_products`.
- `Employee`: `has_many :mtto_work_orders` (FK `mechanic_id`).
- Concern `BusinessUnitAssignable`: ahora expone `belongs_to :business_unit, optional: true`.
- `Ability`: roles `mantenimiento` y `capturista` gestionan `MTTO_MODELS`.
