# Sistema de Usuarios para Clientes - Arquitectura de Microservicios

## Resumen

Se ha reestructurado completamente `client_contacts` a `client_users` para soportar:

- ✅ Autenticación JWT
- ✅ Seguridad robusta (bloqueo de cuentas, reset de contraseña)
- ✅ Trazabilidad completa (quién creó, desde qué app/API)
- ✅ Sistema de permisos granular
- ✅ Control de acceso por sucursales
- ✅ Preparado para microservicios

---

## Estructura de la Base de Datos

### Tabla: `client_users`

#### Campos de Identificación

- `id` - ID único
- `client_id` - Cliente al que pertenece
- `nombre` - Nombre completo
- `telefono` - Teléfono
- `correo` - Email (legacy)

#### Campos de Autenticación

- `email` - Email único (requerido)
- `username` - Nombre de usuario único
- `password_digest` - Contraseña encriptada (bcrypt)

#### Campos JWT

- `jti` - JWT ID único (para revocación de tokens)
- `refresh_token_digest` - Token de refresco encriptado
- `last_sign_in_at` - Última fecha de inicio de sesión
- `last_sign_in_ip` - IP del último inicio de sesión
- `sign_in_count` - Contador de inicios de sesión

#### Campos de Trazabilidad

- `created_by_app` - Nombre de la aplicación que creó el usuario
- `created_by_api_key_id` - ID del API key usado para crear
- `updated_by_app` - Aplicación que hizo la última actualización
- `updated_by_api_key_id` - API key de la última actualización

#### Campos de Roles y Permisos

- `role` - Rol del usuario: `user`, `admin`, `viewer`
- `permissions` - JSONB con permisos específicos

#### Campos de Seguridad

- `failed_attempts` - Intentos fallidos de login
- `locked_at` - Fecha de bloqueo de cuenta
- `unlock_token` - Token para desbloquear cuenta
- `reset_password_token` - Token para reset de contraseña
- `reset_password_sent_at` - Fecha de envío del token
- `email_confirmed_at` - Fecha de confirmación de email
- `confirmation_token` - Token de confirmación de email
- `confirmation_sent_at` - Fecha de envío de confirmación

#### Campos de Acceso a Sucursales

- `branch_office_ids` - Array de IDs de sucursales con acceso
- `all_branches_access` - Boolean para acceso a todas las sucursales

#### Campos de Estado

- `status` - Activo/Inactivo
- `created_at` - Fecha de creación
- `updated_at` - Fecha de actualización

---

## API Endpoints

### Autenticación (JWT)

#### POST `/api/v1/client_auth/login`

Iniciar sesión y obtener tokens JWT.

**Request:**

```json
{
  "email": "usuario@cliente.com",
  "password": "password123"
}
```

**Response:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "abc123...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "user": {
    "id": 1,
    "email": "usuario@cliente.com",
    "username": "usuario_cliente",
    "nombre": "Juan Pérez",
    "role": "user",
    "client_id": 5,
    "permissions": {},
    "branch_office_ids": [1, 2, 3],
    "all_branches_access": false
  }
}
```

#### POST `/api/v1/client_auth/refresh`

Refrescar access token usando refresh token.

**Request:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "abc123..."
}
```

#### DELETE `/api/v1/client_auth/logout`

Cerrar sesión y revocar tokens.

**Headers:**

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

#### GET `/api/v1/client_auth/me`

Obtener información del usuario actual.

**Headers:**

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

---

### Gestión de Usuarios

#### GET `/api/v1/client_users`

Listar usuarios de clientes.

**Query Params:**

- `client_id` - Filtrar por cliente
- `status` - Filtrar por status (true/false)
- `role` - Filtrar por rol (user/admin/viewer)
- `search` - Buscar por nombre, email o username

#### POST `/api/v1/client_users`

Crear nuevo usuario de cliente.

**Request:**

```json
{
  "client_user": {
    "client_id": 5,
    "nombre": "Juan Pérez",
    "email": "juan@cliente.com",
    "username": "juan_perez",
    "password": "SecurePass123!",
    "telefono": "1234567890",
    "role": "user",
    "branch_office_ids": [1, 2],
    "all_branches_access": false,
    "permissions": {
      "view_reports": true,
      "manage_bookings": true
    }
  }
}
```

**Headers (para trazabilidad):**

```
X-API-Key: your-api-key
X-App-Name: MiAplicacion
```

#### PUT `/api/v1/client_users/:id`

Actualizar usuario.

#### DELETE `/api/v1/client_users/:id`

Desactivar usuario (soft delete).

#### POST `/api/v1/client_users/:id/lock`

Bloquear cuenta de usuario.

#### POST `/api/v1/client_users/:id/unlock`

Desbloquear cuenta de usuario.

#### POST `/api/v1/client_users/:id/confirm_email`

Confirmar email de usuario.

**Request:**

```json
{
  "token": "confirmation-token-here"
}
```

#### POST `/api/v1/client_users/reset_password`

Solicitar reset de contraseña.

**Request:**

```json
{
  "email": "usuario@cliente.com"
}
```

