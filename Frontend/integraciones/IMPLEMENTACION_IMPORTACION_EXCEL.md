# Implementación de Importación de Excel - TTPN Bookings

## ✅ Completado:

### Frontend:

1. ✅ Botón de filtros convertido a icono redondo con tooltip
2. ✅ Botón de importación agregado (icono redondo con tooltip)
3. ✅ Diálogo de importación con selector de archivo
4. ✅ Barra de progreso en tiempo real
5. ✅ Composable `useTtpnBookingImport` con polling de progreso

### Backend:

1. ✅ Job `TtpnBookingImportJob` con lógica completa de importación

## ⏳ Pendiente:

### Backend:

1. **Modelo `TtpnBookingImport`** para rastrear importaciones
2. **Migración** para crear tabla `ttpn_booking_imports`
3. **Endpoints** en `TtpnBookingsController`:
   - `POST /api/v1/ttpn_bookings/import` - Iniciar importación
   - `GET /api/v1/ttpn_bookings/import/:id/status` - Obtener progreso
4. **Gem `roo`** para leer archivos Excel

## Próximos Pasos:

```bash
# 1. Agregar gem roo al Gemfile
gem 'roo'

# 2. Crear migración
rails g model TtpnBookingImport user:references status:string progress:decimal processed_rows:integer total_rows:integer created_count:integer updated_count:integer error_messages:text started_at:datetime completed_at:datetime

# 3. Ejecutar migración
rails db:migrate

# 4. Agregar endpoints al controlador
```

## Lógica de Importación:

### Validación de Duplicados:

- **Identificador único**: `clv_servicio` (client_id + fecha + hora + tipo + destino + vehículo)
- **Si existe booking**: Agregar o actualizar pasajero
- **Si no existe**: Crear nuevo booking con pasajero

### Identificación de Pasajeros:

- **Clave única**: nombre + apaterno + amaterno
- **Si existe pasajero**: Actualizar datos (solo campos no vacíos)
- **Si no existe**: Agregar nuevo pasajero al booking

### Campos del Excel:

- client_id, fecha, hora, unidad, tipo, servicio
- nombre, apaterno, amaterno, num empleado
- celular, calle, numero, colonia, area, planta

## Flujo Completo:

1. Usuario selecciona archivo Excel
2. Frontend sube archivo → Backend crea registro `TtpnBookingImport`
3. Backend encola job en Sidekiq
4. Job procesa archivo fila por fila:
   - Busca/crea cliente, vehículo, servicio, planta
   - Genera `clv_servicio`
   - Busca booking existente
   - Agrega/actualiza pasajero
   - Actualiza progreso cada fila
5. Frontend hace polling cada 2 segundos
6. Al completar, muestra resumen (creados/actualizados/errores)
