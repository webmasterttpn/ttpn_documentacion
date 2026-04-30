# Cambio — Stats Cards en TtpnBookingsCapturePage

**Fecha:** 2026-03-27
**Estado:** Backend COMPLETADO / Frontend integrado en refactor de la página

---

## Cambios en backend

1. Campo `status` agregado al response del endpoint `/index`
2. Nuevos stats agregados: `inactive` e `inconsistent`
3. Filtros agregados: `match_status: 'inactive'` y `match_status: 'inconsistent'`

## Orden de las tarjetas de stats

1. **Hoy** (gris)
2. **Esta Semana** (gris)
3. **Sin Cuadrar** (naranja) — `status: true` AND `viaje_encontrado: false`
4. **Inactivos** (gris oscuro) — `status: false` AND `viaje_encontrado: false`
5. **Inconsistencias** (rojo) — `status: false` AND `viaje_encontrado: true`
6. **Cuadrados** (verde) — `status: true` AND `viaje_encontrado: true`

## Ver también

- [TtpnBookingsCapturePage.md](../../../Frontend/paginas/bookings/TtpnBookingsCapturePage.md) — refactor completo de la página donde se integró esto
