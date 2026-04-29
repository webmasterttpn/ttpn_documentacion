# 🎨 UI Moderna para Captura de Servicios TTPN

**Fecha:** 2026-01-16 11:21  
**Objetivo:** Crear UI eficiente con auto-creación de pasajeros

---

## ✅ Backend Implementado

### Endpoint: GET /api/v1/vehicles/:id/capacity

**Propósito:** Obtener capacidad del vehículo para auto-crear pasajeros

**Respuesta:**

```json
{
  "vehicle_id": 123,
  "clv": "U-001",
  "capacity": 3,
  "group": "1 a 3",
  "passenger_qty": 3,
  "suggested_passengers": 3
}
```

### Lógica de Capacidad

```ruby
# Basado en clv del vehículo y passenger_qty

if passenger_qty <= 3
  { capacity: 3, group: '1 a 3' }  # Autos
elsif passenger_qty >= 4 && clv.start_with?('U')
  { capacity: 3, group: '1 a 3' }  # Autos especiales
elsif passenger_qty >= 4 && (clv.start_with?('T') || clv.start_with?('V'))
  { capacity: 12, group: '4 a 12' }  # Vans
elsif !clv.start_with?('U', 'T', 'V')
  { capacity: 40, group: '13 a 40' }  # Camiones
else
  { capacity: passenger_qty, group: 'Personalizado' }
end
```

---

## 🎯 Flujo de Usuario

### 1. Usuario Selecciona Vehículo

```
Formulario de Captura
  ↓
Usuario selecciona: "U-001" (Auto)
  ↓
Sistema llama: GET /api/v1/vehicles/123/capacity
  ↓
Respuesta: { capacity: 3, group: "1 a 3" }
```

### 2. Auto-creación de Pasajeros

```javascript
// Frontend detecta cambio de vehículo
onVehicleChange(vehicleId) {
  // 1. Obtener capacidad
  const capacity = await getVehicleCapacity(vehicleId)

  // 2. Auto-crear pasajeros vacíos
  const passengers = []
  for (let i = 0; i < capacity.suggested_passengers; i++) {
    passengers.push({
      nombre: '',
      apaterno: '',
      amaterno: '',
      area: '',
      // ... campos vacíos
    })
  }

  // 3. Actualizar formulario
  this.passengers = passengers
}
```

### 3. Usuario Completa o Ajusta

```
Pasajeros pre-creados (vacíos):
  [ ] Pasajero 1: ___________
  [ ] Pasajero 2: ___________
  [ ] Pasajero 3: ___________

Usuario puede:
  ✅ Llenar los que conoce
  ✅ Dejar vacíos los desconocidos
  ✅ Agregar más pasajeros (+)
  ✅ Eliminar pasajeros (-)
```

---

## 📊 Ejemplos por Tipo de Vehículo

### Auto (U-001, capacidad 3)

```
Selecciona: U-001
  ↓
Auto-crea: 3 pasajeros vacíos
  ↓
Usuario llena: 2 pasajeros conocidos
Deja vacío: 1 pasajero
  ↓
Guarda: 2 pasajeros con datos, 1 sin datos
```

### Van (T-005, capacidad 12)

```
Selecciona: T-005
  ↓
Auto-crea: 12 pasajeros vacíos
  ↓
Usuario llena: 8 pasajeros conocidos
Deja vacíos: 4 pasajeros
  ↓
Guarda: 8 pasajeros con datos, 4 sin datos
```

### Camión (C-010, capacidad 40)

```
Selecciona: C-010
  ↓
Auto-crea: 40 pasajeros vacíos
  ↓
Usuario llena: 0 pasajeros (no tiene detalle)
Deja vacíos: 40 pasajeros
  ↓
Guarda: 40 pasajeros sin datos (solo conteo)
```

---

## 🎨 Propuesta de UI (Frontend)

### Componente: TtpnBookingForm.vue

