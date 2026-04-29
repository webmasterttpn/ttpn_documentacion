# Vehicle

## Propósito

Representa una unidad de la flotilla de TTPN (autobús, van, etc.). Pertenece a una o más Concesionarias, que a su vez están asociadas a BusinessUnits. Soporta documentos adjuntos (licencias, permisos) con imágenes/PDFs en S3.

---

## Campos principales

| Campo         | Tipo    | Descripción                                                       |
|---------------|---------|-------------------------------------------------------------------|
| `clv`         | string  | Número económico. Único. Usado como slug FriendlyId.              |
| `status`      | boolean | `true` = activo, `false` = baja.                                  |
| `marca`       | string  | Marca del vehículo.                                               |
| `modelo`      | string  | Modelo.                                                           |
| `annio`       | integer | Año de fabricación.                                               |
| `placa`       | string  | Número de placa.                                                  |
| `serie`       | string  | Número de serie.                                                  |
| `app_version` | string  | Versión de la app instalada en la unidad (si aplica).             |
| `vehicle_type_id` | integer | FK a `VehicleType`. Tipo de unidad.                          |

---

## Concerns incluidos

| Concern                | Qué agrega                                                         |
|------------------------|--------------------------------------------------------------------|
| `BusinessUnitAssignable` | Scope `business_unit_filter`. Auto-asigna `business_unit_id` al crear (no aplica directamente — Vehicle filtra via concessionaires). |
| `Auditable`            | `created_by_id`, `updated_by_id`. Callbacks automáticos.          |
| `Cacheable`            | Cache TTL = 1 hora. Invalida en `after_save`.                      |

---

## Asociaciones

| Asociación           | Tipo                      | Notas                                                    |
|----------------------|---------------------------|----------------------------------------------------------|
| `vehicle_type`       | `belongs_to`              |                                                          |
| `concessionaires`    | `has_and_belongs_to_many` | Tabla join `concessionaires_vehicles`.                   |
| `vehicle_documents`  | `has_many`                | Documentos de la unidad. `dependent: :destroy`.          |
| `gas_charges`        | `has_many`                | Cargas de combustible.                                   |
| `vehicle_check`      | `has_one`                 | Checklist de revisión.                                   |
| `vehicle_asignations`| `has_many`                | Histórico de asignaciones chofer ↔ unidad.               |
| `employees_incidences`| `has_many`               | Incidencias reportadas por operadores.                   |

---

## Validaciones

- `clv`: presencia y unicidad.

---

## Scopes

### `business_unit_filter`

Filtra a través de la cadena `Vehicle → Concessionaires → BusinessUnits`:

```ruby
joins(:concessionaires)
  .where(concessionaires: {
    id: Concessionaire.joins(:business_units).where(business_units: { id: Current.business_unit.id }).select(:id)
  })
  .distinct
```

- Super admin (`sadmin?`) ve **todos** los vehículos (`return all`).
- Sin BU activa (non-sadmin sin BU): retorna `none`.

> Esto es diferente a `Employee.business_unit_filter`, que filtra directamente por `business_unit_id`.

### `active` / `inactive`

`where(status: true)` / `where(status: false)`.

### `ordered_by_status`

Activos primero, luego inactivos. Dentro de cada grupo, orden por `clv`.

---

## Nested attributes

`vehicle_documents_attributes` — rechaza si `numero` está en blanco.

---

## FriendlyId

El `clv` se usa como slug. Para buscar un vehículo: `Vehicle.friendly.find(clv_o_id)`.

---

## Archivos relacionados

- `app/models/vehicle.rb`
- `app/models/vehicle_document.rb`
- `app/serializers/vehicle_serializer.rb`
- `app/controllers/api/v1/vehicles_controller.rb`
- `app/controllers/concerns/vehicle_stats_calculable.rb`
