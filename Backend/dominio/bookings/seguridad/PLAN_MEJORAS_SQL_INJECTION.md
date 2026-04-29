# Plan de Mejoras: Prevención de SQL Injection en Helpers

**Fecha:** 2026-01-15  
**Prioridad:** 🔴 CRÍTICA  
**Riesgo Actual:** ALTO - Vulnerabilidad a SQL Injection

---

## 📋 Resumen Ejecutivo

### Situación Actual

✅ **Funciones PostgreSQL:** SEGURAS (usan parámetros posicionales)  
🔴 **Helpers de Ruby:** VULNERABLES (usan interpolación de strings)

### Helpers Afectados

| Helper             | Archivo                   | Parámetros Vulnerables    | Líneas |
| ------------------ | ------------------------- | ------------------------- | ------ |
| `obtener_empleado` | `ttpn_bookings_helper.rb` | `vehiculo`, `hora_actual` | 4-25   |
| `busca_en_travel`  | `ttpn_bookings_helper.rb` | 7 parámetros              | 27-36  |
| `buscar_destino`   | `ttpn_bookings_helper.rb` | `ttpn_service_id`         | 38-45  |
| `obtener_vehiculo` | `travel_counts_helper.rb` | `empleado`, `fecha_hora`  | 4-12   |
| `busca_en_booking` | `travel_counts_helper.rb` | 7 parámetros              | 22-32  |

**Total:** 5 helpers vulnerables, ~20 parámetros sin sanitizar

---

## 🔴 Vulnerabilidades Identificadas

### 1. Helper: `obtener_empleado`

**Código Actual (VULNERABLE):**

```ruby
def obtener_empleado(vehiculo, hora_actual)
  sql = "select em.id as employee_id
        from employees as em
        where em.id = COALESCE((select
                        CASE
                          WHEN '#{hora_actual}'::timestamp <= va.fecha_hasta THEN
                            va.employee_id
                          WHEN '#{hora_actual}'::timestamp >= va.fecha_hasta THEN
                            null
                          WHEN va.fecha_hasta is null THEN
                            va.employee_id
                        END as empleado
                    from vehicle_asignations as va
                    where va.id = (select asignacion(#{vehiculo}, to_timestamp('#{hora_actual}','YYYY-MM-DD HH24:MI')))
                    ),63);"

  @empleado = ActiveRecord::Base.connection.exec_query(sql).to_a.map(&:to_h)
end
```

**Vectores de Ataque:**

```ruby
# Ataque 1: Inyección en vehiculo
vehiculo = "1); DROP TABLE employees; --"
# SQL resultante: SELECT asignacion(1); DROP TABLE employees; --, ...)

# Ataque 2: Inyección en hora_actual
hora_actual = "2026-01-15 10:00'); DROP TABLE vehicle_asignations; --"
# SQL resultante: ...to_timestamp('2026-01-15 10:00'); DROP TABLE vehicle_asignations; --', ...)
```

---

### 2. Helper: `busca_en_travel`

**Código Actual (VULNERABLE):**

```ruby
def busca_en_travel(vehiculo, empleado, tst, tfd, cliente, fecha, hora)
  fecha_fin = "#{fecha} #{hora.strftime('%H:%M')}"
  fecha_inicio = fecha_fin.to_datetime - 15.minutes

  sql = "select buscar_travel_id(#{vehiculo}, #{empleado}, #{tst}, #{tfd}, #{cliente}, '#{fecha_inicio}', '#{fecha_fin}')"

  @viaje_encontrado = ActiveRecord::Base.connection.exec_query(sql)
end
```

**Vectores de Ataque:**

```ruby
# Cualquiera de los 7 parámetros puede ser inyectado
vehiculo = "1, 2, 3, 4, 5, '2026-01-15', '2026-01-15'); DROP TABLE travel_counts; --"
```

---

## ✅ Soluciones Propuestas

### Solución 1: Usar Parámetros Preparados (Recomendado)

**Ventajas:**

- ✅ Seguro contra SQL injection
- ✅ Cambio mínimo en la lógica
- ✅ Compatible con funciones PostgreSQL existentes

**Desventajas:**

- ⚠️ Sintaxis menos intuitiva
- ⚠️ Requiere refactorización de todos los helpers

**Implementación:**

