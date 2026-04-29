# Refactor: DashboardPage.vue

**Archivo actual:** `pages/Dashboard/DashboardPage.vue` — 1,473 líneas
**Problema:** Todo en un solo archivo: lógica de período, carga async con polling, 5 gráficos, matriz expandible, exportación y estilos.

---

## Diagnóstico del archivo actual

| Bloque | Líneas aprox. | Responsabilidad |
|---|---|---|
| Header + Tabs | 1–61 | Título, botones, tabs |
| Period Panel | 62–221 | Selector de fechas, atajos, comparativa |
| KPI Cards | 223–256 | 4 tarjetas de resumen |
| Trend Chart | 258–295 | Gráfico de barras/línea/área por mes |
| Donut Charts | 297–330 | Distribución por tipo de vehículo |
| Compare Bar | 368–389 | Gráfico solo cuando hay comparativa activa |
| Top Clients Chart | 391–425 | Horizontal bar top 10/20/todos |
| Matrix Table | 427–565 | Tabla expandible Cliente × Mes × Tipo |
| Export Dialog | 333–365 | Diálogo de progreso de exportación |
| **Script — estado + computeds** | 598–1374 | ~776 líneas de lógica mezclada |
| **CSS** | 1377–1474 | ~100 líneas de estilos |

---

## Propuesta de estructura

```
src/
├── pages/Dashboard/
│   ├── DashboardPage.vue              ← orquestador (~120 líneas)
│   └── tabs/
│       ├── DashboardRevenueTab.vue    ← tab activo hoy (~80 líneas)
│       ├── DashboardTtpnsTab.vue      ← futuro (TTPNs operativos)
│       └── DashboardFuelTab.vue       ← futuro (rendimiento combustible)
│
├── components/Dashboard/
│   ├── DashboardPeriodPanel.vue       ← selector de fechas + atajos
│   ├── DashboardKpiCards.vue          ← 4 tarjetas con deltas
│   ├── DashboardTrendChart.vue        ← gráfico principal bar/line/area
│   ├── DashboardDistributionChart.vue ← donut principal + donut comparativa
│   ├── DashboardCompareChart.vue      ← barras lado a lado (solo si compareMode)
│   ├── DashboardTopClientsChart.vue   ← horizontal bar top clientes
│   ├── DashboardMatrixTable.vue       ← tabla expandible Cliente × Mes × Tipo
│   └── DashboardExportDialog.vue      ← diálogo de progreso de exportación
│
└── composables/Dashboard/
    ├── useDashboardPeriod.js          ← estado de período + lógica de atajos
    ├── useDashboardData.js            ← carga async, polling, matrix builder
    └── useDashboardExport.js          ← exportación async + polling + descarga
```

---

## Detalle de cada pieza

### `useDashboardPeriod.js`
Todo lo que hoy está mezclado entre líneas 634–776.

```js
// Expone:
return {
  period,           // { from, to }
  compareMode,      // 'none' | 'prev_year' | 'custom'
  comparePeriod,    // { from, to } solo cuando mode === 'custom'
  activeShortcut,
  displayMode,      // 'trips' | 'money'
  shortcuts,
  periodDays,
  periodLabel,
  visibleMonths,
  effectiveComparePeriod,
  compareModeLabel,
  applyShortcut,
  formatDateLabel,
  formatValue,
}
```

**Por qué separarlo:** Este composable no tiene dependencia del DOM ni de la API. Se puede testear de forma aislada y reutilizar en futuros tabs (Capture, Fuel) que usarán el mismo selector de período.

---

### `useDashboardData.js`
Carga async con polling + construcción de la matriz (líneas 778–1300).

```js
// Expone:
return {
  apiRows,           // datos del período principal (raw)
  apiCompareRows,    // datos del período comparativo (raw)
  loading,
  loadProgress,
  lastUpdated,
  matrixData,        // computed: buildMatrixFromApiRows(apiRows)
  compareMatrixData, // computed: buildMatrixFromApiRows(apiCompareRows)
  columnTotals,
  annualTotals,
  grandTotalAll,
  compareAnnualTotals,
  compareGrandTotal,
  loadData,          // recibe { from, to, compare_from?, compare_to? }
}
```

**Por qué separarlo:** La función `buildMatrixFromApiRows` es la más compleja del archivo (~60 líneas). Al aislarla en un composable, los futuros tabs de Capture y Fuel pueden reutilizar el mismo patrón de polling sin duplicar código.

---

### `useDashboardExport.js`
Todo el bloque de exportación (líneas 1302–1372).

```js
// Expone:
return {
  exporting,
  exportDialog,
  exportProgress,
  exportMessage,
  exportStatus,
  startExport,   // recibe { from, to, compare_from?, compare_to? }
}
```

**Por qué separarlo:** La lógica de polling es idéntica a la de carga de datos pero con estado independiente. Al separarlo, `DashboardExportDialog.vue` solo recibe props y emite eventos; no necesita conocer la URL de la API.

---

### `DashboardPeriodPanel.vue`
Recibe los valores del composable como props y emite eventos. No maneja estado internamente.

```
props: period, compareMode, comparePeriod, activeShortcut, shortcuts,
       displayMode, compareModeLabel, effectiveComparePeriod, loading
emits: update:period, update:compareMode, update:comparePeriod,
       update:displayMode, apply, shortcut-click
```

---

