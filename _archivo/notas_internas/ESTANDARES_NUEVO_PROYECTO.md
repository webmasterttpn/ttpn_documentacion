# Estándares — Nuevo Proyecto

**Fecha:** 2026-04-25  
**Aplica a:** Todo proyecto nuevo creado dentro del ecosistema Kumi TTPN

---

## Propósito

Este documento es la referencia única para arrancar cualquier sistema nuevo — portal, módulo, API satélite, app móvil — de manera que cumpla desde el primer commit con calidad, seguridad, mantenibilidad y coherencia con el ecosistema existente. No repetir instrucciones: este documento es suficiente.

---

## 1. Antes de Escribir una Línea de Código

### 1.1 Registro de la Decisión (ADR)

Crear `Documentacion/ADR/ADR-00X-nombre-del-proyecto.md` con:

```markdown
# ADR-00X — [Nombre del Proyecto]

## Fecha
YYYY-MM-DD

## Estado
Propuesto | Aceptado | Rechazado | Deprecado

## Contexto
Qué problema resuelve. Por qué se crea este sistema ahora.

## Opciones consideradas
1. Opción A — descripción breve
2. Opción B — descripción breve
3. Opción C (la elegida) — descripción breve

## Decisión
Se elige Opción C porque...

## Consecuencias
- ✅ Beneficios
- ⚠️ Trade-offs aceptados
- ❌ Lo que NO cubre este proyecto
```

### 1.2 PRD (Product Requirements Document)

Crear `Documentacion/PRD_NOMBRE_PROYECTO.md`:

```markdown
# PRD — [Nombre del Proyecto]

## Objetivo de negocio
Una frase. Qué problema del cliente resuelve.

## Usuarios
| Rol | Qué puede hacer |
|---|---|
| Cliente administrador | Solicitar viajes, ver historial |
| Coordinador TTPN | Aprobar, asignar, responder |

## Casos de uso principales
1. [Actor] puede [acción] para [objetivo]
2. ...

## Casos de uso excluidos (fuera de alcance v1)
- X no es parte de esta versión

## Integraciones
- Kumi API — fuente de datos maestra
- [Otro sistema si aplica]

## Métricas de éxito
- KPI 1: tiempo de respuesta al cliente < 2h
- KPI 2: ...
```

### 1.3 Definición del Stack

Elegir basado en el tipo de proyecto:

| Tipo de proyecto | Stack recomendado |
|---|---|
| API / módulo nuevo en Kumi | Rails module dentro de `ttpngas` |
| Portal web de cliente/proveedor | Vue 3 + Quasar (repo separado) |
| App móvil | React Native o Capacitor sobre Quasar |
| Sistema interno backoffice | Rails + Quasar (mismo patrón Kumi) |
| Sistema autónomo con su propia BD | Rails API + Vue 3 + misma BD Supabase |
| Automatización / integraciones | N8N + webhooks a Kumi API |

---

## 2. Estructura de Repositorio

### Backend (Rails API)

```
mi-proyecto-api/
├── app/
│   ├── controllers/api/v1/
│   ├── models/
│   ├── services/          ← lógica de negocio
│   ├── serializers/       ← para modelos complejos
│   ├── concerns/          ← comportamiento compartido
│   ├── jobs/              ← Sidekiq
│   └── channels/          ← ActionCable
├── config/routes/         ← un archivo por dominio
├── db/migrate/
├── spec/
│   ├── factories.rb
│   ├── models/
│   ├── requests/api/v1/
│   ├── services/
│   └── support/
├── swagger/               ← generado por rswag
├── CLAUDE.md              ← OBLIGATORIO, copiar plantilla de abajo
└── .env.example           ← OBLIGATORIO, nunca .env real
```

### Frontend (Vue 3 + Quasar)

```
mi-proyecto-fe/
├── src/
│   ├── pages/
│   │   └── ModuloX/
│   │       ├── ModuloXPage.vue      ← máx 300 líneas
│   │       └── components/
│   ├── composables/
│   │   └── ModuloX/
│   │       ├── useModuloXData.js
│   │       ├── useModuloXForm.js
│   │       └── useModuloXActions.js
│   ├── services/
│   │   └── modulox.service.js
│   ├── mocks/                       ← datos de desarrollo sin BE
│   └── router/routes.js
├── CLAUDE.md                        ← OBLIGATORIO
└── .env.example                     ← OBLIGATORIO
```

---

## 3. Principios — No Negociables

