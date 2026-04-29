# Dominio: Employees (Recursos Humanos)

El dominio más crítico del sistema. Gestiona empleados, sus movimientos laborales (altas, bajas, reingresos), documentos, salarios, vacaciones, nómina y estadísticos de RR.HH.

---

## Modelos principales

| Modelo | Archivo | Descripción |
| --- | --- | --- |
| `Employee` | [model.md](model.md) | Empleado. Campos, validaciones, asociaciones, reglas de negocio |
| `EmployeeMovement` | [movements.md](movements.md) | Alta, Baja, Reingreso. Fuente de verdad del estado activo |
| `EmployeeMovementType` | [movement_types.md](movement_types.md) | Catálogo de tipos. Constantes canónicas |

---

## Estructura de carpetas

```
employees/
├── README.md                   ← este archivo
├── model.md                    ← Employee
├── movements.md                ← EmployeeMovement
├── movement_types.md           ← EmployeeMovementType
├── ANALISIS_EMPLOYEE.md        ← Análisis completo de campos y enums
│
├── controller/
│   └── endpoints.md            ← API REST del módulo
│
├── concerns/
│   └── employee_stats_calculable.md  ← Cálculo de KPIs RR.HH.
│
├── stats/
│   ├── README.md               ← Fórmulas, fuentes de datos, errores comunes
│   └── ai-prompts.md           ← Cómo pedir datos a la IA correctamente
│
├── jobs/
│   └── README.md               ← Jobs asíncronos del dominio
│
├── services/
│   └── README.md               ← Services del dominio
│
├── workers/
│   └── README.md               ← Workers (Sidekiq) del dominio
│
└── tests/
    ├── factories.md            ← FactoryBot factories
    ├── model_spec.md           ← Specs de modelo
    └── controller_spec.md     ← Specs de controller (request specs)
```

---

## Regla de oro: estado activo/inactivo

**El estado de un empleado viene de `EmployeeMovement`, no de `Employee.status`.**

`Employee.status` es un campo denormalizado que el callback `revisar_status_chofer` mantiene actualizado. Para consultas históricas ("¿quién era activo el 1 de enero de 2026?"), usar `EmployeeMovement` con `fecha_expiracion`.

Ver: [stats/README.md](stats/README.md)

---

## Archivos Rails relacionados

```
app/models/employee.rb
app/models/employee_movement.rb
app/models/employee_movement_type.rb
app/models/employee_document.rb
app/models/employee_salary.rb
app/models/employee_vacation.rb
app/models/employee_appointment.rb
app/controllers/api/v1/employees_controller.rb
app/controllers/api/v1/employee_stats_controller.rb
app/controllers/concerns/employee_stats_calculable.rb
app/serializers/employee_serializer.rb
```
