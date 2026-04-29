# Specs de Modelo — Dominio Employees

## Employee

Archivo: `spec/models/employee_spec.rb`

### Qué cubrir

```ruby
RSpec.describe Employee, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:clv) }
    it { should validate_uniqueness_of(:clv) }
    it { should validate_presence_of(:nombre) }
    it { should validate_presence_of(:apaterno) }
  end

  describe 'associations' do
    it { should belong_to(:business_unit).optional }
    it { should belong_to(:labor) }
    it { should have_many(:employee_movements).dependent(:destroy) }
    it { should have_many(:employee_documents).dependent(:destroy) }
  end

  describe '#fecha_inicio_actual' do
    it 'returns the latest Alta/Reingreso fecha_efectiva' do
      emp = create(:employee)
      alta = create(:employee_movement, :alta, employee: emp, fecha_efectiva: '2024-03-01')
      expect(emp.fecha_inicio_actual).to eq(Date.parse('2024-03-01'))
    end

    it 'falls back to created_at when no movements exist' do
      emp = create(:employee)
      expect(emp.fecha_inicio_actual).to eq(emp.created_at.to_date)
    end
  end

  describe '.business_unit_filter' do
    it 'returns only employees of the current BU' do
      bu1 = create(:business_unit)
      bu2 = create(:business_unit)
      emp1 = create(:employee, business_unit: bu1)
      emp2 = create(:employee, business_unit: bu2)

      Current.business_unit = bu1
      expect(Employee.business_unit_filter).to include(emp1)
      expect(Employee.business_unit_filter).not_to include(emp2)
    end

    it 'returns none when no BU is set' do
      Current.business_unit = nil
      expect(Employee.business_unit_filter).to be_empty
    end
  end
end
```

## EmployeeMovement

Archivo: `spec/models/employee_movement_spec.rb`

### Qué cubrir

```ruby
RSpec.describe EmployeeMovement, type: :model do
  describe 'valida_transicion' do
    it 'prevents a second Alta for the same employee' do
      emp = create(:employee)
      create(:employee_movement, :alta, employee: emp)
      second_alta = build(:employee_movement, :alta, employee: emp)
      expect(second_alta).not_to be_valid
      expect(second_alta.errors[:base]).to include(/Alta solo puede ocurrir una vez/)
    end

    it 'prevents Baja without active Alta or Reingreso' do
      emp = create(:employee)
      baja = build(:employee_movement, :baja, employee: emp)
      expect(baja).not_to be_valid
    end
  end

  describe 'cerrar_movimiento_previo' do
    it 'sets fecha_expiracion on the previous Alta when Baja is created' do
      emp  = create(:employee)
      alta = create(:employee_movement, :alta, employee: emp, fecha_efectiva: '2024-01-01')
      baja = create(:employee_movement, :baja, employee: emp, fecha_efectiva: '2025-06-01')
      expect(alta.reload.fecha_expiracion).to eq(Date.parse('2025-06-01'))
    end
  end

  describe 'revisar_status_chofer' do
    it 'sets employee status to false after Baja' do
      emp = create(:employee, status: true)
      create(:employee_movement, :alta, employee: emp)
      create(:employee_movement, :baja, employee: emp)
      expect(emp.reload.status).to be false
    end
  end
end
```
