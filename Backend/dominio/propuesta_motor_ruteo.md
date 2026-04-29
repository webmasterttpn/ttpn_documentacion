# Propuesta: Motor de Optimización de Ruteo
**Proyecto:** Kumi TTPN Admin V2  
**Fecha:** 2026-04-24  
**Estado:** APROBADO PARA IMPLEMENTAR — decisiones tomadas el 2026-04-24

---

## 0. Decisiones de Diseño Confirmadas

| Pregunta | Decisión |
|----------|----------|
| ¿Propuesta o automático? | **Propuesta con aprobación humana.** El motor genera un borrador; un usuario lo revisa y aprueba antes de aplicar. |
| ¿Google Maps API? | **No se usa.** Se resuelve con Haversine + OSRM público + factores de tráfico locales (ver sección 3.2). |
| ¿`vehicle_asignations`? | **No se usa en esta versión.** El motor solo asigna vehículos disponibles (status: true). La asignación de chofer es manual posterior. |

---

## 1. Diagnóstico del Estado Actual

### 1.1 Modelo de Datos Relevante

```
ttpn_bookings           → viaje programado (vehículo + conductor + fecha + hora)
ttpn_booking_passengers → pasajeros de ese viaje (lat, lng por pasajero)
fixed_routes            → disponibilidad esperada (vqty, aqty por horario y dia)
vehicle_asignations     → qué conductor tiene asignada qué unidad
travel_counts           → viaje contabilizado (registro operativo real)
coo_travel_requests     → solicitudes espontáneas del cliente
crdh_routes / crdhr_points → rutas fijas históricas (legacy, actualmente en desuso)
```

### 1.2 Gaps Identificados

| Necesidad | Estado actual |
|-----------|---------------|
| Agrupación geográfica de pasajeros (clustering) | No existe |
| Cálculo de hora de inicio de ruta desde hora_entrada/salida | No existe |
| Validación de disponibilidad de unidad entre servicios | No existe |
| Encadenamiento de servicios (release time) | No existe |
| VRP / asignación optimizada de flota | No existe |
| Dashboard de calor de ocupación | No existe |
| Reporte asientos ofrecidos vs ocupados | No existe |
| Alerta de rutas > 45 min | No existe |

### 1.3 Lo que SÍ tenemos que aprovechar

- `ttpn_booking_passengers.lat/lng` — coordenadas GPS por pasajero (clave para clustering)
- `vehicle_asignations` — asignación conductor-unidad con rango de fechas
- `fixed_routes.vqty / aqty / dias` — oferta esperada por horario
- `ttpn_bookings.aforo` — capacidad usada por viaje
- `ttpn_bookings.passenger_qty` — actualizado automáticamente vía callbacks
- `vehicles.vehicle_type_id` — clasifica Auto/Van/Camión
- El motor de cuadre (`TtpnCuadreService`) ya es robusto; el motor de ruteo se apoya en él, no lo reemplaza

---

## 2. Arquitectura General

```
                    ┌─────────────────────────────────┐
                    │         MOTOR DE RUTEO           │
                    │   Services::Routing::Engine      │
                    └──────────┬──────────────────────┘
                               │
          ┌────────────────────┼────────────────────────┐
          ▼                    ▼                         ▼
  PassengerClusterer    TimeWindowCalculator    VehicleAvailability
  (K-Means / DBSCAN)   (buffer + tráfico)      (línea de tiempo)
          │                    │                         │
          └────────────────────┼─────────────────────────┘
                               ▼
                    RouteAssignmentSolver
                    (VRP simplificado)
                               │
                 ┌─────────────┴──────────────┐
                 ▼                            ▼
         RouteProposal DB              AlertDispatcher
         (nueva tabla)             (rutas > 45 min, 0% disp.)
```

---

## 3. Propuesta Backend (Ruby / Rails)

### 3.1 Nuevas Tablas Necesarias

#### `route_proposals`
Almacena el resultado del motor: una propuesta de asignación para un día.

