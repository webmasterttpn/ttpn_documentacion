# Dominio: Proveedores

Catálogo de proveedores externos: gasolineras, talleres y concesionarias. Los modelos de este dominio son de catálogo y son referenciados por otros dominios (Combustible, Vehículos, Servicios TTPN).

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `Supplier` | `suppliers` | Proveedor genérico: talleres, refaccionarias, servicios externos |
| `GasStation` | `gas_stations` | Estación de servicio (gasolinera). Compartida con dominio Combustible |
| `Concessionaire` | `concessionaires` | Concesionaria propietaria de unidades. Compartida con dominio Servicios TTPN |

---

## Uso por dominio

| Modelo | Usado por |
| --- | --- |
| `Supplier` | Mantenimientos de vehículos, órdenes de compra |
| `GasStation` | `GasCharge`, `GasolineCharge` (dónde se cargó el combustible) |
| `Concessionaire` | `Vehicle` (propietario de la unidad), `TtpnService` (concesionaria del servicio) |

---

## Notas de diseño

- `GasStation` y `Concessionaire` están físicamente en este dominio pero se documentan también en Combustible y Servicios TTPN respectivamente, ya que son el punto de contacto principal.
- `Supplier` solo tiene relación con Vehículos hoy. Si se amplía a compras generales, este dominio crecerá.

---

## Controllers

```text
app/controllers/api/v1/suppliers_controller.rb
app/controllers/api/v1/gas_stations_controller.rb
```

---

## Archivos Rails completos

```text
app/models/supplier.rb
app/models/gas_station.rb
app/models/concessionaire.rb
app/controllers/api/v1/suppliers_controller.rb
app/controllers/api/v1/gas_stations_controller.rb
```
