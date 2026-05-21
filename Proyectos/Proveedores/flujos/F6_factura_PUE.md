# F6 — Factura PUE (Pago en Una Exhibición)

## Objetivo

Las facturas con `metodo_pago = PUE` se pagan al momento o ya están
pagadas, **no llevan complemento**. El CFDI original con el método PUE
es la confirmación al SAT. El portal trata estas facturas con un
flujo abreviado.

## Diferencias con PPD

| Aspecto | PUE | PPD |
|---|---|---|
| Requiere complemento de pago | **NO** | SÍ, uno por exhibición |
| Estatus al aprobarse | puede ir directo a `paid` | va a `scheduled` y espera complementos |
| Confirmación al SAT | el propio CFDI | CFDI complemento(s) |
| Forma de pago | siempre especificada en CFDI (01, 03, etc.) | en CFDI puede ser "99 Por definir"; se aclara en el complemento |

## Pasos del flujo PUE

### 1. Proveedor sube factura PUE (mismo bulk upload de F3)

`POST /portal/invoices/bulk_upload` — el parser detecta
`metodo_pago = PUE` del XML y lo guarda en `supplier_invoices.metodo_pago`.

Estatus inicial: `pending_match` (igual que cualquier otra).

### 2. Admin reconcilia con OC

`PATCH /supplier_invoices/:id/match_purchase_order` → `in_review`.

### 3. Admin aprueba y registra el pago

UI: `InvoiceApproveDialog.vue` para PUE incluye un checkbox extra
"Pago ya realizado (PUE)". Si se marca:

```text
PATCH /api/v1/supplier_invoices/:id/approve
{ "mark_paid_now": true, "fecha_pago": "2026-05-21", "forma_pago": "03" }
```

Backend:

```ruby
def approve
  attrs = { estatus: 'approved', approved_by: current_user }

  if @invoice.metodo_pago == 'PUE' && params[:mark_paid_now]
    attrs[:estatus] = 'paid'
    attrs[:fecha_pago] = params[:fecha_pago] || Date.current
    attrs[:forma_pago] = params[:forma_pago] if params[:forma_pago].present?
    attrs[:monto_pagado] = @invoice.monto_total
  end

  @invoice.update!(attrs)
  # ... audit ...
end
```

Resultado: la factura PUE queda directamente `paid` con la fecha real.
No se generan complementos.

### 4. Si admin no marca "mark_paid_now"

Sigue el flujo normal: aprueba → programa fecha → cuando TTPN paga,
el admin actualiza `fecha_pago` real y cambia estatus a `paid`
manualmente (NO espera complemento del proveedor).

```text
PATCH /api/v1/supplier_invoices/:id/schedule_payment
{ "fecha_pago": "2026-06-01", "mark_paid": false }
```

Luego cuando se concrete:

```text
PATCH /api/v1/supplier_invoices/:id/mark_paid
{ "fecha_pago_real": "2026-05-30" }
```

(Endpoint adicional `mark_paid` específico para PUE — el dev lo
implementa siguiendo el patrón de `schedule_payment`.)

### 5. Visibilidad para el proveedor

En `InvoicesPage`:

- PUE pagada: chip verde "Pagada" + fecha + forma de pago.
- En el detalle: sección "Confirmación" con texto "Esta factura PUE
  no requiere complemento de pago según SAT. El CFDI original es la
  confirmación."

El portal NO le pide al proveedor subir nada adicional para PUE.

## Validación que NO debe pasar

Si un proveedor (por error) intenta subir un complemento contra una
factura PUE:

```text
POST /api/v1/portal/payments/:invoice_id/complements (con invoice PUE)
```

Backend rechaza con 422 y mensaje explicativo:

```json
{
  "error": "Las facturas PUE no requieren complemento de pago. El CFDI original ya cuenta como confirmación al SAT."
}
```

## Efecto en el semáforo

Las facturas PUE pagadas se consideran **siempre confirmadas** por el
proveedor (porque emitir CFDI con `PUE` ya es la confirmación). Por
eso `SupplierInvoice#confirmed_by_supplier?` devuelve `true`
automáticamente para PUE `paid`.

Esto significa que un proveedor que solo trabaja con PUE tendrá
semáforo VERDE por default (no tiene complementos pendientes).

## Verificación

1. Sube una factura con `metodo_pago = PUE` (genera un CFDI dummy
   con ese atributo si no tienes uno real).
2. Como admin: marca OC, aprueba con checkbox "Pago ya realizado".
3. Verifica `estatus = paid`, `monto_pagado == monto_total`,
   `fecha_pago` registrada.
4. Verifica que `SupplierInvoice#confirmed_by_supplier?` devuelve
   `true`.
5. Verifica que el portal NO permite subir complemento contra esa
   factura (422 con mensaje claro).
6. Sube otra PUE pero NO marques "Pago ya realizado" → queda
   `approved`. Programa pago y luego `mark_paid` cuando se concrete.
