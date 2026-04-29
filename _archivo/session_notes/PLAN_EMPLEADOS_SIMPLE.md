# 🎯 Plan de Acción - Módulo de Empleados (SIN UUID)

## ✅ Decisión: Mantener IDs Consecutivos

Por ahora mantendremos los IDs consecutivos actuales. La migración a UUID queda como proyecto futuro cuando el sistema esté más maduro y estable.

---

## 📋 Plan Simplificado

### Fase 1: Backend API (Prioridad ALTA)

#### 1.1 Controlador Principal

**Archivo:** `app/controllers/api/v1/employees_controller.rb`

**Acciones:**

- [x] Index (lista con filtros y búsqueda)
- [x] Show (detalle completo con relaciones)
- [x] Create (con nested attributes)
- [x] Update (con nested attributes)
- [x] Destroy
- [x] Activate/Deactivate (acciones custom)

**Estimado:** 2-3 horas

#### 1.2 Serializer

**Archivo:** `app/serializers/employee_serializer.rb`

**Scopes:**

- `minimal` - Para listas (id, nombre, puesto, status)
- `full` - Para detalle (todo + relaciones)

**Incluir:**

- business_unit
- labor (puesto)
- concessionaire
- employee_documents (opcional)
- current_salary (método calculado)
- avatar_url (ActiveStorage)

**Estimado:** 1-2 horas

#### 1.3 Controladores Secundarios

**Archivos:**

- `app/controllers/api/v1/employee_documents_controller.rb`
- `app/controllers/api/v1/employee_salaries_controller.rb`

**Estimado:** 2-3 horas

---

### Fase 2: Frontend (Prioridad ALTA)

#### 2.1 Página Principal

**Archivo:** `src/pages/EmployeesPage.vue`

**Características:**

- Tabla responsive (grid en móvil)
- Búsqueda y filtros
- Dialog con tabs:
  - General (datos personales)
  - Documentos (nested forms)
  - Salarios (nested forms)
  - Movimientos (nested forms)

**Patrón:** Igual que VehiclesPage.vue

**Estimado:** 4-5 horas

#### 2.2 Componentes Auxiliares (Opcional)

- EmployeeCard.vue
- EmployeeFilters.vue

**Estimado:** 1-2 horas

---

### Fase 3: Tests (Prioridad MEDIA)

#### 3.1 Backend

- [ ] Factory para Employee
- [ ] Model specs básicos
- [ ] Request specs para EmployeesController

**Estimado:** 2-3 horas

#### 3.2 Frontend

- [ ] Tests E2E básicos (opcional)

**Estimado:** 1-2 horas

---

## 🚀 Orden de Implementación

### Día 1: Backend Base

1. ✅ Crear EmployeesController
2. ✅ Crear EmployeeSerializer
3. ✅ Probar endpoints con Postman/Swagger
4. ✅ Ajustar modelo Employee (scope business_unit_filter)

### Día 2: Frontend Base

1. ✅ Crear EmployeesPage.vue
2. ✅ Implementar tabla y búsqueda
3. ✅ Crear dialog con tab General
4. ✅ CRUD básico funcionando

### Día 3: Nested Forms

1. ✅ Tab de Documentos con nested forms
2. ✅ Tab de Salarios con nested forms
3. ✅ Upload de archivos
4. ✅ Validaciones

### Día 4: Pulido y Tests

1. ✅ Tests backend
2. ✅ Responsive design
3. ✅ Documentación
4. ✅ Deploy a staging

---

## 📊 Estimación Total

| Fase        | Tiempo          |
| ----------- | --------------- |
| Backend API | 5-8 horas       |
| Frontend    | 5-7 horas       |
| Tests       | 3-5 horas       |
| **TOTAL**   | **13-20 horas** |

**Tiempo real estimado:** 2-3 días de trabajo efectivo

---

## 🎯 Entregables

### Mínimo Viable (MVP)

- ✅ CRUD de empleados
- ✅ Búsqueda y filtros básicos
- ✅ Gestión de documentos
- ✅ Responsive design

### Deseable

- ✅ Gestión de salarios
- ✅ Gestión de movimientos
- ✅ Upload de fotos
- ✅ Tests > 70%

### Futuro

- 📅 Gestión de vacaciones
- 📅 Asignación de vehículos
- 📅 Reportes y estadísticas
- 📅 Migración a UUID (cuando sea necesario)

---

## ⚠️ Consideraciones Importantes

### 1. Scope de Business Unit

```ruby
# Actualizar en app/models/employee.rb
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

### 3. Nested Attributes

```ruby
# Ya existe en el modelo, solo asegurar que funcione
accepts_nested_attributes_for :employee_documents,
  allow_destroy: true,
  reject_if: proc { |att| att['employee_document_type_id'].blank? }
```

---

## 📝 Checklist de Inicio

- [ ] Revisar modelo Employee actual
- [ ] Crear EmployeesController base
- [ ] Crear EmployeeSerializer
- [ ] Probar endpoints
- [ ] Crear EmployeesPage.vue
- [ ] Implementar CRUD básico
- [ ] Agregar nested forms
- [ ] Tests básicos

---

## 🎓 Aprendizajes del Módulo de Vehículos

**Aplicar:**

- ✅ Patrón de tabs para organización
- ✅ Nested forms dinámicas
- ✅ Upload de archivos después de crear
- ✅ Validaciones visuales en tabs
- ✅ Responsive con :grid
- ✅ Estados vacíos informativos

**Evitar:**

- ❌ Cargar todas las relaciones siempre
- ❌ No validar antes de guardar
- ❌ Formularios muy largos sin tabs
- ❌ No manejar estados de loading

---

## 🚀 Próximo Paso Inmediato

**Empezar con:** Crear `app/controllers/api/v1/employees_controller.rb`

**Referencia:** `app/controllers/api/v1/vehicles_controller.rb`

---

**Última actualización:** 2025-12-18  
**Decisión:** Mantener IDs consecutivos (sin UUID)  
**Prioridad:** ALTA  
**Estimado:** 2-3 días
