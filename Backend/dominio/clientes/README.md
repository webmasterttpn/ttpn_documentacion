# Dominio: Clientes

Clientes de TTPN: razón social, sucursales, contactos, servicios contratados y estadísticos.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `Client` | Cliente / empresa contratante |
| `ClientBranchOffice` | Sucursales del cliente |
| `ClientContact` | Contactos del cliente |
| `ClientTtpnService` | Servicios TTPN contratados por el cliente |
| `ClientEmployee` | Empleados asignados a un cliente |

## Estado de documentación

Pendiente. Seguir la estructura de [employees/](../employees/README.md) como referencia.

## Archivos Rails relacionados

```text
app/models/client.rb
app/models/client_branch_office.rb
app/models/client_contact.rb
app/models/client_ttpn_service.rb
app/controllers/api/v1/clients_controller.rb
app/controllers/concerns/client_stats_calculable.rb
```
