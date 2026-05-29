# Cuadre TB ↔ TC — Documento Maestro

**Última actualización:** 2026-05-29
**Estado:** Fase 1 completa (A + B), refactor service + fix timezone PG en deploy. Pruebas E2E pendientes.

> Este documento es la **única fuente de verdad** sobre el cuadre. Cualquier modificación al flujo debe actualizar este archivo el mismo día. Los docs `PROCESO_CUADRE_AUTOMATICO.md` e `IMPLEMENTACION_CLV_SERVICIO.md` quedan como referencia histórica y deben apuntar aquí.

---

## 1. Qué es el cuadre

El cuadre es el proceso que enlaza un `TtpnBooking` (TB — viaje programado por capturista en web) con su `TravelCount` (TC — viaje ejecutado por chofer en app móvil) cuando ambos representan el mismo evento de transporte.

Cuando cuadran:

- `tb.viaje_encontrado = true` y `tb.travel_count_id = tc.id`.
- `tc.viaje_encontrado = true` y `tc.ttpn_booking_id = tb.id`.

Operativamente, esto permite:

- Confirmar que un viaje programado realmente se realizó.
- Cálculo de nómina por viaje completado.
- Identificar PNC (Programado No Capturado) y CNP (Capturado No Programado).

---

## 2. Arquitectura — flujo bidireccional

### 2.1 Lado TB (capturista programa via Rails API)

1. Frontend POST `/api/v1/ttpn_bookings` con datos del viaje.
2. Modelo `TtpnBooking` corre callbacks:
   - `before_validation :extra_campos` — genera `clv_servicio` y `clv_servicio_completa`. Si MATCH_FIELDS cambió en update, marca `@viaje_anterior` para desvincular.
   - `validate :sin_duplicado_en_15_minutos, on: :create` — bloquea TB con mismo `client_id + fecha + vehicle_id` a `<900s` (estricto). Aplica a `creation_method='cloned'`. NO aplica a `'automatico'`.
   - `before_create :set_default_statuses` — defaults (`status=true`, `coo_travel_request_id=0`, `viaje_encontrado=false`). **NO corre cuadre.**
   - `before_update :clear_stale_tc_link` — desvincula `@viaje_anterior` si MATCH_FIELDS cambió.
   - `after_commit :enqueue_cuadre_job, on: [:create, :update], if: :cuadre_needs_recompute?` — encola job async.
3. **`Cuadre::TbMatchJob`** corre en Sidekiq cola `default`:
   - Llama `TtpnCuadreService#buscar_travel(booking)`.
   - Si encuentra TC: `service.vincular(booking, travel)` + `booking.update_columns(viaje_encontrado: true, travel_count_id: travel.id)`.
   - Si `user_id` presente, broadcast `tb_cuadre_done` al `JobStatusChannel`.

### 2.2 Lado TC (chofer captura via app móvil → PHP/Heroku → Supabase)

1. App móvil POST `https://pacific-river-53404.herokuapp.com/Gasto_INSERT_TRAVEL_COUNTS.php` con datos del TC.
2. PHP ejecuta `INSERT INTO travel_counts ...` con `id` explícito (sin pasar `clv_servicio`).
3. **Trigger Postgres `sp_tctb_insert`** (BEFORE INSERT) ejecuta:
   - Genera `clv_servicio` en formato canónico, **convirtiendo `NEW.hora` de UTC a America/Chihuahua** (migration `20260529101804`).
   - Rellena `created_by_id=1` y `updated_by_id=1` si vienen NULL.
   - Llama función PG `buscar_booking(...)` → setea `viaje_encontrado`.
   - Llama función PG `buscar_booking_id(...)` → setea `ttpn_booking_id`.
4. Después del INSERT, PHP corre `UPDATE discrepancies SET status=false WHERE kpi='pnc' AND record_id=tc.ttpn_booking_id` para desactivar el PNC reportado.

### 2.3 Lado TC vía Rails API (poco usado, solo para correcciones administrativas)

1. POST `/api/v1/travel_counts` con datos.
2. Modelo `TravelCount`:
   - `before_validation :generar_clv_servicio` — genera en formato canónico, hora local Chihuahua.
   - `before_create :verificar_id` — setea `payroll_id`.
3. Trigger PG `sp_tctb_insert` **NO genera CLV** porque ya viene poblado (condicional `IF NEW.clv_servicio IS NULL`). Sí corre el resto.

---

## 3. `TtpnCuadreService` — los dos niveles

**Refactor 2026-05-29**: orden invertido respecto a la versión original.

### 3.1 Nivel 1 — campos base + ventana ±15 min

Query ActiveRecord directo en `app/services/ttpn_cuadre_service.rb`:

