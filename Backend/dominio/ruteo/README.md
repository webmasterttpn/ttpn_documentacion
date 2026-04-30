# Dominio: Ruteo

Asignación de rutas fijas para transporte de personal: días de operación, horarios, rutas y puntos de parada. Es el dominio más complejo estructuralmente junto con Bookings.

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `CrDay` | `cr_days` | Día de ruta activo (lunes, martes…) para una configuración de ruta |
| `CrdHr` | `crd_hrs` | Horario de ruta en un día específico (hora de salida, llegada) |
| `CrdhRoute` | `crdh_routes` | Ruta concreta asignada a un horario: vehículo + conductor |
| `CrdhrPoint` | `crdhr_points` | Punto de parada dentro de una ruta (dirección, orden, pasajeros) |
| `ReviewPoint` | `review_points` | Punto de revisión/control de seguridad en una ruta |

---

## Jerarquía de datos

```text
CrDay (día de operación)
  └── CrdHr (horario del día)
        └── CrdhRoute (ruta: vehículo + chofer)
                └── CrdhrPoint (parada 1, parada 2 … parada N)
```

Un `CrDay` puede tener múltiples horarios (`CrdHr`). Cada horario tiene una ruta operativa (`CrdhRoute`) con sus paradas ordenadas (`CrdhrPoint`).

---

## Estado del dominio

Este dominio está implementado pero **no tiene motor de optimización de rutas**. La propuesta de motor de ruteo se encuentra en: [propuesta_motor_ruteo.md](../propuesta_motor_ruteo.md)

La propuesta incluye integración con Google Maps / OSRM para optimización automática de paradas. Hoy las rutas se configuran manualmente.

---

## ReviewPoint

Los `ReviewPoint` son puntos de control de seguridad (casetas, retenes). Se registran en la configuración de la ruta y se validan durante la ejecución del viaje.

---

## Controllers

```text
app/controllers/api/v1/cr_days_controller.rb
app/controllers/api/v1/crd_hrs_controller.rb
app/controllers/api/v1/crdh_routes_controller.rb
app/controllers/api/v1/crdhr_points_controller.rb
app/controllers/api/v1/review_points_controller.rb
```

---

## Archivos Rails completos

```text
app/models/cr_day.rb
app/models/crd_hr.rb
app/models/crdh_route.rb
app/models/crdhr_point.rb
app/models/review_point.rb
app/controllers/api/v1/cr_days_controller.rb
app/controllers/api/v1/review_points_controller.rb
```

---

## Ver también

- [Propuesta Motor de Ruteo](../propuesta_motor_ruteo.md) — integración propuesta con Google Maps / OSRM para optimización automática de paradas
- [Dominio Bookings](../bookings/) — los `CrdhRoute` y `CrdhrPoint` se usan al asignar rutas a reservas de viaje
- [ARQUITECTURA_TECNICA.md](../../../INFRA/arquitectura/ARQUITECTURA_TECNICA.md) — Sección 9: modelos de ruteo (`CrDay`, `CrdHr`, `CrdhRoute`, `CrdhrPoint`) en la base de datos
