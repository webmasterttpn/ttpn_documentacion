# Dominio: Servicios TTPN

Catálogo de servicios que TTPN ofrece a sus clientes: tipos, precios por tipo de vehículo, incrementos por chofer e historial.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `TtpnService` | Servicio ofrecido (un viaje, una ruta, etc.) |
| `TtpnServiceType` | Tipo de servicio (traslado, tour, etc.) |
| `TtpnServicePrice` | Precio por tipo de vehículo |
| `TtpnServiceDriverIncrease` | Incremento por chofer |
| `TtpnForeignDestiny` | Destino foráneo |

## Estado de documentación

Pendiente. Seguir la estructura de [employees/](../employees/README.md) como referencia.

## Archivos Rails relacionados

```text
app/models/ttpn_service.rb
app/models/ttpn_service_type.rb
app/models/ttpn_service_price.rb
app/controllers/api/v1/ttpn_services_controller.rb
```
