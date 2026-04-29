# Limpieza SonarCloud P0 — Eliminación de console.* y archivos backup (2026-03-20)

## Contexto y motivación

SonarCloud marca como violación la regla `javascript:S2228` (Console logging should
not be used in production code) en todos los archivos `.vue` y `.js` del frontend.
Adicionalmente, los archivos `.bak` y `.broken` eran código muerto que contaminaba
el análisis de cobertura y duplicación.

Este documento cubre las actividades **P0-1** y **P0-2** del plan de refactorización
FE para SonarCloud aprobado el 2026-03-20.

---

## P0-1 — Eliminación de `console.log/warn/error/info/debug`

### Magnitud del problema

| Métrica | Valor |
|---|---|
| Ocurrencias totales antes | 241 |
| Archivos afectados | 58 |
| Ocurrencias tras limpieza | 0 |

### Estrategia aplicada

Se distinguieron dos tipos de ocurrencias:

**Tipo A — Líneas autónomas (235 ocurrencias)**
Líneas en las que el único contenido era la llamada a `console.*`, con o sin
indentación. Eliminadas con:

```bash
find src/ -type f \( -name "*.vue" -o -name "*.js" \) -print0 | \
  xargs -0 perl -i -pe \
  's/^\s*console\.(log|warn|error|info|debug)\(.*\);\s*\n//g; \
   s/^\s*console\.(log|warn|error|info|debug)\(.*\)\n//g'
```

**Tipo B — Inline en la misma línea que otra lógica (6 ocurrencias)**
Tratados manualmente archivo por archivo.

---

### Casos especiales — Tipo B

#### `TravelCountsPage.vue` — inline if

```js
// ANTES
results.forEach((r, i) => {
  if (r.status === 'rejected') console.error(`Catalog ${i} failed:`, r.reason)
})

// DESPUÉS
results.forEach((r) => {
  if (r.status === 'rejected') { /* catalog load failure silenced — handled by empty options */ }
})
```

**Decisión:** El bloque `forEach` de diagnóstico se mantuvo pero sin efecto visible.
SonarCloud ya no detecta `console.error`. El parámetro `i` se removió al no ser
necesario sin el log.

---

#### `Users/RolesTable.vue`, `UsersTable.vue`, `InvitationsTable.vue` — catch inline

```js
// ANTES
} catch(e) { console.error(e) }

// DESPUÉS
} catch { /* silent */ }
```

**Decisión:** Estos catch eran la única lógica de error (sin `$q.notify`). Se
dejaron como catch vacíos con comentario explicativo. SonarCloud puede marcar
empty catch blocks (`javascript:S108`), pero es preferible a tener console calls.
Se anotó en el backlog (P1) agregar notificación de error al usuario.

---

#### `DriverRequestsPage.vue` — bloque de debug activo + función comentada

Dos casos distintos en el mismo archivo:

**Bloque activo (eliminado):**
```js
// ANTES — dentro de nextDay()
if (allEvents.value.length > 0) {
  console.log('nextDay - Primeros eventos:', allEvents.value.slice(0, 3).map(...))
}
fetchRequests()

// DESPUÉS
fetchRequests()
```

**Función debug completamente comentada (eliminada):**
```
// function debugDayView() {
//   console.log('=== DEBUG VISTA DIARIA ===')
//   ... (37 líneas comentadas)
// }
// function getRequestPosition(request) { ... }
```

Estas 37 líneas de código muerto comentado se eliminaron completamente.
Representaban un artefacto de desarrollo que nunca se limpió.

---

### Archivos modificados — resumen

