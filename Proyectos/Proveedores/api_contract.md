# Contrato de la API — Portal de Proveedores

Todos los endpoints viven en `/api/v1/`. Hay dos prefijos:

- `/portal/*` — consumidos por la PWA del proveedor (requiere
  `X-API-Key` + JWT supplier_user).
- `/suppliers/*` y `/supplier_invoices/*` — consumidos por el Admin
  Kumi (requiere JWT User normal con privilegio Finanzas).

## Headers comunes

| Header | Endpoints `/portal/*` | Endpoints admin |
|---|---|---|
| `X-API-Key` | **Obligatorio** | No aplica |
| `Authorization: Bearer <jwt>` | **Obligatorio** salvo `/auth/*` (login, forgot, reset, confirm) | **Obligatorio** (JWT User) |
| `Content-Type: application/json` | En requests con body | En requests con body |

## Códigos de error estandarizados

| Status | Significado |
|---|---|
| 200 OK | Operación exitosa con cuerpo |
| 201 Created | Recurso creado |
| 202 Accepted | Job encolado, esperar broadcast por WebSocket |
| 204 No Content | OK sin cuerpo (logout, forgot_password) |
| 401 Unauthorized | API Key o JWT inválido / faltante |
| 403 Forbidden | Autenticado pero sin privilegio (admin) |
| 404 Not Found | Recurso no existe o no pertenece al proveedor del JWT |
| 422 Unprocessable Content | Validación falló (`errors: [...]`) |
| 423 Locked | Cuenta bloqueada por intentos fallidos |
| 429 Too Many Requests | Rate limit alcanzado |

---

## Portal — Auth

### POST `/api/v1/portal/auth/login`

**Body:**

```json
{ "email": "ana@proveedor.com", "password": "Tmp123456789!" }
```

**200 OK:**

```json
{
  "jwt": "eyJhbGciOiJIUzI1NiI...",
  "supplier_user": {
    "id": 7,
    "email": "ana@proveedor.com",
    "nombre": "Ana López",
    "supplier_id": 42,
    "supplier_name": "Refacciones del Norte",
    "force_password_change": true
  },
  "must_change_password": true
}
```

**Errores:**

- 401 `{ "error": "Credenciales inválidas" }` — email o password incorrectos.
- 401 `{ "error": "Cuenta no confirmada" }` — falta activar.
- 423 `{ "error": "Cuenta bloqueada" }` — 5 fallos consecutivos.
- 401 `{ "error": "No autorizado" }` — sin `X-API-Key`.

### POST `/api/v1/portal/auth/forgot_password`

**Body:** `{ "email": "ana@proveedor.com" }`

**204 No Content** — siempre (no revela si el email existe).

### POST `/api/v1/portal/auth/reset_password`

**Body:**

```json
{ "token": "<raw_token_del_email>", "password": "NuevaPwd2026!!" }
```

**200 OK:** mismo payload que `login`.

### POST `/api/v1/portal/auth/confirm`

**Body:** `{ "token": "<raw_token_del_email>" }`

**200 OK:** `{ "message": "Cuenta activada. Inicia sesión." }`

### POST `/api/v1/portal/auth/logout`

Requiere JWT. Invalida el JTI actual.

**204 No Content**.

### PATCH `/api/v1/portal/me/password`

Requiere JWT. Para cambio voluntario o el forzado al primer login.

**Body:**

```json
{ "current_password": "Tmp123456789!", "new_password": "MiPwd2026!!" }
```

**200 OK:** `{ "message": "Password actualizado" }`

---

## Portal — Invoices

### GET `/api/v1/portal/invoices`

**Query params:** `page`, `per_page`, `estatus`, `from`, `to`,
`metodo_pago`.

**200 OK:**

```json
{
  "data": [
    {
      "id": 101,
      "folio": "T5403",
      "uuid_cfdi": "7F50A8E4-...",
      "fecha_recepcion": "2026-05-18",
      "fecha_vencimiento": "2026-08-16",
      "fecha_pago": null,
      "monto_total": "66260.59",
      "monto_pagado": "0.00",
      "moneda": "MXN",
      "metodo_pago": "PPD",
      "estatus": "pending_match",
      "purchase_order_number": null,
      "numero_recepcion": "2287"
    }
  ],
  "meta": { "current_page": 1, "per_page": 20, "total_count": 1, "total_pages": 1 }
}
```

### GET `/api/v1/portal/invoices/:id`

Igual al payload anterior + campos detallados:

```json
{
  "id": 101,
  // ... campos del index ...
  "rejection_note": null,
  "documents": [
    { "id": 501, "kind": "pdf",
      "signed_url": "https://xxx.supabase.co/storage/v1/object/sign/..." },
    { "id": 502, "kind": "xml",
      "signed_url": "https://xxx.supabase.co/storage/v1/object/sign/..." }
  ],
  "complements": []
}
```

