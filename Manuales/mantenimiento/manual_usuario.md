# Manual de Usuario — Módulo de Mantenimiento (Control de Inventario de Taller)

Kumi by TTPN · Versión 1 (Fase 1) · Mayo 2026

Este manual explica, paso a paso, cómo operar el módulo de **Mantenimiento**:
catálogos, recepción de producto, inventario, salidas/consumo y Órdenes de
Trabajo. Las capturas son de la aplicación real con datos de ejemplo.

> 🔑 **Lo más importante de leer:** la sección
> [4. Recepción de producto: pieza vs. líquido](#4-recepción-de-producto-pieza-vs-líquido).
> Ahí se explica la diferencia clave al recibir un producto que se cuenta por
> **pieza** y uno que es **líquido**.

---

## Índice

1. [Acceso y navegación](#1-acceso-y-navegación)
2. [Conceptos clave (leer antes de capturar)](#2-conceptos-clave)
3. [Catálogos](#3-catálogos)
4. [Recepción de producto: pieza vs. líquido](#4-recepción-de-producto-pieza-vs-líquido) ⭐
5. [Inventario y costo promedio](#5-inventario-y-costo-promedio)
6. [Salidas / consumo (y residuo de líquidos)](#6-salidas--consumo)
7. [Órdenes de Trabajo](#7-órdenes-de-trabajo)
8. [Tablero de Monitoreo](#8-tablero-de-monitoreo)
9. [Estados y permisos](#9-estados-y-permisos)

---

## 1. Acceso y navegación

Inicie sesión con su usuario y contraseña. En el menú lateral abra el grupo
**Mantenimiento**. Verá las secciones del módulo:

- **Productos** — catálogo de artículos de inventario.
- **Categorías** — agrupación de productos (Lubricantes, Filtros, etc.).
- **Presentaciones** — cómo se compra cada producto (pieza, caja, tambor…).
- **Servicios de Taller** — catálogo de servicios con tiempo estándar.
- **Recepciones** — entrada de producto al inventario.
- **Salidas** — consumo de producto (a un área o a una Orden de Trabajo).
- **Órdenes de Trabajo** — trabajos de taller y su seguimiento.
- **Tablero de Monitoreo** — OT activas en vivo.

![Menú de Mantenimiento](img/00-menu.png)

El acceso a cada sección depende de sus permisos (ver
[sección 9](#9-estados-y-permisos)).

---

## 2. Conceptos clave

Antes de capturar conviene entender 4 conceptos:

| Concepto | Qué es |
|---|---|
| **Unidad base** | La unidad en la que el sistema **guarda y consume** el producto (ej. *pieza* para un filtro, *litro* para un aceite). Se define en el producto. |
| **Presentación** | Cómo se **compra** el producto al proveedor (ej. *Caja x12*, *Tambor 200 L*). Cada presentación indica **cuántas unidades base trae**. |
| **Costo promedio móvil** | El costo unitario del producto se recalcula automáticamente en cada recepción, ponderando lo que ya había con lo que entra. |
| **Residuo reutilizable (costo hundido)** | En líquidos, lo que sobra de un consumo y aún sirve regresa al inventario **a costo $0**, para no ensuciar el costo promedio. |

👉 La **Presentación** es el puente entre *cómo compro* y *cómo consumo*. Es lo
que hace que recibir “1 caja” sume “12 piezas”, o recibir “1 tambor” sume
“200 litros”.

---

## 3. Catálogos

### 3.1 Categorías

Agrupan los productos. Use **Nueva Categoría**, capture *Nombre* y *Código*
(LUBR, FILT…). Puede desactivarlas sin borrarlas.

![Categorías](img/categorias.png)

### 3.2 Presentaciones

Define las formas de compra. El campo más importante es **Unidades base que
trae**:

- `Pieza` → **1** unidad base (para productos por pieza).
- `Caja x12` → **12** unidades base.
- `Tambor 200 L` → **200** unidades base (para líquidos en litros).

![Presentaciones](img/presentaciones.png)

> Cree una presentación por cada forma real de comprar. El sistema usará
> *Unidades base* para convertir automáticamente en la recepción.

### 3.3 Productos

Catálogo de artículos. Al crear/editar un producto:

- **Categoría**, **Nombre**.
- **SKU** — clave formal del producto.
- **Clave taller** — clave corta de uso rápido en taller (distinta del SKU).
- **Unidad base** — *seleccionable de una lista* (pieza, litro, mililitro,
  kilogramo, caja, …) o puede escribir una nueva. **Esta es la unidad en la que
  vivirá el inventario y se consumirá.**
- **Mín./Máx./Reorden/Lead time** — umbrales para alertas de stock.

![Formulario de Producto — Unidad base seleccionable](img/form-producto.png)

La lista muestra disponible, costo promedio y estado de stock
(OK / REORDER / OUT_OF_STOCK / OVERSTOCK):

![Productos](img/productos.png)

> Ejemplo real de la imagen:
> **FA01 · Filtro de Aire** (unidad base *pieza*) y
> **AC530 · Aceite Motor 5W-30** (unidad base *litro*).

### 3.4 Servicios de Taller

Catálogo de servicios con **tiempo estándar (minutos)** — estilo agencia. Lo usa
la Orden de Trabajo para estimar el tiempo total del trabajo.

![Servicios de Taller](img/servicios.png)

---

## 4. Recepción de producto: pieza vs. líquido

⭐ **Esta es la sección clave.** Recibir producto siempre sigue los mismos
pasos; la diferencia entre un producto **por pieza** y uno **líquido** está
únicamente en la **Presentación** que elija, porque ella define la conversión a
unidad base.

### Pasos generales

1. Entre a **Recepciones → Nueva Recepción**.
2. Seleccione el **Proveedor**, capture **Factura** y **Ubicación de almacén**.
3. Por cada producto, **Agregar línea**:
   - **Producto**
   - **Presentación** ← *aquí está la diferencia pieza vs. líquido*
   - **Cant.** (en presentaciones, no en unidad base)
   - **Costo unit.** (costo de **una presentación**)
   - **Aceptado** (cuántas presentaciones se aceptan tras revisión)
4. **Guardar**. La recepción queda en estado `in_progress`.
5. En la lista, use **Procesar** para que entre al inventario.

![Formulario de Recepción](img/form-recepcion.png)

![Recepciones — Procesar](img/recepciones.png)

> Sólo al **Procesar** se afecta el inventario y se recalcula el costo
> promedio. Mientras está `in_progress` aún puede corregirla.

### 4.1 Caso A — Producto por **PIEZA** (ej. Filtro de Aire)

Se compran **5 cajas** y cada caja trae **12 piezas**.

| Campo | Valor a capturar |
|---|---|
| Producto | Filtro de Aire (unidad base = *pieza*) |
| Presentación | **Caja x12** (12 unidades base) |
| Cant. | **5** (cajas) |
| Costo unit. | **$1,440** (por caja) |
| Aceptado | **5** |

Al **Procesar**, el sistema convierte:

```
5 cajas × 12 piezas = 60 piezas entran al inventario
costo por pieza = $1,440 / 12 = $120
```

Resultado: el Filtro queda con **60 piezas** disponibles y **costo promedio
$120**. (En la captura de Productos aparece con 58, porque ya se consumieron 2
en una salida — ver sección 6.)

### 4.2 Caso B — Producto **LÍQUIDO** (ej. Aceite Motor 5W-30)

Se compra **1 tambor** que trae **200 litros**.

| Campo | Valor a capturar |
|---|---|
| Producto | Aceite Motor 5W-30 (unidad base = *litro*) |
| Presentación | **Tambor 200 L** (200 unidades base) |
| Cant. | **1** (tambor) |
| Costo unit. | **$4,000** (por tambor) |
| Aceptado | **1** |

Al **Procesar**, el sistema convierte:

```
1 tambor × 200 litros = 200 litros entran al inventario
costo por litro = $4,000 / 200 = $20
```

Resultado: el Aceite queda con **200 litros** disponibles y **costo promedio
$20 por litro**.

### 4.2.1 Varias presentaciones del mismo líquido (caso real)

Es común recibir el mismo aceite en formatos distintos: a veces en **galones
empacados en caja**, a veces en **litros sueltos por caja**. Cada combinación
real es **una Presentación distinta** en el catálogo, y su `Unidades base` es
**el total de unidad base que trae la caja completa**. Como `Unidades base`
acepta decimales, los envases fraccionarios (4.9 L, 0.946 L, etc.) funcionan
sin problema.

**Ejemplo**: Aceite Motor 5W-30 (unidad base = *litro*) recibido en dos formas:

| Presentación a crear | Unidades base | Cálculo |
| --- | --- | --- |
| Caja 6 galones 4.9 L | 29.4 | 6 envases × 4.9 L |
| Caja 24 litros | 24 | 24 envases × 1 L |

> Cree una presentación por cada formato real. El catálogo de presentaciones
> es libre y por unidad de negocio; no se mezclan entre productos.

**Captura de cada recepción:**

| Recepción | Presentación | Cant. | Costo unit. (la caja) | El sistema suma |
| --- | --- | --- | --- | --- |
| A | Caja 6 galones 4.9 L | 1 | $1,470 | 29.4 L a $50/L |
| B | Caja 24 litros | 1 | $1,320 | 24 L a $55/L |

> Recuerde: `Cant.` es **cuántas cajas** recibe, no litros. El `Costo unit.` es
> el costo **de una caja**. La conversión a litros y a costo por litro la hace
> el sistema usando *Unidades base* de la presentación.

**Costo promedio resultante** (móvil ponderado por unidad base):

```
costo por litro de A = $1,470 / 29.4 = $50.00
costo por litro de B = $1,320 / 24   = $55.00

promedio combinado  = (29.4·$50 + 24·$55) / (29.4 + 24)
                    = (1,470 + 1,320) / 53.4
                    = $52.25 por litro
```

Al consumir, el costo cargado es el promedio vigente (sección 6), sin importar
de qué caja salió el aceite.

> 💡 **Cuándo crear más presentaciones**: si a veces compra **galones sueltos**
> (sin caja) o **litros sueltos**, cree también `Galón 4.9 L` (base 4.9) y
> `Litro` (base 1). Cada forma de comprar = una presentación.

### 4.3 Regla de oro

> **Usted siempre captura en PRESENTACIONES (cajas, tambores, piezas) y a costo
> de la presentación. El sistema convierte solo a la unidad base usando la
> Presentación.** Por eso es indispensable que la *Presentación* tenga bien
> capturadas sus **Unidades base** (sección 3.2).

Si recibe el mismo líquido otra vez a otro precio (ej. otro tambor a $5,000),
el costo promedio se **recalcula ponderado**:

```
(200 L × $20  +  200 L × $25)  /  400 L  =  $22.50 por litro
```

---

## 5. Inventario y costo promedio

El inventario se actualiza **solo** mediante Recepciones (entradas) y Salidas
(consumos) procesadas — nunca se edita a mano. Cada producto muestra:

- **Disponible** = en mano + recuperado − reservado.
- **Costo prom.** = costo promedio móvil por unidad base.
- **Estado** = OK / REORDER (≤ mínimo) / OVERSTOCK (≥ máximo) / OUT_OF_STOCK.

Todo movimiento queda en un **libro auditable** (no se puede editar ni borrar):
entradas, salidas y devoluciones de residuo.

---

## 6. Salidas / consumo

Una **Salida** descuenta producto del inventario. Puede ser:

- **Departamental** — a un área (ej. “Taller Mecánico”).
- **Orden de Trabajo** — consumo asociado a una OT.

![Salidas](img/salidas.png)

Pasos: **Nueva Salida** → elija el **Tipo** (Departamental u Orden de Trabajo)
→ destino u OT → agregue **productos** con la cantidad (en unidad base) → en
líquidos puede capturar **Residuo devuelto** → **Guardar** → **Procesar**.

### 6.1 Residuo reutilizable de líquidos (costo hundido)

Cuando entrega líquido a una OT y sobra una parte aún utilizable, captúrela en
**Residuo devuelto**. El sistema:

- Regresa ese residuo al inventario como “recuperado” **a costo $0**.
- **No modifica el costo promedio** (no se “ensucia”).
- En el siguiente consumo, **gasta primero el residuo recuperado** (a $0) y
  luego el stock a costo promedio.

> Ejemplo real (datos de la demo): se entregaron **5 L** de aceite a la OT y se
> devolvieron **1.5 L** reutilizables. Inventario del aceite: 200 − 5 + 1.5 =
> **196.5 L**, con **1.5 L recuperados a $0** y el costo promedio intacto en
> **$20**.

Esto es intencional y se llama *método de costo hundido*: el costo del líquido
se reconoce completo en la primera salida; el residuo se reaprovecha sin
distorsionar costos ni generar “costos de retorno”. (Detalle contable en
[`../../Backend/dominio/mantenimiento/costeo_liquidos.md`](../../Backend/dominio/mantenimiento/costeo_liquidos.md).)

---

## 7. Órdenes de Trabajo

Una **Orden de Trabajo (OT)** representa un trabajo de taller sobre un vehículo.

![Órdenes de Trabajo](img/ordenes-trabajo.png)

### 7.1 Crear una OT

**Nueva OT** → capture:

- **Tipo** (preventivo / correctivo / otro).
- **Mecánico** — un empleado responsable (uno por OT).
- **Vehículo** (opcional).
- **Descripción**.
- **Servicios** — uno o varios del catálogo. El **tiempo estimado total** se
  calcula como la suma de los tiempos estándar de los servicios elegidos.

![Formulario de OT](img/form-ot.png)

### 7.2 Ciclo de vida (Fase 1)

La OT avanza con el botón **Acción** según su estado:

```
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
Trabajo* (sección 6).

---

## 8. Tablero de Monitoreo

Vista en vivo de las **OT activas**, estilo agencia. Se actualiza solo (sin
recargar) cuando una OT cambia de estado o tiempo. Cada tarjeta muestra
mecánico, estimado vs. transcurrido, % de avance y alerta de retraso.

![Tablero de Monitoreo](img/tablero-monitoreo.png)

El indicador **En vivo / Desconectado** (arriba a la derecha) muestra si el
tablero está recibiendo actualizaciones en tiempo real.

---

## 9. Estados y permisos

**Recepción:** `draft` → `in_progress` → `completed` / `cancelled`.
**Salida:** `draft` → `pending_approval` → `approved` → `completed` /
`cancelled`.
**Orden de Trabajo:** `draft` → `activated` → `in_progress` → `paused` →
`completed` / `cancelled`.

Los botones de crear, editar, eliminar y **Procesar** aparecen solo si su
usuario tiene el permiso correspondiente para cada módulo de Mantenimiento. Si
no ve una sección o un botón, solicite el permiso al administrador.

---

### Documentos relacionados

- Esquema de datos: [`../../Backend/dominio/mantenimiento/schema.sql`](../../Backend/dominio/mantenimiento/schema.sql)
- Modelo de costo de líquidos: [`../../Backend/dominio/mantenimiento/costeo_liquidos.md`](../../Backend/dominio/mantenimiento/costeo_liquidos.md)
- Endpoints API: [`../../Backend/dominio/mantenimiento/controller/endpoints.md`](../../Backend/dominio/mantenimiento/controller/endpoints.md)
