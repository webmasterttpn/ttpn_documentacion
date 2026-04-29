# Introducción de capa de servicios — TtpnBookings (2026-03-19)

## Contexto y motivación

`TtpnBookingsController` era el segundo controller más problemático del proyecto.
La auditoría de mantenibilidad identificó tres problemas concretos:

| Problema | Descripción | Severidad |
|---|---|---|
| Fat controller | 503 líneas, `index` con 122 líneas y 11 filtros condicionales en cascada | Alta |
| Código duplicado | Los mismos 11 filtros copiados entre `index` y `stats` — cualquier cambio de negocio debía aplicarse en dos lugares | Alta |
| Lógica de dominio en controller | `apply_date_filters` (35 líneas): cálculo de semana de nómina con `KumiSetting`, no reutilizable desde otros contextos | Media |
| Tech debt explícito | `backfill_clvs` usa `Thread.new` en un request HTTP — sin manejo de errores, el thread muere silenciosamente | Media |

---

## Decisión de arquitectura

Se introdujeron dos patrones complementarios:

### Query Object (`app/queries/`)

Para la cadena de filtros. Un Query Object es una clase que:
- Recibe un scope AR base y parámetros
- Aplica condiciones de forma encadenada
- Devuelve el scope modificado (no los datos)

Esto lo diferencia de un Service Object: **no ejecuta**, solo **construye la query**.
El controller conserva el control de `order`, paginación y formato de respuesta.

### Service Object (`app/services/payroll/`)

Para el cálculo de la semana de nómina. Es lógica de dominio pura (no de presentación
ni de HTTP) que necesita ser reutilizable desde jobs, rake tasks y otros controllers
(por ejemplo `TravelCountsController` o un futuro `PayrollDashboardController`).

---

## Archivos creados

### `app/queries/ttpn_booking_filter.rb`

**Responsabilidad:** Centralizar todos los filtros aplicables a `TtpnBooking`.

**Interfaz:**

```ruby
scope = TtpnBookingFilter.call(params: params, scope: TtpnBooking.all)
# => ActiveRecord::Relation filtrada, sin order ni paginación
```

**Filtros encapsulados:**

| Filtro | Parámetro | Lógica |
|---|---|---|
| Estado de cuadre | `match_status` | `matched / pending / inactive / inconsistent` — combina `viaje_encontrado` y `status` |
| Cliente | `client` | IDs separados por coma: `"1,2,3"` → `WHERE client_id IN (1,2,3)` |
| Tipo de servicio | `tipo` | `WHERE ttpn_service_type_id = ?` |
| Servicio TTPN | `servicio` | `WHERE ttpn_service_id = ?` |
| Unidad/vehículo | `unidad` | Búsqueda parcial ILIKE por CLV, múltiples valores por coma, hace `JOIN vehicles` |
| Chofer | `chofer` | Búsqueda ILIKE sobre `CONCAT(nombre, apaterno, amaterno)`, hace `JOIN employees` |
| Hora | `hora` | Extrae `HOUR` y `MINUTE` de la columna `hora` con `EXTRACT` |
| Encontrado | `encontrado` | `WHERE travel_count_id IS NOT NULL` / `IS NULL` |
| Status | `status` | `WHERE status = true/false` |

**Por qué no se incluye el filtro de fechas aquí:**

`index` y `stats` tienen defaults distintos (15 días vs semana de nómina).
El filtro de fechas queda en el controller como `apply_date_filters_listing` y
`apply_date_filters_stats`, y `TtpnBookingFilter` recibe el scope ya filtrado por fecha.
Esto evita que el Query Object tenga que conocer el contexto de uso.

---

### `app/services/payroll/week_calculator.rb`

**Responsabilidad:** Calcular el rango exacto de la semana de nómina vigente según
`KumiSetting`.

**Interfaz:**

```ruby
# Devuelve el rango como hash
range = Payroll::WeekCalculator.call(business_unit_id: 1)
# => { start_date: Date, start_time: "01:30:00", end_date: Date, end_time: "01:30:00" }

# O aplica directamente a un scope AR
scope = Payroll::WeekCalculator.apply_to_scope(scope, business_unit_id: 1)
```

**Lógica:**

```
inicio = domingo_de_esta_semana + dia_pago_días + hora_corte
si inicio > ahora → inicio -= 1.semana   (la semana actual empezó la semana pasada)
fin = inicio + 7.días
```

La configuración viene de `KumiSetting`:
- `payroll_dia_pago(bu_id)` → entero (4 = jueves), default: 4
- `payroll_hora_corte(bu_id)` → string `"HH:MM"`, default: `"01:30"`

El SQL generado compara `fecha` (Date) y `hora` (Time) de forma separada porque
son columnas discretas en `ttpn_bookings`:

