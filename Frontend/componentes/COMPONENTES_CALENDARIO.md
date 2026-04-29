# 📅 CALENDARIO DE CITAS - COMPONENTES COMPLETOS

## ✅ YA CREADO:

- Backend completo (Controller, Serializer, Rutas)
- Migración ejecutada
- EmployeeAppointmentsPage.vue (página principal)

## 📝 COMPONENTES PENDIENTES:

Crea estos archivos en: `src/pages/EmployeeAppointments/components/`

---

## 1. CalendarHeader.vue

```vue
<template>
  <q-header elevated class="bg-white text-dark">
    <q-toolbar>
      <q-icon name="calendar_month" size="sm" color="primary" class="q-mr-sm" />
      <q-toolbar-title>Calendario de Citas</q-toolbar-title>

      <!-- View Selector -->
      <q-btn-toggle
        :model-value="view"
        @update:model-value="$emit('update:view', $event)"
        toggle-color="primary"
        :options="[
          { label: 'Día', value: 'day' },
          { label: 'Semana', value: 'week' },
          { label: 'Mes', value: 'month' },
        ]"
        class="q-mr-md"
      />

      <!-- Navigation -->
      <q-btn flat round icon="chevron_left" @click="previousPeriod" />
      <q-btn flat round icon="chevron_right" @click="nextPeriod" />
      <div class="text-h6 q-mx-md">{{ formattedDate }}</div>

      <q-space />

      <!-- Actions -->
      <q-btn flat round icon="search" />
      <q-btn unelevated color="primary" icon="add" label="Crear" @click="$emit('create')" />
    </q-toolbar>
  </q-header>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  view: String,
  date: Date,
})

const emit = defineEmits(['update:view', 'update:date', 'create'])

const formattedDate = computed(() => {
  return props.date.toLocaleDateString('es-MX', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
})

function previousPeriod() {
  const newDate = new Date(props.date)
  if (props.view === 'day') newDate.setDate(newDate.getDate() - 1)
  else if (props.view === 'week') newDate.setDate(newDate.getDate() - 7)
  else newDate.setMonth(newDate.getMonth() - 1)
  emit('update:date', newDate)
}

function nextPeriod() {
  const newDate = new Date(props.date)
  if (props.view === 'day') newDate.setDate(newDate.getDate() + 1)
  else if (props.view === 'week') newDate.setDate(newDate.getDate() + 7)
  else newDate.setMonth(newDate.getMonth() + 1)
  emit('update:date', newDate)
}
</script>
```

---

## 2. DayView.vue