```ruby
# ✅ SEGURO - Usando parámetros preparados
def obtener_empleado(vehiculo, hora_actual)
  sql = <<-SQL
    SELECT em.id as employee_id
    FROM employees as em
    WHERE em.id = COALESCE((
      SELECT CASE
        WHEN $2::timestamp <= va.fecha_hasta THEN va.employee_id
        WHEN $2::timestamp >= va.fecha_hasta THEN null
        WHEN va.fecha_hasta is null THEN va.employee_id
      END as empleado
      FROM vehicle_asignations as va
      WHERE va.id = (SELECT asignacion($1, to_timestamp($2, 'YYYY-MM-DD HH24:MI')))
    ), 63)
  SQL

  bindings = [
    [nil, vehiculo],
    [nil, hora_actual]
  ]

  ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings).to_a.map(&:to_h)
end
```

---

### Solución 2: Usar ActiveRecord y Arel (Más Seguro)

**Ventajas:**

- ✅ Máxima seguridad
- ✅ Más mantenible
- ✅ Mejor integración con Rails

**Desventajas:**

- ⚠️ Requiere mayor refactorización
- ⚠️ Puede ser más complejo para funciones PostgreSQL

**Implementación:**

```ruby
# ✅ MÁS SEGURO - Usando ActiveRecord
def obtener_empleado(vehiculo, hora_actual)
  # Llamar a la función PostgreSQL de forma segura
  asignacion_id = ActiveRecord::Base.connection.select_value(
    sanitize_sql_array([
      "SELECT asignacion(?, to_timestamp(?, 'YYYY-MM-DD HH24:MI'))",
      vehiculo,
      hora_actual
    ])
  )

  if asignacion_id
    # Obtener el employee_id de la asignación
    va = VehicleAsignation.find_by(id: asignacion_id)

    if va && (hora_actual.to_time <= va.fecha_hasta || va.fecha_hasta.nil?)
      Employee.where(id: va.employee_id).select(:id).first
    else
      Employee.where(clv: '00000').select(:id).first
    end
  else
    Employee.where(clv: '00000').select(:id).first
  end
end
```

---

### Solución 3: Crear Métodos de Modelo (Mejor Práctica)

**Ventajas:**

- ✅ Encapsulación de lógica
- ✅ Testeable
- ✅ Reutilizable
- ✅ Sigue principios SOLID

**Desventajas:**

- ⚠️ Requiere crear nuevos métodos en modelos
- ⚠️ Mayor refactorización inicial

**Implementación:**

```ruby
# app/models/vehicle_asignation.rb
class VehicleAsignation < ApplicationRecord
  # Método de clase para obtener asignación vigente
  def self.find_by_vehicle_and_time(vehicle_id, timestamp)
    sql = "SELECT id FROM vehicle_asignations WHERE id = asignacion(?, ?)"
    connection.select_value(sanitize_sql_array([sql, vehicle_id, timestamp]))
  end

  # Método de instancia para obtener el empleado
  def employee_at_time(timestamp)
    if timestamp.to_time <= fecha_hasta || fecha_hasta.nil?
      employee
    else
      nil
    end
  end
end

# app/models/employee.rb
class Employee < ApplicationRecord
  # Empleado por defecto cuando no hay asignación
  def self.default_employee
    find_by(clv: '00000')
  end
end

# app/helpers/ttpn_bookings_helper.rb
def obtener_empleado(vehiculo, hora_actual)
  asignacion_id = VehicleAsignation.find_by_vehicle_and_time(vehiculo, hora_actual)

  if asignacion_id
    va = VehicleAsignation.find(asignacion_id)
    employee = va.employee_at_time(hora_actual)
    employee || Employee.default_employee
  else
    Employee.default_employee
  end
end
```

---

### Solución 4: Usar Service Objects (Arquitectura Limpia)

**Ventajas:**

- ✅ Separación de responsabilidades
- ✅ Fácil de testear
- ✅ Reutilizable en controllers, jobs, etc.
- ✅ Mejor organización del código

**Implementación:**

