# 08 — WebSockets, ActionCable y Webhooks

**Para leer con calma. Sin conocimiento previo del tema.**

---

## El problema que resuelve esto

Antes de esta implementación, cada vez que el FE lanzaba un proceso pesado
(dashboard, exportación, importación), hacía esto:

```
FE: "¿Ya terminó?" → API: "Aún no" (cada 1.5 segundos)
FE: "¿Ya terminó?" → API: "Aún no"
FE: "¿Ya terminó?" → API: "Aún no"
FE: "¿Ya terminó?" → API: "Sí, aquí están los datos"
```

Con 10 usuarios simultáneos = **~7 requests HTTP por segundo** al servidor
consumiendo memoria, threads de Rails y CPU — sin hacer trabajo real.

La solución es invertir la dirección: **el servidor avisa al FE cuando termina**,
en lugar de que el FE pregunte constantemente.

---

## Tres conceptos que necesitas entender

### 1. Polling (lo que teníamos)

```
FE ──GET──► API  cada 1.5s
FE ◄──JSON── API  "no terminé"
FE ──GET──► API
FE ◄──JSON── API  "no terminé"
FE ──GET──► API
FE ◄──JSON── API  "terminé, aquí los datos"
```

- Conexión HTTP nueva por cada request
- El servidor espera preguntas — nunca habla primero
- Gasta memoria aunque no haya nada nuevo que reportar

### 2. WebSocket / ActionCable (lo que usamos para FE↔BE interno)

```
FE ──────────── conecta WebSocket ──────────► Rails
               (conexión persistente abierta)

Rails ◄─────── "suscríbeme al canal JobStatus" ─── FE
Rails ──── "el job terminó, aquí los datos" ──────► FE
               (Rails habla cuando quiere, sin que FE pregunte)
```

- **Una sola conexión** abierta por usuario (no una por request)
- El servidor empuja datos cuando hay algo nuevo
- Sin polling, sin requests repetidos
- Rails tiene **ActionCable** para esto — ya viene incluido

### 3. Webhook (para sistemas externos → nuestro servidor)

```
WhatsApp ──POST /api/v1/webhooks/whatsapp──► Rails
GPS API  ──POST /api/v1/webhooks/gps──────► Rails
n8n      ──POST /api/v1/webhooks/n8n──────► Rails

Rails recibe, procesa y puede avisar al FE vía ActionCable:
Rails ──────────── ActionCable ──────────► FE (usuario ve la notificación)
```

- El sistema externo llama a nuestro endpoint cuando pasa algo
- Es un POST HTTP estándar — no necesita conexión persistente
- Nosotros validamos que viene del emisor correcto (firma HMAC o token secreto)

---

## Cuándo usar cada uno

| Situación | Solución | Razón |
|---|---|---|
| Job largo (dashboard, export, import) | **ActionCable** | FE espera resultado, servidor avisa al terminar |
| Alertas en tiempo real | **ActionCable** | Ya implementado — notificar a usuarios de la BU |
| Notificaciones push internas | **ActionCable** | Campana de alertas |
| WhatsApp nos manda un mensaje | **Webhook entrante** | WhatsApp llama a nuestra API |
| GPS avisa que llegó un vehículo | **Webhook entrante** | Proveedor externo llama a nuestra API |
| Nosotros avisamos a otro sistema | **Webhook saliente** | Nosotros hacemos POST a la URL del cliente |
| Datos que cambian cada hora+ | **Polling cada 5min** | No vale la pena WebSocket |
| Datos en tiempo real de alta frecuencia | **ActionCable** | Updates continuos |

**Regla simple:** ¿Quién inicia la conversación?
- FE espera algo del BE → **ActionCable**
- Sistema externo nos notifica → **Webhook entrante**
- El usuario pidió algo y necesita saber cuándo terminó → **ActionCable**
- Necesito avisar a otro servidor → **Webhook saliente**

---

## Arquitectura completa implementada

