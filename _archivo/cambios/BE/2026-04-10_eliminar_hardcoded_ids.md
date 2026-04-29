# Refactor: Eliminar IDs hardcodeados de roles y tipos de movimiento

**Fecha:** 2026-04-10  
**Branch:** `transform_to_api`  
**Commit:** `97e80ca`  
**Autor:** Antonio Castellanos

---

## Problema que se resolvió

Existían dos tipos de IDs hardcodeados en el código que hacían frágil el sistema:

1. **`role_id == 1`** disperso en 6 archivos — asumía que el rol con ID 1 siempre sería el admin, lo que rompería si la DB se recreaba en diferente orden.
2. **`EmployeeMovementType::ALTA = 1`, `::BAJA = 2`, etc.** — constantes enteras que asumían IDs específicos en la tabla, rompería si el seed insertaba en diferente orden.
3. **`employee_id: 63, vehicle_id: 39`** — IDs de registros de producción hardcodeados en lógica de negocio.

---

## Cambios realizados

### 1. `role_id == 1` → `sadmin?`

El campo `sadmin` (booleano en tabla `users`) es la verdad real de si un usuario es superadmin. El `role_id` es un detalle de implementación, no debe usarse como gate de acceso.

**Regla:** un usuario es superadmin si y solo si `sadmin: true`. El rol asignado no determina esto.

| Archivo | Cambio |
|---|---|
| `app/models/user.rb` | Eliminó `ROLE_ADMIN = 1`; `role_id == ROLE_ADMIN && sadmin` → `sadmin?` |
| `app/models/vehicle.rb` | `role_id == User::ROLE_ADMIN && Current.user&.sadmin` → `sadmin?` |
| `app/models/concessionaire.rb` | `role_id == 1` → `sadmin?` |
| `app/controllers/api/v1/base_controller.rb` | `current_user.sadmin && current_user.role_id == 1` → `current_user.sadmin?` |
| `app/controllers/users/sessions_controller.rb` | `resource.role_id == 1 && resource.sadmin` → `resource.sadmin?` |
| `config/routes.rb` | `u.role_id == 1` (guard Sidekiq) → `u.sadmin?` |

---

### 2. `EmployeeMovementType` — de constantes enteras a métodos por nombre

**Antes:**
```ruby
class EmployeeMovementType < ApplicationRecord
  ALTA               = 1
  BAJA               = 2
  REINGRESO          = 3
  BAJA_LISTA_NEGRA   = 6
  ALTAS_Y_REINGRESOS = [ALTA, REINGRESO].freeze
end
```

**Después:**
```ruby
class EmployeeMovementType < ApplicationRecord
  NOMBRE_ALTA             = 'Alta'
  NOMBRE_BAJA             = 'Baja'
  NOMBRE_REINGRESO        = 'Reingreso'
  NOMBRE_BAJA_LISTA_NEGRA = 'Baja Lista Negra'

  def self.alta_id             = @alta_id             ||= find_by!(nombre: NOMBRE_ALTA).id
  def self.baja_id             = @baja_id             ||= find_by!(nombre: NOMBRE_BAJA).id
  def self.reingreso_id        = @reingreso_id        ||= find_by!(nombre: NOMBRE_REINGRESO).id
  def self.baja_lista_negra_id = @baja_lista_negra_id ||= find_by!(nombre: NOMBRE_BAJA_LISTA_NEGRA).id
  def self.altas_y_reingresos_ids = [alta_id, reingreso_id]
  def self.reset_id_cache!    = @alta_id = @baja_id = @reingreso_id = @baja_lista_negra_id = nil
end
```

Los IDs se resuelven en runtime buscando por nombre y se cachean por proceso (memoización con `@var ||=`).

**Usages actualizados:**

| Archivo | Antes | Después |
|---|---|---|
| `app/models/employee.rb` | `EmployeeMovementType::ALTAS_Y_REINGRESOS` | `EmployeeMovementType.altas_y_reingresos_ids` |
| `app/models/employee_movement.rb` | `EmployeeMovementType::BAJA` | `EmployeeMovementType.baja_id` |
| `app/models/employee.rb` | `MOV_ALTA/BAJA/REINGRESO/BAJA_LISTA_NEGRA` aliases | Eliminados (no se usaban en ningún lado) |

---

### 3. IDs de producción hardcodeados en lógica de negocio

**Archivo:** `app/models/employee_movement.rb`, método `desasignar_vehiculo`

**Antes:**
```ruby
TtpnBooking.where(employee_id: emp)
           .where('fecha + hora >= ?', fecha)
           .update(employee_id: 63, vehicle_id: 39)
```

**Después:**
```ruby
# Al desasignar, los bookings futuros quedan sin chofer/vehículo para reasignación manual
TtpnBooking.where(employee_id: emp)
           .where('fecha + hora >= ?', fecha)
           .update(employee_id: nil, vehicle_id: nil)
```

Los IDs `63` y `39` eran registros específicos de la base de producción. En cualquier otro ambiente (dev, staging, nueva instalación) esos IDs no existen o apuntan a registros incorrectos.

---

### 4. `db/seeds/role_privileges_sistemas.rb`

**Antes:**
```ruby
sistemas_role = Role.find_by(id: 1)
sistemas_role = Role.create!(id: 1, nombre: 'Sistemas')
```

**Después:**
```ruby
sistemas_role = Role.find_by(nombre: 'Sistemas')
# Si no existe, aborta con mensaje claro en lugar de crearlo forzando ID
```

---

## Impacto en el Frontend

**Ninguno.** El FE:
- Usa `sadmin` como campo booleano del usuario (no cambió la forma del dato)
- Obtiene `role_id` de dropdowns de la API (no asume valores)
- Usa `employee_movement_type_id` como ID numérico de la API (no hardcodeado)
- `useBusinessUnitContext.js` ya chequeaba `user.sadmin === true` (compatible)

---

## Cómo revertir (rollback)

```bash
cd ttpngas
git revert 97e80ca --no-commit
git commit -m "revert: restaurar hardcoded IDs (rollback 97e80ca)"
git push github transform_to_api
```

O para revertir solo un archivo específico:
```bash
git checkout 97e80ca~1 -- app/models/employee_movement_type.rb
```

---

## Requisito del seed después de este cambio

Los registros de `employee_movement_types` **deben existir con estos nombres exactos** antes de que cualquier código que use `.baja_id`, `.alta_id`, etc. se ejecute:

| Nombre en DB | Método que lo resuelve |
|---|---|
| `'Alta'` | `EmployeeMovementType.alta_id` |
| `'Baja'` | `EmployeeMovementType.baja_id` |
| `'Reingreso'` | `EmployeeMovementType.reingreso_id` |
| `'Baja Lista Negra'` | `EmployeeMovementType.baja_lista_negra_id` |

Si los nombres no coinciden exactamente, `find_by!` lanza `ActiveRecord::RecordNotFound` con un error claro en lugar de fallar silenciosamente.

En tests, llamar `EmployeeMovementType.reset_id_cache!` en `before(:each)` para evitar IDs cacheados entre pruebas.
