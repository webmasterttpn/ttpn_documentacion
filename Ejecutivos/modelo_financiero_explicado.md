# El modelo financiero del sistema TTPN — explicado para no programadores

**Fecha:** 2026-05-21
**Audiencia:** Dirección de Finanzas TTPN + equipo no técnico que necesita
entender cómo se calculan los indicadores financieros del sistema.
**Propósito:** Servir de base para validar con el Director de Finanzas si
el modelo de ROI actual es correcto y qué falta para producir reportes
formales de contaduría.

---

## 1. Resumen en una página

El sistema TTPN tiene un módulo de **Viabilidad de Proyectos** que
responde una pregunta concreta:

> *Si abrimos un negocio (un taller, un servicio nuevo, una unidad de
> negocio) con una inversión inicial X y gastos mensuales Y, ¿cuándo
> recupera lo invertido y cuál es su retorno?*

### Qué SÍ responde

- ¿Cuánto llevamos invertido en este negocio? *(inversión acumulada)*
- ¿Cuánto cuesta operarlo cada mes? *(gasto fijo mensual)*
- ¿Cuánto está ingresando? *(revenue, manual o automático)*
- ¿En qué mes el ingreso acumulado igualó la suma invertida + gastada?
  *(break-even)*
- ¿Qué retorno porcentual lleva sobre la inversión? *(ROI %)*

### Qué NO responde (todavía)

- No calcula IVA ni participa en declaraciones SAT.
- No genera estado de resultados, balance general, ni libro mayor en
  formato contable.
- No integra automáticamente los sueldos pagados al cálculo de cada
  proyecto.
- No considera depreciación de activos (toda la inversión se registra
  entera al inicio).
- No reconcilia movimientos bancarios.
- No cierra períodos formalmente — los movimientos pasados se pueden
  modificar en cualquier momento.

El módulo está diseñado como **herramienta de gestión gerencial** (ver
si un negocio "vale la pena"), no como sistema contable formal. Lo que
falta para contaduría está catalogado en la sección 8 con su propuesta
de desarrollo.

---

## 2. Los 3 niveles del modelo (analogía con Excel)

Toda la información financiera del sistema vive en tres tablas, una
dentro de la otra:

| Nivel | Nombre técnico | Analogía Excel | Ejemplo |
|---|---|---|---|
| 1 | **Proyecto** | Un libro de Excel | "Taller Mecánico TTPN" |
| 2 | **Concepto** | Una fila con etiqueta y propiedades | "Luz", "Compra de aceite", "Renta del local" |
| 3 | **Movimiento** | La celda con el monto del mes | "Luz de mayo 2026 = $3,000" |

**Reglas importantes:**

- Un Proyecto contiene varios Conceptos (su "catálogo de cuentas").
- Cada Concepto tiene un tipo (inversión, gasto, ingreso) y una
  frecuencia esperada (única, mensual, trimestral, anual).
- **Solo puede existir 1 Movimiento por Concepto por mes.** Si la luz de
  mayo ya está registrada en $3,000, no se puede crear otra entrada
  "Luz mayo $500"; se debe editar la existente o sumarla.

Esta restricción técnica es importante porque significa que el sistema
**no soporta** dos facturas del mismo proveedor en el mismo mes como
dos entries separadas: hay que sumarlas en un solo movimiento o crear
dos Conceptos distintos.

---

## 3. Tipos de movimiento y frecuencias

### Tipos (`entry_type`)

Solo existen 3, intencionalmente:

| Tipo del sistema | Significado de negocio | Ejemplo |
|---|---|---|
| **Inversión** (`investment`) | Capital que se mete UNA vez para arrancar o ampliar el negocio | Compresor inicial, herramienta mayor, inversión inicial de $2,000 del Taller |
| **Gasto fijo** (`fixed_expense`) | Lo que cuesta operar el negocio mes a mes | Luz, agua, internet, gas, renta, compras recurrentes de insumos |
| **Ingreso** (`revenue`) | Dinero (o ahorro contable) que entra al negocio | Facturación a clientes, ahorro contra taller externo |

**No existen** los tipos: amortización, depreciación, ajuste contable,
provisión, costo de venta, devolución. Cualquiera de esos requeriría
ampliar el modelo (ver sección 8).

### Frecuencias (`frequency`)

