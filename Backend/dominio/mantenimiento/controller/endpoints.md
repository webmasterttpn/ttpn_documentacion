# Endpoints — Dominio Mantenimiento

Base: `/api/v1/mtto`. Auth: JWT (usuario) o API Key. Controllers
`Api::V1::Mtto::*` heredan de `Api::V1::Mtto::BaseController` (paginación con
`meta`). Filtrado por BU vía `business_unit_filter`. Rutas en
`config/routes/maintenance.rb` (`draw :maintenance`).

Respuesta de colección: `{ data: [...], meta: { current_page, per_page,
total_count, total_pages } }`. Errores de validación: `{ errors: [...] }` (422).
No encontrado: `{ error: ... }` (404). Sin token: 401.

## CRUD (index/show/create/update/destroy)

| Recurso | Ruta | Notas |
|---|---|---|
| Categorías | `/mtto/categories` | filtros `is_active`, `search`; soft-delete |
| Presentaciones | `/mtto/pack_sizes` | catálogo seleccionable |
| Productos | `/mtto/products` | filtros `category_id`, `is_active`, `low_stock`, `search`; serializa stock/costo |
| Servicios | `/mtto/services` | catálogo con `standard_time_minutes` |
| Proveedor↔Producto | `/mtto/supplier_products` | filtros `supplier_id`, `product_id` |
| Recepciones | `/mtto/product_receipts` | nested `product_receipt_items_attributes` |
| Salidas | `/mtto/inventory_transfers` | nested `inventory_transfer_items_attributes` |
| Órdenes de Trabajo | `/mtto/work_orders` | nested `work_order_services_attributes`; filtros `status`, `active`, `mechanic_id` |

## Solo lectura

| Endpoint | Descripción |
|---|---|
| `GET /mtto/inventories` | Stock por producto (filtro `low_stock`) |
| `GET /mtto/inventories/:id` | Detalle de inventario |
| `GET /mtto/inventories/movements` | Libro append-only (filtros `product_id`, `movement_type`, `recent`) |

## Acciones (member, delegan a services)

| Endpoint | Service | Resultado |
|---|---|---|
| `POST /mtto/product_receipts/:id/complete` | `ReceiveProductService` | Entrada a inventario + costo promedio |
| `POST /mtto/inventory_transfers/:id/complete` | `TransferProductService` | Consumo (recuperado primero) + residuo |
| `POST /mtto/work_orders/:id/activate` | `WorkOrderProgressService` | draft → activated (admin, fase 1) |
| `POST /mtto/work_orders/:id/start` | id. | activated/paused → in_progress |
| `POST /mtto/work_orders/:id/pause` | id. | in_progress → paused |
| `POST /mtto/work_orders/:id/resume` | id. | paused → in_progress |
| `POST /mtto/work_orders/:id/complete` | `ReconcileMaterialsService` + id. | concilia residuo/scrap + → completed (`actual_minutes`) |
| `POST /mtto/work_orders/:id/cancel` | id. | → cancelled |

Transición/recepción/salida inválida → 422 `{ error: ... }`.

### `POST /mtto/work_orders/:id/complete` con conciliación de residuo/scrap

Acepta un body **opcional** `reconciliation` para conciliar el material
consumido al cerrar la OT (residuo recuperable vs. scrap no recuperable):

```text
{ "reconciliation": [
    { "transfer_item_id": 12, "residue": 3.0, "scrap": 2.0 }, ...
] }
```

- Corre `Mtto::ReconcileMaterialsService` (residuo → `quantity_recovered` $0 +
  movimiento `residue_return`; scrap → solo `quantity_scrapped`, no cambia
  stock) y luego la transición `complete`.
- Sin `reconciliation`: cierra con residuo/scrap = 0 (comportamiento previo).
- Errores → 422: línea ajena a la OT (`InvalidLine`), residuo + scrap mayor a lo
  consumido (`RecordInvalid`), o transición inválida.

Ver `services/ReconcileMaterialsService.md` y `costeo_liquidos.md`.

### `GET /mtto/work_orders/:id` (detalle, solo lectura)

`show(detailed: true)` para el diálogo "Ver detalle de OT" del FE. Además de los
campos base de la OT incluye:

