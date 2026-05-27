# Concern: `SequenceSynchronizable`

`app/models/concerns/sequence_synchronizable.rb`

## Qué agrega

Un `before_create :sync_id_sequence` que **realinea la secuencia de PK** de la
tabla a `MAX(id)` antes de cada alta (y un método de clase `sync_sequence!` para
hacerlo manual tras imports):

```ruby
before_create :sync_id_sequence

def sync_id_sequence
  ActiveRecord::Base.connection.reset_pk_sequence!(self.class.table_name)
rescue StandardError => e
  Rails.logger.warn("No se pudo sincronizar secuencia para #{self.class.table_name}: #{e.message}")
end
```

## Por qué existe (⚠️ mientras viva PHP)

El **legacy PHP (y Android) insertan filas con `INSERT` directo y `id` explícito**,
por fuera de Rails. Eso **no avanza la secuencia** de PostgreSQL. Cuando Rails luego
hace `create`, `nextval` devuelve un id que ya existe →
`ActiveRecord::RecordNotUnique` (`<tabla>_pkey`) → **500**.

> **🔴 LEYENDA — ELIMINAR este concern y todos sus `include` CUANDO SE RETIRE PHP.**
> Es deuda técnica puente: mientras PHP siga insertando directo, es obligatorio.

## Modelos que lo incluyen

| Modelo | Tabla |
| --- | --- |
| `ServiceAppointment` | service_appointments |
| `GasCharge` | gas_charges |
| `GasolineCharge` | gasoline_charges |
| `TravelCount` | travel_counts |
| `EmployeeAppointment` | employee_appointments |
| `EmployeesIncidence` | employees_incidences |
| `VehicleAsignation` | vehicle_asignations |
| `DriverRequest` | driver_requests |

Cada `include` lleva una leyenda "eliminar este include cuando se retire PHP".

## Consolidación (2026-05-27)

Antes, cada modelo tenía su propio `verificar_id` (`before_create`) que mezclaba el
realign con `ModeloX.last.id + 1` + un `create` basura. Problemas:
- `last.id + 1` tronaba con `nil.id` cuando la tabla estaba **vacía** → 500 al crear
  el PRIMER registro (rompió la creación de servicios en prod).
- Lógica duplicada en N modelos.

Se centralizó todo en este concern (idempotente, forward-only, seguro con tabla
vacía). Donde `verificar_id` además tenía **lógica de negocio**, se conservó esa
parte y solo se quitó la de secuencia:
- `GasCharge#verificar_id` → ahora solo el cuadre contra gasfile.
- `TravelCount#verificar_id` → ahora solo asigna `payroll_id`.
- `GasolineCharge#verificar_id`, `EmployeeAppointmentLog#verificar_id` (código
  muerto) → eliminados.

## Caveat de concurrencia (a validar si crece el tráfico)

`setval` no es transaccional: bajo alta concurrencia dos creates podrían leer el
mismo `MAX(id)` y reusar un id. En estas tablas (altas administrativas, baja
concurrencia) el riesgo es mínimo. Si deja de serlo, migrar a **reintento ante
`RecordNotUnique`** (realinear y reintentar el INSERT una vez).

## Validación

`spec/models/service_appointment_spec.rb` desincroniza la secuencia (como la
dejaría un INSERT de PHP) y verifica que el `create` no colisiona.
