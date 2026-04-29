# 📝 PLAN DE IMPLEMENTACIÓN: Nested Attributes de 4 Niveles

## 🎯 Objetivo

Replicar la funcionalidad de RailsAdmin para crear/editar clientes con servicios que incluyen:

- **Nivel 1**: Client
- **Nivel 2**: client_ttpn_services (Servicios)
- **Nivel 3**: cts_increments (Periodos de incremento)
- **Nivel 4**: cts_increment_details (Detalles por rango de pasajeros)

Además:

- **Nivel 3 (paralelo)**: cts_driver_increments (Incrementos al chofer por tipo de vehículo)

---

## 📊 Estructura de Datos

### JSON Completo de Ejemplo

```json
{
  "client": {
    "clv": "CLI001",
    "razon_social": "Empresa SA",
    "status": true,

    "client_ttpn_services_attributes": [
      {
        "ttpn_service_id": 1,
        "status": true,

        "cts_increments_attributes": [
          {
            "fecha_efectiva": "2020-01-01",
            "fecha_hasta": "2021-01-10",

            "cts_increment_details_attributes": [
              {
                "incremento": 234.0,
                "pasajeros_min": 1,
                "pasajeros_max": 3
              },
              {
                "incremento": 503.0,
                "pasajeros_min": 4,
                "pasajeros_max": 7
              }
            ]
          },
          {
            "fecha_efectiva": "2021-01-11",
            "fecha_hasta": "2022-12-31",

            "cts_increment_details_attributes": [
              {
                "incremento": 250.0,
                "pasajeros_min": 1,
                "pasajeros_max": 5
              }
            ]
          }
        ],

        "cts_driver_increments_attributes": [
          {
            "vehicle_type_id": 1,
            "incremento": 50.0,
            "fecha_efectiva": "2020-01-01",
            "fecha_hasta": "2022-12-31",
            "status": true
          }
        ]
      }
    ]
  }
}
```

---

## 🏗️ Componentes Necesarios

### 1. **ClientForm.vue** (Principal)

- Stepper de 3 pasos
- Paso 3: Lista de servicios con botón "Editar Servicio"

### 2. **ServiceForm.vue** (Nuevo - Diálogo)

- Selector de servicio TTPN
- Status del servicio
- Tabs:
  - **Tab 1**: Incrementos al Servicio (por pasajeros)
  - **Tab 2**: Incrementos al Chofer (por tipo de vehículo)

### 3. **IncrementPeriodForm.vue** (Nuevo - Componente)

- Fecha efectiva
- Fecha hasta
- Lista de detalles de incremento
- Botón "Agregar Rango de Pasajeros"

### 4. **IncrementDetailForm.vue** (Nuevo - Inline)

- % Incremento
- Min. de Personas
- Max. de Personas

### 5. **DriverIncrementForm.vue** (Nuevo - Inline)

- Tipo de Vehículo (selector)
- Incremento (monto)
- Fecha efectiva
- Fecha hasta
- Status

---

## 🎨 Diseño de UI

### Paso 3 del ClientForm

```
┌─────────────────────────────────────────────────────┐
│ Servicios Contratados                    [+ Agregar]│
├─────────────────────────────────────────────────────┤
│ □ SRV001 - Servicio Ejecutivo          [✏️] [🗑️]  │
│   • 2 periodos de incremento configurados           │
│   • 3 tipos de vehículo con incremento              │
├─────────────────────────────────────────────────────┤
│ □ SRV002 - Traslado Aeropuerto         [✏️] [🗑️]  │
│   • 1 periodo de incremento configurado             │
│   • 2 tipos de vehículo con incremento              │
└─────────────────────────────────────────────────────┘
```

### Diálogo de ServiceForm

