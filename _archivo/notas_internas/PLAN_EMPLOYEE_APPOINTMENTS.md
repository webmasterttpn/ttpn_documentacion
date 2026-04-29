# 📅 SISTEMA DE CITAS DE EMPLEADOS - PLAN DE IMPLEMENTACIÓN

## 🎯 **OBJETIVO:**

Crear un calendario de citas para empleados con vistas Diaria, Semanal y Mensual, con lazy loading y diseño responsive basado en el ejemplo HTML proporcionado.

---

## 🏗️ **ARQUITECTURA DECIDIDA:**

### **✅ Una Sola Página con Componentes**

**Razones:**

- Compartir estado entre vistas (fecha, filtros, empleados)
- Evitar duplicación de código
- Transiciones suaves
- Mejor UX y mantenibilidad

### **Estructura de Archivos:**

```
Frontend:
pages/
  EmployeeAppointments/
    EmployeeAppointmentsPage.vue          # Contenedor principal
    components/
      CalendarHeader.vue                   # Header con navegación y botones
      MiniCalendar.vue                     # Calendario pequeño lateral
      EmployeeFilter.vue                   # Filtros de empleados
      StatusFilter.vue                     # Filtros de estado
      DayView.vue                          # Vista diaria
      WeekView.vue                         # Vista semanal
      MonthView.vue                        # Vista mensual
      AppointmentCard.vue                  # Tarjeta de cita
      AppointmentDialog.vue                # Modal crear/editar cita

Backend:
models/
  employee_appointment.rb
controllers/
  api/v1/employee_appointments_controller.rb
serializers/
  employee_appointment_serializer.rb
```

---

## 📊 **BACKEND:**

### **1. Modelo `EmployeeAppointment`**

```ruby
# Campos:
- employee_id (FK)
- business_unit_id (FK)
- title (string, required)
- description (text)
- start_time (datetime, required)
- end_time (datetime, required)
- status (string: scheduled, completed, cancelled)
- location (string)
- appointment_type (string: meeting, interview, review, training, other)
- created_by_id (FK)
- updated_by_id (FK)

# Índices:
- start_time
- end_time
- status
- [business_unit_id, start_time] (compuesto)
```

### **2. Controller `EmployeeAppointmentsController`**

**Endpoints:**

```ruby
GET    /api/v1/employee_appointments          # Lista con filtros
GET    /api/v1/employee_appointments/:id      # Detalle
POST   /api/v1/employee_appointments          # Crear
PATCH  /api/v1/employee_appointments/:id      # Actualizar
DELETE /api/v1/employee_appointments/:id      # Eliminar

# Filtros soportados:
?start_date=2025-10-27
?end_date=2025-10-27
?employee_id=123
?status=scheduled
?view=day|week|month
```

**Lazy Loading:**

- Solo cargar citas del rango de fechas visible
- Día: 1 día
- Semana: 7 días
- Mes: 1 mes

### **3. Serializer**

```ruby
{
  id, title, description,
  start_time, end_time,
  status, location, appointment_type,
  employee: { id, nombre, avatar_url },
  created_at, updated_at
}
```

---

## 🎨 **FRONTEND:**

### **1. EmployeeAppointmentsPage.vue (Contenedor)**

**Responsabilidades:**

- Gestionar estado global (fecha, vista, filtros)
- Lazy loading de datos según vista activa
- Renderizar componente de vista activa

**Estado:**

```javascript
const currentView = ref("day"); // day, week, month
const selectedDate = ref(new Date());
const appointments = ref([]);
const employees = ref([]);
const selectedEmployees = ref([]);
const selectedStatuses = ref(["scheduled", "completed"]);
const loading = ref(false);
```

**Lazy Loading:**

```javascript
watch([currentView, selectedDate], async () => {
  const range = getDateRange(currentView.value, selectedDate.value);
  await loadAppointments(range.start, range.end);
});
```

### **2. Vistas (DayView, WeekView, MonthView)**

#### **DayView.vue**

- Grid de horas (8 AM - 8 PM)
- Citas posicionadas absolutamente
- Línea roja de hora actual
- Scroll automático a hora actual
- Citas superpuestas en columnas

#### **WeekView.vue**

- 7 columnas (Lun-Dom)
- Grid de horas
- Citas en cada día
- Navegación por semana

#### **MonthView.vue**

- Grid de 7x5/6 (semanas)
- Citas como puntos o mini-cards
- Click en día para ver detalle
- Indicador de cantidad de citas

### **3. Componentes Auxiliares**

#### **CalendarHeader.vue**

- Selector de vista (Day/Week/Month)
- Navegación (prev/next)
- Fecha actual
- Botón "Crear Cita"
- Búsqueda

#### **MiniCalendar.vue**

- Calendario pequeño lateral
- Navegación de meses
- Indicadores de días con citas
- Click para cambiar fecha

#### **EmployeeFilter.vue**

- Lista de empleados
- Checkboxes para filtrar
- Avatar + nombre
- Contador de citas

