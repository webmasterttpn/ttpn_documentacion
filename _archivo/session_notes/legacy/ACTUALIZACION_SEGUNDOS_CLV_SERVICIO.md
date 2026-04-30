# ✅ Actualización Final: clv_servicio con Segundos

**Fecha:** 2026-01-16 11:03  
**Cambio:** Incluir segundos (HH:MM:SS) para diferenciar viajes dobles

---

## 🎯 Problema Identificado

### Viajes Dobles con Segundos

**Escenario Real:**

**Capturistas (TtpnBooking):**

```
11:00 - Servicio 1
11:15 - Servicio 2
```

**Choferes (TravelCount):**

```
11:00:00 - Viaje 1
11:00:15 - Viaje 2  ← 15 segundos después
```

**Problema con HH:MM:**

```ruby
Travel 1: clv_servicio = "...11:00..."
Travel 2: clv_servicio = "...11:00..."  ← DUPLICADO!
```

---

## ✅ Solución: Usar HH:MM:SS

### Cambio en Formato

**Antes:**

```ruby
hora.strftime('%H:%M')  # "11:00" - Sin segundos
```

**Después:**

```ruby
hora.strftime('%H:%M:%S')  # "11:00:15" - Con segundos
```

### Resultado

```ruby
Travel 1: clv_servicio = "...11:00:00..."
Travel 2: clv_servicio = "...11:00:15..."  ✅ ÚNICO
```

---

## 📝 Cambios Implementados

### 1. TtpnBooking

```ruby
# app/models/ttpn_booking.rb

# clv_servicio
self.clv_servicio = client_id.to_s + fecha.to_s +
                    hora.strftime('%H:%M:%S').to_s +  # ← Con segundos
                    ttpn_service_type_id.to_s + foreign_destiny_id.to_s +
                    vehicle_id.to_s

# clv_servicio_completa
self.clv_servicio_completa = client_id.to_s + fecha.to_s +
                             hora.strftime('%H:%M:%S').to_s +  # ← Con segundos
                             ttpn_service_type_id.to_s + ttpn_service_id.to_s +
                             foreign_destiny_id.to_s + vehicle_id.to_s
```

### 2. TravelCount

```ruby
# app/models/travel_count.rb

def generar_clv_servicio
  self.clv_servicio = [
    client_id,
    fecha,
    hora.strftime('%H:%M:%S'),  # ← Con segundos
    ttpn_service_type_id,
    ttpn_foreign_destiny_id,
    vehicle_id
  ].join
end
```

### 3. Rake Tasks

```ruby
# lib/tasks/backfill_clv_servicio.rake

# TravelCounts
tc.hora&.strftime('%H:%M:%S')  # ← Con segundos

# TtpnBookings
tb.hora&.strftime('%H:%M:%S')  # ← Con segundos
```

---

## 📊 Ejemplos

### Caso 1: Viajes Dobles

**Datos:**

```
Travel 1: 2026-01-16 11:00:00, Aldama, Vehículo 5
Travel 2: 2026-01-16 11:00:15, Aldama, Vehículo 5
```

**clv_servicio:**

```
Travel 1: "1232026-01-1611:00:00155"
Travel 2: "1232026-01-1611:00:15155"
         ↑ Diferencia en segundos
```

### Caso 2: Match con Booking

**Booking:**

```
2026-01-16 11:00:00  (segundos = 00 por defecto)
clv_servicio: "1232026-01-1611:00:00155"
```

**Travel:**

```
2026-01-16 11:00:00
clv_servicio: "1232026-01-1611:00:00155"
```

**Resultado:** ✅ **MATCH EXACTO**

---

## 🔍 Consideraciones

### UI Sigue Mostrando HH:MM

**Importante:** El campo `hora` en PostgreSQL guarda HH:MM:SS internamente, pero:

- ✅ En formularios se muestra: `11:15`
- ✅ En reportes se muestra: `11:15`
- ✅ En `clv_servicio` se usa: `11:15:00`

**No hay cambios en la UI**, solo internamente.

### Segundos por Defecto

Si se captura solo HH:MM (11:15), PostgreSQL guarda:

```
11:15:00  ← Segundos = 00 por defecto
```

Esto es perfecto para el match.

---

## 🚀 Plan de Acción

### 1. ✅ Modelos Actualizados

- TtpnBooking: Usa `%H:%M:%S`
- TravelCount: Usa `%H:%M:%S`
- Rake tasks: Usa `%H:%M:%S`

### 2. 🔄 Limpiar Datos Antiguos

```bash
# Limpiar clv_servicio con formato antiguo (HH:MM)
rails runner "TravelCount.update_all(clv_servicio: nil)"
```

### 3. ⏳ Re-ejecutar Backfill

```bash
# Con nuevo formato (HH:MM:SS)
rails cuadre:backfill_travel_counts
```

### 4. ⏳ Backfill de Bookings

```bash
rails cuadre:backfill_ttpn_bookings
```

---

## 📈 Beneficios

### 1. Diferencia Viajes Dobles

```
11:00:00 vs 11:00:15  ✅ Únicos
```

### 2. Match Exacto

```
Booking (11:00:00) ↔ Travel (11:00:00)  ✅ Match
```

### 3. Sin Cambios en UI

```
Formularios: "11:15"  ← Igual que antes
Interno: "11:15:00"   ← Con segundos
```

### 4. Compatible con Realidad

```
Choferes capturan: 11:00, 11:00:15, 11:00:30
clv_servicio diferencia cada uno
```

---

## 🎯 Estado Final

**Formato de clv_servicio:**

```
client_id + fecha + HH:MM:SS + tipo + destino + vehículo
```

**Ejemplo:**

```
"1232026-01-1611:00:15155"
                ^^^^^^^^ Hora con segundos
```

**Beneficios:**

- ✅ Diferencia viajes dobles
- ✅ Match exacto funciona
- ✅ UI sin cambios
- ✅ Adaptado a la realidad

---

**Creado por:** Antigravity AI  
**Fecha:** 2026-01-16 11:03  
**Estado:** ✅ IMPLEMENTADO - 🔄 BACKFILL PENDIENTE