### `DashboardKpiCards.vue`
Puramente presentacional. Recibe los totales calculados.

```
props: annualTotals, compareAnnualTotals, grandTotalAll, compareGrandTotal,
       compareMode, displayMode, periodLabel, formatValue
```

---

### `DashboardTrendChart.vue`
Gráfico con toggle bar/line/area. La lógica de `trendChartSeries` y `trendChartOptions` (~100 líneas) vive aquí.

```
props: columnTotals, compareMatrixData, visibleMonths, compareMode,
       effectiveComparePeriod, vehicleTypes, displayMode
```

---

### `DashboardMatrixTable.vue`
La pieza más independiente y más larga del template (~140 líneas de HTML + CSS de la tabla). Toda la lógica de `expandedClients`, `tableSearch`, `filteredMatrixData`, `toggleClient`, `expandAll`, `collapseAll`, `getCellClass` vive aquí.

```
props: matrixData, visibleMonths, vehicleTypes, displayMode
```

---

### `DashboardRevenueTab.vue`
Orquesta los componentes del tab activo. Recibe todo del composable padre y distribuye a cada componente.

```vue
<template>
  <DashboardPeriodPanel ... />
  <DashboardKpiCards ... />
  <div class="row">
    <DashboardTrendChart class="col-lg-8" ... />
    <DashboardDistributionChart class="col-lg-4" ... />
  </div>
  <DashboardCompareChart v-if="compareMode !== 'none'" ... />
  <DashboardTopClientsChart ... />
  <DashboardMatrixTable ... />
</template>
```

---

### `DashboardPage.vue` resultante (~120 líneas)
Solo maneja: header, tabs, botones globales (Actualizar / Exportar), y ensambla el tab activo.

```vue
<script setup>
const period   = useDashboardPeriod()
const data     = useDashboardData()
const exporter = useDashboardExport()

function onApply() {
  data.loadData({
    from: period.period.value.from,
    to:   period.period.value.to,
    compare_from: period.effectiveComparePeriod.value.from,
    compare_to:   period.effectiveComparePeriod.value.to,
  })
}
</script>
```

---

## Estrategia para tabs futuros

El archivo ya tiene la estructura base:

```html
<q-tab name="revenue" label="Ingresos y Volumen de Venta" />
<q-tab name="ttpns"   label="Indicadores de TTPNs" disable />
<q-tab name="fuel"    label="Rendimiento Combustible" disable />
```

**Recomendación:** Activar los tabs con carga diferida usando `defineAsyncComponent` para que no impacten el tiempo de carga inicial:

```js
const DashboardTtpnsTab = defineAsyncComponent(() =>
  import('./tabs/DashboardTtpnsTab.vue')
)
```

### Qué iría en cada tab futuro

| Tab | Indicadores sugeridos |
|---|---|
| **Viajes (TTPNs)** | Servicios capturados vs completados, servicios por operador |
| **Combustible** | Litros consumidos por unidad, rendimiento km/litro, gasto vs presupuesto, top 10 unidades con mayor consumo |
| **Operativo** | Puntualidad de choferes, incidencias por período, disponibilidad de flota, utilización de unidades |
| **RH / Nómina** | Días trabajados, horas extra, incidencias por empleado, comparativa semana a semana |

Todos comparten el mismo `useDashboardPeriod` — el selector de fecha ya está listo para reutilizarse.

---

## Plan de ejecución (orden sugerido)

Hacerlo tab por tab / componente por componente para no romper nada:

1. **Extraer `useDashboardPeriod.js`** — sin cambios en el template, solo mover lógica
2. **Extraer `useDashboardExport.js`** + crear `DashboardExportDialog.vue`
3. **Extraer `useDashboardData.js`** — incluye `buildMatrixFromApiRows`
4. **Crear `DashboardMatrixTable.vue`** — el bloque más aislado del template
5. **Crear `DashboardKpiCards.vue`** — puramente presentacional
6. **Crear `DashboardTrendChart.vue`** + `DashboardDistributionChart.vue`
7. **Crear `DashboardTopClientsChart.vue`** + `DashboardCompareChart.vue`
8. **Crear `DashboardPeriodPanel.vue`**
9. **Envolver en `DashboardRevenueTab.vue`**
10. **Limpiar `DashboardPage.vue`** al resultado final de ~120 líneas

Cada paso puede hacerse en un PR independiente y el dashboard sigue funcionando entre pasos.

---

## Estimado de líneas por archivo resultante

| Archivo | Líneas estimadas |
|---|---|
| `DashboardPage.vue` | ~120 |
| `DashboardRevenueTab.vue` | ~80 |
| `DashboardPeriodPanel.vue` | ~180 |
| `DashboardKpiCards.vue` | ~70 |
| `DashboardTrendChart.vue` | ~180 |
| `DashboardDistributionChart.vue` | ~100 |
| `DashboardCompareChart.vue` | ~80 |
| `DashboardTopClientsChart.vue` | ~100 |
| `DashboardMatrixTable.vue` | ~280 |
| `DashboardExportDialog.vue` | ~60 |
| `useDashboardPeriod.js` | ~130 |
| `useDashboardData.js` | ~180 |
| `useDashboardExport.js` | ~80 |
| **Total** | **~1,640** |

El total sube un poco por boilerplate de componentes, pero ningún archivo supera las 300 líneas y cada uno tiene una sola responsabilidad.
