# Deuda Técnica — Kumi TTPN Admin V2

Archivo único. Agregar nuevas entradas al tope de la sección correspondiente.
Actualizar el `Status` y el bloque `Avance` en lugar de crear archivos nuevos.

**Severidad:** Alta → bloquea o genera bugs en producción | Media → degradación o inconsistencia | Baja → cosmético o deuda de código

---

## Pendientes / En progreso

---

### DT-021 — Auto-crear `fixed_expense` al recibir mercancía en proyectos Mtto
**Registrada:** 2026-05-20 | **Dominio:** Backend — mantenimiento/finanzas | **Severidad:** Media
**Status:** Pendiente — diseño

Hoy `Mtto::ProductReceipt` (compra) y `Mtto::InventoryTransfer` (salida a
OT) solo tocan `Mtto::Inventory` y `Mtto::InventoryMovement` — **no crean
filas en `finance_entries`**. Por lo tanto el costo de comprar insumos
nunca aparece en el dashboard del proyecto y el burn rate está
subestimado.

Simulación del Taller (ver
[simulacion_taller_aceite.md](../../Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md))
muestra que el aceite consumido representa **$56,160/mes** que hoy no se
contabilizan automáticamente.

**Diseño propuesto:** callback `after_commit :sync_finance_expense` en
`Mtto::ProductReceipt` (al cerrar la recepción, no en draft) que cree un
`Finance::Entry` tipo `fixed_expense` ligado al proyecto Mtto de la
misma BU, con `amount = total_amount` y `entry_date = received_at`.

**Bloqueado por (decidir primero):**

- Mapeo BU → Finance::Project: hoy es 1-a-N. Hay que decidir si:
  (a) por convención el proyecto con `auto_revenue_source ∈ ('mtto_work_orders', 'mtto_internal_savings')` recibe los entries;
  (b) agregar `mtto_expense_project_id` explícito en `business_units`; o
  (c) un campo `is_mtto_project` boolean en `finance_projects` con check de unicidad por BU.
- Qué hacer si no existe proyecto receptor (skip silencioso vs. log).
- Idempotencia: la `uniqueness scope: :period` del concept impide
  insertar 2 entries del mismo concept en el mismo mes — el callback
  debe agregar al monto existente, no fallar.

---

### DT-020 — Modo de revenue "tarifa externa asumida" sin capturar precios por SKU/servicio
**Registrada:** 2026-05-20 | **Dominio:** Backend — finanzas | **Severidad:** Baja
**Status:** Pendiente — diseño

`mtto_internal_savings` (DT-019) exige capturar `sale_price` por producto y
`external_rate` por servicio. En la práctica el encargado del taller no va
a llenar esos campos uno por uno — calcula ROI por fuera con su Excel a
partir de una **tarifa promedio asumida**.

**Idea:** agregar un 4° valor al enum, p. ej. `'mtto_assumed_external'`,
que sume por cada OT `completed`:

```text
revenue_OT = (estimated_total_minutes / 60) × project.assumed_hourly_rate
```

(No descuenta `materials_cost`: el material ya está absorbido por la
inversión inicial / gastos del proyecto.) Requiere una columna nueva en
`finance_projects`: `assumed_hourly_rate` (decimal, default 0).

Pendiente decidir si se enriquece con un `markup` sobre `materials_cost`
para reflejar que el taller externo cobra material con sobreprecio.
Ver `_archivo/session_notes/2026-05-20_mtto_internal_savings_dashboard.md`.

---

### DT-019 — Activar `mtto_internal_savings` en el proyecto Taller cuando haya precios
**Registrada:** 2026-05-20 | **Dominio:** Backend — finanzas/mantenimiento | **Severidad:** Baja
**Status:** Pendiente — bloqueado por captura de datos

El proyecto **Taller Mecánico TTPN** (seed `20260520215508`) sigue en
`auto_revenue_source: 'none'` aunque ya está implementada la opción
`'mtto_internal_savings'` en `Finance::DashboardCalculator` y los métodos
`Mtto::WorkOrder#internal_market_value` / `#estimated_savings` están listos.
No se cambió en esta sesión porque los `sale_price` de productos y los
`external_rate` de servicios están todos en 0 (default de la migración
`20260521025531`) → activar ahora mostraría revenue 0 en el dashboard y
confundiría al usuario.

**Acción cuando se hayan capturado los precios reales:**

```ruby
Finance::Project.find_by(slug: 'taller-mecanico-ttpn')
  .update!(auto_revenue_source: 'mtto_internal_savings')
```