```ruby
# migration
create_table :route_proposals do |t|
  t.date        :fecha,           null: false
  t.integer     :business_unit_id, null: false
  t.string      :status,          default: 'draft'  # draft | approved | executing | done
  t.jsonb       :summary,         default: {}        # totales, KPIs
  t.integer     :created_by_id
  t.timestamps
end

create_table :route_proposal_legs do |t|
  t.references  :route_proposal,  null: false
  t.integer     :vehicle_id
  t.integer     :employee_id
  t.time        :hora_inicio_ruta  # calculada por TimeWindowCalculator
  t.time        :hora_liberacion   # release time estimado
  t.integer     :passenger_count
  t.integer     :estimated_minutes
  t.string      :cluster_id        # referencia al cluster de pasajeros
  t.jsonb       :waypoints,        default: []  # [{lat, lng, nombre, orden}]
  t.integer     :ttpn_booking_id   # booking al que corresponde si ya existe
  t.boolean     :needs_split,      default: false  # si supera 13 pax o 40 min
  t.timestamps
end
```

#### `fleet_availability_snapshots`
Línea de tiempo por unidad para el encadenamiento de servicios.

```ruby
create_table :fleet_availability_snapshots do |t|
  t.integer  :vehicle_id,      null: false
  t.date     :fecha,           null: false
  t.time     :busy_from        # inicio de ocupación
  t.time     :busy_until       # release time estimado
  t.integer  :ttpn_booking_id  # booking que genera la ocupación
  t.boolean  :is_available,    default: true
  t.timestamps
end
```

---

### 3.2 Servicios Ruby

#### `Services::Routing::Engine` — Orquestador principal

```ruby
# app/services/routing/engine.rb
module Services
  module Routing
    class Engine
      def initialize(fecha:, business_unit_id:)
        @fecha            = fecha
        @business_unit_id = business_unit_id
      end

      # Punto de entrada principal
      def call
        bookings   = load_bookings
        passengers = load_passengers(bookings)
        clusters   = PassengerClusterer.new(passengers).call
        windows    = TimeWindowCalculator.new(bookings).call
        timeline   = VehicleAvailabilityBuilder.new(fecha: @fecha).call
        proposals  = RouteAssignmentSolver.new(
                       clusters:  clusters,
                       windows:   windows,
                       timeline:  timeline,
                       fleet:     available_fleet
                     ).call
        persist_proposals(proposals)
      end

      private

      def load_bookings
        TtpnBooking
          .where(fecha: @fecha, business_unit_id: @business_unit_id, status: true)
          .includes(:ttpn_booking_passengers, :vehicle, :employee, :ttpn_service_type)
      end

      def load_passengers(bookings)
        TtpnBookingPassenger
          .where(ttpn_booking_id: bookings.select(:id))
          .where.not(lat: nil, lng: nil)
      end

      def available_fleet
        Vehicle
          .where(business_unit_id: @business_unit_id, status: true)
          .includes(:vehicle_type, :vehicle_asignations)
      end
    end
  end
end
```

---

#### `Services::Routing::PassengerClusterer` — Agrupación geográfica

**Algoritmo:** DBSCAN adaptado (mejor que K-Means para clusters de forma irregular).  
**Radio inicial:** 3 km (configurable vía `KumiSetting`).  
**Criterio de división:** Si un cluster supera 13 pasajeros o 40 min de ruta estimada → dividir en 2.

```ruby
# app/services/routing/passenger_clusterer.rb
module Services
  module Routing
    class PassengerClusterer
      EPSILON_KM    = 3.0   # Radio máximo entre puntos del mismo cluster
      MIN_POINTS    = 2     # Mínimo de pasajeros para formar cluster
      MAX_PAX       = 13    # Umbral de división
      MAX_ROUTE_MIN = 40    # Umbral de tiempo (minutos)

      def initialize(passengers)
        @passengers = passengers
      end

      def call
        # 1. Calcular matriz de distancias haversine entre todos los pasajeros
        # 2. Aplicar DBSCAN
        # 3. Evaluar cada cluster: si supera MAX_PAX → subdividir
        # 4. Retornar array de Cluster objects con {passengers, centroid, estimated_minutes}
        clusters = dbscan(@passengers)
        clusters.flat_map { |c| c.overloaded? ? c.split : [c] }
      end

      private

      def haversine(lat1, lng1, lat2, lng2)
        rad = Math::PI / 180
        dlat = (lat2 - lat1) * rad
        dlng = (lng2 - lng1) * rad
        a = Math.sin(dlat/2)**2 +
            Math.cos(lat1*rad) * Math.cos(lat2*rad) * Math.sin(dlng/2)**2
        6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
      end
    end
  end
end
```

