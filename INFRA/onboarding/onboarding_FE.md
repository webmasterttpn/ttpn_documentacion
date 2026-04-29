# Kumi Admin PWA — Guía de Onboarding

Kumi Admin es la PWA principal de administración de TTPN. Construida con Quasar 2 / Vue 3, consume la API REST del backend Rails (`ttpngas`). Esta guía documenta la estructura actual, patrones establecidos y flujo de trabajo para desarrolladores que se incorporan al proyecto.

---

## Tabla de Contenidos

1. [Stack y versiones](#1-stack-y-versiones)
2. [Configuración del entorno local](#2-configuración-del-entorno-local)
3. [Estructura de carpetas](#3-estructura-de-carpetas)
4. [Conexión al backend](#4-conexión-al-backend)
5. [Autenticación y sesión](#5-autenticación-y-sesión)
6. [Sistema de privilegios](#6-sistema-de-privilegios)
7. [Servicios (capa de API)](#7-servicios-capa-de-api)
8. [Composables del sistema](#8-composables-del-sistema)
9. [Componentes globales](#9-componentes-globales)
10. [Patrón de página obligatorio](#10-patrón-de-página-obligatorio)
11. [Módulos actuales](#11-módulos-actuales)
12. [Router y rutas registradas](#12-router-y-rutas-registradas)
13. [Stores Pinia](#13-stores-pinia)
14. [PWA — manifest e instalación](#14-pwa--manifest-e-instalación)
15. [Flujo de trabajo y convenciones](#15-flujo-de-trabajo-y-convenciones)
16. [Despliegue en Netlify](#16-despliegue-en-netlify)

---

## 1. Stack y versiones

| Capa | Tecnología |
| --- | --- |
| Framework | Quasar 2.16 + Vue 3.4 |
| Lenguaje | JavaScript ES6+ (`<script setup>`) |
| Estado global | Pinia 3 + pinia-plugin-persistedstate |
| HTTP Client | Axios 1.2 |
| Gráficas | Vue3-ApexCharts + ApexCharts 5 |
| Calendario | @quasar/quasar-ui-qcalendar |
| Build tool | Vite (via Quasar CLI) |
| Modo | PWA (`quasar build -m pwa`) |
| Deploy | Netlify |
| Backend | Rails 7.1 API — Railway + Supabase |

---

## 2. Configuración del entorno local

### Requisitos

```bash
node --version  # 18+
npm --version   # 9+
quasar --version  # 2.4+  (npm install -g @quasar/cli)
```

### Instalar y arrancar

```bash
cd ttpn-frontend
npm install
quasar dev        # → http://localhost:9000
# o para modo PWA:
quasar dev -m pwa
```

### Variables de entorno

Crear `ttpn-frontend/.env`:

```bash
API_URL=http://localhost:3000
```

El `.env` no está en git. Pedir al equipo el archivo o generarlo apuntando al BE local.

### Backend simultáneo (desarrollo)

```bash
# Terminal 1 — Backend
cd ttpngas
rails server         # → http://localhost:3000

# Terminal 2 — Frontend
cd ttpn-frontend
quasar dev           # → http://localhost:9000
```

El proxy en `quasar.config.js` redirige `/api/*` a `http://localhost:3000`.

---

## 3. Estructura de carpetas

```text
ttpn-frontend/
├── public/               # Assets estáticos (íconos, favicon, logos)
├── src-pwa/
│   └── manifest.json     # Configuración PWA (nombre, íconos, colores)
├── documentacion/        # Este archivo y New_App_Onboarding.md
├── quasar.config.js      # Config build, proxy, PWA, framework plugins
├── eslint.config.js      # Linting
├── .env                  # Variables locales (no commiteado)
│
└── src/
    ├── boot/
    │   └── axios.js            # Instancia Axios + interceptores JWT
    │
    ├── stores/
    │   ├── auth-store.js       # Usuario activo, login/logout
    │   ├── privileges-store.js # Mapa de permisos por módulo
    │   └── catalogs-store.js   # Catálogos globales cacheados
    │
    ├── router/
    │   ├── index.js            # Router + guard de autenticación
    │   └── routes.js           # Árbol de rutas de la app
    │
    ├── layouts/
    │   └── MainLayout.vue      # Sidebar + header + AlertBell + install button
    │
    ├── services/               # Funciones puras que llaman a la API
    │   ├── alerts.service.js
    │   ├── bookings.service.js
    │   ├── catalogs.service.js
    │   ├── clients.service.js
    │   ├── dashboard.service.js
    │   ├── employees.service.js
    │   ├── gas.service.js
    │   ├── payroll.service.js
    │   ├── settings.service.js
    │   ├── ttpn-dashboard.service.js
    │   ├── users.service.js
    │   └── vehicles.service.js
    │
    ├── composables/
    │   ├── useCrud.js                    # CRUD genérico
    │   ├── useFilters.js                 # Estado y lógica de filtros
    │   ├── useNotify.js                  # Notificaciones Quasar
    │   ├── usePrivileges.js              # Guards de UI por permiso
    │   ├── useBusinessUnitContext.js     # Selector de unidad de negocio
    │   ├── useCatalogs.js                # Carga de catálogos globales
    │   ├── useDropdownCache.js           # Motor de caché para dropdowns
    │   ├── useDateFormat.js              # Formateo de fechas
    │   ├── useSelectFilter.js            # Filtros tipo select
    │   ├── usePayrollSettings.js         # Configuración de nómina
    │   ├── useTtpnBookingForm.js         # Formulario de booking complejo
    │   ├── useTtpnBookingImport.js       # Importación masiva de bookings
    │   │
    │   ├── orchestrators/                # Lógica compleja de página
    │   │   ├── useClientsOrchestrator.js
    │   │   ├── useEmployeesOrchestrator.js
    │   │   └── useVehiclesOrchestrator.js
    │   │
    │   └── dropdowns/                   # Catálogos cacheados por entidad
    │       ├── useBusinessUnitsDropdown.js
    │       ├── useClientsDropdown.js
    │       ├── useConcessionairesDropdown.js
    │       ├── useDriversLevelsDropdown.js
    │       ├── useEmployeeDocTypesDropdown.js
    │       ├── useEmployeeMovementTypesDropdown.js
    │       ├── useLaborTypesDropdown.js
    │       ├── useTtpnServicesDropdown.js
    │       ├── useVehicleDocTypesDropdown.js
    │       └── useVehicleTypesDropdown.js
    │
    ├── components/                       # Componentes reutilizables globales
    │   ├── AppTable.vue                  # Tabla estándar
    │   ├── FilterPanel.vue               # Panel de filtros colapsable
    │   ├── PageHeader.vue                # Header de página con acciones
    │   ├── AlertBell.vue                 # Campana de notificaciones
    │   ├── AppProgressDialog.vue         # Dialog de progreso para jobs largos
    │   ├── BusinessUnitSelector.vue      # Selector de unidad de negocio
    │   ├── CatalogManager.vue            # Manager genérico de catálogos simples
    │   ├── KPIs/                         # Tarjetas de métricas para dashboards
    │   └── calendar/                     # Componentes de calendario
    │
    └── pages/                            # Una carpeta por módulo
        ├── LoginPage.vue
        ├── IndexPage.vue
        ├── ErrorNotFound.vue
        ├── Dashboard/
        ├── Employees/
        ├── Clients/
        ├── Vehicles/
        ├── VehicleAsignations/
        ├── VehicleChecks/
        ├── VehicleCatalogs/
        ├── DriverRequests/
        ├── TtpnBookings/
        ├── TtpnBookingsCapture/
        ├── TravelCounts/
        ├── Payrolls/
        ├── Gas/
        ├── Services/
        ├── EmployeeAppointments/
        ├── Users/
        ├── Settings/
        ├── Alerts/
        ├── ApiAccess/
        └── Suppliers/
```

---

## 4. Conexión al backend

### Instancia Axios (`src/boot/axios.js`)

La instancia `api` es el único punto de comunicación con el BE. Se configura en el boot:

```javascript
import { api } from 'boot/axios'

// Uso en cualquier servicio o composable:
const { data } = await api.get('/api/v1/employees', { params: { status: true } })
```

### Interceptor de request

Adjunta automáticamente en cada llamada:
- `Authorization: Bearer <jwt>` si hay token en `localStorage`
- `business_unit_id` como query param (excepto en rutas de auth)

### Interceptor de respuesta

- Convierte errores de tipo `Blob` a JSON (para descargas fallidas)
- En `401` → limpia sesión y redirige a `/login`

### Proxy en desarrollo

```javascript
// quasar.config.js
devServer: {
  proxy: {
    '/api': { target: process.env.API_URL || 'http://localhost:3000', changeOrigin: true }
  }
}
```

En producción (Netlify), el frontend usa su propia URL — el browser llama directamente al backend en Railway.

---

## 5. Autenticación y sesión

### Flujo de login

```
LoginPage.vue
  → authStore.login(email, password)
    → POST /api/v1/auth/login
    → guarda jwt_token en localStorage
    → guarda user en authStore (persistido)
    → carga privileges en privilegesStore
  → router redirige a '/'
```

### Tokens y storage

| Key | Contenido | Storage |
| --- | --- | --- |
| `jwt_token` | Bearer token JWT | `localStorage` |
| `auth` | `{ user: {...} }` serializado | `localStorage` (Pinia persist) |
| `privileges` | Mapa de permisos | `localStorage` (Pinia persist) |
| `selected_business_unit_id` | ID de BU activa | `localStorage` |

### Logout

```javascript
authStore.logout()
// Llama DELETE /api/v1/auth/logout
// Limpia: user, jwt_token, privileges, selected_business_unit_id
// Redirige a /login
```

### Guard de navegación

```javascript
// router/index.js — se ejecuta en cada navegación
Router.beforeEach((to, from, next) => {
  const requiresAuth = to.matched.some(r => r.meta.requiresAuth)
  if (requiresAuth && !authStore.isAuthenticated) return next('/login')
  if (to.path === '/login' && authStore.isAuthenticated) return next('/')
  next()
})
```

Todas las rutas bajo `'/'` tienen `meta: { requiresAuth: true }` heredado del padre.

---

## 6. Sistema de privilegios

Los privilegios vienen del BE al hacer login. Cada módulo tiene 7 flags booleanos:

```javascript
privileges = {
  employees: {
    can_access: true,
    can_create: true,
    can_edit:   true,
    can_delete: false,
    can_clone:  false,
    can_import: false,
    can_export: true,
  },
  vehicles: { ... },
  // ...
}
```

### Usar en un componente

```javascript
import { usePrivileges } from 'src/composables/usePrivileges'

// La clave del módulo debe coincidir con la registrada en el BE
const priv = usePrivileges('employees')

priv.canCreate()  // → true/false
priv.canEdit()
priv.canDelete()
priv.canExport()
```

```vue
<!-- En template -->
<q-btn v-if="priv.canCreate()" label="Nuevo" @click="openDialog()" />
<q-btn v-if="priv.canDelete()" icon="delete" @click="confirmDelete(row)" />
```

### Claves de módulos registrados

| Clave BE | Módulo en UI |
| --- | --- |
| `employees` | Empleados |
| `vehicles` | Vehículos |
| `clients` | Clientes |
| `ttpn_bookings` | Viajes / Bookings |
| `travel_counts` | Registros de viaje |
| `payrolls` | Nóminas |
| `gas_charges` | Combustible |
| `users` | Usuarios internos |
| `roles` | Roles y permisos |
| `api_keys` | Acceso API externo |
| `alerts` | Sistema de alertas |

---

## 7. Servicios (capa de API)

Cada dominio tiene su archivo en `src/services/`. Son objetos con funciones puras — sin estado, sin lógica de UI.

### Patrón de servicio

```javascript
// src/services/employees.service.js
import { api } from 'boot/axios'

export const employeesService = {
  list:    (params)      => api.get('/api/v1/employees', { params }),
  find:    (id)          => api.get(`/api/v1/employees/${id}`),
  create:  (data)        => api.post('/api/v1/employees', data),
  update:  (id, data)    => api.put(`/api/v1/employees/${id}`, data),
  destroy: (id)          => api.delete(`/api/v1/employees/${id}`),
}

// Acciones especiales:
export const vacationsService = {
  list:              (params) => api.get('/api/v1/employee_vacations', { params }),
  create:            (data)   => api.post('/api/v1/employee_vacations', data),
  authorizeVacation: (id)     => api.post(`/api/v1/employee_vacations/${id}/authorize_vacation`),
}
```

### Payload al BE

El BE Rails espera los datos envueltos en la clave del modelo:

```javascript
// Crear empleado
await employeesService.create({
  employee: {
    nombre: 'Juan',
    apaterno: 'Pérez',
    clv: 'EMP-001',
    // nested attributes
    employee_documents_attributes: [
      { document_type_id: 1, fecha_vencimiento: '2027-12-31' }
    ],
  }
})

// Actualizar
await employeesService.update(id, {
  employee: { nombre: 'Juan Carlos' }
})
```

### Descarga de archivos

```javascript
// Descargar Excel
const response = await api.get('/api/v1/payrolls/1/download', { responseType: 'blob' })
const url  = window.URL.createObjectURL(new Blob([response.data]))
const link = document.createElement('a')
link.href = url
link.setAttribute('download', 'nomina.xlsx')
link.click()
```

---

## 8. Composables del sistema

### `useNotify` — Notificaciones

```javascript
import { useNotify } from 'src/composables/useNotify'
const { notifyOk, notifyError, notifyWarn, notifyInfo, notifyApiError } = useNotify()

notifyOk('Guardado correctamente')
notifyError('Error al guardar')
notifyApiError(error, 'Fallback si no hay mensaje del BE')
// notifyApiError extrae error.response.data.errors automáticamente
```

### `useCrud` — CRUD genérico

Para módulos simples (catálogos, configuraciones):

```javascript
import { useCrud } from 'src/composables/useCrud'
import { suppliersService } from 'src/services/catalogs.service'

const { items, loading, saving, dialog, form, isEditMode,
        fetchData, openDialog, closeDialog, save, destroy } = useCrud({
  service:      suppliersService,    // necesita list/create/update/destroy
  resourceName: 'supplier',          // clave para el payload: { supplier: form }
  formDefault:  { nombre: '', activo: true },
  createMsg:    'Proveedor creado',
  updateMsg:    'Proveedor actualizado',
})
```

### `useFilters` — Filtros

```javascript
import { useFilters } from 'src/composables/useFilters'

const { filters, showFilters, activeFiltersCount, clearFilters, toggleFilters, openFilters } =
  useFilters({
    search:      null,
    status:      null,
    fecha_inicio: null,
    fecha_fin:    null,
    client_id:   null,
  })

// filters.value.search → valor actual
// activeFiltersCount → computed con cuántos filtros tienen valor
// clearFilters() → resetea a los valores iniciales
```

### `usePrivileges` — Permisos de UI

```javascript
import { usePrivileges } from 'src/composables/usePrivileges'
const priv = usePrivileges('employees')
// priv.canAccess() / canCreate() / canEdit() / canDelete() / canImport() / canExport()
```

### `useDropdownCache` — Motor de caché

Base para todos los dropdowns de catálogo. Cachea por 5 minutos con soporte ETag:

```javascript
import { useDropdownCache } from 'src/composables/useDropdownCache'

const { data, loading, load, invalidate } = useDropdownCache(
  'mi_catalogo',                  // key única de caché
  '/api/v1/mi_endpoint',          // URL
  { ttl: 5 * 60 * 1000,          // TTL en ms (default: 5 min)
    transform: (items) => items   // transformación opcional
  }
)
```

### `useBusinessUnitContext` — Unidad de negocio

```javascript
import { useBusinessUnitContext } from 'src/composables/useBusinessUnitContext'

const { selectedBusinessUnit, businessUnits, isSuperAdmin,
        loadBusinessUnits, selectBusinessUnit } = useBusinessUnitContext()

// isSuperAdmin → true si user.sadmin === true (puede ver todas las BU)
// selectedBusinessUnit → ID de la BU activa (también en localStorage)
```

### Dropdowns pre-construidos

```javascript
import { useClientsDropdown }    from 'src/composables/dropdowns/useClientsDropdown'
import { useVehicleTypesDropdown } from 'src/composables/dropdowns/useVehicleTypesDropdown'
import { useLaborTypesDropdown }  from 'src/composables/dropdowns/useLaborTypesDropdown'

const { clientOptions, loadClients } = useClientsDropdown()
// clientOptions → [{ value: id, label: 'CLV - Razón Social', disable: false }]
// loadClients() → hace la llamada al BE solo si el caché expiró

// Invalidar manualmente tras crear/editar un catálogo:
// invalidateClients()
```

| Composable | Endpoint BE |
| --- | --- |
| `useClientsDropdown` | `/api/v1/clients` |
| `useBusinessUnitsDropdown` | `/api/v1/business_units` |
| `useVehicleTypesDropdown` | `/api/v1/vehicle_types` |
| `useConcessionairesDropdown` | `/api/v1/concessionaires` |
| `useLaborTypesDropdown` | `/api/v1/labors` |
| `useDriversLevelsDropdown` | `/api/v1/drivers_levels` |
| `useTtpnServicesDropdown` | `/api/v1/ttpn_services` |
| `useVehicleDocTypesDropdown` | `/api/v1/vehicle_document_types` |
| `useEmployeeDocTypesDropdown` | `/api/v1/employee_document_types` |
| `useEmployeeMovementTypesDropdown` | `/api/v1/employee_movement_types` |

### Orquestadores

Para módulos complejos (empleados, vehículos, clientes), la lógica de página está en un orquestador:

```javascript
import { useEmployeesOrchestrator } from 'src/composables/orchestrators/useEmployeesOrchestrator'

const {
  employees, loading, pagination, filters, showFilters, activeFiltersCount,
  columns, laborOptions, statusFilterOptions,
  fetchEmployees, openCreateDialog, editEmployee, viewEmployee, deleteEmployee,
  onClearFilters, toggleFilters,
} = useEmployeesOrchestrator()
```

El orquestador encapsula: fetch con filtros, paginación servidor, apertura de dialogs, delete con confirm, y cualquier lógica de negocio de la página. La page solo arma el template.

---

## 9. Componentes globales

### `AppTable.vue`

Tabla con paginación cliente, altura dinámica, y slots por columna.

```vue
<AppTable
  :rows="employees"
  :columns="columns"
  :loading="loading"
  :pagination="pagination"
  selection="none"
>
  <!-- Slot por columna: cell-{nombre} -->
  <template #cell-status="{ row }">
    <q-badge :color="row.status ? 'positive' : 'grey'">
      {{ row.status ? 'Activo' : 'Inactivo' }}
    </q-badge>
  </template>

  <template #cell-actions="{ row }">
    <q-btn flat dense round icon="edit" @click="editEmployee(row)" />
  </template>
</AppTable>
```

Props: `rows`, `columns`, `loading`, `pagination`, `selection` (`'none'`/`'multiple'`), `rowClass`, `flat`, `rowsPerPageOptions`.

### `FilterPanel.vue`

Panel colapsable con transición. Controlado con `v-model` (Boolean).

```vue
<FilterPanel
  v-model="showFilters"
  :active-count="activeFiltersCount"
  @clear="onClearFilters"
>
  <!-- Slots de filtros con grid de Quasar -->
  <div class="col-12 col-md-4">
    <q-input v-model="filters.search" dense outlined debounce="400" clearable
      @update:model-value="fetchData" />
  </div>
  <div class="col-6 col-md-2">
    <q-select v-model="filters.status" :options="statusOptions"
      dense outlined clearable emit-value map-options
      @update:model-value="fetchData" />
  </div>
</FilterPanel>
```

### `PageHeader.vue`

```vue
<PageHeader title="Empleados" subtitle="Gestión de plantilla laboral">
  <template #actions>
    <q-btn outline round icon="filter_list" @click="toggleFilters">
      <q-badge v-if="activeFiltersCount > 0" color="primary" floating>
        {{ activeFiltersCount }}
      </q-badge>
    </q-btn>
    <q-btn unelevated color="primary" icon="add" label="Nuevo" @click="openCreateDialog" />
  </template>
</PageHeader>
```

### `AlertBell.vue`

Campana de notificaciones en el header. Escucha el canal ActionCable `AlertsChannel` y muestra badge con alertas no leídas. No requiere configuración adicional — se monta en `MainLayout.vue`.

### `AppProgressDialog.vue`

Para jobs de larga duración (importaciones, exportaciones Excel). Muestra progreso en tiempo real haciendo polling al endpoint de status del job.

```vue
<AppProgressDialog
  v-model="showProgress"
  :job-id="currentJobId"
  :status-endpoint="(id) => `/api/v1/ttpn_bookings/import/${id}/status`"
  @completed="onImportComplete"
  @failed="onImportFailed"
/>
```

---

## 10. Patrón de página obligatorio

Toda página nueva debe seguir esta estructura. No inventar patrones alternativos.

```text
[Modulo]Page.vue (orquestador)
  │
  ├── PageHeader
  │     ├── título + subtítulo
  │     └── slot #actions: botón filtros + botón nuevo + botón exportar
  │
  ├── FilterPanel (v-model showFilters)
  │     └── campos de filtro en grid q-col-gutter-md
  │
  ├── AppTable (desktop)
  │     └── slots cell-{col} para columnas personalizadas
  │
  ├── Lista q-card (móvil, opcional si la página lo requiere)
  │
  └── q-dialog (create/edit)
        └── formulario con q-input, q-select, q-toggle según el modelo
```

### Reglas de estilo

- Fondo de página: `class="bg-grey-2"` en `<q-page>`
- Padding interior: `class="q-pa-md"` en el `<div>` contenedor
- Inputs del formulario: siempre `dense outlined`
- Botones de acción de fila: `flat dense round` con `q-tooltip`
- Confirmación de borrado: siempre usar `$q.dialog({ cancel: true })`, nunca `confirm()` del browser
- Debounce en búsquedas de texto: mínimo `400`ms

### Columnas de AppTable

```javascript
const columns = [
  { name: 'nombre',   label: 'Nombre',   field: 'nombre',   align: 'left',   sortable: true },
  { name: 'status',   label: 'Estatus',  field: 'status',   align: 'center' },
  { name: 'actions',  label: '',         field: 'actions',  align: 'right'  },
]
```

---

## 11. Módulos actuales

| Módulo | Ruta | Página principal |
| --- | --- | --- |
| Dashboard | `/dashboard` | `Dashboard/DashboardPage.vue` |
| Empleados | `/employees` | `Employees/EmployeesPage.vue` |
| Vacaciones | `/employees/vacations` | `Employees/EmployeeVacationsPage.vue` |
| Incidencias | `/employees/incidences` | `Employees/EmployeesIncidencesPage.vue` |
| Citas | `/employees/appointments` | `EmployeeAppointments/EmployeeAppointmentsPage.vue` |
| Aguinaldo | `/employees/aguinaldo` | `Employees/EmployeesAguinaldoPage.vue` |
| Vehículos | `/vehicles` | `Vehicles/VehiclesPage.vue` |
| Asignaciones | `/vehicle-asignations` | `VehicleAsignations/VehicleAsignationsPage.vue` |
| Revisiones | `/vehicle-checks` | `VehicleChecks/VehicleChecksPage.vue` |
| Solicitudes chofer | `/driver-requests` | `DriverRequests/DriverRequestsPage.vue` |
| Clientes | `/clients` | `Clients/ClientsPage.vue` |
| Usuarios cliente | `/clients/users` | `Clients/ClientUsersPage.vue` |
| Viajes (captura) | `/ttpn_bookings/captura` | `TtpnBookings/TtpnBookingsCapturePage.vue` |
| Cuadre de viajes | `/ttpn_bookings/cuadre` | `TtpnBookings/TtpnBookingsCuadrePage.vue` |
| Travel Counts | `/travel_counts` | `TtpnBookings/TravelCountsPage.vue` |
| Discrepancias | `/ttpn_bookings/discrepancies` | `TtpnBookings/DiscrepanciesPage.vue` |
| Facturación | `/ttpn_bookings/invoicing` | `TtpnBookings/TtpnInvoicingPage.vue` |
| Nóminas | `/payrolls` | `Payrolls/PayrollsPage.vue` |
| Gasolineras | `/gas/gas_stations` | `Gas/GasStationsPage.vue` |
| Combustible | `/gas/gas_charges` | `Gas/GasChargesPage.vue` |
| Rendimiento | `/gas/performance` | `Gas/FuelPerformancePage.vue` |
| Servicios TTPN | `/ttpn_services` | `Services/TtpnServicesPage.vue` |
| Alertas | `/alerts` | `Alerts/AlertsPage.vue` |
| Usuarios | `/users` | `Users/UsersPage.vue` |
| Roles | `/roles` | `Users/RolesPage.vue` |
| Configuración | `/settings` | `Settings/SettingsPage.vue` |
| Permisos | `/privileges` | `Settings/UsuariosPermisos/PrivilegesManagementPage.vue` |
| Versiones | `/versions` | `Settings/Organizacion/VersionsPage.vue` |
| API Access | `/api-access` | `Settings/Integraciones/ApiAccessPage.vue` |
| Unidades de negocio | `/business-units` | `Settings/Organizacion/BusinessUnitsPage.vue` |

---

## 12. Router y rutas registradas

```javascript
// src/router/routes.js (estructura simplificada)
[
  {
    path: '/',
    component: MainLayout,
    meta: { requiresAuth: true },
    children: [
      // Todas las páginas autenticadas aquí
    ]
  },
  { path: '/login', component: LoginPage },
  { path: '/:catchAll(.*)*', component: ErrorNotFound },
]
```

### Agregar una ruta nueva

```javascript
// En routes.js, dentro de children:
{ path: 'mi-modulo', component: () => import('pages/MiModulo/MiModuloPage.vue') },
```

La importación dinámica (`import()`) hace lazy-loading automático — no requiere configuración adicional.

---

## 13. Stores Pinia

### `auth-store`

```javascript
const authStore = useAuthStore()

authStore.user          // objeto usuario o null
authStore.isAuthenticated  // true/false (getter)
authStore.login(email, password)  // async
authStore.logout()                // async
```

### `privileges-store`

```javascript
const privilegesStore = usePrivilegesStore()

privilegesStore.canAccess('employees')  // true/false
privilegesStore.canCreate('vehicles')
privilegesStore.setPrivileges(obj)   // al login
privilegesStore.clearPrivileges()    // al logout
```

### `catalogs-store`

Almacena catálogos globales cargados una vez por sesión:

```javascript
const catalogsStore = useCatalogsStore()

catalogsStore.invalidateAll()  // fuerza recarga en próxima visita
```

---

## 14. PWA — manifest e instalación

### `src-pwa/manifest.json`

```json
{
  "name": "Kumi by TTPN",
  "short_name": "Kumi Admin",
  "description": "Sistema de Administración TTPN",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#027be3",
  "icons": [
    { "src": "/ttpn_icon.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/ttpn_icon.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

### Botón de instalación

El `MainLayout.vue` captura el evento `beforeinstallprompt` del browser y muestra un botón "Instalar App" en el header cuando la PWA puede instalarse:

```javascript
// Captura el evento
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  deferredPrompt.value = e
  showInstallButton.value = true
})

// Al hacer clic en el botón
async function installApp() {
  deferredPrompt.value.prompt()
  const { outcome } = await deferredPrompt.value.userChoice
  if (outcome === 'accepted') showInstallButton.value = false
}
```

---

## 15. Flujo de trabajo y convenciones

### Branching

```text
main  ← producción (Netlify auto-deploy)
  ↑
transform_to_api  ← rama de desarrollo principal
  ↑
feature/nombre-feature  ← tu trabajo
```

```bash
git checkout transform_to_api
git pull origin transform_to_api
git checkout -b feature/nombre-feature

# Desarrollar...

git add src/pages/MiModulo/MiModuloPage.vue src/services/mi.service.js
git commit -m "feat(mi-modulo): agregar página y servicio"
git push origin feature/nombre-feature
# → Pull Request hacia transform_to_api
```

### Convención de commits

```text
feat:     nueva funcionalidad
fix:      corrección de bug
refactor: reorganización sin cambio de comportamiento
style:    solo estilos / formato
docs:     documentación
chore:    dependencias, configuración
```

### Agregar un módulo nuevo

1. Crear `src/services/[modulo].service.js`
2. Crear `src/pages/[Modulo]/[Modulo]Page.vue` siguiendo el patrón
3. Si hay dropdowns de catálogos → crear en `src/composables/dropdowns/`
4. Si la página es compleja → crear orquestador en `src/composables/orchestrators/`
5. Registrar ruta en `src/router/routes.js`
6. Agregar entrada en el sidebar de `MainLayout.vue`

### Linting y formato

```bash
npm run lint     # ESLint
npm run format   # Prettier
```

---

## 16. Despliegue en Netlify

### Configuración actual

| Campo | Valor |
| --- | --- |
| Build command | `quasar build -m pwa` |
| Publish directory | `dist/pwa` |
| Branch | `main` |
| Node version | `18` |

### `netlify.toml`

```toml
[build]
  command   = "quasar build -m pwa"
  publish   = "dist/pwa"

[[redirects]]
  from   = "/*"
  to     = "/index.html"
  status = 200
```

El redirect maneja el modo `history` de Vue Router — sin él, los refrescos de página fallan.

### Variables de entorno en Netlify

Configurar en **Site settings → Environment variables**:

```
API_URL = https://[backend-railway-url]
```

### Auto-deploy

Cada push a `main` dispara un build automático en Netlify. El tiempo de build es aproximadamente 3-4 minutos.

---

**Ultima actualizacion:** 2026-04-10
