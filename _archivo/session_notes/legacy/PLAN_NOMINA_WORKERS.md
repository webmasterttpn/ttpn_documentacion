# 📊 Sistema de Nómina con Workers y Polling - Plan de Implementación

## 🎯 Requerimientos

### Funcionalidad

1. **Filtros personalizados de fecha/hora**

   - Fecha inicio + hora
   - Fecha fin + hora
   - Ejemplo: "Jueves 18 a las 13:30 hasta Miércoles 24 a las 12:00"

2. **Procesamiento en background**

   - Worker de Sidekiq para cálculos pesados
   - Generación de Excel con caxlsx
   - Almacenamiento temporal del archivo

3. **Sistema de polling**
   - Frontend consulta estado cada X segundos
   - Muestra progreso del reporte
   - Descarga automática cuando esté listo

---

## 🏗️ Arquitectura

```
┌─────────────┐
│  Frontend   │
│             │
│ 1. Usuario  │
│    selecciona│
│    rango     │
└──────┬──────┘
       │ POST /api/v1/payrolls/generate
       ▼
┌─────────────────┐
│   Backend       │
│                 │
│ 2. Crea Job     │
│    en Sidekiq   │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  Sidekiq Worker │
│                 │
│ 3. Calcula      │
│    nómina       │
│ 4. Genera Excel │
│ 5. Guarda en    │
│    ActiveStorage│
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│   Frontend      │
│                 │
│ 6. Polling cada │
│    3 segundos   │
│ 7. Descarga     │
│    cuando listo │
└─────────────────┘
```

---

## 📝 Backend - Implementación

### 1. Modelo: PayrollReport

```ruby
# app/models/payroll_report.rb
class PayrollReport < ApplicationRecord
  belongs_to :user
  belongs_to :business_unit

  has_one_attached :excel_file

  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :start_datetime, :end_datetime, presence: true
  validate :end_after_start

  def end_after_start
    return if end_datetime.blank? || start_datetime.blank?

    if end_datetime < start_datetime
      errors.add(:end_datetime, "debe ser posterior a la fecha de inicio")
    end
  end

  def duration_hours
    ((end_datetime - start_datetime) / 1.hour).round(2)
  end

  def file_url
    return nil unless excel_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(excel_file, only_path: true)
  end
end
```

### 2. Migración

```ruby
# db/migrate/20241219_create_payroll_reports.rb
class CreatePayrollReports < ActiveRecord::Migration[7.0]
  def change
    create_table :payroll_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :business_unit, foreign_key: true

      t.datetime :start_datetime, null: false
      t.datetime :end_datetime, null: false
      t.integer :status, default: 0, null: false

      t.integer :total_employees, default: 0
      t.integer :total_trips, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0

      t.text :error_message
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :payroll_reports, :status
    add_index :payroll_reports, :created_at
  end
end
```

### 3. Worker: PayrollReportWorker

