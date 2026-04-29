# Seguridad — Kumi TTPN Admin

Estado de implementación de las tres capas de seguridad del proyecto.
Última actualización: 2026-04-29

---

## Estado General

| Capa | Estado | Archivo |
| --- | --- | --- |
| CORS — Origins explícitos + env var | ✅ Implementado | `ttpngas/config/initializers/cors.rb` |
| CORS — Bloque separado para webhooks | ✅ Implementado | `ttpngas/config/initializers/cors.rb` |
| CORS — ActionCable WebSocket | ✅ Implementado | `ttpngas/config/application.rb` |
| Security Headers Rails (X-Frame, nosniff, etc.) | ✅ Implementado | `ttpngas/config/initializers/security_headers.rb` |
| HSTS (force_ssl + hsts preload) | ✅ Implementado | `ttpngas/config/environments/production.rb` |
| Permissions-Policy | ✅ Implementado | `ttpngas/config/initializers/permissions_policy.rb` |
| CSP (API-only — intencionalmente omitido) | ✅ Documentado | `ttpngas/config/initializers/content_security_policy.rb` |
| Security Headers Frontend (Netlify `_headers`) | ✅ Implementado | `ttpn-frontend/public/_headers` |
| CSP Frontend | ✅ Implementado | `ttpn-frontend/public/_headers` |
| RLS — SQL listo para ejecutar | ⏳ Pendiente ejecución | `Documentacion/seguridad/rls_policies.sql` |

---

## CORS

### Backend (`ttpngas/config/initializers/cors.rb`)

- **Origins de producción** leídos desde `FRONTEND_URL` (env var) + `FRONTEND_URL_EXTRA` para apps adicionales.
- **Orígenes no-productivos** agregados automáticamente cuando `Rails.env != production`.
- **Webhooks** tienen bloque separado con `origins '*'` — la verificación HMAC es la barrera real.
- **`credentials`** removido — el proyecto usa JWT en header, no cookies de sesión.

**Variables requeridas en producción (Railway):**

```bash
FRONTEND_URL=https://kumi.ttpn.com.mx
# FRONTEND_URL_EXTRA=https://otra-app.com,https://movil.com   (opcional)
```

### ActionCable WebSocket (`ttpngas/config/application.rb`)

Origins permitidos en `config.action_cable.allowed_request_origins`. Actualizar si se agrega un nuevo dominio frontend.

---

## Security Headers (Rails API)

Archivo: `ttpngas/config/initializers/security_headers.rb`

| Header | Valor | Protege contra |
| --- | --- | --- |
| `X-Frame-Options` | `DENY` | Clickjacking |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing |
| `X-XSS-Protection` | `1; mode=block` | XSS en browsers legacy |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Fuga de URL en header Referer |
| `Permissions-Policy` | `camera=(), mic=(), geo=()...` | Acceso no autorizado a periféricos |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Downgrade HTTPS (via production.rb) |

**CSP**: Intencionalmente no configurado en la API. Solo aplica en respuestas HTML — este proyecto devuelve solo JSON. Ver `content_security_policy.rb` para la explicación completa.

---

## Security Headers (Frontend — Netlify)

Archivo: `ttpn-frontend/public/_headers`

Todos los headers del API más **Content-Security-Policy** con:

- `connect-src`: solo `kumi-admin-api-production.up.railway.app` y WebSocket equivalente
- `frame-ancestors 'none'`: equivalente a `X-Frame-Options: DENY` para browsers modernos
- `object-src 'none'`: bloquea plugins Flash/Java
- `base-uri 'self'`: previene inyección de `<base>` tag

**Si cambias el dominio de la API en Railway**, actualizar `connect-src` en `_headers`.

---

## RLS — Row Level Security (PENDIENTE EJECUCIÓN)

### Estado

El SQL está listo en `Documentacion/seguridad/rls_policies.sql`. **Aún no se ha ejecutado en Supabase.**

### Cómo afecta RLS a cada tipo de conexión

| Conexión | Usuario | BYPASSRLS | Afectado por RLS |
| --- | --- | --- | --- |
| Rails API (producción) | `service_role` | ✅ Sí | No — el ORM filtra por BU |
| Android / PHP (pruebas) | `postgres` vía pooler :6543 | ✅ Sí | **No** — superusuario |
| N8N (futuro) | `app_user` | ❌ No | **Sí** — necesita `SET LOCAL` |
| Python scripts (futuro) | `app_user` | ❌ No | **Sí** — necesita `SET LOCAL` |

