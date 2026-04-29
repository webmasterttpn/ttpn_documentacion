# Auditable (model concern)

## Qué hace

Agrega trazabilidad de quién creó y quién modificó un registro por última vez. Lee `Current.user` (seteado por `BaseController`) para asignar automáticamente los campos.

## Incluir en

```ruby
class MiModelo < ApplicationRecord
  include Auditable
end
```

Requiere columnas `created_by_id :bigint` y `updated_by_id :bigint` en la tabla.

## Lo que agrega

### Asociaciones

- `belongs_to :creator, class_name: 'User', foreign_key: 'created_by_id', optional: true`
- `belongs_to :updater, class_name: 'User', foreign_key: 'updated_by_id', optional: true`

### Scopes

- `.created_by(user)` — filtra por creador.
- `.updated_by(user)` — filtra por último modificador.
- `.recent_changes` — ordena por `updated_at DESC`.

### Callbacks

- `before_create :set_creator` — asigna `created_by_id` si está en blanco.
- `before_save :set_updater` — asigna `updated_by_id` en toda operación de escritura.

### Métodos de instancia

- `created_by_name` → nombre o email del creador, o `'Sistema'` si no hay usuario.
- `updated_by_name` → ídem para el modificador.
- `audit_trail` → `{ created_at, created_by, updated_at, updated_by }`.

## Modelos que lo incluyen

- `Vehicle`

## Archivos relacionados

- `app/models/concerns/auditable.rb`
