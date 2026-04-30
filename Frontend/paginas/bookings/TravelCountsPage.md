# Refactorización — TravelCountsPage.vue

**Fecha:** 2026-03-27
**Estado:** COMPLETADO

---

## Resumen

`TravelCountsPage.vue` pasó de **1,381 líneas** a **~130 líneas** como orquestador puro.
La lógica fue distribuida en 2 composables y 6 componentes específicos de página,
más 1 componente compartido nuevo (`StatsBar`) que también se adoptó en `TtpnBookingsCapturePage`.

---

## Archivos creados

### Componente compartido

| Archivo | Líneas | Descripción |
|---|---|---|
| `src/components/StatsBar.vue` | ~55 | Barra de stat cards genérica, data-driven, reutilizable en cualquier página |

### Composables — `src/composables/TravelCounts/`

| Archivo | Líneas | Descripción |
|---|---|---|
| `useTravelCountsData.js` | ~120 | Fetch, paginación, CRUD, `filterByQuickStat`, utils exportados |
| `useTravelCountsCatalogs.js` | ~120 | Carga paralela de 6 catálogos, filtrado virtual-scroll, `ensureInOptions` |

### Componentes de página — `src/components/TtpnBookings/TravelCounts/`

| Archivo | Líneas | Descripción |
|---|---|---|
| `TravelCountsFilters.vue` | ~110 | Campos del slot de FilterPanel (10 filtros) |
| `TravelCountsTable.vue` | ~100 | q-table desktop, patrón estándar, `columns[]` interno |
| `TravelCountsMobileList.vue` | ~80 | Vista tarjetas mobile |
| `TravelCountsImportDialog.vue` | ~65 | Dialog import Excel, estado interno |
| `TravelCountsDetailDialog.vue` | ~95 | Dialog detalle de viaje |
| `TravelCountsFormDialog.vue` | ~190 | Dialog crear/editar, form state interno, watch de `editingTravel` |

---

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `pages/TtpnBookings/TravelCountsPage.vue` | Reemplazado completamente — orquestador ~130 líneas |
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | Stats cards (50 líneas) reemplazadas por `<StatsBar>` |

---

## Componentes reutilizados (no creados)

| Componente | Dónde estaba | Cómo se usa |
|---|---|---|
| `FilterPanel.vue` | `src/components/` | `<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">` |
| `useFilters.js` | `src/composables/` | `useFilters({ ...INITIAL_FILTERS })` — reemplaza el estado inline de filtros |
| `useNotify.js` | `src/composables/` | Sin cambios |

---

## Decisiones de diseño

### StatsBar — genérico, no TTPN-específico

Props:
- `items: Array` — cada item: `{ key, label, value, color?, textColor?, noClick? }`
- `hasDateFilter: Boolean` — cuando `label === null` muestra "Total Rango" vs "Semana Nómina"

Emit: `quick-stat(key)`

El `label: null` es la convención para el card dinámico de semana. Las páginas definen sus propios `statItems` como computed.

### useFilters reutilizado (no duplicado)

`INITIAL_FILTERS` se exporta desde `useTravelCountsData.js` para que la página haga:

```js
const { filters, showFilters, activeFiltersCount, toggleFilters, clearFilters } =
  useFilters({ ...INITIAL_FILTERS })
```

### TravelCountsFilters — solo campos, sin envoltura

El componente emite `update:modelValue` con el objeto completo (inmutable, sin mutar props)
y `change` para que el padre llame `applyFilters()`. La envoltura visual la provee `FilterPanel`.

### Funciones de formato exportadas independientemente

`formatDate`, `formatTime`, `formatEmployeeName`, `getRowClass` se exportan como funciones
nombradas desde `useTravelCountsData.js`. Esto permite que los componentes hijos
(`TravelCountsTable`, `TravelCountsMobileList`, `TravelCountsDetailDialog`) las importen
sin instanciar el composable:

```js
import { formatTime, formatEmployeeName, getRowClass } from 'src/composables/TravelCounts/useTravelCountsData'
```

### TravelCountsTable — patrón estándar del proyecto

Adoptó el patrón de `TtpnBookingsCapturePage`:
- `v-model:selected` con checkbox column
- `v-slot:body` con `q-tr/:props` + `q-td v-for col`
- `columns[]` definido internamente en el componente

### TravelCountsFormDialog — form state interno

El form vive en el dialog. La página pasa:
- `:editing-travel` — objeto a editar (null = modo crear)
- `:saving` — estado de guardado del composable
- Catálogos filtrados y funciones de filtrado (via props)

El dialog emite `@save(form)` → la página llama `saveTravelCount(form, editingId, onSuccess)`.

### ensureInOptions — llamado desde la página al abrir edición

```js
function editTravel(travel) {
  ensureInOptions(travel.employee_id, employeeOptions.value, filteredEmployeeOptions)
  // ... (6 catálogos)
  editingTravel.value = travel
  showForm.value = true
}
```

### Duplicación futura pendiente

| Patrón | Páginas afectadas | Acción futura sugerida |
|---|---|---|
| `formatDate` / `formatTime` | TravelCounts, Dashboard, CapturePage | Extraer a `src/utils/format.js` |
| Lógica de import con polling | `useTtpnBookingImport` vs `TravelCountsImportDialog` | Crear `useImport(service)` genérico |

---

## Estructura final

```
src/
  components/
    StatsBar.vue                          ← NUEVO (compartido)
    FilterPanel.vue                       ← ya existía
    TtpnBookings/
      TtpnBookingForm.vue                 ← sin cambios
      TtpnBookingPassengerList.vue        ← sin cambios
      TravelCounts/                       ← NUEVA carpeta
        TravelCountsFilters.vue
        TravelCountsTable.vue
        TravelCountsMobileList.vue
        TravelCountsImportDialog.vue
        TravelCountsDetailDialog.vue
        TravelCountsFormDialog.vue

  composables/
    useFilters.js                         ← ya existía, reutilizado
    TravelCounts/                         ← NUEVA carpeta
      useTravelCountsData.js
      useTravelCountsCatalogs.js

  pages/
    TtpnBookings/
      TravelCountsPage.vue               ← reescrito (~130 líneas)
      TtpnBookingsCapturePage.vue        ← stats cards migradas a StatsBar
```

---

## Conteo de líneas resultante

| Archivo | Líneas |
|---|---|
| `TravelCountsPage.vue` | ~130 |
| `StatsBar.vue` | ~55 |
| `TravelCountsFilters.vue` | ~110 |
| `TravelCountsTable.vue` | ~100 |
| `TravelCountsMobileList.vue` | ~80 |
| `TravelCountsImportDialog.vue` | ~65 |
| `TravelCountsDetailDialog.vue` | ~95 |
| `TravelCountsFormDialog.vue` | ~190 |
| `useTravelCountsData.js` | ~120 |
| `useTravelCountsCatalogs.js` | ~120 |
| **Total distribuido** | **~1,065** |

Reducción del orquestador: **1,381 → 130 líneas (−91%)**.
Ningún archivo supera 200 líneas.

---

## Ver también

- [TtpnBookingsCapturePage.md](TtpnBookingsCapturePage.md) — misma sesión de refactor, patrón idéntico
- [README.md](README.md) — índice de todas las páginas del dominio bookings
- [Backend/dominio/bookings/](../../../../Backend/dominio/bookings/) — TtpnBooking, TravelCount, flujo de cuadre
