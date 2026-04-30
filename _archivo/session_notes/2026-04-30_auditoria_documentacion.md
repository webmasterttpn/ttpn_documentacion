# 2026-04-30 — Auditoría y Actualización Completa de Documentación

## Resumen ejecutivo

Sesión de auditoría integral de la documentación. Se comparó el estado real del código vs los documentos existentes, se eliminaron duplicados y obsoletos, se reescribieron documentos con contenido genérico incorrecto, y se completaron los stubs de dominio pendientes. La documentación queda sincronizada con el sistema al 2026-04-30.

---

## 1. Limpieza de Duplicados y Obsoletos

### Commit: `d8ded39`

Se eliminaron **13 archivos** (2433 líneas) que estaban duplicados, desactualizados o fuera de lugar:

| Archivo eliminado | Razón |
| --- | --- |
| `ttpngas/RAILWAY_STAGING_DEPLOYMENT_GUIDE.md` | Tenía credenciales reales expuestas. Contenido limpio movido a `Documentacion/INFRA/operaciones/railway_deployment.md` |
| Varios `.md` duplicados en subcarpetas de proyectos | Documentación debe vivir solo en `Documentacion/` (monorepo) |

---

## 2. PRD.md — Actualización

**Archivo:** `Documentacion/INFRA/PRD.md`

### Cambios

- Stack table actualizado: agregados `rack-attack`, `rack-timeout`, `bundler-audit`, corregido `ActiveStorage` a AWS S3
- Sección 24 (Reglas y Restricciones Globales) — nuevas reglas de seguridad (11-15):
  - Rate limiting: rack-attack (5 req/20s login, 300/5min general, blocklist 1h tras 20 intentos)
  - Account lockout: 10 intentos → 1h bloqueado
  - CSP Frontend: `script-src 'self'` únicamente
  - Pre-commit hook: detecta secrets antes de commit
  - API Keys externas: rotación semestral, gestión desde panel admin
- Referencias al pie corregidas: paths rotos → paths reales en `arquitectura/` e `infraestructura/`

---

## 3. ARQUITECTURA_TECNICA.md — Reescritura Completa

**Archivo:** `Documentacion/INFRA/arquitectura/ARQUITECTURA_TECNICA.md`

El documento previo (2025-12-18) tenía contenido genérico/inventado que no reflejaba el sistema real:
- Usaba CanCanCan → el sistema usa **Pundit**
- Usaba Pinia stores para todo → el sistema usa **composables** para estado de página
- Schema inventado (companies, maintenances) → schema real (business_units, vehicles, employees, etc.)
- Queues Sidekiq incorrectas (critical/low_priority) → reales (default/payrolls/alerts/mailers)
- Mostraba NGINX → Railway no usa NGINX

**Reescritura completa** con 13 secciones que documentan el sistema real:

1. Visión general + diagrama de arquitectura real
2. Multi-tenancy: Business Units (cómo funciona el scope por BU)
3. Backend Rails: estructura, patrón de controller, patrón de service, auditoría automática
4. Autenticación: 3 canales separados (User JWT, Employee JWT, ApiKey)
5. Autorización: Pundit + objeto Privileges en JWT
6. Jobs Sidekiq: queues reales, jobs existentes, jobs programados
7. Tiempo real ActionCable: flujo de alertas, auth WebSocket
8. Almacenamiento: ActiveStorage → AWS S3
9. Base de datos: categorías de modelos, funciones PostgreSQL, trigger sp_tctb_insert
10. N8N: integración via HTTP + API Key (no conexión directa a BD)
11. Seguridad: 9 capas implementadas con código de ejemplo
12. Frontend: patrón obligatorio de página, privileges, manejo de errores, stores Pinia
13. Deployment: servicios Railway, proceso de deploy BE y FE, variables clave

---

## 4. onboarding_BE.md — Fix CanCanCan → Pundit

**Archivo:** `Documentacion/INFRA/onboarding/onboarding_BE.md`

Stack table corregida: `CanCanCan + Privileges personalizados` → `Pundit + Privileges personalizados`

