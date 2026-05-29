# Pasos y Tareas Tras la Migración a Producción (Kumi V2)

Este documento es una lista de verificación (checklist) crítica para ejecutar inmediatamente después de restaurar o migrar la Base de Datos a producción. Durante el desarrollo de la rama `transform_to_api`, construimos tablas y dependencias obligatorias (Business Units, Control de Privilegios y Auditoría de usuarios). Por tanto, la Base de Datos vieja fallará ante el nuevo backend si no "rellenamos" o "purgamos" estas dependencias huérfanas o valores nulos introducidos.

Para que no batalles con accesos a la Nube, **hemos creado 4 comandos remotos `cURL`** que puedes copiar y pegar de forma independiente desde la terminal de tu computadora local (VSCode/Mac) después de subir el código y migrar la base. Tu servidor de Railway los ejecutará automáticamente.

> ⚠️ **Autenticación obligatoria.** Todos los cURL exigen el header
> `X-Maintenance-Token: <valor>` donde `<valor>` debe coincidir **exactamente**
> con la env `MAINTENANCE_TOKEN` configurada en Railway. Sin la env (o con header
> distinto), el endpoint responde 401/503. Antes de empezar, exporta el token en
> tu shell local: `export MAINT_TOKEN="<el-valor-de-Railway>"` — los ejemplos lo
> usan con `-H "X-Maintenance-Token: $MAINT_TOKEN"`.

---

## Orden de ejecución sugerido para el cutover (lunes 2-jun-2026)

Hacer en este orden estricto:

1. **Restaurar respaldo Heroku** sobre Supabase prod.
2. **Paso 5.bis** — `railway run -- bundle exec rails db:migrate` (aplica las migrations nuevas, incluidos los 3 fixes del 2026-05-29: `20260529101804` timezone trigger, `20260529112617` client_id en trigger, `20260529113725` proximidad temporal en funciones PG).
3. **Paso 6 (todo-en-uno)** — `task: "all"` para correr 1, 2, 3 en cadena (backfill BU, concesionarios, módulos).
4. **Paso 4** — `backfill_clvs` cURL para `clv_servicio_completa` de TBs.
5. **Paso 4.bis** — `cuadre:fill_clvs DAYS=60 REBUILD=true` (realineación estructural de CLVs legacy).
6. **Paso 4.ter** — SQL UPDATE quirúrgico para hora local en TCs (el rake REBUILD no detecta offset de timezone).
7. **Paso 4.qua** — SQL retroactivo cuadre TB ↔ TC (cuadra los huérfanos del rango).
8. **Paso 5** — `reset_sequences` cURL.
9. **Verificaciones finales** (ver sección final).

Tras estos pasos, el sistema queda listo para captura operativa normal. Los nuevos viajes (TB-first vía Rails o TC-first vía PHP) se cuadran automáticamente en runtime (job `Cuadre::TbMatchJob` + triggers PG).

> **Recomendación cron**: agregar el SQL del paso 4.qua a `sidekiq-cron` corriendo cada lunes 04:00 — reconcilia huérfanos que pudieran quedar por Sidekiq caído o redeploy. Idempotente.

---

## 1. Asignación de Usuarios Raíz y Unidades de Negocio (Tablas Nuevas)

Al dividir la API, se agregaron `business_unit_id`, `created_by_id` y `updated_by_id` a decenas de tablas como validaciones estrictas de trazabilidad y multi-tenancy. La base vieja los tendrá nulos (`nil`). Este proceso asocia los registros viejos a tu Unidad de Negocio Principal y al Usuario Administrador raíz en todos los catálogos.

> **Tablas operativas cubiertas** (`db:post_migration_backfill`): `clients`,
> `vehicles`, `vehicle_asignations`, `driver_requests`, `service_appointments`,
> `ttpn_bookings`, `travel_counts`, `gas_charges`, `gas_files`,
> `gasoline_charges`, `employees`, `concessionaires`, `invoice_types`, `labors`.
> Si una fila de alguna de esas tablas queda con `business_unit_id` NULL, el
> filtro multitenant la excluye en TODOS los reportes y dashboards (cuadre de
> servicios, gasolina, viajes). **Si ves números en cero después del cutover,
> casi siempre falta correr este paso.**

