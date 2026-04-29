# 📊 Auditoría y Caching - Guía de Implementación

## 📋 Tabla de Contenidos

1. [Auditoría (created_by/updated_by)](#auditoría)
2. [Caching Inteligente](#caching-inteligente)
3. [Implementación en Modelos](#implementación-en-modelos)
4. [Uso en Controladores](#uso-en-controladores)
5. [Respuestas API](#respuestas-api)
6. [Testing](#testing)

---

## 🔍 Auditoría (created_by/updated_by)

### Objetivo

Mantener un historial de **quién creó** y **quién modificó** cada registro, más allá de los timestamps automáticos.

### Implementación

#### 1. Migración

```bash
# Ejecutar migración
docker-compose exec app rails db:migrate
```

La migración agrega a cada tabla:

- `created_by_id` - ID del usuario que creó el registro
- `updated_by_id` - ID del usuario que modificó el registro

#### 2. Concern `Auditable`

**Ubicación:** `app/models/concerns/auditable.rb`

**Características:**

- ✅ Asigna automáticamente `created_by_id` al crear
- ✅ Actualiza `updated_by_id` en cada modificación
- ✅ Asociaciones `creator` y `updater` para acceder al usuario
- ✅ Métodos helper: `created_by_name`, `updated_by_name`
- ✅ Scopes útiles: `created_by(user)`, `updated_by(user)`

#### 3. Uso en Modelos

```ruby
class Vehicle < ApplicationRecord
  include Auditable

  # ... resto del modelo
end
```

#### 4. Métodos Disponibles

```ruby
vehicle = Vehicle.find(1)

# Obtener nombres
vehicle.created_by_name  # => "Juan Pérez"
vehicle.updated_by_name  # => "María García"

# Obtener usuarios completos
vehicle.creator  # => #<User id: 5, name: "Juan Pérez">
vehicle.updater  # => #<User id: 8, name: "María García">

# Trail completo
vehicle.audit_trail
# => {
#   created_at: "2025-01-15 10:30:00",
#   created_by: "Juan Pérez",
#   updated_at: "2025-01-18 14:20:00",
#   updated_by: "María García"
# }

# Scopes
Vehicle.created_by(current_user)
Vehicle.updated_by(current_user)
Vehicle.recent_changes  # Ordenado por updated_at desc
```

---

## ⚡ Caching Inteligente

### Objetivo

Cachear recursos que **cambian poco** (vehículos, tipos, catálogos) para mejorar performance del frontend.

### Características

- ✅ Cache automático con TTL configurable
- ✅ Invalidación automática en create/update/destroy
- ✅ Métodos helper para acceso cacheado
- ✅ Soporte para filtros por company

### Implementación

#### 1. Concern `Cacheable`

**Ubicación:** `app/models/concerns/cacheable.rb`

**Configuración:**

```ruby
class Vehicle < ApplicationRecord
  include Cacheable

  # TTL personalizado (default: 30 minutos)
  self.cache_ttl = 1.hour
end
```

#### 2. Métodos Disponibles

```ruby
# Obtener todos (cacheado)
vehicles = Vehicle.cached_all

# Obtener activos (cacheado)
vehicles = Vehicle.cached_active

# Obtener por ID (cacheado)
vehicle = Vehicle.cached_find(123)

# Obtener por company (cacheado)
vehicles = Vehicle.cached_by_company(5)

# Limpiar cache manualmente
Vehicle.clear_all_cache
```

#### 3. Invalidación Automática

El cache se invalida automáticamente cuando:

- Se crea un nuevo registro
- Se actualiza un registro
- Se elimina un registro

```ruby
# Esto invalida el cache automáticamente
vehicle = Vehicle.create(clv: "ABC123", ...)  # Cache cleared
vehicle.update(marca: "Toyota")               # Cache cleared
vehicle.destroy                               # Cache cleared
```

---

## 🎯 Implementación en Modelos

### Modelos que Deben Usar Auditable

**Alta prioridad:**

- ✅ `Vehicle` - Vehículos
- ✅ `Client` - Clientes
- ✅ `Employee` - Empleados
- ✅ `Maintenance` - Mantenimientos
- ✅ `Company` - Empresas
- ✅ `CompanySubsidiary` - Sucursales

**Media prioridad:**

- `AccountReceivable` - Cuentas por cobrar
- `AccountPayable` - Cuentas por pagar
- `PaymentTransaction` - Transacciones

### Modelos que Deben Usar Cacheable

**Recursos que cambian poco:**

- ✅ `Vehicle` - Vehículos (TTL: 1 hora)
- ✅ `VehicleType` - Tipos de vehículo (TTL: 24 horas)
- ✅ `Role` - Roles (TTL: 24 horas)
- ✅ `Company` - Empresas (TTL: 2 horas)
- ✅ `CompanySubsidiary` - Sucursales (TTL: 2 horas)

**Recursos que NO deben cachearse:**

- ❌ `PaymentTransaction` - Cambian frecuentemente
- ❌ `Notification` - Tiempo real
- ❌ `AccountReceivable` - Actualizaciones frecuentes

### Ejemplo Completo

```ruby
class Vehicle < ApplicationRecord
  # Concerns
  include Auditable
  include Cacheable

  # Configuración
  self.cache_ttl = 1.hour

  # Asociaciones
  belongs_to :vehicle_type
  # ... resto de asociaciones

  # Validaciones
  validates :clv, presence: true, uniqueness: true

  # Scopes
  scope :available, -> { where(status: 'available') }
end
```

---

## 🎮 Uso en Controladores

### Ejemplo: VehiclesController

```ruby
module Api
  module V1
    class VehiclesController < BaseController
      # GET /api/v1/vehicles
      def index
        # Cache key único por company y business unit
        cache_key = "vehicles/company/#{Current.user&.company_id}/#{Current.business_unit&.id}"

        # Obtener de cache o ejecutar query
        @vehicles = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          Vehicle.business_unit_filter
                 .includes(:vehicle_type, :concessionaires, :vehicle_documents, :creator, :updater)
                 .order(clv: :asc)
                 .to_a
        end

        render json: @vehicles.as_json(
          only: [:id, :clv, :marca, :modelo, :annio],
          methods: [:created_by_name, :updated_by_name],
          include: {
            vehicle_type: { only: [:id, :nombre] }
          }
        ).map do |vehicle_json|
          vehicle_json.merge(
            audit: {
              created_at: vehicle_json['created_at'],
              created_by: vehicle_json['created_by_name'],
              updated_at: vehicle_json['updated_at'],
              updated_by: vehicle_json['updated_by_name']
            }
          )
        end
      end

      # POST /api/v1/vehicles
      def create
        @vehicle = Vehicle.new(vehicle_params)

        # created_by_id se asigna automáticamente por Auditable
        if @vehicle.save
          # Cache se invalida automáticamente
          render json: @vehicle, status: :created
        else
          render json: { errors: @vehicle.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/vehicles/:id
      def update
        # updated_by_id se actualiza automáticamente
        if @vehicle.update(vehicle_params)
          # Cache se invalida automáticamente
          render json: @vehicle
        else
          render json: { errors: @vehicle.errors }, status: :unprocessable_entity
        end
      end
    end
  end
end
```

---

## 📡 Respuestas API

### Formato de Respuesta con Auditoría

```json
{
  "id": 123,
  "clv": "VEH-001",
  "marca": "Toyota",
  "modelo": "Corolla",
  "annio": 2023,
  "audit": {
    "created_at": "2025-01-15T10:30:00Z",
    "created_by": "Juan Pérez",
    "updated_at": "2025-01-18T14:20:00Z",
    "updated_by": "María García"
  },
  "vehicle_type": {
    "id": 1,
    "nombre": "Sedán"
  }
}
```

### Headers de Cache

```http
GET /api/v1/vehicles
X-Cache-Hit: true
X-Cache-Key: vehicles/company/5/business_unit/3
Cache-Control: max-age=3600
```

---

## 🧪 Testing

### RSpec para Auditable

```ruby
# spec/models/vehicle_spec.rb
require 'rails_helper'

RSpec.describe Vehicle, type: :model do
  let(:user) { create(:user, name: 'Test User') }

  before do
    Current.user = user
  end

  describe 'auditing' do
    it 'sets created_by on create' do
      vehicle = Vehicle.create(clv: 'TEST-001', ...)

      expect(vehicle.created_by_id).to eq(user.id)
      expect(vehicle.created_by_name).to eq('Test User')
    end

    it 'sets updated_by on update' do
      vehicle = create(:vehicle)

      vehicle.update(marca: 'Toyota')

      expect(vehicle.updated_by_id).to eq(user.id)
      expect(vehicle.updated_by_name).to eq('Test User')
    end

    it 'returns audit trail' do
      vehicle = create(:vehicle)
      trail = vehicle.audit_trail

      expect(trail).to include(:created_at, :created_by, :updated_at, :updated_by)
      expect(trail[:created_by]).to eq('Test User')
    end
  end
end
```

### RSpec para Cacheable

```ruby
# spec/models/vehicle_spec.rb
RSpec.describe Vehicle, type: :model do
  describe 'caching' do
    it 'caches all vehicles' do
      create_list(:vehicle, 3)

      # Primera llamada - hit DB
      expect {
        Vehicle.cached_all
      }.to change { Vehicle.count }.by(0)

      # Segunda llamada - hit cache
      expect(Rails.cache).to receive(:fetch).and_call_original
      Vehicle.cached_all
    end

    it 'clears cache on create' do
      expect(Rails.cache).to receive(:delete).at_least(:once)

      Vehicle.create(clv: 'TEST-001', ...)
    end

    it 'clears cache on update' do
      vehicle = create(:vehicle)

      expect(Rails.cache).to receive(:delete).at_least(:once)
      vehicle.update(marca: 'Toyota')
    end
  end
end
```

### Request Specs

```ruby
# spec/requests/api/v1/vehicles_spec.rb
RSpec.describe 'Api::V1::Vehicles', type: :request do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.token}" } }

  describe 'GET /api/v1/vehicles' do
    it 'returns vehicles with audit info' do
      vehicle = create(:vehicle, creator: user)

      get '/api/v1/vehicles', headers: headers

      json = JSON.parse(response.body)
      expect(json.first['audit']).to include(
        'created_by' => user.name,
        'updated_by' => user.name
      )
    end

    it 'uses cache on subsequent requests' do
      create_list(:vehicle, 3)

      # Primera request
      get '/api/v1/vehicles', headers: headers

      # Segunda request (debe usar cache)
      expect(Vehicle).not_to receive(:business_unit_filter)
      get '/api/v1/vehicles', headers: headers
    end
  end
end
```

---

## 📊 Monitoreo de Cache

### Ver Estadísticas de Cache

```ruby
# En rails console
Rails.cache.stats

# Ver keys de cache
Rails.cache.instance_variable_get(:@data).keys

# Limpiar cache específico
Rails.cache.delete('vehicles/company/5/business_unit/3')

# Limpiar todo el cache de vehículos
Vehicle.clear_all_cache
```

### Logs

```ruby
# config/environments/development.rb
config.log_level = :debug

# Verás en logs:
# Cache read: vehicles/company/5/business_unit/3
# Cache write: vehicles/company/5/business_unit/3
# Cache cleared for Vehicle #123
```

---

## 🎯 Mejores Prácticas

### 1. Auditoría

✅ **DO:**

- Usar en modelos críticos de negocio
- Incluir en respuestas API cuando sea relevante
- Usar scopes para reportes de auditoría

❌ **DON'T:**

- No usar en tablas de log o tracking (redundante)
- No exponer en APIs públicas (seguridad)

### 2. Caching

✅ **DO:**

- Cachear recursos que cambian poco
- Usar TTL apropiado según frecuencia de cambio
- Incluir filtros relevantes en cache key (company, business_unit)

❌ **DON'T:**

- No cachear datos en tiempo real
- No usar TTL muy largo en datos críticos
- No olvidar invalidar cache en updates

### 3. Performance

```ruby
# ✅ BUENO: Cache con includes
@vehicles = Rails.cache.fetch(cache_key) do
  Vehicle.includes(:vehicle_type, :creator, :updater).to_a
end

# ❌ MALO: Cache sin includes (N+1 queries)
@vehicles = Rails.cache.fetch(cache_key) do
  Vehicle.all.to_a
end
```

---

## 🚀 Próximos Pasos

1. **Ejecutar migración:**

   ```bash
   docker-compose exec app rails db:migrate
   ```

2. **Agregar concerns a otros modelos:**

   ```ruby
   # app/models/client.rb
   class Client < ApplicationRecord
     include Auditable
     include Cacheable
     self.cache_ttl = 30.minutes
   end
   ```

3. **Actualizar controladores** para usar cache

4. **Agregar tests** para auditoría y caching

5. **Monitorear performance** en producción

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0
