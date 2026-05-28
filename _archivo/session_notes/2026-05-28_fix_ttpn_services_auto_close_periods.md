# 2026-05-28 — Cierre automático de períodos en Precios e Incrementos de Servicios TTPN

Continuación de
`2026-05-28_fix_ttpn_services_nested_edit.md`. Tras corregir el bug de display
de "Tipo vehículo" y el refetch al editar, el usuario reportó que **varios
incrementos del mismo `vehicle_type` quedaban abiertos al mismo tiempo**
(captura: para "Auto" había dos registros sin `fecha_hasta`). Pidió:

1. Que al **agregar** un precio/costo nuevo, el período anterior activo se
   cierre automáticamente con `fecha_hasta` = día anterior a hoy (placeholder
   visual mientras edita).
2. Que al **cambiar** `fecha_efectiva` del nuevo, el `fecha_hasta` del anterior
   se recompute a `nueva_fecha - 1 día`.
3. Que al **borrar** el nuevo antes de guardar (papelera), se restaure el
   `fecha_hasta` del anterior a como estaba.
4. Para Costo x Chofer, el cierre debe respetar el `vehicle_type_id` (cerrar
   un "Auto" no debe afectar a un "Van" o "Camioneta" del mismo servicio).
5. Los registros históricos huérfanos (NULL `fecha_hasta` heredados de la
   migración) NO se normalizan masivamente esta semana — quedan tal cual; el
   flujo nuevo evita que se generen más casos.

## Diagnóstico inicial

- **Display bug**: `TtpnServicesPage.vue:323` usaba `d.vehicle_type?.nombre`
  pero el serializer expone `vehicle_type_nombre` (string plano) tras el
  refactor de la iteración previa. Por eso la tabla "Costo por Chofer" en
  vista detalle siempre mostraba `—` en Tipo vehículo.
- **Sin cierre automático**: ni el FE ni los modelos del BE hacían nada al
  insertar/actualizar un Price/Increase, así que el período anterior quedaba
  perpetuamente abierto.

## Fix

### BE — `app/models/ttpn_service_price.rb` y `ttpn_service_driver_increase.rb`
Callback `before_save :close_previous_open_period` en ambos modelos. Para cada
registro que entra (create o update):

1. Solo actúa si `fecha_efectiva` está presente.
2. Busca el período anterior abierto (`fecha_hasta IS NULL`,
   `fecha_efectiva < self.fecha_efectiva`, excluyendo el propio id) del mismo
   scope:
   - `TtpnServicePrice`: scope = `ttpn_service_id`.
   - `TtpnServiceDriverIncrease`: scope = `(ttpn_service_id, vehicle_type_id)`.
3. Si encuentra, le pone `fecha_hasta = self.fecha_efectiva - 1.day` vía
   `update_columns` (saltea callbacks → no recursión, no toca `updated_at`).
4. Idempotente: si no hay anterior abierto, no hace nada.

Esto es la red de seguridad: aplica en cualquier alta — endpoint REST,
`accepts_nested_attributes_for`, rails_admin, importer, rake.

### FE — `src/pages/Services/TtpnServicesPage.vue`
La UX dinámica que pidió el usuario (placeholder visual mientras edita):

- `addPrice` y `addIncrease` agregan un item con marker transitorio
  `_isNew: true`.
- `addPrice` cierra inmediatamente al activo del servicio con `fecha_hasta =
  ayer`. Para `addIncrease` el cierre se difiere hasta que el usuario
  selecciona `vehicle_type_id` (sin scope no se puede saber qué cerrar).
- Watchers profundos sobre `fecha_efectiva` y `vehicle_type_id` del nuevo
  recomputan el `fecha_hasta` del anterior cerrado:
  - Cambio de `fecha_efectiva` → `fecha_hasta` = `nueva - 1 día`.
  - Cambio de `vehicle_type_id` en increases → restaura el anterior cerrado
    (si había) y cierra el nuevo scope.
- `removePrice` / `removeIncrease` invocan `restorePrev(item)` que pone al
  anterior su `_originalEnding` (típicamente `null`) antes de eliminar el
  nuevo del array — deshace el cierre visual.
- Antes de mandar al BE, `stripTransient` quita `_isNew`, `_closedPrev` y
  `_originalEnding` para que el payload solo lleve campos válidos del modelo.

### Display
Una sola línea en el `q-markup-table` del show dialog:
`{{ d.vehicle_type_nombre || '—' }}` (antes era `d.vehicle_type?.nombre`).

## Específicamente NO hecho

- **Normalización masiva de datos viejos**: el usuario indicó que no hace
  falta — los registros sin `fecha_hasta` del histórico no van a recibir más
  altas esta semana, y el flujo nuevo previene crear más. Si en el futuro se
  necesita, queda como deuda técnica un rake `ttpn_services:normalize_periods`
  que recorra cada servicio + cada vehicle_type, ordene por `fecha_efectiva`
  y cierre cada anterior abierto al `next.fecha_efectiva - 1 día`.

## Verificación

- **BE specs**: 34/34 verde (`spec/models/ttpn_service_price_spec.rb` 6 ej.,
  `ttpn_service_driver_increase_spec.rb` 7 ej.,
  `requests/api/v1/ttpn_services_spec.rb` 16 ej., `ttpn_service_spec.rb` 5
  ej.). Tests cubren: cierre dentro del scope correcto, NO cruce de scopes
  (otro servicio o vehicle_type), respeta `fecha_hasta` ya seteado, no se
  cierra a sí mismo, idempotente, inserción retroactiva no rompe el más
  reciente.
- **RuboCop**: 0 ofensas en archivos modificados.
- **ESLint**: 0 errores/warnings en `TtpnServicesPage.vue`.

## Archivos tocados

- `ttpngas/app/models/ttpn_service_price.rb`
- `ttpngas/app/models/ttpn_service_driver_increase.rb`
- `ttpngas/spec/models/ttpn_service_price_spec.rb` (nuevo)
- `ttpngas/spec/models/ttpn_service_driver_increase_spec.rb` (nuevo)
- `ttpn-frontend/src/pages/Services/TtpnServicesPage.vue`
