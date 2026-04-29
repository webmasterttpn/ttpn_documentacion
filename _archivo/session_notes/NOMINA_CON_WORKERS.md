# 🚀 SISTEMA DE NÓMINA CON WORKERS - IMPLEMENTACIÓN

## ✅ **LO QUE SE IMPLEMENTÓ (Backend)**

### 1. **Migraciones**

- ✅ `progress` (integer, default: 0)
- ✅ `excel_generated` (boolean, default: false)
- ✅ `fecha_fin_planificada` / `hora_fin_planificada`
- ✅ Tabla `payroll_logs`

### 2. **Modelo Payroll**

```ruby
# Callbacks actualizados:
before_create :cerrar_anterior
after_create :encolar_procesamiento  # ← NUEVO

# ActiveStorage:
has_one_attached :excel_file

# Métodos:
- asignar_viajes_inteligente  # Asigna viajes + detecta rezagados
- crear_log_creacion          # Crea log inicial
- reasignar_viajes_rezagados  # Manual
- viajes_sin_asignar_en_rango # Detecta pendientes
```

### 3. **Worker: PayrollProcessWorker**

```ruby
# Queue: :payrolls
# Progreso:
10% - Inicio
30% - Asignar viajes
40% - Viajes asignados
50% - Log creado
70% - Generando Excel
90% - Excel generado
100% - Completado

# Genera Excel y lo adjunta con ActiveStorage
```

### 4. **Controller Actualizado**

```ruby
# GET /api/v1/payrolls
- Incluye: processing_status, progress, excel_generated, excel_url

# GET /api/v1/payrolls/:id
- Incluye: logs, progreso, URL del Excel

# POST /api/v1/payrolls
- Crea nómina
- Encola worker automáticamente
- Retorna status: pending

# GET /api/v1/payrolls/:id/download
- Redirige al Excel adjunto (ActiveStorage)
```

---

## 📝 **LO QUE FALTA (Frontend)**

### **Actualizar PayrollsPage.vue:**

1. **Agregar Polling**

```javascript
const pollingInterval = ref(null);

function startPolling(payrollId) {
  stopPolling();
  pollingInterval.value = setInterval(async () => {
    try {
      const res = await api.get(`/api/v1/payrolls/${payrollId}`);

      // Actualizar payroll en la lista
      const index = payrolls.value.findIndex((p) => p.id === payrollId);
      if (index !== -1) {
        payrolls.value[index] = res.data;
      }

      // Si completó o falló, detener polling
      if (
        res.data.processing_status === "completed" ||
        res.data.processing_status === "failed"
      ) {
        stopPolling();

        if (res.data.processing_status === "completed") {
          $q.notify({
            color: "positive",
            message: "¡Nómina procesada correctamente!",
            icon: "check_circle",
          });
        }
      }
    } catch (e) {
      stopPolling();
    }
  }, 2000); // Cada 2 segundos
}

function stopPolling() {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
}

onUnmounted(() => {
  stopPolling();
});
```

2. **Actualizar createPayroll**

```javascript
async function createPayroll() {
  creating.value = true;
  try {
    const res = await api.post("/api/v1/payrolls", {
      payroll: {
        descripcion: newPayroll.value.descripcion,
        fecha_inicio: newPayroll.value.fecha_inicio,
        hora_inicio: newPayroll.value.hora_inicio + ":00",
        fecha_fin_planificada: newPayroll.value.fecha_fin_planificada || null,
        hora_fin_planificada: newPayroll.value.hora_fin_planificada
          ? newPayroll.value.hora_fin_planificada + ":00"
          : null,
      },
    });

    $q.notify({
      color: "info",
      message: "Nómina creándose en segundo plano...",
      icon: "hourglass_empty",
    });

    showCreateDialog.value = false;

    // Iniciar polling
    startPolling(res.data.id);

    // Refrescar lista
    fetchPayrolls();
  } catch (e) {
    $q.notify({
      color: "negative",
      message: e.response?.data?.errors?.join(", ") || "Error al crear nómina",
      icon: "error",
    });
  } finally {
    creating.value = false;
  }
}
```

3. **Agregar Columna de Progreso en Tabla**

