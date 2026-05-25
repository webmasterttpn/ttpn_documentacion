# DashboardPage.vue

**Archivo:** `pages/Dashboard/DashboardPage.vue` (orquestador) + `pages/Dashboard/tabs/*` + `components/KPIs/*` + `composables/Dashboard/*`.
**Estado del refactor:** EJECUTADO (la estructura propuesta más abajo ya existe en el código).

---

## Comportamiento actual (2026-05-25)

### Tabs por privilegio
Cada tab del dashboard es un **privilegio independiente** (`module_key`): `dashboard_revenue`
(Ingresos), `dashboard_ttpns` (TTPNs), `dashboard_taller` (Mantenimiento). El componente usa
`usePrivileges('dashboard_revenue')`, etc., y oculta el tab si el rol no tiene **Acceso** (`v-if`).
- En **gestión de privilegios** (Settings → Usuarios/Permisos) estos tres aparecen bajo el grupo
  "General" y se les puede dar Acceso (= view) por separado. Requieren estar **sembrados** en la BD
  (seed `db/seeds/privileges.rb`; si solo existe `dashboard`, faltan los tres tabs — sembrarlos).
- **Fallback:** si un rol no tiene asignado **ningún** tab, se muestran todos (para no dejar el
  dashboard en blanco). En cuanto se asigna al menos uno, se respeta la selección. Sadmin ve todos.

### Carga perezosa ("nada hasta Generar")
**No se carga nada al entrar** (se quitó `onMounted(onLoad)`). El usuario abre la página al instante
y dispara la carga del tab que le interesa:
- **Ingresos:** el panel de período queda visible con su botón **Consultar** (o el botón **Generar**
  del header). Hasta entonces el tab muestra un estado vacío. `revenueLoaded` (en `DashboardPage`)
  controla el estado vacío vía prop `:loaded` de `DashboardRevenueTab`.
- **TTPNs:** ya era manual (botón **Consultar** propio, sin `onMounted`). Sin cambios.
- **Mantenimiento (Taller):** los paneles `WorkshopOpsPanel`/`WorkshopWeeklyTab` auto-cargan al
  montar y se comparten con Finanzas, así que **no se modifican**; el tab los **gatea** detrás de un
  botón **Generar** (`generated` ref) — solo se montan (y cargan) al presionarlo.

> Patrón general buscado: ninguna pantalla pesada debe auto-cargar todo al montar; cargar el
> contenido del tab/sección activo bajo demanda. (Por ahora aplicado solo al Dashboard.)

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