```
┌───────────────────────────────────────────────────────┐
│ Editar Servicio                                   [✕] │
├───────────────────────────────────────────────────────┤
│ Tipo de servicio: [CUU - Traslado Aeropuerto ▼]      │
│ Status: [✓] Activo                                    │
├───────────────────────────────────────────────────────┤
│ [Incrementos por Pasajeros] [Incrementos al Chofer]  │
├───────────────────────────────────────────────────────┤
│ TAB 1: Incrementos por Pasajeros                      │
│                                                        │
│ ┌─────────────────────────────────────────────────┐  │
│ │ Periodo 1: 2020-01-01 a 2021-01-10          [🗑️]│  │
│ │ ┌───────────────────────────────────────────┐   │  │
│ │ │ Rango 1: 1-3 pasajeros → +234%       [🗑️]│   │  │
│ │ │ Rango 2: 4-7 pasajeros → +503%       [🗑️]│   │  │
│ │ │                    [+ Agregar Rango]      │   │  │
│ │ └───────────────────────────────────────────┘   │  │
│ └─────────────────────────────────────────────────┘  │
│                                                        │
│ ┌─────────────────────────────────────────────────┐  │
│ │ Periodo 2: 2021-01-11 a 2022-12-31          [🗑️]│  │
│ │ ┌───────────────────────────────────────────┐   │  │
│ │ │ Rango 1: 1-5 pasajeros → +250%       [🗑️]│   │  │
│ │ │                    [+ Agregar Rango]      │   │  │
│ │ └───────────────────────────────────────────┘   │  │
│ └─────────────────────────────────────────────────┘  │
│                                                        │
│ [+ Agregar Periodo]                                   │
│                                                        │
├───────────────────────────────────────────────────────┤
│                     [Cancelar] [Guardar]              │
└───────────────────────────────────────────────────────┘
```

---

## 💻 Implementación por Componente

### 1. ServiceForm.vue (Componente Principal)

