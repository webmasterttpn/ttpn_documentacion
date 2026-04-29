# Dominio: Alertas

Sistema de alertas automáticas: reglas de disparo, destinatarios, entregas y lecturas.

## Modelos principales

| Modelo | Descripción |
| --- | --- |
| `Alert` | Alerta generada |
| `AlertRule` | Regla que dispara una alerta (condición + threshold) |
| `AlertRuleRecipient` | Destinatarios de una regla |
| `AlertDelivery` | Registro de entrega de una alerta (email, push, etc.) |
| `AlertRead` | Registro de lectura por usuario |
| `AlertContact` | Contacto externo para alertas |

## Estado de documentación

Pendiente. Hay una propuesta inicial en _archivo/session_notes/ALERTS_PROPOSAL.md.

## Archivos Rails relacionados

```text
app/models/alert.rb
app/models/alert_rule.rb
app/models/alert_rule_recipient.rb
app/models/alert_delivery.rb
app/models/alert_read.rb
app/controllers/api/v1/alerts_controller.rb
```
