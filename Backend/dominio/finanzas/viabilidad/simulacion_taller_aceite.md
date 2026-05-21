# Simulación financiera — Taller propio (cambio de aceite)

**Fecha:** 2026-05-20
**Propósito:** Auditar a detalle cómo se calculan los KPIs del proyecto
**Taller Mecánico TTPN** antes de meter datos productivos. Responde la
pregunta concreta: *si el taller atiende 6 camionetas/día solo con cambio
de aceite (4.5 L × $80/L), ¿en qué mes se recupera una inversión de
$2,000 con gastos fijos de $5,100/mes?*

---

## 1. Hallazgo: hay un gap entre Mantenimiento y Finanzas

Ni la **recepción de mercancía** (`Mtto::ProductReceipt`) ni la **salida
de material a una OT** (`Mtto::InventoryTransfer`) crean filas en
`finance_entries`. Solo tocan `Mtto::Inventory` (stock + costo promedio)
y `Mtto::InventoryMovement` (auditoría).

| Evento | ¿Crea `Finance::Entry`? | ¿Aparece en el dashboard? |
|---|---|---|
| Compra de aceite (ProductReceipt) | NO | NO |
| Salida a OT (InventoryTransfer) | NO | Solo si `auto_revenue_source` ≠ `'none'` |
| OT cerrada (WorkOrder.completed) | NO | Igual que arriba |

**Consecuencia operativa**: si TTPN compra 702 L de aceite al mes
(= **$56,160**) y nadie crea entries manuales, el dashboard del proyecto
**no ve ese egreso**. El burn rate real está subestimado por todo lo que
se compre. Ver [DT-021](../../../../_archivo/deuda_tecnica/DEUDA_TECNICA.md)
para la implementación pendiente del callback que automatiza esto.

Hasta que DT-021 esté lista, el operador debe crear un
`Finance::Entry` tipo `fixed_expense` por cada compra (o el aceite y
demás insumos quedan invisibles para el ROI).

---

## 2. Parámetros de la simulación

| Variable | Valor |
|---|---|
| OTs/día | 6 |
| Aceite por OT | 4.5 L |
| Costo unitario aceite | $80 / L |
| Días/mes (asumido L–S) | 26 |
| Aceite consumido /mes | 702 L |
| **Costo aceite /mes** | **$56,160** |
| Gastos fijos (luz $3,000 + agua $400 + internet $1,000 + gas $700) | $5,100 / mes |
| **Outflow /mes (aceite + fijos)** | **$61,260** |
| Inversión inicial (mes 0) | $2,000 |

---

## 3. Escenario A — Hoy (subsidio puro, sin venta al público)

`Finance::Project.auto_revenue_source = 'none'`, sin entries de tipo
`revenue`.

- Revenue lifetime = **$0**.
- Outflow acumulado a 3 meses = $2,000 + 3 × $61,260 = **$185,780**.
- `break_even_period` = **`null`** (matemáticamente imposible).
- ROI = $-185,780 / $2,000 × 100 = **-9,289 %** y empeorando cada mes.

**Esto NO es un bug**: refleja la realidad operativa. Mientras el taller
solo dé servicio a camionetas TTPN sin cobrar, el proyecto solo gasta.
El dashboard es un termómetro de *cuánto está subsidiando TTPN* al
taller, no un cálculo de recuperación.

---

## 4. Escenario B — Cuando se capture `external_rate` por servicio

`Finance::Project.auto_revenue_source = 'mtto_internal_savings'`.

El revenue automático mensual = Σ `estimated_savings` de las 156 OTs
mensuales (= 6 × 26). Con `sale_price` del aceite = 0 (no se vende a
público), cada OT aporta:

```
estimated_savings = external_rate(servicio) − materials_cost(OT)
                  = external_rate − $360
```

| `external_rate` del servicio "Cambio de aceite" | Ahorro/OT | Ahorro/mes (156 OTs) | ¿Cubre $61,260? | Mes en que recupera los $2,000 |
|---|---|---|---|---|
| $500 | $140 | $21,840 | ❌ no | nunca |
| $800 | $440 | $68,640 | ✅ apenas | mes 1 (sobra $7,380) |
| $1,000 | $640 | $99,840 | ✅✅ | mes 1 (sobra $38,580) |
| $1,500 | $1,140 | $177,840 | ✅✅✅ | mes 1 (sobra $116,580) |

