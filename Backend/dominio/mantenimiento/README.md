# Dominio Mantenimiento — Control de Inventario de Taller

Módulo dentro del monolito `ttpngas` (no repo independiente — ver ADR-001 y
existencia previa de modelos de mantenimiento como `ScheduledMaintenance`).

## Alcance (Fase 1)

- **Catálogos:** Categorías, Presentaciones (`PackSize`), Productos, Servicios de taller.
- **Proveedor ↔ Producto:** reutiliza la tabla `suppliers` existente.
- **Recepción:** entrada a inventario con conversión presentación→unidad base y
  recálculo de **costo promedio móvil**.
- **Inventario:** stock por producto con dos cubetas — `quantity_on_hand`
  (a costo promedio) y `quantity_recovered` (residuo reutilizable, $0).
- **Movimientos:** libro auditable **append-only**.
- **Órdenes de Trabajo:** un mecánico (`Employee`) por OT, servicios con tiempo
  estándar, ciclo de estados y **tablero de monitoreo en vivo** (ActionCable).
- **Salidas:** consumo departamental o contra OT; **método de costo hundido**
  para residuo de líquidos.

## Decisiones de diseño

| SQL original (autónomo) | Implementación Kumi |
|---|---|
| `CREATE SCHEMA mtto` | Esquema `public`, tablas `mtto_*` (namespace `Mtto::`) |
| Triggers PL/pgSQL | Services Rails en transacción |
| Vistas SQL | Scopes + métodos de modelo + serializers |
| `created_by_id` sueltos | concern `Auditable` |
| Sin `business_unit_id` | `business_unit_id` + `BusinessUnitAssignable` |
| `pack_size INT` | Catálogo `mtto_pack_sizes` (FK) |
| `sku` único | `sku` + **`clv`** (clave corta de taller) |
| `cost_price` plano | **Costo promedio móvil** en `mtto_inventories.average_cost` |

## Archivos

- `model.md` — modelos, validaciones, asociaciones, scopes, reglas de negocio.
- `schema.sql` — DDL de referencia (fuente operativa: migraciones + `db/schema.rb`).
- `costeo_liquidos.md` — método de costo hundido (inventario y contabilidad).
- `controller/endpoints.md` — endpoints REST.
- `services/README.md` — services del dominio.

## Diferido a Fase 2

Órdenes de Compra, Historial de Costos, Conteos cíclicos, analítica JIT/spending,
PWA de mecánicos + sugerencias de servicios (columnas aditivas en
`mtto_work_order_services`).
