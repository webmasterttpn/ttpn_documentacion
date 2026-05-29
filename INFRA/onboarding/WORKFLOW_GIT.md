# Workflow de Git — Kumi TTPN Admin V2

**Última actualización:** 2026-05-29
**Para:** desarrolladores nuevos en el equipo. No asume experiencia previa con git ni con flujos de ramas.

---

## 1. ¿Por qué leer esto?

Si vas a escribir código en el proyecto Kumi TTPN Admin V2 (Rails API + Quasar PWA), necesitas saber **dónde** y **cómo** poner tus cambios para que:

- No rompas producción accidentalmente.
- Tu trabajo se vea en un ambiente de prueba antes de llegar a los clientes.
- El equipo pueda revisar y validar antes de liberar.

Si te equivocas y haces cambios directos en `main`, despliegas a producción al instante. Lee este documento antes de tocar el repo por primera vez.

---

## 2. Conceptos básicos (5 min)

### 2.1 ¿Qué es una rama (branch)?

Una rama es una **copia paralela** del código. Te permite trabajar en cambios sin afectar a los demás. Cuando terminas, "mergeas" (combinas) tu rama de vuelta a la rama principal.

Imagínalo como una hoja de papel:

- **`main`** = el original que está en producción. Sagrado.
- **`stage`** = una fotocopia donde el equipo junta los cambios de la semana para probarlos.
- **`feat/cambiar-color-boton`** = otra fotocopia donde TÚ trabajas en tu cambio puntual.

### 2.2 Los 3 niveles del proyecto

```text
┌──────────────────────────────────────────────────────────────┐
│  feature branches  (feat/xxx, fix/xxx) ← donde tú trabajas   │
│         ↓ mergea a                                            │
│  stage              ← integración / pruebas del equipo        │
│         ↓ mergea a                                            │
│  main               ← PRODUCCIÓN (Railway redeploya automático)│
└──────────────────────────────────────────────────────────────┘
```

**Regla de oro**: NUNCA pushees directamente a `main`. Todo cambio pasa primero por `stage`.

### 2.3 ¿Qué pasa cuando algo llega a `main`?

Railway (la plataforma donde corre el código en internet) está configurada para **redesplegar automáticamente** cada vez que `main` cambia. Eso significa:

- Push a `main` → producción se actualiza en ~3 minutos.
- Si lo que pusheaste tiene un bug → los clientes lo ven inmediatamente.
- Por eso `stage` existe: para probar primero.

---

## 3. Setup inicial (una sola vez)

### 3.1 Clonar el repo

```bash
git clone https://github.com/webmasterttpn/kumi-admin-api.git
cd kumi-admin-api
```

### 3.2 Configurar tu identidad (si no lo has hecho)

```bash
git config user.name "Tu Nombre"
git config user.email "tu.correo@ttpn.com.mx"
```

### 3.3 ⚠️ Importante — el remoto se llama `github`, no `origin`

En este repo, el remoto principal **NO** se llama `origin` (que es lo estándar). Se llama **`github`**. Por eso todos los comandos de este documento usan `git push github ...` y `git pull github ...` en lugar de `git push origin ...`.

Verifica con:

```bash
git remote -v
```

Debes ver al menos:

```text
github  https://github.com/webmasterttpn/kumi-admin-api.git (fetch)
github  https://github.com/webmasterttpn/kumi-admin-api.git (push)
```

También puede aparecer `origin` apuntando a GitLab — está obsoleto, **no lo uses**.

### 3.4 Verificar que ves las ramas remotas

```bash
git branch -a
```

Debes ver al menos:

- `* main`
- `remotes/github/main`
- `remotes/github/stage`

Si NO ves `stage`, ejecuta:

```bash
git fetch github
git branch -a
```

---

## 4. Workflow paso a paso

### Paso 1 — Antes de empezar, actualiza `stage`

Siempre que vayas a trabajar en algo nuevo, parte de un `stage` actualizado. Esto evita conflictos con cambios que otros compañeros hayan subido.

```bash
git checkout stage
git pull github stage
```

**¿Qué hace cada comando?**

