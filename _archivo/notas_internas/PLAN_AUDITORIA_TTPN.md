# Plan de Implementación: Auditoría y Mejoras de TTPN Bookings

## 1. Campos de Auditoría (Backend)

### Migración Creada:

- ✅ `created_by_type` (integer) - Enum para tipo de creación

### Enum en el Modelo:

```ruby
# app/models/ttpn_booking.rb
enum created_by_type: {
  manual: 0,
  clone: 1,
  import: 2
}
```

### Campos Existentes:

- ✅ `created_by_id` - ID del usuario que creó
- ✅ `updated_by_id` - ID del usuario que actualizó
- ✅ `viaje_encontrado` - Boolean
- ✅ `status` - Boolean (activo/inactivo)
- ✅ `travel_count_id` - ID del viaje relacionado

## 2. Controlador - Asignar Usuario Actual

```ruby
# app/controllers/api/v1/ttpn_bookings_controller.rb
def create
  @ttpn_booking = TtpnBooking.new(ttpn_booking_params)
  @ttpn_booking.created_by_id = current_user.id
  @ttpn_booking.created_by_type = params[:created_by_type] || 'manual'

  if @ttpn_booking.save
    render json: { id: @ttpn_booking.id, message: 'Servicio creado exitosamente' }, status: :created
  else
    render json: { errors: @ttpn_booking.errors.full_messages }, status: :unprocessable_entity
  end
end
```

## 3. Frontend - Captura Manual

```javascript
// useTtpnBookingForm.js
const payload = {
  ttpn_booking: {
    client_id: clientId,
    // ... otros campos
    created_by_type: "manual", // Por defecto
  },
};
```

## 4. Frontend - Clonación

```javascript
// useTtpnBookingForm.js - en cloneBooking
const payload = {
  ttpn_booking: {
    // ... datos clonados
    created_by_type: "clone", // Marcar como clonado
  },
};
```

## 5. Endpoint de Importación Excel (Nuevo)

```ruby
# app/controllers/api/v1/ttpn_bookings_controller.rb
def import
  file = params[:file]
  user_id = current_user.id

  TtpnBookingImportJob.perform_later(file.path, user_id)

  render json: { message: 'Importación iniciada' }, status: :accepted
end
```

## 6. Vista/Edición - Mostrar Campos

### Campos a Agregar en el Formulario (Solo Lectura):

- `viaje_encontrado` - Checkbox deshabilitado o badge
- `status` - Checkbox deshabilitado o badge
- `travel_count_id` - Input deshabilitado (si existe)

### Cargar Pasajeros en Edición:

```javascript
// useTtpnBookingForm.js - loadBooking
const loadBooking = async (booking) => {
  // Cargar datos del booking
  const response = await api.get(`/api/v1/ttpn_bookings/${booking.id}`);
  const data = response.data;

  formData.value = {
    client_id: data.client_id,
    // ... otros campos
    passengers: data.ttpn_booking_passengers || [],
  };
};
```

### Endpoint Show debe incluir:

```ruby
# app/controllers/api/v1/ttpn_bookings_controller.rb
def show
  render json: {
    id: @ttpn_booking.id,
    client: {
      id: @ttpn_booking.client.id,
      nombre: @ttpn_booking.client.razon_social,
      clv: @ttpn_booking.client.clv
    },
    # ... otros campos
    viaje_encontrado: @ttpn_booking.viaje_encontrado,
    status: @ttpn_booking.status,
    travel_count_id: @ttpn_booking.travel_count_id,
    ttpn_booking_passengers: @ttpn_booking.ttpn_booking_passengers.map do |p|
      {
        id: p.id,
        client_branch_office_id: p.client_branch_office_id,
        nombre: p.nombre,
        # ... otros campos
      }
    end
  }
end
```

## 7. Próximos Pasos

1. ✅ Migración de `created_by_type` (en proceso)
2. ⏳ Agregar enum al modelo `TtpnBooking`
3. ⏳ Actualizar controlador para asignar `created_by_id` y `created_by_type`
4. ⏳ Actualizar frontend para enviar `created_by_type`
5. ⏳ Implementar endpoint `show` con datos completos
6. ⏳ Actualizar `loadBooking` para cargar pasajeros
7. ⏳ Agregar campos de solo lectura en el formulario
8. ⏳ Implementar importación de Excel (próxima fase)