```vue
<template>
  <div class="day-view">
    <!-- Header con día -->
    <div class="day-header q-pa-md bg-white">
      <div class="text-h6">{{ dayName }}</div>
      <div class="text-h4 text-primary">{{ dayNumber }}</div>
    </div>

    <!-- Grid de horas -->
    <div class="time-grid" ref="gridRef">
      <q-inner-loading :showing="loading" />

      <!-- Columna de horas -->
      <div class="time-labels">
        <div v-for="hour in hours" :key="hour" class="time-label">{{ hour }}:00</div>
      </div>

      <!-- Área de citas -->
      <div class="appointments-area" @click="handleGridClick">
        <!-- Líneas de hora -->
        <div v-for="hour in hours" :key="`line-${hour}`" class="hour-line" />

        <!-- Línea de hora actual -->
        <div v-if="showCurrentTimeLine" class="current-time-line" :style="currentTimeStyle" />

        <!-- Citas -->
        <AppointmentCard
          v-for="apt in positionedAppointments"
          :key="apt.id"
          :appointment="apt"
          :style="apt.style"
          @click="$emit('click-appointment', apt)"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import AppointmentCard from './AppointmentCard.vue'

const props = defineProps({
  appointments: Array,
  date: Date,
  loading: Boolean,
})

const emit = defineEmits(['click-appointment', 'click-time'])

const gridRef = ref(null)
const hours = Array.from({ length: 13 }, (_, i) => i + 8) // 8 AM - 8 PM
const currentTime = ref(new Date())

const dayName = computed(() => {
  return props.date.toLocaleDateString('es-MX', { weekday: 'long' })
})

const dayNumber = computed(() => props.date.getDate())

const showCurrentTimeLine = computed(() => {
  const today = new Date()
  return props.date.toDateString() === today.toDateString()
})

const currentTimeStyle = computed(() => {
  const now = currentTime.value
  const minutes = now.getHours() * 60 + now.getMinutes()
  const startMinutes = 8 * 60 // 8 AM
  const top = ((minutes - startMinutes) / 60) * 60 // 60px por hora
  return { top: `${top}px` }
})

const positionedAppointments = computed(() => {
  return props.appointments.map((apt) => {
    const [hours, minutes] = apt.hora_inicio.split(':')
    const startMinutes = parseInt(hours) * 60 + parseInt(minutes)
    const gridStartMinutes = 8 * 60
    const top = ((startMinutes - gridStartMinutes) / 60) * 60

    // Calcular duración (default 1 hora si no hay hora_fin)
    let duration = 60
    if (apt.hora_fin) {
      const [endHours, endMinutes] = apt.hora_fin.split(':')
      const endTotalMinutes = parseInt(endHours) * 60 + parseInt(endMinutes)
      duration = endTotalMinutes - startMinutes
    }
    const height = (duration / 60) * 60

    return {
      ...apt,
      style: {
        position: 'absolute',
        top: `${top}px`,
        height: `${height}px`,
        left: '8px',
        right: '8px',
      },
    }
  })
})

function handleGridClick(event) {
  const rect = event.currentTarget.getBoundingClientRect()
  const y = event.clientY - rect.top
  const hour = Math.floor(y / 60) + 8
  const minutes = Math.floor(y % 60)
  const time = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
  emit('click-time', time)
}

// Actualizar hora actual cada minuto
let interval
onMounted(() => {
  interval = setInterval(() => {
    currentTime.value = new Date()
  }, 60000)
})

onUnmounted(() => {
  clearInterval(interval)
})
</script>

<style scoped>
.day-view {
  background: white;
  border-radius: 8px;
  overflow: hidden;
}

.day-header {
  border-bottom: 1px solid #e0e0e0;
}

.time-grid {
  display: flex;
  position: relative;
  min-height: 780px; /* 13 hours * 60px */
}

.time-labels {
  width: 80px;
  flex-shrink: 0;
  border-right: 1px solid #e0e0e0;
}

.time-label {
  height: 60px;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding-right: 8px;
  font-size: 12px;
  color: #666;
}

.appointments-area {
  flex: 1;
  position: relative;
  cursor: pointer;
}

.hour-line {
  position: absolute;
  left: 0;
  right: 0;
  height: 60px;
  border-bottom: 1px solid #f0f0f0;
}

.hour-line:nth-child(odd) {
  background: #fafafa;
}

.current-time-line {
  position: absolute;
  left: 0;
  right: 0;
  height: 2px;
  background: #ef4444;
  z-index: 10;
}

.current-time-line::before {
  content: '';
  position: absolute;
  left: -6px;
  top: -5px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #ef4444;
}
</style>
```

---

## 3. AppointmentCard.vue

```vue
<template>
  <div
    class="appointment-card"
    :class="`status-${appointment.status}`"
    @click.stop="$emit('click')"
  >
    <div class="card-header">
      <div class="employee-name">{{ appointment.employee.nombre }}</div>
      <div class="time-badge">
        {{ appointment.hora_inicio }} - {{ appointment.hora_fin || '...' }}
      </div>
    </div>
    <div class="card-body">
      <div v-if="appointment.titulo" class="titulo">{{ appointment.titulo }}</div>
      <div class="descripcion">{{ appointment.descripcion }}</div>
      <q-icon
        v-if="appointment.status === 'completed'"
        name="check_circle"
        color="positive"
        size="sm"
      />
    </div>
  </div>
</template>

<script setup>
defineProps({
  appointment: Object,
})

defineEmits(['click'])
</script>

<style scoped>
.appointment-card {
  border-radius: 6px;
  padding: 8px;
  cursor: pointer;
  transition: all 0.2s;
  border-left: 4px solid;
  overflow: hidden;
}

.appointment-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  transform: translateY(-1px);
}

.status-scheduled {
  background: #dbeafe;
  border-left-color: #3b82f6;
}

.status-completed {
  background: #d1fae5;
  border-left-color: #10b981;
}

.status-cancelled {
  background: #fee2e2;
  border-left-color: #ef4444;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.employee-name {
  font-weight: 600;
  font-size: 13px;
  color: #1f2937;
}

.time-badge {
  font-size: 11px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.7);
  padding: 2px 6px;
  border-radius: 4px;
}

.titulo {
  font-weight: 500;
  font-size: 12px;
  margin-bottom: 2px;
}

.descripcion {
  font-size: 11px;
  color: #6b7280;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
```

