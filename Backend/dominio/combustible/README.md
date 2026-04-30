# Dominio: Combustible

Gestión de cargas de combustible: registro manual por unidad, importación de archivos de gasolinera, y estadísticos de rendimiento (km/litro, costo/km, rankings por conductor).

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `GasCharge` | `gas_charges` | Carga de gas LP registrada para un vehículo |
| `GasolineCharge` | `gasoline_charges` | Carga de gasolina (vehículos de apoyo) |
| `GasFile` | `gas_files` | Archivo importado desde la gasolinera (CSV/Excel) |
| `GasStation` | `gas_stations` | Estación de servicio (compartida con dominio Proveedores) |
| `FuelPerformanceCache` | `fuel_performance_caches` | Cache de estadísticos de rendimiento precalculados |

---

## Services de análisis

| Service | Responsabilidad |
| --- | --- |
| `FuelPerformance::VehicleCalculator` | Calcula km/litro y costo/km para un vehículo en un período |
| `FuelPerformance::TimelineBuilder` | Construye la línea de tiempo de cargas para un vehículo |
| `FuelPerformance::PerformersRanker` | Rankea conductores por rendimiento (mejores y peores) en la BU |

Los servicios escriben en `FuelPerformanceCache` para evitar recalcular en cada request. El cache se invalida al registrar una nueva carga.

---

## Flujo de importación de archivo gasolinera

```text
Usuario sube archivo Excel/CSV
          │
          ▼
GasChargesController#import
          │
          ▼
QueueImport service parsea el archivo
          │
          └── Crea GasCharge por cada fila válida
          └── Registra errores de fila en GasFile#import_errors
```

---

## Controllers

```text
app/controllers/api/v1/gas_charges_controller.rb
app/controllers/api/v1/gasoline_charges_controller.rb
app/controllers/api/v1/gas_stations_controller.rb
app/controllers/api/v1/fuel_performance_controller.rb
```

---

## Archivos Rails completos

```text
app/models/gas_charge.rb
app/models/gasoline_charge.rb
app/models/gas_file.rb
app/models/gas_station.rb
app/models/fuel_performance_cache.rb
app/services/fuel_performance/vehicle_calculator.rb
app/services/fuel_performance/timeline_builder.rb
app/services/fuel_performance/performers_ranker.rb
app/controllers/api/v1/gas_charges_controller.rb
app/controllers/api/v1/fuel_performance_controller.rb
```
