# Employee

## Propósito

Representa a un trabajador de TTPN. Es el modelo central del dominio de Recursos Humanos. Agrupa datos personales, laborales y operativos. Su estado activo/inactivo se gestiona exclusivamente a través de `EmployeeMovement` — **nunca modificando `status` directamente desde la UI**.

---

## Campos principales

| Campo            | Tipo    | Descripción                                                  |
|------------------|---------|--------------------------------------------------------------|
| `clv`            | string  | Clave única del empleado. Obligatoria. Ej: `OP-0042`         |
| `nombre`         | string  | Nombre(s). Obligatorio.                                      |
| `apaterno`       | string  | Apellido paterno. Obligatorio.                               |
| `amaterno`       | string  | Apellido materno.                                            |
| `area`           | string  | Área operativa. Valor `'operaciones'` activa lógica especial de desasignación de vehículo. |
| `status`         | boolean | Reflejo del último `EmployeeMovement`. **No modificar directamente.** Lo actualiza `revisar_status_chofer` (callback en `EmployeeMovement`). |
| `business_unit_id` | integer | FK a `BusinessUnit`. Todos los filtros se aplican sobre este campo. |
| `concessionaire_id` | integer | FK a `Concessionaire`. Opcional. |
| `labor_id`       | integer | FK a `Labor` (puesto). Obligatorio para distribución por puesto. |

---

## Constantes

| Constante        | Valor     | Descripción                                                   |
|------------------|-----------|---------------------------------------------------------------|
| `SIN_CHOFER_CLV` | `'00000'` | CLV del empleado ficticio "Sin Chofer". Se usa al desasignar un vehículo en una Baja. |

### `Employee.sin_chofer_id`

Retorna el `id` del empleado "Sin Chofer" (memoizado por proceso). Se identifica por `clv = SIN_CHOFER_CLV`. Si no existe el registro, retorna `nil`.

---

## Validaciones

- `business_unit`: presencia (obligatorio, calculado en el controller al crear).
- `clv`: presencia y unicidad.
- `nombre`: presencia.
- `apaterno`: presencia.

---

## Asociaciones

| Asociación                    | Tipo              | Notas                                                        |
|-------------------------------|-------------------|--------------------------------------------------------------|
| `business_unit`               | `belongs_to`      | **Obligatorio.** Se asigna automáticamente en el controller al crear (del `Current.business_unit` del usuario). El FE no lo envía. |
| `concessionaire`              | `belongs_to`      | Opcional.                                                    |
| `labor`                       | `belongs_to`      | Puesto / categoría laboral.                                  |
| `employee_movements`          | `has_many`        | Historial de altas, bajas y reingresos. **Fuente de verdad del estado.** |
| `employee_documents`          | `has_many`        | Documentos adjuntos (licencias, IMSS, etc.). `dependent: :destroy`. |
| `employee_salaries`           | `has_many`        | Historial de salarios. `dependent: :destroy`.                |
| `employee_work_days`          | `has_many`        | Días laborales configurados. `dependent: :destroy`.          |
| `employee_drivers_levels`     | `has_many`        | Niveles de conductor. `dependent: :destroy`.                 |
| `employee_deductions`         | `has_many`        | Deducciones de nómina. `dependent: :destroy`.                |
| `vehicle_asignations`         | `has_many`        | Asignaciones de unidad (chofer ↔ vehículo).                  |
| `travel_counts`               | `has_many`        | Registros de viajes realizados.                              |
| `employee_vacations`          | `has_many`        | Periodos de vacaciones. `dependent: :destroy`.               |
| `avatar`                      | Active Storage    | Imagen de perfil. URL via `avatar.url` (S3 presignado).      |

---

## Scopes

| Scope                  | Descripción                                                                           |
|------------------------|---------------------------------------------------------------------------------------|
| `business_unit_filter` | Filtra por `Current.business_unit.id`. Retorna `none` si no hay BU activa. **No aplicar sadmin bypass aquí — ver Vehicle para contraste.** |

> **Nota:** A diferencia de `Vehicle`, el scope de `Employee` retorna `none` cuando no hay BU activa (sadmin debe usar todos). El sadmin que necesite ver todos los empleados debe asignar una BU en `Current` o usar `Employee.all` explícitamente.

---

## Métodos de instancia

### `fecha_inicio_actual`

Retorna la `fecha_efectiva` del último movimiento de Alta o Reingreso. Si no existe, usa `created_at.to_date`.