```ruby
# app/workers/payroll_report_worker.rb
class PayrollReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :reports, retry: 3

  def perform(payroll_report_id)
    report = PayrollReport.find(payroll_report_id)
    report.update!(status: :processing)

    begin
      # 1. Calcular nómina
      payroll_data = calculate_payroll(report)

      # 2. Generar Excel
      excel_data = generate_excel(payroll_data, report)

      # 3. Guardar archivo
      report.excel_file.attach(
        io: StringIO.new(excel_data),
        filename: "nomina_#{report.start_datetime.strftime('%Y%m%d')}_#{report.end_datetime.strftime('%Y%m%d')}.xlsx",
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )

      # 4. Actualizar estadísticas
      report.update!(
        status: :completed,
        total_employees: payroll_data[:employees].count,
        total_trips: payroll_data[:total_trips],
        total_amount: payroll_data[:total_amount]
      )

    rescue StandardError => e
      report.update!(
        status: :failed,
        error_message: e.message
      )
      raise e
    end
  end

  private

  def calculate_payroll(report)
    # Query para obtener viajes en el rango de fecha/hora
    sql = <<-SQL
      SELECT
        e.id as employee_id,
        e.clv,
        e.nombre,
        e.apaterno,
        e.amaterno,
        COUNT(t.id) as total_trips,
        SUM(t.amount) as total_amount,
        -- Aquí va tu lógica de cálculo de nómina
        -- basada en viajes, tarifas, bonos, etc.
      FROM employees e
      LEFT JOIN trips t ON t.employee_id = e.id
        AND t.created_at BETWEEN :start_datetime AND :end_datetime
      WHERE e.business_unit_id = :business_unit_id
        AND e.status = true
      GROUP BY e.id, e.clv, e.nombre, e.apaterno, e.amaterno
      ORDER BY e.nombre, e.apaterno
    SQL

    employees = ActiveRecord::Base.connection.exec_query(
      sql,
      'Payroll Calculation',
      {
        start_datetime: report.start_datetime,
        end_datetime: report.end_datetime,
        business_unit_id: report.business_unit_id
      }
    ).to_a.map(&:symbolize_keys)

    total_trips = employees.sum { |e| e[:total_trips] }
    total_amount = employees.sum { |e| e[:total_amount].to_f }

    {
      employees: employees,
      total_trips: total_trips,
      total_amount: total_amount,
      start_datetime: report.start_datetime,
      end_datetime: report.end_datetime
    }
  end

  def generate_excel(payroll_data, report)
    package = Axlsx::Package.new
    workbook = package.workbook

    # Estilos
    header_style = workbook.styles.add_style(
      bg_color: '0066CC',
      fg_color: 'FFFFFF',
      b: true,
      alignment: { horizontal: :center }
    )

    currency_style = workbook.styles.add_style(
      format_code: '$#,##0.00'
    )

    # Hoja principal
    workbook.add_worksheet(name: 'Nómina') do |sheet|
      # Título
      sheet.add_row ['REPORTE DE NÓMINA']
      sheet.add_row ["Período: #{report.start_datetime.strftime('%d/%m/%Y %H:%M')} - #{report.end_datetime.strftime('%d/%m/%Y %H:%M')}"]
      sheet.add_row []

      # Headers
      sheet.add_row [
        '# Empleado',
        'Nombre',
        'Total Viajes',
        'Monto Total'
      ], style: header_style

      # Datos
      payroll_data[:employees].each do |emp|
        sheet.add_row [
          emp[:clv],
          "#{emp[:nombre]} #{emp[:apaterno]} #{emp[:amaterno]}",
          emp[:total_trips],
          emp[:total_amount].to_f
        ], style: [nil, nil, nil, currency_style]
      end

      # Totales
      sheet.add_row []
      sheet.add_row [
        'TOTALES',
        '',
        payroll_data[:total_trips],
        payroll_data[:total_amount]
      ], style: [header_style, nil, header_style, currency_style]
    end

    package.to_stream.read
  end
end
```

### 4. Controller: PayrollReportsController

```ruby
# app/controllers/api/v1/payroll_reports_controller.rb
class Api::V1::PayrollReportsController < Api::V1::BaseController
  before_action :set_report, only: [:show, :download]

  # POST /api/v1/payroll_reports
  def create
    @report = PayrollReport.new(report_params)
    @report.user = current_user
    @report.business_unit_id = current_user.business_unit_id
    @report.status = :pending

    if @report.save
      # Encolar worker
      PayrollReportWorker.perform_async(@report.id)

      render json: {
        id: @report.id,
        status: @report.status,
        message: 'Reporte en cola para procesamiento'
      }, status: :created
    else
      render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/payroll_reports
  def index
    @reports = PayrollReport
      .where(business_unit_id: current_user.business_unit_id)
      .order(created_at: :desc)
      .limit(50)

    render json: @reports.map { |r|
      {
        id: r.id,
        start_datetime: r.start_datetime,
        end_datetime: r.end_datetime,
        status: r.status,
        total_employees: r.total_employees,
        total_trips: r.total_trips,
        total_amount: r.total_amount,
        file_url: r.file_url,
        created_at: r.created_at,
        error_message: r.error_message
      }
    }
  end

  # GET /api/v1/payroll_reports/:id
  def show
    render json: {
      id: @report.id,
      start_datetime: @report.start_datetime,
      end_datetime: @report.end_datetime,
      status: @report.status,
      total_employees: @report.total_employees,
      total_trips: @report.total_trips,
      total_amount: @report.total_amount,
      duration_hours: @report.duration_hours,
      file_url: @report.file_url,
      created_at: @report.created_at,
      updated_at: @report.updated_at,
      error_message: @report.error_message
    }
  end

  # GET /api/v1/payroll_reports/:id/download
  def download
    if @report.completed? && @report.excel_file.attached?
      redirect_to rails_blob_url(@report.excel_file, disposition: 'attachment')
    else
      render json: { error: 'Reporte no disponible' }, status: :not_found
    end
  end

  private

  def set_report
    @report = PayrollReport.find(params[:id])
    authorize! :read, @report
  end

  def report_params
    params.require(:payroll_report).permit(:start_datetime, :end_datetime)
  end
end
```

