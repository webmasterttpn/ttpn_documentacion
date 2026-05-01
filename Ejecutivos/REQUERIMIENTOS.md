# Agente de Voz — Autos Ejecutivos TTPN

**Estado:** Documento vivo — en discusión, NO iniciar codificación aún  
**Última actualización:** 2026-04-30 (rev 2)  
**Propósito:** Centralizar todos los requerimientos, decisiones y pendientes antes de comenzar el desarrollo

---

## 1. Visión del Negocio

Autos Ejecutivos es un negocio paralelo de TTPN que ofrece traslados en camionetas ejecutivas. La administración de estos viajes **vivirá dentro de Kumi** como una nueva BusinessUnit, reutilizando la infraestructura existente.

### Decisiones de arquitectura confirmadas

| Concepto | Implementación en Kumi |
|---|---|
| Unidad de negocio | Nueva `BusinessUnit` en Kumi (`autos_ejecutivos`) |
| Empleados | Modelo `Employee` existente — rol: choferes |
| Vehículos | Nuevo catálogo de unidades ejecutivas (modelo `Vehicle` o tabla específica) |
| Reservaciones | `TtpnBooking` — reutilizado |
| Calendario | Nuevo calendario de viajes (a definir — ¿extensión de TtpnBooking o modelo nuevo?) |
| Multi-tenancy | Aislado por `business_unit_id` igual que el resto de Kumi |

### Lógica de disponibilidad

Un vehículo está **disponible** si cumple **cualquiera** de estas condiciones:
1. No tiene asignación (`VehicleAsignacion` inexistente o inactiva)
2. Tiene asignación pero **no tiene viaje programado** en el slot de tiempo solicitado

Pseudocódigo de consulta:
```ruby
Vehicle.ejecutivos.disponibles_en(fecha_inicio, fecha_fin)
# WHERE id NOT IN (
#   SELECT vehicle_id FROM ttpn_bookings
#   WHERE status IN ['confirmado', 'en_curso']
#   AND fecha_inicio < :fecha_fin AND fecha_fin > :fecha_inicio
# )
```

---

## 2. Agente de Voz — Stack Tecnológico

