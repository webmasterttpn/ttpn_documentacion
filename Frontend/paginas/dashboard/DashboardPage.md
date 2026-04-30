# Refactor Plan — DashboardPage.vue

**Archivo actual:** `pages/Dashboard/DashboardPage.vue` — 1,473 líneas
**Estado:** PENDIENTE DE EJECUTAR
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

```js
return {
  period, compareMode, comparePeriod, activeShortcut,
  displayMode, shortcuts, periodDays, periodLabel,
  visibleMonths, effectiveComparePeriod, compareModeLabel,
  applyShortcut, formatDateLabel, formatValue,
}
```

No tiene dependencia del DOM ni de la API. Se puede testear de forma aislada y reutilizar en futuros tabs.

### `useDashboardData.js`

```js
return {
  apiRows, apiCompareRows, loading, loadProgress, lastUpdated,
  matrixData, compareMatrixData, columnTotals, annualTotals,
  grandTotalAll, compareAnnualTotals, compareGrandTotal,
  loadData,  // recibe { from, to, compare_from?, compare_to? }
}
```

### `useDashboardExport.js`

```js
return {
  exporting, exportDialog, exportProgress,
  exportMessage, exportStatus,
  startExport,  // recibe { from, to, compare_from?, compare_to? }
}
```

---

## Plan de ejecución (orden sugerido)

1. Extraer `useDashboardPeriod.js` — sin cambios en el template
2. Extraer `useDashboardExport.js` + crear `DashboardExportDialog.vue`
3. Extraer `useDashboardData.js` — incluye `buildMatrixFromApiRows`
4. Crear `DashboardMatrixTable.vue` — el bloque más aislado del template
5. Crear `DashboardKpiCards.vue` — puramente presentacional
6. Crear `DashboardTrendChart.vue` + `DashboardDistributionChart.vue`
7. Crear `DashboardTopClientsChart.vue` + `DashboardCompareChart.vue`
8. Crear `DashboardPeriodPanel.vue`
9. Envolver en `DashboardRevenueTab.vue`
10. Limpiar `DashboardPage.vue` al resultado final de ~120 líneas

Cada paso puede hacerse en un PR independiente y el dashboard sigue funcionando.

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

Ningún archivo supera las 300 líneas.

---

## Ver también

- [README.md](README.md) — índice de páginas del dominio dashboard
- [Backend/scripts/dashboard_data.md](../../../../Backend/scripts/dashboard_data.md) — DashboardDataService que genera los datos
- [_archivo/deuda_tecnica/DEUDA_TECNICA_KUMI_CHAT.md](../../../../_archivo/deuda_tecnica/DEUDA_TECNICA_KUMI_CHAT.md) — endpoints de stats que alimentan el dashboard