---

#### `Services::Routing::DistanceCalculator` — Motor de distancias con fallback

**Estrategia dual: OSRM si está disponible, Haversine si no**

El sistema detecta automáticamente si OSRM está corriendo. Si lo está, usa calles
reales de Chihuahua. Si no, cae a distancia haversine con un factor de corrección
de 1.25 (Chihuahua en cuadrícula, la distancia real por calle es ~25% mayor que
la línea recta). El sistema funciona en ambos casos — solo cambia la precisión.

```ruby
# app/services/routing/distance_calculator.rb
module Services
  module Routing
    class DistanceCalculator
      OSRM_URL             = ENV.fetch('OSRM_URL', 'http://localhost:5000')
      HAVERSINE_CORRECTION = 1.25   # Factor corrección cuadrícula urbana
      AVG_SPEED_KMH        = 30.0   # Velocidad promedio Chihuahua ciudad

      TRAFFIC_FACTORS = {
        (6..7)   => 1.40,
        (8..13)  => 1.00,
        (14..15) => 1.20,
        (16..18) => 1.35,
        (19..23) => 0.90,
        (0..5)   => 0.90
      }.freeze

      # Retorna duración en minutos entre dos puntos, con factor de tráfico aplicado
      def self.duration_minutes(lat1, lng1, lat2, lng2, hora: nil)
        base_min = osrm_available? ? osrm_duration(lat1, lng1, lat2, lng2)
                                   : haversine_duration(lat1, lng1, lat2, lng2)
        (base_min * traffic_factor(hora)).ceil
      end

      # Ruta optimizada para N puntos. Retorna { duration_minutes:, distance_km:, waypoint_order: }
      def self.optimized_trip(coords, hora: nil)
        if osrm_available?
          osrm_trip(coords, hora: hora)
        else
          haversine_trip(coords, hora: hora)
        end
      end

      def self.engine_name
        osrm_available? ? 'OSRM (calles reales)' : 'Haversine (estimado)'
      end

      # --- OSRM ---

      def self.osrm_available?
        @osrm_available ||= begin
          Net::HTTP.get_response(URI("#{OSRM_URL}/health"))
          true
        rescue
          false
        end
      end

      def self.osrm_duration(lat1, lng1, lat2, lng2)
        url  = "#{OSRM_URL}/route/v1/driving/#{lng1},#{lat1};#{lng2},#{lat2}"
        data = JSON.parse(Net::HTTP.get(URI(url)))
        return haversine_duration(lat1, lng1, lat2, lng2) unless data['code'] == 'Ok'
        data.dig('routes', 0, 'duration') / 60.0
      end

      def self.osrm_trip(coords, hora: nil)
        coord_str = coords.map { |lat, lng| "#{lng},#{lat}" }.join(';')
        url  = "#{OSRM_URL}/trip/v1/driving/#{coord_str}?roundtrip=false&source=first&destination=last&overview=false"
        data = JSON.parse(Net::HTTP.get(URI(url)))
        return haversine_trip(coords, hora: hora) unless data['code'] == 'Ok'
        factor = traffic_factor(hora)
        {
          duration_minutes: ((data.dig('trips', 0, 'duration') / 60.0) * factor).ceil,
          distance_km:      (data.dig('trips', 0, 'distance') / 1000.0).round(1),
          waypoint_order:   data['waypoints'].sort_by { |w| w['trips_index'] }.map { |w| w['waypoint_index'] },
          engine:           'osrm'
        }
      end

      # --- Haversine fallback ---

      def self.haversine_km(lat1, lng1, lat2, lng2)
        rad = Math::PI / 180
        dlat = (lat2 - lat1) * rad
        dlng = (lng2 - lng1) * rad
        a = Math.sin(dlat/2)**2 +
            Math.cos(lat1*rad) * Math.cos(lat2*rad) * Math.sin(dlng/2)**2
        6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)) * HAVERSINE_CORRECTION
      end

      def self.haversine_duration(lat1, lng1, lat2, lng2)
        (haversine_km(lat1, lng1, lat2, lng2) / AVG_SPEED_KMH * 60)
      end

      # Nearest-neighbor sobre haversine para ordenar waypoints
      def self.haversine_trip(coords, hora: nil)
        return { duration_minutes: 0, distance_km: 0, waypoint_order: [], engine: 'haversine' } if coords.size < 2

        order  = [0]
        remaining = (1...coords.size).to_a
        total_km  = 0

        until remaining.empty?
          current = order.last
          nearest = remaining.min_by { |i| haversine_km(*coords[current], *coords[i]) }
          total_km += haversine_km(*coords[current], *coords[nearest])
          order << nearest
          remaining.delete(nearest)
        end

        factor = traffic_factor(hora)
        {
          duration_minutes: ((total_km / AVG_SPEED_KMH * 60) * factor).ceil,
          distance_km:      total_km.round(1),
          waypoint_order:   order,
          engine:           'haversine'
        }
      end

      def self.traffic_factor(hora)
        return 1.0 unless hora
        h = hora.is_a?(Integer) ? hora : hora.to_s.split(':').first.to_i
        TRAFFIC_FACTORS.find { |range, _| range.include?(h) }&.last || 1.0
      end
    end
  end
end
```

