# Dominio: Finanzas

Nómina de choferes y personal, salarios, deducciones, facturación y reportes contables. El cálculo de nómina es el proceso más crítico del sistema: ocurre en background, con progreso en tiempo real vía WebSocket.

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `Payroll` | `payrolls` | Período de nómina (semana, quincena). Una `Payroll` abierta absorbe automáticamente nuevos `TravelCount` via `buscar_nomina()` |
| `PayrollLog` | `payroll_logs` | Log de procesamiento: cada paso del cálculo queda registrado |
| `EmployeeSalary` | `employee_salaries` | Salario histórico de un empleado: SDI, SBC, fecha de vigencia |
| `EmployeeDeduction` | `employee_deductions` | Deducciones aplicadas: préstamos, multas, IMSS, etc. |
| `Invoicing` | `invoicings` | Facturación generada para un cliente en un período |
| `InvoiceType` | `invoice_types` | Catálogo de tipos de factura |
| `KumiSetting` | `kumi_settings` | Configuración por BU: topes de nómina, factores de cálculo, reglas de redondeo |

---

## Conceptos clave de nómina

| Término | Significado |
| --- | --- |
| SDI | Salario Diario Integrado (base IMSS) |
| SBC | Salario Base de Cotización |
| `buscar_nomina()` | Función PostgreSQL que encuentra la Payroll activa que debe absorber un TravelCount |
| Payroll abierta | `fecha_hasta IS NULL` — sigue absorbiendo viajes mientras esté abierta |
| Payroll cerrada | `fecha_hasta NOT NULL` — no admite más viajes, solo edición manual |

---

## Flujo de cálculo de nómina

```text
Admin inicia cálculo de nómina
          │
          ▼
PayrollsController#calculate
          │
          └── PayrollProcessWorker.perform_async(payroll_id)
                        │ (queue: payrolls)
                        │
                        ├── PayrollSvc::WeekCalculator
                        │       └── Calcula base por viajes de la semana
                        │
                        ├── PayrollSvc::ReportQuery
                        │       └── Agrega deducciones y bonos
                        │
                        └── ActionCable broadcast → frontend muestra progreso
```

El worker encola mensajes de progreso (`0%`, `25%`, `50%`, `100%`) que el frontend recibe en tiempo real via `AlertsChannel` o canal dedicado.

---

## Services

| Service | Responsabilidad |
| --- | --- |
| `PayrollSvc::WeekCalculator` | Calcula base de nómina semanal a partir de TravelCounts |
| `PayrollSvc::ReportQuery` | Construye reporte de nómina con deducciones aplicadas |
| `PayrollSvc::ReportExporter` | Exporta nómina a Excel (descargable desde el admin) |

---

## Jobs

| Job | Queue | Trigger |
| --- | --- | --- |
| `PayrollProcessWorker` | `payrolls` | Manual desde el admin al iniciar un cálculo de nómina |

---

## KumiSetting

`KumiSetting` almacena configuración financiera por BU. Ejemplos de llaves:

- `payroll_week_start` — día de inicio de semana de nómina
- `sdfc_factor` — factor de cálculo de SDI
- `max_weekly_hours` — tope de horas para horas extra

Se accede via `KumiSetting.get(key, business_unit_id)`.

---

## Controllers

```text
app/controllers/api/v1/payrolls_controller.rb
app/controllers/api/v1/payroll_reports_controller.rb
app/controllers/api/v1/invoicings_controller.rb
app/controllers/api/v1/invoice_types_controller.rb
app/controllers/api/v1/kumi_settings_controller.rb
```

---

## Archivos Rails completos

```text
app/models/payroll.rb
app/models/payroll_log.rb
app/models/employee_salary.rb
app/models/employee_deduction.rb
app/models/invoicing.rb
app/models/invoice_type.rb
app/models/kumi_setting.rb
app/services/payroll_svc/week_calculator.rb
app/services/payroll_svc/report_query.rb
app/services/payroll_svc/report_exporter.rb
app/workers/payroll_process_worker.rb
app/controllers/api/v1/payrolls_controller.rb
app/controllers/api/v1/kumi_settings_controller.rb
```
