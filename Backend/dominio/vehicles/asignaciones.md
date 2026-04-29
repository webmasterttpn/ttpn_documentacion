# VehicleAsignation

## Propósito

Registra la asignación de un chofer a una unidad vehicular. Es la fuente de verdad del vínculo chofer ↔ vehículo en un momento dado. Una asignación sin `fecha_hasta` es la asignación activa.

---

## Campos principales

| Campo             | Tipo     | Descripción                                                                 |
|-------------------|----------|-----------------------------------------------------------------------------|
| `vehicle_id`      | integer  | FK a `Vehicle`. Obligatorio.                                                |
| `employee_id`     | integer  | FK a `Employee`. Obligatorio. Puede ser el empleado "Sin Chofer".           |
| `business_unit_id`| integer  | FK a `BusinessUnit`. Obligatorio. Siempre se toma del vehículo, no del usuario. |
| `fecha_efectiva`  | datetime | Fecha en que inicia la asignación. Obligatoria.                             |
| `fecha_hasta`     | datetime | Fecha en que termina la asignación. `NULL` = asignación activa.             |

---

## Reglas de negocio

### Una unidad, un chofer activo

Un vehículo solo puede tener **un** chofer activo (`fecha_hasta IS NULL`) a la vez. La excepción es el empleado "Sin Chofer" (`clv = '00000'`), que puede estar activo en múltiples unidades simultáneamente.

Un chofer regular tampoco puede tener más de una unidad activa al mismo tiempo.

### Empleado "Sin Chofer"

Representa una unidad sin chofer asignado. Se usa cuando un chofer es dado de baja y su unidad queda libre. Se identifica por `Employee::SIN_CHOFER_CLV = '00000'` y se obtiene su ID con `Employee.sin_chofer_id` (memoizado).

### `business_unit_id`

Siempre debe coincidir con la BU del vehículo. Al crear una asignación desde `desasignar_vehiculo` (Baja de chofer), se toma de la asignación previa del vehículo — nunca del `Current.business_unit` del usuario que opera, para proteger la integridad si un sadmin opera desde otra BU.

---

## Callbacks

### `before_create :finalize_previous_asignations`

Al crear una nueva asignación:

1. **Lado empleado** — cierra las asignaciones activas del empleado en *otros* vehículos. **Excepción: si el empleado es Sin Chofer, este paso se omite** para permitir que Sin Chofer esté activo en múltiples unidades.
2. **Lado vehículo** — cierra las asignaciones activas de *otros* empleados en este vehículo. Siempre se ejecuta.

### `after_create_commit :create_assignment_alert`

Crea una `Alert` con `trigger_type: 'new_assignment'` si existe una `AlertRule` activa para la BU. Dispara `AlertDispatchJob`.

---

## Scopes

| Scope               | Descripción                                          |
|---------------------|------------------------------------------------------|
| `.active`           | `fecha_hasta IS NULL OR fecha_hasta > Time.current`  |
| `.inactive`         | `fecha_hasta IS NOT NULL AND fecha_hasta <= Time.current` |
| `.by_vehicle(id)`   | Filtra por `vehicle_id`.                             |
| `.by_employee(id)`  | Filtra por `employee_id`.                            |
| `.by_business_unit(id)` | Filtra por `business_unit_id`.                   |
| `.latest_per_vehicle` | Última asignación de cada vehículo (JOIN optimizado, sin N+1). |

---

## Métodos de instancia

### `active?`

`true` si `fecha_hasta` es `nil` o posterior a `Time.current`.

### `finalize!`

Pone `fecha_hasta = Time.current`. Forma segura de cerrar una asignación desde código externo.

---

## Flujo: Baja de chofer → desasignación automática

Cuando se registra una Baja en `EmployeeMovement`:

1. `EmployeeMovement#desasignar_vehiculo` busca la última asignación del chofer.
2. Si ya tiene `fecha_hasta` → no hace nada (vehículo ya reasignado).
3. Si `fecha_hasta` es `NULL` → llama a `VehicleAsignation.create!` con Sin Chofer.
4. `finalize_previous_asignations` cierra la asignación del chofer saliente (por `vehicle_id`).

---

## Flujo: Reasignación manual

Cuando se crea una nueva asignación desde el controller de asignaciones:

1. `finalize_previous_asignations` cierra la asignación activa del chofer en su vehículo anterior.
2. `finalize_previous_asignations` cierra la asignación del chofer anterior en el nuevo vehículo.
3. La nueva asignación queda activa (`fecha_hasta = NULL`).

---

## Archivos relacionados

- `app/models/vehicle_asignation.rb`
- `app/models/employee.rb` — `SIN_CHOFER_CLV`, `sin_chofer_id`
- `app/models/employee_movement.rb` — `desasignar_vehiculo`
- `spec/models/vehicle_asignation_spec.rb`
