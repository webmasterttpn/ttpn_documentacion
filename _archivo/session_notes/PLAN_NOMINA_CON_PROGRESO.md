# 📊 Sistema de Consulta de Nómina con Workers y Progreso - IMPLEMENTACIÓN FINAL

## 🎯 Objetivo

Implementar sistema robusto de consulta de nómina que:

- Procesa reportes grandes (hasta 1 año) en background
- Muestra progreso en tiempo real
- Genera Excel sin bloquear la UI
- Usa polling para actualizar estado

---

## 📝 Archivos a Crear/Modificar

### 1. Migración

**`db/migrate/XXXXXX_create_payroll_reports.rb`**

```ruby
class CreatePayrollReports < ActiveRecord::Migration[7.1]
  def change
    create_table :payroll_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :start_datetime, null: false
      t.datetime :end_datetime, null: false
      t.integer :status, default: 0, null: false
      t.integer :progress, default: 0
      t.integer :total_employees, default: 0
      t.integer :total_trips, default: 0
      t.decimal :total_amount, precision: 12, scale: 2, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :payroll_reports, :status
    add_index :payroll_reports, :user_id
  end
end
```

### 2. Modelo

**`app/models/payroll_report.rb`**

```ruby
class PayrollReport < ApplicationRecord
  belongs_to :user
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

  def duration_days
    ((end_datetime - start_datetime) / 1.day).round(2)
  end

  def file_url
    return nil unless excel_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(excel_file, only_path: true)
  end
end
```

### 3. Worker

**`app/workers/payroll_report_worker.rb`**

```ruby
class PayrollReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :reports, retry: 3

  def perform(report_id)
    report = PayrollReport.find(report_id)
    report.update!(status: :processing, progress: 0)

    begin
      # 1. Calcular datos (10% progreso)
      report.update!(progress: 10)
      data = calculate_payroll_data(report)

      # 2. Generar Excel (50% progreso)
      report.update!(progress: 50)
      excel_data = generate_excel(data, report)

      # 3. Guardar archivo (80% progreso)
      report.update!(progress: 80)
      report.excel_file.attach(
        io: StringIO.new(excel_data),
        filename: "consulta_nomina_#{report.start_datetime.strftime('%Y%m%d')}_#{report.end_datetime.strftime('%Y%m%d')}.xlsx",
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )

      # 4. Completado (100%)
      report.update!(
        status: :completed,
        progress: 100,
        total_employees: data[:total_employees],
        total_trips: data[:total_trips],
        total_amount: data[:total_amount]
      )

    rescue StandardError => e
      report.update!(
        status: :failed,
        error_message: e.message,
        progress: 0
      )
      raise e
    end
  end

  private

  def calculate_payroll_data(report)
    inicio_timestamp = "#{report.start_datetime.to_date} #{report.start_datetime.strftime('%H:%M:%S')}"
    fin_timestamp = "#{report.end_datetime.to_date} #{report.end_datetime.strftime('%H:%M:%S')}"

    resultados = Employee
      .joins(:labor, :travel_counts)
      .where(
        labors: { nombre: ['Chofer', 'Coordinador'] },
        travel_counts: { status: true }
      )
      .where("employees.clv != ?", '00000')
      .where(
        "travel_counts.fecha + travel_counts.hora BETWEEN ? AND ?",
        inicio_timestamp,
        fin_timestamp
      )
      .select(
        "employees.id",
        "employees.clv",
        "employees.nombre",
        "employees.apaterno",
        "labors.nombre as puesto",
        "ROUND(SUM(travel_counts.costo)::numeric, 2) as cost_viajes",
        "COUNT(travel_counts.id) as cont_viajes",
        "(SELECT COALESCE(SUM(employee_deductions.monto_semanal), 0)
          FROM employee_deductions
          WHERE employee_deductions.employee_id = employees.id
          AND employee_deductions.is_active = true
          AND (employee_deductions.fecha_inicio <= '#{fin_timestamp}')
          AND (employee_deductions.fecha_fin IS NULL
               OR employee_deductions.fecha_fin >= '#{fin_timestamp}')
         ) as deducciones"
      )
      .group("employees.id, employees.clv, employees.nombre, employees.apaterno, labors.nombre")
      .order("employees.nombre, employees.apaterno")
      .to_a

    {
      resultados: resultados,
      total_employees: resultados.count,
      total_trips: resultados.sum { |r| r.cont_viajes.to_i },
      total_amount: resultados.sum { |r| r.cost_viajes.to_f }
    }
  end

  def generate_excel(data, report)
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: 'Consulta Nómina') do |sheet|
      # Título
      sheet.add_row ["CONSULTA DE NÓMINA"]
      sheet.add_row ["Período: #{report.start_datetime.strftime('%d/%m/%Y %H:%M')} - #{report.end_datetime.strftime('%d/%m/%Y %H:%M')}"]
      sheet.add_row []

      # Headers
      sheet.add_row [
        '# Empleado',
        'Nombre',
        'Puesto',
        'Viajes',
        'Monto Bruto',
        'Deducciones',
        'Monto Neto'
      ]

      # Datos
      total_viajes = 0
      total_bruto = 0
      total_deducciones = 0

      data[:resultados].each do |r|
        monto_bruto = r.cost_viajes.to_f
        deducciones = r.deducciones.to_f
        monto_neto = monto_bruto - deducciones

        sheet.add_row [
          r.clv,
          "#{r.nombre} #{r.apaterno}",
          r.puesto,
          r.cont_viajes.to_i,
          monto_bruto,
          deducciones,
          monto_neto
        ]

        total_viajes += r.cont_viajes.to_i
        total_bruto += monto_bruto
        total_deducciones += deducciones
      end

      # Totales
      sheet.add_row []
      sheet.add_row [
        'TOTALES',
        '',
        '',
        total_viajes,
        total_bruto,
        total_deducciones,
        total_bruto - total_deducciones
      ]
    end

    package.to_stream.read
  end
end
```

