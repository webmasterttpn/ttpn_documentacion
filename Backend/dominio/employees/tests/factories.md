# FactoryBot Factories — Dominio Employees

## Factories existentes

Verificar en `spec/factories/` los archivos actuales antes de crear duplicados.

### `employees.rb`

```ruby
FactoryBot.define do
  factory :employee do
    sequence(:clv) { |n| "EMP-#{n.to_s.rjust(4, '0')}" }
    nombre  { Faker::Name.first_name }
    apaterno { Faker::Name.last_name }
    amaterno { Faker::Name.last_name }
    status  { true }
    association :business_unit
    association :labor

    trait :inactive do
      status { false }
    end

    trait :operaciones do
      area { 'operaciones' }
    end
  end
end
```

### `employee_movements.rb`

```ruby
FactoryBot.define do
  factory :employee_movement do
    association :employee
    association :employee_movement_type
    fecha_efectiva { Date.current }
    fecha_expiracion { nil }

    trait :alta do
      association :employee_movement_type, factory: :employee_movement_type,
                  nombre: EmployeeMovementType::NOMBRE_ALTA
    end

    trait :baja do
      association :employee_movement_type, factory: :employee_movement_type,
                  nombre: EmployeeMovementType::NOMBRE_BAJA
    end
  end
end
```

### `employee_movement_types.rb`

```ruby
FactoryBot.define do
  factory :employee_movement_type do
    nombre { EmployeeMovementType::NOMBRE_ALTA }

    trait :baja do
      nombre { EmployeeMovementType::NOMBRE_BAJA }
    end

    trait :reingreso do
      nombre { EmployeeMovementType::NOMBRE_REINGRESO }
    end

    trait :baja_lista_negra do
      nombre { EmployeeMovementType::NOMBRE_BAJA_LISTA_NEGRA }
    end
  end
end
```

## Nota sobre memoización de IDs

Llamar `EmployeeMovementType.reset_id_cache!` en `spec/support/database_cleaner.rb` o en `before(:each)` cuando el test recrea los tipos, para evitar que los IDs memoizados del proceso apunten a registros eliminados.
