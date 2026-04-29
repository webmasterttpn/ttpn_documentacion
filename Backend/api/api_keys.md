# 🔑 Sistema de API Keys - Guía Completa

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Crear API Keys](#crear-api-keys)
3. [Usar API Keys](#usar-api-keys)
4. [Permisos Granulares](#permisos-granulares)
5. [Gestión en el Frontend](#gestión-en-el-frontend)
6. [Seguridad](#seguridad)
7. [Ejemplos de Uso](#ejemplos-de-uso)

---

## 🎯 Visión General

El sistema de API Keys permite crear **tokens de acceso programático** para integraciones externas, con control granular de permisos por recurso y acción.

### Características

- ✅ **Permisos Granulares:** Control por recurso (vehicles, clients, etc.) y acción (read, create, update, delete)
- ✅ **Expiración Configurable:** Keys con fecha de expiración opcional
- ✅ **Auditoría Completa:** Tracking de quién creó, cuándo y cuántas veces se usó
- ✅ **Revocación Instantánea:** Desactivar keys comprometidas
- ✅ **Regeneración:** Crear nueva key manteniendo permisos
- ✅ **Rate Limiting:** Contador de requests por key

---

## 🔧 Crear API Keys

### Desde el Backend (Rails Console)

```ruby
# Crear una API key con permisos específicos
user = User.find_by(email: 'admin@ttpn.com')

api_key = ApiKey.generate_for_user(
  user,
  'Integración ERP',
  {
    'vehicles' => {
      'read' => true,
      'create' => false,
      'update' => false,
      'delete' => false
    },
    'clients' => {
      'read' => true,
      'create' => true,
      'update' => true,
      'delete' => false
    }
  }
)

puts "API Key creada: #{api_key.key}"
```

### Desde la API

**Endpoint:** `POST /api/v1/api_keys`

**Headers:**

```
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json
```

**Body:**

```json
{
  "api_key": {
    "name": "Integración ERP",
    "user_id": 1,
    "expires_at": "2026-12-31T23:59:59Z",
    "permissions": {
      "vehicles": {
        "read": true,
        "create": false,
        "update": false,
        "delete": false
      },
      "clients": {
        "read": true,
        "create": true,
        "update": true,
        "delete": false
      }
    }
  }
}
```

**Response:**

```json
{
  "id": 1,
  "name": "Integración ERP",
  "key": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "permissions": {
    "vehicles": {
      "read": true
    },
    "clients": {
      "read": true,
      "create": true,
      "update": true
    }
  },
  "active": true,
  "expired": false,
  "expires_at": "2026-12-31T23:59:59Z",
  "last_used_at": null,
  "requests_count": 0,
  "created_at": "2025-12-18T20:00:00Z"
}
```

⚠️ **Importante:** La key completa solo se muestra al crear. Guárdala en un lugar seguro.

---

## 🔐 Usar API Keys

### Opción 1: Header (Recomendado)

```bash
curl -X GET "http://localhost:3000/api/v1/vehicles" \
  -H "X-API-Key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2"
```

### Opción 2: Query Parameter (Solo para testing)

```bash
curl -X GET "http://localhost:3000/api/v1/vehicles?api_key=a1b2c3d4e5f6..."
```

⚠️ **No usar en producción:** Los query params quedan en logs.

### Desde JavaScript

```javascript
// Usando fetch
const apiKey =
  "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2";

fetch("http://localhost:3000/api/v1/vehicles", {
  headers: {
    "X-API-Key": apiKey,
    "Content-Type": "application/json",
  },
})
  .then((response) => response.json())
  .then((data) => console.log(data));

// Usando axios
import axios from "axios";

const api = axios.create({
  baseURL: "http://localhost:3000",
  headers: {
    "X-API-Key": apiKey,
  },
});

const vehicles = await api.get("/api/v1/vehicles");
```

---

## 🎛️ Permisos Granulares

### Recursos Disponibles

```ruby
{
  'vehicles' => {
    'read' => 'Ver vehículos',
    'create' => 'Crear vehículos',
    'update' => 'Actualizar vehículos',
    'delete' => 'Eliminar vehículos'
  },
  'clients' => {
    'read' => 'Ver clientes',
    'create' => 'Crear clientes',
    'update' => 'Actualizar clientes',
    'delete' => 'Eliminar clientes'
  },
  'employees' => {
    'read' => 'Ver empleados',
    'create' => 'Crear empleados',
    'update' => 'Actualizar empleados',
    'delete' => 'Eliminar empleados'
  },
  'bookings' => {
    'read' => 'Ver reservas',
    'create' => 'Crear reservas',
    'update' => 'Actualizar reservas',
    'delete' => 'Eliminar reservas'
  }
}
```

### Mapeo de Acciones

| Endpoint HTTP                 | Permiso Requerido |
| ----------------------------- | ----------------- |
| `GET /api/v1/vehicles`        | `vehicles.read`   |
| `GET /api/v1/vehicles/:id`    | `vehicles.read`   |
| `POST /api/v1/vehicles`       | `vehicles.create` |
| `PATCH /api/v1/vehicles/:id`  | `vehicles.update` |
| `DELETE /api/v1/vehicles/:id` | `vehicles.delete` |

### Ejemplos de Configuración

#### Solo Lectura

```json
{
  "vehicles": { "read": true },
  "clients": { "read": true }
}
```

#### Lectura y Escritura

```json
{
  "vehicles": {
    "read": true,
    "create": true,
    "update": true
  }
}
```

#### Acceso Completo

```json
{
  "vehicles": {
    "read": true,
    "create": true,
    "update": true,
    "delete": true
  },
  "clients": {
    "read": true,
    "create": true,
    "update": true,
    "delete": true
  }
}
```

---

## 💻 Gestión en el Frontend

### Ubicación

**Configuración → Acceso a API**

### Funcionalidades

1. **Listar API Keys**

   - Ver todas las keys activas
   - Ver keys expiradas
   - Ver última vez usada
   - Ver contador de requests

2. **Crear Nueva Key**

   - Nombre descriptivo
   - Seleccionar usuario propietario
   - Configurar permisos (checkboxes por recurso/acción)
   - Fecha de expiración opcional
   - Mostrar key completa una sola vez

3. **Editar Key**

   - Cambiar nombre
   - Modificar permisos
   - Cambiar fecha de expiración
   - ⚠️ No se puede ver la key completa

4. **Regenerar Key**

   - Genera nueva key
   - Mantiene permisos
   - Invalida key anterior
   - Muestra nueva key completa

5. **Revocar Key**

   - Desactiva inmediatamente
   - No se puede reactivar
   - Crear nueva si es necesario

6. **Eliminar Key**
   - Elimina permanentemente
   - Requiere confirmación

---

## 🔒 Seguridad

### Mejores Prácticas

1. **Nunca Compartir Keys**

   - Cada integración debe tener su propia key
   - No reutilizar keys entre sistemas

2. **Principio de Menor Privilegio**

   - Solo dar permisos necesarios
   - Ejemplo: Si solo necesita leer, no dar permisos de escritura

3. **Rotación Regular**

   - Regenerar keys periódicamente
   - Especialmente si hay cambio de personal

4. **Expiración**

   - Configurar fecha de expiración cuando sea posible
   - Renovar antes de que expire

5. **Monitoreo**

   - Revisar `last_used_at` regularmente
   - Revocar keys no usadas

6. **Almacenamiento Seguro**
   - Guardar en variables de entorno
   - Nunca en código fuente
   - Usar servicios de secrets (AWS Secrets Manager, etc.)

### Respuestas de Error

**Key Inválida:**

```json
{
  "error": "No autorizado"
}
```

Status: `401 Unauthorized`

**Sin Permisos:**

```json
{
  "error": "Permiso denegado",
  "message": "Esta API key no tiene permiso para create en vehicles"
}
```

Status: `403 Forbidden`

**Key Expirada:**

```json
{
  "error": "No autorizado"
}
```

Status: `401 Unauthorized`

---

## 📝 Ejemplos de Uso

### Ejemplo 1: Integración ERP (Solo Lectura)

**Caso de Uso:** Sistema ERP necesita consultar vehículos y clientes.

**Permisos:**

```json
{
  "vehicles": { "read": true },
  "clients": { "read": true }
}
```

**Código:**

```javascript
const apiKey = process.env.TTPN_API_KEY;

async function syncVehicles() {
  const response = await fetch("https://api.ttpn.com/api/v1/vehicles", {
    headers: { "X-API-Key": apiKey },
  });

  const vehicles = await response.json();
  // Procesar vehículos en ERP
}
```

### Ejemplo 2: App de Reservas (Lectura y Escritura)

**Caso de Uso:** App móvil para crear reservas.

**Permisos:**

```json
{
  "bookings": {
    "read": true,
    "create": true,
    "update": true
  },
  "vehicles": {
    "read": true
  }
}
```

**Código:**

```javascript
async function createBooking(bookingData) {
  const response = await fetch("https://api.ttpn.com/api/v1/bookings", {
    method: "POST",
    headers: {
      "X-API-Key": process.env.TTPN_API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ booking: bookingData }),
  });

  return await response.json();
}
```

### Ejemplo 3: Dashboard Externo (Solo Lectura)

**Caso de Uso:** Dashboard de métricas para clientes.

**Permisos:**

```json
{
  "vehicles": { "read": true },
  "bookings": { "read": true }
}
```

**Código:**

```python
import requests

API_KEY = os.getenv('TTPN_API_KEY')
BASE_URL = 'https://api.ttpn.com/api/v1'

headers = {'X-API-Key': API_KEY}

# Obtener vehículos
vehicles = requests.get(f'{BASE_URL}/vehicles', headers=headers).json()

# Obtener reservas
bookings = requests.get(f'{BASE_URL}/bookings', headers=headers).json()

# Generar métricas
print(f"Total vehículos: {len(vehicles)}")
print(f"Total reservas: {len(bookings)}")
```

---

## 🛠️ Gestión de API Keys

### Listar Todas las Keys

```bash
GET /api/v1/api_keys
```

### Ver Permisos Disponibles

```bash
GET /api/v1/api_keys/permissions
```

**Response:**

```json
{
  "available_permissions": {
    "vehicles": {
      "read": "Ver vehículos",
      "create": "Crear vehículos",
      "update": "Actualizar vehículos",
      "delete": "Eliminar vehículos"
    },
    ...
  }
}
```

### Regenerar Key

```bash
POST /api/v1/api_keys/:id/regenerate
```

**Response:**

```json
{
  "id": 1,
  "name": "Integración ERP",
  "key": "NEW_KEY_HERE",
  ...
}
```

### Revocar Key

```bash
POST /api/v1/api_keys/:id/revoke
```

**Response:**

```json
{
  "id": 1,
  "active": false,
  ...
}
```

---

## 📊 Monitoreo

### Métricas por Key

- **requests_count:** Total de requests realizados
- **last_used_at:** Última vez que se usó
- **created_at:** Cuándo se creó
- **expires_at:** Cuándo expira

### Auditoría

Todas las API keys tienen tracking completo:

- Quién la creó
- Cuándo se creó
- Quién la modificó
- Cuándo se modificó

---

## ⚠️ Troubleshooting

### Key no funciona

1. Verificar que esté activa
2. Verificar que no haya expirado
3. Verificar que tenga los permisos necesarios
4. Verificar que el header sea correcto: `X-API-Key`

### Error 403 (Forbidden)

La key no tiene permisos para esa acción. Revisar permisos en el panel de administración.

### Error 401 (Unauthorized)

La key es inválida, está revocada o expiró. Crear una nueva.

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0
