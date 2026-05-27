# 2026-05-26 — Fix: subir documento de empleado (mismo problema que vehículos)

## Síntoma

Al agregar un documento a un empleado no se podía adjuntar el archivo (mensaje
"Guarda el empleado primero…" + diálogo separado). Igual que el bug de vehículos.

## Causas (3, encadenadas)

1. **FE**: `EmployeeForm.vue` subía por un diálogo gateado por `doc.id` (requería
   guardar primero); sin `q-file` inline.
2. **BE — controlador faltante**: la ruta `resources :employee_documents` existía
   pero **no había** `EmployeeDocumentsController`, así que
   `PUT /api/v1/employee_documents/:id` reventaba (no había a quién subir el archivo).
3. **BE — mismatch de campos**: el form/serializer usan `numero`/`expiracion`,
   pero el `employees_controller` permitía `identificador`/`vigencia` (columnas
   reales) → al guardar, número y vencimiento se descartaban.

## Fix

### BE (`ttpngas`)
- `EmployeeDocument`: `alias_attribute :numero, :identificador` y
  `:expiracion, :vigencia` + método `doc_image_url`.
- **Nuevo** `Api::V1::EmployeeDocumentsController` (index/show/create/update/destroy):
  permite `doc_image`, `remove_doc_image`, `numero`, `expiracion`, `descripcion`,
  `employee_document_type_id`. Upload multipart por `PUT /employee_documents/:id`.
- `employees_controller`: nested `employee_documents_attributes` ahora permite
  `numero`/`expiracion` (alias → identificador/vigencia); `create`/`update`
  responden con `EmployeeSerializer` (antes `@employee` crudo, sin documentos),
  necesario para emparejar el archivo de documentos nuevos.
- Specs: `employee_documents_spec` (alias numero/expiracion, upload multipart, 404,
  401). Suite empleados verde (40 ej., 0 fallos, 1 pending preexistente).

### FE (`ttpn-frontend`)
- `EmployeeForm.vue`: `q-file` inline por documento (`doc._pendingFile`,
  "se sube al guardar"); se quita el botón gateado por `doc.id` y el mensaje
  "Guarda primero". `saveEmployee` separa archivos pendientes, guarda el empleado
  (payload sin `_pendingFile`) y luego sube cada archivo a
  `employee_documents/:id` emparejando por `employee_document_type_id|numero`.
  (El diálogo de **avatar** se mantiene como estaba.)

Verificado: RuboCop 0, ESLint 0, build limpio. Desplegado: ttpngas → github
transform_to_api (Railway); FE → GitLab (Netlify) + GitHub. Espejo del fix de
vehículos (ver `2026-05-26_fix_vehiculos_subir_documento.md`).
