# 2026-05-27 — Clasificación de proveedores: servicio / consumo

## Contexto

Se necesita distinguir proveedores **de servicio** (talleres a los que mandamos
trabajos de mantenimiento) de proveedores **de consumo** (a los que les compramos
refacciones/insumos). Decisión del usuario: **dos casillas independientes** (un
proveedor puede ser ambos), no un solo enum.

## Backend (`ttpngas`)

- Migración `20260527000004`: agrega a `suppliers` los booleanos
  `provee_servicio` y `provee_consumo` (default `false`, `null: false`).
- `Supplier`: scopes `de_servicio` / `de_consumo`.
- `SuppliersController`: permite los dos campos; filtros
  `?provee_servicio=true` / `?provee_consumo=true`; ambos en el serializer
  (lista y detalle).
- Spec: filtro por flags + create devuelve los flags. 10 ejemplos verdes, RuboCop 0.
- **Existentes quedan sin clasificar** (false/false) — se marcan desde el catálogo.

## Frontend (`ttpn-frontend`)

- `SupplierForm`: sección "Clasificación" con dos toggles.
- `SupplierDetails`: chips Servicio/Consumo (o "Sin clasificar").
- `SuppliersPage`: columna "Clasificación" (chips) en tabla y tarjetas móvil +
  filtro "Clasificación" (Servicio/Consumo) en el panel.
- ESLint 0, build limpio.

## Pendiente (siguiente paso natural)

Conectar el dropdown "Proveedor/Taller" del modal **Agendar servicio** para que
filtre solo `provee_servicio` (talleres). Hoy muestra todos. Relacionado con el
comentario del usuario de que el Mecánico/Responsable solo aplica si el taller es
propio. Ver doc `Backend/dominio/proveedores/README.md`.

## Despliegue

Migración nueva → corre en Railway vía `db:prepare` en el deploy. ttpngas → github
transform_to_api; FE → GitLab (Netlify) + GitHub; doc → GitHub.
