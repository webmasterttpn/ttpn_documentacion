# PLAN DE MIGRACIÓN A PRODUCCIÓN — Kumi V2

Playbook completo para el cutover de Heroku (producción actual) → Railway + Supabase (nuevo stack).
Cada paso está ordenado cronológicamente. No saltar pasos.

---

## ARQUITECTURA ACTUAL vs. OBJETIVO

```
HOY (producción)
  Heroku Rails + RailsAdmin (monolito)  ←→  Heroku Postgres
  PHP móvil (EC2)                       ←→  Heroku Postgres

DESPUÉS (producción nueva)
  Railway Rails API (solo API, sin RailsAdmin)  ←→  Supabase Postgres
  PHP móvil (EC2)                               ←→  Supabase Postgres  ← requiere cambios en PHP
  Netlify FE (Quasar PWA)                       ←→  Railway API
```

---

## FASE 0 — PRE-VUELO (días/semanas antes)

Completar ANTES de programar la fecha de corte. No hay prisa; cada punto debe estar 100%.

### 0.1 PHP móvil — Cambiar INSERTs posicionales a columnas nombradas

Los archivos PHP usan `INSERT INTO tabla VALUES(...)` **sin nombres de columna**.
Al agregar `business_unit_id` (y otras columnas) al schema de Supabase, el orden posicional
ya no coincide y los inserts fallan con error de columnas.

El `business_unit_id` siempre será `1` en PHP — el móvil opera solo para la BU principal.

**Patrón de corrección:**

```php
// MAL — posicional, se rompe al agregar columnas al schema
"INSERT INTO driver_requests VALUES (?, ?, ?, ?, ?, ?, ?)"

// BIEN — nombrado, inmune a cambios futuros de esquema
"INSERT INTO driver_requests
   (id, descripcion, vehicle_id, employee_id, status, created_at, updated_at, business_unit_id)
 VALUES (?, ?, ?, ?, ?, ?, ?, 1)"
```

---

#### Análisis completo de archivos PHP

**`Gasto_INSERT_VEHICLE_ASIGNATION.php` → tabla `vehicle_asignations`**
- Problema: 7 valores posicionales, tabla tiene 8 columnas
- Falta: `business_unit_id`
- Fix: agregar nombre de columnas + `business_unit_id = 1` al final

```php
// ANTES
"INSERT INTO vehicle_asignations Values(?,?,?,?,?,?,?)",
array($id, $vehicle_id, $employee_id, $fecha_efectiva, $fecha_hasta, $created_at, $updated_at)

// DESPUÉS
"INSERT INTO vehicle_asignations
   (id, vehicle_id, employee_id, fecha_efectiva, fecha_hasta, created_at, updated_at, business_unit_id)
 VALUES (?,?,?,?,?,?,?,1)",
array($id, $vehicle_id, $employee_id, $fecha_efectiva, $fecha_hasta, $created_at, $updated_at)
```

---

**`Gasto_INSERT_DRIVER_REQUESTS.php` → tabla `driver_requests`**
- Problema: 7 valores posicionales, tabla tiene 8 columnas
- Falta: `business_unit_id`

```php
// ANTES
"INSERT INTO driver_requests VALUES (?, ?, ?, ?, ?, ?,?);",
array($id, $descripcion, $vehicle_id, $employee_id, $status, $created_at, $updated_at)

// DESPUÉS
"INSERT INTO driver_requests
   (id, descripcion, vehicle_id, employee_id, status, created_at, updated_at, business_unit_id)
 VALUES (?, ?, ?, ?, ?, ?, ?, 1);",
array($id, $descripcion, $vehicle_id, $employee_id, $status, $created_at, $updated_at)
```

---

**`Gasto_INSERT_SERVICE_APPOINTMENT.php` → tabla `service_appointments`**
- Problema: 11 valores posicionales, tabla tiene 13 columnas
- Falta: `driver_request_id` (nullable → `null`) y `business_unit_id`

```php
// ANTES
"INSERT INTO service_appointments Values(?,?,?,?,?,?,?,?,?,?,?)",
array($id, $vehicle_id, $employee_id, $fecha_inicio, $hora_inicio, $descripcion,
      $supplier_id, $odometro, $status, $created_at, $updated_at)

// DESPUÉS
"INSERT INTO service_appointments
   (id, vehicle_id, employee_id, fecha_inicio, hora_inicio, descripcion,
    supplier_id, odometro, status, created_at, updated_at, driver_request_id, business_unit_id)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,null,1)",
array($id, $vehicle_id, $employee_id, $fecha_inicio, $hora_inicio, $descripcion,
      $supplier_id, $odometro, $status, $created_at, $updated_at)
```

---

**`Gasto_INSERT_COO_TRAVEL_REQUEST.php` → tabla `coo_travel_requests`**
- Problema: 12 valores posicionales, tabla tiene 13 columnas
- Falta: `business_unit_id`

