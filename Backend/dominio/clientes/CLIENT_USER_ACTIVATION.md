# Sistema de Activación por Email - Usuarios de Clientes

## Flujo de Activación

### 1. Creación de Usuario (Backend)

```ruby
# POST /api/v1/client_users
{
  "client_user": {
    "client_id": 5,
    "nombre": "Juan Pérez",
    "email": "juan@cliente.com",
    "username": "juan_perez",
    "telefono": "1234567890"
    # password es opcional, se genera automáticamente si no se proporciona
  }
}
```

**Proceso Automático:**

1. ✅ Usuario se crea con `status: false` (inactivo)
2. ✅ Se genera `confirmation_token` único
3. ✅ Se genera contraseña temporal (si no se proporciona)
4. ✅ Se envía email de activación automáticamente

### 2. Email de Activación

El usuario recibe un email con:

- ✉️ Asunto: "Activa tu cuenta de TTPN"
- 🔗 Link de activación: `http://frontend/client-auth/activate?token=XXXXX`
- ℹ️ Información de la cuenta (email, username, cliente)
- ⏰ Válido por 48 horas

### 3. Activación (Frontend - Pendiente)

**URL:** `/client-auth/activate?token=XXXXX`

**Request al Backend:**

```javascript
POST /api/v1/client_users/:id/confirm_email
{
  "token": "confirmation-token-here"
}
```

**Proceso:**

1. ✅ Valida el token
2. ✅ Marca `email_confirmed_at` con timestamp
3. ✅ Cambia `status` a `true` (activa usuario)
4. ✅ Elimina `confirmation_token`
5. ✅ Envía email de confirmación
6. ✅ Redirige a login

### 4. Email de Confirmación

El usuario recibe un segundo email:

- ✉️ Asunto: "Tu cuenta de TTPN ha sido activada"
- 🔗 Link al login: `http://frontend/client-auth/login`
- ✅ Confirmación de activación exitosa

### 5. Login (Frontend - Pendiente)

**URL:** `/client-auth/login`

El usuario puede iniciar sesión con:

- Email o Username
- Contraseña (la que se le proporcionó o la que estableció)

---

## Configuración de Emails

### Desarrollo (Letter Opener)

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

**Funcionamiento:**

- Los emails NO se envían realmente
- Se abren en el navegador automáticamente
- Se guardan en `tmp/letter_opener/`
- Perfecto para testing

### Producción (SMTP)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'ttpn.com.mx',
  user_name: 'info@ttpn.com.mx',
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

**Email Corporativo:**

- 📧 Remitente: `info@ttpn.com.mx`
- 🔐 Credenciales en variables de entorno

---

## Seguridad

### Usuarios Inactivos

- ❌ No pueden iniciar sesión
- ❌ No aparecen en listados activos
- ✅ Deben activar cuenta primero

### Tokens de Confirmación

- 🔒 Generados con `SecureRandom.urlsafe_base64`
- 🔑 Únicos por usuario
- ⏰ Expiran en 48 horas (configurable)
- 🗑️ Se eliminan después de usar

### Validaciones

```ruby
# En el login
if !user.confirmed?
  return { error: 'Email no confirmado' }
end

if !user.status?
  return { error: 'Cuenta inactiva' }
end
```

---

## Tareas Pendientes (Frontend)

### 1. Página de Activación

**Ruta:** `/client-auth/activate`

**Componente:** `ClientActivationPage.vue`

**Funcionalidad:**

```vue
<template>
  <q-page class="flex flex-center">
    <q-card>
      <q-card-section>
        <h5>Activando tu cuenta...</h5>
        <q-spinner v-if="loading" />
        <div v-if="success">
          ✅ Cuenta activada exitosamente
          <q-btn to="/client-auth/login">Ir al Login</q-btn>
        </div>
        <div v-if="error">❌ {{ errorMessage }}</div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { api } from "boot/axios";

const route = useRoute();
const router = useRouter();

onMounted(async () => {
  const token = route.query.token;
  const userId = route.query.user_id; // Opcional

  try {
    await api.post(`/api/v1/client_users/${userId}/confirm_email`, {
      token: token,
    });
    success.value = true;
    // Redirigir al login después de 3 segundos
    setTimeout(() => {
      router.push("/client-auth/login");
    }, 3000);
  } catch (error) {
    error.value = true;
    errorMessage.value =
      error.response?.data?.error || "Error al activar cuenta";
  }
});
</script>
```

### 2. Página de Login

**Ruta:** `/client-auth/login`

**Componente:** `ClientLoginPage.vue`

**Funcionalidad:**

- Login con email o username
- Validación de cuenta activa
- Validación de email confirmado
- Manejo de errores específicos
- Redirección después de login exitoso

### 3. Actualizar Rutas

```javascript
// router/routes.js
{
  path: '/client-auth',
  component: () => import('layouts/ClientAuthLayout.vue'),
  children: [
    { path: 'activate', component: () => import('pages/ClientAuth/ActivationPage.vue') },
    { path: 'login', component: () => import('pages/ClientAuth/LoginPage.vue') },
    { path: 'reset-password', component: () => import('pages/ClientAuth/ResetPasswordPage.vue') }
  ]
}
```

---

## Testing

### Crear Usuario de Prueba

```bash
curl -X POST http://localhost:3000/api/v1/client_users \
  -H "Content-Type: application/json" \
  -d '{
    "client_user": {
      "client_id": 1,
      "nombre": "Test User",
      "email": "test@example.com",
      "username": "testuser"
    }
  }'
```

### Ver Email en Desarrollo

1. Usuario se crea
2. Email se abre automáticamente en navegador
3. Click en link de activación
4. Usuario queda activo

### Verificar Activación

```bash
curl http://localhost:3000/api/v1/client_users/1
```

Debe mostrar:

```json
{
  "status": true,
  "confirmed": true,
  "email_confirmed_at": "2026-01-09T15:45:00Z"
}
```

---

## Mejoras Futuras

1. ⏳ **Reenvío de Email de Activación**

   - Endpoint para reenviar email si expiró
   - Generar nuevo token

2. ⏳ **Notificaciones al Admin**

   - Email al admin cuando se crea usuario
   - Email al admin cuando usuario se activa

3. ⏳ **Dashboard de Usuarios Pendientes**

   - Ver usuarios sin activar
   - Reenviar emails masivamente
   - Eliminar usuarios no activados después de X días

4. ⏳ **Personalización de Emails**
   - Templates por cliente
   - Branding personalizado
   - Idiomas múltiples

---

## Variables de Entorno

```bash
# .env
FRONTEND_URL=http://localhost:9000
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=ttpn.com.mx
SMTP_USER_NAME=info@ttpn.com.mx
SMTP_PASSWORD=your-password-here
```

---

## Resumen

✅ **Implementado:**

- Sistema de activación por email
- Emails automáticos al crear usuario
- Letter Opener para desarrollo
- Usuarios inactivos por defecto
- Activación cambia status a activo
- Email de confirmación después de activar

⏳ **Pendiente (Frontend):**

- Página de activación
- Página de login
- Manejo de errores
- Redirecciones

🔐 **Seguridad:**

- Tokens únicos y seguros
- Usuarios inactivos no pueden login
- Email debe estar confirmado
- Tokens expiran en 48 horas