### `years_worked(hasta_fecha = Date.today)`

Años trabajados desde el último Alta/Reingreso. Usado para calcular vacaciones.

### `dias_vacaciones_correspondientes(hasta_fecha)`

Consulta `KumiSetting.vacation_days_for_year(business_unit_id, years)` con los años calculados.

### `dias_vacaciones_pendientes(hasta_fecha)`

`correspondientes - tomados`. Los tomados se suman de `EmployeeVacation`.

### `avatar_url`

Retorna `avatar.url` (URL presignada de S3). Retorna `nil` si no hay avatar adjunto.

---

## Reglas de negocio críticas

### Estado activo/inactivo

`status` es un campo denormalizado. Su valor canónico lo mantiene `EmployeeMovement#revisar_status_chofer` (callback `after_save`):
- Si el último movimiento del empleado (por `fecha_efectiva`) es Baja o Baja-LN → `status = false`.
- Si es Alta o Reingreso → `status = true`.

**No modificar `status` directamente desde controllers ni desde la consola** a menos que sea una corrección de datos.

### Desasignación de vehículo en Baja

Cuando se registra una Baja o Baja-Lista Negra, el callback `revisar_status_chofer` llama a `desasignar_vehiculo`. El flujo es:

1. Busca la última `VehicleAsignation` del chofer (por `fecha_efectiva DESC`).
2. Si `fecha_hasta` ya tiene valor → el vehículo fue reasignado antes de la baja → **no hace nada**.
3. Si `fecha_hasta` es `NULL` (asignación activa) → crea una nueva `VehicleAsignation` con `employee_id = Employee.sin_chofer_id`, mismo `vehicle_id` y `business_unit_id` del vehículo. El callback `before_create :finalize_previous_asignations` de `VehicleAsignation` cierra automáticamente la asignación del chofer saliente.
4. Cancela los `TtpnBooking` futuros asignados a ese chofer (`employee_id` y `vehicle_id` → `nil`).

El `business_unit_id` de la nueva asignación **siempre viene del vehículo**, no del usuario que registra la baja. Esto protege la integridad aunque un sadmin opere desde otra BU.

### Plantilla activa histórica

Para calcular cuántos empleados estaban activos en una fecha pasada, **no usar `Employee.where('created_at < ?', date).count`** — eso cuenta el total histórico acumulado.

La fuente correcta es `EmployeeMovement`:

```ruby
# Empleados activos en `date` para la BU actual
EmployeeMovement
  .joins(:employee)
  .merge(Employee.business_unit_filter)
  .where(employee_movement_type_id: alta_y_reingreso_ids)
  .where('fecha_efectiva <= ?', date)
  .where('fecha_expiracion IS NULL OR fecha_expiracion > ?', date)
  .count('DISTINCT employee_movements.employee_id')
```

Ver implementación en `EmployeeStatsCalculable#active_headcount_at`.

---

## Indicadores derivados (KPIs)

Los KPIs del módulo de RR.HH. se calculan en `EmployeeStatsCalculable`:

| KPI                    | Fuente                                      |
|------------------------|---------------------------------------------|
| Headcount total        | `Employee.business_unit_filter.count`       |
| Headcount activos      | `Employee.business_unit_filter.where(status: true).count` |
| Altas del período      | `EmployeeMovement` con tipo Alta y fecha en rango |
| Bajas del período      | `EmployeeMovement` con tipo Baja/Baja-LN y fecha en rango |
| Reingresos del período | `EmployeeMovement` con tipo Reingreso y fecha en rango |
| Promedio plantilla     | Headcount activo al inicio + fin del año / 2 (usa `active_headcount_at`) |
| % Rotación             | `(bajas / promedio_plantilla) * 100`        |
| Antigüedad promedio    | Días desde la primera Alta de cada empleado |

---

## Nested attributes aceptados

- `employee_documents_attributes` — rechaza si `employee_document_type_id` está en blanco.
- `employee_movements_attributes` — rechaza si `employee_movement_type_id` está en blanco.
- `employee_salaries_attributes` — rechaza si `sdi` está en blanco.
- `employee_drivers_levels_attributes`
- `employee_work_days_attributes`

---

## Archivos relacionados

- `app/models/employee.rb`
- `app/models/employee_movement.rb`
- `app/models/employee_movement_type.rb`
- `app/controllers/concerns/employee_stats_calculable.rb`
- `app/serializers/employee_serializer.rb`
- `app/controllers/api/v1/employees_controller.rb`
