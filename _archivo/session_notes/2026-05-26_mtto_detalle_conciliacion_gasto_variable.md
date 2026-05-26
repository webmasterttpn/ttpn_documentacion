# 2026-05-26 — Mantenimiento: detalle de OT, conciliación residuo/scrap, gasto variable

Épica de 3 fases para cerrar huecos del módulo de Mantenimiento (mtto).

## Fase 1 — Detalle de OT (solo lectura) ✅

**Problema**: la tabla de OT solo tenía el dropdown de transiciones; no había
forma de ver qué servicios/materiales/costos lleva una OT.

- **BE** `work_orders_controller.rb`: `serialize(detailed: true)` ahora incluye
  `vehicle` (clv), `materials` (líneas de salidas completadas con producto,
  cantidad, costo) y los totales `materials_cost`, `internal_market_value`,
  `estimated_savings`.
- **FE**: nuevo `WorkOrderDetailDialog.vue` (solo lectura: cabecera, servicios
  con ✔, materiales, tarjetas de costo). Acción "Ver detalle" en
  `WorkOrdersTable` y `WorkOrdersMobileList`; carga vía `find(id)` en la Page.
- **Fix**: `WorkOrderForm.vue` ya no duplica servicios al editar (diff con
  `id`/`_destroy`).
- **Decisión**: "solo lectura" — NO se habilita agregar/quitar servicios a una
  OT iniciada. Queja original "no puedo agregar otro servicio" queda como
  follow-up opcional (acción puntual "+ agregar servicio").
- Specs: request spec del detalle. RuboCop 0, ESLint 0, build OK.

## Fase 2 — Conciliación de residuo/scrap al cerrar la OT ✅

**Problema**: el residuo/scrap real solo se conoce **después** de usar el
material. En líquidos se usa costo hundido, pero **si el líquido se contaminó es
scrap/desperdicio, no residuo**.

- **Migración**: `quantity_scrapped` (decimal 14,4, default 0) en
  `mtto_inventory_transfer_items`.
- **`Mtto::InventoryTransferItem`**: validación `residuo + scrap <= consumido`;
  método `quantity_used = transferido − residuo − scrap`.
- **`Mtto::ReconcileMaterialsService`** (nuevo): residuo → `quantity_recovered`
  $0 + movimiento `residue_return` (incremento, idempotente); scrap → solo
  `quantity_scrapped` (NO cambia stock ni `average_cost` — costo ya hundido).
  Transacción + lock pesimista.
- **Endpoint**: `POST /work_orders/:id/complete` acepta opcional
  `reconciliation: [{ transfer_item_id, residue, scrap }]`; corre el service y
  luego la transición `complete`. Sin reconciliación → cierra con 0/0.
- **FE**: `WorkOrderCompleteDialog.vue` (residuo/scrap por línea, valida
  residuo+scrap ≤ consumido, muestra "usado"); `useWorkOrdersData.transition`
  intercepta `complete` → abre el diálogo (OT sin material consumido cierra
  directo). `maintenance.service.js` + `complete(id, { reconciliation })`.
- Specs: model (scrap + quantity_used), service (5 casos), request (complete con
  conciliación). 121 ejemplos mtto en verde. RuboCop 0, ESLint 0, build OK.
- Docs: `costeo_liquidos.md` (residuo vs. scrap), `model.md`,
  `services/ReconcileMaterialsService.md`, `controller/endpoints.md`.

## Fase 3 — Dashboard: panel "Gasto variable" (Python async) ⏳

Pendiente: script `scripts/mtto/workshop_variable_costs.py` (gasto por
categoría, costo externo vs interno/ahorro, ingreso vs utilizado externo,
ahorro/profit total) + `Mtto::VariableCostsJob` + endpoint
`GET /work_orders/variable_costs` (202) + FE `useWorkshopVariableCosts.js` +
`WorkshopCostsPanel.vue` en `DashboardTallerTab.vue`.

## Despliegue

Por fase: ttpngas → `github transform_to_api` (Railway auto-deploy + db:prepare);
ttpn-frontend → `origin` (GitLab→Netlify) + `github`; Documentacion → `origin`.
