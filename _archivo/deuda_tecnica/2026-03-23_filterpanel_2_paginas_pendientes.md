# FilterPanel — 2 páginas sin migrar

**Fecha registrada:** 2026-03-23 (detectado en auditoría 2026-04-30)
**Dominio:** frontend — Gas
**Status:** Pendiente

## Descripción

El estándar FilterPanel se implementó en marzo 2026 y 8 de las 10 páginas objetivo fueron migradas. Quedan 2 sin migrar:

1. `src/pages/TtpnBookings/DiscrepanciesPage.vue` — tiene filtros de fecha y estado
2. `src/pages/Gas/FuelPerformancePage.vue` — tiene filtros de rango de fechas

## Impacto

**Severidad:** Baja

- Inconsistencia visual vs el resto de páginas
- Estado de filtros activos no se muestra (no hay badge con conteo)
- SonarCloud puede detectar código duplicado

## Solución propuesta

Seguir los 5 pasos de `_archivo/cambios/FE/2026-03-23_filterpanel_estandar.md`:

1. Importar FilterPanel y useFilters
2. Reemplazar refs de filtros con `useFilters(initialFilters)`
3. Agregar handler `onClearFilters`
4. Actualizar botón toggle con badge
5. Envolver el panel en `<FilterPanel>`

## Decidido por

No se registró razón explícita para no migrarlas. Probablemente quedaron fuera por prioridad o por tener lógica de filtros más compleja (FuelPerformancePage tiene rangos de fecha dinámicos).
