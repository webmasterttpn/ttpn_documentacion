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

## Zona horaria — `fecha_efectiva` / `fecha_hasta` son wall-clock

`fecha_efectiva` y `fecha_hasta` son columnas `datetime` que el negocio maneja
como **hora de pared (wall-clock)**, no como instante UTC a reconvertir (mismo
criterio que `travel_counts.hora`).

- **Backend (lectura)**: `VehicleAsignationsController#wall_clock` serializa
  ambas con los dígitos crudos almacenados, **sin zona** (sin la "Z"), vía
  `datetime&.utc&.strftime('%Y-%m-%dT%H:%M:%S')`. `.utc` normaliza a los dígitos
  guardados sin importar el `Time.zone` del entorno (en prod `config.time_zone`
  está comentado → UTC).
- **Frontend (escritura)**: `AsignationDialog.vue#onSubmit` envía la hora que el
  usuario eligió **tal cual** (string `YYYY-MM-DDTHH:mm`), sin `toISOString()`.
- **Backend (normalización en escritura)**: `VehicleAsignationsController#normalized_asignation_params`
  + `#to_wall_clock` normalizan `fecha_efectiva`/`fecha_hasta` ANTES de guardar.
  Si el valor trae zona (ISO con "Z" u offset — p. ej. un FE viejo cacheado en el
  PWA que todavía hace `toISOString`), se interpreta como instante UTC y se
  convierte a la hora local del negocio; si es naive (FE nuevo) se guarda igual.
  **Esto hace el fix robusto a la versión del FE**: no depende de redeploy ni de
  limpiar el service worker. (Síntoma que evita: ID 9323, hora fin guardada +6 h.)
- **Frontend (lectura)**: `date.formatDate` interpreta el string sin "Z" como
  hora local y la muestra verbatim.

**Síntoma que corrige**: la hora se veía desfasada en el FE (p. ej. −6 h) aunque
en la tabla estaba correcta, porque el ISO con "Z" hacía que el navegador la
reconvirtiera a su zona local. Regresión cubierta en
`spec/requests/api/v1/vehicle_asignations_spec.rb` (serialización sin zona +
round-trip de POST con `Time.use_zone('UTC')`).

### Escrituras "ahora" server-side — `VehicleAsignation.wall_clock_now`

Cuando el servidor escribe un "ahora" (finalizar asignación, cierre automático
de asignaciones previas) NO se usa `Time.current` (UTC), porque eso guardaría la
hora en UTC y la lectura verbatim la mostraría +6 h adelante. Se usa
`VehicleAsignation.wall_clock_now`, que toma la hora local del negocio
(`America/Chihuahua`, UTC-6) y la construye como instante naive con esos dígitos.

Aplica a:
- `VehicleAsignationsController#finalize` (`fecha_hasta`).
- `VehicleAsignation#finalize!`, `#active?`, scopes `active`/`inactive` y
  `finalize_previous_asignations` (consistencia: guardar y comparar "ahora"
  siempre en hora de pared).

Cubierto por la regresión `POST .../finalize` con `travel_to(Time.utc(...))`.

## Auditoría — `created_by_id` / `updated_by_id`

`vehicle_asignations` incluye los campos de control `created_by_id` y
`updated_by_id` (migración `20260522160000`). Se llenan **server-side** vía el
concern `Auditable` desde `Current.user` (configurado en `BaseController`); son
**transparentes para el FE** (no se envían en el payload ni se permiten en
`vehicle_asignation_params`). Ver `app/models/concerns/auditable.rb`.

---

## Archivos relacionados

- `app/models/vehicle_asignation.rb`
- `app/models/employee.rb` — `SIN_CHOFER_CLV`, `sin_chofer_id`
- `app/models/employee_movement.rb` — `desasignar_vehiculo`
- `spec/models/vehicle_asignation_spec.rb`