#### `Services::Routing::TimeWindowCalculator` — Estimación de ventanas de tiempo

```
Entrada (tipo servicio = ENTRADA):
  resultado        = DistanceCalculator.optimized_trip(waypoints_cluster, hora:)
  tiempo_ruta_min  = resultado[:duration_minutes]   ← OSRM o Haversine según disponibilidad
  hora_inicio_ruta = hora_entrada
                   - (2 min × num_pasajeros)         ← buffer de abordaje
                   - tiempo_ruta_min
                   - 10 min                          ← margen de seguridad

  hora_liberacion  = hora_entrada + 15 min

Salida (tipo servicio = SALIDA):
  hora_inicio_ruta = hora_salida
  hora_liberacion  = hora_salida + tiempo_ruta_min + 15 min
```

El motor registra en cada propuesta qué engine calculó el tiempo (`osrm` o `haversine`)
para que el operador sepa la precisión de la estimación.

```ruby
# app/services/routing/time_window_calculator.rb
module Services
  module Routing
    class TimeWindowCalculator
      BOARDING_BUFFER_MIN = 2  # minutos por pasajero

      TRAFFIC_FACTORS = {
        (6..8)   => 1.4,
        (8..14)  => 1.0,
        (14..16) => 1.2,
        (16..19) => 1.35,
        (19..24) => 0.9,
        (0..6)   => 0.9
      }.freeze

      def initialize(bookings)
        @bookings = bookings
      end

      def call
        @bookings.map do |booking|
          pax_count        = booking.passenger_qty.to_i
          avg_transit_min  = estimate_transit(booking)
          traffic_factor   = factor_for(booking.hora)

          start_time    = calculate_start(booking, pax_count, avg_transit_min, traffic_factor)
          release_time  = calculate_release(booking, avg_transit_min, traffic_factor)

          {
            booking_id:   booking.id,
            hora_inicio:  start_time,
            hora_liberacion: release_time,
            estimated_minutes: (avg_transit_min * traffic_factor).ceil
          }
        end
      end

      private

      def factor_for(hora)
        h = hora.is_a?(Time) ? hora.hour : hora.to_s.split(':').first.to_i
        TRAFFIC_FACTORS.find { |range, _| range.include?(h) }&.last || 1.0
      end

      def estimate_transit(booking)
        # Promedio simple por distancia desde centroide del cluster al destino
        # En primera versión: valor fijo configurable (20 min default)
        # En v2: usar Google Distance Matrix API o OSRM (self-hosted)
        KumiSetting.find_by(key: 'routing_default_transit_min')&.value&.to_i || 20
      end
    end
  end
end
```