```sql
(fecha > :start_date OR (fecha = :start_date AND hora >= :start_time))
AND
(fecha < :end_date   OR (fecha = :end_date   AND hora < :end_time))
```

**Ventaja de extraerlo como servicio:** antes de este cambio, si se necesitaba
la semana de nómina desde un rake task o un job, había que duplicar esas 35 líneas.
Ahora es una llamada simple.

---

## Archivos modificados

### `app/controllers/api/v1/ttpn_bookings_controller.rb`

El controller pasó de **503 líneas** a **~200 líneas**.

**Antes — `index`:** 122 líneas con 11 bloques `if/elsif` de filtros incrustados.

**Después — `index`:**

```ruby
def index
  base  = TtpnBooking.includes(...)
  scope = apply_date_filters_listing(base)
  scope = TtpnBookingFilter.call(params: params, scope: scope)
                           .order(fecha: :desc, hora: :desc)
  # paginación + render
end
```

**Antes — `stats`:** Tenía los mismos 11 filtros copiados de `index` + la lógica de conteos.

**Después — `stats`:**

```ruby
def stats
  base  = TtpnBooking.includes(...)
  scope = apply_date_filters_stats(base)
  scope = TtpnBookingFilter.call(params: params, scope: scope)
  # conteos + render
end
```

**Métodos privados eliminados del controller:**

| Método eliminado | Destino |
|---|---|
| Bloque de filtros en `index` (11 condicionales) | `TtpnBookingFilter` |
| Bloque de filtros en `stats` (copia de los 11) | `TtpnBookingFilter` |
| `apply_date_filters` (semana de nómina, 35 líneas) | `Payroll::WeekCalculator` |

**Métodos privados nuevos/reorganizados:**

| Método | Qué hace |
|---|---|
| `apply_date_filters_listing` | Default 15 días — lógica simple, queda en controller |
| `apply_date_filters_stats` | Delega en `Payroll::WeekCalculator` cuando no hay fechas |
| `normalize_booking` | Formatea la hora y normaliza `client.nombre` (extraído del map inline) |
| `serialize_passenger` | Serialización de pasajeros (extraído del método `show`) |
| `open_spreadsheet` | Detecta extensión del archivo y abre con `roo` (extraído de `import`) |

**Correcciones adicionales aprovechando el refactor:**

- El parámetro `:celular` estaba duplicado en `ttpn_booking_params` — eliminada la duplicación.
- `@ttpn_booking.creation_method ||= 'manual'` reemplaza el `unless present?` original.

---

## Tech debt documentado (no resuelto en este sprint)

### `backfill_clvs` — `Thread.new` en request HTTP

```ruby
# ESTADO ACTUAL (conservado)
def backfill_clvs
  Thread.new { system("DAYS=#{days} bin/rails cuadre:backfill_ttpn_bookings") }
end
```

**Problema:** Un thread creado en el proceso de Puma no tiene:
- Manejo de errores (si falla, nadie lo sabe)
- Visibilidad de progreso
- Límite de concurrencia
- Reintento automático

**Solución propuesta (sprint separado):** convertir `cuadre:backfill_ttpn_bookings`
en un Sidekiq job `BackfillTtpnBookingsJob` y reemplazar el `Thread.new` por:

```ruby
BackfillTtpnBookingsJob.perform_async(days.to_i)
```

---

## Impacto en el sistema

| Aspecto | Antes | Después |
|---|---|---|
| Líneas en controller | 503 | ~200 |
| Filtros duplicados | 22 bloques (11 × 2 actions) | 9 métodos en `TtpnBookingFilter` |
| Lógica de nómina reutilizable | No (solo en este controller) | Sí (servicio independiente) |
| Testabilidad de filtros | Solo vía request specs | Unit specs sobre `TtpnBookingFilter` |
| Testabilidad de semana nómina | Solo vía request specs | Unit specs sobre `Payroll::WeekCalculator` |

---

## Compatibilidad

- No se modificaron rutas (`routes.rb`)
- No se modificaron contratos de respuesta JSON
- No se modificaron modelos
- `TtpnBookingFilter` recibe el scope base como argumento → no tiene estado global,
  seguro para uso concurrente

---

## Próximos pasos del plan de servicios

1. ~~`FuelPerformanceController`~~ ✓
2. ~~`TtpnBookingsController`~~ ✓ (este documento)
3. `PayrollReportsController` → `Payroll::ReportQuery` + `Payroll::ReportExporter` (+ fix SQL injection)
4. `GasolineChargesController` → `Gasoline::EmployeeAssignmentService` + `Gasoline::StatsBuilder`
5. `Auth::SessionsController` → `User#build_privileges`
