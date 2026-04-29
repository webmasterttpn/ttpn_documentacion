# Introducción de capa de servicios — PayrollReports (2026-03-20)

## Contexto y motivación

`PayrollReportsController` tenía tres problemas, siendo el más grave una
**vulnerabilidad de seguridad** activa (SQL injection):

| Problema | Descripción | Severidad |
|---|---|---|
| SQL injection | `fin_timestamp` interpolado directamente en un subquery de `employee_deductions` | **Crítica** |
| Query duplicada | La consulta de 40+ líneas estaba copiada íntegramente entre `create` y `download` | Alta |
| Generación de Excel en controller | `generate_excel` (63 líneas) mezclaba lógica de presentación con HTTP | Media |

---

## Vulnerabilidad de seguridad — SQL injection

### El problema original

En ambos métodos `create` y `download`, el subquery de deducciones interpolaba
la variable `fin_timestamp` directamente en el string SQL:

```ruby
# ANTES — VULNERABLE
"(SELECT COALESCE(SUM(employee_deductions.monto_semanal), 0)
   FROM employee_deductions
  WHERE employee_deductions.employee_id = employees.id
    AND employee_deductions.is_active = true
    AND (employee_deductions.fecha_inicio <= '#{fin_timestamp}')   ← interpolación directa
    AND (employee_deductions.fecha_fin IS NULL
         OR employee_deductions.fecha_fin >= '#{fin_timestamp}')   ← interpolación directa
 ) as deducciones"
```

`fin_timestamp` se construía a partir de `params[:end_datetime]` parseado con
`DateTime.parse`. Si bien `DateTime.parse` descarta entradas completamente
inválidas, un atacante con acceso al endpoint podría inyectar caracteres SQL
dentro de un string válido de fecha.

### La corrección

Se usa `ActiveRecord::Base.sanitize_sql_array` para parametrizar los valores:

```ruby
# DESPUÉS — SEGURO
def deductions_subquery
  sql = ActiveRecord::Base.sanitize_sql_array([
    "(SELECT COALESCE(SUM(employee_deductions.monto_semanal), 0)
       FROM employee_deductions
      WHERE employee_deductions.employee_id = employees.id
        AND employee_deductions.is_active = true
        AND employee_deductions.fecha_inicio <= ?
        AND (employee_deductions.fecha_fin IS NULL
             OR employee_deductions.fecha_fin >= ?)
     ) as deducciones",
    @fin,
    @fin
  ])
  Arel.sql(sql)
end
```

`sanitize_sql_array` aplica el mismo mecanismo de bind parameters que usa AR
internamente — los valores se escapan por el driver de la base de datos antes
de ejecutarse.

---

## Archivos creados

### `app/services/payroll/report_query.rb`

**Responsabilidad:** Ejecutar la consulta de nómina para un rango de fechas y
devolver los resultados como array de objetos `Employee` con atributos virtuales.

**Interfaz:**

```ruby
results = Payroll::ReportQuery.call(
  start_datetime: '2026-03-13 01:30:00',
  end_datetime:   '2026-03-20 01:30:00'
)
# => Array<Employee> con .puesto, .cost_viajes, .cont_viajes, .deducciones
```

**Qué hace la query:**

- Filtra empleados con puesto `Chofer` o `Coordinador`
- Excluye el empleado especial CLV `00000` (empleado nulo del sistema)
- Filtra viajes (`travel_counts`) cuya `fecha + hora` cae dentro del período
- Agrega por empleado: suma de costos, conteo de viajes, suma de deducciones activas
- Ordena por `nombre, apaterno`

**Por qué el resultado es un array y no una relación AR:**

La query tiene un `select` con atributos virtuales (`cont_viajes`, `cost_viajes`,
`deducciones`) que no existen como columnas en la tabla. Llamar `.to_a` al final
materializa los resultados y permite acceder a esos atributos directamente.
Devolver la relación sin evaluar causaría problemas al intentar encadenar más
scopes (los atributos virtuales se perderían).

---

### `app/services/payroll/report_exporter.rb`

**Responsabilidad:** Generar el stream binario del archivo `.xlsx` a partir de
los resultados de `ReportQuery`.

**Interfaz:**

