# Función PostgreSQL — `costo_viaje_chofer`

## Propósito

Calcula el **pago al chofer por un viaje** (`travel_counts`) directamente en el servidor de base de
datos, liberando al worker de Rails. Se introdujo para la feature **"Sacar de VCPA"**: los viajes
marcados como VCPA (capturados por administrativo) hoy quedan con `costo = 0`, y al sacarlos de VCPA
desde la web —sin la app móvil de por medio— hay que recalcular el pago en ese momento.

Definición versionada en `db/functions/costo_viaje_chofer.sql` y cargada por la migración
`20260605120000_create_costo_viaje_chofer_function.rb`.

## Firma

```sql
costo_viaje_chofer(p_tc_id bigint, p_incluir_nivel boolean) RETURNS double precision
```

## Fórmula (validada 2026-06-05 contra viajes ya pagados)

```
costo = base × (1 + inc_servicio/100) × (1 + inc_cliente/100) + nivel_pesos
```

| Componente | Origen | Tipo |
|---|---|---|
| `base` | `vehicle_type_prices.price` vigente del tipo de vehículo | pesos |
| `inc_servicio` | `incremento_servicio(vehicle_type_id, destino_nombre)` → `ttpn_service_driver_increases.incremento` | **%** |
| `inc_cliente` | `incremento_cliente(vehicle_type_id, destino, sucursal)` → `cts_driver_increments.incremento` | **%** |
| `nivel_pesos` | `incremento_por_nivel(employee_id, vehicle_id)` → `drivers_levels.incremento` | **PESOS (0/5/10/15)** |

Reusa las 3 funciones de apoyo (`incremento_servicio`, `incremento_cliente`, `incremento_por_nivel`),
todas versionadas en `db/functions/`. La migración las vuelve a crear (idempotente, `CREATE OR REPLACE`);
en particular **`incremento_cliente` antes no estaba en ninguna migración** (solo en la BD) — ahora sí.

## Reglas del nivel

- El nivel del chofer es una **suma fija en pesos** (no porcentaje), **solo para viajes locales**
  (destino = `'Chihuahua'`).
- Se suma únicamente si `p_incluir_nivel = true` **y** el viaje es local.
- Uso en "Sacar de VCPA": `p_incluir_nivel = !crear_incidencia`
  - Genera incidencia (no capturó por flojera) → `false` → **sin** nivel.
  - No genera incidencia (apoyo legítimo, ej. celular dañado) → `true` → **con** nivel si es local.

## Valor de retorno

- `double precision` redondeado a 2 decimales.
- `NULL` si no hay precio base vigente para el tipo de vehículo (el caller no sobrescribe `costo`).

## ⚠️ NO usar `pago_chofer`

La función legacy `pago_chofer(base, inc_servicio, inc_nivel)` está **incompleta/incorrecta**:
ignora el incremento de cliente y trata el nivel como porcentaje (`÷100`) en vez de pesos. Es dead
code (0 callers). `costo_viaje_chofer` la reemplaza para este cálculo.

## Uso desde Ruby

Vía el wrapper `PayrollSvc::DriverTripCostCalculator` (ver
`finanzas/services/DriverTripCostCalculator.md`). En tests se carga vía
`spec/support/postgres_functions.rb` (schema_format = ruby no serializa funciones).
