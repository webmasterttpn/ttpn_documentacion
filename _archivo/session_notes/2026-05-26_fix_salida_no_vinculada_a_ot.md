# 2026-05-26 — Fix: salida desde el detalle de la OT no quedaba vinculada

## Síntoma

El usuario creó OTs en la semana 22 y "les puso productos", pero el material no
aparecía en el resumen semanal ni sumaba ahorro/costo. Diagnóstico en BD dev: las
OTs #183–#187 (cerradas 25–26 may) tenían **0 salidas vinculadas**, y en el
sistema **no se persistió ninguna salida después del 2026-05-21** (total: 6
salidas, todas del 21 may). La salida nunca llegó a guardarse/vincularse.

## Causa raíz (FE)

`TransferForm.vue` leía `props.workOrderId` solo en el inicializador de `form`
(en setup). Al abrirse desde el detalle de la OT (`+ Salida`), si el `q-dialog`
conservaba el contenido montado desde antes (cuando `workOrderId` era null), el
form quedaba como `transfer_type: 'departmental'` con `work_order_id: null`,
aunque el banner mostrara "vinculada a esta OT" (`lockedToWorkOrder` sí es
reactivo). Al guardar, el payload iba sin OT → salida sin vincular o rechazada.
El resto de diálogos del código (p.ej. WorkOrderForm) ya usan `watch` con
`immediate` para re-inicializar; este no lo tenía.

## Fix (FE, `ttpn-frontend`)

- `WorkOrdersPage.vue`: `:key="transferFormKey"` en `<TransferForm>`, incrementado
  en cada `onAddTransfer`, fuerza un montaje **fresco** del form con el
  `workOrderId` actual y sin productos previos.
- `TransferForm.vue`: `save()` usa la OT bloqueada como **fuente de verdad**
  (`isWorkOrderTransfer` / `resolvedWorkOrderId`): una salida abierta desde el
  detalle SIEMPRE se envía como `work_order` + `work_order_id` de esa OT, sin
  importar el estado reactivo. Valida que haya OT antes de enviar.

## Notas de flujo (recordatorio al usuario)

- "Ponerle productos" a la OT en su formulario = **servicios** (mano de obra). El
  **material** entra SOLO por una **Salida** (work_order), y debe **Procesarse**
  para descontar stock y costear.
- No se bloquea cerrar una OT sin material (hay OTs solo de mano de obra); se
  **advierte** en el diálogo de cierre. Las OTs ya cerradas sin salida requieren
  reabrir (transición no implementada aún).

Verificado: ESLint 0, build limpio. Desplegado a GitLab (Netlify) + GitHub.