---

## 4. MiniCalendar.vue

```vue
<template>
  <div class="mini-calendar q-pa-md">
    <div class="calendar-header q-mb-md">
      <div class="text-subtitle2">{{ currentMonth }}</div>
      <div>
        <q-btn flat dense round size="sm" icon="chevron_left" @click="previousMonth" />
        <q-btn flat dense round size="sm" icon="chevron_right" @click="nextMonth" />
      </div>
    </div>

    <div class="calendar-grid">
      <div v-for="day in weekDays" :key="day" class="day-header">{{ day }}</div>
      <div
        v-for="day in calendarDays"
        :key="day.date"
        class="day-cell"
        :class="{
          'other-month': !day.currentMonth,
          selected: isSelected(day.date),
          today: isToday(day.date),
          'has-appointments': day.hasAppointments,
        }"
        @click="selectDate(day.date)"
      >
        {{ day.day }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  modelValue: Date,
  appointments: Array,
})

const emit = defineEmits(['update:modelValue'])

const viewDate = ref(new Date(props.modelValue))
const weekDays = ['D', 'L', 'M', 'M', 'J', 'V', 'S']

const currentMonth = computed(() => {
  return viewDate.value.toLocaleDateString('es-MX', { month: 'long', year: 'numeric' })
})

const calendarDays = computed(() => {
  const year = viewDate.value.getFullYear()
  const month = viewDate.value.getMonth()
  const firstDay = new Date(year, month, 1)
  const lastDay = new Date(year, month + 1, 0)
  const prevMonthDays = firstDay.getDay()
  const days = []

  // Días del mes anterior
  for (let i = prevMonthDays - 1; i >= 0; i--) {
    const date = new Date(year, month, -i)
    days.push({
      date,
      day: date.getDate(),
      currentMonth: false,
      hasAppointments: hasAppointmentsOnDate(date),
    })
  }

  // Días del mes actual
  for (let i = 1; i <= lastDay.getDate(); i++) {
    const date = new Date(year, month, i)
    days.push({
      date,
      day: i,
      currentMonth: true,
      hasAppointments: hasAppointmentsOnDate(date),
    })
  }

  // Días del mes siguiente
  const remaining = 42 - days.length
  for (let i = 1; i <= remaining; i++) {
    const date = new Date(year, month + 1, i)
    days.push({
      date,
      day: i,
      currentMonth: false,
      hasAppointments: hasAppointmentsOnDate(date),
    })
  }

  return days
})

function hasAppointmentsOnDate(date) {
  const dateStr = date.toISOString().split('T')[0]
  return props.appointments.some((apt) => apt.fecha_inicio === dateStr)
}

function isSelected(date) {
  return date.toDateString() === props.modelValue.toDateString()
}

function isToday(date) {
  return date.toDateString() === new Date().toDateString()
}

function selectDate(date) {
  emit('update:modelValue', date)
}

function previousMonth() {
  viewDate.value = new Date(viewDate.value.getFullYear(), viewDate.value.getMonth() - 1)
}

function nextMonth() {
  viewDate.value = new Date(viewDate.value.getFullYear(), viewDate.value.getMonth() + 1)
}
</script>

<style scoped>
.calendar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.day-header {
  text-align: center;
  font-size: 11px;
  font-weight: 600;
  color: #666;
  padding: 4px;
}

.day-cell {
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.day-cell:hover {
  background: #f3f4f6;
}

.day-cell.other-month {
  color: #d1d5db;
}

.day-cell.selected {
  background: #3b82f6;
  color: white;
  font-weight: 600;
}

.day-cell.today {
  border: 2px solid #3b82f6;
}

.day-cell.has-appointments::after {
  content: '';
  position: absolute;
  bottom: 2px;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: #3b82f6;
}
</style>
```

