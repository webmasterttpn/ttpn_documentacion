# Proceso de Cuadre Automático — TtpnBooking ↔ TravelCount

**Última actualización:** 2026-04-15  
**Aplica a:** Kumi TTPN Admin V2 (API Rails)

---

## 1. ¿Qué es el cuadre?

El **cuadre** es el proceso que enlaza un registro de `ttpn_bookings` (viaje programado, creado por operaciones/despacho) con un registro de `travel_counts` (viaje ejecutado, capturado por el chofer desde la app Android).

Cuando ambos registros coinciden, se consideran el mismo evento de transporte y se marcan como **encontrados** (`viaje_encontrado = true`). Esto permite:

- Confirmar que un viaje programado realmente se realizó.
- Generar indicadores de cumplimiento.
- Detectar viajes ejecutados sin programación previa.

---

## 2. Archivos involucrados

| Archivo | Rol |
|---|---|
| `app/models/ttpn_booking.rb` | Modelo del viaje programado. Dispara cuadre al crear/actualizar. |
| `app/models/travel_count.rb` | Modelo del viaje ejecutado. Dispara cuadre al crear/actualizar. |
| `app/models/concerns/cuadrable.rb` | Concern compartido. Expone `match_fields_changed?`. |
| `app/services/ttpn_cuadre_service.rb` | Servicio central. Contiene toda la lógica de búsqueda, vinculación y desvinculación. |
| `app/models/current.rb` | `CurrentAttributes`. Contiene el flag `cuadre_in_progress` que evita loops. |
| `app/models/concerns/ttpn_bookings_helper.rb` | Helper con `busca_en_travel` (función SQL Nivel 2). |
| `app/models/concerns/travel_counts_helper.rb` | Helper con `busca_en_booking` (función SQL Nivel 2). |

---

## 3. Campos de control

### En `ttpn_bookings`

| Campo | Tipo | Descripción |
|---|---|---|
| `viaje_encontrado` | boolean | `true` si se encontró su TravelCount correspondiente. |
| `travel_count_id` | integer | FK al TravelCount cuadrado. `nil` si no hay cuadre. |
| `clv_servicio` | string | Clave de coincidencia (Nivel 1). Formato: `client_id-fecha-HH:MM:SS-tipo-destino-vehicle_id`. |
| `clv_servicio_completa` | string | Clave interna incluyendo `ttpn_service_id`. **Solo para detectar duplicados dentro de ttpn_bookings. No se usa para cuadre con travel_counts.** |

### En `travel_counts`

| Campo | Tipo | Descripción |
|---|---|---|
| `viaje_encontrado` | boolean | `true` si se encontró su TtpnBooking correspondiente. |
| `ttpn_booking_id` | integer | FK al TtpnBooking cuadrado. `nil` si no hay cuadre. |
| `clv_servicio` | string | Clave de coincidencia (Nivel 1). Mismo formato que en `ttpn_bookings`. |

---

## 4. Campos que determinan el cuadre (MATCH_FIELDS)

El cuadre solo se re-ejecuta si cambia alguno de estos campos. Un cambio en campos secundarios (descripcion, pasajeros, notas) **no** dispara re-cuadre.

### TtpnBooking::MATCH_FIELDS
```ruby
%w[fecha hora vehicle_id client_id ttpn_service_type_id ttpn_service_id]
```

### TravelCount::MATCH_FIELDS
```ruby
%w[fecha hora vehicle_id employee_id client_branch_office_id ttpn_service_type_id ttpn_foreign_destiny_id]
```

---

## 5. Formato de clv_servicio

```
client_id - fecha - HH:MM:SS - ttpn_service_type_id - ttpn_foreign_destiny_id - vehicle_id
```

**Ejemplo:** `42-2026-04-15-08:00:00-1-4-5`

- Se genera en `TtpnBooking#extra_campos` (before_validation) usando `ttpn_service.ttpn_foreign_destiny_id`.
- Se genera en `TravelCount#generar_clv_servicio` (before_validation) usando directamente `ttpn_foreign_destiny_id`.
- Usa **segundos** (`HH:MM:SS`) para distinguir viajes dobles en el mismo vehículo a la misma hora (e.g. 11:00:00 vs 11:00:15).
- Los separadores `-` son obligatorios para evitar ambigüedades (sin separadores `1` + `2` = `12` = `12` + `''`).

---

## 6. Dos niveles de cuadre

### Nivel 1 — clv_servicio (exacto, ~70% de casos)

Búsqueda directa por clave generada. Es el método preferido: preciso y sin falsos positivos.

```ruby
TravelCount.find_by(clv_servicio: booking.clv_servicio, status: true, viaje_encontrado: [false, nil])
TtpnBooking.find_by(clv_servicio: travel.clv_servicio, status: true, viaje_encontrado: [false, nil])
```

Solo busca registros aún **no cuadrados** (`viaje_encontrado: [false, nil]`) para evitar cuadres dobles.