---

#### `Services::Routing::VehicleAvailabilityBuilder` — Línea de tiempo de flota

```ruby
# app/services/routing/vehicle_availability_builder.rb
module Services
  module Routing
    class VehicleAvailabilityBuilder
      SAFETY_MARGIN_MIN = 10  # Margen de seguridad entre servicios

      def initialize(fecha:)
        @fecha = fecha
      end

      # Retorna hash { vehicle_id => [{ from:, until:, booking_id: }, ...] }
      def call
        TtpnBooking
          .where(fecha: @fecha, status: true)
          .includes(:vehicle)
          .group_by(&:vehicle_id)
          .transform_values { |bookings| build_timeline(bookings) }
      end

      def available_at?(vehicle_id, start_time, timeline)
        slots = timeline[vehicle_id] || []
        slots.none? do |slot|
          # El slot nuevo empieza antes de que termine el anterior + margen
          start_time < slot[:until] + SAFETY_MARGIN_MIN.minutes
        end
      end

      private

      def build_timeline(bookings)
        bookings.sort_by(&:hora).map do |b|
          calc = TimeWindowCalculator.new([b]).call.first
          {
            booking_id: b.id,
            from:       calc[:hora_inicio],
            until:      calc[:hora_liberacion]
          }
        end
      end
    end
  end
end
```

---

#### `Services::Routing::RouteAssignmentSolver` — Asignación VRP simplificado

**Algoritmo:** Nearest Neighbor Heuristic (NNH) — O(n²), suficiente para el volumen actual.  
**Optimización futura:** OR-Tools (Google) si el volumen escala > 200 puntos/día.

**Reglas de asignación:**
1. Ordenar clusters por hora de inicio de ruta (más temprano primero).
2. Para cada cluster, encontrar la unidad disponible más cercana al centroide.
3. Si ninguna unidad propia está disponible → marcar como `needs_subcontract: true`.
4. Si el cluster supera 13 pax → asignar unidad tipo Van/Bus; si < 13 → Auto/Van.
5. Al asignar, actualizar la línea de tiempo de la unidad.

```ruby
# app/services/routing/route_assignment_solver.rb
module Services
  module Routing
    class RouteAssignmentSolver
      def initialize(clusters:, windows:, timeline:, fleet:)
        @clusters = clusters
        @windows  = windows.index_by { |w| w[:booking_id] }
        @timeline = timeline
        @fleet    = fleet
        @assigned = Hash.new { |h, k| h[k] = [] }  # vehicle_id => slots
      end

      def call
        sorted_clusters = @clusters.sort_by { |c| c[:earliest_window] }

        sorted_clusters.map do |cluster|
          window   = @windows[cluster[:booking_id]]
          vehicle  = best_vehicle_for(cluster, window)
          employee = assigned_driver(vehicle)

          if vehicle
            register_slot(vehicle.id, window)
            build_leg(cluster, vehicle, employee, window, needs_split: cluster[:overloaded])
          else
            build_leg(cluster, nil, nil, window, needs_subcontract: true)
          end
        end
      end

      private

      def best_vehicle_for(cluster, window)
        candidates = @fleet.select do |v|
          correct_capacity?(v, cluster[:passenger_count]) &&
            available?(v, window[:hora_inicio])
        end

        # El candidato más cercano al centroide del cluster
        candidates.min_by { |v| last_position_distance(v, cluster[:centroid]) }
      end

      def correct_capacity?(vehicle, pax_count)
        if pax_count > 13
          vehicle.vehicle_type.nombre.downcase.include?('van') ||
            vehicle.vehicle_type.nombre.downcase.include?('bus')
        else
          true  # cualquier tipo sirve para < 13 pax
        end
      end

      def available?(vehicle, start_time)
        VehicleAvailabilityBuilder::SAFETY_MARGIN_MIN.tap do |margin|
          slots = @assigned[vehicle.id]
          slots.none? { |s| start_time < (s[:until] + margin.minutes) }
        end
      end
    end
  end
end
```

