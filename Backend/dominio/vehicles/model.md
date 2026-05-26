# Vehicle

## Propósito

Representa una unidad de la flotilla de TTPN (autobús, van, etc.). Pertenece a **una** BusinessUnit dueña (`business_unit_id`) y a una o más Concesionarias (dato comercial/administrativo). Soporta documentos adjuntos (licencias, permisos) con imágenes/PDFs en S3.

> **Visibilidad (importante):** el listado de cada BU muestra los vehículos de su **BU dueña** (`business_unit_id`) **y** los que el sadmin le **prestó** (`operable_business_units`). La concesionaria **ya no** otorga visibilidad cross-BU (ver "Scopes" e "Histórico: Regla B"). El **servicio** cross-BU (taller/autolavado/hojalatería) usa la relación dedicada `serviceable_business_units` (no entra al listado de flotilla).

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
| `business_unit_id` | integer | FK a `BusinessUnit`. **BU dueña.** Criterio base del listado (`business_unit_filter` = dueña O operable). Se auto-asigna al crear desde `Current.business_unit` (`BusinessUnitAssignable`). |

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
| `serviceable_business_units` | `has_and_belongs_to_many` | OTRAS BUs que pueden **dar servicio** al vehículo (taller/autolavado). Inicia vacío. Tabla join `vehicle_serviceable_business_units`. Inverso: `BusinessUnit#serviceable_vehicles`. **No** entra a `business_unit_filter`. |
| `operable_business_units` | `has_and_belongs_to_many` | OTRAS BUs que pueden **operar** el vehículo (préstamo). Inicia vacío; solo sadmin. Tabla join `vehicle_operable_business_units`. Inverso: `BusinessUnit#operable_vehicles`. **Sí** entra a `business_unit_filter` (aparece en su flotilla). |
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

Filtra por la BU **dueña** (`business_unit_id`) **O** las BUs que pueden **operar** el vehículo (`operable_business_units`, préstamo cross-BU):

```ruby
scope :business_unit_filter, lambda {
  return all if Current.user&.sadmin? && Current.business_unit.nil?
  return none unless Current.business_unit

  bu_id = Current.business_unit.id
  operable_ids = Vehicle.joins(:operable_business_units)
    .where(business_units: { id: bu_id }).select(:id)
  where(business_unit_id: bu_id).or(where(id: operable_ids)).distinct
}
```

- Super admin (`sadmin?`) **sin BU activa** ve **todos** los vehículos (`return all`).
- Super admin **con BU activa** respeta el mismo filtro que cualquier usuario.
- Sin BU activa (non-sadmin sin BU): retorna `none`.

> Un vehículo aparece en su BU dueña y en las BUs a las que el sadmin lo **prestó** (`operable_business_units`). Es el **mismo registro** (mismo `id`): no se duplica ni se parte el historial. El **servicio** (`serviceable_business_units`) NO entra en este filtro.

#### Histórico: "Regla B" (eliminada — 2026-05-25)

Antes el scope tenía una **segunda regla** que hacía visible un vehículo en otra BU si **alguno de sus concesionarios** estaba ligado a esa BU (`Vehicle → Concessionaires → BusinessUnits`). Se eliminó porque, al permitirse que **un concesionario se comparta entre varias BUs**, esa regla "ensuciaba" el listado de cada BU con vehículos ajenos (un vehículo dado de alta en TTPN aparecía en BU 2, 3, … solo por compartir concesionario). La concesionaria volvió a ser un dato puramente comercial; **no** otorga visibilidad. La visibilidad cross-BU legítima (taller/autolavado/hojalatería que atiende flota de otra BU) se resuelve ahora con `serviceable_business_units`.

### `active` / `inactive`

`where(status: true)` / `where(status: false)`.

### `ordered_by_status`

Activos primero, luego inactivos. Dentro de cada grupo, orden por `clv`.

---

## Relaciones cross-BU: servicio vs. operación

Dos relaciones **dedicadas** (HABTM), ambas inician **vacías** (solo las gestiona el **sadmin**); son
el reemplazo explícito de la vieja "regla B" por concesionario. La **BU dueña no se auto-agrega** a
ninguna de las dos:

| Relación | Tabla join | Qué habilita | ¿Entra a `business_unit_filter`? |
| --- | --- | --- | --- |
| `serviceable_business_units` | `vehicle_serviceable_business_units` | Otras BUs **dan servicio** (taller/autolavado/hojalatería) | **No** — solo el endpoint `serviceable` |
| `operable_business_units` | `vehicle_operable_business_units` | Otras BUs **operan** el vehículo (préstamo: asignar chofer, usarlo en viajes) | **Sí** — aparece en su flotilla |

En ambas el vehículo **sigue siendo el mismo registro** (mismo `id`, misma BU dueña): no se duplica
ni se parte el historial. Índice único `(vehicle_id, business_unit_id)` en cada tabla.

### `serviceable_business_units` (servicio)
- Inicia vacío; guarda solo las **otras** BU que dan servicio (la dueña NO se agrega).
- El endpoint `GET /vehicles/serviceable` devuelve **BU dueña O serviceable** (así la propia BU sigue
  viendo sus vehículos en el picker aunque serviceable esté vacío). La OT (`Mtto::WorkOrder`) acepta
  `vehicle_id` de cualquier BU. Ver `Documentacion/Backend/dominio/mantenimiento/acceso_taller_camiones.md`.

```ruby
vehiculo.serviceable_business_units << bu_taller   # otra BU que da servicio
```

### `operable_business_units` (préstamo / operación)
- Inicia vacío; el sadmin agrega las BU a las que se **presta** el vehículo.
- `business_unit_filter` = `where(business_unit_id: bu).or(where(id: <operables por bu>))` → el vehículo
  aparece en la **flotilla** de esas BU y lo pueden operar (mismo `id`, sin perder historial).

```ruby
vehiculo.operable_business_units << bu_prestada    # otra BU que puede operar el vehículo
```

**FE:** el form (`ttpn-frontend/src/pages/Vehicles/components/VehicleForm.vue`) muestra —**solo a
sadmin**— dos multiselect: "Unidades de negocio que pueden dar servicio" (`serviceable_business_unit_ids`)
y "Unidades de negocio que pueden operar (préstamo)" (`operable_business_unit_ids`), ambos vía
`PATCH /api/v1/vehicles/:id`. Opciones del catálogo de BUs (`useBusinessUnitsDropdown`).
`business_unit_id` (BU dueña) **no** se muestra ni se manda: lo asigna el controller desde la BU del
usuario que crea/clona.

---

## Nested attributes

`vehicle_documents_attributes` — rechaza si `numero` está en blanco.

---

## FriendlyId

El `clv` se usa como slug. Para buscar un vehículo: `Vehicle.friendly.find(clv_o_id)`.

---

## Archivos relacionados

- `app/models/vehicle.rb`
- `app/models/business_unit.rb` — inversos `serviceable_vehicles`, `operable_vehicles`
- `app/models/vehicle_document.rb`
- `app/serializers/vehicle_serializer.rb`
- `app/controllers/api/v1/vehicles_controller.rb`
- `app/controllers/concerns/vehicle_serviceable_actions.rb` — endpoints serviceable / assign_serviceable
- `app/controllers/concerns/vehicle_stats_calculable.rb`
- `db/migrate/20260525000001_create_vehicle_serviceable_business_units.rb`
- `db/migrate/20260526000001_create_vehicle_operable_business_units.rb`
- FE: `ttpn-frontend/src/pages/Vehicles/components/VehicleForm.vue` (campos serviceable/operable, solo sadmin)
