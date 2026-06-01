# 2026-05-30 — Auto-reset PK sequences al boot del contenedor

## Contexto

Tras la importación más reciente a **stage**, el endpoint `POST /api/v1/roles`
empezó a devolver 500 con:

```text
PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "roles_pkey"
DETAIL:  Key (id)=(4) already exists.
```

Causa raíz: el import cargó filas con `id` explícito y dejó la secuencia
`roles_id_seq` atrasada respecto a `MAX(id)`. PostgreSQL asignó al nuevo rol un
id ya existente.

Esto **ya está documentado** como riesgo crónico tras imports
(`PASOS_TRAS_MIGRACION.md` §5 y memoria `feedback_reset_sequences_tras_importacion`).
Es la **segunda reincidencia** registrada (la primera fue `vehicle_asignations`
el 2026-05-27).

## Fix inmediato — stage

```bash
railway environment stage
railway ssh --service kumi-admin-api "bundle exec rails db:reset_sequences"
```

Todas las secuencias resincronizadas. Creación de roles desbloqueada.

## Blindaje permanente

PR `fix/auto-reset-sequences-on-boot` (kumi-admin-api, base `stage`):

- **Archivo**: `Dockerfile` (stage `production`).
- **Cambio**: el CMD agrega `bundle exec rails db:reset_sequences` entre
  `db:prepare` y `puma`.
- **Antes**:

  ```bash
  rm -f tmp/pids/server.pid && bundle exec rails db:prepare && bundle exec puma -C config/puma.rb
  ```

- **Después**:

  ```bash
  rm -f tmp/pids/server.pid && bundle exec rails db:prepare && bundle exec rails db:reset_sequences && bundle exec puma -C config/puma.rb
  ```

- **Efecto**: cada deploy/restart de `kumi-admin-api` resincroniza solo. Si
  alguien importa datos y olvida disparar el cURL, el siguiente deploy lo cura.
- **Costo**: ~5 s extra al boot. Idempotente.
- **Sigue siendo obligatorio** disparar el cURL `reset_sequences` justo después
  de un import: entre el import y el siguiente deploy puede haber horas con la
  app rompiéndose en cada `POST` que asigna PK nuevo.

## Por qué no se eligió otra opción

| Opción descartada | Razón |
| --- | --- |
| Banner OBLIGATORIO al tope del runbook | No automatiza. Si el operador olvida, se rompe igual. |
| Endpoint health-check `/check_sequences` | Detecta pero no cura — sigue exigiendo acción manual. |
| Rescue PG::UniqueViolation en BaseController con retry | Magia que oculta el problema; difícil de razonar; no se detecta drift en otras secuencias dormidas. |

El auto-reset al boot es el único que **cura sin acción humana**, sin ocultar el
problema (los logs del deploy muestran qué tablas se resincronizaron).

## Actualizaciones colaterales

- `Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md` §5: agregado el
  bloque informativo del auto-reset (la regla "obligatorio tras cada import"
  sigue vigente).
- Memoria `feedback_reset_sequences_tras_importacion`: registrada la reincidencia
  y el blindaje.

## Flujo del PR

1. Branch `fix/auto-reset-sequences-on-boot` desde `main`.
2. PR a `stage` (no bumpea version — Action solo dispara con `base: main`).
3. Deploy automático de Railway al mergear → primer test es ver los logs del
   boot mostrando "All sequence IDs have been successfully reset!".
4. Cuando se mergea `stage → main` post-cutover, bumpea `V2.0.x → V2.0.(x+1)`
   y el comportamiento queda activo en prod.
