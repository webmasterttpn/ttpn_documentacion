# BusinessUnit

## Propósito

Unidad de negocio (empresa / división) de TTPN. Es el eje del multi-tenancy: cada empleado, vehículo y usuario pertenece a una BU, y todos los filtros de datos operativos se aplican sobre este campo.

---

## Campos principales

| Campo | Tipo   | Descripción             |
|-------|--------|-------------------------|
| `clv` | string | Clave identificadora.   |

---

## Asociaciones

| Asociación       | Tipo                      | Notas                                    |
|------------------|---------------------------|------------------------------------------|
| `concessionaires`| `has_and_belongs_to_many` | BU ↔ Concesionarias que la operan.       |
| `kumi_settings`  | `has_many`                | Configuración específica por BU (vacaciones, parámetros, etc.). `dependent: :destroy`. |

---

## Multi-tenancy — cómo funciona

`Current.business_unit` se puebla en `BaseController` a partir del JWT del usuario autenticado. Cada modelo con datos operativos expone un scope `business_unit_filter` que filtra por ese valor.

| Modelo   | Cómo filtra                                      |
|----------|--------------------------------------------------|
| `Employee` | `WHERE business_unit_id = ?`                   |
| `Vehicle`  | Via join `concessionaires → business_units`    |
| `User`     | `WHERE business_unit_id = ?`                   |

El sadmin (`role.nombre == 'sadmin'` o `user.role_id == User::ROLE_ADMIN`) puede ver todos los datos. Cada scope maneja ese bypass de forma diferente — revisar el scope del modelo específico.

---

## Archivos relacionados

- `app/models/business_unit.rb`
- `app/models/current.rb` (thread-local `Current.business_unit`)
- `app/controllers/api/v1/base_controller.rb`
- `app/models/concerns/business_unit_assignable.rb`