### 5. Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :payroll_reports, only: [:index, :create, :show] do
      member do
        get :download
      end
    end
  end
end
```

---

## 📱 Frontend - Implementación

### EmployeesPayrollPage.vue (Actualizado)

```vue
<template>
  <q-page class="q-pa-md">
    <q-card>
      <q-card-section class="bg-primary text-white">
        <div class="text-h5">Consulta de Nómina</div>
        <div class="text-caption">
          Genera reportes de nómina por rango de fecha/hora
        </div>
      </q-card-section>

      <q-card-section>
        <!-- Formulario de Rango -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="startDate"
              label="Fecha Inicio"
              type="date"
              stack-label
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="startTime"
              label="Hora Inicio"
              type="time"
              stack-label
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="endDate"
              label="Fecha Fin"
              type="date"
              stack-label
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="endTime"
              label="Hora Fin"
              type="time"
              stack-label
            />
          </div>
        </div>

        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-12">
            <q-btn
              unelevated
              color="primary"
              icon="play_arrow"
              label="Generar Reporte"
              @click="generateReport"
              :loading="generating"
              :disable="!isValidRange"
            />
            <q-btn
              flat
              color="grey-7"
              icon="refresh"
              label="Refrescar Lista"
              @click="fetchReports"
              class="q-ml-sm"
            />
          </div>
        </div>

        <!-- Reporte en Progreso -->
        <q-card v-if="currentReport" flat bordered class="q-mb-md">
          <q-card-section>
            <div class="row items-center">
              <div class="col">
                <div class="text-subtitle2">Reporte en Proceso</div>
                <div class="text-caption text-grey-7">
                  {{ formatDateTime(currentReport.start_datetime) }} -
                  {{ formatDateTime(currentReport.end_datetime) }}
                </div>
              </div>
              <div class="col-auto">
                <q-chip
                  :color="statusColor(currentReport.status)"
                  text-color="white"
                >
                  {{ statusLabel(currentReport.status) }}
                </q-chip>
              </div>
            </div>
            <q-linear-progress
              v-if="currentReport.status === 'processing'"
              indeterminate
              color="primary"
              class="q-mt-sm"
            />
            <div v-if="currentReport.status === 'completed'" class="q-mt-sm">
              <q-btn
                unelevated
                color="positive"
                icon="download"
                label="Descargar Excel"
                @click="downloadReport(currentReport)"
              />
            </div>
            <div
              v-if="currentReport.status === 'failed'"
              class="q-mt-sm text-negative"
            >
              Error: {{ currentReport.error_message }}
            </div>
          </q-card-section>
        </q-card>

        <!-- Historial de Reportes -->
        <q-table
          title="Historial de Reportes"
          :rows="reports"
          :columns="columns"
          row-key="id"
          :loading="loading"
          flat
          bordered
        >
          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <q-chip
                :color="statusColor(props.row.status)"
                text-color="white"
                size="sm"
              >
                {{ statusLabel(props.row.status) }}
              </q-chip>
            </q-td>
          </template>

          <template v-slot:body-cell-actions="props">
            <q-td :props="props" auto-width>
              <q-btn
                v-if="props.row.status === 'completed'"
                flat
                round
                color="primary"
                icon="download"
                size="sm"
                @click="downloadReport(props.row)"
              >
                <q-tooltip>Descargar</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue";
import { api } from "boot/axios";
import { useQuasar } from "quasar";

const $q = useQuasar();

const reports = ref([]);
const currentReport = ref(null);
const loading = ref(false);
const generating = ref(false);
const pollingInterval = ref(null);

// Formulario
const startDate = ref("");
const startTime = ref("00:00");
const endDate = ref("");
const endTime = ref("23:59");

const columns = [
  { name: "id", label: "ID", field: "id", align: "left", sortable: true },
  {
    name: "period",
    label: "Período",
    field: (row) =>
      `${formatDateTime(row.start_datetime)} - ${formatDateTime(
        row.end_datetime
      )}`,
    align: "left",
  },
  { name: "status", label: "Estado", field: "status", align: "center" },
  {
    name: "employees",
    label: "Empleados",
    field: "total_employees",
    align: "center",
  },
  { name: "trips", label: "Viajes", field: "total_trips", align: "center" },
  {
    name: "amount",
    label: "Total",
    field: "total_amount",
    align: "right",
    format: (val) => `$${Number(val || 0).toFixed(2)}`,
  },
  {
    name: "created",
    label: "Creado",
    field: "created_at",
    align: "center",
    format: (val) => new Date(val).toLocaleString("es-MX"),
  },
  { name: "actions", label: "Acciones", align: "center" },
];

