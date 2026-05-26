# 2026-05-26 — Plan: ciclo de vida del vehículo, reemplazo sin perder trazabilidad y alertas

> **Estado: PLAN ACORDADO — NO implementado.** Documenta la definición del comportamiento del
> vehículo, el alcance inmediato y la fase de robustez diferida. No se escribió código en esta sesión.

## Contexto y decisión clave

Al definir "cómo se debe comportar un vehículo" surgió un riesgo: **crear un vehículo nuevo para
reemplazar uno (reutilizando el CLV) rompe la trazabilidad**, porque todo el historial cuelga del
`vehicle_id`, no del CLV. Quedaría huérfano/partido en:

- `ttpn_bookings` (planeación de viajes)
- `gas_charges` y `gasoline_charges`
- `vehicle_asignations`
- `travel_counts`

**Decisión:** la robustez (CLV reutilizable vía registro nuevo, préstamo operable cross‑BU,
notificación al sadmin, clonado‑reuse) se **difiere a una fase completa futura**. Por ahora el
reemplazo se maneja **manteniendo el mismo registro** (mismo `id` → historial intacto) y
**reiniciando el odómetro a mano**.

## Definición canónica del comportamiento del vehículo

1. **Identidad:** hoy el CLV es único global (validación). El vehículo vive como **un solo registro**.
2. **Ciclo de vida:** alta (`status=true`) / baja (`status=false`). Cuando se devalúa o se pierde, se
   da de baja. El listado debe mostrar **solo activos** por defecto.
3. **Reemplazo SIN perder trazabilidad (regla actual):** cuando un vehículo se reemplaza físicamente
   pero conserva su CLV/número económico, **NO se crea un registro nuevo**. Se mantiene el mismo `id`
   (preserva `ttpn_bookings`, `gas_charges`, `gasoline_charges`, `vehicle_asignations`,
   `travel_counts`) y se **reinicia el odómetro** + se actualizan números/vigencias de
   placas/póliza/tarjeta en el formulario.
4. **Odómetro:** convención del usuario = documento tipo **'Otro'**, descripción **'Odómetro'**,
   `numero` = contador. "Reiniciar" = poner ese documento en `numero=0` (editable en el form actual;
   sin campo nuevo, sin botón).
5. **Pertenencia:** una **BU dueña** (`business_unit_id`). El listado se filtra por la BU dueña.
6. **Servicio cross‑BU:** taller/autolavado de otra BU ven sus vehículos vía
   `serviceable_business_units` (ya implementado).
7. **Documentos y vencimientos:** placas, tarjeta de circulación, póliza, etc., con `expiracion`.
   Un **job nocturno ya existente** notifica los próximos a vencer (ver abajo).

## Hallazgos de exploración (lo que YA existe — no reconstruir)

- **Job nocturno de vencimientos YA funciona:** `ttpngas/app/jobs/doc_expiration_check_job.rb`
  (cron `0 6 * * *` en `config/schedule.yml`, cola `cron`) crea `Alert` para documentos
  (`vehicle_doc_expiration` / `employee_doc_expiration`) que vencen en `AlertRule.days_before` →
  `AlertDispatchJob` → `Alerts::DispatcherService` = **email** (`AlertMailer` → `AlertContact`),
  **push FCM** (`PushSenderService` → usuarios internos de la BU) y **ActionCable** (`alerts_#{bu}`).
- `status` (boolean) ya es el flag activo/inactivo (`vehicle.rb` scopes `active`/`inactive`).
- Listado FE filtra estado **en cliente** (`VehiclesPage.vue`, `useFilters`, default muestra todos).
- El **clonado** ya existe en FE (Vehículos/Clientes/Bookings); falta hacerlo genérico.

## Alcance INMEDIATO (pendiente de implementar — ronda mínima, bajo riesgo)

1. **FE — Vehículos: solo activos por defecto + filtro "Ver deshabilitados".**
   `ttpn-frontend/src/pages/Vehicles/VehiclesPage.vue`: default del filtro de estado en **activos**;
   control "Ver deshabilitados" que incluye las bajas. Filtrado en cliente, **sin tocar el backend**.
2. **Doc — job nocturno de alertas:** nuevo `Documentacion/Backend/dominio/alertas/notificaciones_vencimientos.md`
   con la arquitectura end‑to‑end y **cómo programar/configurar** (crear `AlertRule vehicle_doc_expiration`
   con `days_before` + `AlertRuleRecipient`/`AlertContact`; cron en `config/schedule.yml`; colas en
   `config/sidekiq.yml`; `FCM_SERVER_KEY`). Hardening opcional anotado (el job hace match EXACTO
   `expiracion == hoy + days_before`; a futuro usar rango con dedupe).
3. **Doc — ciclo de vida:** sección en `Documentacion/Backend/dominio/vehicles/model.md` con la
   definición de arriba (reemplazo = mismo registro + reset de odómetro a mano).

## Fase COMPLETA diferida (epic futuro — solo para registrar)

- **CLV reutilizable vía registro nuevo** con **preservación/migración de historial**
  (`ttpn_bookings`/`gas_charges`/`gasoline_charges`/`vehicle_asignations`/`travel_counts`),
  unicidad de CLV scoped a activos + **índice único parcial** `vehicles.clv WHERE status` (resolvería
  la offense `Rails/UniqueValidationWithoutIndex`) y manejo del slug FriendlyId.
- **Préstamo operable cross‑BU:** relación `operable_business_units` (HABTM, espejo de
  `serviceable`), `business_unit_filter` = dueña O operable, serializer + param sadmin, endpoint y
  campo FE (form, solo sadmin).
- **Conflicto de CLV → notificación al sadmin** vía alertas (nuevo `trigger_type vehicle_multi_bu_request`).
- **Clonado‑reuse de vehículos** + composable genérico `useClone` + rollout a pantallas de catálogo.

> Al implementar la fase diferida, agregar la entrada correspondiente al tope de
> `Documentacion/_archivo/deuda_tecnica/DEUDA_TECNICA.md`.
