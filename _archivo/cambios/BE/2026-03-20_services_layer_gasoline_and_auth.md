# Introducción de capa de servicios — GasolineCharges y Auth::Sessions (2026-03-20)

## Contexto y motivación

Se completaron los dos últimos controllers del plan de refactorización:

| Controller | Problemas identificados |
|---|---|
| `GasolineChargesController` | SQL raw sin parametrizar para asignación de empleado; agrupaciones de stats mezcladas con HTTP |
| `Auth::SessionsController` | Lógica de privilegios del dominio `User` incrustada directamente en el controller de sesión |

---

## Controller 4 — `GasolineChargesController`

### Problema 1: SQL raw sin parametrizar en `calculate_employee_assignment`

El método original construía la query interpolando directamente el string de fecha:

```ruby
# ANTES — SQL con string building manual
sql = "SELECT va.employee_id
       FROM vehicle_asignations AS va
       WHERE va.id = (SELECT asignacion(#{vehicle.id}, to_timestamp('#{fecha_hora}','YYYY-MM-DD HH24:MI')))"

result = ActiveRecord::Base.connection.exec_query(sql).to_a.map(&:to_h)
```

Aunque `fecha_hora` se construía internamente (no venía directamente del request),
el patrón es incorrecto: no usa bind parameters y mezcla lógica de negocio con
la capa HTTP.

### Problema 2: Lógica de agrupación de stats en el controller

Los métodos `group_by_employee`, `group_by_station` y `monthly_trend` estaban
como métodos privados del controller. No eran reutilizables y aumentaban la
complejidad del controller sin necesidad.

---

### Archivos creados

#### `app/services/gasoline/employee_assignment.rb`

**Responsabilidad:** Determinar el `employee_id` correspondiente a un vehículo
en el momento de una carga, usando la función Postgres `asignacion()`.

**Interfaz:**

```ruby
employee_id = Gasoline::EmployeeAssignment.call(
  neconomico: 'A113',
  fecha:      Date.today,
  hora:       Time.current   # opcional, default '12:00'
)
# => Integer (employee_id) o nil
```

**Flujo:**

1. Busca el vehículo por `clv = neconomico`
2. Si no existe → devuelve `id` del empleado CLV `00000`
3. Llama a `asignacion(vehicle_id, timestamp)` via `exec_query` parametrizado
4. Si el resultado es nil → devuelve `id` del empleado CLV `00000`
5. Si hay resultado → devuelve ese `employee_id`

**Fix de SQL:**

```ruby
# DESPUÉS — parametrizado con sanitize_sql_array
sql = <<~SQL
  SELECT va.employee_id
    FROM vehicle_asignations AS va
   WHERE va.id = (
     SELECT asignacion(#{vehicle_id.to_i}, to_timestamp(?, 'YYYY-MM-DD HH24:MI'))
   )
SQL
ActiveRecord::Base.connection.exec_query(
  ActiveRecord::Base.sanitize_sql_array([sql, fecha_hora])
)
```

Nota: el `vehicle_id` se convierte a `.to_i` antes de interpolarse para garantizar
que solo sea un entero — es el único valor que no puede parametrizarse como bind
en ese contexto (es parte del nombre de función, no un valor de comparación).

---

#### `app/services/gasoline/stats_builder.rb`

**Responsabilidad:** Calcular agrupaciones estadísticas sobre un conjunto de
`GasolineCharge` ya filtrado.

**Interfaz:**

```ruby
charges = GasolineCharge.includes(:employee).where(fecha: rango)
result  = Gasoline::StatsBuilder.new(charges).call
# => { por_empleado: [...], por_estacion: [...], tendencia_mensual: [...] }
```

**Decisión de diseño — materialización en el constructor:**

```ruby
def initialize(charges)
  @charges = charges.to_a  # materializar una sola vez
end
```

Los tres métodos (`by_employee`, `by_station`, `monthly_trend`) iteran la misma
colección. Materializar con `.to_a` en el constructor evita que cada método
ejecute la query de nuevo. El scope llega ya con `includes(:employee)` desde
el controller, por lo que no hay N+1 al acceder a `.employee`.

---

### Archivo modificado: `GasolineChargesController`

**Cambios:**

| Antes | Después |
|---|---|
| `calculate_employee_assignment` (29 líneas, privado) | `Gasoline::EmployeeAssignment.call(...)` — 1 línea |
| `group_by_employee`, `group_by_station`, `monthly_trend` (3 métodos privados) | `Gasoline::StatsBuilder.new(charges).call` — 1 línea |
| Filtros de `index` incrustados en cascada | Extraídos a `apply_date_filter` y `apply_search` |
| `serialize_gasoline_charge` ternario ilegible | Reescrito con operador ternario limpio al final del método |

