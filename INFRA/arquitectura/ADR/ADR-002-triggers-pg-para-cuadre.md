# ADR-002 — Triggers PostgreSQL para el Cuadre Automático

**Fecha:** 2026-04-10  
**Estado:** Aceptado  
**Autor:** Antonio Castellanos

---

## Contexto

El cuadre automático (match entre `TravelCount` y `TtpnBooking`) se podría implementar en Ruby (callbacks de ActiveRecord) o en PostgreSQL (triggers).

## Decisión

El cuadre vive en triggers y funciones PostgreSQL, no en callbacks Rails.

**Triggers en `travel_counts`:**
- `sp_tctb_insert` — al insertar un TravelCount, llama a `buscar_booking()`, `buscar_booking_id()` y `buscar_nomina()`
- `sp_tctb_update` — al actualizar, reintenta el cuadre
- `tc_insert` / `tc_update` — actualizan el TtpnBooking vinculado

**Funciones PG relevantes:**
`buscar_booking`, `buscar_booking_id`, `buscar_nomina`, `buscar_planta`, `enc_booking`, `enc_travel`, `cont_viajes`, `pago_chofer`, `incremento_por_nivel`, `incremento_cliente`, entre otras (28 funciones en total).

## Razones

El cuadre necesita ser **atómico**: si un paso falla, el registro no queda en estado inconsistente. Un trigger en PostgreSQL corre en la misma transacción que el INSERT — si falla, el INSERT completo se revierte.

Con callbacks Rails (`after_create`), si el proceso muere entre el INSERT y la actualización del booking, quedan dos registros inconsistentes sin forma de saberlo.

Además, el cuadre se lanzó originalmente desde PHP. Al migrar a Rails, mantener la lógica en PG garantizó que el comportamiento no cambiara durante la transición.

## Consecuencias

- **Las funciones PG son la fuente de verdad del cuadre.** Si hay un bug en el cuadre, el primer lugar a revisar es la función PG, no el modelo Rails.
- Los developers nuevos deben conocer SQL y las funciones del sistema antes de tocar el módulo de viajes.
- Las migraciones que modifican `travel_counts` deben verificar que los triggers no se eliminaron.
- Tests de integración del cuadre deben correr contra una BD real (no mocks) — ver RUNBOOK sección 6.
- Al agregar lógica nueva al cuadre (ej. nuevos campos en `clv_servicio`), actualizar tanto el trigger PG como el modelo Rails que construye esa clave.