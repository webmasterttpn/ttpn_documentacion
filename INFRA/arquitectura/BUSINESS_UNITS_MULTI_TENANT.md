# 🏢 Control de Acceso Multi-Tenant con Business Units

## 📋 Visión General

El sistema TTPN Admin utiliza **Business Units** (Unidades de Negocio) como mecanismo de **multi-tenancy** para separar datos entre diferentes organizaciones o divisiones.

---

## 🎯 Arquitectura de Business Units

### Modelo de Datos

```
User
  ├── business_unit_id (FK)
  └── belongs_to :business_unit

BusinessUnit
  ├── id
  ├── clv (código único)
  ├── nombre
  └── has_many :users

Vehicle
  └── Filtrado por business_unit via concessionaires

Concessionaire
  └── Asociado a business_units via tabla intermedia
```

### Flujo de Autenticación y Contexto

```
1. Usuario hace login
   ↓
2. Devise autentica al usuario
   ↓
3. BaseController ejecuta set_current_attributes
   ↓
4. Current.user = current_user
   ↓
5. Current automáticamente asigna:
   - Current.business_unit = user.business_unit
   - Current.role = user.role
   ↓
6. Todos los scopes usan Current.business_unit
```

---

## 🔒 Scopes de Seguridad

### Vehicle.business_unit_filter

**Ubicación:** `app/models/vehicle.rb`

```ruby
scope :business_unit_filter, -> {
  # 1. Si es Super Admin (rol 1), ve todo
  return all if Current.user&.role_id == 1

  # 2. Si no tiene unidad de negocio, no ve nada
  return none unless Current.business_unit

  # 3. Filtro por business unit
  joins(:concessionaires)
    .where(concessionaires_vehicles: {
      concessionaire_id: BusinessUnitsConcessionaire.select(:concessionaire_id)
                                                    .where(business_unit_id: Current.business_unit.id)
    })
    .distinct
}
```

**Cómo Funciona:**

1. **Super Admin:** Ve todos los vehículos de todas las business units
2. **Usuario Normal:** Solo ve vehículos de su business unit
3. **Sin Business Unit:** No ve nada (seguridad por defecto)

---

## 💾 Caching por Business Unit

### Estrategia de Cache

```ruby
# app/controllers/api/v1/vehicles_controller.rb
def index
  # Cache único por business unit
  cache_key = "vehicles/business_unit/#{Current.business_unit&.id}"

  @vehicles = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    Vehicle.business_unit_filter
           .includes(:vehicle_type, :concessionaires, :vehicle_documents)
           .order(clv: :asc)
           .to_a
  end

  render json: @vehicles.map { |vehicle| VehicleSerializer.new(vehicle).as_json }
end
```

**Ventajas:**

- ✅ Cache separado por business unit
- ✅ No hay "leakage" de datos entre units
- ✅ Invalidación automática por unit
- ✅ Performance optimizada

---

## 🔑 API Keys y Business Units

### Asociación

```ruby
# API Key pertenece a un User
# User pertenece a un Business Unit
# Por lo tanto, API Key hereda el business unit

ApiKey
  └── belongs_to :user
        └── belongs_to :business_unit
```

### Flujo con API Keys

```
1. Request con X-API-Key header
   ↓
2. Middleware autentica la API key
   ↓
3. env['api_key_user'] = api_key.user
   ↓
4. BaseController asigna:
   Current.user = api_key.user
   Current.business_unit = api_key.user.business_unit
   ↓
5. Scopes filtran por business_unit automáticamente
```

**Ejemplo:**

```bash
# API Key de Business Unit 1
curl -X GET "http://localhost:3000/api/v1/vehicles" \
  -H "X-API-Key: key_de_business_unit_1"

# Solo retorna vehículos de Business Unit 1
```

---

## 🎛️ Configuración de Business Units

### Crear Business Unit

```ruby
# Rails console
business_unit = BusinessUnit.create!(
  clv: 'BU-NORTE',
  nombre: 'Unidad Norte'
)
```

### Asignar Usuario a Business Unit

```ruby
user = User.find_by(email: 'usuario@example.com')
user.update!(business_unit_id: business_unit.id)
```

### Asociar Concesionaria a Business Unit

```ruby
# Tabla intermedia: business_units_concessionaires
BusinessUnitsConcessionaire.create!(
  business_unit_id: business_unit.id,
  concessionaire_id: concessionaire.id
)
```

---

## 📊 Ejemplo Completo

### Escenario

```
Business Unit Norte (ID: 1)
  ├── Usuario: Juan (ID: 10)
  ├── Concesionaria: Norte Motors (ID: 5)
  └── Vehículos: VEH-001, VEH-002

Business Unit Sur (ID: 2)
  ├── Usuario: María (ID: 20)
  ├── Concesionaria: Sur Motors (ID: 6)
  └── Vehículos: VEH-003, VEH-004

Super Admin (Role ID: 1)
  └── Usuario: Admin (ID: 1)
      └── Ve TODOS los vehículos
```

