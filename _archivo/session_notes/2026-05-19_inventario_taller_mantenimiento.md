# 2026-05-19 — Control de Inventario de Taller (Módulo Mantenimiento)

## Objetivo
Adaptar e implementar el esquema SQL de inventario para el módulo de
Mantenimiento, dentro del monolito `ttpngas`, siguiendo convenciones Kumi.

## Decisiones
- Dominio dentro de `ttpngas` (no repo independiente) — ADR-001 + modelos de
  mantenimiento ya existentes.
- Tablas prefijadas `mtto_*` en esquema `public`; namespace `Mtto::`.
- MVP + Órdenes de Trabajo + tablero de monitoreo en vivo.
- `clv` de producto (clave de taller ≠ SKU); catálogo `mtto_pack_sizes`.
- Conversión por unidad base; **costo promedio móvil**; **costo hundido** para
  residuo de líquidos (bucket `quantity_recovered` a $0).
- Mecánico = `Employee` interno; un mecánico por OT; tiempo a nivel OT.
- Fase 1: OT activada por administrador. Fase 2 (diferida): PWA mecánicos +
  sugerencias (columnas aditivas).

## Entregado
- **BE:** 7 migraciones (13 tablas `mtto_*` + seed Privilegios/categorías),
  namespace + 13 modelos, 4 services, canal `MttoWorkOrdersChannel`, 9
  controllers + `config/routes/maintenance.rb`, Ability + Privilege + Supplier/
  Employee, concern `BusinessUnitAssignable` (ahora expone `belongs_to
  :business_unit`).
- **Tests:** 66 specs (modelos/services/requests) + 10 rswag = **76, 0 fallos**.
  RuboCop **0 ofensas** en archivos nuevos. Swagger regenerado (6 rutas mtto).
- **FE:** `maintenance.service.js`, 8 páginas + forms (Productos, Categorías,
  Presentaciones, Servicios, Recepciones, Salidas, OT, Tablero ActionCable),
  rutas + menú + `routeToModuleKey`. ESLint **0 errores**, build **limpio**.
- **Docs:** dominio `Backend/dominio/mantenimiento/` (README, model, schema.sql,
  costeo_liquidos, controller/endpoints, services).

## Verificación funcional (rails runner + specs)
Recepción 200 L @ $20 → avg 20; +200 L @ $25 → **avg 22.5**. OT-1 consume 5 L →
line_cost $112.5; residuo 1.5 L → `recovered` 1.5, avg sin cambio. OT-2 consume
1 L → del recuperado, line_cost $0. Append-only de movimientos verificado.
Transiciones de OT + broadcast al tablero verificados.

## Deuda técnica detectada (no introducida por esta sesión)
1. **Suite baseline con fallos preexistentes**: `spec/services/fuel_performance/*`,
   `spec/services/gasoline/*`, `ttpn_cuadre`, `fuel_performance_worker` fallan en
   `main` por la factory `:vehicle` (`Debe asignarse al menos un concesionario`).
   Verificado con `git stash` de los cambios de esta sesión: los fallos
   persisten sin mis cambios → **no son regresión**. La cobertura global del gate
   (`minimum_coverage 80`) está deprimida por estos fallos preexistentes.
2. **`app/models/ability.rb`**: 13 ofensas RuboCop **preexistentes** (líneas
   largas en arrays de roles + Metrics del `initialize` de ~80 líneas). No se
   refactoriza (lógica de autorización legacy, fuera de alcance, riesgo). Mis
   adiciones son líneas cortas; no introduje ofensas nuevas.
3. **FE — patrón de arquitectura**: las páginas nuevas siguen el patrón
   single-file (como las páginas catálogo simples existentes) sin extraer
   `useXxxData/useXxxForm` ni vista móvil dedicada `XxxMobileList`. Pendiente
   alinear a `feedback_frontend_architecture_standard` (composables + mobile).

## Pendiente
- Push a ambos remotes del FE (`origin` GitLab + `github`) — requiere acción del
  usuario.
- Fase 2: Órdenes de Compra, Historial de Costos, Conteos cíclicos, analítica
  JIT, PWA mecánicos.
