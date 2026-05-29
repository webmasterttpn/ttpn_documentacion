# 2026-05-29 — Fase 1.B cerrada: cuadre TB ahora corre async

## Contexto

Tras alinear el formato de `clv_servicio` el 2026-05-28 (ver `2026-05-28_realineacion_clv_servicio_legacy.md`), se confirmó vía SQL diagnostic que el cuadre retroactivo §1.A.2 **no encuentra candidatos** ahora mismo:

- May 14-24: TBs y TCs ya pegados (Q1=0 confirmó que ningún TB cuadrado apunta a un TC fuera del rango).
- May 25-29: hay 2,275 TBs descuadrados y 6,223 TCs descuadrados, pero **no se cruzan temporalmente**: el respaldo legacy llega solo hasta el 24-mayo, y los choferes de la app móvil siguen apuntando a V1 (no migrados todavía). El cruce real ocurrirá en el cutover del 2-jun cuando los choferes empiecen a capturar en V2.

Decisión: el SQL retroactivo queda armado en `PASOS_TRAS_MIGRACION.md` 4.ter para correrse manualmente tras el cutover real, y arrancamos Fase 1.B (cuadre async) para que el cutover llegue con el código en producción.

## Cambio

### `ttpngas/app/jobs/cuadre/tb_match_job.rb` (nuevo)

`Cuadre::TbMatchJob` reemplaza el cuadre síncrono que vivía en los callbacks:

- Cola `default`, retry 2.
- Recibe `(booking_id, user_id = nil)`.
- Setea `Current.cuadre_in_progress = true`, busca travel via `TtpnCuadreService` (Nivel 1 + Nivel 2), enlaza si hay match con `update_columns` (sin re-disparar callbacks).
- Si `user_id` viene, hace broadcast a `"job_status_#{user_id}"` con payload `{ type: 'tb_cuadre_done', tb_id, viaje_encontrado, travel_count_id }`.
- `ensure` restaura `cuadre_in_progress = false` aún ante excepción.

### `ttpngas/app/models/ttpn_booking.rb`

Callbacks redibujados:

| Antes (síncrono) | Ahora (async) |
| --- | --- |
| `before_create :statuses` (asignaba defaults + corría cuadre Nivel 1 + Nivel 2 en proceso) | `before_create :set_default_statuses` (solo asigna `status=true`, `coo_travel_request_id=0`, `viaje_encontrado=false`) |
| `before_update :update_borra_tc` (desvinculaba TC viejo + corría re-cuadre síncrono) | `before_update :clear_stale_tc_link` (solo desvincula `@viaje_anterior` si existía) |
| — | `after_commit :enqueue_cuadre_job, on: [:create, :update], if: :cuadre_needs_recompute?` |

`cuadre_needs_recompute?` es `true` en create siempre y en update solo si `MATCH_FIELDS` cambió (`fecha`, `hora`, `vehicle_id`, `client_id`, `ttpn_service_type_id`, `ttpn_service_id`). Se omite si `Current.import_mode` o `Current.cuadre_in_progress`.

### `ttpngas/spec/jobs/cuadre/tb_match_job_spec.rb` (nuevo)

9 ejemplos cubriendo: booking inexistente, status=false, match encontrado, sin match, broadcast con user_id (con y sin match), sin broadcast con user_id=nil, `cuadre_in_progress` restaurado en éxito y ante raise.

### `ttpngas/spec/models/ttpn_booking_spec.rb`

- Stubs actualizados de `:statuses`/`:update_borra_tc` a `:set_default_statuses`/`:clear_stale_tc_link`.
- Stub global `allow(Cuadre::TbMatchJob).to receive(:perform_async)` para que los `create(:ttpn_booking)` no encolen jobs reales.
- 6 ejemplos nuevos: `#enqueue_cuadre_job` (encolado en create, forward de user_id, skip en import_mode, skip en cuadre_in_progress) y `#set_default_statuses` (defaults correctos, no-op en import_mode).

### Documentación

- Nuevo: `Documentacion/Backend/dominio/bookings/jobs/Cuadre_TbMatchJob.md` (qué hace, cuándo se encola, args, flujo, broadcast, retry, tests).
- Actualizado: `Documentacion/Backend/dominio/bookings/PROCESO_CUADRE_AUTOMATICO.md` con banner de actualización 2026-05-29 apuntando al doc del job.

## Verificación

```bash
bundle exec rubocop app/jobs/cuadre/tb_match_job.rb spec/jobs/cuadre/tb_match_job_spec.rb
# → 0 offenses en archivos nuevos

bundle exec rspec spec/jobs/cuadre/tb_match_job_spec.rb spec/models/ttpn_booking_spec.rb
# → 29 examples, 0 failures
```

Las offenses pre-existentes en `extra_campos` (Metrics/AbcSize, MethodLength, etc.) quedan fuera de scope — son deuda técnica de Fase 3.

## Próximos pasos

1. Push a `github transform_to_api` y `origin main` (en curso al cerrar nota).
2. Validar en staging: crear un TB y verificar (a) response time <100ms, (b) job en la queue, (c) `viaje_encontrado` actualiza ~1 s después, (d) broadcast llega al FE.
3. Cutover 2-jun: con esto en prod, los TBs nuevos se cuadran async con los TCs que empiezan a llegar de los choferes recién migrados. Si quedan huérfanos, correr SQL retroactivo §1.A.2.
4. Fase 1.B opcional FE: indicador "Cuadrando…" / "✓ Cuadrado" / "○ Sin par" en la pantalla de captura escuchando `tb_cuadre_done`. No bloqueante para nómina 4-jun.

## Riesgos conocidos

- **Race condition perceptual**: capturista crea TB y navega antes de que el job termine. Mitigación: indicador asíncrono cuando se implemente FE; mientras tanto, refrescar la lista resuelve la percepción.
- **Sidekiq apagado**: cuadre se "atrasa" pero no se pierde. SQL retroactivo §1.A.2 reconcilia.
- **Race con la edición**: si la capturista edita un TB mientras el job del create está en cola, el job del update también se encola y procesa después — sin conflicto.
