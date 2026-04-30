# Dominio: Alertas

Sistema de alertas automáticas. Las reglas definen condiciones de disparo y destinatarios. Cuando se cumple una condición, el sistema genera una alerta y la entrega por múltiples canales (email, web push, WebSocket).

---

## Modelos principales

| Modelo | Tabla | Descripción |
| --- | --- | --- |
| `AlertRule` | `alert_rules` | Regla: condición, threshold, frecuencia de evaluación |
| `AlertRuleRecipient` | `alert_rule_recipients` | Qué usuarios o contactos reciben cada regla |
| `AlertContact` | `alert_contacts` | Contacto externo (email, teléfono) que recibe alertas sin tener cuenta |
| `Alert` | `alerts` | Instancia generada cuando se dispara una regla |
| `AlertDelivery` | `alert_deliveries` | Registro de entrega por canal (email / push / websocket) |
| `AlertRead` | `alert_reads` | Registro de lectura: qué usuario leyó qué alerta y cuándo |

---

## Flujo completo

```text
[Evento / Cron]
      │
      ▼
AlertDispatchJob
      │
      ├── Evalúa AlertRule(s)
      │
      ├── Si se cumple la condición:
      │       └── Crea Alert
      │
      └── Para cada destinatario (AlertRuleRecipient):
              ├── Alerts::EmailSenderService   → AlertMailer → SendGrid
              ├── Alerts::PushSenderService    → Web Push API
              └── AlertsChannel.broadcast_to  → ActionCable WebSocket
                        │
                        └── AlertBell.vue actualiza badge en tiempo real
```

---

## Services

| Service | Ubicación | Responsabilidad |
| --- | --- | --- |
| `Alerts::DispatcherService` | `app/services/alerts/dispatcher_service.rb` | Orquesta la evaluación de reglas y creación de alertas |
| `Alerts::EmailSenderService` | `app/services/alerts/email_sender_service.rb` | Envía alerta por email via AlertMailer |
| `Alerts::PushSenderService` | `app/services/alerts/push_sender_service.rb` | Envía web push notification |

---

## Jobs

| Job | Queue | Trigger |
| --- | --- | --- |
| `AlertDispatchJob` | `alerts` | sidekiq-cron (periódico) o encolado manualmente |

---

## Canal WebSocket

`AlertsChannel < ApplicationCable::Channel`

El frontend se suscribe al canal en el boot. Cuando llega un broadcast, `AlertBell.vue` incrementa el badge sin recargar la página.

```javascript
// src/boot/cable.js
cable.subscriptions.create({ channel: 'AlertsChannel' }, {
  received(data) {
    alertStore.addAlert(data)
  }
})
```

---

## Controllers

```text
app/controllers/api/v1/alerts_controller.rb
app/controllers/api/v1/alert_rules_controller.rb
app/controllers/api/v1/alert_contacts_controller.rb
```

---

## Archivos Rails completos

```text
app/models/alert.rb
app/models/alert_rule.rb
app/models/alert_rule_recipient.rb
app/models/alert_contact.rb
app/models/alert_delivery.rb
app/models/alert_read.rb
app/services/alerts/dispatcher_service.rb
app/services/alerts/email_sender_service.rb
app/services/alerts/push_sender_service.rb
app/jobs/alert_dispatch_job.rb
app/mailers/alert_mailer.rb
app/channels/alerts_channel.rb
app/controllers/api/v1/alerts_controller.rb
```
