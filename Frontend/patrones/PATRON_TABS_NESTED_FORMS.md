# 📘 Patrón de Tabs y Nested Forms Dinámicas

## 🎯 Basado en VehiclesPage.vue

Este documento explica el patrón usado en Vehículos para implementarlo en Empleados.

---

## 🏗️ Estructura del Dialog con Tabs

### 1. Dialog Principal

```vue
<q-dialog v-model="dialogOpen" :maximized="$q.screen.lt.sm" persistent>
  <q-card style="width: 900px; max-width: 100vw;">
    <!-- Toolbar -->
    <q-toolbar class="bg-white text-primary shadow-1">
      <q-toolbar-title>{{ isEditing ? 'Editar' : 'Nuevo' }} Empleado</q-toolbar-title>
      <q-btn flat round dense icon="close" v-close-popup />
    </q-toolbar>

    <!-- Tabs Principales -->
    <q-card-section class="q-pa-none">
      <q-tabs v-model="tab" dense>
        <q-tab name="general" label="Datos Generales" icon="person" />
        <q-tab name="docs" label="Documentos" icon="folder" />
        <q-tab name="salaries" label="Salarios" icon="payments" />
        <q-tab name="movements" label="Movimientos" icon="swap_horiz" />
      </q-tabs>
      <q-separator />

      <!-- Tab Panels -->
      <q-tab-panels v-model="tab" animated>
        <!-- Contenido de cada tab -->
      </q-tab-panels>
    </q-card-section>

    <!-- Botones de Acción -->
    <q-separator />
    <q-card-actions align="right">
      <q-btn outline label="Cancelar" v-close-popup />
      <q-btn unelevated color="primary" label="Guardar Todo" @click="saveEmployee" />
    </q-card-actions>
  </q-card>
</q-dialog>
```

---

## 📑 Tab de Nested Forms (Documentos)

### Estructura de 3 Niveles

#### Nivel 1: Tabs Horizontales de Documentos

```vue
<q-tab-panel name="docs" class="q-pa-md bg-grey-1">
  <!-- Header con tabs de documentos + botón agregar -->
  <div class="row items-center q-mb-md">
    <div class="col-grow">
      <q-tabs
        v-model="activeDocIndex"
        dense
        active-color="primary"
        align="left"
        outside-arrows
        mobile-arrows
      >
        <template v-for="(doc, index) in form.employee_documents_attributes" :key="index">
          <q-tab
            v-if="!doc._destroy"
            :name="index"
            :label="getDocumentLabel(doc, index)"
            :class="hasError(doc) ? 'text-negative' : ''"
          />
        </template>
      </q-tabs>
    </div>
    <div class="col-auto">
      <q-btn color="primary" icon="add" label="Agregar Nuevo" @click="addDocument" />
    </div>
  </div>

  <!-- Contenido de cada documento -->
  <q-tab-panels v-model="activeDocIndex" animated>
    <!-- Panel por cada documento -->
  </q-tab-panels>
</q-tab-panel>
```

#### Nivel 2: Panel de Cada Documento

```vue
<q-tab-panel v-for="(doc, index) in form.employee_documents_attributes" :key="index" :name="index">
  <div v-if="!doc._destroy">
    <q-card flat bordered>
      <q-card-section>
        <!-- Header con título y botón eliminar -->
        <div class="row items-center justify-between q-mb-md">
          <div class="text-subtitle2 text-primary">
            Editando: {{ getDocumentLabel(doc, index) }}
          </div>
          <q-btn
            flat
            label="Eliminar Documento"
            icon="delete"
            color="negative"
            @click="removeDocument(index)"
          />
        </div>

        <!-- Formulario del documento -->
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-select
              v-model="doc.employee_document_type_id"
              :options="documentTypeOptions"
              label="Tipo de Documento"
              emit-value
              map-options
              option-value="id"
              option-label="nombre"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model="doc.numero" label="Número / Folio" />
          </div>
          <!-- Más campos... -->
        </div>
      </q-card-section>
    </q-card>
  </div>
</q-tab-panel>
```

---

## 🔧 Lógica de Nested Forms

### Estado en Script

```javascript
const form = ref({
  id: null,
  nombre: '',
  // ... otros campos
  employee_documents_attributes: [],
  employee_salaries_attributes: [],
  employee_movements_attributes: [],
})

const activeDocIndex = ref(0)
```

### Agregar Documento

```javascript
function addDocument() {
  form.value.employee_documents_attributes.push({
    employee_document_type_id: null,
    numero: '',
    expiracion: '',
    descripcion: '',
  })

  // Cambiar a la nueva pestaña
  setTimeout(() => {
    activeDocIndex.value = form.value.employee_documents_attributes.length - 1
  }, 100)
}
```

### Eliminar Documento

```javascript
function removeDocument(index) {
  const doc = form.value.employee_documents_attributes[index]

  if (doc.id) {
    // Si tiene ID, marcarlo para destruir (Rails nested attributes)
    doc._destroy = true

    // Cambiar a la primera pestaña visible
    const firstVisible = form.value.employee_documents_attributes.findIndex((d) => !d._destroy)
    activeDocIndex.value = firstVisible !== -1 ? firstVisible : 0
  } else {
    // Si no tiene ID, eliminarlo del array
    form.value.employee_documents_attributes.splice(index, 1)
    activeDocIndex.value = Math.max(0, index - 1)
  }
}
```