#### POST `/api/v1/client_users/confirm_reset_password`

Confirmar reset de contraseña.

**Request:**

```json
{
  "token": "reset-token-here",
  "password": "NewSecurePass123!"
}
```

---

## Seguridad

### Bloqueo de Cuenta

- Después de 5 intentos fallidos, la cuenta se bloquea automáticamente
- Se genera un `unlock_token` para desbloquear
- Admin puede desbloquear manualmente

### Tokens JWT

- **Access Token**: Expira en 24 horas
- **Refresh Token**: Usado para obtener nuevo access token
- **JTI**: Permite revocar tokens individuales
- Tokens se invalidan al hacer logout

### Confirmación de Email

- Se genera `confirmation_token` al crear usuario
- Usuario debe confirmar email antes de poder iniciar sesión
- Token expira según configuración

### Reset de Contraseña

- Token válido por 2 horas
- Se invalida después de usar
- Resetea intentos fallidos y desbloquea cuenta

---

## Trazabilidad

### Creación de Usuarios

Cuando se crea un usuario vía API:

```ruby
created_by_app: "MiAplicacion"
created_by_api_key_id: 123
```

### Auditoría

Cada usuario tiene registro de:

- Cuándo fue creado y por quién/qué app
- Última actualización y por quién/qué app
- Historial de inicios de sesión (fecha, IP, contador)
- Intentos fallidos de login

---

## Sistema de Permisos

### Roles Predefinidos

- **user**: Usuario estándar
- **admin**: Administrador con todos los permisos
- **viewer**: Solo lectura

### Permisos Granulares (JSONB)

```json
{
  "view_reports": true,
  "manage_bookings": true,
  "view_invoices": false,
  "manage_users": false
}
```

### Verificación de Permisos

```ruby
user.has_permission?('view_reports') # => true
user.grant_permission('view_invoices')
user.revoke_permission('manage_bookings')
```

---

## Control de Acceso a Sucursales

### Acceso Específico

```ruby
user.branch_office_ids = [1, 2, 3]
user.has_branch_access?(1) # => true
user.has_branch_access?(4) # => false
```

### Acceso Total

```ruby
user.all_branches_access = true
user.has_branch_access?(999) # => true
```

---

## Integración con Microservicios

### Headers Requeridos

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
X-API-Key: your-api-key (opcional, para trazabilidad)
X-App-Name: NombreAplicacion (opcional, para trazabilidad)
```

### Payload del JWT

```json
{
  "user_id": 1,
  "client_id": 5,
  "email": "usuario@cliente.com",
  "role": "user",
  "jti": "unique-jwt-id",
  "exp": 1234567890
}
```

### Verificación en Microservicios

```ruby
# Decodificar y verificar token
decoded = JWT.decode(
  token,
  Rails.application.credentials.secret_key_base,
  true,
  { algorithm: 'HS256' }
).first

# Verificar que no esté revocado
user = ClientUser.find(decoded['user_id'])
if decoded['jti'] != user.jti
  # Token revocado
end
```

---

## Migración de Datos

La migración automáticamente:

1. Renombra `client_contacts` a `client_users`
2. Migra `correo` a `email`
3. Genera `username` basado en nombre + ID
4. Genera `jti` único para cada usuario
5. Mantiene compatibilidad con datos existentes

---

## Próximos Pasos

1. ✅ Ejecutar migración: `rails db:migrate`
2. ⏳ Implementar envío de emails (confirmación, reset)
3. ⏳ Crear frontend para gestión de usuarios
4. ⏳ Documentar API con Swagger/OpenAPI
5. ⏳ Implementar rate limiting
6. ⏳ Agregar 2FA (opcional)
7. ⏳ Implementar refresh token rotation

---

## Ejemplo de Uso Completo

### 1. Crear Usuario (desde otra app)

```bash
curl -X POST http://api.ttpn.com/api/v1/client_users \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -H "X-App-Name: BookingApp" \
  -d '{
    "client_user": {
      "client_id": 5,
      "nombre": "Juan Pérez",
      "email": "juan@cliente.com",
      "username": "juan_perez",
      "password": "SecurePass123!",
      "role": "user",
      "branch_office_ids": [1, 2]
    }
  }'
```

### 2. Usuario Confirma Email

```bash
curl -X POST http://api.ttpn.com/api/v1/client_users/1/confirm_email \
  -d '{"token": "confirmation-token"}'
```

### 3. Login

```bash
curl -X POST http://api.ttpn.com/api/v1/client_auth/login \
  -d '{"email": "juan@cliente.com", "password": "SecurePass123!"}'
```

### 4. Usar Access Token

```bash
curl -X GET http://api.ttpn.com/api/v1/client_auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```

### 5. Refrescar Token

```bash
curl -X POST http://api.ttpn.com/api/v1/client_auth/refresh \
  -d '{
    "access_token": "expired-token",
    "refresh_token": "refresh-token"
  }'
```

### 6. Logout

```bash
curl -X DELETE http://api.ttpn.com/api/v1/client_auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```
