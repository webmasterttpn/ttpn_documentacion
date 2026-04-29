# Estándares de API — Backend Rails

**Fecha:** 2026-04-11  
**Aplica a:** Todos los controllers en `app/controllers/api/v1/`

---

## 1. Estructura de un Controller

Todo controller sigue esta estructura exacta. No agregar métodos públicos fuera de las acciones REST.

```ruby
# frozen_string_literal: true

class Api::V1::RecursosController < Api::V1::BaseController
  before_action :set_recurso, only: [:show, :update, :destroy]

  def index   ; end
  def show    ; end
  def create  ; end
  def update  ; end
  def destroy ; end

  private

  def set_recurso
    @recurso = Recurso.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: ERR_NOT_FOUND }, status: :not_found
  end

  def recurso_params
    params.require(:recurso).permit(:campo1, :campo2)
  end
end
```

**Reglas:**
- Siempre `# frozen_string_literal: true`
- `set_recurso` **siempre** usa `rescue ActiveRecord::RecordNotFound` con `ERR_NOT_FOUND`
- `before_action :set_recurso` solo en acciones que necesitan el registro: `[:show, :update, :destroy]`
- Acciones extra (no-CRUD) van en la sección `collection` o `member` de las rutas, nunca inventadas

---

## 2. Formato de Respuestas

### Recurso único — éxito

```ruby
# show / create / update
render json: @recurso                                # simple
render json: serialize_recurso(@recurso)             # con helper privado
render json: RecursoSerializer.new(@recurso).as_json # con serializer
```

### Colección con paginación

El formato estándar para índices paginados. **Siempre incluir `meta`.**

```ruby
render json: {
  data: @recursos.map { |r| serialize_recurso(r) },
  meta: {
    current_page: page,
    per_page:     per_page,
    total_count:  total_count,
    total_pages:  (total_count.to_f / per_page).ceil
  }
}
```

> **Inconsistencia actual conocida:** algunos controllers usan `data/meta`, otros usan `pagination`. Nuevo código usa `data/meta`. Al tocar un controller viejo, migrar al mismo tiempo.

### Error de validación

```ruby
render json: { errors: @recurso.errors.full_messages }, status: :unprocessable_content
```

Siempre array, nunca string. El FE hace `error.response.data.errors.join(', ')`.

### Error de negocio (no de validación)

```ruby
render json: { error: 'Mensaje explicativo' }, status: :unprocessable_content
# o
render json: { error: ERR_NOT_FOUND }, status: :not_found
```

Constantes definidas en `BaseController`:

| Constante | Mensaje |
|---|---|
| `ERR_NOT_FOUND` | `'Recurso no encontrado'` |
| `ERR_UNAUTHORIZED` | `'Sesión expirada o inválida (No JWT found)'` |
| `ERR_INVALID_TOKEN` | `'Token inválido'` |
| `ERR_EXPIRED_TOKEN` | `'Token expirado'` |
| `ERR_REVOKED_TOKEN` | `'Token revocado'` |
| `ERR_CREDENTIALS` | `'Credenciales inválidas'` |

### Delete exitoso

```ruby
head :no_content  # 204, sin body
```

---

## 3. Paginación

Parámetros estándar que el FE envía:

| Parámetro | Default | Descripción |
|---|---|---|
| `page` | `1` | Página solicitada |
| `per_page` | `20` ó `50` | Registros por página |

```ruby
page     = params[:page]&.to_i     || 1
per_page = params[:per_page]&.to_i || 20

# Con kaminari (preferido para queries complejas):
@records = scope.page(page).per(per_page)
total    = scope.count

# Con limit/offset (para queries simples):
@records = scope.limit(per_page).offset((page - 1) * per_page)
total    = scope.count
```

**Sin paginación:** cuando se usan para dropdowns, limitar siempre a 500 con `.limit(500)`. Nunca retornar todos los registros sin límite.

---

## 4. Filtros

Los filtros se aplican progresivamente sobre el scope. Cada filtro es opcional e independiente.

```ruby
def index
  scope = Recurso.includes(:asociacion)
  
  # Filtro por ID foráneo
  scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
  
  # Filtro boolean
  scope = scope.where(status: params[:status] == 'true') if params[:status].present?
  
  # Filtro por rango de fechas (patrón estándar)
  if params[:fecha_inicio].present? && params[:fecha_fin].present?
    scope = scope.where(fecha: params[:fecha_inicio]..params[:fecha_fin])
  elsif params[:fecha_inicio].present?
    scope = scope.where('fecha >= ?', params[:fecha_inicio])
  elsif params[:fecha_fin].present?
    scope = scope.where('fecha <= ?', params[:fecha_fin])
  end
  
  # Búsqueda de texto — siempre ILIKE (case-insensitive), nunca LIKE
  if params[:search].present?
    term = "%#{params[:search]}%"
    scope = scope.where('campo ILIKE ? OR otro_campo ILIKE ?', term, term)
  end
  
  scope = scope.order(created_at: :desc)
  # ... paginación y render
end
```

