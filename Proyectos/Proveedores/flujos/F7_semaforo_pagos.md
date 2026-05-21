# F7 — Semáforo de confirmación de pagos por proveedor

## Objetivo de negocio

Medir qué tan disciplinado es cada proveedor para **confirmar los
pagos que ya recibió** (subir complementos PPD; las PUE se confirman
solas).

El semáforo NO es para tracking interno de TTPN — es una **herramienta
de decisión**:

| Color | Acción de TTPN |
|---|---|
| 🟢 Verde | Pagar facturas futuras en los términos acordados |
| 🟡 Amarillo | Atrasar el pago de futuras unos días hasta que se ponga al corriente |
| 🔴 Rojo | Atrasar significativamente o pausar pagos hasta que confirme |

## Cómo se calcula

Para cada proveedor, evaluamos sus facturas `paid` + `partially_paid`:

| Tipo | Confirmada cuando |
|---|---|
| PUE pagada | **Siempre** (el CFDI original es la confirmación SAT) |
| PPD pagada | Σ `payment_complements.monto` == `monto_pagado` |
| PPD `partially_paid` | El complemento del último pago parcial ya cargado |

```ruby
def confirmed_by_supplier?
  return true if metodo_pago == 'PUE' && estatus == 'paid'
  return false unless %w[paid partially_paid].include?(estatus)

  payment_complements.sum(:monto) >= monto_pagado
end
```

Luego el método `Supplier#confirmation_status`:

```ruby
paid = supplier_invoices.where(estatus: %w[paid partially_paid])
return { color: :green, ... } if paid.empty?

confirmed = paid.count(&:confirmed_by_supplier?)
rate = confirmed.to_f / paid.size

pendings = paid.reject(&:confirmed_by_supplier?)
old_pending = pendings.any? { |i| (Date.current - i.fecha_pago).to_i > 15 }
medium_pending = pendings.any? { |i| (Date.current - i.fecha_pago).to_i > 7 }

color = if rate < 0.7 || old_pending
          :red
        elsif rate < 1.0 || medium_pending
          :yellow
        else
          :green
        end
```

### Umbrales (configurables vía `KumiSetting`)

| Setting | Default |
|---|---|
| `supplier_semaforo.red_rate_threshold` | 0.7 |
| `supplier_semaforo.yellow_rate_threshold` | 1.0 |
| `supplier_semaforo.medium_pending_days` | 7 |
| `supplier_semaforo.old_pending_days` | 15 |

Si finanzas decide ser más estricto / más laxo, ajusta estos valores
en `Configuración → KumiSettings` (sin tocar código).

## Visibilidad en el Admin Kumi

### Tabla de proveedores

`/proveedores` (lista existente) muestra una columna nueva
**"Estado de pagos"** con el chip de color por proveedor. Click al
chip → drill-down a `/finanzas/proveedores/semaforo?supplier_id=X`.

### Página dedicada — `PaymentStatusPage.vue`

`/finanzas/proveedores/semaforo`:

- Filtros: chips de color (Solo rojos / Solo amarillos / Solo verdes / Todos).
- Por cada proveedor: nombre, color, % confirmado, X de Y facturas
  pendientes, fecha de la más vieja sin confirmar.
- Click expande: lista de facturas con sus folios y días pendientes.

## Notificación al proveedor

### Banner en el portal

Cuando el proveedor logueado tiene `confirmation_status.color != green`,
el portal muestra un banner ámbar/rojo en el top de `InvoicesPage`:

```text
⚠ Tienes 3 pagos completados pendientes de complemento.
   Esto puede retrasar pagos futuros. Súbelos cuanto antes.
```

Click en el banner → filtra la tabla a "Pendientes de confirmar".

### Email recordatorio (job cron diario)

`Suppliers::ConfirmationReminderJob` (Sidekiq cron):

- Corre cada día a las 9 AM.
- Por cada proveedor con `confirmation_status.color != green`:
  - Manda email "Tienes X complementos pendientes" si:
    - Es la primera vez (no se envió en los últimos 7 días), Y
    - Hay al menos 1 pendiente > 7 días.
- Registra `SupplierAuditEvent('reminder_sent')` para no enviar más
  de uno cada 7 días por proveedor.

## Performance

Para 100+ proveedores en `/proveedores` evita N+1:

```ruby
# En SuppliersController#index
@suppliers = Supplier.includes(supplier_invoices: :payment_complements)
                      .where(business_unit_filter)
```

Memoizar con `Rails.cache.fetch("supplier_#{id}_status", expires_in: 5.minutes)`:

```ruby
def confirmation_status_cached
  Rails.cache.fetch("supplier_#{id}_confirmation_status", expires_in: 5.minutes) do
    confirmation_status
  end
end
```

Invalidar cache al crear/borrar `PaymentComplement` con un
`after_commit` en el modelo.

## Verificación

1. Crea un proveedor con 5 facturas PPD pagadas. Sube complemento
   para 5 → semáforo VERDE.
2. Sube complemento solo para 4 (1 pendiente, hace 3 días) → AMARILLO.
3. Backdate `payment_complements` removiendo 2 más (queda 1 con
   complemento, 4 sin, una hace > 15 días) → ROJO.
4. Verifica que `KumiSetting.find_or_create_by(key:
   'supplier_semaforo.red_rate_threshold')` se respeta — si subes el
   threshold a 0.5, el proveedor que era rojo puede pasar a amarillo.
5. El proveedor recibe email del recordatorio una vez (verifica en
   LetterOpener).
6. Repite el cron al día siguiente → NO debe mandar otro email (los
   7 días).