### Nivel 2 — función SQL con ventana de tiempo (~25% de casos)

Se ejecuta solo si el Nivel 1 no encuentra nada. Usa funciones PostgreSQL que buscan con una **ventana de tolerancia de ±N minutos** alrededor de la hora.

| Dirección | Función SQL | Helper |
|---|---|---|
| Booking → TravelCount | `busca_en_travel(...)` | `TtpnBookingsHelper` |
| TravelCount → TtpnBooking | `busca_en_booking(...)` | `TravelCountsHelper` |

**Parámetros de `busca_en_travel`:**
```ruby
busca_en_travel(vehicle_id, employee_id, ttpn_service_type_id, foreign_destiny_id, client_id, fecha, hora)
# → devuelve array de hashes: [{ 'buscar_travel_id' => '123' }, ...]
# → nil o buscar_travel_id = nil si no hay resultado
```

**Parámetros de `busca_en_booking`:**
```ruby
busca_en_booking(vehicle_id, employee_id, ttpn_service_type_id, client_id, foreign_destiny_id, fecha, hora)
# → devuelve array de hashes: [{ 'buscar_booking_id' => '456' }, ...]
# → nil o buscar_booking_id = nil si no hay resultado
```

---

## 7. Flujo completo — Creación de TtpnBooking

```
POST /api/v1/ttpn_bookings
        │
        ▼
before_validation :extra_campos
  ├─ Genera clv_servicio y clv_servicio_completa
  ├─ Asigna employee_id si es nil (busca por vehicle_id + fecha_hora)
  └─ Si es update con MATCH_FIELDS cambiados: guarda @viaje_anterior y limpia travel_count_id
        │
        ▼
before_create :statuses
  ├─ Nivel 1: TravelCount.find_by(clv_servicio: ...) → encontrado?
  │     ├─ SÍ → vincular(booking, travel) → viaje_encontrado=true, travel_count_id=travel.id
  │     └─ NO → Nivel 2: busca_en_travel(...)
  │               ├─ SÍ → vincular(booking, travel)
  │               └─ NO → viaje_encontrado=false, travel_count_id=nil
        │
        ▼
INSERT ttpn_bookings
        │
        ▼
after_create :create_actualiza_tc
  └─ Si travel_count_id presente:
       TravelCount.update(viaje_encontrado: true, ttpn_booking_id: booking.id)
        │
        ▼
after_save :cuenta_pasajeros
  └─ Actualiza passenger_qty
```

---

## 8. Flujo completo — Actualización de TtpnBooking

```
PATCH /api/v1/ttpn_bookings/:id
        │
        ▼
before_validation :extra_campos
  └─ Si MATCH_FIELDS cambió Y había travel_count_id:
       @viaje_anterior = travel_count_id (guardado para el callback siguiente)
       self.viaje_encontrado = false
       self.travel_count_id  = nil
        │
        ▼
before_update :update_borra_tc
  ├─ Si @viaje_anterior es nil → SKIP (no cambió nada relevante)
  ├─ Si Current.cuadre_in_progress → SKIP (ya hay un cuadre activo)
  └─ Current.cuadre_in_progress = true
       ├─ TtpnCuadreService.desvincular_travel(@viaje_anterior)
       │    → TravelCount.update(viaje_encontrado: false, ttpn_booking_id: nil)
       └─ update_actualiza_tc
            ├─ Nivel 1: clv_servicio exacto
            └─ Nivel 2: busca_en_travel (fallback)
       Current.cuadre_in_progress = false  [ensure]
```

---

## 9. Flujo completo — Creación de TravelCount

```
POST /api/v1/travel_counts  (o desde app Android)
        │
        ▼
before_validation :generar_clv_servicio
  └─ Genera clv_servicio desde client_branch_office.client_id + campos del viaje
        │
        ▼
before_create :verificar_id
  └─ Asigna payroll_id desde nómina activa
        │
        ▼
INSERT travel_counts
```

> **Nota:** La creación de TravelCount **no** dispara cuadre automático. El cuadre desde TravelCount se activa solo en `before_update`. Esto refleja el flujo real: el chofer crea el registro y luego puede editarlo (ej. corregir hora o vehículo), momento en que sí se cuadra.

---

## 10. Flujo completo — Actualización de TravelCount

```
PATCH /api/v1/travel_counts/:id  (o sincronización desde app Android)
        │
        ▼
before_validation :generar_clv_servicio
  └─ Regenera clv_servicio con los nuevos valores
        │
        ▼
before_update :update_borra_tb
  ├─ match_fields_changed? → false → SKIP
  ├─ Current.cuadre_in_progress → true → SKIP
  └─ Si había ttpn_booking_id_was:
       TtpnCuadreService.desvincular_booking(ttpn_booking_id_was)
       → TtpnBooking.update(viaje_encontrado: false, travel_count_id: nil)
     update_actualiza_tb
       Current.cuadre_in_progress = true
       ├─ Nivel 1: TtpnBooking.find_by(clv_servicio: ...)
       └─ Nivel 2: busca_en_booking(...) (fallback)
       viaje_encontrado y ttpn_booking_id actualizados en self + en TtpnBooking
       Current.cuadre_in_progress = false  [ensure]
```

