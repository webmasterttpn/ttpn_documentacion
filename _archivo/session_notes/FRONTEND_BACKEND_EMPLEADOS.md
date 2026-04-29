# 📊 Comparación Frontend vs Backend - Empleados

## 🎯 Objetivo

Este documento mapea qué campos del backend se muestran en qué parte del frontend.

---

## 📋 Vista de Lista (EmployeesPage - Tabla)

### Columnas Mostradas (6)

| Columna    | Campo Backend     | Tipo     | Notas                          |
| ---------- | ----------------- | -------- | ------------------------------ |
| Estatus    | `status`          | boolean  | Badge verde/gris               |
| # Empleado | `clv`             | string   | Clave única                    |
| Nombre     | `nombre_completo` | computed | nombre + apaterno + amaterno   |
| Puesto     | `labor.nombre`    | relation | belongs_to :labor              |
| Área       | `area`            | enum     | administración/operaciones/etc |
| Acciones   | -                 | -        | Botones editar/eliminar        |

### JSON Necesario (Minimal)

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
  "labor": {
    "id": 1,
    "nombre": "Chofer"
  },
  "business_unit": {
    "id": 1,
    "nombre": "TTPN"
  }
}
```

**Tamaño estimado:** ~200 bytes por empleado  
**1000 empleados:** ~200 KB

---

## 📱 Vista de Cards (Móvil)

### Información Mostrada

```
┌─────────────────────────────┐
│ [JP] Juan Pérez García      │
│ EMP-001 • Chofer            │
│ ─────────────────────────   │
│ Área: Operaciones           │
│ [Editar]                    │
└─────────────────────────────┘
```

**Campos usados:**

- `nombre[0]` + `apaterno[0]` (avatar)
- `nombre_completo`
- `clv`
- `labor.nombre`
- `area`
- `status` (badge)

---

## 📝 Dialog - Tab General

### Campos del Formulario

#### Información Personal

| Campo Frontend   | Campo Backend      | Tipo   | Validación                 |
| ---------------- | ------------------ | ------ | -------------------------- |
| # Empleado       | `clv`              | text   | required, unique           |
| Nombre           | `nombre`           | text   | required                   |
| Apellido Paterno | `apaterno`         | text   | required                   |
| Apellido Materno | `amaterno`         | text   | optional                   |
| Sexo             | `sexo`             | select | masculino/femenino         |
| Estado Civil     | `estado_civil`     | select | casado/soltero/union libre |
| Fecha Nacimiento | `fecha_nacimiento` | date   | optional                   |

#### Información Laboral

| Campo Frontend    | Campo Backend       | Tipo   | Validación                                    |
| ----------------- | ------------------- | ------ | --------------------------------------------- |
| Puesto            | `labor_id`          | select | required                                      |
| Área              | `area`              | select | administración/intendencia/operaciones/taller |
| Unidad de Negocio | `business_unit_id`  | select | optional                                      |
| Concesionaria     | `concessionaire_id` | select | optional                                      |

#### Información de Contacto

| Campo Frontend | Campo Backend | Tipo | Validación |
| -------------- | ------------- | ---- | ---------- |
| Dirección      | `direccion`   | text | optional   |
| Ciudad         | `ciudad`      | text | optional   |

#### Estado

| Campo Frontend  | Campo Backend | Tipo     | Validación |
| --------------- | ------------- | -------- | ---------- |
| Empleado Activo | `status`      | checkbox | boolean    |

### JSON Necesario (Full)

```json
{
  "id": 1,
  "clv": "EMP-001",
  "nombre": "Juan",
  "apaterno": "Pérez",
  "amaterno": "García",
  "sexo": "masculino",
  "estado_civil": "casado",
  "fecha_nacimiento": "1990-05-15",
  "area": "operaciones",
  "direccion": "Calle Principal 123",
  "ciudad": "Chihuahua",
  "status": true,
  "labor_id": 1,
  "business_unit_id": 1,
  "concessionaire_id": null,
  "labor": { "id": 1, "nombre": "Chofer" },
  "business_unit": { "id": 1, "nombre": "TTPN" },
  "concessionaire": null,
  "avatar_url": "/rails/active_storage/...",
  ...
}
```

---

## 📄 Dialog - Tab Documentos

### Nested Form: employee_documents_attributes

#### Campos por Documento

| Campo Frontend    | Campo Backend               | Tipo   | Validación |
| ----------------- | --------------------------- | ------ | ---------- |
| Tipo de Documento | `employee_document_type_id` | select | required   |
| Número/Folio      | `numero`                    | text   | optional   |
| Fecha Vencimiento | `expiracion`                | date   | optional   |
| Descripción       | `descripcion`               | text   | optional   |
| Archivo           | `doc_image`                 | file   | image/pdf  |

### JSON Necesario

```json
{
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
  ]
}
```

### Payload al Guardar

```json
{
  "employee": {
    "employee_documents_attributes": [
      {
        "id": 1,
        "employee_document_type_id": 1,
        "numero": "123456789",
        "expiracion": "2025-12-31",
        "descripcion": "INE"
      },
      {
        "employee_document_type_id": 2,
        "numero": "987654321",
        "expiracion": "2026-06-30",
        "descripcion": "Licencia"
      },
      {
        "id": 3,
        "_destroy": true
      }
    ]
  }
}
```

---

## 💰 Dialog - Tab Salarios

### Nested Form: employee_salaries_attributes

#### Campos por Salario

| Campo Frontend | Campo Backend   | Tipo   | Validación |
| -------------- | --------------- | ------ | ---------- |
| SDI            | `sdi`           | number | required   |
| Sueldo Diario  | `sueldo_diario` | number | optional   |
| Fecha Inicio   | `fecha_inicio`  | date   | optional   |
| Fecha Fin      | `fecha_fin`     | date   | optional   |

### JSON Necesario

```json
{
  "employee_salaries": [
    {
      "id": 1,
      "sdi": 250.0,
      "sueldo_diario": 300.0,
      "fecha_inicio": "2024-01-01",
      "fecha_fin": null
    }
  ],
  "current_salary": 300.0
}
```

---

## 🔄 Dialog - Tab Movimientos

### Nested Form: employee_movements_attributes

#### Campos por Movimiento

| Campo Frontend     | Campo Backend               | Tipo   | Validación |
| ------------------ | --------------------------- | ------ | ---------- |
| Tipo de Movimiento | `employee_movement_type_id` | select | required   |
| Fecha              | `fecha`                     | date   | optional   |
| Descripción        | `descripcion`               | text   | optional   |

### JSON Necesario

```json
{
  "employee_movements": [
    {
      "id": 1,
      "employee_movement_type_id": 1,
      "employee_movement_type": {
        "id": 1,
        "nombre": "Alta"
      },
      "fecha": "2024-01-01",
      "descripcion": "Ingreso a la empresa"
    }
  ]
}
```

---

## 🔍 Búsqueda y Filtros

### Campos Buscables

```javascript
function filterMethod(rows, terms) {
  const lowerTerms = terms.toLowerCase();
  return rows.filter((row) => {
    const searchText = `
      ${row.clv}
      ${row.nombre_completo}
      ${row.labor?.nombre}
      ${row.area}
      ${row.business_unit?.nombre}
    `.toLowerCase();

    return searchText.includes(lowerTerms);
  });
}
```

### Filtros Disponibles

- **Área:** administración, intendencia, operaciones, taller
- **Puesto:** Select de labors
- **Unidad de Negocio:** Select de business_units
- **Estado:** Activo/Inactivo

---

## 📊 Resumen de Datos

### Tamaño de Respuestas

| Endpoint           | Scope   | Campos | Tamaño Aprox |
| ------------------ | ------- | ------ | ------------ |
| GET /employees     | minimal | 10     | 200 bytes    |
| GET /employees/:id | full    | 50+    | 2-5 KB       |

### Performance

| Acción                 | Queries | Tiempo Estimado |
| ---------------------- | ------- | --------------- |
| Index (1000 empleados) | 3       | ~200ms          |
| Show (con relaciones)  | 8       | ~50ms           |
| Create                 | 5-10    | ~100ms          |
| Update                 | 5-10    | ~100ms          |

---

## ✅ Checklist de Implementación Frontend

### EmployeesPage.vue

- [ ] Tabla con 6 columnas
- [ ] Vista de cards para móvil
- [ ] Búsqueda en tiempo real
- [ ] Filtros (área, puesto, status)
- [ ] Botón "Nuevo Empleado"

### Dialog - Tab General

- [ ] Formulario con todos los campos
- [ ] Validaciones client-side
- [ ] Upload de avatar
- [ ] Selects de catálogos (labor, business_unit, etc.)

### Dialog - Tab Documentos

- [ ] Tabs horizontales por documento
- [ ] Botón "Agregar Nuevo"
- [ ] Botón "Eliminar" por documento
- [ ] Upload de archivo (después de guardar)
- [ ] Preview de archivo

### Dialog - Tab Salarios

- [ ] Lista de salarios
- [ ] Botón "Agregar Nuevo"
- [ ] Mostrar salario actual destacado

### Dialog - Tab Movimientos

- [ ] Lista de movimientos
- [ ] Botón "Agregar Nuevo"
- [ ] Ordenar por fecha DESC

---

**Última actualización:** 2024-12-19  
**Referencia:** VehiclesPage.vue (patrón a seguir)
