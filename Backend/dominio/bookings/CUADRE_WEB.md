# Cuadre de Servicios — versión web

Port del módulo de Cuadre del móvil a la web (admin Quasar + API Rails). Compara
lo **Programado** (`ttpn_bookings` / TB, capturistas) vs lo **Capturado**
(`travel_counts` / TC, choferes), por **planta** (facturación) o **chofer**
(nómina). El match TB↔TC ya es automático (callbacks + `TtpnCuadreService`);
este módulo solo **organiza y reporta**.

## Hechos de dominio

- `discrepancies.record_type`: `'Ttpn_booking'` (TB) / `'Travel_count'` (TC).
- `discrepancies.kpi`: `pnc`, `cnp`, `err`, `pcr`.
- **PNC** (Programado No Capturado) nace de un **TB**; **CNP** (Capturado No
  Programado) nace de un **TC**. NO son un selector: son inherentes a la tabla.
- **VCPA** = `travel_counts.comentario = 'VCPA'` (capturado por administrativo).
- Ventana de cuadre **continua**: `(fecha + hora) BETWEEN (fecha_ini + hora_desde)
  AND (fecha_fin + hora_hasta)`. `hora_desde`/`hora_hasta` (params
  `hora_inicio`/`hora_fin`) definen los límites del día inicial y final; si no se
  dan, usan el corte (`KumiSetting.payroll_hora_corte`, default 01:30). Ej. "del 7
  a la 01:30 al 14 a la 01:30" = una sola ventana continua. **No** se agrega
  `+1 día` (el usuario controla `fecha_fin`); planta y chofer usan la misma
  ventana — la diferencia es el agrupamiento y que chofer excluye VCPA.
- Filtro de vehículo operativo: `vehicles.clv LIKE 'T%'/'U%'/'A%'/'V%'`.
- Semáforo (igual que el adaptador móvil): `capturados == programados` → verde;
  `<` → ámbar (faltan); `>` → rojo (exceso).

## Backend

### Resumen (agregación) — Python + async

`GET /api/v1/cuadre/resumen?modo=planta|chofer&from=&to=&hora_inicio=&hora_fin=`
→ **202 + `job_id`**. El resultado llega por ActionCable (`JobStatusChannel`,
`kind: 'cuadre_resumen'`). Sin polling.

- `Api::V1::CuadreController#resumen` → encola `Cuadre::ResumenJob`.
- `Cuadre::ResumenJob` lee el `corte` de `KumiSetting` y corre el script Python
  vía `EjecutarScriptPythonJob`; al terminar hace broadcast a
  `job_status_#{user_id}`.
- Scripts: `scripts/cuadre/resumen_por_planta.py` y `resumen_por_chofer.py`
  (cuentan programados vs capturados; por chofer `fecha_fin + 1 día` y excluye
  VCPA en capturados). Devuelven `[{ id, nombre, programados, capturados,
  semaforo }]`. Tests: `scripts/cuadre/test_resumen.py` (pytest).

### Drill-down — Ruby (paginado)

- `GET /api/v1/cuadre/descuadres?modo=&id=&from=&to=&hora_inicio=&hora_fin=` →
  dos secciones fijas `{ capturistas: [...TB], choferes: [...TC] }`: viajes NO
  cuadrados (`viaje_encontrado` false/null) y SIN discrepancia activa.
- `GET /api/v1/cuadre/pnc?modo=&id=&from=&to=` → TB con discrepancia PNC activa.
- `GET /api/v1/cuadre/cnp?modo=&id=&from=&to=` → TC con discrepancia CNP activa.
- Serializadores (campos del móvil) en el concern `CuadreSerializable`:
  cliente, fecha, hora (wall-clock), tipo_servicio, unidad, destino, chofer,
  teléfono (employee_document tipo 13, en batch), comentario, descripción.
- `id` = `client_id` (planta) o `employee_id` (chofer).

Filtros de BU aplican en todo el cuadre (los PHP del móvil no los tenían).

## Frontend

- `src/services/cuadre.service.js` — endpoints.
- `src/composables/Cuadre/useCuadre.js` — `runResumen()` (encola + escucha
  `JobStatusChannel`, sin polling), `fetchDescuadres/fetchPnc/fetchCnp()`.
- `src/pages/TtpnBookings/TtpnBookingsCuadrePage.vue` — selector planta/chofer +
  rango fecha + hora desde/hasta + tabla resumen con semáforo; click en fila →
  drill-down. (Se quitó el tab "Alertas".)
- `src/pages/TtpnBookings/components/Cuadre/CuadreDrilldown.vue` — diálogo con 3
  vistas: "Sin cuadrar" (Capturistas/Choferes), "PNC", "CNP".

## Pendiente

- **Fase 3 — Acciones** (diferida): AGREGAR (crea TC `comentario='VCPA'`), ERR
  (corrige TC), PCR (discrepancia `kpi='pcr'`), AUTORIZAR CNP (+ FCM coordinador),
  CANCELAR CNP (+ FCM chofer). El FE actual es **solo lectura**.
- **Swagger (rswag)** de los 4 endpoints del cuadre.
- Validar contra el móvil que los conteos del resumen coinciden para el mismo
  periodo (corte 01:30, filtro clv, VCPA en chofer).
