# 2026-06-01 — Lectura abierta de catálogos para dropdowns de captura

## Problema reportado

En el **área de captura**, el dropdown de `ttpn_service_type` devolvía **403** y
quedaba vacío. Síntoma general: los catálogos de referencia usados en los
formularios de captura (TB, TC, vehículos, RR.HH.) fallaban si el rol no tenía
el privilegio de gestión de ese catálogo.

## Diagnóstico

El 403 viene de `EnforceModulePrivileges` (fail-closed,
`app/controllers/concerns/enforce_module_privileges.rb`):

1. Catálogos **mapeados** (p. ej. `ttpn_service_type`, `ttpn_foreign_destiny`):
   `index` exigía `can?(module_key, :access)`. Roles operativos (capturista,
   coordinador) solo tienen `ttpn_bookings_capture`, `travel_counts`,
   `dashboard` → el `GET` del dropdown daba `FORBIDDEN_PRIVILEGE`.
2. Catálogos **sin mapeo** (`employee_movement_types`, `vehicle_types`,
   `vehicle_type_prices`, `employee_document_types`, `invoice_types`): daban
   `FORBIDDEN_NO_MAPPING` a todo rol no-sadmin.

Distinción clave (la marcó el usuario): **una cosa es el privilegio para ver el
menú/listado de gestión del catálogo; otra es que los dropdowns de captura
puedan leerlo**. Los dropdowns solo necesitan lectura.

## Decisión

Abrir lectura en el BE (no migración de datos por rol). En
`EnforceModulePrivileges` se agregó:

- `READ_ONLY_ACTIONS = {index, show}`.
- `CATALOG_READ_OPEN_CONTROLLERS`: set de controllers de catálogo/dropdown.
- Early-return en `enforce_module_privileges`: si la acción es `index`/`show`
  sobre un controller del set, pasa sin exigir privilegio.

**Sin cambios:** escritura (`create`/`update`/`destroy`) sigue gateada por
`module_key`; filtro de Business Unit sigue aplicando; visibilidad de menús la
controla el FE vía `usePrivileges`.

## Alcance (confirmado con el usuario)

Catálogos TTPN, vehiculares, RR.HH., facturación, proveedores/gas, mantenimiento
y entidades operativas usadas como dropdowns (clients, branch_offices,
employees, vehicles, users). Detalle completo en
`Backend/dominio/configuracion/usuarios_permisos/enforce_module_privileges.md`.

## Entregables

- `app/controllers/concerns/enforce_module_privileges.rb` — lógica.
- `spec/concerns/enforce_module_privileges_spec.rb` — 41 ejemplos, 0 fallos.
- RuboCop: 0 offenses.
- PR: webmasterttpn/kumi-admin-api **#25** (`fix/be-catalog-dropdowns-read-open` → `stage`).
- PR release **#26** (`stage` → `main`).

## Follow-up — auditoría de dropdowns de TODOS los módulos

Tras el #25 se auditó el FE (mtto, vehículos, RR.HH., finanzas, gas, clientes,
bookings, ruteo) mapeando cada `q-select` que carga datos de un endpoint. Se
encontraron 2 fuentes de dropdown que seguían dando 403:

- `business_units` — dropdown "Unidad de Negocio" en EmployeeForm/VehicleForm.
- `mtto/work_orders` — dropdown "Orden de Trabajo" en TransferForm.

Ambos agregados a `CATALOG_READ_OPEN_CONTROLLERS` (solo index/show; escritura y
filtro BU intactos). Finanzas (`finance/concepts`, `finance/projects`) NO se
abrió: comparte `module_key` con sus propios forms y es dato sensible.

- Specs: 43 ejemplos, 0 fallos. RuboCop: 0 offenses.
- PR follow-up **#27** (`fix/be-catalog-dropdowns-read-open-2` → `stage`); el
  release #26 lo recoge al mergear a stage.

## Pendiente / seguimiento

- Merge `stage → main` para que Railway despliegue (bump patch automático por
  prefijo `fix/`).
- Si en el futuro se agrega **crear catálogo inline** desde captura, esa acción
  seguirá requiriendo el privilegio de `create` del módulo (o habrá que
  manejarla aparte) — el fix actual solo cubre lectura.
- Catálogos sin mapeo (`employee_movement_types`, `vehicle_types`, etc.) tienen
  lectura abierta, pero su **gestión** (create/update/destroy) sigue dando
  `NO_MAPPING`. Si se quiere administrarlos desde UI, agregarlos a
  `CONTROLLER_MODULE_MAP` con su `module_key`.
- ⚠️ Seguridad: el remote `github` local tiene un PAT embebido en la URL. Si se
  va a compartir el repo/config, conviene rotar ese token y usar credential
  helper.