**Umbral mínimo identificado por simulación**: para el servicio "Cambio de
aceite" (consumo 4.5 L × $80/L = $360 de material), `external_rate` debe
ser **≥ $800** para que el ahorro mensual cubra el outflow operativo del
Taller (~$61,260/mes con 156 OTs y gastos fijos $5,100). Detalle del
cálculo y sensibilidad en
[`Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md`](../../Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md).

Ver también `_archivo/session_notes/2026-05-20_mtto_internal_savings_dashboard.md`.

---

### DT-011 — MTTO: total/subtotal/IVA de Recepciones no se autocalcula
**Registrada:** 2026-05-19 | **Dominio:** Backend — mantenimiento | **Severidad:** Media
**Status:** Pendiente

`Mtto::ProductReceipt` tiene columnas `subtotal`, `tax_amount`, `total_amount` pero quedan en
0.0 incluso después de procesar la recepción. `line_total` sí se calcula bien por línea
(columna generada `quantity_received * unit_cost`). En el manual la tabla de Recepciones se ve
con "Total: 0.0" en todos los renglones.

**Solución propuesta:** En `Mtto::ReceiveProductService` (o un callback de
`product_receipt_items`), sumar `line_total` de las líneas aceptadas al cerrar la recepción y
asignarlo a `subtotal` (y `total_amount` mientras no haya cálculo de IVA). Si más adelante se
captura IVA, agregar la fórmula explícita. Actualizar el serializer del controller y la
columna "Total" del FE.

---

### DT-012 — MTTO: Fase 2 — Órdenes de Compra (Purchase Orders)
**Registrada:** 2026-05-19 | **Dominio:** Backend + Frontend — mantenimiento | **Severidad:** Media
**Status:** Pendiente

El SQL original incluía `mtto_purchase_orders` + `mtto_purchase_order_items`. En Fase 1 se
omitió: hoy las Recepciones se crean libres (sin OC). Falta flujo formal de OC con
seguimiento (cantidades ordenadas vs recibidas vs facturadas, estado por línea, lead time
medido por OC).

**Solución propuesta:** Crear tablas `mtto_purchase_orders` + items, modelos `Mtto::PurchaseOrder`
y `Mtto::PurchaseOrderItem`, controllers + service de cierre. Vincular opcionalmente
`mtto_product_receipts.purchase_order_id` (ya estaba reservado en el SQL original). UI: catálogo
con folio `PO-YYYY-NNN`, líneas con `supplier_product` para autollenar precio/lead time.

---

### DT-013 — MTTO: Fase 2 — PWA de mecánicos + sugerencias de servicios en OT
**Registrada:** 2026-05-19 | **Dominio:** Backend + nuevo FE (PWA) — mantenimiento | **Severidad:** Media
**Status:** Pendiente

En Fase 1 la OT la activa el administrador y los mecánicos no tienen acceso directo. Quedó
pendiente la PWA dedicada para mecánicos donde puedan activar la OT, iniciar/pausar/completar,
y **sugerir servicios adicionales** si al inspeccionar el vehículo detectan algo extra (ej.
durante "cambio de aceite" se ve que necesita "cambio de balatas").

**Solución propuesta:** Cambio aditivo en `mtto_work_order_services` (no requiere migración
destructiva): columnas `is_suggested:boolean`, `suggestion_status:string`
(`pending|approved|rejected`), `suggested_by_id:bigint`, `approved_by_id:bigint`. Endpoints
`POST /work_order_services/:id/approve` y `/reject` para el administrador. PWA con login,
listado de OT asignadas al mecánico y vista de servicios + botón "sugerir nuevo".

---

### DT-014 — MTTO: Fase 2 — Conteos cíclicos de inventario
**Registrada:** 2026-05-19 | **Dominio:** Backend + Frontend — mantenimiento | **Severidad:** Media
**Status:** Pendiente

El SQL original incluía `mtto_inventory_counts` + `mtto_inventory_count_items` para auditorías
periódicas (cantidad teórica vs real, varianza). No se implementó en Fase 1.

**Solución propuesta:** Crear tablas + modelos `Mtto::InventoryCount` / `CountItem`, flujo de
captura por almacén con `expected_quantity` (snapshot del sistema) vs `actual_quantity` (lo
que se cuenta físico), `variance` virtual generada, status (`in_progress`/`discrepancy_review`/
`completed`). Al completar, generar `inventory_movement` tipo `adjustment` por cada varianza
distinta de 0 para mantener el libro auditable consistente.

---

### DT-015 — MTTO: Fase 2 — Historial de costos + analíticas JIT/spending
**Registrada:** 2026-05-19 | **Dominio:** Backend — mantenimiento | **Severidad:** Baja
**Status:** Pendiente

