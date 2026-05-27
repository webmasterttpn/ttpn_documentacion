# 2026-05-26 — Apartado "Retorno de material" por OT (residuo / scrap / merma)

## Contexto

El retorno de residuo/scrap estaba escondido en el cierre de la OT y confundía.
Además surgió un 500 (`undefined method quantity_scrapped`) por **caché de
esquema viejo** en el Puma de `kumi_api` tras la migración por `docker exec`; se
resolvió reiniciando el contenedor (en prod no aplica: `db:prepare` reinicia).

Decisión del usuario: un **apartado dedicado de Retorno de material, por OT**,
que clasifique cada cantidad como **reutilizable** o **no recuperable + motivo
(scrap/merma)**, y que **reemplace** la captura en el cierre.

## Cambios

### BE (`ttpngas`)
- Migración: `scrap_reason` (string) en `mtto_inventory_transfer_items`.
- `Mtto::InventoryTransferItem`: valida `scrap_reason ∈ {scrap, merma}` y lo exige
  cuando `quantity_scrapped > 0`. (`SCRAP_REASONS`.)
- `Mtto::ReconcileMaterialsService`: acepta `scrap_reason` por línea (lo fija si
  `scrap > 0`, nil si no). Misma lógica de residuo (delta a recuperado $0) y scrap
  (solo registro).
- Endpoint nuevo `POST /work_orders/:id/return_materials`: corre el servicio **sin
  cambiar el estado** de la OT (apartado de retorno). `complete` ya **no** captura
  retorno (acepta `reconciliation` por compat; el FE manda `{}`).
- Detalle de OT: `materials` incluye `quantity_residue_returned`,
  `quantity_scrapped`, `scrap_reason`.
- Specs: modelo (motivo requerido / inválido), servicio (scrap_reason / merma),
  request (return_materials ok + 422 sin motivo). **129 ejemplos mtto, 0 fallos.**

### FE (`ttpn-frontend`)
- `WorkOrderReturnDialog.vue`: por material consumido, inputs reutilizable +
  no recuperable + select motivo (scrap/merma, requerido si no recup. > 0); valida
  reutilizable + no recup. ≤ consumido; muestra "usado".
- `WorkOrderDetailDialog`: botón **"Retorno de material"** + columna que muestra el
  retorno aplicado (reutil. / no recup. + motivo).
- `WorkOrdersPage`: diálogo de retorno → `returnMaterials(id, { reconciliation })`
  → refresca detalle. `maintenance.service` + `returnMaterials`.
- `WorkOrderCompleteDialog`: simplificado — sin inputs de residuo/scrap; resumen de
  material (solo lectura) + aviso si no hay material procesado + confirmar.
  `useWorkOrdersData`: el cierre ya no manda reconciliación.

## Notas

- El retorno puede aplicarse mientras la OT tenga material procesado (incluye OTs
  ya completadas → también sirve para corregir las que se cerraron sin registrar).
- scrap y merma tienen el mismo efecto (registro, no tocan stock ni costo); el
  motivo distingue la causa para reporte.

Verificado: RuboCop 0, ESLint 0, build limpio. Desplegado: ttpngas → github
transform_to_api (Railway corre la migración con `db:prepare`); FE → GitLab
(Netlify) + GitHub.