```vue
<template>
  <q-dialog v-model="show" persistent maximized>
    <q-card>
      <q-card-section class="row items-center">
        <div class="text-h6">{{ editing ? "Editar" : "Nuevo" }} Servicio</div>
        <q-space />
        <q-btn icon="close" flat round dense @click="cancel" />
      </q-card-section>

      <q-card-section>
        <!-- Selector de Servicio -->
        <q-select
          v-model="serviceForm.ttpn_service_id"
          :options="ttpnServices"
          option-value="id"
          option-label="descripcion"
          emit-value
          map-options
          label="Tipo de Servicio *"
          outlined
          dense
        >
          <template v-slot:option="scope">
            <q-item v-bind="scope.itemProps">
              <q-item-section>
                <q-item-label
                  >{{ scope.opt.clv }} -
                  {{ scope.opt.descripcion }}</q-item-label
                >
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <q-toggle
          v-model="serviceForm.status"
          label="Activo"
          color="positive"
        />

        <!-- Tabs -->
        <q-tabs v-model="tab" dense>
          <q-tab name="increments" label="Incrementos por Pasajeros" />
          <q-tab name="driver" label="Incrementos al Chofer" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="tab" animated>
          <!-- Tab 1: Incrementos por Pasajeros -->
          <q-tab-panel name="increments">
            <div class="q-gutter-md">
              <div class="row items-center">
                <div class="text-subtitle1">Periodos de Incremento</div>
                <q-space />
                <q-btn
                  color="primary"
                  icon="add"
                  label="Agregar Periodo"
                  size="sm"
                  @click="addIncrement"
                />
              </div>

              <!-- Lista de Periodos -->
              <q-list
                bordered
                separator
                v-if="serviceForm.cts_increments_attributes.length > 0"
              >
                <q-expansion-item
                  v-for="(
                    increment, incIndex
                  ) in serviceForm.cts_increments_attributes"
                  :key="incIndex"
                  v-show="!increment._destroy"
                  :label="`Periodo ${incIndex + 1}: ${
                    increment.fecha_efectiva || 'Sin fecha'
                  } - ${increment.fecha_hasta || 'Sin fecha'}`"
                  icon="date_range"
                >
                  <q-card>
                    <q-card-section>
                      <!-- Fechas del Periodo -->
                      <div class="row q-col-gutter-md q-mb-md">
                        <div class="col-6">
                          <q-input
                            v-model="increment.fecha_efectiva"
                            label="Fecha Efectiva *"
                            type="date"
                            outlined
                            dense
                          />
                        </div>
                        <div class="col-6">
                          <q-input
                            v-model="increment.fecha_hasta"
                            label="Fecha Hasta"
                            type="date"
                            outlined
                            dense
                          />
                        </div>
                      </div>

                      <!-- Detalles de Incremento (Rangos de Pasajeros) -->
                      <div class="text-subtitle2 q-mb-sm">
                        Rangos de Pasajeros
                      </div>
                      <q-btn
                        color="primary"
                        icon="add"
                        label="Agregar Rango"
                        size="sm"
                        @click="addIncrementDetail(incIndex)"
                        class="q-mb-md"
                      />

                      <q-list
                        bordered
                        v-if="
                          increment.cts_increment_details_attributes?.length > 0
                        "
                      >
                        <q-item
                          v-for="(
                            detail, detIndex
                          ) in increment.cts_increment_details_attributes"
                          :key="detIndex"
                          v-show="!detail._destroy"
                        >
                          <q-item-section>
                            <div class="row q-col-gutter-sm">
                              <div class="col-4">
                                <q-input
                                  v-model.number="detail.pasajeros_min"
                                  label="Min. Pasajeros"
                                  type="number"
                                  outlined
                                  dense
                                />
                              </div>
                              <div class="col-4">
                                <q-input
                                  v-model.number="detail.pasajeros_max"
                                  label="Max. Pasajeros"
                                  type="number"
                                  outlined
                                  dense
                                />
                              </div>
                              <div class="col-3">
                                <q-input
                                  v-model.number="detail.incremento"
                                  label="% Incremento"
                                  type="number"
                                  outlined
                                  dense
                                  suffix="%"
                                />
                              </div>
                              <div class="col-1">
                                <q-btn
                                  flat
                                  round
                                  dense
                                  icon="delete"
                                  color="negative"
                                  @click="
                                    removeIncrementDetail(incIndex, detIndex)
                                  "
                                />
                              </div>
                            </div>
                          </q-item-section>
                        </q-item>
                      </q-list>

                      <q-btn
                        flat
                        color="negative"
                        icon="delete"
                        label="Eliminar Periodo"
                        @click="removeIncrement(incIndex)"
                        class="q-mt-md"
                      />
                    </q-card-section>
                  </q-card>
                </q-expansion-item>
              </q-list>

              <div v-else class="text-center text-grey-7 q-pa-md">
                No hay periodos configurados
              </div>
            </div>
          </q-tab-panel>

          <!-- Tab 2: Incrementos al Chofer -->
          <q-tab-panel name="driver">
            <div class="q-gutter-md">
              <div class="row items-center">
                <div class="text-subtitle1">
                  Incrementos por Tipo de Vehículo
                </div>
                <q-space />
                <q-btn
                  color="primary"
                  icon="add"
                  label="Agregar Tipo de Vehículo"
                  size="sm"
                  @click="addDriverIncrement"
                />
              </div>

              <q-list
                bordered
                separator
                v-if="serviceForm.cts_driver_increments_attributes.length > 0"
              >
                <q-item
                  v-for="(
                    driverInc, index
                  ) in serviceForm.cts_driver_increments_attributes"
                  :key="index"
                  v-show="!driverInc._destroy"
                >
                  <q-item-section>
                    <div class="row q-col-gutter-md">
                      <div class="col-12 col-md-3">
                        <q-select
                          v-model="driverInc.vehicle_type_id"
                          :options="vehicleTypes"
                          option-value="id"
                          option-label="nombre"
                          emit-value
                          map-options
                          label="Tipo de Vehículo *"
                          outlined
                          dense
                        />
                      </div>
                      <div class="col-12 col-md-2">
                        <q-input
                          v-model.number="driverInc.incremento"
                          label="Incremento $"
                          type="number"
                          outlined
                          dense
                          prefix="$"
                        />
                      </div>
                      <div class="col-12 col-md-3">
                        <q-input
                          v-model="driverInc.fecha_efectiva"
                          label="Fecha Efectiva"
                          type="date"
                          outlined
                          dense
                        />
                      </div>
                      <div class="col-12 col-md-3">
                        <q-input
                          v-model="driverInc.fecha_hasta"
                          label="Fecha Hasta"
                          type="date"
                          outlined
                          dense
                        />
                      </div>
                      <div class="col-12 col-md-1">
                        <q-btn
                          flat
                          round
                          dense
                          icon="delete"
                          color="negative"
                          @click="removeDriverIncrement(index)"
                        />
                      </div>
                    </div>
                    <q-toggle
                      v-model="driverInc.status"
                      label="Activo"
                      color="positive"
                      class="q-mt-sm"
                    />
                  </q-item-section>
                </q-item>
              </q-list>

              <div v-else class="text-center text-grey-7 q-pa-md">
                No hay incrementos al chofer configurados
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancelar" @click="cancel" />
        <q-btn unelevated color="primary" label="Guardar" @click="save" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { api } from "boot/axios";

const props = defineProps({
  modelValue: Boolean,
  service: Object,
  editing: Boolean,
});

const emit = defineEmits(["update:modelValue", "save"]);

const show = computed({
  get: () => props.modelValue,
  set: (val) => emit("update:modelValue", val),
});

const tab = ref("increments");
const ttpnServices = ref([]);
const vehicleTypes = ref([]);

const serviceForm = ref({
  ttpn_service_id: null,
  status: true,
  cts_increments_attributes: [],
  cts_driver_increments_attributes: [],
});

// Métodos para Incrementos
function addIncrement() {
  serviceForm.value.cts_increments_attributes.push({
    fecha_efectiva: "",
    fecha_hasta: "",
    cts_increment_details_attributes: [],
  });
}

function removeIncrement(index) {
  const inc = serviceForm.value.cts_increments_attributes[index];
  if (inc.id) {
    inc._destroy = true;
  } else {
    serviceForm.value.cts_increments_attributes.splice(index, 1);
  }
}

function addIncrementDetail(incrementIndex) {
  const increment = serviceForm.value.cts_increments_attributes[incrementIndex];
  if (!increment.cts_increment_details_attributes) {
    increment.cts_increment_details_attributes = [];
  }
  increment.cts_increment_details_attributes.push({
    pasajeros_min: 1,
    pasajeros_max: 14,
    incremento: 0,
  });
}

function removeIncrementDetail(incrementIndex, detailIndex) {
  const detail =
    serviceForm.value.cts_increments_attributes[incrementIndex]
      .cts_increment_details_attributes[detailIndex];
  if (detail.id) {
    detail._destroy = true;
  } else {
    serviceForm.value.cts_increments_attributes[
      incrementIndex
    ].cts_increment_details_attributes.splice(detailIndex, 1);
  }
}

// Métodos para Driver Increments
function addDriverIncrement() {
  serviceForm.value.cts_driver_increments_attributes.push({
    vehicle_type_id: null,
    incremento: 0,
    fecha_efectiva: "",
    fecha_hasta: "",
    status: true,
  });
}

function removeDriverIncrement(index) {
  const di = serviceForm.value.cts_driver_increments_attributes[index];
  if (di.id) {
    di._destroy = true;
  } else {
    serviceForm.value.cts_driver_increments_attributes.splice(index, 1);
  }
}

function cancel() {
  emit("update:modelValue", false);
}

function save() {
  emit("save", serviceForm.value);
  emit("update:modelValue", false);
}

onMounted(async () => {
  // Cargar servicios TTPN
  const servicesRes = await api.get("/api/v1/ttpn_services");
  ttpnServices.value = servicesRes.data;

  // Cargar tipos de vehículos
  const vehiclesRes = await api.get("/api/v1/vehicle_types");
  vehicleTypes.value = vehiclesRes.data;

  // Si estamos editando, cargar datos
  if (props.service) {
    serviceForm.value = { ...props.service };
  }
});
</script>
```

---

## ✅ Checklist de Implementación

### Backend

- [✅] Modelo Client con nested attributes
- [✅] Controller con permisos de nested attributes
- [✅] Serializer con datos completos
- [✅] Eager loading para evitar N+1

### Frontend

- [ ] Crear `ServiceForm.vue` (componente completo)
- [ ] Actualizar `ClientForm.vue` paso 3 para usar `ServiceForm`
- [ ] Cargar catálogos (ttpn_services, vehicle_types)
- [ ] Implementar lógica de nested attributes
- [ ] Validaciones de formulario
- [ ] Tests de integración

---

## 🎯 Próximos Pasos

1. **Crear ServiceForm.vue** con toda la lógica de nested attributes
2. **Actualizar ClientForm.vue** para integrar el ServiceForm
3. **Crear endpoints** para catálogos (ttpn_services, vehicle_types)
4. **Probar** creación/edición completa

**¿Quieres que empiece a implementar el ServiceForm.vue completo?** 🚀
