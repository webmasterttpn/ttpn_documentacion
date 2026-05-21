# PRD — Portal de Proveedores TTPN

## Problema

Hoy TTPN coordina facturas con sus proveedores **por correo y teléfono**:

- El proveedor manda la factura por mail y espera "días" sin saber si
  fue recibida, aprobada o programada para pago.
- TTPN administrativo recibe 40 facturas al mes en bandeja de entrada,
  sin un flujo único, sin trazabilidad, sin status estandarizado.
- Los complementos de pago (CFDI PPD) llegan tarde o nunca, y eso afecta
  la deducibilidad y la disciplina contable.
- No hay forma rápida de saber qué proveedor tiene confirmaciones
  pendientes para decidir si pagar a tiempo o retrasar.

## Solución

Una **PWA Portal de Proveedores** donde cada proveedor:

- Crea sus usuarios (uno o varios por empresa), administrados por TTPN.
- Sube facturas en lote (PDF + XML CFDI), hasta 40 por carga.
- Ve el estatus en tiempo real (`pending_match`, `in_review`,
  `approved`, `rejected`, `scheduled`, `partially_paid`, `paid`,
  `cancelled`).
- Conoce la **fecha programada de pago** y la **fecha real**.
- Sube los **complementos de pago** correspondientes a sus facturas PPD.
- Recibe notificación cuando su comportamiento de confirmación afecta
  los términos de pago.

Y un **módulo administrativo en Kumi** (dentro de "Finanzas") donde el
área administrativa de TTPN:

- Da de alta usuarios de proveedores con flujo de confirmación por
  email (cero gestión manual de contraseñas).
- Concilia facturas con sus órdenes de compra (texto libre por ahora
  — Fase 2 cuando exista módulo OC).
- Aprueba o rechaza facturas (con nota visible para el proveedor).
- Programa la fecha de pago.
- Ve un **semáforo** por proveedor que mide qué tan disciplinado es
  para confirmar pagos recibidos (decide si pagar a término o
  retrasar).

## Métrica de éxito (3-6 meses post-lanzamiento)

| Indicador | Estado actual | Objetivo |
|---|---|---|
| Tiempo promedio de "factura recibida → aprobada" | varios días | < 48 h |
| % de facturas PPD con complemento recibido < 30 días | desconocido | > 80 % |
| Tickets / llamadas / correos sobre status de factura | alto | -70 % |
| Visibilidad del semáforo de confirmaciones | inexistente | 100% proveedores con score visible |

## Usuarios

### Externos (Portal)

| Rol | Acciones | Permisos |
|---|---|---|
| **SupplierUser** | Login, ver facturas propias, subir facturas y complementos, ver fecha programada de pago | Solo su propio `Supplier` |

Pueden existir N usuarios por proveedor (ej. el contador y la
asistente de cuentas por cobrar). Cada uno con su email y password.

### Internos (Kumi Admin)

| Rol | Acciones | Privilegios necesarios |
|---|---|---|
| **Finanzas / Contador** | Alta de SupplierUsers, conciliar facturas, aprobar / rechazar, programar pago, ver semáforo | `supplier_portal_users`, `supplier_invoices_admin`, `supplier_payment_complements_admin` |
| **Sadmin / Admin** | Lo que Finanzas + cualquier modificación de catálogo | `manage :all` (ya existente) |

## Flujos clave (referencia rápida — detalle en `flujos/`)

| ID | Flujo | Doc |
|---|---|---|
| F1 | Alta de SupplierUser (admin captura → email confirmación → activación → cambio forzado de password) | [flujos/F1_alta_supplier_user.md](flujos/F1_alta_supplier_user.md) |
| F2 | Recovery de password (proveedor pide → email → portal de cambio → login automático) | [flujos/F2_recovery_password.md](flujos/F2_recovery_password.md) |
| F3 | Bulk upload de facturas (proveedor sube 40 PDF+XML → pending_match) | [flujos/F3_bulk_upload_facturas.md](flujos/F3_bulk_upload_facturas.md) |
| F4 | Aprobación admin (admin concilia con OC + aprueba o rechaza con nota) | [flujos/F4_aprobacion_admin.md](flujos/F4_aprobacion_admin.md) |
| F5 | Complemento PPD (proveedor sube complemento de pago) | [flujos/F5_complemento_pago_PPD.md](flujos/F5_complemento_pago_PPD.md) |
| F6 | Factura PUE (sin complemento, pago en una exhibición) | [flujos/F6_factura_PUE.md](flujos/F6_factura_PUE.md) |
| F7 | Semáforo de confirmación de pagos por proveedor | [flujos/F7_semaforo_pagos.md](flujos/F7_semaforo_pagos.md) |