```
┌────────────────────────────────────────────────────────────────┐
│  BROWSER (Vue/Quasar)                                          │
│                                                                │
│  boot/actioncable.js ── crea Consumer (una conexión global)    │
│                                    │                           │
│  AlertBell.vue ── suscribe ────────┤ AlertsChannel             │
│  useDashboardData.js ── suscribe ──┤ JobStatusChannel          │
│  useDashboardExport.js ── suscribe─┤ JobStatusChannel          │
│  useTtpnBookingImport.js ── suscribe JobStatusChannel          │
└───────────────────────┬────────────────────────────────────────┘
                        │  ws://<host>/cable?token=<jwt>
┌───────────────────────▼────────────────────────────────────────┐
│  RAILS (ActionCable)                                           │
│                                                                │
│  Connection < ActionCable::Connection::Base                    │
│    → verifica JWT del query param ?token=                      │
│    → identifica current_user                                   │
│                                                                │
│  AlertsChannel                                                 │
│    → stream_from "alerts_#{business_unit_id}"                  │
│    → recibe: new_alert, all_read                               │
│                                                                │
│  JobStatusChannel  ← NUEVO                                     │
│    → stream_from "job_status_#{user_id}"                       │
│    → recibe: job_done, job_progress, job_failed                │
│                                                                │
│  Sidekiq Workers (al terminar broadcasetean):                  │
│    DashboardCalculationJob → job_done → user_id                │
│    DashboardExportJob      → job_done → user_id                │
│    TtpnCalculationJob      → job_done → user_id                │
│    TtpnBookingImportJob    → job_done → user_id                │
└───────────────────────┬────────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────────┐
│  SISTEMAS EXTERNOS (Webhooks entrantes)                        │
│                                                                │
│  POST /api/v1/webhooks/whatsapp  ← WhatsApp Cloud API          │
│  POST /api/v1/webhooks/generic   ← cualquier sistema           │
│                                                                │
│  WebhooksController:                                           │
│    1. Verifica HMAC secret header                              │
│    2. Procesa el evento                                        │
│    3. Opcional: broadcast por ActionCable al FE                │
│    4. Responde 200 OK inmediatamente                           │
└────────────────────────────────────────────────────────────────┘
```

---

## Flujo detallado: Dashboard con ActionCable

### Antes (polling)
```
1. FE: POST /api/v1/dashboard/initiate_load → recibe job_id
2. FE: setInterval cada 1500ms:
   → GET /api/v1/dashboard/load_status/JOB_ID
   ← "aún no"  (repite 5-10 veces)
   ← "terminé, aquí los datos"
3. FE: clearInterval, muestra datos
```

### Ahora (ActionCable)
```
1. FE: se conecta al WebSocket en el mount de la app
2. FE: suscribe a JobStatusChannel (una vez)
3. FE: POST /api/v1/dashboard/initiate_load → recibe job_id
4. Sidekiq: procesa DashboardCalculationJob
5. Sidekiq: al terminar → ActionCable.server.broadcast("job_status_#{user_id}", {...})
6. FE: recibe el broadcast → muestra datos
   (sin un solo request HTTP de polling)
```

---

## Los archivos y qué hace cada uno

### Backend

#### `app/channels/job_status_channel.rb` (NUEVO)
```ruby
class JobStatusChannel < ApplicationCable::Channel
  def subscribed
    # Cada usuario tiene su propio canal — nadie ve jobs ajenos
    stream_from "job_status_#{current_user.id}"
  end
end
```

#### Jobs — qué se agrega al final de `perform`
```ruby
# Al terminar el trabajo, en vez de solo store():
ActionCable.server.broadcast(
  "job_status_#{user_id}",
  {
    type:     'job_done',
    job_id:   jid,           # jid = Sidekiq job ID automático
    status:   'complete',
    progress: 100,
    data:     { ... }        # resultado del job
  }
)
```

Si el job falla (en `rescue`):
```ruby
ActionCable.server.broadcast(
  "job_status_#{user_id}",
  { type: 'job_failed', job_id: jid, error: e.message }
)
```

#### `app/controllers/api/v1/webhooks_controller.rb` (NUEVO)
```ruby
class Api::V1::WebhooksController < ApplicationController
  skip_before_action :authenticate_request!   # no lleva JWT — viene del exterior
  before_action :verify_signature             # verifica que es quien dice ser

  def whatsapp
    event = params.permit!.to_h              # aceptar todo — validar manualmente
    # procesar evento, crear alertas, etc.
    head :ok                                  # SIEMPRE responder 200 rápido
  end

  private

  def verify_signature
    secret   = ENV['WHATSAPP_WEBHOOK_SECRET']
    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)
    received = request.headers['X-Hub-Signature-256']&.delete_prefix('sha256=')
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end
end
```

### Frontend

#### `src/boot/actioncable.js` (NUEVO)
```js
import { createConsumer } from '@rails/actioncable'

let _consumer = null

// getConsumer() se llama desde composables — crea la conexión una sola vez
export function getConsumer() {
  if (!_consumer) {
    const token  = localStorage.getItem('jwt_token')
    const wsBase = import.meta.env.VITE_WS_URL || window.location.origin.replace(/^http/, 'ws')
    _consumer = createConsumer(`${wsBase}/cable?token=${token}`)
  }
  return _consumer
}

export function disconnectConsumer() {
  _consumer?.disconnect()
  _consumer = null
}
```

