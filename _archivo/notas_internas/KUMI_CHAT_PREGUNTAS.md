# Kumi Chat — Preguntas disponibles

Referencia de todo lo que puedes preguntarle al asistente de Kumi.
El chat analiza tu mensaje, selecciona el endpoint correcto y formatea la respuesta.

---

## Estadísticas RH (`/api/v1/employee_stats`)

Agrega `"en 2024"` o `"en 2025"` para filtrar por año. Sin año usa el actual.

### Headcount
- ¿Cuántos empleados tenemos activos?
- ¿Cuántos empleados están inactivos?
- ¿Cuántos empleados en total hay en la empresa?

### Rotación
- ¿Cuántos empleados fueron dados de baja en 2025?
- ¿Cuál fue el porcentaje de rotación en 2024?
- ¿Cuántas altas de personal hubo en 2025?
- ¿Cuántos reingresos tuvimos en 2025?
- ¿Cuál fue el promedio de plantilla en 2024?

### Distribución
- ¿Cómo está distribuida la plantilla por área?
- ¿Cuántos empleados hay por puesto?
- ¿Cuántos choferes tenemos activos?

### Antigüedad
- ¿Cuál es la antigüedad promedio de los empleados?
- ¿Cuántos días en promedio llevan los empleados en la empresa?

### Documentos
- ¿Cuántos empleados tienen documentos vencidos?
- ¿Cuántos documentos vencen en los próximos 30 días?
- ¿Hay empleados con documentación por vencer?

### Citas
- ¿Cuántas citas médicas hay programadas este año?
- ¿Cuántas citas hay en 2025 y en qué estatus?

---

## Estadísticas de Flotilla (`/api/v1/vehicle_stats`)

### Unidades

- ¿Cuántos vehículos tenemos en total?
- ¿Cuántas unidades están activas?
- ¿Cuántas unidades están inactivas?
- ¿Cómo está distribuida la flotilla por tipo de vehículo?

### Documentos de vehículos

- ¿Cuántos vehículos tienen documentos vencidos?
- ¿Qué vehículos tienen póliza de seguro vencida?
- ¿Cuántos documentos vencen en los próximos 30 días?
- ¿Qué tipos de documentos están más vencidos?
- ¿Cuántas unidades no tienen documentos registrados?

### Asignaciones

- ¿Cuántos vehículos están asignados actualmente?
- ¿Cuántas unidades activas no tienen asignación?

---

## Estadísticas de Viajes (`/api/v1/booking_stats`)

Agrega `"en abril"`, `"en mayo 2025"` o `"del 1 al 15 de abril"` para filtrar por periodo. Sin periodo usa el mes actual.

- ¿Cuántos viajes hubo este mes?
- ¿Cuántos servicios se registraron en abril 2025?
- ¿Cuántos viajes hubo del 1 al 15 de marzo?
- ¿Cuántos viajes activos hay este mes?
- ¿Cuántos servicios hay por tipo en este periodo?
- ¿Cuántos pasajeros se transportaron este mes?
- ¿Cuál es el promedio de pasajeros por viaje?
- ¿Cuántos viajes no tienen chofer asignado?

---

## Estadísticas de Clientes (`/api/v1/client_stats`)

Agrega periodo para la actividad de viajes.

- ¿Cuántos clientes tenemos activos?
- ¿Cuántos clientes están inactivos?
- ¿Cuántas sucursales tenemos registradas?
- ¿Cuáles son los clientes con más viajes este mes?
- ¿Cuál es el top 10 de clientes por viajes en abril?

---

## Flotilla (`/api/v1/vehicles`)

Para buscar vehículos individuales por CLV.

- Busca el vehículo T001
- Dame información del vehículo U023
- ¿Cuáles son las unidades activas?

---

## Documentos de Vehículos (`/api/v1/vehicle_documents`)

Para listados específicos de documentos.

- ¿Qué vehículos tienen la póliza de seguro vencida?
- ¿Cuáles unidades tienen tenencia pendiente?
- ¿Qué verificaciones están por vencer?

---

## Empleados (`/api/v1/employees`)

Para buscar empleados individuales, no para conteos.

- Busca al chofer Juan Pérez
- ¿Cuáles choferes están activos?
- Dame la lista de empleados del área de operaciones

---

## Viajes / Bookings (`/api/v1/ttpn_bookings`)

Para listado de viajes del día o semana.

- Muéstrame los servicios de hoy
- ¿Cuántos servicios se registraron esta semana?
- ¿Qué viajes hay el 15 de abril?

---

## Cargas de Gasolina (`/api/v1/gasoline_charges`)

- ¿Cuántas cargas de gasolina hubo este mes?
- Muéstrame las últimas cargas de combustible

---

## Rendimiento de Combustible (`/api/v1/fuel_performance/summary`)

- ¿Cuál es el rendimiento de combustible de la flotilla?
- ¿Qué vehículo tiene el peor rendimiento de combustible?
- Dame el resumen de eficiencia de la flotilla

---

## Conteo de Viajes (`/api/v1/travel_counts`)

- ¿Cuántos viajes se han registrado?
- Muéstrame el conteo de viajes de esta semana

---

## Tips para mejores resultados

- **Fechas**: usa formato `15/04/2025`, `abril 2025` o `del 1 al 15 de abril`
- **Vehículos**: escribe la clave exacta en mayúsculas (`T001`, `U023`) o deja que el chat la detecte
- **Clientes**: puedes escribir en minúsculas, el sistema los normaliza (`bafar` = `BAFAR`)
- **Año**: si no lo especificas en RH, usa el año actual
- **Periodo**: si no lo especificas en viajes/clientes, usa el mes actual
- **Stats vs listado**: pregunta "cuántos" para obtener KPIs; pide "busca" o "muéstrame" para listados individuales