#### **StatusFilter.vue**

- Filtros por estado
- Scheduled (azul)
- Completed (verde)
- Cancelled (rojo)

#### **AppointmentCard.vue**

- Título y empleado
- Hora inicio - fin
- Descripción
- Estado (badge)
- Click para editar

#### **AppointmentDialog.vue**

- Formulario crear/editar
- Campos: título, empleado, fecha/hora, descripción, tipo
- Validaciones
- Guardar/Cancelar

---

## 📱 **RESPONSIVE:**

### **Mobile (<768px):**

- Sidebar oculto (drawer)
- Vista por defecto: Day
- Navegación simplificada
- Cards más grandes
- Scroll vertical

### **Tablet (768px-1024px):**

- Sidebar colapsable
- Todas las vistas disponibles
- Grid adaptado

### **Desktop (>1024px):**

- Sidebar fijo
- Vista completa
- Máximo aprovechamiento

---

## ⚡ **OPTIMIZACIONES:**

### **1. Lazy Loading**

```javascript
// Solo cargar datos del rango visible
const getDateRange = (view, date) => {
  switch (view) {
    case "day":
      return { start: startOfDay(date), end: endOfDay(date) };
    case "week":
      return { start: startOfWeek(date), end: endOfWeek(date) };
    case "month":
      return { start: startOfMonth(date), end: endOfMonth(date) };
  }
};
```

### **2. Caching**

- Guardar citas cargadas en Map por fecha
- Evitar recargas innecesarias
- Invalidar cache al crear/editar/eliminar

### **3. Virtual Scrolling**

- En vista mensual con muchas citas
- Solo renderizar días visibles

---

## 🎨 **DISEÑO (Basado en HTML Ejemplo):**

### **Colores:**

```css
Primary: #137fec (azul)
Success: #10b981 (verde - completed)
Warning: #f59e0b (amarillo - scheduled)
Danger: #ef4444 (rojo - cancelled)
Background Light: #f6f7f8
Background Dark: #101922
```

### **Estados de Citas:**

- **Scheduled** (Agendado): Azul
- **Completed** (Completo): Verde con ✓
- **Cancelled** (Cancelado): Rojo

### **Tipos de Citas:**

- Meeting (Reunión)
- Interview (Entrevista)
- Review (Revisión)
- Training (Capacitación)
- Other (Otro)

---

## 📝 **FLUJO DE USUARIO:**

### **1. Ver Citas**

1. Usuario entra a "Citas a Empleados"
2. Se carga vista diaria del día actual
3. Puede cambiar a semana/mes
4. Puede navegar fechas
5. Puede filtrar por empleado/estado

### **2. Crear Cita**

1. Click en "Crear" o en espacio vacío del calendario
2. Se abre modal
3. Llena formulario
4. Guarda
5. Cita aparece en calendario

### **3. Editar Cita**

1. Click en cita existente
2. Se abre modal con datos
3. Modifica
4. Guarda
5. Cita se actualiza

### **4. Filtrar**

1. Selecciona empleados en sidebar
2. Selecciona estados
3. Calendario se actualiza automáticamente

---

## 🚀 **FASES DE IMPLEMENTACIÓN:**

### **Fase 1: Backend** (30 min)

1. ✅ Migración de tabla
2. Modelo EmployeeAppointment
3. Controller con endpoints
4. Serializer
5. Rutas

### **Fase 2: Frontend Base** (45 min)

1. Estructura de carpetas
2. EmployeeAppointmentsPage.vue
3. CalendarHeader.vue
4. Estado y lazy loading

### **Fase 3: Vista Diaria** (60 min)

1. DayView.vue
2. Grid de horas
3. AppointmentCard.vue
4. Posicionamiento de citas
5. Línea de hora actual

### **Fase 4: Vistas Adicionales** (60 min)

1. WeekView.vue
2. MonthView.vue
3. Navegación entre vistas

### **Fase 5: Componentes Auxiliares** (45 min)

1. MiniCalendar.vue
2. EmployeeFilter.vue
3. StatusFilter.vue
4. AppointmentDialog.vue

### **Fase 6: Responsive y Pulido** (30 min)

1. Media queries
2. Mobile drawer
3. Transiciones
4. Testing

**TOTAL ESTIMADO: ~4.5 horas**

---

## ❓ **DECISIONES PENDIENTES:**

1. **¿Permitir citas recurrentes?** (Ej: reunión semanal)
2. **¿Notificaciones/recordatorios?**
3. **¿Integración con calendario externo?** (Google Calendar)
4. **¿Permitir invitar múltiples empleados a una cita?**
5. **¿Colores personalizados por empleado?**

---

## 🎯 **PRÓXIMO PASO:**

**¿Procedemos con la implementación completa o prefieres:**

- A) Empezar con Fase 1 (Backend completo)
- B) Crear solo vista diaria primero (MVP)
- C) Ajustar algo del plan

**Confirma para continuar** 🚀