---

## 5. READMEs de Dominios — Expansión

Los siguientes READMEs pasaron de ~25 líneas (stub) a documentación completa:

| Dominio | Archivo | Contenido agregado |
| --- | --- | --- |
| Alertas | `Backend/dominio/alertas/README.md` | Flujo completo, services, jobs, canal WebSocket, código de suscripción |
| Combustible | `Backend/dominio/combustible/README.md` | Modelos completos, services FuelPerformance, flujo de importación |
| Servicios TTPN | `Backend/dominio/servicios_ttpn/README.md` | Relación con TtpnBooking, rol de Concessionaire, jerarquía de precios |
| Proveedores | `Backend/dominio/proveedores/README.md` | Uso por dominio, relaciones cross-domain, notas de diseño |
| Ruteo | `Backend/dominio/ruteo/README.md` | Jerarquía CrDay→CrdHr→CrdhRoute→CrdhrPoint, estado del motor de ruteo |
| Finanzas | `Backend/dominio/finanzas/README.md` | SDI/SBC, flujo de cálculo de nómina, PayrollProcessWorker, KumiSetting |

---

## 6. ADR-008 — Hardening de Seguridad

**Archivo:** `Documentacion/INFRA/arquitectura/ADR/ADR-008-hardening-seguridad-2026.md`

Documenta las decisiones de la sesión de auditoría (2026-04-29):
- Alternativas consideradas para rate limiting, lockout y CSP
- Justificación de cada decisión
- Consecuencias y cosas a tener en cuenta
- Tabla completa de archivos creados/modificados

---

## Decisiones tomadas

1. **Scope de documentación:** La documentación técnica de junior está en `ARQUITECTURA_TECNICA.md`. El PRD explica el negocio. Los ADRs explican el "por qué" de las decisiones.
2. **Dominios cross-model:** `GasStation` y `Concessionaire` aparecen en múltiples dominios porque son modelos compartidos — se documenta en el dominio principal y se referencia en los secundarios.
3. **Motor de ruteo:** No implementado. La propuesta existe en `propuesta_motor_ruteo.md`. Se deja indicado en el README del dominio.
4. **onboarding_FE.md:** Ya estaba actualizado y preciso — no requirió cambios de fondo.

---

## Archivos creados / modificados

| Archivo | Tipo de cambio |
| --- | --- |
| `Documentacion/INFRA/PRD.md` | Actualización (stack + reglas + referencias) |
| `Documentacion/INFRA/arquitectura/ARQUITECTURA_TECNICA.md` | Reescritura completa + corrección Pundit → CanCan |
| `Documentacion/INFRA/arquitectura/ADR/ADR-008-hardening-seguridad-2026.md` | Nuevo |
| `Documentacion/INFRA/onboarding/onboarding_BE.md` | Corrección CanCan (se corrigió "Pundit" erróneo escrito en sesión anterior) |
| `Documentacion/Backend/dominio/alertas/README.md` | Expansión |
| `Documentacion/Backend/dominio/combustible/README.md` | Expansión |
| `Documentacion/Backend/dominio/servicios_ttpn/README.md` | Expansión |
| `Documentacion/Backend/dominio/proveedores/README.md` | Expansión |
| `Documentacion/Backend/dominio/ruteo/README.md` | Expansión |
| `Documentacion/_archivo/cambios/FE/2026-03-23_filterpanel_estandar.md` | Actualización estado: 8/10 migradas, 2 pendientes |
| `Documentacion/_archivo/deuda_tecnica/README.md` | +3 items nuevos |
| `Documentacion/_archivo/deuda_tecnica/2026-03-19_backfill_clvs_thread_new.md` | Nuevo |
| `Documentacion/_archivo/deuda_tecnica/2026-03-20_silent_catch_blocks.md` | Nuevo |
| `Documentacion/_archivo/deuda_tecnica/2026-03-23_filterpanel_2_paginas_pendientes.md` | Nuevo |
| `Documentacion/Backend/dominio/finanzas/README.md` | Expansión |
