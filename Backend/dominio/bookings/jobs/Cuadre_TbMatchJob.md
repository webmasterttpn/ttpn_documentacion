# `Cuadre::TbMatchJob`

**Última actualización:** 2026-05-29
**Cola:** `default`
**Retry:** 2

---

## Qué hace

Cuadra un `TtpnBooking` con su `TravelCount` hermano en background. Reemplaza el cuadre **síncrono** que antes vivía en los callbacks `before_create :statuses` y `before_update :update_actualiza_tc` del modelo, los cuales bloqueaban el response del save 300–500 ms por viaje. Ahora el save retorna inmediato (<100 ms) y el cuadre se resuelve en segundos vía Sidekiq.

Razón operativa: las capturistas hacen **cargas masivas, clonado y captura diaria** que con cientos de viajes acumulaban segundos de bloqueo. El job async elimina ese costo.

---

## Cuándo se encola

Desde `TtpnBooking#after_commit :enqueue_cuadre_job, on: [:create, :update], if: :cuadre_needs_recompute?`:

- **Create** → siempre (detección: `previous_changes.key?('id')`).
- **Update** → solo si alguno de `MATCH_FIELDS` cambió (`fecha`, `hora`, `vehicle_id`, `client_id`, `ttpn_service_type_id`, `ttpn_service_id`).

Se **omite** cuando:

- `Current.import_mode == true` (cargas masivas via `TtpnBookingImportJob`).
- `Current.cuadre_in_progress == true` (evita loops cuando un cuadre del lado TC nos actualizó).

El callback `before_update :clear_stale_tc_link` se ejecuta antes del save y desvincula el TC viejo si `MATCH_FIELDS` cambió (vía `@viaje_anterior` calculado en `extra_campos`).

---

## Argumentos

```ruby
Cuadre::TbMatchJob.perform_async(booking_id, user_id = nil)
```

| Arg | Tipo | Descripción |
|---|---|---|
| `booking_id` | Integer | ID del `TtpnBooking` a cuadrar. |
| `user_id` | Integer / nil | Si presente, se hace broadcast del resultado al `JobStatusChannel` de ese usuario. |

`user_id` viene de `Current.user&.id` (asignado en `BaseController`). En contextos sin usuario (Sidekiq cron, rake task, console), se pasa `nil` y no hay broadcast.

---

## Flujo interno

1. Cargar `booking = TtpnBooking.find_by(id: booking_id)`. Return temprano si no existe o `status=false`.
2. Setear `Current.cuadre_in_progress = true` (mismo flag anti-loop que el código síncrono).
3. `TtpnCuadreService.new.buscar_travel(booking)` — Nivel 1 (clv exacto) o Nivel 2 (función SQL con ventana ±15 min).
4. Si encuentra travel:
   - `service.vincular(booking, travel)` actualiza el TC en BD.
   - `booking.update_columns(viaje_encontrado: true, travel_count_id: travel.id)` persiste sin disparar callbacks ni re-cuadre.
5. Si `user_id` presente, broadcast.
6. `ensure` restaura `Current.cuadre_in_progress = false` aunque haya excepción.

---

## Broadcast

Stream: `"job_status_#{user_id}"` (mismo canal `JobStatusChannel` que el resto del sistema).

Payload:

```json
{
  "type": "tb_cuadre_done",
  "tb_id": 12345,
  "viaje_encontrado": true,
  "travel_count_id": 6789
}
```

`viaje_encontrado` es `true` solo si se encontró pareja; `false` si quedó sin par (PNC potencial). El FE puede filtrar por `msg.type === 'tb_cuadre_done'` y `msg.tb_id` para actualizar el indicador "Cuadrando…" / "✓ Cuadrado" / "○ Sin par" sin bloquear la captura.

---

## Retry y safety net

- `retry: 2` → si el job falla 3 veces queda en `failed_jobs`.
- Safety net operativa: si Sidekiq se desactiva o el job se pierde, el **SQL retroactivo de §1.A.2** (`Documentacion/_archivo/migracion/PASOS_TRAS_MIGRACION.md` paso 4.ter) reconcilia los huérfanos. Puede correrse manualmente o programado cada lunes pre-nómina.

---

## Tests

`spec/jobs/cuadre/tb_match_job_spec.rb` cubre:

- Booking inexistente → no-op.
- Booking con `status=false` → no-op.
- Match encontrado → enlaza ambos.
- Sin match → deja booking intacto.
- Broadcast con `user_id` (link exitoso vs sin pareja).
- Sin broadcast cuando `user_id` es nil.
- `Current.cuadre_in_progress` se restaura siempre (éxito + raise).

---

## Referencias

- Modelo: `app/models/ttpn_booking.rb` (callbacks `set_default_statuses`, `clear_stale_tc_link`, `enqueue_cuadre_job`, predicate `cuadre_needs_recompute?`).
- Servicio: `app/services/ttpn_cuadre_service.rb` (Nivel 1 + Nivel 2).
- Canal: `app/channels/job_status_channel.rb`.
- Doc histórico del flujo síncrono: [PROCESO_CUADRE_AUTOMATICO.md](../PROCESO_CUADRE_AUTOMATICO.md).
