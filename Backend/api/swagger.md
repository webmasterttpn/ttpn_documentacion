# 📚 Guía de Documentación API con Swagger

## 📋 Tabla de Contenidos

1. [Acceso a Swagger UI](#acceso-a-swagger-ui)
2. [Autenticación en Swagger](#autenticación-en-swagger)
3. [Probar Endpoints](#probar-endpoints)
4. [Generar Documentación](#generar-documentación)
5. [Agregar Nuevos Endpoints](#agregar-nuevos-endpoints)
6. [Ejemplos de Uso](#ejemplos-de-uso)
7. [Troubleshooting](#troubleshooting)

---

## 🌐 Acceso a Swagger UI

### Desarrollo Local

**URL:** http://localhost:3000/api-docs

1. **Levantar el servidor:**

   ```bash
   cd ttpngas
   docker-compose up -d
   ```

2. **Abrir Swagger UI en el navegador:**

   ```
   http://localhost:3000/api-docs
   ```

3. **Verás la interfaz de Swagger con:**
   - Lista de todos los endpoints disponibles
   - Documentación de cada endpoint
   - Posibilidad de probar cada endpoint directamente

### Producción

**URL:** https://api.ttpn.com/api-docs

---

## 🔐 Autenticación en Swagger

Swagger está configurado para usar **JWT Bearer Authentication**.

### Paso 1: Obtener un Token

#### Opción A: Desde Swagger UI

1. Ve a la sección **Autenticación** en Swagger
2. Busca el endpoint `POST /api/v1/auth/login`
3. Haz clic en **"Try it out"**
4. Ingresa las credenciales:
   ```json
   {
     "email": "tu-email@example.com",
     "password": "tu-password"
   }
   ```
5. Haz clic en **"Execute"**
6. Copia el `token` de la respuesta

#### Opción B: Desde curl

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@ttpn.com",
    "password": "password123"
  }'
```

**Respuesta:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "admin@ttpn.com",
    "nombre": "Admin User"
  }
}
```

### Paso 2: Configurar el Token en Swagger

1. En la parte superior derecha de Swagger UI, haz clic en el botón **"Authorize" 🔓**
2. En el modal que aparece, ingresa:

   ```
   Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   ⚠️ **Importante:** Incluye la palabra `Bearer` seguida de un espacio y luego el token

3. Haz clic en **"Authorize"**
4. Cierra el modal
5. Ahora todos los endpoints usarán automáticamente este token

---

## 🧪 Probar Endpoints

### Ejemplo: Listar Vehículos

1. **Encuentra el endpoint:**

   - Sección: **Vehículos**
   - Endpoint: `GET /api/v1/vehicles`

2. **Haz clic en el endpoint** para expandirlo

3. **Haz clic en "Try it out"**

4. **(Opcional) Configura parámetros:**

   - `page`: 1
   - `per_page`: 10

5. **Haz clic en "Execute"**

6. **Revisa la respuesta:**
   - **Código de respuesta:** 200 OK
   - **Body:** JSON con la lista de vehículos
   - **Headers:** Información adicional

### Ejemplo: Crear un Vehículo

1. **Encuentra el endpoint:**

   - Sección: **Vehículos**
   - Endpoint: `POST /api/v1/vehicles`

2. **Haz clic en "Try it out"**

3. **Edita el JSON del request body:**

   ```json
   {
     "vehicle": {
       "clv": "VEH-999",
       "marca": "Toyota",
       "modelo": "Corolla",
       "annio": 2024,
       "serie": "ABC123456",
       "placa": "XYZ-789",
       "vehicle_type_id": 1,
       "password": "password123",
       "status": true,
       "concessionaire_ids": [1, 2]
     }
   }
   ```

4. **Haz clic en "Execute"**

5. **Revisa la respuesta:**
   - **Código 201:** Vehículo creado exitosamente
   - **Código 422:** Error de validación (revisa el campo `errors`)

---

## 📝 Generar Documentación

### Regenerar Swagger después de cambios

Cada vez que agregues o modifiques un spec, debes regenerar la documentación:

```bash
# Desde la raíz del proyecto
docker-compose exec app rails rswag:specs:swaggerize
```

Esto:

1. Ejecuta todos los specs de Swagger
2. Genera el archivo `swagger/v1/swagger.yaml`
3. Actualiza la documentación en Swagger UI

### Ver la documentación generada

```bash
# Ver el archivo YAML generado
cat swagger/v1/swagger.yaml
```

---

## ➕ Agregar Nuevos Endpoints

### Paso 1: Crear el Spec

Crea un archivo en `spec/requests/api/v1/`:

```ruby
# spec/requests/api/v1/clients_spec.rb
require 'swagger_helper'

RSpec.describe 'API V1 Clients', type: :request do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_token(user)}" }

  path '/api/v1/clients' do
    get 'Lista todos los clientes' do
      tags 'Clientes'
      description 'Obtiene la lista de todos los clientes'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      response '200', 'clientes encontrados' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   clv: { type: :string },
                   razon_social: { type: :string },
                   rfc: { type: :string },
                   status: { type: :boolean },
                   audit: { '$ref' => '#/components/schemas/AuditInfo' }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
        end
      end
    end

    post 'Crear un nuevo cliente' do
      tags 'Clientes'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      parameter name: :client, in: :body, schema: {
        type: :object,
        properties: {
          client: {
            type: :object,
            properties: {
              clv: { type: :string, example: 'CLI-001' },
              razon_social: { type: :string, example: 'Cliente SA de CV' },
              rfc: { type: :string, example: 'CLI123456789' },
              telefono: { type: :string, example: '6141234567' },
              status: { type: :boolean, example: true }
            },
            required: %w[clv razon_social rfc]
          }
        }
      }

      response '201', 'cliente creado' do
        let(:client) do
          {
            client: {
              clv: 'CLI-TEST-001',
              razon_social: 'Test SA',
              rfc: 'TEST123456789'
            }
          }
        end

        run_test!
      end
    end
  end
end
```

### Paso 2: Regenerar Swagger

```bash
docker-compose exec app rails rswag:specs:swaggerize
```

### Paso 3: Verificar en Swagger UI

Recarga http://localhost:3000/api-docs y verás el nuevo endpoint.

---

## 💡 Ejemplos de Uso

### Ejemplo 1: Buscar Vehículos con Filtros

**Request:**

```bash
curl -X GET "http://localhost:3000/api/v1/vehicles?page=1&per_page=10" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**

```json
[
  {
    "id": 1,
    "clv": "VEH-001",
    "marca": "Toyota",
    "modelo": "Corolla",
    "annio": 2023,
    "audit": {
      "created_at": "2025-01-15T10:30:00Z",
      "created_by": "Juan Pérez",
      "updated_at": "2025-01-18T14:20:00Z",
      "updated_by": "María García"
    }
  }
]
```

### Ejemplo 2: Actualizar un Vehículo

**Request:**

```bash
curl -X PATCH "http://localhost:3000/api/v1/vehicles/veh-001" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicle": {
      "marca": "Honda",
      "modelo": "Civic"
    }
  }'
```

**Response:**

```json
{
  "id": 1,
  "clv": "VEH-001",
  "marca": "Honda",
  "modelo": "Civic",
  "audit": {
    "updated_at": "2025-01-20T09:15:00Z",
    "updated_by": "Admin User"
  }
}
```

### Ejemplo 3: Eliminar un Vehículo

**Request:**

```bash
curl -X DELETE "http://localhost:3000/api/v1/vehicles/veh-001" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**

```
204 No Content
```

---

## 🔍 Estructura de la Documentación

### Archivos Importantes

```
ttpngas/
├── spec/
│   ├── swagger_helper.rb           # Configuración global de Swagger
│   ├── requests/
│   │   └── api/
│   │       └── v1/
│   │           ├── vehicles_spec.rb    # Spec de vehículos
│   │           ├── clients_spec.rb     # Spec de clientes
│   │           └── employees_spec.rb   # Spec de empleados
│   └── support/
│       └── auth_helper.rb          # Helper para autenticación
├── swagger/
│   └── v1/
│       └── swagger.yaml            # Documentación generada
└── config/
    └── initializers/
        ├── rswag_api.rb            # Configuración de Rswag API
        └── rswag_ui.rb             # Configuración de Rswag UI
```

### Configuración de Rutas

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Swagger UI
  mount Rswag::Ui::Engine => '/api-docs'

  # Swagger JSON/YAML
  mount Rswag::Api::Engine => '/api-docs'

  # Tu API
  namespace :api do
    namespace :v1 do
      resources :vehicles
      # ...
    end
  end
end
```

---

## 🐛 Troubleshooting

### Problema: Swagger UI no carga

**Solución:**

```bash
# Verificar que el servidor esté corriendo
docker-compose ps

# Reiniciar el servidor
docker-compose restart app

# Verificar logs
docker-compose logs -f app
```

### Problema: Token no funciona (401 Unauthorized)

**Causas comunes:**

1. Token expirado (genera uno nuevo)
2. No incluiste "Bearer " antes del token
3. Token mal copiado (verifica espacios extra)

**Solución:**

```bash
# Generar nuevo token
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@ttpn.com","password":"password123"}'

# Copiar el token completo y usar:
# Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Problema: Cambios no se reflejan en Swagger

**Solución:**

```bash
# Regenerar documentación
docker-compose exec app rails rswag:specs:swaggerize

# Limpiar cache del navegador
# Ctrl+Shift+R (Windows/Linux) o Cmd+Shift+R (Mac)
```

### Problema: Error al generar Swagger

**Solución:**

```bash
# Verificar que los specs sean válidos
docker-compose exec app bundle exec rspec spec/requests/api/v1/vehicles_spec.rb

# Ver errores detallados
docker-compose exec app rails rswag:specs:swaggerize --trace
```

---

## 📊 Mejores Prácticas

### 1. Documentar Todos los Endpoints

✅ **Bueno:**

```ruby
response '200', 'vehículos encontrados' do
  schema type: :array, items: { ... }
  run_test!
end

response '401', 'no autorizado' do
  schema type: :object, properties: { error: { type: :string } }
  run_test!
end

response '422', 'parámetros inválidos' do
  schema type: :object, properties: { errors: { type: :array } }
  run_test!
end
```

❌ **Malo:**

```ruby
response '200', 'ok' do
  run_test!
end
```

### 2. Usar Schemas Reutilizables

```ruby
# En swagger_helper.rb
components: {
  schemas: {
    AuditInfo: {
      type: :object,
      properties: {
        created_at: { type: :string, format: 'date-time' },
        created_by: { type: :string },
        updated_at: { type: :string, format: 'date-time' },
        updated_by: { type: :string }
      }
    }
  }
}

# En el spec
audit: { '$ref' => '#/components/schemas/AuditInfo' }
```

### 3. Agregar Ejemplos

```ruby
parameter name: :page,
          in: :query,
          type: :integer,
          required: false,
          description: 'Número de página',
          example: 1

properties: {
  clv: { type: :string, example: 'VEH-001' },
  marca: { type: :string, example: 'Toyota' }
}
```

### 4. Agrupar por Tags

```ruby
tags 'Vehículos'  # Todos los endpoints de vehículos juntos
tags 'Clientes'   # Todos los endpoints de clientes juntos
```

---

## 🚀 Comandos Rápidos

```bash
# Generar documentación
docker-compose exec app rails rswag:specs:swaggerize

# Ejecutar solo specs de Swagger
docker-compose exec app bundle exec rspec spec/requests

# Ver Swagger UI
open http://localhost:3000/api-docs

# Ver archivo YAML generado
cat swagger/v1/swagger.yaml

# Validar specs
docker-compose exec app bundle exec rspec spec/requests/api/v1/vehicles_spec.rb
```

---

## 📖 Recursos Adicionales

### Documentación Oficial

- **Rswag:** https://github.com/rswag/rswag
- **OpenAPI 3.0:** https://swagger.io/specification/
- **Swagger UI:** https://swagger.io/tools/swagger-ui/

### Ejemplos en el Proyecto

- `spec/requests/api/v1/vehicles_spec.rb` - Ejemplo completo de CRUD
- `spec/swagger_helper.rb` - Configuración global
- `spec/support/auth_helper.rb` - Helper de autenticación

---

## ✅ Checklist para Nuevos Endpoints

- [ ] Crear spec en `spec/requests/api/v1/`
- [ ] Documentar todos los códigos de respuesta (200, 401, 422, etc.)
- [ ] Agregar ejemplos de request/response
- [ ] Usar schemas reutilizables cuando sea posible
- [ ] Asignar tag apropiado
- [ ] Ejecutar `rails rswag:specs:swaggerize`
- [ ] Verificar en Swagger UI
- [ ] Probar endpoint desde Swagger UI

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0  
**Mantenido por:** TTPN Admin Team
