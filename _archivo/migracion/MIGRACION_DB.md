# MIGRACION_DB — Gestión de base de datos Heroku → Railway/Supabase

Guía operativa para el proyecto Kumi V2. Railway y Supabase corren en **staging** con
datos reales importados de Heroku. Las migraciones se aplican de forma continua con cada
push a `transform_to_api`.

---

## CONTEXTO IMPORTANTE

```
Heroku (producción actual)
    └── Backup manual vía dashboard → archivo binario (80318abf-e5bf-4b77-...)

Railway (staging API)        Supabase (staging DB)
    └── Auto-deploy en push      └── Recibe migraciones de Railway
```

- Railway/Supabase **ya tienen los datos de Heroku** — no se parte desde cero
- Los `db:migrate` se ejecutan automáticamente en Railway al hacer push
- El riesgo real: agregar columnas con `NOT NULL` sin backfill previo → error en la migración

---

## CÓMO GENERAR UN BACKUP DE HEROKU

**No usar `heroku pg:dump` desde terminal** — la DB es demasiado grande y el comando truena por timeout.

### Proceso correcto:
1. Ir a [dashboard.heroku.com](https://dashboard.heroku.com) → app `kumi-admin-api`
2. Pestaña **Resources** → add-on **Heroku Postgres** → clic en el add-on
3. **Durability** → **Manual Backup** → esperar a que termine
4. En la lista de backups, clic en el ícono de descarga
5. Se descarga un archivo sin extensión tipo: `80318abf-e5bf-4b77-b2c8-fe94b1b10a29`
   — este es formato `pg_custom` compatible con `pg_restore`

### Restaurar ese backup en Supabase (cuando se requiera reset):
```bash
SUPABASE_URL="postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"

pg_restore \
  --verbose \
  --no-acl \
  --no-owner \
  --no-privileges \
  -d "$SUPABASE_URL" \
  80318abf-e5bf-4b77-b2c8-fe94b1b10a29
```

Si hay errores de extensiones (solo primera vez):
```sql
-- En Supabase SQL Editor antes de restaurar
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

---

## FLUJO NORMAL DE DESARROLLO

```
1. Escribir migración en local (columna nullable, sin UPDATE masivo)
2. Correr db:migrate en local → verificar que no truena
3. Push a transform_to_api → Railway corre db:migrate automáticamente
4. Correr el backfill en Supabase (ver sección por columna abajo)
5. Si la columna eventualmente necesita NOT NULL → agregar en migración posterior
```

### Regla de oro para migraciones:
- Agregar columnas **siempre como `nullable`** primero
- El backfill se hace **manualmente** en Supabase después del migrate
- Solo después de verificar que no hay NULLs, considerar agregar `NOT NULL` en otra migración

---

## ADVERTENCIAS CRÍTICAS PARA BACKFILL

### 1. Siempre usar `SET session_replication_role = replica`
Las tablas `ttpn_bookings` y `travel_counts` tienen triggers que se disparan en UPDATE
(por ejemplo `sp_tctb_update` que llama a `buscar_booking_id` para cada fila).
Sin desactivar los triggers, un UPDATE de 116K filas tarda horas en vez de segundos.

### 2. Correr cada tabla en su propia llamada SQL (no todo en un bloque)
Cuando psql recibe múltiples statements en un solo string `-c "stmt1; stmt2;"`, los ejecuta
en **una sola transacción implícita**. Si uno falla, revierte TODOS. Ejecutar cada UPDATE
por separado garantiza que lo que ya se commitió no se pierde.

### 3. El pooler de Supabase tiene `search_path` vacío
Las tablas están en `public` pero el pooler conecta sin search_path.
Toda operación SQL directa debe incluir `SET search_path TO public;` al inicio,
o calificar con `public.tabla`. El pg_restore funciona porque usa nombres
explícitos `"public"."tabla"` en los COPY statements.

### 4. `pg_restore` SÍ funciona via pooler (port 6543)
Supabase usa Supavisor (no PgBouncer clásico) — soporta COPY protocol.
No se necesita la conexión directa (port 5432/IPv4).

---

## RESTAURAR TABLAS ESPECÍFICAS DESDE BACKUP DE HEROKU

Para repoblar tablas que fueron purgadas (ttpn_bookings, travel_counts, etc.) sin
borrar los catálogos que ya están llenos:

### Paso 1 — Verificar qué columnas tiene el backup vs. la DB actual

El backup de Heroku puede tener nombres de columnas distintos a los de la migración.
Conocidos hasta ahora:

| Tabla | Heroku (backup) | DB actual | Acción |
|---|---|---|---|
| `ttpn_bookings` | `created_by`, `updated_by` | `created_by_id`, `updated_by_id` | sed rename |
| `travel_counts` | sin `clv_servicio`, `created_by_id`, `updated_by_id` | con esas columnas (nullable) | backfill después |

### Paso 2 — Truncar solo las tablas que se van a restaurar

```sql
SET session_replication_role = replica;
TRUNCATE TABLE ttpn_booking_passengers;
TRUNCATE TABLE travel_counts;
TRUNCATE TABLE discrepancies;
TRUNCATE TABLE ttpn_bookings;
SET session_replication_role = DEFAULT;
```

### Paso 3 — Restaurar con triggers desactivados

```bash
SUPABASE_DIRECT="postgresql://postgres.REF:PASSWORD@db.REF.supabase.co:5432/postgres"

# Tablas sin conflicto de columnas — restaurar directamente
(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=discrepancies -f - backup_file && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=ttpn_booking_passengers -f - backup_file && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=travel_counts -f - backup_file && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"

# ttpn_bookings — requiere renombrar columnas con sed
(echo "SET session_replication_role = replica;" && \
 pg_restore --data-only --table=ttpn_bookings -f - backup_file \
   | sed 's/"created_by", "updated_by"/"created_by_id", "updated_by_id"/' && \
 echo "SET session_replication_role = DEFAULT;") | psql "$SUPABASE_DIRECT"
```

### Paso 4 — Purga para dejar solo el último trimestre

```sql
SET session_replication_role = replica;

DELETE FROM ttpn_booking_passengers
WHERE ttpn_booking_id IN (SELECT id FROM ttpn_bookings WHERE created_at < '2025-10-01');

DELETE FROM ttpn_bookings   WHERE created_at < '2025-10-01';
DELETE FROM travel_counts   WHERE created_at < '2025-10-01';
DELETE FROM discrepancies   WHERE created_at < '2025-10-01';

SET session_replication_role = DEFAULT;

VACUUM FULL ttpn_booking_passengers;
VACUUM FULL ttpn_bookings;
VACUUM FULL travel_counts;
VACUUM FULL discrepancies;
```

### Paso 5 — Backfill por tabla (cada una por separado, con triggers desactivados)

```sql
-- CRÍTICO: cada statement debe ser una llamada separada en Supabase SQL Editor
-- NO pegar todo en un bloque — si uno falla, los anteriores se revierten

SET session_replication_role = replica;
UPDATE ttpn_bookings SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
```
```sql
SET session_replication_role = replica;
UPDATE travel_counts SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
```
```sql
SET session_replication_role = replica;
UPDATE travel_counts SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
SET session_replication_role = DEFAULT;
```
```sql
UPDATE discrepancies SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

### Paso 6 — Ajustar secuencias (SIEMPRE después de restaurar datos)

```sql
SELECT setval('ttpn_bookings_id_seq',          (SELECT MAX(id) FROM ttpn_bookings));
SELECT setval('travel_counts_id_seq',           (SELECT MAX(id) FROM travel_counts));
SELECT setval('discrepancies_id_seq',           (SELECT MAX(id) FROM discrepancies));
SELECT setval('ttpn_booking_passengers_id_seq', (SELECT MAX(id) FROM ttpn_booking_passengers));
```

---

## ENFOQUE CSV PARA TABLAS GRANDES (alternativa a UPDATE masivo)

Para tablas con millones de filas (`travel_counts`, `ttpn_bookings`) el UPDATE masivo genera
WAL logs por cada fila y puede tardar minutos o fallar por timeout en Supabase.
La alternativa es exportar como CSV, inyectar la columna, e importar con COPY.

### Cuándo usarlo

| Situación                                 | Enfoque recomendado                                       |
| ----------------------------------------- | --------------------------------------------------------- |
| Tabla < 50K filas                         | UPDATE directo con `session_replication_role = replica`   |
| Tabla 50K–500K filas                      | UPDATE con triggers desactivados (ya documentado arriba)  |
| Tabla > 500K filas o timeout en Supabase  | **CSV → COPY** (esta sección)                             |

### Paso 1 — Exportar la tabla desde Heroku como CSV

```bash
# Desde terminal local con acceso a Heroku
heroku pg:psql -a ttpngas -c "\COPY travel_counts TO '/tmp/travel_counts.csv' CSV HEADER;"

# O si la tabla es muy grande, solo las columnas necesarias + id para el JOIN
heroku pg:psql -a ttpngas -c "\COPY (SELECT id FROM travel_counts) TO '/tmp/tc_ids.csv' CSV HEADER;"
```

### Paso 2 — Agregar la columna business_unit_id al CSV con Python/AWK

```python
# add_bu_column.py — agrega business_unit_id=1 a cada fila
import csv, sys

in_file, out_file = sys.argv[1], sys.argv[2]
bu_id = sys.argv[3] if len(sys.argv) > 3 else "1"

with open(in_file) as fin, open(out_file, "w", newline="") as fout:
    reader = csv.DictReader(fin)
    fieldnames = reader.fieldnames + ["business_unit_id"]
    writer = csv.DictWriter(fout, fieldnames=fieldnames)
    writer.writeheader()
    for row in reader:
        row["business_unit_id"] = bu_id
        writer.writerow(row)

# Uso:
# python add_bu_column.py travel_counts.csv travel_counts_bu.csv 1
```

O con AWK si solo se necesita agregar una columna al final:

```bash
# Agrega "1" como última columna (incluyendo header)
awk -F',' 'NR==1 {print $0 ",business_unit_id"} NR>1 {print $0 ",1"}' \
  travel_counts.csv > travel_counts_bu.csv
```

### Paso 3 — Importar a Supabase con COPY (mucho más rápido que UPDATE)

```bash
SUPABASE_DIRECT="postgresql://postgres.REF:PASSWORD@db.REF.supabase.co:5432/postgres"

# Opción A: importar tabla completa (si se hizo TRUNCATE previo)
psql "$SUPABASE_DIRECT" -c \
  "\COPY travel_counts FROM '/tmp/travel_counts_bu.csv' CSV HEADER;"

# Opción B: solo actualizar la columna business_unit_id via tabla temporal
psql "$SUPABASE_DIRECT" <<'SQL'
SET session_replication_role = replica;

CREATE TEMP TABLE tc_bu_import (id bigint, business_unit_id integer);
\COPY tc_bu_import FROM '/tmp/tc_ids_bu.csv' CSV HEADER;

UPDATE travel_counts t
SET business_unit_id = s.business_unit_id
FROM tc_bu_import s
WHERE t.id = s.id AND t.business_unit_id IS NULL;

DROP TABLE tc_bu_import;
SET session_replication_role = DEFAULT;
SQL
```

### Paso 4 — Verificar y ajustar secuencias

```sql
-- Siempre después de un COPY masivo
SELECT setval('travel_counts_id_seq',   (SELECT MAX(id) FROM travel_counts));
SELECT setval('ttpn_bookings_id_seq',   (SELECT MAX(id) FROM ttpn_bookings));

-- Verificar que no quedaron NULLs
SELECT COUNT(*) FROM travel_counts WHERE business_unit_id IS NULL;
SELECT COUNT(*) FROM ttpn_bookings WHERE business_unit_id IS NULL;
```

### Nota de rendimiento

| Método                  | 500K filas (estimado)  |
| ----------------------- | ---------------------- |
| UPDATE directo          | 5–15 min, alto WAL     |
| UPDATE con triggers off | 1–3 min                |
| COPY desde CSV          | < 30 seg               |

---

## BACKFILL POR COLUMNA — Ejecutar en Supabase SQL Editor

### `business_unit_id` en tablas operativas grandes
_(Migración `20260422185129` — vehicles, gas_files, gas_charges, gasoline_charges, ttpn_bookings, travel_counts)_

```sql
-- Verificar el ID de la primera BU
SELECT id FROM business_units ORDER BY id LIMIT 1;
-- Resultado esperado: 1
```

Ejecutar **uno por uno** en SQL Editor (cada bloque es una ejecución separada):

```sql
SET session_replication_role = replica;
UPDATE ttpn_bookings SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
```
```sql
SET session_replication_role = replica;
UPDATE travel_counts SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SET session_replication_role = DEFAULT;
```
```sql
UPDATE vehicles         SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_files        SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_charges      SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gasoline_charges SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

Verificar (todos deben dar 0):
```sql
SELECT 'vehicles',         COUNT(*) FROM vehicles         WHERE business_unit_id IS NULL
UNION ALL
SELECT 'gas_files',        COUNT(*) FROM gas_files        WHERE business_unit_id IS NULL
UNION ALL
SELECT 'gas_charges',      COUNT(*) FROM gas_charges      WHERE business_unit_id IS NULL
UNION ALL
SELECT 'gasoline_charges', COUNT(*) FROM gasoline_charges WHERE business_unit_id IS NULL
UNION ALL
SELECT 'ttpn_bookings',    COUNT(*) FROM ttpn_bookings    WHERE business_unit_id IS NULL
UNION ALL
SELECT 'travel_counts',    COUNT(*) FROM travel_counts    WHERE business_unit_id IS NULL;
```

---

### `business_unit_id` en tablas secundarias y catálogos
_(Migraciones `20260422185201`, `20260422182302` — todas las tablas operativas restantes)_

Estas tablas **no tienen triggers agresivos**, se pueden backfillear en una sola pasada:

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

-- Verificar
SELECT 'suppliers',                    COUNT(*) FROM suppliers                    WHERE business_unit_id IS NULL
UNION ALL
SELECT 'gas_stations',                 COUNT(*) FROM gas_stations                 WHERE business_unit_id IS NULL
UNION ALL
SELECT 'coo_travel_requests',          COUNT(*) FROM coo_travel_requests          WHERE business_unit_id IS NULL
UNION ALL
SELECT 'coo_travel_employee_requests', COUNT(*) FROM coo_travel_employee_requests WHERE business_unit_id IS NULL
UNION ALL
SELECT 'payrolls',                     COUNT(*) FROM payrolls                     WHERE business_unit_id IS NULL
UNION ALL
SELECT 'invoicings',                   COUNT(*) FROM invoicings                   WHERE business_unit_id IS NULL
UNION ALL
SELECT 'scheduled_maintenances',       COUNT(*) FROM scheduled_maintenances       WHERE business_unit_id IS NULL
UNION ALL
SELECT 'incidences',                   COUNT(*) FROM incidences                   WHERE business_unit_id IS NULL
UNION ALL
SELECT 'discrepancies',                COUNT(*) FROM discrepancies                WHERE business_unit_id IS NULL;
```

---

### `business_unit_id` en labors (puestos)
_(Migración `20260422182302`)_

```sql
UPDATE labors SET business_unit_id = 1 WHERE business_unit_id IS NULL;

-- Verificar distribución
SELECT business_unit_id, COUNT(*) FROM labors GROUP BY business_unit_id;
```

---

### `business_unit_id` en roles
_(Migración `20260311172720`)_

```sql
UPDATE roles SET business_unit_id = 1 WHERE business_unit_id IS NULL;
SELECT business_unit_id, COUNT(*) FROM roles GROUP BY business_unit_id;
```

---

### `jti` en users (revocación JWT)
_(Migración `20260226000000`)_

**Crítico — usuarios sin jti no pueden autenticarse.**

```sql
-- Verificar primero
SELECT COUNT(*) FROM users WHERE jti IS NULL;

-- Si hay NULLs (requiere gen_random_uuid disponible en Supabase):
UPDATE users SET jti = gen_random_uuid()::text WHERE jti IS NULL;
```

---

### `created_by_id` / `updated_by_id` en tablas de auditoría
_(Migración `20251218203315`)_

```sql
-- Obtener ID del usuario administrador principal
SELECT id FROM users WHERE sadmin = true ORDER BY id LIMIT 1;
-- Resultado esperado: 1

-- Backfill (ajustar el valor 1 al ID real del sadmin)
UPDATE vehicles       SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE gas_files      SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE gas_charges    SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE ttpn_bookings  SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE travel_counts  SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE employees      SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
UPDATE payrolls       SET created_by_id = 1, updated_by_id = 1 WHERE created_by_id IS NULL;
```

---

## VERIFICACIÓN GENERAL POST-MIGRATE

Correr después de cada `db:migrate` en Railway:

```sql
-- 1. Secuencias de IDs (evitar PK duplicados si se importaron datos)
SELECT setval('ttpn_bookings_id_seq',   (SELECT MAX(id) FROM ttpn_bookings));
SELECT setval('travel_counts_id_seq',   (SELECT MAX(id) FROM travel_counts));
SELECT setval('vehicles_id_seq',        (SELECT MAX(id) FROM vehicles));
SELECT setval('gas_charges_id_seq',     (SELECT MAX(id) FROM gas_charges));
SELECT setval('gasoline_charges_id_seq',(SELECT MAX(id) FROM gasoline_charges));
SELECT setval('payrolls_id_seq',        (SELECT MAX(id) FROM payrolls));
SELECT setval('invoicings_id_seq',      (SELECT MAX(id) FROM invoicings));

-- 2. Funciones PostgreSQL (verificar que existen)
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- 3. Privileges y KumiSettings inicializados
SELECT COUNT(*) FROM privileges;
SELECT business_unit_id, COUNT(*) FROM kumi_settings GROUP BY business_unit_id;
```

Si los privileges o kumi_settings están vacíos:
```bash
# Desde Railway console o curl al API
curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "setup_modules"}'
```

---

## NOTAS IMPORTANTES

- **`secret_key_base`**: mantener igual o todos los JWT activos quedan inválidos
- **Backup de Heroku**: siempre generar desde el dashboard — `heroku pg:dump` desde terminal truena por el tamaño de la DB
- **Staging actual**: Railway (`kumi-api.up.railway.app`) + Supabase — ambiente completamente funcional para pruebas