Valores disponibles: `one_time`, `daily`, `weekly`, `monthly`,
`bimonthly`, `quarterly`, `semiannual`, `yearly`. En la base de datos
viajan en inglés pero la interfaz siempre los muestra en español
(*Una sola vez*, *Diaria*, *Semanal*, *Mensual*, *Bimestral*,
*Trimestral*, *Semestral*, *Anual*).

**Importante:** la frecuencia es solo descriptiva. Marcar un concepto
como "Mensual" **no hace que el sistema genere automáticamente** un
movimiento cada mes — es solo una etiqueta para que el usuario sepa
cómo capturar. Los 12 movimientos del año los crea el usuario
manualmente uno por uno.

---

## 4. Cómo se calcula el ROI — paso a paso

El sistema toma todos los movimientos del proyecto y los suma agrupándolos
por tipo:

```
Inversión acumulada     = suma de todos los movimientos tipo "inversión"
Gasto fijo acumulado    = suma de todos los movimientos tipo "gasto fijo"
Ingreso acumulado total = suma de movimientos tipo "ingreso"
                        + ingreso automático (ver sección 5)

Resultado neto = Ingreso acumulado − Inversión acumulada − Gasto fijo acumulado

ROI % = (Resultado neto / Inversión acumulada) × 100
```

El **break-even** (mes de recuperación) se calcula iterando mes a mes:
acumula el ingreso de cada mes y lo compara con la inversión + gastos
acumulados; el primer mes en que el ingreso iguala o supera al gasto,
ese es el break-even. Si nunca llega, el sistema devuelve "no
recuperado".

### Ejemplo con números reales del Taller (simulado en BD local)

Parámetros:

- Inversión inicial: **$2,000** (un solo movimiento mes de mayo).
- Gasto fijo mensual: **$5,100** (luz $3,000 + agua $400 + internet $1,000 + gas $700).
- Compra de aceite mensual: **$56,160** (702 L × $80/L).
- Sin ingresos.

Después de 3 meses (mayo–julio 2026):

| Métrica | Valor |
|---|---|
| Inversión acumulada | $2,000 |
| Gasto fijo acumulado (3 meses) | $183,780 |
| Ingreso acumulado | $0 |
| **Resultado neto** | **−$185,780** |
| **ROI** | **−9,289 %** |
| **Break-even** | **No alcanzado** (nunca, mientras no haya ingreso) |

Esto es exactamente lo que el sistema devuelve y es **correcto** dada la
lógica: un negocio que solo gasta no recupera nada. La discusión con el
Director es **qué constituye "ingreso"** cuando el taller no factura
(ver sección 5).

> *Detalle completo de esta simulación, con sensibilidad a tarifas
> externas y comparación entre 3 escenarios, en el apéndice y en
> [`Documentacion/Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md`](../Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md).*

---

## 5. De dónde viene el ingreso (los 3 modos del proyecto)

Cada proyecto tiene una configuración llamada
**`auto_revenue_source`** que define qué cuenta como ingreso automático,
**además** de los movimientos tipo "ingreso" capturados manualmente.

| Configuración | Qué cuenta como ingreso automático | Caso típico de negocio |
|---|---|---|
| **Ninguno** (`none`) | Nada. Solo cuenta lo capturado manualmente. | Proyecto en fase de inversión pura sin ventas todavía. |
| **OTs como ingreso** (`mtto_work_orders`) | El costo del material que sale del almacén a las órdenes de trabajo se cuenta como "venta". | Cuando ese material se está facturando tal cual a un cliente externo (reventa). |
| **Beneficio del taller** (`mtto_internal_savings`) | Por cada OT cerrada se calcula: *(lo que cobraría un taller externo) − (lo que nos costó) = beneficio*. **Aplica igual a OT internas (ahorro) y externas (profit).** Modo recomendado para el proyecto Taller. | Taller propio que atiende camionetas TTPN **y** clientes externos. Una sola cuenta de beneficio. |

### Por qué importa esta decisión

Mientras el proyecto Taller esté en modo **Ninguno**, el dashboard
nunca mostrará recuperación de inversión porque matemáticamente no
puede haber ROI sin ingreso. Para que el dashboard refleje el
**beneficio de tener taller propio**, hay que:

1. Capturar en cada **producto del catálogo** un campo *precio de venta
   interno* (`sale_price`).
2. Capturar en cada **servicio del catálogo** un campo *tarifa externa
   equivalente* (`external_rate`).
