# 2026-05-26 — Mtto: rango de fechas en dashboard + flujo de salidas en la OT

Reportes del usuario sobre el dashboard de Mantenimiento y el flujo OT ↔ salidas.

## Aclaraciones de flujo (no eran bugs)

- **Activar una OT no requiere productos** — es solo cambio de estado.
- **Las salidas SÍ pueden vincularse a OTs activas/en progreso/pausadas**; solo se
  ocultan las completadas/canceladas.
- **Crear una salida ≠ procesarla**: queda en borrador; el material se descuenta y
  costea (`line_cost`) solo al darle **Procesar**. El resumen semanal / dashboard
  solo suman salidas **procesadas (completed)** de OTs completadas, en la semana
  del cierre (`completed_at`). Por eso el material "no apareció": la salida no se
  había procesado, o la OT se cerró sin la salida procesada.
- **Más material**: crear otra salida para la misma OT mientras esté activa y
  procesarla. Una OT puede tener varias salidas.

## Fixes / mejoras implementadas

### Dashboard — selector de período en el tab Mantenimiento (FE)
El panel de fechas solo existía en el tab Ingresos; el tab Mantenimiento recibía
`period` sin control para cambiarlo. `DashboardTallerTab.vue` ahora tiene su
propio Desde/Hasta + atajos (semana/mes/3 meses/año) que emiten `update:range` a
`DashboardPage.vue`. (El rango por defecto ya incluía la semana en curso.)

### Avisar al cerrar una OT sin material (FE)
`useWorkOrdersData.startComplete` ahora siempre abre `WorkOrderCompleteDialog`.
Si la OT no tiene material procesado, muestra un banner de advertencia (por si se
olvidó registrar/procesar la salida) pero permite cerrar igualmente.

### Quitar "Residuo" del form de salida para OT (FE)
`TransferForm.vue`: el campo "Residuo" se oculta cuando `transfer_type ==
'work_order'` (el residuo/scrap se concilia al cerrar la OT — Fase 2) y se manda
`quantity_residue_returned: 0`. Se mantiene para salidas **departamentales** (que
no tienen cierre de OT). Banner explicativo en modo OT.

### Ver/agregar/procesar salidas desde el detalle de la OT (BE + FE)
- **BE**: el detalle de OT (`GET /work_orders/:id`) ahora incluye `transfers`
  (todas las salidas vinculadas, cualquier estado): `{ id, transfer_number,
  status, items_count, total_cost }`.
- **FE**: `WorkOrderDetailDialog` lista las salidas con estado; si la OT está
  activa y hay permiso, botón **"+ Salida"** (abre `TransferForm` con la OT
  bloqueada) y **"Procesar"** por salida en borrador. `TransferForm` acepta
  `workOrderId` para fijar la OT. `WorkOrdersPage` orquesta crear/procesar y
  refresca el detalle.

## Verificación

RuboCop 0 (disable puntual de `Metrics/ClassLength` en el controller, que ya
hospeda varios endpoints de dashboard). RSpec mtto work_orders + reconcile: 22
ejemplos, 0 fallos. ESLint 0, build limpio. Desplegado: ttpngas → github
transform_to_api (Railway); FE → GitLab (Netlify) + GitHub.
