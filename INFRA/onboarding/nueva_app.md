# Nueva PWA con el Backend TTPN — Guía de Inicio

Esta guía explica cómo arrancar una nueva PWA (Quasar + Vue 3) que consuma la API de TTPN, siguiendo los mismos patrones, estructura y convenciones que Kumi Admin.

Úsala cuando necesites crear una app nueva para un cliente, módulo externo, portal de captura, o cualquier interfaz adicional que use nuestra base de datos y servicios.

---

## Tabla de Contenidos

1. [Requisitos](#1-requisitos)
2. [Crear el proyecto Quasar](#2-crear-el-proyecto-quasar)
3. [Estructura de carpetas obligatoria](#3-estructura-de-carpetas-obligatoria)
4. [Configurar Axios y conexión al BE](#4-configurar-axios-y-conexión-al-be)
5. [Autenticación JWT](#5-autenticación-jwt)
6. [Stores (Pinia)](#6-stores-pinia)
7. [Router y guards de navegación](#7-router-y-guards-de-navegación)
8. [Servicios (capa de API)](#8-servicios-capa-de-api)
9. [Composables estándar](#9-composables-estándar)
10. [Patrón de página](#10-patrón-de-página)
11. [Componentes globales recomendados](#11-componentes-globales-recomendados)
12. [Configurar como PWA](#12-configurar-como-pwa)
13. [Variables de entorno](#13-variables-de-entorno)
14. [Despliegue en Netlify](#14-despliegue-en-netlify)
15. [Checklist de nueva app](#15-checklist-de-nueva-app)

---

## 1. Requisitos

| Herramienta | Versión mínima |
| --- | --- |
| Node.js | 18+ |
| npm | 9+ |
| Quasar CLI | 2.4+ |
| Vue | 3.4+ |

```bash
npm install -g @quasar/cli
```

---

## 2. Crear el proyecto Quasar

```bash
npm create quasar@latest mi-nueva-app

# Seleccionar:
# ✓ Quasar App with Vite
# ✓ JavaScript (no TypeScript — convencion del proyecto)
# ✓ Vue 3 (Composition API con <script setup>)
# ✓ Pinia
# ✓ Axios
# ✓ ESLint + Prettier
```

Instalar dependencias adicionales requeridas:

```bash
cd mi-nueva-app
npm install pinia-plugin-persistedstate
npm install dotenv
```

---

## 3. Estructura de carpetas obligatoria

```text
src/
├── boot/
│   └── axios.js           # Interceptor JWT + baseURL
│
├── stores/
│   ├── auth-store.js      # Sesión y JWT
│   └── privileges-store.js # Permisos por módulo
│
├── router/
│   ├── index.js           # Configuración + guards
│   └── routes.js          # Definición de rutas
│
├── services/              # Una función por endpoint, sin lógica de UI
│   └── [modulo].service.js
│
├── composables/
│   ├── useNotify.js        # Notificaciones Quasar
│   ├── useFilters.js       # Estado de filtros
│   ├── useCrud.js          # CRUD genérico
│   ├── usePrivileges.js    # Guards de UI por permiso
│   └── dropdowns/          # Catálogos cacheados
│       └── use[Entidad]Dropdown.js
│
├── components/             # Componentes reutilizables
│   ├── AppTable.vue        # Tabla estándar con paginación
│   ├── FilterPanel.vue     # Panel colapsable de filtros
│   └── PageHeader.vue      # Header con título y acciones
│
├── pages/
│   └── [Modulo]/
│       ├── [Modulo]Page.vue    # Página principal (orquestador)
│       └── components/        # Componentes locales del módulo
│
└── layouts/
    └── MainLayout.vue      # Layout con sidebar + header
```

---

## 4. Configurar Axios y conexión al BE

Copiar este archivo como `src/boot/axios.js`:

```javascript
import { defineBoot } from '#q-app/wrappers'
import axios from 'axios'

const api = axios.create({
  baseURL: '/',  // El proxy de quasar.config.js redirige al BE
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    // Requerido para VS Code tunnels o ngrok:
    'X-Tunnel-Skip-Anti-Phishing-Page': 'true',
  },
})

export default defineBoot(({ app, router }) => {
  app.config.globalProperties.$axios = axios
  app.config.globalProperties.$api = api

  // ── INTERCEPTOR DE REQUEST ────────────────────────────────────────
  api.interceptors.request.use((config) => {
    const jwt = localStorage.getItem('jwt_token')

    const authRoutes = ['/auth/login', '/auth/logout', '/client_auth']
    const isAuthRoute = authRoutes.some(route => config.url?.includes(route))

    if (jwt) {
      config.headers.set('Authorization', `Bearer ${jwt}`)
    }

    // business_unit_id en todos los requests excepto auth
    if (!isAuthRoute) {
      const buId = localStorage.getItem('selected_business_unit_id')
      if (buId) {
        config.params = { ...config.params, business_unit_id: buId }
      }
    }

    return config
  })

  // ── INTERCEPTOR DE RESPUESTA ─────────────────────────────────────
  api.interceptors.response.use(
    (response) => response,
    async (error) => {
      // Convertir Blob a JSON en errores de descarga
      if (error.response?.data instanceof Blob) {
        try {
          const text = await error.response.data.text()
          error.response.data = JSON.parse(text)
        } catch { /* mantener error original */ }
      }

      // 401 → limpiar sesión y redirigir a login
      if (error.response?.status === 401) {
        const { useAuthStore } = await import('stores/auth-store')
        const authStore = useAuthStore()
        authStore.user = null
        localStorage.removeItem('jwt_token')

        if (router.currentRoute.value.path !== '/login') {
          router.push('/login')
        }
      }

      return Promise.reject(error)
    }
  )
})

export { api }
```

### Configurar el proxy en `quasar.config.js`

```javascript
import dotenv from 'dotenv'
dotenv.config()

export default defineConfig(() => ({
  boot: ['axios'],
  css: ['app.scss'],
  extras: ['roboto-font', 'material-icons'],

  build: {
    vueRouterMode: 'history',
    env: {
      API_URL: process.env.API_URL,
    },
  },

  devServer: {
    port: 9000,
    proxy: {
      '/api': {
        target: process.env.API_URL || 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },

  framework: {
    plugins: ['Notify', 'Dialog', 'Loading'],
  },

  pwa: {
    workboxMode: 'GenerateSW',
    manifest: {
      name: 'Mi App TTPN',
      short_name: 'MiApp',
      description: 'Descripción de la app',
      display: 'standalone',
      background_color: '#ffffff',
      theme_color: '#027be3',
      icons: [
        { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
      ],
    },
  },
}))
```

---

## 5. Autenticación JWT

El BE usa Devise + JWT. El flujo es:

```
POST /api/v1/auth/login  →  { access_token, user, privileges }
DELETE /api/v1/auth/logout
GET  /api/v1/auth/me
```

Copiar como `src/stores/auth-store.js`:

```javascript
import { defineStore } from 'pinia'
import { api } from 'boot/axios'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
  }),

  getters: {
    isAuthenticated: (state) => !!state.user,
  },

  actions: {
    async login(email, password) {
      localStorage.removeItem('jwt_token')

      const response = await api.post('/api/v1/auth/login', { email, password })

      const token = response.data.access_token
      localStorage.setItem('jwt_token', token)
      this.user = response.data.user

      // Cargar privilegios del usuario
      const { usePrivilegesStore } = await import('./privileges-store')
      const privilegesStore = usePrivilegesStore()
      privilegesStore.setPrivileges(response.data.privileges || {})

      return true
    },

    async logout() {
      try {
        await api.delete('/api/v1/auth/logout')
      } catch { /* silent */ } finally {
        const { usePrivilegesStore } = await import('./privileges-store')
        usePrivilegesStore().clearPrivileges()

        this.user = null
        localStorage.removeItem('jwt_token')
        localStorage.removeItem('selected_business_unit_id')
      }
    },
  },

  persist: {
    enabled: true,
    strategies: [{ key: 'auth', storage: localStorage, paths: ['user'] }],
  },
})
```

### Estructura del usuario autenticado

```javascript
// response.data.user contiene:
{
  id: 1,
  nombre: 'Antonio',
  apaterno: 'Castellanos',
  email: 'admin@ttpn.com',
  role_id: 1,
  sadmin: true,          // super admin (acceso a todas las BU)
  business_unit: {
    id: 1,
    nombre: 'TTPN Principal'
  }
}

// response.data.privileges contiene:
{
  employees: {
    can_access: true,
    can_create: true,
    can_edit: true,
    can_delete: false,
    can_clone: false,
    can_import: false,
    can_export: true,
  },
  vehicles: { ... },
  // un objeto por módulo registrado en el BE
}
```

---

## 6. Stores (Pinia)

### privileges-store.js

```javascript
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export const usePrivilegesStore = defineStore('privileges', () => {
  const privileges = ref({})

  const canAccess = (key) => privileges.value[key]?.can_access || false
  const canCreate = (key) => privileges.value[key]?.can_create || false
  const canEdit   = (key) => privileges.value[key]?.can_edit   || false
  const canDelete = (key) => privileges.value[key]?.can_delete || false
  const canImport = (key) => privileges.value[key]?.can_import || false
  const canExport = (key) => privileges.value[key]?.can_export || false

  function setPrivileges(newPrivileges) { privileges.value = newPrivileges || {} }
  function clearPrivileges() { privileges.value = {} }

  return { privileges, canAccess, canCreate, canEdit, canDelete, canImport, canExport,
           setPrivileges, clearPrivileges }
}, { persist: true })
```

### Instalar persistencia en `src/boot/axios.js` o en `main.js`

```javascript
// quasar.config.js  — agrega 'pinia-plugin-persistedstate' automáticamente
// O manualmente en el entry point:
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)
app.use(pinia)
```

---

## 7. Router y guards de navegación

```javascript
// src/router/index.js
import { route } from 'quasar/wrappers'
import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'
import { useAuthStore } from 'stores/auth-store'

export default route(() => {
  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createWebHistory(process.env.VUE_ROUTER_BASE),
  })

  Router.beforeEach((to, from, next) => {
    const authStore = useAuthStore()
    const requiresAuth = to.matched.some(r => r.meta.requiresAuth)

    if (requiresAuth && !authStore.isAuthenticated) {
      next('/login')
    } else if (to.path === '/login' && authStore.isAuthenticated) {
      next('/')
    } else {
      next()
    }
  })

  return Router
})
```

```javascript
// src/router/routes.js
const routes = [
  {
    path: '/',
    component: () => import('layouts/MainLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', component: () => import('pages/IndexPage.vue') },
      { path: 'mi-modulo', component: () => import('pages/MiModulo/MiModuloPage.vue') },
    ],
  },
  {
    path: '/login',
    component: () => import('pages/LoginPage.vue'),
  },
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
]

export default routes
```

---

## 8. Servicios (capa de API)

Cada módulo tiene su propio archivo de servicio. Las funciones son puras — solo llaman a `api`, sin estado ni lógica de UI.

```javascript
// src/services/productos.service.js
import { api } from 'boot/axios'

export const productosService = {
  list:    (params)     => api.get('/api/v1/productos', { params }),
  find:    (id)         => api.get(`/api/v1/productos/${id}`),
  create:  (data)       => api.post('/api/v1/productos', data),
  update:  (id, data)   => api.patch(`/api/v1/productos/${id}`, data),
  destroy: (id)         => api.delete(`/api/v1/productos/${id}`),
}

// Para descarga de archivos (Excel, PDF):
export const productosExcelService = (params) =>
  api.get('/api/v1/productos/export.xlsx', { params, responseType: 'blob' })
```

### Payload estándar hacia el BE

El BE espera los datos envueltos en la clave del modelo:

```javascript
// Crear
api.post('/api/v1/productos', {
  producto: {
    nombre: 'Widget',
    precio: 100.0,
    activo: true,
  }
})

// Actualizar con nested attributes
api.patch('/api/v1/productos/1', {
  producto: {
    nombre: 'Widget Pro',
    documentos_attributes: [
      { id: 5, archivo: 'nuevo.pdf' },
      { nombre: 'manual.pdf', _destroy: false },
    ]
  }
})
```

### Catálogos compartidos del BE

Estos endpoints están disponibles para cualquier app conectada al BE:

| Endpoint | Descripción |
| --- | --- |
| `GET /api/v1/employees` | Empleados activos |
| `GET /api/v1/clients` | Clientes |
| `GET /api/v1/vehicles` | Vehículos |
| `GET /api/v1/business_units` | Unidades de negocio |
| `GET /api/v1/ttpn_service_types` | Tipos de servicio |
| `GET /api/v1/ttpn_foreign_destinies` | Destinos foráneos |
| `GET /api/v1/labors` | Puestos de trabajo |
| `GET /api/v1/roles` | Roles de usuario |

---

## 9. Composables estándar

Copiar estos composables del proyecto Kumi Admin o reescribirlos siguiendo el mismo contrato.

### useNotify.js

```javascript
import { useQuasar } from 'quasar'

export function useNotify() {
  const $q = useQuasar()

  const notifyOk    = (msg, opts = {}) => $q.notify({ type: 'positive', message: msg, ...opts })
  const notifyError = (msg, opts = {}) => $q.notify({ type: 'negative', message: msg, ...opts })
  const notifyWarn  = (msg, opts = {}) => $q.notify({ type: 'warning',  message: msg, ...opts })
  const notifyInfo  = (msg, opts = {}) => $q.notify({ type: 'info',     message: msg, ...opts })

  // Extrae el mensaje de error de la respuesta Rails
  const notifyApiError = (error, fallback = 'Error al guardar') => {
    const message = error?.response?.data?.errors?.join(', ') || fallback
    $q.notify({ type: 'negative', message })
  }

  return { notifyOk, notifyError, notifyWarn, notifyInfo, notifyApiError }
}
```

### useCrud.js

```javascript
// CRUD genérico. Recibe un servicio con list/create/update/destroy.
import { ref, computed } from 'vue'
import { useNotify } from './useNotify'

export function useCrud({ service, resourceName, formDefault,
  createMsg = 'Creado correctamente', updateMsg = 'Actualizado correctamente' }) {

  const { notifyOk, notifyApiError } = useNotify()

  const items       = ref([])
  const loading     = ref(false)
  const saving      = ref(false)
  const dialog      = ref(false)
  const editingItem = ref(null)
  const form        = ref({ ...formDefault })
  const isEditMode  = computed(() => !!editingItem.value)

  async function fetchData(params = {}) {
    loading.value = true
    try {
      const { data } = await service.list(params)
      items.value = data
    } catch (e) {
      notifyApiError(e, 'Error al cargar datos')
    } finally {
      loading.value = false
    }
  }

  function openDialog(item = null) {
    editingItem.value = item ?? null
    form.value = item ? { ...item } : { ...formDefault }
    dialog.value = true
  }

  function closeDialog() { dialog.value = false }

  async function save() {
    saving.value = true
    try {
      const payload = { [resourceName]: form.value }
      if (isEditMode.value) {
        await service.update(form.value.id, payload)
        notifyOk(updateMsg)
      } else {
        await service.create(payload)
        notifyOk(createMsg)
      }
      await fetchData()
      closeDialog()
    } catch (e) {
      notifyApiError(e)
    } finally {
      saving.value = false
    }
  }

  async function destroy(id) {
    try {
      await service.destroy(id)
      items.value = items.value.filter(i => i.id !== id)
      notifyOk('Eliminado correctamente')
    } catch (e) {
      notifyApiError(e, 'Error al eliminar')
    }
  }

  return { items, loading, saving, dialog, form, isEditMode,
           fetchData, openDialog, closeDialog, save, destroy }
}
```

### usePrivileges.js

```javascript
import { usePrivilegesStore } from 'stores/privileges-store'

// moduleKey = clave del módulo registrada en el BE (ej: 'productos')
export function usePrivileges(moduleKey) {
  const store = usePrivilegesStore()
  return {
    canAccess: () => store.canAccess(moduleKey),
    canCreate: () => store.canCreate(moduleKey),
    canEdit:   () => store.canEdit(moduleKey),
    canDelete: () => store.canDelete(moduleKey),
    canImport: () => store.canImport(moduleKey),
    canExport: () => store.canExport(moduleKey),
  }
}
```

### useFilters.js

```javascript
import { ref, computed } from 'vue'

export function useFilters(initialFilters = {}) {
  const filters     = ref({ ...initialFilters })
  const showFilters = ref(false)

  const activeFiltersCount = computed(() =>
    Object.entries(filters.value).filter(([key, val]) => {
      const initial = initialFilters[key] ?? null
      return val !== null && val !== undefined && val !== '' && val !== initial
    }).length
  )

  function clearFilters() { filters.value = { ...initialFilters } }
  function toggleFilters() { showFilters.value = !showFilters.value }
  function openFilters()   { showFilters.value = true }

  return { filters, showFilters, activeFiltersCount, clearFilters, toggleFilters, openFilters }
}
```

---

## 10. Patrón de página

Toda página sigue esta estructura:

```text
[Modulo]Page.vue
  ├── PageHeader      → título + botones (filtros, nuevo, exportar)
  ├── FilterPanel     → filtros colapsables
  ├── AppTable        → tabla con slots por columna
  └── q-dialog        → formulario de create/edit
```

### Ejemplo completo

```vue
<!-- src/pages/Productos/ProductosPage.vue -->
<template>
  <q-page class="bg-grey-2">
    <div class="q-pa-md">

      <PageHeader title="Productos" subtitle="Catálogo de productos">
        <template #actions>
          <q-btn
            outline round icon="filter_list" color="grey-7"
            @click="toggleFilters"
          >
            <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
              {{ activeFiltersCount }}
            </q-badge>
          </q-btn>
          <q-btn
            v-if="priv.canCreate()"
            unelevated color="primary" icon="add" label="Nuevo"
            @click="openDialog()"
          />
        </template>
      </PageHeader>

      <FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClear">
        <div class="col-12 col-md-4">
          <q-input
            v-model="filters.search" dense outlined debounce="400" clearable
            placeholder="Buscar por nombre..."
            @update:model-value="load"
          >
            <template #prepend><q-icon name="search" /></template>
          </q-input>
        </div>
        <div class="col-6 col-md-2">
          <q-select
            v-model="filters.activo" dense outlined clearable
            :options="[{ label: 'Activo', value: true }, { label: 'Inactivo', value: false }]"
            label="Estatus" emit-value map-options
            @update:model-value="load"
          />
        </div>
      </FilterPanel>

      <AppTable
        :rows="items"
        :columns="columns"
        :loading="loading"
        selection="none"
      >
        <template #cell-activo="{ row }">
          <q-badge :color="row.activo ? 'positive' : 'grey'" rounded>
            {{ row.activo ? 'Activo' : 'Inactivo' }}
          </q-badge>
        </template>
        <template #cell-acciones="{ row }">
          <q-btn flat dense round icon="edit"   color="primary"  @click="openDialog(row)" />
          <q-btn flat dense round icon="delete" color="negative" @click="confirmDelete(row)" />
        </template>
      </AppTable>

    </div>

    <!-- Dialog Create / Edit -->
    <q-dialog v-model="dialog" persistent>
      <q-card style="min-width: 400px">
        <q-card-section>
          <div class="text-h6">{{ isEditMode ? 'Editar' : 'Nuevo' }} Producto</div>
        </q-card-section>
        <q-card-section class="q-gutter-md">
          <q-input v-model="form.nombre" label="Nombre *" dense outlined />
          <q-input v-model.number="form.precio" label="Precio" type="number" dense outlined />
          <q-toggle v-model="form.activo" label="Activo" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancelar" @click="closeDialog" />
          <q-btn unelevated color="primary" label="Guardar" :loading="saving" @click="save" />
        </q-card-actions>
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script setup>
import { onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useCrud }       from 'src/composables/useCrud'
import { useFilters }    from 'src/composables/useFilters'
import { usePrivileges } from 'src/composables/usePrivileges'
import { productosService } from 'src/services/productos.service'
import AppTable    from 'src/components/AppTable.vue'
import FilterPanel from 'src/components/FilterPanel.vue'
import PageHeader  from 'src/components/PageHeader.vue'

const $q = useQuasar()

// ── Privilegios ────────────────────────────────────────────────────
const priv = usePrivileges('productos')

// ── Filtros ────────────────────────────────────────────────────────
const { filters, showFilters, activeFiltersCount, clearFilters, toggleFilters } =
  useFilters({ search: null, activo: null })

function onClear() {
  clearFilters()
  load()
}

// ── CRUD ───────────────────────────────────────────────────────────
const { items, loading, saving, dialog, form, isEditMode, fetchData, openDialog, closeDialog, save, destroy } =
  useCrud({
    service:      { list: (p) => productosService.list(p), ...productosService },
    resourceName: 'producto',
    formDefault:  { nombre: '', precio: 0, activo: true },
  })

async function load() {
  await fetchData(filters.value)
}

function confirmDelete(row) {
  $q.dialog({
    title: 'Eliminar',
    message: `¿Eliminar "${row.nombre}"?`,
    cancel: true,
  }).onOk(() => destroy(row.id))
}

// ── Columnas ───────────────────────────────────────────────────────
const columns = [
  { name: 'nombre',   label: 'Nombre',  field: 'nombre',  align: 'left', sortable: true },
  { name: 'precio',   label: 'Precio',  field: 'precio',  align: 'right' },
  { name: 'activo',   label: 'Estatus', field: 'activo',  align: 'center' },
  { name: 'acciones', label: '',        field: 'acciones', align: 'right' },
]

onMounted(load)
</script>
```

---

## 11. Componentes globales recomendados

Copiar desde Kumi Admin (`ttpn-frontend/src/components/`):

| Componente | Uso |
| --- | --- |
| `AppTable.vue` | Tabla con paginación cliente, slots por columna, altura dinámica |
| `FilterPanel.vue` | Panel colapsable con transición, contador de filtros activos, botón limpiar |
| `PageHeader.vue` | Título + subtítulo + slot `#actions` para botones |

Registrarlos globalmente en `quasar.config.js` o importarlos en cada página.

---

## 12. Configurar como PWA

En `quasar.config.js`:

```javascript
pwa: {
  workboxMode: 'GenerateSW',
  injectPwaMetaTags: true,
  swFilename: 'sw.js',
  manifest: {
    name: 'Mi App TTPN',
    short_name: 'MiApp',
    description: 'Portal de captura TTPN',
    start_url: '/',
    display: 'standalone',
    orientation: 'portrait',
    background_color: '#ffffff',
    theme_color: '#027be3',
    icons: [
      { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
    ],
  },
},
```

Colocar los íconos en `public/`:

```bash
public/
├── icon-192.png
├── icon-512.png
└── favicon.ico
```

---

## 13. Variables de entorno

Crear `.env` en la raíz del proyecto:

```bash
# URL del backend TTPN
API_URL=http://localhost:3000

# Para producción (Netlify):
# API_URL=https://tu-backend.railway.app
```

El `.env` NO se commitea al repositorio. Compartir con el equipo por canal seguro.

En producción, configurar las variables directamente en el panel de Netlify:
**Site settings → Environment variables → Add variable**

---

## 14. Despliegue en Netlify

### Build settings en Netlify

| Campo | Valor |
| --- | --- |
| Build command | `quasar build -m pwa` |
| Publish directory | `dist/pwa` |
| Node version | `18` |

### `netlify.toml` (en raíz del proyecto)

```toml
[build]
  command   = "quasar build -m pwa"
  publish   = "dist/pwa"

[[redirects]]
  from   = "/*"
  to     = "/index.html"
  status = 200
```

El redirect es indispensable para que Vue Router (modo history) funcione correctamente.

### CORS en el BE

Verificar que el dominio de Netlify esté en los orígenes permitidos en `ttpngas/config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://mi-nueva-app.netlify.app', 'http://localhost:9000'
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
```

---

## 15. Checklist de nueva app

```
Setup inicial
  [ ] quasar create corrido con las opciones correctas
  [ ] pinia-plugin-persistedstate instalado
  [ ] dotenv instalado y quasar.config.js actualizado

Conexión al BE
  [ ] boot/axios.js copiado y configurado
  [ ] Proxy en quasar.config.js apuntando a API_URL
  [ ] .env creado con API_URL
  [ ] CORS actualizado en el BE para el nuevo dominio

Autenticación
  [ ] auth-store.js creado
  [ ] privileges-store.js creado
  [ ] Router guard configurado en index.js
  [ ] LoginPage.vue creada
  [ ] Logout limpia jwt_token y selected_business_unit_id

Estructura
  [ ] Carpetas services/, composables/, components/ creadas
  [ ] useNotify.js copiado
  [ ] useCrud.js copiado
  [ ] useFilters.js copiado
  [ ] usePrivileges.js copiado
  [ ] AppTable.vue copiado
  [ ] FilterPanel.vue copiado
  [ ] PageHeader.vue copiado

Primera página
  [ ] Servicio creado en services/
  [ ] Ruta registrada en router/routes.js
  [ ] Página sigue patrón: PageHeader + FilterPanel + AppTable + Dialog

PWA
  [ ] manifest configurado en quasar.config.js
  [ ] Íconos en public/
  [ ] build -m pwa sin errores

Despliegue
  [ ] netlify.toml creado
  [ ] Variables de entorno configuradas en Netlify
  [ ] CORS en BE actualizado
```

---

**Ultima actualizacion:** 2026-04-10