- `git checkout stage` → te cambias a la rama `stage`.
- `git pull github stage` → descarga los últimos cambios que el equipo subió a `stage`.

### Paso 2 — Crea tu rama de feature

A partir de `stage`, crea una rama con un nombre **descriptivo** del cambio que vas a hacer.

```bash
git checkout -b feat/agregar-filtro-por-cliente
```

**Convención de nombres** (sigue uno de estos prefijos):

| Prefijo | Cuándo usar | Ejemplo |
|---|---|---|
| `feat/` | Nueva funcionalidad | `feat/dashboard-mantenimiento` |
| `fix/` | Arreglo de bug | `fix/cuadre-no-actualiza-fk` |
| `refactor/` | Mejorar código sin cambiar comportamiento | `refactor/extraer-helper-cuadre` |
| `docs/` | Solo documentación | `docs/api-key-rotation` |
| `chore/` | Mantenimiento (gemas, configs) | `chore/bundle-update-rails-7-2` |

**Reglas del nombre**:

- Todo en minúsculas, con guiones (`-`), no espacios ni mayúsculas.
- Corto y claro. Máximo 60 caracteres.
- Si la feature está en un ticket, incluir el número: `feat/KUMI-42-filtro-cliente`.

### Paso 3 — Trabaja en tu rama

Haz tus cambios en el código. Commitea seguido — un commit por cada "paso lógico" del cambio.

```bash
# Después de editar archivos
git add app/models/ttpn_booking.rb spec/models/ttpn_booking_spec.rb
git commit -m "feat(bookings): agrega scope filter_by_cliente con tests"
```