---

### 3.3 Job para ejecución asíncrona

```ruby
# app/jobs/routing/optimization_job.rb
module Routing
  class OptimizationJob < ApplicationJob
    queue_as :routing

    def perform(fecha, business_unit_id)
      Services::Routing::Engine.new(
        fecha:            Date.parse(fecha),
        business_unit_id: business_unit_id
      ).call
    rescue => e
      Rails.logger.error "[RoutingEngine] Error para #{fecha}: #{e.message}"
      raise  # re-raise para Sidekiq retry
    end
  end
end
```

---

### 3.4 Módulo de Inteligencia de Negocios

#### Reporte: Capacidad Ofrecida vs Ocupada

```ruby
# app/services/routing/capacity_report.rb
#
# Compara fixed_routes (oferta) vs ttpn_booking_passengers (demanda real)
# Granularidad: semana / franja horaria / tipo de vehículo
#
# Salida ejemplo:
# {
#   week: "2026-W17",
#   slots: [
#     { hora: "06:30", offered_seats: 40, occupied_seats: 28, occupancy_rate: 70.0 },
#     { hora: "07:00", offered_seats: 56, occupied_seats: 12, occupancy_rate: 21.4 },
#   ]
# }
```

#### Reporte: Estrés de Flota (franjas con 0% disponibilidad)

```ruby
# app/services/routing/fleet_stress_report.rb
#
# Para cada franja de 30 min del día, cuenta cuántas unidades están ocupadas.
# Si todas las unidades están ocupadas → franja en "estrés".
# Resultado: array de franjas con % ocupación para justificar compra de activos.
```

#### Reporte: ROI de Subcontratación

```ruby
# app/services/routing/subcontract_roi_report.rb
#
# Cuenta viajes marcados needs_subcontract por mes.
# Calcula costo estimado (viajes × tarifa promedio externa).
# Compara vs costo mensual de una unidad nueva (configurable en KumiSetting).
# Output: "En este mes el costo de subcontratación fue $X.
#          Una unidad nueva cuesta $Y/mes. ROI: Z meses."
```

---

### 3.5 API Endpoints Nuevos

```ruby
# config/routes.rb (dentro del namespace api/v1)
namespace :routing do
  post   :optimize,          to: 'engine#optimize'     # lanza OptimizationJob
  get    :proposals,         to: 'proposals#index'     # lista propuestas por fecha
  get    'proposals/:id',    to: 'proposals#show'
  patch  'proposals/:id/approve', to: 'proposals#approve'

  get    :fleet_timeline,    to: 'analytics#fleet_timeline'   # línea de tiempo por día
  get    :capacity_report,   to: 'analytics#capacity_report'  # ofrecido vs ocupado
  get    :fleet_stress,      to: 'analytics#fleet_stress'     # franjas críticas
  get    :subcontract_roi,   to: 'analytics#subcontract_roi'
end
```

---

## 4. Propuesta Frontend (Quasar PWA)

### 4.1 Página Principal: `RoutingOptimizerPage.vue`

**Ruta:** `/ruteo/optimizador`

**Layout:** 3 columnas

```
┌─────────────────┬────────────────────────────┬───────────────────────┐
│  PANEL IZQUIERDO│        MAPA CENTRAL         │   PANEL DERECHO       │
│                 │                             │                       │
│  Fecha selector │  Google Maps / Leaflet      │  Propuestas generadas │
│  Botón Optimizar│                             │  por cluster          │
│                 │  Clusters coloreados        │                       │
│  Flota disponible│  con íconos de vehículo    │  Cada card:           │
│  (chips por     │  asignado                   │  - Vehículo asignado  │
│  tipo de unidad)│                             │  - # Pasajeros        │
│                 │  Waypoints ordenados        │  - Hora inicio        │
│  KPIs rápidos:  │  con líneas de ruta         │  - Hora liberación    │
│  - Rutas        │                             │  - Est. minutos       │
│  - Subcontratos │                             │  - [Aprobar] [Editar] │
│  - % Ocupación  │                             │                       │
└─────────────────┴────────────────────────────┴───────────────────────┘
```