**Ejecutar para rellenar (cURL):**

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-H "X-Maintenance-Token: $MAINT_TOKEN" \
-d '{"task": "backfill_tables"}'
```

---

## 2. Separador de Concesionarios (Campos Apellidos Nuevos)

Antes, el catálogo de concesionarios usaba un solo campo `nombre`. Ahora emplea `a_paterno` y `a_materno`. Este analizador de texto barre los cientos de registros y los fragmenta automáticamente depositándolos en sus columnas correctas.

**Ejecutar para fragmentar (cURL):**

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-H "X-Maintenance-Token: $MAINT_TOKEN" \
-d '{"task": "concessionaires"}'
```

_(Si prefieres hacerlo dentro de Railway: `bin/rails concessionaires:split_names`)_

---

## 3. Inicializar Módulos de Operaciones y Privilegios (Rol Administrativo)

Al crearse las barreras de autenticación nuevas, se introdujo el concepto de "Privilegios Dinámicos" y Configuraciones Globales de Nómina (`KumiSettings`). Esta rutina inyecta a la Base de Datos los permisos esenciales para cada ventana web creada recientemente y le otorga acceso universal a tu Rol de Sistemas / Administrador para que no te bloquees fuera de las nuevas pantallas.

**Ejecutar configuración (cURL):**

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-H "X-Maintenance-Token: $MAINT_TOKEN" \
-d '{"task": "setup_modules"}'
```

---

## 4. Recálculo Automático de Llaves de Servicio (CLVs del Excel)

Modificamos la forma en que el Backend construye las llaves largas y llaves de cuadre masivo (`clv_servicio_completa`) conectándolas por guiones con hasta con segundos de precisión. Los viajes importados viejos no las tienen. Este escáner revisa los últimos días que indiques y estampa el código en la Base a quienes carezcan del mismo.

**Ejecutar para sanar inventario (cURL):**

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/ttpn_bookings/backfill_clvs \
-H "Content-Type: application/json" \
-d '{"days": 30}'
```

_(Puedes correrlo varias veces y no duplicará datos. Si quieres cambiar el barrido histórico masivo de tu empresa pon `"days": 365` o el número que prefieras)._

---

## 4.bis ⚠️ OBLIGATORIO tras cutover — Rellenar/realinear `clv_servicio` en TB y TC

El paso 4 anterior solo cubre `clv_servicio_completa` de `ttpn_bookings`. Falta
**`clv_servicio`** (clave de match Nivel 1) en `ttpn_bookings` Y `travel_counts`
para que el **Cuadre de Servicios** funcione correctamente, mostrando los pares
TB↔TC con CLVs comparables.

Hay dos escenarios separados que cubre el mismo rake:

| Modo | Cuándo | Comportamiento |
| --- | --- | --- |
| **Backfill** (default) | Datos legacy con `clv_servicio = NULL` | Solo rellena filas NULL — no toca lo que ya tiene valor |
| **REBUILD=true** | Datos legacy con **formato viejo** (ej. `72026-05-0416:15163` sin guiones) | Reescribe TODA fila cuyo CLV no cumpla el regex canónico, deja iguales las ya canónicas |

**Síntoma si no se corre el backfill**: en el drilldown del cuadre los TBs/TCs
salen con CLV `—`. El match operativo funciona via FK
`travel_count_id`/`ttpn_booking_id`, pero el usuario no puede verificar
visualmente el nivel del match.

**Síntoma si NO se corre REBUILD post-cutover de PHP**: en el drilldown los CLV
TB salen con formato ilegible sin separadores (`72026-05-0416:15163`) y los CLV
TC con formato canónico (`7-2026-05-04-09:15:00-1-1-3`). El match Nivel 1
(`clv_servicio` exacto) NUNCA dispara para los legacy — siempre cae a Nivel 2
(ventana de tiempo, ~10× más lento). Se ve como descuadres "fantasma" donde TB y
TC deberían pegarse pero el sistema no los reconoce como mismo viaje hasta
correr el cuadre retroactivo (paso 4.ter).

**Por qué pasa**: el `before_validation :generar_clv_servicio` solo dispara al
guardar el registro vía Rails. Datos legacy importados con `update_columns`,
via SQL crudo, o que vienen del CRUD PHP no pasan por el callback.

**Ejecutar (railway run)**:

```bash
# Backfill simple — solo rellena NULL (default últimos 30 días)
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs

# Backfill con más histórico
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=90

# REBUILD — reescribe legacy a formato canónico (obligatorio post-cutover de PHP)
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=60 REBUILD=true
```