**Android usa el usuario `postgres` de Supabase.** Este usuario es superadmin y tiene `BYPASSRLS = true` por defecto en PostgreSQL. Habilitar RLS **no rompe nada en Android** independientemente del puerto (6543 o cualquier otro).

### Transaction Pooler (puerto 6543) y SET LOCAL

El puerto 6543 es el **Transaction Pooler** de Supabase (pgbouncer en modo transacción). En este modo:

- La conexión se devuelve al pool al finalizar cada transacción
- `SET LOCAL` solo vive dentro de la transacción actual
- Sin `BEGIN` explícito, cada statement es su propia transacción → `SET LOCAL` solo aplica a ese statement

**Para N8N y Python usando el pooler, el patrón obligatorio es:**

```sql
-- Siempre envolver en transacción explícita
BEGIN;
SELECT set_config('app.current_business_unit_id', '2', true);
SELECT * FROM employees;  -- ve solo empleados de la BU 2
COMMIT;
```

**Alternativa**: conectar a Supabase por la conexión directa (no el pooler) usando el host `db.<project-ref>.supabase.co:5432` — en ese caso `SET LOCAL` sin `BEGIN` funciona porque la conexión es persistente (sesión dedicada).

### Comportamiento de seguridad si se olvida establecer la BU

Si `app_user` hace una query sin establecer `business_unit_id`:

- `current_setting('app.current_business_unit_id', true)` devuelve `NULL`
- La policy `USING (business_unit_id = NULL::int)` nunca evalúa a `TRUE`
- Resultado: **0 filas** — falla segura, no expone datos de otras BUs

### Cómo ejecutar el SQL

1. Ir a Supabase Dashboard → SQL Editor
2. Abrir `Documentacion/seguridad/rls_policies.sql`
3. Reemplazar `CAMBIAR_EN_PRODUCCION` con un password seguro para `app_user`
4. Ejecutar el script completo
5. Verificar con la query final del script que todas las tablas tienen `rls_enabled = true`
6. Cuando N8N o Python necesiten acceso directo a BD, usar `app_user` con el patrón `BEGIN; set_config(); query; COMMIT;`

### Tablas cubiertas (34 tablas)

```text
alert_contacts, alert_rules, alerts, api_users,
business_units_concessionaires, client_employees, client_users,
clients, coo_travel_employee_requests, coo_travel_requests,
discrepancies, driver_requests, employee_appointment_logs,
employee_appointments, employees, employees_incidences,
gas_charges, gas_files, gas_stations, gasoline_charges,
incidences, invoicings, kumi_settings, labors, payrolls,
roles, scheduled_maintenances, service_appointments, suppliers,
travel_counts, ttpn_bookings, users, vehicle_asignations, vehicles
```

### Tablas sin RLS (intencionalmente)

Catálogos compartidos entre BUs — no tienen `business_unit_id`:

```text
vehicle_types, employee_document_types, vehicle_document_types,
ttpn_service_types, ttpn_services, concessionaires,
privileges, role_privileges, versions (PaperTrail)
```

---

## Checklist de Verificación en Producción

```bash
# Verificar headers de la API
curl -I https://kumi-admin-api-production.up.railway.app/api/v1/health

# Buscar en la respuesta:
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# Strict-Transport-Security: max-age=...
# Permissions-Policy: camera=()...

# Verificar headers del frontend
curl -I https://kumi.ttpn.com.mx

# Verificar CORS (debe rechazar origen no autorizado)
curl -H "Origin: https://sitio-malicioso.com" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     https://kumi-admin-api-production.up.railway.app/api/v1/health
# Debe responder sin Access-Control-Allow-Origin o con el dominio bloqueado
```

Herramienta online: [securityheaders.com](https://securityheaders.com)

---

## Pendientes

- [ ] **RLS**: Ejecutar `rls_policies.sql` en Supabase (dev y prod)
- [ ] **RLS**: Actualizar N8N para usar rol `app_user` + `SET LOCAL` antes de queries
- [ ] **RLS**: Actualizar scripts Python (`utils/db.py`) para usar `app_user` y `SET LOCAL`
- [ ] **FRONTEND_URL**: Verificar que Railway tiene la variable `FRONTEND_URL=https://kumi.ttpn.com.mx` configurada
- [ ] **`_headers`**: Verificar que Netlify aplica correctamente (abrir DevTools → Network → Response Headers)
- [ ] **ActionCable**: Revisar si el dominio custom `kumi.ttpn.com.mx` está en `allowed_request_origins` de `application.rb`
