# 🎯 Sistema de Filtros Avanzados para Captura de Servicios

**Fecha:** 2026-01-16 12:17  
**Objetivo:** Implementar filtros dinámicos estilo Rails Admin

---

## 📋 Filtros Requeridos

### 1. **Búsqueda General**

- Campo de texto libre
- Busca en: Cliente, Descripción, Unidad

### 2. **Fecha**

- ✅ Fecha específica
- ✅ Rango de fechas (desde - hasta)
- ✅ Presets: Hoy, Ayer, Última semana, Último mes

### 3. **Hora**

- ✅ Hora específica
- ✅ Rango de horas (desde - hasta)
- ✅ Presets: Mañana (06-12), Tarde (12-18), Noche (18-24)

### 4. **Cliente**

- ✅ Selección múltiple
- ✅ Búsqueda por nombre
- ✅ Autocompletado

### 5. **Estado (Est)**

- ✅ Cuadrado
- ✅ Sin Cuadrar
- ✅ Todos

### 6. **Tipo (Entrada/Salida)**

- ✅ Selección múltiple
- ✅ Entrada
- ✅ Salida

### 7. **Servicio TTPN**

- ✅ Selección múltiple
- ✅ Búsqueda por descripción
- ✅ Autocompletado

### 8. **Unidad (Vehículo)**

- ✅ Selección múltiple
- ✅ Empieza con (U, T, V, etc.)
- ✅ Termina con
- ✅ Contiene
- ✅ Búsqueda por CLV

### 9. **QPs (Cantidad Pasajeros)**

- ✅ Igual a
- ✅ Mayor que
- ✅ Menor que
- ✅ Rango (desde - hasta)

---

## 🎨 Diseño de UI

### Estructura de Filtros

```vue
<q-card v-show="showFilters" class="q-mb-md">
  <q-card-section>
    <div class="row q-col-gutter-md">
      
      <!-- Búsqueda General -->
      <div class="col-12 col-md-3">
        <q-input 
          v-model="filters.search"
          label="Buscar"
          outlined dense clearable
        >
          <template v-slot:prepend>
            <q-icon name="search" />
          </template>
        </q-input>
      </div>

      <!-- Fecha con Rango -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.fechaPreset"
          :options="fechaPresets"
          label="Fecha"
          outlined dense clearable
          @update:model-value="onFechaPresetChange"
        />
      </div>

      <div class="col-12 col-md-3">
        <q-input
          v-model="filters.fechaDesde"
          type="date"
          label="Desde"
          outlined dense clearable
        />
      </div>

      <div class="col-12 col-md-3">
        <q-input
          v-model="filters.fechaHasta"
          type="date"
          label="Hasta"
          outlined dense clearable
        />
      </div>

      <!-- Hora con Rango -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.horaPreset"
          :options="horaPresets"
          label="Hora"
          outlined dense clearable
          @update:model-value="onHoraPresetChange"
        />
      </div>

      <div class="col-12 col-md-3">
        <q-input
          v-model="filters.horaDesde"
          type="time"
          label="Desde"
          outlined dense clearable
        />
      </div>

      <div class="col-12 col-md-3">
        <q-input
          v-model="filters.horaHasta"
          type="time"
          label="Hasta"
          outlined dense clearable
        />
      </div>

      <!-- Cliente (Múltiple) -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.clientes"
          :options="clientesOptions"
          label="Cliente"
          multiple
          use-chips
          outlined dense clearable
          option-value="id"
          option-label="nombre"
          emit-value
          map-options
        >
          <template v-slot:prepend>
            <q-icon name="business" />
          </template>
        </q-select>
      </div>

      <!-- Estado -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.estado"
          :options="estadoOptions"
          label="Estado"
          outlined dense clearable
        />
      </div>

      <!-- Tipo (Múltiple) -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.tipos"
          :options="tiposOptions"
          label="Tipo"
          multiple
          use-chips
          outlined dense clearable
          option-value="id"
          option-label="nombre"
          emit-value
          map-options
        />
      </div>

      <!-- Servicio TTPN (Múltiple) -->
      <div class="col-12 col-md-3">
        <q-select
          v-model="filters.servicios"
          :options="serviciosOptions"
          label="Servicio TTPN"
          multiple
          use-chips
          outlined dense clearable
          option-value="id"
          option-label="descripcion"
          emit-value
          map-options
        />
      </div>

      <!-- Unidad con Operadores -->
      <div class="col-12 col-md-2">
        <q-select
          v-model="filters.unidadOperador"
          :options="operadorOptions"
          label="Operador"
          outlined dense
        />
      </div>

      <div class="col-12 col-md-4">
        <q-select
          v-model="filters.unidades"
          :options="vehiculosOptions"
          label="Unidad"
          multiple
          use-chips
          outlined dense clearable
          option-value="id"
          option-label="clv"
          emit-value
          map-options
          use-input
          @filter="filterVehiculos"
        />
      </div>

      <!-- QPs con Operadores -->
      <div class="col-12 col-md-2">
        <q-select
          v-model="filters.qpsOperador"
          :options="operadorNumericoOptions"
          label="QPs"
          outlined dense
        />
      </div>

      <div class="col-12 col-md-2">
        <q-input
          v-model.number="filters.qpsValor"
          type="number"
          label="Valor"
          outlined dense clearable
        />
      </div>

      <div class="col-12 col-md-2" v-if="filters.qpsOperador === 'rango'">
        <q-input
          v-model.number="filters.qpsValorHasta"
          type="number"
          label="Hasta"
          outlined dense clearable
        />
      </div>

      <!-- Botones de Acción -->
      <div class="col-12">
        <div class="row justify-end q-gutter-sm">
          <q-btn
            label="Limpiar Filtros"
            icon="clear"
            color="grey-7"
            outline
            @click="clearFilters"
          />
          <q-btn
            label="Aplicar Filtros"
            icon="filter_alt"
            color="primary"
            @click="applyFilters"
          />
        </div>
      </div>

    </div>
  </q-card-section>
</q-card>
```

