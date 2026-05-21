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

`sale_price` (decimal NOT NULL, default 0): precio unitario en unidad base al que
el producto se "vendería" / valuaría si saliera por una OT al cliente externo
equivalente. Alimenta `Mtto::WorkOrder#internal_market_value`. 0 = sin precio
capturado, no participa en cálculo de ahorro.

## Mtto::Service

Catálogo de servicios de taller con `standard_time_minutes` (tiempo estándar
estilo agencia), usado por las OT para estimar tiempo total.
`external_rate` (decimal NOT NULL, default 0): tarifa que cobraría un taller
externo por el servicio completo (mano de obra incluida). **Vive solo en el
catálogo** — no se replica por OT. La OT lo lee del catálogo cuando calcula
`internal_market_value`. 0 = sin cotización externa, no participa en ahorro.

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

`subtotal` y `total_amount` se recalculan automáticamente con un `after_commit
:recalc_totals` que suma la columna virtual `line_total` (`quantity_received *
unit_cost`) de las líneas. Representan el monto **facturado** por el proveedor
(lo recibido), no lo aceptado tras revisión — para conciliar lo aceptado se usa
`quantity_accepted` por línea. El callback no genera loop porque persiste con
`update_columns` (sin callbacks).

**Validaciones financieras (importante):**

- `pack_size_id` es obligatorio (NOT NULL en BD y `belongs_to` sin
  `optional: true`). Sin él el factor presentación→unidad base es indefinido
  y `ReceiveProductService` contaminaría el costo promedio del producto.
- `quantity_received` y `unit_cost` deben ser **estrictamente positivos**
  (`> 0`). Un costo unitario de 0 reduciría artificialmente el `average_cost`
  del producto.
- `quantity_accepted >= 0` y `quantity_accepted + quantity_rejected <=
  quantity_received`.
- `subtotal`, `total_amount` y `status` **no** se aceptan en `permit` del
  controller; los gestiona el modelo (totales) y el service (status).

## Mtto::WorkOrder / WorkOrderService

Orden de Trabajo. `enum status` (draft/activated/in_progress/paused/completed/
cancelled). `belongs_to :mechanic, class_name: 'Employee'` (un mecánico por OT).
`estimated_total_minutes` = Σ de los servicios. `after_update_commit` →
broadcast `mtto_work_orders_#{bu}`. `WorkOrderService` copia el tiempo estándar
del catálogo al crearse y recalcula el estimado de la OT.

`has_many :inventory_transfers` con `dependent: :restrict_with_error` — una
OT con salidas registradas no se puede destruir sin reversar antes el
material consumido (evita pérdida de trazabilidad contable).

`materials_cost` suma `line_cost` de las transfers `completed` ligadas a la
OT. Es el número que finanzas usa para conocer el costo real de la OT y se
expone en el serializer del controller.

`internal_market_value` = Σ (`quantity_transferred × product.sale_price`)
de los items en transfers `completed` + Σ (`service.external_rate`) leído
del catálogo `mtto_services` por cada `WorkOrderService` de la OT.
Representa lo que el trabajo costaría si se hiciera en un taller externo
("valor de mercado"). Tanto `sale_price` como `external_rate` tienen
default 0 NOT NULL (migración `20260521025531`) → un producto/servicio sin
precio capturado aporta 0 (ROI conservador, nunca NULL).

`estimated_savings` = `internal_market_value − materials_cost`. Es el
ahorro de hacer la OT en taller propio vs. externo. Puede ser **negativo**
si el costo real superó al precio externo (señal de tarifa mal capturada
o desperdicio). El proyecto financiero con
`auto_revenue_source: 'mtto_internal_savings'` suma este número como
revenue mensual del dashboard (agrupa por `completed_at`).

**Interno vs Externo (migración `20260522000001`):**

- `is_external` (boolean, NOT NULL, default false): marca si la OT es para
  flota propia TTPN (`false`) o para un cliente externo (`true`).
- `external_customer_name` (string): nombre del cliente externo. **Obligatorio
  cuando `is_external = true`** (validación de modelo).