```text
{
  ...campos base de la OT...,
  "vehicle": "CLV-001",                      # clv del vehículo (nil si externa)
  "services": [
    { "id", "service_id", "service", "estimated_time_minutes", "completed" }
  ],
  "materials": [                             # items de inventory_transfers.completed
    { "id", "product", "unit_of_measure",
      "quantity_transferred", "unit_cost_charged", "line_cost" }
  ],
  "materials_cost":        0.0,              # Σ line_cost (costo interno a costo promedio)
  "internal_market_value": 0.0,             # valor de mercado de los servicios
  "estimated_savings":     0.0              # ahorro estimado vs. cotización externa
}
```

Solo lectura: el detalle no permite agregar/quitar servicios a una OT iniciada
(decisión de diseño). `materials` proviene de las salidas de inventario
completadas asociadas a la OT; los totales de costo son métodos del modelo
`Mtto::WorkOrder` (`materials_cost`, `internal_market_value`, `estimated_savings`).

### `GET /mtto/work_orders/weekly_summary`

Resumen semanal de OT completadas para la vista de viabilidad
(`/finanzas/viabilidad`, tab "Servicios del Taller").

Params:

- `from` (ISO date, default: hace 8 semanas).
- `to` (ISO date, default: hoy).

Respuesta:

```text
{
  "from", "to",
  "weeks": ["2026-W18", "2026-W19", ...],   # eje ISO (lunes-domingo)
  "internal": {
    "totals_per_week": { "2026-W18": 4, ... },
    "services": [
      { "service_id", "service_name",
        "counts_per_week": { "2026-W18": 3, ... },
        "products": [
          { "product_id", "name", "unit", "sale_price",
            "per_week": { "2026-W18": { "qty", "cost", "avg_cost" }, ... } }
        ] }
    ]
  },
  "external": { ...,
    "per_week" extra de cada producto: { "qty", "cost", "avg_cost",
                                          "sale_price", "revenue", "profit" }
  }
}
```

Filtra por `Current.business_unit`, solo OTs `status='completed'` con
`completed_at` en el rango. La sección `external` agrega `revenue`
(`qty × sale_price`) y `profit` (`revenue − cost`) por celda para la
narrativa financiera del taller atendiendo clientes externos.

Servicio: `Mtto::WorkshopWeeklySummaryService`. Sin paginación
(rango temporal pequeño).

### `GET /mtto/work_orders/ops_kpis` (async — 202 + JobStatusChannel)

KPIs operativos del taller para el Dashboard de Viabilidad. Sigue el
estándar Python+async (ttpngas/CLAUDE.md):

- Responde **`202 Accepted`** con `{ job_id, status: 'queued', range }`.
- El job `Mtto::OpsKpisJob` ejecuta `scripts/mtto/workshop_ops_kpis.py`
  vía `EjecutarScriptPythonJob` (Open3).
- Al terminar hace broadcast a `job_status_#{user_id}` con
  `{ type: 'job_done', job_id, kind: 'mtto_ops_kpis', data }`.
- El FE filtra por `job_id` en `JobStatusChannel`. **Polling prohibido**.

Params (default últimos 6 meses): `from` (ISO date), `to` (ISO date).

Payload `data` del broadcast:

```text
{
  "range": { "from", "to" },
  "vehicles_per_week": { "2026-W18": 3, ... },
  "top_services":         [{ service_id, service_name, count }],
  "services_per_vehicle": [{ vehicle_id, label, services_count }],
  "mechanics":            [{ mechanic_id, name, hours, ot_count, services_count }],
  "top_overdue":          [{ work_order_id, work_order_number,
                             vehicle_label, mechanic_name,
                             estimated_minutes, actual_minutes,
                             excess_minutes, excess_pct, completed_at }]
}
```

Servicio: `scripts/mtto/workshop_ops_kpis.py` (Python). Detalles en
`Documentacion/Backend/dominio/mantenimiento/services/WorkshopOpsKpisService.md`.

## Tiempo real

Canal `MttoWorkOrdersChannel` → `stream_from "mtto_work_orders_#{bu_id}"`.
`Mtto::WorkOrder#after_update_commit` hace broadcast (`type:
work_order_changed`). El tablero FE se suscribe; **sin polling**.

Swagger: `spec/integration/api/v1/mtto/maintenance_spec.rb` →
`bundle exec rake rswag:specs:swaggerize` (rutas mtto en `swagger/v1/swagger.yaml`).
