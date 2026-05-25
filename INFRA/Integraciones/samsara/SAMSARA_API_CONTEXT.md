# SAMSARA_API_CONTEXT — Integración GPS/Telemática en Kumi

Documento de **contexto, mapeo e ideas** para integrar la API REST de **Samsara**
(GPS/telemática de flotas) al proyecto Kumi (TTPN). No es un plan de implementación cerrado:
sirve para decidir **qué construir y en qué orden**, aterrizado en los módulos e infraestructura
que **ya existen** en Kumi.

> Prioridad acordada: **1) Mapa en vivo / rastreo · 2) Validar el cuadre con GPS ·
> 3) Conciliación de combustible + mantenimiento.** Alertas en tiempo real queda como
> extensión natural (la infraestructura ya está).

---

## 1. Propósito y alcance

- **Qué resuelve:** visibilidad en vivo de la flota, validación objetiva de los viajes
  (GPS vs. lo programado/capturado), control de combustible y mantenimiento basado en
  telemetría real (odómetro, fallas de motor).
- **Qué NO entra ahora:** cumplimiento HOS/ELD (es regulación de EE.UU., baja prioridad en MX),
  cámaras/coaching de seguridad, y reescribir el cuadre actual (Samsara lo **enriquece**, no lo
  reemplaza).
- **Principio:** reusar la infraestructura existente de Kumi (webhooks, alertas, ActionCable,
  Sidekiq-cron, Python async, `KumiSetting`, filtrado por unidad de negocio). No reinventar.

---

## 2. Conceptos de la API de Samsara

| Tema | Detalle |
|---|---|
| Base URL | `https://api.samsara.com` |
| Auth | Bearer token en header `Authorization: Bearer <token>` |
| Rate limit | ~10 req/seg en la mayoría de endpoints |
| Paginación | Cursor: enviar `after` con el cursor devuelto en la respuesta anterior |
| Snapshot | Estado actual de todo en un instante (una sola llamada) |
| Feed (cursor) | Cambios incrementales desde el último cursor — **eficiente para casi-tiempo-real** |
| History | Datos históricos por rango de fechas (backfill / reportes) |
| Webhooks | Samsara empuja eventos a nuestro endpoint — **evita polling** |
| Docs | <https://developers.samsara.com/reference/> y guías por caso de uso |

**Regla de ingesta:** usar **feed (cursor)** para datos vivos (guardando el `after`), **history**
para backfill puntual, y **webhooks** para eventos (alertas). Evitar polling de snapshot en bucle.

---

## 3. Mapeo Samsara → Kumi

Lo más valioso: Kumi ya tiene los "ganchos" para enlazar con Samsara.

| Entidad / endpoint Samsara | Modelo / campo Kumi | Módulo |
|---|---|---|
| Vehicle / Asset (id del dispositivo) | `vehicles.gps_uniq` (string, **índice único**, hoy sin uso) | Flotilla |
| Driver | `employees` (`clv`, `imei`) | Empleados / RH |
| Driver-vehicle assignment | `VehicleAsignation` (`employee_id`, `vehicle_id`, `fecha_efectiva`, `fecha_hasta`) | Asignaciones |
| Address / Geofence | `client_branch_offices.gps_uniq`, `crdhr_points.lat/lng`, `review_points` | Clientes / Ruteo |
| Trip / Locations history | Cuadre `TtpnBooking` ↔ `TravelCount` (`TtpnCuadreService`) | Viajes / Cuadre |
| Vehicle stats (odómetro, combustible) | `gas_charges.odometro`, patrón `GasCharge` ↔ `GasFile` | Combustible |
| Engine faults / check-engine | `Mtto::WorkOrder`, `ScheduledMaintenance`, `VehicleCheck` | Mantenimiento |
| DVIR (inspecciones) | `VehicleCheck`, `Mtto::WorkOrder` | Mantenimiento |
| Alert incidents (speeding, geofence…) | `Alert` / `AlertRule` + `Alerts::DispatcherService` | Alertas |
| Locations feed (live) | ActionCable (`alerts_#{bu_id}` como patrón de canal por BU) | Tiempo real |

> **Mapeo de unidades:** el emparejamiento flota Kumi ↔ Samsara se guarda en
> `vehicles.gps_uniq` (ya es único). El chofer puede mapearse por `employees.imei` si Samsara
> expone el dispositivo del conductor.

---

## 4. Casos de uso priorizados

