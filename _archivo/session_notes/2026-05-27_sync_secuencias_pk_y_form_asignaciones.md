# 2026-05-27 — Sincronización de secuencias de PK + fixes del form de Asignaciones

## 1. Asignaciones devolvía 500 al crear → secuencias de PK desincronizadas

**Síntoma:** crear una asignación nueva lanzaba
`PG::UniqueViolation: duplicate key value violates "vehicle_asignations_pkey"
Key (id)=(9016) already exists`.

**Causa raíz (sistémica, no del modelo):** la base se pobló importando datos con
`id` **explícito** (volcado/COPY/delta de cutover). Eso **no** avanza la secuencia
de PK, que queda atrás del `MAX(id)`. Al crear un registro nuevo, PostgreSQL asigna
un id ya existente → violación de unicidad → 500. Afecta a cualquier tabla importada,
no solo `vehicle_asignations`.

**Solución en dos capas (ttpngas):**

1. **Migración `SyncPkSequencesForward` (`20260527000003`)** — one-time,
   **FORWARD-ONLY**: recorre todas las tablas `public` con columna `id`, y solo
   avanza la secuencia a `MAX(id)` cuando está por detrás (nunca la baja). Idempotente
   y segura con tráfico en vivo. Corre en prod vía `db:prepare` en el deploy de Railway.
2. **`SystemMaintenanceController#run_tasks`** — nueva task `reset_sequences`
   (ejecuta `bin/rails db:reset_sequences`, rake idempotente ya existente) e incluida
   como **último paso** del `{"task":"all"}`, para resincronizar tras cualquier
   importación posterior vía cURL.

**Local:** se corrió el reset sobre las 113 secuencias (`vehicle_asignations`
quedó en `MAX(id)=9308`, seq=9308) y se validó la migración en dev+test.

**Proceso permanente documentado:** `PASOS_TRAS_MIGRACION.md` punto 5 (OBLIGATORIO):
correr `reset_sequences` como último paso después de CADA carga de datos. Crítico
para el cutover de prod, donde olvidarlo causaría 500 en cualquier alta nueva.

## 2. Form de Asignaciones (FE) — dropdowns buscables + reset del modal

`src/pages/VehicleAsignations/components/AsignationDialog.vue`:

- **Dropdowns buscables**: vehículo y empleado pasaron a `q-select` con
  `use-input` + `@filter` (`fill-input`, `hide-selected`, `input-debounce`). Se
  escribe para filtrar por etiqueta; slot `no-option` → "Sin resultados".
- **Reset del modal**: el form se reinicializa al **abrir** el diálogo (watch sobre
  `modelValue`), no solo cuando cambia `props.asignation`. Bug previo: "Nueva" →
  guardar → "Nueva" dejaba `asignation` en `null → null`, el watch sobre la prop no
  re-disparaba y el modal conservaba los valores anteriores (q-dialog conserva el
  contenido montado). Ver memoria `feedback_quasar_dialog_prop_reinit`.

ESLint 0, build SPA limpio.

## Despliegue

- ttpngas → `github transform_to_api` (Railway corre la migración con `db:prepare`;
  ese deploy es lo que sincroniza las secuencias en prod).
- ttpn-frontend → `origin` (GitLab → Netlify) + `github`.
- Documentacion → `origin` (GitHub).