### POST `/api/v1/portal/invoices/bulk_upload`

**Content-Type:** `multipart/form-data`

**Form data:** `invoices[][pdf]`, `invoices[][xml]` (hasta 40 pares).

**201 Created:**

```json
{
  "uploaded": 38,
  "rejected": 2,
  "rejections": [
    { "filename": "factura_dup.xml", "reason": "UUID duplicado" },
    { "filename": "huge.pdf", "reason": "Excede 10 MB" }
  ]
}
```

### POST `/api/v1/portal/invoices/:id/cancel`

Solo si `estatus = pending_match`.

**204 No Content** o **422** si no se puede cancelar.

---

## Portal — Payments

### GET `/api/v1/portal/payments`

Lista pagos (invoices con `monto_pagado > 0`).

### POST `/api/v1/portal/payments/:invoice_id/complements`

Subir complemento PPD.

**Body multipart:** `xml`, `pdf` (opcional).

**201 Created:** payload del complemento creado.

---

## Admin Kumi — Suppliers Portal Users

### GET `/api/v1/suppliers/:id/users`

Lista supplier_users del proveedor.

### POST `/api/v1/suppliers/:id/users`

**Body:**

```json
{ "supplier_user": { "email": "nueva@proveedor.com", "nombre": "Nueva Persona" } }
```

Genera password temporal + token de confirmación + manda email
**automáticamente**. No se devuelve la password.

**201 Created:**

```json
{ "id": 8, "email": "nueva@proveedor.com", "nombre": "Nueva Persona",
  "confirmed_at": null, "active": false }
```

### POST `/api/v1/suppliers/:id/users/:uid/resend_confirmation`

Reenvía el email de confirmación (genera token nuevo).

**204 No Content**.

### POST `/api/v1/suppliers/:id/users/:uid/unlock`

Desbloquea cuenta lockeada antes del auto-unlock de 1h.

**200 OK** con el supplier_user actualizado.

### DELETE `/api/v1/suppliers/:id/users/:uid`

Revoca acceso (`active = false`).

**204 No Content**.

### GET `/api/v1/suppliers/:id/confirmation_status`

```json
{
  "color": "yellow",
  "rate": 0.85,
  "total_paid": 20,
  "confirmed": 17,
  "pending": 3,
  "pending_invoices": ["T5403", "T5500", "T5511"]
}
```

---

## Admin Kumi — Supplier Invoices

### GET `/api/v1/supplier_invoices`

**Query params:** `estatus`, `supplier_id`, `from`, `to`, `page`, `per_page`.

**200 OK:** mismo formato que portal pero incluye `supplier` info y
no filtra por proveedor logueado.

### PATCH `/api/v1/supplier_invoices/:id/approve`

**200 OK:** invoice actualizada con `estatus = approved`.

### PATCH `/api/v1/supplier_invoices/:id/reject`

**Body:** `{ "rejection_note": "Falta el desglose de impuestos" }`

**200 OK:** invoice con `estatus = rejected` + nota visible para el
proveedor.

### PATCH `/api/v1/supplier_invoices/:id/schedule_payment`

**Body:** `{ "fecha_pago": "2026-06-15" }`

**200 OK:** invoice con `estatus = scheduled` + `fecha_pago`.

### PATCH `/api/v1/supplier_invoices/:id/match_purchase_order`

**Body:** `{ "purchase_order_number": "OC-2026-088" }`

**200 OK:** invoice con `estatus = in_review` + el número de OC asignado.

---

## Enumeración de estatus de `SupplierInvoice`

| Estatus | Significado | Quién lo asigna |
|---|---|---|
| `pending_match` | Subida, sin OC asignada | Sistema (al subir) |
| `in_review` | Tiene OC, esperando aprobación | Admin (match) |
| `approved` | Aprobada, lista para pago | Admin (approve) |
| `rejected` | Rechazada con nota | Admin (reject) |
| `scheduled` | Aprobada + fecha de pago | Admin (schedule_payment) |
| `partially_paid` | Algún complemento llegó | Sistema (al crear complement) |
| `paid` | Σ complementos == monto_total (PPD) o aprobada con `fecha_pago` (PUE) | Sistema |
| `cancelled` | Cancelada antes de aprobar | Proveedor o Admin |

## Métodos de pago CFDI

| Valor | Significado | Requiere complemento? |
|---|---|---|
| `PUE` | Pago en Una Exhibición | NO |
| `PPD` | Pago en Parcialidades o Diferido | SÍ (uno por exhibición) |

## Códigos de `forma_pago` (catálogo SAT)

| Código | Descripción |
|---|---|
| `01` | Efectivo |
| `02` | Cheque nominativo |
| `03` | Transferencia electrónica |
| `04` | Tarjeta de crédito |
| `99` | Por definir (solo para PPD) |
| ... | ver catálogo completo del SAT |
