# ADR-007 — ActionCable WebSocket en lugar de Polling HTTP para Jobs Asíncronos

**Fecha:** 2026-04-28  
**Estado:** Aceptado  
**Autor:** Antonio Castellanos

---

## Contexto

Varios flujos del sistema (dashboard, nóminas, importación de reservas, Excel de facturación)
ejecutaban jobs largos en Sidekiq y notificaban al frontend mediante `setInterval` con polling
cada 1.5–2 segundos al endpoint `/status/:job_id`.

Problemas del enfoque:

- **CPU y red innecesarios**: cada tab abierta generaba N requests/segundo aunque el job no hubiera terminado.
- **Latencia artificial**: el frontend se enteraba del resultado hasta el siguiente tick del intervalo.
- **Memory leaks potenciales**: intervals no limpiados al navegar entre rutas dejaban goroutines activas.
- **Escala mal**: 10 usuarios simultáneos con 3 tabs cada uno = 30 requests/segundo de pura overhead.

---

## Opciones consideradas

| Opción | Ventaja | Desventaja |
|---|---|---|
| Polling `setInterval` | Simple de implementar | CPU/red constante, latencia artificial |
| Server-Sent Events (SSE) | Unidireccional, simple | No soporta múltiples canales por conexión fácilmente |
| **ActionCable WebSocket** | Bidireccional, ya incluido en Rails, comparte auth JWT | Requiere configurar origenes, Redis como adapter |
| Long-polling | Compatible con proxies sin WS | Complejidad de manejo de colas de respuesta |

---

## Decisión

Usar **ActionCable** con un canal centralizado `JobStatusChannel` por usuario.

### Patrón implementado

```
FE lanza job → BE retorna job_id → FE suscribe JobStatusChannel
                                         ↓
                              Job termina → broadcast("job_status_#{user_id}", payload)
                                         ↓
                              FE recibe msg → actualiza UI sin ningún request HTTP
```

**Canal:** `JobStatusChannel` — stream key `job_status_#{user_id}`.  
**Adapter:** Redis (ya existente para Sidekiq).  
**Autenticación:** JWT via query param `?token=` en la URL del WebSocket (mismo token que la API REST).

### Regla de decisión para nuevos jobs

| Pregunta | Sí → | No → |
|---|---|---|
| ¿El usuario espera el resultado en pantalla? | ActionCable broadcast | Sin WebSocket |
| ¿La operación termina en < 2 s? | Síncrono (sin job) | Job + broadcast |
| ¿Afecta a múltiples usuarios de la misma BU? | Broadcast a `canal_#{bu_id}` | Broadcast a `job_status_#{user_id}` |

---

## Implementación

### Backend

- `app/channels/job_status_channel.rb` — stream por usuario
- `app/channels/application_cable/connection.rb` — auth JWT (`payload['user_id']`)
- `config/application.rb` — `config.action_cable.allowed_request_origins` con dominios de producción
- Workers: `PayrollProcessWorker`, `InvoicingExcelWorker` y jobs de dashboard hacen `ActionCable.server.broadcast` al finalizar

### Frontend

- `src/boot/actioncable.js` — singleton consumer con `getConsumer()` / `disconnectConsumer()`
- `auth-store.js` — llama `disconnectConsumer()` en logout
- Composables migrados: `useTtpnData`, `useTtpnBookingImport`
- Pages migradas: `PayrollsPage`, `TtpnPayrollPage`, `TtpnInvoicingPage`

---

## Configuración de producción

Railway soporta WebSocket nativamente. Se requiere:

1. `config.action_cable.allowed_request_origins` con el dominio de Netlify (`kumi.ttpn.com.mx`)
2. `REDIS_URL` disponible en Railway (ya existente para Sidekiq)
3. `VITE_WS_URL` / `API_URL` en el build de Netlify apuntando a Railway (inyectado via `ctx.prod` en `quasar.config.js`)

---

## Consecuencias

**Positivas:**
- Eliminado el polling — 0 requests innecesarios mientras el job corre
- Latencia de notificación: < 100ms (vs hasta 2000ms con polling)
- Un solo WebSocket por sesión compartido por todos los composables

**Negativas / Trade-offs:**
- Si el WebSocket cae antes de que el job termine, el FE no recibe el resultado.
  Mitigación: el usuario puede recargar la página y volver a lanzar el job.
- Los WebSockets requieren configuración extra de CORS/origins vs HTTP simple.
- Railway debe soportar conexiones persistentes (lo hace, pero hay que verificar en upgrades de plan).