3. Cambiar el proyecto a modo **Beneficio del taller** (`mtto_internal_savings`).

> **Estado actual** (mayo 2026): los precios `sale_price` y `external_rate`
> ya son capturables desde el catálogo de productos y servicios, y el
> proyecto canónico "Taller Mecánico TTPN" ya está en modo `mtto_internal_savings`.
> Si una tarifa quedó en `$0` (no capturada), aporta `0` al beneficio (no
> contamina con negativos — es una decisión conservadora de diseño).

En la simulación se identificó que la tarifa externa para "cambio de
aceite" debe ser **≥ $800** para que el modelo arroje que el taller
propio es rentable contra mandar a externo. Si esa tarifa real está
por debajo, el sistema estará diciendo correctamente que **el taller
propio cuesta más que ir afuera**.

### OT internas vs externas — la misma cuenta contable

El módulo de Órdenes de Trabajo distingue dos casos con un toggle en
el formulario:

- **OT interna** (camioneta TTPN, flota propia): `estimated_savings` se
  lee como **"ahorro vs taller externo"**.
- **OT externa** (cliente que paga al taller): `estimated_savings` se
  lee como **"profit por servir al cliente"**.

Matemáticamente son la misma operación: `valor de mercado − costo`. Por
eso `mtto_internal_savings` suma ambos casos en un único agregado y el
dashboard lo expone como un solo número en el KPI "Ingreso (rango)".
Si más adelante se necesita partir el reporte (cuánto vino de flota vs
cuánto de clientes externos) el desglose ya está disponible en el tab
**Servicios del Taller** del mismo dashboard (sección interno/externo).

---

## 6. Lo que el sistema HACE hoy

| Capacidad | Detalle |
|---|---|
| Crear proyectos independientes | Cada negocio (Taller, Refacciones, futuros) es una caja aislada. |
| Catalogar conceptos por proyecto | Cuentas tipo "Luz", "Renta", "Sueldos", "Compra de insumos". |
| Registrar movimientos día a día | Captura manual con fecha exacta (`entry_date`), monto, número de factura opcional, notas. |
| Calcular ROI, break-even, burn rate | En tiempo real, sobre el rango **día a día** que el usuario elija con el selector de calendario. |
| Mostrar serie mensual y desglose por concepto | La serie se agrupa por mes para gráfica, pero filtra por fecha exacta (no por etiqueta mensual). |
| Tres modos de ingreso automático | Vinculados al módulo de mantenimiento (sección 5). |
| Panel de Operación del Taller | 5 widgets adicionales: vehículos atendidos por semana, top servicios, servicios por vehículo, horas y servicios por mecánico, ranking de mayor atraso. Se activa automáticamente cuando el proyecto tiene `auto_revenue_source = mtto_*`. |
| Calcular nómina | Módulo separado (`Payroll`) que suma viajes × costo y resta deducciones activas para choferes y coordinadores. Genera Excel listo para pagaduría. |
| Generar Excel de facturación a clientes | Módulo separado (`Invoicing`) con 6 layouts distintos según el tipo de cliente. Asíncrono (encola job y se descarga cuando termina). |
| Privilegios diferenciados | El acceso a Viabilidad de Proyectos es un privilegio aparte (`finance_project_viability`) que se asigna por rol. |

### 6.1 Selector de rango: de mes-año a día a día

El selector de fechas del Dashboard solía ser un *input* con máscara
`YYYY-MM` (granularidad mensual). Desde mayo 2026 es un **calendario
visual** con rango día a día. Internamente todos los movimientos viven
con su `entry_date` exacta; el cambio permite reportes como
"del 14 al 30 de mayo" o "todo el primer trimestre" sin redondeo.

La gráfica mensual sigue agrupando por mes (porque visualmente es lo
útil), pero los meses que solo están parcialmente dentro del rango
se recortan al borde elegido.

### 6.2 Panel "Operación del taller" — KPIs no contables

Debajo del KPI financiero clásico, el Dashboard muestra un panel
operativo cuando el proyecto está conectado al taller:

| Widget | Pregunta de negocio que responde |
|---|---|
| Vehículos atendidos por semana | ¿Cuántas camionetas TTPN entraron a taller esta semana? ¿Hay picos? |
| Top servicios | ¿Qué tipo de mantenimiento es más recurrente? (orienta compra de refacciones) |
| Servicios por vehículo | ¿Qué unidades están consumiendo más servicio? (señal de unidades problemáticas) |
| Horas y servicios por mecánico | ¿Cómo está distribuida la carga? ¿Quién cierra más OT? |
| Mayor atraso | ¿Qué OT se pasaron más del estándar? (mejora continua, capacitación) |

