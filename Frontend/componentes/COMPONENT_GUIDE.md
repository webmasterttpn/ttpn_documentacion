# Guía de Componentes — Kumi TTPN Admin Frontend

Referencia para construir nuevos módulos CRUD siguiendo el estándar establecido.
Copia el bloque que necesites y ajusta los nombres de dominio.

---

## Índice

1. [Arquitectura de un módulo](#1-arquitectura-de-un-módulo)
2. [PageHeader](#2-pageheader)
3. [FilterPanel + useFilters](#3-filterpanel--usefilters)
4. [AppTable](#4-apptable)
5. [Modal estándar — Show (Details)](#5-modal-estándar--show-details)
6. [Modal estándar — Edit/Create (Form)](#6-modal-estándar--editcreate-form)
7. [Página orquestadora (Page)](#7-página-orquestadora-page)
8. [SonarCloud — Reglas a seguir](#8-sonarcloud--reglas-a-seguir)
9. [¿Pueden Details y Form ser genéricos?](#9-pueden-details-y-form-ser-genéricos)
10. [Checklist módulo nuevo](#10-checklist-módulo-nuevo)

---

## 1. Arquitectura de un módulo

```
src/pages/MiModulo/
├── MiModuloPage.vue          ← orquestador (~200 líneas)
└── components/
    ├── MiModuloDetails.vue   ← solo lectura (Show)
    └── MiModuloForm.vue      ← crear / editar
```

**Regla:** `Details` y `Form` son componentes de **dominio**, no genéricos.
Cada módulo tiene sus propios campos, validaciones y lógica de negocio.
Lo que sí es genérico y compartido: `AppTable`, `PageHeader`, `FilterPanel`.

---

## 2. PageHeader

**Archivo:** `src/components/PageHeader.vue`

### Props

| Prop       | Tipo   | Requerido | Descripción          |
|------------|--------|-----------|----------------------|
| `title`    | String | ✓         | Título principal     |
| `subtitle` | String |           | Subtítulo gris       |

### Slot

| Slot      | Descripción                              |
|-----------|------------------------------------------|
| `actions` | Botones de acción (filtros, nuevo, etc.) |

### Uso

```vue
<PageHeader title="Empleados" subtitle="Gestión de plantilla laboral">
  <template #actions>
    <q-btn color="grey-7" icon="filter_list" outline round @click="toggleFilters">
      <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
        {{ activeFiltersCount }}
      </q-badge>
      <q-tooltip>{{ showFilters ? 'Ocultar Filtros' : 'Mostrar Filtros' }}</q-tooltip>
    </q-btn>
    <q-btn unelevated color="primary" icon="add" label="Nuevo" @click="openCreateDialog" />
  </template>
</PageHeader>
```

---

## 3. FilterPanel + useFilters

**Archivo:** `src/components/FilterPanel.vue`

### Props

| Prop          | Tipo    | Descripción                               |
|---------------|---------|-------------------------------------------|
| `modelValue`  | Boolean | Controla visibilidad (usa `v-model`)      |
| `activeCount` | Number  | Número de filtros activos                 |

### Emits

| Evento  | Descripción                    |
|---------|-------------------------------|
| `clear` | Usuario pulsó "Limpiar filtros"|

### Composable useFilters

```javascript
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } = useFilters({
  search: null,
  status: null,
  // ... más filtros
})
```

- `filters` — ref reactivo con los valores actuales
- `showFilters` — controla si el panel está visible
- `activeFiltersCount` — cuenta de filtros no-nulos
- `toggleFilters()` — abre/cierra el panel
- `clearFilters()` — resetea todos a null

### Uso completo

```vue
<template>
  <!-- Botón en PageHeader -->
  <q-btn color="grey-7" icon="filter_list" outline round @click="toggleFilters">
    <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
      {{ activeFiltersCount }}
    </q-badge>
  </q-btn>

  <!-- Panel de filtros -->
  <FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
    <div class="col-12 col-md-4">
      <q-input
        v-model="filters.search"
        dense outlined clearable
        placeholder="Buscar..."
        @update:model-value="fetchItems"
      >
        <template #prepend><q-icon name="search" /></template>
      </q-input>
    </div>
    <div class="col-6 col-md-2">
      <q-select
        dense outlined clearable
        v-model="filters.status"
        :options="statusOptions"
        label="Estatus"
        emit-value map-options
        @update:model-value="fetchItems"
      />
    </div>
  </FilterPanel>
</template>

<script setup>
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } = useFilters({
  search: null,
  status: null,
})

function onClearFilters() {
  clearFilters()
  fetchItems()
}
</script>
```

---

## 4. AppTable

**Archivo:** `src/components/AppTable.vue`

### Props

| Prop                 | Tipo     | Default             | Descripción                              |
|----------------------|----------|---------------------|------------------------------------------|
| `rows`               | Array    | `[]`                | Datos a mostrar                          |
| `columns`            | Array    | requerido           | Definición de columnas Quasar            |
| `loading`            | Boolean  | `false`             | Spinner de carga                         |
| `pagination`         | Object   | `{rowsPerPage:20}`  | Paginación inicial                       |
| `selection`          | String   | `'multiple'`        | `'none'` \| `'single'` \| `'multiple'`  |
| `selected`           | Array    | `[]`                | Filas seleccionadas (v-model)            |
| `rowClass`           | Function | `() => ''`          | Clase CSS dinámica por fila              |
| `flat`               | Boolean  | `true`              | Sin sombra en el card                    |
| `rowsPerPageOptions` | Array    | `[10,20,50,100]`    | Opciones del selector de filas           |

### Emits

| Evento           | Payload      | Descripción               |
|------------------|--------------|---------------------------|
| `update:selected`| Array        | Cambio en selección       |

### Slots de celda

Nombre: `cell-{column.name}`

```vue
<template #cell-status="{ row }">
  <q-badge :color="row.status ? 'positive' : 'negative'"
           :label="row.status ? 'Activo' : 'Inactivo'" />
</template>

<template #cell-actions="{ row }">
  <q-btn flat dense round icon="visibility" color="primary" @click="viewItem(row)" />
  <q-btn flat dense round icon="edit"       color="primary" @click="editItem(row)" />
  <q-btn flat dense round icon="delete"     color="negative" @click="deleteItem(row)" />
</template>
```

### Definición de columnas (ejemplo)

```javascript
const columns = [
  { name: 'status',   align: 'center', label: 'Estatus', field: 'status',             sortable: true },
  { name: 'clv',      align: 'left',   label: 'CLV',     field: 'clv',                sortable: true },
  { name: 'nombre',   align: 'left',   label: 'Nombre',  field: 'nombre_completo',    sortable: true },
  { name: 'area',     align: 'left',   label: 'Área',    field: row => row.area || '-', sortable: true },
  { name: 'actions',  align: 'right',  label: 'Acciones' },
]
```

### Uso completo

```vue
<AppTable
  class="gt-sm"
  :rows="rows"
  :columns="columns"
  :loading="loading"
  :pagination="{ rowsPerPage: 20, sortBy: 'status', descending: true }"
  selection="none"
>
  <template #cell-status="{ row }">
    <q-badge :color="row.status ? 'positive' : 'negative'"
             :label="row.status ? 'Activo' : 'Inactivo'" />
  </template>
  <template #cell-actions="{ row }">
    <q-btn flat dense round icon="visibility" color="primary" @click="viewItem(row)" />
    <q-btn flat dense round icon="edit"       color="primary" @click="editItem(row)" />
    <q-btn flat dense round icon="delete"     color="negative" @click="deleteItem(row)" />
  </template>
</AppTable>
```

---

## 5. Modal estándar — Show (Details)

**Archivo:** `src/pages/MiModulo/components/MiModuloDetails.vue`

### Dimensiones estándar

```
width: 900px | max-width: 95vw | height: 85vh
```

### Props / Emits

```javascript
defineProps({ item: { type: Object, required: true } })
defineEmits(['close', 'edit'])
```

### Estructura base (copiar y ajustar campos)

```vue
<template>
  <q-card style="width: 900px; max-width: 95vw; height: 85vh; display: flex; flex-direction: column; margin: auto;">

    <!-- Header -->
    <q-card-section class="row items-center q-pb-none" style="flex-shrink: 0;">
      <div class="text-h6">{{ item.clv }} — {{ item.nombre }}</div>
      <q-space />
      <q-btn flat round dense icon="edit" color="primary" @click="$emit('edit', item)">
        <q-tooltip>Editar</q-tooltip>
      </q-btn>
      <q-btn flat round dense icon="close" @click="$emit('close')" />
    </q-card-section>

    <q-separator style="flex-shrink: 0;" />

    <!-- Contenido con scroll -->
    <q-scroll-area style="flex: 1;">
      <q-card-section class="q-pa-md">
        <!-- Si el modal tiene tabs: -->
        <!-- <q-tabs v-model="tab" dense ... align="left" narrow-indicator outside-arrows mobile-arrows> -->

        <div class="row q-col-gutter-md">

          <!-- Sección -->
          <div class="col-12">
            <div class="text-subtitle2 text-primary q-mb-sm">Identificación</div>
            <div class="row q-col-gutter-sm">
              <div class="col-6 col-sm-3">
                <div class="text-caption text-grey-6">CLV</div>
                <div class="text-body2 text-weight-medium">{{ item.clv || '—' }}</div>
              </div>
              <!-- más campos... -->
            </div>
          </div>

        </div>
      </q-card-section>
    </q-scroll-area>

    <!-- Footer -->
    <q-separator style="flex-shrink: 0;" />
    <q-card-actions align="right" class="q-pa-md" style="flex-shrink: 0;">
      <q-btn flat color="grey-8" label="Cerrar" @click="$emit('close')" />
      <q-btn unelevated color="primary" icon="edit" label="Editar" @click="$emit('edit', item)" />
    </q-card-actions>

  </q-card>
</template>

<script setup>
defineProps({ item: { type: Object, required: true } })
defineEmits(['close', 'edit'])
</script>
```

### Si el modal tiene tabs

```vue
<!-- Entre el header y el scroll-area -->
<q-tabs
  v-model="tab"
  dense class="text-grey"
  active-color="primary" indicator-color="primary"
  align="left" narrow-indicator outside-arrows mobile-arrows
  style="flex-shrink: 0;"
>
  <q-tab name="general"  label="General"    />
  <q-tab name="detalle"  label="Detalle"    />
</q-tabs>
<q-separator style="flex-shrink: 0;" />

<!-- Dentro del scroll-area -->
<q-scroll-area style="flex: 1;">
  <q-tab-panels v-model="tab" animated>
    <q-tab-panel name="general"> ... </q-tab-panel>
    <q-tab-panel name="detalle"> ... </q-tab-panel>
  </q-tab-panels>
</q-scroll-area>
```

---

## 6. Modal estándar — Edit/Create (Form)

**Archivo:** `src/pages/MiModulo/components/MiModuloForm.vue`

### Props / Emits

```javascript
// item = null → crear nuevo | item con id → editar
defineProps({ item: { type: Object, default: null } })
defineEmits(['saved', 'cancel'])
const isEditing = computed(() => !!props.item?.id)
```

### Título dinámico

```vue
<div class="text-h6">{{ isEditing ? `Editar: ${form.clv}` : 'Nuevo Elemento' }}</div>
```

### Patrón watch para hidratar el form

```javascript
const formDefault = {
  clv: '', nombre: '', status: true,
  // nested: nested_attributes: []
}
const form = ref({ ...formDefault })

watch(() => props.item, (item) => {
  if (item) {
    form.value = JSON.parse(JSON.stringify(item))
    // mapear nested si aplica:
    // form.value.nested_attributes = item.nested || []
  } else {
    form.value = JSON.parse(JSON.stringify(formDefault))
  }
}, { immediate: true })
```

### Patrón save (el Form hace el API call)

```javascript
const saving = ref(false)

async function saveItem() {
  if (!form.value.clv) { notifyWarn('Completa los campos obligatorios'); return }
  saving.value = true
  try {
    if (isEditing.value) {
      await miService.update(form.value.id, { item: form.value })
      notifyOk('Actualizado')
    } else {
      await miService.create({ item: form.value })
      notifyOk('Creado')
    }
    emit('saved')
  } catch (e) {
    notifyError(e.response?.data?.error || 'Error al guardar')
  } finally {
    saving.value = false
  }
}
```

### Footer del form

```vue
<q-separator style="flex-shrink: 0;" />
<q-card-actions align="right" class="q-pa-md" style="flex-shrink: 0;">
  <q-btn outline label="Cancelar" color="grey-8" @click="$emit('cancel')" />
  <q-btn unelevated color="primary" label="Guardar" @click="saveItem" :loading="saving" />
</q-card-actions>
```

### Nested attributes — patrón add/remove

```javascript
function addNested() {
  form.value.nested_attributes.push({
    _uid: Date.now() + Math.random(),
    campo: '',
    status: true
  })
}

function removeNested(index) {
  const item = form.value.nested_attributes[index]
  if (item.id) item._destroy = true          // existente → marcar para destruir
  else form.value.nested_attributes.splice(index, 1)  // nuevo → eliminar del array
}

const visibleNested = computed(() =>
  form.value.nested_attributes.filter(n => !n._destroy)
)
```

---

## 7. Página orquestadora (Page)

**Archivo:** `src/pages/MiModulo/MiModuloPage.vue`

Responsabilidades: fetching, filtros, dialogs, delete. No contiene lógica de form ni de detalle.

### Estructura completa (copiar y adaptar)

```vue
<template>
  <q-page class="bg-grey-2">
    <div class="q-pa-md">

      <PageHeader title="Mi Módulo" subtitle="Descripción breve">
        <template #actions>
          <q-btn color="grey-7" icon="filter_list" outline round @click="toggleFilters">
            <q-badge v-if="activeFiltersCount > 0" color="primary" floating>{{ activeFiltersCount }}</q-badge>
          </q-btn>
          <q-btn unelevated color="primary" icon="add" label="Nuevo" @click="openCreateDialog" />
        </template>
      </PageHeader>

      <FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">
        <div class="col-12 col-md-4">
          <q-input v-model="filters.search" dense outlined clearable placeholder="Buscar..."
            @update:model-value="fetchItems">
            <template #prepend><q-icon name="search" /></template>
          </q-input>
        </div>
      </FilterPanel>

      <!-- Desktop -->
      <AppTable class="gt-sm" :rows="rows" :columns="columns" :loading="loading"
        :pagination="{ rowsPerPage: 20 }" selection="none">
        <template #cell-status="{ row }">
          <q-badge :color="row.status ? 'positive' : 'negative'"
                   :label="row.status ? 'Activo' : 'Inactivo'" />
        </template>
        <template #cell-actions="{ row }">
          <q-btn flat dense round icon="visibility" color="primary" @click="viewItem(row)" />
          <q-btn flat dense round icon="edit"       color="primary" @click="editItem(row)" />
          <q-btn flat dense round icon="delete"     color="negative" @click="deleteItem(row)" />
        </template>
      </AppTable>

      <!-- Mobile -->
      <div class="lt-md">
        <div v-if="loading" class="flex flex-center q-pa-xl">
          <q-spinner color="primary" size="40px" />
        </div>
        <div v-else-if="rows.length === 0" class="text-center q-pa-xl text-grey-6">
          <q-icon name="inbox" size="48px" />
          <div class="q-mt-sm">No se encontraron registros</div>
        </div>
        <div v-else class="q-gutter-sm">
          <q-card v-for="row in rows" :key="row.id" flat bordered>
            <q-item>
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ row.nombre }}</q-item-label>
                <q-item-label caption>{{ row.clv }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge :color="row.status ? 'positive' : 'negative'"
                         :label="row.status ? 'Activo' : 'Inactivo'" />
              </q-item-section>
            </q-item>
            <q-separator />
            <q-card-actions align="right">
              <q-btn flat round icon="visibility" color="grey-7" @click="viewItem(row)" />
              <q-btn flat round icon="edit"       color="primary" @click="editItem(row)" />
              <q-btn flat round icon="delete"     color="negative" @click="deleteItem(row)" />
            </q-card-actions>
          </q-card>
        </div>
      </div>

    </div>

    <!-- Diálogo Ver -->
    <q-dialog v-model="showDetailsDialog" :maximized="$q.screen.lt.sm">
      <MiModuloDetails
        v-if="selectedItem"
        :item="selectedItem"
        @close="showDetailsDialog = false"
        @edit="editFromDetails"
      />
    </q-dialog>

    <!-- Diálogo Crear/Editar -->
    <q-dialog v-model="showFormDialog" persistent :maximized="$q.screen.lt.sm">
      <MiModuloForm
        :item="selectedItem"
        @saved="onSaved"
        @cancel="showFormDialog = false"
      />
    </q-dialog>

  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useNotify }  from 'src/composables/useNotify'
import { useFilters } from 'src/composables/useFilters'
import { miService }  from 'src/services/mi-modulo.service'
import PageHeader      from 'src/components/PageHeader.vue'
import AppTable        from 'src/components/AppTable.vue'
import FilterPanel     from 'src/components/FilterPanel.vue'
import MiModuloDetails from './components/MiModuloDetails.vue'
import MiModuloForm    from './components/MiModuloForm.vue'

const $q = useQuasar()
const { notifyOk, notifyError } = useNotify()
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } = useFilters({
  search: null,
  status: null,
})

const rows             = ref([])
const loading          = ref(false)
const showDetailsDialog = ref(false)
const showFormDialog    = ref(false)
const selectedItem      = ref(null)

const columns = [
  { name: 'status',  align: 'center', label: 'Estatus', field: 'status',  sortable: true },
  { name: 'clv',     align: 'left',   label: 'CLV',     field: 'clv',     sortable: true },
  { name: 'nombre',  align: 'left',   label: 'Nombre',  field: 'nombre',  sortable: true },
  { name: 'actions', align: 'right',  label: 'Acciones' },
]

async function fetchItems() {
  loading.value = true
  try {
    const params = {}
    if (filters.value.search) params.search = filters.value.search
    if (filters.value.status != null) params.status = filters.value.status
    const res = await miService.list(params)
    rows.value = res.data
  } catch (_e) {
    notifyError('Error al cargar')
  } finally {
    loading.value = false
  }
}

function onClearFilters() { clearFilters(); fetchItems() }

async function viewItem(row) {
  try {
    const { data } = await miService.find(row.id)
    selectedItem.value = data
  } catch (_e) {
    selectedItem.value = row
  }
  showDetailsDialog.value = true
}

function openCreateDialog() {
  selectedItem.value = null
  showFormDialog.value = true
}

async function editItem(row) {
  try {
    const { data } = await miService.find(row.id)
    selectedItem.value = data
  } catch (_e) {
    selectedItem.value = row
  }
  showFormDialog.value = true
}

function editFromDetails(item) {
  showDetailsDialog.value = false
  selectedItem.value = item
  showFormDialog.value = true
}

function onSaved() {
  showFormDialog.value = false
  fetchItems()
}

function deleteItem(row) {
  $q.dialog({
    title: 'Eliminar',
    message: `¿Eliminar "${row.nombre}"?`,
    cancel: true, persistent: true,
    ok: { label: 'Eliminar', color: 'negative', flat: true }
  }).onOk(async () => {
    try {
      await miService.destroy(row.id)
      notifyOk('Eliminado')
      fetchItems()
    } catch (_e) {
      notifyError('No se pudo eliminar')
    }
  })
}

onMounted(fetchItems)
</script>
```

---

## 8. SonarCloud — Reglas a seguir

### ✅ DO

```javascript
// Catch vacío: nombrar el parámetro con _ para indicar descarte intencional
try {
  await algo()
} catch (_e) {
  // silent — fallo no crítico
}

// Variables de loading: solo cuando el componente hace el API call directamente
const saving = ref(false)
try {
  await service.save(...)
  emit('saved')
} catch (_e) {
  notifyError(...)
} finally {
  saving.value = false   // siempre resetear en finally
}
```

### ❌ DON'T

```javascript
// ❌ saving que nunca resetea (queda bloqueado para siempre)
function saveClient() {
  saving.value = true
  emit('save', form.value)  // el padre hace el call, saving nunca vuelve a false
}

// ❌ catch vacío sin nombre (SonarCloud warning)
try { ... } catch { }

// ❌ variable declarada y nunca usada
const unusedRef = ref(null)

// ❌ v-if y v-for en el mismo elemento
<div v-for="item in items" v-if="item.active">  ← usar computed filtrado
```

### Patrón: Form delega vs Form guarda

| Patrón | Cuándo usar | Loading |
|--------|-------------|---------|
| Form emite datos, Page guarda | Cuando Page necesita controlar el flujo (raro) | `saving` vive en Page |
| Form hace el API call directamente | **Preferido** — Form es autónomo | `saving` vive en Form, resetea en `finally` |

---

## 9. ¿Pueden Details y Form ser genéricos?

**No.** Y es la decisión correcta.

`ClientDetails`, `EmployeeForm`, etc. son **componentes de dominio**, no de UI.
Contienen campos específicos, validaciones de negocio, nested attributes propios y lógica irreproducible con parámetros.

Lo que sí es genérico (y ya existe):

| Componente      | Ruta                            | Es genérico |
|-----------------|---------------------------------|-------------|
| `AppTable`      | `src/components/AppTable.vue`   | ✓           |
| `PageHeader`    | `src/components/PageHeader.vue` | ✓           |
| `FilterPanel`   | `src/components/FilterPanel.vue`| ✓           |

La **consistencia** entre módulos viene de seguir el mismo patrón estructural
(dimensiones del card, tabs estándar, footer fijo, scroll-area), no de compartir código.

---

## 10. Checklist módulo nuevo

```
[ ] src/services/mi-modulo.service.js        ← list, find, create, update, destroy
[ ] src/pages/MiModulo/MiModuloPage.vue      ← orquestador (copiar de sección 7)
[ ] src/pages/MiModulo/components/
    [ ] MiModuloDetails.vue                  ← solo lectura (copiar de sección 5)
    [ ] MiModuloForm.vue                     ← crear/editar (copiar de sección 6)
[ ] Agregar ruta en src/router/routes.js
[ ] Agregar ítem de menú en src/layouts/MainLayout.vue (o donde corresponda)
```

### Service mínimo

```javascript
// src/services/mi-modulo.service.js
import { api } from 'boot/axios'

export const miModuloService = {
  list:    (params = {}) => api.get('/mi_modulo',        { params }),
  find:    (id)          => api.get(`/mi_modulo/${id}`),
  create:  (data)        => api.post('/mi_modulo',        data),
  update:  (id, data)    => api.put(`/mi_modulo/${id}`,   data),
  destroy: (id)          => api.delete(`/mi_modulo/${id}`),
}
```

---

*Última actualización: módulo de referencia = Clients (con ClientForm, ClientDetails, ClientsPage)*