```php
// ANTES
"INSERT INTO coo_travel_requests Values(?,?,?,?,?,?,?,?,?,?,?,?)",
array($id, $client_id, $fecha, $hora, $ttpn_service_type_id, $descripcion,
      $user_id, $qty_van, $qty_auto, $status, $created_at, $updated_at)

// DESPUÉS
"INSERT INTO coo_travel_requests
   (id, client_id, fecha, hora, ttpn_service_type_id, descripcion,
    user_id, qty_van, qty_auto, status, created_at, updated_at, business_unit_id)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,1)",
array($id, $client_id, $fecha, $hora, $ttpn_service_type_id, $descripcion,
      $user_id, $qty_van, $qty_auto, $status, $created_at, $updated_at)
```

---

**`Gasto_INSERT_COO_TRAVEL_EMPLOYEE_REQUEST.php` → tabla `coo_travel_employee_requests`**
- Problema: 7 valores posicionales, tabla tiene 10 columnas
- Falta: `lat`, `lng` (ya en el schema, valores del Android disponibles en `$datos`) y `business_unit_id`

```php
// ANTES
"INSERT INTO coo_travel_employee_requests Values(?,?,?,?,?,?,?)",
array($id, $employee_id, $vehicle_id, $ttpn_booking_id, $status, $created_at, $updated_at)

// DESPUÉS — agregar lectura de lat/lng del JSON recibido
$lat = $datos["lat"] ?? null;
$lng = $datos["lng"] ?? null;

"INSERT INTO coo_travel_employee_requests
   (id, employee_id, vehicle_id, ttpn_booking_id, status, created_at, updated_at,
    lat, lng, business_unit_id)
 VALUES (?,?,?,?,?,?,?,?,?,1)",
array($id, $employee_id, $vehicle_id, $ttpn_booking_id, $status, $created_at, $updated_at, $lat, $lng)
```

---

**`Gasto_INSERT_DISCREPANCIES.php` → tabla `discrepancies`**
- Problema: 9 valores posicionales (incluyendo subquery para id), tabla tiene 11 columnas
- Falta: `capturado` (nullable → `null`) y `business_unit_id`

```php
// ANTES
"INSERT INTO discrepancies Values((select COALESCE(max(id) + 1,1) from discrepancies),?,?,?,?,?,true,?,null)",
array($record_type, $record_id, $kpi, $created_at, $updated_at, $descripcion)

// DESPUÉS
"INSERT INTO discrepancies
   (id, record_type, record_id, kpi, created_at, updated_at, status, descripcion, image_key, capturado, business_unit_id)
 VALUES ((select COALESCE(max(id)+1,1) from discrepancies),?,?,?,?,?,true,?,null,null,1)",
array($record_type, $record_id, $kpi, $created_at, $updated_at, $descripcion)
```

---

**`Gasto_INSERTAR_CARGA_GASOLINA.php` → tabla `gasoline_charges`**
- Problema: 16 valores posicionales, tabla tiene 17 columnas
- Falta: `business_unit_id`
- Nota: usa interpolación directa (`$var`) en vez de `?` — riesgo de SQL injection, pero no es el foco ahora

```php
// ANTES
"INSERT INTO gasoline_charges Values($id,'0',$numero,'$noeconomico','$estacion',
 '$fecha','$hora','0','$ticket','MAGNA',$cantidad,$monto,$odometro,'$created_at','$updated_at',$employee_id)",

// DESPUÉS
"INSERT INTO gasoline_charges
   (id, factura, vehicle_id, neconomico, estacion, fecha, hora, orden, ticket, producto,
    cantidad, monto, odometro, created_at, updated_at, employee_id, business_unit_id)
 VALUES ($id,'0',$numero,'$noeconomico','$estacion','$fecha','$hora','0',
         '$ticket','MAGNA',$cantidad,$monto,$odometro,'$created_at','$updated_at',$employee_id,1)",
```

---

**`Gasto_INSERTAR_POST.php` → tabla `gas_charges`**
- Problema: 19 valores posicionales, tabla tiene 20 columnas
- Falta: `business_unit_id`

```php
// ANTES
"INSERT INTO gas_charges Values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,
    (select CASE WHEN buscar_gasfile_id(...) is null THEN false ... END),
    (select buscar_gasfile_id(...)),'$fecha')",
array($id, $vehicle_id, $monto, $cantidad, $odometro, $fecha, $created_at, $updated_at,
      $hora, $lat, $lng, $imei, $created_by, $updated_by, $gas_station_id, $ticket)

// DESPUÉS
"INSERT INTO gas_charges
   (id, vehicle_id, monto, cantidad, odometro, fecha, created_at, updated_at,
    hora, lat, lng, imei, created_by, updated_by, gas_station_id, ticket,
    carga_encontrada, gas_file_id, fecha_cuadre, business_unit_id)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,
    (select CASE WHEN buscar_gasfile_id($ticket,'$fecha',$cantidad,$monto) is null THEN false ELSE true END),
    (select buscar_gasfile_id($ticket,'$fecha',$cantidad,$monto)),'$fecha',1)",
array($id, $vehicle_id, $monto, $cantidad, $odometro, $fecha, $created_at, $updated_at,
      $hora, $lat, $lng, $imei, $created_by, $updated_by, $gas_station_id, $ticket)
```

