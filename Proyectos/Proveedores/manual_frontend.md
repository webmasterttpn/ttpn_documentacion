# Manual Frontend — PWA del Portal de Proveedores

> **Audiencia**: dev que nunca ha usado Quasar/Vue.
> **Resultado**: PWA corriendo en `localhost:9001` con login, cambio de
> password forzado, y la pantalla "Estatus de Facturas" consumiendo el
> API de Kumi.
> **Tiempo estimado**: 10-16 horas distribuidas en varios días.
> **Pre-requisito**: `manual_backend.md` completo (al menos hasta los
> endpoints de auth + GET /invoices funcionando).

---

## Bloques del manual

| Bloque | Pasos | Objetivo |
|---|---|---|
| A | 1-4 | Crear branch + scaffold Quasar inicial + Dockerfile |
| B | 5-8 | Limpiar boilerplate + estructura de carpetas |
| C | 9-12 | Boot files (axios, actioncable opcional) + .env |
| D | 13-16 | Stores (Pinia): auth store con persistencia |
| E | 17-21 | Páginas de auth (Login, Confirm, Reset, ChangePassword) |
| F | 22-24 | Router + guards |
| G | 25-29 | Layout principal + InvoicesPage (la pantalla principal) |
| H | 30-32 | PWA manifest + service worker |
| I | 33-35 | Deploy a Netlify + Variables de entorno en producción |

---

## Bloque A — Setup

### Paso 1 — Crear branch nueva en el repo del portal

#### Por qué

Antonio creó el repo `portal-proveedores` vacío con solo `main`. Nunca
pushees a `main` directamente.

#### Comando(s)

```bash
cd ~/Documents/Kumi/portal-proveedores
git checkout -b feature/initial-scaffold
```

#### Verificación

```bash
git branch --show-current
```

Debe imprimir `feature/initial-scaffold`.

### Paso 2 — Inicializar el scaffold Quasar dentro del repo vacío

#### Por qué

Quasar es un framework Vue. Usaremos su CLI para crear toda la
estructura base.

#### Comando(s)

```bash
cd ~/Documents/Kumi/portal-proveedores
npm init quasar@latest .
```

#### Te preguntará (responde así)

| Pregunta | Respuesta |
|---|---|
| Project name | `portal-proveedores` |
| Project description | `Portal de Proveedores TTPN` |
| Package name | `portal-proveedores` |
| Author | tu nombre |
| Pick Quasar version | **Quasar v2 (Vue 3)** |
| Pick script type | **Composition API** + `<script setup>` |
| Pick Quasar App CLI | **Quasar App CLI with Vite** |
| Pick a Vue component style | **Composition API with `<script setup>`** |
| Pick a CSS preprocessor | **SCSS** |
| Features | marca: ESLint, Prettier, **Pinia**, axios |
| Install dependencies? | **Yes** (npm) |

Toma 2-3 minutos.

#### Salida esperada

```text
✨ Quasar project created in .
...
Done. Now run:

  cd .
  quasar dev
```

### Paso 3 — Crear el Dockerfile

Si vas a correr el portal en Docker (recomendado para consistencia con
Kumi), crea `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS development

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 9200
CMD ["npm", "run", "dev"]
```

### Paso 4 — Verificar que el scaffold corre

```bash
# Opción A: local (sin Docker)
npm run dev

# Opción B: en Docker (requiere haber hecho el Paso 8 de 00_setup_docker_y_entorno.md)
cd ../kumi-orchestrator
docker compose --profile portal_proveedores up -d
```

Abre `http://localhost:9001` (o `9200` si corriste local).
Debes ver la página default de Quasar.

#### Si falla

- **`npm ERR! code ENOENT`** → te falta `package.json`. Repite el
  Paso 2.
- **Puerto en uso** → cambia el puerto en `quasar.config.js` →
  `devServer.port`.

---

## Bloque B — Limpieza y estructura

### Paso 5 — Limpiar el boilerplate

Borra archivos que no aplican al portal:

```bash
rm -rf src/pages/IndexPage.vue
rm -rf src/pages/ErrorNotFound.vue
rm -rf src/components/EssentialLink.vue
rm -rf src/components/ExampleComponent.vue
```

Crea las páginas que vas a necesitar (vacías por ahora):

```bash
mkdir -p src/pages
touch src/pages/LoginPage.vue
touch src/pages/ConfirmAccountPage.vue
touch src/pages/ResetPasswordPage.vue
touch src/pages/ChangePasswordPage.vue
touch src/pages/InvoicesPage.vue
touch src/pages/UploadInvoicesPage.vue
```

