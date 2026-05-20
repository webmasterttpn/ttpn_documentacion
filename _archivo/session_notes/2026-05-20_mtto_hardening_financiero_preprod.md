# 2026-05-20 — Endurecimiento financiero del módulo Mantenimiento (pre-prod)

## Contexto

Antes de subir el módulo de Mantenimiento a producción se hizo auditoría de
correctitud financiera enfocada en costos. Dos agentes paralelos revisaron
entrada (Recepciones) y salida (Transferencias + Órdenes de Trabajo);
verifiqué cada hallazgo y descarté un falso positivo (loop de
`recalc_totals`, que está protegido por el guard de igualdad).

Resultaron **5 P0** (bloqueantes prod) + **5 P1** (fix corto plazo) +
**4 P2** (mejora). El usuario pidió resolver todo. Se resolvieron los 14.

## Cambios por hallazgo

### P0 — Bloqueantes resueltos

| # | Fix | Archivo |
| --- | --- | --- |
| 1 | `lock!` pesimista en recepción + inventory por línea | `app/services/mtto/receive_product_service.rb` |
| 2 | `lock!` pesimista en salida + inventory en `consume` y `return_residue` | `app/services/mtto/transfer_product_service.rb` |
| 3 | `destroy` de salida `completed` devuelve 422; `cancelable?` en modelo | `app/controllers/api/v1/mtto/inventory_transfers_controller.rb`, `app/models/mtto/inventory_transfer.rb` |
| 4 | `block_cancel_with_consumption!` en service; `dependent: :restrict_with_error` | `app/services/mtto/work_order_progress_service.rb`, `app/models/mtto/work_order.rb` |
| 5 | `:status`, `:subtotal`, `:total_amount` fuera del whitelist de ambos controllers | `inventory_transfers_controller.rb`, `product_receipts_controller.rb` |

### P1 — Validaciones y exposición de costo

| # | Fix | Archivo |
| --- | --- | --- |
| 6 | `belongs_to :pack_size` sin `optional: true` + NOT NULL en BD | `app/models/mtto/product_receipt_item.rb` + migration |
| 7 | `numericality: { greater_than: 0 }` en `quantity_received` y `unit_cost` | `product_receipt_item.rb` |
| 8 | `residue_within_consumed` valida `quantity_residue_returned <= approved/requested` | `app/models/mtto/inventory_transfer_item.rb` |
| 9 | `WorkOrder#materials_cost` (suma `line_cost` de transfers `completed`) expuesto en serializer | `work_order.rb`, `work_orders_controller.rb` |
| 10 | `InventoryTransferItem#effective_unit_cost` (= `line_cost / quantity_transferred`) + doc de `unit_cost_charged` | `inventory_transfer_item.rb`, `inventory_transfers_controller.rb` |

### P2 — Defensa en profundidad

Migration `20260520202405_HardenMttoFinancialIntegrity`:

- `mtto_product_receipt_items.pack_size_id` → NOT NULL (con guard que reporta
  registros NULL antes de fallar).
- Índice único `(source_type, source_id, product_id, cost_layer)` filtrado a
  `receipt`/`transfer` en `mtto_inventory_movements`.
- Índice en `reference_number` para reverse-lookup desde folios.
- Triggers PL/pgSQL `BEFORE UPDATE`/`BEFORE DELETE` que abortan con
  `RAISE EXCEPTION` — append-only a nivel BD, salta callbacks Ruby.

Adicionales en código:
- `enum :status` en `Mtto::InventoryTransfer` (en lugar de array `STATUSES`).
- `Mtto::Inventory` se crea con `find_or_create_by!` en lugar de `create!`
  (evita `RecordNotUnique` bajo concurrencia).

## Falso positivo descartado

- "`after_commit :recalc_totals` loopea infinito" — verificado en console.
  La segunda llamada solo dispara 1 query SQL (el SUM) y no `update_columns`
  porque el guard de igualdad corta; además `update_columns` no dispara
  `after_commit`. Se documentó esto en `model.md`.

## Testing

- Specs nuevos:
  - `spec/models/mtto/product_receipt_item_spec.rb`
  - `spec/models/mtto/inventory_transfer_item_spec.rb`
  - `spec/requests/api/v1/mtto/inventory_transfers_spec.rb`
- Specs ampliados:
  - `spec/services/mtto/work_order_progress_service_spec.rb` (block cancel
    + allow cancel)
  - `spec/models/mtto/work_order_spec.rb` (`#materials_cost`)
  - `spec/models/mtto/inventory_movement_spec.rb` (compatibilidad con trigger
    append-only)
  - `spec/services/mtto/transfer_product_service_spec.rb` (assertion
    específica al transfer, no global)
- Resultado: **89 examples, 0 failures** en `spec/.../mtto/`.
  Suite completa 1573 examples / 107 failures — todos pre-existentes en
  dominios ajenos (gasoline, employees, vehicles, etc.).
- **RuboCop**: 0 offenses en archivos tocados.

## Veredicto

Listo para deploy. Recomendaciones operativas:

1. Aplicar la migración `20260520202405` en orden — el guard
   `backfill_pack_size_or_fail` detendrá la migración si hay registros con
   `pack_size_id NULL` en prod.
2. Comunicar al equipo de taller: cancelar una salida ya procesada o una OT
   con consumo ahora **bloquea** y exige reverso manual.
3. Frontend debe leer el nuevo campo `materials_cost` en el serializer de
   OT y `effective_unit_cost` en líneas de salida.

## Próximos pasos sugeridos

- `Mtto::ReverseTransferService` para reversar formalmente una salida
  procesada — hoy es ajuste manual.
- Drift de precisión en `unit_cost_base` (P2 del agente) — atender si
  finanzas detecta divergencia tras varias recepciones.
