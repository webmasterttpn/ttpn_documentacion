# Acceso al módulo de Mantenimiento para el Taller de Camiones (multi-BU)

> **Estado: PARCIALMENTE IMPLEMENTADO (2026-05-25).** Backend de visibilidad cross-BU **listo**:
> la relación `Vehicle#serviceable_business_units` + los endpoints `GET /vehicles/serviceable`
> (picker) y `POST /vehicles/assign_serviceable` (asignación masiva, sadmin). Queda pendiente el
> **setup operativo** (crear la BU del taller, rol/privilegios, usuarios), correr la **migración en
> prod**, y la **UI del FE** (picker en la OT + pantalla de asignación masiva).

## Contexto / problema

La empresa tiene un **taller de camiones** y quiere darle acceso al módulo de **Mantenimiento**
para que lleve su propio control (inventario, órdenes de trabajo, servicios). La duda original:
¿basta con **crear una unidad de negocio (BU)** o hay que volver **multitenant** las tablas `mtto_*`?

## Hallazgo: `mtto` ya es completamente multitenant

No hay que tocar las tablas. El módulo ya aísla por `business_unit_id`:

- **Todos los modelos padre** (`Mtto::Category`, `PackSize`, `Product`, `Service`,
  `SupplierProduct`, `Inventory`, `InventoryMovement`, `ProductReceipt`, `WorkOrder`,
  `InventoryTransfer`) incluyen el concern `BusinessUnitAssignable` y tienen `business_unit_id`.
  Las tablas de detalle (`*_items`, `work_order_services`) heredan la BU del padre.
- **Los catálogos son por BU** (índices únicos `(campo, business_unit_id)` en products/services/
  categories/pack_sizes). ⇒ **una BU nueva arranca con catálogo vacío.**
- Los controllers filtran con `.business_unit_filter`
  (`app/models/concerns/business_unit_assignable.rb:15`) y los de mtto **no usan CanCanCan** — solo
  autenticación + scope por BU (`app/controllers/api/v1/mtto/work_orders_controller.rb`). Por eso el
  `return unless user&.sadmin?` de `Ability` **no bloquea** mtto.
- El tiempo real ya está scopeado: canal `mtto_work_orders_#{business_unit_id}`
  (`app/models/mtto/work_order.rb:106`, `app/channels/mtto_work_orders_channel.rb:14`).

**Conclusión:** crear una BU para el taller de camiones es el enfoque correcto y, a nivel de datos,
**suficiente**. NO se modifican las tablas `mtto_*`.

## Decisiones de negocio tomadas

- **Vehículos que atiende:** la **flota de la empresa** (camiones que viven en otra BU,
  p. ej. TTPN / TTPN-E).
- **Catálogo del taller:** **propio desde cero** (no se comparte ni se copia el de TTPN).

## Visibilidad cross-BU de vehículos (IMPLEMENTADO)

Como el taller atiende camiones de la **flota (otra BU)**, surge un detalle: la OT
(`Mtto::WorkOrder`) ya **acepta `vehicle_id` de cualquier BU** (no hay validación de BU;
`work_order.rb:12`), pero `Vehicle.business_unit_filter` (ahora **solo** por `business_unit_id`)
**oculta** los vehículos de otras BU. Se resolvió con una **relación dedicada a nivel vehículo**:

**`Vehicle#serviceable_business_units`** (HABTM, tabla `vehicle_serviceable_business_units`):

- Indica **qué BUs pueden atender** cada vehículo, además de su BU dueña. Es una relación dedicada
  (no se sobrecarga "concesionario"), por lo que **no ensucia** ningún listado ni se acopla a un
  concepto comercial.
- **Auto-fill al crear:** un `after_create` agrega la BU donde se da de alta el vehículo
  (`Current.business_unit`). **Backfill** (migración `20260525000001`): cada vehículo existente quedó
  atendible por su BU dueña (toda la data actual = BU 1).
- **Para habilitar el taller:** se agregan los camiones a atender con
  `vehiculo.serviceable_business_units << bu_taller` (puntual o en lote por tipo "Camion").
- **El vehículo sigue perteneciendo a su BU dueña**; solo se **agrega** quién más lo atiende. La OT
  guarda ese `vehicle_id` (ya acepta cualquier BU). No se duplica ni re-etiqueta el dueño.