### A. Mapa en vivo / rastreo de flota (prioridad 1)

- **Fuente Samsara:** `GET /fleet/vehicles/locations` (feed con cursor) o
  `GET /assets/location-and-speed/stream` (ubicación + velocidad de todos los activos).
- **Flujo en Kumi:**
  1. Un job de Sidekiq-cron consume el **feed** cada N segundos, guardando el cursor `after`.
  2. Empareja cada posición con el vehículo por `vehicles.gps_uniq` (y filtra por BU).
  3. Hace **broadcast por ActionCable** a un canal por unidad de negocio (mismo patrón que
     `alerts_#{bu_id}`) → el FE pinta marcadores en un mapa **Leaflet** (ya está en el stack).
- **Reusa:** patrón de canales ActionCable, `BusinessUnitAssignable`, Leaflet del FE.
- **No-polling en FE:** el FE solo se suscribe al canal; nunca hace polling (regla del proyecto).

### B. Validar el cuadre con GPS (prioridad 2)

- **Fuente Samsara:** `GET /fleet/trips` + `Vehicle Locations history`.
- **Idea:** el cuadre actual concilia **programado** (`TtpnBooking`) vs. **capturado por el
  chofer** (`TravelCount`) por `clv_servicio` + ventana de tiempo (`TtpnCuadreService`). Samsara
  agrega una **tercera fuente objetiva**: ¿el vehículo realmente se movió y llegó al destino?
- **Validaciones nuevas posibles:**
  - Viaje **capturado sin movimiento GPS** en esa ventana → sospechoso.
  - Viaje **GPS detectado sin captura** → falta capturar (PNC potencial).
  - **Llegada a destino** verificada por geocerca (`crdhr_points.lat/lng` /
    `client_branch_offices.gps_uniq`) dentro del rango horario del corte.
  - Atribución correcta al chofer usando `VehicleAsignation` activa en esa fecha/hora
    (wall-clock `America/Chihuahua`, igual que el cuadre).
- **Salida:** nueva señal/etiqueta en `Discrepancy` o un KPI de "viajes verificados por GPS".

### C. Conciliación de combustible + mantenimiento (prioridad 3)

- **Combustible:**
  - **Fuente:** `Vehicle Stats` (odómetro, nivel/consumo de combustible) y `Fuel & Energy`.
  - **Idea:** comparar el `odometro` que captura `GasCharge` contra el odómetro GPS para
    calcular **rendimiento real** y detectar **robo de combustible** (carga mayor a la capacidad
    o sin movimiento que la justifique). Reusa el patrón de conciliación que ya existe entre
    `GasCharge` ↔ `GasFile` (archivo de la gasolinera).
- **Mantenimiento:**
  - **Fuente:** `engine-immobilization` (fallas/check engine) y `DVIR` (inspecciones).
  - **Idea:** una falla o un DVIR con defecto → crea automáticamente una `Mtto::WorkOrder`
    (correctiva) o agenda un `ScheduledMaintenance`; el odómetro GPS alimenta el km de los
    `ScheduledMaintenance` (servicios por kilometraje) y los `VehicleCheck`.

### Secundario — Alertas en tiempo real

- **Fuente:** `Alert Incidents` + **webhooks** de Samsara (exceso de velocidad, geocerca,
  ralentí, frenazos).
- **Flujo:** webhook entrante → se crea un `Alert` (`trigger_type`, `source_type/source_id`
  apuntando al vehículo) → `Alerts::DispatcherService` lo entrega por **email / push FCM /
  ActionCable** a los destinatarios de la `AlertRule`. Toda la cañería ya existe.

---

## 5. Patrón técnico de integración (a reusar, sin implementar aún)

- **Ingesta de datos:**
  - *Feeds* (locations, stats, trips): job de **Sidekiq-cron** que guarda el cursor `after`
    (en `KumiSetting` o una tabla de estado de sync). Colas existentes: `default`, `cron`.
  - *Eventos* (alertas): **webhook entrante** siguiendo el patrón de
    `WebhooksController` — verifica firma **HMAC**, encola un job y responde **200 en < 5 s**.
- **Tiempo real al FE:** **ActionCable** (canal por BU). Nunca polling.
- **Cálculos agregados / dashboards GPS:** **Python + `EjecutarScriptPythonJob`** (regla del
  proyecto para analítica pesada), con broadcast del resultado por `JobStatusChannel`.