```vue
<template>
  <q-form @submit="onSubmit">
    <!-- Información Básica -->
    <q-card class="q-mb-md">
      <q-card-section>
        <div class="text-h6">Información del Servicio</div>
      </q-card-section>

      <q-card-section>
        <div class="row q-col-gutter-md">
          <!-- Cliente -->
          <div class="col-12 col-md-6">
            <q-select
              v-model="form.client_id"
              :options="clients"
              label="Cliente"
              option-value="id"
              option-label="nombre"
              emit-value
              map-options
              outlined
              dense
            />
          </div>

          <!-- Fecha -->
          <div class="col-12 col-md-3">
            <q-input
              v-model="form.fecha"
              type="date"
              label="Fecha"
              outlined
              dense
            />
          </div>

          <!-- Hora -->
          <div class="col-12 col-md-3">
            <q-input
              v-model="form.hora"
              type="time"
              label="Hora"
              outlined
              dense
            />
          </div>

          <!-- Tipo de Servicio -->
          <div class="col-12 col-md-6">
            <q-select
              v-model="form.ttpn_service_type_id"
              :options="serviceTypes"
              label="Tipo (Entrada/Salida)"
              option-value="id"
              option-label="nombre"
              emit-value
              map-options
              outlined
              dense
            />
          </div>

          <!-- Servicio TTPN -->
          <div class="col-12 col-md-6">
            <q-select
              v-model="form.ttpn_service_id"
              :options="services"
              label="Servicio TTPN"
              option-value="id"
              option-label="descripcion"
              emit-value
              map-options
              outlined
              dense
            />
          </div>

          <!-- Vehículo -->
          <div class="col-12 col-md-6">
            <q-select
              v-model="form.vehicle_id"
              :options="vehicles"
              label="Unidad"
              option-value="id"
              option-label="clv"
              emit-value
              map-options
              outlined
              dense
              @update:model-value="onVehicleChange"
            >
              <template v-slot:append>
                <q-icon name="directions_car" />
              </template>
            </q-select>
          </div>

          <!-- Aforo -->
          <div class="col-12 col-md-6">
            <q-input
              v-model.number="form.aforo"
              type="number"
              label="Aforo"
              outlined
              dense
              readonly
              :hint="`Capacidad: ${vehicleCapacity.group || 'N/A'}`"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Pasajeros -->
    <q-card>
      <q-card-section>
        <div class="row items-center">
          <div class="col">
            <div class="text-h6">
              Pasajeros
              <q-badge color="primary" :label="passengers.length" />
            </div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              icon="add"
              label="Agregar Pasajero"
              @click="addPassenger"
              flat
              dense
            />
          </div>
        </div>

        <div
          v-if="vehicleCapacity.suggested_passengers"
          class="text-caption text-grey q-mt-sm"
        >
          <q-icon name="info" size="xs" />
          {{ passengers.length }} de
          {{ vehicleCapacity.suggested_passengers }} pasajeros sugeridos
        </div>
      </q-card-section>

      <q-separator />

      <q-card-section>
        <!-- Lista de Pasajeros -->
        <div
          v-if="passengers.length === 0"
          class="text-center text-grey q-pa-md"
        >
          <q-icon name="person_off" size="48px" />
          <div class="q-mt-sm">No hay pasajeros agregados</div>
          <div class="text-caption">
            Selecciona un vehículo para auto-crear pasajeros
          </div>
        </div>

        <q-list v-else separator>
          <q-item
            v-for="(passenger, index) in passengers"
            :key="index"
            class="q-pa-md"
          >
            <q-item-section>
              <div class="row q-col-gutter-sm">
                <div class="col-12">
                  <div class="text-subtitle2">Pasajero {{ index + 1 }}</div>
                </div>

                <!-- Nombre -->
                <div class="col-12 col-md-4">
                  <q-input
                    v-model="passenger.nombre"
                    label="Nombre"
                    outlined
                    dense
                    placeholder="Opcional"
                  />
                </div>

                <!-- Apellido Paterno -->
                <div class="col-12 col-md-4">
                  <q-input
                    v-model="passenger.apaterno"
                    label="Apellido Paterno"
                    outlined
                    dense
                    placeholder="Opcional"
                  />
                </div>

                <!-- Apellido Materno -->
                <div class="col-12 col-md-4">
                  <q-input
                    v-model="passenger.amaterno"
                    label="Apellido Materno"
                    outlined
                    dense
                    placeholder="Opcional"
                  />
                </div>

                <!-- Área -->
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="passenger.area"
                    label="Área"
                    outlined
                    dense
                    placeholder="Opcional"
                  />
                </div>

                <!-- Teléfono -->
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="passenger.telefono"
                    label="Teléfono"
                    outlined
                    dense
                    placeholder="Opcional"
                  />
                </div>
              </div>
            </q-item-section>

            <q-item-section side>
              <q-btn
                icon="delete"
                color="negative"
                flat
                round
                dense
                @click="removePassenger(index)"
              >
                <q-tooltip>Eliminar pasajero</q-tooltip>
              </q-btn>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card-section>
    </q-card>

    <!-- Botones de Acción -->
    <div class="row q-mt-md q-gutter-sm">
      <q-btn label="Cancelar" color="grey" flat @click="onCancel" />
      <q-space />
      <q-btn label="Guardar" color="primary" type="submit" :loading="loading" />
    </div>
  </q-form>
</template>

<script setup>
import { ref, computed } from "vue";
import { api } from "src/boot/axios";

// Props
const props = defineProps({
  booking: Object,
});

// Emit
const emit = defineEmits(["submit", "cancel"]);

// State
const form = ref({
  client_id: null,
  fecha: null,
  hora: null,
  ttpn_service_type_id: null,
  ttpn_service_id: null,
  vehicle_id: null,
  aforo: 0,
});

const passengers = ref([]);
const vehicleCapacity = ref({});
const loading = ref(false);

// Catálogos
const clients = ref([]);
const serviceTypes = ref([]);
const services = ref([]);
const vehicles = ref([]);

// Methods
const onVehicleChange = async (vehicleId) => {
  if (!vehicleId) return;

  try {
    // Obtener capacidad del vehículo
    const response = await api.get(`/vehicles/${vehicleId}/capacity`);
    vehicleCapacity.value = response.data;

    // Auto-crear pasajeros vacíos
    const suggestedCount = response.data.suggested_passengers;
    passengers.value = [];

    for (let i = 0; i < suggestedCount; i++) {
      passengers.value.push({
        nombre: "",
        apaterno: "",
        amaterno: "",
        area: "",
        telefono: "",
        calle: "",
        numero: "",
        colonia: "",
        celular: "",
      });
    }

    // Actualizar aforo
    form.value.aforo = suggestedCount;

    // Notificar al usuario
    $q.notify({
      message: `${suggestedCount} pasajeros pre-creados para ${response.data.clv}`,
      caption: `Grupo: ${response.data.group}`,
      color: "positive",
      icon: "check_circle",
    });
  } catch (error) {
    console.error("Error obteniendo capacidad:", error);
    $q.notify({
      message: "Error al obtener capacidad del vehículo",
      color: "negative",
      icon: "error",
    });
  }
};

const addPassenger = () => {
  passengers.value.push({
    nombre: "",
    apaterno: "",
    amaterno: "",
    area: "",
    telefono: "",
    calle: "",
    numero: "",
    colonia: "",
    celular: "",
  });
};

const removePassenger = (index) => {
  passengers.value.splice(index, 1);
  form.value.aforo = passengers.value.length;
};

const onSubmit = () => {
  const data = {
    ...form.value,
    ttpn_booking_passengers_attributes: passengers.value,
  };

  emit("submit", data);
};

const onCancel = () => {
  emit("cancel");
};
</script>
```