### Paso 6 — Estructura de carpetas recomendada

Después de crear, tu `src/` debe verse así:

```text
src/
├── App.vue              # ya existe
├── assets/              # logos, imágenes
├── boot/                # archivos boot (ya tendrás axios.js)
├── components/          # componentes reusables (vacío por ahora)
├── composables/         # composables (vacío por ahora)
├── css/                 # SCSS globales
├── layouts/
│   └── MainLayout.vue   # ya existe, lo modificaremos
├── pages/               # las que creaste
├── router/
│   ├── index.js
│   └── routes.js
├── services/            # crear: clients REST
├── stores/              # Pinia
└── utils/               # helpers
```

### Paso 7 — Copiar `enumLabels.js` desde Kumi Admin

El admin de Kumi tiene un diccionario de traducciones de enums
(`status`, `metodo_pago`, etc.) en español. Copia ese archivo para
mantener consistencia.

```bash
cp ../ttpn-frontend/src/utils/enumLabels.js src/utils/enumLabels.js
```

Quita las entradas que NO aplican al portal (deja solo
`SUPPLIER_INVOICE_*`, `METODO_PAGO_*`, etc.). Si dudas, déjalo
completo — sobra contenido pero no estorba.

### Paso 8 — Crear `.env` y `.env.example`

`.env.example` (este SÍ se commitea):

```bash
# URL del API Rails de Kumi
VITE_API_URL=http://localhost:3000

# API Key del Portal (Antonio te la da; pídela y NO la versiones)
VITE_PORTAL_API_KEY=CAMBIA_ESTO

# WebSocket (futuro)
VITE_WS_URL=ws://localhost:3000/cable
```

`.env` (este NO se commitea — ya está en `.gitignore`):

```bash
VITE_API_URL=http://localhost:3000
VITE_PORTAL_API_KEY=<la-api-key-real>
VITE_WS_URL=ws://localhost:3000/cable
```

#### Verifica que `.env` está en `.gitignore`

```bash
grep -E '^\.env$' .gitignore
```

Debe imprimir `.env`. Si no, agrégalo.

---

## Bloque C — Boot files

### Paso 9 — Boot `axios.js`

Crea `src/boot/axios.js`:

```js
import { boot } from 'quasar/wrappers'
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000'
})

// Interceptor: inyecta X-API-Key + Bearer JWT en cada request.
api.interceptors.request.use((config) => {
  config.headers['X-API-Key'] = import.meta.env.VITE_PORTAL_API_KEY
  const jwt = localStorage.getItem('portal_jwt')
  if (jwt) {
    config.headers.Authorization = `Bearer ${jwt}`
  }
  return config
})

// Interceptor: si el JWT expiró, redirige a login.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && !error.config.url.includes('/auth/')) {
      localStorage.removeItem('portal_jwt')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default boot(({ app }) => {
  app.config.globalProperties.$axios = axios
  app.config.globalProperties.$api = api
})

export { api }
```

### Paso 10 — Registrar el boot en `quasar.config.js`

Abre `quasar.config.js` y busca la sección `boot`:

```js
boot: [
  'axios'
]
```

Si no está, agrégalo. Asegúrate de que solo aparece una vez.

### Paso 11 — Reinicia el dev server

```bash
docker compose restart kumi_portal_proveedores
# o si corres local:
# Ctrl+C en la terminal donde corre `npm run dev`, luego npm run dev
```

### Paso 12 — Verificación

Abre la consola del navegador (F12) → tab Network. Recarga la página.
Aunque todavía no hay llamadas, abre `src/App.vue` y agrega
temporalmente:

```vue
<script setup>
import { api } from 'src/boot/axios'
console.log('API base URL:', api.defaults.baseURL)
console.log('API Key configured:', !!import.meta.env.VITE_PORTAL_API_KEY)
</script>
```

En la consola del navegador debes ver tus dos valores.
**Quítalo después** — solo era para verificar.

---

## Bloque D — Pinia store de auth

### Paso 13 — Crear `src/stores/auth-store.js`

