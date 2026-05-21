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
| `POST /mtto/work_orders/:id/complete` | id. | → completed (calcula `actual_minutes`) |
| `POST /mtto/work_orders/:id/cancel` | id. | → cancelled |

Transición/recepción/salida inválida → 422 `{ error: ... }`.

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

## Tiempo real

Canal `MttoWorkOrdersChannel` → `stream_from "mtto_work_orders_#{bu_id}"`.
`Mtto::WorkOrder#after_update_commit` hace broadcast (`type:
work_order_changed`). El tablero FE se suscribe; **sin polling**.

Swagger: `spec/integration/api/v1/mtto/maintenance_spec.rb` →
`bundle exec rake rswag:specs:swaggerize` (rutas mtto en `swagger/v1/swagger.yaml`).
