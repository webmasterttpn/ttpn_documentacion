# ADR-009 — Versionado web automático vía GitHub Actions

**Estado**: Aceptado
**Fecha**: 2026-05-30
**Decisores**: Equipo TTPN

## Contexto

La tabla `versions` se mantenía manualmente desde la UI. La app móvil se gestiona así desde el inicio del proyecto (modelo de 2 versiones activas: la nueva permanente y la anterior con `fecha_fin` futuro como deadline para forzar actualización). Pero el producto web (BE Rails + FE Quasar) no tenía versionado: solo había una entrada `V1.0.0` (web) creada manualmente el 2025-09-04.

Antes del cutover V2 (2026-06-02), se necesita:

- Registrar cada release web automáticamente (sin que el equipo tenga que actualizar la tabla a mano).
- Mostrar la versión actual al usuario en el footer del FE (LoginPage + MainLayout).
- Reflejar el `commit_sha` del merge para poder rastrear qué cambio originó cada versión.

## Opciones consideradas

### A — Versionado manual desde la UI

Mantener el flujo actual: cada release el responsable edita la tabla `versions` desde Settings → Versiones.

**Pros**: cero infraestructura nueva. Funciona para móvil.
**Contras**: alta fricción para web (deploys frecuentes via PRs). Inconsistencia entre la realidad del código desplegado y lo registrado en BD. Olvidos.

### B — Versionado automático en cada commit a `main`

Un GitHub Action que dispara en cada push a `main` y crea una entrada.

**Pros**: cero esfuerzo manual.
**Contras**: cada commit individual crea una versión. Demasiado granular. Pierde el sentido del semver.

### C — Versionado automático en cada PR mergeado a `main`, con bump según prefijo de branch *(elegida)*

Un GitHub Action dispara en `pull_request closed merged` con `base: main`. Lee `head.ref`:

- `feature/...` → bump minor.
- `fix/...` → bump patch.
- `stage` (release consolidado) → analiza commits del PR vía `gh pr view --json commits`, aplica bump máximo.
- Otros (`chore/`, `docs/`, etc.) → skip silencioso.

POST al endpoint nuevo `/api/v1/versions/bump` autenticado con API Key del bot.

**Pros**: respeta semver. Convención de naming `feature/` y `fix/` ya estaba en uso. Granularidad correcta (un PR = un cambio meritorio). Bot autenticado, humanos no pueden mutar versiones web (defensa en profundidad).
**Contras**: requiere disciplina en el naming de branches. PRs con prefijo distinto no actualizan la versión (decisión consciente, deseado).

## Decisión

**Opción C**.

### Por qué

1. **Alineación con el flujo git existente**: el equipo ya usa `feature/` y `fix/` por convención. Aprovecharlo cuesta menos que imponer un sistema nuevo.
2. **Separación de responsabilidades**: humanos siguen gestionando móvil (donde el flujo de 2 activas tiene sentido); el bot gestiona web.
3. **Auditoría incluida**: cada bump guarda `pr_title`, `pr_url`, `commit_sha` en la descripción/token.

### Cómo bloqueamos el acceso humano a versions web

- BE: `before_action :block_web_for_humans` en `VersionsController` rechaza CRUD manual cuando `dispositivo='web'` y `current_api_key` no está presente. Devuelve 422 con mensaje claro.
- FE: `VersionsPage` quita 'Web' del select de dispositivo, oculta botones edit/delete en filas web, muestra banner "Gestionadas por GitHub Actions". El endpoint `bump` exige API Key (403 si lo invoca un humano con JWT).

## Consecuencias

### Positivas

- Cero esfuerzo manual para releases web.
- Footer del FE siempre refleja la realidad de prod (consume `GET /api/v1/public/version`).
- Convención de naming ya documentada y obligatoria.

### Negativas

- Si alguien mergea un PR con prefijo no estándar (`refactor/`, `chore/`, `docs/`), no se crea versión. Cambios reales pueden quedar fuera del changelog.
  → **Mitigación**: documentado en CLAUDE.md y ADR; el Action loguea explícitamente "Saltado en silencio" para que sea trazable.
- Major bumps requieren intervención manual (`rake versions:bump_major` o `workflow_dispatch`).
  → **Aceptable**: cambios major son raros y benefician de gating manual.
- Bot tiene capacidad de crear versions. Si la API Key se compromete, atacante puede inyectar versiones falsas.
  → **Mitigación**: key guardada como secret en GitHub. Permisos restringidos a `{versions: {bump: true}}`. Rotación recomendada semestral.

### Operativas

- Cualquier nuevo desarrollador del equipo debe respetar `feature/<descripcion>` o `fix/<descripcion>` para que su PR bumpee. Documentado en CLAUDE.md raíz y ttpngas/CLAUDE.md.
- El endpoint público `/api/v1/public/version` queda expuesto sin auth. Es trivial (devuelve solo `version_name`), pero queda dentro del rate-limit general de `/api/` (300 req/5min por IP).

## Implementación

Ver `Documentacion/Backend/dominio/configuracion/organizacion/versions.md`.

## Estado actual

- Implementado y desplegado en stage + producción el 2026-05-30.
- V2.0.0 sembrada con descripción del cutover en ambos ambientes.
- Workflow `bump-version.yml` configurado en `kumi-admin-api` y `kumi-admin-frontend`.
- Secret `KUMI_API_KEY` configurado en ambos repos.
