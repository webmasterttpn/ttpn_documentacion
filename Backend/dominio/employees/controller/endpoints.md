# 📚 Documentación API - Módulo de Empleados

## 🎯 Endpoints Disponibles

### Base URL

```
http://localhost:3000/api/v1/employees
```

---

## 📋 Listado de Empleados

### GET /api/v1/employees

**Descripción:** Obtiene lista de empleados filtrada por business_unit

**Headers:**

```
Content-Type: application/json
Cookie: _ttpngas_session=...
```

**Response (200 OK):**

```json
[
  {
    "id": 1,
    "clv": "EMP-001",
    "nombre": "Juan",
    "apaterno": "Pérez",
    "amaterno": "García",
    "nombre_completo": "Juan Pérez García",
    "area": "operaciones",
    "status": true,
    "labor": {
      "id": 1,
      "nombre": "Chofer"
    },
    "business_unit": {
      "id": 1,
      "nombre": "Transportación Turística y Privada del Norte"
    }
  }
]
```

**Características:**

- ✅ Filtrado automático por `business_unit_id`
- ✅ Eager loading de relaciones
- ✅ Scope `business_unit_filter` aplicado
- ✅ Ordenado por `created_at DESC`

---

## 👤 Detalle de Empleado

### GET /api/v1/employees/:id

**Descripción:** Obtiene información completa de un empleado

**Response (200 OK):**

```json
{
  "id": 1,
  "clv": "EMP-001",
  "nombre": "Juan",
  "apaterno": "Pérez",
  "amaterno": "García",
  "nombre_completo": "Juan Pérez García",
  "area": "operaciones",
  "status": true,
  "sexo": "masculino",
  "estado_civil": "casado",
  "fecha_nacimiento": "1990-05-15",
  "direccion": "Calle Principal 123",
  "ciudad": "Chihuahua",
  "labor": {
    "id": 1,
    "nombre": "Chofer"
  },
  "business_unit": {
    "id": 1,
    "nombre": "Transportación Turística y Privada del Norte"
  },
  "concessionaire": {
    "id": 1,
    "nombre": "Concesionaria A"
  },
  "employee_documents": [
    {
      "id": 1,
      "employee_document_type_id": 1,
      "employee_document_type": {
        "id": 1,
        "nombre": "INE"
      },
      "numero": "123456789",
      "expiracion": "2025-12-31",
      "descripcion": "Identificación oficial",
      "doc_image_url": "/rails/active_storage/blobs/..."
    }
  ],
  "employee_salaries": [
    {
      "id": 1,
      "sdi": 250.0,
      "sueldo_diario": 300.0,
      "fecha_inicio": "2024-01-01",
      "fecha_fin": null
    }
  ],
  "employee_movements": [],
  "employee_work_days": [],
  "employee_drivers_levels": [],
  "avatar_url": "/rails/active_storage/blobs/...",
  "current_salary": 300.0,
  "created_at": "2024-01-01T00:00:00.000Z",
  "updated_at": "2024-01-01T00:00:00.000Z"
}
```

---

## ➕ Crear Empleado

### POST /api/v1/employees

**Request Body:**

```json
{
  "employee": {
    "clv": "EMP-002",
    "nombre": "María",
    "apaterno": "López",
    "amaterno": "Martínez",
    "sexo": "femenino",
    "estado_civil": "soltera",
    "area": "administración",
    "fecha_nacimiento": "1995-03-20",
    "direccion": "Av. Juárez 456",
    "ciudad": "Chihuahua",
    "status": true,
    "labor_id": 2,
    "business_unit_id": 1,
    "employee_documents_attributes": [
      {
        "employee_document_type_id": 1,
        "numero": "987654321",
        "expiracion": "2026-12-31",
        "descripcion": "INE"
      }
    ],
    "employee_salaries_attributes": [
      {
        "sdi": 200.0,
        "sueldo_diario": 250.0,
        "fecha_inicio": "2024-01-01"
      }
    ]
  }
}
```

**Response (201 Created):**

```json
{
  "id": 2,
  "clv": "EMP-002",
  ...
}
```

**Response (422 Unprocessable Entity):**

```json
{
  "errors": ["Clv ya está en uso", "Nombre no puede estar en blanco"]
}
```

---

## ✏️ Actualizar Empleado

### PATCH /api/v1/employees/:id

**Request Body:**

