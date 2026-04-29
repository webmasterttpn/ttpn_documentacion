# Introducción de `useNotify` — eliminación de código duplicado de notificaciones (2026-03-20)

## Contexto y motivación

Se identificaron **362 llamadas a `$q.notify({...})`** dispersas en 58 archivos del
frontend. Este patrón repetido es la principal fuente de duplicación de código
detectada por SonarCloud (`javascript:S4144` — bloque duplicado).

Adicionalmente, la inconsistencia en el uso de `color:` vs `type:` y la
variación en las opciones (icono, timeout, multiLine) hacía que bloques
semánticamente idénticos tuvieran sintaxis distinta, aumentando el conteo
de issues de SonarCloud.

---

## Composable creado: `src/composables/useNotify.js`

```js
import { useQuasar } from 'quasar'

export function useNotify() {
  const $q = useQuasar()

  function notifyOk(message, opts = {}) {
    $q.notify({ type: 'positive', message, ...opts })
  }

  function notifyError(message, opts = {}) {
    $q.notify({ type: 'negative', message, ...opts })
  }

  function notifyWarn(message, opts = {}) {
    $q.notify({ type: 'warning', message, ...opts })
  }

  function notifyInfo(message, opts = {}) {
    $q.notify({ type: 'info', message, ...opts })
  }

  function notifyErrorMultiline(message) {
    $q.notify({ type: 'negative', message, multiLine: true })
  }

  function notifyApiError(error, fallback = 'Error al guardar') {
    const message = error?.response?.data?.errors?.join(', ') || fallback
    $q.notify({ type: 'negative', message })
  }

  return { notifyOk, notifyError, notifyWarn, notifyInfo, notifyErrorMultiline, notifyApiError }
}
```

### Helpers y cuándo usar cada uno

| Helper | Cuándo usarlo |
|---|---|
| `notifyOk(msg, opts?)` | Operación exitosa (guardar, crear, eliminar, descargar) |
| `notifyError(msg, opts?)` | Error genérico con mensaje fijo |
| `notifyWarn(msg, opts?)` | Advertencia o validación fallida (campo obligatorio, acción no disponible) |
| `notifyInfo(msg, opts?)` | Mensaje informativo (estado en progreso, funcionalidad pendiente) |
| `notifyErrorMultiline(msg)` | Error con texto largo que requiere múltiples líneas |
| `notifyApiError(error, fallback)` | Error de API — extrae `errors[]` del response o usa fallback |

El parámetro `opts` acepta cualquier opción extra de Quasar Notify:
`{ icon, timeout, caption, position, actions, ... }`

---

## Patrón de uso en `.vue`

```js
import { useNotify } from 'src/composables/useNotify'

// En <script setup>:
const { notifyOk, notifyError } = useNotify()

// Uso:
notifyOk('Guardado correctamente')
notifyError('Error al cargar datos')
notifyApiError(error, 'Error al guardar')
notifyOk('Archivo descargado', { icon: 'file_download_done' })
notifyWarn('Campo obligatorio', { icon: 'warning' })
```

---

## Casos especiales que permanecen como `$q.notify`

### Patrón `dismiss` (notificación progresiva)

Dos páginas usan `$q.notify()` asignando el resultado a una variable `dismiss`
para cerrar la notificación programáticamente una vez completado el proceso:

```js
// TtpnInvoicingPage.vue y TtpnPayrollPage.vue
const dismiss = $q.notify({
  type: 'ongoing',
  message: 'Generando reporte...',
})
// ... después de completar:
dismiss()
```

Este patrón no es cubierto por los helpers porque el valor de retorno es la
función de cierre, no una notificación simple. Se mantiene como `$q.notify`
directo en esos 2 casos.

---

## Resultado

| Métrica | Antes | Después |
|---|---|---|
| Llamadas `$q.notify` en páginas/composables | 362 | 2 (dismiss pattern) |
| Archivos con `$q.notify` | 58 | 2 (solo dismiss) |
| Archivos que usan `useNotify` | 0 | 52 |
| Inconsistencias `color:` vs `type:` | ~80 | 0 — todo usa `type:` vía helper |

---

## Archivos modificados

### Composables
| Archivo | Cambio |
|---|---|
| `composables/useNotify.js` | **CREADO** — composable central |
| `composables/useTtpnBookingForm.js` | Eliminado `useQuasar`, reemplazados 3 notify (warning × 2, info × 1) |
| `composables/useTtpnBookingImport.js` | Eliminado `useQuasar`, reemplazado 1 notify (warning) |

### Components
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `components/CatalogManager.vue` | `+notifyWarn` | 1 (warning) |
| `components/BusinessUnitSelector.vue` | Import + `notifyInfo` | 1 (info) |
| `components/CreateApiKeyDialog.vue` | Procesado por agente | 1+ |

### Pages — Clients
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/Clients/ClientUsersPage.vue` | `+notifyInfo` | 1 (info) |
| `pages/Clients/components/ServiceForm.vue` | Import + `notifyWarn` | 1 (warning) |

### Pages — Settings / Config
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/Settings/VacationSettings.vue` | `+notifyInfo` | 1 (info) |

### Pages — Vehicles / Employees
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/VehiclesPage.vue` | `+notifyWarn` | 1 (warning) |
| `pages/EmployeesPage.vue` | `+notifyWarn` | 1 (warning) |
| `pages/EmployeesPayrollPage.vue` | `+notifyWarn` | 1 (warning) |

### Pages — Roles / Users
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/RolesPage.vue` | `+notifyWarn` | 2 (warning) |
| `pages/Users/RolesTable.vue` | Procesado por agente | 2+ |
| `pages/Users/UsersTable.vue` | Procesado por agente | 3+ |
| `pages/Users/InvitationsTable.vue` | Procesado por agente | 1+ |

### Pages — Services
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/Services/TtpnServiceDriverIncreasesPage.vue` | `+notifyWarn` | 3 (warning + positive + negative) |

### Pages — Payroll / Bookings
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/PayrollsPage.vue` | `+notifyWarn, +notifyInfo` | 3 (warning, info × 2) |
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | `+notifyInfo` | 1 (info) |
| `pages/TtpnBookings/TtpnInvoicingPage.vue` | `+notifyWarn` | 1 (warning) |
| `pages/TtpnBookings/TtpnPayrollPage.vue` | `+notifyInfo` | 1 (info) |
| `pages/TtpnBookings/TravelCountsPage.vue` | Procesado por agente | múltiple |
| `pages/TtpnBookings/DiscrepanciesPage.vue` | Procesado por agente | múltiple |

### Pages — API / Dashboard / otros
| Archivo | Helpers añadidos | Calls reemplazadas |
|---|---|---|
| `pages/ApiAccessPage.vue` | `+notifyInfo` | 1 (info) |
| `pages/Dashboard/DashboardPage.vue` | Procesado por agente | múltiple |
| `pages/DriverRequests/DriverRequestsPage.vue` | Procesado por agente | múltiple |
| Resto (30+ archivos) | Procesado por agente | múltiple por archivo |

---

## Compatibilidad

- Sin cambios en la UI — `type: 'positive'` y `color: 'positive'` son equivalentes
  en Quasar Notify; el helper normaliza todo a `type:`
- El parámetro `opts` spread permite pasar cualquier propiedad adicional
  (`icon`, `timeout`, `caption`, `position`, `actions`) sin perder flexibilidad
- `$q` sigue disponible en los 2 archivos con dismiss pattern y en todos los que
  necesitan `$q.dialog()` o `$q.screen`