El SQL original incluía `mtto_product_cost_history` y vistas analíticas
(`v_supplier_spending_analysis`, `v_jit_performance`). Diferidas a Fase 2; el costo promedio
móvil actual cubre la operación pero no las tendencias.

**Solución propuesta:**

1. `mtto_product_cost_history` poblada por `ReceiveProductService` con `(product, supplier,
   unit_cost_base, cost_date)` para gráficas de tendencia de precio por proveedor.
2. Endpoints/dashboards de análisis: gasto por proveedor (suma `quantity_consumed_average ·
   unit_cost_charged` por proveedor de origen), lead time real vs `lead_time_days` (cuando
   exista OC — ver DT-012), OT vencidas vs en tiempo.

---

### DT-016 — MTTO: alerta de stock bajo no implementada
**Registrada:** 2026-05-19 | **Dominio:** Backend — mantenimiento | **Severidad:** Baja
**Status:** Pendiente

`Mtto::Product.low_stock` ya existe como scope y el FE muestra estado `REORDER`/`OUT_OF_STOCK`
en la tabla, pero no hay job que recorra los productos bajo mínimo y dispare una `Alert` en el
dominio `alertas` existente.

**Solución propuesta:** Job en cola `:alerts` (Sidekiq, cron diario) que itere
`Mtto::Product.business_unit_filter.active.low_stock` y, por cada producto, cree una `Alert`
con `AlertRule` tipo "stock_bajo_mantenimiento". Es cron silencioso → sin ActionCable (tabla
de decisión de `ttpngas/CLAUDE.md`).

---

### DT-017 — MTTO: vistas de detalle (Ver) en Recepciones/Salidas/OT del FE
**Registrada:** 2026-05-19 | **Dominio:** Frontend — mantenimiento | **Severidad:** Baja
**Status:** Pendiente

Las páginas de Recepciones, Salidas y Órdenes de Trabajo solo exponen tabla y formulario de
creación/edición. No hay diálogo de "Ver detalle" como sí existe en `src/pages/Suppliers/`
(`SupplierDetails.vue`). El operador no puede revisar las líneas/servicios de un registro sin
entrar al modo edición.

**Solución propuesta:** Crear `ReceiptDetails.vue`, `TransferDetails.vue` y
`WorkOrderDetails.vue` con el detalle (líneas/servicios + audit trail + movimientos
relacionados de inventario). Agregar botón "Ver" (icono `visibility`) en las tablas + mobile
list, abriendo el diálogo correspondiente.

---

### DT-018 — MTTO: tablero de monitoreo sin desglose de servicios por OT
**Registrada:** 2026-05-19 | **Dominio:** Frontend — mantenimiento | **Severidad:** Baja
**Status:** Pendiente

Las cards del Tablero (`WorkOrdersMonitorPage.vue`) muestran folio, mecánico, estimado vs
transcurrido y bandera de retraso, pero **no listan los servicios** que incluye la OT. El
supervisor no ve de un vistazo qué trabajos tiene cada mecánico.

**Solución propuesta:** El payload del broadcast `MttoWorkOrdersChannel` ya puede llevar la
lista de servicios (vienen en `serialize(:detailed)` del controller). Incluir un campo
`services_summary` (ej. `"Cambio de aceite · Cambio de balatas"` o `"Cambio aceite (45'),
Balatas (60')"`) en el broadcast del modelo y en el endpoint `?active=true`, y renderizar como
chips en la card.

---

### DT-009 — `ClientContact` modelo sin tabla en BD
**Registrada:** 2026-04-30 | **Dominio:** Backend — clientes | **Severidad:** Baja
**Status:** Pendiente

Detectado al generar el ERD global con `rails-erd`. El modelo `ClientContact` existe en
`app/models/` pero no tiene tabla en la base de datos. `rails-erd` lo ignora con un warning.

**Solución propuesta:** Decidir si el modelo se implementa (crear migración) o se elimina del código.

---

### DT-010 — `FixedRouteDetail` asociación fantasma en `TtpnService`
**Registrada:** 2026-04-30 | **Dominio:** Backend — servicios_ttpn | **Severidad:** Baja
**Status:** Pendiente

`TtpnService` tiene `has_many :fixed_route_details` pero la clase `FixedRouteDetail` no existe.
`rails-erd` lo ignora con un warning. No causa error en runtime porque la asociación nunca se llama.

**Solución propuesta:** Eliminar la asociación del modelo o crear el modelo/tabla correspondiente.

---

