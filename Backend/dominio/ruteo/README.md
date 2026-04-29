# Dominio: Ruteo

Asignación de pasajeros a vehículos, optimización de rutas, puntos de parada y días de operación.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `CrDay` | Día de ruta |
| `CrdHr` | Horario de ruta diaria |
| `CrdhRoute` | Ruta asignada a un horario |
| `CrdhrPoint` | Punto de parada de una ruta |
| `ReviewPoint` | Punto de revisión |

## Estado de documentación

Pendiente. Es el dominio más complejo junto con bookings. Documentar modelos antes de stats.

## Archivos Rails relacionados

```text
app/models/cr_day.rb
app/models/crd_hr.rb
app/models/crdh_route.rb
app/models/crdhr_point.rb
app/controllers/api/v1/cr_days_controller.rb
```