```ruby
# app/services/vehicle_assignment_service.rb
class VehicleAssignmentService
  def initialize(vehicle_id, timestamp)
    @vehicle_id = vehicle_id
    @timestamp = timestamp
  end

  def find_employee
    asignacion_id = find_asignacion
    return Employee.default_employee unless asignacion_id

    asignacion = VehicleAsignation.find_by(id: asignacion_id)
    return Employee.default_employee unless asignacion

    asignacion.employee_at_time(@timestamp) || Employee.default_employee
  end

  private

  def find_asignacion
    sql = "SELECT asignacion(?, ?)"
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, @vehicle_id, @timestamp])
    )
  end
end

# Uso en el helper:
def obtener_empleado(vehiculo, hora_actual)
  service = VehicleAssignmentService.new(vehiculo, hora_actual)
  employee = service.find_employee
  [{ 'employee_id' => employee.id }]
end

# Uso en el modelo:
class TtpnBooking < ApplicationRecord
  before_validation :assign_employee

  private

  def assign_employee
    service = VehicleAssignmentService.new(vehicle_id, "#{fecha} #{hora}")
    self.employee_id = service.find_employee.id
  end
end
```

---

## 📝 Plan de Implementación

### Fase 1: Refactorización Crítica (Semana 1)

**Prioridad:** 🔴 CRÍTICA

1. **Refactorizar `obtener_empleado`**

   - [ ] Usar parámetros preparados
   - [ ] Agregar tests
   - [ ] Verificar en desarrollo
   - [ ] Desplegar a staging

2. **Refactorizar `busca_en_travel`**

   - [ ] Usar parámetros preparados
   - [ ] Agregar tests
   - [ ] Verificar en desarrollo
   - [ ] Desplegar a staging

3. **Refactorizar `buscar_destino`**
   - [ ] Usar parámetros preparados
   - [ ] Agregar tests

### Fase 2: Refactorización Completa (Semana 2)

**Prioridad:** 🟡 ALTA

4. **Refactorizar `obtener_vehiculo`**

   - [ ] Usar parámetros preparados
   - [ ] Agregar tests

5. **Refactorizar `busca_en_booking`**
   - [ ] Usar parámetros preparados
   - [ ] Agregar tests

### Fase 3: Mejoras Arquitectónicas (Semana 3-4)

**Prioridad:** 🟢 MEDIA

6. **Crear Service Objects**

   - [ ] `VehicleAssignmentService`
   - [ ] `TravelMatchingService`
   - [ ] `BookingMatchingService`

7. **Agregar Métodos a Modelos**

   - [ ] `VehicleAsignation.find_by_vehicle_and_time`
   - [ ] `VehicleAsignation#employee_at_time`
   - [ ] `Employee.default_employee`

8. **Refactorizar Callbacks**
   - [ ] Mover lógica de `extra_campos` a service
   - [ ] Mover lógica de `statuses` a service

---

## 🧪 Tests Requeridos

### Tests para Helpers Refactorizados

```ruby
# test/helpers/ttpn_bookings_helper_test.rb
require 'test_helper'

class TtpnBookingsHelperTest < ActionView::TestCase
  test "obtener_empleado with valid vehicle and time" do
    vehicle = create(:vehicle)
    employee = create(:employee)
    asignacion = create(:vehicle_asignation,
      vehicle: vehicle,
      employee: employee,
      fecha_efectiva: 1.day.ago,
      fecha_hasta: nil
    )

    result = obtener_empleado(vehicle.id, Time.current.to_s)

    assert_equal employee.id, result.first['employee_id']
  end

  test "obtener_empleado returns default employee when no asignacion" do
    default_employee = create(:employee, clv: '00000')
    vehicle = create(:vehicle)

    result = obtener_empleado(vehicle.id, Time.current.to_s)

    assert_equal default_employee.id, result.first['employee_id']
  end

  test "obtener_empleado is safe from SQL injection" do
    default_employee = create(:employee, clv: '00000')

    # Intentar inyección SQL
    malicious_input = "1); DROP TABLE employees; --"

    assert_nothing_raised do
      result = obtener_empleado(malicious_input, Time.current.to_s)
    end

    # Verificar que la tabla employees sigue existiendo
    assert Employee.count > 0
  end
end
```

---

## 📊 Checklist de Seguridad

### Antes de Desplegar

- [ ] Todos los helpers usan parámetros preparados
- [ ] No hay interpolación de strings en SQL
- [ ] Tests de seguridad pasan
- [ ] Tests de integración pasan
- [ ] Revisión de código completada
- [ ] Documentación actualizada

### Verificación en Staging

- [ ] Crear reserva funciona correctamente
- [ ] Actualizar reserva funciona correctamente
- [ ] Cuadre automático funciona
- [ ] No hay errores en logs
- [ ] Performance es aceptable

