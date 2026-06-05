# Services::PayrollSvc::DriverTripCostCalculator

## Qué hace

Wrapper Ruby delgado que calcula el **pago del chofer por un viaje** invocando la función
PostgreSQL `costo_viaje_chofer`. Toda la aritmética y los lookups corren **en la BD** (no en Ruby);
el service solo ejecuta el `SELECT` y devuelve el resultado.

Archivo: `app/services/payroll_svc/driver_trip_cost_calculator.rb`

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `travel_count_id` | Integer | Id del `TravelCount` a calcular |
| `incluir_nivel:` | Boolean (default `false`) | Si suma el nivel del chofer (pesos, solo viajes locales) |

## Resultado

- `Float` con el costo (redondeado a 2 decimales).
- `nil` si no hay precio base vigente para el tipo de vehículo del viaje.

## Cuándo usarlo

Al **sacar un viaje de VCPA** (`Api::V1::TravelCountsController#remove_vcpa`). El motivo determina si
se incluye el nivel:

```ruby
# Flojera (genera incidencia) → sin nivel:
PayrollSvc::DriverTripCostCalculator.call(tc.id, incluir_nivel: false)
# Apoyo legítimo (ej. celular) → con nivel si es local:
PayrollSvc::DriverTripCostCalculator.call(tc.id, incluir_nivel: true)
```

## Dependencias

- Función PG `costo_viaje_chofer` y sus 3 funciones de apoyo (ver
  `bookings/funciones_postgres/costo_viaje_chofer.md`).
- En tests, las funciones se crean en la BD de test vía `spec/support/postgres_functions.rb`.

## Fórmula

`base × (1 + inc_servicio/100) × (1 + inc_cliente/100) + nivel_pesos` (validada contra viajes ya
pagados, 2026-06-05). Detalle en el doc de la función PG.
