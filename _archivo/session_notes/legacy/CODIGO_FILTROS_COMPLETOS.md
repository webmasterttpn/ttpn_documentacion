# Código JavaScript para Filtros Completos

## State (agregar después de la línea 250)

```javascript
// State
const bookings = ref([]);
const clients = ref([]);
const filteredClients = ref([]);
const tipos = ref([]);
const filteredTipos = ref([]);
const servicios = ref([]);
const filteredServicios = ref([]);
const vehiculos = ref([]);
const filteredVehiculos = ref([]);
const choferes = ref([]);
const filteredChoferes = ref([]);
const loading = ref(false);
const saving = ref(false);
const showCreateDialog = ref(false);
const showFilters = ref(false);

const filters = ref({
  search: "",
  fecha: null,
  client: null,
  status: null,
  tipo: null,
  servicio: null,
  unidad: null,
  chofer: null,
});
```

## Métodos de Fetch (agregar después de fetchClients)

```javascript
const fetchTipos = async () => {
  try {
    const response = await api.get("/api/v1/ttpn_service_types");
    tipos.value = response.data;
    filteredTipos.value = response.data;
  } catch (error) {
    console.error("Error fetching tipos:", error);
  }
};

const fetchServicios = async () => {
  try {
    const response = await api.get("/api/v1/ttpn_services");
    servicios.value = response.data;
    filteredServicios.value = response.data;
  } catch (error) {
    console.error("Error fetching servicios:", error);
  }
};

const fetchVehiculos = async () => {
  try {
    const response = await api.get("/api/v1/vehicles");
    vehiculos.value = response.data;
    filteredVehiculos.value = response.data;
  } catch (error) {
    console.error("Error fetching vehiculos:", error);
  }
};

const fetchChoferes = async () => {
  try {
    const response = await api.get("/api/v1/employees");
    choferes.value = response.data.map((emp) => ({
      ...emp,
      nombre: `${emp.nombre} ${emp.apaterno}`.trim(),
    }));
    filteredChoferes.value = choferes.value;
  } catch (error) {
    console.error("Error fetching choferes:", error);
  }
};
```

## Métodos de Filtrado

```javascript
const filterTipos = (val, update) => {
  update(() => {
    if (val === "") {
      filteredTipos.value = tipos.value;
    } else {
      const needle = val.toLowerCase();
      filteredTipos.value = tipos.value.filter((tipo) =>
        tipo.nombre.toLowerCase().includes(needle)
      );
    }
  });
};

const filterServicios = (val, update) => {
  update(() => {
    if (val === "") {
      filteredServicios.value = servicios.value;
    } else {
      const needle = val.toLowerCase();
      filteredServicios.value = servicios.value.filter((servicio) =>
        servicio.descripcion.toLowerCase().includes(needle)
      );
    }
  });
};

const filterVehiculos = (val, update) => {
  update(() => {
    if (val === "") {
      filteredVehiculos.value = vehiculos.value;
    } else {
      const needle = val.toLowerCase();
      filteredVehiculos.value = vehiculos.value.filter((vehiculo) =>
        vehiculo.clv.toLowerCase().includes(needle)
      );
    }
  });
};

const filterChoferes = (val, update) => {
  update(() => {
    if (val === "") {
      filteredChoferes.value = choferes.value;
    } else {
      const needle = val.toLowerCase();
      filteredChoferes.value = choferes.value.filter((chofer) =>
        chofer.nombre.toLowerCase().includes(needle)
      );
    }
  });
};
```

## onMounted (actualizar)

```javascript
onMounted(() => {
  fetchBookings();
  fetchStats();
  fetchClients();
  fetchTipos();
  fetchServicios();
  fetchVehiculos();
  fetchChoferes();
});
```

---

**Instrucciones:**

1. Agregar el state completo
2. Agregar los métodos de fetch
3. Agregar los métodos de filtrado
4. Actualizar onMounted

Esto completará todos los filtros con búsqueda en tiempo real.