---

**`Gasto_INSERT_TTPN_BOOKINGS.php` → tabla `ttpn_bookings`**
- Problema: 23 valores posicionales, tabla tiene 26 columnas
- Falta: `clv_servicio_completa` (null — la genera un trigger), `creation_method` (default `'manual'`), `business_unit_id`
- Nota: las variables `$created_by`/`$updated_by` mapean a las columnas `created_by_id`/`updated_by_id` — los nombres son distintos pero los valores son correctos (integers)

```php
// ANTES (fragmento relevante)
"INSERT INTO ttpn_bookings Values(?,?,?,?,?,3,?,?,?,null,?,?,1,?,null,false,true,'',0,?,?,0,?)",
array($id, $client_id, $fecha, $hora, $ttpn_service_type_id, $vehicle_id, $employee_id,
      $clv_servicio, $created_at, $updated_at, $descripcion, $created_by, $updated_by,
      $coo_travel_request_id)

// DESPUÉS
"INSERT INTO ttpn_bookings
   (id, client_id, fecha, hora, ttpn_service_type_id, ttpn_service_id,
    vehicle_id, employee_id, clv_servicio, booking_status_id,
    created_at, updated_at, passenger_qty, descripcion, empalme,
    viaje_encontrado, status, desactivacion, aforo,
    created_by_id, updated_by_id, travel_count_id, coo_travel_request_id,
    clv_servicio_completa, creation_method, business_unit_id)
 VALUES (?,?,?,?,?,3,?,?,?,null,?,?,1,?,null,false,true,'',0,?,?,0,?,null,'manual',1)",
array($id, $client_id, $fecha, $hora, $ttpn_service_type_id, $vehicle_id, $employee_id,
      $clv_servicio, $created_at, $updated_at, $descripcion, $created_by, $updated_by,
      $coo_travel_request_id)
```

---

**`Gasto_INSERT_TRAVEL_COUNTS.php` → tabla `travel_counts`**
- Problema: el más complejo — 19 valores posicionales, tabla tiene 25 columnas (sin contar id serial)
- Falta: `requiere_autorizacion` (false), `status_autorizacion` (false), `user_id` (null), `clv_servicio` (null — la asigna un trigger), `created_by_id` (null), `updated_by_id` (null), `business_unit_id` (1)
- Este INSERT usa el trigger `before_insert_travel_counts` que asigna `clv_servicio` automáticamente

```php
// ANTES — posicional con concatenación directa (alto riesgo)
"INSERT INTO travel_counts Values(".$id.",".$employee_id.",".$client_branch_office_id.",
  ".$ttpn_service_type_id.",'".$fecha."',time '".$hora."',".$ttpn_foreign_destiny_id.",
  ".$costo.",".$status.",'".$created_at."','".$updated_at."',".$vehicle_id.",
  COALESCE((select buscar_booking(...)),false),null,null,
  COALESCE((select buscar_booking_id(...)),null),0,(select buscar_nomina()),false)"

// DESPUÉS — columnas nombradas, business_unit_id y columnas faltantes añadidas
"INSERT INTO travel_counts
   (id, employee_id, client_branch_office_id, ttpn_service_type_id,
    fecha, hora, ttpn_foreign_destiny_id, costo, status, created_at, updated_at,
    vehicle_id, viaje_encontrado, comentario, desactivacion, ttpn_booking_id,
    aforo, payroll_id, errorcode, requiere_autorizacion, status_autorizacion,
    user_id, clv_servicio, created_by_id, updated_by_id, business_unit_id)
 VALUES (".$id.",".$employee_id.",".$client_branch_office_id.",".$ttpn_service_type_id.",
  date '".$fecha."',time '".$hora."',".$ttpn_foreign_destiny_id.",".$costo.",".$status.",
  '".$created_at."','".$updated_at."',".$vehicle_id.",
  COALESCE((select buscar_booking(".$vehicle_id.",".$employee_id.",".$ttpn_service_type_id.",
    (Select client_id from client_branch_offices where id=".$client_branch_office_id."),
    ".$ttpn_foreign_destiny_id.",(date '".$fecha."'+time '".$hora."'),
    ((date '".$fecha."'+time '".$hora."')+'15 minutes'::INTERVAL))),false),
  null,null,
  COALESCE((select buscar_booking_id(".$vehicle_id.",".$employee_id.",".$ttpn_service_type_id.",
    (Select client_id from client_branch_offices where id=".$client_branch_office_id."),
    ".$ttpn_foreign_destiny_id.",(date '".$fecha."'+time '".$hora."'),
    ((date '".$fecha."'+time '".$hora."')+'15 minutes'::INTERVAL))),null),
  0,(select buscar_nomina()),false,
  false,false,null,null,null,null,1)"
```