```ruby
TravelCount
  .joins(:client_branch_office)
  .where(vehicle_id: ..., employee_id: ..., ttpn_service_type_id: ...,
         ttpn_foreign_destiny_id: ..., client_branch_offices: { client_id: ... },
         status: true, viaje_encontrado: [false, nil])
  .where('ABS(EXTRACT(EPOCH FROM ((travel_counts.fecha + travel_counts.hora) - ?::timestamp))) <= 900', booking_dt)
  .to_a
  .sort_by { |tc| time_distance(...) }
```

Si devuelve **1 candidato** → ese gana.

### 3.2 Nivel 2 — CLV exacto desempata dobles

Si Nivel 1 devuelve **>1 candidatos**:

```ruby
candidates.find { |c| c.clv_servicio == booking.clv_servicio } || candidates.first
```

Caso de uso: viajes dobles del mismo vehículo+empleado+cliente+destino dentro de la misma ventana de 15 min. El CLV con segundos exactos identifica cuál cuadra con cuál (porque el segundo viaje tiene un CLV distinto en los segundos).

Si ningún candidato tiene CLV idéntico → fallback al temporalmente más cercano.

### 3.3 Funciones PG `buscar_travel_id` y `buscar_booking_id`

Quedan vivas porque el **trigger `sp_tctb_insert` las usa** para el cuadre lado TC (sin pasar por Ruby). Su ventana combinada con los helpers Ruby es **±30 min** (más permisiva). Si causa problemas operativos, alinear a ±15 min editando ambas. Ver memoria `feedback-cuadre-ventana-asimetrica-pg`.

---

## 4. `clv_servicio` — formato canónico

```
client_id-fecha-HH:MM:SS-ttpn_service_type_id-ttpn_foreign_destiny_id-vehicle_id
```

Regex: `\A\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+\z`

Ejemplo: `7-2026-05-29-09:15:00-1-1-3`.

**Hora siempre en zona local Chihuahua** (UTC-6).

### 4.1 Los 4 caminos de generación (deben coincidir)

| Camino | Archivo | Mecanismo |
|---|---|---|
| Callback Ruby TB | `app/models/ttpn_booking.rb:74` (`extra_campos`) | `hora.strftime('%H:%M:%S')` con `Time.zone='America/Chihuahua'` |
| Callback Ruby TC vía Rails | `app/models/travel_count.rb:96-103` (`generar_clv_servicio`) | Idéntico al de TB |
| Trigger PG (TC vía PHP) | `db/migrate/20260310035106_*.rb` + fix `20260529101804_update_sp_tctb_insert_timezone_aware.rb` | `to_char((('2000-01-01'::date + NEW.hora) AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chihuahua'), 'HH24:MI:SS')` |
| Rake `cuadre:fill_clvs` | `lib/tasks/fill_cuadre_clvs.rake` | Ruby `hora.strftime('%H:%M:%S')` |

### 4.2 Rake `cuadre:fill_clvs`

```bash
# Backfill — solo rellena clv_servicio IS NULL
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=30

# REBUILD — reescribe filas con formato no canónico (overwrite legacy)
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=15 REBUILD=true
```

Idempotente: el modo REBUILD usa el regex y deja intactas las ya canónicas. Usa `update_columns` (no dispara callbacks).

### 4.3 Verificación

```sql
-- Counts del formato no canónico (debe dar 0 tras correr REBUILD)
SELECT COUNT(*) FROM ttpn_bookings
WHERE fecha >= CURRENT_DATE - INTERVAL '15 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';

SELECT COUNT(*) FROM travel_counts
WHERE fecha >= CURRENT_DATE - INTERVAL '15 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';

-- Cross-source: TB+TC ya cuadrados deben tener clv idéntico tras fix del trigger
SELECT tb.id, tb.clv_servicio, tc.clv_servicio,
       (tb.clv_servicio = tc.clv_servicio) AS coinciden
FROM ttpn_bookings tb
JOIN travel_counts tc ON tc.id = tb.travel_count_id
WHERE tb.viaje_encontrado = true AND tb.created_at > NOW() - INTERVAL '7 days'
LIMIT 10;
```

---

## 5. Reglas de negocio

### 5.1 `sin_duplicado_en_15_minutos` (TtpnBooking)

- Bloquea crear un 2do TB con mismo `client_id + fecha + vehicle_id` a `<900s` (estricto).
- **Aplica** a `creation_method='cloned'`.
- **NO aplica** a `creation_method='automatico'` (el controller lo intercepta y devuelve el TB existente).
- TravelCount **NO tiene** validación equivalente — el chofer puede capturar 2 TCs a <15 min.

### 5.2 MATCH_FIELDS (re-cuadre tras edición)

```ruby
TtpnBooking::MATCH_FIELDS = %w[fecha hora vehicle_id client_id ttpn_service_type_id ttpn_service_id]
```

Cualquier cambio en estos campos:

1. `extra_campos` regenera `clv_servicio` y limpia `viaje_encontrado=false, travel_count_id=nil`.
2. `clear_stale_tc_link` desvincula el TC anterior.
3. `after_commit` encola `Cuadre::TbMatchJob` para re-cuadrar.