---

## 💻 Lógica de Filtros (JavaScript)

```javascript
// State de Filtros
const filters = ref({
  search: "",

  // Fecha
  fechaPreset: null,
  fechaDesde: null,
  fechaHasta: null,

  // Hora
  horaPreset: null,
  horaDesde: null,
  horaHasta: null,

  // Selecciones Múltiples
  clientes: [],
  tipos: [],
  servicios: [],
  unidades: [],

  // Estado
  estado: null,

  // Unidad con Operador
  unidadOperador: "contiene",

  // QPs con Operador
  qpsOperador: "igual",
  qpsValor: null,
  qpsValorHasta: null,
});

// Opciones de Presets
const fechaPresets = [
  { label: "Hoy", value: "hoy" },
  { label: "Ayer", value: "ayer" },
  { label: "Última Semana", value: "semana" },
  { label: "Último Mes", value: "mes" },
  { label: "Últimos 20 Días", value: "20dias" },
];

const horaPresets = [
  { label: "Mañana (06:00-12:00)", value: "manana" },
  { label: "Tarde (12:00-18:00)", value: "tarde" },
  { label: "Noche (18:00-24:00)", value: "noche" },
];

const estadoOptions = [
  { label: "Todos", value: null },
  { label: "Cuadrado", value: true },
  { label: "Sin Cuadrar", value: false },
];

const operadorOptions = [
  { label: "Contiene", value: "contiene" },
  { label: "Empieza con", value: "empieza" },
  { label: "Termina con", value: "termina" },
  { label: "Exacto", value: "exacto" },
];

const operadorNumericoOptions = [
  { label: "Igual a", value: "igual" },
  { label: "Mayor que", value: "mayor" },
  { label: "Menor que", value: "menor" },
  { label: "Rango", value: "rango" },
];

// Métodos
const onFechaPresetChange = (preset) => {
  const today = new Date();

  switch (preset) {
    case "hoy":
      filters.value.fechaDesde = today.toISOString().split("T")[0];
      filters.value.fechaHasta = today.toISOString().split("T")[0];
      break;
    case "ayer":
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      filters.value.fechaDesde = yesterday.toISOString().split("T")[0];
      filters.value.fechaHasta = yesterday.toISOString().split("T")[0];
      break;
    case "semana":
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      filters.value.fechaDesde = weekAgo.toISOString().split("T")[0];
      filters.value.fechaHasta = today.toISOString().split("T")[0];
      break;
    case "mes":
      const monthAgo = new Date(today);
      monthAgo.setMonth(monthAgo.getMonth() - 1);
      filters.value.fechaDesde = monthAgo.toISOString().split("T")[0];
      filters.value.fechaHasta = today.toISOString().split("T")[0];
      break;
    case "20dias":
      const days20Ago = new Date(today);
      days20Ago.setDate(days20Ago.getDate() - 20);
      filters.value.fechaDesde = days20Ago.toISOString().split("T")[0];
      filters.value.fechaHasta = today.toISOString().split("T")[0];
      break;
  }
};

const onHoraPresetChange = (preset) => {
  switch (preset) {
    case "manana":
      filters.value.horaDesde = "06:00";
      filters.value.horaHasta = "12:00";
      break;
    case "tarde":
      filters.value.horaDesde = "12:00";
      filters.value.horaHasta = "18:00";
      break;
    case "noche":
      filters.value.horaDesde = "18:00";
      filters.value.horaHasta = "23:59";
      break;
  }
};

const clearFilters = () => {
  filters.value = {
    search: "",
    fechaPreset: null,
    fechaDesde: null,
    fechaHasta: null,
    horaPreset: null,
    horaDesde: null,
    horaHasta: null,
    clientes: [],
    tipos: [],
    servicios: [],
    unidades: [],
    estado: null,
    unidadOperador: "contiene",
    qpsOperador: "igual",
    qpsValor: null,
    qpsValorHasta: null,
  };
  applyFilters();
};

const applyFilters = () => {
  fetchBookings();
};
```

