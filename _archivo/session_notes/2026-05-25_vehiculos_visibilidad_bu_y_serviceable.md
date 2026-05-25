# 2026-05-25 — Visibilidad de vehículos por BU + relación de servicio cross-BU

## Contexto / problema

Al permitir que **un concesionario se comparta entre varias BUs** (feature previo de esta semana),
la "Regla B" de `Vehicle.business_unit_filter` (visibilidad vía `Vehicle → Concessionaires → BU`)
empezó a **ensuciar** el listado de vehículos de cada BU: un vehículo dado de alta en TTPN aparecía
en BU 2, 3, … solo por compartir concesionario. El dueño operativo real de cada vehículo es su
`business_unit_id`, así que esa visibilidad cruzada por concesionario estaba mal.

Paralelamente, existe la necesidad de que una **BU de servicio** (taller de camiones, autolavado,
hojalatería) pueda ver/atender flota de **otra** BU — pero de forma **explícita**, no como efecto
colateral del concesionario.

## Decisiones

1. **Eliminar la Regla B.** `Vehicle.business_unit_filter` ahora filtra **solo** por `business_unit_id`
   (igual que `Employee`). El concesionario vuelve a ser dato puramente comercial.
   - Seguro: todo vehículo tiene `business_unit_id` = su dueño, así que **nunca desaparece** de la BU
     dueña. La Regla B solo *agregaba* visibilidad; quitarla no le quita nada a nadie sobre lo suyo.
   - El **taller actual** (vans) opera bajo TTPN (BU 1) y todos los ~389 vehículos son BU 1, así que
     **sigue viéndolos** por la regla A (`business_unit_id`). El cambio no le afecta.

2. **Visibilidad cross-BU = relación dedicada a nivel vehículo** (no `KumiSetting mtto.*`, no
   concesionario): `Vehicle#serviceable_business_units` (HABTM, tabla
   `vehicle_serviceable_business_units`). Se eligió a nivel **vehículo** (no a nivel BU de servicio)
   por ser semánticamente correcto y granular, y genérico para cualquier servicio (taller/autolavado/
   hojalatería), no atado a mtto.
   - **Trade-off asumido:** granularidad a costo de etiquetar cada vehículo → mitigar a futuro con
     asignación masiva / default por tipo.

3. **Prerelleno (decisión del usuario):** existentes → atendibles por su BU dueña (= 1); nuevos →
   auto-fill con la BU donde se dan de alta.

## Cambios implementados (ttpngas)

- `app/models/vehicle.rb`:
  - `business_unit_filter` reescrito a `where(business_unit_id: Current.business_unit.id)` (+ bypass
    sadmin sin BU). Comentario explica la eliminación de la regla B.
  - Nueva HABTM `serviceable_business_units` (class_name `BusinessUnit`).
  - Callback `after_create :ensure_owner_business_unit_serviceable` (idempotente, no-op sin BU).
- `app/models/business_unit.rb`: inverso `serviceable_vehicles` (HABTM).
- `db/migrate/20260525000001_create_vehicle_serviceable_business_units.rb`: tabla join `id: false`,
  índice único `(vehicle_id, business_unit_id)` `idx_vehicle_serviceable_bu_unique`, **backfill**
  `INSERT … SELECT id, COALESCE(business_unit_id, 1) FROM vehicles ON CONFLICT DO NOTHING`.
- `spec/models/vehicle_spec.rb`: reescrito el bloque de multitenancy (ya no depende de la regla B;
  incluye test de que un concesionario compartido NO filtra vehículos de otra BU) + nuevos tests de
  la relación `serviceable_business_units` y el callback.

## Endpoints de consumo (misma sesión)

- `app/controllers/api/v1/vehicles_controller.rb`:
  - `GET /api/v1/vehicles/serviceable` — picker: vehículos que la BU activa puede atender (dueña +
    concedidos vía `serviceable_business_units`). Filtros `vehicle_type_id`, `search`,
    `include_inactive`. Límite 500. NO usa `business_unit_filter`.
  - `POST /api/v1/vehicles/assign_serviceable` (**solo sadmin**, `before_action :require_sadmin!`) —
    asigna/revoca en lote una BU de servicio. Selección por `vehicle_ids` o `owner_business_unit_id`
    (+ `vehicle_type_id`). Idempotente. Param `service_business_unit_id` (nombrado así para no chocar
    con el `business_unit_id` que el BaseController usa como filtro de BU activa del sadmin).
  - `serviceable_business_unit_ids: []` permitido en `vehicle_params` **solo si sadmin**.
- `config/routes/vehicles.rb`: collection `serviceable` (get) + `assign_serviceable` (post).
- `app/serializers/vehicle_serializer.rb`: `serviceable_business_units` en `full_json`.
- Specs: `spec/requests/api/v1/vehicles_request_spec.rb` (picker, bulk por tipo, idempotencia, revoke,
  422, 403) + rswag en `spec/requests/api/v1/vehicles_spec.rb` → swagger regenerado.
- Docs: `Documentacion/Backend/dominio/vehicles/controller/endpoints.md`.

## Verificación

- Migración aplicada en dev (docker): **389 vehículos**, todos con serviceable BU 1. `schema.rb` →
  versión `2026_05_25_000001`.
- `bundle exec rspec` (RAILS_ENV=test): **1664 examples, 0 failures, 1 pending** (pending pre-existente
  ajeno). Cobertura global **84.54%**.
- RuboCop: modelos/migración sin offenses nuevas (las 2 HABTM nuevas siguen el patrón pre-existente de
  `concessionaires`, aceptado por el proyecto sin `disable`). Spec sin offenses.

## Documentación actualizada

- `Documentacion/Backend/dominio/vehicles/model.md` — scope corregido, sección histórica de la regla B,
  campo `business_unit_id`, relación `serviceable_business_units` + callback.
- `Documentacion/Backend/dominio/mantenimiento/acceso_taller_camiones.md` — mecanismo cross-BU pasó de
  "KumiSetting mtto (no implementado)" a "relación `serviceable_business_units` (implementada)".

## Pendiente (no bloqueante)

- **Prod:** correr la migración `20260525000001` en Supabase prod (lo hace el deploy / el usuario). El
  backfill dejará todos los vehículos prod atendibles por su BU dueña.
- **Consumo:** endpoint/picker que liste vehículos por `serviceable_business_units` para el flujo de OT
  del taller; setup operativo de la BU taller (rol/privilegios/usuarios). Ver `acceso_taller_camiones.md`.
- **FE/Serializer:** exponer/gestionar `serviceable_business_unit_ids` cuando se construya la UI de
  asignación (acción masiva por tipo "Camion").
