# F3 — Bulk upload de facturas (hasta 40 por carga)

## Objetivo

El proveedor sube en una sola operación los PDF + XML de hasta 40
facturas. El sistema valida cada par, sube a Supabase y crea
`SupplierInvoice` en estado `pending_match`. Si alguna falla
(duplicada, tamaño, formato), se reporta sin abortar las demás.

## Pasos

### 1. Proveedor abre uploader

UI: `/cargar-facturas` (`UploadInvoicesPage.vue`).

Drag-and-drop o file picker → seleccionar PDF y XML. El FE intenta
**aparear** automáticamente por nombre de archivo similar
(`factura_T5403.pdf` ↔ `factura_T5403.xml`). Cada par o single
aparece como una "fila" con check de validación local:

- ✓ PDF + XML emparejados
- ⚠ Solo XML (el sistema acepta — el PDF es opcional)
- ✗ Solo PDF (rechazo — sin XML no podemos parsear el CFDI)
- ✗ Tamaño > 10 MB
- ✗ Más de 40 archivos

### 2. Click "Subir todo"

```text
POST /api/v1/portal/invoices/bulk_upload
Content-Type: multipart/form-data

invoices[0][pdf]: <archivo>
invoices[0][xml]: <archivo>
invoices[1][pdf]: <archivo>
invoices[1][xml]: <archivo>
...
```

### 3. Backend procesa par por par

`Api::V1::Portal::InvoicesController#bulk_upload`:

```ruby
def bulk_upload
  results = { uploaded: 0, rejected: 0, rejections: [] }

  params[:invoices].each do |pair|
    begin
      process_pair(pair)
      results[:uploaded] += 1
    rescue StandardError => e
      results[:rejected] += 1
      results[:rejections] << { filename: pair[:xml]&.original_filename,
                                  reason: e.message }
    end
  end

  render json: results, status: :created
end
```

Cada `process_pair` hace:

1. Parsea el XML mínimo: extrae `UUID`, `folio`, `total`, `moneda`,
   `metodo_pago`, `forma_pago`, `fecha emisión`.
   Usar `Nokogiri::XML` y consultar atributos del nodo
   `cfdi:Comprobante` + `tfd:TimbreFiscalDigital`.
2. Verifica que el `UUID` no exista ya en `supplier_invoices` (índice
   único).
3. Verifica que el RFC del emisor del XML coincida con un
   `SupplierIdentifier` del proveedor logueado (futuro — Fase 2).
   Por ahora, **acepta cualquier UUID** (el admin reconciliará).
4. Sube PDF y XML a Supabase:

   ```ruby
   pdf_path = SupplierDocument.build_path(supplier_id: ..., kind: 'pdf', filename: ...)
   Storage::SupabaseStorageService.new.upload(io, path: pdf_path, content_type: 'application/pdf')
   ```

5. Calcula SHA256 de cada archivo y verifica que no exista uno con
   el mismo hash para el mismo `supplier_id` (índice único).
6. Crea `SupplierInvoice` en `pending_match`.
7. Crea 1-2 `SupplierDocument` (uno por PDF, uno por XML) apuntando a
   `attachable_type: 'SupplierInvoice'`.
8. Registra `SupplierAuditEvent('invoice_uploaded')`.

### 4. Respuesta al proveedor

```json
{
  "uploaded": 38,
  "rejected": 2,
  "rejections": [
    { "filename": "factura_dup.xml", "reason": "UUID ya registrado" },
    { "filename": "huge.pdf", "reason": "Archivo excede 10 MB" }
  ]
}
```

FE muestra resultado con éxito/error por fila. Las exitosas
desaparecen; las rechazadas quedan visibles con su motivo para que
el proveedor las corrija y vuelva a subir.

### 5. Admin reconcilia

El proveedor ya las ve en su tabla con estatus `pending_match`. El
admin las verá en `/finanzas/proveedores/facturas` con el mismo
estatus. Sigue [F4_aprobacion_admin.md](F4_aprobacion_admin.md).

## Validaciones por archivo

| Validación | Falla si | Mensaje |
|---|---|---|
| Existe XML | falta | "Se requiere el XML del CFDI" |
| Content-Type | no es `application/xml`, `text/xml` o `application/pdf` | "Tipo de archivo no permitido" |
| Tamaño individual | > 10 MB | "Archivo excede 10 MB" |
| Total archivos | > 40 | (rechazo a nivel request) "Máximo 40 facturas por carga" |
| Tamaño total | > 200 MB | (rechazo a nivel request) "Carga total excede 200 MB" |
| UUID CFDI | duplicado en BD | "UUID ya registrado" |
| SHA256 | duplicado por supplier | "Archivo idéntico ya subido" |
| Parse XML | falla | "XML inválido o corrupto" |

## Errores comunes y recovery

- **Si Supabase rechaza el upload a mitad**: el invoice NO se crea
  (el `process_pair` está en transacción). El proveedor reintenta.
- **Si el XML parsea pero el monto sale negativo**: rechaza con
  "Monto inválido en CFDI".
- **Si el método de pago no es PUE/PPD**: rechaza con "metodo_pago
  inválido (debe ser PUE o PPD)".

## Anti-abuse

- Rate limit `bulk_upload`: 5 cargas / 10 min / supplier_user.
- Auditoría: cada upload genera un `SupplierAuditEvent` con
  `metadata: { folio:, uuid:, monto:, sha256: }`.

## Verificación

1. Portal logueado → `/cargar-facturas`.
2. Sube 3 PDF+XML válidos.
3. Backend responde `{ uploaded: 3, rejected: 0 }`.
4. Tabla `/facturas` muestra 3 nuevas en `pending_match`.
5. Supabase Storage muestra los 6 archivos (3 PDF + 3 XML) bajo
   `supplier_<id>/<año>/<mes>/`.
6. `SupplierAuditEvent` tiene 3 entradas de `invoice_uploaded`.
7. Repite intentando subir un UUID duplicado → respuesta debe ser
   `{ uploaded: 0, rejected: 1, rejections: [...] }`.
