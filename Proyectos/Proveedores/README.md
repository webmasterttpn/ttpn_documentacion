# Portal de Proveedores TTPN

Carpeta única con TODA la documentación del proyecto **Portal de
Proveedores** — una PWA nueva donde los proveedores de TTPN consultan
sus facturas, suben CFDI XML + PDF, suben complementos de pago y ven
la fecha programada de pago.

## Lectura recomendada (orden)

> Si esta es tu primera vez con Kumi, **respeta el orden**. Cada manual
> asume que terminaste el anterior.

| # | Doc | Para qué sirve |
|---|---|---|
| 1 | [PRD.md](PRD.md) | Qué se construye, para quién y por qué |
| 2 | [seguridad.md](seguridad.md) | Reglas anti-hacking que NO se negocian |
| 3 | [00_setup_docker_y_entorno.md](00_setup_docker_y_entorno.md) | Instalar Docker, clonar repos, levantar Kumi local. Para dev que NUNCA usó Docker |
| 4 | [manual_supabase.md](manual_supabase.md) | Crear cuenta Supabase + bucket + keys + verificar |
| 5 | [manual_letter_opener.md](manual_letter_opener.md) | Cómo ver correos durante desarrollo (sin SMTP real) |
| 6 | [manual_backend.md](manual_backend.md) | Paso a paso para construir el BE (Rails/Ruby) |
| 7 | [manual_frontend.md](manual_frontend.md) | Paso a paso para construir el FE (PWA Quasar) |
| 8 | [kumi_admin_changes.md](kumi_admin_changes.md) | Cambios en el Admin Kumi (Finanzas) — privilegios + menú + páginas |
| 9 | [api_contract.md](api_contract.md) | Contrato completo de la API (endpoints, payloads) |
| 10 | [prompts_mockup.md](prompts_mockup.md) | Prompt para generar el diseño visual en Claude Design o Stitch |
| 11 | [troubleshooting.md](troubleshooting.md) | FAQ de errores comunes |
| 12 | [flujos/](flujos/) | Cada flujo de negocio explicado (alta usuario, recovery password, bulk upload, etc.) |

## Diagrama de capas

```text
┌───────────────────────────────────────────────────────────────────┐
│ PORTAL DE PROVEEDORES (PWA Quasar nueva — repo aparte)            │
│  • LoginPage / ResetPasswordPage / ChangePasswordPage             │
│  • InvoicesPage (Estatus de Facturas)                             │
│  • Uploads (CFDI + PDF + complementos)                            │
│  • Storage local: JWT del supplier_user                           │
└───────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS + X-API-Key + Bearer JWT
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│ RAILS API (Kumi · ttpngas — ya existente, se extiende)            │
│                                                                    │
│  Middleware: ApiKeyAuthenticatable (valida X-API-Key)             │
│                                                                    │
│  Controllers nuevos:                                               │
│    • Api::V1::Portal::*                ← usa SupplierUser JWT     │
│    • Api::V1::Suppliers::Users         ← admin Kumi (User JWT)    │
│    • Api::V1::SupplierInvoices         ← admin Kumi               │
│                                                                    │
│  Modelos nuevos:                                                   │
│    • SupplierUser (has_secure_password + JWT propio)              │
│    • SupplierUserToken, SupplierAuditEvent                         │
│    • SupplierInvoice (PUE/PPD), PaymentComplement                  │
│    • SupplierDocument (refs a Supabase)                            │
│                                                                    │
│  Storage: Supabase (nuevo) — bucket privado supplier_docs          │
│  Mailers: confirmación, reset, bloqueo (LetterOpener en dev)      │
└───────────────────────────────────────────────────────────────────┘
                              │
                              │ ActiveRecord
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│ POSTGRES (Supabase Pro — la misma DB de Kumi)                      │
│  + Tabla suppliers existente · + nuevas tablas supplier_*          │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│ KUMI ADMIN (ttpn-frontend existente — se extiende)                │
│  • /finanzas/proveedores/facturas        (aprobar / rechazar)     │
│  • /finanzas/proveedores/semaforo        (validar comportamiento) │
│  • /finanzas/proveedores/portal-usuarios (alta de cuentas)        │
└───────────────────────────────────────────────────────────────────┘
```

## Audiencia de los manuales

Los manuales asumen que el dev **no conoce Ruby/Rails/Quasar/Docker**.
Cada paso incluye:

1. **Comando exacto** a ejecutar (copy-paste).
2. **Salida esperada** (qué verás si funcionó).
3. **Por qué** se hace el paso (1-2 líneas de contexto).
4. **Si falla** — errores comunes y cómo resolverlos.
5. **Aprende esto antes de seguir** — concepto mínimo necesario.

El supervisor (Antonio) ya recorrió cada receta antes de entregártela.
Si algo no se reproduce como el manual dice, **avisa de inmediato**
en lugar de improvisar — preferimos corregir el manual a que tengas
un día de rescate.

## Cómo trabajar en este proyecto (workflow git)

1. Antonio (supervisor) crea los repos vacíos en GitHub:
   - `portal-proveedores-api` (este NO se crea — todo se hace dentro
     de `ttpngas` existente, en branch dedicada `feature/portal-proveedores`).
   - `portal-proveedores-frontend` (nuevo, vacío con solo `main`).
2. Tú (dev) lo clonas y **NUNCA pusheas a `main`**. En su lugar:

   ```bash
   git clone <url> portal-proveedores-frontend
   cd portal-proveedores-frontend
   git checkout -b feature/initial-scaffold
   # ... tu trabajo ...
   git add .
   git commit -m "feat: scaffold inicial del portal"
   git push -u origin feature/initial-scaffold
   ```

3. Antonio revisa tu branch en GitHub (Pull Request). Si pasa la
   revisión, él mergea a `main`. Si requiere cambios, los hace en
   tu misma branch (`git pull` para traerlos a tu local) y vuelves a
   pushear.
4. **Nunca** uses `git push origin main` — está bloqueado por
   convención. Si necesitas urgentemente, **avisa primero** a Antonio.

Detalles paso a paso del workflow git están en
[00_setup_docker_y_entorno.md](00_setup_docker_y_entorno.md) sección
"Git workflow del proyecto".

## Restricciones de esta fase

- **No** se crea módulo de Órdenes de Compra (OC) en Kumi. El campo
  `purchase_order_number` es texto libre por ahora.
- **No** se hace parsing de XML CFDI para auto-match. El admin
  reconcilia manualmente.
- **No** se aprueba por línea — la factura es una unidad indivisible
  (aprobar todo o rechazar todo con nota).

## Estado del documento

| Versión | Fecha | Autor | Notas |
|---|---|---|---|
| 1.0 | 2026-05-21 | Antonio + Claude | Versión inicial, lista para inicio de desarrollo |
