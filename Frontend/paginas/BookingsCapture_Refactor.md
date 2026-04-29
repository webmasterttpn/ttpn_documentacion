# Refactorización — TtpnBookingsCapturePage.vue

**Fecha:** 2026-03-27
**Estado:** COMPLETADO

---

## Resumen

`TtpnBookingsCapturePage.vue` pasó de **1,277 líneas** a **~213 líneas** como orquestador puro.
La lógica fue distribuida en 2 composables y 6 componentes específicos de página.

---

## Archivos creados

### Composables — `src/composables/TtpnBookingsCapture/`

| Archivo | Líneas | Descripción |
|---|---|---|
| `useBookingCaptureData.js` | ~214 | Fetch, paginación, CRUD, stats, `filterByQuickStat`, `viewBooking`, utils exportados |
| `useBookingCaptureCatalogs.js` | ~103 | Carga de 3 catálogos (clients, tipos, servicios), filtrado virtual-scroll |

### Componentes de página — `src/components/TtpnBookings/Capture/`

| Archivo | Líneas | Descripción |
|---|---|---|
| `BookingCaptureFilters.vue` | ~174 | 10 campos del slot de FilterPanel |
| `BookingCaptureTable.vue` | ~122 | q-table desktop, `columns[]` interno, checkbox, 4 acciones |
| `BookingCaptureMobileList.vue` | ~150 | Vista tarjetas mobile con chips de creation_method y pasajeros |
| `BookingCaptureImportDialog.vue` | ~57 | Dialog import Excel con barra de progreso, usa `useTtpnBookingImport` |
| `BookingCaptureDetailDialog.vue` | ~110 | Dialog detalle + lista de pasajeros |
| `BookingCaptureDeleteDialog.vue` | ~22 | Dialog progreso de eliminación múltiple |

---

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | Reemplazado completamente — orquestador ~213 líneas |

---

## Componentes reutilizados (no creados)

| Componente | Dónde estaba | Cómo se usa |
|---|---|---|
| `StatsBar.vue` | `src/components/` | Ya migrado en sesión anterior, sin cambios |
| `FilterPanel.vue` | `src/components/` | `<FilterPanel v-model="showFilters" :active-count="activeFiltersCount" @clear="onClearFilters">` |
| `TtpnBookingForm.vue` | `src/components/TtpnBookings/` | Ya era un componente extraído, sin cambios |
| `useFilters.js` | `src/composables/` | `useFilters({ ...INITIAL_FILTERS })` |
| `useTtpnBookingImport.js` | `src/composables/` | Usado internamente en `BookingCaptureImportDialog` |
| `useNotify.js` | `src/composables/` | Sin cambios |

---

## Decisiones de diseño

### INITIAL_FILTERS exportado desde el composable de datos

```js
export const INITIAL_FILTERS = Object.freeze({
  fecha_inicio: null, fecha_fin: null, hora: null,
  encontrado: null, client: null, status: null,
  match_status: null, tipo: null, servicio: null,
  unidad: null, chofer: null,
})
```

La página usa `useFilters({ ...INITIAL_FILTERS })` para que `activeFiltersCount` sea correcto.

### formatDate y getRowClass exportados como funciones nombradas

```js
import { formatDate, getRowClass } from 'src/composables/TtpnBookingsCapture/useBookingCaptureData'
```

Los componentes hijos (`BookingCaptureTable`, `BookingCaptureMobileList`) los importan
sin instanciar el composable — mismo patrón que TravelCounts.

### filterByQuickStat — showFilters en la página, no en el composable

El composable muta los filtros y recarga datos. La página añade:

```js
function onQuickStat(type) {
  filterByQuickStat(type)
  showFilters.value = true  // responsabilidad de la página
}
```

### BookingCaptureFilters — patrón inmutable (mismo que TravelCountsFilters)

Recibe `modelValue` (objeto completo), emite `update:modelValue` con objeto nuevo + `change`.
Los catálogos dinámicos (clients, tipos, servicios) llegan como props con sus handlers.

### deletingMultiple y deleteProgress en el composable

El dialog de progreso es pasivo — solo muestra el estado. El composable gestiona
`deletingMultiple` y `deleteProgress` y los expone como refs. La página los pasa al dialog:

```html
<BookingCaptureDeleteDialog v-model="deletingMultiple" :progress="deleteProgress" />
```

### viewBooking en el composable de datos

Llama a `bookingsService.find(id)`, setea `selectedBookingDetail` y `showDetailDialog`.
Estos tres se exportan desde el composable y la página los pasa al dialog correspondiente.

### Catálogos: fetchAll para onMounted

```js
const { fetchAll } = useBookingCaptureCatalogs()
onMounted(() => {
  fetchBookings()
  fetchStats()
  fetchAll()  // Promise.allSettled([fetchClients, fetchTipos, fetchServicios])
})
```

Los tres catálogos se cargan al inicio (no lazy) porque se usan en el formulario
`TtpnBookingForm` y los filtros simultáneamente. Cada fetch individual aún tiene
guard `if (length > 0) return` para `@popup-show` y llamadas redundantes.

---

## Estructura final

```
src/
  components/
    StatsBar.vue                          ← compartido (creado en TravelCounts refactor)
    FilterPanel.vue                       ← ya existía
    TtpnBookings/
      TtpnBookingForm.vue                 ← ya existía, sin cambios
      TtpnBookingPassengerList.vue        ← ya existía, sin cambios
      Capture/                            ← NUEVA carpeta
        BookingCaptureFilters.vue
        BookingCaptureTable.vue
        BookingCaptureMobileList.vue
        BookingCaptureImportDialog.vue
        BookingCaptureDetailDialog.vue
        BookingCaptureDeleteDialog.vue

  composables/
    useFilters.js                         ← ya existía, reutilizado
    TtpnBookingsCapture/                  ← NUEVA carpeta
      useBookingCaptureData.js
      useBookingCaptureCatalogs.js

  pages/
    TtpnBookings/
      TtpnBookingsCapturePage.vue        ← reescrito (~213 líneas)
```

---

## Conteo de líneas resultante

| Archivo | Líneas |
|---|---|
| `TtpnBookingsCapturePage.vue` | 213 |
| `BookingCaptureFilters.vue` | 174 |
| `BookingCaptureTable.vue` | 122 |
| `BookingCaptureMobileList.vue` | 150 |
| `BookingCaptureImportDialog.vue` | 57 |
| `BookingCaptureDetailDialog.vue` | 110 |
| `BookingCaptureDeleteDialog.vue` | 22 |
| `useBookingCaptureData.js` | 214 |
| `useBookingCaptureCatalogs.js` | 103 |
| **Total distribuido** | **1,165** |

Reducción del orquestador: **1,277 → 213 líneas (−83%)**.
Ningún archivo supera 215 líneas.
