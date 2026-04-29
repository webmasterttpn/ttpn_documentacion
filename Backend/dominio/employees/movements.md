# EmployeeMovement

## Propósito

Registra cada cambio de estado laboral de un empleado: Alta, Baja, Baja-Lista Negra o Reingreso. Es la **fuente de verdad** del estado activo/inactivo de cualquier empleado. También actualiza `Employee.status` automáticamente vía callback `after_save`.

---

## Campos principales

| Campo                        | Tipo    | Descripción                                                                 |
|------------------------------|---------|-----------------------------------------------------------------------------|
| `employee_id`                | integer | FK a `Employee`.                                                            |
| `employee_movement_type_id`  | integer | FK a `EmployeeMovementType`. Determina el tipo (Alta, Baja, Reingreso, etc.). |
| `fecha_efectiva`             | date    | Fecha en que el movimiento entra en vigor. Es el campo de referencia temporal. |
| `fecha_expiracion`           | date    | Fecha en que este movimiento fue cerrado por uno posterior. `nil` si el movimiento está vigente. **Campo clave para cálculos históricos.** |
| `observaciones`              | text    | Notas libres.                                                               |

---

## Asociaciones

| Asociación                | Tipo          | Notas                         |
|---------------------------|---------------|-------------------------------|
| `employee`                | `belongs_to`  |                               |
| `employee_movement_type`  | `belongs_to`  | Tipo canónico del movimiento. |

---

## Ciclo de vida (`fecha_expiracion`)

`fecha_expiracion` es la clave para reconstruir el estado histórico:

| Escenario                                 | `fecha_expiracion` del movimiento previo |
|-------------------------------------------|------------------------------------------|
| Se registra una Baja tras un Alta         | Se pone `fecha_efectiva` de la Baja en el Alta anterior |
| Se registra una Baja-LN tras un Alta/Reing| Ídem                                     |
| Se registra un Reingreso tras una Baja    | Se pone `fecha_efectiva` del Reingreso en la Baja anterior |
| Movimiento actualmente vigente            | `fecha_expiracion = NULL`               |

Esto permite consultar "quién era activo en la fecha X" sin guardar snapshots:

```ruby
# Activos en `date` (en una BU dada)
EmployeeMovement
  .where(employee_movement_type_id: [alta_id, reingreso_id])
  .where('fecha_efectiva <= ?', date)
  .where('fecha_expiracion IS NULL OR fecha_expiracion > ?', date)
  .count('DISTINCT employee_id')
```

---

## Validaciones (`valida_transicion`, sólo `on: :create`)

| Tipo de movimiento | Regla                                                                 |
|--------------------|-----------------------------------------------------------------------|
| Alta               | Solo puede ocurrir una vez por empleado (si ya tiene Alta → error).   |
| Baja               | Requiere un Alta o Reingreso activo (sin `fecha_expiracion`).         |
| Baja - Lista Negra | Ídem Baja.                                                            |
| Reingreso          | Requiere Baja activa. Si hay Baja-LN activa, bloquea el Reingreso.    |

---

## Callbacks

### `before_create :cerrar_movimiento_previo`

Cierra el movimiento activo anterior antes de crear el nuevo:
- Baja / Baja-LN → cierra el Alta o Reingreso vigente.
- Reingreso → cierra la Baja vigente.

### `after_save :revisar_status_chofer`

Actualiza `Employee.status` basándose en el tipo del último movimiento (por `MAX(fecha_efectiva)`):

- Tipo = Baja o Baja-LN → `status = false` + llama a `desasignar_vehiculo(employee_id, fecha_efectiva)`.
- Tipo = Alta o Reingreso → `status = true`.

### `desasignar_vehiculo(emp_id, fecha_baja)` (privado)

Ejecutado únicamente en Baja/Baja-LN. Flujo:

1. Busca la última `VehicleAsignation` del empleado (`ORDER BY fecha_efectiva DESC`).
2. Si no existe o ya tiene `fecha_hasta` → el vehículo fue reasignado antes de la baja → **retorna sin hacer nada**.
3. Si `fecha_hasta` es `NULL` → crea una nueva `VehicleAsignation` con `employee_id = Employee.sin_chofer_id`, mismo `vehicle_id`, y `business_unit_id` tomado de la asignación del vehículo (no del usuario que registra la baja). La `fecha_efectiva` de la nueva asignación es la `fecha_efectiva` de la Baja.
4. El `before_create :finalize_previous_asignations` de `VehicleAsignation` cierra automáticamente la asignación activa del chofer saliente al crear la de Sin Chofer.
5. Cancela `TtpnBooking` futuros del chofer (pone `employee_id` y `vehicle_id` en `nil`).

Si `Employee.sin_chofer_id` retorna `nil` (registro no encontrado), loguea error y retorna sin crear asignación para no interrumpir la Baja.

---

## Reglas de negocio

- **No crear movimientos con fecha retroactiva sin revisión** — afecta `fecha_expiracion` de movimientos previos y puede romper el historial.
- **Alta ocurre solo una vez** por empleado. Los reingresos usan el tipo `Reingreso`, nunca un segundo Alta.
- **Un empleado con Baja-LN no puede recibir Reingreso** — se debe gestionar el caso manualmente a nivel de administración.

---

## Archivos relacionados

- `app/models/employee_movement.rb`
- `app/models/employee_movement_type.rb`
- `app/models/employee.rb`
- `app/controllers/concerns/employee_stats_calculable.rb` — usa `fecha_expiracion` para calcular `active_headcount_at`
