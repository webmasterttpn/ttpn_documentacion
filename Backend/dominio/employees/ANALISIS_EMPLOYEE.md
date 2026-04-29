# 📊 Análisis Detallado - Modelo Employee

## 🔍 Estructura Actual

### Campos Principales

```ruby
- clv (string) - Clave única del empleado
- nombre (string) - Nombre
- apaterno (string) - Apellido paterno
- amaterno (string) - Apellido materno
- sexo (enum) - masculino/femenino
- estado_civil (enum) - casado/soltero/union libre
- area (enum) - administración/intendencia/operaciones/taller
- fecha_nacimiento (date)
- direccion (string)
- ciudad (string)
- status (boolean) - Activo/Inactivo
- password (string) - Para app móvil
- imei (string) - Identificador del dispositivo
- app_version (string) - Versión de app móvil
```

### Relaciones Identificadas

#### belongs_to (Nivel 1)

- `business_unit` (opcional) - Unidad de negocio
- `concessionaire` (opcional) - Concesionario
- `labor` (requerido) - Puesto/Labor

#### has_many (Nivel 2)

- `employee_documents` - Documentos del empleado
- `employee_movements` - Movimientos/cambios
- `employee_salaries` - Historial de salarios
- `employee_work_days` - Días laborales
- `employee_drivers_levels` - Niveles de conductor
- `vehicle_asignations` - Asignaciones de vehículos
- `employees_incidences` - Incidencias

#### has_one_attached

- `avatar` - Foto del empleado (ActiveStorage)

### Nested Attributes

Acepta atributos anidados para:

- employee_documents
- employee_movements
- employee_salaries
- employee_drivers_levels
- employee_work_days

---

## 🎯 Campos Críticos para API

### Esenciales (siempre incluir)

- id, clv, nombre, apaterno, amaterno
- status, area
- business_unit_id, labor_id

### Opcionales (según contexto)

- sexo, estado_civil, fecha_nacimiento
- direccion, ciudad
- concessionaire_id

### Sensibles (solo para admin)

- password, imei, app_version

### Relaciones (eager loading)

- business_unit
- labor
- concessionaire
- employee_documents (con tipos)
- employee_salaries (último salario)

---

## 📋 Endpoints Necesarios

### CRUD Básico

```
GET    /api/v1/employees           # Lista con filtros
GET    /api/v1/employees/:id       # Detalle completo
POST   /api/v1/employees           # Crear
PATCH  /api/v1/employees/:id       # Actualizar
DELETE /api/v1/employees/:id       # Eliminar
```

### Acciones Especiales

```
PATCH  /api/v1/employees/:id/activate    # Activar
PATCH  /api/v1/employees/:id/deactivate  # Desactivar
GET    /api/v1/employees/:id/documents   # Documentos
GET    /api/v1/employees/:id/salaries    # Historial salarial
GET    /api/v1/employees/:id/movements   # Movimientos
```

### Documentos

```
GET    /api/v1/employees/:employee_id/documents
POST   /api/v1/employees/:employee_id/documents
DELETE /api/v1/employees/:employee_id/documents/:id
```

---

## 🔧 Optimizaciones Necesarias

### 1. Scope de Business Unit

```ruby
scope :business_unit_filter, lambda {
  return all if Current.user&.role_id == 1
  return none unless Current.business_unit

  where(business_unit_id: Current.business_unit.id)
}
```

### 2. Eager Loading

```ruby
# En controlador
@employees = Employee
  .includes(:business_unit, :labor, :concessionaire)
  .includes(employee_documents: :employee_document_type)
  .includes(:employee_salaries)
  .business_unit_filter
```

### 3. Índices Necesarios

```ruby
add_index :employees, :clv, unique: true
add_index :employees, :business_unit_id
add_index :employees, :status
add_index :employees, [:business_unit_id, :status]
```

---

## 📊 Serializer Strategy

### Minimal (para listas)

```ruby
{
  id, clv, nombre_completo, area, status,
  business_unit: { id, nombre },
  labor: { id, nombre },
  avatar_url
}
```

### Full (para detalle)

```ruby
{
  ...minimal,
  sexo, estado_civil, fecha_nacimiento,
  direccion, ciudad,
  concessionaire: { id, nombre },
  employee_documents: [...],
  current_salary: {...},
  last_movement: {...}
}
```

---

## ⚠️ Problemas Identificados

1. **Scope `active` usa variable global** `$business_unit_id`

   - ❌ No es thread-safe
   - ✅ Cambiar a `Current.business_unit`

2. **Validaciones incompletas**

   - Falta validación de email (si se usa)
   - Falta validación de fecha_nacimiento

3. **Password en texto plano**

   - ⚠️ Debería usar `has_secure_password`
   - O separar autenticación de app móvil

4. **Nested attributes sin límites**
   - Podría causar problemas de performance
   - Agregar límites razonables

---

## 🚀 Plan de Acción Inmediato

### Paso 1: Crear Controlador Base

- [ ] Api::V1::EmployeesController
- [ ] Acciones CRUD básicas
- [ ] Filtros y búsqueda
- [ ] Paginación

### Paso 2: Serializer

- [ ] EmployeeSerializer con scopes
- [ ] Incluir relaciones principales
- [ ] Avatar URL helper

### Paso 3: Tests

- [ ] Factory para Employee
- [ ] Request specs básicos
- [ ] Model specs

### Paso 4: Documentos

- [ ] EmployeeDocumentsController
- [ ] Upload de archivos
- [ ] Validación de tipos

---

**Siguiente:** Implementar EmployeesController
