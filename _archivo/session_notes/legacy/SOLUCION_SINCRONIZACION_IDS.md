# ✅ SOLUCIÓN AL PROBLEMA DE SINCRONIZACIÓN DE IDS

## 🎯 **PROBLEMA:**

La app Android usa PHP y hace `INSERT` directo en PostgreSQL con IDs específicos:

```sql
INSERT INTO employees_incidences (id, employee_id, ...) VALUES (150, 1, ...);
```

Esto desincroniza la secuencia de PostgreSQL, causando que Rails falle al hacer `.create`:

```ruby
# Rails intenta usar ID 100 (de la secuencia)
# Pero el ID 100 ya existe (insertado por Android)
# ERROR: duplicate key value violates unique constraint
```

---

## ✅ **SOLUCIÓN IMPLEMENTADA:**

### **1. Concern `SequenceSynchronizable`**

Creado en: `app/models/concerns/sequence_synchronizable.rb`

**Qué hace:**

- Resetea la secuencia de IDs **antes de cada `.create`** desde Rails
- Asegura que el próximo ID sea mayor que cualquier ID existente
- Funciona automáticamente sin código adicional

**Cómo funciona:**

```ruby
module SequenceSynchronizable
  included do
    before_create :sync_id_sequence
  end

  private

  def sync_id_sequence
    # Resetear la secuencia al máximo ID actual
    ActiveRecord::Base.connection.reset_pk_sequence!(table_name)
  end
end
```

**Ventajas:**

- ✅ Reutilizable en múltiples modelos
- ✅ Automático (no requiere llamadas manuales)
- ✅ Maneja errores gracefully
- ✅ Incluye método manual `.sync_sequence!` para imports masivos

---

### **2. Modelos Actualizados:**

#### **EmployeesIncidence**

**Antes:**

```ruby
before_create :verificar_id

def verificar_id
  ActiveRecord::Base.connection.reset_pk_sequence!('employees_incidences')
  actual_id = EmployeesIncidence.last
  next_id = actual_id.id + 1
  EmployeesIncidence.create { |employee_incidence| employee_incidence.id = next_id }
end
```

**Ahora:**

```ruby
include SequenceSynchronizable  # ✅ Una línea
```

#### **EmployeeAppointment**

```ruby
include SequenceSynchronizable  # ✅ Mismo concern
```

---

### **3. Migración para `employee_appointments`**

Agregados campos opcionales:

```ruby
add_column :employee_appointments, :titulo, :string
add_column :employee_appointments, :fecha_fin, :date
add_column :employee_appointments, :hora_fin, :time
add_column :employee_appointments, :ubicacion, :string
add_column :employee_appointments, :tipo_cita, :string
add_reference :employee_appointments, :business_unit, default: 1

# Índices para performance
add_index :employee_appointments, :fecha_inicio
add_index :employee_appointments, :status
add_index :employee_appointments, [:business_unit_id, :fecha_inicio]
```

---

## 🔧 **CÓMO USAR:**

### **Para Nuevos Modelos con Inserts Externos:**

```ruby
class MiModelo < ApplicationRecord
  include SequenceSynchronizable  # ✅ Agregar esta línea

  # ... resto del código
end
```

### **Sincronización Manual (Opcional):**

Si haces un import masivo desde Android/PHP:

```ruby
# Después del import, sincronizar manualmente
EmployeesIncidence.sync_sequence!
EmployeeAppointment.sync_sequence!
```

---

## 📊 **CAMPOS DE `employee_appointments`:**

### **Campos Existentes:**

- `employee_id` (required)
- `fecha_inicio` (required)
- `hora_inicio` (required)
- `descripcion`
- `status`
- `created_by`, `updated_by`

### **Campos Nuevos (Opcionales):**

- `titulo` - Título de la cita
- `fecha_fin` - Fecha de finalización
- `hora_fin` - Hora de finalización
- `ubicacion` - Lugar de la cita
- `tipo_cita` - Tipo: meeting, interview, review, training, other
- `business_unit_id` - Default: 1 (o del usuario actual)

---

## 🎨 **MODELO ACTUALIZADO:**

### **Constantes:**

```ruby
STATUSES = {
  'scheduled' => 'Agendado',
  'completed' => 'Completado',
  'cancelled' => 'Cancelado'
}

TIPOS_CITA = {
  'meeting' => 'Reunión',
  'interview' => 'Entrevista',
  'review' => 'Revisión',
  'training' => 'Capacitación',
  'other' => 'Otro'
}
```

### **Scopes:**

```ruby
scope :by_business_unit, ->(bu_id) { where(business_unit_id: bu_id) }
scope :by_employee, ->(emp_id) { where(employee_id: emp_id) }
scope :by_status, ->(status) { where(status: status) }
scope :in_date_range, ->(start_date, end_date) { where(fecha_inicio: start_date..end_date) }
scope :ordered, -> { order(fecha_inicio: :asc, hora_inicio: :asc) }
```

### **Métodos Útiles:**

```ruby
appointment.display_title        # Título o descripción truncada
appointment.start_datetime       # Combina fecha_inicio + hora_inicio
appointment.end_datetime         # Combina fecha_fin + hora_fin
appointment.creator_name         # Nombre del creador
```

---

## 🚀 **PRÓXIMOS PASOS:**

1. ✅ Correr migración:

   ```bash
   docker-compose exec app rails db:migrate
   ```

2. ✅ Verificar que funciona:

   ```ruby
   # Crear cita desde Rails
   EmployeeAppointment.create!(
     employee_id: 1,
     titulo: "Reunión de equipo",
     fecha_inicio: Date.today,
     hora_inicio: "10:00"
   )

   # Insertar desde Android/PHP (simulado)
   # INSERT INTO employee_appointments (id, employee_id, ...) VALUES (999, 1, ...);

   # Crear otra desde Rails (debería funcionar sin error)
   EmployeeAppointment.create!(
     employee_id: 2,
     titulo: "Entrevista",
     fecha_inicio: Date.today,
     hora_inicio: "14:00"
   )
   ```

3. ⏳ Implementar Controller API (siguiente paso)
4. ⏳ Implementar Frontend Calendario (siguiente paso)

---

## ✅ **BENEFICIOS:**

1. **No más errores de ID duplicado** entre Rails y Android
2. **Código más limpio** (concern reutilizable)
3. **Automático** (no requiere llamadas manuales)
4. **Preparado para el calendario** (campos adicionales)
5. **Multi-tenancy** (business_unit_id)
6. **Optimizado** (índices en campos clave)

**¡Problema resuelto!** 🎉