```vue
<template v-slot:body-cell-progress="props">
  <q-td :props="props">
    <div v-if="props.row.processing_status === 'processing'">
      <q-linear-progress
        :value="props.row.progress / 100"
        color="primary"
        size="20px"
      >
        <div class="absolute-full flex flex-center">
          <q-badge color="white" text-color="primary">
            {{ props.row.progress }}%
          </q-badge>
        </div>
      </q-linear-progress>
    </div>
    <div v-else-if="props.row.processing_status === 'completed'">
      <q-chip color="green" text-color="white" size="sm">
        <q-icon name="check" />
        Completado
      </q-chip>
    </div>
    <div v-else-if="props.row.processing_status === 'failed'">
      <q-chip color="red" text-color="white" size="sm">
        <q-icon name="error" />
        Error
      </q-chip>
    </div>
    <div v-else>
      <q-chip color="orange" text-color="white" size="sm">
        <q-icon name="hourglass_empty" />
        Pendiente
      </q-chip>
    </div>
  </q-td>
</template>
```

4. **Actualizar Columna de Acciones**

```vue
<template v-slot:body-cell-actions="props">
  <q-td :props="props">
    <!-- Botón Download solo si Excel está generado -->
    <q-btn
      v-if="props.row.excel_generated"
      flat
      round
      color="primary"
      icon="download"
      size="sm"
      @click="downloadExcel(props.row)"
    >
      <q-tooltip>Descargar Excel</q-tooltip>
    </q-btn>

    <!-- Spinner si está procesando -->
    <q-spinner
      v-else-if="props.row.processing_status === 'processing'"
      color="primary"
      size="sm"
    />

    <!-- Resto de botones... -->
  </q-td>
</template>
```

5. **Actualizar downloadExcel**

```javascript
function downloadExcel(payroll) {
  if (!payroll.excel_url) {
    $q.notify({
      color: "warning",
      message: "Excel no disponible aún",
      icon: "warning",
    });
    return;
  }

  window.open(payroll.excel_url, "_blank");

  $q.notify({
    color: "info",
    message: "Descargando reporte...",
    icon: "download",
  });
}
```

6. **Actualizar columns**

```javascript
const columns = [
  {
    name: "descripcion",
    label: "Descripción",
    field: "descripcion",
    align: "left",
    sortable: true,
  },
  { name: "periodo", label: "Período", align: "left" },
  { name: "viajes", label: "Viajes", align: "center" },
  { name: "progress", label: "Progreso", align: "center" }, // ← NUEVO
  { name: "status", label: "Estado", align: "center" },
  { name: "actions", label: "Acciones", align: "center" },
];
```

7. **Cards Móvil - Agregar Progreso**

```vue
<div v-if="payroll.processing_status === 'processing'" class="q-mb-sm">
  <div class="text-caption text-grey-7">Progreso</div>
  <q-linear-progress
    :value="payroll.progress / 100"
    color="primary"
    size="15px"
  >
    <div class="absolute-full flex flex-center">
      <q-badge color="white" text-color="primary" class="text-caption">
        {{ payroll.progress }}%
      </q-badge>
    </div>
  </q-linear-progress>
</div>
```

---

## 🎯 **FLUJO COMPLETO**

```
1. Usuario crea nómina
   ↓
2. Backend:
   - Crea registro (status: pending, progress: 0)
   - Cierra nómina anterior
   - Encola PayrollProcessWorker
   - Retorna inmediatamente
   ↓
3. Frontend:
   - Muestra "Creándose en segundo plano..."
   - Inicia polling cada 2 segundos
   - Muestra barra de progreso
   ↓
4. Worker (background):
   10% - Inicio
   30% - Asignando viajes
   40% - Viajes asignados
   50% - Log creado
   70% - Generando Excel
   90% - Excel generado
   100% - Completado
   ↓
5. Frontend (polling detecta 100%):
   - Detiene polling
   - Muestra notificación "¡Completado!"
   - Habilita botón "Descargar Excel"
   - Actualiza tabla
```

---

## ⚙️ **VERIFICAR**

```bash
# 1. Sidekiq corriendo
docker-compose ps sidekiq

# 2. Ver logs de Sidekiq
docker-compose logs -f sidekiq

# 3. Ver logs del worker
docker-compose logs app | grep PayrollProcessWorker
```

---

## 🚨 **IMPORTANTE**

- ✅ Sidekiq DEBE estar corriendo
- ✅ ActiveStorage configurado
- ✅ Queue `:payrolls` configurada en Sidekiq
- ✅ Frontend debe hacer polling para ver progreso
- ✅ No bloquea la UI durante procesamiento

**¿Quieres que actualice el frontend con el polling ahora?**
