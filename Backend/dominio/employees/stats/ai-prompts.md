# Guía: Cómo pedir datos de empleados a la IA

Reglas de comportamiento para la IA cuando un usuario hace preguntas sobre el módulo de empleados.

---

## Antes de responder cualquier pregunta: verificar privilegios

El usuario solo puede preguntar sobre un módulo si tiene `can_access: true` en el `module_key` correspondiente.

```ruby
# En el controller (siempre presente vía Pundit o before_action)
privileges = current_user.build_privileges
unless privileges.dig('employees', :can_access)
  render json: { error: 'No tienes acceso al módulo de Empleados' }, status: :forbidden
end
```

Si el usuario no tiene acceso, la IA debe responder:

> "No tienes acceso al módulo de Empleados. Contacta a tu administrador para solicitar acceso."

No dar ningún dato parcial ni explicar cómo obtenerlo. Sin acceso → sin respuesta.

---

## Dos premisas que aplican a TODOS los stats de empleados

### 1. La BU siempre es implícita

Cada usuario tiene un `business_unit_id`. El sistema lo carga en `Current.business_unit` al autenticar la request. **Nunca hay que especificar la BU al hacer una pregunta** — está implícita en el contexto del usuario.

Preguntas como "¿Cuál es el promedio de plantilla de 2026?" o "¿Cuántos documentos vencidos hay?" son correctas tal cual. La BU no se menciona porque ya está en el contexto.

Lo que la IA sí debe saber: `Employee.business_unit_filter` aplica ese filtro automáticamente. No necesita recibir un `business_unit_id` explícito — solo usar ese scope.

### 2. Los stats solo consideran empleados activos

Cualquier indicador (documentos vencidos, antigüedad, distribución por área, distribución por puesto) aplica **únicamente sobre empleados con `status: true`**. Un empleado dado de baja no es relevante para ningún KPI operativo.

```ruby
# Base correcta para stats de documentos, antigüedad, distribución
base_activos = Employee.business_unit_filter.where(status: true)

# Documentos: solo de empleados activos
EmployeeDocument.joins(:employee).merge(base_activos)

# Antigüedad: solo empleados activos
EmployeeMovement
  .joins(:employee)
  .merge(base_activos)
  .where(employee_movement_type_id: alta_ids)
  ...
```

La excepción son los stats de **rotación** (altas, bajas, reingresos del año) — ahí sí se cuentan movimientos de empleados que ya no están activos, porque las bajas mismas son el dato que interesa.

---

## Contexto técnico para sesiones nuevas

Si la conversación arranca sin contexto del proyecto, incluir este bloque:

```text
- Estado activo/inactivo: EmployeeMovement (fecha_efectiva, fecha_expiracion), no Employee.status ni created_at
- fecha_expiracion NULL = movimiento vigente
- Tipos de movimiento: Alta (única por empleado), Baja, Baja-Lista Negra, Reingreso
- EmployeeMovementType.alta_id / baja_id / reingreso_id / baja_lista_negra_id (memoizados)
- BU implícita: Employee.business_unit_filter usa Current.business_unit automáticamente
- Stats = solo empleados activos (status: true), excepto rotación
```

---

## Preguntas y respuestas de referencia

### "¿Cuál es el promedio de plantilla de 2026?"

Válida tal cual. La BU es implícita.

**Respuesta correcta:**

```ruby
active_type_ids = [EmployeeMovementType.alta_id, EmployeeMovementType.reingreso_id]
inicio = active_headcount_at(Date.new(2026, 1, 1),  active_type_ids)
fin    = active_headcount_at(Date.new(2026, 12, 31), active_type_ids)
((inicio + fin) / 2.0).round(1)

# Donde active_headcount_at filtra por BU via Employee.business_unit_filter:
def active_headcount_at(date, type_ids)
  EmployeeMovement
    .joins(:employee).merge(Employee.business_unit_filter)
    .where(employee_movement_type_id: type_ids)
    .where('fecha_efectiva <= ?', date)
    .where('fecha_expiracion IS NULL OR fecha_expiracion > ?', date)
    .count('DISTINCT employee_movements.employee_id')
end
```

---

### "¿Cuántos documentos vencidos hay?"

Válida. Solo aplica a empleados activos.

**Respuesta correcta:**

```ruby
hoy     = Date.current
proximo = hoy + 30.days
base    = EmployeeDocument
            .joins(:employee)
            .merge(Employee.business_unit_filter.where(status: true))  # ← solo activos

vencidos   = base.where('vigencia < ?', hoy).count
por_vencer = base.where(vigencia: hoy..proximo).count
```

---

### "¿Cuál es la antigüedad promedio?"

Válida. Solo empleados activos.

**Respuesta correcta:**

```ruby
alta_ids = EmployeeMovementType.where(nombre: 'Alta').pluck(:id)

first_altas = EmployeeMovement
                .joins(:employee)
                .merge(Employee.business_unit_filter.where(status: true))  # ← solo activos
                .where(employee_movement_type_id: alta_ids)
                .where.not(fecha_efectiva: nil)
                .group(:employee_id)
                .minimum(:fecha_efectiva)
                .values.compact

total_days = first_altas.sum { |date| (Date.current - date.to_date).to_i }
(total_days / first_altas.size.to_f).round
```

---

### "¿Cuántas altas y bajas hubo en 2026?"

Válida. Rotación sí incluye movimientos de empleados ya dados de baja.

**Respuesta correcta:**

```ruby
range     = Date.new(2026, 1, 1)..Date.new(2026, 12, 31)
alta_ids  = [EmployeeMovementType.alta_id]
baja_ids  = [EmployeeMovementType.baja_id, EmployeeMovementType.baja_lista_negra_id]
reing_ids = [EmployeeMovementType.reingreso_id]

# No se filtra por status: true aquí — la baja en sí es el dato
altas      = EmployeeMovement.joins(:employee).merge(Employee.business_unit_filter)
                             .where(employee_movement_type_id: alta_ids,  fecha_efectiva: range).count
bajas      = EmployeeMovement.joins(:employee).merge(Employee.business_unit_filter)
                             .where(employee_movement_type_id: baja_ids,  fecha_efectiva: range).count
reingresos = EmployeeMovement.joins(:employee).merge(Employee.business_unit_filter)
                             .where(employee_movement_type_id: reing_ids, fecha_efectiva: range).count
```

---

### "¿Cómo está distribuida la plantilla por área?"

Válida. Solo activos.

**Respuesta correcta:**

```ruby
Employee.business_unit_filter
        .where(status: true)
        .where.not(area: [nil, ''])
        .group(:area)
        .order(Arel.sql('COUNT(*) DESC'))
        .count
        .map { |area, total| { area: area, total: total } }
```

---

## Señales de alerta en una respuesta

| Señal | Problema |
| --- | --- |
| `Employee.where('created_at < ?', ...)` para headcount histórico | Total acumulado, no activos en esa fecha |
| `Employee.count` o queries sin `.business_unit_filter` | Mezcla todas las BU |
| `EmployeeDocument` sin filtrar por `status: true` | Incluye documentos de empleados inactivos |
| `EmployeeMovement` para antigüedad sin filtrar activos | Promedia empleados que ya no trabajan |
| Promedio de plantilla > 200 para BU pequeña | Probablemente usando `created_at` histórico |

---

## Template de pregunta rápida

```text
[Si sesión nueva — pegar contexto técnico de arriba]

Pregunta: ¿[lo que quiero saber]?

Recordatorios automáticos:
- BU implícita (no especificar)
- Solo empleados activos (status: true), excepto en stats de rotación
- Verificar que el usuario tiene acceso al módulo antes de responder
```
