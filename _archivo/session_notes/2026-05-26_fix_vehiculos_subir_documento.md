# 2026-05-26 — Fix: subir documento de vehículo desde el formulario

## Síntoma

Al crear un vehículo nuevo o editar uno y **agregar un documento**, no había forma
de adjuntar el archivo: para un documento nuevo (sin `id`) el formulario solo
mostraba el mensaje "Guarda el vehículo primero para subir el archivo", y la
subida real estaba detrás de un diálogo separado que exigía que el documento ya
existiera (`v-if="doc.id"`). El usuario recordaba poder seleccionar el archivo
inline y que se subía al dar "Guardar".

## Causa

`VehicleForm.vue` subía el archivo por un diálogo aparte
(`PUT /api/v1/vehicle_documents/:id` multipart) que requería `doc.id`. Como un
documento recién agregado no tiene `id` hasta guardar el vehículo, el control de
subida nunca aparecía para documentos nuevos.

## Arreglo (solo FE — `ttpn-frontend`)

`src/pages/Vehicles/components/VehicleForm.vue`:

- **Inline `q-file` por documento** (`doc._pendingFile`, transitorio, no viaja en
  el JSON), visible para documentos nuevos y existentes ("Adjuntar/Reemplazar
  archivo — se sube al guardar").
- `save()` ahora: 1) separa los archivos pendientes, 2) guarda el vehículo (JSON,
  vía `buildVehiclePayload` que envía solo campos permitidos de cada documento),
  3) sube cada archivo al `vehicle_documents/:id` correspondiente. Para documentos
  nuevos toma el `id` del documento recién creado que devuelve el BE, emparejando
  por `tipo_documento|numero` (`docKey`).
- Se eliminó el diálogo de subida separado y el botón gateado por `doc.id`.

No requiere cambios de BE: `vehicle_documents_attributes` ya permitía
`vehicle_doc_image` y el endpoint `PUT /vehicle_documents/:id` (multipart) ya
existía. Las actualizaciones de metadata no tocan la imagen adjunta (ActiveStorage
`has_one_attached`; solo se purga con `remove_vehicle_doc_image`).

Verificado: ESLint 0, build limpio. Desplegado a GitLab (Netlify) + GitHub.