---

#### Resumen — archivos a modificar

| Archivo | Tabla | Valores actuales → correctos | Columnas faltantes |
|---|---|---|---|
| `Gasto_INSERT_TRAVEL_COUNTS.php` | `travel_counts` | 19 → 26 | `requiere_autorizacion`, `status_autorizacion`, `user_id`, `clv_servicio`, `created_by_id`, `updated_by_id`, `business_unit_id` |
| `Gasto_INSERT_TTPN_BOOKINGS.php` | `ttpn_bookings` | 23 → 26 | `clv_servicio_completa`, `creation_method`, `business_unit_id` |
| `Gasto_INSERT_SERVICE_APPOINTMENT.php` | `service_appointments` | 11 → 13 | `driver_request_id`, `business_unit_id` |
| `Gasto_INSERT_COO_TRAVEL_EMPLOYEE_REQUEST.php` | `coo_travel_employee_requests` | 7 → 10 | `lat`, `lng`, `business_unit_id` |
| `Gasto_INSERT_DISCREPANCIES.php` | `discrepancies` | 9 → 11 | `capturado`, `business_unit_id` |
| `Gasto_INSERT_VEHICLE_ASIGNATION.php` | `vehicle_asignations` | 7 → 8 | `business_unit_id` |
| `Gasto_INSERT_DRIVER_REQUESTS.php` | `driver_requests` | 7 → 8 | `business_unit_id` |
| `Gasto_INSERT_COO_TRAVEL_REQUEST.php` | `coo_travel_requests` | 12 → 13 | `business_unit_id` |
| `Gasto_INSERTAR_CARGA_GASOLINA.php` | `gasoline_charges` | 16 → 17 | `business_unit_id` |
| `Gasto_INSERTAR_POST.php` | `gas_charges` | 19 → 20 | `business_unit_id` |
| `Gasto_INSERT_EMPLOYEE_INCIDENCE.php` | `employees_incidences` | 12 → 13 | `business_unit_id` (migración `20260422190000`) |
| `Gasto_INSERT_CLIENT_EMPLOYEES.php` | `client_employees` | 12 → 13 | `business_unit_id` (migración `20260422190000`) |
| `Gasto_INSERT_EMPLOYEE_APPOINTMENT_LOG.php` | `employee_appointment_logs` | 8 → 9 | `business_unit_id` (migración `20260422190000`) |

**Fixes para los 3 archivos de la migración `20260422190000`:**

```php
// Gasto_INSERT_EMPLOYEE_INCIDENCE.php — ANTES
"INSERT INTO employees_incidences VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
array($id, $employee_id, $incidence_id, $user_id, $comentario, $fecha, $hora,
      $client_branch_office_id, $vehicle_id, $status, $created_at, $updated_at)
// DESPUÉS
"INSERT INTO employees_incidences
   (id, employee_id, incidence_id, user_id, comentario, fecha, hora,
    client_branch_office_id, vehicle_id, status, created_at, updated_at, business_unit_id)
 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1);",
array($id, $employee_id, $incidence_id, $user_id, $comentario, $fecha, $hora,
      $client_branch_office_id, $vehicle_id, $status, $created_at, $updated_at)
```

```php
// Gasto_INSERT_CLIENT_EMPLOYEES.php — ANTES
"INSERT INTO client_employees Values((select COALESCE(max(id) + 1,1) from client_employees),?,?,?,?,?,?,?,?,?,?,?)",
array($client_id, $client_branch_office_id, $employee_num, $fullname, $direccion,
      $telefono, $area, $lat, $lng, $created_at, $updated_at)
// DESPUÉS
"INSERT INTO client_employees
   (id, client_id, client_branch_office_id, employee_num, fullname, direccion,
    telefono, area, lat, lng, created_at, updated_at, business_unit_id)
 VALUES ((select COALESCE(max(id)+1,1) from client_employees),?,?,?,?,?,?,?,?,?,?,?,1)",
array($client_id, $client_branch_office_id, $employee_num, $fullname, $direccion,
      $telefono, $area, $lat, $lng, $created_at, $updated_at)
```

```php
// Gasto_INSERT_EMPLOYEE_APPOINTMENT_LOG.php — ANTES
"INSERT INTO employee_appointment_logs VALUES (?, ?, ?, ?, ?, ?, ?, ?);",
array($id, $employee_id, $employee_appointment_id, $created_by, $updated_by,
      $is_active, $created_at, $updated_at)
// DESPUÉS
"INSERT INTO employee_appointment_logs
   (id, employee_id, employee_appointment_id, created_by, updated_by,
    is_active, created_at, updated_at, business_unit_id)
 VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1);",
array($id, $employee_id, $employee_appointment_id, $created_by, $updated_by,
      $is_active, $created_at, $updated_at)
```

**Archivos que NO necesitan cambios** (sus tablas no tienen `business_unit_id`):