### 4. Controller Actualizado

**`app/controllers/api/v1/payroll_reports_controller.rb`**

```ruby
class Api::V1::PayrollReportsController < Api::V1::BaseController

  # POST /api/v1/payroll_reports
  def create
    @report = PayrollReport.new(
      user: current_user,
      start_datetime: params[:start_datetime],
      end_datetime: params[:end_datetime],
      status: :pending
    )

    if @report.save
      # Encolar worker
      PayrollReportWorker.perform_async(@report.id)

      render json: {
        id: @report.id,
        status: @report.status,
        progress: @report.progress,
        message: 'Reporte en cola para procesamiento'
      }, status: :created
    else
      render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/payroll_reports/:id
  def show
    @report = PayrollReport.find(params[:id])
    authorize! :read, @report

    render json: {
      id: @report.id,
      start_datetime: @report.start_datetime,
      end_datetime: @report.end_datetime,
      status: @report.status,
      progress: @report.progress,
      total_employees: @report.total_employees,
      total_trips: @report.total_trips,
      total_amount: @report.total_amount,
      duration_days: @report.duration_days,
      file_url: @report.file_url,
      error_message: @report.error_message,
      created_at: @report.created_at,
      updated_at: @report.updated_at
    }
  end

  # GET /api/v1/payroll_reports
  def index
    @reports = PayrollReport
      .where(user: current_user)
      .order(created_at: :desc)
      .limit(20)

    render json: @reports.map { |r|
      {
        id: r.id,
        start_datetime: r.start_datetime,
        end_datetime: r.end_datetime,
        status: r.status,
        progress: r.progress,
        total_employees: r.total_employees,
        total_trips: r.total_trips,
        total_amount: r.total_amount,
        file_url: r.file_url,
        created_at: r.created_at
      }
    }
  end

  # GET /api/v1/payroll_reports/:id/download
  def download
    @report = PayrollReport.find(params[:id])
    authorize! :read, @report

    unless @report.completed? && @report.excel_file.attached?
      render json: { error: 'Reporte no disponible' }, status: :not_found
      return
    end

    redirect_to rails_blob_url(@report.excel_file, disposition: 'attachment')
  end
end
```

### 5. Rutas

**`config/routes.rb`** (actualizar)

```ruby
# Consulta de Nómina (con workers y progreso)
resources :payroll_reports, only: [:index, :create, :show] do
  member do
    get :download
  end
end
```

### 6. Frontend con Progreso

