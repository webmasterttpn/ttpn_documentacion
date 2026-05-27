# 2026-05-27 — Fix: aceptar solicitud no creaba el servicio (no aparecía en Aceptadas ni Agendados)

## Síntoma (producción)

Al **aceptar** una solicitud de chofer y guardar el servicio, la solicitud no
pasaba a **Aceptadas** y el servicio no aparecía en **Agendados**.

## Causas (dos, una específica de prod)

1. **`ServiceAppointment#verificar_id`** (`before_create`): workaround viejo del
   desfase de secuencias de PK. Hacía `ServiceAppointment.last.id + 1`. En
   **producción con la tabla vacía**, `ServiceAppointment.last` era `nil` →
   `nil.id` → **500** al crear el primer servicio. El create fallaba, así que el
   servicio no se creaba y la solicitud nunca pasaba a ACEPTADO (de ahí que no
   apareciera ni en Aceptadas ni en Agendados).
   - **Fix**: se **eliminó** `verificar_id` (callback + método). Ya no se necesita:
     las secuencias se sincronizan sistémicamente (migración `SyncPkSequencesForward`
     + `db:reset_sequences` tras importaciones). El factory `:service_appointment`
     se simplificó (ya no salta ese callback).

2. **Ventana de fechas del fetch** (`DriverRequestsPage._computeDateRange`): la vista
   de lista/búsqueda traía `[hace 1 mes, hoy]`. Un servicio agendado **a futuro** caía
   fuera y no aparecía en Agendados aunque se creara bien.
   - **Fix**: el `end` de la ventana se extiende **+1 año** (lista y búsqueda), ya
     que los servicios se agendan a futuro.

## Verificación

RuboCop 0 (modelo), 21 ejemplos verdes (model + request specs de service_appointment),
ESLint 0, build limpio. El POST del request spec ejercita la creación sin `verificar_id`.

## Nota de despliegue

Sin migración nueva. Tras desplegar, si algún create diera `PG::UniqueViolation` en
`service_appointments_pkey` (secuencia atrasada), correr el cURL idempotente
`{"task":"reset_sequences"}` (ver `migracion/PASOS_TRAS_MIGRACION.md`). En la práctica
la secuencia ya quedó sincronizada por la migración forward-only y por los
`reset_pk_sequence!` que `verificar_id` ejecutaba en cada intento.
