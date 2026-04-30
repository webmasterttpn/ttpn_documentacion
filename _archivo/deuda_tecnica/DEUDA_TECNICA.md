# Deuda Técnica — Kumi TTPN Admin V2

Archivo único. Agregar nuevas entradas al tope de la sección correspondiente.
Actualizar el `Status` y el bloque `Avance` en lugar de crear archivos nuevos.

**Severidad:** Alta → bloquea o genera bugs en producción | Media → degradación o inconsistencia | Baja → cosmético o deuda de código

---

## Pendientes / En progreso

---

### DT-009 — `ClientContact` modelo sin tabla en BD
**Registrada:** 2026-04-30 | **Dominio:** Backend — clientes | **Severidad:** Baja
**Status:** Pendiente

Detectado al generar el ERD global con `rails-erd`. El modelo `ClientContact` existe en
`app/models/` pero no tiene tabla en la base de datos. `rails-erd` lo ignora con un warning.

**Solución propuesta:** Decidir si el modelo se implementa (crear migración) o se elimina del código.

---

### DT-010 — `FixedRouteDetail` asociación fantasma en `TtpnService`
**Registrada:** 2026-04-30 | **Dominio:** Backend — servicios_ttpn | **Severidad:** Baja
**Status:** Pendiente

`TtpnService` tiene `has_many :fixed_route_details` pero la clase `FixedRouteDetail` no existe.
`rails-erd` lo ignora con un warning. No causa error en runtime porque la asociación nunca se llama.

**Solución propuesta:** Eliminar la asociación del modelo o crear el modelo/tabla correspondiente.

---

### DT-006 — Dashboard no consultable por IA (chat)
**Registrada:** 2026-04-19 | **Dominio:** Backend — dashboard | **Severidad:** Baja
**Status:** Pendiente

`/api/v1/dashboard` usa Sidekiq jobs asincrónicos. La IA no puede hacer polling de un `job_id`.

**Solución propuesta:** `GET /api/v1/dashboard/summary` — resumen sincrónico de los datos más
recientes sin Sidekiq, específico para el chat.

| KPI | Fuente |
|---|---|
| Viajes del mes vs mes anterior | `TtpnBooking` + comparativo |
| Top 5 clientes por viajes | agregación |
| Ingresos estimados del periodo | `TtpnServicePrice` × viajes |

---

---

### DT-003 — FilterPanel sin migrar en 2 páginas
**Registrada:** 2026-03-23 | **Dominio:** Frontend — Gas | **Severidad:** Baja
**Status:** Pendiente

El estándar FilterPanel se implementó en marzo 2026. 8 de 10 páginas fueron migradas. Quedan:

1. `src/pages/TtpnBookings/DiscrepanciesPage.vue` — filtros de fecha y estado
2. `src/pages/Gas/FuelPerformancePage.vue` — filtros de rango de fechas

**Solución propuesta:** Seguir el patrón de `_archivo/cambios/FE/2026-03-23_filterpanel_estandar.md`:
importar FilterPanel + useFilters, reemplazar refs inline, agregar badge de filtros activos.

---

### DT-002 — 46 silent catch blocks sin useNotify
**Registrada:** 2026-03-20 | **Dominio:** Frontend — transversal | **Severidad:** Media
**Status:** Pendiente

Durante la limpieza SonarCloud P0 se dejaron catch blocks con `/* silent */` para P1.
En P1 se creó `useNotify.js` pero los catch blocks nunca recibieron tratamiento.
Al 2026-04-30 hay **46 `/* silent */` en 29 archivos**.

**Archivos principales:** `useTtpnBookingForm.js`, `useBusinessUnitContext.js`,
`useBookingCaptureCatalogs.js`, `auth-store.js`, `AlertBell.vue`, `EmployeesPage.vue`,
`VehicleChecksPage.vue`, `ClientsPage.vue`, `FuelPerformancePage.vue`, y otros 20.

**Solución propuesta:**
```javascript
// Antes
} catch (e) { /* silent */ }

// Después — notificar al usuario
} catch (e) { notifyError('Error al cargar los datos') }

// Solo si hay razón documentada para el silencio
} catch { /* omitir — razón: X */ }
```

---

---

## Completados

---

### DT-001 — `backfill_clvs` usaba `Thread.new` en lugar de Sidekiq

**Registrada:** 2026-03-19 | **Dominio:** Backend — bookings | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-30

Creado `BackfillTtpnBookingsJob` (Sidekiq, queue: default, retry: 2).
`TtpnBookingsController#backfill_clvs` migrado a `BackfillTtpnBookingsJob.perform_async(days)`.

---

### DT-005 — `employee_stats` 500 en producción

**Registrada:** 2026-04-19 | **Dominio:** Backend — employees | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

`exec_query` (formato Rails 6) reemplazado por ActiveRecord puro. `rescue StandardError` con
logging agregado. Confirmado funcionando en producción.

---

### DT-004 — Sin control de acceso por privilegios en el chat
**Registrada:** 2026-04-19 | **Dominio:** Backend + N8N | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-19

`ChatController` extrae `build_privileges` del JWT → filtra módulos con `can_access: true` →
pasa `allowed_modules: [...]` al webhook de N8N → el nodo "Construir Prompt" restringe los
endpoints disponibles según los módulos del usuario.

---

### DT-C03 — Endpoints de stats sin filtros útiles para IA
**Registrada:** 2026-04-19 | **Dominio:** Backend | **Severidad:** Media
**Status:** ✅ Completado — 2026-04-19

Implementados: `vehicle_stats`, `booking_stats`, `client_stats`. `employee_stats` ya existía.

---

### DT-C02 — AI routing incorrecto (employees vs employee_stats)
**Registrada:** 2026-04-19 | **Dominio:** N8N | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

Prompt actualizado con sección "REGLAS CRÍTICAS DE ROUTING" que distingue explícitamente
cuándo usar endpoint de stats vs listado individual.

---

### DT-C01 — Llamadas directas del FE a N8N (CORS)
**Registrada:** 2026-04-19 | **Dominio:** Backend + Frontend | **Severidad:** Alta
**Status:** ✅ Completado — 2026-04-19

Proxy implementado en `POST /api/v1/chat`. El browser nunca llama a N8N directamente.
Rails extrae `allowed_modules` del JWT y los pasa a N8N. Configurar `N8N_WEBHOOK_URL` en `.env`.