Estos KPIs no afectan la cuenta de pesos del proyecto; complementan el
ROI con métricas operativas para que el Director de Finanzas tenga
visibilidad de qué tanto el taller "trabaja" más allá de cuánto cuesta.

### 6.3 Arquitectura: cálculos pesados en Python asíncrono

A partir de mayo 2026, **todos los dashboards y agregaciones
estadísticas** se calculan en Python (no en Ruby) y se ejecutan de
forma asíncrona:

1. El usuario abre el Dashboard → el FE pide los datos al BE.
2. El BE responde **inmediatamente** con un identificador de trabajo
   (`job_id`), liberando el servidor web.
3. Un proceso Python en segundo plano corre las consultas a Postgres
   con `chunksize` (procesa por trozos para no saturar memoria).
4. Cuando termina, **avisa al navegador por WebSocket** y los widgets
   se llenan automáticamente.

Por qué importa para Finanzas: reportes de un año o varios años antes
podían tronar la pestaña del navegador o agotar memoria del servidor.
Con este patrón, un reporte de 5 años de actividad del taller es
factible y rápido. Es un cambio **invisible para el usuario** salvo
por uno o dos segundos de espera mientras los widgets se actualizan
después de cambiar el rango de fechas.

---

## 7. Lo que el sistema NO hace + propuesta de desarrollo

Esta sección lista los huecos que el Director de Finanzas previsiblemente
identificará y, para cada uno, propone qué desarrollo técnico cubriría
la brecha. El esfuerzo se estima en S (días), M (1–2 semanas), L (3+
semanas).

### 7.1 IVA / impuestos

- **Estado actual:** los montos se guardan brutos. No hay campos
  `tax_amount`, `subtotal`, `tax_rate`. Las facturas de proveedores se
  capturan con un solo monto.
- **Workaround manual:** crear conceptos separados "IVA acreditable" e
  "IVA trasladado" y meter sus montos como movimientos paralelos. Es
  doble captura y propenso a error.
- **Propuesta técnica:** agregar columnas `subtotal`, `tax_rate`,
  `tax_amount` a `Finance::Entry` y validar `subtotal + tax_amount =
  amount`. Calcular automáticamente cuando el usuario elija un
  `tax_rate` de catálogo (0 %, 8 %, 16 %, exento). Reportes mensuales
  de IVA acreditable vs. trasladado.
- **Esfuerzo:** M (1–2 semanas).
- **Bloqueo:** decidir si TTPN va a usar el sistema para sustentar
  declaración SAT o solo para gestión interna. Cambia mucho el alcance.

### 7.2 Sueldos integrados al proyecto

- **Estado actual:** el módulo `Payroll` calcula nómina (genera Excel),
  pero esos sueldos pagados **no aparecen** automáticamente como gasto
  fijo del proyecto al que pertenece el empleado. El burn rate del
  Taller está subestimado por todo lo que TTPN paga a los mecánicos.
- **Workaround manual:** crear un concepto "Sueldos mecánicos del
  Taller" y meter el total bruto cada mes. Requiere que alguien lo
  copie del Excel de nómina.
- **Propuesta técnica:** al cerrar una nómina, generar automáticamente
  un movimiento tipo `fixed_expense` por cada proyecto que tenga
  empleados asignados. Requiere agregar al empleado un campo
  `finance_project_id` (el proyecto al que se carga su costo).
- **Esfuerzo:** S–M (5–10 días).
- **Bloqueo:** decidir el mapeo empleado → proyecto. Hoy no existe.

### 7.3 Compras de mercancía como gasto automático

- **Estado actual:** cuando se recibe inventario (compra de aceite,
  refacciones, etc.) solo aumenta el stock; no genera movimiento
  financiero. Ya catalogado como **DT-021** en deuda técnica.
- **Workaround manual:** capturar cada compra grande como movimiento
  fijo del mes.
- **Propuesta técnica:** callback `after_commit` en
  `Mtto::ProductReceipt` que cree un movimiento tipo `fixed_expense`
  ligado al proyecto Mtto de la misma unidad de negocio. Requiere
  definir el mapeo unidad de negocio → proyecto receptor.
