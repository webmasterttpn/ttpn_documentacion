# Introducción de capa de servicios — FuelPerformance (2026-03-19)

## Contexto y motivación

Durante una revisión de mantenibilidad del código se identificó que `FuelPerformanceController`
concentraba toda la lógica de negocio del módulo de rendimiento de combustible:
cálculos de métricas, combinación de fuentes de datos, agrupaciones temporales y
clasificación de vehículos. Esto violaba el principio de responsabilidad única (SRP)
y hacía el controller imposible de testear de forma aislada.

Problemas concretos que motivaron el cambio:

| Problema | Descripción | Severidad |
|---|---|---|
| Fat controller | 585 líneas, 15 métodos privados con lógica de negocio | Alta |
| N+1 en best/worst performers | `calculate_vehicle_performance` se llamaba en un loop `Vehicle.limit(100).each` — hasta 200 queries por request | Alta |
| Código duplicado | `combine_and_sort_charges` y `combine_charges_simple` hacían lo mismo con estructuras ligeramente distintas | Media |
| Métodos muertos | `all_vehicles_performance` y `vehicle_performance` definidos pero sin ruta ni llamador | Media |
| No reutilizable | La lógica de cálculo no podía ser llamada desde jobs, rake tasks ni otros controllers | Alta |

---

## Decisión de arquitectura

Se introdujo una **capa de servicios** en `app/services/` siguiendo el patrón
**Service Object** (PORO con método `.call`), estándar en proyectos Rails modernos.

### ¿Por qué Service Objects y no otras alternativas?

- **Concerns**: sirven para compartir comportamiento entre modelos/controllers, no para
  encapsular lógica de negocio compleja. No aplica aquí.
- **Model methods**: los cálculos cruzan dos modelos (`GasCharge` y `GasolineCharge`)
  sin un modelo "dueño" claro. Meterlo en uno de los dos sería arbitrario.
- **Presenters/Serializers**: el problema es lógica de cálculo, no de presentación.
- **Service Objects**: encapsulan una operación con entradas y salida definidas,
  son fáciles de testear y no requieren dependencias adicionales (no hay gem nueva).

### Convención adoptada

```ruby
# Inicialización con kwargs nombrados
# Ejecución con .call (instancia o clase)
result = FuelPerformance::VehicleCalculator.call(
  vehicle_id:   5,
  fecha_inicio: '2026-01-01',
  fecha_fin:    '2026-03-01'
)
```

Todos los servicios siguen este contrato:

```ruby
def self.call(**args)
  new(**args).call
end
```

Esto permite llamarlos tanto como clase (`MyService.call(...)`) como instancia
(`MyService.new(...).call`) según el contexto.

---

## Archivos creados

### `app/services/fuel_performance/vehicle_calculator.rb`

**Responsabilidad:** Calcular las métricas de rendimiento de combustible para un
vehículo individual o para todos los vehículos con cargas en el período.

**Métodos públicos:**

| Método | Descripción |
|---|---|
| `.call(vehicle_id:, fecha_inicio:, fecha_fin:)` | Si se pasa `vehicle_id` → hash de métricas del vehículo. Si no → array ordenado por rendimiento |

**Optimización anti-N+1 (modo todos los vehículos):**

El controller original tenía:

```ruby
# ANTES — N+1: 1 query por vehículo × 100 vehículos = ~200 queries
def best_performers(fecha_inicio, fecha_fin)
  vehicles = Vehicle.limit(100)
  vehicles.each do |vehicle|
    perf = calculate_vehicle_performance(vehicle.id, fecha_inicio, fecha_fin)
    # ^ GasCharge.where + GasolineCharge.where por cada vehículo
  end
end
```

Ahora:

```ruby
# DESPUÉS — 2 queries totales independientemente del número de vehículos
gas_by_vehicle  = GasCharge.where(fecha: ...).group_by(&:vehicle_id)   # 1 query
gasoline_by_clv = GasolineCharge.where(fecha: ...).group_by(&:neconomico) # 1 query
# Luego se itera en memoria
```

**Métricas calculadas:**

- `total_km`: diferencia entre odómetro máximo y mínimo del período
- `total_litros`, `total_costo`: suma de todas las cargas (gas + gasolina)
- `rendimiento_promedio`: km / litros
- `costo_por_km`: costo / km
- `gas_charges`, `gasoline_charges`: conteos separados por fuente

---

### `app/services/fuel_performance/timeline_builder.rb`

**Responsabilidad:** Construir timelines de consumo agrupadas por semana o mes,
y calcular la distribución porcentual entre gas y gasolina para un vehículo.

**Métodos públicos:**

| Método | Descripción |
|---|---|
| `.call(fecha_inicio:, fecha_fin:, vehicle_id: nil)` | Devuelve `{ timeline: [...], grouping: 'weekly'|'monthly' }`. Agrupa por semana si el rango ≤ 4 meses, por mes si es mayor |
| `#monthly_by_vehicle` | Timeline mensual para el detalle de un vehículo específico |
| `#fuel_distribution` | Distribución gas vs gasolina en litros y porcentaje |

**Lógica de agrupación:**

```ruby
months_diff = ((fecha_fin - fecha_inicio) / 30).to_i
grouping    = months_diff > 4 ? 'monthly' : 'weekly'
```

Los buckets (semanas o meses) se construyen primero vacíos y luego se llenan
iterando las cargas — evita huecos en el timeline cuando no hay cargas en un período.

