# ✅ Eliminación de Callback verificar_id - TtpnBookingPassenger

**Fecha:** 2026-01-15  
**Modelo:** TtpnBookingPassenger  
**Estado:** ✅ COMPLETADO

---

## 📝 Resumen de Cambios

### Archivo Modificado

**`app/models/ttpn_booking_passenger.rb`**

**Antes:**

```ruby
class TtpnBookingPassenger < ApplicationRecord
  before_save :revisar_clv_servicio
  before_create :revisar_coo_travel_request
  before_create :verificar_id  # ❌ PROBLEMÁTICO

  def verificar_id
    ActiveRecord::Base.connection.reset_pk_sequence!('ttpn_booking_passengers')
    actual_id = TtpnBookingPassenger.last
    next_id = actual_id.id + 1
    TtpnBookingPassenger.create { |ttpn_booking_passenger| ttpn_booking_passenger.id = next_id }
  end
end
```

**Después:**

```ruby
class TtpnBookingPassenger < ApplicationRecord
  before_save :revisar_clv_servicio
  before_create :revisar_coo_travel_request

  # Eliminado: before_create :verificar_id (2026-01-15)
  # Razón: Creaba registros vacíos innecesarios. PostgreSQL maneja IDs automáticamente.
  # Ver: /documentacion/ANALISIS_CALLBACKS_VERIFICAR_ID.md
end
```

---

## 🎯 Problema Resuelto

### ❌ Comportamiento Anterior

Cada vez que se creaba un `TtpnBookingPassenger`:

1. El callback `verificar_id` se ejecutaba ANTES de crear el registro
2. Creaba un registro VACÍO con el siguiente ID
3. Luego se creaba el registro REAL

**Resultado:** 2 registros por cada creación (1 vacío + 1 real)

### ✅ Comportamiento Actual

Cuando se crea un `TtpnBookingPassenger`:

1. PostgreSQL asigna automáticamente el siguiente ID disponible
2. Se crea SOLO el registro real

**Resultado:** 1 registro por cada creación

---

## 🧪 Verificación

### 1. Verificar que el Callback Fue Eliminado

```bash
# Buscar referencias a verificar_id en el modelo
grep -n "verificar_id" app/models/ttpn_booking_passenger.rb

# Resultado esperado:
# 11:  # Eliminado: before_create :verificar_id (2026-01-15)
```

### 2. Probar Creación de Registros

```ruby
# En rails console
rails console

# Contar registros antes
count_before = TtpnBookingPassenger.count
puts "Registros antes: #{count_before}"

# Crear un registro de prueba
passenger = TtpnBookingPassenger.create!(
  nombre: "Test",
  apaterno: "Prueba",
  amaterno: "Callback",
  num_empleado: "12345",
  client_branch_office_id: 1
)

# Contar registros después
count_after = TtpnBookingPassenger.count
puts "Registros después: #{count_after}"

# Verificar que solo se creó 1 registro
created_count = count_after - count_before
puts "Registros creados: #{created_count}"

# ✅ Debe ser: 1 (no 2)
if created_count == 1
  puts "✅ CORRECTO: Solo se creó 1 registro"
else
  puts "❌ ERROR: Se crearon #{created_count} registros"
end

# Verificar que el registro tiene datos
puts "\nDatos del registro:"
puts "ID: #{passenger.id}"
puts "Nombre: #{passenger.nombre}"
puts "Apaterno: #{passenger.apaterno}"

# Limpiar
passenger.destroy
```

### 3. Verificar IDs Únicos

```ruby
# Crear múltiples registros
ids = []
10.times do |i|
  p = TtpnBookingPassenger.create!(
    nombre: "Test#{i}",
    apaterno: "Prueba",
    client_branch_office_id: 1
  )
  ids << p.id
end

# Verificar que todos los IDs son únicos
unique_ids = ids.uniq
puts "IDs creados: #{ids.count}"
puts "IDs únicos: #{unique_ids.count}"

# ✅ Deben ser iguales
if ids.count == unique_ids.count
  puts "✅ CORRECTO: Todos los IDs son únicos"
else
  puts "❌ ERROR: Hay IDs duplicados"
end

# Limpiar
TtpnBookingPassenger.where(nombre: ids.map { |i| "Test#{i}" }).destroy_all
```

---

## 🗑️ Limpieza de Registros Vacíos

### Reporte de Registros Vacíos

```bash
# Ver cuántos registros vacíos existen
rails cleanup:report_ttpn_booking_passengers
```

**Salida esperada:**

```
================================================================================
Reporte de TtpnBookingPassenger - Registros Vacíos
================================================================================

📊 Estadísticas:
   Total de registros: 1000
   Registros vacíos: 500
   Registros válidos: 500

📈 Porcentaje de basura: 50.0%

📅 Distribución por fecha de creación:
   2026-01-10: 45 registros
   2026-01-11: 52 registros
   ...

💾 Espacio estimado desperdiciado:
   ~500 KB (~0.49 MB)

🔧 Para limpiar, ejecuta:
   rails cleanup:ttpn_booking_passengers
```

