# 📊 Acciones Especiales de Empleados - Plan de Implementación

## 🎯 Acciones Identificadas

### 1. **Cálculo de Aguinaldo**

- **Ubicación actual:** `EmployeesController#aguinaldo`
- **Helper:** `EmployeesHelper#calculo_aguinaldo`
- **Formato:** Excel (XLSX)
- **Descripción:** Calcula aguinaldo, vacaciones y prima vacacional para todos los empleados activos

### 2. **Consulta de Nómina**

- **Ubicación:** Por determinar (probablemente en `PayrollsController`)
- **Descripción:** Consulta de nómina de empleados

---

## 🏗️ Propuesta de Implementación

### Opción 1: Botones en la Tabla Principal (Recomendado)

Agregar botones de acción en el toolbar de EmployeesPage:

```vue
<template v-slot:top>
  <div class="row full-width items-center justify-between q-mb-md">
    <div class="text-h6 text-primary q-mr-md">Empleados</div>
    <div class="row q-gutter-sm items-center">
      <q-input
        dense
        outlined
        debounce="300"
        v-model="search"
        placeholder="Buscar..."
      />

      <!-- Botones de Acciones Especiales -->
      <q-btn-dropdown
        unelevated
        color="secondary"
        icon="functions"
        label="Reportes"
      >
        <q-list>
          <q-item clickable v-close-popup @click="calcularAguinaldo">
            <q-item-section avatar>
              <q-icon name="card_giftcard" />
            </q-item-section>
            <q-item-section>
              <q-item-label>Cálculo de Aguinaldo</q-item-label>
              <q-item-label caption>Generar reporte Excel</q-item-label>
            </q-item-section>
          </q-item>

          <q-item clickable v-close-popup @click="consultarNomina">
            <q-item-section avatar>
              <q-icon name="receipt_long" />
            </q-item-section>
            <q-item-section>
              <q-item-label>Consulta de Nómina</q-item-label>
              <q-item-label caption>Ver nómina actual</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-btn-dropdown>

      <q-btn
        unelevated
        color="primary"
        icon="add"
        label="Nuevo"
        @click="openDialog()"
      />
    </div>
  </div>
</template>
```

### Opción 2: Menú Contextual por Empleado

Agregar opciones en el menú de acciones de cada empleado:

```vue
<q-btn-dropdown flat round color="primary" icon="more_vert" size="sm">
  <q-list>
    <q-item clickable v-close-popup @click="openDialog(props.row)">
      <q-item-section avatar><q-icon name="edit" /></q-item-section>
      <q-item-section>Editar</q-item-section>
    </q-item>
    
    <q-separator />
    
    <q-item clickable v-close-popup @click="calcularAguinaldoIndividual(props.row)">
      <q-item-section avatar><q-icon name="card_giftcard" /></q-item-section>
      <q-item-section>Calcular Aguinaldo</q-item-section>
    </q-item>
    
    <q-item clickable v-close-popup @click="verNomina(props.row)">
      <q-item-section avatar><q-icon name="receipt_long" /></q-item-section>
      <q-item-section>Ver Nómina</q-item-section>
    </q-item>
    
    <q-separator />
    
    <q-item clickable v-close-popup @click="deleteEmployee(props.row)">
      <q-item-section avatar><q-icon name="delete" color="negative" /></q-item-section>
      <q-item-section>Eliminar</q-item-section>
    </q-item>
  </q-list>
</q-btn-dropdown>
```

---

## 🔧 Backend - Endpoints Necesarios

### 1. Aguinaldo

```ruby
# app/controllers/api/v1/employees_controller.rb

# GET /api/v1/employees/aguinaldo
def aguinaldo
  authorize! :read, Employee

  @aguinaldo_data = calculo_aguinaldo

  respond_to do |format|
    format.json { render json: @aguinaldo_data }
    format.xlsx {
      # Generar Excel
      send_data generate_aguinaldo_xlsx(@aguinaldo_data),
        filename: "aguinaldo_#{Date.today}.xlsx",
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    }
  end
end

# GET /api/v1/employees/:id/aguinaldo
def aguinaldo_individual
  authorize! :read, @employee

  @aguinaldo_data = calculo_aguinaldo_individual(@employee)

  render json: @aguinaldo_data
end

private

def calculo_aguinaldo
  # Lógica del helper actual
  sql = "..." # Query SQL del helper
  ActiveRecord::Base.connection.exec_query(sql).to_a.map(&:to_h)
end

def calculo_aguinaldo_individual(employee)
  # Versión individual del cálculo
  # ...
end
```

### 2. Nómina

```ruby
# app/controllers/api/v1/payrolls_controller.rb

# GET /api/v1/payrolls
def index
  @payrolls = Payroll
    .includes(:employee)
    .where(business_unit_id: current_business_unit_id)
    .order(created_at: :desc)

  render json: @payrolls
end

# GET /api/v1/employees/:id/payrolls
def employee_payrolls
  @employee = Employee.find(params[:id])
  @payrolls = @employee.payrolls.order(created_at: :desc)

  render json: @payrolls
end
```

---