Basado en el análisis de [sofia-voice-agent](https://github.com/santmun/sofia-voice-agent) (Retell AI + Twilio + Claude), adaptado al contexto TTPN.

### Componentes

| Capa | Tecnología | Función |
|---|---|---|
| Telefonía | **Twilio** | Número mexicano, SIP trunk, recibir/hacer llamadas |
| Voice AI | **Retell AI** | STT + TTS + orquestación de conversación (<500ms latencia) |
| Razonamiento | **Claude Sonnet 4.5+** | LLM para entender intención, llamar tools, generar respuestas |
| Backend | **Rails API (Kumi)** | Endpoints para tools del agente (disponibilidad, booking, precios) |
| Post-llamada | **N8N** | Automatizaciones: confirmación por WhatsApp, resumen al chofer, CRM |
| Auth M2M | **API Keys** | Retell → Kumi usando el sistema de API Keys existente |

### Alternativa de backend

Sofia usa **Modal** (Python serverless). Para TTPN, el backend ya existe en Rails — los tools del agente serán endpoints dedicados en Kumi, sin necesidad de un backend separado.

---

## 3. Tools del Agente

Funciones que el LLM puede llamar durante la conversación:

| Tool | Descripción | Endpoint Kumi |
|---|---|---|
| `check_availability` | Verificar disponibilidad para fecha/hora/ruta | `GET /api/v1/ejecutivos/disponibilidad` |
| `get_pricing` | Cotizar traslado por ruta/distancia/tipo de unidad | `GET /api/v1/ejecutivos/cotizacion` |
| `lookup_client` | Buscar cliente por teléfono o nombre | `GET /api/v1/ejecutivos/clientes` |
| `create_booking` | Crear reserva preliminar (estado: pendiente) | `POST /api/v1/ejecutivos/bookings` |
| `confirm_booking` | Confirmar reserva (cobro o validación) | `PATCH /api/v1/ejecutivos/bookings/:id/confirmar` |
| `cancel_booking` | Cancelar reserva existente | `PATCH /api/v1/ejecutivos/bookings/:id/cancelar` |
| `get_booking_status` | Consultar estado de reserva por folio | `GET /api/v1/ejecutivos/bookings/:folio` |

### Datos que el agente debe capturar en llamada

- Fecha y hora del servicio
- Origen y destino (aeropuerto, hotel, dirección, etc.)
- Número de pasajeros
- Tipo de unidad (si el cliente tiene preferencia)
- Nombre del pasajero
- Teléfono de contacto
- Número de vuelo (si aplica — para rastreo de llegadas)

---

## 4. System Prompt Base (borrador)

```
Eres Sofía, asistente virtual de TTPN Autos Ejecutivos. Ayudas a los clientes 
a reservar traslados en vehículos ejecutivos de manera rápida y profesional.

CONTEXTO:
- Servicio de traslados ejecutivos en [Ciudad/Región]
- Flota: camionetas ejecutivas con chofer profesional
- Horario de servicio: [definir]

PERSONALIDAD:
- Profesional, amable y eficiente
- Tono formal pero accesible

IDIOMA:
- Detecta automáticamente el idioma del cliente desde su primer mensaje.
- Responde SIEMPRE en el mismo idioma que el cliente.
- Idiomas soportados: español e inglés.
- Si el idioma no es identificable con certeza, pregunta: "¿Prefiere continuar en español o in English?"
- Una vez detectado el idioma, mantenerlo durante toda la llamada.

FLUJO ESTÁNDAR:
1. Saludar e identificar necesidad
2. Verificar disponibilidad para la fecha/hora solicitada
3. Cotizar el servicio
4. Recopilar datos del pasajero si el cliente confirma
5. Crear la reserva
6. Confirmar los detalles por voz
7. Informar que llegará confirmación por WhatsApp

RESTRICCIONES:
- No ofrecer descuentos sin autorización
- Si el cliente pregunta por precios especiales, decir que un ejecutivo lo contactará
- No confirmar bookings sin capturar nombre, teléfono, origen y destino
- Máximo 2 intentos de aclaración antes de transferir con un operador humano
```

> **Pendiente:** Ajustar horarios, zonas de servicio y políticas de precios reales.

---

## 5. Flujo Completo de una Llamada

```
Cliente llama al número TTPN Ejecutivos
         │
         ▼
    Twilio (SIP)
         │
         ▼
    Retell AI ←──────────────────────────────────┐
    (STT + TTS)                                  │
         │                                       │
         ▼                                 Respuesta voz
    Claude Sonnet                                │
    (LLM + Tools)                                │
         │                                       │
    ┌────┴────┐                                  │
    │         │                                  │
Tool calls   Respuesta                           │
    │         └────────────────────────────────→─┘
    ▼
Kumi API (Rails)
    ├── check_availability → Vehicle.disponibles_en(slot)
    ├── get_pricing → TarifaService.calcular(origen, destino)
    ├── lookup_client → Cliente.by_phone(tel)
    ├── create_booking → TtpnBooking.create(...)
    └── confirm_booking → TtpnBooking.confirmar(...)
         │
         ▼
    N8N Webhook (post-llamada)
    ├── Enviar confirmación por WhatsApp (Twilio / WA Business)
    ├── Notificar al chofer asignado
    ├── Registrar lead/cliente en CRM
    └── Enviar correo resumen al administrador (SIEMPRE en español)
```

---

## 6. Detección de Idioma y Notificación al Administrador

### Detección de idioma

Retell AI transcribe la voz del cliente a texto. Claude recibe ese texto y detecta el idioma naturalmente — no requiere configuración extra porque los LLMs hacen esto de forma nativa.

Cómo funciona en la práctica:

- El cliente habla → Retell transcribe → Claude detecta idioma en el primer turno
- Claude responde en ese idioma por el resto de la llamada
- El campo `idioma_detectado` se guarda en `TtpnBooking` (o metadata) para reportes

No se necesita ninguna librería de detección de idioma — Claude lo resuelve solo con la instrucción en el system prompt.

### Correo de notificación al administrador

Al finalizar cada llamada donde se **creó o intentó crear** una reserva, N8N envía un correo al administrador con el resumen del requerimiento, **siempre en español**, independientemente del idioma que habló el cliente.

**Destinatario:** `ing.castean@gmail.com` (configurable en N8N)

**Asunto:**

```
[Ejecutivos] Nueva solicitud de reserva — {nombre_cliente} · {fecha_servicio}
```

**Cuerpo del correo (plantilla):**

```
Resumen de llamada — Autos Ejecutivos TTPN
==========================================

DATOS DEL CLIENTE
  Nombre:        {nombre_pasajero}
  Teléfono:      {telefono}
  Idioma:        {idioma_detectado}  ← útil para asignar chofer que hable ese idioma

SERVICIO SOLICITADO
  Fecha y hora:  {fecha_hora_servicio}
  Origen:        {origen}
  Destino:       {destino}
  Pasajeros:     {num_pasajeros}
  Tipo de unidad:{tipo_unidad | "Sin preferencia"}
  Vuelo:         {numero_vuelo | "No aplica"}

RESERVA
  Folio:         {folio_booking}
  Estado:        {status}  ← pendiente / confirmada / sin reserva (solo consulta)
  Precio cotizado:{precio}

LLAMADA
  Duración:      {duracion_llamada}
  Resultado:     {resultado}  ← reserva_creada / solo_cotizacion / llamada_incompleta
  Grabación:     {url_grabacion | "No disponible"}

--
Generado automáticamente por el Agente de Voz Ejecutivos
```

**Trigger en N8N:** Webhook `POST /n8n/ejecutivos/call-ended` que Retell AI dispara al colgar.

**Casos en que se envía el correo:**

- Reserva creada exitosamente
- Cliente cotizó pero no confirmó (lead caliente — para dar seguimiento)
- Llamada incompleta / cliente colgó antes de terminar (lead frío)

**Caso en que NO se envía:**

- Llamada de menos de 15 segundos (marcados erróneos, silencio)

---

## 7. Componentes de TTPN Reutilizables

| Componente | Dónde vive | Cómo se reutiliza |
|---|---|---|
| `TtpnBooking` | `ttpngas/app/models/ttpn_booking.rb` | Modelo base de reserva — extender o usar directo con scope `ejecutivos` |
| `VehicleAsignacion` | `ttpngas/` | Determinar chofer asignado a vehículo |
| API Keys M2M | `Documentacion/Backend/api/api_keys.md` | Auth entre Retell AI y Kumi |
| N8N workflows | `ttpn_n8n/` | Post-call automation (adaptar flows existentes) |
| BusinessUnit scope | Concern en `ttpngas/` | Multi-tenancy automático por BU |
| `Employee` model | `ttpngas/` | Choferes como empleados de la BU ejecutivos |

---

## 7. Pendientes — Definir antes de codear

### Negocio
- [ ] ¿Cuáles son las ciudades/rutas de servicio?
- [ ] ¿Cuál es la estructura de precios? (por km, por zona, tarifa fija por ruta)
- [ ] ¿Cuáles son los tipos de unidad disponibles y su capacidad?
- [ ] ¿Qué método de pago acepta el agente de voz? (¿el pago es posterior o por adelantado?)
- [ ] ¿Cuál es la política de cancelación?
- [ ] ¿Horario de atención del agente? (¿24/7 o con horario?)
- [ ] ¿Cuántos números de teléfono? (¿uno para reservas, otro para ejecutivos?)
- [ ] ¿El agente también hace llamadas salientes? (ej: recordatorio de viaje)

### Técnico
- [ ] ¿`TtpnBooking` se extiende con campos ejecutivos o se crea modelo separado `EjecutivoBooking`?
- [ ] ¿El calendario de viajes es una vista de `TtpnBooking` o un modelo independiente?
- [ ] ¿Cómo se rastrea el vuelo del pasajero para ajustar hora de llegada?
- [ ] ¿Integración con Google Maps/Waze para calcular tiempos y rutas?
- [ ] ¿El chofer tiene app propia o recibe notificaciones por WhatsApp/SMS?
- [ ] ¿Cómo se maneja la escalación a operador humano?
- [ ] ¿Grabación de llamadas? (implicaciones legales en México — Ley Federal de Telecomunicaciones)

### Kumi
- [ ] Definir nombre del scope en BusinessUnit: `autos_ejecutivos`
- [ ] ¿Los choferes tienen acceso a Kumi admin o solo reciben notificaciones?
- [ ] ¿Los vehículos ejecutivos comparten modelo con vehículos de gas o son tabla separada?
- [ ] ¿Se necesita panel en Kumi para que un operador supervise las reservas del agente?

---

## 8. Siguiente Paso en esta Documentación

1. **`ARQUITECTURA.md`** — Diagrama de componentes y decisiones de diseño (ADR)
2. **`MODELOS.md`** — Definición de los modelos de datos nuevos/modificados
3. **`API_TOOLS.md`** — Contrato detallado de cada tool endpoint
4. **`SYSTEM_PROMPT.md`** — System prompt final con contexto real de negocio
5. **`CALENDAR.md`** — Especificación del calendario de viajes
6. **`PRD.md`** — Product Requirements Document consolidado

---

*Este documento se irá completando en sesiones sucesivas antes de escribir una sola línea de código.*