- **Esfuerzo:** S (3–5 días) más la decisión de mapeo.

### 7.4 Estado de resultados (P&L) mensual formal

- **Estado actual:** el dashboard muestra KPIs agregados, pero no
  produce un **estado de resultados** con la estructura clásica
  (ingresos – costo de ventas = utilidad bruta; – gastos de operación =
  utilidad operativa; – impuestos = utilidad neta).
- **Propuesta técnica:** servicio `Finance::IncomeStatementGenerator`
  que reagrupa los movimientos del mes en las categorías estándar
  (ingresos, costo de ventas, gastos operativos, otros, impuestos) y
  exporta a Excel y PDF. Requiere clasificar cada `Finance::Concept`
  con un campo `accounting_group`.
- **Esfuerzo:** M (10–15 días).

### 7.5 Libro mayor / libro diario

- **Estado actual:** no existe. El sistema almacena movimientos
  agrupados por concepto, sin partida doble.
- **Propuesta técnica:** nuevo modelo `Finance::JournalEntry` con doble
  partida (cargo y abono a cuentas de un catálogo SAT). Cada
  `Finance::Entry` generaría automáticamente la partida doble
  correspondiente.
- **Esfuerzo:** L (3+ semanas).
- **Comentario:** este es el cambio más grande. Implica decidir si TTPN
  llevará contabilidad formal dentro del sistema o seguirá usando
  software contable externo (Contpaq, Aspel, etc.) alimentado con
  exports.

### 7.6 Balance general

- **Estado actual:** no existe. El sistema no tiene noción de activos,
  pasivos ni capital.
- **Propuesta técnica:** requiere primero el libro mayor (7.5). Sobre
  esa base, un servicio que tome los saldos de las cuentas de balance
  y genere el reporte estándar.
- **Esfuerzo:** L. **Bloqueado por 7.5.**

### 7.7 Conciliación bancaria

- **Estado actual:** no hay registro de cuentas bancarias ni
  movimientos. Solo los movimientos del proyecto.
- **Propuesta técnica:** modelos `BankAccount` y
  `BankReconciliation` con import de estados de cuenta (CSV o API
  bancaria si existe). Casamiento automático/manual con
  `Finance::Entry` y reporte de pendientes.
- **Esfuerzo:** L. Cada banco mexicano tiene formato distinto.

### 7.8 Depreciación de activos

- **Estado actual:** la inversión inicial se registra en su totalidad
  el día que ocurre. El ROI del primer mes la absorbe completa, lo que
  distorsiona la rentabilidad mensual.
- **Workaround manual:** dividir la inversión en cuotas mensuales y
  capturarla como gasto fijo en lugar de inversión. Pierde la
  trazabilidad de qué fue inversión vs. operación.
- **Propuesta técnica:** modelo `Finance::Asset` con `useful_life_months`
  y `depreciation_method` (lineal, SUM, etc.). Cada cierre mensual
  genera automáticamente un movimiento de depreciación.
- **Esfuerzo:** M (10–15 días).

### 7.9 Cierres mensuales formales

- **Estado actual:** las entries se pueden modificar en cualquier
  momento, sin candado. Contaduría no puede confiar en que el mes
  pasado no cambie.
- **Propuesta técnica:** modelo `Finance::PeriodClose` que congele un
  proyecto-mes. Una vez cerrado, los movimientos del mes no se pueden
  editar; correcciones requieren un movimiento de ajuste con
  trazabilidad. Reabrir un período exige autorización privilegiada.
- **Esfuerzo:** S–M (5–10 días).

### 7.10 Multi-moneda

- **Estado actual:** todos los montos son MXN implícito; sin campo de
  moneda ni tipo de cambio.
- **Propuesta técnica:** agregar campos `currency` y `exchange_rate` a
  cada movimiento. Tabla de tipos de cambio históricos. Reporte de
  exposición cambiaria.
- **Esfuerzo:** M.
- **Bloqueo:** solo si TTPN va a facturar en USD o pagar a proveedores
  extranjeros. No urgente hoy.

---

## 8. Reportes que se pueden generar hoy

