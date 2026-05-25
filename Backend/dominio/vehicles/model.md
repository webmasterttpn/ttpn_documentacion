# Vehicle

## Propósito

Representa una unidad de la flotilla de TTPN (autobús, van, etc.). Pertenece a **una** BusinessUnit dueña (`business_unit_id`) y a una o más Concesionarias (dato comercial/administrativo). Soporta documentos adjuntos (licencias, permisos) con imágenes/PDFs en S3.

> **Visibilidad (importante):** el listado de vehículos de cada BU se filtra **solo por `business_unit_id`** (la BU dueña). La concesionaria **ya no** otorga visibilidad cross-BU (ver "Scopes" e "Histórico: Regla B"). Para que una BU de servicio (taller, autolavado, hojalatería) atienda flota de otra BU se usa la relación dedicada `serviceable_business_units`.

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
| `business_unit_id` | integer | FK a `BusinessUnit`. **BU dueña.** Único criterio del listado (`business_unit_filter`). Se auto-asigna al crear desde `Current.business_unit` (`BusinessUnitAssignable`). |

---

## Concerns incluidos

| Concern                | Qué agrega                                                         |
|------------------------|--------------------------------------------------------------------|
| `BusinessUnitAssignable` | Auto-asigna `business_unit_id` al crear desde `Current.business_unit`. **Nota:** Vehicle **sobrescribe** el scope `business_unit_filter` del concern (ver "Scopes"). |
| `Auditable`            | `created_by_id`, `updated_by_id`. Callbacks automáticos.          |
| `Cacheable`            | Cache TTL = 1 hora. Invalida en `after_save`.                      |

---

## Asociaciones

| Asociación           | Tipo                      | Notas                                                    |
|----------------------|---------------------------|----------------------------------------------------------|
| `vehicle_type`       | `belongs_to`              |                                                          |
| `concessionaires`    | `has_and_belongs_to_many` | Tabla join `concessionaires_vehicles`. Dato comercial; **no** afecta visibilidad. |
| `serviceable_business_units` | `has_and_belongs_to_many` | BUs que pueden **atender/dar servicio** al vehículo además de su BU dueña. Tabla join `vehicle_serviceable_business_units`. Clase `BusinessUnit`. Inverso: `BusinessUnit#serviceable_vehicles`. |
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

Filtra **solo** por la BU dueña (`business_unit_id`):

```ruby
scope :business_unit_filter, lambda {
  return all if Current.user&.sadmin? && Current.business_unit.nil?
  return none unless Current.business_unit

  where(business_unit_id: Current.business_unit.id)
}
```

- Super admin (`sadmin?`) **sin BU activa** ve **todos** los vehículos (`return all`).
- Super admin **con BU activa** respeta el mismo filtro que cualquier usuario.
- Sin BU activa (non-sadmin sin BU): retorna `none`.

> Igual que `Employee.business_unit_filter`: cada vehículo se ve únicamente en su BU dueña.

#### Histórico: "Regla B" (eliminada — 2026-05-25)

Antes el scope tenía una **segunda regla** que hacía visible un vehículo en otra BU si **alguno de sus concesionarios** estaba ligado a esa BU (`Vehicle → Concessionaires → BusinessUnits`). Se eliminó porque, al permitirse que **un concesionario se comparta entre varias BUs**, esa regla "ensuciaba" el listado de cada BU con vehículos ajenos (un vehículo dado de alta en TTPN aparecía en BU 2, 3, … solo por compartir concesionario). La concesionaria volvió a ser un dato puramente comercial; **no** otorga visibilidad. La visibilidad cross-BU legítima (taller/autolavado/hojalatería que atiende flota de otra BU) se resuelve ahora con `serviceable_business_units`.

### `active` / `inactive`

`where(status: true)` / `where(status: false)`.

### `ordered_by_status`

Activos primero, luego inactivos. Dentro de cada grupo, orden por `clv`.

---

## Visibilidad cross-BU de servicio (`serviceable_business_units`)

Relación **dedicada** (HABTM, tabla `vehicle_serviceable_business_units`) que indica **qué BUs pueden atender / dar servicio** a un vehículo, además de su BU dueña. Habilita que una BU de servicio (taller de camiones, autolavado, hojalatería) vea y opere flota de otras BUs **sin** alterar `business_unit_filter` (que sigue siendo solo por BU dueña) y **sin** acoplar el concepto a "concesionario".

- **Auto-fill al crear:** el callback `after_create :ensure_owner_business_unit_serviceable` agrega la BU donde se da de alta el vehículo (`business_unit_id`, tomada de `Current.business_unit`) a la lista. Idempotente (no duplica) y no-op si el vehículo se crea sin BU.
- **Backfill inicial (migración `20260525000001`):** cada vehículo existente quedó atendible por su BU dueña (`COALESCE(business_unit_id, 1)` — toda la data actual es BU 1).
- **Índice único** `(vehicle_id, business_unit_id)` (`idx_vehicle_serviceable_bu_unique`) garantiza idempotencia a nivel BD.
- **Uso previsto:** el flujo de servicio (p. ej. picker de vehículo de una OT de mantenimiento de la BU taller) consulta los vehículos donde la BU activa está en `serviceable_business_units`, en vez de `business_unit_filter`. La OT (`Mtto::WorkOrder`) ya acepta `vehicle_id` de cualquier BU.

```ruby
# Agregar una BU de servicio a un vehículo
vehiculo.serviceable_business_units << bu_taller

# Vehículos que la BU activa puede atender (dueña + concedidos)
Vehicle.joins(:serviceable_business_units)
       .where(business_units: { id: Current.business_unit.id })
```

> El vehículo **sigue perteneciendo** a su BU dueña; `serviceable_business_units` solo **agrega** quién más lo puede atender. Ver `Documentacion/Backend/dominio/mantenimiento/acceso_taller_camiones.md`.

---

## Nested attributes

`vehicle_documents_attributes` — rechaza si `numero` está en blanco.

---

## FriendlyId

El `clv` se usa como slug. Para buscar un vehículo: `Vehicle.friendly.find(clv_o_id)`.

---

## Archivos relacionados

- `app/models/vehicle.rb`
- `app/models/business_unit.rb` — inverso `serviceable_vehicles`
- `app/models/vehicle_document.rb`
- `app/serializers/vehicle_serializer.rb`
- `app/controllers/api/v1/vehicles_controller.rb`
- `app/controllers/concerns/vehicle_stats_calculable.rb`
- `db/migrate/20260525000001_create_vehicle_serviceable_business_units.rb`
