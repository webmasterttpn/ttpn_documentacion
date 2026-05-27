# 2026-05-27 — Consolidar realineación de secuencia (PHP INSERT directo) en `SequenceSynchronizable`

## Contexto

PHP/Android legacy hacen `INSERT` directo con `id` explícito en varias tablas, lo
que **no avanza la secuencia de PK** de PostgreSQL → el siguiente `create` de Rails
reusa un id → `RecordNotUnique` (`<tabla>_pkey`) → 500. Hay que realinear la
secuencia antes de cada alta **mientras exista PHP**. Varios modelos tenían cada uno
su `verificar_id` (`before_create`) duplicado y con bug (`Modelo.last.id + 1` →
`nil.id` en tabla vacía → rompió la creación del primer service_appointment en prod).

## Qué se hizo

Centralizado TODO en el concern existente **`SequenceSynchronizable`** (uno solo):

- Header del concern actualizado: explicación + **leyenda "eliminar cuando se retire
  PHP"** + caveat de concurrencia.
- Eliminado el concern duplicado `PgSequenceRealign` (creado por error antes en la
  sesión, nunca commiteado).
- `include SequenceSynchronizable` (con leyenda) en: `ServiceAppointment`,
  `GasCharge`, `GasolineCharge`, `TravelCount`, y leyenda agregada a los que ya lo
  tenían: `EmployeeAppointment`, `EmployeesIncidence`.
- `verificar_id` por-modelo:
  - `ServiceAppointment`, `GasolineCharge`: eliminado (era solo secuencia).
  - `EmployeeAppointmentLog`: eliminado (código muerto, ningún callback lo llamaba y
    operaba sobre `service_appointments`).
  - `GasCharge#verificar_id`: conservado SOLO el cuadre contra gasfile (se quitó
    secuencia + `last.id+1` + create basura).
  - `TravelCount#verificar_id`: conservado SOLO la asignación de `payroll_id` (se
    quitó el `reset_pk_sequence!`).
- Specs/factories: quitado el `to_create` que saltaba `verificar_id` en la factory
  `gasoline_charge` y el stub en `gasoline_charges_spec`; spec de validación del
  realign en `service_appointment_spec` (desincroniza la secuencia como PHP y
  verifica que el create no colisiona).

## Validación

RuboCop sin offenses nuevas (la suciedad restante en los modelos legacy es
preexistente). **290 ejemplos verdes** en todos los specs que tocan estas factories
(service_appointment, travel_count, cuadre, gas/gasoline charges, employee_*,
fuel_performance, etc.).

## Pendiente / caveats

- `vehicle_asignations` y `driver_requests` también reciben INSERT directo de PHP
  (ya dieron el 500 de pkey en asignaciones). Si reaparece, agregarles
  `include SequenceSynchronizable`. No se agregó ahora (fuera del alcance "consolidar
  donde ya estaba").
- Caveat de concurrencia del `setval` (ver doc del concern). Revisar si crece el tráfico.
- Doc: `Backend/dominio/concerns/sequence_synchronizable.md`.
