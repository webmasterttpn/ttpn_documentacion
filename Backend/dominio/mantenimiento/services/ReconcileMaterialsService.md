# Services::Mtto::ReconcileMaterialsService

## Qué hace

Concilia el material consumido por una Orden de Trabajo **al cerrarla**. Por
cada línea de salida ya procesada registra cuánto del material consumido fue
**residuo recuperable** y cuánto **scrap** (sobrante no recuperable). Resuelve el
problema de que el residuo/scrap real solo se conoce **después** de usar el
material, no al momento de la salida.

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `work_order` | `Mtto::WorkOrder` | OT cuyo material se concilia |
| `lines` | `Array<Hash>` | `[{ transfer_item_id:, residue:, scrap:, scrap_reason: }, ...]` |
| `user:` | `User` | quién concilia (para el movimiento); default `Current.user` |

`scrap_reason` ∈ {`scrap`, `merma`}, obligatorio cuando `scrap > 0` (etiqueta de
reporte; mismo efecto de inventario/costo).

## Comportamiento

- **Residuo** (`residue`): suma el **incremento** respecto a lo ya devuelto a
  `inventory.quantity_recovered` (bucket $0, costo hundido) y crea un movimiento
  `residue_return` (`unit_cost = 0`, `cost_layer = recovered`). Idempotente: si
  la salida ya había registrado residuo, solo aplica la diferencia.
- **Scrap** (`scrap`): solo fija `quantity_scrapped` en la línea. **No** cambia
  stock ni `average_cost` — el material ya salió del almacén en la salida y se
  contaminó/perdió; su costo ya está hundido en la OT. Solo queda registrado
  para reportes (gasto variable, merma).
- Todo en una transacción con lock pesimista por inventario.
- La validación del modelo (`quantity_residue_returned + quantity_scrapped <=
  quantity_transferred`) corre al persistir cada línea.

## Errores

- `Mtto::ReconcileMaterialsService::InvalidLine` — `transfer_item_id` no
  pertenece a una salida **completada** de esta OT.
- `ActiveRecord::RecordInvalid` — residuo + scrap exceden lo consumido.

El controller rescata ambos → 422.

## Cuándo usarlo

Principalmente desde `POST /mtto/work_orders/:id/return_materials` (apartado
"Retorno de material" por OT) — **no** cambia el estado de la OT y puede correrse
varias veces. Sigue siendo invocable desde `#complete` (acepta `reconciliation`
por compatibilidad), pero el FE ya no captura el retorno en el cierre. Con `lines`
vacío no hace nada.

## Dependencias

- `Mtto::InventoryMovement` (libro append-only) — movimiento `residue_return`.
- `Mtto::InventoryTransferItem#quantity_used` = transferido − residuo − scrap.
- Ver `costeo_liquidos.md` (residuo vs. scrap, método de costo hundido).

Specs: `spec/services/mtto/reconcile_materials_service_spec.rb`.