```js
import { defineStore } from 'pinia'
import { api } from 'src/boot/axios'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    jwt: localStorage.getItem('portal_jwt') || null,
    supplierUser: null, // { id, email, nombre, supplier_id, supplier_name, force_password_change }
    loading: false,
    error: null
  }),

  getters: {
    isAuthenticated: (state) => !!state.jwt,
    mustChangePassword: (state) => state.supplierUser?.force_password_change === true
  },

  actions: {
    async login (email, password) {
      this.loading = true
      this.error = null
      try {
        const { data } = await api.post('/api/v1/portal/auth/login', { email, password })
        this.jwt = data.jwt
        this.supplierUser = data.supplier_user
        localStorage.setItem('portal_jwt', data.jwt)
        localStorage.setItem('portal_user', JSON.stringify(data.supplier_user))
        return data
      } catch (err) {
        this.error = err.response?.data?.error || 'Error al iniciar sesión'
        throw err
      } finally {
        this.loading = false
      }
    },

    async logout () {
      try { await api.post('/api/v1/portal/auth/logout') } catch (_) {}
      this.jwt = null
      this.supplierUser = null
      localStorage.removeItem('portal_jwt')
      localStorage.removeItem('portal_user')
    },

    async forgotPassword (email) {
      await api.post('/api/v1/portal/auth/forgot_password', { email })
    },

    async resetPassword (token, password) {
      const { data } = await api.post('/api/v1/portal/auth/reset_password', { token, password })
      this.jwt = data.jwt
      this.supplierUser = data.supplier_user
      localStorage.setItem('portal_jwt', data.jwt)
    },

    async confirm (token) {
      await api.post('/api/v1/portal/auth/confirm', { token })
    },

    async changePassword (currentPassword, newPassword) {
      await api.patch('/api/v1/portal/me/password', {
        current_password: currentPassword,
        new_password: newPassword
      })
      // Refresca el usuario local quitando force_password_change
      if (this.supplierUser) {
        this.supplierUser.force_password_change = false
        localStorage.setItem('portal_user', JSON.stringify(this.supplierUser))
      }
    },

    rehydrate () {
      const raw = localStorage.getItem('portal_user')
      if (raw) {
        try { this.supplierUser = JSON.parse(raw) } catch (_) {}
      }
    }
  }
})
```

### Paso 14 — Auto-rehidratar al arrancar

En `src/boot/axios.js`, al final agrega:

```js
import { useAuthStore } from 'src/stores/auth-store'
// ... después de definir api ...

export default boot(({ app, store }) => {
  app.config.globalProperties.$api = api
  // Rehydrate auth state from localStorage
  const auth = useAuthStore(store)
  auth.rehydrate()
})
```

---

## Bloque E — Páginas de auth

### Paso 15 — `LoginPage.vue`

```vue
<template>
  <q-page class="flex flex-center bg-grey-2">
    <q-card style="width: 400px; max-width: 92vw">
      <q-card-section class="text-center">
        <h5 class="q-my-md">Portal de Proveedores</h5>
        <p class="text-grey-7">TTPN — Inicia sesión con tu correo</p>
      </q-card-section>
      <q-form @submit.prevent="onSubmit">
        <q-card-section>
          <q-input v-model="email" type="email" label="Correo electrónico" outlined required />
          <q-input v-model="password" type="password" label="Contraseña" outlined required class="q-mt-md" />
          <div v-if="auth.error" class="text-negative q-mt-sm">{{ auth.error }}</div>
        </q-card-section>
        <q-card-actions class="q-px-md q-pb-md">
          <q-btn type="submit" :loading="auth.loading" color="primary" label="Entrar" class="full-width" />
        </q-card-actions>
        <q-card-section class="text-center">
          <q-btn flat dense to="/forgot-password" label="¿Olvidaste tu contraseña?" />
        </q-card-section>
      </q-form>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/stores/auth-store'

const email = ref('')
const password = ref('')
const auth = useAuthStore()
const router = useRouter()

async function onSubmit () {
  try {
    await auth.login(email.value, password.value)
    if (auth.mustChangePassword) {
      router.push('/cambiar-password')
    } else {
      router.push('/facturas')
    }
  } catch (_) { /* error en store */ }
}
</script>
```

### Paso 16 — `ConfirmAccountPage.vue`

