# 2026-05-20 — Fix: Recepciones mostraban Total = 0

## Contexto

El usuario reportó que la columna **Total** del listado de Recepciones
siempre quedaba en 0, aun después de crear una recepción con líneas
(ejemplo: Aceite en caja de 12). Además se mencionó que el screenshot
del manual (`img/recepciones.png`) se ve con texto de iconos sobrepuesto.

## Diagnóstico

- `mtto_product_receipts.total_amount` se crea con `default: 0` en la
  migración `20260519000004_create_mtto_receipts`, pero **nadie la
  calculaba**:
  - El form FE no la envía (`ReceiptForm.vue`).
  - El controller la acepta en `permit` pero no la asigna
    (`product_receipts_controller.rb`).
  - `ReceiveProductService` recalcula inventario y costo promedio, pero
    no toca subtotal/total_amount.
- Los items ya tienen una columna **virtual stored** `line_total =
  quantity_received * unit_cost`, así que el dato existe — solo faltaba
  agregarlo al header.
- El screenshot con texto sobrepuesto (`keyboard_arrow_down`, `inventory`,
  `filter_list`, etc.) es un problema de la captura: se tomó antes de
  que cargara la fuente Material Icons. No es un bug de la app.

## Decisión

- **Definición de Total** = monto facturado por el proveedor (Σ
  quantity_received × unit_cost). Es lo que aparece en la factura, no lo
  aceptado tras revisión.
- **Cálculo** vía `after_commit :recalc_totals` en el modelo
  `Mtto::ProductReceipt`. Persiste con `update_columns` (sin callbacks)
  para evitar loops.

## Cambios

- `ttpngas/app/models/mtto/product_receipt.rb` → `after_commit
  :recalc_totals` + método público `recalc_totals` que suma
  `product_receipt_items.sum(:line_total)` y actualiza `subtotal` +
  `total_amount` solo si difieren.
- `ttpngas/spec/models/mtto/product_receipt_spec.rb` → spec nuevo con
  cobertura de asociaciones y del callback (5 examples, 0 failures).
- `Documentacion/Backend/dominio/mantenimiento/model.md` → sección
  ProductReceipt explica la regla de cálculo y por qué no genera loop.
- `Documentacion/Manuales/mantenimiento/manual_usuario.md` → nota en
  sección 6 que aclara qué representa la columna Total.

## Backfill

Las 3 recepciones demo se recalcularon con
`Mtto::ProductReceipt.find_each(&:recalc_totals)`:

| Folio        | Total |
| ------------ | ----- |
| REC-2026-001 | 7,200 |
| REC-2026-002 | 4,000 |
| REC-2026-003 | 2,900 |

## Pendientes

- Retomar el screenshot `img/recepciones.png` esperando 1–2 s a que
  cargue la fuente Material Icons (no es un fix de código, es captura).