**Componentes:**
- `RoutingControlPanel.vue` — fecha, botón optimizar, resumen de flota
- `RouteMap.vue` — mapa con clusters, waypoints y unidades asignadas
- `RouteProposalList.vue` — lista de legs generados
- `RouteProposalCard.vue` — card individual por leg/cluster

---

### 4.2 Dashboard BI: `FleetOccupancyDashboard.vue`

**Ruta:** `/ruteo/dashboard`

**Componentes visuales:**

#### Heatmap de Ocupación (`OccupancyHeatmap.vue`)
- Eje X: días de la semana (Lun–Dom)
- Eje Y: franjas horarias (05:00 – 22:00, cada 30 min)
- Color: gradiente verde (0%) → amarillo (50%) → rojo (100%)
- Librería: Apache ECharts (ya en el proyecto vía quasar-app-extension)

```
            Lun   Mar   Mié   Jue   Vie   Sáb
05:00–05:30  ░░   ░░   ░░   ░░   ░░   ░░
06:00–06:30  ██   ██   ██   ██   ██   ▒▒   ← Ruta Entrada pico
07:00–07:30  ██   ██   ██   ██   ██   ░░
...
14:00–14:30  ▒▒   ▒▒   ░░   ▒▒   ▒▒   ░░
16:00–16:30  ██   ██   ██   ██   ██   ░░   ← Salida pico
```

#### Capacidad Ofrecida vs Ocupada (`CapacityBarChart.vue`)
- Barras apiladas por horario
- Capa 1 (azul): asientos ofrecidos (`fixed_routes.vqty × capacidad_van`)
- Capa 2 (verde): asientos ocupados (`SUM(ttpn_booking_passengers)`)
- Métrica en tooltip: `% de ocupación`

#### Estrés de Flota (`FleetStressTimeline.vue`)
- Timeline horizontal por unidad
- Bloques por ocupación (color según servicio)
- Franjas rojas: 0% disponibilidad → candidatas a alerta de compra

#### ROI de Subcontratación (`SubcontractROICard.vue`)
- Tarjeta con semáforo:
  - 🟢 Costo subcontratación < 60% de mensualidad nueva unidad
  - 🟡 Entre 60–90%
  - 🔴 > 90% → recomendación de compra automática

---

### 4.3 Alertas

#### Alertas en tiempo real (via WebSocket / Action Cable)
```
[!] Ruta A113-06:30 estimada en 52 minutos (supera umbral de 45 min)
    → Sugerencia: dividir en 2 unidades o ajustar waypoints
```

#### Alertas de disponibilidad
```
[!] Franja 16:00–17:30 — 100% de flota ocupada (0 unidades libres)
    → Martes y Jueves de esta semana
```

---

### 4.4 Composables Necesarios

```
useRoutingOptimizer.js   → llama POST /api/v1/routing/optimize
                         → polling o WebSocket para resultado
useRouteProposals.js     → GET /api/v1/routing/proposals
useFleetTimeline.js      → GET /api/v1/routing/fleet_timeline
useCapacityReport.js     → GET /api/v1/routing/capacity_report
useFleetStress.js        → GET /api/v1/routing/fleet_stress
useSubcontractROI.js     → GET /api/v1/routing/subcontract_roi
```

---

## 5. Migraciones Nuevas Requeridas