### KISS (Keep It Simple)
- La solución más simple que funcione correctamente, siempre.
- Si necesitas explicar el diseño más de 2 minutos, es demasiado complejo.
- Sin abstracciones anticipadas. Tres líneas repetidas > abstracción prematura.
- Un método hace una cosa. Un composable tiene una responsabilidad.

### DRY (Don't Repeat Yourself)
- Lógica de negocio en un único lugar: concern, service o composable.
- Copy-paste entre controllers/composables = señal de que falta extraer.
- Validaciones en el modelo (BE) y en el formulario (FE) — no en el controller.

### Seguridad desde el Diseño
- Autenticación en cada endpoint desde el día 1. No "lo agrego después".
- Autorización por rol/privilegio — nunca `role_id` hardcodeado.
- Params con whitelist explícita (`permit`). Nunca `permit!`.
- Datos sensibles: nunca en logs, URLs ni commits.
- API Keys con scope mínimo. Rotación cada 6 meses.
- HTTPS siempre en producción. Certificado en el deploy, no en la app.
- Inputs sanitizados en el BE aunque el FE ya valide.

### Código Limpio
- Nombres descriptivos. Si el nombre necesita un comentario, cámbialo.
- Comentarios solo para el **por qué**, nunca para el **qué**.
- Funciones < 20 líneas. Métodos > 20 líneas se dividen.
- Sin `console.log`, `binding.pry`, `debugger` en código que se mergea.
- Sin `TODO` sin ticket asociado.

---

## 4. CLAUDE.md — Obligatorio en cada Repositorio

Crear en la raíz del repo. Copiar y adaptar esta plantilla:

```markdown
# CLAUDE.md — [Nombre del Proyecto]

Proyecto: [qué hace]
Ecosistema: Kumi TTPN Admin V2
Ver estándares base: ../Documentacion/ (si es sub-repo) o Documentacion/

## Stack
[tabla con tecnologías]

## Integración con Kumi
- URL API: configurada en KUMI_API_URL (.env)
- Auth: API Key con scope [listar scopes]
- Ver: Documentacion/INFRAESTRUCTURA_API.md

## Principios
KISS · DRY · Seguridad desde el diseño
Ver: Documentacion/ESTANDARES_NUEVO_PROYECTO.md

## Estándares BE
Ver: Documentacion/ESTANDARES_API.md

## Estándares FE
Ver: Documentacion/ESTANDARES_FE.md

## Comandos útiles
[comandos específicos del proyecto]

## Checklist pre-merge
- [ ] Tests pasando, cobertura ≥ 85%
- [ ] Lint/RuboCop: 0 errores
- [ ] Swagger actualizado
- [ ] Documentación de artefactos nuevos
- [ ] .env.example actualizado
```

---

## 5. Documentación Obligatoria por Artefacto

Crear **el mismo día** que el artefacto. No al final del sprint.

| Artefacto | Archivo | Contenido mínimo |
|---|---|---|
| Modelo (BE) | `Documentacion/modelos/NombreModelo.md` | Propósito, campos, validaciones, asociaciones, scopes, reglas de negocio |
| Service (BE) | `Documentacion/servicios/NombreServicio.md` | Qué hace, parámetros, resultado, cuándo usarlo, dependencias |
| Concern (BE) | Comentario de módulo en el archivo | Qué agrega, cómo incluirlo, requisitos de columnas |
| Helper (BE) | Comentario de módulo en el archivo | Qué hace cada método público |
| Endpoint nuevo | Swagger via rswag | Parámetros, respuestas 200/422/401, ejemplos |
| Composable (FE) | `Documentacion/composables/useNombre.md` | Estado expuesto, funciones, cómo usarlo, dependencias |
| Componente complejo (FE) | Bloque JSDoc al inicio del `<script setup>` | Props, emits, slots, propósito |
| Service (FE) | Comentario de módulo en el archivo | Endpoints que cubre, auth requerido |
| Decisión de arquitectura | `Documentacion/ADR/ADR-00X-titulo.md` | Contexto, opciones, decisión, consecuencias |

### Template modelo BE

