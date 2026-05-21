# DateRangePicker

`src/components/DateRangePicker.vue`

## Qué hace

Selector visual de rango de fechas reutilizable. Sustituye los `q-input` con
mask `YYYY-MM` o `YYYY-MM-DD` por un calendario visual `q-date` con `range`.
Día a día.

## Props

| Prop | Tipo | Default | Descripción |
|---|---|---|---|
| `modelValue` | Object | `{ from: null, to: null }` | `{ from: 'YYYY-MM-DD', to: 'YYYY-MM-DD' }` |
| `label` | String | `'Rango de fechas'` | etiqueta del input |
| `dense` | Boolean | `false` | densidad reducida |
| `hint` | String | `''` | hint debajo del input |

## Emits

- `update:modelValue` → `{ from, to }` cada vez que el usuario cambia el rango.

## Uso

```vue
<template>
  <DateRangePicker v-model="range" label="Rango del proyecto" dense
    hint="Día a día. Aplica a Dashboard y otras pestañas." />
</template>

<script setup>
import DateRangePicker from 'src/components/DateRangePicker.vue'
import { ref } from 'vue'

const range = ref({ from: '2026-01-01', to: '2026-05-21' })
</script>
```

## Notas de comportamiento

- El popup usa `q-date` con `mask="YYYY-MM-DD"` y `first-day-of-week="1"` (lunes).
- Si el usuario pica un solo día, se emite `{ from: día, to: día }` (rango de 1).
- El input es `readonly` — solo se puede editar pickando en el calendario.
- Si `range.from === range.to` se muestra solo `from` en el campo; si difieren,
  se muestra `from → to`.

## Por qué reemplazó al `q-input` con mask

Petición del usuario el 2026-05-21: "el rango de fechas del proyecto no es un
calendar donde pueda elegir el rango a revisar". El mask `YYYY-MM-DD` requería
teclear sin feedback visual del calendario y no permitía picar un rango.

## Lugares donde está integrado

- `src/pages/Finance/ProjectViabilityPage.vue` — rango global del proyecto que
  alimenta Dashboard, Conceptos, Movimientos y Servicios del Taller.

Aún por reemplazar: cualquier `q-input mask="####-##"` o `mask="####-##-##"`
en el código viejo (deuda técnica para próximas pasadas).