| Archivo | Tabla | Estado |
|---|---|---|
| `Gasto_INSERT_TTPN_BOOKING_PASSENGERS.php` | `ttpn_booking_passengers` | ✅ OK |
| `Gasto_INSERT_VEHICLE_CHECKS.php` | `vehicle_checks` | ✅ OK |
| `Gasto_INSERT_EMPLOYEE_APPOINTMENT.php` | `employee_appointments` | ✅ Ya tiene BU con default 1 — solo necesita columnas nombradas |

### 0.2 Verificar filtros BU en staging (Railway)

Antes del corte, confirmar que NINGÚN endpoint devuelve datos de otra BU:

```bash
# Login como usuario normal (no sadmin) y verificar que solo ve su BU
curl -H "Authorization: Bearer TOKEN_USUARIO_BU1" \
  https://kumi-admin-api-production.up.railway.app/api/v1/labors

# Debe devolver solo labors con business_unit_id = 1
# Si aparece alguno con business_unit_id = 2, hay un leak
```

Endpoints críticos a verificar:
- `/api/v1/labors`
- `/api/v1/employees`
- `/api/v1/travel_counts`
- `/api/v1/ttpn_bookings`
- `/api/v1/vehicles`
- `/api/v1/payroll_report`

### 0.3 Verificar que Supabase tiene datos de staging al día

```sql
-- En Supabase SQL Editor
SELECT
  (SELECT COUNT(*) FROM ttpn_bookings)    AS bookings,
  (SELECT COUNT(*) FROM travel_counts)    AS travel_counts,
  (SELECT COUNT(*) FROM employees)        AS employees,
  (SELECT COUNT(*) FROM vehicles)         AS vehicles;
```

Si los conteos son muy bajos vs. Heroku, hacer una restauración fresca (ver MIGRACION_DB.md).

### 0.4 Checklist pre-vuelo

- [ ] PHP actualizado con columnas nombradas y `business_unit_id = 1`
- [ ] Filtros BU verificados en staging (ningún leak)
- [ ] FE en staging probado end-to-end (login, nómina, viajes, vehículos)
- [ ] Backups de Heroku generados y descargados localmente
- [ ] Variables de entorno de Railway documentadas y listas para producción
- [ ] Equipo notificado de la ventana de mantenimiento

---

## FASE 1 — BACKUP DE HEROKU (día del corte)

### 1.1 Generar backup manual desde dashboard