### 5.3 Sin viaje cuadrado = pago no facturado

Los TBs con `viaje_encontrado=false` en la corrida de nómina del 4-jun-2026 generan errores de pago. Esto es el por qué de toda la urgencia de Fase 1.

---

## 6. Diagnóstico y troubleshooting

### 6.1 Drilldown del cuadre muestra CLVs distintos entre TB y TC cuadrados

Causa: trigger PG `sp_tctb_insert` generaba CLV en hora UTC. **FIXEADO en migration `20260529101804`**. Aplicar la migration con `bundle exec rails db:migrate` resuelve los TCs futuros.

**⚠️ Para realinear el histórico el rake REBUILD NO sirve**: el regex `\d+-\d{4}-...` es estructural (CLVs con hora UTC cumplen igual que CLVs con hora local). El rake los saltará reportando "0 realineados". Hay que correr SQL UPDATE quirúrgico que aplica la fórmula con `AT TIME ZONE`:

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

Idempotente — si el CLV ya está en hora local, produce el mismo valor. Validar con el cross-check de §4.3.

Si los TBs también requieren realineación (caso raro — el callback Ruby los genera bien), análogo:

```sql
UPDATE ttpn_bookings tb
SET clv_servicio = tb.client_id::text || '-' ||
                   tb.fecha::text || '-' ||
                   to_char(
                     (('2000-01-01'::date + tb.hora) AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chihuahua')::time,
                     'HH24:MI:SS'
                   ) || '-' ||
                   tb.ttpn_service_type_id::text || '-' ||
                   ts.ttpn_foreign_destiny_id::text || '-' ||
                   tb.vehicle_id::text,
    updated_at = NOW()
FROM ttpn_services ts
WHERE ts.id = tb.ttpn_service_id
  AND tb.fecha >= CURRENT_DATE - INTERVAL '15 days'
  AND tb.hora IS NOT NULL;
```

### 6.2 Cuadre Nivel 1 nunca dispara (todo cae a Nivel 2)

Causas posibles:

- Mismatch de formato CLV entre TB y TC (timezone, separadores). Ver §4.3 cross-source.
- Sólo se manifiesta como performance — operativamente el cuadre sigue ocurriendo vía Nivel 2.

### 6.3 TBs descuadrados después del cutover

Correr SQL retroactivo `PASOS_TRAS_MIGRACION.md` paso 4.ter. Funciona en cualquier momento (idempotente).

### 6.4 Sidekiq queue `default` se llena de `Cuadre::TbMatchJob`

Causa: importación masiva está encolando 1 job por TB. `TtpnBookingImportJob` **NO setea `Current.import_mode=true`** — bug conocido pendiente de fix. Workaround: pausar Sidekiq + correr SQL retroactivo después de la importación.

---

## 7. Archivos clave

Ver memoria persistente `reference-cuadre-archivos-clave`. Resumen:

- Modelos: `app/models/{ttpn_booking,travel_count}.rb` + concern `cuadrable.rb` + `current.rb`.
- Service: `app/services/ttpn_cuadre_service.rb`.
- Job: `app/jobs/cuadre/tb_match_job.rb`.
- Helpers: `app/helpers/{ttpn_bookings,travel_counts}_helper.rb`.
- Triggers/funciones PG: `db/migrate/20260115172945_*`, `20260310035106_*`, `20260529101804_*`.
- Rake: `lib/tasks/fill_cuadre_clvs.rake`.
- PHP: `ttpn_php/Gasto_INSERT_TRAVEL_COUNTS.php` (URL `https://pacific-river-53404.herokuapp.com`).

---

## 8. Roadmap

- **Fase 1.A** — Alineación CLV. **DONE 2026-05-28.**
- **Fase 1.B** — Cuadre TB async. **DONE 2026-05-29.**
- **Refactor service + fix timezone trigger** — **DONE 2026-05-29.**
- **Pruebas E2E** — 12 escenarios bash+curl+SQL. **PENDIENTE.**
- **Fase 2** — Web mirror del flujo móvil (dashboard 4-KPI, drilldown, edición en hot, integración Samsara GPS). Post 4-jun.
- **Fase 3** — Cleanup hardcoded, configurabilidad por BU, refactor funciones SQL, alineación funciones PG ventana a ±15min, fix `import_mode` en `TtpnBookingImportJob`, spec RSpec integration E2E.

---

## 9. Operación recurrente

| Tarea | Frecuencia | Comando |
|---|---|---|
| Backfill CLVs (post-import) | Cada import masivo | `railway run -- bundle exec rails cuadre:fill_clvs DAYS=15` |
| Realinear CLVs (post-cutover) | Cutover | `railway run -- bundle exec rails cuadre:fill_clvs DAYS=15 REBUILD=true` |
| SQL retroactivo cuadre (huérfanos) | Cada lunes pre-nómina | Query §1.A.2 del plan en Supabase |
| Verificar cross-source CLV | Tras cualquier cambio | Query §4.3 cross-source |