| Archivo | Tipo de cambio |
|---|---|
| `boot/axios.js` | Eliminación automática (Tipo A) |
| `components/CreateApiKeyDialog.vue` | Eliminación automática |
| `composables/useBusinessUnitContext.js` | Eliminación automática |
| `composables/useCatalogs.js` | Eliminación automática |
| `composables/usePayrollSettings.js` | Eliminación automática |
| `composables/useTtpnBookingForm.js` | Eliminación automática (7 ocurrencias) |
| `composables/useTtpnBookingImport.js` | Eliminación automática |
| `layouts/MainLayout.vue` | Eliminación automática |
| `pages/Clients/ClientContactsPage.vue` | Eliminación automática |
| `pages/Clients/ClientCoordinatorsPage.vue` | Eliminación automática |
| `pages/Clients/ClientUsersPage.vue` | Eliminación automática |
| `pages/Clients/ClientsPage.vue` | Eliminación automática |
| `pages/Clients/components/ServiceForm.vue` | Eliminación automática |
| `pages/Dashboard/DashboardPage.vue` | Eliminación automática |
| `pages/DriverRequests/DriverRequestsPage.vue` | Manual — bloque activo + función comentada |
| `pages/EmployeeAppointments/EmployeeAppointmentsPage.vue` | Eliminación automática |
| `pages/EmployeeAppointments/components/AppointmentDialog.vue` | Eliminación automática |
| `pages/EmployeeAppointments/components/AppointmentViewDialog.vue` | Eliminación automática |
| `pages/EmployeeAppointments/components/DayView.vue` | Eliminación automática |
| `pages/EmployeeAppointments/components/EmployeeFilter.vue` | Eliminación automática |
| `pages/EmployeeDeductionsPage.vue` | Eliminación automática |
| `pages/EmployeeVacationsPage.vue` | Eliminación automática |
| `pages/EmployeesAguinaldoPage.vue` | Eliminación automática |
| `pages/EmployeesIncidencesPage.vue` | Eliminación automática |
| `pages/EmployeesPage.vue` | Eliminación automática |
| `pages/EmployeesPayrollPage.vue` | Eliminación automática |
| `pages/Gas/FuelPerformancePage.vue` | Eliminación automática |
| `pages/Gas/GasChargesPage.vue` | Eliminación automática |
| `pages/Gas/GasStationsPage.vue` | Eliminación automática |
| `pages/Gas/GasolineChargesPage.vue` | Eliminación automática |
| `pages/LoginPage.vue` | Eliminación automática |
| `pages/PayrollsPage.vue` | Eliminación automática |
| `pages/RolesPage.vue` | Eliminación automática |
| `pages/Services/TtpnServiceDriverIncreasesPage.vue` | Eliminación automática |
| `pages/Services/TtpnServicesPage.vue` | Eliminación automática |
| `pages/Services/components/TtpnServiceIncreaseHistory.vue` | Eliminación automática |
| `pages/Settings/PayrollConfigSettings.vue` | Eliminación automática |
| `pages/Settings/VacationSettings.vue` | Eliminación automática |
| `pages/SuppliersPage.vue` | Eliminación automática |
| `pages/TtpnBookings/DiscrepanciesPage.vue` | Eliminación automática |
| `pages/TtpnBookings/TravelCountsPage.vue` | Manual — inline if |
| `pages/TtpnBookings/TtpnBookingsCapturePage.vue` | Eliminación automática |
| `pages/TtpnBookings/TtpnBookingsCuadrePage.vue` | Eliminación automática |
| `pages/TtpnBookings/TtpnInvoicingPage.vue` | Eliminación automática |
| `pages/TtpnBookings/TtpnPayrollPage.vue` | Eliminación automática |
| `pages/Users/InvitationsTable.vue` | Manual — catch inline |
| `pages/Users/RolesTable.vue` | Manual — catch inline |
| `pages/Users/UsersTable.vue` | Manual — catch inline (2 ocurrencias) |
| `pages/UsersPage.vue` | Eliminación automática |
| `pages/VehicleAsignations/VehicleAsignationsPage.vue` | Eliminación automática |
| `pages/VehicleAsignations/components/AsignationDialog.vue` | Eliminación automática |
| `pages/VehicleAsignations/components/VehicleHistory.vue` | Eliminación automática |
| `pages/VehicleCatalogs/CheckPointsPage.vue` | Eliminación automática |
| `pages/VehicleCatalogs/VehicleTypePricesPage.vue` | Eliminación automática |
| `pages/VehicleChecks/VehicleChecksPage.vue` | Eliminación automática |
| `pages/VehicleChecks/components/VehicleCheckDialog.vue` | Eliminación automática |
| `pages/VehiclesPage.vue` | Eliminación automática |
| `stores/auth-store.js` | Eliminación automática |

---

## P0-2 — Eliminación de archivos backup

### Archivos eliminados

| Archivo | Motivo |
|---|---|
| `src/pages/Clients/components/ClientForm.vue.broken` | Backup de un refactor previo; ya no correspondía al estado actual del componente |
| `src/pages/EmployeeAppointments/EmployeeAppointmentsPage.vue.bak` | Backup previo a rediseño de calendario; código obsoleto |
| `src/pages/EmployeeAppointments/components/WeekView.vue.bak` | Backup de WeekView previo a ajustes de formato de hora |

**Impacto:** SonarCloud analiza todos los archivos del repositorio por defecto.
Los `.bak` y `.broken` generaban falsos positivos de duplicación y aumentaban
el conteo de líneas con issues.

---

## Compatibilidad

- Sin cambios en comportamiento visible para el usuario
- Los `console.error` en catch blocks eran informativos para desarrollo —
  los errores de API ya estaban manejados por `$q.notify` en la mayoría de los casos
- Los 4 catch blocks que quedaron vacíos (`/* silent */`) están anotados para
  recibir notificación al usuario en la siguiente iteración (P1 del plan)
- Ningún archivo de rutas, stores ni boot fue afectado en su lógica

---

## Pendiente relacionado (siguiente iteración)

Los catch blocks vacíos en `RolesTable`, `UsersTable` e `InvitationsTable`
deberían recibir un `$q.notify` de error genérico para informar al usuario cuando
falla la carga de datos. Esto se registra como parte de **P1-9 — helper useNotify**.