```ruby
# 1. route_proposals
# 2. route_proposal_legs
# 3. fleet_availability_snapshots
# 4. kumi_settings nuevas entradas:
#    routing_default_transit_min (default: 20)
#    routing_boarding_buffer_min (default: 2)
#    routing_safety_margin_min   (default: 10)
#    routing_max_pax_per_vehicle (default: 13)
#    routing_max_route_minutes   (default: 40)
#    routing_alert_threshold_min (default: 45)
#    routing_subcontract_monthly_cost (default: 0)
```

---

## 6. Plan de Implementación por Fases

### Fase 1 — Fundamentos (2 semanas)
- [ ] Migraciones: `route_proposals`, `route_proposal_legs`
- [ ] `TimeWindowCalculator` (cálculo de hora_inicio y hora_liberacion)
- [ ] `VehicleAvailabilityBuilder` (línea de tiempo básica)
- [ ] Endpoint `POST /api/v1/routing/optimize` (síncrono, sin clustering)
- [ ] `RoutingControlPanel.vue` + `FleetStressTimeline.vue` básico

### Fase 2 — Clustering y VRP (2 semanas)
- [ ] `PassengerClusterer` con DBSCAN
- [ ] `RouteAssignmentSolver` con NNH
- [ ] `RouteMap.vue` con clusters coloreados en Google Maps
- [ ] `RouteProposalCard.vue` con aprobación manual

### Fase 3 — BI y Alertas (1 semana)
- [ ] `CapacityReport` + `FleetStressReport`
- [ ] `OccupancyHeatmap.vue`
- [ ] `CapacityBarChart.vue`
- [ ] Sistema de alertas (rutas > 45 min)
- [ ] `SubcontractROI` + tarjeta semáforo

### Fase 4 — Refinamiento (1 semana)
- [ ] `fleet_availability_snapshots` para persistencia histórica
- [ ] Migración de `OptimizationJob` a Sidekiq async
- [ ] WebSocket para resultado del optimizador en tiempo real
- [ ] Encadenamiento de servicios Tiempo Extra

---

## 7. Dependencias y Riesgos

| Item | Tipo | Riesgo | Mitigación |
|------|------|--------|------------|
| Coordenadas lat/lng en `ttpn_booking_passengers` | Requerido | Alto — si hay pasajeros sin coordenadas, el clustering falla | Filtrar solo pasajeros con lat/lng; el resto se agregan manualmente |
| Cálculo de tiempos de tránsito | Requerido | Medio — sin API de mapas, los tiempos son estimados | Usar valor fijo configurable en Fase 1; integrar OSRM/Google en Fase 3 |
| Volumen de datos | Performance | Bajo — actualmente < 500 bookings/día | DBSCAN es O(n²); escala bien hasta ~2000 puntos |
| Integración con `TtpnCuadreService` | Acoplamiento | Bajo — el motor de ruteo no modifica el cuadre, solo propone | Separar propuesta (draft) de ejecución (approved) |
| Datos de prueba en tablas | Calidad | Medio — el usuario menciona que hay datos de test | Añadir scope `where(status: true)` y filtro por business_unit |

---

## 8. Preguntas Abiertas (requieren decisión antes de codificar)

1. **¿El resultado del motor es una propuesta (requiere aprobación humana) o se aplica automáticamente?**
   > Recomendación: propuesta con botón "Aprobar" — minimiza errores en producción.

2. **¿Se integra Google Distance Matrix API o se trabaja con distancia haversine + tiempo fijo?**
   > Para Fase 1: haversine + tiempo configurable. Para Fase 2+: OSRM self-hosted (gratuito).

3. **¿Los datos de "rutas fijas" existentes en `crdh_routes/crdhr_points` se migran al nuevo motor o se descontinúan?**
   > Parece que están en desuso. Recomendación: leer y usar como waypoints semilla opcionales.

4. **¿El dashboard de BI debe ser por cliente específico o global (todos los clientes de la BU)?**
   > Recomendación: filtro por cliente con opción "todos".

5. **¿El algoritmo debe respetar `vehicle_asignations` (conductor fijo por unidad) o puede proponer reasignaciones?**
   > Recomendación: respetar asignaciones vigentes en Fase 1; reasignación opcional en Fase 3.
