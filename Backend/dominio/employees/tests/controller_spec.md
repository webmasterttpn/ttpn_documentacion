# Specs de Controller (Request Specs) — Dominio Employees

## Employees Controller

Archivo: `spec/requests/api/v1/employees_spec.rb`

### Qué cubrir mínimo

```ruby
RSpec.describe 'Api::V1::Employees', type: :request do
  let(:business_unit) { create(:business_unit) }
  let(:user)          { create(:user, business_unit: business_unit) }
  let(:headers)       { auth_headers(user) }

  describe 'GET /api/v1/employees' do
    it 'returns employees filtered by BU' do
      create(:employee, business_unit: business_unit)
      create(:employee) # otra BU
      get '/api/v1/employees', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body.size).to eq(1)
    end

    it 'returns 401 without token' do
      get '/api/v1/employees'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/employees/:id' do
    let(:employee) { create(:employee, business_unit: business_unit) }

    it 'returns the employee with movements and documents' do
      get "/api/v1/employees/#{employee.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body['id']).to eq(employee.id)
    end

    it 'returns 404 for employee of another BU' do
      other_emp = create(:employee) # otra BU
      get "/api/v1/employees/#{other_emp.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/employees' do
    let(:valid_params) do
      { employee: { clv: 'EMP-001', nombre: 'Juan', apaterno: 'Pérez', labor_id: create(:labor).id } }
    end

    it 'creates employee and assigns business_unit from Current' do
      post '/api/v1/employees', params: valid_params, headers: headers
      expect(response).to have_http_status(:created)
      expect(Employee.last.business_unit_id).to eq(business_unit.id)
    end

    it 'returns 422 with validation errors' do
      post '/api/v1/employees', params: { employee: { clv: '' } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to be_present
    end
  end
end
```

## Employee Stats Controller

Archivo: `spec/requests/api/v1/employee_stats_spec.rb`

### Qué cubrir

- `GET /api/v1/employee_stats?year=2026` → retorna estructura completa de KPIs
- `promedio_plantilla` usa `active_headcount_at`, no `Employee.count` histórico
- Sin token → 401
