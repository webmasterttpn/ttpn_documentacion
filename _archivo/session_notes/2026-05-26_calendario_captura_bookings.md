# 2026-05-26 — Vista de calendario en Captura de Servicios (ttpn_bookings) + overflow por dirección

## Contexto
Se pidió una vista de calendario en **Cuadre y Captura → Captura de Servicios** (como Citas a Empleados
/ Solicitudes de Mantenimiento) que muestre el **CLV programado** por día/semana/mes. Refinamientos del
usuario: diferenciar **entradas/salidas** (a las 6:00 puede haber ~10 entradas y ~10 salidas), tope de 3
**por dirección** con "+N", y **salidas en tono más oscuro**.

## Solución (solo frontend — el backend ya estaba listo)
- **Toggle lista/calendario** en `TtpnBookingsCapturePage.vue`. En calendario monta el `CalendarLayout`
  compartido con `:max-per-group="3"`.
- **Composable `useBookingCalendar.js`** (nuevo): reusa `GET /api/v1/ttpn_bookings` por rango (según la
  vista), mapea cada booking a evento:
  - `title` = CLV (`'Sin unidad'` si falta), `subtitle` = chofer · cliente.
  - `group` = `ttpn_service_type.nombre` ('Entrada'/'Salida').
  - `color` = estado de cuadre (hue) + dirección (intensidad): 🟢 programado `#21BA45`/`#15803D`,
    🟡 pendiente `#F59E0B`/`#B45309`,  ⚪ cuadrado `#9E9E9E`/`#5F6368` (entrada/salida; **salida más oscura**).
- **Clic en evento** → `viewBooking` (de `useBookingCaptureData`) → `BookingCaptureDetailDialog`
  (solo lectura), superpuesto sin salir del calendario.

## Overflow "+N" por dirección (componentes compartidos)
Helper nuevo `src/components/calendar/calendarOverflow.js` (`groupEvents`). Comportamiento **gated por
`maxPerGroup`** para no romper Citas/Solicitudes:
- **Sin `maxPerGroup`** (Citas, Solicitudes): comportamiento heredado intacto (Día/Semana absolutos por
  minuto; Mes 3 por día). Único cambio benéfico: el `+N más` de Mes ahora es **popover clickable**.
- **Con `maxPerGroup`=3** (Captura): cada horario/día agrupa por `ev.group` (Entrada/Salida), muestra
  hasta 3 por grupo + chip **"+N {grupo}"** con `q-menu` (lista todos del grupo; clic → `click-event`).
  - `CalendarMonthView`: agrupa por día.
  - `CalendarWeekView`: chips apilados por celda-hora (rama gated; la heredada sigue absoluta).
  - `CalendarDayView`: lista por hora (label + chips) en rama gated; la heredada sigue con grid absoluto.
- `CalendarLayout` recibe y propaga `maxPerGroup` a las tres vistas.

## Archivos
- NUEVOS: `ttpn-frontend/src/composables/TtpnBookingsCapture/useBookingCalendar.js`,
  `ttpn-frontend/src/components/calendar/calendarOverflow.js`.
- Modificados: `src/pages/TtpnBookings/TtpnBookingsCapturePage.vue` (toggle + calendario),
  `src/components/calendar/CalendarLayout.vue` (prop `maxPerGroup`),
  `CalendarMonthView.vue` / `CalendarWeekView.vue` / `CalendarDayView.vue` (overflow gated).
- Reutilizados sin tocar: `CalendarMiniCalendar.vue`, `BookingCaptureDetailDialog.vue`,
  `useBookingCaptureData.js` (`viewBooking`), `bookings.service.js`.

## Verificación
- ESLint 0 + `npm run build` **Build succeeded**.
- Regresión: Citas/Solicitudes no pasan `maxPerGroup` → rama heredada sin cambios; el build compiló todas
  las páginas.
- Sin cambios de backend ni de la vista de lista.

## Pendiente / mejoras futuras
- Optimización por volumen: endpoint ligero `ttpn_bookings/calendar` (payload mínimo) si el mes crece mucho.
- (Opcional) etiqueta E/S explícita además del tono.
