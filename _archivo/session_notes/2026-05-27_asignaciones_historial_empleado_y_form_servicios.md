# 2026-05-27 — Pantalla de Asignaciones (historial por empleado + lazy) y modal Agendar servicio

## Pantalla de Asignaciones de Vehículos (`VehicleAsignationsPage.vue`)

Arreglada paso a paso a partir de feedback del usuario:

1. **Orden de la tabla por unidad**: la asignación **activa** (`fecha_hasta` null)
   arriba; debajo las finalizadas por **fecha de fin descendente** (la más reciente
   primero). Aplica en desktop y móvil (computed `filteredAsignations`).

2. **Buscar por empleado ≠ por unidad**: la vista colapsable por unidad solo es
   válida buscando por unidad (muestra la última asignación de cada vehículo). Al
   buscar por empleado se necesita su **historial completo**. Solución: **selector
   de empleado buscable** en filtros.
   - Vacío → vista por unidad (tabla colapsable, intacta).
   - Empleado elegido → se oculta la tabla y aparece **`EmployeeHistory.vue`**
     (lista plana, **no colapsable**) con su historial completo.

3. **Lazy load del historial** (antes "tardaba mucho al abrir un colapse"):
   - **Backend**: `render_history` compartido por `vehicle_history` y el nuevo
     `employee_history`. Carga inicial = **activa siempre + últimos 15 días**;
     `?older_page=N` → lotes de **5** finalizadas más viejas; respuesta
     `{ data, has_more }`. Ver `Backend/dominio/vehicles/asignaciones.md`.
   - **Frontend**: `EmployeeHistory.vue` con `q-infinite-scroll` automático (índice
     1 = inicial, índice > 1 → `older_page`). `VehicleHistory.vue` migrado al mismo
     patrón, con **área de scroll propia** (340px) para que el auto-lazy funcione
     por colapse sin pelear con el scroll de la página (varios abiertos a la vez).
   - editar/finalizar/eliminar desde el historial refrescan la vista (remonta
     `EmployeeHistory` vía `:key`).

**Backend** (`vehicle_asignations_controller.rb`): el archivo venía con 28 offenses
históricas de RuboCop → se dejó en **0** (helper `full_name` DRY + disables puntuales
en los métodos de serialización pesada). 21 ejemplos del request spec verdes
(incluye 4 nuevos de `employee_history`).

## Modal "Agendar servicio" (`ServiceAppointmentForm.vue`)

Feedback: no era mobile-friendly, tenía campos empalmados (Fecha/Hora encima del
dropdown Proveedor) y los dropdowns no permitían escribir para filtrar.

- **Layout en grid** (`row q-col-gutter-md`, cada campo en `col-12`, Fecha/Hora en
  `col-12 col-sm-6`) → elimina el empalme y stackea en móvil.
- **Ancho responsivo**: `$q.screen.lt.sm ? 'width:100%' : 'min-width:540px; max-width:92vw'`
  (antes `min-width:520px` forzaba scroll horizontal en teléfono).
- **Dropdowns buscables**: vehículo, mecánico, proveedor y solicitud de chofer con
  `use-input` + `@filter` (listas filtradas locales, re-sincronizadas con los props).

## Calidad / Despliegue

ESLint 0, build SPA limpio, RuboCop 0, RSpec verde. Sin migración nueva (BE solo
controller + rutas + spec). Commits locales; despliegue: ttpngas → github
transform_to_api; FE → GitLab (Netlify) + GitHub.
