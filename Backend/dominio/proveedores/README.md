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

## Clasificación de `Supplier` (servicio / consumo)

`Supplier` tiene dos flags **independientes** (un proveedor puede ser ambos):

| Campo | Tipo | Significado |
| --- | --- | --- |
| `provee_servicio` | boolean (default false) | Taller al que **mandamos trabajos** (servicios de mantenimiento) |
| `provee_consumo` | boolean (default false) | Proveedor al que **le compramos** cosas (refacciones, insumos) |

- Scopes: `Supplier.de_servicio`, `Supplier.de_consumo`.
- Filtro en `GET /api/v1/suppliers?provee_servicio=true` / `?provee_consumo=true`.
- Ambos van en el serializer (lista y detalle). Migración `20260527000004`.
- Los registros existentes quedan en `false`/`false` (sin clasificar) — se marcan
  desde el catálogo de Proveedores (FE: toggles en `SupplierForm`, chips en lista/detalle).
- Uso previsto: el dropdown "Proveedor/Taller" del modal de Agendar servicio debe
  filtrar `de_servicio`; compras/inventario filtran `de_consumo`.

## Notas de diseño

- `GasStation` y `Concessionaire` están físicamente en este dominio pero se documentan también en Combustible y Servicios TTPN respectivamente, ya que son el punto de contacto principal.
- `Supplier` se relaciona con Vehículos (mantenimiento) y, vía `provee_consumo`, con compras/inventario de taller.

---

## Controllers

```text
app/controllers/api/v1/suppliers_controller.rb
app/controllers/api/v1/gas_stations_controller.rb
app/controllers/api/v1/concessionaires_controller.rb
```

- `Concessionaire` (global, multi-BU + deduplicación al crear): ver
  [`concessionaire.md`](concessionaire.md).

---

## Archivos Rails completos

```text
app/models/supplier.rb
app/models/gas_station.rb
app/models/concessionaire.rb
app/controllers/api/v1/suppliers_controller.rb
app/controllers/api/v1/gas_stations_controller.rb
```
