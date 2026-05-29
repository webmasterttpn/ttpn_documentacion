# Agente IA Multi-Canal — TTPN

Documentación del Agente IA conversacional de Kumi TTPN. El agente atiende clientes y operación a través de **3 canales unificados**, todos compartiendo la misma base de conocimiento y lógica de negocio.

---

## Canales

| Canal | Estado | Doc principal |
|---|---|---|
| **Voz** (Retell AI vía Twilio) | Borrador / configuración | [voz/RETELL_TEMPLATE.md](voz/RETELL_TEMPLATE.md) |
| **Correo electrónico** | Por implementar | [correo/](correo/) |
| **WhatsApp** | Por implementar | [whatsapp/](whatsapp/) |

---

## Arquitectura común

- **Base de conocimiento**: Kumi Admin V2 (clientes, servicios, viajes programados, estado de facturación). El agente lee/escribe via API REST `/api/v1/*` con API Key dedicada.
- **Identidad consistente**: mismo tono, glosario y políticas en los 3 canales. Definidos en el template de voz y replicados en correo/whatsapp.
- **Logs centralizados**: cada conversación queda registrada en BD (tabla pendiente de definir) con `canal`, `usuario_id`, `transcripción`, `acciones_ejecutadas`.

## Convenciones

- Cada canal vive en su subcarpeta (`voz/`, `correo/`, `whatsapp/`).
- Cada subcarpeta tiene su propio README + un archivo de configuración/template.
- Cambios en la **base de conocimiento compartida** (tono, glosario, FAQs) van en `compartido/` cuando se cree.