```vue
<template>
  <q-page class="flex flex-center bg-grey-2">
    <q-card style="width: 400px">
      <q-card-section v-if="loading" class="text-center">
        <q-spinner-dots size="40px" /> Activando cuenta...
      </q-card-section>
      <q-card-section v-else-if="error" class="text-center">
        <q-icon name="error" size="64px" color="negative" />
        <p>{{ error }}</p>
        <q-btn to="/login" label="Ir al login" color="primary" />
      </q-card-section>
      <q-card-section v-else class="text-center">
        <q-icon name="check_circle" size="64px" color="positive" />
        <h5>Cuenta activada</h5>
        <p>Ya puedes iniciar sesión.</p>
        <q-btn to="/login" label="Ir al login" color="primary" />
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from 'src/stores/auth-store'

const auth = useAuthStore()
const route = useRoute()
const loading = ref(true)
const error = ref(null)

onMounted(async () => {
  try {
    await auth.confirm(route.query.token)
  } catch (e) {
    error.value = e.response?.data?.error || 'Token inválido o expirado'
  } finally {
    loading.value = false
  }
})
</script>
```

### Paso 17 — `ResetPasswordPage.vue`

Similar a Login pero con campos `nueva_password` + `confirmar` y llama
a `auth.resetPassword(token, password)`. Si éxito, redirige a
`/facturas`. (El detalle del template lo escribes copiando el patrón
de `LoginPage`).

### Paso 18 — `ChangePasswordPage.vue`

Aplica para el primer login (cuando `force_password_change = true`).
Form de 3 campos: actual + nueva + confirmar. Llama a
`auth.changePassword(current, new)`. Si éxito, redirige a `/facturas`.

### Paso 19 — `ForgotPasswordPage.vue`

Form simple con email → `auth.forgotPassword(email)` →
`q-notify('Si el correo existe, te llegará un link...')`. **No revela
si el email existe** (regla de seguridad).

---

## Bloque F — Router

### Paso 20 — `src/router/routes.js`

```js
const routes = [
  { path: '/login', component: () => import('pages/LoginPage.vue') },
  { path: '/confirmar', component: () => import('pages/ConfirmAccountPage.vue') },
  { path: '/forgot-password', component: () => import('pages/ForgotPasswordPage.vue') },
  { path: '/reset', component: () => import('pages/ResetPasswordPage.vue') },

  // Rutas autenticadas (requieren JWT)
  {
    path: '/',
    component: () => import('layouts/MainLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', redirect: '/facturas' },
      { path: 'cambiar-password', component: () => import('pages/ChangePasswordPage.vue'),
        meta: { allowDuringForcedChange: true } },
      { path: 'facturas', component: () => import('pages/InvoicesPage.vue') },
      { path: 'cargar-facturas', component: () => import('pages/UploadInvoicesPage.vue') }
    ]
  },

  { path: '/:catchAll(.*)*', component: () => import('pages/ErrorNotFound.vue') }
]

export default routes
```

### Paso 21 — Guards en `src/router/index.js`

Busca el `Router.beforeEach` (o agrégalo):

```js
import { useAuthStore } from 'src/stores/auth-store'

Router.beforeEach((to, from) => {
  const auth = useAuthStore()
  const needsAuth = to.matched.some(r => r.meta.requiresAuth)
  const allowsDuringForced = to.matched.some(r => r.meta.allowDuringForcedChange)

  if (needsAuth && !auth.isAuthenticated) {
    return { path: '/login' }
  }
  if (auth.isAuthenticated && auth.mustChangePassword && !allowsDuringForced) {
    return { path: '/cambiar-password' }
  }
  if (!needsAuth && auth.isAuthenticated && to.path === '/login') {
    return { path: '/facturas' }
  }
})
```

---

## Bloque G — Layout principal e InvoicesPage

### Paso 22 — `src/layouts/MainLayout.vue`

Layout sencillo con header + drawer + page container:

```vue
<template>
  <q-layout view="hHh Lpr lFf">
    <q-header elevated class="bg-primary">
      <q-toolbar>
        <q-btn dense flat round icon="menu" @click="drawer = !drawer" />
        <q-toolbar-title>Portal de Proveedores TTPN</q-toolbar-title>
        <q-space />
        <q-btn-dropdown flat :label="auth.supplierUser?.nombre || ''">
          <q-list>
            <q-item v-if="!auth.mustChangePassword" clickable v-close-popup to="/cambiar-password">
              <q-item-section>Cambiar contraseña</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="onLogout">
              <q-item-section>Cerrar sesión</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
      </q-toolbar>
    </q-header>

    <q-drawer v-model="drawer" show-if-above bordered>
      <q-list>
        <q-item-label header>{{ auth.supplierUser?.supplier_name || 'Proveedor' }}</q-item-label>
        <q-item to="/facturas" exact clickable v-ripple>
          <q-item-section avatar><q-icon name="receipt_long" /></q-item-section>
          <q-item-section>Estatus de Facturas</q-item-section>
        </q-item>
        <q-item to="/cargar-facturas" clickable v-ripple>
          <q-item-section avatar><q-icon name="cloud_upload" /></q-item-section>
          <q-item-section>Cargar Documentos</q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/stores/auth-store'

const drawer = ref(false)
const auth = useAuthStore()
const router = useRouter()

async function onLogout () {
  await auth.logout()
  router.push('/login')
}
</script>
```

