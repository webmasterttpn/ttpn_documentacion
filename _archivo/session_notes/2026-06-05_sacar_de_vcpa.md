# Sesión 2026-06-05 — Sacar de VCPA + comentario editable + cálculo de pago en BD

## Objetivo

Permitir sacar un viaje de "VCPA" (Viaje Capturado Por Administrativo) desde la web sin editar a
mano: comentario editable, botón en el listado, recálculo del pago del chofer y generación opcional
de incidencia "No capturó su viaje".

## Decisiones de negocio (confirmadas con el usuario)

- Al sacar de VCPA solo se **quita la leyenda "VCPA"** del comentario (se preservan otras notas).
- El **nivel del chofer** es una **suma fija en pesos (5/10/15), no porcentaje**, y solo aplica a
  **viajes locales (Chihuahua)**.
- El nivel se paga según el motivo (decisión en el diálogo): incidencia/flojera → **sin** nivel;
  apoyo legítimo (ej. celular dañado) → **con** nivel. ⇒ `incluir_nivel = !crear_incidencia`.
- Tipo de incidencia "No capturó su viaje": **BU=1**, puntuación 5. Ya existía en stage; faltaba en prod.
- El cálculo va **en la BD** (función PostgreSQL), no en Ruby.

## Hallazgo importante — fórmula real del pago

Validada con `psql` contra viajes ya pagados en dev:

```
costo = base × (1 + inc_servicio/100) × (1 + inc_cliente/100) + nivel_pesos
```

- `base` = `vehicle_type_prices.price`; `inc_servicio`/`inc_cliente` = % (funciones PG existentes);
  `nivel` = pesos de `drivers_levels.incremento` (solo local).
- **`pago_chofer` (legacy) está mal**: ignora el incremento de cliente y trata el nivel como %.
  Se dejó como dead code. **`incremento_cliente` no estaba versionada** en ninguna migración (solo en
  la BD) → ahora sí, vía `db/functions/`.

## Cambios — Backend (`ttpngas`, rama `feature/sacar-de-vcpa`)

- `db/functions/*.sql` (4) + migración `20260605120000_create_costo_viaje_chofer_function.rb`:
  función `costo_viaje_chofer(tc_id, incluir_nivel)` que reusa las 3 funciones de apoyo.
- `app/services/payroll_svc/driver_trip_cost_calculator.rb`: wrapper Ruby (`.call`).
- `spec/support/postgres_functions.rb`: crea las funciones en la BD de test (schema ruby no las serializa).
- `app/models/travel_count.rb`: `VCPA_TOKEN`, `#vcpa?`, `#comentario_sin_vcpa`.
- `travel_counts_controller.rb`: acción `remove_vcpa`, `:comentario` en strong params, helper de incidencia.
- `config/routes/bookings.rb`: `post :remove_vcpa` (member).
- Migración `20260605120100_seed_incidence_no_capturo_su_viaje.rb` + entrada en `db/seeds/01_catalogs.rb`
  (idempotente, no duplica si ya existe en stage; fuerza BU=1).
- Specs: service, model (`#vcpa?`/`#comentario_sin_vcpa`), request (`remove_vcpa` + update con comentario),
  rswag (`remove_vcpa`). Factories nuevas: `client_ttpn_service`, `cts_driver_increment`, `employee_drivers_level`.
- Swagger regenerado.

## Cambios — Frontend (`ttpn-frontend`, rama `feature/sacar-de-vcpa`)

- `bookings.service.js`: `removeVcpa(id, data)`.
- `useTravelCountsData.js`: `removingVcpaId` + `removeVcpaFromTravelCount` (diálogo 3 opciones).
- `TravelCountsTable.vue` + `TravelCountsMobileList.vue`: botón "Sacar de VCPA" (solo si comentario tiene VCPA).
- `TravelCountsPage.vue`: wiring props/eventos.
- `TravelCountsFormDialog.vue`: campo `comentario` (textarea).

## Calidad

- RSpec: 61 ejemplos de los specs afectados en verde. Swagger: 879 ej., 0 fallas (1 pending pre-existente).
- RuboCop: archivos nuevos 0 offenses (los restantes en travel_count.rb / controller son pre-existentes).
- ESLint: 0 errores en archivos FE.

## Pendiente operativo

- **Deploy a stage** (lo hace el agente): merge a `stage` y correr `rails db:migrate` en stage,
  **revisando colisiones de versión** con otros agentes. Railway NO auto-migra.
- Deuda técnica DT-027 (destino local hardcodeado; recálculo sobre nómina cerrada).

## schema.rb

Había un `db/schema.rb` con un revert accidental previo (dump desactualizado). Al correr `db:migrate`
en dev se regeneró desde la BD real y quedó limpio (solo el bump de versión + reformateo cosmético de
un índice mtto).