### Eliminar Registros Vacíos

```bash
# Ejecutar limpieza
rails cleanup:ttpn_booking_passengers
```

**Proceso:**

1. Muestra estadísticas
2. Pide confirmación
3. Elimina registros vacíos en lotes
4. Muestra resultado final

**⚠️ IMPORTANTE:** Ejecutar primero en desarrollo/staging antes de producción.

---

## 📊 Impacto Esperado

### Antes de la Eliminación

```sql
-- Registros totales
SELECT COUNT(*) FROM ttpn_booking_passengers;
-- Ejemplo: 1000

-- Registros vacíos
SELECT COUNT(*) FROM ttpn_booking_passengers
WHERE nombre IS NULL AND apaterno IS NULL;
-- Ejemplo: 500 (50%)

-- Registros válidos
SELECT COUNT(*) FROM ttpn_booking_passengers
WHERE nombre IS NOT NULL OR apaterno IS NOT NULL;
-- Ejemplo: 500 (50%)
```

### Después de la Eliminación y Limpieza

```sql
-- Registros totales
SELECT COUNT(*) FROM ttpn_booking_passengers;
-- Ejemplo: 500 (reducción del 50%)

-- Registros vacíos
SELECT COUNT(*) FROM ttpn_booking_passengers
WHERE nombre IS NULL AND apaterno IS NULL;
-- Ejemplo: 0 (0%)

-- Registros válidos
SELECT COUNT(*) FROM ttpn_booking_passengers
WHERE nombre IS NOT NULL OR apaterno IS NOT NULL;
-- Ejemplo: 500 (100%)
```

### Beneficios

- ✅ **50% menos registros** en la tabla
- ✅ **Consultas más rápidas** (menos datos que escanear)
- ✅ **Datos más limpios** (solo registros válidos)
- ✅ **Menos espacio en disco**
- ✅ **Sin race conditions** en creación de IDs
- ✅ **Código más simple** (un callback menos)

---

## ✅ Checklist de Verificación

### Pre-Despliegue

- [x] Callback eliminado del modelo
- [x] Comentario explicativo agregado
- [x] Rake task de limpieza creado
- [ ] Tests ejecutados (si existen)
- [ ] Verificación manual en desarrollo

### Post-Despliegue (Desarrollo)

- [ ] Crear registro de prueba
- [ ] Verificar que solo se crea 1 registro
- [ ] Verificar que el ID se asigna correctamente
- [ ] Ejecutar reporte de registros vacíos
- [ ] Ejecutar limpieza de registros vacíos
- [ ] Verificar que no quedan registros vacíos

### Post-Despliegue (Staging)

- [ ] Ejecutar reporte de registros vacíos
- [ ] Ejecutar limpieza (con confirmación)
- [ ] Crear registros de prueba
- [ ] Monitorear por 24 horas
- [ ] Verificar que no hay errores

### Post-Despliegue (Producción)

- [ ] Backup de base de datos
- [ ] Ejecutar reporte de registros vacíos
- [ ] Ejecutar limpieza en horario de bajo tráfico
- [ ] Monitorear logs
- [ ] Verificar métricas de performance

---

## 🚨 Rollback Plan

Si algo sale mal:

### 1. Revertir Cambio en el Código

```bash
git revert <commit_hash>
git push
```

### 2. Restaurar Registros (si se eliminaron por error)

```bash
# Restaurar desde backup
pg_restore -d ttpngas_production backup.dump -t ttpn_booking_passengers
```

### 3. Verificar Funcionalidad

```ruby
# Crear registro de prueba
TtpnBookingPassenger.create!(...)

# Verificar que funciona
```

---

## 📈 Métricas de Éxito

### Antes

- 🔴 2 registros creados por cada operación
- 🔴 50% de registros son basura
- 🔴 Posibles race conditions
- 🔴 Código complejo

### Después

- ✅ 1 registro creado por cada operación
- ✅ 0% de registros basura (después de limpieza)
- ✅ Sin race conditions
- ✅ Código más simple

---

## 📚 Referencias

- **Análisis completo:** `/documentacion/ANALISIS_CALLBACKS_VERIFICAR_ID.md`
- **Rake task:** `/lib/tasks/cleanup_ttpn_booking_passengers.rake`
- **Modelo modificado:** `/app/models/ttpn_booking_passenger.rb`

---

## 🎯 Próximos Pasos

1. ✅ **Callback eliminado** (completado)
2. ✅ **Rake task creado** (completado)
3. 🔄 **Ejecutar tests** (pendiente)
4. 🔄 **Verificar en desarrollo** (pendiente)
5. 🔄 **Limpiar registros vacíos** (pendiente)
6. 🔄 **Desplegar a staging** (pendiente)
7. 🔄 **Monitorear** (pendiente)
8. 🔄 **Desplegar a producción** (pendiente)

---

**Implementado por:** Antigravity AI  
**Fecha:** 2026-01-15 12:30  
**Estado:** ✅ CÓDIGO MODIFICADO - LISTO PARA PRUEBAS
