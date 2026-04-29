# Dominio: Combustible

Gestión de combustible: cargas por unidad, archivos de importación de gasolinera, estadísticos de consumo.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `GasCharge` | Carga de combustible de una unidad |
| `GasFile` | Archivo importado de la gasolinera |
| `GasStation` | Estación (compartido con Proveedores) |

## Estado de documentación

Pendiente. stats/ debe incluir consumo por unidad, por ruta, por período, y ai-prompts.md.

## Archivos Rails relacionados

```text
app/models/gas_charge.rb
app/models/gas_file.rb
app/controllers/api/v1/gas_charges_controller.rb
```
