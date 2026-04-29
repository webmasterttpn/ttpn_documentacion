# FilterPanel — Componente y Composable Estándar de Filtros

**Fecha:** 2026-03-23
**Archivos nuevos:**
- `src/components/FilterPanel.vue`
- `src/composables/useFilters.js`

**Primera página migrada:** `src/pages/TtpnBookings/TtpnBookingsCapturePage.vue`

---

## Problema que resuelve

Antes de este cambio, cada página que tenía filtros implementaba por su cuenta:
- Un `ref(false)` para mostrar/ocultar el panel
- Un `ref({})` con los valores de filtros
- La lógica de limpiar filtros
- El HTML del `<q-slide-transition>` + `<q-card>` + layout

Esto resultaba en código duplicado en 15+ páginas con pequeñas inconsistencias entre sí y sin ninguna señal visual de cuántos filtros están activos.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  Página (ej. TtpnBookingsCapturePage.vue)                   │
│                                                             │
│  useFilters()  ──►  filters, showFilters,                  │
│                     activeFiltersCount,                     │
│                     toggleFilters, clearFilters             │
│                                                             │
│  Header:                                                    │
│  ┌─────────────────────────────┐                           │
│  │ [Título]  [···] [🔽 badge]  │  ← toggle button estándar │
│  └─────────────────────────────┘                           │
│                                                             │
│  <FilterPanel v-model="showFilters"                        │
│               :active-count="activeFiltersCount"           │
│               @clear="onClearFilters">                     │
│    <!-- campos específicos de la página via slot -->        │
│    <div class="col-12 col-md-4"> ... </div>                │
│    <div class="col-12 col-md-4"> ... </div>                │
│  </FilterPanel>                                            │
└─────────────────────────────────────────────────────────────┘
```

**Responsabilidades:**

| Quién | Qué hace |
|---|---|
| `useFilters.js` | Estado de filtros, show/hide, conteo activos, limpiar |
| `FilterPanel.vue` | UI: slide-transition, card, layout, botón "Limpiar" |
| La página | Define qué campos tiene, hace fetch cuando cambian filtros |

---

## useFilters.js

**Ubicación:** `src/composables/useFilters.js`

### API

```javascript
const {
  filters,            // ref({ ... }) — objeto de filtros reactivo
  showFilters,        // ref(false)  — visibilidad del panel
  activeFiltersCount, // computed    — cuántos filtros no están en valor inicial
  toggleFilters,      // function    — abre/cierra el panel
  clearFilters,       // function    — resetea filters a initialFilters
} = useFilters(initialFilters)
```

### Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `initialFilters` | `Object` | Valores iniciales de cada filtro. Usar `null` para filtros vacíos. Estos valores son los que se restauran al limpiar. |

### Ejemplo de uso

```javascript
import { useFilters } from 'src/composables/useFilters'

const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } =
  useFilters({
    fecha_inicio: null,
    fecha_fin:    null,
    status:       null,
    client:       null,
    search:       '',
  })

// La página define qué hacer cuando cambian los filtros
const applyFilters = () => {
  pagination.value.page = 1
  fetchData()
}

// Handler para el evento @clear del FilterPanel
const onClearFilters = () => {
  clearFilters()   // resetea los valores
  applyFilters()   // re-fetch con filtros limpios
}
```

### Cómo cuenta filtros activos

`activeFiltersCount` compara el valor actual de cada filtro contra su valor inicial.
Si el valor actual es diferente al inicial (y no es `null`/`''`/`undefined`), cuenta como filtro activo.

```javascript
// initialFilters = { status: null, fecha: null }
// filters.value  = { status: 'active', fecha: null }
// activeFiltersCount → 1  (solo status cambió)
```

---

## FilterPanel.vue

**Ubicación:** `src/components/FilterPanel.vue`

### Props

| Prop | Tipo | Default | Descripción |
|---|---|---|---|
| `modelValue` | `Boolean` | `false` | Controla si el panel está visible. Usar con `v-model`. |
| `activeCount` | `Number` | `0` | Número de filtros activos. Habilita el botón "Limpiar" y muestra el texto informativo. |

### Emits

| Evento | Cuándo | Qué hacer en la página |
|---|---|---|
| `update:modelValue` | Cuando el panel se cierra internamente | Automático con `v-model` |
| `clear` | Click en botón "Limpiar filtros" | Llamar `clearFilters()` + `applyFilters()` |

### Slot

El contenido del panel va en el slot por defecto. Cada campo debe venir en un `<div class="col-*">` siguiendo el sistema de grid de Quasar. El `row` y `q-col-gutter-md` ya están dentro del componente.

```vue
<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
  <div class="col-12 col-md-4">
    <q-input v-model="filters.fecha_inicio" ... />
  </div>
  <div class="col-12 col-md-4">
    <q-select v-model="filters.status" ... />
  </div>
