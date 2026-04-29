# 🚀 Plan de Implementación - Módulo de Empleados

## ⚠️ IMPORTANTE: SIN UUID

Este plan NO incluye migración a UUID. Mantenemos IDs consecutivos actuales.  
**Razón:** Evitar riesgos innecesarios al sistema en producción.

---

## 🎯 Objetivo

Migrar el módulo de Empleados al nuevo patrón API V1 con frontend moderno, siguiendo el mismo patrón exitoso de Vehículos.

---

## 📋 Alcance del Proyecto

### ✅ Incluido

- CRUD completo de empleados
- Gestión de documentos (nested forms)
- Gestión de salarios (nested forms)
- Gestión de movimientos (nested forms)
- Upload de archivos
- Búsqueda y filtros
- Responsive design (PWA)
- Tests básicos

### ❌ NO Incluido (Futuro)

- Migración a UUID
- Gestión de vacaciones (fase 2)
- Asignación de vehículos (fase 2)
- Reportes avanzados (fase 2)
- Integración con nómina (fase 2)

---

## 📊 Fases de Implementación

### Fase 1: Backend API (5-8 horas)

#### 1.1 Controlador Principal

**Archivo:** `app/controllers/api/v1/employees_controller.rb`

```ruby
class Api::V1::EmployeesController < Api::V1::BaseController
  before_action :set_employee, only: [:show, :update, :destroy, :activate, :deactivate]

  def index
    @employees = Employee
      .includes(:business_unit, :labor, :concessionaire)
      .includes(employee_documents: :employee_document_type)
      .includes(:employee_salaries)
      .business_unit_filter
      .order(created_at: :desc)

    render json: @employees, each_serializer: EmployeeSerializer, scope: :minimal
  end

  def show
    render json: @employee, serializer: EmployeeSerializer, scope: :full
  end

  def create
    @employee = Employee.new(employee_params)
    if @employee.save
      render json: @employee, status: :created
    else
      render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @employee.update(employee_params)
      render json: @employee
    else
      render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy
    head :no_content
  end

  def activate
    @employee.update(status: true)
    render json: @employee
  end

  def deactivate
    @employee.update(status: false)
    render json: @employee
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(
      :clv, :nombre, :apaterno, :amaterno,
      :sexo, :estado_civil, :area, :fecha_nacimiento,
      :direccion, :ciudad, :status,
      :labor_id, :business_unit_id, :concessionaire_id,
      employee_documents_attributes: [
        :id, :employee_document_type_id, :numero, :expiracion, :descripcion, :_destroy
      ],
      employee_salaries_attributes: [
        :id, :sdi, :sueldo_diario, :fecha_inicio, :_destroy
      ],
      employee_movements_attributes: [
        :id, :employee_movement_type_id, :fecha, :descripcion, :_destroy
      ]
    )
  end
end
```

**Rutas:**

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :employees do
      member do
        patch :activate
        patch :deactivate
      end
    end
  end
end
```

#### 1.2 Serializer

**Archivo:** `app/serializers/employee_serializer.rb`

```ruby
class EmployeeSerializer < ActiveModel::Serializer
  attributes :id, :clv, :nombre_completo, :nombre, :apaterno, :amaterno,
             :sexo, :estado_civil, :area, :fecha_nacimiento,
             :direccion, :ciudad, :status, :created_at, :updated_at

  belongs_to :business_unit, if: -> { scope != :minimal }
  belongs_to :labor
  belongs_to :concessionaire, if: -> { scope == :full }

  has_many :employee_documents, if: -> { scope == :full }
  has_many :employee_salaries, if: -> { scope == :full }

  def nombre_completo
    "#{object.nombre} #{object.apaterno} #{object.amaterno}".strip
  end

  def current_salary
    object.employee_salaries.order(created_at: :desc).first&.sueldo_diario
  end

  def avatar_url
    return nil unless object.avatar.attached?
    Rails.application.routes.url_helpers.rails_blob_url(object.avatar, only_path: true)
  end
end
```

#### 1.3 Actualizar Modelo

**Archivo:** `app/models/employee.rb`

```ruby
# Cambiar scope global por business_unit_filter
scope :business_unit_filter, lambda {
  return all if Current.user&.role_id == 1
  return none unless Current.business_unit

  where(business_unit_id: Current.business_unit.id)
}