#### Patrón en composables — reemplazar `_pollXxx` con cable
```js
// ANTES:
const timer = setInterval(async () => {
  const res = await dashboardService.loadStatus(jobId)
  if (res.data.status === 'complete') { clearInterval(timer); ... }
}, 1500)

// AHORA:
import { getConsumer } from 'boot/actioncable'

let _sub = null

function _subscribeJobStatus(jobId, onDone, onError) {
  const consumer = getConsumer()
  _sub = consumer.subscriptions.create('JobStatusChannel', {
    received(data) {
      if (data.job_id !== jobId) return      // ignorar jobs de otras pestañas
      if (data.type === 'job_done')   onDone(data)
      if (data.type === 'job_failed') onError(data)
      _sub.unsubscribe()                      // limpiar al recibir resultado
      _sub = null
    }
  })
}
```

---

## Webhooks entrantes — guía de integración

### ¿Qué es un webhook entrante?

El proveedor externo (WhatsApp, GPS, n8n) te pide que les des una URL pública.
Cuando pasa algo (llega un mensaje, el vehículo se mueve), ellos hacen un POST
a tu URL con los datos del evento.

### Pasos para agregar un webhook nuevo

1. **Crear el endpoint** en `webhooks_controller.rb`:
```ruby
def mi_proveedor
  payload = JSON.parse(request.raw_post)
  # procesar
  head :ok
end
```

2. **Agregar la ruta** en `config/routes/webhooks.rb`:
```ruby
post 'mi_proveedor', to: 'api/v1/webhooks#mi_proveedor'
```

3. **Verificar la firma** — cada proveedor usa un mecanismo diferente:
   - WhatsApp: `X-Hub-Signature-256: sha256=<hmac>`
   - Stripe: `Stripe-Signature`
   - n8n: token en query param

4. **Responder 200 inmediatamente** — si tardas más de 5s, el proveedor
   reintentará pensando que falló. Encola el procesamiento en Sidekiq:
```ruby
def whatsapp
  payload = request.raw_post          # guardar antes de async
  WhatsappEventJob.perform_later(payload)
  head :ok                            # ← responde rápido
end
```

5. **Registrar la URL con el proveedor** — en producción usarás Railway:
   `https://kumi-api.railway.app/api/v1/webhooks/whatsapp`

6. **Para desarrollo local** — usa ngrok para exponer tu puerto 3000:
```bash
ngrok http 3000
# Te da: https://abc123.ngrok.io
# Registras: https://abc123.ngrok.io/api/v1/webhooks/whatsapp
```

---

## Checklist antes de implementar un job nuevo

Antes de crear cualquier job de Sidekiq, responde estas preguntas:

### 1. ¿El usuario necesita saber cuándo terminó?
- **Sí** → El job debe hacer `ActionCable.server.broadcast` al terminar
- **No** (cron nocturno, tarea de limpieza) → solo `store(completed: true)` es suficiente

### 2. ¿Cuánto tiempo tarda?
- **< 2 segundos** → No necesita job. Hazlo síncrono en el controller
- **2s - 5 minutos** → Job + ActionCable broadcast
- **> 5 minutos** → Job + ActionCable broadcast por progreso + resultado final

### 3. ¿El evento viene de un sistema externo?
- **Sí** → Necesitas webhook entrante con verificación de firma
- **No** → Solo ActionCable es suficiente

### 4. ¿Necesitas notificar a múltiples usuarios de la misma BU?
- **Sí** → broadcast a `"canal_#{business_unit_id}"` (como AlertsChannel)
- **Solo al usuario que lo lanzó** → broadcast a `"job_status_#{user_id}"`

---

## Configuración obligatoria en producción

### 1. Orígenes permitidos para WebSocket (`config/application.rb`)

ActionCable tiene su propio control de orígenes, **independiente del CORS de Rack**.
Si no se configura, rechaza todas las conexiones WebSocket de producción con
`Request origin not allowed`.

```ruby
config.action_cable.allowed_request_origins = [
  'https://kumi.ttpn.com.mx',
  'https://ttpn.com.mx',
  /https:\/\/.*\.netlify\.app/,
  /https:\/\/.*\.devtunnels\.ms/,
  'http://localhost:9000',
  'http://localhost:9200',
]
```

### 2. URL del WebSocket en el build de Netlify (`quasar.config.js`)

Netlify (plan gratuito) no permite configurar variables de entorno. El `.env` local
tiene `API_URL=http://localhost:3000`, que Quasar inyecta en el build.
Si no se corrige, el browser en producción intenta conectar a `ws://localhost:3000`.

