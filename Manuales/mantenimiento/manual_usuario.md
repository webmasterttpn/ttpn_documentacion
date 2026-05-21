# Manual de Usuario — Módulo de Mantenimiento (Control de Inventario de Taller)

Kumi by TTPN · Versión 1 (Fase 1) · Mayo 2026

Este manual sigue el **orden recomendado de captura inicial**: cada sección
depende de la anterior, así que conviene leerlo y aplicarlo en este orden.

> 🔑 **Lo más importante de leer:** la sección
> [6. Recepción de producto: pieza vs. líquido](#6-recepción-de-producto-pieza-vs-líquido).
> Ahí se explica la diferencia clave al recibir un producto que se cuenta por
> **pieza** y uno que es **líquido** (incluye galones en caja).

---

## Índice

1. [Acceso y navegación](#1-acceso-y-navegación)
2. [Conceptos clave (leer antes de capturar)](#2-conceptos-clave)
3. [Categorías](#3-categorías)
4. [Presentaciones](#4-presentaciones)
5. [Productos (incluye cómo capturar un líquido)](#5-productos) ⭐
6. [Recepción de producto: pieza vs. líquido](#6-recepción-de-producto-pieza-vs-líquido) ⭐
7. [Servicios de Taller](#7-servicios-de-taller)
8. [Órdenes de Trabajo](#8-órdenes-de-trabajo)
9. [Salidas / consumo (residuo de líquidos)](#9-salidas--consumo)
10. [Tablero de Monitoreo](#10-tablero-de-monitoreo)
11. [Estados y permisos](#11-estados-y-permisos)
12. [Finanzas del Taller — Viabilidad del Proyecto](#12-finanzas-del-taller--viabilidad-del-proyecto) ⭐

---

## 1. Acceso y navegación

Inicie sesión con su usuario y contraseña. En el menú lateral abra el grupo
**Mantenimiento**. Las opciones aparecen en el orden lógico de captura:
**Categorías → Presentaciones → Productos → Recepciones → Servicios de Taller
→ Órdenes de Trabajo → Salidas → Tablero de Monitoreo**.

![Menú de Mantenimiento](img/00-menu.png)

El acceso a cada sección depende de sus permisos (ver
[sección 11](#11-estados-y-permisos)).

---

## 2. Conceptos clave

Antes de capturar conviene entender 4 conceptos:

| Concepto | Qué es |
| --- | --- |
| **Unidad base** | La unidad en la que el sistema **guarda y consume** el producto (ej. *pieza* para un filtro, *litro* para un aceite). Se define en el producto. |
| **Presentación** | Cómo se **compra** el producto. Tiene dos niveles: *tamaño del envase* (ej. galón = 4.9 L) y *envases por paquete* (ej. caja x 6). El sistema multiplica los dos y obtiene cuántas unidades base entran al inventario por cada paquete recibido. |
| **Costo promedio móvil** | El costo unitario del producto se recalcula automáticamente en cada recepción, ponderando lo que ya había con lo que entra. |
| **Residuo reutilizable (costo hundido)** | En líquidos, lo que sobra de un consumo y aún sirve regresa al inventario **a costo $0**, para no ensuciar el costo promedio. |

👉 La **Presentación** es el puente entre *cómo compro* y *cómo consumo*. Por
eso es lo segundo que se captura (después de Categorías): sin ella el producto
no puede ligarse a una forma de compra.

---

## 3. Categorías

Agrupan los productos. **Mantenimiento → Categorías → Nueva Categoría**.
Capture *Nombre* y *Código* (LUBR, FILT…). Puede desactivarlas sin borrarlas.

![Categorías](img/categorias.png)

> Sugerencia: tenga al menos *Lubricantes*, *Filtros* y *Repuestos* antes de
> capturar productos.

---

## 4. Presentaciones

Define **cómo compra** cada producto. Una presentación tiene **dos niveles**:

- **Tamaño del envase (en unidad base)** — qué tan grande es **un envase**.
  Ej.: un galón de **4.9 L**; un envase de **1 L**; una **pieza** suelta (1).
- **Envases por paquete** — cuántos envases trae **el paquete que recibe**.
  Ej.: **6** para una caja con 6 galones; **24** para una caja con 24 litros;
  **1** para envases sueltos sin caja.

El sistema calcula automáticamente:

```text
Total (unid. base) = Tamaño del envase × Envases por paquete
```

### 4.1 Crear una presentación

**Nueva Presentación**, capture los 4 campos. El recuadro azul muestra el
total calculado en tiempo real (útil para verificar antes de guardar):

![Formulario de Presentación — Caja 6 galones 4.9 L = 29.4 L](img/form-presentacion.png)

### 4.2 Catálogo de presentaciones

La lista muestra envase × paquete y el total en unidad base:

![Presentaciones — Catálogo](img/presentaciones.png)

> Cree una presentación por cada **forma real** de comprar. Mismo producto
> recibido en dos formatos (caja de galones y caja de litros) ⇒ dos
> presentaciones distintas. El catálogo es libre y por unidad de negocio.

### 4.3 Ejemplos típicos

| Presentación | Envase | Paquete | Total | Para qué se usa |
| --- | --- | --- | --- | --- |
| Pieza | 1 | 1 | 1 | Refacción suelta (filtro, balata) |
| Caja x12 piezas | 1 | 12 | 12 | Filtros, focos, fusibles… |
| Galón 4.9 L | 4.9 | 1 | 4.9 | Aceite comprado por galón suelto |
| Caja 6 galones 4.9 L | 4.9 | 6 | 29.4 | Aceite comprado por caja de galones |
| Caja 24 litros | 1 | 24 | 24 | Aceite/refrigerante comprado por caja de envases de 1 L |
| Tambor 200 L | 200 | 1 | 200 | Lubricante a granel |

---

## 5. Productos

Catálogo de artículos del inventario. **Mantenimiento → Productos →
Nuevo Producto**. Los campos clave:

- **Categoría** (creada en sección 3).
- **Nombre** — el descriptivo del producto.
- **SKU** — clave formal interna o del fabricante.
- **Clave taller** — clave corta de uso rápido en taller (distinta del SKU,
  para que el mecánico la pida sin teclear el SKU completo).
- **Unidad base** — *seleccionable de una lista* (pieza, litro, mililitro,
  kilogramo, caja, …) o puede escribir una nueva. **Esta es la unidad en la que
  vivirá el inventario y se consumirá.**
- **Mín./Máx./Reorden/Lead time** — umbrales para alertas de stock.
- **Precio de venta (por unidad base)** — *opcional, pero clave para medir
  ahorro*. Es lo que costaría 1 unidad base (1 litro, 1 pieza) si lo comprara
  en taller externo o se lo facturara a un tercero. Cuando el inventario se
  consuma en una OT, este precio se usa para calcular cuánto se "ahorró" TTPN
  al usar inventario propio en lugar de cotizar afuera. Si aún no lo tiene,
  déjelo en blanco — se puede agregar después editando el producto.

### 5.1 Capturar un producto **por pieza** (ejemplo: Filtro de Aire)

| Campo | Valor |
| --- | --- |
| Categoría | Filtros |
| Nombre | Filtro de Aire |
| SKU | FILT-AIR-01 |
| Clave taller | FA01 |
| **Unidad base** | **pieza** |
| Mín. / Máx. / Reorden | 10 / 200 / 30 |

![Formulario de Producto — vacío](img/form-producto.png)

### 5.2 Capturar un producto **líquido** ⭐ (ejemplo: Aceite Motor 10W-40)

| Campo | Valor |
| --- | --- |
| Categoría | Lubricantes |
| Nombre | Aceite Motor 10W-40 |
| SKU | LUBR-10W40 |
| Clave taller | AC1040 |
| **Unidad base** | **litro** ← seleccionar del dropdown |
| Mín. / Máx. / Reorden | 20 / 600 / 100 |

![Formulario de Producto — líquido, unidad base = litro](img/form-producto-liquido.png)

> ⚠️ La **Unidad base** se elige UNA sola vez al crear el producto y es **la
> unidad en la que el sistema cuenta el inventario y carga el consumo**. Para
> aceite use *litro* (o *mililitro* si trabaja con cantidades muy pequeñas).
> Las distintas formas de comprarlo (galón, litro suelto, caja) se manejan en
> las **Presentaciones** (sección 4), no en el producto.

### 5.3 Catálogo de productos

La lista muestra disponible, costo promedio y estado de stock
(OK / REORDER / OUT_OF_STOCK / OVERSTOCK):

![Productos](img/productos.png)

> Ejemplo real de la imagen:
> **FA01 · Filtro de Aire** (unidad base *pieza*, 58 disponibles) y
> **AC530 · Aceite Motor 5W-30** (unidad base *litro*, 196.5 disponibles).

---

## 6. Recepción de producto: pieza vs. líquido

⭐ **Esta es la sección clave.** Recibir producto siempre sigue los mismos
pasos; la diferencia entre un producto **por pieza** y uno **líquido** está
únicamente en la **Presentación** que elija, porque ella define la conversión
a unidad base.

### Pasos generales

1. **Mantenimiento → Recepciones → Nueva Recepción**.
2. Seleccione el **Proveedor** y capture:
   - **Factura del proveedor** — folio de la remisión / nota de entrega
     que entrega el proveedor con la mercancía.
   - **Factura fiscal** — folio del CFDI / factura SAT. Es opcional al
     momento de la recepción porque el proveedor a veces la emite después;
     puede dejarlo en blanco y editarlo cuando llegue.
   - **Ubicación de almacén**.
3. Por cada producto, **Agregar línea**:
   - **Producto**
   - **Presentación** ← *aquí está la diferencia pieza vs. líquido*
   - **Cant.** (en **paquetes/cajas**, no en unidad base)
   - **Costo unit.** (costo de **un paquete/caja**)
   - **Aceptado** (cuántos paquetes se aceptan tras revisión)
4. **Guardar**. La recepción queda en estado `in_progress`.
5. En la lista, use **Procesar** para que entre al inventario.

![Formulario de Recepción](img/form-recepcion.png)

![Recepciones — botón Procesar](img/recepciones.png)

> Sólo al **Procesar** se afecta el inventario y se recalcula el costo
> promedio. Mientras está `in_progress` aún puede corregirla.
>
> La columna **Total** del listado es el **monto facturado por el proveedor**:
> Σ (Cant. × Costo unit.) de todas las líneas — es decir, **lo recibido**,
> no lo aceptado. Se actualiza solo al guardar la recepción.

### 6.1 Caso A — Producto por **PIEZA** (Filtro de Aire)

Se compran **5 cajas** de filtros, cada caja con **12 piezas**.

| Campo | Valor a capturar |
| --- | --- |
| Producto | Filtro de Aire *(unidad base = pieza)* |
| Presentación | **Caja x12 piezas** *(envase 1 × paquete 12 = 12)* |
| Cant. | **5** (cajas) |
| Costo unit. | **$1,440** (por caja) |
| Aceptado | **5** |

Al **Procesar**, el sistema convierte:

```text
5 cajas × 12 piezas = 60 piezas entran al inventario
costo por pieza     = $1,440 / 12 = $120
```

Resultado: el Filtro queda con **60 piezas** disponibles a **costo promedio
$120**. (En la captura aparece con 58, porque ya se consumieron 2 en una salida
— sección 9.)

### 6.2 Caso B — Producto **LÍQUIDO** en un solo formato (Tambor 200 L)

Se compra **1 tambor** que trae **200 litros**.

| Campo | Valor a capturar |
| --- | --- |
| Producto | Aceite Motor 5W-30 *(unidad base = litro)* |
| Presentación | **Tambor 200 L** *(envase 200 × paquete 1 = 200)* |
| Cant. | **1** (tambor) |
| Costo unit. | **$4,000** (por tambor) |
| Aceptado | **1** |

Conversión automática:

```text
1 tambor × 200 litros = 200 litros entran al inventario
costo por litro       = $4,000 / 200 = $20
```

### 6.3 Caso C — Producto **LÍQUIDO** recibido en dos formatos distintos

Cuando recibe el mismo aceite a veces en **caja de galones** y a veces en
**caja de litros**, **cada formato es una Presentación distinta** en el
catálogo (ver sección 4). La Recepción usa la presentación que corresponda en
cada línea.

**Presentaciones que deben existir (creadas una sola vez):**

| Presentación | Envase | Paquete | Total |
| --- | --- | --- | --- |
| Caja 6 galones 4.9 L | 4.9 | 6 | 29.4 L |
| Caja 24 litros | 1 | 24 | 24 L |

**Captura de cada recepción del Aceite Motor 5W-30:**

| Recepción | Presentación | Cant. | Costo unit. (caja) | El sistema suma |
| --- | --- | --- | --- | --- |
| A | Caja 6 galones 4.9 L | 1 | $1,470 | 29.4 L a $50/L |
| B | Caja 24 litros | 1 | $1,320 | 24 L a $55/L |

> Recuerde: **Cant.** es cuántas cajas recibe, **no** litros. El **Costo unit.**
> es el costo de una caja. La conversión a litros y a costo por litro la hace
> el sistema usando *Envase × Paquete* de la presentación.

**Costo promedio resultante** (móvil ponderado por unidad base):

```text
costo por litro de A = $1,470 / 29.4 = $50.00
costo por litro de B = $1,320 / 24   = $55.00

promedio combinado  = (29.4·$50 + 24·$55) / (29.4 + 24)
                    = (1,470 + 1,320) / 53.4
                    = $52.25 por litro
```

Al consumir, el costo cargado es el promedio vigente (sección 9), sin importar
de qué caja salió el aceite.

### 6.4 Regla de oro

> **Usted siempre captura en PAQUETES/CAJAS y al costo de la caja. El sistema
> convierte solo a la unidad base usando la Presentación.** Por eso es
> indispensable que la *Presentación* tenga bien capturadas el *envase* y los
> *envases por paquete* (sección 4).

### 6.5 Ver el detalle de una recepción

Haga **click en el renglón** (o en el ícono 👁 a la derecha) para abrir el
diálogo de detalle. Verá:

- **Encabezado**: folio, estado (Borrador / En proceso / Completada /
  Cancelada), proveedor, fecha de recepción, fecha de factura, **factura del
  proveedor**, **factura fiscal (CFDI)**, almacén, quién recibió, total
  facturado.
- **Productos recibidos**: por cada línea — producto (nombre + CLV +
  unidad base), presentación capturada, cantidad facturada, cantidad aceptada,
  costo unitario, total de la línea, lote y fecha de caducidad.

En pantallas pequeñas (celular) el diálogo se expande a pantalla completa y
los productos se muestran como **tarjetas apiladas** en vez de tabla
horizontal, para que se lean cómodamente sin scroll lateral.

---

## 7. Servicios de Taller

Catálogo de servicios con **tiempo estándar (minutos)** — estilo agencia. Lo
usa la Orden de Trabajo para estimar el tiempo total del trabajo.

![Servicios de Taller](img/servicios.png)

Ejemplos típicos: *Cambio de aceite* (45 min, Preventivo); *Cambio de balatas*
(60 min, Correctivo). Estos tiempos son los que se usan como referencia en el
tablero de monitoreo para detectar OT en retraso.

**Tarifa de taller externo** (campo opcional). Es lo que cobraría un taller
externo por ese servicio completo (mano de obra). Cuando una OT consuma ese
servicio, el sistema lo usa junto con el `precio de venta` de los productos
para calcular el ahorro vs. cotización externa. Si aún no tiene la cotización,
déjelo en blanco y edítelo cuando la consiga.

---

## 8. Órdenes de Trabajo

Una **Orden de Trabajo (OT)** representa un trabajo de taller sobre un
vehículo.

![Órdenes de Trabajo](img/ordenes-trabajo.png)

### 8.1 Crear una OT

**Nueva OT** → capture:

- **Servicio a cliente externo (no flota TTPN)** — toggle al inicio del
  formulario. Déjelo apagado para OT sobre **camionetas de TTPN**; actívelo
  cuando el trabajo es **para un cliente externo** (entonces se ocultan
  Vehículo y Mantenimiento programado y aparecen *Cliente externo* + *Vehículo
  del cliente (placa/modelo)*).
- **Tipo** — selector con **Correctivo**, **Preventivo** u **Otro**
  (las etiquetas se muestran siempre en español; el sistema las guarda
  internamente como `corrective` / `preventive` / `other`).
- **Mecánico** — un empleado responsable (uno por OT).
- **Vehículo** (solo OT internas, opcional).
- **Cliente externo** (solo OT externas, **obligatorio**).
- **Vehículo del cliente** (texto libre, opcional).
- **Descripción**.
- **Servicios** — uno o varios del catálogo (sección 7). El **tiempo estimado
  total** se calcula como la suma de los tiempos estándar de los servicios
  elegidos.

![Formulario de OT](img/form-ot.png)

> Esta marca alimenta el desglose **Interno (TTPN) vs Externo** en la nueva
> vista [Viabilidad — Servicios del Taller](#12-viabilidad-del-proyecto--servicios-del-taller-por-semana).

### 8.2 Ciclo de vida (Fase 1)

La OT avanza con el botón **Acción** según su estado:

```text
borrador ──activar──▶ activada ──iniciar──▶ en progreso ──completar──▶ completada
                  │                 ▲   │
                  │            reanudar  pausar
                  │                 │   ▼
                  └────cancelar──── pausada
```

- En **Fase 1 la OT la activa el administrador**.
- Al **activar** arranca el reloj; al **completar** se calcula el tiempo real.
- Si el tiempo transcurrido supera el estimado, la OT se marca **en retraso**.

El consumo de refacciones de una OT se hace con una **Salida** tipo *Orden de
Trabajo* (sección 9).

---

## 9. Salidas / consumo

Una **Salida** descuenta producto del inventario. Puede ser:

- **Departamental** — a un área (ej. “Taller Mecánico”).
- **Orden de Trabajo** — consumo asociado a una OT (sección 8).

![Salidas](img/salidas.png)

Pasos: **Nueva Salida** → elija el **Tipo** → destino u OT → agregue
**productos** con la cantidad (en unidad base) → en líquidos puede capturar
**Residuo devuelto** → **Guardar** → **Procesar**.

> **⚠️ Regla de oro de la captura.** Para líquidos, junto a cada campo
> (Cantidad y Residuo) hay un toggle **L / ml**. Captura el número como lo
> ves en el envase y elige la unidad que corresponda; el sistema convierte
> solo a la unidad base interna (litros).
>
> Ejemplo real: entregas **1 L de aceite** y te regresan **355 ml** de
> residuo. Captura `1` en Cantidad con **L** seleccionado, y `355` en
> Residuo con **ml** seleccionado. El hint debajo de Residuo te confirma
> `= 0.355 litro`.
>
> Para sólidos (filtros, repuestos) la unidad es siempre **pieza** y no
> aparece toggle.

### 9.1 Residuo reutilizable de líquidos (costo hundido)

Cuando entrega líquido a una OT y sobra una parte aún utilizable, captúrela
en **Residuo devuelto**. El sistema:

- Regresa ese residuo al inventario como “recuperado” **a costo $0**.
- **No modifica el costo promedio** (no se “ensucia”).
- En el siguiente consumo, **gasta primero el residuo recuperado** (a $0) y
  luego el stock a costo promedio.

#### 9.1.1 Cómo capturar el residuo paso a paso ⭐

**Mantenimiento → Salidas → Nueva Salida** y llene:

1. **Tipo *** = `Orden de Trabajo` (si el residuo viene de consumo de un
   trabajo). Para residuo de un proceso departamental use `Departamental`.
2. **Orden de Trabajo *** = la OT donde se generó el residuo (en el ejemplo,
   `OT-2026-001`).
3. **Motivo** = una descripción corta (ej. *“Cambio de aceite OT”*).
4. En **Productos**, en la línea del producto líquido:
   - **Producto** = el líquido (ej. `AC530 · Aceite Motor 5W-30`).
   - **Cantidad** = la cantidad **total entregada** a la OT, en unidad base
     (ej. **`5`** litros, NO 5 cajas).
   - **Residuo devuelto** = la cantidad **reutilizable** que sobra y vuelve al
     inventario (ej. **`1.5`** litros). Justo debajo de este campo se ve la
     pista `Reutilizable ($0)` — es el indicador de que esa cantidad **no
     toca el costo promedio** (entra al bucket recuperado a $0).
5. **Guardar**. La salida queda en `draft` o `in_progress`.
6. En la lista, use **Procesar** para que el sistema:
   - Descuente del inventario los **5 L** consumidos a costo promedio.
   - Cargue el **`line_cost`** = `5 × costo promedio` al expediente de la OT.
   - Reingrese los **1.5 L** como “recuperado a $0”, **sin alterar** el costo
     promedio.

![Formulario Salida con Residuo devuelto = 1.5 (Reutilizable $0)](img/form-salida-residuo.png)

**⚠️ Cuándo NO capturar residuo.** Captura `Residuo devuelto` solo cuando el
sobrante **se va a reutilizar**. Si el sobrante se desperdició/contaminó,
déjelo en `0` — en ese caso los 5 L se consideran totalmente consumidos.

**💡 Qué pasa en la siguiente salida.** La próxima vez que se consuma del mismo
producto (otra OT u otra área), el sistema **descuenta primero del recuperado**
(a $0) antes de tocar el stock a costo promedio. Se ve como un ahorro en el
`line_cost` de esa nueva salida.

> Ejemplo real (datos demo): se entregaron **5 L** de aceite a una OT y se
> devolvieron **1.5 L** reutilizables. Inventario del aceite: 200 − 5 + 1.5 =
> **196.5 L**, con **1.5 L recuperados a $0** y el costo promedio intacto en
> **$20**.

Esto es intencional y se llama *método de costo hundido*: el costo del líquido
se reconoce completo en la primera salida; el residuo se reaprovecha sin
distorsionar costos ni generar "costos de retorno". Detalle contable en
[`../../Backend/dominio/mantenimiento/costeo_liquidos.md`](../../Backend/dominio/mantenimiento/costeo_liquidos.md).

### 9.2 Ver el detalle de una salida

Click en el renglón (o en el ícono 👁) abre el diálogo de detalle. Incluye:

- **Encabezado**: folio, **tipo** (*Departamental* / *Orden de trabajo*),
  estado (Borrador / Pendiente de aprobación / Aprobada / Completada /
  Cancelada), OT vinculada cuando aplica, fechas de solicitud / aprobación /
  entrega, y los usuarios que **solicitó**, **aprobó** y **entregó**.
- **Productos consumidos**: por línea — producto, cantidades **solicitada /
  aprobada / entregada**, porción **a costo promedio**, porción **recuperada
  $0** (residuo reutilizado), **residuo devuelto** y costo total de la línea.

Igual que en Recepciones, en móvil cada producto se muestra como tarjeta
apilada para evitar scroll lateral.

> **Por qué importa**: el detalle permite auditar de un vistazo qué se cargó
> al taller / OT y cuánto se ahorró gracias a residuo recuperado (líneas en
> verde). La conciliación con el módulo de Finanzas usa estos mismos números.

---

## 10. Tablero de Monitoreo

Vista en vivo de las **OT activas**, estilo agencia. Se actualiza solo (sin
recargar) cuando una OT cambia de estado o tiempo. Cada tarjeta muestra
mecánico, estimado vs. transcurrido, % de avance y alerta de retraso.

![Tablero de Monitoreo](img/tablero-monitoreo.png)

El indicador **En vivo / Desconectado** (arriba a la derecha) muestra si el
tablero está recibiendo actualizaciones en tiempo real.

---

## 11. Estados y permisos

**Recepción:** `draft` → `in_progress` → `completed` / `cancelled`.
**Salida:** `draft` → `pending_approval` → `approved` → `completed` /
`cancelled`.
**Orden de Trabajo:** `draft` → `activated` → `in_progress` → `paused` →
`completed` / `cancelled`.

Los botones de crear, editar, eliminar y **Procesar** aparecen solo si su
usuario tiene el permiso correspondiente para cada módulo de Mantenimiento. Si
no ve una sección o un botón, solicite el permiso al administrador.

---

## 12. Finanzas del Taller — Viabilidad del Proyecto

⭐ **Esta sección es para personal administrativo.** Permite registrar la
inversión inicial del taller y los gastos fijos mensuales para medir cuánto
capital está consumiendo el proyecto y, cuando estén capturados los precios
de referencia, cuánto está ahorrando vs taller externo.

El módulo vive bajo **Finanzas TTPN → Viabilidad de Proyectos** y comparte
estructura con cualquier otro proyecto futuro (Servicio a Terceros,
Capacitación, etc.) — todos se reportan con la misma vista filtrando por
proyecto.

> **Importante sobre el ingreso del taller propio (lectura previa).** El
> taller de TTPN no factura a terceros todavía; sirve a la flota interna.
> Eso significa que **no hay "ingreso" en sentido estricto**. La métrica
> útil hoy es el **burn rate** (capital que estás invirtiendo + gasto fijo
> que estás absorbiendo) y, cuando los productos tengan **Precio de venta**
> (sección 5) y los servicios tengan **Tarifa de taller externo**
> (sección 7), el sistema podrá calcular el **ahorro estimado** por OT
> interna (lo que TTPN se habría gastado en taller externo, menos el costo
> real). Hasta que esos datos existan, el dashboard solo muestra burn rate
> y deja en cero el indicador de ingreso/ROI.

### 12.1 Concepto del módulo

Tres entidades:

1. **Proyecto** — La "bolsa" donde se acumulan los movimientos del Taller.
   Ya viene creado por defecto como **Taller Mecánico TTPN** con la marca
   "Manual" (sin revenue automático todavía). Cuando el sistema pueda
   calcular ahorro estimado (requiere precio de venta en productos y tarifa
   externa en servicios), se cambiará la marca a "Ahorro interno" para que
   el dashboard lo sume automáticamente.
2. **Concepto** — La plantilla del movimiento: *"Luz"*, *"Renta del local"*,
   *"Compra de compresor"*. Se da de alta una sola vez y se reusa cada mes.
3. **Movimiento** — El valor real de la factura del mes para un concepto
   (la luz de enero costó $1,480; la de febrero $1,620). Un concepto
   recurrente acumula un movimiento por mes.

### 12.2 Tipos de movimiento

| Tipo | Cuándo usar | Ejemplo |
| --- | --- | --- |
| **Inversión** | Compras one-time del arranque o expansión | Compra del compresor, juego de herramientas |
| **Gasto fijo** | Costo recurrente (mensual/trimestral/anual), aunque el monto varíe | Renta, luz, agua, internet, salarios |
| **Ingreso** | Cobros manuales (cuando arranque servicio a terceros) | Factura a flotilla externa |

> **Nota:** No captures aquí compras de aceite o refacciones — esas van en
> **Recepciones** (sección 6). El ingreso por OTs del taller se calcula
> solo, no se captura.

### 12.3 Dar de alta el proyecto del taller

El proyecto **Taller Mecánico TTPN** ya está creado. Para verlo o editarlo:
**Finanzas TTPN → Proyectos**.

![Listado de proyectos](img/finanzas/01-proyectos-listado.png)

Si necesita crear un proyecto adicional (ej. *Servicio a Terceros*),
**Nuevo Proyecto** y llene:

| Campo | Qué poner |
| --- | --- |
| Nombre | Nombre descriptivo (ej. *"Servicio a Terceros"*) |
| Slug | Se autogenera del nombre; déjelo en blanco al crear |
| Descripción | Para qué es el proyecto |
| Fecha inicio | Cuándo arrancó (clave para medir ROI desde el día 1) |
| Revenue automático | **Manual** mientras no se cierren cotizaciones externas · cambiará a "ahorro interno" cuando productos y servicios tengan precio de referencia |
| Proyecto activo | Déjelo encendido |

![Formulario Nuevo Proyecto](img/finanzas/02-proyecto-form.png)

> **Sobre "Revenue automático":** hoy el taller TTPN está en **Manual** —
> el dashboard no infla el ingreso con el costo del material ya pagado.
> Cuando se conecte el ahorro automático (sale_price + external_rate),
> solo UN proyecto por unidad de negocio puede tener esa marca para evitar
> doble conteo.

### 12.4 Dar de alta los conceptos del taller

**Mantenimiento → Finanzas TTPN → Viabilidad de Proyectos →** elija el
proyecto en el selector superior → tab **Conceptos**.

![Tab Conceptos](img/finanzas/04-conceptos.png)

Use **Nuevo concepto** para cada concepto del taller. Lo recomendado para
arrancar:

| Concepto | Tipo | Frecuencia | Monto sugerido |
| --- | --- | --- | --- |
| Compra de compresor industrial | Inversión | Una sola vez | costo real |
| Herramientas y juego inicial | Inversión | Una sola vez | costo real |
| Renta del local | Gasto fijo | Mensual | renta mensual |
| Luz | Gasto fijo | Mensual | promedio (sirve solo de sugerencia) |
| Agua | Gasto fijo | Mensual | promedio |
| Internet | Gasto fijo | Mensual | tarifa |
| Servicio a terceros | Ingreso | Mensual | déjelo en 0 hasta que arranque |

![Formulario Nuevo Concepto](img/finanzas/05-concepto-form.png)

Campos importantes:

- **Tipo** y **Frecuencia** definen cómo se cataloga (no automatiza nada
  — la frecuencia es informativa).
- **Monto sugerido** prellena el campo Monto cuando captura el movimiento
  del mes; siempre puede sobrescribirlo con el monto real de la factura.
- **Proveedor** se vincula al catálogo de proveedores TTPN (útil para
  agrupar gasto por proveedor).
- **Activo**: desactive un concepto que ya no aplica (ej. *"Renta vieja"*).
  Los inactivos no aparecen en el dropdown del Movimiento.

> **Regla:** Un mismo concepto no puede tener dos movimientos del mismo
> mes (no puedes capturar *"Luz de Enero 2026"* dos veces). Si te
> equivocaste, **edita** el movimiento existente en lugar de crear otro.

### 12.5 Capturar movimientos cada mes

Tab **Movimientos** → **Nuevo movimiento**.

![Tab Movimientos](img/finanzas/06-movimientos.png)

Cada vez que llega una factura (luz de junio, renta de junio, etc.):

1. **Concepto** — Seleccione el concepto al que pertenece la factura.
   El sistema prellena el Monto con el valor sugerido del concepto.
2. **Fecha** — La fecha de la factura. El periodo (YYYY-MM) se deriva
   automáticamente para agrupar movimientos.
3. **Monto** — El monto **real** que pagó este mes (no el sugerido).
4. **Factura** (opcional) — Número de folio para trazabilidad.
5. **Notas** (opcional) — Cualquier comentario contextual.

![Formulario Nuevo Movimiento](img/finanzas/07-movimiento-form.png)

> Para **inversiones one-time**, simplemente capture un solo movimiento
> con la fecha y monto real de la compra. No necesita repetirlo cada mes.

#### Filtro por periodo

Arriba del listado de Movimientos hay un campo **Periodo (YYYY-MM)** para
filtrar solo los del mes que quiera revisar (ej. `2026-03` muestra los
movimientos de marzo).

### 12.6 Cómo leer el Dashboard

Tab **Dashboard**. Arriba está el **selector de rango de fechas** estilo
calendario: pique la fecha de inicio y luego la de fin para definir el
rango. Es **día a día** — puede analizar una quincena, un mes, un
trimestre o varios años de un solo tirón. Antes era un *input* con formato
`YYYY-MM`; ahora es un calendario visual. El rango elegido alimenta todos
los tabs (Dashboard, Conceptos, Movimientos y Servicios del Taller).

Por defecto el rango es **desde el 1° de enero del año en curso hasta hoy**.

![Dashboard con datos reales](img/finanzas/03-dashboard.png)

#### Las 4 tarjetas (KPIs)

| Tarjeta | Qué significa | Cómo interpretar |
| --- | --- | --- |
| **Inversión** | Suma de todos los movimientos de tipo Inversión desde siempre | Lo que "metió" al proyecto. No depende del rango — siempre es lifetime. |
| **Gasto fijo (rango)** | Σ gastos fijos del periodo seleccionado · debajo: lifetime | Cuánto le cuesta operar al taller en ese rango. El "lifetime" abajo es desde el día uno. |
| **Ingreso (rango)** | Σ ingresos manuales del rango · debajo: lifetime. **HOY: $0** porque el taller no factura a terceros y aún no se conecta el ahorro automático. | Cuando exista, mostrará el ahorro vs taller externo o las facturas a clientes externos. |
| **Neto lifetime** | Ingreso − Inversión − Gasto fijo (todo lifetime). ROI% = neto/inversión × 100 | Hoy aparecerá **rojo** porque solo hay egresos. Es **normal**: estás en fase de inversión + burn rate, no en operación con ingreso. |

En el ejemplo de la captura: invertimos **$53,500**, llevamos
**$74,280** de gasto fijo y solo **$340** de ingreso (las OTs apenas
arrancaron). Neto −$127,440 · ROI −238%. Eso es **normal en taller nuevo**:
todavía está en fase de inversión y costo fijo, antes del break-even.

#### Gráfica "Serie mensual"

Muestra mes a mes:

- **Línea verde** = ingreso (manual + automático de OTs)
- **Línea amarilla** = gasto fijo
- **Línea morada** = inversión (típicamente pico en los primeros meses)

Para que el proyecto sea viable, la línea verde debe crecer hasta cruzar
y superar a la amarilla, y los picos morados deben recuperarse.

#### Desglose por concepto (rango)

Tabla al final del dashboard. Lista cada concepto que tuvo movimientos en
el rango con su total. Sirve para detectar:

- Qué gasto fijo está pesando más (¿la luz subió mucho?).
- Cuál fue el desglose de la inversión inicial.
- Qué fuentes están aportando ingreso.

#### Indicador de Break-even

Debajo de las tablas aparece uno de estos mensajes:

- 🎉 **"Break-even alcanzado en YYYY-MM"** — el ingreso acumulado superó
  inversión + gasto fijo en ese mes. A partir de ahí, todo lo que entra
  es utilidad real.
- *"Aún no se ha alcanzado el break-even del proyecto en el rango
  analizado."* — el taller sigue absorbiendo capital. Normal en los
  primeros meses.

### 12.7 Buenas prácticas

1. **Capture la factura el mismo día que llega.** Evita que se acumulen.
2. **Use el monto real, no el sugerido.** El monto sugerido es solo una
   ayuda de captura.
3. **Revise el dashboard al cierre del mes.** Es cuando se ve si los
   gastos están bajo control o si hay un servicio que se disparó.
4. **No edite movimientos viejos sin nota.** Si necesita ajustar el monto
   de la luz de febrero, agregue en "Notas" el motivo (*"corrección por
   recargos no facturados"*).
5. **Cuando arranque a facturar terceros**, cambie el concepto *"Servicio
   a terceros"* a `Ingreso` activo y capture el monto al cobrar cada
   servicio. Los ingresos automáticos de OTs internas siguen sumando aparte.

### 12.8 Operación del taller en el Dashboard

Cuando el proyecto seleccionado tiene `auto_revenue_source = mtto_*`
(taller), debajo de las KPIs financieras aparece el panel **Operación
del taller** con 5 widgets más:

1. **Vehículos atendidos por semana** — gráfica de barras (semanas ISO en X,
   cantidad de unidades distintas atendidas en Y). Solo vehículos de la
   **flota TTPN** (no clientes externos).
2. **Servicios más solicitados** — top 5 del rango: nombre del servicio +
   cuántas OT lo incluyeron.
3. **Servicios por vehículo** — top 10 de la flota: vehículo (CLV · placa)
   y total de servicios recibidos.
4. **Horas y servicios por mecánico** — horas reales (derivadas de
   `activated_at → completed_at`), OTs cerradas y total de servicios
   prestados, ordenado por horas descendente. Incluye OTs internas y
   externas.
5. **Mayor atraso** — top 10 OTs donde el tiempo real superó al estimado:
   muestra OT, vehículo/cliente, mecánico, estimado, real, exceso en
   minutos y porcentaje. Sirve para detectar trabajos que sistemáticamente
   se pasan del tiempo estándar.

**Tiempo real sin polling**: el panel se calcula en el servidor con un
script Python especializado (`scripts/mtto/workshop_ops_kpis.py`) y el
resultado llega por WebSocket cuando el job termina. Esto permite manejar
rangos de 1+ año sin saturar la memoria del navegador ni del API. Si tarda
un par de segundos en aparecer es **normal** — está procesando agregaciones
en Postgres.

### 12.9 Texto en español en todas las listas

Los enums internos del sistema (`completed`, `in_progress`, `corrective`,
`monthly`, `weekly`, etc.) se almacenan en inglés en la base de datos pero
**siempre se muestran traducidos** en la interfaz:

| Concepto | Cómo lo ve el usuario |
| --- | --- |
| Estado OT | Borrador · Activada · En progreso · En pausa · Completada · Cancelada |
| Tipo OT | Correctivo · Preventivo · Otro |
| Estado Salida | Borrador · Pendiente de aprobación · Aprobada · Completada · Cancelada |
| Tipo Salida | Departamental · Orden de trabajo |
| Estado Recepción | Borrador · En proceso · Completada · Cancelada |
| Frecuencia Conceptos | Una sola vez · Diaria · Semanal · Mensual · Bimestral · Trimestral · Semestral · Anual |
| Tipo Concepto | Inversión · Gasto fijo · Ingreso |
| Movimiento Inventario | Entrada (recepción) · Salida (consumo) · Devolución de residuo · Ajuste · Merma / daño |

La traducción vive en un solo lugar (`src/utils/enumLabels.js`) para evitar
inconsistencias entre pantallas.

---

## 12. Viabilidad del Proyecto — Servicios del Taller por semana

Vista de análisis para entender el flujo del taller: **cuántos servicios se
dieron por semana**, separados entre flota **interna TTPN** y trabajos a
**clientes externos**, desglosados por tipo de servicio del catálogo, con
expansión por fila para ver productos consumidos + costo promedio. Vive como
tab dentro de **Finanzas → Viabilidad de Proyectos → Servicios del Taller**.

### 12.1 Cómo se alimenta la vista

- Solo cuentan OTs con `status = completed` en el rango de fechas elegido.
- La separación interno/externo viene del toggle **Servicio a cliente externo**
  del formulario de OT (sección 8).
- Los productos vienen de las Salidas (sección 9) procesadas contra la OT.

### 12.2 Cómo leer la tabla

- **Sección Interno (Flota TTPN, azul)**: filas por servicio del catálogo,
  columnas por semana ISO (`Sem 20/2026` = semana 20 del 2026). Cada celda es
  cuántas OT internas incluyeron ese servicio esa semana. Expandir la fila
  muestra los productos consumidos y su **costo promedio** por semana.
- **Sección Externo (Clientes, naranja)**: misma estructura, pero al expandir
  cada producto muestra además **ingreso** (`cantidad × precio de venta`) y
  **profit** (`ingreso − costo`). Esto refleja la ganancia del taller al
  servir a clientes externos.
- **Toggle Servicios / Productos** en la cabecera: cambia el desglose entre
  "por servicio del catálogo" (default) y "por producto consumido".

### 12.3 Filtros

- **Desde / Hasta**: rango de fechas. Por defecto las **últimas 8 semanas**.
- **Refrescar**: recarga los datos contra el endpoint.

### 12.4 Reglas de negocio importantes

1. Una OT cuenta una sola vez por semana en `total_per_week`, aunque incluya
   varios servicios.
2. Si una OT cubre varios servicios (ej. *cambio de aceite* + *balatas*) y
   consume aceite + balatas, los productos aparecen bajo **ambos** servicios
   en el desglose. Esto es una simplificación: el modelo no asocia un producto
   a un servicio específico dentro de la OT.
3. Para externos, `precio de venta` se toma de **Producto.sale_price** y
   `external_rate` del catálogo de **Servicios** (visible en cada catálogo).
   Si están en `$0`, la columna **profit** mostrará valores negativos (señal
   de capturar el precio de venta).
4. `costo promedio` es el `unit_cost_charged` con el que se procesó la salida.

---

### Documentos relacionados

- Esquema de datos: [`../../Backend/dominio/mantenimiento/schema.sql`](../../Backend/dominio/mantenimiento/schema.sql)
- Modelo de costo de líquidos: [`../../Backend/dominio/mantenimiento/costeo_liquidos.md`](../../Backend/dominio/mantenimiento/costeo_liquidos.md)
- Endpoints API: [`../../Backend/dominio/mantenimiento/controller/endpoints.md`](../../Backend/dominio/mantenimiento/controller/endpoints.md)
- Módulo Finanzas / Viabilidad: [`../../Backend/dominio/finanzas/viabilidad/viabilidad_proyectos.md`](../../Backend/dominio/finanzas/viabilidad/viabilidad_proyectos.md)
