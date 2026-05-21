# F5 — Complemento de pago para factura PPD

## Objetivo

Cuando TTPN paga (en bancos / fuera del sistema) una factura PPD, el
proveedor está obligado por el SAT a emitir un **CFDI complemento de
pago** y subirlo al portal. El portal:

- Asocia el complemento a la factura PPD correcta.
- Suma el monto del complemento al `monto_pagado` de la factura.
- Si `monto_pagado >= monto_total` → estatus `paid`.
- Si todavía falta → estatus `partially_paid`.

Las facturas **PUE** no llevan complemento (ver
[F6_factura_PUE.md](F6_factura_PUE.md)).

## Pasos

### 1. Proveedor verifica que tiene facturas pagadas sin complemento

UI: en `InvoicesPage` filtra por estatus `scheduled` con `fecha_pago`
pasada (banner amarillo: "Tienes X pagos pendientes de complemento").

Otra ruta: `/cargar-facturas` → tab "Complemento de Pago".

### 2. Proveedor selecciona factura PPD y sube complemento

UI: selector dropdown de facturas PPD pagadas/programadas → drag XML
del complemento.

```text
POST /api/v1/portal/payments/:invoice_id/complements
Content-Type: multipart/form-data

xml: <archivo>
pdf: <archivo>   (opcional)
```

### 3. Backend procesa

`Api::V1::Portal::PaymentsController#create_complement`:

1. Verifica que la factura es PPD:

   ```ruby
   invoice = current_supplier_user.supplier.supplier_invoices.find(params[:invoice_id])
   render(json: { error: 'Las facturas PUE no llevan complemento' },
          status: :unprocessable_content) and return \
     if invoice.metodo_pago == 'PUE'
   ```

2. Parsea el XML del complemento CFDI: extrae `UUID complemento`,
   `fecha pago`, `monto`, `forma_pago_p`.
3. Verifica que `monto_pagado + complement.monto <= monto_total`
   (no sobrepasar).
4. Sube XML (y PDF si lo subió) a Supabase.
5. Crea `PaymentComplement` — el callback `after_create
   :recalculate_invoice_status` se encarga de:
   - `invoice.monto_pagado += complement.monto`
   - Si nuevo `monto_pagado >= monto_total`: `estatus = 'paid'`
   - Si no: `estatus = 'partially_paid'`
6. Crea `SupplierDocument(attachable: complement)`.
7. Registra `SupplierAuditEvent('complement_uploaded')`.
8. Responde 201 con `{ complement, invoice_status, monto_pagado, monto_pendiente }`.

### 4. Proveedor ve el estado actualizado

FE refresca → la factura ahora muestra:

- Chip teal "Pagada parcial" si quedan pagos
- Chip verde "Pagada" si quedó completa
- En el detalle: sección "Complementos" con cada complemento listado
  (UUID, fecha, monto).

## Casos de error

| Caso | Respuesta |
|---|---|
| Factura es PUE | 422 `{ error: "Las facturas PUE no llevan complemento" }` |
| Factura no pertenece al supplier_user (otro proveedor) | 404 |
| Monto del complemento haría sobrepasar `monto_total` | 422 `{ error: "Monto excede el saldo pendiente" }` |
| UUID complemento duplicado | 422 `{ error: "UUID de complemento ya registrado" }` |
| XML inválido / no parsea | 422 `{ error: "XML inválido" }` |
| El XML no tiene nodo `pago10:Pagos` | 422 `{ error: "El XML no es un complemento de pago" }` |

## Efecto en el semáforo

El semáforo de confirmación de pagos
([F7_semaforo_pagos.md](F7_semaforo_pagos.md)) recalcula al crear el
complemento. Si el proveedor pone al día sus complementos, su color
mejora.

## Verificación

1. Como admin: ten una factura PPD en `scheduled` con
   `monto_total = 10000`, `monto_pagado = 0`.
2. Como proveedor en el portal: sube un complemento de `5000`.
3. Backend: `monto_pagado = 5000`, estatus `partially_paid`.
4. Como proveedor: sube otro complemento de `5000`.
5. Backend: `monto_pagado = 10000`, estatus `paid`.
6. Verifica `payment_complements.count == 2` y los dos están
   listados en el detalle.
7. Verifica que el semáforo del proveedor mejora (si era amarillo,
   pasa a verde).