1. Ir a [dashboard.heroku.com](https://dashboard.heroku.com) → app `kumi-admin-api`
2. **Resources** → add-on **Heroku Postgres** → clic en el add-on
3. **Durability** → **Manual Backup** → esperar a que termine
4. Descargar el archivo (formato `pg_custom`)

**NO usar `heroku pg:dump` desde terminal** — la DB es demasiado grande y truena por timeout.

### 1.2 Verificar integridad del backup

```bash
# Listar contenido del backup para confirmar que tiene las tablas principales
pg_restore --list backup_file | grep -E "TABLE DATA public (ttpn_bookings|travel_counts|employees|vehicles)"
```

---

## FASE 2 — RESTAURAR EN SUPABASE (producción)

> Si Supabase staging ya tiene los datos actualizados y no hay un Supabase separado
> para producción, saltar al Paso 3 directamente.

### 2.0 Desactivar triggers antes de cualquier operación masiva

Supabase tiene triggers en varias tablas (especialmente `travel_counts` y `ttpn_bookings`)
que se disparan en INSERT/UPDATE. Sin desactivarlos, restaurar 100K filas puede tardar horas
o fallar por timeouts.

**Triggers conocidos que existen en la DB:**

| Tabla | Trigger | Cuándo se dispara | Qué hace |
|---|---|---|---|
| `travel_counts` | `before_insert_travel_counts` | BEFORE INSERT | Asigna `clv_servicio` y valida `ttpn_booking_id` |
| `ttpn_bookings` | `sp_tctb_update` | BEFORE UPDATE | Llama a `buscar_booking_id` para cada fila |

**Método 1 — Por sesión (recomendado para SQL Editor de Supabase):**

Afecta solo la sesión actual. Automático al cerrar la ventana.

```sql
-- DESACTIVAR (correr antes de TRUNCATE / INSERT masivo / UPDATE masivo)
SET session_replication_role = replica;

-- aquí van los TRUNCATE, INSERT, UPDATE...

-- REACTIVAR (correr siempre al terminar)
SET session_replication_role = DEFAULT;
```

> ⚠️ Si cierras el SQL Editor sin correr `SET session_replication_role = DEFAULT`,
> los triggers se reactivan solos al iniciar una nueva sesión — no hay riesgo de dejarlos
> permanentemente desactivados.

**Método 2 — Por tabla (más granular, persiste entre sesiones):**

Usar si se necesita desactivar solo en tablas específicas.

```sql
-- DESACTIVAR triggers en tablas problemáticas
ALTER TABLE travel_counts  DISABLE TRIGGER ALL;
ALTER TABLE ttpn_bookings  DISABLE TRIGGER ALL;
ALTER TABLE discrepancies  DISABLE TRIGGER ALL;

-- aquí van las operaciones masivas...

-- REACTIVAR — OBLIGATORIO al terminar
ALTER TABLE travel_counts  ENABLE TRIGGER ALL;
ALTER TABLE ttpn_bookings  ENABLE TRIGGER ALL;
ALTER TABLE discrepancies  ENABLE TRIGGER ALL;
```

> ⚠️ El método 2 persiste entre sesiones. Si no corres el ENABLE, los triggers quedan
> desactivados permanentemente hasta que alguien los reactive manualmente.
> **Preferir el Método 1 en SQL Editor.**

**Verificar qué triggers están activos en este momento:**

```sql
SELECT
  trigger_name,
  event_object_table AS tabla,
  event_manipulation AS evento,
  action_timing AS momento,
  CASE WHEN trigger_enabled THEN 'ACTIVO' ELSE 'DESACTIVADO' END AS estado
FROM information_schema.triggers
JOIN pg_trigger ON tgname = trigger_name
WHERE trigger_schema = 'public'
  AND event_object_table IN ('travel_counts','ttpn_bookings','discrepancies')
ORDER BY event_object_table, trigger_name;
```

---

### 2.1 Truncar tablas que se van a restaurar

```sql
-- En Supabase SQL Editor
SET session_replication_role = replica;
TRUNCATE TABLE ttpn_booking_passengers;
TRUNCATE TABLE travel_counts;
TRUNCATE TABLE discrepancies;
TRUNCATE TABLE ttpn_bookings;
TRUNCATE TABLE vehicles CASCADE;
TRUNCATE TABLE gas_charges;
TRUNCATE TABLE gas_files CASCADE;
TRUNCATE TABLE gasoline_charges;
SET session_replication_role = DEFAULT;
```

### 2.2 Restaurar con triggers desactivados

```bash
SUPABASE_DIRECT="postgresql://postgres.REF:PASSWORD@db.REF.supabase.co:5432/postgres"
BACKUP_FILE="ruta/al/backup_heroku"

# Tablas sin conflicto de columnas
(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=employees -f - "$BACKUP_FILE" && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=vehicles -f - "$BACKUP_FILE" && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=travel_counts -f - "$BACKUP_FILE" && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

# ttpn_bookings — requiere renombrar columnas (Heroku usa created_by/updated_by)
(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=ttpn_bookings -f - "$BACKUP_FILE" \
   | sed 's/"created_by", "updated_by"/"created_by_id", "updated_by_id"/' && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"
```

### 2.3 Purga opcional (solo último trimestre para staging/testing)

Solo si no se quiere todo el histórico:

```sql
SET session_replication_role = replica;
DELETE FROM ttpn_booking_passengers
  WHERE ttpn_booking_id IN (SELECT id FROM ttpn_bookings WHERE created_at < '2025-10-01');
DELETE FROM ttpn_bookings  WHERE created_at < '2025-10-01';
DELETE FROM travel_counts  WHERE created_at < '2025-10-01';
DELETE FROM discrepancies  WHERE created_at < '2025-10-01';
SET session_replication_role = DEFAULT;

VACUUM FULL ttpn_bookings;
VACUUM FULL travel_counts;
```

---

## FASE 3 — MIGRACIONES Y BACKFILL

### 3.1 Ejecutar migraciones pendientes

Las migraciones se ejecutan automáticamente en Railway con cada push a `transform_to_api`.
Verificar que Railway corrió todas las migraciones sin error:

```bash
# En Railway console o via curl
curl https://kumi-admin-api-production.up.railway.app/api/v1/health
```

Si hay migraciones pendientes, forzar un redeploy en Railway.

### 3.2 Backfill `business_unit_id` — tablas grandes (CSV approach)

Para `ttpn_bookings` y `travel_counts` con cientos de miles de filas,
usar el enfoque CSV (ver sección completa en MIGRACION_DB.md):

```bash
# Opción rápida si la tabla ya fue restaurada sin business_unit_id
psql "$SUPABASE_DIRECT" <<'SQL'
SET session_replication_role = replica;
UPDATE ttpn_bookings SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
SQL

psql "$SUPABASE_DIRECT" <<'SQL'
SET session_replication_role = replica;
UPDATE travel_counts SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
SQL
```

Si hay timeout, usar el enfoque CSV completo (ver MIGRACION_DB.md → "ENFOQUE CSV PARA TABLAS GRANDES").

### 3.3 Backfill `business_unit_id` — tablas medianas y catálogos

Ejecutar **uno por uno** en Supabase SQL Editor:

```sql
SET search_path TO public;
UPDATE vehicles         SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_files        SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_charges      SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gasoline_charges SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

```sql
SET search_path TO public;
UPDATE suppliers                    SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_stations                 SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE coo_travel_requests          SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE coo_travel_employee_requests SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE payrolls                     SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE invoicings                   SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE scheduled_maintenances       SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE incidences                   SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE discrepancies                SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE labors                       SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE roles                        SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

### 3.4 Backfill de auditoría (`created_by_id` / `updated_by_id`)

```sql
-- Obtener ID del sadmin principal
SELECT id FROM users WHERE sadmin = true ORDER BY id LIMIT 1;
-- Ajustar el valor 1 al ID real si es diferente

UPDATE vehicles      SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE gas_files     SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE gas_charges   SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE ttpn_bookings SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE travel_counts SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE employees     SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE payrolls      SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
```

### 3.5 Backfill `jti` en usuarios (crítico — sin esto no pueden hacer login)

```sql
-- Verificar cuántos usuarios no tienen jti
SELECT COUNT(*) FROM users WHERE jti IS NULL;

-- Rellenar (gen_random_uuid está disponible en Supabase por defecto)
UPDATE users SET jti = gen_random_uuid()::text WHERE jti IS NULL;
```

### 3.6 Ajustar secuencias de IDs

**Siempre después de restaurar datos** — evita errores de PK duplicada en inserts nuevos:

```sql
SELECT setval('ttpn_bookings_id_seq',          (SELECT MAX(id) FROM ttpn_bookings));
SELECT setval('travel_counts_id_seq',           (SELECT MAX(id) FROM travel_counts));
SELECT setval('ttpn_booking_passengers_id_seq', (SELECT MAX(id) FROM ttpn_booking_passengers));
SELECT setval('vehicles_id_seq',                (SELECT MAX(id) FROM vehicles));
SELECT setval('gas_files_id_seq',               (SELECT MAX(id) FROM gas_files));
SELECT setval('gas_charges_id_seq',             (SELECT MAX(id) FROM gas_charges));
SELECT setval('gasoline_charges_id_seq',        (SELECT MAX(id) FROM gasoline_charges));
SELECT setval('payrolls_id_seq',                (SELECT MAX(id) FROM payrolls));
SELECT setval('invoicings_id_seq',              (SELECT MAX(id) FROM invoicings));
SELECT setval('employees_id_seq',               (SELECT MAX(id) FROM employees));
SELECT setval('users_id_seq',                   (SELECT MAX(id) FROM users));
```

---

## FASE 4 — TAREAS POST-MIGRACIÓN (vía API)

Ejecutar en orden. Cada curl puede tardar algunos segundos:

### 4.1 Rellenar tablas y asociar usuarios raíz

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "backfill_tables"}'
```

### 4.2 Separar nombres de concesionarios

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "concessionaires"}'
```

