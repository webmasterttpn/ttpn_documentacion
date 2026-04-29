# Estadísticos del Módulo de Empleados

Explica de dónde viene cada KPI, cómo se calcula y cuál es la fuente de verdad. Actualizar este documento cada vez que cambie la lógica en `EmployeeStatsCalculable`.

---

## Fuente de verdad: EmployeeMovement

El estado activo/inactivo de un empleado nunca se determina por `Employee.status` ni por `Employee.created_at`. La fuente de verdad es `EmployeeMovement`.

| Campo | Significado |
| --- | --- |
| `fecha_efectiva` | Cuándo entró en vigor el movimiento (Alta, Baja, Reingreso) |
| `fecha_expiracion` | Cuándo fue cerrado por un movimiento posterior. `NULL` = vigente actualmente |

Un empleado es **activo** en una fecha D si tiene un movimiento tipo Alta o Reingreso donde:
- `fecha_efectiva <= D`
- `fecha_expiracion IS NULL OR fecha_expiracion > D`

---

## KPIs y cómo se calculan

### Headcount

| Indicador | Cómo | Archivo |
| --- | --- | --- |
| Total | `Employee.business_unit_filter.count` | — |
| Activos | `where(status: true)` | El campo `status` es reflejo del último movimiento |
| Inactivos | `total - activos` | — |

### Rotación del año

| Indicador | Cómo | Filtro de fecha |
| --- | --- | --- |
| Altas | `EmployeeMovement` tipo Alta | `fecha_efectiva IN rango_año` |
| Bajas | `EmployeeMovement` tipo Baja o Baja-LN | `fecha_efectiva IN rango_año` |
| Reingresos | `EmployeeMovement` tipo Reingreso | `fecha_efectiva IN rango_año` |

### Promedio de plantilla

```
promedio_plantilla = (headcount_activo_al_1_enero + headcount_activo_al_31_diciembre) / 2
```

**Cálculo de headcount activo en una fecha** → `EmployeeStatsCalculable#active_headcount_at`:

```ruby
EmployeeMovement
  .joins(:employee)
  .merge(Employee.business_unit_filter)
  .where(employee_movement_type_id: [alta_id, reingreso_id])
  .where('fecha_efectiva <= ?', date)
  .where('fecha_expiracion IS NULL OR fecha_expiracion > ?', date)
  .count('DISTINCT employee_movements.employee_id')
```

**Error histórico (corregido 2026-04-29):** antes se usaba `Employee.where('created_at < ?', date).count`, que retornaba el total histórico acumulado (~653 para 2026) en lugar de la plantilla activa real.

### Porcentaje de rotación

```
porcentaje_rotacion = (bajas / promedio_plantilla) * 100
```

### Antigüedad promedio

Promedio de días desde la primera Alta de cada empleado (no desde `created_at`). Se calcula con `EmployeeMovement.minimum(:fecha_efectiva)` agrupado por `employee_id`.

### Documentos

- **Vencidos**: `EmployeeDocument.vigencia < Date.current`
- **Por vencer**: `EmployeeDocument.vigencia IN (hoy..hoy+30)`
- Filtra por BU via join `Employee.business_unit_filter`

### Citas

- `EmployeeAppointment` en el rango de fechas pedido
- Agrupadas por `status` para `por_status`

---

## Archivo de implementación

`app/controllers/concerns/employee_stats_calculable.rb`

Ver también: [concerns/employee_stats_calculable.md](../concerns/employee_stats_calculable.md)

---

## Guía para pedir datos a la IA

Ver [ai-prompts.md](ai-prompts.md) — ejemplos de preguntas correctas y respuestas esperadas.
