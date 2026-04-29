# Services — Dominio Employees

## Estado actual

No hay services dedicados en `app/services/` para el dominio de empleados. La lógica de KPIs vive en `EmployeeStatsCalculable` (controller concern).

## Cuándo extraer un service de employees

Si una operación cumple alguna de estas condiciones, va en un service:
- Es llamada desde más de un controller
- Tiene más de ~15 líneas de lógica de negocio
- Necesita ser testeable de forma aislada del controller

## Candidatos futuros

| Operación | Posible service |
| --- | --- |
| Calcular liquidación de un empleado | `Services::Employees::LiquidacionCalculator` |
| Importar empleados desde CSV | `Services::Employees::CsvImporter` |
| Validar transición de movimiento | Ya en `EmployeeMovement#valida_transicion` — si crece, mover a service |

## Plantilla

```
Documentacion/dominio/employees/services/NombreServicio.md
```

Contenido mínimo: qué hace, parámetros, resultado, desde dónde se llama.
