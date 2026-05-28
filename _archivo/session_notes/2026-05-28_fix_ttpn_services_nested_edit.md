# 2026-05-28 — Fix Catálogo de Servicios TTPN: edición no cargaba nested + columna Precio actual vacía

## Síntoma
Usuario reporta que la pantalla **Catálogo de Servicios TTPN** del FE
(`/services/ttpn`) no muestra ni permite editar los nested
(`ttpn_service_prices` y `ttpn_service_driver_increases`) que sí ve en el panel
de admin (rails_admin). Captura adjunta del admin muestra las pestañas Precios
y Costo por Chofer pobladas; en la app del FE las mismas pestañas aparecen
vacías al editar.

## Causas raíz (dos bugs juntos)

### Bug 1 — `openDialog` no refetchea al editar desde la lista
`TtpnServicesPage.vue` tiene dos rutas para abrir el dialog:

- Desde la tabla → `openDialog(row)` recibe el row del listado.
- Desde "Ver detalle → Editar" → `openDialog(showService)` que ya tiene los nested.

El endpoint `GET /api/v1/ttpn_services` (index) usa
`serialize_service(..., include_nested: false)` — omite los arrays
`ttpn_service_prices` y `ttpn_service_driver_increases` por perf. Cuando
`openDialog` recibía el row del listado, mapeaba
`(service.ttpn_service_prices || [])` → array vacío y las pestañas Precios /
Costo x Chofer abrían vacías aunque la DB sí tuviera datos.

### Bug 2 — Columna "Precio actual" siempre en `—`
El template hacía `row.precio_actual` pero el serializer devolvía
`current_price`, y SOLO cuando `include_nested: true` (es decir, en `show` pero
no en `index`). Doble miss: nombre de key equivocado + key no presente en el
listado.

## Fix

### BE — `app/controllers/api/v1/ttpn_services_controller.rb`
- Renombrado `current_price` → `precio_actual` (alinea con el FE).
- Movido el cálculo de `precio_actual` fuera del `if include_nested` → ahora
  aparece tanto en `index` como en `show`.
- Cálculo del precio vigente extraído a helper `current_price_for(service)` que
  filtra in-memory las prices ya eager-loaded (cero queries extra; no hay N+1).
- Refactor cosmético: extraídos `serialize_price` y `serialize_increase` para
  bajar la complejidad ciclómatica del método grande. Sorts movidos antes del
  map para evitar `MultilineBlockChain`.
- RuboCop: 23 ofensas pre-existentes → **0**. Las 4 ofensas de métricas que
  quedaron sobre `serialize_service` se silencian con
  `# rubocop:disable Metrics/...` con el cop específico (lógica de serializer
  es lineal pero larga; refactorizar más rompería la claridad).

### FE — `src/pages/Services/TtpnServicesPage.vue`
- `openDialog` ahora es `async`. Si recibe un servicio sin
  `ttpn_service_prices` o sin `ttpn_service_driver_increases` (proviene del
  listado), llama `servicesService.find(id)` para traer el detalle con
  nested. Si ya viene completo (desde "show → editar"), no refetchea.
- Manejo de loading + `notifyApiError` ante fallos del find.

## Verificación

- BE RSpec: 21/21 verde
  (`spec/requests/api/v1/ttpn_services_spec.rb` + `spec/models/ttpn_service_spec.rb`).
- BE RuboCop: 0 ofensas.
- FE ESLint: 0 errores/warnings.

## Archivos tocados
- `ttpngas/app/controllers/api/v1/ttpn_services_controller.rb`
- `ttpn-frontend/src/pages/Services/TtpnServicesPage.vue`

## Compatibilidad
- El key `current_price` que usan `ClientForm.vue` / `ClientDetails.vue` viene
  del serializer de Client (`app/serializers/client_serializer.rb:90`) NO del
  de TtpnService. No se afecta.
- Lo mismo para `vehicle_type.current_price` (otro endpoint).