**`src/pages/EmployeesPayrollPage.vue`**

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
        <!-- Formulario -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="startDate"
              label="Fecha Inicio *"
              type="date"
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="startTime"
              label="Hora Inicio *"
              type="time"
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="endDate"
              label="Fecha Fin *"
              type="date"
            />
          </div>
          <div class="col-12 col-md-3">
            <q-input
              dense
              outlined
              v-model="endTime"
              label="Hora Fin *"
              type="time"
            />
          </div>
        </div>

        <div class="row q-mb-md">
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
          </div>
        </div>

        <!-- Reporte en Progreso -->
        <q-card
          v-if="currentReport"
          flat
          bordered
          class="q-mb-md"
          :class="
            currentReport.status === 'completed' ? 'bg-green-1' : 'bg-blue-1'
          "
        >
          <q-card-section>
            <div class="text-subtitle2">
              {{
                currentReport.status === "completed"
                  ? "✅ Reporte Completado"
                  : "⏳ Generando Reporte"
              }}
            </div>
            <div class="text-caption text-grey-7">
              {{ formatDateTime(currentReport.start_datetime) }} -
              {{ formatDateTime(currentReport.end_datetime) }}
            </div>

            <!-- Barra de Progreso -->
            <q-linear-progress
              v-if="currentReport.status === 'processing'"
              :value="currentReport.progress / 100"
              color="primary"
              class="q-mt-md"
              size="20px"
            >
              <div class="absolute-full flex flex-center">
                <q-badge
                  color="white"
                  text-color="primary"
                  :label="`${currentReport.progress}%`"
                />
              </div>
            </q-linear-progress>

            <!-- Estadísticas cuando completa -->
            <div v-if="currentReport.status === 'completed'" class="q-mt-md">
              <div class="row q-col-gutter-sm q-mb-sm">
                <div class="col-auto">
                  <q-chip color="blue" text-color="white">
                    {{ currentReport.total_employees }} empleados
                  </q-chip>
                </div>
                <div class="col-auto">
                  <q-chip color="purple" text-color="white">
                    {{ currentReport.total_trips }} viajes
                  </q-chip>
                </div>
                <div class="col-auto">
                  <q-chip color="green" text-color="white">
                    ${{
                      Number(currentReport.total_amount || 0).toLocaleString(
                        "es-MX"
                      )
                    }}
                  </q-chip>
                </div>
              </div>
              <q-btn
                unelevated
                color="positive"
                icon="download"
                label="Descargar Excel"
                @click="downloadReport(currentReport)"
              />
            </div>
          </q-card-section>
        </q-card>

        <!-- Historial -->
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
              <q-linear-progress
                v-if="props.row.status === 'processing'"
                :value="props.row.progress / 100"
                color="primary"
                class="q-mt-xs"
              />
            </q-td>
          </template>

          <template v-slot:body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                v-if="props.row.status === 'completed'"
                flat
                round
                color="primary"
                icon="download"
                size="sm"
                @click="downloadReport(props.row)"
              />
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

const startDate = ref("");
const startTime = ref("01:30");
const endDate = ref("");
const endTime = ref("01:30");

const columns = [
  { name: "id", label: "ID", field: "id", align: "left" },
  {
    name: "period",
    label: "Período",
    field: (row) =>
      `${formatDateTime(row.start_datetime)} - ${formatDateTime(
        row.end_datetime
      )}`,
    align: "left",
  },
  { name: "status", label: "Estado", align: "center" },
  {
    name: "stats",
    label: "Estadísticas",
    field: (row) => `${row.total_employees} emp, ${row.total_trips} viajes`,
    align: "center",
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
      start_datetime: `${startDate.value}T${startTime.value}:00`,
      end_datetime: `${endDate.value}T${endTime.value}:00`,
    });

    currentReport.value = res.data;
    startPolling(res.data.id);

    $q.notify({
      color: "positive",
      message: "Reporte generándose en segundo plano",
      icon: "check",
    });
  } catch (e) {
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
            message: "¡Reporte completado!",
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

function downloadReport(report) {
  window.open(`/api/v1/payroll_reports/${report.id}/download`, "_blank");
}

onMounted(() => {
  fetchReports();
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

## ✅ Checklist de Implementación

- [ ] Correr migración
- [ ] Actualizar modelo PayrollReport
- [ ] Crear worker PayrollReportWorker
- [ ] Actualizar controller
- [ ] Actualizar rutas
- [ ] Actualizar frontend
- [ ] Reiniciar servidor
- [ ] Verificar Sidekiq corriendo

---

## 🚀 Comandos

```bash
# 1. Migración
docker-compose exec app rails db:migrate

# 2. Reiniciar
docker-compose restart app

# 3. Verificar Sidekiq
docker-compose ps sidekiq
```

---

**¿Procedo con la implementación completa?** 🎯