### Helpers

```javascript
// Contador de documentos visibles
const visibleDocumentsCount = computed(() => {
  return form.value.employee_documents_attributes
    ? form.value.employee_documents_attributes.filter((d) => !d._destroy).length
    : 0
})

// Label del tab
function getDocumentLabel(doc, index) {
  if (doc.employee_document_type?.nombre) {
    return doc.employee_document_type.nombre
  }
  if (doc.employee_document_type_id) {
    const type = documentTypeOptions.value.find((t) => t.id === doc.employee_document_type_id)
    return type?.nombre || `Doc ${index + 1}`
  }
  return `Doc ${index + 1}`
}

// Validación visual
function hasError(doc) {
  return !doc.employee_document_type_id || !doc.numero
}
```

---

## 💾 Guardar con Nested Attributes

### Payload al Backend

```javascript
async function saveEmployee() {
  const payload = {
    employee: {
      ...form.value,
      // Rails acepta nested attributes automáticamente
      employee_documents_attributes: form.value.employee_documents_attributes,
      employee_salaries_attributes: form.value.employee_salaries_attributes,
    },
  }

  if (isEditing.value) {
    await api.put(`/api/v1/employees/${form.value.id}`, payload)
  } else {
    await api.post('/api/v1/employees', payload)
  }
}
```

### Backend (Rails)

```ruby
# app/models/employee.rb
accepts_nested_attributes_for :employee_documents,
  allow_destroy: true,
  reject_if: proc { |att| att['employee_document_type_id'].blank? }

# app/controllers/api/v1/employees_controller.rb
def employee_params
  params.require(:employee).permit(
    :nombre, :apaterno, :amaterno,
    # ... otros campos
    employee_documents_attributes: [
      :id, :employee_document_type_id, :numero, :expiracion, :descripcion, :_destroy
    ],
    employee_salaries_attributes: [
      :id, :sdi, :sueldo_diario, :fecha_inicio, :_destroy
    ]
  )
end
```

---

## 📤 Upload de Archivos

### Dialog de Upload

```vue
<q-dialog v-model="uploadDialog.open">
  <q-card style="width: 400px">
    <q-card-section>
      <div class="text-h6">Subir Documento</div>
    </q-card-section>
    <q-card-section>
      <q-file
        v-model="uploadDialog.file"
        label="Seleccionar archivo"
        accept="image/*, .pdf"
      />
    </q-card-section>
    <q-card-actions align="right">
      <q-btn flat label="Cancelar" v-close-popup />
      <q-btn
        color="primary"
        label="Subir"
        @click="uploadFile"
        :loading="uploadDialog.uploading"
      />
    </q-card-actions>
  </q-card>
</q-dialog>
```

### Lógica de Upload

```javascript
const uploadDialog = ref({
  open: false,
  file: null,
  docId: null,
  uploading: false,
})

function openUploadDialog(doc) {
  uploadDialog.value.docId = doc.id
  uploadDialog.value.file = null
  uploadDialog.value.open = true
}

async function uploadFile() {
  if (!uploadDialog.value.file || !uploadDialog.value.docId) return

  uploadDialog.value.uploading = true
  try {
    const formData = new FormData()
    formData.append('employee_document[doc_image]', uploadDialog.value.file)

    await api.put(`/api/v1/employee_documents/${uploadDialog.value.docId}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })

    $q.notify({ color: 'positive', message: 'Archivo subido' })
    uploadDialog.value.open = false

    // Recargar datos
    await fetchData()
  } catch (e) {
    $q.notify({ color: 'negative', message: 'Error al subir' })
  } finally {
    uploadDialog.value.uploading = false
  }
}
```

---

## 🎨 Estilos y UX

### Estado Vacío

```vue
<div v-if="visibleDocumentsCount === 0" class="text-center q-pa-xl text-grey-6">
  <q-icon name="folder_off" size="40px" />
  <div class="q-mt-sm">No hay documentos registrados</div>
  <div class="text-caption">Haz clic en "Agregar Nuevo" para comenzar</div>
</div>
```

### Indicador de Error en Tab

```vue
<q-tab
  :name="index"
  :label="getDocumentLabel(doc, index)"
  :class="hasError(doc) ? 'text-negative' : ''"
/>
```

### Responsive

```vue
<!-- Maximizar dialog en móvil -->
<q-dialog :maximized="$q.screen.lt.sm"></q-dialog>
```

---

## 📋 Checklist de Implementación

### Para Empleados

- [ ] Crear estructura de tabs (General, Documentos, Salarios, Movimientos)
- [ ] Implementar nested forms para documentos
- [ ] Implementar nested forms para salarios
- [ ] Implementar nested forms para movimientos
- [ ] Agregar lógica de add/remove
- [ ] Implementar upload de archivos
- [ ] Validaciones visuales
- [ ] Estados vacíos
- [ ] Responsive design

---

## 🎯 Ventajas del Patrón

1. **Organización:** Datos complejos en tabs separados
2. **UX:** Fácil navegación entre documentos
3. **Validación:** Visual en tabs con errores
4. **Performance:** Solo carga lo necesario
5. **Responsive:** Se adapta a móvil
6. **Escalable:** Fácil agregar más tabs

---

## 🚀 Próximo Paso

Implementar EmployeesPage.vue siguiendo este patrón exacto.

**Archivo de referencia:** `src/pages/VehiclesPage.vue`
