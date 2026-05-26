# Vehicles — Endpoints

`Api::V1::VehiclesController`. Todos requieren autenticación (JWT o API Key). El listado
estándar respeta la BU dueña (`Vehicle.business_unit_filter`, solo `business_unit_id`).

## CRUD estándar

| Método | Ruta | Notas |
| --- | --- | --- |
| GET | `/api/v1/vehicles` | Lista por `business_unit_filter` = BU dueña **O** operable. `?search=` (clv/placa, ILIKE). Cacheado por BU. |
| GET | `/api/v1/vehicles/:id` | Detalle (slug FriendlyId). Incluye `serviceable_business_units` y `operable_business_units`. |
| POST | `/api/v1/vehicles` | Crea. Auto-asigna `business_unit_id` de la BU del usuario (no se manda ni se ve). |
| PATCH/PUT | `/api/v1/vehicles/:id` | Actualiza. `serviceable_business_unit_ids` y `operable_business_unit_ids` **solo permitidos a sadmin**. |
| DELETE | `/api/v1/vehicles/:id` | Elimina. |
| GET | `/api/v1/vehicles/:id/capacity` | Capacidad sugerida para auto-crear pasajeros. |

## Visibilidad cross-BU: servicio (serviceable) vs. operación (operable)

Ver el modelo [model.md](../model.md). Dos relaciones dedicadas, ambas inician vacías y solo las
gestiona el sadmin (reemplazo explícito de la regla B):
- **operable** (préstamo: operar el vehículo) → entra a `business_unit_filter` (aparece en la flotilla).
- **serviceable** (dar servicio) → NO entra a `business_unit_filter`; solo al endpoint de abajo.

### `GET /api/v1/vehicles/serviceable`

Vehículos que la **BU activa puede ATENDER**: su BU dueña **O** los concedidos vía
`serviceable_business_units` (la BU dueña ya no se auto-agrega; el endpoint la incluye explícito).
Para el **picker de OT** de una BU de servicio (taller / autolavado / hojalatería). **No** usa
`business_unit_filter`.

| Param (query) | Tipo | Descripción |
| --- | --- | --- |
| `vehicle_type_id` | integer | Filtra por tipo (p. ej. solo "Camion"). Opcional. |
| `search` | string | clv o placa (ILIKE). Opcional. |
| `include_inactive` | boolean | Incluir `status=false`. Default: solo activos. |

- Respuesta: array de vehículos (serializer `minimal`). Límite 500.
- Sadmin sin BU activa: devuelve todos (cap 500).
- **401** sin token.

### `POST /api/v1/vehicles/assign_serviceable` — **solo sadmin**

Asigna —o revoca con `remove=true`— una **BU de servicio** a un conjunto de vehículos
(operación de configuración cross-BU). Idempotente.

| Param (body JSON) | Tipo | Descripción |
| --- | --- | --- |
| `service_business_unit_id` | integer | **Requerido.** BU que podrá atender los vehículos. |
| `vehicle_ids` | array<int> | Selección explícita de vehículos. |
| `owner_business_unit_id` | integer | Selecciona todos los vehículos de esta BU dueña. |
| `vehicle_type_id` | integer | Restringe la selección anterior a este tipo (p. ej. "Camion"). |
| `remove` | boolean | `true` para revocar en vez de asignar. |

- Selección: usar `vehicle_ids` **o** `owner_business_unit_id` (+ `vehicle_type_id` opcional).
  Caso típico: *todos los "Camion" de TTPN → atendibles por la BU del taller.*
- Respuesta `200`: `{ business_unit_id, affected, total_matched }`.
- **422** si falta selección o `service_business_unit_id` es inválido.
- **403** si el usuario no es sadmin.

> `service_business_unit_id` se nombra distinto de `business_unit_id` a propósito: para un
> sadmin, `business_unit_id` es el param que el `BaseController` usa como filtro de BU activa.

## `GET /api/v1/vehicles/:id/capacity`

Capacidad sugerida de pasajeros (según tipo de unidad por prefijo de CLV y tarifa vigente del
cliente) + chofer asignado. La lógica vive en el query object `VehicleCapacityQuery`
(`app/queries/vehicle_capacity_query.rb`); el controller solo valida `client_id`/`@vehicle` y delega.

## Archivos

- `app/controllers/api/v1/vehicles_controller.rb`
- `app/queries/vehicle_capacity_query.rb` — lógica de `capacity` (SQL + fallback por CLV + chofer asignado)
- `app/serializers/vehicle_serializer.rb` (`serviceable_business_units` en la vista completa)
- `config/routes/vehicles.rb`
- FE: `ttpn-frontend/src/pages/Vehicles/components/VehicleForm.vue` (campos serviceable y operable, solo sadmin)
- Swagger: `spec/requests/api/v1/vehicles_spec.rb` → `swagger/v1/swagger.yaml`
