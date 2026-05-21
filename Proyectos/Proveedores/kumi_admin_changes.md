# Cambios en el Kumi Admin para soportar el Portal

> **Audiencia**: el mismo dev del backend + frontend.
> **Resultado**: el área de Finanzas en el Kumi Admin puede crear
> supplier_users, aprobar/rechazar facturas, ver el semáforo de
> confirmación de pagos.
> **Pre-requisito**: `manual_backend.md` completo hasta los endpoints
> del bloque G.

---

## Por qué este manual va aparte

El **Portal de Proveedores** es un repo nuevo (la PWA externa). El
**Admin Kumi** ya existe (`ttpn-frontend`) y se extiende con páginas
nuevas dentro de la sección **Finanzas**. Este manual cubre solo esas
extensiones.

---

## Bloque A — Privilegios y Ability (backend)

### Paso 1 — Migración seed de Privileges

#### Por qué

El sistema usa `Privilege` para que el FE Admin (Quasar) decida qué
mostrar en el menú. Si un usuario no tiene el privilegio, el ítem no
aparece.

#### Comando(s)

```bash
docker compose exec kumi_api bundle exec rails generate migration \
  SeedSupplierPortalPrivileges
```

#### Contenido

```ruby
# frozen_string_literal: true

class SeedSupplierPortalPrivileges < ActiveRecord::Migration[7.1]
  def up
    privileges = [
      { module_key: 'supplier_portal_users',
        module_name: 'Usuarios del Portal',
        module_group: 'Proveedores',
        requires_create: true, requires_edit: true, requires_delete: true },
      { module_key: 'supplier_invoices_admin',
        module_name: 'Facturas de Proveedores',
        module_group: 'Proveedores',
        requires_edit: true, requires_export: true },
      { module_key: 'supplier_payment_complements_admin',
        module_name: 'Complementos de Pago',
        module_group: 'Proveedores',
        requires_edit: true }
    ]

    privileges.each do |attrs|
      Privilege.find_or_create_by!(module_key: attrs[:module_key]) do |p|
        p.assign_attributes(attrs)
      end
    end
  end

  def down
    Privilege.where(module_key: %w[supplier_portal_users supplier_invoices_admin
                                    supplier_payment_complements_admin]).destroy_all
  end
end
```

```bash
docker compose exec kumi_api bundle exec rails db:migrate
```

#### Verificación

```bash
docker compose exec kumi_api bundle exec rails runner \
  "puts Privilege.where(module_group: 'Proveedores').pluck(:module_key).inspect"
```

Debe imprimir `["supplier_portal_users", "supplier_invoices_admin",
"supplier_payment_complements_admin"]`.

### Paso 2 — Asignar privilegios al rol Finanzas en `Ability`

#### Cambio en `app/models/ability.rb`

Busca el bloque del rol que corresponda (suele haber un `case
user.role.nombre` o `if user.has_role?(:finanzas)`). Agrega:

```ruby
# Dentro del bloque del rol finanzas / coordinador_finanzas
can :manage, SupplierUser
can :manage, SupplierInvoice
can :manage, PaymentComplement
can :manage, SupplierAuditEvent
```

Si el rol Finanzas todavía no existe, **avisa a Antonio** — no lo
crees tú. Si existe pero con otro nombre (ej. `contabilidad`),
úsalo.

### Paso 3 — Controllers admin

Los detalles del código están en `manual_backend.md` Bloque G. Aquí
solo el listado y rutas en `config/routes/suppliers.rb` (crear si no
existe):

```ruby
# frozen_string_literal: true

resources :suppliers, only: [] do
  resources :users, controller: 'suppliers/users', only: [:index, :create, :destroy] do
    member { post :resend_confirmation; post :unlock }
  end
  member { get :confirmation_status }
end

resources :supplier_invoices, only: [:index, :show, :update] do
  member do
    patch :approve
    patch :reject
    patch :schedule_payment
    patch :match_purchase_order
  end
end
```

Y en `config/routes.rb` agrega `draw :suppliers` dentro de
`namespace :v1` (si no estaba).

### Paso 4 — Implementación de los controllers

Sigue el patrón estándar del proyecto. Lo crítico:

- `before_action :authorize_finance!` que verifica
  `current_user.sadmin? || current_user.has_privilege?('supplier_portal_users')`.
- `params.permit(...)` explícito (NUNCA `params.permit!`).
- Auditar acciones críticas (`approve`, `reject`) con un
  `SupplierAuditEvent` que indique qué admin ejecutó la acción.

Ejemplo abreviado:

```ruby
# app/controllers/api/v1/supplier_invoices_controller.rb
class Api::V1::SupplierInvoicesController < Api::V1::BaseController
  before_action :authorize_finance!
  before_action :set_invoice, only: [:show, :update, :approve, :reject,
                                      :schedule_payment, :match_purchase_order]

  def index
    scope = SupplierInvoice.business_unit_filter
                            .includes(:supplier)
                            .order(created_at: :desc)
    scope = scope.where(estatus: params[:estatus]) if params[:estatus].present?
    scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    render_paginated(scope) { |i| serialize(i) }
  end

  def approve
    @invoice.update!(estatus: 'approved', approved_by: current_user)
    # ... audit ...
    render json: serialize(@invoice, detailed: true)
  end

  def reject
    @invoice.update!(estatus: 'rejected', rejected_by: current_user,
                     rejection_note: params[:rejection_note])
    render json: serialize(@invoice, detailed: true)
  end

  def schedule_payment
    @invoice.update!(estatus: 'scheduled', fecha_pago: params[:fecha_pago])
    render json: serialize(@invoice, detailed: true)
  end

  def match_purchase_order
    @invoice.update!(estatus: 'in_review',
                     purchase_order_number: params[:purchase_order_number])
    render json: serialize(@invoice, detailed: true)
  end

  private

  def set_invoice
    @invoice = SupplierInvoice.business_unit_filter.find(params[:id])
  end

  def authorize_finance!
    return if current_user.sadmin? ||
              current_user.has_privilege?('supplier_invoices_admin')

    render json: { error: 'Sin privilegio' }, status: :forbidden
  end

  # serialize, render_paginated, etc. — siguen patrón estándar
end
```

---

## Bloque B — Páginas en `ttpn-frontend`

### Paso 5 — Branch en `ttpn-frontend`

```bash
cd ttpn-frontend
git checkout main
git pull
git checkout -b feature/finanzas-proveedores
```

### Paso 6 — Estructura de carpetas

Crea:

```bash
mkdir -p src/pages/Finance/Suppliers/components
mkdir -p src/composables/Finance/Suppliers
```

Páginas a crear:

- `src/pages/Finance/Suppliers/InvoicesAdminPage.vue`
- `src/pages/Finance/Suppliers/PaymentStatusPage.vue` (semáforo)
- `src/pages/Finance/Suppliers/PortalUsersPage.vue`

Components dentro de `src/pages/Finance/Suppliers/components/`:

- `InvoicesAdminTable.vue`
- `InvoiceApproveDialog.vue`
- `InvoiceRejectDialog.vue`
- `SchedulePaymentDialog.vue`
- `MatchPurchaseOrderDialog.vue`
- `SemaforoChip.vue`
- `SupplierUsersTable.vue`
- `NewSupplierUserDialog.vue`

### Paso 7 — Service

Extiende `src/services/finance.service.js` (o créalo si no existe)
con:

```js
import { api } from 'boot/axios'

export const supplierInvoicesService = {
  list: (params) => api.get('/api/v1/supplier_invoices', { params }),
  find: (id) => api.get(`/api/v1/supplier_invoices/${id}`),
  approve: (id) => api.patch(`/api/v1/supplier_invoices/${id}/approve`),
  reject: (id, note) => api.patch(`/api/v1/supplier_invoices/${id}/reject`,
                                    { rejection_note: note }),
  schedulePayment: (id, fecha) => api.patch(`/api/v1/supplier_invoices/${id}/schedule_payment`,
                                            { fecha_pago: fecha }),
  matchPO: (id, po) => api.patch(`/api/v1/supplier_invoices/${id}/match_purchase_order`,
                                  { purchase_order_number: po })
}

export const supplierPortalUsersService = {
  list: (supplierId) => api.get(`/api/v1/suppliers/${supplierId}/users`),
  create: (supplierId, payload) => api.post(`/api/v1/suppliers/${supplierId}/users`, payload),
  destroy: (supplierId, userId) => api.delete(`/api/v1/suppliers/${supplierId}/users/${userId}`),
  resendConfirmation: (supplierId, userId) =>
    api.post(`/api/v1/suppliers/${supplierId}/users/${userId}/resend_confirmation`),
  unlock: (supplierId, userId) =>
    api.post(`/api/v1/suppliers/${supplierId}/users/${userId}/unlock`),
  confirmationStatus: (supplierId) =>
    api.get(`/api/v1/suppliers/${supplierId}/confirmation_status`)
}
```

### Paso 8 — Menú: agregar 3 sub-ítems bajo Finanzas

En `src/layouts/MainLayout.vue`, busca la estructura `fullMenuList`.
Localiza la sección **Finanzas** y agrega:

```js
{
  label: 'Finanzas', icon: 'paid', children: [
    // … los items que ya existen (viabilidad, conceptos, movimientos…)
    {
      label: 'Facturas de Proveedores',
      icon: 'receipt_long',
      to: '/finanzas/proveedores/facturas',
      moduleKey: 'supplier_invoices_admin'
    },
    {
      label: 'Estado de Pagos (Semáforo)',
      icon: 'traffic',
      to: '/finanzas/proveedores/semaforo',
      moduleKey: 'supplier_invoices_admin'
    },
    {
      label: 'Usuarios del Portal',
      icon: 'group_add',
      to: '/finanzas/proveedores/portal-usuarios',
      moduleKey: 'supplier_portal_users'
    }
  ]
}
```

Verifica también `routeToModuleKey` (mapping para `usePrivileges`):

```js
const routeToModuleKey = {
  '/finanzas/proveedores/facturas': 'supplier_invoices_admin',
  '/finanzas/proveedores/semaforo': 'supplier_invoices_admin',
  '/finanzas/proveedores/portal-usuarios': 'supplier_portal_users',
  // … resto que ya existía
}
```

### Paso 9 — Rutas

En `src/router/routes.js`, dentro del bloque de rutas autenticadas
del Admin, agrega:

```js
{
  path: 'finanzas/proveedores',
  children: [
    { path: 'facturas', component: () => import('pages/Finance/Suppliers/InvoicesAdminPage.vue') },
    { path: 'semaforo', component: () => import('pages/Finance/Suppliers/PaymentStatusPage.vue') },
    { path: 'portal-usuarios', component: () => import('pages/Finance/Suppliers/PortalUsersPage.vue') }
  ]
}
```

### Paso 10 — Página `InvoicesAdminPage.vue`

Estructura general (sigue el patrón `Page orquestador + composable +
tabla + dialogs` del proyecto):

```vue
<template>
  <q-page class="q-pa-md">
    <PageHeader title="Facturas de Proveedores"
                subtitle="Administración, aprobación y programación de pago" />

    <FilterPanel v-model="showFilters" :active-count="activeFiltersCount">
      <q-select v-model="filters.estatus" :options="estatusOptions" label="Estatus"
                emit-value map-options dense />
      <q-select v-model="filters.supplier_id" :options="suppliers" label="Proveedor"
                emit-value map-options dense />
      <DateRangePicker v-model="filters.dateRange" label="Rango de fecha" dense />
    </FilterPanel>

    <InvoicesAdminTable :rows="rows" :loading="loading"
                         @view="onView" @approve="openApprove"
                         @reject="openReject" @schedule="openSchedule"
                         @match="openMatch" />

    <InvoiceApproveDialog v-model="dlg.approve" :invoice="selected" @done="fetchData" />
    <InvoiceRejectDialog v-model="dlg.reject" :invoice="selected" @done="fetchData" />
    <SchedulePaymentDialog v-model="dlg.schedule" :invoice="selected" @done="fetchData" />
    <MatchPurchaseOrderDialog v-model="dlg.match" :invoice="selected" @done="fetchData" />
  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useSupplierInvoicesAdmin } from 'src/composables/Finance/Suppliers/useSupplierInvoicesAdmin'
// ... imports de componentes ...

const { rows, loading, filters, fetchData, showFilters, activeFiltersCount } =
  useSupplierInvoicesAdmin()
const selected = ref(null)
const dlg = ref({ approve: false, reject: false, schedule: false, match: false })

function openApprove (row) { selected.value = row; dlg.value.approve = true }
function openReject (row) { selected.value = row; dlg.value.reject = true }
function openSchedule (row) { selected.value = row; dlg.value.schedule = true }
function openMatch (row) { selected.value = row; dlg.value.match = true }
function onView (row) { /* navegar a detalle o abrir drawer */ }

onMounted(fetchData)
</script>
```

### Paso 11 — Composable

`src/composables/Finance/Suppliers/useSupplierInvoicesAdmin.js`:

```js
import { ref } from 'vue'
import { supplierInvoicesService } from 'src/services/finance.service'
import { useNotify } from 'src/composables/useNotify'

export function useSupplierInvoicesAdmin () {
  const rows = ref([])
  const loading = ref(false)
  const filters = ref({ estatus: null, supplier_id: null, dateRange: null })
  const showFilters = ref(false)
  const { notifyApiError } = useNotify()

  async function fetchData () {
    loading.value = true
    try {
      const params = { ...filters.value }
      if (filters.value.dateRange) {
        params.from = filters.value.dateRange.from
        params.to = filters.value.dateRange.to
        delete params.dateRange
      }
      const { data } = await supplierInvoicesService.list(params)
      rows.value = data.data
    } catch (e) {
      notifyApiError(e, 'Error al cargar facturas')
    } finally {
      loading.value = false
    }
  }

  return { rows, loading, filters, fetchData, showFilters,
           activeFiltersCount: ref(0) }
}
```

### Paso 12 — `PaymentStatusPage.vue` (semáforo)