**Umbral mínimo ≈ $800** para que `mtto_internal_savings` muestre el
proyecto como rentable. Por debajo de eso, hacer el cambio de aceite en
taller propio sigue costando más que mandarlo afuera.

Aquí "recupera" significa: el ahorro contable de no haber pagado a un
taller externo supera lo que TTPN está gastando para operar su propio
taller. **No hay dinero entrando**, solo dinero que no se gastó.

---

## 5. Escenario C — Cuando se abra el servicio al público (futuro)

No requiere cambios de código (el calculador ya soporta esto):

1. Capturar `sale_price` en cada producto y `external_rate` en cada
   servicio del catálogo.
2. Cambiar `Finance::Project.auto_revenue_source` a
   `'mtto_internal_savings'` para reflejar el ahorro de las camionetas
   TTPN.
3. **Por cada OT facturada a un cliente externo, crear un
   `Finance::Entry` tipo `revenue`** ligado al proyecto. El calculador
   suma esto encima del ahorro automático.

Si la ganancia por venta a externos cubre lo que falte para igualar el
outflow, el `break_even_period` se dispara solo. No hay configuración
adicional. (Cuando se conecte la facturación al backend, idealmente esos
`revenue` también se autogenerarían — DT futura, no urgente.)

---

## 6. Anexo: corrida real contra BD local (2026-05-20)

Sembré el escenario A en la BD local con
`slug: 'taller-simulacion-aceite'` (proyecto sandbox, no afecta al
proyecto Taller real). 1 inversión + 3 meses × 5 conceptos =
**16 entries**, $183,780 de gasto fijo lifetime.

Salida real de `Finance::DashboardCalculator.new(p, from:'2026-05', to:'2026-07').call`:

```json
{
  "kpis": {
    "investment_lifetime": "2000.0",
    "fixed_expense_range": "183780.0",
    "fixed_expense_lifetime": "183780.0",
    "revenue_range": "0.0",
    "revenue_lifetime": "0.0",
    "net_lifetime": "-185780.0",
    "roi_pct": "-9289.0",
    "break_even_period": null
  },
  "monthly_series": [
    {"period":"2026-05","investment":"2000.0","fixed_expense":"61260.0","revenue":"0.0"},
    {"period":"2026-06","investment":"0.0",   "fixed_expense":"61260.0","revenue":"0.0"},
    {"period":"2026-07","investment":"0.0",   "fixed_expense":"61260.0","revenue":"0.0"}
  ],
  "breakdown_by_concept": [
    {"concept":"Inversión inicial","total":"2000.0"},
    {"concept":"Luz",              "total":"9000.0"},
    {"concept":"Agua",             "total":"1200.0"},
    {"concept":"Internet",         "total":"3000.0"},
    {"concept":"Gas",              "total":"2100.0"},
    {"concept":"Compra de aceite", "total":"168480.0"}
  ]
}
```

Los números calculados por el código empatan exactamente con la
proyección manual del escenario A. ✅

### Cómo verlo en el FE local

`http://localhost:9000` → Finanzas → Viabilidad → seleccionar
**`[SIM] Taller Aceite — Mayo 2026`** → rango 2026-05 a 2026-07.

### Cómo borrar el sandbox cuando ya no haga falta

```bash
docker exec -t kumi_api bundle exec rails runner '
Finance::Project.find_by(slug: "taller-simulacion-aceite")&.then do |p|
  p.entries.destroy_all
  p.concepts.destroy_all
  p.destroy!
  puts "Sandbox borrado"
end'
```

---

## 7. Recomendaciones

1. **Hoy**: dejar el proyecto Taller real en `'none'`. El dashboard sirve
   como termómetro del subsidio. Está bien que `break_even` sea `null`.
2. **Antes de activar `'mtto_internal_savings'`**: capturar
   `external_rate` ≥ $800 en el servicio "Cambio de aceite" (calibrar el
   resto contra el mercado de la zona). Si las tarifas reales están por
   debajo de eso, el modelo dirá que el taller propio cuesta más que el
   externo — y será verdad.
3. **Captura de gastos de mercancía**: hasta que DT-021 automatice el
   callback, el operador debe crear un `Finance::Entry` tipo
   `fixed_expense` por cada compra grande de aceite/insumos. Sin eso, el
   ROI estará inflado falsamente (no contabiliza el material).
4. **Cuando se abra al público**: configurar los `sale_price` y empezar a
   crear `Finance::Entry` tipo `revenue` por cada factura externa. El
   calculador ya soporta sumar ambas fuentes (ahorro interno + venta).
