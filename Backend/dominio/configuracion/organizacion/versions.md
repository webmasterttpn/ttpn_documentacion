# Versiones del producto Kumi

Tabla `versions` y su flujo de gestión, separando móvil (manual) de web (automático vía GitHub Actions).

---

## Propósito

Registrar las versiones del producto en sus 2 dispositivos:

- `movil`: app Android/iOS. Se gestiona **manualmente** desde `Settings → Organización → Versiones`. Permite 2 versiones activas simultáneas (la nueva permanente + la anterior con `fecha_fin` futuro como deadline para forzar actualización).
- `web`: BE Rails API + FE Quasar PWA. Se gestiona **100% automáticamente** vía GitHub Actions al mergear PRs a `main`. Una sola versión activa permanente. La anterior queda `is_active=false, fecha_fin=Date.current` al desplegar la nueva.

---

## Modelo

`app/models/version.rb`

Campos relevantes:

| Campo | Tipo | Notas |
|---|---|---|
| `version_name` | string | semver web: `V<major>.<minor>.<patch>`. Móvil: libre (ej. `V3-23`). |
| `descripcion` | text | Para web: lista de items `- [BE\|FE] <PR title> (<PR url>)`. Para móvil: texto libre. |
| `dispositivo` | enum-like | `'movil'` o `'web'`. |
| `fecha_inicio` | date | Cuándo entró en vigencia. |
| `fecha_fin` | date | Web: cuándo se desactivó. Móvil: deadline futuro para forzar update. |
| `is_active` | bool | Si la versión sigue vigente. |
| `token` | string | Web: `commit_sha` del merge que la originó. Móvil: nullable. |

Reglas (`validate_version_rules`, solo si `is_active`):

- Máx 2 versiones activas por `dispositivo`.
- Máx 1 versión permanente (`fecha_fin = nil`) activa por `dispositivo`.
- Si es permanente y existe otra activa, su `fecha_inicio` debe ser mayor.
- Si es temporal con `fecha_fin <= today`, exige una permanente de reemplazo.

En web nunca se tocan las reglas 3-5 porque al cerrar la anterior queda `is_active=false` y se sale del scope de validación.

---

## Endpoints

### POST `/api/v1/versions/bump` (M2M, solo bot)

Lo invoca el GitHub Action al mergear PRs a `main`. Exige `Authorization: Bearer <API_KEY>` con `@current_api_key.present?`. Devuelve 403 si lo invoca un usuario humano.

**Body**:

```json
{
  "component":   "BE | FE",
  "bump_type":   "major | minor | patch",
  "branch_name": "feature/algo",
  "pr_number":   42,
  "pr_title":    "feat(algo): descripción",
  "pr_url":      "https://github.com/owner/repo/pull/42",
  "head_sha":    "abc123..."
}
```

**Comportamiento**:

1. Lee la última `Version` web ordenada por `fecha_inicio desc, id desc`.
2. Si la última es de hoy y `created_at > 12.hours.ago`: hace **UPDATE** (concatena descripción + recalcula `version_name` con el nuevo bump si aplica).
3. Si más vieja o no existe: hace **CREATE** (cierra anterior con `is_active=false, fecha_fin=Date.current`, crea nueva con `is_active=true, fecha_inicio=Date.current`).
4. Devuelve `201` con `{ version: {...}, action: 'created' | 'updated' }`.

### GET `/api/v1/public/version` (sin auth)

Endpoint público para que el footer del FE (LoginPage + MainLayout) muestre la versión activa antes del login. Devuelve `{ version_name: 'V2.0.0' }` o `{ version_name: 'V?.?.?' }` si no hay versión web activa permanente.

Hereda directo de `ActionController::API`, no pasa por `BaseController`. Rack::Attack cubre con throttle general de `/api/`.

### Endpoints de CRUD manual (`/api/v1/versions`)

Existentes: `index`, `show`, `create`, `update`, `destroy`, `activate`, `deactivate`. Todos exigen JWT humano excepto `index/show` que también aceptan API Key (lectura).

**Bloqueo de versiones web manuales**: el `before_action :block_web_for_humans` rechaza con `422` cualquier intento de `create/update/destroy/activate/deactivate` sobre `dispositivo='web'` cuando el caller es humano (JWT, sin `@current_api_key`). Solo bot puede mutar web.

---

## GitHub Action — flujo de bump

`.github/workflows/bump-version.yml` en `ttpngas` y en `ttpn-frontend` (un workflow por repo).

**Triggers**:

1. `pull_request closed merged` con `base: main` → bumpea producción.
2. `workflow_dispatch` (botón "Run workflow" en pestaña Actions) → permite probar manualmente sin abrir PR. Inputs: `bump_type` y `target_api` (production | stage).

**Lógica del bump según `head.ref` del PR**:

| `head.ref` | Decisión |
|---|---|
| `feature/...` | minor |
| `fix/...` | patch |
| `stage` | mira commits del PR vía `gh pr view --json commits`; si hay `feature/` en mensajes → minor; si solo `fix/` → patch; si ninguno → skip |
| Otro (`chore/`, `docs/`, etc.) | skip silencioso |

**Bump major** NO es automático. Se hace a mano con `rake versions:bump_major[descripción]` o vía `workflow_dispatch` con `bump_type=major`.

---

## Rake tasks

`lib/tasks/versions.rake`:

| Task | Uso |
|---|---|
| `versions:create_api_key` | Crea o reutiliza ApiUser `github-actions@ttpn.com.mx` y genera una API Key con permission `{versions: {bump: true}}`. Imprime la key — guárdala en GitHub Settings → Secrets → `KUMI_API_KEY`. |
| `versions:seed[V2.0.0,"descripción"]` | Siembra una versión web manualmente. Útil para el cutover inicial (V2.0.0 antes de migrar a v2). Cierra cualquier versión web activa previa con `fecha_fin=today` y crea la nueva como permanente. |
| `versions:bump_major[descripción]` | Bumpea major a mano (sin API Action). Equivale al `bump_type=major` del endpoint. |

---

## Setup inicial (cutover V2.0.0)

```bash
# 1. Generar API Key del bot (en cada ambiente, stage y prod)
railway run --service kumi-admin-api -e stage      -- bundle exec rake versions:create_api_key
railway run --service kumi-admin-api               -- bundle exec rake versions:create_api_key

# 2. Pegar la key en GitHub Settings → Secrets → KUMI_API_KEY (de cada repo: kumi-admin-api y kumi-admin-frontend)

# 3. Seed V2.0.0 en stage (hoy) y prod (cutover lunes 2-jun)
railway run --service kumi-admin-api -e stage -- 'bundle exec rake versions:seed[V2.0.0,"Kumi V2..."]'
railway run --service kumi-admin-api          -- 'bundle exec rake versions:seed[V2.0.0,"Kumi V2..."]'
```

---

## Diferencia con móvil

Móvil queda como antes: el admin crea/edita desde la UI (`Settings → Organización → Versiones → Móvil`). Puede tener 2 activas simultáneas (la nueva permanente + la anterior con `fecha_fin` futuro). Cuando llega `fecha_fin` se desactiva automáticamente.

En web la UI bloquea creación/edición y muestra un banner informativo: *"Las versiones web se gestionan automáticamente por GitHub Actions al mergear PRs a main."*