**Reglas de filtros:**
- Siempre `params[:x].present?` antes de aplicar — nunca `if params[:x]`
- Búsquedas de texto: `ILIKE` para case-insensitive (PostgreSQL)
- Búsqueda por nombre completo: `CONCAT(nombre, ' ', apaterno, ' ', amaterno) ILIKE ?`
- Joins para filtrar por asociaciones: preferir `.joins` sobre `.includes` cuando solo se filtra (no se serializa)

---

## 5. Eager Loading (N+1)

Regla: **nunca** hacer una query dentro de un `.map` o bucle.

```ruby
# ❌ MAL — N+1 queries
@bookings.map { |b| { cliente: b.client.razon_social } }

# ✅ BIEN — 1 query con includes
@bookings = TtpnBooking.includes(:client, :vehicle, :employee)
@bookings.map { |b| { cliente: b.client&.razon_social } }
```

**Patrón de serialización en el controller:**

Para recursos sin serializer dedicado, usar un método `serialize_x` privado en el controller:

```ruby
private

def serialize_gas_charge(charge, detailed: false)
  base = {
    id:          charge.id,
    vehicle_clv: charge.vehicle&.clv,  # safe navigation siempre
    monto:       charge.monto,
    fecha:       charge.fecha,
    hora:        charge.hora&.strftime('%H:%M')
  }
  base.merge!(lat: charge.lat, lng: charge.lng) if detailed
  base
end
```

Para modelos complejos con muchos campos o vistas diferentes (minimal vs full), usar un Serializer:

```ruby
# app/serializers/employee_serializer.rb
class EmployeeSerializer
  def initialize(employee, minimal: false)
    @e = employee
    @minimal = minimal
  end

  def as_json
    @minimal ? minimal_json : full_json
  end
  # ...
end
```

---

## 6. Filtrado por Business Unit

**Todos los controllers** que devuelven datos de empleados, vehículos, clientes, etc. deben respetar la Business Unit del usuario.

```ruby
# Opción A — scope en el modelo (preferida para modelos con scope definido)
@employees = Employee.business_unit_filter.where(...)

# Opción B — filtro explícito (para modelos sin scope)
if @business_unit_id
  scope = scope.where(business_unit_id: @business_unit_id)
end
# @business_unit_id viene de BaseController#set_business_unit_id
# Es nil si el usuario es sadmin (puede ver todo)
```

---

## 7. Acciones Extra (no-CRUD)

Las acciones que no son index/show/create/update/destroy se declaran en las rutas así:

```ruby
# Para acciones sobre un registro específico (member):
resources :employees do
  member do
    patch :activate    # PATCH /api/v1/employees/:id/activate
    patch :deactivate  # PATCH /api/v1/employees/:id/deactivate
  end
end

# Para acciones sobre la colección (collection):
resources :ttpn_bookings do
  collection do
    get  :stats   # GET /api/v1/ttpn_bookings/stats
    post :import  # POST /api/v1/ttpn_bookings/import
  end
end
```

En el controller, estas acciones son métodos públicos normales:

```ruby
def activate
  @employee.update(status: true)
  render json: EmployeeSerializer.new(@employee, minimal: true).as_json
end
```

---

## 8. Jobs Asíncronos (Sidekiq)

Cuando una acción tarda más de ~2 segundos, usar un job. El controller retorna el `job_id` inmediatamente.

```ruby
def import
  job_id = TtpnBookingImportJob.perform_async(params[:file], current_user.id)
  render json: { job_id: job_id, message: 'Procesando...' }, status: :accepted
end

# Endpoint de status que el FE consulta periódicamente:
def import_status
  status = Sidekiq::Status::status(params[:job_id])
  pct    = Sidekiq::Status::pct_complete(params[:job_id])
  render json: { status: status, progress: pct }
end
```

**Colas disponibles:**

| Cola | Uso |
|---|---|
| `default` | Jobs generales |
| `payrolls` | Cálculo de nómina (jobs pesados) |
| `alerts` | Dispatch de alertas |

---

## 9. Rutas — Convenciones de Nombres