**El controller `create` quedó:**

```ruby
def create
  @gasoline_charge = GasolineCharge.new(gasoline_charge_params)

  if @gasoline_charge.employee_id.nil? && @gasoline_charge.neconomico.present?
    @gasoline_charge.employee_id = Gasoline::EmployeeAssignment.call(
      neconomico: @gasoline_charge.neconomico,
      fecha:      @gasoline_charge.fecha,
      hora:       @gasoline_charge.hora
    )
  end

  # ... save y render
end
```

**El `stats` quedó:**

```ruby
def stats
  charges = GasolineCharge.includes(:employee).where(fecha: fecha_inicio..fecha_fin)
  charges = charges.where(employee_id: params[:employee_id]) if params[:employee_id].present?
  builder = Gasoline::StatsBuilder.new(charges)

  render json: {
    total_cargas: charges.count,
    total_litros: charges.sum(:cantidad),
    total_monto:  charges.sum(:monto),
    **builder.call
  }
end
```

---

## Controller 5 — `Auth::SessionsController`

### Problema: lógica de dominio en el controller de sesión

El cálculo de privilegios es una regla del dominio `User` — depende de `role_id`,
`sadmin` y `role.privileges_hash`. Tenerlo en el controller de sesión significa que:
- No es reutilizable (si otro controller necesita los privilegios, los duplica)
- El controller conoce detalles internos del modelo `User`
- Viola el principio "Tell, don't ask"

```ruby
# ANTES — 9 líneas de lógica de dominio en el controller
privileges = if @user.role_id == 1 && @user.sadmin
               Privilege.active.each_with_object({}) do |p, h|
                 h[p.module_key] = { can_access: true, can_create: true, can_edit: true, can_delete: true }
               end
             elsif @user.role
               @user.role.privileges_hash
             else
               {}
             end
```

### Solución: `User#build_privileges`

Se agregó el método al modelo `user.rb`:

```ruby
def build_privileges
  if role_id == ROLE_ADMIN && sadmin
    Privilege.active.each_with_object({}) do |p, h|
      h[p.module_key] = { can_access: true, can_create: true, can_edit: true, can_delete: true }
    end
  elsif role
    role.privileges_hash
  else
    {}
  end
end
```

El controller `create` quedó:

```ruby
# DESPUÉS — 1 línea
privileges = @user.build_privileges
```

**Por qué un método de modelo y no un Service Object:**

La lógica solo depende del propio usuario (`role_id`, `sadmin`, `role`) — no hay
dependencias externas ni parámetros de entrada. Es exactamente el tipo de lógica
que pertenece al modelo. Un Service Object añadiría indirección sin valor.

La constante `ROLE_ADMIN = 1` ya existía en el modelo, por lo que el método
puede usarla directamente sin magic numbers.

---

## Estado final de la estructura de servicios

```
app/
├── queries/
│   └── ttpn_booking_filter.rb
└── services/
    ├── fuel_performance/
    │   ├── vehicle_calculator.rb
    │   ├── timeline_builder.rb
    │   └── performers_ranker.rb
    ├── gasoline/
    │   ├── employee_assignment.rb
    │   └── stats_builder.rb
    └── payroll/
        ├── week_calculator.rb
        ├── report_query.rb
        └── report_exporter.rb
```

Y en modelos:
- `User#build_privileges` — lógica de privilegios movida al dueño natural

---

## Impacto consolidado — plan completo

| Controller | Líneas antes | Líneas después | Servicios creados |
|---|---|---|---|
| `FuelPerformanceController` | 585 | ~100 | `VehicleCalculator`, `TimelineBuilder`, `PerformersRanker` |
| `TtpnBookingsController` | 503 | ~200 | `TtpnBookingFilter`, `WeekCalculator` |
| `PayrollReportsController` | 213 | ~70 | `ReportQuery`, `ReportExporter` |
| `GasolineChargesController` | 257 | ~130 | `EmployeeAssignment`, `StatsBuilder` |
| `Auth::SessionsController` | 82 | 72 | `User#build_privileges` (método modelo) |
| **Total** | **1.640** | **~572** | **10 servicios / 1 query object** |

---

## Compatibilidad

- Sin cambios en rutas, contratos de respuesta JSON ni migraciones
- Todos los servicios son PORO — no requieren gems adicionales
- `User#build_privileges` es retrocompatible: `me` y cualquier otro endpoint
  que necesite privilegios puede llamarlo directamente sobre el usuario
