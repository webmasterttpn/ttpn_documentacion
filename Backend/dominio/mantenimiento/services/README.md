# Services — Dominio Mantenimiento

`app/services/mtto/`. Reemplazan los triggers PL/pgSQL del SQL original con
lógica Rails en transacción (KISS/DRY del monorepo).

## Mtto::NumberSequenceService
`.next(prefix:, business_unit_id:, model:)` → folio `PREFIX-YYYY-NNN` por BU y
año (REC/OUT/OT). Sin gem extra. Lo invocan los modelos en `before_validation`.

## Mtto::ReceiveProductService
`new(receipt, user:).call`. En transacción, por cada línea aceptada: convierte
presentación→unidad base (`pack_size.base_quantity`), normaliza `unit_cost` por
unidad base, crea `InventoryMovement` (`receipt`), incrementa `quantity_on_hand`
y **recalcula `average_cost`** (promedio móvil ponderado). Marca la recepción
`completed`. `AlreadyProcessed` si ya estaba procesada. Reemplaza
`update_inventory_on_receipt`.

## Mtto::TransferProductService
`new(transfer, user:).call`. En transacción, por cada línea: valida stock
suficiente; descuenta **primero `quantity_recovered` ($0)** y el remanente de
`quantity_on_hand` a `average_cost`; registra `line_cost` y movimientos
(`transfer`, capas recovered/average). Devuelve residuo reutilizable
(`residue_return`, costo 0, sin tocar `average_cost`). Marca `completed`.
`InsufficientStock` / `AlreadyProcessed`. Reemplaza
`update_inventory_on_transfer`. Ver `../costeo_liquidos.md`.

## Mtto::WorkOrderProgressService
`new(work_order, user:).call(event)` con `event` ∈ {activate, start, pause,
resume, complete, cancel}. Valida la transición (mapa `TRANSITIONS`), sella
timestamps, recalcula estimado/`actual_minutes`. El broadcast al tablero lo hace
`Mtto::WorkOrder#after_update_commit`. `InvalidTransition` si el evento no aplica
al estado actual. Toda la lógica de negocio de la OT vive aquí (no en el
controller).

## Canal ActionCable
`app/channels/mtto_work_orders_channel.rb` — `stream_from
"mtto_work_orders_#{bu_id}"` (patrón JWT de `JobStatusChannel`).

Specs: `spec/services/mtto/*_spec.rb` (incluye costo hundido, stock insuficiente,
transiciones inválidas).