```ruby
stream = Payroll::ReportExporter.call(
  resultados: rows,
  inicio:     '2026-03-13 01:30:00',
  fin:        '2026-03-20 01:30:00'
)

send_data stream,
          filename: Payroll::ReportExporter.filename,
          type:     Payroll::ReportExporter::CONTENT_TYPE
```

**Constantes públicas:**

| Constante | Valor |
|---|---|
| `CONTENT_TYPE` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` |
| `HEADERS` | Array con los encabezados del Excel |

**Estructura del Excel generado:**

```
Fila 1: CONSULTA DE NÓMINA
Fila 2: Período: {inicio} - {fin}
Fila 3: (vacía)
Fila 4: # Empleado | Nombre | Puesto | Viajes | Monto Bruto | Deducciones | Monto Neto
Fila 5+: datos por empleado
...
Penúltima: (vacía)
Última: TOTALES | | | {sum_viajes} | {sum_bruto} | {sum_ded} | {neto}
```

**Por qué es un servicio separado de `ReportQuery`:**

Separación de responsabilidades: la query sabe qué datos obtener, el exporter
sabe cómo presentarlos. Si en el futuro se necesita exportar a CSV o PDF, se
crea un `CsvExporter` sin tocar la query.

---

## Archivos modificados

### `app/controllers/api/v1/payroll_reports_controller.rb`

El controller pasó de **213 líneas** a **~70 líneas**.

**Antes:**

```ruby
def create
  begin
    # 40 líneas de query con SQL injection
    # 10 líneas de cálculo de totales
    # 20 líneas de serialización
  rescue => e  # ← captura genérica
    ...
  end
end

def download
  begin
    # mismas 40 líneas de query duplicadas
    # 63 líneas de generate_excel
  rescue => e
    ...
  end
end
```

**Después:**

```ruby
def create
  inicio, fin = parse_timestamps
  resultados  = Payroll::ReportQuery.call(start_datetime: inicio, end_datetime: fin)
  render json: {
    resultados: serialize_results(resultados),
    totales:    calculate_totals(resultados),
    periodo:    { inicio: inicio, fin: fin }
  }
rescue ArgumentError => e   # ← rescue específico por tipo
  ...
rescue StandardError => e
  ...
end

def download
  inicio, fin = parse_timestamps
  resultados  = Payroll::ReportQuery.call(start_datetime: inicio, end_datetime: fin)
  stream      = Payroll::ReportExporter.call(resultados: resultados, inicio: inicio, fin: fin)
  send_data stream, filename: ..., type: ...
end
```

**Métodos privados del controller:**

| Método | Qué hace |
|---|---|
| `parse_timestamps` | Parsea y formatea `start_datetime` / `end_datetime` de los params. Lanza `ArgumentError` si el formato es inválido |
| `serialize_results` | Transforma el array de Employee a hashes JSON |
| `calculate_totals` | Suma totales para el bloque `totales` de la respuesta |

**Mejora adicional en manejo de errores:**

El controller original usaba `rescue => e` (captura genérica que incluye
`Exception`, no solo `StandardError`). Ahora se rescatan tipos específicos:
- `ArgumentError` → fechas inválidas → 422
- `StandardError` → error de DB u otro → 422 con log

---

## Impacto en el sistema

| Aspecto | Antes | Después |
|---|---|---|
| Líneas en controller | 213 | ~70 |
| SQL injection | Presente en 2 lugares | Eliminada |
| Query duplicada | 2 copias de 40+ líneas | 1 clase reutilizable |
| Generación Excel en controller | Sí (63 líneas) | No — `ReportExporter` |
| Testabilidad de la query | Solo vía request specs | Unit specs sobre `ReportQuery` |
| Rescue genérico | `rescue => e` (captura Exception) | `rescue ArgumentError / StandardError` |

---

## Compatibilidad

- No se modificaron rutas ni contratos de respuesta JSON
- `Payroll::ReportQuery` y `Payroll::ReportExporter` viven en el mismo namespace
  `Payroll::` que `WeekCalculator` (creado en el sprint anterior) — consistencia
  de organización

---

## Próximos pasos del plan de servicios

1. ~~`FuelPerformanceController`~~ ✓
2. ~~`TtpnBookingsController`~~ ✓
3. ~~`PayrollReportsController`~~ ✓ (este documento)
4. `GasolineChargesController` → `Gasoline::EmployeeAssignmentService` + `Gasoline::StatsBuilder`
5. `Auth::SessionsController` → `User#build_privileges`