Idempotente en ambos modos:

- Sin `REBUILD`: solo toca filas con `clv_servicio IS NULL`.
- Con `REBUILD=true`: detecta el regex canónico
  `\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+` y deja intactas las que
  ya cumplen.

Usa `update_columns` así que NO dispara callbacks del `TtpnCuadreService` ni de
auditoría — el cuadre se reconstruye después en paso 4.ter.

Verificación rápida después de correrlo:

```sql
-- Backfill: ambos counts deben acercarse a 0
SELECT COUNT(*) FROM ttpn_bookings
WHERE clv_servicio IS NULL AND fecha >= CURRENT_DATE - INTERVAL '30 days';

SELECT COUNT(*) FROM travel_counts
WHERE clv_servicio IS NULL AND fecha >= CURRENT_DATE - INTERVAL '30 days';

-- REBUILD: ambos counts deben ser 0 (no quedan formatos legacy)
SELECT COUNT(*) FROM ttpn_bookings
WHERE fecha >= CURRENT_DATE - INTERVAL '60 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';

SELECT COUNT(*) FROM travel_counts
WHERE fecha >= CURRENT_DATE - INTERVAL '60 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';
```

> Nota: los registros nuevos creados a través de los flujos normales del API
> (no por SQL directo ni importación masiva sin `save`) tendrán `clv_servicio`
> automáticamente en formato canónico. Este rake es solo para datos legacy del
> cutover y para backfills posteriores donde alguien haya saltado el callback.

---

## 4.ter ⚠️ OBLIGATORIO tras cutover — Realinear hora local en `clv_servicio` de TCs

**Por qué este paso adicional al 4.bis**: el rake REBUILD valida con un regex
**estructural** (`HH:MM:SS` cumple igual sea hora UTC o local). Los TCs del
respaldo Heroku tienen `clv_servicio` con **hora UTC** (porque el flujo PHP
legacy no convertía timezone). El rake los salta reportando "0 realineados"
porque ya cumplen el regex.

**Síntoma si no se corre**: en el drilldown, los CLVs de TBs y TCs del mismo
viaje difieren ~7h (TBs en local Chihuahua, TCs en UTC). El match Nivel 2
(CLV exacto, usado para desempatar dobles) **nunca** dispara cross-source.
Hallazgo confirmado 2026-05-29 con cross-check query.

**Ejecutar (railway run psql o vía SQL Editor de Supabase)**:

```sql
UPDATE travel_counts tc
SET clv_servicio = cbo.client_id::text || '-' ||
                   tc.fecha::text || '-' ||
                   to_char(
                     (('2000-01-01'::date + tc.hora) AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chihuahua')::time,
                     'HH24:MI:SS'
                   ) || '-' ||
                   tc.ttpn_service_type_id::text || '-' ||
                   tc.ttpn_foreign_destiny_id::text || '-' ||
                   tc.vehicle_id::text,
    updated_at = NOW()
FROM client_branch_offices cbo
WHERE cbo.id = tc.client_branch_office_id
  AND tc.fecha >= CURRENT_DATE - INTERVAL '15 days'
  AND tc.client_branch_office_id IS NOT NULL
  AND tc.hora IS NOT NULL;
```

Idempotente — aplica la misma fórmula del trigger fixeado (migration
`20260529101804`). Si el CLV ya está en hora local, produce el mismo valor.

**Verificación cross-source** (la mayoría de pares ya cuadrados debe mostrar
`clv_coinciden=true`; los que no coinciden son diferencias reales de timing
entre la hora del TB programado y la hora que el chofer capturó):

```sql
SELECT tb.id AS tb_id, tb.clv_servicio AS tb_clv,
       tc.id AS tc_id, tc.clv_servicio AS tc_clv,
       (tb.clv_servicio = tc.clv_servicio) AS clv_coinciden,
       EXTRACT(EPOCH FROM ((tc.fecha + tc.hora) - (tb.fecha + tb.hora))) AS diff_seg
FROM ttpn_bookings tb
JOIN travel_counts tc ON tc.id = tb.travel_count_id
WHERE tb.viaje_encontrado = true
  AND tb.created_at > NOW() - INTERVAL '7 days'
ORDER BY tb.created_at DESC LIMIT 10;
```

---

## 4.qua ⚠️ OPCIONAL pero recomendado tras cutover — SQL retroactivo del cuadre TB ↔ TC