```markdown
# NombreModelo

**Tabla:** nombre_tabla  
**Módulo:** Dominio

## Propósito
Qué representa en el negocio. Una o dos líneas.

## Campos
| Campo | Tipo | Nulo | Descripción |
|---|---|---|---|
| nombre | string | no | ... |
| status | boolean | no | true = activo |

## Validaciones
- `validates :nombre, presence: true, length: { maximum: 120 }`
- `validates :clv, uniqueness: { scope: :client_id }`

## Asociaciones
- `belongs_to :client`
- `has_many :items, dependent: :destroy`

## Scopes
- `.activos` — where(status: true)
- `.para_cliente(id)` — where(client_id: id)

## Reglas de negocio
- Solo usuarios con rol coordinador pueden crear registros.
- El campo X no puede modificarse una vez aprobado.

## Historial
- 2026-04-25 — Creado para módulo de ruteo
```

### Template service BE

```markdown
# Services::Dominio::NombreServicio

## Qué hace
Una línea.

## Interfaz
\`\`\`ruby
resultado = Services::Dominio::NombreServicio.new(param1, param2).call
\`\`\`

## Parámetros
| Parámetro | Tipo | Descripción |
|---|---|---|
| param1 | Array<Model> | ... |

## Resultado
Hash: `{ exito: Boolean, datos: [...], errores: [] }`

## Cuándo usarlo
Solo desde [Job / Controller específico]. No llamar desde otro service.

## Dependencias
- `Services::Otro::Servicio`

## Historial
- 2026-04-25 — Creado para optimización de rutas
```

---

## 6. Testing — Cobertura Mínima 85%

### Regla
No se hace merge sin tests. No "los agrego después". Se escriben junto con el código.

### Qué testear por capa

**Modelos:** validaciones, asociaciones, scopes, métodos de instancia no triviales.

**Controllers/Requests:** happy path + error path (401, 404, 422) por cada acción.

**Services:** casos de éxito y casos de error con datos reales de BD.

**Concerns:** modelo anónimo que incluye el concern para aislar el test.

**Jobs:** que encolan correctamente y que el worker ejecuta la lógica esperada.

### Estructura de spec

```ruby
# frozen_string_literal: true
require 'rails_helper'

RSpec.describe NombreModelo, type: :model do
  # 1. Validaciones con shoulda-matchers
  # 2. Asociaciones con shoulda-matchers
  # 3. Scopes con datos reales (create, no build)
  # 4. Métodos de instancia con casos límite
end

RSpec.describe 'Api::V1::Recursos', type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }

  # Por cada acción: happy path + error path
  # auth_headers helper en spec/support/
  # json_body helper en spec/support/
end
```

### Correr con cobertura

```bash
# BE
COVERAGE=true bundle exec rspec
open coverage/index.html    # revisar qué falta

# No bajar del 85% — SimpleCov falla el build automáticamente
```

---

## 7. Calidad — Gates Antes de Merge

### Backend
```bash
bundle exec rubocop --parallel          # 0 offenses
COVERAGE=true bundle exec rspec         # 0 failures + ≥ 85%
bundle exec rake rswag:specs:swaggerize # swagger actualizado
```

### Frontend
```bash
npm run lint    # 0 errores (warnings en archivos nuevos = bloqueante)
npm run build   # build limpio sin warnings críticos
```

### Checklist universal pre-PR

- [ ] RuboCop / ESLint: 0 errores
- [ ] Tests: 0 failures, cobertura ≥ 85%
- [ ] Swagger actualizado si hay endpoints nuevos o modificados
- [ ] Documentación creada para cada artefacto nuevo
- [ ] `.env.example` actualizado con variables nuevas
- [ ] Sin `console.log`, `binding.pry`, `debugger`
- [ ] Sin `TODO` sin ticket
- [ ] Sin `params.permit!`
- [ ] Sin queries dentro de `.map` (N+1)
- [ ] Business Unit filtrado si aplica
- [ ] Vista móvil implementada si es pantalla nueva (FE)
- [ ] `usePrivileges` en acciones de escritura (FE)

---

## 8. Integración con Kumi — Checklist

Para todo proyecto que se conecte a Kumi como master hub:

- [ ] API Key creada con scope mínimo necesario (ver `INFRAESTRUCTURA_API.md`)
- [ ] `KUMI_API_URL` y `KUMI_API_KEY` en `.env.example` (sin valores reales)
- [ ] Endpoints del portal bajo namespace separado (`/api/v1/portal/` o `/api/v1/supplier_portal/`)
- [ ] Controller base propio que hereda de `ApplicationController` (no de `Api::V1::BaseController` de Kumi)
- [ ] Filtro de scope por `client_id` o `supplier_id` en TODOS los queries — nunca mezclar datos entre clientes
- [ ] Rate limiting configurado en Rack::Attack
- [ ] Logs de acceso por API Key

