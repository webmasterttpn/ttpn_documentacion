# 2026-05-26 — Préstamo cross-BU (operable_business_units) + alineación de serviceable

## Contexto

Del plan de ciclo de vida del vehículo se sacó (sin riesgo de trazabilidad) la pieza de **préstamo
cross-BU**: un vehículo puede ser **operado** por varias BU. A diferencia de reutilizar el CLV con un
registro nuevo (diferido por romper historial), operable usa **el mismo registro** (mismo `id`), así
que `ttpn_bookings`/`gas_charges`/`gasoline_charges`/`vehicle_asignations`/`travel_counts` quedan
intactos. El sadmin lo habilita por vehículo.

También se **alineó `serviceable`** con el modelo del usuario: ambas relaciones (servicio y operación)
inician **vacías**, guardan solo **otras** BU, y la **BU dueña no se auto-agrega**.

## Definición confirmada por el usuario

- **`business_unit_id`** (BU dueña): **invisible** para el usuario; el controller lo asigna desde la BU
  del usuario que crea/clona (`BusinessUnitAssignable`; no está en los `permit`).
- **`operable_business_units`**: solo sadmin; nulo por defecto; ahí se agregan las otras BU si hay
  préstamo.
- **`serviceable_business_units`**: solo sadmin; nulo por defecto; las otras BU que dan servicio.

## Cambios (backend, ttpngas)

- Migración `20260526000001_create_vehicle_operable_business_units` (join `id: false`, índice único
  `(vehicle_id, business_unit_id)` `idx_vehicle_operable_bu_unique`, **sin backfill** — opt-in).
- `Vehicle#operable_business_units` (HABTM) + inverso `BusinessUnit#operable_vehicles`.
- **`Vehicle.business_unit_filter`** = `where(business_unit_id: bu).or(where(id: <operables por bu>)).distinct`
  → el vehículo aparece en la flotilla de la BU dueña y de las BU a las que se prestó.
- Serializer expone `operable_business_units`; `permitted_vehicle_attributes` permite
  `operable_business_unit_ids` (y `serviceable_business_unit_ids`) **solo a sadmin**.
- **Alineación serviceable:** se eliminó el callback `ensure_owner_business_unit_serviceable` (ya no
  auto-agrega la BU dueña). El endpoint `GET /vehicles/serviceable` ahora devuelve **BU dueña O
  serviceable** (vía `serviceable_scope`), para que la propia BU siga viendo sus vehículos aunque
  serviceable esté vacío.
- Specs: relación operable, `business_unit_filter` incluye operable, PATCH operable solo sadmin
  (no-sadmin ignora el param); serviceable reescrito (inicia vacío; guarda solo otras BU). Suite
  completa **0 failures**. RuboCop sin offenses nuevas (HABTM de operable sigue el patrón aceptado).

## Cambios (frontend, ttpn-frontend)

- `VehicleForm.vue`: segundo multiselect **"Unidades de negocio que pueden operar (préstamo)"**
  (`operable_business_unit_ids`), solo sadmin, junto al de serviceable. `buildForm` mapea
  `operable_business_units` → `operable_business_unit_ids`. ESLint 0 + build OK.

## Qué NO cambió / sigue diferido

- **No** se duplica el vehículo ni se toca el CLV. La reutilización de CLV con registro nuevo +
  preservación de historial, la notificación al sadmin por conflicto de CLV y el clonado-reuse siguen
  en la fase completa diferida (ver `2026-05-26_plan_ciclo_de_vida_vehiculo.md`).
- Las offenses de modelo pre-existentes (HABTM, `dependent:`, índice de `clv`) siguen fuera de alcance.

## Verificación

1. Sadmin agrega BU-2 a `operable_business_units` de un vehículo de BU-1 (form o PATCH) → usuario de
   BU-2 lo ve en su flotilla (`business_unit_filter`); BU-3 no.
2. serviceable inicia vacío; el picker `/vehicles/serviceable` de la BU dueña sigue devolviendo sus
   vehículos (cláusula dueña O serviceable).
3. RSpec suite **0 failures**; ESLint 0 + build FE OK.
