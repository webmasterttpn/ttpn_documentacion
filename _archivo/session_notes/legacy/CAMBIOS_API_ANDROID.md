# Cambios y Actualizaciones en la API (Kumi V2) - Guía para Android

Este documento detalla todas las modificaciones recientes a nivel Base de Datos y puntos de conexión (Endpoints de la API) que el equipo de desarrollo de Android debe tomar en cuenta para enviar y recibir datos en los nuevos formatos esperados.

---

## 1. Concesionarios e Información de Choferes (Concessionaires / Employees)

Se separó el nombre monolítico de los campos en favor del formato estándar corporativo de los empleados, ahora cada concesionario respeta su apellido paterno y materno en las respuestas JSON y en las creaciones.

**Antes:**

```json
{
  "nombre": "Juan Pérez Ramos"
}
```

**Ahora:**
Tu aplicación web lo manda y la API responderá siempre con estructuración segmentada:

```json
{
  "nombre": "Juan",
  "a_paterno": "Pérez",
  "a_materno": "Ramos",
  "full_name": "Juan Pérez Ramos" // (Disponible en endpoints parseados como lectura)
}
```

- **Acción para Android:** Asegurar que si el chofer/concesionario edita o crea perfiles, los formularios envíen el `POST/PUT` con las 3 variables separadas.

---

## 2. Llaves de Cobro de Viaje (clv_servicio y clv_servicio_completa)

El esqueleto más importante de cruce entre Kumi Admin y el Operador físico/Cuentas. Se cambió el formato para hacerlo 100% legible y seguro ante _bugs_ históricos de cruce de husos horarios.

**Estructura y Nuevo Formato:**
Ahora la API calculará internamente las llaves con separadores **guiones** `-`, incorporando hasta los segundos en las horas de creación para evitar viajes dobles en la misma ubicación.

- `clv_servicio` = _`client_id`_ **-** _`fecha`_ **-** _`hora`_ (`HH:MM:SS`) **-** _`ttpn_service_type_id`_ **-** _`foreign_destiny_id`_ **-** _`vehicle_id`_
- _(Nota: La llave corta excluye intencionalmente el identificador del área del servicio `ttpn_service_id`)_

- **Acción para Android (Travel Counts):** **¡No necesitan enviar estar llave de Base de datos!** La API Web se encarga ahora de auto-generar este código `clv_servicio` exacto y con guiones cada vez que la aplicación mande a crear un viaje.
- **Validación y Triggers al crear Viajes:** Tampoco necesitan mandar una validación extra ni pedir cruces. En el nuevo Backend existen _Triggers_ (Disparadores de Postgres); en milisegundos de recibir a través de la API el nuevo `TravelCount` creado desde la App, la Base de Datos internamente lo procesa y valida por sí sola si empata con un _TtpnBooking_, actualizándolo todo en completo silencio.

---

## 3. Origen del Viaje (`creation_method` y `created_by_id`) en `TtpnBooking`

Se implementó auditoría estricta para saber de dónde proviene un viaje programado o guardado (`TtpnBooking`). Todas las tablas del sistema TtpnBooking ahora demandan esta información.

**Nuevos Campos Aceptados:**

1.  `creation_method` (String). El servidor aceptará cualquiera de estos valores:
    - `"manual"` _(Creado por una persona en un Formulario regular)_.
    - `"cloned"` _(Copiado de otro viaje en un solo clic)_.
    - `"imported"` _(Construido por la carga masiva de archivos de Coordinadores)_.

2.  `created_by_id` (Integer): ID de tu tabla `users` o del identificador del Coordinador/Móvil que subió este viaje.

- **Acción para Android:** Cuando guarden un viaje (`POST /api/v1/ttpn_bookings`), envíen en su JSON de "payload" el `creation_method` como `"manual"` para todos los viajes digitados desde la app. Si no, por defecto podrían generarse como nulos.

---

## 4. Cantidad de Pasajeros de la Lista (`passenger_qty`) en `TtpnBooking`

El sistema Web ha sido actualizado para **crear estrictamente la misma QPs (Cantidad de pasajeros en base de datos) a la que te envíen como Array (`ttpn_booking_passengers_attributes`)**.
Anteriormente se inyectaban espacios vacíos ("rellenos de base de datos") para igualar capacidades de camiones o "Vans". Eso ya no ocurre ni debe ocurrir en Base de Datos.

- **Acción para Android:** Cíñanse a mandar un Array únicamente con los pasajeros reales llenados por el usuario. No usen datos vacíos ni arrays fantasma para inflar o rellenar el viaje hacia la capacidad mínima del vehículo. El cálculo lo hará visualmente su Frontend; el servidor debe recibir solo lo verdaderamente documentado.
