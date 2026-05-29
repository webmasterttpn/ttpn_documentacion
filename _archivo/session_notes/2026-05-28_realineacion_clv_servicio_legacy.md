# 2026-05-28 — Realineación de formato `clv_servicio` (legacy → canónico)

## Contexto

Preparando Fase 1 del plan de cuadre (`/Users/ttpn_acl/.claude/plans/revisa-esto-para-ver-smooth-dusk.md`) para la migración del 2-jun-2026 y la corrida de nómina del 4-jun-2026, se detectó que muchos `TtpnBooking` heredados del flujo PHP tienen `clv_servicio` en formato sin separadores (ej. `72026-05-0416:15163`), mientras los `TravelCount` y los TBs nuevos generados por Rails usan el formato canónico con guiones (`7-2026-05-04-09:15:00-1-1-3`).

Mientras ambos formatos coexistan:

- El match Nivel 1 (`tb.clv_servicio = tc.clv_servicio`) jamás dispara para los legacy → todo cae a Nivel 2 (ventana de tiempo, ~10× más lento).
- El drilldown del cuadre muestra CLVs ilegibles en el lado TB, rompiendo la verificación visual del match.
- El SQL retroactivo §1.A.2 del plan reporta `nivel_1_clv_exacto = 0` aunque sí haya pares en el rango.

## Cambio

### `ttpngas/lib/tasks/fill_cuadre_clvs.rake`

Se extendió el rake `cuadre:fill_clvs` con flag `REBUILD=true`:

- **Sin `REBUILD`** (default): solo rellena filas con `clv_servicio IS NULL` (comportamiento previo, backfill).
- **Con `REBUILD=true`**: aplica el regex canónico `\A\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+\z` y reescribe TODA fila que no cumpla; deja intactas las que ya están en formato canónico (idempotente).

Constante `CANONICAL_CLV_REGEX` movida al nivel top-del-archivo para no caer en `Lint/ConstantDefinitionInBlock` dentro de `namespace :cuadre do`.

Sigue usando `update_columns` → no dispara callbacks de `TtpnCuadreService` ni de auditoría.

### `Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md` — paso 4.bis

Reescrito para documentar los dos modos (backfill vs REBUILD), cuándo correr cada uno, comandos `railway run`, y los counts de verificación post-ejecución (incluyendo el SQL con el regex canónico).

### Plan §1.A.0 (nuevo)

Se agregó §1.A.0 "PRE-REQUISITO — Realinear formato `clv_servicio`" antes del SQL retroactivo del cuadre §1.A.2. Sin esa realineación previa, el diagnóstico Nivel 1 vs Nivel 2 del SQL retroactivo es engañoso.

## Comandos relevantes

```bash
# Backfill normal (solo NULL, default 30 días)
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs

# REBUILD post-cutover (overwrite legacy, 60 días — usar antes del SQL §1.A.2)
railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=60 REBUILD=true
```

Verificación SQL post-rake (ambos counts deben ser 0):

```sql
SELECT COUNT(*) FROM ttpn_bookings
WHERE fecha >= CURRENT_DATE - INTERVAL '60 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';

SELECT COUNT(*) FROM travel_counts
WHERE fecha >= CURRENT_DATE - INTERVAL '60 days'
  AND clv_servicio !~ '^\d+-\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}-\d+-\d+-\d+$';
```

## Pendiente (deuda técnica Fase 3)

Discrepancia de timezone entre la lectura Ruby (`hora.strftime('%H:%M:%S')` con `Time.zone='America/Chihuahua'`) y `TO_CHAR(hora,'HH24:MI:SS')` en SQL puro: la primera da hora local; la segunda da hora cruda en UTC.

- Por ahora **el rake es la fuente única** de generación/realineación de `clv_servicio` para no abrir ese frente durante la urgencia de migración.
- Resolver en Fase 3 §3.1: decidir convención única (¿hora local del BU o UTC?) y migrar columnas + callbacks + queries.

## Próximos pasos en la sesión

1. Correr en Supabase (vía Railway):
   ```bash
   railway run --service kumi-admin-api bundle exec rails cuadre:fill_clvs DAYS=60 REBUILD=true
   ```
2. Verificar con los dos SQL counts.
3. Ejecutar SQL retroactivo §1.A.2 del plan.
4. Iniciar Fase 1.B (job async `Cuadre::TbMatchJob`).