- Recursos: **snake_case plural** → `travel_counts`, `ttpn_bookings`, `gas_charges`
- Namespace API: siempre bajo `api/v1`
- Las rutas están divididas por dominio en `config/routes/`:
  - `auth.rb`, `vehicles.rb`, `employees.rb`, `clients.rb`, `bookings.rb`, `payroll.rb`, `fuel.rb`, `administration.rb`, `alerts.rb`, `dashboard.rb`
- Agregar recursos nuevos al archivo de dominio correspondiente, no a `routes.rb` directamente

---

## 10. Params — Whitelist

Nunca `params.permit!`. Siempre whitelist explícita:

```ruby
def recurso_params
  params.require(:recurso).permit(
    :campo1, :campo2,
    nested_attributes: [:id, :campo, :_destroy]
  )
end
```

El `require(:recurso)` corresponde al wrapper que envía el FE: `{ recurso: { campo1: ... } }`.

---

## 11. Auditoría (created_by / updated_by)

Los modelos que tienen `created_by_id` / `updated_by_id` se llenan en el controller, no en el modelo:

```ruby
def create
  @recurso = Recurso.new(recurso_params)
  @recurso.created_by_id = current_user.id
  # ...
end

def update
  @recurso.updated_by_id = current_user.id
  @recurso.update(recurso_params)
  # ...
end
```

Para campos legacy con nombre de usuario en texto (`created_by` string):

```ruby
@gas_charge.created_by = current_user&.nombre || 'API'
```

---

## 12. Testing — Cobertura mínima 85 %

**Stack:** `rspec-rails`, `factory_bot_rails`, `faker`, `shoulda-matchers`, `simplecov`

### Regla general

> Por cada **controller, modelo, servicio o concern** nuevo o modificado, se requiere su spec correspondiente antes de hacer merge. La cobertura global medida por SimpleCov no debe bajar del **85 %**.

### 12.1 Model specs — `spec/models/`

Cubrir obligatoriamente:

| Qué testear | Ejemplo |
|---|---|
| Validaciones de presencia/unicidad | `expect(build(:recurso, campo: nil)).not_to be_valid` |
| Asociaciones | `should belong_to(:client)` (shoulda-matchers) |
| Scopes con datos reales | crear registros y verificar que el scope los filtra |
| Métodos de instancia no triviales | resultado esperado vs. resultado real |

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Recurso, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:nombre) }
    it { should validate_uniqueness_of(:clv).case_insensitive }
  end

  describe 'associations' do
    it { should belong_to(:client) }
    it { should have_many(:items).dependent(:destroy) }
  end

  describe 'scopes' do
    describe '.activos' do
      it 'returns only active records' do
        activo  = create(:recurso, status: true)
        inactivo = create(:recurso, status: false)
        expect(Recurso.activos).to include(activo)
        expect(Recurso.activos).not_to include(inactivo)
      end
    end
  end

  describe '#metodo_de_instancia' do
    it 'returns expected value' do
      recurso = build(:recurso, campo: 'valor')
      expect(recurso.metodo_de_instancia).to eq('resultado esperado')
    end
  end
end
```

### 12.2 Request (controller) specs — `spec/requests/api/v1/`

Cubrir los **happy paths** de todas las acciones REST y al menos un **error path** por acción (401, 404, 422).

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Recursos', type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }   # helper en spec/support/

  describe 'GET /api/v1/recursos' do
    it 'returns paginated list' do
      create_list(:recurso, 3)
      get '/api/v1/recursos', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data'].size).to eq(3)
      expect(json_body['meta']).to include('total_count', 'current_page')
    end

    it 'returns 401 without token' do
      get '/api/v1/recursos'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/recursos' do
    it 'creates recurso with valid params' do
      post '/api/v1/recursos', params: { recurso: attributes_for(:recurso) }, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 with invalid params' do
      post '/api/v1/recursos', params: { recurso: { nombre: nil } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_body['errors']).to be_an(Array)
    end
  end
end
```

**Helper `json_body`** (agregar en `spec/support/request_helpers.rb`):
```ruby
module RequestHelpers
  def json_body
    JSON.parse(response.body)
  end
end
```

### 12.3 Service specs — `spec/services/`

