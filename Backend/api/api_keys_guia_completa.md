# 🔑 Sistema de API Keys - Guía Completa de Uso

## 📋 Índice

1. [Introducción](#introducción)
2. [Conceptos Clave](#conceptos-clave)
3. [Guía de Uso - Frontend](#guía-de-uso-frontend)
4. [Guía de Uso - API](#guía-de-uso-api)
5. [Permisos Disponibles](#permisos-disponibles)
6. [Ejemplos de Uso](#ejemplos-de-uso)
7. [Seguridad](#seguridad)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Introducción

El sistema de API Keys permite a terceros integrar sus aplicaciones con nuestra plataforma de forma segura, con permisos granulares por recurso.

### Características Principales

- ✅ **Usuarios API separados** - No confundir con usuarios de plataforma
- ✅ **Permisos granulares** - Control fino por recurso y acción
- ✅ **Múltiples claves por usuario** - Producción, testing, desarrollo
- ✅ **Auditoría completa** - Tracking de uso y actividad
- ✅ **Expiración automática** - Claves con fecha de caducidad
- ✅ **Regeneración segura** - Rotar claves sin perder configuración

---

## 🧩 Conceptos Clave

### API User vs User

| Concepto          | API User               | User (Plataforma)        |
| ----------------- | ---------------------- | ------------------------ |
| **Propósito**     | Integraciones externas | Usuarios internos        |
| **Autenticación** | API Key                | Email + Password         |
| **Acceso**        | APIs/Endpoints         | Aplicaciones web/móvil   |
| **Permisos**      | Por recurso y acción   | Por rol                  |
| **Ejemplo**       | Sistema ERP, CRM       | Administrador, Conductor |

### Estructura de Permisos

```json
{
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
```

---

## 🖥️ Guía de Uso - Frontend

### 1. Crear Usuario API

1. Navegar a **Settings → Acceso a API**
2. Click en **"Nuevo Usuario API"**
3. Completar formulario:
   - **Nombre:** Nombre descriptivo (ej: "Sistema ERP Empresa XYZ")
   - **Email:** Email de contacto
   - **Empresa:** Nombre de la empresa
   - **Unidad de Negocio:** Seleccionar la unidad correspondiente
4. Click en **"Guardar"**

### 2. Crear API Key

1. En la tabla de **Usuarios API**, localizar el usuario
2. Click en el botón verde **"+"** (Crear API Key)
3. Configurar la clave:
   - **Nombre:** Identificador (ej: "Producción", "Testing")
   - **Fecha de expiración:** (Opcional) Fecha de caducidad
   - **Permisos:** Seleccionar checkboxes por recurso
4. Click en **"Crear Clave"**
5. **⚠️ IMPORTANTE:** Copiar la clave mostrada (solo se muestra una vez)

### 3. Gestionar Claves

**Regenerar Clave:**

- Click en el ícono de **"refresh"**
- Confirmar acción
- Copiar nueva clave generada

**Revocar Clave:**

- Click en el ícono de **"block"**
- La clave se desactiva inmediatamente

**Eliminar Clave:**

- Click en el ícono de **"delete"**
- Confirmar eliminación permanente

---

## 🔌 Guía de Uso - API

### Autenticación

**Método 1: Header (Recomendado)**

```bash
curl -X GET "https://api.ttpn.com/api/v1/vehicles" \
  -H "X-API-Key: tu_clave_api_aqui"
```

**Método 2: Query Parameter (Solo para testing)**

```bash
curl -X GET "https://api.ttpn.com/api/v1/vehicles?api_key=tu_clave_api_aqui"
```

### Ejemplos por Recurso

#### Vehículos

**Listar vehículos:**

```bash
curl -X GET "https://api.ttpn.com/api/v1/vehicles" \
  -H "X-API-Key: YOUR_API_KEY"
```

**Crear vehículo:**

```bash
curl -X POST "https://api.ttpn.com/api/v1/vehicles" \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicle": {
      "clv": "VEH-001",
      "marca": "Toyota",
      "modelo": "Hiace",
      "annio": 2020,
      "placa": "ABC123"
    }
  }'
```

#### Clientes

**Listar clientes:**

```bash
curl -X GET "https://api.ttpn.com/api/v1/clients" \
  -H "X-API-Key: YOUR_API_KEY"
```

**Crear cliente:**

```bash
curl -X POST "https://api.ttpn.com/api/v1/clients" \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "client": {
      "nombre": "Empresa ABC",
      "email": "contacto@empresa.com"
    }
  }'
```

---

## 🔐 Permisos Disponibles

### Recursos y Acciones

| Recurso       | Read | Create | Update | Delete | Descripción              |
| ------------- | ---- | ------ | ------ | ------ | ------------------------ |
| **vehicles**  | ✅   | ✅     | ✅     | ✅     | Vehículos de la flotilla |
| **clients**   | ✅   | ✅     | ✅     | ✅     | Clientes y contactos     |
| **employees** | ✅   | ✅     | ✅     | ✅     | Empleados y conductores  |
| **bookings**  | ✅   | ✅     | ✅     | ✅     | Reservas y servicios     |
| **users**     | ✅   | ✅     | ✅     | ✅     | Usuarios de plataforma   |
| **api_users** | ✅   | ✅     | ✅     | ✅     | Usuarios de API          |

### Mapeo de Acciones

| Acción HTTP             | Permiso Requerido |
| ----------------------- | ----------------- |
| GET /resource           | `read`            |
| POST /resource          | `create`          |
| PATCH/PUT /resource/:id | `update`          |
| DELETE /resource/:id    | `delete`          |

---

## 💡 Ejemplos de Uso

### Caso 1: Integración de Solo Lectura

**Escenario:** Dashboard externo que muestra vehículos

**Permisos:**

```json
{
  "vehicles": { "read": true },
  "clients": { "read": true }
}
```

**Código:**

```javascript
// Node.js
const axios = require("axios");

const API_KEY = "tu_clave_api";
const BASE_URL = "https://api.ttpn.com/api/v1";

async function getVehicles() {
  const response = await axios.get(`${BASE_URL}/vehicles`, {
    headers: { "X-API-Key": API_KEY },
  });
  return response.data;
}
```

### Caso 2: Sistema ERP Completo

**Escenario:** ERP que sincroniza vehículos y clientes

**Permisos:**

```json
{
  "vehicles": {
    "read": true,
    "create": true,
    "update": true,
    "delete": false
  },
  "clients": {
    "read": true,
    "create": true,
    "update": true,
    "delete": false
  }
}
```

**Código:**

```python
# Python
import requests

API_KEY = 'tu_clave_api'
BASE_URL = 'https://api.ttpn.com/api/v1'

headers = {'X-API-Key': API_KEY}

# Crear vehículo
def create_vehicle(data):
    response = requests.post(
        f'{BASE_URL}/vehicles',
        json={'vehicle': data},
        headers=headers
    )
    return response.json()

# Actualizar cliente
def update_client(client_id, data):
    response = requests.patch(
        f'{BASE_URL}/clients/{client_id}',
        json={'client': data},
        headers=headers
    )
    return response.json()
```

### Caso 3: App Móvil de Terceros

**Escenario:** App que permite reservar servicios

**Permisos:**

```json
{
  "bookings": {
    "read": true,
    "create": true,
    "update": true,
    "delete": false
  },
  "vehicles": {
    "read": true
  }
}
```

---

## 🔒 Seguridad

### Mejores Prácticas

1. **Nunca expongas la API Key en el código cliente**

   - ❌ Mal: JavaScript en el navegador
   - ✅ Bien: Backend/servidor

2. **Usa HTTPS siempre**

   ```bash
   # ❌ Mal
   http://api.ttpn.com/api/v1/vehicles

   # ✅ Bien
   https://api.ttpn.com/api/v1/vehicles
   ```

3. **Rota las claves periódicamente**

   - Producción: Cada 90 días
   - Testing: Cada 30 días

4. **Usa claves diferentes por ambiente**

   - Clave de Producción
   - Clave de Staging
   - Clave de Desarrollo

5. **Principio de menor privilegio**
   - Solo otorga los permisos necesarios
   - No des acceso de eliminación si no es necesario

### Variables de Entorno

```bash
# .env
TTPN_API_KEY=tu_clave_api_produccion
TTPN_API_URL=https://api.ttpn.com/api/v1

# .env.staging
TTPN_API_KEY=tu_clave_api_staging
TTPN_API_URL=https://staging-api.ttpn.com/api/v1
```

### Almacenamiento Seguro

**❌ Mal:**

```javascript
const API_KEY = "sk_live_abc123..."; // Hardcoded
```

**✅ Bien:**

```javascript
const API_KEY = process.env.TTPN_API_KEY;
```

---

## 🔧 Troubleshooting

### Error: "No autorizado"

**Causa:** API Key inválida o no proporcionada

**Solución:**

```bash
# Verificar que el header esté correcto
curl -v -X GET "https://api.ttpn.com/api/v1/vehicles" \
  -H "X-API-Key: YOUR_KEY"
```

### Error: "Permiso denegado"

**Causa:** La API Key no tiene el permiso necesario

**Solución:**

1. Ir a Settings → Acceso a API
2. Editar los permisos de la clave
3. Agregar el permiso faltante

### Error: "API Key expirada"

**Causa:** La clave llegó a su fecha de expiración

**Solución:**

1. Regenerar la clave
2. O crear una nueva clave

### Clave no funciona después de regenerar

**Causa:** Usando la clave antigua

**Solución:**

1. Actualizar la clave en tu aplicación
2. Verificar variables de entorno
3. Reiniciar tu aplicación

---

## 📊 Monitoreo

### Estadísticas Disponibles

En el frontend puedes ver:

- **Total de requests:** Número de llamadas realizadas
- **Último uso:** Fecha/hora de la última llamada
- **Claves activas:** Cuántas claves están activas

### Logs

Los requests con API Key se registran en:

```
log/development.log
log/production.log
```

Buscar por:

```bash
grep "API Key" log/production.log
```

---

## 🚀 Rate Limiting (Futuro)

**Planeado para v2:**

- 1000 requests/hora para claves de producción
- 100 requests/hora para claves de testing

---

## 📞 Soporte

**Problemas técnicos:**

- Email: soporte@ttpn.com
- Slack: #api-support

**Solicitar nuevos permisos:**

- Contactar al administrador del sistema

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0
