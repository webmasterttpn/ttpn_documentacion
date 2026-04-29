# ✅ Importación de Excel - Flexibilidad de Columnas

## 🎯 El Orden NO Importa

El sistema lee la primera fila del Excel como encabezados y crea un Hash con los nombres de las columnas. Esto significa que **puedes poner las columnas en cualquier orden**.

### Ejemplo:

**Opción 1:**

```
client_id | fecha | hora | unidad | nombre | apaterno | ...
```

**Opción 2:**

```
nombre | apaterno | client_id | unidad | fecha | hora | ...
```

**Opción 3:**

```
fecha | unidad | nombre | client_id | hora | apaterno | ...
```

**¡Todas funcionan igual!**

## 📝 Nombres de Columnas Flexibles

El sistema normaliza los nombres de las columnas a **lowercase** y elimina espacios extra, por lo que acepta variaciones:

### Ejemplos de nombres válidos:

| Columna Esperada | Variaciones Aceptadas                          |
| ---------------- | ---------------------------------------------- |
| `client_id`      | `Client_ID`, `CLIENT_ID`, `client_id`          |
| `fecha`          | `Fecha`, `FECHA`, `fecha`                      |
| `num empleado`   | `Num Empleado`, `NUM EMPLEADO`, `num empleado` |
| `nombre`         | `Nombre`, `NOMBRE`, `nombre`                   |

## 📋 Columnas Requeridas (en cualquier orden):

### Datos del Servicio:

- `client_id` - CLV del cliente
- `fecha` - Fecha del servicio
- `hora` - Hora del servicio
- `unidad` - CLV del vehículo
- `tipo` - Tipo de servicio
- `servicio` - Descripción del servicio
- `planta` - Nombre de la planta

### Datos del Pasajero:

- `nombre` - Nombre del pasajero
- `apaterno` - Apellido paterno
- `amaterno` - Apellido materno

### Datos Opcionales del Pasajero:

- `num empleado` - Número de empleado
- `celular` - Teléfono celular
- `calle` - Calle
- `numero` - Número
- `colonia` - Colonia
- `area` - Área

## ✅ Ejemplos Válidos:

### Excel 1 (Orden A):

```
client_id | fecha | hora | unidad | tipo | servicio | planta | nombre | apaterno | amaterno | num empleado
BAFAR | 2026-01-21 | 14:30 | T001 | PERSONAL | POSTURERO | BAFAR | Juan | Perez | Lopez | 12345
```

### Excel 2 (Orden B):

```
nombre | apaterno | amaterno | client_id | unidad | fecha | hora | tipo | servicio | planta | celular
Juan | Perez | Lopez | BAFAR | T001 | 2026-01-21 | 14:30 | PERSONAL | POSTURERO | BAFAR | 6141234567
```

### Excel 3 (Orden C - con mayúsculas):

```
NOMBRE | APATERNO | AMATERNO | CLIENT_ID | UNIDAD | FECHA | HORA | TIPO | SERVICIO | PLANTA
Juan | Perez | Lopez | BAFAR | T001 | 2026-01-21 | 14:30 | PERSONAL | POSTURERO | BAFAR
```

**¡Todos funcionan correctamente!**

## 🔍 Cómo Funciona:

1. **Lee la primera fila** como encabezados
2. **Normaliza los nombres** (lowercase, sin espacios extra)
3. **Crea un Hash** con nombre_columna => valor
4. **Busca los datos** por nombre de columna, no por posición

## ⚠️ Importante:

- Los **nombres de las columnas** deben coincidir (case-insensitive)
- El **orden** de las columnas no importa
- Las **columnas opcionales** pueden omitirse
- Las **columnas requeridas** deben estar presentes

## 💡 Recomendación:

Para mayor claridad, usa los nombres exactos en minúsculas:

```
client_id, fecha, hora, unidad, tipo, servicio, planta,
nombre, apaterno, amaterno, num empleado, celular,
calle, numero, colonia, area
```

Pero si tu Excel ya tiene los encabezados en mayúsculas o con espacios diferentes, **¡no hay problema!** El sistema los normalizará automáticamente.
