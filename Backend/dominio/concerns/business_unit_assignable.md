# BusinessUnitAssignable (model concern)

## Qué hace

Dos responsabilidades:
1. Agrega el scope `business_unit_filter` al modelo.
2. Auto-asigna `business_unit_id` desde `Current.business_unit` al crear un registro, si el campo está en blanco.

## Incluir en

```ruby
class MiModelo < ApplicationRecord
  include BusinessUnitAssignable
end
```

Requiere columna `business_unit_id :bigint` en la tabla.

## Lo que agrega

### Scope `business_unit_filter`

```ruby
scope :business_unit_filter, -> {
  bu = Current.business_unit
  bu ? where(business_unit_id: bu.id) : all
}
```

> **Nota:** Este scope retorna `all` cuando no hay BU (sadmin ve todo). `Employee.business_unit_filter` sobreescribe este comportamiento retornando `none` en ese caso — revisar cada modelo.

### Callback `before_create :assign_business_unit_from_current`

Asigna `business_unit_id` desde `Current.business_unit&.id` si está en blanco. El controller no necesita enviar este campo en los params.

## Modelos que lo incluyen

- `Vehicle` (pero sobreescribe `business_unit_filter` con lógica via concessionaires)

## Archivos relacionados

- `app/models/concerns/business_unit_assignable.rb`