---

### `app/services/fuel_performance/performers_ranker.rb`

**Responsabilidad:** Devolver los 10 mejores y 10 peores vehículos por rendimiento.

**Método público:**

| Método | Descripción |
|---|---|
| `.call(fecha_inicio:, fecha_fin:)` | Devuelve `{ best: [...10 vehículos...], worst: [...10 vehículos...] }` |

**Eliminación del N+1:**

`PerformersRanker` delega en `VehicleCalculator.call` sin `vehicle_id`,
que ya hace el pre-load optimizado. El resultado se ordena en memoria dos veces
(asc y desc) para obtener best y worst sin queries adicionales.

```ruby
def call
  all_performances = VehicleCalculator.call(fecha_inicio: @fecha_inicio, fecha_fin: @fecha_fin)
  with_data = all_performances.select { |p| p[:rendimiento_promedio] > 0 }
  {
    best:  with_data.sort_by { |p| -p[:rendimiento_promedio] }.first(10),
    worst: with_data.sort_by { |p|  p[:rendimiento_promedio] }.first(10)
  }
end
```

---

## Archivos modificados

### `app/controllers/api/v1/fuel_performance_controller.rb`

El controller pasó de **585 líneas** a **~100 líneas**.

**Antes:** 5 actions públicas + 15 métodos privados con lógica de cálculo.

**Después:** 5 actions públicas + 3 helpers privados simples:

```ruby
private

def fecha_inicio = params[:fecha_inicio] || 30.days.ago.to_date
def fecha_fin    = params[:fecha_fin]    || Date.today
def cache_key    = "fuel_performance:#{current_user.id}:#{params[:vehicle_id] || 'all'}:#{fecha_inicio}:#{fecha_fin}"
```

Cada action ahora solo:
1. Extrae parámetros
2. Llama al servicio correspondiente
3. Renderiza el resultado

**Métodos eliminados del controller** (movidos a servicios):

| Método eliminado | Destino |
|---|---|
| `calculate_vehicle_performance` | `VehicleCalculator#single_vehicle_performance` |
| `calculate_all_vehicles_performance` | `VehicleCalculator#all_vehicles_performance` |
| `combine_and_sort_charges` | `VehicleCalculator#combine_and_sort` |
| `combine_charges_simple` | `VehicleCalculator#combine_charges_simple` |
| `calculate_total_km` | `VehicleCalculator#total_km_from` |
| `calculate_total_km_simple` | `VehicleCalculator#total_km_simple` |
| `default_performance` | `VehicleCalculator#default_performance` |
| `calculate_timeline` | `TimelineBuilder#monthly_by_vehicle` |
| `timeline_by_week` | `TimelineBuilder#by_week` |
| `timeline_by_month` | `TimelineBuilder#by_month` |
| `calculate_fuel_distribution` | `TimelineBuilder#fuel_distribution` |
| `best_performers` | `PerformersRanker#call` |
| `worst_performers` | `PerformersRanker#call` |
| `all_vehicles_performance` *(muerto)* | Eliminado — no tenía ruta ni llamador |
| `vehicle_performance` *(muerto)* | Eliminado — no tenía ruta ni llamador |

---

## Impacto en el sistema

| Aspecto | Antes | Después |
|---|---|---|
| Líneas en controller | 585 | ~100 |
| Métodos privados en controller | 15 | 3 |
| Queries en `best/worst_performers` | ~200 (N+1) | 2 |
| Testabilidad | Solo vía request specs | Unit specs directamente sobre los servicios |
| Reutilización | Solo desde ese controller | Cualquier job, rake task u otro controller |
| Métodos muertos | 2 | 0 |

---

## Cómo usar los servicios desde otros contextos

```ruby
# Desde un rake task o job:
result = FuelPerformance::VehicleCalculator.call(
  vehicle_id:   vehicle.id,
  fecha_inicio: Date.today - 30,
  fecha_fin:    Date.today
)
puts result[:rendimiento_promedio]

# Timeline general (sin vehículo específico):
timeline = FuelPerformance::TimelineBuilder.call(
  fecha_inicio: '2026-01-01',
  fecha_fin:    '2026-03-01'
)
# => { timeline: [...], grouping: 'monthly' }

# Ranking:
ranking = FuelPerformance::PerformersRanker.call(
  fecha_inicio: '2026-01-01',
  fecha_fin:    '2026-03-01'
)
# => { best: [...10...], worst: [...10...] }
```

---

## Lo que NO se cambió (intencionalmente)

| Elemento | Razón |
|---|---|
| Lógica de caché en el controller | Es responsabilidad de orquestación HTTP, no de negocio |
| Contratos de respuesta JSON | Compatibilidad con el frontend sin cambios |
| Gem `axlsx` ni generación de Excel | No aplica a este módulo |
| Rutas | No se modificó `routes.rb` |

---

## Próximos pasos (pendientes)

Este es el primer controller refactorizado. El plan completo incluye:

1. ~~`FuelPerformanceController`~~ ✓ (este documento)
2. `TtpnBookingsController` → `Queries::TtpnBookingFilter` + `Payroll::WeekCalculator`
3. `PayrollReportsController` → `Payroll::ReportQuery` + `Payroll::ReportExporter` (+ fix SQL injection)
4. `GasolineChargesController` → `Gasoline::EmployeeAssignmentService` + `Gasoline::StatsBuilder`
5. `Auth::SessionsController` → método `User#build_privileges`
