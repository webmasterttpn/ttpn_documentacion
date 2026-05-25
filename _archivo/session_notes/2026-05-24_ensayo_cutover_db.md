# 2026-05-24 — Ensayo de cutover de DB (Heroku → esquema V2)

## Objetivo
Cargar el respaldo de **producción** de Heroku (`acfd4e22-9dc3-4293-ba33-db54650bc6ac`)
en una DB de prueba **sin perder** el esquema V2 (columnas/tablas nuevas de
`transform_to_api`), correr todo lo necesario, y verificar que nada se rompe —
como ensayo del cutover de producción de la próxima semana.

## Decisiones
- **DB nueva paralela** `ttpngas_cutover` (local, Postgres 17). NO se tocó
  `ttpngas_development` ni la Supabase de producción (URL comentada en `.env`).
- **Todo el histórico** (sin purga de trimestre).
- Estrategia = ensayo real de cutover: `restore full → db:migrate → backfill →
  seeds → setval → verify`.

## Resultado (todo exit 0)
1. Restore del dump (209 MB, 79 tablas, mig tope `20260128020918`) — 42 s, 0 errores.
2. `db:migrate` de las **85 migraciones** V2 sobre datos reales — ~2 min, **limpio**
   (valida el riesgo #1 del cutover). Esquema final: 111 tablas, mig `20260522160000`.
3. Backfills con triggers off (`session_replication_role=replica`) — ~12 min,
   **0 NULLs** restantes en `business_unit_id` / `created_by_id` / `updated_by_id`.
4. Seeds: **75 privileges, 196 role_privileges, 10 kumi_settings**.
5. **106 secuencias** ajustadas (setval generado, no lista fija).
6. Smoke: `needs_migration? = false`, modelos+asociaciones OK,
   `KumiSetting.payroll_hora_corte(1) = 01:30`. Counts: 1.6M bookings / 1.3M TC /
   158K discrepancias.

## Hallazgos (para el cutover real)
- **BUG** `db/seeds/role_privileges_sistemas.rb:9`: busca rol `'Sistemas'`
  (mayúscula) y hace `exit 1`; prod usa `'sistemas'` → aborta toda la cadena de
  seeds. Fix: lookup `ILIKE` + sin `exit 1`. (Ensayo corrió un equivalente corregido.)
- `sadmin` ahora es **booleano por usuario** (no id fijo 1/2). Backfill histórico
  de auditoría usó un `users.id` con `sadmin=true` (id 2 en este ensayo).
- Tabla `client_contacts` existe solo en prod (renombrada/eliminada en V2) → su
  data se omite. Confirmar que nada la use.
- `db/schema.rb` se revierte tras el migrate (la corrida añade pgcrypto/uuid-ossp).

## Estado
`ttpngas_cutover` queda cargada y verificada como DB de prueba. Para usarla con la
app: `docker exec -e DATABASE_URL=postgres://castean:<pwd>@host.docker.internal:5432/ttpngas_cutover ...`
o apuntar `LOCAL_DB_NAME`. Detalle completo y reproducible en
`migracion/MIGRACION_DB.md` → sección «ENSAYO DE CUTOVER VALIDADO».
