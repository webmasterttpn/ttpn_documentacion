# Método de costo hundido para control de líquidos (inventario y contabilidad)

> Referenciado también desde `Backend/dominio/finanzas/`. **Avisar al contador**:
> la valuación física en libros es deliberadamente conservadora (subvalúa el
> residuo recuperado a $0) para evitar la contabilidad de costos de retorno.

## Problema

Los líquidos (aceite, refrigerante, solvente) se compran en presentaciones
grandes (tambor 200 L) y se consumen en cantidades pequeñas y **fraccionarias**.
Tras usar parte en una OT queda un **residuo reutilizable**. Reingresarlo "a
costo" obliga a revaluar, **ensucia el costo promedio** y complica la
contabilidad con **costos de retorno** (reversa parcial de gasto). Decisión:
**método de costo hundido**.

## Principio

El costo del líquido se reconoce **completo en su primera salida**. El residuo
que vuelve a quedar disponible entra con **valor en libros $0** (costo ya
hundido). Nunca se revalúa ni se recalcula el promedio por un retorno.

## Lado INVENTARIO (`mtto_inventories`)

- Dos cubetas por producto:
  - `quantity_on_hand` → valuada a `average_cost` (promedio móvil ponderado).
  - `quantity_recovered` → residuo reutilizable, **valor $0**.
- **Recepción** (`Mtto::ReceiveProductService`): convierte presentación→unidad
  base (`pack_size.base_quantity`), suma a `quantity_on_hand` y recalcula
  `average_cost = (on_hand·avg + qty_in·unit_cost_base) / (on_hand + qty_in)`.
- **Consumo** (`Mtto::TransferProductService`): descuenta **primero
  `quantity_recovered` ($0)**, el remanente de `quantity_on_hand` a
  `average_cost`. Registra `quantity_consumed_recovered` y
  `quantity_consumed_average` en la línea.
- **Devolución de residuo** al cerrar OT/salida: `quantity_recovered +=
  quantity_residue_returned`, movimiento `residue_return` con `unit_cost = 0`,
  `cost_layer = 'recovered'`. **No** toca `average_cost`. **No** hay costo de
  retorno.

## Lado CONTABILIDAD / COSTOS

- `line_cost = quantity_consumed_average · average_cost +
  quantity_consumed_recovered · 0`.
- El gasto del líquido se reconoce íntegro en la **primera OT** que lo consumió
  (incluida la fracción que luego volvió como residuo): ese costo queda
  **hundido** en esa OT.
- Reutilizar residuo aparece como **ahorro / variación favorable de costo**
  (línea a $0), nunca como costo negativo ni revaluación de inventario.
- Conciliación: como `residue_return` y el consumo del bucket recuperado van a
  costo 0, el **costo total reconocido a lo largo de la vida del líquido = costo
  de compra** (sin sobre/subvaluación). `mtto_inventory_movements` es el libro
  auditable.

## Ejemplo numérico (validado por specs)

1. Compra 1 tambor = 200 L @ $20/L → `on_hand`=200, `average_cost`=$20.
2. Segunda recepción 200 L @ $25 → `on_hand`=400, `average_cost`=**$22.5**
   ((200·20 + 200·25)/400).
3. OT-1 consume 5 L (recovered=0): `line_cost`=$112.5; `on_hand`=395;
   `average_cost`=$22.5 (sin cambio).
4. OT-1 cierra con 1.5 L reutilizables → `residue_return`:
   `quantity_recovered`=1.5 @ $0; `average_cost`=$22.5 (sin cambio).
5. OT-2 consume 1 L → toma del recuperado primero: `line_cost`=$0;
   `recovered`=0.5; `on_hand`=395. El promedio nunca se ensució; sin costo de
   retorno.

Specs: `spec/services/mtto/transfer_product_service_spec.rb`,
`spec/services/mtto/receive_product_service_spec.rb`.