---

## 5. StatusFilter.vue

```vue
<template>
  <div class="status-filter q-pa-md">
    <div class="text-caption text-grey-7 text-uppercase q-mb-sm">Filtros</div>

    <q-list dense>
      <q-item tag="label" v-ripple>
        <q-item-section side>
          <q-checkbox
            :model-value="modelValue.includes('scheduled')"
            @update:model-value="toggle('scheduled')"
            color="primary"
          />
        </q-item-section>
        <q-item-section>
          <div class="row items-center">
            <div class="status-dot bg-primary q-mr-sm" />
            <span>Agendado</span>
          </div>
        </q-item-section>
      </q-item>

      <q-item tag="label" v-ripple>
        <q-item-section side>
          <q-checkbox
            :model-value="modelValue.includes('completed')"
            @update:model-value="toggle('completed')"
            color="positive"
          />
        </q-item-section>
        <q-item-section>
          <div class="row items-center">
            <div class="status-dot bg-positive q-mr-sm" />
            <span>Completado</span>
          </div>
        </q-item-section>
      </q-item>

      <q-item tag="label" v-ripple>
        <q-item-section side>
          <q-checkbox
            :model-value="modelValue.includes('cancelled')"
            @update:model-value="toggle('cancelled')"
            color="negative"
          />
        </q-item-section>
        <q-item-section>
          <div class="row items-center">
            <div class="status-dot bg-negative q-mr-sm" />
            <span>Cancelado</span>
          </div>
        </q-item-section>
      </q-item>
    </q-list>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: Array,
})

const emit = defineEmits(['update:modelValue'])

function toggle(status) {
  const current = [...props.modelValue]
  const index = current.indexOf(status)
  if (index > -1) {
    current.splice(index, 1)
  } else {
    current.push(status)
  }
  emit('update:modelValue', current)
}
</script>

<style scoped>
.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
</style>
```

---

## 6. EmployeeFilter.vue

```vue
<template>
  <div class="employee-filter q-pa-md">
    <div class="text-caption text-grey-7 text-uppercase q-mb-sm">Empleados</div>

    <q-list dense>
      <q-item
        v-for="employee in employees"
        :key="employee.id"
        clickable
        v-ripple
        @click="toggle(employee.id)"
      >
        <q-item-section avatar>
          <q-avatar size="32px" color="primary" text-color="white">
            {{ employee.initials }}
          </q-avatar>
        </q-item-section>
        <q-item-section>
          {{ employee.nombre }}
        </q-item-section>
        <q-item-section side>
          <q-checkbox :model-value="modelValue.includes(employee.id)" @click.stop />
        </q-item-section>
      </q-item>
    </q-list>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: Array,
  employees: Array,
})

const emit = defineEmits(['update:modelValue'])

function toggle(employeeId) {
  const current = [...props.modelValue]
  const index = current.indexOf(employeeId)
  if (index > -1) {
    current.splice(index, 1)
  } else {
    current.push(employeeId)
  }
  emit('update:modelValue', current)
}
</script>
```

---

## 7. AppointmentDialog.vue

