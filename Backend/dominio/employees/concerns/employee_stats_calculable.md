# EmployeeStatsCalculable (controller concern)

## Qué hace

Centraliza el cálculo de todos los KPIs del módulo de Recursos Humanos. Lo incluye `Api::V1::EmployeeStatsController`.

## Método principal

### `build_stats(year)`

Retorna un hash con todos los indicadores para el año dado:

```ruby
{
  year:                     year,
  headcount:                { total:, activos:, inactivos: },
  rotacion:                 { bajas:, altas:, reingresos:, promedio_plantilla:, porcentaje_rotacion: },
  distribucion_area:        [{ area:, total: }, ...],
  distribucion_puesto:      [{ puesto:, total: }, ...],
  antiguedad_promedio_dias: integer,
  documentos:               { vencidos:, por_vencer_30_dias: },
  citas:                    { total:, por_status: }
}
```

---

## Métodos privados

### `headcount_stats`

- `total`: todos los empleados de la BU (activos + inactivos).
- `activos`: `where(status: true)`.
- `inactivos`: `total - activos`.

### `rotacion_stats(year, range)`

Calcula altas, bajas y reingresos en el rango, más el promedio de plantilla.

**Promedio de plantilla**: headcount activo al inicio del año + headcount activo al fin del año, dividido entre 2. Calculado con `active_headcount_at` (ver abajo).

**Porcentaje de rotación**: `(bajas / promedio_plantilla) * 100`.

### `active_headcount_at(date, active_type_ids)`

**Método clave.** Determina cuántos empleados de la BU estaban activos en una fecha específica.

```ruby
EmployeeMovement
  .joins(:employee)
  .merge(Employee.business_unit_filter)
  .where(employee_movement_type_id: active_type_ids)
  .where('employee_movements.fecha_efectiva <= ?', date)
  .where('employee_movements.fecha_expiracion IS NULL OR employee_movements.fecha_expiracion > ?', date)
  .count('DISTINCT employee_movements.employee_id')
```

**Por qué no usar `Employee.where('created_at < ?', date).count`**: eso cuenta el total histórico acumulado (todos los empleados que alguna vez existieron), no la plantilla activa en esa fecha. En 2026, daría el total histórico desde la fundación de TTPN.

### `distribucion_por_area`

Empleados activos agrupados por `area`, ordenados por `COUNT(*) DESC`.

### `distribucion_por_puesto`

Empleados activos con join a `labors`, agrupados por `labors.nombre`.

### `antiguedad_promedio`

Promedio de días desde la primera Alta de cada empleado (vía `EmployeeMovement.minimum(:fecha_efectiva)` agrupado por `employee_id`).

### `documentos_stats`

Documentos de empleados de la BU: `vencidos` (vigencia < hoy) y `por_vencer_30_dias` (vigencia en próximos 30 días).

### `citas_stats(range)`

`EmployeeAppointment` en el rango dado, con `por_status` agrupado.

---

## Archivos relacionados

- `app/controllers/concerns/employee_stats_calculable.rb`
- `app/controllers/api/v1/employee_stats_controller.rb`
- `Documentacion/modelos/Employee.md` — sección "Indicadores derivados"
- `Documentacion/modelos/EmployeeMovement.md` — sección "Ciclo de vida (fecha_expiracion)"
