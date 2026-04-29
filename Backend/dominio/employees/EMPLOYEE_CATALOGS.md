# Catálogos de Empleados - Documentación

## Descripción General

Este módulo proporciona endpoints para gestionar los catálogos relacionados con empleados en el sistema TTPN Admin V2.

## Endpoints Disponibles

### 1. Tipos de Movimientos de Empleados

**Endpoint:** `/api/v1/employee_movement_types`

Gestiona los tipos de movimientos que pueden aplicarse a los empleados (Altas, Bajas, Cambios de puesto, etc.)

#### Campos:

- `nombre` (string, requerido): Nombre del tipo de movimiento
- `descripcion` (text, opcional): Descripción detallada

#### Ejemplos de uso:

```ruby
# Crear un tipo de movimiento
POST /api/v1/employee_movement_types
{
  "employee_movement_type": {
    "nombre": "Alta",
    "descripcion": "Ingreso de nuevo empleado"
  }
}

# Listar todos
GET /api/v1/employee_movement_types

# Actualizar
PATCH /api/v1/employee_movement_types/:id
{
  "employee_movement_type": {
    "descripcion": "Descripción actualizada"
  }
}

# Eliminar
DELETE /api/v1/employee_movement_types/:id
```

---

### 2. Puestos (Labors)

**Endpoint:** `/api/v1/labors`

Gestiona los puestos o cargos disponibles para los empleados.

#### Campos:

- `nombre` (string, requerido): Nombre del puesto
- `descripcion` (text, opcional): Descripción del puesto
- `tope_salarial` (decimal, opcional): Tope salarial para el puesto
- `status` (boolean): Estado activo/inactivo

#### Ejemplos de uso:

```ruby
# Crear un puesto
POST /api/v1/labors
{
  "labor": {
    "nombre": "Gerente de Operaciones",
    "descripcion": "Responsable de las operaciones diarias",
    "tope_salarial": 50000.00
  }
}

# Listar todos
GET /api/v1/labors

# Actualizar
PATCH /api/v1/labors/:id

# Eliminar
DELETE /api/v1/labors/:id
```

---

### 3. Tipos de Documentos de Empleados

**Endpoint:** `/api/v1/employee_document_types`

Gestiona los tipos de documentos que pueden asociarse a los empleados.

#### Campos:

- `nombre` (string, requerido): Nombre del tipo de documento
- `descripcion` (text, opcional): Descripción del tipo de documento

#### Ejemplos comunes:

- INE
- CURP
- RFC
- Comprobante de domicilio
- Acta de nacimiento
- Título profesional

#### Ejemplos de uso:

```ruby
# Crear un tipo de documento
POST /api/v1/employee_document_types
{
  "employee_document_type": {
    "nombre": "INE",
    "descripcion": "Identificación oficial"
  }
}

# Listar todos
GET /api/v1/employee_document_types
```

---

### 4. Tipos de Incidencias

**Endpoint:** `/api/v1/incidences`

Gestiona los tipos de incidencias que pueden registrarse para los empleados.

#### Campos:

- `descripcion` (string, requerido): Descripción de la incidencia
- `puntuacion` (integer, requerido): Puntuación o peso de la incidencia
- `status` (boolean): Estado activo/inactivo

#### Ejemplos comunes:

- Retardo (puntuación: 1)
- Falta injustificada (puntuación: 3)
- Falta justificada (puntuación: 0)
- Permiso (puntuación: 0)
- Incapacidad (puntuación: 0)

#### Ejemplos de uso:

```ruby
# Crear un tipo de incidencia
POST /api/v1/incidences
{
  "incidence": {
    "descripcion": "Retardo",
    "puntuacion": 1,
    "status": true
  }
}

# Listar todos
GET /api/v1/incidences

# Actualizar
PATCH /api/v1/incidences/:id

# Eliminar
DELETE /api/v1/incidences/:id
```

---

## Autenticación

Todos los endpoints requieren autenticación mediante Bearer Token:

```
Authorization: Bearer {your_api_key}
```

## Permisos

Los permisos se configuran en el sistema de API Keys. Para cada catálogo se pueden configurar:

- `read`: Ver registros
- `create`: Crear nuevos registros
- `update`: Actualizar registros existentes
- `delete`: Eliminar registros

### Configuración de permisos en API Key:

```json
{
  "permissions": {
    "labors": {
      "read": true,
      "create": true,
      "update": true,
      "delete": false
    },
    "employee_movement_types": {
      "read": true,
      "create": true,
      "update": true,
      "delete": true
    },
    "employee_document_types": {
      "read": true,
      "create": false,
      "update": false,
      "delete": false
    },
    "incidences": {
      "read": true,
      "create": true,
      "update": true,
      "delete": true
    }
  }
}
```

## Testing

### Factories

Todos los catálogos tienen factories definidos en `spec/factories.rb`:

```ruby
# Crear registros de prueba
create(:incidence)
create(:incidence, :high_score)
create(:employee_movement_type, :alta)
create(:employee_document_type, :ine)
create(:labor)
```

### Ejecutar Tests

```bash
# Todos los tests de catálogos
bundle exec rspec spec/requests/api/v1/incidences_spec.rb

# Generar documentación Swagger
bundle exec rake rswag:specs:swaggerize
```

## Frontend

Los catálogos están disponibles en la interfaz web en:
**Configuración → Catálogos / Directorios**

Cada catálogo proporciona:

- Listado con búsqueda
- Creación de nuevos registros
- Edición de registros existentes
- Eliminación de registros
- Vista responsiva (desktop y móvil)

## Notas Importantes

### Compatibilidad con App Móvil

- ⚠️ **NO modificar** la estructura de las tablas existentes sin actualizar primero la app móvil PHP
- ✅ **SÍ agregar** nuevos campos opcionales
- ✅ **SÍ agregar** nuevos endpoints
- ✅ **SÍ agregar** nuevos catálogos

### Performance

- Todos los controladores están optimizados para evitar N+1 queries
- Los índices están configurados en las columnas de búsqueda frecuente
- Las respuestas JSON son serializadas manualmente para mejor performance

### Validaciones

- Los campos requeridos están validados a nivel de modelo
- Las respuestas de error incluyen mensajes descriptivos
- Los códigos HTTP son estándar (200, 201, 422, 404, etc.)

## Changelog

### 2025-12-29

- ✅ Agregado endpoint completo para `incidences`
- ✅ Agregados permisos de API para todos los catálogos de empleados
- ✅ Agregados factories para testing
- ✅ Agregados tests RSpec con documentación Swagger
- ✅ Integración con frontend (CatalogManager)

## Soporte

Para reportar issues o solicitar nuevas funcionalidades, contactar al equipo de desarrollo.
