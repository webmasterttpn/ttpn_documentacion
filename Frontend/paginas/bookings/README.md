# Frontend — Páginas: Dominio Bookings

Páginas del dominio `TtpnBookings` — captura, cuadre y conteos de viajes.

---

## Páginas

| Página | Archivo | Estado | Líneas |
|---|---|---|---|
| Captura de Bookings | [TtpnBookingsCapturePage.md](TtpnBookingsCapturePage.md) | COMPLETADO (refactor 2026-03-27) | ~213 |
| Conteos de Viajes | [TravelCountsPage.md](TravelCountsPage.md) | COMPLETADO (refactor 2026-03-27) | ~130 |
| Discrepancias | *(pendiente de documentar)* | — | — |

---

## Patrones aplicados

- Orquestador puro (~130–213 líneas) + composables + componentes atómicos
- `StatsBar.vue` compartido entre ambas páginas
- `FilterPanel.vue` + `useFilters.js` reutilizados
- Funciones de formato exportadas como named exports (sin instanciar el composable)

---

## Ver también

- [README.md de páginas FE](../README.md) — índice de todos los dominios
- [Backend/dominio/bookings/](../../../../Backend/dominio/bookings/) — TtpnBooking, TravelCount, flujo de cuadre
- [Frontend/componentes/](../../componentes/) — StatsBar, FilterPanel, AppTable
- [_archivo/cambios/FE/2026-03-27_stats_cards_ttpnbookings.md](../../../../_archivo/cambios/FE/2026-03-27_stats_cards_ttpnbookings.md) — stats cards implementadas en esta sesión
