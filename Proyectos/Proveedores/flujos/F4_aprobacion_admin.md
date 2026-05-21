# F4 — Aprobación o rechazo por admin

## Objetivo

El admin de Finanzas en Kumi revisa cada factura en `pending_match`,
le asigna un número de OC (texto libre por Fase 1), y decide si la
aprueba (programar pago) o la rechaza con nota visible para el
proveedor.

## Pasos

### 1. Admin abre la pantalla

UI: `/finanzas/proveedores/facturas`.

`InvoicesAdminPage.vue` lista todas las facturas con filtros por
proveedor, estatus, rango de fecha. Default muestra `pending_match` y
`in_review`.

### 2. Admin reconcilia con OC (Fase 1: texto libre)

Click en una factura → modal `MatchPurchaseOrderDialog.vue`:

```text
PATCH /api/v1/supplier_invoices/:id/match_purchase_order
{ "purchase_order_number": "OC-2026-088" }
```

Backend: update directo. `estatus: 'in_review'`. Registra audit
event (interno, no `SupplierAuditEvent`).

Cuando exista módulo OC (Fase 2), este campo será FK a
`PurchaseOrder` y se rellenará desde un dropdown searchable.

### 3a. Aprobación

Modal `InvoiceApproveDialog.vue` — el admin confirma:

```text
PATCH /api/v1/supplier_invoices/:id/approve
```

Backend:

1. `invoice.update!(estatus: 'approved', approved_by: current_user)`.
2. Registra `SupplierAuditEvent('invoice_approved')` con metadata
   `{ admin_user_id: current_user.id }`.

Después de aprobar, el admin programa fecha de pago (paso 4).

### 3b. Rechazo

Modal `InvoiceRejectDialog.vue` — pide motivo obligatorio (mínimo
15 caracteres):

```text
PATCH /api/v1/supplier_invoices/:id/reject
{ "rejection_note": "Falta el desglose de IVA. Reemite la factura." }
```

Backend:

1. `invoice.update!(estatus: 'rejected', rejected_by: current_user,
   rejection_note: ...)`.
2. Registra `SupplierAuditEvent('invoice_rejected')` con metadata
   `{ rejection_note: ... }`.

El proveedor verá la nota en el portal en su `InvoicesPage` (chip
rojo "Rechazada" + sección "Motivo del rechazo" en el detalle).

### 4. Programar pago (solo después de aprobar)

Modal `SchedulePaymentDialog.vue`:

```text
PATCH /api/v1/supplier_invoices/:id/schedule_payment
{ "fecha_pago": "2026-06-15" }
```

Backend:

1. `invoice.update!(estatus: 'scheduled', fecha_pago: ...)`.
2. Si `metodo_pago = 'PUE'` y el admin marca un checkbox "Ya está
   pagada" → setea `estatus = 'paid'` y `monto_pagado = monto_total`
   en lugar de `scheduled`. (Ver [F6_factura_PUE.md](F6_factura_PUE.md).)

## Casos de error

| Caso | Respuesta |
|---|---|
| Aprobar una factura `cancelled` o `paid` | 422 `{ error: "Estatus inválido para aprobación" }` |
| Rechazo sin nota | 422 `{ errors: ["Motivo es obligatorio (min 15 caracteres)"] }` |
| Admin sin privilegio `supplier_invoices_admin` | 403 |
| Programar fecha en el pasado | 422 `{ errors: ["Fecha de pago debe ser futura"] }` |

## Visibilidad para el proveedor

| Estatus en admin | Lo que ve el proveedor en `/facturas` |
|---|---|
| `pending_match` | Chip gris "Pendiente reconciliación" |
| `in_review` | Chip ámbar "En revisión" |
| `approved` | Chip verde "Aprobada" (sin fecha aún) |
| `scheduled` | Chip azul "Programada para pago" + fecha |
| `rejected` | Chip rojo "Rechazada" + tooltip con la nota |
| `paid` | Chip verde "Pagada" + fecha |

## Verificación

1. Como proveedor sube 1 factura PPD → queda `pending_match`.
2. Como admin entra a `/finanzas/proveedores/facturas`:
   - Marca OC `OC-2026-001` → estatus pasa a `in_review`.
   - Aprueba → estatus `approved`.
   - Programa pago para `2026-06-15` → estatus `scheduled`.
3. Cambia a otro tab del proveedor → refresca `/facturas` → ve
   "Programada para pago - 2026-06-15".
4. Repite con otra factura, esta vez la rechaza con nota
   "Falta IVA desglosado". Como proveedor ve chip rojo y la nota.
5. `SupplierAuditEvent` tiene los eventos con el admin user id.
