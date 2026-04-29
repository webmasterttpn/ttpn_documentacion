# reportes/contables.py

Genera el reporte contable diario de un usuario: ingresos, gastos, ganancia e impuestos.
Guarda el resultado en la tabla `reportes_diarios`.

---

## Propósito

Calcular el resumen financiero diario de un usuario a partir de sus transacciones
en Supabase y persistir el resultado para que el FE lo consulte.

---

## Uso

```bash
# Manual
python3 scripts/reportes/contables.py --user-id 123 --fecha 2026-04-27

# Desde Sidekiq (Rails)
EjecutarScriptPythonJob.perform_later(
  'reportes/contables.py',
  { user_id: current_user.id, fecha: Date.today.to_s }
)
```

---

## Parámetros

| Parámetro | Requerido | Default | Descripción |
| --- | --- | --- | --- |
| `--user-id` | Sí | — | ID del usuario |
| `--fecha` | No | Hoy | Fecha YYYY-MM-DD |

---

## Salida

```json
{
  "status": "success",
  "reporte": {
    "user_id":   "123",
    "fecha":     "2026-04-27",
    "ingresos":  850.00,
    "gastos":    200.00,
    "ganancia":  650.00,
    "impuestos": 195.00
  }
}
```

---

## Cálculo

- `ganancia = ingresos - gastos`
- `impuestos = max(ganancia * 0.30, 0)` — no negativos
- Lee tabla `transacciones` filtrando `user_id` y `fecha`
- Guarda con `ON CONFLICT (user_id) DO UPDATE` en `reportes_diarios`

---

## Cuándo corre

- Manual: para generar reportes históricos o debugging
- Sidekiq: disparado al final del día (sidekiq-cron)
- On-demand: cuando el usuario solicita su reporte desde el FE

---

## Dependencias

- `utils/db.py` → `PostgresClient`
- Tabla `transacciones` (campos: `user_id`, `tipo`, `monto`, `fecha`)
- Tabla `reportes_diarios` (campos: `user_id`, `fecha`, `ingresos`, `gastos`, `ganancia`, `impuestos`)

---

## Tests

```bash
PYTHONPATH=scripts pytest scripts/reportes/ -v
```

5 tests — happy path, sin transacciones, solo ingresos, impuestos no negativos,
verificación de escritura en BD.