### Verificación en Producción

- [ ] Monitorear logs por 24 horas
- [ ] Verificar que no hay SQL injection attempts
- [ ] Verificar performance
- [ ] Rollback plan preparado

---

## 🎯 Código de Ejemplo Completo

### Helper Refactorizado: `ttpn_bookings_helper.rb`

```ruby
# frozen_string_literal: true

module TtpnBookingsHelper
  # ✅ SEGURO - Usando parámetros preparados
  def obtener_empleado(vehiculo, hora_actual)
    sql = <<-SQL
      SELECT em.id as employee_id
      FROM employees as em
      WHERE em.id = COALESCE((
        SELECT CASE
          WHEN $2::timestamp <= va.fecha_hasta THEN va.employee_id
          WHEN $2::timestamp >= va.fecha_hasta THEN null
          WHEN va.fecha_hasta is null THEN va.employee_id
        END as empleado
        FROM vehicle_asignations as va
        WHERE va.id = (SELECT asignacion($1, to_timestamp($2, 'YYYY-MM-DD HH24:MI')))
      ), 63)
    SQL

    bindings = [
      [nil, vehiculo],
      [nil, hora_actual]
    ]

    ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings).to_a.map(&:to_h)
  end

  # ✅ SEGURO - Usando parámetros preparados
  def busca_en_travel(vehiculo, empleado, tst, tfd, cliente, fecha, hora)
    fecha_fin = "#{fecha} #{hora.strftime('%H:%M')}"
    fecha_inicio = (fecha_fin.to_datetime - 15.minutes).to_s

    sql = "SELECT buscar_travel_id($1, $2, $3, $4, $5, $6::timestamp, $7::timestamp)"

    bindings = [
      [nil, vehiculo],
      [nil, empleado],
      [nil, tst],
      [nil, tfd],
      [nil, cliente],
      [nil, fecha_inicio],
      [nil, fecha_fin]
    ]

    ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings)
  end

  # ✅ SEGURO - Usando parámetros preparados
  def buscar_destino(ttpn_service_id)
    sql = <<-SQL
      SELECT tfd.id
      FROM ttpn_foreign_destinies as tfd,
           ttpn_services as ts
      WHERE ts.id = $1
        AND ts.ttpn_foreign_destiny_id = tfd.id
    SQL

    bindings = [[nil, ttpn_service_id]]

    ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings).to_a.map(&:to_h)
  end

  # Este método está bien, no usa SQL directo
  def importacion_servicios(file)
    Rails.logger.debug('Estoy en el helper')
    CSV.foreach(file.path, headers: true) do |info|
      Rails.logger.debug('importando registro')
      client_id = info[0]
      vehicle_id = info[6]
      Rails.logger.debug(client_id)
      Rails.logger.debug(vehicle_id)
      TtpnBooking.create(
        client_id: client_id,
        vehicle_id: vehicle_id
      )
    end
  end
end
```

---

## 📚 Recursos Adicionales

### Documentación

- [Rails Security Guide - SQL Injection](https://guides.rubyonrails.org/security.html#sql-injection)
- [PostgreSQL Prepared Statements](https://www.postgresql.org/docs/current/sql-prepare.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

### Herramientas de Análisis

- **Brakeman:** Escáner de seguridad para Rails
- **bundler-audit:** Verifica gemas con vulnerabilidades
- **RuboCop Security:** Reglas de seguridad para RuboCop

```bash
# Instalar herramientas
gem install brakeman bundler-audit

# Ejecutar análisis
brakeman -A -q
bundle audit check --update
```

---

## ✅ Conclusión

### Resumen de Acciones

1. ✅ **Documentadas** todas las funciones PostgreSQL
2. ✅ **Creadas** migraciones para versionar funciones
3. ✅ **Identificadas** vulnerabilidades de SQL injection
4. ✅ **Propuestas** 4 soluciones diferentes
5. ✅ **Definido** plan de implementación en 3 fases

### Próximos Pasos Inmediatos

1. 🔴 **Revisar y aprobar** este plan
2. 🔴 **Ejecutar migraciones** en desarrollo
3. 🔴 **Refactorizar** helpers críticos (Fase 1)
4. 🔴 **Agregar tests** de seguridad
5. 🔴 **Desplegar** a staging para pruebas

---

**Autor:** Antigravity AI  
**Fecha:** 2026-01-15  
**Versión:** 1.0