```vue
<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 500px">
      <q-card-section class="bg-primary text-white">
        <div class="text-h6">{{ isEditing ? 'Editar Cita' : 'Nueva Cita' }}</div>
      </q-card-section>

      <q-card-section>
        <q-form @submit="save">
          <q-select
            outlined
            v-model="form.employee_id"
            :options="employees"
            option-value="id"
            option-label="nombre"
            emit-value
            map-options
            label="Empleado *"
            class="q-mb-md"
            :rules="[(val) => !!val || 'Campo requerido']"
          />

          <q-input outlined v-model="form.titulo" label="Título" class="q-mb-md" />

          <q-input
            outlined
            v-model="form.descripcion"
            label="Descripción"
            type="textarea"
            rows="3"
            class="q-mb-md"
          />

          <div class="row q-col-gutter-md q-mb-md">
            <div class="col-6">
              <q-input
                outlined
                v-model="form.fecha_inicio"
                label="Fecha Inicio *"
                type="date"
                :rules="[(val) => !!val || 'Campo requerido']"
              />
            </div>
            <div class="col-6">
              <q-input
                outlined
                v-model="form.hora_inicio"
                label="Hora Inicio *"
                type="time"
                :rules="[(val) => !!val || 'Campo requerido']"
              />
            </div>
          </div>

          <div class="row q-col-gutter-md q-mb-md">
            <div class="col-6">
              <q-input outlined v-model="form.fecha_fin" label="Fecha Fin" type="date" />
            </div>
            <div class="col-6">
              <q-input outlined v-model="form.hora_fin" label="Hora Fin" type="time" />
            </div>
          </div>

          <q-input outlined v-model="form.ubicacion" label="Ubicación" class="q-mb-md" />

          <q-select
            outlined
            v-model="form.tipo_cita"
            :options="tiposCita"
            label="Tipo de Cita"
            class="q-mb-md"
          />

          <q-select
            outlined
            v-model="form.status"
            :options="statuses"
            label="Estado"
            class="q-mb-md"
          />

          <div class="row justify-end q-gutter-sm">
            <q-btn flat label="Cancelar" v-close-popup />
            <q-btn unelevated color="primary" label="Guardar" type="submit" />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: Boolean,
  appointment: Object,
  employees: Array,
})

const emit = defineEmits(['update:modelValue', 'save'])

const form = ref({
  employee_id: null,
  titulo: '',
  descripcion: '',
  fecha_inicio: '',
  hora_inicio: '',
  fecha_fin: '',
  hora_fin: '',
  ubicacion: '',
  tipo_cita: 'meeting',
  status: 'scheduled',
})

const tiposCita = [
  { label: 'Reunión', value: 'meeting' },
  { label: 'Entrevista', value: 'interview' },
  { label: 'Revisión', value: 'review' },
  { label: 'Capacitación', value: 'training' },
  { label: 'Otro', value: 'other' },
]

const statuses = [
  { label: 'Agendado', value: 'scheduled' },
  { label: 'Completado', value: 'completed' },
  { label: 'Cancelado', value: 'cancelled' },
]

const isEditing = computed(() => !!props.appointment?.id)

watch(
  () => props.appointment,
  (newVal) => {
    if (newVal) {
      form.value = { ...newVal }
    } else {
      resetForm()
    }
  },
  { immediate: true },
)

function resetForm() {
  form.value = {
    employee_id: null,
    titulo: '',
    descripcion: '',
    fecha_inicio: new Date().toISOString().split('T')[0],
    hora_inicio: '09:00',
    fecha_fin: '',
    hora_fin: '',
    ubicacion: '',
    tipo_cita: 'meeting',
    status: 'scheduled',
  }
}

function save() {
  emit('save', form.value)
}
</script>
```

---

## 8. Agregar Ruta

En `src/router/routes.js`:

```javascript
{
  path: '/employees/appointments',
  component: () => import('pages/EmployeeAppointments/EmployeeAppointmentsPage.vue'),
  meta: { requiresAuth: true }
}
```

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN:

1. [ ] Crear todos los componentes en `src/pages/EmployeeAppointments/components/`
2. [ ] Agregar ruta en `router/routes.js`
3. [ ] Probar creación de cita
4. [ ] Probar edición de cita
5. [ ] Probar filtros
6. [ ] Probar navegación de fechas
7. [ ] Verificar responsive

---

## 🚀 PRÓXIMOS PASOS:

1. Implementar WeekView.vue
2. Implementar MonthView.vue
3. Agregar drag & drop para mover citas
4. Agregar citas recurrentes
5. Integración con notificaciones

**¡Todo listo para implementar!** 🎉