const isValidRange = computed(() => {
  if (!startDate.value || !endDate.value) return false;
  const start = new Date(`${startDate.value}T${startTime.value}`);
  const end = new Date(`${endDate.value}T${endTime.value}`);
  return end > start;
});

function formatDateTime(datetime) {
  return new Date(datetime).toLocaleString("es-MX", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function statusColor(status) {
  const colors = {
    pending: "orange",
    processing: "blue",
    completed: "green",
    failed: "red",
  };
  return colors[status] || "grey";
}

function statusLabel(status) {
  const labels = {
    pending: "Pendiente",
    processing: "Procesando",
    completed: "Completado",
    failed: "Error",
  };
  return labels[status] || status;
}

async function generateReport() {
  generating.value = true;
  try {
    const res = await api.post("/api/v1/payroll_reports", {
      payroll_report: {
        start_datetime: `${startDate.value}T${startTime.value}:00`,
        end_datetime: `${endDate.value}T${endTime.value}:00`,
      },
    });

    currentReport.value = res.data;
    startPolling(res.data.id);

    $q.notify({
      color: "positive",
      message: "Reporte generándose en segundo plano",
      icon: "check",
    });
  } catch (e) {
    console.error(e);
    $q.notify({
      color: "negative",
      message:
        e.response?.data?.errors?.join(", ") || "Error al generar reporte",
    });
  } finally {
    generating.value = false;
  }
}

async function fetchReports() {
  loading.value = true;
  try {
    const res = await api.get("/api/v1/payroll_reports");
    reports.value = res.data;
  } catch (e) {
    console.error(e);
  } finally {
    loading.value = false;
  }
}

function startPolling(reportId) {
  stopPolling();
  pollingInterval.value = setInterval(async () => {
    try {
      const res = await api.get(`/api/v1/payroll_reports/${reportId}`);
      currentReport.value = res.data;

      if (res.data.status === "completed" || res.data.status === "failed") {
        stopPolling();
        fetchReports();

        if (res.data.status === "completed") {
          $q.notify({
            color: "positive",
            message: "Reporte completado. ¡Listo para descargar!",
            icon: "check_circle",
          });
        }
      }
    } catch (e) {
      console.error("Polling error:", e);
      stopPolling();
    }
  }, 3000); // Cada 3 segundos
}

function stopPolling() {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
}

async function downloadReport(report) {
  try {
    const res = await api.get(`/api/v1/payroll_reports/${report.id}/download`, {
      responseType: "blob",
    });

    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", `nomina_${report.id}.xlsx`);
    document.body.appendChild(link);
    link.click();
    link.remove();

    $q.notify({
      color: "positive",
      message: "Reporte descargado",
      icon: "download",
    });
  } catch (e) {
    console.error(e);
    $q.notify({
      color: "negative",
      message: "Error al descargar reporte",
    });
  }
}

onMounted(() => {
  fetchReports();

  // Valores por defecto: última semana
  const now = new Date();
  const lastWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  startDate.value = lastWeek.toISOString().split("T")[0];
  endDate.value = now.toISOString().split("T")[0];
});

onUnmounted(() => {
  stopPolling();
});
</script>
```

---

## 🎯 Flujo Completo

1. **Usuario selecciona rango:** Jueves 18 13:30 - Miércoles 24 12:00
2. **Click "Generar Reporte":** POST a `/api/v1/payroll_reports`
3. **Backend crea registro:** Status = `pending`
4. **Sidekiq Worker inicia:** Status = `processing`
5. **Frontend hace polling:** Cada 3 segundos consulta estado
6. **Worker termina:** Genera Excel, guarda en ActiveStorage, Status = `completed`
7. **Frontend detecta:** Muestra botón "Descargar"
8. **Usuario descarga:** GET `/api/v1/payroll_reports/:id/download`

---

## ✅ Checklist de Implementación

### Backend

- [ ] Crear migración `PayrollReport`
- [ ] Crear modelo `PayrollReport`
- [ ] Crear worker `PayrollReportWorker`
- [ ] Crear controller `PayrollReportsController`
- [ ] Agregar rutas
- [ ] Configurar Sidekiq queue `:reports`

### Frontend

- [ ] Actualizar `EmployeesPayrollPage.vue`
- [ ] Implementar formulario de fecha/hora
- [ ] Implementar polling
- [ ] Implementar descarga

---

**¿Quieres que empiece a implementar esto?** 🚀
