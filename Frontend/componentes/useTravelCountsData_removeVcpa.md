# useTravelCountsData — `removeVcpaFromTravelCount`

Parte del composable `src/composables/TravelCounts/useTravelCountsData.js`. Documenta la acción
nueva "Sacar de VCPA" (ver también `Backend/dominio/bookings/sacar_de_vcpa.md`).

## Qué hace

Saca un `TravelCount` de "VCPA": muestra un diálogo de confirmación con 3 opciones, llama al endpoint
`remove_vcpa` y refresca la lista. El backend quita la leyenda, recalcula el pago del chofer y
(opcional) genera la incidencia "No capturó su viaje".

## Estado que expone (nuevo)

| Ref | Tipo | Descripción |
|---|---|---|
| `removingVcpaId` | `Ref<Number\|null>` | Id del TC en proceso; alimenta el spinner del botón en la fila |

## Función

| Función | Descripción |
|---|---|
| `removeVcpaFromTravelCount(travel)` | Abre `$q.dialog` con 3 opciones y ejecuta la acción según la elección |

### Diálogo (3 opciones)

`$q.dialog` con `options` radio + botón Cancelar nativo:

| Opción | Envía | Efecto en el pago |
|---|---|---|
| Sí — no capturó por descuido (flojera) | `crear_incidencia: true` | Pago **sin** nivel + genera incidencia |
| No — apoyo legítimo (ej. celular dañado) | `crear_incidencia: false` | Pago **con** nivel (si es local) |
| Cancelar (botón nativo) | — | No hace nada |

Tras éxito: `notifyOk`; si `costo_recalculado === false` avisa con `notifyInfo`
(sin precio vigente para el destino); luego `fetchTravelCounts()`.

## Dónde se usa el botón

- `TravelCountsTable.vue` (desktop) y `TravelCountsMobileList.vue` (móvil): el botón
  "Sacar de VCPA" aparece **solo si** `row.comentario && row.comentario.includes('VCPA')`.
- Wiring en `TravelCountsPage.vue`: props `:removing-vcpa-id` y evento `@remove-vcpa`.

## Dependencias

- `travelCountsService.removeVcpa(id, { crear_incidencia })` en `bookings.service.js`.
- `useNotify` (`notifyOk`, `notifyInfo`, `notifyError`).

## Relacionado: comentario editable

El campo `comentario` (textarea) se agregó al `TravelCountsFormDialog.vue` (en `EMPTY_FORM` y en el
`watch` de edición). El BE lo acepta vía `travel_count_params` (`:comentario`). Rails auto-envuelve el
payload (ParamsWrapper), por eso el form plano funciona sin wrapper explícito.