```vue
<template>
  <q-page class="q-pa-md">
    <PageHeader title="Estado de Pagos — Semáforo"
                subtitle="Comportamiento de confirmación de pagos por proveedor" />

    <q-card class="q-mb-md">
      <q-card-section class="row q-gutter-md">
        <q-chip clickable :color="filter==='all' ? 'primary' : 'grey-3'"
                @click="filter='all'" label="Todos" />
        <q-chip clickable :color="filter==='red' ? 'negative' : 'red-2'"
                @click="filter='red'" :label="`🔴 Rojos (${counts.red})`" />
        <q-chip clickable :color="filter==='yellow' ? 'warning' : 'amber-2'"
                @click="filter='yellow'" :label="`🟡 Amarillos (${counts.yellow})`" />
        <q-chip clickable :color="filter==='green' ? 'positive' : 'green-2'"
                @click="filter='green'" :label="`🟢 Verdes (${counts.green})`" />
      </q-card-section>
    </q-card>

    <q-table :rows="filteredRows" :columns="columns" :loading="loading"
             row-key="id" dense flat>
      <template #body-cell-status="props">
        <q-td>
          <SemaforoChip :color="props.row.confirmation_status.color" />
        </q-td>
      </template>
      <template #body-cell-rate="props">
        <q-td>{{ (props.row.confirmation_status.rate * 100).toFixed(0) }}%</q-td>
      </template>
      <template #body-cell-pending="props">
        <q-td>
          {{ props.row.confirmation_status.pending }} de
          {{ props.row.confirmation_status.total_paid }}
        </q-td>
      </template>
    </q-table>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from 'boot/axios'
import SemaforoChip from './components/SemaforoChip.vue'

const rows = ref([])
const loading = ref(false)
const filter = ref('all')

const columns = [
  { name: 'nombre', label: 'Proveedor', field: r => r.nombre, align: 'left' },
  { name: 'status', label: 'Estado', field: 'confirmation_status' },
  { name: 'rate', label: '% Confirmado', field: 'confirmation_status' },
  { name: 'pending', label: 'Pendientes', field: 'confirmation_status' }
]

const counts = computed(() => ({
  red: rows.value.filter(r => r.confirmation_status?.color === 'red').length,
  yellow: rows.value.filter(r => r.confirmation_status?.color === 'yellow').length,
  green: rows.value.filter(r => r.confirmation_status?.color === 'green').length
}))

const filteredRows = computed(() => {
  if (filter.value === 'all') return rows.value
  return rows.value.filter(r => r.confirmation_status?.color === filter.value)
})

async function fetchData () {
  loading.value = true
  try {
    const { data } = await api.get('/api/v1/suppliers', { params: { with_confirmation_status: true } })
    rows.value = data.data
  } finally { loading.value = false }
}

onMounted(fetchData)
</script>
```

### Paso 13 — `PortalUsersPage.vue`

Tabla de proveedores; al expandir un proveedor, muestra sus
SupplierUsers con acciones: **+ Nuevo usuario**, **Reenviar
confirmación**, **Desbloquear**, **Revocar acceso**.

Patrón estándar (tabla + dialog modal `NewSupplierUserDialog`).

---

## Bloque C — Verificación

### Checklist

- [ ] Migración de Privileges aplicada
- [ ] `Ability` actualizado para rol Finanzas
- [ ] 3 rutas nuevas registradas en routes.js
- [ ] 3 sub-ítems aparecen en el menú Finanzas (solo si el rol tiene
      el privilegio)
- [ ] InvoicesAdminPage lista facturas y filtra por estatus
- [ ] Dialog de aprobar funciona (cambia estatus a `approved`)
- [ ] Dialog de rechazar guarda la nota y la factura queda visible
      en el portal con la nota
- [ ] PaymentStatusPage muestra el semáforo con los 3 colores
- [ ] PortalUsersPage permite crear un supplier_user y se manda email
      de confirmación

### Test end-to-end con dos navegadores

1. **Navegador A** = Admin Kumi:
   - Login como `finanzas@ttpn.com`.
   - Crea un supplier_user para un proveedor de prueba.
2. **Tab de LetterOpener** (`localhost:3000/letter_opener`):
   - Aparece el email de confirmación. Copia el link.
3. **Navegador B (incógnito)** = Portal:
   - Abre el link de confirmación.
   - Login con email + password temporal.
   - Cambia password obligatoriamente.
   - Sube una factura PDF + XML.
4. **Navegador A** otra vez:
   - Entra a `/finanzas/proveedores/facturas`.
   - Ve la factura en `pending_match`.
   - La aprueba.
   - Programa fecha de pago.
5. **Navegador B**:
   - Refresca `/facturas`.
   - Ve estatus `scheduled` con fecha programada.

---

## Siguiente paso

→ [api_contract.md](api_contract.md) — referencia completa de todos
los endpoints.