### 4.3 Inicializar módulos, privilegios y KumiSettings

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "setup_modules"}'
```

### 4.4 Recalcular claves de servicio (CLVs)

```bash
# Últimos 365 días — ajustar según necesidad
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/ttpn_bookings/backfill_clvs \
  -H "Content-Type: application/json" \
  -d '{"days": 365}'
```

### 4.5 O ejecutar todo en uno

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "all"}'
# Luego correr backfill_clvs por separado (acepta parámetros)
```

---

## FASE 5 — VERIFICACIÓN DE INTEGRIDAD

Ejecutar ANTES de abrir acceso a usuarios:

### 5.1 Verificar que no hay NULLs de business_unit_id

```sql
SELECT 'vehicles',                     COUNT(*) FROM vehicles                    WHERE business_unit_id IS NULL
UNION ALL SELECT 'gas_files',          COUNT(*) FROM gas_files                   WHERE business_unit_id IS NULL
UNION ALL SELECT 'gas_charges',        COUNT(*) FROM gas_charges                 WHERE business_unit_id IS NULL
UNION ALL SELECT 'gasoline_charges',   COUNT(*) FROM gasoline_charges            WHERE business_unit_id IS NULL
UNION ALL SELECT 'ttpn_bookings',      COUNT(*) FROM ttpn_bookings               WHERE business_unit_id IS NULL
UNION ALL SELECT 'travel_counts',      COUNT(*) FROM travel_counts               WHERE business_unit_id IS NULL
UNION ALL SELECT 'suppliers',          COUNT(*) FROM suppliers                   WHERE business_unit_id IS NULL
UNION ALL SELECT 'payrolls',           COUNT(*) FROM payrolls                    WHERE business_unit_id IS NULL
UNION ALL SELECT 'scheduled_maint',    COUNT(*) FROM scheduled_maintenances      WHERE business_unit_id IS NULL
UNION ALL SELECT 'labors',             COUNT(*) FROM labors                      WHERE business_unit_id IS NULL
UNION ALL SELECT 'roles',              COUNT(*) FROM roles                       WHERE business_unit_id IS NULL
UNION ALL SELECT 'users_sin_jti',      COUNT(*) FROM users                       WHERE jti IS NULL;
-- Todos deben dar 0
```

### 5.2 Verificar módulos y settings

```sql
SELECT COUNT(*) FROM privileges;       -- debe ser > 0
SELECT COUNT(*) FROM kumi_settings;    -- debe ser > 0
SELECT COUNT(*) FROM business_units;   -- debe tener al menos 1 registro
```

