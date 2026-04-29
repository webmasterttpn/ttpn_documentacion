# 📋 Formato Correcto del Excel para Importación

## Columnas Requeridas (en cualquier orden):

### Datos del Servicio:

| Columna     | Descripción                       | Ejemplo                   |
| ----------- | --------------------------------- | ------------------------- |
| `client_id` | CLV del cliente                   | `BAFAR`                   |
| `fecha`     | Fecha del servicio                | `2026-01-21`              |
| `hora`      | Hora del servicio                 | `14:30`                   |
| `unidad`    | CLV del vehículo                  | `T001`                    |
| `tipo`      | Tipo de servicio (Entrada/Salida) | `Entrada` o `Salida`      |
| `servicio`  | **CLV del servicio TTPN**         | `RTL`, `TEL`, `RDL`, etc. |
| `planta`    | Nombre de la planta del cliente   | `BAFAR`                   |

### Datos del Pasajero (Requeridos):

| Columna    | Descripción         | Ejemplo |
| ---------- | ------------------- | ------- |
| `nombre`   | Nombre del pasajero | `Juan`  |
| `apaterno` | Apellido paterno    | `Perez` |
| `amaterno` | Apellido materno    | `Lopez` |

### Datos del Pasajero (Opcionales):

| Columna        | Descripción        | Ejemplo      |
| -------------- | ------------------ | ------------ |
| `num empleado` | Número de empleado | `12345`      |
| `celular`      | Teléfono celular   | `6141234567` |
| `calle`        | Calle              | `Av. Juarez` |
| `numero`       | Número             | `123`        |
| `colonia`      | Colonia            | `Centro`     |
| `area`         | Área               | `Producción` |

## ⚠️ IMPORTANTE:

### Tipo de Servicio:

- **Entrada** (ID: 1)
- **Salida** (ID: 2)

Se busca por nombre (case-insensitive), así que puedes poner:

- `Entrada`, `ENTRADA`, `entrada`
- `Salida`, `SALIDA`, `salida`

### Servicio TTPN (CLV):

**NO uses la descripción, usa el CLV:**

| ❌ Incorrecto             | ✅ Correcto |
| ------------------------- | ----------- |
| `Ruta - Local`            | `RTL`       |
| `Tiempo Extra - Local`    | `TEL`       |
| `Ruta - Delicias`         | `RDL`       |
| `Tiempo Extra - Delicias` | `TED`       |

### Servicios TTPN Disponibles:

```
RTL - Ruta - Local
TEL - Tiempo Extra - Local
RDL - Ruta - Delicias
TED - Tiempo Extra - Delicias
RTR - Ruta - Rancho Bafar
TEA - Tiempo Extra - Aldama
TEM - Tiempo Extra - Meoqui
TES - Tiempo Extra - Satevo
TSG - Tiempo Extra - San Guillermo
RLT - Ruta - Labor de terrazas
```

## 📝 Ejemplo de Excel Correcto:

```
client_id | fecha      | hora  | unidad | tipo    | servicio | planta | nombre | apaterno | amaterno | num empleado | celular
BAFAR     | 2026-01-21 | 14:30 | T001   | Entrada | RTL      | BAFAR  | Juan   | Perez    | Lopez    | 12345        | 6141234567
BAFAR     | 2026-01-21 | 14:30 | T001   | Entrada | RTL      | BAFAR  | Maria  | Garcia   | Ruiz     | 12346        | 6141234568
BAFAR     | 2026-01-21 | 18:00 | T002   | Salida  | TEL      | BAFAR  | Pedro  | Martinez | Gomez    |              |
```

## 🔍 Validaciones:

El sistema validará que existan:

1. ✅ Cliente (por CLV)
2. ✅ Vehículo (por CLV)
3. ✅ Tipo de servicio (por nombre: Entrada/Salida)
4. ✅ **Servicio TTPN (por CLV)** ← IMPORTANTE
5. ✅ Planta del cliente (por nombre)

## 🚀 Proceso de Importación:

1. El sistema busca el chofer asignado al vehículo en la fecha/hora especificada
2. Si el booking ya existe (misma fecha/hora/unidad/tipo/servicio/cliente):
   - Agrega el pasajero si no existe
   - Actualiza los datos si el pasajero ya existe
3. Si el booking no existe:
   - Crea nuevo booking con el pasajero

## ⚙️ Chofer (employee_id):

**NO necesitas especificar el chofer en el Excel.**

El sistema automáticamente:

1. Busca en `vehicle_asignations` quién tenía asignado el vehículo en esa fecha/hora
2. Asigna ese chofer al booking
3. Si no hay asignación, usa el chofer por defecto (CLV '00000')
