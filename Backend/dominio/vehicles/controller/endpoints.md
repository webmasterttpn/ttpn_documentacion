# Vehicles — Endpoints

`Api::V1::VehiclesController`. Todos requieren autenticación (JWT o API Key). El listado
estándar respeta la BU dueña (`Vehicle.business_unit_filter`, solo `business_unit_id`).

## CRUD estándar

| Método | Ruta | Notas |
| --- | --- | --- |
| GET | `/api/v1/vehicles` | Lista por BU dueña. `?search=` (clv/placa, ILIKE). Cacheado por BU. |
| GET | `/api/v1/vehicles/:id` | Detalle (slug FriendlyId). Incluye `serviceable_business_units`. |
| POST | `/api/v1/vehicles` | Crea. Auto-asigna `business_unit_id` de la BU activa. |
| PATCH/PUT | `/api/v1/vehicles/:id` | Actualiza. `serviceable_business_unit_ids: []` **solo permitido a sadmin**. |
| DELETE | `/api/v1/vehicles/:id` | Elimina. |
| GET | `/api/v1/vehicles/:id/capacity` | Capacidad sugerida para auto-crear pasajeros. |

## Visibilidad cross-BU de servicio

Ver el modelo [model.md](../model.md) (relación `serviceable_business_units`, regla B eliminada).

### `GET /api/v1/vehicles/serviceable`

Vehículos que la **BU activa puede ATENDER**: su BU dueña + los concedidos vía
`serviceable_business_units`. Para el **picker de OT** de una BU de servicio (taller de
camiones / autolavado / hojalatería) que opera flota de otras BU. **No** usa
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

## Archivos

- `app/controllers/api/v1/vehicles_controller.rb`
- `app/serializers/vehicle_serializer.rb` (`serviceable_business_units` en la vista completa)
- `config/routes/vehicles.rb`
- Swagger: `spec/requests/api/v1/vehicles_spec.rb` → `swagger/v1/swagger.yaml`