Solución — usar `ctx.prod` en `quasar.config.js`:

```js
const PROD_API_URL = 'https://kumi-admin-api-production.up.railway.app'

export default defineConfig((ctx) => {
  const apiUrl = ctx.prod ? PROD_API_URL : (process.env.API_URL || 'http://localhost:3000')
  const wsUrl  = ctx.prod
    ? PROD_API_URL.replace(/^https/, 'wss')
    : (process.env.VITE_WS_URL || 'ws://localhost:3000')

  return {
    build: {
      env: { API_URL: apiUrl, VITE_WS_URL: wsUrl },
    },
    ...
  }
})
```

---

## Variables de entorno nuevas

```bash
# En ttpngas/.env
VITE_WS_URL=ws://localhost:3000          # FE → para desarrollo local

# En ttpn-frontend/.env
VITE_WS_URL=ws://localhost:3000          # WebSocket URL del backend
# En producción: wss://kumi-api.railway.app

# Webhooks — secretos por proveedor
WHATSAPP_WEBHOOK_SECRET=                 # Secret de la app de WhatsApp Business
WHATSAPP_API_TOKEN=                      # Token para enviar mensajes
WEBHOOK_SECRET_GENERIC=                  # Para webhooks sin proveedor específico
```

---

## Comandos útiles

```bash
# ── Verificar que ActionCable conecta ────────────────────────────────────────
# Abrir la consola del navegador y buscar:
# "ActionCable: Opened connection" en la tab Network (filtro: WS)

# ── Ver subscripciones activas en Rails console ──────────────────────────────
docker compose exec kumi_api bundle exec rails console
>> ActionCable.server.connections.size
>> ActionCable.server.connections.map(&:current_user).map(&:email)

# ── Testear broadcast manualmente ────────────────────────────────────────────
>> ActionCable.server.broadcast("job_status_1", { type: 'job_done', job_id: 'test', data: {} })

# ── Ver mensajes WebSocket en el navegador ───────────────────────────────────
# DevTools → Network → WS → selecciona la conexión /cable → tab Messages

# ── Instalar @rails/actioncable en el FE ────────────────────────────────────
cd ttpn-frontend && npm install @rails/actioncable

# ── Webhooks locales con ngrok ───────────────────────────────────────────────
ngrok http 3000
# Usar la URL https que ngrok genera para registrar en el proveedor externo
```

---

## Troubleshooting

| Problema | Causa probable | Solución |
|---|---|---|
| WebSocket no conecta | JWT expirado o `VITE_WS_URL` incorrecto | Verificar URL en DevTools Network → WS |
| `window.ActionCable is undefined` | Librería no instalada como npm | `npm install @rails/actioncable` |
| Broadcast no llega al FE | `user_id` incorrecto en el canal | Verificar que el job usa el mismo `user_id` que la suscripción |
| Webhook recibe 401 | Firma HMAC no coincide | Verificar `WEBHOOK_SECRET` y algoritmo del proveedor |
| Job termina pero FE no reacciona | `job_id` de la suscripción no coincide | Confirmar que el FE filtra por `data.job_id` |
| Suscripción duplicada | No se llama `unsubscribe()` al desmontar | Llamar `_sub?.unsubscribe()` en `onUnmounted` |

---

## Archivos modificados en esta implementación

### Backend (ttpngas/)
| Archivo | Acción |
|---|---|
| `app/channels/job_status_channel.rb` | CREADO — canal por usuario |
| `app/controllers/api/v1/webhooks_controller.rb` | CREADO — receptor de webhooks externos |
| `config/routes/webhooks.rb` | CREADO — rutas de webhooks |
| `config/routes.rb` | MODIFICADO — `draw :webhooks` |
| `app/jobs/dashboard_calculation_job.rb` | MODIFICADO — broadcast al terminar |
| `app/jobs/dashboard_export_job.rb` | MODIFICADO — broadcast al terminar |
| `app/jobs/ttpn_calculation_job.rb` | MODIFICADO — broadcast al terminar |
| `app/jobs/ttpn_booking_import_job.rb` | MODIFICADO — broadcast al terminar |

### Frontend (ttpn-frontend/)
| Archivo | Acción |
|---|---|
| `src/boot/actioncable.js` | CREADO — setup de ActionCable |
| `quasar.config.js` | MODIFICADO — agregar boot actioncable |
| `src/components/AlertBell.vue` | MODIFICADO — usa npm package en vez de CDN |
| `src/composables/Dashboard/useDashboardData.js` | MODIFICADO — elimina polling 1500ms |
| `src/composables/Dashboard/useDashboardExport.js` | MODIFICADO — elimina polling 2000ms |