**Por qué**: el respaldo Heroku trae datos sin `viaje_encontrado` poblado para
viajes del rango previo (TBs y TCs huérfanos). Los flujos en runtime
(callback Rails `Cuadre::TbMatchJob` para TB-first, triggers PG para TC-first)
solo aplican a registros **nuevos** o **modificados** post-cutover. Los
históricos quedan sin pegar.

**Solución**: un solo SQL que pega retroactivamente todos los pares
candidatos del rango usando los campos clave + ventana ±15 min. Idempotente,
atómico (un statement). Ver §1.A.2 del plan `~/.claude/plans/revisa-esto-para-ver-smooth-dusk.md`.

**Ejecutar (SQL Editor de Supabase)** — ajustar el rango de fechas según necesidad:

```sql
WITH candidates AS (
  SELECT
    tb.id AS tb_id, tc.id AS tc_id,
    tb.vehicle_id, tb.employee_id, tb.ttpn_service_type_id,
    tb.client_id, ts.ttpn_foreign_destiny_id,
    tb.fecha + tb.hora AS tb_dt,
    tc.fecha + tc.hora AS tc_dt
  FROM ttpn_bookings tb
  JOIN ttpn_services ts ON ts.id = tb.ttpn_service_id
  JOIN client_branch_offices cbo ON cbo.client_id = tb.client_id
  JOIN travel_counts tc ON
    tc.vehicle_id = tb.vehicle_id
    AND tc.employee_id = tb.employee_id
    AND tc.ttpn_service_type_id = tb.ttpn_service_type_id
    AND tc.client_branch_office_id = cbo.id
    AND tc.ttpn_foreign_destiny_id = ts.ttpn_foreign_destiny_id
    AND ABS(EXTRACT(EPOCH FROM (tc.fecha + tc.hora) - (tb.fecha + tb.hora))) <= 900
  WHERE tb.fecha BETWEEN CURRENT_DATE - INTERVAL '15 days' AND CURRENT_DATE + INTERVAL '5 days'
    AND tb.status = true AND tc.status = true
    AND (tb.viaje_encontrado IS NULL OR tb.viaje_encontrado = false)
    AND (tc.viaje_encontrado IS NULL OR tc.viaje_encontrado = false)
),
tb_pos AS (
  SELECT DISTINCT tb_id, vehicle_id, employee_id, ttpn_service_type_id,
                  client_id, ttpn_foreign_destiny_id, tb_dt,
                  ROW_NUMBER() OVER (
                    PARTITION BY vehicle_id, employee_id, ttpn_service_type_id,
                                 client_id, ttpn_foreign_destiny_id
                    ORDER BY tb_dt, tb_id
                  ) AS pos
  FROM candidates
),
tc_pos AS (
  SELECT DISTINCT tc_id, vehicle_id, employee_id, ttpn_service_type_id,
                  client_id, ttpn_foreign_destiny_id, tc_dt,
                  ROW_NUMBER() OVER (
                    PARTITION BY vehicle_id, employee_id, ttpn_service_type_id,
                                 client_id, ttpn_foreign_destiny_id
                    ORDER BY tc_dt, tc_id
                  ) AS pos
  FROM candidates
),
matches AS (
  SELECT tbp.tb_id, tcp.tc_id
  FROM tb_pos tbp
  JOIN tc_pos tcp USING (vehicle_id, employee_id, ttpn_service_type_id,
                         client_id, ttpn_foreign_destiny_id, pos)
),
upd_tb AS (
  UPDATE ttpn_bookings tb
  SET viaje_encontrado = true, travel_count_id = m.tc_id, updated_at = NOW()
  FROM matches m WHERE tb.id = m.tb_id
  RETURNING tb.id
),
upd_tc AS (
  UPDATE travel_counts tc
  SET viaje_encontrado = true, ttpn_booking_id = m.tb_id, updated_at = NOW()
  FROM matches m WHERE tc.id = m.tc_id
  RETURNING tc.id
)
SELECT
  (SELECT COUNT(*) FROM matches)   AS pares_identificados,
  (SELECT COUNT(*) FROM upd_tb)    AS tbs_actualizados,
  (SELECT COUNT(*) FROM upd_tc)    AS tcs_actualizados;
```

> Si el rango devuelve >5min de espera o timeout en Supabase UI: dividir
> por semanas (`BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`) y correr cada
> chunk. Idempotente.

