# 2026-05-25 — Refactor RuboCop (capacity + serializer) y campo serviceable en el form de vehículo

## Contexto

Dos pedidos del usuario:
1. No encontraba en el FE **dónde asignar qué BU puede dar servicio** a un vehículo → porque la UI
   no existía (en la sesión previa solo se hizo el backend). Decisión: **campo en el form del vehículo**.
2. De los 9 offenses preexistentes de RuboCop, limpiar **las fáciles + refactor de `capacity`**.

## Backend (ttpngas)

### Limpieza RuboCop (las fáciles)
- `app/serializers/vehicle_serializer.rb`:
  - `documents_data` → extrae `document_hash(document)` (calcula el blob una sola vez; antes llamaba
    `attached?` 4 veces). Elimina `Metrics/AbcSize`.
  - `audit_data` → extrae `display_name(user)`. Elimina `Cyclomatic/PerceivedComplexity`.
- `spec/requests/api/v1/vehicles_request_spec.rb:27` → se quitó `allow_any_instance_of(Vehicle)`;
  ahora el 422 se prueba con validación real (`clv` en blanco) + assert del body de errores.

### Refactor de `capacity` → query object
- Nuevo `app/queries/vehicle_capacity_query.rb` (`VehicleCapacityQuery`, patrón de `TtpnBookingFilter`):
  encapsula el SQL grande (pasajeros_min/grupo según prefijo de CLV + tarifa del cliente), el fallback
  por prefijo y el chofer asignado (`VehicleAsignation` / "Sin Chofer" 00000). Devuelve
  `{ capacity:, group:, suggested_passengers:, employee_id: }`.
- `VehiclesController#capacity` quedó delgado: valida `client_id`/`@vehicle` y delega. Se borraron del
  controller `calculate_vehicle_capacity` y `find_assigned_employee` (movidos al query).
- Spec nuevo `spec/queries/vehicle_capacity_query_spec.rb` (fallback por CLV U/A, T/V, otro; chofer
  asignado). El spec de integración existente de `/capacity` (200 + 422) sigue verde → comportamiento
  preservado.

### Estado RuboCop tras el refactor
- Eliminadas: `documents_data` AbcSize, `audit_data` Cyclomatic/Perceived, `AnyInstance`,
  `capacity` MethodLength.
- `ClassLength` del controller bajó de **259 → 157** (sigue 7 sobre el límite de 150).
- `capacity` conserva `# rubocop:disable Metrics/AbcSize` justificado (ya es solo guards + delegación +
  render/rescue, igual criterio que `serviceable`).
- Pendiente/opcional (fuera del alcance elegido): `index` (AbcSize/Cyclomatic preexistente) y los
  últimos 7 de `ClassLength` (se eliminarían extrayendo `serviceable`/`assign_serviceable` a un concern).
- Suite completa: **1681 examples, 0 failures, 1 pending**.

## Frontend (ttpn-frontend)

- `src/pages/Vehicles/components/VehicleForm.vue`: nuevo multiselect **"Unidades de negocio que pueden
  dar servicio"**, visible **solo a sadmin** (`auth.user?.sadmin`). Bindea `serviceable_business_unit_ids`
  y se guarda vía `PATCH /vehicles/:id` (el BE solo lo permite a sadmin). Opciones del catálogo de BUs
  (`useBusinessUnitsDropdown`, cargado en `onMounted` solo si sadmin). `buildForm` mapea
  `serviceable_business_units` (del serializer) → `serviceable_business_unit_ids`.
- ESLint 0 + `npm run build` correcto.

## Pendiente

- **Commit + deploy** (preguntar antes; mismo flujo de remotes que siempre).
- **Asignación masiva**: el endpoint `POST /vehicles/assign_serviceable` sigue sin UI (se decidió el
  campo por vehículo). Queda como mejora si se requiere "todos los Camión de BU X → taller" desde UI.