# Eliminar scope :active que usa variable global
# scope :active, -> { where(business_unit_id: $business_unit_id) }
```

---

### Fase 2: Frontend (5-7 horas)

#### 2.1 Página Principal

**Archivo:** `src/pages/EmployeesPage.vue`

**Estructura:**

```vue
<template>
  <q-page class="q-pa-md">
    <!-- Tabla con búsqueda -->
    <q-table
      title="Empleados"
      :rows="rows"
      :columns="columns"
      :grid="$q.screen.lt.md"
      :filter="search"
    >
      <!-- Vista tabla (desktop) -->
      <!-- Vista cards (móvil) -->
    </q-table>
        </q-toolbar>

        <!-- Tabs -->
        <q-tabs v-model="tab">
          <q-tab name="general" label="Datos Generales" icon="person" />
          <q-tab name="docs" label="Documentos" icon="folder" />
          <q-tab name="salaries" label="Salarios" icon="payments" />
          <q-tab name="movements" label="Movimientos" icon="swap_horiz" />
        </q-tabs>

        <!-- Tab Panels -->
        <q-tab-panels v-model="tab">
          <!-- General -->
          <q-tab-panel name="general">
            <!-- Formulario de datos personales -->
          </q-tab-panel>

          <!-- Documentos (nested forms) -->
          <q-tab-panel name="docs">
            <!-- Igual que VehiclesPage -->
          </q-tab-panel>

          <!-- Salarios (nested forms) -->
          <q-tab-panel name="salaries">
            <!-- Igual que VehiclesPage -->
          </q-tab-panel>

          <!-- Movimientos (nested forms) -->
          <q-tab-panel name="movements">
            <!-- Igual que VehiclesPage -->
          </q-tab-panel>
        </q-tab-panels>

        <!-- Botones -->
        <q-card-actions>
          <q-btn label="Cancelar" v-close-popup />
          <q-btn label="Guardar Todo" @click="saveEmployee" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>
```

**Referencia:** `src/pages/VehiclesPage.vue` (copiar patrón exacto)

---

### Fase 3: Catálogos en Settings (2-3 horas)

Agregar a `src/pages/SettingsPage.vue`:

```vue
<!-- Catálogos de Empleados -->
<q-item-label header>Catálogos de Empleados</q-item-label>

<q-tab name="employee_doc_types" label="Tipos de Documentos" />
<q-tab name="employee_movement_types" label="Tipos de Movimientos" />
<q-tab name="labors" label="Puestos" />
<q-tab name="drivers_levels" label="Niveles de Conductor" />
```

Cada catálogo usa el mismo componente reutilizable.

---

### Fase 4: Tests (3-5 horas)

#### Backend

```ruby
# spec/factories/employees.rb
FactoryBot.define do
  factory :employee do
    sequence(:clv) { |n| "EMP-#{n.to_s.rjust(4, '0')}" }
    nombre { Faker::Name.first_name }
    apaterno { Faker::Name.last_name }
    amaterno { Faker::Name.last_name }
    status { true }
    association :labor
    association :business_unit
  end
end

# spec/requests/api/v1/employees_spec.rb
# spec/models/employee_spec.rb
```

---

## 📅 Cronograma

| Día | Tareas                                   | Horas |
| --- | ---------------------------------------- | ----- |
| 1   | Backend: Controller + Serializer + Tests | 6-8h  |
| 2   | Frontend: EmployeesPage + Tab General    | 4-5h  |
| 3   | Frontend: Nested Forms (Docs, Salarios)  | 4-5h  |
| 4   | Catálogos + Pulido + Tests               | 3-4h  |

**Total:** 17-22 horas (3-4 días)

---

## ✅ Checklist de Implementación

### Backend

- [ ] Crear `EmployeesController`
- [ ] Crear `EmployeeSerializer`
- [ ] Actualizar scope en modelo `Employee`
- [ ] Agregar rutas
- [ ] Probar con Postman/Swagger
- [ ] Tests de request
- [ ] Tests de modelo

### Frontend

- [ ] Crear `EmployeesPage.vue`
- [ ] Implementar tabla responsive
- [ ] Dialog con tab General
- [ ] Tab de Documentos (nested)
- [ ] Tab de Salarios (nested)
- [ ] Tab de Movimientos (nested)
- [ ] Upload de avatar
- [ ] Búsqueda y filtros

### Catálogos

- [ ] Employee Document Types
- [ ] Employee Movement Types
- [ ] Labors
- [ ] Drivers Levels

### Documentación

- [ ] Actualizar README
- [ ] Documentar endpoints
- [ ] Guía de uso

---

## 🎯 Criterios de Éxito

- ✅ CRUD completo funcionando
- ✅ Nested forms guardando correctamente
- ✅ Responsive en móvil
- ✅ Tests > 70% coverage
- ✅ Sin errores de ESLint
- ✅ Performance similar a Vehículos

---

## ⚠️ Riesgos y Mitigaciones

| Riesgo                       | Mitigación                                |
| ---------------------------- | ----------------------------------------- |
| Nested attributes no guardan | Verificar `accepts_nested_attributes_for` |
| Performance lenta            | Eager loading correcto                    |
| Scope no filtra bien         | Probar con diferentes business_units      |
| Upload falla                 | Verificar ActiveStorage configurado       |

---

## 📚 Referencias

- ✅ `app/controllers/api/v1/vehicles_controller.rb`
- ✅ `src/pages/VehiclesPage.vue`
- ✅ `documentacion/PATRON_TABS_NESTED_FORMS.md`
- ✅ `documentacion/ORGANIZACION_MENUS.md`

---

## 🚫 LO QUE NO SE HARÁ

- ❌ Migración a UUID
- ❌ Cambios en estructura de base de datos
- ❌ Módulos de vacaciones (fase 2)
- ❌ Integración con nómina (fase 2)

---

**Última actualización:** 2025-12-18  
**Estado:** Listo para implementar  
**Prioridad:** ALTA  
**Riesgo:** BAJO (sin cambios estructurales)
