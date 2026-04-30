# Silent Catch Blocks — 46 sin useNotify

**Fecha registrada:** 2026-03-20 (detectados en P0; prometidos en P1; nunca resueltos)
**Dominio:** frontend (transversal)
**Status:** Pendiente

## Descripción

Durante la limpieza SonarCloud P0 (2026-03-20) se dejaron 4 catch blocks con `/* silent */` para resolver en P1. En P1 se creó useNotify.js pero los catch blocks nunca recibieron tratamiento.

Al 2026-04-30 hay **46 `/* silent */` en 29 archivos**. No todos son catch blocks — algunos son comentarios de intención. Pero todos indican errores que se capturan sin notificar al usuario.

### Archivos principales afectados

Composables: `useTtpnBookingForm.js`, `useBusinessUnitContext.js`, `useBookingCaptureCatalogs.js`
Stores: `auth-store.js`
Componentes: `AlertBell.vue`, `AsignationDialog.vue`, `VehicleHistory.vue`, `VehicleCheckDialog.vue`, `AppointmentDialog.vue`, `CreateApiKeyDialog.vue`
Páginas: `EmployeesPage.vue`, `EmployeeVacationsPage.vue`, `EmployeeAppointmentsPage.vue`, `VehicleChecksPage.vue`, `DriverRequestsPage.vue`, `ClientsPage.vue`, `FuelPerformancePage.vue`, `GasChargesPage.vue`, `GasolineChargesPage.vue`, y otros.

## Impacto

**Severidad:** Media

- El usuario no sabe cuando una operación falla silenciosamente
- Dificulta debugging en producción
- SonarCloud sigue marcando estos blocks como code smell

## Solución propuesta

Reemplazar cada `/* silent */` con la llamada apropiada de useNotify:

```javascript
// Antes:
} catch (e) {
  /* silent */
}

// Después (para operaciones en background que no deben interrumpir el flujo):
} catch (e) {
  notifyError('Error al cargar los datos')
}

// O para errores de red esperados donde realmente queremos silencio:
} catch {
  // Omitir — solo si hay razón documentada
}
```

## Decidido por

Se dejaron silenciosos en el sprint P0 por urgencia. La intención original era resolverlos en P1, pero P1 se enfocó en el patrón useNotify y no volvió a estos casos.
