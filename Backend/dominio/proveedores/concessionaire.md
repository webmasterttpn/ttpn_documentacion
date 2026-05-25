# Concessionaire (Concesionario)

Concesionario (persona/entidad propietaria de unidades). Es **global**: un mismo
concesionario puede pertenecer a **varias unidades de negocio** vía la tabla
HABTM `business_units_concessionaires`.

## Campos principales

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `nombre` | string | Requerido. Nombre o razón social |
| `a_paterno`, `a_materno` | string | Apellidos (personas físicas) |
| `contacto`, `telefono`, `email` | string | Datos de contacto |
| `rfc` | string | RFC (opcional). Clave principal para detectar duplicados |
| `canonical_name` | string | Slug heredado de seeds (no se usa en lógica) |

## Asociaciones

- `has_and_belongs_to_many :business_units` — visibilidad por unidad de negocio
- `has_and_belongs_to_many :clients`
- `has_and_belongs_to_many :vehicles`
- `has_many :employees`

## Scopes

- `by_current_business_unit` — filtra por `Current.business_unit`. Devuelve
  `none` si no hay BU activa. **No** hace bypass para sadmin: un usuario solo ve
  los concesionarios ligados a su unidad. (Para ver todos, se cambia el contexto
  de BU o se liga el concesionario a esa unidad.)

## Reglas de negocio — deduplicación cross-BU

Un concesionario no debe duplicarse entre unidades de negocio. Métodos de clase:

- `Concessionaire.normalize_full_name(nombre, a_paterno, a_materno)` — nombre
  completo normalizado (sin acentos, minúsculas, espacios colapsados).
- `Concessionaire.find_duplicate(nombre:, a_paterno:, a_materno:, rfc:, excluding_id:)`
  — busca un equivalente en **toda** la organización (sin filtrar por BU):
  1. Si trae `rfc` → match por RFC (ignora mayúsculas/espacios).
  2. Si no → match por nombre completo normalizado.

## Endpoints

`config/routes/vehicles.rb` → `resources :concessionaires` + member
`post :assign_business_unit`.

| Método | Ruta | Notas |
| --- | --- | --- |
| GET | `/api/v1/concessionaires` | Lista filtrada por BU actual |
| GET | `/api/v1/concessionaires/:id` | Detalle |
| POST | `/api/v1/concessionaires` | Crear (con deduplicación, ver abajo) |
| PATCH | `/api/v1/concessionaires/:id` | Actualizar |
| DELETE | `/api/v1/concessionaires/:id` | Eliminar |
| POST | `/api/v1/concessionaires/:id/assign_business_unit` | Liga un concesionario existente a la BU actual (idempotente) |

### POST create — comportamiento de deduplicación

1. Busca duplicado con `find_duplicate` (RFC → nombre).
2. Si **existe en la unidad actual** → `422` `{ error: 'Ya existe este concesionario en tu unidad de negocio' }`.
3. Si **existe en otra(s) unidad(es)** → `409` con cuerpo
   `{ "code": "concessionaire_exists", "message": "Ya existe…", "concessionaire": { "id", "business_units" } }`.
   El FE muestra "ya existe en X, ¿asignarlo a esta unidad?" y, al confirmar,
   llama `assign_business_unit`.
4. Si **no existe** → crea y liga la BU actual → `201`.

### Asignación de varias unidades de negocio (solo super admin)

- `concessionaire_params` permite `business_unit_ids: []` **solo si `current_user.sadmin?`**
  (defensa en profundidad; hoy además el `Ability` exige sadmin para gestionar).
- **Crear**: si el sadmin manda `business_unit_ids`, el concesionario queda ligado
  a esas unidades. Si no manda ninguna, se liga por defecto a la unidad actual
  (`ensure_default_business_unit`).
- **Editar** (`PATCH`): `business_unit_ids` **reemplaza** la colección de unidades.
  Un no-sadmin no puede modificarlas (se ignora el parámetro).
- FE: el multi-select de unidades aparece solo para sadmin (`isSuperAdmin`); en
  edición precarga las unidades actuales, en alta preselecciona la unidad activa.

## Frontend

- `src/pages/VehicleCatalogs/ConcessionairesPage.vue` — `onSubmit` maneja el `409`
  y dispara el diálogo de confirmación → `concessionairesService.assignBusinessUnit(id)`.
- `src/services/catalogs.service.js` → `concessionairesService.assignBusinessUnit(id)`.