| Reporte | Quién lo emite | Formato | Cómo se solicita |
|---|---|---|---|
| Nómina del período | RR.HH. / pagaduría | Excel (XLSX) | Crear nómina → encolar generación → descargar |
| Reporte de cálculo de nómina | Finanzas | Excel | Endpoint específico, no requiere persistir nómina |
| Facturación a un cliente | Operaciones / cobranza | Excel (6 layouts según tipo) | Encolar generación asíncrona → consultar estado → descargar |
| Viabilidad de proyectos (KPIs + serie mensual) | Dirección | JSON en pantalla (no descargable hoy) | Dashboard web |
| Estadísticas de gasolina | Operaciones vehiculares | JSON en pantalla | Dashboard web |

**Lo que no existe hoy** y previsiblemente Contaduría pedirá:

- Estado de resultados mensual / anual en PDF/Excel.
- Balanza de comprobación.
- Reporte de IVA acreditable y trasladado.
- Resumen de gastos por proveedor / por categoría / por proyecto en un
  rango.
- Auxiliar de cuentas.
- Reporte de cierre mensual (con sello de "cerrado el día X por Y").
- Exportación a formato compatible con Contpaq / Aspel / SAP.

Todos esos están cubiertos en las propuestas de la sección 7.

---

## 9. Glosario

| Término del sistema | Qué significa para un humano |
|---|---|
| **Proyecto** (`Finance::Project`) | Negocio independiente con su propia caja: inversión, gastos, ingresos. |
| **Concepto** (`Finance::Concept`) | Línea/cuenta del catálogo del proyecto. Define el tipo y la frecuencia esperada. |
| **Movimiento** (`Finance::Entry`) | Captura real: el monto de un concepto en un mes específico. |
| **Período** (`period`) | El mes al que pertenece un movimiento, en formato YYYY-MM. Se calcula automáticamente de la fecha. |
| **Tipo de movimiento** (`entry_type`) | Inversión, gasto fijo o ingreso. No hay más. |
| **Frecuencia** (`frequency`) | Etiqueta descriptiva (única / mensual / trimestral / anual). No automatiza nada. |
| **Inversión acumulada** (`investment_lifetime`) | Suma de todos los movimientos tipo inversión desde el inicio del proyecto. |
| **Gasto fijo acumulado** (`fixed_expense_lifetime`) | Suma de todos los gastos fijos desde el inicio. |
| **Ingreso acumulado** (`revenue_lifetime`) | Suma de ingresos manuales + ingresos automáticos. |
| **Resultado neto** (`net_lifetime`) | Ingreso − Inversión − Gasto fijo. Positivo = rentable. |
| **ROI %** (`roi_pct`) | Resultado neto entre inversión, en porcentaje. |
| **Mes de recuperación** (`break_even_period`) | Primer mes en que el ingreso acumulado iguala o supera la inversión + gastos acumulados. "No alcanzado" si nunca llega. |
| **Origen del ingreso automático** (`auto_revenue_source`) | La regla por la que el sistema cuenta como ingreso eventos del módulo de mantenimiento. Ver sección 5. |
| **Costo de materiales de una OT** (`materials_cost`) | Lo que costó internamente el material consumido en una orden de trabajo (a costo promedio del inventario). |
| **Valor de mercado interno** (`internal_market_value`) | Cuánto cobraría un taller externo por la misma orden (suma de tarifas externas de los servicios + precio de los productos al "como si se vendieran"). |
| **Ahorro estimado de una OT** (`estimated_savings`) | Valor de mercado interno menos costo real de la OT. Es el "ingreso" que el modo *Ahorro vs taller externo* reconoce. |

---

## Apéndice — Simulación del Taller (resumen)

Con datos sembrados en la base de datos local (proyecto sandbox
`taller-simulacion-aceite`), se simuló la operación del Taller con 6
camionetas/día solo de cambio de aceite (4.5 L × $80 = $360 de material
por orden, 156 órdenes/mes). Resultado: el dashboard muestra ROI −9,289 %
y "no recuperado" después de 3 meses, lo cual es correcto: sin
configurar tarifas externas ni capturar ingresos, no hay forma
matemática de recuperar nada. La sensibilidad sugiere que la tarifa
externa por cambio de aceite debe ser **≥ $800** para que el modo
*Ahorro vs taller externo* arroje rentabilidad.

Detalle completo (tablas, escenarios alternos, comando para limpiar el
sandbox local) en
[`Documentacion/Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md`](../Backend/dominio/finanzas/viabilidad/simulacion_taller_aceite.md).
