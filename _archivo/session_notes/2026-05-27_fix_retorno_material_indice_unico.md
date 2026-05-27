# 2026-05-27 — Fix: el retorno de material fallaba (500) por índice único

## Síntoma

Aplicar "Retorno de material" en una OT daba 500 / "No se pudo aplicar el retorno
de material":

```
PG::UniqueViolation: idx_mtto_movements_unique_source_layer
Key (source_type, source_id, product_id, cost_layer)=(transfer, 139, 128, recovered) already exists
```

## Causa

El índice único parcial `idx_mtto_movements_unique_source_layer` (de
`harden_mtto_financial_integrity`) defendía contra el doble procesamiento de
recepciones/salidas, pero su condición estaba sobre
`source_type IN ('receipt','transfer')`. El movimiento `residue_return` (retorno
de residuo) **también** tiene `source_type='transfer'` y `cost_layer='recovered'`,
así que chocaba con el movimiento de **consumo** de la misma salida+producto+capa
(creado al procesar la salida cuando se consumió de la cubeta recuperada). El
índice no distinguía por `movement_type`.

## Fix (BE)

Migración `RelaxMttoMovementsUniqueIndexForResidue`: reescribe la condición del
índice a `movement_type IN ('receipt','transfer')` (solo los movimientos de
**procesamiento**), excluyendo `residue_return`/`adjustment`/`damage`. Así:

- Se mantiene la defensa anti-doble-procesamiento para recepciones/consumos.
- El retorno de residuo (capa recuperada) ya no choca con el consumo.
- Permite re-ajustar el retorno (varios `residue_return` para la misma línea).

Spec de regresión en `reconcile_materials_service_spec`: con un movimiento de
consumo previo en capa recuperada para el mismo transfer+producto, el retorno de
residuo ahora se aplica sin chocar. Suite mtto en verde (91 ej., 0 fallos).

La migración corre en prod vía `db:prepare` al desplegar (Railway). En dev se
aplicó a dev+test y se reinició `kumi_api`.
