# Resumen de Cambios para Stats Cards

## ✅ Backend - YA COMPLETADO

1. **Campo `status` agregado al response** del endpoint `/index`
2. **Nuevos stats agregados**: `inactive` e `inconsistent`
3. **Filtros agregados**: `match_status: 'inactive'` y `match_status: 'inconsistent'`

## ⏳ Frontend - PENDIENTE (Manual)

### 1. Reemplazar las tarjetas de stats (líneas 30-64)

Abre `ttpn-frontend/src/pages/TtpnBookings/TtpnBookingsCapturePage.vue` y reemplaza las líneas 30-64 con el contenido del archivo `STATS_CARDS_TEMPLATE.html`

### 2. Los handlers ya están agregados ✅

Los casos `'inactive'` e `'inconsistent'` ya fueron agregados a la función `filterByQuickStat`.

## 📊 Orden de las Tarjetas

1. **Hoy** (gris)
2. **Esta Semana** (gris)
3. **Sin Cuadrar** (naranja) - `status: true` AND `viaje_encontrado: false`
4. **Inactivos** (gris oscuro) - `status: false` AND `viaje_encontrado: false`
5. **Inconsistencias** (rojo) - `status: false` AND `viaje_encontrado: true`
6. **Cuadrados** (verde) - `status: true` AND `viaje_encontrado: true`

## 🔄 Próximos Pasos

1. Copia el contenido de `STATS_CARDS_TEMPLATE.html`
2. Pégalo en `TtpnBookingsCapturePage.vue` reemplazando las líneas 30-64
3. Guarda el archivo
4. Refresca el navegador (Ctrl+Shift+R)

## ✅ Resultado Esperado

- **Sin Cuadrar**: 35 (viajes activos sin cuadrar)
- **Inactivos**: 0 (viajes deshabilitados)
- **Inconsistencias**: 0 (viajes deshabilitados pero marcados como encontrados)
- **Cuadrados**: 0 (viajes activos y cuadrados)
- Los registros ahora mostrarán checkmarks verdes (✓) en lugar de X rojas (✗)
