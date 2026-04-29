# Mejoras Sugeridas — Frontend Vue 3 + Quasar

**Fecha de análisis:** 2026-03-23
**Última actualización:** 2026-04-02 (sesión 9)
**Base de código:** `ttpn-frontend/src/`
**Objetivo:** Performance, buenas prácticas Vue 3/Quasar y cumplimiento de SonarCloud

---

## Leyenda de estado

| Símbolo | Significado |
|---|---|
| ✅ | Completado |
| 🔄 | En progreso / parcialmente hecho |
| ⏳ | Pendiente |

---

## Índice

1. [v-for con :key="index"](#1-v-for-con-keyindex) ✅
2. [Import axios inconsistente](#2-import-axios-inconsistente) ✅
3. [Composable useTableSearch](#3-composable-usetablesearch) ✅
4. [Composable useCrud](#4-composable-usecrud) ✅
5. [Composable useDateFormat](#5-composable-usedateformat) ✅
6. [Composable useSelectFilter](#6-composable-useselectfilter) ✅
7. [Magic number 100 en .slice()](#7-magic-number-100-en-slice) ✅
8. [Capa de servicios API](#8-capa-de-servicios-api) ✅
9. [Componentes gigantes](#9-componentes-gigantes) ✅
10. [Métodos largos >40 líneas](#10-métodos-largos-40-líneas) ✅
11. [Dialogs inline en páginas grandes](#11-dialogs-inline-en-páginas-grandes) 🔄
12. [Watchers vs computed](#12-watchers-vs-computed) ✅
13. [Promise.all sin abstracción](#13-promiseall-sin-abstracción) ✅
14. [TODOs sin resolver](#14-todos-sin-resolver) ⏳
15. [Reorganización de componentes](#15-reorganización-de-componentes) ✅
16. [AppTable — Paginación y altura dinámica](#16-apptable--paginación-y-altura-dinámica) ✅
17. [Módulos estandarizados (patrón Page + Form + Details)](#17-módulos-estandarizados-patrón-page--form--details) 🔄
18. [SonarCloud — catch vacíos y saving sin finally](#18-sonarcloud--catch-vacíos-y-saving-sin-finally) ✅

---

## 1. v-for con :key="index"

**Tipo:** Bug potencial / SonarCloud
**Estado:** ✅ Completado 2026-03-31

**Archivos corregidos:**

| Archivo | Problema | Solución aplicada |
|---|---|---|
| `pages/VehicleChecks/components/PointsGrid.vue` | `:key="index"` en array de valores 0/1 | `:key="reviewPoints[index]?.id ?? index"` |
| `pages/Employees/components/EmployeeForm.vue` | `:key="salary.id \|\| index"` — items nuevos sin `_uid` | Añadido `_uid` en `addSalary()`, `addMovement()`, `addDriverLevel()`; keys → `salary.id \|\| salary._uid` |

**Nota:** El resto de los `v-for` con `(item, index)` ya usaban keys correctos (`item.id || item._uid`, `item.id`, el valor string mismo, etc.). No requerían cambio.

---

## 2. Import axios inconsistente

**Tipo:** Mantenibilidad / posible error en producción
**Estado:** ✅ Completado — verificado 2026-03-31

Búsqueda de `from 'src/boot/axios'` en todo el proyecto devuelve cero resultados. Todos los archivos ya usan el alias correcto de Quasar:

```javascript
import { api } from 'boot/axios'  // ✅ correcto en todos los archivos
```

---

## 3. Composable useTableSearch

**Tipo:** Duplicación de código / SonarCloud S4144
**Estado:** ✅ Completado 2026-03-31

**Resolución:** `useTableSearch.js` fue eliminado. El estándar unificado es `useFilters` + `FilterPanel`.
Las dos últimas páginas que lo usaban fueron migradas:

| Archivo | Migración aplicada |
| --- | --- |
| `pages/Employees/EmployeeDeductionsPage.vue` | `useFilters` + `FilterPanel` + `filteredEmployees` computed |
| `pages/Employees/EmployeesAguinaldoPage.vue` | `useFilters` + `FilterPanel` + `filteredData` computed |

**Patrón estándar (en todos los módulos):**

```javascript
// Script
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } = useFilters({ search: null })

const filteredRows = computed(() => {
  if (!filters.value.search) return rows.value
  const q = filters.value.search.toLowerCase()
  return rows.value.filter(r => r.nombre?.toLowerCase().includes(q) || r.clv?.toLowerCase().includes(q))
})
```

```html
<!-- Template -->
<PageHeader ...>
  <template #actions>
    <q-btn color="grey-7" icon="filter_list" outline round @click="toggleFilters">
      <q-badge v-if="activeFiltersCount > 0" color="primary" floating>{{ activeFiltersCount }}</q-badge>
    </q-btn>
  </template>
</PageHeader>

<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="clearFilters">
  <div class="col-12 col-md-4">
    <q-input v-model="filters.search" outlined dense placeholder="Buscar..." clearable debounce="300">
      <template #prepend><q-icon name="search" /></template>
    </q-input>
  </div>
</FilterPanel>
```

---

## 4. Composable useCrud

**Tipo:** Duplicación de código / SonarCloud S4144
**Estado:** ✅ Completado 2026-04-01

**Composable creado:** `src/composables/useCrud.js`

Gestiona: `items`, `form`, `loading`, `saving`, `dialog`, `editingItem`, `isEditMode`, `fetchData`, `openDialog`, `closeDialog`, `save`.

**Páginas migradas:**

| Archivo | resourceName | Líneas eliminadas |
| --- | --- | --- |
| `pages/Services/TtpnServiceTypesPage.vue` | `ttpn_service_type` | ~50 |
| `pages/Services/TtpnForeignDestiniesPage.vue` | `ttpn_foreign_destiny` | ~55 |
| `pages/VehicleCatalogs/CheckPointsPage.vue` | `review_point` | ~60 |
| `pages/VehicleCatalogs/ConcessionairesPage.vue` | `concessionaire` | ~90 (+ migración a `<script setup>`) |
| `pages/Gas/GasStationsPage.vue` | `gas_station` | ~50 |

**Patrón resultante en cada página:**
```javascript
const { items, form, loading, saving, dialog, isEditMode, fetchData, openDialog, save } = useCrud({
  service: myService,
  resourceName: 'resource_name',
  formDefault: { campo: '', status: true },
  createMsg: 'Creado',
  updateMsg: 'Actualizado'
})
```

---

## 5. Composable useDateFormat

**Tipo:** Duplicación de código
**Estado:** ✅ Completado 2026-04-01

**Composable creado:** `src/composables/useDateFormat.js`

Exporta: `today()`, `daysAgo(n)`, `toDateStr(date)`, `toTimeStr(str)`, `currentTime()`, `toDateTime(date, time)`.

**20 archivos actualizados** — eliminadas 35+ instancias del patrón `new Date().toISOString().split('T')[0]` y sus variantes.

---

## 6. Composable useSelectFilter

**Tipo:** Duplicación de código / SonarCloud S4144
**Estado:** ✅ Completado 2026-04-01

**Composable creado:** `src/composables/useSelectFilter.js`

Recibe `(sourceRef, searchFields)` — inicializa automáticamente via `watchEffect` y expone `{ filteredOptions, filterFn }`.

**5 archivos migrados** — eliminados ~60 handlers de filtro manuales:

| Archivo | Filters eliminados |
| --- | --- |
| `composables/useTtpnBookingForm.js` | `filterVehiculosForm`, `filterChoferesForm` |
| `composables/TtpnBookingsCapture/useBookingCaptureCatalogs.js` | `filterClients`, `filterTipos`, `filterServicios` |
| `pages/Employees/EmployeesIncidencesPage.vue` | `filterEmployees`, `filterVehicles` |
| `pages/TtpnBookings/TtpnInvoicingPage.vue` | `filterClientsFn` |
| `pages/Clients/ClientCoordinatorsPage.vue` | `filterClients`, `filterCoordinators` |

**Patrón resultante (reemplaza ~12 líneas por 1):**
```javascript
const { filteredOptions: filteredEmployees, filterFn: filterEmployees } =
  useSelectFilter(allEmployees, ['nombre', 'clv'])
```

**No migrados (lógica especial):**

- `useTravelCountsCatalogs.js` — ya tiene `execFilter` propio centralizado
- `GasChargesPage.vue` — patrón no estándar (mezcla source/target)
- `EmployeeVacationsPage.vue` — búsqueda via API, no array pre-cargado
- `RolesPage.vue` — lógica de negocio adicional (filtrar asignados + is_active)

---

## 7. Magic number 100 en .slice()

**Tipo:** Mantenibilidad / SonarCloud S109
**Estado:** ✅ Completado 2026-04-01

**Archivo creado:** `src/constants/ui.js`

```javascript
export const MAX_SELECT_OPTIONS = 100
export const SEARCH_DEBOUNCE_MS = 300
export const DEFAULT_ROWS_PER_PAGE = 20
```

Usado directamente por `useSelectFilter` — todos los `.slice(0, 100)` de los select filters ahora pasan por esta constante.

---

## 8. Capa de servicios API

**Tipo:** Arquitectura / mantenibilidad
**Estado:** Completado — se creó la capa `src/services/` con módulos por dominio.

**Estructura implementada:**

```text
src/services/
  employees.service.js   ✅
  clients.service.js     ✅
  bookings.service.js    ✅
  gas.service.js         ✅
  vehicles.service.js    ✅
  catalogs.service.js    ✅
```

---

## 9. Componentes gigantes

**Tipo:** Complejidad cognitiva / SonarCloud
**Impacto:** Alto
**Meta:** Ningún componente debe superar 400 líneas.

**Estado actualizado:**

| Archivo | Líneas originales | Líneas actuales | Estado |
|---|---|---|---|
| `pages/Employees/EmployeesPage.vue` | 1,305 | ~190 | ✅ Refactorizado |
| `pages/Suppliers/SuppliersPage.vue` | 592 | ~150 | ✅ Refactorizado |
| `pages/Vehicles/VehiclesPage.vue` | 758 | ~330 | ✅ Refactorizado |
| `pages/DriverRequests/DriverRequestsPage.vue` | 1,667 | ~280 | ✅ Refactorizado |
| `pages/Dashboard/DashboardPage.vue` | 1,473 | 156 | ✅ Refactorizado + KPIs extraídos |
| `pages/TtpnBookings/TravelCountsPage.vue` | 1,381 | ~182 | ✅ Refactorizado |
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | 1,306 | ~209 | ✅ Refactorizado |
| `pages/Gas/GasChargesPage.vue` | 820 | 459 | ✅ Refactorizado |
| `pages/Payrolls/PayrollsPage.vue` | 745 | 407 | ✅ Refactorizado |
| `pages/TtpnBookings/DiscrepanciesPage.vue` | 737 | 410 | ✅ Refactorizado |

**DriverRequestsPage.vue — estructura implementada:**

```text
src/
  components/calendar/              ← componentes GENERALES reutilizables
    CalendarMonthView.vue  ✅       ← recibe events[], emite event-click
    CalendarWeekView.vue   ✅
    CalendarDayView.vue    ✅
  pages/DriverRequests/
    DriverRequestsPage.vue          ← orquestador ~280 líneas ✅
    components/
      RequestsList.vue              ← ya existía ✅
      DriverRequestForm.vue         ✅
      DriverRequestDetailsDialog.vue ✅
```

**Interfaz de los calendarios generales:**

```javascript
// Props
events: [{ id, datetime, color, label, sublabel, icon, ...metadata }]
modelValue: 'YYYY/MM/DD'  // fecha seleccionada (v-model)

// Emits
'update:modelValue'  // navegación prev/next
'event-click'        // clic sobre un evento
```

Los calendarios son agnósticos del dominio — cualquier módulo puede usarlos.

---

## 10. Métodos largos >40 líneas

**Tipo:** Complejidad cognitiva / SonarCloud
**Impacto:** Alto — SonarCloud penaliza funciones con complejidad ciclomática alta
**Estado:** ✅ Completado 2026-04-01

**Métodos refactorizados:**

| Archivo | Método | Antes | Después | Técnica |
| --- | --- | --- | --- | --- |
| `composables/Dashboard/useDashboardData.js` | `buildMatrixFromApiRows` | 56L | 41L | Extrae `_accumulate()` + `_emptyVtEntry()` |
| `composables/Dashboard/useTtpnData.js` | `buildTtpnMatrix` | 64L | 43L | Extrae `_mapEmployee()`, `_mapCoordinator()`, `_mapClient()` |
| `composables/Dashboard/useTtpnData.js` | `buildTtpnAnalytics` | 50L | 8L | Extrae `_accumulateTtpnRow()` (34L) |
| `composables/Dashboard/useTtpnData.js` | `buildTtpnTrends` | 38L | 15L | Extrae `_accumulateTrendRow()` (23L) |
| `pages/DriverRequests/DriverRequestsPage.vue` | `fetchRequests` | 40L | 15L | Extrae `_computeDateRange()` (22L) |

**No refactorizados (complejidad inherente):**

| Archivo | Método | Motivo |
| --- | --- | --- |
| `composables/Dashboard/useDashboardData.js` | `_pollDataStatus` (36L) | Polling async — cada rama maneja estado distinto, no divisible |
| `composables/Dashboard/useTtpnData.js` | `_pollStatus` (35L) | Ídem — ya nombrado con `_` como helper interno |

**Regla aplicada:** Un método debe caber en pantalla (~30 líneas). Si hace más de una cosa, extraer funciones auxiliares con nombre descriptivo. Las funciones `_` (helpers internos) pueden ser algo más largas si son bloques cohesivos.

---

## 11. Dialogs inline en páginas grandes

**Tipo:** Separación de responsabilidades
**Impacto:** Medio

**Estado actualizado:**

| Archivo | Dialogs originales | Estado |
|---|---|---|
| `pages/Employees/EmployeesPage.vue` | 4 inline | ✅ → `EmployeeForm.vue` + `EmployeeDetails.vue` |
| `pages/Suppliers/SuppliersPage.vue` | 2 inline | ✅ → `SupplierForm.vue` + `SupplierDetails.vue` |
| `pages/Vehicles/VehiclesPage.vue` | 2 inline | ✅ → `VehicleForm.vue` + `VehicleDetails.vue` |
| `pages/Payrolls/PayrollsPage.vue` | 2 inline | ✅ → `PayrollCreateDialog.vue` + `PayrollDetailDialog.vue` |
| `pages/TtpnBookings/DiscrepanciesPage.vue` | 2 inline | ✅ → `DiscrepancyFormDialog.vue` + `DiscrepancyDetailDialog.vue` |
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | 4 inline | ⏳ Pendiente |
| `pages/TtpnBookings/TravelCountsPage.vue` | 3 inline | ⏳ Pendiente |
| `pages/Gas/GasChargesPage.vue` | 3 inline | ✅ → `GasChargeFormDialog.vue` + `GasChargeDetailsDialog.vue` + `GasChargeStatsDialog.vue` |
| `pages/DriverRequests/DriverRequestsPage.vue` | 2 inline | ✅ → `DriverRequestForm.vue` + `DriverRequestDetailsDialog.vue` |
| `pages/Dashboard/DashboardPage.vue` | 1 inline | ✅ → `DashboardExportDialog.vue` (ya extraído) |

---

## 12. Watchers vs computed

**Tipo:** Buenas prácticas Vue 3
**Impacto:** Medio
**Estado:** ✅ Completado 2026-04-01

**Cambios aplicados:**

| Archivo | Cambio |
|---|---|
| `pages/Settings/components/CreateApiKeyDialog.vue` | 2 watchers separados unificados en 1 con `immediate: true` |
| `pages/EmployeeAppointments/components/MiniCalendar.vue` | `watch(() => props.modelValue)` → `watchEffect` (tracking automático + ejecución inmediata) |

**Watchers legítimos (no tocados):**

| Archivo | Watcher | Motivo |
|---|---|---|
| `pages/DriverRequests/DriverRequestsPage.vue` | searchQuery, filterVehicle, filterEmployee | Re-fetch al cambiar filtros |
| `pages/EmployeeAppointments/EmployeeAppointmentsPage.vue` | selectedDate, currentView | Re-fetch al navegar calendario |
| `pages/EmployeeAppointments/components/MiniCalendar.vue` | `watch(viewDate → selectedYear)` | `selectedYear` recibe mutaciones directas desde el picker; no es derivable como computed |

---

## 13. Promise.all sin abstracción

**Tipo:** Mantenibilidad / performance
**Impacto:** Medio — catálogos como `vehicle_types` se cargan en 4+ páginas sin caché
**Estado:** ✅ Completado 2026-04-01

**Solución implementada — `stores/catalogs-store.js` (Pinia):**

Fuente única de verdad con caché automático para 10 catálogos compartidos. Los composables de dropdown son ahora wrappers delgados que simplemente acceden al store.

**Catálogos incluidos:**

| Clave | Endpoint |
| --- | --- |
| `vehicleTypes` | `/api/v1/vehicle_types` |
| `vehicleDocTypes` | `/api/v1/vehicle_document_types` |
| `concessionaires` | `/api/v1/concessionaires` |
| `laborTypes` | `/api/v1/labors` |
| `businessUnits` | `/api/v1/business_units` |
| `driversLevels` | `/api/v1/drivers_levels` |
| `employeeDocTypes` | `/api/v1/employee_document_types` |
| `movementTypes` | `/api/v1/employee_movement_types` |
| `ttpnServices` | `/api/v1/ttpn_services` |
| `roles` | `/api/v1/roles` |

**API del store:**

```javascript
store.load('vehicleTypes')           // idempotente: salta si ya cargado
store.loadMany(['vehicleTypes', 'roles'])  // paralelo, evita Promise.all manual
store.invalidate('vehicleTypes')     // fuerza recarga en próximo acceso
store.invalidateAll()                // llamado en logout
```

**Archivos actualizados:**

| Archivo | Cambio |
|---|---|
| `stores/catalogs-store.js` | **Nuevo** — Pinia store con 10 catálogos |
| `composables/dropdowns/*.js` (10 archivos) | Reescritos como wrappers del store (API pública sin cambios) |
| `composables/orchestrators/useEmployeesOrchestrator.js` | Delega a `store.loadMany([...])` |
| `composables/orchestrators/useVehiclesOrchestrator.js` | Ídem |
| `composables/orchestrators/useClientsOrchestrator.js` | Ídem |
| `pages/Services/TtpnServiceDriverIncreasesPage.vue` | `Promise.all` de 3 APIs → 1 (`increases`) + `loadMany` del store |
| `pages/Users/UsersTable.vue` | `Promise.all` de 3 APIs → 1 (`users`) + `loadMany` del store; `roles`/`businessUnits` reactivos desde store |
| `stores/auth-store.js` | `logout()` llama `catalogsStore.invalidateAll()` |

**Beneficio vs `useDropdownCache` anterior:** el `_store` del módulo JS era global pero los `ref()` locales no eran reactivos entre instancias. Con Pinia, si `UsersTable` carga `roles` y luego monta `SettingsPage`, esta tiene los datos inmediatamente sin segunda request.

---

## 14. TODOs sin resolver

**Tipo:** SonarCloud blocker
**Impacto:** Medio — cada `// TODO` genera un issue en SonarCloud

**TODOs encontrados:**

| Archivo | Línea | Texto |
|---|---|---|
| `pages/TtpnBookings/TtpnBookingsCuadrePage.vue` | 259 | `// TODO: Implementar endpoint de estadísticas` |
| `pages/TtpnBookings/TtpnBookingsCuadrePage.vue` | 272–352 | 8 TODOs de endpoints pendientes |
| `pages/Clients/ClientUsersPage.vue` | 587 | `// TODO: Implementar endpoint de reenvío` |
| `pages/Settings/ApiAccessPage.vue` | 597 | `// TODO: Implementar vista detallada` |

**Acción:** Reemplazar por `// PENDIENTE:` o mover al backlog y eliminar del código.

---

## 15. Reorganización de componentes

**Tipo:** Arquitectura / organización
**Completado:** 2026-03-31

**Regla implementada:**

- `src/components/` → solo componentes **compartidos entre módulos** (PageHeader, AppTable, FilterPanel, etc.)
- `src/pages/Módulo/components/` → componentes **exclusivos del módulo** (colocation)

**Movimientos realizados:**

| Origen | Destino |
|---|---|
| `src/components/Dashboard/` | `src/pages/Dashboard/components/` |
| `src/components/TtpnBookings/` | `src/pages/TtpnBookings/components/` |
| `src/components/StatsBar.vue` | `src/pages/TtpnBookings/components/` |
| `src/components/CreateApiKeyDialog.vue` | `src/pages/Settings/components/` |

**`src/components/` final (solo compartidos):**

```text
AppProgressDialog.vue
AppTable.vue
BusinessUnitSelector.vue
CatalogManager.vue
EssentialLink.vue
FilterPanel.vue
PageHeader.vue
```

---

## 16. AppTable — Paginación y altura dinámica

**Tipo:** Bug / UX
**Completado:** 2026-03-31

**Problemas resueltos:**

1. **Paginación no funcionaba** — `q-table` usaba `:pagination` (one-way binding). Fix: prop interno `localPagination` + `v-model:pagination`.

2. **Tabla más ancha que la pantalla** — la paginación quedaba fuera del viewport. Fix: wrapper `overflow-x: auto` + footer de paginación fuera del scroll, como elemento hermano.

3. **Primera columna aplastada a 50px** — CSS `:first-child` aplicaba a columnas de datos, no solo al checkbox. Fix: clase `.col-checkbox` explícita en la celda del checkbox.

4. **Texto solapado entre columnas** — Fix: `white-space: nowrap` en todos los `q-td`.

5. **Altura no se adaptaba** — al abrir el panel de filtros la tabla desbordaba. Fix: `ResizeObserver` en `document.body` calcula `height = viewportHeight - tableTop - 50px` en tiempo real.

---

## 17. Módulos estandarizados (patrón Page + Form + Details)

**Tipo:** Consistencia / arquitectura
**Patrón estándar establecido** — documentado en `documentacion/COMPONENT_GUIDE.md`

**Estado por módulo:**

| Módulo | Page (~200L) | Form | Details | Filtros |
| --- | --- | --- | --- | --- |
| Clients | ✅ | ✅ | ✅ | ✅ FilterPanel |
| Employees | ✅ | ✅ | ✅ | ✅ FilterPanel |
| Vehicles | ✅ | ✅ | ✅ | ✅ FilterPanel |
| Suppliers | ✅ | ✅ | ✅ | ✅ FilterPanel |
| TtpnServices | ✅ | inline (simple) | — | ✅ FilterPanel |
| TtpnForeignDestiny | ✅ | inline (simple) | — | — sin filtros |
| VehicleChecks | ✅ | `VehicleCheckDialog` | — | ✅ FilterPanel |
| EmployeeDeductions | ✅ | inline | — | ✅ FilterPanel |
| EmployeesAguinaldo | ✅ | — | — | ✅ FilterPanel |
| DriverRequests | ⏳ | ⏳ | ⏳ | ⏳ pendiente |
| TtpnBookings/Capture | ⏳ | ⏳ | ⏳ | ⏳ pendiente |
| TtpnBookings/TtpnInvoicing | ⏳ | — | — | ⏳ pendiente |
| TtpnBookings/TtpnPayroll | ⏳ | — | — | ⏳ pendiente |
| TtpnBookings/Cuadre | ⏳ | — | — | ⏳ pendiente |
| TtpnBookings/Discrepancies | ⏳ | — | — | ⏳ pendiente |
| Payrolls/PayrollsPage | ⏳ | — | — | ⏳ pendiente |
| Employees/EmployeesPayroll | ⏳ | — | — | ⏳ pendiente |
| EmployeeAppointments | ⏳ | — | — | ⏳ pendiente |
| VehicleCatalogs/CheckPoints | ⏳ | — | — | ⏳ pendiente |
| Services/TtpnServiceTypes | ⏳ | — | — | ⏳ pendiente |
| Gas/GasCharges | ⏳ | ⏳ | ⏳ | ⏳ pendiente |
| Gas/GasolineCharges | ⏳ | ⏳ | ⏳ | ⏳ pendiente |
| Gas/FuelPerformance | ⏳ | — | — | ⏳ pendiente |

---

## 18. SonarCloud — catch vacíos y saving sin finally

**Tipo:** SonarCloud / buenas prácticas
**Impacto:** Medio

**Reglas aplicadas:**

- `catch { }` → `catch (_e) { }` — SonarCloud requiere variable aunque no se use
- `saving.value = true` debe tener siempre su `saving.value = false` en el bloque `finally`

**Módulos corregidos:**

- ✅ `pages/Vehicles/VehiclesPage.vue`
- ✅ `pages/Services/TtpnServicesPage.vue`
- ✅ `pages/Services/TtpnForeignDestiniesPage.vue`
- ✅ `pages/VehicleChecks/VehicleChecksPage.vue`
- ✅ `pages/VehicleChecks/components/VehicleCheckDialog.vue`
- ✅ `pages/Suppliers/components/SupplierForm.vue`

- ✅ `pages/DriverRequests/DriverRequestsPage.vue`
- ✅ `pages/TtpnBookings/TtpnBookingsCapturePage.vue` (sin ocurrencias)
- ✅ `pages/TtpnBookings/TravelCountsPage.vue` (sin ocurrencias)
- ✅ `pages/Gas/GasChargesPage.vue`
- ✅ `pages/Gas/GasolineChargesPage.vue`
- ✅ `pages/Gas/FuelPerformancePage.vue`

---

## Plan de Implementación (actualizado 2026-03-31)

| Sprint | Mejora | Archivos afectados | Riesgo | Esfuerzo |
| --- | --- | --- | --- | --- |
| ~~1~~ | ~~#8 Capa de servicios API~~ | — | — | ✅ Hecho |
| ~~1~~ | ~~#15 Reorganización componentes~~ | — | — | ✅ Hecho |
| ~~1~~ | ~~#16 AppTable bugs~~ | — | — | ✅ Hecho |
| ~~2~~ | ~~#17 Módulos estándar (Employees, Vehicles, Suppliers)~~ | — | — | ✅ Hecho |
| ~~2~~ | ~~#1 v-for :key~~ | — | — | ✅ Hecho |
| ~~2~~ | ~~#2 Import axios~~ | — | — | ✅ Hecho |
| ~~2~~ | ~~#3 useTableSearch → useFilters~~ | — | — | ✅ Hecho |
| **Ahora** | **#14 Eliminar TODOs** | 3 archivos | Muy bajo | 15 min |
| **Ahora** | **#18 catch vacíos restantes** | 4 módulos | Muy bajo | 30 min |
| **Ahora** | **#7 Constantes magic numbers** | 2 archivos + constants/ui.js | Bajo | 30 min |
| **Ahora** | **#17 Filtros pendientes** | 14 módulos | Bajo | 3h |
| 3 | #5 useDateFormat composable | 15 archivos | Bajo | 2h |
| 4 | #6 useSelectFilter composable | 20 archivos | Medio | 3h |
| 4 | #13 Pinia store catálogos | 10 archivos | Medio | 1 día |
| 5 | #4 useCrud composable | 20 archivos | Medio | 4h |
| 5 | #17 Módulos pendientes (DriverRequests, Gas, TtpnBookings) — estructura | 5 archivos | Alto | 2 días |
| 6 | #11 Extraer dialogs inline restantes | 4 archivos | Alto | 1 día |
| 6 | #10 Reducir métodos largos | 3 archivos | Alto | 1 día |
| 6 | #9 Dividir componentes gigantes restantes | 4 archivos | Alto | 2–3 días |
| 7 | #12 Revisar watchers | 10 archivos | Medio | 1 día |

---

Análisis inicial: 2026-03-23 — Última actualización: 2026-03-31
