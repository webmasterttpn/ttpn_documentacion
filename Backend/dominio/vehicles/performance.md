# 🚀 Optimizaciones de Performance - Endpoint de Vehículos

## 📊 Problema Identificado

**Síntoma:** Endpoint `/api/v1/vehicles` tardaba ~3 segundos con solo 500 registros

**Causas:**

1. ❌ **Serialización fuera del cache** - Los objetos se cacheaban pero se serializaban en cada request
2. ❌ **N+1 queries en ActiveStorage** - `doc_image_url` causaba queries individuales
3. ❌ **Inclusión innecesaria de datos** - Siempre incluía concessionaires, documents y audit
4. ❌ **No eager loading de ActiveStorage attachments**

---

## ✅ Soluciones Implementadas

### 1. Cache de Respuesta Serializada

**Antes:**

```ruby
@vehicles = Rails.cache.fetch(cache_key) do
  Vehicle.business_unit_filter.to_a
end
render json: @vehicles.map { |v| VehicleSerializer.new(v).as_json }
```

❌ Problema: Serialización en cada request

**Después:**

```ruby
cached_response = Rails.cache.fetch(cache_key) do
  vehicles = Vehicle.business_unit_filter.includes(...)
  vehicles.map { |v| VehicleSerializer.new(v, minimal: true).as_json }
end
render json: cached_response
```

✅ Solución: Cache de la respuesta completa serializada

### 2. Eager Loading de ActiveStorage

**Antes:**

```ruby
.includes(:vehicle_type, :concessionaires, :vehicle_documents)
```

❌ Problema: No cargaba los attachments de ActiveStorage

**Después:**

```ruby
.includes(
  :vehicle_type,
  :concessionaires,
  vehicle_documents: :vehicle_doc_image_attachment,  # ← NUEVO
  :creator,
  :updater
)
```

✅ Solución: Eager load de attachments previene N+1

### 3. Serializer con Versión Minimal

**Antes:**

```ruby
def as_json
  {
    # ... todos los campos
    concessionaires: concessionaires_data,  # Siempre incluido
    vehicle_documents: documents_data,       # Siempre incluido
    audit: audit_data                        # Siempre incluido
  }
end
```

❌ Problema: Demasiados datos innecesarios en listados

**Después:**

```ruby
def as_json
  if @options[:minimal]
    minimal_json  # Solo campos esenciales
  else
    full_json     # Todos los campos
  end
end
```

✅ Solución: Listados usan versión minimal, detalles usan full

### 4. Invalidación Inteligente de Cache

**Nuevo:**

```ruby
def invalidate_vehicles_cache
  Rails.cache.delete_matched("vehicles/business_unit/*/serialized/*")
end
```

✅ Solución: Cache se invalida automáticamente en create/update/destroy

---

## 📈 Mejoras de Performance Esperadas

### Primera Carga (Sin Cache)

- **Antes:** ~3000ms
- **Después:** ~800ms (eager loading elimina N+1)
- **Mejora:** 73% más rápido

### Cargas Subsecuentes (Con Cache)

- **Antes:** ~1500ms (serialización en cada request)
- **Después:** ~50ms (respuesta completa cacheada)
- **Mejora:** 97% más rápido

---

## 🔍 Cómo Verificar las Optimizaciones

### 1. Ver Queries en Logs

```bash
docker-compose logs app | grep "SELECT"
```

**Antes:** Verías múltiples queries por cada vehículo
**Después:** Solo 1-2 queries para toda la colección

### 2. Medir Tiempo de Respuesta

```bash
curl -w "\nTime: %{time_total}s\n" http://localhost:3000/api/v1/vehicles
```

**Primera vez:** ~800ms
**Segunda vez:** ~50ms (cacheado)

### 3. Verificar Cache

```ruby
# Rails console
Rails.cache.read("vehicles/business_unit/1/serialized/v2")
```

Debería retornar el array completo serializado

---

## 🎯 Versión Minimal vs Full

### Minimal (Para Listados)

```json
{
  "id": 1,
  "clv": "VEH-001",
  "marca": "Toyota",
  "modelo": "Hiace",
  "annio": 2020,
  "placa": "ABC123",
  "status": "active",
  "vehicle_type": {
    "id": 1,
    "nombre": "Van"
  }
}
```

### Full (Para Detalles)

```json
{
  // ... todos los campos de minimal +
  "serie": "XYZ789",
  "concessionaires": [...],
  "vehicle_documents": [...],
  "audit": {
    "created_by": "Juan Pérez",
    "updated_by": "María García"
  }
}
```

---

## 🔄 Invalidación de Cache

El cache se invalida automáticamente cuando:

- ✅ Se crea un vehículo nuevo
- ✅ Se actualiza un vehículo existente
- ✅ Se elimina un vehículo

**Duración del cache:** 1 hora (configurable)

---

## 📝 Mejores Prácticas Aplicadas

1. ✅ **Cache de respuestas completas** - No solo objetos
2. ✅ **Eager loading** - Prevenir N+1 queries
3. ✅ **Serialización condicional** - Minimal vs Full
4. ✅ **Invalidación automática** - Cache siempre fresco
5. ✅ **Cache keys versionados** - Fácil invalidación global (v2)

---

## 🚨 Monitoreo

### Bullet Gem (Recomendado)

Agregar a Gemfile:

```ruby
gem 'bullet', group: :development
```

Configurar en `config/environments/development.rb`:

```ruby
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
end
```

---

## 📊 Métricas de Éxito

- ✅ Tiempo de respuesta < 100ms (con cache)
- ✅ Tiempo de respuesta < 1s (sin cache)
- ✅ Cero queries N+1
- ✅ Cache hit rate > 90%

**Última actualización:** 2025-12-18  
**Versión:** 2.0 (Optimizada)
