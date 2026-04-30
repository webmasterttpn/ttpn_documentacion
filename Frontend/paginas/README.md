# Frontend — Páginas

Documentación de páginas del frontend, organizada por dominio de negocio.
Cada carpeta espeja la estructura de `Backend/dominio/`.

---

## Dominios

| Dominio | Carpeta | Páginas documentadas | Estado |
|---|---|---|---|
| Bookings | [bookings/](bookings/) | TtpnBookingsCapturePage, TravelCountsPage | Activo |
| Dashboard | [dashboard/](dashboard/) | DashboardPage (refactor pendiente) | Activo |
| Empleados | [employees/](employees/) | — | Stub |
| Vehículos | [vehicles/](vehicles/) | — | Stub |
| Combustible | [gas/](gas/) | — | Stub |
| Configuración | [settings/](settings/) | — | Stub |
| Clientes | [clientes/](clientes/) | — | Stub |
| Ruteo | [ruteo/](ruteo/) | — | Stub |
| Finanzas | [finanzas/](finanzas/) | — | Stub |
| Alertas | [alertas/](alertas/) | — | Stub |

---

## Patrón estándar de página

Toda página sigue el patrón:

```
PageOrquestador.vue           ← ≤250 líneas
  ├── useXxxData.js           ← fetch, paginación, CRUD, stats
  ├── useXxxCatalogs.js       ← catálogos async
  ├── XxxFilters.vue          ← campos del FilterPanel
  ├── XxxTable.vue            ← q-table desktop
  ├── XxxMobileList.vue       ← vista tarjetas mobile
  └── XxxFormDialog.vue       ← formulario crear/editar
```

Compartidos: `StatsBar.vue`, `FilterPanel.vue`, `useFilters.js`, `AppTable.vue`

---

## Ver también

- [Frontend/componentes/](../componentes/) — componentes compartidos
- [Frontend/patrones/](../patrones/) — patrones de diseño del frontend
- [Backend/dominio/](../../Backend/dominio/) — espejo de dominio en el backend
