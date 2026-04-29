# EmployeeMovementType

## Propósito

Catálogo de los tipos de movimiento laboral. Sus registros viven en la base de datos; los nombres canónicos están fijados como constantes en el modelo para evitar strings mágicos en el código.

---

## Campos principales

| Campo    | Tipo   | Descripción                        |
|----------|--------|------------------------------------|
| `nombre` | string | Nombre canónico del tipo. Único.   |

---

## Asociaciones

| Asociación           | Tipo       | Notas |
|----------------------|------------|-------|
| `employee_movements` | `has_many` |       |

---

## Constantes de nombres

```ruby
NOMBRE_ALTA             = 'Alta'
NOMBRE_BAJA             = 'Baja'
NOMBRE_REINGRESO        = 'Reingreso'
NOMBRE_BAJA_LISTA_NEGRA = 'Baja - Lista Negra'
```

Usar **siempre estas constantes** para comparar nombres. Nunca strings literales en controllers o concerns.

---

## IDs memoizados (class methods)

| Método                    | Descripción                                     |
|---------------------------|-------------------------------------------------|
| `alta_id`                 | ID del tipo "Alta". Memoizado por proceso.      |
| `baja_id`                 | ID del tipo "Baja".                             |
| `reingreso_id`            | ID del tipo "Reingreso".                        |
| `baja_lista_negra_id`     | ID del tipo "Baja - Lista Negra".               |
| `altas_y_reingresos_ids`  | `[alta_id, reingreso_id]` — estados activos.    |
| `reset_id_cache!`         | Limpia memoización. Útil en tests y seeds.      |

Los IDs están memoizados con `@var ||= find_by!(nombre: ...).id`. Se resuelven una vez por proceso de Rails/Sidekiq. En tests, llamar `reset_id_cache!` entre ejemplos si se recrea el catálogo.

---

## Reglas de negocio

- Los 4 tipos canónicos deben existir en la BD antes de registrar cualquier `EmployeeMovement`.
- Si un tipo no existe, `find_by!` lanzará `ActiveRecord::RecordNotFound` y el proceso fallará.
- **No renombrar ni eliminar** estos registros en producción sin actualizar las constantes y todos los lugares que los usan.

---

## Archivos relacionados

- `app/models/employee_movement_type.rb`
- `app/models/employee_movement.rb`
- `app/controllers/concerns/employee_stats_calculable.rb`
- `db/seeds.rb` (debe crear los 4 tipos)