## 📱 Frontend - Implementación

### Métodos en EmployeesPage.vue

```javascript
// Aguinaldo para todos
async function calcularAguinaldo() {
  $q.loading.show({ message: "Calculando aguinaldo..." });
  try {
    const res = await api.get("/api/v1/employees/aguinaldo");

    // Mostrar dialog con resultados
    aguinaldoDialog.value = true;
    aguinaldoData.value = res.data;

    $q.notify({
      color: "positive",
      message: "Aguinaldo calculado correctamente",
      icon: "check",
    });
  } catch (e) {
    $q.notify({
      color: "negative",
      message: "Error al calcular aguinaldo",
    });
  } finally {
    $q.loading.hide();
  }
}

// Descargar Excel
async function descargarAguinaldoExcel() {
  try {
    const res = await api.get("/api/v1/employees/aguinaldo.xlsx", {
      responseType: "blob",
    });

    // Crear link de descarga
    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute(
      "download",
      `aguinaldo_${new Date().toISOString().split("T")[0]}.xlsx`
    );
    document.body.appendChild(link);
    link.click();
    link.remove();

    $q.notify({
      color: "positive",
      message: "Excel descargado",
      icon: "download",
    });
  } catch (e) {
    $q.notify({
      color: "negative",
      message: "Error al descargar Excel",
    });
  }
}

// Nómina
async function consultarNomina() {
  router.push("/payrolls");
}
```

### Dialog de Resultados de Aguinaldo

```vue
<q-dialog v-model="aguinaldoDialog" maximized>
  <q-card>
    <q-toolbar class="bg-primary text-white">
      <q-toolbar-title>Cálculo de Aguinaldo {{ new Date().getFullYear() }}</q-toolbar-title>
      <q-btn flat round dense icon="download" @click="descargarAguinaldoExcel">
        <q-tooltip>Descargar Excel</q-tooltip>
      </q-btn>
      <q-btn flat round dense icon="close" v-close-popup />
    </q-toolbar>
    
    <q-card-section>
      <q-table
        :rows="aguinaldoData"
        :columns="aguinaldoColumns"
        row-key="clv"
        flat
        bordered
      >
        <template v-slot:body-cell-aguinaldo="props">
          <q-td :props="props">
            <div class="text-weight-bold text-positive">
              ${{ props.row.aguinaldo.toLocaleString('es-MX', { minimumFractionDigits: 2 }) }}
            </div>
          </q-td>
        </template>
      </q-table>
    </q-card-section>
  </q-card>
</q-dialog>
```

---

## 📊 Columnas para Tabla de Aguinaldo

```javascript
const aguinaldoColumns = [
  {
    name: "clv",
    label: "# Empleado",
    field: "clv",
    align: "left",
    sortable: true,
  },
  {
    name: "nombre_completo",
    label: "Nombre",
    field: (row) => `${row.nombre} ${row.apaterno} ${row.amaterno}`,
    align: "left",
    sortable: true,
  },
  {
    name: "puesto",
    label: "Puesto",
    field: "puesto",
    align: "left",
    sortable: true,
  },
  {
    name: "fecha_efectiva",
    label: "Fecha Ingreso",
    field: "fecha_efectiva",
    align: "center",
    sortable: true,
  },
  {
    name: "periodo",
    label: "Años",
    field: "periodo",
    align: "center",
    sortable: true,
  },
  {
    name: "dias_aguinaldo",
    label: "Días",
    field: "dias_aguinaldo",
    align: "center",
    sortable: true,
  },
  {
    name: "sd",
    label: "Salario Diario",
    field: "sd",
    align: "right",
    sortable: true,
    format: (val) => `$${val.toFixed(2)}`,
  },
  {
    name: "aguinaldo",
    label: "Aguinaldo",
    field: "aguinaldo",
    align: "right",
    sortable: true,
    format: (val) => `$${val.toFixed(2)}`,
  },
  {
    name: "dvaccrrp",
    label: "Días Vac.",
    field: "dvaccrrp",
    align: "center",
    sortable: true,
  },
  {
    name: "pago_vac",
    label: "Pago Vac.",
    field: "pago_vac",
    align: "right",
    sortable: true,
    format: (val) => `$${val.toFixed(2)}`,
  },
  {
    name: "prima_vac",
    label: "Prima Vac.",
    field: "prima_vac",
    align: "right",
    sortable: true,
    format: (val) => `$${val.toFixed(2)}`,
  },
];
```

---

## 🎯 Recomendación Final

**Implementar Opción 1** (Botones en toolbar) porque:

1. ✅ Más visible y accesible
2. ✅ Acciones que aplican a todos los empleados
3. ✅ Mejor UX para reportes masivos
4. ✅ Consistente con el patrón de la aplicación

**Próximos pasos:**

1. Crear endpoint `/api/v1/employees/aguinaldo` en el backend
2. Agregar botón dropdown "Reportes" en EmployeesPage
3. Implementar dialog de resultados
4. Agregar funcionalidad de descarga Excel
5. Crear página de Nómina (si no existe)

---

**¿Quieres que implemente alguna de estas opciones?** 🚀