- **Mapeo de IDs:** `vehicles.gps_uniq` para el asset de Samsara; choferes vía `employees.imei`.
  A futuro podrían agregarse columnas `samsara_*` (p. ej. `samsara_last_sync_at`) sin romper schema.
- **Secrets y config:** token de Samsara en `credentials.yml.enc` (o ENV, como
  `FCM_SERVER_KEY`/`WHATSAPP_WEBHOOK_SECRET`); toggles y frecuencia de sync por unidad en
  **`KumiSetting`** (key/value por BU).
- **Multi-unidad:** todo lo que se persista pasa por `BusinessUnitAssignable` /
  `business_unit_filter`.

---

## 6. Endpoints prioritarios

| # | Endpoint Samsara | Uso en Kumi | Módulo |
|---|---|---|---|
| 1 | `assets/location-and-speed/stream` | Ubicación + velocidad de todos los activos (mapa) | Tiempo real |
| 2 | `fleet/vehicles/locations` (snapshot/feed/history) | Posición de vehículos (live + backfill) | Flotilla |
| 3 | `fleet/vehicles/stats` (snapshot/feed/history) | Odómetro, combustible, RPM | Combustible / Mtto |
| 4 | `fleet/trips` | Viajes completos (origen/destino/distancia/duración) | Cuadre |
| 5 | `addresses` (GET/POST) | Geocercas (sucursales, plantas, destinos) | Ruteo / Clientes |
| 6 | `alert/incidents` | Eventos de alerta activos | Alertas |
| 7 | `webhooks` (POST) | Recibir eventos en tiempo real (sin polling) | Tiempo real |
| 8 | `fleet/vehicles` | Catálogo de la flota (mapear `gps_uniq`) | Flotilla |
| 9 | `fleet/drivers` | Lista de conductores | Empleados |
| 10 | `fleet/drivers/vehicle-assignments` | Quién maneja qué (cruzar con `VehicleAsignation`) | Asignaciones |
| 11 | `safety/events` | Frenazos/aceleraciones (a futuro) | Seguridad |
| 12 | `fleet/vehicles/engine-immobilization` | Vehículos con fallas / check engine | Mantenimiento |

---

## 7. Roadmap por fases

- **Fase 0 — Cimientos:** dar de alta el token (credentials), modelar el estado de sync,
  **mapear la flota** (poblar `vehicles.gps_uniq` con el asset id de Samsara) y toggles en
  `KumiSetting`.
- **Fase 1 — Mapa en vivo:** job de feed de locations + canal ActionCable + mapa Leaflet en el FE.
- **Fase 2 — Cuadre con GPS:** ingerir `trips`/locations history y agregar las validaciones
  objetivas al cuadre (`Discrepancy`/KPI "verificado por GPS").
- **Fase 3 — Combustible + mantenimiento:** stats (odómetro/combustible) → rendimiento y robo;
  engine faults / DVIR → `Mtto::WorkOrder`/`ScheduledMaintenance`.
- **Fase 4 — Alertas/webhooks:** endpoint webhook con HMAC → `Alert` → `Alerts::DispatcherService`.

---

## 8. Riesgos y consideraciones

- **Costo/licencias:** Samsara es por dispositivo/suscripción; validar alcance comercial antes de
  construir.
- **PII de choferes:** ubicación y telemetría son datos sensibles — respetar BU y permisos.
- **Zona horaria:** mantener consistencia con el wall-clock `America/Chihuahua` del cuadre y las
  asignaciones (no usar `Date.today`/UTC crudo para lógica de negocio).
- **HOS/ELD:** regulación de EE.UU.; baja prioridad en operación mexicana.
- **Rate limit (10 req/s):** preferir feeds/webhooks sobre polling; throttle en los jobs de sync.
- **Mapeo inicial:** el primer reto operativo es emparejar cada unidad de la flota con su asset de
  Samsara (`gps_uniq`); planear una carga/validación inicial.

---

## 9. Referencias

- Samsara API reference: <https://developers.samsara.com/reference/>
- Samsara guías de telemática: <https://developers.samsara.com/docs/telematics>
- Webhooks + ActionCable en Kumi: `Documentacion/Backend/integracion/webhooks.md`
- Dominios Kumi relacionados: `Backend/dominio/vehicles/`, `bookings/`, `combustible/`,
  `proveedores/`, `ruteo/`, `alertas/`, `configuracion/` (KumiSetting).