```json
{
  "employee": {
    "area": "taller",
    "direccion": "Nueva Dirección 789",
    "employee_salaries_attributes": [
      {
        "id": 1,
        "_destroy": true
      },
      {
        "sdi": 300.0,
        "sueldo_diario": 350.0,
        "fecha_inicio": "2024-06-01"
      }
    ]
  }
}
```

**Nested Attributes:**

- `employee_documents_attributes`
- `employee_salaries_attributes`
- `employee_movements_attributes`
- `employee_work_days_attributes`
- `employee_drivers_levels_attributes`

**Para eliminar:** Agregar `"_destroy": true` al objeto con `id`

---

## 🗑️ Eliminar Empleado

### DELETE /api/v1/employees/:id

**Response (204 No Content)**

---

## ✅ Activar Empleado

### PATCH /api/v1/employees/:id/activate

**Response (200 OK):**

```json
{
  "id": 1,
  "status": true,
  ...
}
```

---

## ❌ Desactivar Empleado

### PATCH /api/v1/employees/:id/deactivate

**Response (200 OK):**

```json
{
  "id": 1,
  "status": false,
  ...
}
```

---

## 🔐 Autenticación

Todos los endpoints requieren autenticación mediante sesión de Rails.

**Cookie requerida:**

```
_ttpngas_session=...
```

---

## 🎯 Filtrado por Business Unit

El scope `business_unit_filter` se aplica automáticamente:

- **SuperAdmin (`sadmin: true`):** Ve todos los empleados
- **Usuario regular:** Solo ve empleados de su `business_unit_id`
- **Sin business_unit:** No ve ningún empleado

---

## 📊 Campos del Modelo

### Campos Principales

- `clv` (string, unique, required) - Clave del empleado
- `nombre` (string, required)
- `apaterno` (string, required)
- `amaterno` (string)
- `sexo` (enum: masculino, femenino)
- `estado_civil` (enum: casado, soltero, union libre)
- `area` (enum: administración, intendencia, operaciones, taller)
- `fecha_nacimiento` (date)
- `direccion` (string)
- `ciudad` (string)
- `status` (boolean, default: true)

### Relaciones

- `belongs_to :labor` (required)
- `belongs_to :business_unit` (optional)
- `belongs_to :concessionaire` (optional)
- `has_many :employee_documents`
- `has_many :employee_salaries`
- `has_many :employee_movements`
- `has_many :employee_work_days`
- `has_many :employee_drivers_levels`

### ActiveStorage

- `avatar` (imagen del empleado)

---

## 🚀 Ejemplos de Uso

### Listar empleados activos

```bash
curl -X GET http://localhost:3000/api/v1/employees \
  -H "Content-Type: application/json" \
  --cookie "_ttpngas_session=..."
```

### Obtener detalle

```bash
curl -X GET http://localhost:3000/api/v1/employees/1 \
  -H "Content-Type: application/json" \
  --cookie "_ttpngas_session=..."
```

### Crear empleado

```bash
curl -X POST http://localhost:3000/api/v1/employees \
  -H "Content-Type: application/json" \
  --cookie "_ttpngas_session=..." \
  -d '{
    "employee": {
      "clv": "EMP-003",
      "nombre": "Pedro",
      "apaterno": "Sánchez",
      "amaterno": "Ruiz",
      "labor_id": 1,
      "business_unit_id": 1
    }
  }'
```

### Activar empleado

```bash
curl -X PATCH http://localhost:3000/api/v1/employees/1/activate \
  -H "Content-Type: application/json" \
  --cookie "_ttpngas_session=..."
```

---

## ⚠️ Notas Importantes

1. **Nested Attributes:** Rails acepta nested attributes automáticamente si están configurados en el modelo
2. **Validaciones:** `clv`, `nombre` y `apaterno` son obligatorios
3. **Business Unit Filter:** Se aplica automáticamente en index
4. **Performance:** Index usa eager loading para evitar N+1 queries
5. **Serializer:** Versión minimal para listas, full para detalle

---

## 📝 Changelog

**2024-12-19:**

- ✅ Implementado EmployeesController
- ✅ Implementado EmployeeSerializer
- ✅ Agregado scope business_unit_filter
- ✅ Limpiado código rails_admin
- ✅ Agregadas rutas activate/deactivate

---

**Última actualización:** 2024-12-19  
**Versión API:** V1  
**Autor:** Equipo de Desarrollo