---

## 🔧 Backend - Actualizar Controlador

```ruby
# app/controllers/api/v1/ttpn_bookings_controller.rb

def index
  @ttpn_bookings = TtpnBooking.includes(:client, :vehicle, :ttpn_service, :ttpn_service_type)

  # Búsqueda general
  if params[:search].present?
    search_term = "%#{params[:search]}%"
    @ttpn_bookings = @ttpn_bookings.joins(:client, :vehicle)
      .where("clients.razon_social ILIKE ? OR vehicles.clv ILIKE ? OR ttpn_bookings.descripcion ILIKE ?",
             search_term, search_term, search_term)
  end

  # Filtro de Fecha
  if params[:fecha_desde].present? && params[:fecha_hasta].present?
    @ttpn_bookings = @ttpn_bookings.where(fecha: params[:fecha_desde]..params[:fecha_hasta])
  elsif params[:fecha_desde].present?
    @ttpn_bookings = @ttpn_bookings.where('fecha >= ?', params[:fecha_desde])
  elsif params[:fecha_hasta].present?
    @ttpn_bookings = @ttpn_bookings.where('fecha <= ?', params[:fecha_hasta])
  else
    # Por defecto, últimos 20 días
    @ttpn_bookings = @ttpn_bookings.where(fecha: 20.days.ago.to_date..Date.today)
  end

  # Filtro de Hora
  if params[:hora_desde].present? && params[:hora_hasta].present?
    @ttpn_bookings = @ttpn_bookings.where('hora >= ? AND hora <= ?', params[:hora_desde], params[:hora_hasta])
  end

  # Filtro de Clientes (múltiple)
  if params[:clientes].present?
    @ttpn_bookings = @ttpn_bookings.where(client_id: params[:clientes])
  end

  # Filtro de Estado
  if params[:estado].present?
    @ttpn_bookings = @ttpn_bookings.where(viaje_encontrado: params[:estado])
  end

  # Filtro de Tipos (múltiple)
  if params[:tipos].present?
    @ttpn_bookings = @ttpn_bookings.where(ttpn_service_type_id: params[:tipos])
  end

  # Filtro de Servicios (múltiple)
  if params[:servicios].present?
    @ttpn_bookings = @ttpn_bookings.where(ttpn_service_id: params[:servicios])
  end

  # Filtro de Unidades (múltiple con operador)
  if params[:unidades].present?
    case params[:unidad_operador]
    when 'empieza'
      @ttpn_bookings = @ttpn_bookings.joins(:vehicle).where("vehicles.clv ILIKE ?", "#{params[:unidades].first}%")
    when 'termina'
      @ttpn_bookings = @ttpn_bookings.joins(:vehicle).where("vehicles.clv ILIKE ?", "%#{params[:unidades].first}")
    when 'exacto'
      @ttpn_bookings = @ttpn_bookings.where(vehicle_id: params[:unidades])
    else # contiene
      @ttpn_bookings = @ttpn_bookings.where(vehicle_id: params[:unidades])
    end
  end

  # Filtro de QPs (con operador)
  if params[:qps_valor].present?
    case params[:qps_operador]
    when 'igual'
      @ttpn_bookings = @ttpn_bookings.where(aforo: params[:qps_valor])
    when 'mayor'
      @ttpn_bookings = @ttpn_bookings.where('aforo > ?', params[:qps_valor])
    when 'menor'
      @ttpn_bookings = @ttpn_bookings.where('aforo < ?', params[:qps_valor])
    when 'rango'
      if params[:qps_valor_hasta].present?
        @ttpn_bookings = @ttpn_bookings.where(aforo: params[:qps_valor]..params[:qps_valor_hasta])
      end
    end
  end

  # Ordenar y paginar
  @ttpn_bookings = @ttpn_bookings.order(fecha: :desc, hora: :desc)
                                 .page(params[:page])
                                 .per(params[:per_page] || 20)

  # Renderizar
  render json: @ttpn_bookings.map { |booking|
    # ... mismo formato que antes
  }
end
```

---

## 🎯 Próximos Pasos

1. ⏳ Implementar componente de filtros completo
2. ⏳ Actualizar backend con todos los filtros
3. ⏳ Agregar indicadores visuales de filtros activos
4. ⏳ Guardar preferencias de filtros en localStorage

---

**Creado por:** Antigravity AI  
**Fecha:** 2026-01-16 12:17  
**Estado:** 📋 DOCUMENTADO - ⏳ PENDIENTE IMPLEMENTACIÓN
