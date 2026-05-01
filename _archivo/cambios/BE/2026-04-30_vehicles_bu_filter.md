# 2026-04-30 — Fix: Vehicle business_unit_filter

## Qué cambió

Reescritura del scope `business_unit_filter` en `Vehicle` para corregir que sadmin veía todos los vehículos al operar en una BU específica.

## Archivos

- `app/models/vehicle.rb`
- `app/controllers/api/v1/vehicles_controller.rb`
- `db/migrate/20260430000001_populate_vehicle_business_unit_id.rb`

## Lógica nueva del scope

```ruby
# Sadmin sin BU activa → ve todo
return all if Current.user&.sadmin? && Current.business_unit.nil?

# Regla A: vehículo administrado directamente por esta BU
where(business_unit_id: bu.id)
# Regla B: concesionario del vehículo vinculado a esta BU (préstamo)
.or(where(id: lent_ids))
.distinct
```

## Validación agregada

`at_least_one_concessionaire` — impide crear vehículos sin concesionario.

## Auto-fill en create

Si `concessionaire_ids` llega vacío, el controller busca `Concessionaire.find_by(nombre: Current.business_unit.clv)` como fallback.

## Migración de datos

`PopulateVehicleBusinessUnitId` — asigna `business_unit_id` a vehículos históricos con NULL, usando el concesionario vinculado unívocamente a una BU.
