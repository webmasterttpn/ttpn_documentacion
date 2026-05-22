# 2026-05-22 — Fix desfase de zona horaria en Asignación de Vehículos

## Problema reportado

La hora de la asignación de vehículos se veía **correcta en la tabla (DB)** pero
**desfasada en el FE** (mismo síntoma que ya se había corregido en
`travel_counts.hora`). Ejemplo: una asignación guardada como `15:32` se mostraba
en pantalla con `~6 h` de diferencia.

## Causa raíz

`vehicle_asignations.fecha_efectiva` / `fecha_hasta` son columnas `datetime`. El
negocio las maneja como **hora de pared (wall-clock)**, pero el flujo las trataba
como instante UTC:

- **Lectura**: el controller emitía el `datetime` crudo → `as_json` lo
  serializaba como ISO con `Z` (`2026-05-22T15:32:08.000Z`). Quasar
  `date.formatDate` lo reconvertía a la zona del navegador (Chihuahua, −6) →
  desfase en pantalla.
- **Escritura**: `AsignationDialog.vue` hacía
  `new Date(form.fecha_efectiva).toISOString()`, convirtiendo la hora local
  elegida a UTC antes de enviarla.

`config.time_zone` está comentado → producción usa **UTC**, lo que expone el
problema (en local con `America/Chihuahua` quedaba enmascarado).

## Solución (wall-clock end-to-end)

1. **BE** `app/controllers/api/v1/vehicle_asignations_controller.rb`:
   nuevo helper privado `wall_clock(datetime)` =
   `datetime&.utc&.strftime('%Y-%m-%dT%H:%M:%S')`. Aplicado a `fecha_efectiva` y
   `fecha_hasta` en TODAS las respuestas (`index`, `show`, `create`, `update`,
   `finalize`, `vehicle_history`). Emite los dígitos crudos almacenados, sin "Z".
2. **FE** `src/pages/VehicleAsignations/components/AsignationDialog.vue#onSubmit`:
   se envía la hora elegida tal cual (string `YYYY-MM-DDTHH:mm`), sin
   `toISOString()`.
3. **FE lectura** (`VehicleAsignationsPage.vue`, `VehicleHistory.vue`): sin
   cambios — `date.formatDate` interpreta el string sin "Z" como hora local y lo
   muestra verbatim.

## Pruebas

`spec/requests/api/v1/vehicle_asignations_spec.rb` (2 regresiones nuevas):
- Serializa `fecha_efectiva`/`fecha_hasta` como wall-clock, sin "Z" ni offset.
- Round-trip de POST (con `Time.use_zone('UTC')` para reproducir prod): la hora
  enviada se guarda y regresa con los mismos dígitos.

Resultado: `14 examples, 0 failures`. RuboCop sin offenses nuevos (los
pre-existentes del controller/spec no se tocaron). ESLint del FE limpio.

## Nota de comportamiento

Datos previos creados por el flujo web viejo quedaron guardados como instante UTC
(p. ej. `15:32`); ahora se muestran verbatim (`15:32`), que es el valor que el
usuario considera correcto ("correcta en tabla"). Las asignaciones nuevas guardan
y muestran exactamente la hora de pared elegida. El uso de `fecha_*` en
comparaciones del modelo (`active?`, scopes, `finalize_previous_asignations`)
opera a granularidad de día, por lo que el cambio no afecta la determinación de
asignación activa.

## Documentación

- `Documentacion/Backend/dominio/vehicles/asignaciones.md` — sección "Zona
  horaria — `fecha_efectiva` / `fecha_hasta` son wall-clock".