**Convención de mensaje de commit** (sigue el patrón [Conventional Commits](https://www.conventionalcommits.org/)):

```text
<tipo>(<scope>): <descripción corta en español, máx 70 chars>

[cuerpo opcional explicando POR QUÉ del cambio]
```

Ejemplos:

```text
feat(cuadre): agrega endpoint /cuadre/correct para edición inline
fix(ttpn_services): incremento ahora se aplica como porcentaje, no como suma
refactor(reports): extrae helper PnLCalculator del controller
docs(api): documenta el flujo de rotación de API Keys
chore(deps): bump rubocop-rails 2.20 → 2.25
```

### Paso 4 — Pushea tu rama al remoto

Esto sube tus commits a GitHub para que el equipo pueda ver tu trabajo.

```bash
git push -u github feat/agregar-filtro-por-cliente
```

**`-u`** se pone solo la primera vez. Indica a git que "esta rama local sigue a esa rama remota". Después solo necesitas `git push`.

### Paso 5 — Valida calidad antes de mergear

Antes de mergear a `stage`, asegúrate de que tu código pase los chequeos automáticos. Desde la raíz del backend:

```bash
bundle exec rubocop --parallel        # 0 ofensas obligatorio
bundle exec rspec                      # 0 fallas obligatorio
COVERAGE=true bundle exec rspec        # cobertura ≥ 85%
bundle exec rake rswag:specs:swaggerize # si agregaste/modificaste un endpoint
```

Si algo falla, corrígelo en tu rama antes de seguir.

### Paso 6 — Mergea tu feature a `stage`

Tienes dos opciones: vía Pull Request en GitHub (recomendado para que alguien revise) o merge directo desde tu terminal (rápido, sin revisión).

#### Opción A — Pull Request (recomendada)

1. Ve a `https://github.com/webmasterttpn/kumi-admin-api/pulls`
2. Click en **"New pull request"**.
3. Selecciona:
   - **base**: `stage`
   - **compare**: `feat/agregar-filtro-por-cliente`
4. Escribe título y descripción siguiendo este formato:

```markdown
## Resumen
- Qué hace este cambio en 1-3 bullets.
- Por qué es necesario.

## Cómo probar
- Pasos para que alguien valide el cambio en local o en stage.

## Checklist
- [x] RuboCop 0 ofensas
- [x] RSpec 0 fallas, cobertura ≥ 85 %
- [x] Swagger actualizado (si aplica)
- [x] Documentación creada para artefactos nuevos
```

5. Click **"Create pull request"**.
6. Pide a un compañero que lo revise.
7. Cuando esté aprobado, click **"Merge pull request"** → escoge **"Create a merge commit"** (no Squash ni Rebase, para preservar la historia).

#### Opción B — Merge directo desde terminal

Solo si tu cambio es trivial y no necesita revisión:

```bash
git checkout stage
git pull github stage
git merge --no-ff feat/agregar-filtro-por-cliente
git push github stage
```

**`--no-ff`** crea un commit de merge explícito (queda registro de que existió la feature branch).

### Paso 7 — Probar en `stage`

Después de mergear a `stage`, valida que todo funciona como esperas en el ambiente de pruebas. Esto puede ser:

- Levantar la aplicación local apuntando al BE en stage.
- Si stage tuviera Railway environment separado, validar ahí (actualmente NO está conectado a Railway — solo es una rama de integración).

### Paso 8 — Promover `stage` → `main` (release a producción)

Cuando un conjunto de features está validado en `stage` y está listo para ir a clientes:

1. Ve a `https://github.com/webmasterttpn/kumi-admin-api/compare/main...stage`
2. Click **"Create pull request"**.
3. Título: `release: <descripción del lote, ej. semana 2026-W23>`.
4. En la descripción, lista las features incluidas (puedes copiar de los PRs de stage).
5. Solicita aprobación del responsable de releases.
6. Una vez aprobado: **"Merge pull request"** → **"Create a merge commit"**.
7. Railway detecta el cambio en `main` y redespliega producción automáticamente (~3 minutos).

**Importante**: nunca pushees directamente a `main` desde tu terminal. Todos los releases pasan por PR.

### Paso 9 — Limpiar tu rama después de mergear

Cuando tu feature ya está en `stage` (o en `main`), borra la rama:

```bash
# Local
git checkout stage
git branch -d feat/agregar-filtro-por-cliente

# Remoto (también desde GitHub UI con el botón "Delete branch")
git push github --delete feat/agregar-filtro-por-cliente
```

Esto mantiene el repo limpio.

---

## 5. Comandos clave — chuleta rápida

| Quiero... | Comando |
|---|---|
| Ver en qué rama estoy | `git branch --show-current` |
| Ver todas las ramas | `git branch -a` |
| Cambiar de rama | `git checkout nombre-rama` |
| Crear y cambiar a rama nueva | `git checkout -b feat/algo` |
| Bajar cambios del remoto | `git pull github stage` |
| Subir cambios al remoto | `git push github nombre-rama` |
| Ver qué archivos cambié | `git status` |
| Ver el diff de mis cambios | `git diff` |
| Agregar archivos al próximo commit | `git add archivo1 archivo2` |
| Crear un commit | `git commit -m "tipo(scope): descripción"` |
| Ver historial reciente | `git log --oneline -10` |
| Deshacer cambios no commiteados | `git checkout -- archivo` |
| Borrar rama local | `git branch -d nombre-rama` |
| Borrar rama remota | `git push github --delete nombre-rama` |

---

## 6. Troubleshooting común

### "Mi push fue rechazado: non-fast-forward"

Alguien más subió cambios mientras tú trabajabas. Solución:

```bash
git pull --rebase github stage    # rebase sobre los cambios remotos
# resolver conflictos si los hay (git status te los muestra)
git push github nombre-rama
```

### "Tengo conflictos al mergear"

Git no puede combinar automáticamente porque dos personas cambiaron las mismas líneas. Resolución:

1. Git te marca los archivos en conflicto con `<<<<<<< HEAD ... =======  ... >>>>>>> branch`.
2. Edita cada archivo: deja solo lo que quieres conservar y borra los marcadores.
3. `git add archivo` para cada archivo resuelto.
4. `git commit` (mensaje por default está bien).

### "Hice commit en `main` por error"

Si todavía no pusheaste:

```bash
git checkout -b feat/lo-que-sea           # crea rama nueva con tus cambios
git checkout main
git reset --hard github/main              # main vuelve a estar limpio
git checkout feat/lo-que-sea              # sigue trabajando en tu rama
```

Si ya pusheaste a `main`, **avisa al equipo inmediatamente**. No intentes revertir tú sin coordinar.

### "No sé qué rama merger / dónde quedaron mis cambios"

```bash
git log --oneline --all --graph -20
```

Te muestra un mapa visual de las últimas 20 versiones de todas las ramas.

### "Olvidé en qué rama estaba trabajando"

```bash
git reflog
```

Te muestra el historial de en qué ramas estuviste recientemente.

---

## 7. Reglas no negociables

- ❌ **NUNCA** pushees directo a `main`.
- ❌ **NUNCA** uses `git push --force` (excepto en tu propia feature branch sin compartir).
- ❌ **NUNCA** uses `git reset --hard` sobre cambios commiteados que ya pusheaste — pierdes trabajo.
- ❌ **NUNCA** trabajes directamente sobre `stage`. Siempre desde una feature branch.
- ✅ **SIEMPRE** parte de un `stage` actualizado (`git pull github stage`).
- ✅ **SIEMPRE** corre `rubocop` + `rspec` antes de mergear.
- ✅ **SIEMPRE** usa mensajes de commit en formato `tipo(scope): descripción`.
- ✅ **SIEMPRE** borra tu feature branch después de mergear.

---

## 8. Glosario

| Término | Significado |
|---|---|
| **Branch / rama** | Copia paralela del código donde trabajas sin afectar otras ramas. |
| **Commit** | Un punto en el historial — un cambio nombrado y firmado. |
| **Push** | Subir tus commits locales al remoto (GitHub). |
| **Pull** | Bajar commits del remoto al local. |
| **Merge** | Combinar dos ramas en una sola. |
| **Pull Request (PR)** | Propuesta de merge revisable en GitHub. |
| **Rebase** | Reescribir el historial para que tus commits queden encima de los más recientes. |
| **Conflict** | Cuando git no puede mergear automáticamente y necesita decisión humana. |
| **HEAD** | Apuntador a "donde estás" en el historial. |
| **Remoto / remote** | Una copia del repo en otro lugar (en este caso, GitHub). |
| **Origin** | El alias estándar para el remoto principal en otros proyectos. ⚠️ En **este** repo se usa `github` en su lugar — `origin` apunta a GitLab obsoleto. |
| **Stage** | Rama de integración previa a producción. NO confundir con "staging area" de git. |
| **Producción / prod** | El ambiente real donde los clientes usan la app. En este proyecto = Railway desde `main`. |

---

## 9. Para casos no cubiertos

Si te topas con algo que este documento no resuelve:

- Pregunta a un compañero del equipo de backend.
- Revisa `CLAUDE.md` en la raíz del repo (reglas del codebase específicas).
- Revisa `Documentacion/INFRA/onboarding/onboarding_BE.md` para el setup completo del entorno.
- Si nada ayuda, abre un issue en GitHub describiendo el problema.

---

## 10. Resumen visual del flujo

```text
              [Tú quieres agregar el filtro X]
                            │
                            ▼
        git checkout stage && git pull github stage
                            │
                            ▼
       git checkout -b feat/agregar-filtro-x
                            │
                            ▼
            [editas código, agregas tests]
                            │
                            ▼
        git add . && git commit -m "feat(...): ..."
                            │
                            ▼
            git push -u github feat/agregar-filtro-x
                            │
                            ▼
   [En GitHub UI: crear PR de feat/agregar-filtro-x → stage]
                            │
                            ▼
             [Compañero revisa y aprueba]
                            │
                            ▼
            [Merge PR en GitHub → stage actualizado]
                            │
                            ▼
   git checkout stage && git pull github stage
   git branch -d feat/agregar-filtro-x     ← limpia tu local
                            │
                            ▼
     [Pruebas finales en stage por el equipo]
                            │
                            ▼
[Cuando el lote está listo: PR de stage → main en GitHub UI]
                            │
                            ▼
        [Merge PR → main → Railway redeploya prod]
```

Si seguiste estos pasos, tu cambio llegó a producción de forma segura. ¡Bienvenido al equipo!