**Recomendación operativa**: agregar a cron de Sidekiq cada lunes pre-nómina
para reconciliar huérfanos que pudieran quedar por Sidekiq caído, redeploy
durante operación, etc.

---

## 5. ⚠️ OBLIGATORIO — Resincronizar Secuencias de PK (tras CADA importación)

Cuando la base se restaura/importa con `id` **explícito** (volcado de Heroku,
`COPY`, delta de cutover), las **secuencias de PK quedan atrasadas** respecto al
`MAX(id)`. El backend no lo nota hasta que intentas **crear** un registro nuevo:
PostgreSQL asigna un `id` que ya existe →
`PG::UniqueViolation: duplicate key value violates "<tabla>_pkey"` → **500**.
(Le pasó a `vehicle_asignations` el 2026-05-27.)

**Hay que correr esto SIEMPRE, como ÚLTIMO paso, después de cualquier carga de
datos** (y va incluido en el `all` del punto 6):

**Ejecutar (cURL):**

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-H "X-Maintenance-Token: $MAINT_TOKEN" \
-d '{"task": "reset_sequences"}'
```

_(Dentro de Railway: `bin/rails db:reset_sequences`. Es idempotente y seguro;
solo ajusta cada secuencia a `MAX(id)`. Corre **al final**, después de los
backfills.)_

> Nota: la migración `SyncPkSequencesForward` también sincroniza las secuencias
> (forward-only) una vez en el deploy, pero un **import posterior** las vuelve a
> desincronizar — por eso este paso es obligatorio tras cada carga de datos.

---

## 5.bis ⚠️ OBLIGATORIO tras restore de respaldo — re-ejecutar `db:migrate`

Si el cutover trae un `pg_restore --clean --if-exists`, el dump del legacy
**sobreescribe `schema_migrations` con las migraciones del legacy** y restaura
las tablas con la estructura vieja (p.ej. `employees.password` en vez de
`employees.token_firebase`). Las migraciones que renombran/recolumna columnas
quedan "pendientes" desde el punto de vista del nuevo Rails.

**Después del restore — antes de los cURL de arriba — corre `db:migrate`** para
que se apliquen las migraciones nuevas (rename de `password → token_firebase`,
forward-only de PK sequences, etc.). El runbook lo asegura reiniciando el
servicio (`bin/rails db:prepare` corre en el startup del contenedor), pero si
no reinicias, dispáralo a mano:

- Dentro de Railway: `bin/rails db:migrate`
- O reinicia el servicio para que el CMD del Dockerfile ejecute `db:prepare`.

Las migraciones que aplican rename/transform son **idempotentes** (verifican
`column_exists?` antes de actuar), así que es seguro re-correr aunque el dump
sea de una versión más reciente.

---

## 6. ¡Ahorrar Tiempo! 👉 Comando TODO-EN-UNO (Master)

Si tu base recién fue migrada de volverse a volcar intacta y necesitas purgar _todo el texto_, _rellenar tablas_, y _crear privilegios_ al mismo tiempo sin correr uno por uno los puntos 1, 2 y 3, puedes simplemente dispararlos en cadena:

```bash
curl -X POST https://kumi-admin-api-production.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-H "X-Maintenance-Token: $MAINT_TOKEN" \
-d '{"task": "all"}'
```

_(Nota: El paso de los viajes #4 CLVs se corre por separado pues ese acepta parámetros únicos dependiente los días)._

---

### Detalles Adicionales para Validar Tras estas Tareas

1. **Revisar Lista Negra (Blacklists):**
   Los clientes creados exclusivamente como `black_list = true` (del match con Android/Firebase) utilizarán los nuevos campos `full_name` rápido en lugar de atarte un catálogo pesado de flotillas. En API V1 estos retornos serán simplificados (Ver `documentacion/CAMBIOS_API_ANDROID.md` para detalle técnico de este rubro).

2. **Origen de Viajes:**
   Al descargar reportes, `creation_method` dirá cómo nacieron: `"manual"`, `"imported"` o `"cloned"`.

3. **Purga de Fallas (Reinicio Cargas Excel):**
   Si la primera camada de pasajes da error visual, recuerda que la Base pura respeta el archivo. Borra desde el Frontend esos viajes de prueba usando el check de selección múltiple, y tras re-importar, la herramienta `QPs` (passenger_qty) respetará a hierro los conteos físicos de Excel reales.