---

## 🎯 Beneficios de Esta Solución

### 1. Eficiencia

- ✅ Auto-crea pasajeros según vehículo
- ✅ Usuario solo llena los que conoce
- ✅ Ahorra tiempo en captura

### 2. Flexibilidad

- ✅ Puede agregar más pasajeros
- ✅ Puede eliminar pasajeros
- ✅ Campos opcionales

### 3. Precisión

- ✅ Basado en capacidad real del vehículo
- ✅ Lógica de negocio en backend
- ✅ Grupos bien definidos

### 4. UX Mejorada

- ✅ Notificaciones claras
- ✅ Indicadores visuales
- ✅ Proceso guiado

---

## 📊 Casos de Uso

### Caso 1: Pasajeros Conocidos

```
Usuario selecciona: U-001 (Auto, 3 pasajeros)
  ↓
Sistema pre-crea: 3 pasajeros vacíos
  ↓
Usuario llena: 3 pasajeros con datos completos
  ↓
Guarda: 3 pasajeros registrados
```

### Caso 2: Pasajeros Parcialmente Conocidos

```
Usuario selecciona: T-005 (Van, 12 pasajeros)
  ↓
Sistema pre-crea: 12 pasajeros vacíos
  ↓
Usuario llena: 5 pasajeros con datos
Deja vacíos: 7 pasajeros
  ↓
Guarda: 5 con datos, 7 sin datos (solo conteo)
```

### Caso 3: Sin Detalle de Pasajeros

```
Usuario selecciona: C-010 (Camión, 40 pasajeros)
  ↓
Sistema pre-crea: 40 pasajeros vacíos
  ↓
Usuario NO llena ninguno (no tiene detalle)
  ↓
Guarda: 40 pasajeros sin datos (aforo registrado)
```

---

## 🚀 Próximos Pasos

### 1. ✅ Backend Completado

- Endpoint `/api/v1/vehicles/:id/capacity`
- Lógica de capacidad implementada
- Ruta agregada

### 2. ⏳ Frontend Pendiente

- Crear componente `TtpnBookingForm.vue`
- Integrar con API
- Agregar validaciones

### 3. ⏳ Testing

- Probar con diferentes tipos de vehículos
- Validar auto-creación de pasajeros
- Verificar guardado

---

**Creado por:** Antigravity AI  
**Fecha:** 2026-01-16 11:21  
**Estado:** ✅ BACKEND LISTO - ⏳ FRONTEND PENDIENTE