### 5.3 Verificar funciones PostgreSQL

```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
ORDER BY routine_name;
-- Deben aparecer: calcular_asignaciones_activas, cuadre_viajes, cuadre_gasolina,
--                 buscar_nomina_para_viaje, calcular_contadores
```

### 5.4 Verificar aislamiento de BU (seguridad crítica)

```sql
-- No debe haber labors de BU=2 visibles para usuarios de BU=1
SELECT id, nombre, business_unit_id FROM labors ORDER BY business_unit_id;

-- Verificar distribución de empleados por BU
SELECT business_unit_id, COUNT(*) FROM employees GROUP BY business_unit_id;

-- Verificar que todos los usuarios tienen su BU asignada
SELECT COUNT(*) FROM users WHERE business_unit_id IS NULL;
```

### 5.5 Test de login vía API

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "tu@email.com", "password": "password"}}'
# Debe devolver token JWT y datos del usuario con business_unit incluida
```

---

## FASE 6 — VARIABLES DE ENTORNO EN RAILWAY

Verificar que Railway tiene configuradas estas variables antes del cutover:

| Variable | Descripción | Fuente |
| -------- | ----------- | ------ |
| `DATABASE_URL` | Supabase connection string (pooler port 6543) | Supabase → Settings → Database |
| `SECRET_KEY_BASE` | Igual que en Heroku | `heroku config:get SECRET_KEY_BASE -a ttpngas` |
| `JWT_SECRET` | Igual que en Heroku si existe | Heroku config vars |
| `RAILS_ENV` | `production` | Manual |
| `RAILS_LOG_TO_STDOUT` | `true` | Manual |

> **Si `SECRET_KEY_BASE` cambia**, todos los JWT activos quedan inválidos y los usuarios deben re-loguearse.

---

## FASE 7 — CUTOVER DE TRÁFICO

### 7.1 Actualizar FE (Netlify) para apuntar a Railway

En `ttpn-frontend/.env.production` (o variables de Netlify):

```
VITE_API_URL=https://kumi-admin-api-production.up.railway.app
```

Hacer push y dejar que Netlify redeploye.

### 7.2 Actualizar PHP móvil para apuntar a Supabase

En `ttpn_php/db_config.php`, cambiar la cadena de conexión de Heroku Postgres a Supabase:

```php
// ANTES (Heroku)
$host = "ec2-xx-xx-xx-xx.compute-1.amazonaws.com";
$dbname = "nombre_db_heroku";

// DESPUÉS (Supabase) — usar puerto directo 5432, NO el pooler
$host = "db.REF.supabase.co";
$port = "5432";
$dbname = "postgres";
$user = "postgres.REF";
$password = "PASSWORD_SUPABASE";
```

> PHP necesita conexión directa (port 5432) — el pooler de Supabase (6543) no soporta
> todas las operaciones que usa pg_connect/pg_pconnect de PHP.

### 7.3 Verificar que PHP puede insertar en Supabase

Correr una inserción de prueba desde el dispositivo móvil y confirmar en Supabase:

```sql
-- En Supabase, verificar que el último travel_count tiene business_unit_id
SELECT id, ttpn_booking_id, business_unit_id, created_at
FROM travel_counts
ORDER BY created_at DESC
LIMIT 5;
```

---

## FASE 8 — ROLLBACK (si algo sale mal)

Si en cualquier punto del proceso algo falla gravemente:

### Opción A — Revertir tráfico a Heroku (< 5 min)

1. En Netlify: cambiar `VITE_API_URL` de regreso a la URL de Heroku
2. En PHP `db_config.php`: revertir la cadena de conexión a Heroku Postgres
3. Heroku sigue corriendo sin cambios — los datos originales están intactos

### Opción B — Heroku sigue siendo producción mientras se corrige

Heroku no se toca durante todo el proceso. Es el safety net.
Railway y Supabase son el nuevo stack — si fallan, simplemente no se hace el cutover.

---

## CHECKLIST FINAL DE CUTOVER

- [ ] **Fase 0** — PHP actualizado, staging verificado, backups descargados
- [ ] **Fase 1** — Backup de Heroku generado y validado
- [ ] **Fase 2** — Datos restaurados en Supabase (si aplica fresh restore)
- [ ] **Fase 3** — Migraciones aplicadas, todos los backfills corridos, secuencias ajustadas
- [ ] **Fase 4** — Tareas API corridas (backfill_tables, setup_modules, concessionaires, clvs)
- [ ] **Fase 5** — Verificación de integridad: cero NULLs, módulos OK, login funciona
- [ ] **Fase 6** — Variables de entorno Railway verificadas (especialmente SECRET_KEY_BASE)
- [ ] **Fase 7** — FE apuntando a Railway, PHP apuntando a Supabase, test de inserción PHP OK
- [ ] Notificar al equipo que el nuevo stack está activo
