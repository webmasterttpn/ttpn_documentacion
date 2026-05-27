# 2026-05-27 — Solicitudes de chofer vs. servicios agendados (Solicitudes de Mantenimiento)

## Contexto

La pantalla mezclaba dos cosas: `driver_request` (solicitudes que los choferes
crean desde la app cuando detectan una falla, **pendientes de aprobación**) y
`service_appointment` (servicios **agendados** por el encargado). Se separó el
flujo: las solicitudes se revisan por estado y, al aceptarlas, se agenda un
servicio vinculado. El encargado también agenda servicios sin solicitud.

## Regla central (BE)

**Agendar un servicio para una solicitud PENDIENTE la marca ACEPTADA.** Es la
única fuente de verdad de la transición — convergen el botón "Aceptar" (abre el
modal pre-vinculado) y el dropdown de "solicitud de chofer" del form de servicio.
*Aceptar = agendar*: si se cierra el modal sin guardar, la solicitud sigue
Pendiente. **Rechazar** solo marca RECHAZADO (sin servicio).

## Backend (`ttpngas`)

- `ServiceAppointment`:
  - `validates :driver_request_id, allow_nil: true, uniqueness: { message: ... }`
    (una solicitud ≤ 1 servicio; muchos standalone con NULL).
  - `after_save :mark_driver_request_accepted` — al crear/(re)vincular, si la
    solicitud está PENDIENTE → ACEPTADO (`update_column`, idempotente; no toca
    RECHAZADO/ya ACEPTADO). No se tocó el peculiar `before_create :verificar_id`
    (intenta crear un registro basura que falla validación → solo resetea el PK
    sequence; create funciona).
  - Migración: índice **único parcial** en `driver_request_id`
    (`WHERE driver_request_id IS NOT NULL`) — enforce del has_one en BD.
- `ServiceAppointmentSerializer`: agrega `driver_request: { id, descripcion }`
  (de qué solicitud vino; nil si es standalone).
- `ServiceAppointmentsController`: create/update validan que el `driver_request_id`
  sea de la BU activa (si no → 422); se limpiaron logs de debug del index; se
  extrajo `filter_by_date`; guard con `performed?`.
- Specs: `service_appointment_spec` (uniqueness + callback), `service_appointments_spec`
  (POST con solicitud pendiente → 201 + ACEPTADO; standalone; ya-agendada → 422;
  cross-BU → 422). Factory traits `:standalone` / `:from_request`. 34 ej. verdes,
  RuboCop 0.

## Frontend (`ttpn-frontend`)

- `serviceAppointmentsService`: + `find/create/update/destroy`.
- **`ServiceAppointmentForm.vue`** (nuevo): vehículo, mecánico/responsable,
  proveedor (opcional), fecha, hora, odómetro, descripción, y **dropdown de
  solicitud de chofer con solo pendientes** (bloqueado y pre-llenado cuando se
  abre desde "Aceptar"). prefill desde aceptar o desde un hueco del calendario.
- **`AppointmentsList.vue`** (nuevo): lista responsive de servicios agendados con
  la solicitud de origen (o "—"); editar/eliminar.
- **`DriverRequestsPage.vue`**:
  - Tabs: Pendientes / Aceptadas / Rechazadas (solicitudes) + **Agendados**
    (servicios). Se quitó "Todas".
  - Botón **"Agendar servicio"** (servicio standalone; dropdown desbloqueado).
  - **Aceptar** abre el form de servicio pre-vinculado (al guardar, el BE marca
    la solicitud Aceptada y aparece en Agendados).
  - **Calendario**: se mantienen **ambos** eventos — solicitudes de chofer (color
    por estado) **y** servicios agendados (decisión del usuario: no quitar las
    solicitudes del calendario). Click en hueco → agendar servicio (fecha/hora
    prellenada, dropdown solo pendientes). Click en evento: solicitud → detalle
    (aceptar/rechazar); servicio → editar.
- ESLint 0, build limpio.

## Fuera de alcance (Fase 2)

Notificaciones push a la app móvil (aviso al chofer al aceptar/rechazar y mensaje
"preséntate al servicio" al agendar). Al crear un driver_request ya se dispara
`Alert` + `AlertDispatchJob`; eso queda igual.

Desplegado: ttpngas → github transform_to_api (Railway corre las 2 migraciones con
`db:prepare`); FE → GitLab (Netlify) + GitHub.
