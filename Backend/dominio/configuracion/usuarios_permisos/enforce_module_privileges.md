# Concern: EnforceModulePrivileges

`app/controllers/concerns/enforce_module_privileges.rb`

## Qué hace

`before_action` global incluido en `Api::V1::BaseController`. Valida que
`current_user` tenga el privilegio adecuado para cada combinación
`(controller, action)`. Es **fail-closed**: lo no declarado se rechaza con 403.

## Orden de evaluación

1. `skip_privilege_check?` — pasa si: controller en `PUBLIC_CONTROLLERS`,
   request por API Key, bypass de tests (`Rails.env.test?` sin
   `Current.enforce_privileges`), o `current_user.sadmin?`.
2. `SADMIN_ONLY_CONTROLLERS` — solo sadmin; resto → 403.
3. **Catálogos de lectura abierta** (ver abajo) — si la acción es `index`/`show`
   sobre un controller de catálogo, pasa sin exigir privilegio.
4. `CONTROLLER_MODULE_MAP` no contiene la clase → 403 `FORBIDDEN_NO_MAPPING`.
5. `module_key == '__authenticated_only__'` / `'__public__'` → pasa.
6. `can?(module_key, required_permission)` → pasa o 403 `FORBIDDEN_PRIVILEGE`.

## Catálogos de lectura abierta (dropdowns de captura)

Constantes: `CATALOG_READ_OPEN_CONTROLLERS` + `READ_ONLY_ACTIONS` (`index`, `show`).

**Problema que resuelve:** las pantallas de captura (TB, TC, vehículos, RR.HH.)
llenan dropdowns leyendo catálogos de referencia. Antes, si el rol no tenía el
privilegio de **gestión** de ese catálogo (p. ej. `ttpn_service_type`), el
`GET` del dropdown devolvía 403 y el select quedaba vacío. Además varios
catálogos (`employee_movement_types`, `vehicle_types`, `employee_document_types`,
`invoice_types`) **no estaban mapeados** → daban 403 `NO_MAPPING` a todo rol
no-sadmin.

**Regla:** un usuario autenticado siempre puede **leer** (`index`/`show`) un
catálogo de referencia para llenar dropdowns, aunque no administre ese catálogo.

**Lo que NO cambia:**
- `create` / `update` / `destroy` (y demás acciones de escritura) siguen
  protegidos por el `module_key` en `CONTROLLER_MODULE_MAP` — la **gestión** del
  catálogo sigue gateada.
- El filtro de **Business Unit** del propio controller sigue aplicando: abrir la
  lectura no salta el scope por BU.
- La visibilidad del **menú/listado de gestión** la controla el FE vía
  `usePrivileges(module_key)`; abrir la lectura en el BE no expone menús.

### Controllers con lectura abierta

| Grupo | Controllers |
|---|---|
| Servicios TTPN | `TtpnServiceTypes`, `TtpnServices`, `TtpnForeignDestinies`, `TtpnServiceDriverIncreases`, `TtpnServicePrices` |
| Vehículos (catálogos) | `VehicleMakes`, `VehicleTypes`, `VehicleTypePrices`, `VehicleDocumentTypes`, `DriversLevels`, `Concessionaires` |
| RR.HH. (catálogos) | `EmployeeMovementTypes`, `EmployeeDocumentTypes`, `Labors` |
| Facturación / otros | `InvoiceTypes`, `ReviewPoints` |
| Proveedores / gas | `Suppliers`, `GasStations` |
| Mantenimiento (catálogos) | `Mtto::Categories`, `Mtto::PackSizes`, `Mtto::Products`, `Mtto::SupplierProducts`, `Mtto::Services`, `Mtto::WorkOrders` (dropdown de OT en traspasos) |
| Organización | `BusinessUnits` (dropdown de UN en forms de empleado/vehículo) |
| Entidades operativas (dropdowns captura, filtradas por BU) | `Clients`, `ClientBranchOffices`, `Employees`, `Vehicles`, `Users` |

> **No abiertos a propósito:** `Finance::Concepts` / `Finance::Projects`. Comparten
> `module_key` (`finance_projects`) con sus propios forms, así que quien abre el
> form ya tiene el privilegio; y es dato sensible. Si un rol tiene
> `finance_project_viability` pero no `finance_projects`, otorgar ambos en lugar
> de abrir la lectura global.

> Para agregar un catálogo nuevo a los dropdowns de captura: añadir su controller
> a `CATALOG_READ_OPEN_CONTROLLERS`. No hace falta tocar roles ni correr
> migración de datos.

## Tests

`spec/concerns/enforce_module_privileges_spec.rb`. Para probar el comportamiento
real de los gates: `Current.enforce_privileges = true` en el `before`.