## Pantallas mínimas (MVP)

### Portal de Proveedores (PWA nueva)

1. **Login** — email + password, "olvidé mi contraseña".
2. **Confirmar cuenta** — landing del link del email; cambia password.
3. **Reset password** — landing del link del email de recovery; nueva
   password + auto-login.
4. **Cambio de password obligatorio** (primer login) — formulario
   simple, no se puede saltar.
5. **Estatus de Facturas** (home, dashboard) — tabla con filtros:
   - Folio, Fecha de Recepción, Fecha de Vencimiento, Fecha de Pago,
     Monto Total, Moneda, Estatus, UUID CFDI, No. de Orden, Sucursal,
     No. Recepción.
   - Filtros: rango de fecha, estatus, sucursal, tipo, búsqueda
     por folio/UUID.
   - Botones de acción: "Subir Facturas" (bulk), "Subir Complemento".
6. **Detalle de factura** (modal/drawer al click) — toda la info +
   PDFs + XMLs descargables + status history + nota del admin si fue
   rechazada.
7. **Bulk upload de facturas** — drag-and-drop, valida PDF + XML por
   factura, hasta 40 por carga. Muestra progress y resultado por
   archivo (✓ o ✗ con motivo).
8. **Upload de complemento** — selector de factura PPD a la que aplica
   + drag de XML del complemento.

### Kumi Admin (ttpn-frontend existente)

Bajo el menú **"Finanzas"** (no como sección aparte):

1. **Facturas de Proveedores** (`/finanzas/proveedores/facturas`):
   tabla con todas las facturas, filtros por proveedor / estatus /
   rango, modal de aprobación / rechazo con nota, programar fecha
   de pago, marcar OC.
2. **Estado de Pagos / Semáforo** (`/finanzas/proveedores/semaforo`):
   tabla de proveedores con su color (🟢🟡🔴), drill-down al detalle
   de facturas pendientes de confirmación.
3. **Usuarios del Portal** (`/finanzas/proveedores/portal-usuarios`):
   alta de cuentas, reenviar confirmación, bloquear/desbloquear,
   revocar acceso.

## Decisiones tomadas con el supervisor (no replantear sin avisar)

1. **Auth en 3 capas**: API Key (portal → API) + JWT propio para
   `SupplierUser` (sin Devise, sin Devise-JWT, JWT puro con `has_secure_password`).
2. **Match factura ↔ OC**: bulk upload deja todo en `pending_match`,
   el admin reconcilia manual. No OCR. No parser XML para auto-match.
3. **Aprobación a nivel de factura completa** (no por línea).
4. **Storage**: Supabase Storage (no S3). Bucket privado.
5. **Correos en dev**: `letter_opener_web`. Prod: TBD (Google Workspace
   o similar).
6. **Semáforo**: mide confirmación de pagos por parte del proveedor
   (no es para tracking interno de TTPN). 🟢 paga a término, 🟡 retrasa
   unos días, 🔴 pausa o retrasa significativo.
7. **PUE vs PPD**: PUE no requiere complemento (CFDI original es la
   confirmación). PPD sí requiere complemento por cada exhibición.
8. **Repos**: portal de proveedores es repo aparte (Antonio lo crea).
   El BE se extiende dentro de `ttpngas`. El Admin se extiende dentro
   de `ttpn-frontend`.

## Fuera de alcance (Fase 2+)

- Módulo de Órdenes de Compra en Kumi (hoy texto libre).
- Parser de XML CFDI para auto-match factura ↔ recepción.
- Workflow de aprobación por línea de factura.
- Integración con Google Workspace SMTP para correos productivos
  (queda parametrizado, pero la decisión final no está tomada).
- Notificaciones push (PWA permite, pero no se implementa en MVP).
- Facturación automática (TTPN como receptor de CFDI estampados —
  hoy es manual).
- Conciliación bancaria automática entre `fecha_pago` y movimiento
  bancario real.
