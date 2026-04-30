# Dominio: Servicios TTPN

Catálogo de servicios que TTPN ofrece a sus clientes: tipos de servicio, destinos, precios por tipo de vehículo e incrementos por chofer. Este dominio es la fuente de verdad para cotizar y registrar viajes (`TtpnBooking`).

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `TtpnServiceType` | `ttpn_service_types` | Tipo de servicio (traslado, renta, viaje foráneo, etc.) |
| `TtpnService` | `ttpn_services` | Servicio concreto: origen, destino, tipo, cliente asignado |
| `TtpnServicePrice` | `ttpn_service_prices` | Precio del servicio segmentado por tipo de vehículo |
| `TtpnServiceDriverIncrease` | `ttpn_service_driver_increases` | Incremento económico para el chofer en este servicio |
| `TtpnForeignDestiny` | `ttpn_foreign_destinies` | Catálogo de destinos foráneos para servicios de larga distancia |
| `Concessionaire` | `concessionaires` | Concesionaria propietaria de unidades, vinculada a una BusinessUnit |

---

## Relación con TtpnBooking

Un `TtpnBooking` siempre referencia un `TtpnService`. El precio del booking se resuelve consultando `TtpnServicePrice` según el tipo de vehículo asignado.

```text
TtpnService → TtpnServicePrice (por VehicleType)
     │
     └── TtpnBooking (reserva concreta con fecha, vehicle, employee)
               │
               └── TravelCount (conteo de viaje registrado desde PHP o Rails)
```

---

## Concesionarias

`Concessionaire` representa a la empresa o persona propietaria legal de los vehículos. Un vehículo puede pertenecer a una concesionaria distinta a la empresa operadora. Se usa en reportes de nómina y facturación.

---

## Controllers

```text
app/controllers/api/v1/ttpn_services_controller.rb
app/controllers/api/v1/ttpn_service_types_controller.rb
app/controllers/api/v1/ttpn_foreign_destinies_controller.rb
app/controllers/api/v1/concessionaires_controller.rb
```

---

## Archivos Rails completos

```text
app/models/ttpn_service.rb
app/models/ttpn_service_type.rb
app/models/ttpn_service_price.rb
app/models/ttpn_service_driver_increase.rb
app/models/ttpn_foreign_destiny.rb
app/models/concessionaire.rb
app/controllers/api/v1/ttpn_services_controller.rb
app/controllers/api/v1/ttpn_service_types_controller.rb
app/controllers/api/v1/concessionaires_controller.rb
```
