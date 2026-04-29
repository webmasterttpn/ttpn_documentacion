# Implementación: Eliminar Servicios Individual y Múltiple

## Cambios Necesarios en TtpnBookingsCapturePage.vue

### 1. Agregar botón "Eliminar Seleccionados" en el header (después del botón de importar)

```vue
<q-btn
  v-if="selected.length > 0"
  color="negative"
  icon="delete"
  :label="`Eliminar ${selected.length} seleccionado${selected.length > 1 ? 's' : ''}`"
  @click="confirmDeleteMultiple"
  unelevated
/>
```

### 2. Modificar q-table para agregar selección múltiple

```vue
<q-table
  :rows="bookings"
  :columns="columns"
  row-key="id"
  :loading="loading"
  v-model:pagination="pagination"
  v-model:selected="selected"
  selection="multiple"
  :rows-per-page-options="[10, 20, 50, 100]"
  @request="onRequest"
  binary-state-sort
>
```

### 3. Agregar botón eliminar en columna de acciones (después del botón de ver)

```vue
<q-btn
  icon="delete"
  flat
  round
  dense
  color="negative"
  @click="confirmDelete(props.row)"
>
  <q-tooltip>Eliminar</q-tooltip>
</q-btn>
```

### 4. Agregar estado en script setup

```javascript
const selected = ref([]);
```

### 5. Agregar funciones de eliminación

```javascript
const confirmDelete = (booking) => {
  $q.dialog({
    title: "Confirmar eliminación",
    message: `¿Estás seguro de eliminar el servicio del ${booking.fecha} a las ${booking.hora}?`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      await api.delete(`/api/v1/ttpn_bookings/${booking.id}`);
      $q.notify({
        message: "Servicio eliminado exitosamente",
        color: "positive",
        icon: "check_circle",
      });
      fetchBookings();
    } catch (error) {
      console.error("Error deleting booking:", error);
      $q.notify({
        message: "Error al eliminar el servicio",
        color: "negative",
        icon: "error",
      });
    }
  });
};

const confirmDeleteMultiple = () => {
  $q.dialog({
    title: "Confirmar eliminación múltiple",
    message: `¿Estás seguro de eliminar ${selected.value.length} servicio${selected.value.length > 1 ? "s" : ""}?`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      const deletePromises = selected.value.map((booking) =>
        api.delete(`/api/v1/ttpn_bookings/${booking.id}`),
      );

      await Promise.all(deletePromises);

      $q.notify({
        message: `${selected.value.length} servicio${selected.value.length > 1 ? "s" : ""} eliminado${selected.value.length > 1 ? "s" : ""} exitosamente`,
        color: "positive",
        icon: "check_circle",
      });

      selected.value = [];
      fetchBookings();
    } catch (error) {
      console.error("Error deleting bookings:", error);
      $q.notify({
        message: "Error al eliminar los servicios",
        color: "negative",
        icon: "error",
      });
    }
  });
};
```

## Backend ya está listo

El endpoint `DELETE /api/v1/ttpn_bookings/:id` ya existe en el controlador (línea 249-252):

```ruby
def destroy
  @ttpn_booking.destroy
  head :no_content
end
```

## Resultado Final

- ✅ Checkbox en cada fila para selección
- ✅ Botón "Eliminar X seleccionados" aparece cuando hay selección
- ✅ Botón eliminar individual (🗑️) en cada fila
- ✅ Diálogo de confirmación antes de eliminar
- ✅ Notificación de éxito/error
- ✅ Recarga automática de la tabla después de eliminar