### Requests

**Juan (Business Unit Norte) hace login:**

```ruby
Current.user.id              # => 10
Current.business_unit.id     # => 1
Current.business_unit.nombre # => "Unidad Norte"

# GET /api/v1/vehicles
# Retorna: [VEH-001, VEH-002]
```

**María (Business Unit Sur) hace login:**

```ruby
Current.user.id              # => 20
Current.business_unit.id     # => 2
Current.business_unit.nombre # => "Unidad Sur"

# GET /api/v1/vehicles
# Retorna: [VEH-003, VEH-004]
```

**Admin (Super Admin) hace login:**

```ruby
Current.user.id      # => 1
Current.user.role_id # => 1

# GET /api/v1/vehicles
# Retorna: [VEH-001, VEH-002, VEH-003, VEH-004]
```

---

## 🛡️ Seguridad

### Validaciones Automáticas

1. **BaseController:**

   ```ruby
   before_action :authenticate_user!
   before_action :set_current_attributes
   ```

2. **Current Model:**

   ```ruby
   def self.user=(user)
     Thread.current[:current_user] = user
     Thread.current[:business_unit] = user&.business_unit
     Thread.current[:role] = user&.role
   end
   ```

3. **Scopes:**
   ```ruby
   # Siempre filtran por Current.business_unit
   Vehicle.business_unit_filter
   ```

### Prevención de Leakage

```ruby
# ❌ NUNCA hacer esto:
Vehicle.all  # Retorna TODOS los vehículos

# ✅ SIEMPRE usar:
Vehicle.business_unit_filter  # Filtra por business unit
```

---

## 🔄 Migración a Microservicios

Cuando migremos a microservicios, cada servicio mantendrá el concepto de Business Unit:

```
Auth Service
  └── Valida user + business_unit
        ↓
  JWT Token incluye:
  {
    user_id: 10,
    business_unit_id: 1,
    role_id: 2
  }
        ↓
  Cada servicio valida business_unit_id
```

---

## 📝 Mejores Prácticas

### 1. Siempre Usar Scopes

```ruby
# ✅ BUENO
@vehicles = Vehicle.business_unit_filter

# ❌ MALO
@vehicles = Vehicle.all
```

### 2. Cache por Business Unit

```ruby
# ✅ BUENO
cache_key = "resource/business_unit/#{Current.business_unit&.id}"

# ❌ MALO
cache_key = "resource/all"
```

### 3. Validar Business Unit en Create

```ruby
# ✅ BUENO
def create
  # El business_unit se asigna automáticamente via asociaciones
  @vehicle = Vehicle.new(vehicle_params)
  # ...
end
```

### 4. API Keys Heredan Business Unit

```ruby
# ✅ BUENO
api_key = ApiKey.create!(
  user: current_user,  # Ya tiene business_unit
  name: "Integración ERP",
  permissions: {...}
)
```

---

## 🧪 Testing

### RSpec con Business Units

```ruby
RSpec.describe 'Vehicles API', type: :request do
  let(:business_unit_norte) { create(:business_unit, nombre: 'Norte') }
  let(:business_unit_sur) { create(:business_unit, nombre: 'Sur') }

  let(:user_norte) { create(:user, business_unit: business_unit_norte) }
  let(:user_sur) { create(:user, business_unit: business_unit_sur) }

  let!(:vehicle_norte) { create(:vehicle, business_unit: business_unit_norte) }
  let!(:vehicle_sur) { create(:vehicle, business_unit: business_unit_sur) }

  context 'when user from Norte' do
    before { sign_in user_norte }

    it 'only sees Norte vehicles' do
      get '/api/v1/vehicles'

      json = JSON.parse(response.body)
      expect(json.map { |v| v['id'] }).to include(vehicle_norte.id)
      expect(json.map { |v| v['id'] }).not_to include(vehicle_sur.id)
    end
  end
end
```

---

## 📊 Monitoreo

### Métricas por Business Unit

```ruby
# Vehículos por business unit
BusinessUnit.all.each do |bu|
  count = Vehicle.joins(:concessionaires)
                 .where(concessionaires: {
                   id: bu.concessionaires.pluck(:id)
                 })
                 .distinct
                 .count

  puts "#{bu.nombre}: #{count} vehículos"
end
```

---

## 🎯 Conclusión

El sistema de Business Units proporciona:

- ✅ **Multi-tenancy robusto**
- ✅ **Separación de datos automática**
- ✅ **Cache optimizado por tenant**
- ✅ **Seguridad por defecto**
- ✅ **Escalabilidad a microservicios**

**Última actualización:** 2025-12-18  
**Versión:** 1.0