---

## 11. Prevención de loops bidireccionales

### Problema
Cuando TtpnBooking actualiza a TravelCount (vía `TravelCount.update(...)`), el `before_update` de TravelCount podría volver a disparar un cuadre que actualice a TtpnBooking, generando un loop infinito.

### Solución — Current.cuadre_in_progress

`Current` es un `ActiveSupport::CurrentAttributes`. Sus atributos son **thread-local** y Rails los resetea automáticamente entre requests.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :cuadre_in_progress
  # ...
end
```

**Regla de uso:**
1. Antes de ejecutar un cuadre que pueda actualizar el otro modelo: `Current.cuadre_in_progress = true`
2. El modelo receptor ve el flag activo y retorna sin cuadrar: `return if Current.cuadre_in_progress`
3. Bloque `ensure` garantiza que el flag se libere aunque ocurra una excepción.

### Diagrama del flag

```
TtpnBooking#update_borra_tc
  Current.cuadre_in_progress = true
  ├─ TravelCount.update(...)         ← dispara before_update de TravelCount
  │     └─ TravelCount#update_borra_tb
  │           └─ return if Current.cuadre_in_progress  ✓ SKIP — no loop
  └─ update_actualiza_tc
        └─ TravelCount.update(...)   ← idem, SKIP
  Current.cuadre_in_progress = false [ensure]
```

---

## 12. TtpnCuadreService — API pública

```ruby
service = TtpnCuadreService.new

# Buscar TravelCount para un booking (Nivel 1 + Nivel 2)
travel  = service.buscar_travel(booking)   # → TravelCount | nil

# Buscar TtpnBooking para un travel_count (Nivel 1 + Nivel 2)
booking = service.buscar_booking(travel)   # → TtpnBooking | nil

# Enlazar ambos registros (modifica booking en memoria + actualiza travel en DB)
service.vincular(booking, travel)

# Limpiar vínculo en TravelCount (actualiza DB)
service.desvincular_travel(travel_count_id)

# Limpiar vínculo en TtpnBooking (actualiza DB)
service.desvincular_booking(booking_id)
```

---

## 13. Cuadrable concern — API pública

```ruby
# En cualquier modelo que haga `include Cuadrable` y defina MATCH_FIELDS:
match_fields_changed?   # → true | false
```

Internamente usa `changes.keys.intersect?(self.class::MATCH_FIELDS)`, disponible dentro de callbacks Active Record antes de hacer el UPDATE.

---

## 14. Estados posibles de un par booking/travel

| viaje_encontrado (booking) | travel_count_id (booking) | viaje_encontrado (travel) | ttpn_booking_id (travel) | Estado |
|---|---|---|---|---|
| false / nil | nil | false / nil | nil | Sin cuadre — esperando |
| true | N | true | M (M = booking.id) | Cuadrado correctamente |
| true | N | false / nil | nil | Inconsistente — posible error de sincronización |
| false / nil | nil | true | M | Inconsistente — posible error de sincronización |

Los estados inconsistentes no deberían ocurrir con el flujo actual. Si aparecen, pueden indicar una actualización directa en SQL que saltó los callbacks de Rails.

---

## 15. Consideraciones y limitaciones conocidas

1. **Triggers PostgreSQL (`sp_tb_update`, `sp_tctb_update`):** Hacen UPDATEs directos en SQL sin pasar por Rails. No son afectados por `Current.cuadre_in_progress` (es Ruby-only). Si los triggers y los callbacks de Rails se ejecutan simultáneamente en el mismo registro, podría haber un race condition. En la práctica esto no ocurre porque los triggers solo se activan desde la app Android (PHP) y los callbacks desde la API Ruby — flujos separados.

2. **Creación de TravelCount no cuadra automáticamente:** El cuadre desde el lado TravelCount solo ocurre en `before_update`, no en `before_create`. La razón es que el chofer puede crear el viaje con datos incompletos y corregirlos después. Si se necesita cuadre inmediato al crear, habría que agregar un `after_create :update_actualiza_tb` (protegido por el mismo flag).

3. **clv_servicio_completa:** Solo existe en `ttpn_bookings`. Se usa exclusivamente para detectar viajes duplicados dentro de esa misma tabla. **No se usa para cuadre con travel_counts** — TravelCount no tiene ese campo.

4. **Segundos en clv_servicio:** Se incluyen intencionalmente para distinguir viajes dobles (mismo vehículo, misma hora exacta en minutos, diferente segundo de captura). Si el sistema origen no registra segundos, ambos registros tendrán `HH:MM:00` y el Nivel 1 funcionará correctamente.
