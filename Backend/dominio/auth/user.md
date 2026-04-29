# User

## Propósito

Usuario del sistema Kumi Admin. Gestiona autenticación (Devise + JWT), rol primario y roles secundarios, permisos efectivos (Pundit/`build_privileges`) y avatar en S3.

---

## Campos principales

| Campo              | Tipo    | Descripción                                                         |
|--------------------|---------|---------------------------------------------------------------------|
| `email`            | string  | Email de autenticación (Devise).                                    |
| `encrypted_password`| string | Contraseña cifrada (Devise).                                       |
| `jti`              | string  | JWT ID. Identificador de token para revocación. Único. Se rota con `revoke_jwt!`. |
| `role_id`          | integer | FK al rol **primario**. Aparece en el JWT. No usar para permisos — usar `build_privileges`. |
| `business_unit_id` | integer | FK a `BusinessUnit`. El `BaseController` lo usa para poblar `Current.business_unit`. |
| `nombre`           | string  | Nombre del usuario (mostrado en UI).                                |

---

## Asociaciones

| Asociación         | Tipo                      | Notas                                                   |
|--------------------|---------------------------|---------------------------------------------------------|
| `role`             | `belongs_to`              | Rol primario. Obligatorio.                              |
| `business_unit`    | `belongs_to`              | BU del usuario.                                         |
| `user_roles`       | `has_many`                | Tabla join `roles_users` → roles secundarios.           |
| `secondary_roles`  | `has_many` (through)      | Roles adicionales vía `RolesUser`.                      |
| `alert_reads`      | `has_many`                | Registro de alertas leídas. `dependent: :destroy`.      |
| `read_alerts`      | `has_many` (through)      | Alertas ya leídas.                                      |
| `user_avatar`      | Active Storage            | Avatar del usuario. URL via `avatar_url` (S3 presignado).|

---

## Validaciones

- `jti`: presencia y unicidad. Se genera automáticamente en `before_validation` `:create`.

---

## JWT

### `generate_jwt(exp = 24.hours.from_now)`

Genera el token con payload `{ user_id, role (nombre del rol primario), jti, exp }`.

### `revoke_jwt!`

Rota el `jti` → invalida todos los tokens emitidos anteriormente para este usuario.

---

## Permisos

### `all_roles`

Une rol primario + roles secundarios, sin duplicados.

### `role?(type)`

Verifica si alguno de los roles del usuario tiene `nombre == type.to_s`.

### `build_privileges`

Construye el hash de permisos efectivos. Si es `sadmin?`, retorna acceso total a todos los `Privilege.active`. Si no, une los permisos de todos sus roles con OR por módulo.

```ruby
{ 'employees' => { can_access: true, can_create: true, can_edit: false, can_delete: false }, ... }
```

---

## Métodos de utilidad

### `avatar_url`

```ruby
def avatar_url
  return nil unless user_avatar.attached?
  user_avatar.url
end
```

Retorna URL presignada de S3. Usar siempre este método, nunca `rails_blob_url`.

---

## Archivos relacionados

- `app/models/user.rb`
- `app/models/role.rb`
- `app/models/privilege.rb`
- `app/controllers/api/v1/base_controller.rb` (pobla `Current.user` y `Current.business_unit`)
- `app/controllers/api/v1/auth/sessions_controller.rb` (emite y revoca JWT)
