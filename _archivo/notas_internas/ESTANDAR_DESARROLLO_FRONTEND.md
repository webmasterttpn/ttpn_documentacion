# Estándar de Desarrollo Frontend — Vue 3 + Quasar PWA

**Proyecto base:** Kumi TTPN Admin V2  
**Stack:** Vue 3 (Composition API) · Quasar 2 · Pinia · Axios · SonarCloud  
**Última actualización:** 2026-04-02

---

## Índice

1. [Estructura de archivos](#1-estructura-de-archivos)
2. [Capa de servicios API](#2-capa-de-servicios-api)
3. [Pinia — Store de catálogos](#3-pinia--store-de-catálogos)
4. [Composables de dominio](#4-composables-de-dominio)
5. [Composables compartidos](#5-composables-compartidos)
6. [Componentes base](#6-componentes-base)
7. [Patrón de página (Page orquestador)](#7-patrón-de-página-page-orquestador)
8. [AppTable — tabla estándar](#8-apptable--tabla-estándar)
9. [Formularios y diálogos](#9-formularios-y-diálogos)
10. [Manejo de errores](#10-manejo-de-errores)
11. [Responsive: desktop vs mobile](#11-responsive-desktop-vs-mobile)
12. [Reglas SonarCloud](#12-reglas-sonarcloud)
13. [Nomenclatura y convenciones](#13-nomenclatura-y-convenciones)
14. [Checklist para módulo nuevo](#14-checklist-para-módulo-nuevo)

---

## 1. Estructura de archivos

```
src/
├── boot/
│   └── axios.js              ← instancia global de Axios con interceptor JWT
│
├── stores/
│   ├── auth-store.js         ← login / logout / user
│   ├── catalogs-store.js     ← catálogos compartidos con caché (Pinia)
│   └── privileges-store.js   ← permisos por módulo
│
├── services/
│   ├── employees.service.js  ← un archivo por dominio, exporta objetos con list/find/create/update/destroy
│   ├── vehicles.service.js
│   ├── bookings.service.js
│   └── catalogs.service.js   ← catálogos CRUD (settings)
│
├── composables/
│   ├── useFilters.js          ← filtros reactivos genérico
│   ├── useNotify.js           ← notificaciones Quasar
│   ├── useCrud.js             ← CRUD genérico reutilizable
│   ├── useDateFormat.js       ← formateo de fechas
│   ├── usePrivileges.js       ← control de acceso
│   ├── dropdowns/             ← wrappers sobre catalogs-store
│   │   ├── useVehicleTypesDropdown.js
│   │   └── ...
│   ├── orchestrators/         ← componen varios catálogos para un módulo
│   │   ├── useVehiclesOrchestrator.js
│   │   └── ...
│   └── <Modulo>/              ← composables específicos del módulo
│       ├── use<Modulo>Data.js
│       └── use<Modulo>Catalogs.js
│
├── components/
│   ├── PageHeader.vue         ← título + slot actions
│   ├── FilterPanel.vue        ← panel colapsable de filtros
│   └── calendar/              ← componentes genéricos de calendario
│
├── pages/
│   └── <Modulo>/
│       ├── <Modulo>Page.vue          ← orquestador (<300 líneas)
│       └── components/
│           ├── <Modulo>Table.vue     ← tabla desktop
│           ├── <Modulo>MobileList.vue
│           ├── <Modulo>Filters.vue
│           ├── <Modulo>Form.vue
│           ├── <Modulo>DetailsDialog.vue
│           └── <Modulo>ImportDialog.vue
│
└── constants/
    └── ui.js                  ← magic numbers compartidos (PAGE_SIZE, etc.)
```

---

## 2. Capa de servicios API

Cada dominio tiene su propio archivo de servicio. El patrón es un objeto plano con métodos nombrados.

```js
// src/services/vehicles.service.js
import { api } from 'boot/axios'

export const vehiclesService = {
  list:    (params) => api.get('/api/v1/vehicles', { params }),
  find:    (id)     => api.get(`/api/v1/vehicles/${id}`),
  create:  (data)   => api.post('/api/v1/vehicles', data),
  update:  (id, data) => api.put(`/api/v1/vehicles/${id}`, data),
  destroy: (id)     => api.delete(`/api/v1/vehicles/${id}`),
}

// Si necesita multipart/form-data:
export const vehiclesService = {
  update: (id, formData) =>
    api.put(`/api/v1/vehicles/${id}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
}
```

**Reglas:**
- Siempre importar `api` desde `boot/axios`, nunca `axios` directo.
- El servicio NO maneja errores — eso es responsabilidad del composable o la página.
- Acciones extra se nombran descriptivamente: `authorize`, `accept`, `reject`, `downloadXlsx`.

---

## 3. Pinia — Store de catálogos

Para catálogos compartidos entre ≥ 2 módulos, usar `useCatalogsStore`. Nunca hacer la misma llamada de catálogo en múltiples páginas.

```js
// src/stores/catalogs-store.js (patrón)

const CATALOG_DEFS = {
  vehicleTypes:    { url: '/api/v1/vehicle_types' },
  vehicleDocTypes: {
    url: '/api/v1/vehicle_document_types',
    transform: (items) => items.map(i => ({ value: i.nombre, label: i.nombre })),
  },
  roles:           { url: '/api/v1/roles' },
  businessUnits:   { url: '/api/v1/business_units' },
  // ...
}
```

**Uso en componentes:**

```js
// Opción A — directo al store (páginas simples)
const catalogsStore = useCatalogsStore()
const roles = computed(() => catalogsStore.roles)

onMounted(() => {
  Promise.all([
    fetchData(),
    catalogsStore.loadMany(['roles', 'businessUnits']),
  ])
})

// Opción B — via orchestrator (módulos con varios catálogos)
const { vehicleTypes, concessionaires, loadCatalogs } = useVehiclesOrchestrator()
onMounted(() => Promise.all([fetchData(), loadCatalogs()]))
```

**En logout — limpiar siempre:**
```js
// auth-store.js → logout()
catalogsStore.invalidateAll()
```

**Cuándo agregar un catálogo al store:**
- Se usa en 2 o más módulos distintos.
- Los datos cambian raramente (configuración, tipos, roles).

**Qué NO va en el store:**
- Datos operacionales (employees, vehicles, bookings).
- Datos con filtros dinámicos complejos.

---

## 4. Composables de dominio

Cada módulo complejo tiene dos composables propios:

### `use<Modulo>Data.js` — datos y CRUD

```js
// src/composables/TravelCounts/useTravelCountsData.js
export const INITIAL_FILTERS = {
  fecha_inicio: null,
  fecha_fin: null,
  status: null,
}

export function useTravelCountsData(filters) {
  const { notifyOk, notifyApiError } = useNotify()
  const $q = useQuasar()

  const rows      = ref([])
  const loading   = ref(false)
  const saving    = ref(false)
  const pagination = ref({ page: 1, rowsPerPage: 20, rowsNumber: 0 })

  async function fetchData(options = {}) {
    loading.value = true
    try {
      const res = await myService.list({ ...filters.value, ...options })
      rows.value            = res.data.data
      pagination.value.rowsNumber = res.data.meta.total_count
    } catch (e) {
      notifyApiError(e, 'Error al cargar datos')
    } finally {
      loading.value = false  // ← SIEMPRE en finally
    }
  }

  async function save(formData, id, onSuccess) {
    saving.value = true
    try {
      if (id) {
        await myService.update(id, { resource: formData })
        notifyOk('Actualizado exitosamente')
      } else {
        await myService.create({ resource: formData })
        notifyOk('Creado exitosamente')
      }
      onSuccess?.()
      await fetchData()
    } catch (e) {
      notifyApiError(e, 'Error al guardar')
    } finally {
      saving.value = false  // ← SIEMPRE en finally
    }
  }

  function confirmDelete(item) {
    $q.dialog({
      title: 'Eliminar',
      message: `¿Eliminar "${item.nombre}"?`,
      cancel: true,
      persistent: true,
      color: 'negative',
    }).onOk(async () => {
      try {
        await myService.destroy(item.id)
        notifyOk('Eliminado')
        await fetchData()
      } catch (e) {
        notifyApiError(e, 'Error al eliminar')
      }
    })
  }

  function onRequest(props) {
    pagination.value = props.pagination
    fetchData(props)
  }

  function applyFilters() { fetchData() }

  return { rows, loading, saving, pagination, fetchData, save, confirmDelete, onRequest, applyFilters }
}
```

### `use<Modulo>Catalogs.js` — catálogos específicos del módulo

```js
export function useTravelCountsCatalogs() {
  // Catálogos locales (no compartidos o con lógica de filtrado)
  const employees          = ref([])
  const filteredEmployees  = ref([])

  async function fetchCatalogs() {
    // Cargar catálogos compartidos desde el store
    await catalogsStore.loadMany(['vehicleTypes', 'ttpnServices'])
    // Cargar catálogos locales
    const { data } = await employeesService.list()
    employees.value = filteredEmployees.value = data
  }

  function filterEmployees(val, update) {
    update(() => {
      const q = val.toLowerCase()
      filteredEmployees.value = employees.value.filter(e =>
        e.nombre.toLowerCase().includes(q)
      )
    })
  }

  // Garantiza que el valor actual aparezca en la lista filtrada al abrir un edit
  function ensureInOptions(id, source, filtered) {
    if (id && !filtered.value.find(o => o.id === id)) {
      const found = source.find(o => o.id === id)
      if (found) filtered.value = [found, ...filtered.value]
    }
  }

  return { employees, filteredEmployees, fetchCatalogs, filterEmployees, ensureInOptions }
}
```

---

## 5. Composables compartidos

### `useFilters`

```js
import { useFilters } from 'src/composables/useFilters'

const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters, openFilters } =
  useFilters({
    fecha_inicio: null,
    fecha_fin:    null,
    status:       null,
  })

function onClearFilters() {
  clearFilters()
  applyFilters()  // re-fetch con filtros limpios
}
```

### `useNotify`

```js
const { notifyOk, notifyError, notifyWarn, notifyInfo, notifyApiError } = useNotify()

// notifyApiError extrae errors[] del response Rails:
notifyApiError(error, 'Error al guardar')
// → "Campo no puede estar vacío, Email ya está en uso"
```

### `useCrud` (para módulos simples sin paginación server-side)

```js
const { items, form, loading, saving, dialog, isEditMode, fetchData, openDialog, save } = useCrud({
  service:      myService,
  resourceName: 'vehicle_type',    // clave del payload Rails
  formDefault:  { nombre: '', is_active: true },
  createMsg:    'Tipo creado',
  updateMsg:    'Tipo actualizado',
})
```

### `useDateFormat`

```js
const { formatDate, formatDateTime, today } = useDateFormat()
formatDate('2026-04-02')     // → '02/04/2026'
formatDateTime(isoString)    // → '02/04/2026 14:30'
today()                      // → '2026-04-02' (YYYY-MM-DD)
```

---

## 6. Componentes base

### `PageHeader`

```vue
<PageHeader title="Empleados" subtitle="Gestión del personal activo">
  <template #actions>
    <!-- Botón de filtros -->
    <q-btn color="grey-7" icon="filter_list" outline round @click="toggleFilters">
      <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
        {{ activeFiltersCount }}
      </q-badge>
      <q-tooltip>{{ showFilters ? 'Ocultar Filtros' : 'Mostrar Filtros' }}</q-tooltip>
    </q-btn>
    <!-- Importar (si aplica) -->
    <q-btn color="secondary" icon="upload_file" outline round @click="showImport = true">
      <q-tooltip>Importar desde Excel</q-tooltip>
    </q-btn>
    <!-- Acción principal -->
    <q-btn color="primary" icon="add" label="Nuevo" unelevated @click="openCreate" />
  </template>
</PageHeader>
```

### `FilterPanel`

```vue
<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
  <!-- Los campos van dentro como slot -->
  <div class="col-12 col-md-3">
    <q-select dense outlined v-model="filters.status" :options="statusOptions"
      label="Estatus" clearable emit-value map-options />
  </div>
  <div class="col-12 col-md-3">
    <q-input dense outlined v-model="filters.search" label="Buscar" clearable debounce="300"
      @update:model-value="applyFilters" />
  </div>
</FilterPanel>
```

**Nota importante:** `FilterPanel` dispara `window.dispatchEvent(new Event('resize'))` al terminar la animación de apertura/cierre. Esto sincroniza la altura de `AppTable` sin necesidad de código adicional en la página.

### Calendarios genéricos

```vue
<!-- Agnósticos del dominio — reciben events[], emiten event-click -->
<CalendarMonthView
  v-model="selectedDate"
  :events="calendarEvents"
  @event-click="onEventClick"
/>
```

Formato de evento:
```js
{ id, datetime, color, label, sublabel, icon, ...metadataLibre }
```

---

## 7. Patrón de página (Page orquestador)

La página NO contiene lógica de negocio — solo orquesta composables y componentes.

```vue
<template>
  <q-page class="bg-grey-2">
    <div class="q-pa-md">

      <PageHeader title="..." subtitle="...">
        <template #actions>
          <!-- botones estándar -->
        </template>
      </PageHeader>

      <!-- Stats bar (si el módulo lo requiere) -->
      <StatsBar :items="statItems" :has-date-filter="hasDateFilter" @quick-stat="onQuickStat" />

      <FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
        <XFilters v-model="filters" @change="applyFilters" />
      </FilterPanel>

      <!-- Desktop -->
      <XTable
        class="gt-sm"
        :rows="rows"
        :loading="loading"
        :pagination="pagination"
        @request="onRequest"
        @edit="editItem"
        @view="viewItem"
        @delete="confirmDelete"
      />

      <!-- Mobile -->
      <XMobileList
        class="lt-md"
        :rows="rows"
        :loading="loading"
        @edit="editItem"
        @view="viewItem"
        @delete="confirmDelete"
      />

      <!-- Diálogos -->
      <XForm v-model="showForm" :editing="editingItem" :saving="saving" @save="onFormSave" />
      <XDetailsDialog v-model="showDetail" :item="selectedItem" />
      <XImportDialog v-model="showImport" @import-done="fetchData" />

    </div>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useFilters }   from 'src/composables/useFilters'
import { useXData, INITIAL_FILTERS } from 'src/composables/X/useXData'
import { useXCatalogs } from 'src/composables/X/useXCatalogs'
// imports de componentes...

const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } =
  useFilters({ ...INITIAL_FILTERS })

const { rows, loading, saving, pagination, fetchData, save, confirmDelete, onRequest, applyFilters } =
  useXData(filters)

const { catalogs, fetchCatalogs } = useXCatalogs()

// Estado local de diálogos
const showForm   = ref(false)
const showDetail = ref(false)
const showImport = ref(false)
const editingItem  = ref(null)
const selectedItem = ref(null)

// Stats
const statItems = computed(() => [ /* ... */ ])
const hasDateFilter = computed(() => !!(filters.value.fecha_inicio || filters.value.fecha_fin))

// Acciones
function openCreate() { editingItem.value = null; showForm.value = true }
function editItem(item) { editingItem.value = item; showForm.value = true }
function viewItem(item) { selectedItem.value = item; showDetail.value = true }
function onFormSave(form) { save(form, editingItem.value?.id, () => { showForm.value = false }) }
function onQuickStat(type) { filterByQuickStat(type); showFilters.value = true }
function onClearFilters() { clearFilters(); applyFilters() }

onMounted(() => { fetchData(); fetchCatalogs() })
</script>
```

**Límite:** La página no debe superar ~300 líneas. Si supera, mover lógica a composables.

---

## 8. AppTable — tabla estándar

```vue
<!-- Tabla con sticky header, paginación y altura dinámica -->
<q-table
  :rows="rows"
  :columns="columns"
  row-key="id"
  :loading="loading"
  v-model:pagination="pagination"
  class="fit ttpn-sticky-table no-shadow"
  :rows-per-page-options="[10, 20, 50, 0]"
  @request="onRequest"
>
  <!-- Encabezado sticky -->
  <template v-slot:header="props">
    <q-tr :props="props">
      <q-th v-for="col in props.cols" :key="col.name" :props="props"
        class="text-primary text-weight-bold bg-white">
        {{ col.label }}
      </q-th>
    </q-tr>
  </template>

  <!-- Columna de acciones (siempre a la derecha) -->
  <template v-slot:body-cell-actions="props">
    <q-td :props="props" auto-width>
      <div class="row q-gutter-xs no-wrap justify-end">
        <q-btn flat round color="primary"  icon="visibility" size="sm" @click="$emit('view', props.row)" />
        <q-btn flat round color="primary"  icon="edit"       size="sm" @click="$emit('edit', props.row)" />
        <q-btn flat round color="negative" icon="delete"     size="sm" @click="$emit('delete', props.row)" />
      </div>
    </q-td>
  </template>
</q-table>
```

**Definición de columnas:**
```js
const columns = [
  { name: 'nombre',     label: 'Nombre',   field: 'nombre',     sortable: true,  align: 'left',   style: 'min-width: 200px' },
  { name: 'status',     label: 'Estatus',  field: 'is_active',  sortable: true,  align: 'center' },
  { name: 'actions',    label: 'Acciones', field: 'actions',    sortable: false, align: 'right' },
]
```

**CSS requerido (global o en el componente):**
```scss
.ttpn-sticky-table {
  height: 100%;
  display: flex;
  flex-direction: column;

  .q-table__middle { flex-grow: 1; overflow: auto; }

  .q-table__top,
  .q-table__bottom,
  thead tr:first-child th { background-color: #fff; }

  thead tr th { position: sticky; top: 0; z-index: 1; }
}
```

---

## 9. Formularios y diálogos

```vue
<!-- XForm.vue — dialog estándar -->
<template>
  <q-dialog v-model="show" transition-show="scale" transition-hide="scale">
    <q-card style="width: 700px; max-width: 95vw;">

      <q-toolbar class="bg-white text-primary shadow-1">
        <q-toolbar-title class="text-weight-bold">
          {{ isEditing ? 'Editar Registro' : 'Nuevo Registro' }}
        </q-toolbar-title>
        <q-btn flat round dense icon="close" v-close-popup color="grey-7" />
      </q-toolbar>

      <!-- Skeleton mientras carga (si el form necesita datos previos) -->
      <q-card-section v-if="loading" class="q-pa-lg">
        <q-skeleton type="rect" height="50px" class="q-mb-md" v-for="i in 5" :key="i" />
      </q-card-section>

      <q-card-section v-else class="q-pa-lg scroll" style="max-height: 70vh;">
        <div class="row q-col-gutter-md">
          <div class="col-12">
            <q-input dense outlined v-model="form.nombre" label="Nombre *"
              :rules="[v => !!v || 'Requerido']" />
          </div>
          <!-- más campos -->
        </div>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right" class="bg-white q-pa-md">
        <q-btn outline label="Cancelar" color="grey-8" v-close-popup class="q-mr-sm" />
        <q-btn unelevated color="primary" label="Guardar"
          @click="onSave" :loading="saving" :disable="loading" />
      </q-card-actions>

    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, watch, computed } from 'vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  editing:    { type: Object,  default: null },
  saving:     { type: Boolean, default: false },
  loading:    { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue', 'save'])

const show = ref(false)
const isEditing = computed(() => !!props.editing)
const form = ref({ nombre: '', is_active: true })

watch(() => props.modelValue, (val) => {
  show.value = val
  if (val) {
    form.value = props.editing
      ? { ...props.editing }
      : { nombre: '', is_active: true }
  }
}, { immediate: true })

watch(show, (val) => { if (!val) emit('update:modelValue', false) })

function onSave() { emit('save', { ...form.value }) }
</script>
```

**Regla de watchers:**
- Si hay 2 watchers sobre el mismo `modelValue` que comparten lógica, fusionar en uno con `immediate: true`.
- Preferir `computed` sobre `watch` cuando el valor derivado no tiene side effects.
- Usar `watchEffect` para sincronizar props reactivas sin condiciones.

---

## 10. Manejo de errores

```js
// ✅ Correcto — saving siempre en finally
async function save(data) {
  saving.value = true
  try {
    await service.create(data)
    notifyOk('Creado exitosamente')
  } catch (error) {
    notifyApiError(error, 'Error al guardar')
  } finally {
    saving.value = false  // ← nunca en catch
  }
}

// ✅ Correcto — loading siempre en finally
async function fetchData() {
  loading.value = true
  try {
    const { data } = await service.list()
    rows.value = data
  } catch (error) {
    notifyError('Error al cargar')
  } finally {
    loading.value = false
  }
}

// ✅ Correcto — catch silencioso (datos secundarios que no bloquean)
async function fetchVehicles() {
  try {
    const { data } = await vehiclesService.list()
    vehicles.value = data
  } catch { /* silent */ }
}

// ✅ Correcto — catch en dialog onOk
$q.dialog({ ... }).onOk(async () => {
  try {
    await service.destroy(id)
    notifyOk('Eliminado')
  } catch (error) {
    notifyApiError(error, 'Error al eliminar')
  }
})
```

**Reglas:**
- `saving.value = false` y `loading.value = false` van en `finally`, nunca solo en `catch`.
- `catch (error)` cuando se usa la variable; `catch { /* silent */ }` cuando no.
- No usar `catch (_e)` — ESLint lanza "defined but never used".
- `notifyApiError(error, fallback)` extrae automáticamente el array `errors[]` de Rails.

---

## 11. Responsive: desktop vs mobile

```vue
<!-- Tabla: solo desktop -->
<XTable class="gt-sm" ... />

<!-- Cards: solo mobile -->
<XMobileList class="lt-md" ... />
```

**Breakpoints Quasar:**
| Clase | Equivale a |
|---|---|
| `gt-sm` | Solo en md, lg, xl (≥ 1024px) |
| `lt-md` | Solo en xs, sm (< 1024px) |
| `gt-xs` | Solo en sm, md, lg, xl (≥ 600px) |

**Cards mobile — patrón estándar:**
```vue
<div class="q-gutter-sm q-pa-md">
  <q-card v-for="item in rows" :key="item.id" flat bordered>
    <q-item>
      <q-item-section>
        <q-item-label class="text-weight-bold">{{ item.nombre }}</q-item-label>
        <q-item-label caption>{{ item.descripcion }}</q-item-label>
      </q-item-section>
      <q-item-section side>
        <q-badge :color="item.is_active ? 'positive' : 'grey'">
          {{ item.is_active ? 'Activo' : 'Inactivo' }}
        </q-badge>
      </q-item-section>
    </q-item>
    <q-separator />
    <q-card-actions align="right">
      <q-btn flat size="sm" color="primary"  icon="edit"   @click="$emit('edit', item)" />
      <q-btn flat size="sm" color="negative" icon="delete" @click="$emit('delete', item)" />
    </q-card-actions>
  </q-card>

  <div v-if="loading" class="text-center q-pa-md">
    <q-spinner color="primary" size="md" />
  </div>
  <div v-else-if="!rows.length" class="text-center text-grey q-pa-xl">
    Sin registros
  </div>
</div>
```

---

## 12. Reglas SonarCloud

| Regla | Incorrecto | Correcto |
|---|---|---|
| Empty catch | `catch { }` | `catch { /* silent */ }` |
| Unused catch var | `catch (_e) {` | `catch { /* silent */ }` o `catch (error) {` |
| saving sin finally | `catch { saving.value = false }` | `finally { saving.value = false }` |
| v-for sin key | `v-for="item in items"` | `v-for="item in items" :key="item.id"` |
| Magic numbers | `:rows-per-page-options="[10,20,50]"` | `import { PAGE_SIZES } from 'src/constants/ui'` |
| Métodos largos | función > 40 líneas | extraer a función privada o composable |
| Componente gigante | `.vue` > 400 líneas | dividir en sub-componentes |
| Import axios directo | `import axios from 'axios'` | `import { api } from 'boot/axios'` |

---

## 13. Nomenclatura y convenciones

**Archivos:**
- Componentes: `PascalCase.vue` — `EmployeeForm.vue`, `VehicleTable.vue`
- Composables: `camelCase.js` con prefijo `use` — `useFilters.js`, `useTravelCountsData.js`
- Servicios: `kebab-case.service.js` — `employees.service.js`
- Stores: `kebab-case-store.js` — `catalogs-store.js`

**Variables:**
- Listas reactivas: nombre en plural — `rows`, `employees`, `vehicles`
- Booleanos de estado: `loading`, `saving`, `showFilters`, `showForm`, `showDetail`
- Item en edición: `editingItem`, `editingEmployee`, `selectedTravel`
- Opciones de select: sufijo `Options` — `roleOptions`, `buOptions`, `filteredVehicleOptions`

**Emisiones de componentes:**
- Acciones CRUD: `@view`, `@edit`, `@delete`, `@clone`
- Formulario: `@save`, `@cancel`
- Completado: `@import-done`, `@saved`

**Props booleanas:**
- Estado: `loading`, `saving`
- Modo: `isEditing` (computed interno), nunca como prop directa

---

## 14. Checklist para módulo nuevo

Antes de dar por terminado un módulo:

**Backend (Rails):**
- [ ] Controller con `before_action`, autenticación JWT, strong params
- [ ] `includes()` en queries que traen relaciones (evitar N+1)
- [ ] Serializer o `as_json` con solo los campos necesarios
- [ ] Seed con `find_or_create_by!` para datos de catálogo

**Frontend:**
- [ ] Servicio en `src/services/<modulo>.service.js`
- [ ] Si catálogo compartido: agregado a `catalogs-store.js`
- [ ] `use<Modulo>Data.js` con `INITIAL_FILTERS` exportado
- [ ] `use<Modulo>Catalogs.js` si hay selects dinámicos
- [ ] `<Modulo>Page.vue` < 300 líneas, solo orquesta
- [ ] `<Modulo>Table.vue` con sticky header y acciones
- [ ] `<Modulo>MobileList.vue` con cards
- [ ] `<Modulo>Filters.vue` con los campos del `FilterPanel`
- [ ] `<Modulo>Form.vue` con skeleton si carga datos previos
- [ ] `saving` y `loading` siempre en bloque `finally`
- [ ] Todos los `catch` tienen `/* silent */` o usan la variable `error`
- [ ] `v-for` con `:key` basado en `id`, nunca en `index`
- [ ] Tabla y mobile responden a `gt-sm` / `lt-md`
- [ ] Botón de filtros en `PageHeader` con badge de conteo
- [ ] `onClearFilters` llama `clearFilters()` + `applyFilters()`
- [ ] `catalogsStore.invalidateAll()` en logout si el módulo usa catálogos
- [ ] Ruta registrada en `src/router/routes.js`

---

*Documento generado a partir del código real del proyecto Kumi TTPN Admin V2.*