</FilterPanel>
```

### Visual

```
┌─ FilterPanel ────────────────────────────────────────────┐
│ borde izquierdo azul (--q-primary)                       │
│                                                          │
│  [Fecha Inicio]   [Fecha Fin]   [Status]                │
│  [Cliente]        [Tipo]        [Unidad]                 │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  3 filtros activos              [Limpiar filtros ✕]     │
└──────────────────────────────────────────────────────────┘
```

---

## Toggle button — Patrón estándar para el header

El botón que abre/cierra el panel vive en el header de la página (no dentro de FilterPanel).
**Este es el código estándar** que debe usarse en todas las páginas:

```vue
<q-btn
  color="grey-7"
  icon="filter_list"
  @click="toggleFilters"
  outline
  round
>
  <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
    {{ activeFiltersCount }}
  </q-badge>
  <q-tooltip>{{ showFilters ? 'Ocultar Filtros' : 'Mostrar Filtros' }}</q-tooltip>
</q-btn>
```

El badge muestra cuántos filtros están activos. Si no hay filtros activos, el badge no aparece.

---

## Cómo migrar una página existente

### Paso 1 — Imports

```javascript
import FilterPanel from 'src/components/FilterPanel.vue'
import { useFilters } from 'src/composables/useFilters'
```

### Paso 2 — Reemplazar los refs de estado

```javascript
// ❌ Antes
const showFilters = ref(false)
const filters = ref({ campo1: null, campo2: null })

// ✅ Después
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } =
  useFilters({ campo1: null, campo2: null })
```

### Paso 3 — Agregar onClearFilters

```javascript
// Mantener applyFilters como estaba (resetea paginación + fetch)
const applyFilters = () => {
  pagination.value.page = 1
  fetchItems()
}

// Nuevo: handler para el @clear del panel
const onClearFilters = () => {
  clearFilters()
  applyFilters()
}
```

### Paso 4 — Actualizar el toggle button en el template

Agregar el `q-badge` y cambiar `@click="showFilters = !showFilters"` a `@click="toggleFilters"`.

### Paso 5 — Envolver el panel en FilterPanel

```vue
<!-- ❌ Antes -->
<q-slide-transition>
  <q-card v-show="showFilters" class="q-mb-md">
    <q-card-section>
      <div class="row q-col-gutter-md">
        [campos]
      </div>
    </q-card-section>
  </q-card>
</q-slide-transition>

<!-- ✅ Después -->
<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
  [campos — sin cambios, solo quitar el div.row wrapper]
</FilterPanel>
```

---

## Páginas pendientes de migrar

Páginas que actualmente tienen panel de filtros y pueden adoptar este estándar:

| Página | Campos de filtro | Prioridad |
|---|---|---|
| `TtpnBookings/TravelCountsPage.vue` | 6 filtros (employees, vehicles, plants, services, etc.) | Alta |
| `TtpnBookings/DiscrepanciesPage.vue` | Fechas, estado | Alta |
| `DriverRequests/DriverRequestsPage.vue` | Fechas, vehículo, chofer | Alta |
| `Gas/GasChargesPage.vue` | Fecha, vehículo | Media |
| `Gas/GasolineChargesPage.vue` | Fecha, status | Media |
| `Gas/FuelPerformancePage.vue` | Rango de fechas | Media |
| `EmployeesIncidencesPage.vue` | Fecha, empleado, tipo | Media |
| `EmployeeVacationsPage.vue` | Fecha, empleado | Media |
| `EmployeeAppointments/EmployeeAppointmentsPage.vue` | Fecha, tipo | Baja |
| `VehicleChecks/VehicleChecksPage.vue` | Fecha, vehículo | Baja |

---

## Qué NO hace este componente

- **No hace fetch.** La página decide cuándo y cómo recargar datos.
- **No conoce los campos.** Los campos van en el slot — el componente solo provee el contenedor.
- **No maneja los selects lazy.** El `@popup-show`, `@filter` y las listas filtradas siguen siendo responsabilidad de la página (hasta que se implemente `useSelectFilter`).

---

## Compatibilidad

- Vue 3 Composition API ✓
- Quasar v2 ✓
- `<script setup>` ✓
- Options API (con `setup()`) ✓ — importar normalmente dentro de `setup()`
