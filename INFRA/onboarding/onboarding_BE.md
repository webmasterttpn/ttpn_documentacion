# Guía de Onboarding - Kumi TTPN Admin V2

Bienvenido al equipo de desarrollo de Kumi TTPN Admin V2. Esta guía cubre la configuración del entorno y los patrones de trabajo actuales del proyecto.

---

## Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Configuración Inicial](#configuración-inicial)
3. [Arquitectura del Proyecto](#arquitectura-del-proyecto)
4. [Backend — Estructura y Patrones](#backend--estructura-y-patrones)
5. [Frontend — Estructura y Patrones](#frontend--estructura-y-patrones)
6. [Flujo de Trabajo](#flujo-de-trabajo)
7. [Testing](#testing)
8. [Recursos](#recursos)

---

## Requisitos Previos

### Software

| Herramienta | Versión mínima |
| --- | --- |
| Ruby | 3.3+ |
| Rails | 7.1+ |
| PostgreSQL | 15+ |
| Node.js | 18+ |
| Redis | 7+ |
| Git | 2.30+ |

### Accesos necesarios

- [ ] Repositorio GitHub
- [ ] Credenciales AWS S3 (documentos y archivos)
- [ ] Variables de entorno (`.env`) compartidas por el equipo
- [ ] Acceso a Supabase (producción) o PostgreSQL local (desarrollo)

---

## Configuración Inicial

### 1. Clonar el repositorio

```bash
git clone [URL_DEL_REPOSITORIO]
cd "Kumi TTPN Admin V2"
```

### 2. Variables de entorno

**Backend** (`ttpngas/.env`):

```bash
DATABASE_URL=postgresql://usuario:password@localhost/ttpngas_development
REDIS_URL=redis://localhost:6379/0
FRONTEND_URL=http://localhost:9000
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_REGION=us-east-2
AWS_BUCKET_NAME=ttpngas-production
DEVISE_JWT_SECRET_KEY=xxx
```

**Frontend** (`ttpn-frontend/.env`):

```bash
API_URL=http://localhost:3000
```

### 3. Backend

```bash
cd ttpngas
bundle install
rails db:create db:migrate
rails server
# API disponible en http://localhost:3000
```

### 4. Frontend

```bash
cd ttpn-frontend
npm install
quasar dev -m pwa
# UI disponible en http://localhost:9000
```

### 5. Sidekiq (jobs en background)

```bash
cd ttpngas
bundle exec sidekiq
```

### 6. Verificar

```bash
curl http://localhost:3000
# => "API TTPN Online"
```

---

## Arquitectura del Proyecto

```
Kumi TTPN Admin V2/            # Monorepo
│
├── ttpngas/                   # BACKEND — Rails 7.1 API mode
└── ttpn-frontend/             # FRONTEND — Quasar 2 / Vue 3 PWA
```

### Stack

| Capa | Tecnología |
| --- | --- |
| API | Ruby on Rails 7.1 (API mode) |
| Base de datos | PostgreSQL 15 |
| Jobs background | Sidekiq 8 + Redis 7 |
| Autenticación | Devise + JWT (devise-jwt) |
| Autorización | CanCan (ability.rb) + Privileges personalizados |
| WebSockets | ActionCable |
| API Docs | Rswag (Swagger/OpenAPI) — `/api-docs` |
| Queue monitoring | Sidekiq Web UI — `/sidekiq` (solo admin) |
| Frontend | Quasar 2.16 + Vue 3 |
| Estado global | Pinia (con persistencia) |
| HTTP Client | Axios |
| Deploy BE | Railway |
| Deploy DB | Supabase (PostgreSQL managed) |
| Deploy FE | Netlify |

---

## Backend — Estructura y Patrones

### Árbol de carpetas

```
ttpngas/
├── app/
│   ├── controllers/
│   │   ├── api/v1/              # Controladores REST (ver lista abajo)
│   │   │   ├── base_controller.rb          # Autenticación JWT, permisos base
│   │   │   ├── auth/                       # Login, logout, sesión
│   │   │   ├── client_auth/                # Auth para clientes externos
│   │   │   └── [dominio]_controller.rb
│   │   └── system_maintenance_controller.rb
│   │
│   ├── models/                  # 88 modelos ActiveRecord
│   │
│   ├── services/
│   │   ├── dashboard_data_service.rb
│   │   ├── ttpn_data_service.rb
│   │   ├── queue_import.rb
│   │   ├── alerts/
│   │   │   ├── dispatcher_service.rb
│   │   │   ├── email_sender_service.rb
│   │   │   └── push_sender_service.rb
│   │   ├── fuel_performance/
│   │   │   ├── performers_ranker.rb
│   │   │   ├── timeline_builder.rb
│   │   │   └── vehicle_calculator.rb
│   │   └── payroll_svc/
│   │       ├── report_exporter.rb
│   │       ├── report_query.rb
│   │       └── week_calculator.rb
│   │
│   ├── jobs/
│   │   ├── alert_dispatch_job.rb
│   │   ├── dashboard_calculation_job.rb
│   │   ├── dashboard_export_job.rb
│   │   ├── deactivate_expired_versions_job.rb
│   │   ├── doc_expiration_check_job.rb
│   │   ├── ttpn_booking_import_job.rb      # Importación masiva desde PHP/Excel
│   │   └── ttpn_calculation_job.rb
│   │
│   ├── mailers/
│   │   ├── alert_mailer.rb
│   │   ├── asignation_mailer.rb
│   │   └── client_user_mailer.rb
│   │
│   └── channels/
│       └── alerts_channel.rb               # WebSocket para notificaciones en tiempo real
│
├── config/
│   ├── routes.rb                # Solo mounts y draw calls
│   └── routes/                  # Rutas divididas por dominio
│       ├── auth.rb
│       ├── dashboard.rb
│       ├── vehicles.rb
│       ├── employees.rb
│       ├── clients.rb
│       ├── bookings.rb
│       ├── payroll.rb
│       ├── fuel.rb
│       ├── administration.rb
│       └── alerts.rb
│
├── spec/
│   ├── factories/
│   ├── models/
│   ├── requests/api/v1/         # Specs legacy (algunos generan Swagger)
│   ├── integration/api/v1/      # Specs principales para Swagger/OpenAPI
│   └── support/
│
└── documentacion/
    ├── ONBOARDING.md            # Este archivo
    ├── BACKEND_CHECKLIST.md     # Checklist de desarrollo
    └── README_FUNCIONES_POSTGRES.md
```

### Dominios de controladores

| Dominio | Controladores principales |
| --- | --- |
| Autenticación | `auth/`, `client_auth/` |
| Vehículos | `vehicles`, `vehicle_asignations`, `vehicle_checks`, `vehicle_documents`, `driver_requests`, `concessionaires` |
| Empleados | `employees`, `employee_vacations`, `employee_appointments`, `employees_incidences`, `aguinaldos`, `drivers_levels`, `labors` |
| Clientes | `clients`, `client_branch_offices`, `client_users`, `ttpn_services`, `ttpn_service_types`, `ttpn_foreign_destinies` |
| Viajes | `ttpn_bookings`, `travel_counts`, `ttpn_dashboard` |
| Nómina | `payrolls`, `payroll_reports`, `invoicings`, `invoice_types`, `kumi_settings`, `incidences` |
| Combustible | `gas_charges`, `gasoline_charges`, `gas_stations`, `fuel_performance` |
| Administración | `users`, `roles`, `privileges`, `api_users`, `api_keys`, `business_units`, `versions` |
| Alertas | `alerts`, `alert_contacts`, `alert_rules` |
| Catálogos | `suppliers`, `discrepancies`, `review_points` |

### BaseController — Autenticación

Todos los controladores heredan de `Api::V1::BaseController < ActionController::API`.

```ruby
# El BaseController hace:
before_action :authenticate_with_jwt   # Lee Bearer token del header
before_action :ensure_authenticated_user  # 401 si no hay usuario
before_action :set_business_unit_id    # Disponible como @business_unit_id

# current_user devuelve el User o ApiUser autenticado
# user_signed_in? true si hay usuario en sesión
```

El token JWT va en el header de cada request:

```http
Authorization: Bearer <token>
```

### Auditoría automática

Las tablas principales tienen `created_by_id` y `updated_by_id` (bigint, nullable). El `BaseController` los asigna automáticamente en cada create/update. La tabla `travel_counts` usa `user_id` para el responsable de autorización, y `created_by_id`/`updated_by_id` para auditoría técnica (el trigger los pone en `1` cuando el INSERT viene de PHP sin usuario).

### Trigger de travel_counts

La función `sp_tctb_insert()` (trigger BEFORE INSERT) hace automáticamente:

1. Construye `clv_servicio` si viene NULL (inserts desde PHP)
2. Defaultea `created_by_id`/`updated_by_id` a `1` si vienen NULL
3. Calcula `viaje_encontrado` y `ttpn_booking_id` buscando el booking correspondiente en ventana de ±15 min

### Sistema de Alertas

```
AlertRule (regla) → AlertDispatchJob → Alert (instancia)
                                     → AlertDelivery (canal: email/push/websocket)
                                     → AlertRead (leído/no leído por usuario)

Canales:
- EmailSenderService → AlertMailer
- PushSenderService  → Web Push
- AlertsChannel      → ActionCable WebSocket
```

Modelos: `AlertContact`, `AlertRule`, `AlertRuleRecipient`, `Alert`, `AlertRead`, `AlertDelivery`

### Documentación API (Swagger)

```bash
# Generar swagger.yaml desde los specs
bundle exec rails rswag:specs:swaggerize

# Ver en browser (servidor corriendo)
open http://localhost:3000/api-docs
```

Los specs están en `spec/integration/api/v1/`. Algunos specs legacy en `spec/requests/api/v1/` también contribuyen a Swagger — si hay conflicto, el integration spec tiene precedencia por orden de carga.

---

## Frontend — Estructura y Patrones

### Estructura de carpetas FE

```text
ttpn-frontend/src/
├── boot/
│   └── axios.js                  # Interceptor JWT, manejo de 401
│
├── stores/
│   ├── auth-store.js             # Usuario logueado, token JWT
│   ├── catalogs-store.js         # Catálogos globales
│   └── privileges-store.js       # Privilegios del usuario
│
├── layouts/
│   └── MainLayout.vue            # Sidebar + header + AlertBell
│
├── services/                     # Una función por endpoint, sin lógica de UI
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
│   ├── useCrud.js                # CRUD genérico reutilizable
│   ├── useCatalogs.js            # Carga de catálogos
│   ├── useFilters.js             # Estado y lógica de filtros
│   ├── useNotify.js              # Notificaciones Quasar
│   ├── usePrivileges.js          # Guards de permisos
│   ├── useBusinessUnitContext.js # Contexto de unidad de negocio
│   ├── useDateFormat.js
│   ├── useSelectFilter.js
│   ├── usePayrollSettings.js
│   ├── useDropdownCache.js
│   ├── useTtpnBookingForm.js
│   ├── useTtpnBookingImport.js
│   │
│   ├── orchestrators/            # Orquestadores de página complejos
│   │   ├── useClientsOrchestrator.js
│   │   ├── useEmployeesOrchestrator.js
│   │   └── useVehiclesOrchestrator.js
│   │
│   └── dropdowns/                # Dropdowns cacheados por entidad
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
├── components/                   # Componentes reutilizables globales
│   ├── AppTable.vue              # Tabla estándar con paginación y slots
│   ├── FilterPanel.vue           # Panel colapsable de filtros
│   ├── PageHeader.vue            # Encabezado de página con acciones
│   ├── AlertBell.vue             # Campana de notificaciones (WebSocket)
│   ├── AppProgressDialog.vue
│   ├── BusinessUnitSelector.vue
│   ├── CatalogManager.vue
│   ├── KPIs/                     # Tarjetas de KPIs para dashboards
│   └── calendar/
│
└── pages/                        # Una carpeta por módulo
    ├── Dashboard/
    ├── Vehicles/
    ├── Employees/
    ├── Clients/
    ├── TtpnBookings/
    ├── TtpnBookingsCapture/
    ├── TravelCounts/
    ├── Payrolls/
    ├── Gas/
    ├── Services/
    ├── Users/
    ├── Settings/
    ├── Alerts/
    ├── ApiAccess/
    ├── DriverRequests/
    ├── EmployeeAppointments/
    ├── VehicleAsignations/
    ├── VehicleChecks/
    ├── VehicleCatalogs/
    └── Suppliers/
```

### Patrón estándar de página

Toda página sigue este patrón obligatorio:

```text
Page.vue (orquestador)
  ├── usa composable de dominio o useClientsOrchestrator
  ├── <FilterPanel> — filtros colapsables
  ├── <PageHeader> — título + botones de acción
  ├── <AppTable> — tabla con slots para columnas personalizadas
  └── <Dialog/Drawer> — formularios de create/edit
```

```vue
<!-- Ejemplo: EmployeesPage.vue -->
<template>
  <q-page>
    <PageHeader title="Empleados" @add="openCreate" />
    <FilterPanel v-model="filters" :fields="filterFields" @search="fetchData" />
    <AppTable
      :rows="employees"
      :columns="columns"
      :loading="loading"
      :pagination="pagination"
      @request="onRequest"
    >
      <template #actions="{ row }">
        <q-btn flat icon="edit" @click="openEdit(row)" />
      </template>
    </AppTable>
  </q-page>
</template>

<script setup>
import { useEmployeesOrchestrator } from 'src/composables/orchestrators/useEmployeesOrchestrator'
// El orquestador encapsula: fetchData, filters, pagination, openCreate, openEdit...
const { employees, loading, filters, pagination, fetchData, openCreate, openEdit } =
  useEmployeesOrchestrator()
</script>
```

### Composable de servicio (service layer)

Los servicios son funciones puras que llaman a la API. Sin estado, sin lógica de UI.

```javascript
// src/services/employees.service.js
import { api } from 'boot/axios'

export const getEmployees = (params) => api.get('/api/v1/employees', { params })
export const getEmployee = (id) => api.get(`/api/v1/employees/${id}`)
export const createEmployee = (data) => api.post('/api/v1/employees', data)
export const updateEmployee = (id, data) => api.patch(`/api/v1/employees/${id}`, data)
export const deleteEmployee = (id) => api.delete(`/api/v1/employees/${id}`)
```

### Dropdowns cacheados

Los dropdowns de catálogos se cachean para no recargar en cada navegación:

```javascript
// src/composables/dropdowns/useClientsDropdown.js
// Exporta: clientOptions (ref), loadClients()
// Se llama una vez por sesión, se reutiliza en toda la app
```

### Privilegios

```javascript
import { usePrivileges } from 'src/composables/usePrivileges'

const { can } = usePrivileges()

// En template:
// <q-btn v-if="can('create', 'employees')" ... />
```

---

## Flujo de Trabajo

### Branching

```text
main (producción — Netlify + Railway)
  ↑
transform_to_api (desarrollo principal)
  ↑
feature/nombre-feature (tu trabajo)
```

### Crear una feature

```bash
git checkout transform_to_api
git pull origin transform_to_api
git checkout -b feature/nombre-descriptivo

# desarrollar...

git add archivo1 archivo2          # Nunca git add -A sin revisar
git commit -m "feat(módulo): descripción"
git push origin feature/nombre-descriptivo
# → Pull Request hacia transform_to_api
```

### Convención de commits

```text
feat:     nueva funcionalidad
fix:      corrección de bug
refactor: reorganización sin cambio de comportamiento
docs:     cambios en documentación
test:     agregar o corregir tests
chore:    dependencias, configuración
```

### Crear migración

```bash
rails g migration NombreDeMigracion
rails db:migrate

# Siempre revisar que db/schema.rb esté actualizado antes de commit
```

### Agregar un endpoint nuevo

1. Agregar ruta en `config/routes/[dominio].rb`
2. Crear o actualizar controlador en `app/controllers/api/v1/`
3. Agregar spec en `spec/integration/api/v1/[dominio]_spec.rb`
4. Regenerar Swagger: `bundle exec rails rswag:specs:swaggerize`

### Agregar una página nueva (FE)

1. Crear carpeta `src/pages/NombreModulo/`
2. Crear `NombrePage.vue` usando `AppTable` + `FilterPanel` + `PageHeader`
3. Crear `src/services/nombre.service.js`
4. Crear composable en `src/composables/useNombreOrchestrator.js` si la página es compleja
5. Registrar ruta en `src/router/routes.js`

---

## Testing

### Backend (RSpec)

```bash
# Correr todos los specs
bundle exec rspec

# Spec específico
bundle exec rspec spec/integration/api/v1/employees_spec.rb

# Con documentación legible
bundle exec rspec --format documentation

# Generar Swagger desde specs
bundle exec rails rswag:specs:swaggerize

# Análisis de seguridad
bundle exec brakeman

# Linter
bundle exec rubocop
```

Los specs de integración en `spec/integration/api/v1/` son los que generan la documentación Swagger. Cada endpoint documentado ahí aparece en `/api-docs`.

### Comandos útiles de desarrollo

```bash
# Ver todas las rutas de la API
rails routes | grep "api/v1"

# Consola de Rails
rails console

# Revisar jobs pendientes (Sidekiq)
open http://localhost:3000/sidekiq   # solo con usuario admin

# Ver swagger generado
open http://localhost:3000/api-docs
```

---

## Recursos

### Documentación interna

- [BACKEND_CHECKLIST.md](BACKEND_CHECKLIST.md) — Checklist de desarrollo por módulo
- [README_FUNCIONES_POSTGRES.md](README_FUNCIONES_POSTGRES.md) — Funciones y triggers PostgreSQL

### Documentación externa

- [Rails Guides](https://guides.rubyonrails.org/)
- [Quasar Framework](https://quasar.dev/)
- [Vue 3](https://vuejs.org/)
- [Devise JWT](https://github.com/waiting-for-dev/devise-jwt)
- [Rswag](https://github.com/rswag/rswag)

### Herramientas recomendadas

- **TablePlus** — cliente PostgreSQL/Supabase
- **Bruno / Postman** — testing de API
- **Swagger UI** — `/api-docs` en local
- **Graphviz** — necesario para generar el ERD (`brew install graphviz`)

### Generar el ERD global

```bash
cd ttpngas
bundle exec erd
# → genera Documentacion/INFRA/database/ERD.pdf
```

Regenerar siempre que agregues modelos o asociaciones nuevas. Ver [INFRA/database/README.md](../database/README.md).

---

**Ultima actualizacion:** 2026-04-10
**Version:** 2.0