---

## 9. Planeación — Sprints y Milestones

### Estructura estándar de proyecto

```
Épica 1: [Nombre — área funcional grande]
  Milestone 1.1: MVP — lo mínimo que aporta valor
    Sprint 1 (2 semanas): [módulos concretos]
    Sprint 2 (2 semanas): [módulos concretos]
  Milestone 1.2: Versión completa
    Sprint 3...
Épica 2: ...
```

### Definition of Done — por historia de usuario

Una historia está terminada cuando:

1. ✅ El criterio de aceptación definido se cumple y se verificó manualmente
2. ✅ Tests escritos y pasando (cobertura ≥ 85%)
3. ✅ RuboCop / ESLint: 0 errores
4. ✅ Swagger actualizado (si hay endpoint nuevo)
5. ✅ Documentación del artefacto creada
6. ✅ Code review aprobado
7. ✅ Desplegado en staging y verificado
8. ✅ PR mergeado a `main`

### Definition of Done — por Sprint

Un sprint está cerrado cuando:

1. ✅ Todas las historias cumplen el DoD individual
2. ✅ Build de CI en verde (tests + lint)
3. ✅ Cobertura total no bajó vs. sprint anterior
4. ✅ Demo realizada o evidencia de pantalla tomada
5. ✅ Retrospectiva registrada (qué salió bien, qué mejorar)
6. ✅ Backlog del siguiente sprint priorizado

### Definition of Done — por Milestone / Entrega

1. ✅ Todos los sprints del milestone cumplen su DoD
2. ✅ Pruebas de integración end-to-end ejecutadas
3. ✅ Performance revisada (N+1 queries, tiempos de respuesta)
4. ✅ Seguridad revisada (auth, scope de API Keys, datos expuestos)
5. ✅ Documentación de usuario final creada si aplica
6. ✅ Deploy en producción exitoso
7. ✅ Monitoreo configurado (logs, alertas de error)

---

## 10. Checklist de Arranque — Nuevo Proyecto

Ejecutar en orden. No saltarse pasos.

### Día 1 — Definición

- [ ] ADR creado y aprobado (`Documentacion/ADR/ADR-00X.md`)
- [ ] PRD creado (`Documentacion/PRD_NOMBRE.md`)
- [ ] Stack definido y justificado en el ADR
- [ ] Repositorio creado con estructura base
- [ ] `CLAUDE.md` creado en la raíz
- [ ] `.env.example` creado con todas las variables conocidas
- [ ] `.gitignore` configurado (nunca commitear `.env`, `node_modules`, `coverage/`)

### Día 1-2 — Base técnica

- [ ] CI configurado (GitLab CI o GitHub Actions): lint + tests en cada push
- [ ] Rama `main` protegida: requerir PR + CI en verde para merge
- [ ] RuboCop / ESLint configurados con reglas del proyecto
- [ ] SimpleCov configurado con umbral 85%
- [ ] FactoryBot y helpers de test configurados

### Antes del primer endpoint real

- [ ] Autenticación implementada (JWT o API Key según el tipo)
- [ ] BaseController con `before_action :authenticate_request!`
- [ ] Manejo de errores global (`rescue_from` en ApplicationController)
- [ ] Swagger helper configurado (`spec/swagger_helper.rb`)
- [ ] Primer spec de request funcionando (aunque sea el 401 de auth)

### Antes del primer sprint de features

- [ ] Modelo de datos revisado contra los estándares
- [ ] Migraciones con nombres descriptivos y reversibles
- [ ] Factories para todos los modelos del sprint 1
- [ ] Primer endpoint documentado en Swagger
- [ ] Primera pantalla con vista móvil (FE)

---

## 11. Referencias

| Documento | Contenido |
|---|---|
| `ESTANDARES_API.md` | Controllers, respuestas, paginación, filtros, testing, Swagger |
| `ESTANDARES_FE.md` | Page pattern, composables, servicios, responsive |
| `INFRAESTRUCTURA_API.md` | API Keys, client_users, supplier_users, DB maestra |
| `CLAUDE.md` (raíz monorepo) | Docker, setup.sh, principios, gates de calidad |
| `ADR/` | Decisiones de arquitectura tomadas |
| `ttpngas/CLAUDE.md` | Reglas específicas del BE Rails |
| `ttpn-frontend/CLAUDE.md` | Reglas específicas del FE Vue/Quasar |