### Paso 23 — `InvoicesPage.vue` (la pantalla principal)

```vue
<template>
  <q-page class="q-pa-md">
    <div class="row items-center q-mb-md">
      <h5 class="q-my-none">Estatus de Facturas</h5>
      <q-space />
      <q-btn icon="cloud_upload" label="Subir facturas" color="primary" to="/cargar-facturas" />
    </div>

    <q-card>
      <q-card-section class="row q-gutter-md items-end">
        <q-input v-model="filters.from" type="date" label="Desde" dense outlined />
        <q-input v-model="filters.to" type="date" label="Hasta" dense outlined />
        <q-select v-model="filters.estatus" :options="estatusOptions" label="Estatus" dense outlined
                  emit-value map-options clearable style="min-width:200px" />
        <q-btn icon="search" label="Filtrar" color="primary" @click="fetchData" />
      </q-card-section>

      <q-table
        :rows="rows" :columns="columns" :loading="loading"
        row-key="id" v-model:pagination="pagination" @request="onRequest"
        flat dense>
        <template #body-cell-estatus="props">
          <q-td>
            <q-chip dense :color="estatusColor(props.row.estatus)" text-color="white"
                     :label="estatusLabel(props.row.estatus)" />
          </q-td>
        </template>
        <template #body-cell-acciones="props">
          <q-td>
            <q-btn flat dense icon="visibility" @click="openDetails(props.row)" />
          </q-td>
        </template>
      </q-table>
    </q-card>

    <InvoiceDetailDialog v-model="showDetail" :invoice="selected" />
  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from 'src/boot/axios'
import InvoiceDetailDialog from 'src/components/InvoiceDetailDialog.vue'

const rows = ref([])
const loading = ref(false)
const filters = ref({ from: '', to: '', estatus: null })
const pagination = ref({ page: 1, rowsPerPage: 20, rowsNumber: 0 })
const showDetail = ref(false)
const selected = ref(null)

const columns = [
  { name: 'folio', label: 'Folio', field: 'folio', align: 'left' },
  { name: 'fecha_recepcion', label: 'Fecha recepción', field: 'fecha_recepcion' },
  { name: 'fecha_vencimiento', label: 'Vencimiento', field: 'fecha_vencimiento' },
  { name: 'fecha_pago', label: 'Fecha pago', field: 'fecha_pago' },
  { name: 'monto_total', label: 'Monto total', field: 'monto_total', align: 'right',
    format: v => new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(v) },
  { name: 'moneda', label: 'Moneda', field: 'moneda' },
  { name: 'estatus', label: 'Estatus', field: 'estatus' },
  { name: 'uuid_cfdi', label: 'UUID CFDI', field: 'uuid_cfdi' },
  { name: 'purchase_order_number', label: 'No. Orden', field: 'purchase_order_number' },
  { name: 'numero_recepcion', label: 'No. Recepción', field: 'numero_recepcion' },
  { name: 'acciones', label: '', field: 'acciones' }
]

const estatusOptions = [
  { label: 'Pendiente reconciliación', value: 'pending_match' },
  { label: 'En revisión', value: 'in_review' },
  { label: 'Aprobada', value: 'approved' },
  { label: 'Rechazada', value: 'rejected' },
  { label: 'Programada para pago', value: 'scheduled' },
  { label: 'Pagada parcial', value: 'partially_paid' },
  { label: 'Pagada', value: 'paid' },
  { label: 'Cancelada', value: 'cancelled' }
]

function estatusLabel (e) { return estatusOptions.find(o => o.value === e)?.label || e }
function estatusColor (e) {
  return {
    pending_match: 'grey', in_review: 'amber', approved: 'positive',
    rejected: 'negative', scheduled: 'blue', partially_paid: 'teal',
    paid: 'positive', cancelled: 'grey'
  }[e] || 'grey'
}

async function fetchData () {
  loading.value = true
  try {
    const params = { page: pagination.value.page, per_page: pagination.value.rowsPerPage,
                     ...filters.value }
    const { data } = await api.get('/api/v1/portal/invoices', { params })
    rows.value = data.data
    pagination.value.rowsNumber = data.meta.total_count
  } finally {
    loading.value = false
  }
}

function onRequest (p) {
  pagination.value = { ...pagination.value, ...p.pagination }
  fetchData()
}

async function openDetails (row) {
  const { data } = await api.get(`/api/v1/portal/invoices/${row.id}`)
  selected.value = data
  showDetail.value = true
}

onMounted(fetchData)
</script>
```

