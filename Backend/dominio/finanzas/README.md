# Dominio: Finanzas

Nómina, deducciones, salarios, facturación y reportes contables.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `Payroll` | Período de nómina |
| `PayrollLog` | Log de procesamiento de nómina |
| `EmployeeSalary` | Salario histórico de un empleado (SDI, SBC) |
| `EmployeeDeduction` | Deducciones aplicadas |
| `Invoicing` | Facturación |
| `InvoiceType` | Tipo de factura |

## Estado de documentación

Pendiente. stats/ debe incluir KPIs de nómina y ai-prompts.md con contexto de SDI, SBC, IMSS.

## Workers activos

| Worker | Cola | Función |
| --- | --- | --- |
| `PayrollProcessWorker` | `payrolls` | Procesar nómina en background con progreso en tiempo real |

## Archivos Rails relacionados

```text
app/models/payroll.rb
app/models/payroll_log.rb
app/models/employee_salary.rb
app/models/employee_deduction.rb
app/workers/payroll_process_worker.rb
app/controllers/api/v1/payrolls_controller.rb
```