- `external_vehicle_label` (string): placa/modelo del vehículo del cliente,
  texto libre (no FK a `vehicles`).
- Callback `before_validation :clear_internal_refs_when_external` limpia
  `vehicle_id` y `scheduled_maintenance_id` automáticamente cuando la OT se
  marca externa — evita contaminar el filtro "servicios a camionetas de TTPN"
  en la vista de viabilidad.
- Scopes: `internal` (`where(is_external: false)`) y
  `external` (`where(is_external: true)`).
- Semánticamente `estimated_savings` significa:
  - Internas: "ahorro vs. taller externo".
  - Externas: "profit por servir al cliente" (es la misma operación contable).

`WorkOrderProgressService#call(:cancel)` **bloquea** la cancelación si hay
transfers completadas — exige que el operador reverse el consumo antes de
poder cancelar. Sin este check, el inventario quedaba descontado contra una
OT cancelada.

## Mtto::InventoryTransfer / InventoryTransferItem

Salida. `transfer_type` ∈ {`departmental`, `work_order`} (requiere
`work_order_id` si es `work_order`). Folio `OUT-YYYY-NNN`. Las líneas registran
`quantity_consumed_recovered`, `quantity_consumed_average`,
`quantity_residue_returned`, `unit_cost_charged`, `line_cost`.

**Estados**: `enum :status` con valores
`draft|pending_approval|approved|completed|cancelled`. Una salida es
`cancelable?` solo desde los tres primeros — `completed` requiere reverso
manual explícito (no se permite `DELETE` desde el controller).

**`status` no se acepta en `permit`** del controller. Las transiciones a
`completed` van solo vía `POST /complete` (que ejecuta el service con
descuento real); a `cancelled` solo vía `DELETE` (que valida `cancelable?`).
Esto evita saltarse la descarga de inventario marcando `status` directo.

**`unit_cost_charged` vs `effective_unit_cost`**: `unit_cost_charged` =
`average_cost` del inventario al momento del consumo (referencia histórica
del precio promedio). Cuando una línea consume capas mezcladas
(recovered + average), `unit_cost_charged` no refleja el precio unitario
efectivo de la línea; para ese caso usar `effective_unit_cost = line_cost /
quantity_transferred` (método del modelo, también expuesto en el serializer).

**Validación residue ≤ consumido**: `quantity_residue_returned` no puede
exceder `quantity_approved` (o `quantity_requested` si no hay aprobado).
Sin este tope, el bucket `quantity_recovered` podía inflarse y crear
inventario gratis.

## Concurrencia y append-only

`ReceiveProductService` y `TransferProductService` ahora usan `lock!`
pesimista sobre la recepción/salida y sobre el `Inventory` antes de mutar
cantidades. Dos clicks simultáneos de "Procesar" se serializan; el segundo
lee `status='completed'` tras el lock y aborta con `AlreadyProcessed` —
evita duplicación de movimientos e inventario.

`mtto_inventory_movements` es **append-only** con dos defensas:

1. Callbacks Ruby `before_update`/`before_destroy` en el modelo (Rails-side).
2. Triggers PL/pgSQL `BEFORE UPDATE`/`BEFORE DELETE` en BD
   (`mtto_inventory_movements_append_only` — instalado por la migration
   `HardenMttoFinancialIntegrity`) — defensa también contra
   `update_columns` y `delete` que saltan callbacks.

Un índice único sobre `(source_type, source_id, product_id, cost_layer)`
(filtrado a `receipt`/`transfer`) sirve como cinturón de seguridad ante un
race que se le escape al lock: un segundo INSERT con la misma combinación
falla con `RecordNotUnique` y aborta la transacción.

## Modelos existentes modificados

- `Supplier`: `has_many :supplier_products`.
- `Employee`: `has_many :mtto_work_orders` (FK `mechanic_id`).
- Concern `BusinessUnitAssignable`: ahora expone `belongs_to :business_unit, optional: true`.
- `Ability`: roles `mantenimiento` y `capturista` gestionan `MTTO_MODELS`.
