# Sacar de VCPA (TravelCount)

## Contexto de negocio

Cuando un administrativo captura un viaje por un chofer desde la app móvil (flujo PNC → crea el
VCPA), se guarda la cadena **"VCPA"** ("Viaje Capturado Por Administrativo") en
`travel_counts.comentario`. Antes, la única forma de sacar un viaje de VCPA en la web era editar y
borrar el comentario a mano — y el campo ni siquiera estaba en el form.

Esta feature agrega:
1. **Comentario editable** en el form de TC.
2. **Botón "Sacar de VCPA"** por fila en el listado (solo si el comentario tiene "VCPA").
3. Al sacar de VCPA: quitar la leyenda, **recalcular el pago del chofer** (hoy esos viajes valen 0) y
   opcionalmente **generar una incidencia** "No capturó su viaje".

## Endpoint

```
POST /api/v1/travel_counts/:id/remove_vcpa
Body: { "crear_incidencia": boolean }
```

Controller: `Api::V1::TravelCountsController#remove_vcpa`.

| Paso | Comportamiento |
|---|---|
| Validación | `422` si el viaje no está en VCPA (`travel_count.vcpa?` falso) |
| Comentario | Quita solo la leyenda `VCPA` (preserva otras notas) vía `TravelCount#comentario_sin_vcpa` |
| Pago | Recalcula `costo` con `PayrollSvc::DriverTripCostCalculator`, `incluir_nivel: !crear_incidencia` |
| Incidencia | Si `crear_incidencia=true`, crea `EmployeesIncidence` tipo "No capturó su viaje" (BU=1) |

Se usa `update_columns` para **no** disparar el callback de re-cuadre (`before_update :update_borra_tb`):
quitar VCPA no debe alterar el match TB/TC.

### Respuesta `200`

```json
{
  "removed": true,
  "comentario": "…",          // o null si solo era VCPA
  "costo": 90.0,
  "costo_recalculado": true,   // false si no hay precio base vigente para el destino
  "incidencia_creada": false
}
```

### Errores

- `422` viaje no está en VCPA.
- `422` no existe el tipo de incidencia "No capturó su viaje" (cuando `crear_incidencia=true`).

## El motivo decide el nivel del chofer

El nivel del chofer (pesos 5/10/15, solo viajes locales) se paga o no según por qué el viaje fue VCPA:

| Decisión en el diálogo | `crear_incidencia` | `incluir_nivel` | Efecto |
|---|---|---|---|
| Sí, generar incidencia (no capturó por descuido/flojera) | `true` | `false` | Pago **sin** nivel + incidencia |
| No generar incidencia (apoyo legítimo, ej. celular dañado) | `false` | `true` | Pago **con** nivel (si es local) |

Razón: si el chofer no capturó por flojera, el trabajo lo subsidió la capturista → no se le paga el
extra de nivel. Si fue apoyo legítimo (no pudo capturar), se le paga lo justo, incluido el nivel.

## Modelo — helpers en `TravelCount`

- `VCPA_TOKEN = 'VCPA'`
- `#vcpa?` → true si `comentario` contiene la leyenda.
- `#comentario_sin_vcpa` → quita solo el token VCPA y separadores huérfanos; `nil` si no queda texto.

## Cálculo del pago

Ver `funciones_postgres/costo_viaje_chofer.md` y `finanzas/services/DriverTripCostCalculator.md`.
Fórmula: `base × (1 + inc_servicio/100) × (1 + inc_cliente/100) + nivel_pesos`.

## Tipo de incidencia "No capturó su viaje"

- Catálogo `Incidence`, **`business_unit_id = 1`**, `puntuacion = 5`.
- Creado idempotente por la migración `20260605120100_seed_incidence_no_capturo_su_viaje.rb` (y en el
  seed `db/seeds/01_catalogs.rb`). Ya existía en stage; faltaba en producción.

## Frontend

- Service: `travelCountsService.removeVcpa(id, { crear_incidencia })` (`bookings.service.js`).
- Composable: `useTravelCountsData.removeVcpaFromTravelCount(travel)` — diálogo `$q.dialog` con 3
  opciones (Sí incidencia / No incidencia / Cancelar). `removingVcpaId` para el spinner del botón.
- Botón en `TravelCountsTable.vue` y `TravelCountsMobileList.vue` (visible solo si
  `row.comentario.includes('VCPA')`).
- Campo `comentario` (textarea) agregado al `TravelCountsFormDialog.vue` y a `travel_count_params`.