### Paso 24 — `InvoiceDetailDialog.vue`

Componente de modal con los detalles + documentos descargables.
Sigue el patrón estándar de `q-dialog` con `v-model`. Detalles
exactos a discreción del dev (usar `signed_url` de cada documento
para `<a target="_blank">`).

---

## Bloque H — PWA

### Paso 25 — Manifest

En `quasar.config.js` sección `pwa.manifest`, ajusta:

```js
pwa: {
  workboxMode: 'GenerateSW',
  manifest: {
    name: 'Portal de Proveedores TTPN',
    short_name: 'Proveedores TTPN',
    description: 'Portal para gestionar facturas con TTPN',
    display: 'standalone',
    orientation: 'portrait',
    background_color: '#ffffff',
    theme_color: '#1976d2',
    icons: [
      { src: 'icons/icon-128x128.png', sizes: '128x128', type: 'image/png' },
      { src: 'icons/icon-192x192.png', sizes: '192x192', type: 'image/png' },
      { src: 'icons/icon-256x256.png', sizes: '256x256', type: 'image/png' },
      { src: 'icons/icon-384x384.png', sizes: '384x384', type: 'image/png' },
      { src: 'icons/icon-512x512.png', sizes: '512x512', type: 'image/png' }
    ]
  }
}
```

Crea los íconos en `public/icons/` (puedes usar herramientas como
<https://realfavicongenerator.net/> con el logo de TTPN).

### Paso 26 — Build PWA

```bash
npm run build
```

Output en `dist/spa/`. Sirve ese folder con cualquier static server
para probar la PWA real.

---

## Bloque I — Deploy a Netlify

### Paso 27 — `netlify.toml`

```toml
[build]
  command = "npm run build"
  publish = "dist/spa"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

El redirect es CRÍTICO para SPAs — sin él, recargar una URL
`/facturas` da 404.

### Paso 28 — Configurar en Netlify

1. Entra a <https://app.netlify.com/> (cuenta TTPN).
2. **New site from Git** → conecta el repo `portal-proveedores`.
3. Build settings:
   - **Branch to deploy**: `main` (Netlify desplegará automáticamente
     cuando Antonio mergee).
   - **Build command**: `npm run build`
   - **Publish directory**: `dist/spa`
4. **Environment variables**:
   - `VITE_API_URL` = `https://kumi-admin-api-production.up.railway.app`
   - `VITE_PORTAL_API_KEY` = `<la-key-de-producción>` (Antonio la da)
5. **Deploy**.

### Paso 29 — Verificar

URL temporal de Netlify: `https://portal-proveedores-xxx.netlify.app`.
Si funciona, Antonio configura DNS para
`portal.proveedores.kumiapp.com` (o el dominio que decida).

### Paso 30 — Git workflow para el dev

Recordatorio (más detalle en
[00_setup_docker_y_entorno.md](00_setup_docker_y_entorno.md) sección
"Git workflow del proyecto"):

```bash
git add -A
git commit -m "feat: ..."
git push origin feature/initial-scaffold
```

Antonio revisa en GitHub y mergea a `main` cuando esté listo.

---

## Checklist final del frontend

- [ ] `npm run dev` levanta el portal en localhost
- [ ] LoginPage acepta credenciales y guarda JWT en localStorage
- [ ] ConfirmAccountPage activa cuenta con token del email
- [ ] ChangePasswordPage funciona en el primer login (force change)
- [ ] InvoicesPage lista facturas paginadas del proveedor logueado
- [ ] Detalle de factura abre el modal con docs descargables
- [ ] Logout limpia localStorage y redirige a /login
- [ ] PWA: `npm run build` genera service worker y manifest
- [ ] ESLint: `npm run lint` 0 errores
- [ ] Deploy preview en Netlify funciona

---

## Siguiente paso

→ [kumi_admin_changes.md](kumi_admin_changes.md) — extender el Admin
de Kumi (Finanzas) con las páginas de administración del portal.