### DT-006 — Dashboard no consultable por IA (chat)
**Registrada:** 2026-04-19 | **Dominio:** Backend — dashboard | **Severidad:** Baja
**Status:** Pendiente

`/api/v1/dashboard` usa Sidekiq jobs asincrónicos. La IA no puede hacer polling de un `job_id`.

**Solución propuesta:** `GET /api/v1/dashboard/summary` — resumen sincrónico de los datos más
recientes sin Sidekiq, específico para el chat.

| KPI | Fuente |
|---|---|
| Viajes del mes vs mes anterior | `TtpnBooking` + comparativo |
| Top 5 clientes por viajes | agregación |
| Ingresos estimados del periodo | `TtpnServicePrice` × viajes |

---

---

### DT-003 — FilterPanel sin migrar en 2 páginas
**Registrada:** 2026-03-23 | **Dominio:** Frontend — Gas | **Severidad:** Baja
**Status:** Pendiente

El estándar FilterPanel se implementó en marzo 2026. 8 de 10 páginas fueron migradas. Quedan:

1. `src/pages/TtpnBookings/DiscrepanciesPage.vue` — filtros de fecha y estado
2. `src/pages/Gas/FuelPerformancePage.vue` — filtros de rango de fechas

**Solución propuesta:** Seguir el patrón de `_archivo/cambios/FE/2026-03-23_filterpanel_estandar.md`:
importar FilterPanel + useFilters, reemplazar refs inline, agregar badge de filtros activos.

---

### DT-002 — 46 silent catch blocks sin useNotify
**Registrada:** 2026-03-20 | **Dominio:** Frontend — transversal | **Severidad:** Media
**Status:** Pendiente

Durante la limpieza SonarCloud P0 se dejaron catch blocks con `/* silent */` para P1.
En P1 se creó `useNotify.js` pero los catch blocks nunca recibieron tratamiento.
Al 2026-04-30 hay **46 `/* silent */` en 29 archivos**.

**Archivos principales:** `useTtpnBookingForm.js`, `useBusinessUnitContext.js`,
`useBookingCaptureCatalogs.js`, `auth-store.js`, `AlertBell.vue`, `EmployeesPage.vue`,
`VehicleChecksPage.vue`, `ClientsPage.vue`, `FuelPerformancePage.vue`, y otros 20.

**Solución propuesta:**
```javascript
// Antes
} catch (e) { /* silent */ }

// Después — notificar al usuario
} catch (e) { notifyError('Error al cargar los datos') }

// Solo si hay razón documentada para el silencio
} catch { /* omitir — razón: X */ }
```

---

---

## Completados

---

### DT-001 — `backfill_clvs` usaba `Thread.new` en lugar de Sidekiq

**Registrada:** 2026-03-19 | **Dominio:** Backend — bookings | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-30

Creado `BackfillTtpnBookingsJob` (Sidekiq, queue: default, retry: 2).
`TtpnBookingsController#backfill_clvs` migrado a `BackfillTtpnBookingsJob.perform_async(days)`.

---

### DT-005 — `employee_stats` 500 en producción

**Registrada:** 2026-04-19 | **Dominio:** Backend — employees | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

`exec_query` (formato Rails 6) reemplazado por ActiveRecord puro. `rescue StandardError` con
logging agregado. Confirmado funcionando en producción.

---

### DT-004 — Sin control de acceso por privilegios en el chat
**Registrada:** 2026-04-19 | **Dominio:** Backend + N8N | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-19

`ChatController` extrae `build_privileges` del JWT → filtra módulos con `can_access: true` →
pasa `allowed_modules: [...]` al webhook de N8N → el nodo "Construir Prompt" restringe los
endpoints disponibles según los módulos del usuario.

---

### DT-C03 — Endpoints de stats sin filtros útiles para IA
**Registrada:** 2026-04-19 | **Dominio:** Backend | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-19

Implementados: `vehicle_stats`, `booking_stats`, `client_stats`. `employee_stats` ya existía.

---

### DT-C02 — AI routing incorrecto (employees vs employee_stats)
**Registrada:** 2026-04-19 | **Dominio:** N8N | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

Prompt actualizado con sección "REGLAS CRÍTICAS DE ROUTING" que distingue explícitamente
cuándo usar endpoint de stats vs listado individual.

---

### DT-C01 — Llamadas directas del FE a N8N (CORS)
**Registrada:** 2026-04-19 | **Dominio:** Backend + Frontend | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

Proxy implementado en `POST /api/v1/chat`. El browser nunca llama a N8N directamente.
Rails extrae `allowed_modules` del JWT y los pasa a N8N. Configurar `N8N_WEBHOOK_URL` en `.env`.