**Consumo (IMPLEMENTADO):** endpoints en `Api::V1::VehiclesController`
(ver `Documentacion/Backend/dominio/vehicles/controller/endpoints.md`):

- `GET /api/v1/vehicles/serviceable` — lista los vehículos que la BU activa puede atender
  (su BU dueña + concedidos). Filtros: `vehicle_type_id`, `search`, `include_inactive`. Es lo
  que debe usar el **picker de vehículo de la OT** del taller (en vez del listado por BU dueña).
- `POST /api/v1/vehicles/assign_serviceable` (**solo sadmin**) — asigna/revoca en lote una BU de
  servicio. Caso típico: *todos los "Camion" de TTPN → atendibles por la BU del taller*
  (`service_business_unit_id` + `owner_business_unit_id` + `vehicle_type_id`). Resuelve el dolor
  de etiquetar uno por uno.
- En edición individual de un vehículo (`PATCH /api/v1/vehicles/:id`) un sadmin puede mandar
  `serviceable_business_unit_ids: []`.

**Trade-off asumido:** la relación a nivel vehículo es **granular** (puedes excluir unidades) a costo
de **etiquetar** cada camión que el taller deba ver. Para flotas grandes, mitigar con una **acción de
asignación masiva** (todos los "Camion" de BU X → atendibles por BU taller) y/o un **default por tipo**.

**Por qué NO se usó el concesionario (regla B, eliminada):** habría que ligar el concesionario de
CADA camión a la BU del taller y re-ligar cada camión nuevo; además, al compartirse concesionarios
entre BUs, ensuciaba el listado de vehículos de las BUs dueñas. Por eso se eliminó la regla B y se
creó la relación dedicada.

## Setup necesario (sin código nuevo, salvo lo anterior)

1. Crear la `BusinessUnit` del taller (p. ej. `clv: 'TALLERC'`, nombre "Taller de Camiones").
2. `KumiSetting.initialize_defaults(bu.id)` + setear `mtto.serviceable_business_unit_ids`.
3. Crear el rol `mantenimiento` para esa BU (patrón `db/seeds/02_roles_vehicles_services.rb`) y
   asignarle los privilegios de mtto (`mtto_inventory, mtto_products, mtto_categories, mtto_pack_sizes,
   mtto_services, mtto_receipts, mtto_transfers, mtto_work_orders, mtto_work_orders_monitor` — los
   siembra `db/migrate/20260519000007_seed_mtto_privileges_and_categories.rb`) vía el patrón de
   `db/seeds/04_role_privileges.rb`.
4. Crear usuarios del taller con `business_unit_id` = BU del taller + rol `mantenimiento`
   (quedan fijos a su BU; ven solo su mtto; el FE muestra el menú por los privilegios asignados).
5. El taller captura su catálogo desde cero por la UI existente (per-BU).

## Pendiente / decisión de reporting (no bloqueante)

Las OT del taller quedan bajo **su** BU; el dashboard de la BU dueña del camión (TTPN/TTPN-E),
filtrado por su propia BU, **no verá** ese mantenimiento. Si se quiere que la BU dueña también lo
vea, agregar después un **reporte cross-BU "mantenimiento por vehículo"** (consulta por `vehicle_id`,
no por BU). No bloquea el acceso del taller.

## Lo que NO se hace

- No se modifican las tablas `mtto_*` ni su filtrado por BU (ya multitenant).
- No se comparte catálogo entre talleres (cada taller, su catálogo por BU).
- No se mueve la flota de camiones a la BU del taller (siguen en su BU operativa).

## Archivos relevantes (referencia para cuando se implemente)

- `ttpngas/app/models/vehicle.rb:41` — `business_unit_filter` (el endpoint mtto NO lo usa).
- `ttpngas/app/models/mtto/work_order.rb:12` — `vehicle_id` opcional, sin validación de BU.
- `ttpngas/app/controllers/api/v1/mtto/` + `config/routes/mtto.rb` — endpoint `serviceable_vehicles`.
- `ttpngas/app/models/kumi_setting.rb` — key `mtto.serviceable_business_unit_ids`.
- `ttpngas/db/seeds/02_roles_vehicles_services.rb`, `04_role_privileges.rb`,
  `db/migrate/20260519000007_*` — patrón BU/rol/privilegios.