Los servicios son Plain Old Ruby Objects — testearlos con datos reales de BD (no mocks de BD).

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::Routing::PassengerClusterer do
  describe '#call' do
    it 'groups nearby passengers into a single cluster' do
      passengers = create_list(:route_passenger, 3, :nearby)
      result = described_class.new(passengers, radius_m: 400).call
      expect(result.size).to eq(1)
      expect(result.first[:passengers].size).to eq(3)
    end

    it 'creates separate clusters for distant passengers' do
      p1 = create(:route_passenger, lat: 28.69, lng: -106.10)
      p2 = create(:route_passenger, lat: 28.72, lng: -106.05)
      result = described_class.new([p1, p2], radius_m: 400).call
      expect(result.size).to eq(2)
    end
  end
end
```

### 12.4 Concern specs — `spec/models/concerns/`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auditable, type: :model do
  # Usar un modelo de prueba anónimo para no acoplar al concern con un modelo real
  let(:klass) do
    Class.new(ApplicationRecord) do
      self.table_name = 'employees'
      include Auditable
    end
  end

  it 'sets created_by_id before create' do
    # ...
  end
end
```

### 12.5 Factories — `spec/factories.rb`

Una factory por modelo. Usar `sequence` para campos únicos. Usar `trait` para variantes en lugar de factories adicionales.

```ruby
FactoryBot.define do
  factory :recurso do
    sequence(:clv) { |n| "REC-#{n.to_s.rjust(3, '0')}" }
    nombre  { Faker::Company.name }
    status  { true }
    association :client

    trait :inactive do
      status { false }
    end

    trait :with_items do
      after(:create) { |r| create_list(:item, 2, recurso: r) }
    end
  end
end
```

### 12.6 Ejecutar y medir cobertura

```bash
# Correr todos los specs con cobertura
COVERAGE=true bundle exec rspec

# Solo un directorio
bundle exec rspec spec/requests/api/v1/

# Un archivo
bundle exec rspec spec/models/employee_spec.rb

# Ver reporte HTML
open coverage/index.html
```

SimpleCov está configurado en `spec/spec_helper.rb`. Si la cobertura baja del 85 % el build de CI falla.

---

## 13. Swagger — Documentación con rswag

**Stack:** `rswag`, `rswag-specs`, `rswag-ui`, `rswag-api`

Los specs de Swagger van en `spec/requests/api/v1/` junto a los request specs normales, pero usando la DSL de rswag. Un mismo archivo puede tener ambos estilos.

### Cuándo documentar con Swagger

- **Obligatorio:** endpoints consumidos por terceros o por el portal de cliente
- **Obligatorio:** endpoints nuevos en módulos nuevos (routing, alertas, etc.)
- **Opcional:** endpoints internos de admin que no tienen integración externa

### Estructura del spec rswag

```ruby
# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Recursos API', type: :request do
  path '/api/v1/recursos' do
    get 'Lista recursos' do
      tags        'Recursos'
      security    [{ bearerAuth: [] }]
      produces    'application/json'
      parameter   name: :page,     in: :query, type: :integer, required: false
      parameter   name: :per_page, in: :query, type: :integer, required: false

      response '200', 'Lista paginada' do
        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Recurso' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }
        let(:Authorization) { "Bearer #{auth_token(create(:user))}" }
        run_test!
      end

      response '401', 'No autenticado' do
        let(:Authorization) { 'Bearer invalido' }
        run_test!
      end
    end

    post 'Crea recurso' do
      tags        'Recursos'
      security    [{ bearerAuth: [] }]
      consumes    'application/json'
      produces    'application/json'
      parameter   name: :body, in: :body, schema: { '$ref' => '#/components/schemas/RecursoInput' }

      response '201', 'Creado' do
        let(:Authorization) { "Bearer #{auth_token(create(:user))}" }
        let(:body) { { recurso: attributes_for(:recurso) } }
        run_test!
      end

      response '422', 'Validación fallida' do
        let(:Authorization) { "Bearer #{auth_token(create(:user))}" }
        let(:body) { { recurso: { nombre: nil } } }
        run_test!
      end
    end
  end
end
```

### Schemas compartidos

Definir en `spec/swagger_helper.rb` dentro de `components.schemas`:

```ruby
'Recurso' => {
  type: :object,
  properties: {
    id:     { type: :integer },
    nombre: { type: :string },
    status: { type: :boolean }
  },
  required: %w[id nombre]
},
'PaginationMeta' => {
  type: :object,
  properties: {
    current_page: { type: :integer },
    per_page:     { type: :integer },
    total_count:  { type: :integer },
    total_pages:  { type: :integer }
  }
}
```

### Generar el archivo swagger.yaml

```bash
bundle exec rake rswag:specs:swaggerize
```

El archivo se genera en `swagger/v1/swagger.yaml` y es servido en `/api-docs` por rswag-ui.