# Catálogo Completo de Funciones PostgreSQL

**Fecha:** 2026-01-15  
**Base de Datos:** ttpngas  
**Total de Funciones:** 32

---

## 📋 Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Funciones por Categoría](#funciones-por-categoría)
3. [Análisis de Seguridad (SQL Injection)](#análisis-de-seguridad-sql-injection)
4. [Funciones Detalladas](#funciones-detalladas)
5. [Recomendaciones](#recomendaciones)

---

## 1. Resumen Ejecutivo

### Estado Actual

✅ **32 funciones** encontradas en PostgreSQL  
⚠️ **0 funciones** versionadas en migraciones  
🔴 **Riesgo Alto:** Funciones no versionadas dificultan migración a Supabase

### Categorías de Funciones

| Categoría                   | Cantidad | Propósito                                   |
| --------------------------- | -------- | ------------------------------------------- |
| **Cuadre de Viajes**        | 6        | Matching automático entre reservas y viajes |
| **Asignaciones**            | 2        | Obtener asignaciones de vehículos/choferes  |
| **Cuadre de Gasolina**      | 2        | Matching de cargas de gasolina              |
| **Cálculos de Nómina**      | 5        | Pagos, incrementos, vacaciones              |
| **Contadores/Estadísticas** | 4        | Conteo de viajes, costos, etc.              |
| **Auxiliares**              | 13       | Funciones de soporte                        |

### Nivel de Seguridad

✅ **SEGURAS:** Todas las funciones usan **parámetros posicionales** ($1, $2, etc.)  
✅ **NO hay interpolación de strings** dentro de las funciones  
⚠️ **RIESGO:** Los **helpers de Ruby** sí usan interpolación (SQL injection)

---

## 2. Funciones por Categoría

### 2.1 Cuadre de Viajes (Booking/Travel Matching)

| Función                  | Retorna | Propósito                               |
| ------------------------ | ------- | --------------------------------------- |
| `buscar_travel_id(...)`  | bigint  | ID del viaje que coincide con reserva   |
| `buscar_booking_id(...)` | bigint  | ID de la reserva que coincide con viaje |
| `buscar_booking(...)`    | boolean | Si existe reserva coincidente           |
| `enc_booking(...)`       | ?       | Encabezado de booking                   |
| `enc_travel(...)`        | ?       | Encabezado de travel                    |
| `qty_enc_booking(...)`   | bigint  | Cantidad de bookings encontrados        |
| `qty_enc_travel(...)`    | bigint  | Cantidad de travels encontrados         |

### 2.2 Asignaciones de Vehículos/Choferes

| Función                                       | Retorna | Propósito                            |
| --------------------------------------------- | ------- | ------------------------------------ |
| `asignacion(vehicle_id, timestamp)`           | bigint  | ID de asignación de vehículo vigente |
| `asignacion_x_chofer(employee_id, timestamp)` | bigint  | ID de asignación de chofer vigente   |

### 2.3 Cuadre de Gasolina

| Función                    | Retorna | Propósito                             |
| -------------------------- | ------- | ------------------------------------- |
| `buscar_gascharge_id(...)` | bigint  | ID de carga de gasolina coincidente   |
| `buscar_gasfile_id(...)`   | bigint  | ID de archivo de gasolina coincidente |

### 2.4 Cálculos de Nómina

| Función                                             | Retorna | Propósito                           |
| --------------------------------------------------- | ------- | ----------------------------------- |
| `pago_chofer(base, inc_servicio, inc_nivel)`        | double  | Cálculo de pago total al chofer     |
| `incremento_servicio(vehicle_type, destino)`        | double  | Incremento por tipo de servicio     |
| `incremento_cliente(vehicle_type, destino, planta)` | double  | Incremento por cliente              |
| `incremento_por_nivel(employee_id, vehicle_id)`     | double  | Incremento por nivel del chofer     |
| `pago_vacaciones(fecha_ingreso, employee_id, sdi)`  | numeric | Cálculo de pago de vacaciones       |
| `dias_vacaciones(años)`                             | integer | Días de vacaciones según antigüedad |

### 2.5 Contadores y Estadísticas

| Función                                             | Retorna | Propósito                  |
| --------------------------------------------------- | ------- | -------------------------- |
| `cont_viajes(employee_id, fecha_inicio, fecha_fin)` | bigint  | Cuenta viajes de un chofer |
| `cost_viajes(employee_id, fecha_inicio, fecha_fin)` | double  | Suma costos de viajes      |
| `cont_capt(...)`                                    | ?       | Contador de capturas       |
| `cuenta_cap_fact(...)`                              | ?       | Cuenta capturas facturadas |

### 2.6 Auxiliares

| Función                 | Retorna | Propósito                    |
| ----------------------- | ------- | ---------------------------- |
| `buscar_nomina(...)`    | ?       | Búsqueda de nómina           |
| `buscar_planta(...)`    | ?       | Búsqueda de planta/sucursal  |
| `cobro_fact(...)`       | ?       | Cálculo de cobros facturados |
| `fin_annio(...)`        | ?       | Fin de año                   |
| `max_odometro(...)`     | ?       | Máximo odómetro              |
| `loopthroughtable(...)` | ?       | Loop a través de tabla       |

---

## 3. Análisis de Seguridad (SQL Injection)

### 3.1 Funciones PostgreSQL: ✅ SEGURAS

**Todas las funciones usan parámetros posicionales** ($1, $2, $3, etc.) en lugar de interpolación de strings.

**Ejemplo de función SEGURA:**

```sql
CREATE FUNCTION buscar_travel_id(bigint, bigint, bigint, bigint, bigint, timestamp, timestamp)
RETURNS bigint AS $$
  SELECT min(tc.id)
  FROM travel_counts tc
  WHERE tc.vehicle_id = $1      -- ✅ Parámetro posicional
    AND tc.employee_id = $2     -- ✅ Parámetro posicional
    AND tc.fecha = $6           -- ✅ Parámetro posicional
$$ LANGUAGE SQL;
```

**Por qué es seguro:**

- PostgreSQL trata $1, $2, etc. como **parámetros preparados**
- Los valores se escapan automáticamente
- No hay forma de inyectar SQL malicioso

---

### 3.2 Helpers de Ruby: 🔴 VULNERABLES

**Los helpers SÍ usan interpolación de strings**, lo que los hace vulnerables a SQL injection.

**Ejemplo VULNERABLE:**

```ruby
# ❌ VULNERABLE a SQL Injection
def obtener_empleado(vehiculo, hora_actual)
  sql = "SELECT em.id
         FROM employees em
         WHERE em.id = (
           SELECT asignacion(#{vehiculo}, to_timestamp('#{hora_actual}', 'YYYY-MM-DD HH24:MI'))
         )"

  ActiveRecord::Base.connection.exec_query(sql)
end
```

**Ataque posible:**

```ruby
# Si un atacante controla 'vehiculo':
vehiculo = "1); DROP TABLE employees; --"

# La consulta resultante sería:
"SELECT asignacion(1); DROP TABLE employees; --, ...)"
```

---

### 3.3 Vectores de Ataque Identificados

| Helper             | Parámetros Vulnerables                                                       | Riesgo  |
| ------------------ | ---------------------------------------------------------------------------- | ------- |
| `obtener_empleado` | `vehiculo`, `hora_actual`                                                    | 🔴 Alto |
| `busca_en_travel`  | `vehiculo`, `empleado`, `tst`, `tfd`, `cliente`, `fecha_inicio`, `fecha_fin` | 🔴 Alto |
| `obtener_vehiculo` | `empleado`, `fecha_hora`                                                     | 🔴 Alto |
| `busca_en_booking` | `vehiculo`, `empleado`, `tst`, `cliente`, `tfd`, `fecha_inicio`, `fecha_fin` | 🔴 Alto |

**Total de helpers vulnerables:** 4  
**Total de parámetros sin sanitizar:** ~20

---

## 4. Funciones Detalladas

### 4.1 Cuadre de Viajes

#### `buscar_booking(...)` - Verificar si existe reserva

```sql
CREATE OR REPLACE FUNCTION public.buscar_booking(
  bigint,  -- $1: vehicle_id
  bigint,  -- $2: employee_id
  bigint,  -- $3: ttpn_service_type_id
  bigint,  -- $4: client_id
  bigint,  -- $5: ttpn_foreign_destiny_id
  timestamp with time zone,  -- $6: fecha_inicio
  timestamp with time zone   -- $7: fecha_fin
)
RETURNS boolean
LANGUAGE sql
AS $function$
  SELECT true as encontrado
  FROM ttpn_bookings as tb,
       ttpn_services as ts
  WHERE tb.vehicle_id = $1
    AND tb.employee_id = $2
    AND (tb.viaje_encontrado != true OR tb.viaje_encontrado is null)
    AND tb.ttpn_service_type_id = $3
    AND tb.client_id = $4
    AND (tb.fecha + tb.hora) BETWEEN ($6 - '30 minutes'::INTERVAL) AND ($7 + '15 minutes'::INTERVAL)
    AND tb.status = true
    AND ts.id = tb.ttpn_service_id
    AND ts.ttpn_foreign_destiny_id = $5
    AND tb.id = (
      SELECT max(tb2.id)
      FROM ttpn_bookings as tb2,
           ttpn_services as ts2
      WHERE tb2.vehicle_id = $1
        AND tb2.employee_id = $2
        AND (tb2.viaje_encontrado != true OR tb2.viaje_encontrado is null)
        AND tb2.ttpn_service_type_id = $3
        AND tb2.client_id = $4
        AND tb2.status = true
        AND (tb2.fecha + tb2.hora) BETWEEN ($6 - '30 minutes'::INTERVAL) AND ($7 + '15 minutes'::INTERVAL)
        AND ts2.id = tb2.ttpn_service_id
        AND ts2.ttpn_foreign_destiny_id = $5
    )
$function$
```

**Propósito:** Retorna `true` si existe una reserva que coincida con los parámetros.  
**Usado en:** Trigger `sp_tctb_update`

---

### 4.2 Cuadre de Gasolina

#### `buscar_gascharge_id(...)` - Buscar carga de gasolina

```sql
CREATE OR REPLACE FUNCTION public.buscar_gascharge_id(
  bigint,   -- $1: ticket
  timestamp with time zone,  -- $2: fecha_cuadre
  numeric,  -- $3: cantidad
  numeric   -- $4: monto
)
RETURNS bigint
LANGUAGE sql
AS $function$
  SELECT id
  FROM gas_charges
  WHERE ticket = $1
    AND fecha_cuadre = $2
    AND carga_encontrada != true
    AND cantidad = $3
    AND monto = $4
$function$
```

**Propósito:** Buscar una carga de gasolina que coincida con los datos del archivo.  
**Usado en:** Sistema de cuadre de gasolina

---

#### `buscar_gasfile_id(...)` - Buscar archivo de gasolina

```sql
CREATE OR REPLACE FUNCTION public.buscar_gasfile_id(
  bigint,   -- $1: servicio
  timestamp with time zone,  -- $2: fecha
  numeric,  -- $3: volumen
  numeric   -- $4: importe
)
RETURNS bigint
LANGUAGE sql
AS $function$
  SELECT id
  FROM gas_files
  WHERE servicio = $1
    AND fecha = $2
    AND carga_encontrada != true
    AND volumen = $3
    AND importe = $4
$function$
```

**Propósito:** Buscar un archivo de gasolina que coincida con la carga.

---

### 4.3 Cálculos de Nómina

#### `pago_chofer(...)` - Calcular pago total

```sql
CREATE OR REPLACE FUNCTION public.pago_chofer(
  double precision,  -- $1: monto_base
  double precision,  -- $2: incremento_servicio (%)
  double precision   -- $3: incremento_nivel (%)
)
RETURNS double precision
LANGUAGE sql
AS $function$
  SELECT ($1 + ($1 * ($2 / 100))) + (($1 + ($1 * ($2 / 100))) * ($3 / 100))
$function$
```

**Fórmula:**

```
pago_total = (base + (base * inc_servicio%)) + ((base + (base * inc_servicio%)) * inc_nivel%)
```

**Ejemplo:**

```sql
SELECT pago_chofer(100, 10, 5);
-- base = 100
-- con incremento servicio 10% = 110
-- con incremento nivel 5% sobre 110 = 115.5
-- Resultado: 115.5
```

---

#### `incremento_servicio(...)` - Incremento por servicio

```sql
CREATE OR REPLACE FUNCTION public.incremento_servicio(
  integer,          -- $1: vehicle_type_id
  character varying -- $2: destino_nombre
)
RETURNS double precision
LANGUAGE sql
AS $function$
  SELECT tsdi.incremento
  FROM ttpn_service_driver_increases AS tsdi
  WHERE tsdi.vehicle_type_id = $1
    AND tsdi.ttpn_service_id IN (
      SELECT max(ts.id)
      FROM ttpn_services AS ts,
           ttpn_foreign_destinies AS tfd
      WHERE tfd.id = ts.ttpn_foreign_destiny_id
        AND tfd.nombre = $2
        AND ts.status = true
    )
    AND tsdi.fecha_efectiva = (
      SELECT max(fecha_efectiva)
      FROM ttpn_service_driver_increases AS tsdi2
      WHERE tsdi2.vehicle_type_id = $1
        AND tsdi2.ttpn_service_id IN (
          SELECT max(ts.id)
          FROM ttpn_services AS ts,
               ttpn_foreign_destinies AS tfd
          WHERE tfd.id = ts.ttpn_foreign_destiny_id
            AND tfd.nombre = $2
            AND ts.status = true
        )
        AND fecha_hasta IS NULL
        AND tsdi2.incremento IS NOT NULL
    )
    AND tsdi.fecha_hasta IS NULL
    AND tsdi.incremento IS NOT NULL
$function$
```

**Propósito:** Obtener el incremento vigente para un tipo de vehículo y destino.

---

#### `incremento_por_nivel(...)` - Incremento por nivel del chofer

```sql
CREATE OR REPLACE FUNCTION public.incremento_por_nivel(
  bigint,  -- $1: employee_id
  bigint   -- $2: vehicle_id
)
RETURNS double precision
LANGUAGE sql
AS $function$
  SELECT COALESCE(dl.incremento, 0)
  FROM employee_drivers_levels as edl
  LEFT JOIN drivers_levels as dl ON edl.drivers_level_id = dl.id
  LEFT JOIN vehicles as vh ON edl.vehicle_type_id = vh.vehicle_type_id
  WHERE employee_id = $1
    AND vh.id = $2
$function$
```

**Propósito:** Obtener el incremento según el nivel del chofer y el vehículo.

---

#### `dias_vacaciones(...)` - Días de vacaciones por antigüedad

```sql
CREATE OR REPLACE FUNCTION public.dias_vacaciones(bigint)  -- $1: años_antiguedad
RETURNS integer
LANGUAGE sql
AS $function$
  SELECT CASE
    WHEN $1 = 0 THEN 0
    WHEN $1 = 1 THEN 6
    WHEN $1 = 2 THEN 8
    WHEN $1 = 3 THEN 10
    WHEN $1 = 4 THEN 12
    WHEN $1 BETWEEN 5 AND 9 THEN 14
    ELSE 16
  END
$function$
```

**Tabla de días:**

| Años | Días de Vacaciones |
| ---- | ------------------ |
| 0    | 0                  |
| 1    | 6                  |
| 2    | 8                  |
| 3    | 10                 |
| 4    | 12                 |
| 5-9  | 14                 |
| 10+  | 16                 |

---

#### `pago_vacaciones(...)` - Calcular pago de vacaciones

```sql
CREATE OR REPLACE FUNCTION public.pago_vacaciones(
  timestamp with time zone,  -- $1: fecha_ingreso
  bigint,                    -- $2: employee_id
  numeric                    -- $3: sdi (salario diario integrado)
)
RETURNS numeric
LANGUAGE plpgsql
AS $function$
DECLARE
  dias_vacaciones bigint := (
    SELECT dias_vacaciones((SELECT fin_annio()::date - $1::date) / 365)
  );
  dias_efectivos bigint := (
    SELECT COALESCE(
      (SELECT sum(dias_efectivos)
       FROM employee_vacations
       WHERE employee_id = $2
         AND periodo = (SELECT fin_annio()::date - $1::date) / 365
      ), 0
    )
  );
  pago decimal;
BEGIN
  IF dias_vacaciones > 0 THEN
    CASE
      WHEN dias_efectivos = 0 THEN
        pago := dias_vacaciones * $3;
      ELSE
        pago := (dias_vacaciones - dias_efectivos) * $3;
    END CASE;
  END IF;
  RETURN pago;
END
$function$
```

**Lógica:**

1. Calcula años de antigüedad
2. Obtiene días de vacaciones según tabla
3. Resta días ya tomados
4. Multiplica por SDI

---

### 4.4 Contadores y Estadísticas

#### `cont_viajes(...)` - Contar viajes de un chofer

```sql
CREATE OR REPLACE FUNCTION public.cont_viajes(
  bigint,  -- $1: employee_id
  date,    -- $2: fecha_inicio
  date     -- $3: fecha_fin
)
RETURNS bigint
LANGUAGE sql
AS $function$
  SELECT count(tc.id) as cont_viajes
  FROM travel_counts as tc
  WHERE (tc.fecha + tc.hora) BETWEEN ($2 + time '01:30') AND ($3 + '1 day'::INTERVAL + time '01:30')
    AND tc.status = true
    AND tc.employee_id = $1
$function$
```

**Propósito:** Cuenta los viajes de un chofer en un rango de fechas.  
**Nota:** Ajusta 1:30 horas (posiblemente para considerar turno nocturno)

---

#### `cost_viajes(...)` - Sumar costos de viajes

```sql
CREATE OR REPLACE FUNCTION public.cost_viajes(
  bigint,  -- $1: employee_id
  date,    -- $2: fecha_inicio
  date     -- $3: fecha_fin
)
RETURNS double precision
LANGUAGE sql
AS $function$
  SELECT sum(tc.costo)
  FROM travel_counts as tc
  WHERE (tc.fecha + tc.hora) BETWEEN ($2 + time '01:30') AND ($3 + '1 day'::INTERVAL + time '01:30')
    AND tc.status = true
    AND tc.employee_id = $1
$function$
```

**Propósito:** Suma los costos de todos los viajes de un chofer.

---

## 5. Recomendaciones

### 5.1 Seguridad (SQL Injection)

#### 🔴 Prioridad Crítica: Refactorizar Helpers de Ruby

**Problema:**

```ruby
# ❌ VULNERABLE
sql = "SELECT asignacion(#{vehiculo}, to_timestamp('#{hora_actual}', ...))"
```

**Solución 1: Usar Parámetros Preparados**

```ruby
# ✅ SEGURO
sql = "SELECT asignacion($1, to_timestamp($2, 'YYYY-MM-DD HH24:MI'))"
bindings = [[nil, vehiculo], [nil, hora_actual]]
ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings)
```

**Solución 2: Usar ActiveRecord (Preferido)**

```ruby
# ✅ MÁS SEGURO Y MANTENIBLE
def obtener_empleado(vehiculo, hora_actual)
  # Llamar a la función usando Arel
  result = ActiveRecord::Base.connection.select_value(
    Arel.sql("SELECT asignacion(?, to_timestamp(?, 'YYYY-MM-DD HH24:MI'))"),
    vehiculo,
    hora_actual
  )

  if result
    Employee.where(id: result).select(:id).first
  else
    Employee.where(clv: '00000').select(:id).first
  end
end
```

**Solución 3: Crear Métodos de Modelo**

```ruby
# ✅ MEJOR PRÁCTICA
class VehicleAsignation < ApplicationRecord
  def self.find_by_vehicle_and_time(vehicle_id, timestamp)
    sql = <<-SQL
      SELECT id FROM vehicle_asignations
      WHERE id = asignacion(?, ?)
    SQL

    connection.select_value(sanitize_sql_array([sql, vehicle_id, timestamp]))
  end
end

# Uso:
asignacion_id = VehicleAsignation.find_by_vehicle_and_time(vehiculo, hora_actual)
```

---

### 5.2 Versionamiento (Migraciones)

#### 🔴 Prioridad Alta: Crear Migraciones para Todas las Funciones

**Estructura recomendada:**

```
db/migrate/
├── YYYYMMDDHHMMSS_create_postgres_functions_asignaciones.rb
├── YYYYMMDDHHMMSS_create_postgres_functions_cuadre_viajes.rb
├── YYYYMMDDHHMMSS_create_postgres_functions_cuadre_gasolina.rb
├── YYYYMMDDHHMMSS_create_postgres_functions_nomina.rb
├── YYYYMMDDHHMMSS_create_postgres_functions_contadores.rb
├── YYYYMMDDHHMMSS_create_postgres_triggers_ttpn_booking.rb
└── YYYYMMDDHHMMSS_create_postgres_functions_auxiliares.rb
```

**Beneficios:**

- ✅ Control de versiones
- ✅ Fácil migración a Supabase
- ✅ Recreación de ambientes
- ✅ Rollback si es necesario

---

### 5.3 Performance

#### 🟡 Prioridad Media: Optimizar Funciones Complejas

**Funciones con múltiples subqueries:**

- `incremento_servicio` - 2 subqueries anidadas
- `incremento_cliente` - 3+ subqueries anidadas
- `buscar_travel_id` - Subquery en WHERE

**Recomendaciones:**

1. Usar CTEs (Common Table Expressions)
2. Crear índices compuestos
3. Considerar vistas materializadas

**Ejemplo de optimización:**

```sql
-- ❌ ANTES: Múltiples subqueries
CREATE FUNCTION incremento_servicio(...)
RETURNS double precision AS $$
  SELECT tsdi.incremento
  FROM ttpn_service_driver_increases AS tsdi
  WHERE tsdi.ttpn_service_id IN (SELECT max(ts.id) FROM ...)
    AND tsdi.fecha_efectiva = (SELECT max(fecha_efectiva) FROM ...)
$$ LANGUAGE SQL;

-- ✅ DESPUÉS: Con CTE
CREATE FUNCTION incremento_servicio(...)
RETURNS double precision AS $$
  WITH servicio_activo AS (
    SELECT max(ts.id) as service_id
    FROM ttpn_services ts
    JOIN ttpn_foreign_destinies tfd ON tfd.id = ts.ttpn_foreign_destiny_id
    WHERE tfd.nombre = $2 AND ts.status = true
  ),
  fecha_vigente AS (
    SELECT max(fecha_efectiva) as fecha
    FROM ttpn_service_driver_increases
    WHERE vehicle_type_id = $1
      AND ttpn_service_id = (SELECT service_id FROM servicio_activo)
      AND fecha_hasta IS NULL
  )
  SELECT incremento
  FROM ttpn_service_driver_increases
  WHERE vehicle_type_id = $1
    AND ttpn_service_id = (SELECT service_id FROM servicio_activo)
    AND fecha_efectiva = (SELECT fecha FROM fecha_vigente)
    AND fecha_hasta IS NULL
$$ LANGUAGE SQL;
```

---

### 5.4 Testing

#### 🟡 Prioridad Media: Agregar Tests para Funciones

```ruby
# test/models/postgres_functions_test.rb
class PostgresFunctionsTest < ActiveSupport::TestCase
  test "asignacion returns correct vehicle_asignation" do
    vehicle = create(:vehicle)
    employee = create(:employee)
    asignacion = create(:vehicle_asignation,
      vehicle: vehicle,
      employee: employee,
      fecha_efectiva: 1.day.ago,
      fecha_hasta: nil
    )

    result = ActiveRecord::Base.connection.select_value(
      "SELECT asignacion(?, NOW())",
      vehicle.id
    )

    assert_equal asignacion.id, result
  end

  test "pago_chofer calculates correctly" do
    result = ActiveRecord::Base.connection.select_value(
      "SELECT pago_chofer(100, 10, 5)"
    )

    assert_in_delta 115.5, result, 0.01
  end

  test "dias_vacaciones returns correct days" do
    assert_equal 0, dias_vacaciones(0)
    assert_equal 6, dias_vacaciones(1)
    assert_equal 16, dias_vacaciones(15)
  end
end
```

---

### 5.5 Documentación

#### 🟢 Prioridad Baja: Agregar Comentarios a Funciones

```sql
COMMENT ON FUNCTION asignacion(bigint, timestamp) IS
  'Obtiene el ID de la asignación de vehículo vigente en una fecha/hora específica.
   Parámetros:
     $1: vehicle_id
     $2: timestamp
   Retorna: ID de vehicle_asignation o NULL';

COMMENT ON FUNCTION pago_chofer(double precision, double precision, double precision) IS
  'Calcula el pago total de un chofer incluyendo incrementos.
   Fórmula: (base + base*inc_servicio%) + ((base + base*inc_servicio%) * inc_nivel%)
   Parámetros:
     $1: monto_base
     $2: incremento_servicio (porcentaje)
     $3: incremento_nivel (porcentaje)
   Retorna: monto total a pagar';
```

---

## Resumen de Acciones

### ✅ Completado

- [x] Documentar todas las funciones
- [x] Analizar seguridad SQL injection
- [x] Identificar vectores de ataque

### 🔴 Pendiente - Crítico

- [ ] Refactorizar helpers de Ruby (SQL injection)
- [ ] Crear migraciones para todas las funciones
- [ ] Crear migraciones para triggers

### 🟡 Pendiente - Importante

- [ ] Optimizar funciones con CTEs
- [ ] Agregar índices compuestos
- [ ] Crear tests para funciones

### 🟢 Pendiente - Deseable

- [ ] Agregar comentarios a funciones
- [ ] Documentar funciones auxiliares faltantes
- [ ] Crear vistas materializadas

---

**Autor:** Antigravity AI  
**Fecha:** 2026-01-15  
**Versión:** 1.0
