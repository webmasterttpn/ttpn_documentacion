# Kumi Chat — Documentación del Flujo N8N

**Archivo:** `workflows/kumi-chat.json`  
**Última actualización:** 2026-04-15  
**Nivel:** Principiante (sin conocimientos técnicos previos)

---

## ¿Qué es este flujo?

Es el "cerebro" detrás del chat de Kumi. Cuando un usuario escribe un mensaje en el chatbot del sistema, este flujo se encarga de:

1. **Entender** qué quiere el usuario (¿está haciendo una pregunta o quiere crear viajes?)
2. **Actuar** según lo que detectó — consultar datos o crear los viajes en el sistema
3. **Responder** al usuario con el resultado

Piénsalo como un asistente que lee tu mensaje, lo entiende, hace el trabajo y te contesta.

---

## ¿Qué es N8N?

N8N es una herramienta de automatización visual. Funciona con **nodos** (cajitas) conectados entre sí. Cada nodo hace una tarea específica y le pasa el resultado al siguiente. Es como una cadena de ensamblaje en una fábrica: cada estación hace su parte y pasa el producto al siguiente.

---

## Estructura general del flujo

El flujo tiene **dos caminos** (ramas) que se separan según lo que el usuario quiera hacer:

```
Usuario escribe mensaje
        │
        ▼
[Webhook] ── recibe el mensaje
        │
        ▼
[Construir Prompt] ── prepara la pregunta para la IA
        │
        ▼
[Groq — Detectar Intención] ── la IA lee el mensaje
        │
        ▼
[Parsear Intención] ── interpreta la respuesta de la IA
        │
        ▼
[¿Es Creación?] ─────────────────────────────────────┐
        │ SÍ (crear viajes)                           │ NO (consultar datos)
        ▼                                             ▼
   RAMA CREAR                                    RAMA CONSULTAR
(7 pasos más)                                    (3 pasos más)
        │                                             │
        └─────────────────┬───────────────────────────┘
                          ▼
                 [Respond to Webhook]
                 (responde al usuario)
```

---

## PARTE 1 — Nodos comunes (aplican siempre)

---

### Nodo 1: Webhook
**Nombre en N8N:** `Webhook`  
**Tipo:** Receptor de mensajes HTTP

**¿Qué hace?**  
Es la "puerta de entrada" del flujo. Espera mensajes entrantes del chatbot del FE (frontend). Cuando el usuario presiona "Enviar" en el chat, el FE manda un mensaje a esta puerta y el flujo comienza.

**¿Qué recibe?**
```json
{
  "message": "SALIDA TFLUJO 20:00 15/04/26 T070 VISTAS DEL NORTE (1)",
  "user_id": 42
}
```

- `message` — el texto que escribió el usuario
- `user_id` — el ID del usuario que está usando el chat (para saber quién creó los viajes)

**Ruta del webhook:** `/webhook/kumi-assistant`  
(Es la URL que el FE llama cuando el usuario envía un mensaje)

---

### Nodo 2: Construir Prompt
**Nombre en N8N:** `Construir Prompt`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Prepara la pregunta que le va a hacer a la inteligencia artificial (IA). La IA no entiende contexto automáticamente — hay que darle instrucciones precisas en texto.

**¿Cómo funciona?**  
Toma el mensaje del usuario y lo envuelve en un "prompt" (instrucciones para la IA) que le dice:
- Qué tipo de sistema es Kumi
- Qué tipos de intención puede detectar ("crear viajes" o "consultar datos")
- Señales que indican cada intención
- El mensaje del usuario

**Ejemplo de lo que le envía a la IA:**
```
Eres el asistente de Kumi TTPN Admin. Analiza el mensaje y responde SOLO con JSON...

TIPOS DE INTENCIÓN:
- "query": preguntas sobre información existente (cuántos, cuál, dónde...)
- "create": crear viajes, registrar servicios, mensajes con vehículos y rutas...

SEÑALES DE CREACIÓN: menciona vehículos (T001, U023...) junto con rutas o colonias...

Mensaje: "SALIDA TFLUJO 20:00 15/04/26 T070 VISTAS DEL NORTE (1)"
```

**¿Qué modelo de IA usa?**  
`llama-3.3-70b-versatile` de Groq (un modelo de lenguaje gratuito para pruebas, similar a ChatGPT)

**¿Qué produce?**  
Un objeto listo para enviárselo a Groq (la plataforma de IA):
```json
{
  "model": "llama-3.3-70b-versatile",
  "messages": [{ "role": "user", "content": "...el prompt completo..." }],
  "temperature": 0.1,
  "max_tokens": 200
}
```
- `temperature: 0.1` — IA casi sin "creatividad", respuestas muy predecibles y consistentes
- `max_tokens: 200` — máximo 200 palabras en la respuesta (para esta fase solo necesita detectar la intención)

---

### Nodo 3: Groq — Detectar Intención
**Nombre en N8N:** `Groq — Detectar Intención`  
**Tipo:** Llamada HTTP a la API de Groq

**¿Qué hace?**  
Envía el prompt al servidor de Groq (inteligencia artificial en la nube) y espera la respuesta.

**¿Cómo se comunica?**  
Le manda un mensaje POST con el prompt y su API key (clave de acceso). Groq procesa el texto y devuelve su análisis.

**¿Qué devuelve Groq?**
```json
{
  "choices": [{
    "message": {
      "content": "{\"intent\":\"create\",\"descripcion\":\"Crear viajes TFLUJO\"}"
    }
  }]
}
```
La IA responde con JSON indicando si la intención es `"create"` o `"query"`.

---

### Nodo 4: Parsear Intención
**Nombre en N8N:** `Parsear Intención`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Lee la respuesta de la IA y la convierte en algo usable para el siguiente nodo. También guarda el mensaje original del usuario para usarlo más adelante.

**Casos que maneja:**
- Si la IA responde `"create"` → guarda `intent: "create"` y el mensaje original
- Si la IA responde `"query"` → construye la URL de la API que hay que consultar (ej: `/api/v1/vehicles?search=T070`)
- Si la IA falla o responde algo inesperado → asume que es una consulta de vehículos (fallback seguro)

---

### Nodo 5: ¿Es Creación?
**Nombre en N8N:** `Es Creación?`  
**Tipo:** Condición IF

**¿Qué hace?**  
Es el punto de bifurcación. Revisa si la intención detectada es `"create"`.

- **SÍ (true)** → el flujo toma el camino de crear viajes (rama superior, pasos 6-15)
- **NO (false)** → el flujo toma el camino de consultar datos (rama inferior, pasos A-C)

---

## PARTE 2 — Rama CONSULTAR (cuando el usuario pregunta algo)

Ejemplos de mensajes que toman esta rama:
- "¿Cuántos vehículos hay?"
- "¿Qué viajes hay para mañana?"
- "Muéstrame las cargas de gasolina"

---

### Nodo A: Llamar API Kumi
**Nombre en N8N:** `Llamar API Kumi`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Llama al endpoint de la API de Kumi que la IA determinó en el nodo 4. Por ejemplo, si el usuario preguntó por vehículos, llama a `http://kumi_api:3000/api/v1/vehicles`.

---

### Nodo B: Preparar para Formatear
**Nombre en N8N:** `Preparar para Formatear`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Filtra y prepara los datos para que la IA los pueda resumir. Aplica inteligencia básica:

- Si el usuario mencionó una CLV de vehículo (ej: "T070") → filtra solo ese vehículo
- Si preguntó por una marca → filtra por esa marca
- Si preguntó "cuántos" → genera un resumen por categoría
- Si no hay filtro específico → toma los primeros 8 registros para no sobrecargar la IA

Luego prepara el prompt para que Groq convierta esos datos en una respuesta natural en español.

---

### Nodo C: Groq — Formatear Respuesta
**Nombre en N8N:** `Groq — Formatear Respuesta`  
**Tipo:** Llamada HTTP a Groq

**¿Qué hace?**  
Envía los datos filtrados a Groq para que los convierta en lenguaje natural. Por ejemplo, convierte esto:
```json
[{"id":5,"clv":"T070","marca":"International"}]
```
en esto:
> "El vehículo T070 es un International, actualmente activo en la flotilla."

**Configuración:** `max_tokens: 300`, `temperature: 0.3` (un poco más de flexibilidad para redactar)

---

### Nodo D: Extraer Respuesta
**Nombre en N8N:** `Extraer Respuesta`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Extrae el texto de la respuesta de Groq (que viene anidado en `choices[0].message.content`) y lo empaqueta en el formato que espera el webhook de respuesta: `{ response: "texto de la respuesta" }`.

---

## PARTE 3 — Rama CREAR (cuando el usuario quiere registrar viajes)

Ejemplos de mensajes que toman esta rama:
- "SALIDA TFLUJO 20:00 15/04/26 T070 VISTAS DEL NORTE (1) T057 RIBERAS (4)"
- "Tiempo extra BAFAR 22:00 hoy U11 JARDINES DEL SOL (1)"

Esta rama tiene 9 pasos. Su objetivo es: entender el mensaje, buscar los IDs correctos en la base de datos, y crear cada viaje en el sistema.

---

### Nodo 6: Fetch Clients
**Nombre en N8N:** `Fetch Clients`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Descarga la lista completa de clientes desde la API de Kumi.

**Llama a:** `GET /api/v1/clients?per_page=500`

**¿Por qué necesita los clientes?**  
El mensaje del usuario dice "TFLUJO" pero la base de datos guarda el ID numérico del cliente (ej: `42`). Necesita la lista para poder hacer el match: "TFLUJO" → ID 42.

**¿Qué devuelve?**  
Un array de clientes:
```json
[
  { "id": 42, "razon_social": "F-R Tecnologias de Flujo S.A. de C.V", "clv": "TFLUJO" },
  { "id": 1,  "razon_social": "BAFAR S.A. de C.V", "clv": "BAFAR" },
  ...
]
```

---

### Nodo 7: Collect Clients
**Nombre en N8N:** `Collect Clients`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Limpia y simplifica la lista de clientes (solo guarda `id`, `clv` y `nombre`). También recupera el mensaje original y el `user_id`.

**Además — Pre-filtrado inteligente de cliente:**  
Para reducir los tokens enviados a la IA (y hacerla más precisa), este nodo busca en el mensaje si hay alguna palabra que coincida con la clave (CLV) o nombre de algún cliente:

1. Normaliza el mensaje: quita acentos, pasa a minúsculas, elimina caracteres especiales
2. Divide el mensaje en palabras: `["salida", "tflujo", "2000", "t070", ...]`
3. Para cada cliente, calcula un puntaje:
   - Si la CLV del cliente empieza con alguna palabra del mensaje → +10 puntos (match fuerte)
   - Si el nombre del cliente contiene alguna palabra del mensaje (mínimo 4 letras) → +4 puntos
4. Ordena los clientes por puntaje
5. Resultado:
   - Si hay algún match con puntos → manda solo los 5 mejores candidatos a la IA
   - Si no hay match → manda los primeros 15 para que la IA intente

**Ejemplo con "TFLUJO":**  
- Palabra "tflujo" → coincide con CLV "TFLUJO" (empieza con "tflujo") → score 10
- Solo ese cliente queda en el top → la IA recibe 1 candidato en vez de 80
- Menos tokens, resultado más preciso, menos costo de IA

---

### Nodo 8: Fetch Vehicles
**Nombre en N8N:** `Fetch Vehicles`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Descarga la lista de todos los vehículos activos.

**Llama a:** `GET /api/v1/vehicles`

**¿Por qué?**  
El mensaje dice "T070" pero el sistema necesita el ID numérico (ej: `15`). Con la lista puede hacer el match: "T070" → ID 15.

---

### Nodo 9: Collect Vehicles
**Nombre en N8N:** `Collect Vehicles`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Limpia la lista de vehículos (solo `id` y `clv`). Los une con los datos que venían de Collect Clients para tener todo en un solo objeto.

---

### Nodo 10: Fetch Service Types
**Nombre en N8N:** `Fetch Service Types`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Descarga los tipos de servicio (básicamente: Entrada o Salida).

**Llama a:** `GET /api/v1/ttpn_service_types`

**¿Por qué?**  
El mensaje puede decir "SALIDA" o "ENTRADA". El sistema necesita el ID del tipo: ej `1 = Salida`, `2 = Entrada`.

---

### Nodo 11: Fetch Services
**Nombre en N8N:** `Fetch Services`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Descarga el catálogo de servicios activos (rutas, tipos de viaje como RTL, RTE, TEA...).

**Llama a:** `GET /api/v1/ttpn_services?status=true`

**¿Por qué?**  
Cada viaje necesita un `ttpn_service_id`. Si el mensaje menciona una ruta fija, se usa esa. Si no especifica, se usa un servicio de Tiempo Extra.

---

### Nodo 12: Collect Catalogs
**Nombre en N8N:** `Collect Catalogs`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Une los catálogos de Tipos de Servicio y Servicios en un solo objeto, junto con todo lo recopilado antes (clientes, vehículos, mensaje, user_id).

También etiqueta cada servicio para que la IA sepa qué tipo es:
- `[tiempo_extra]` → si la CLV empieza con T o la descripción empieza con "Tiempo"
- `[foraneo:NombreCiudad]` → si el servicio tiene un destino foráneo asociado
- `[ruta_fija]` → cualquier otro servicio

Ejemplo de cómo quedan los servicios para la IA:
```
3:"TEA"(Tiempo Extra Aeropuerto)[tiempo_extra]
7:"RTL"(Ruta Local)[ruta_fija]
12:"RCU"(Ruta Cuauhtémoc)[foraneo:Cuauhtémoc]
```

---

### Nodo 13: Build Booking Prompt
**Nombre en N8N:** `Build Booking Prompt`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Es el nodo más importante de la rama de creación. Construye el prompt detallado que le envía a Groq con todos los catálogos y reglas para extraer los viajes del mensaje.

**¿Qué calcula antes de armar el prompt?**

1. **Fecha de hoy** — obtiene la fecha actual del servidor N8N en formato `YYYY-MM-DD`
2. **Día de la semana en español** — para que la IA sepa qué día es hoy exactamente

**¿Qué incluye en el prompt?**

- **Lista de clientes candidatos** (los pre-filtrados, ej: solo TFLUJO)
- **Lista de vehículos** (todos, con su CLV e ID)
- **Tipos de servicio** (Entrada/Salida)
- **Catálogo de servicios** con etiquetas `[tiempo_extra]`, `[ruta_fija]`, `[foraneo:X]`
- **Reglas para la IA:**
  - Cómo detectar Entrada vs Salida
  - Cuándo usar Tiempo Extra vs ruta fija
  - Cómo convertir fechas ("15/04/26" → "2026-04-15")
  - Cómo convertir horas ("20:00" → "20:00:00")
  - Que `employee_id` siempre va como `null` (el backend lo asigna)
  - Que si no encuentra el cliente → poner `client_id: null`
  - Capacidad por defecto según prefijo: U* = 1 pax, T* o V* = 4 pax
  - Números entre paréntesis en el mensaje = cantidad exacta de pasajeros
  - Crear un objeto JSON por cada vehículo mencionado

**Ejemplo de lo que produce para el mensaje de prueba:**

Con el mensaje: `SALIDA TFLUJO 20:00 15/04/26 T070 VISTAS DEL NORTE (1) T057 RIBERAS DE SACRAMENTO (4)`

La IA recibe:
```
CLIENTES: 42:"F-R Tecnologias de Flujo S.A. de C.V"(clv:TFLUJO)
VEHÍCULOS: 5:"T070", 8:"T057", 12:"U14", ...
TIPO DE DIRECCIÓN: 1:"Salida", 2:"Entrada"
SERVICIOS: 3:"TEA"(Tiempo Extra)[tiempo_extra], 7:"RTL"(Ruta Local)[ruta_fija], ...

REGLAS:
- Si dice "Salida" → usa id de Salida
- Sin ruta especificada → usa servicio [tiempo_extra]
- Hoy es Miércoles 2026-04-15. "hoy" → "2026-04-15"
- "15/04/26" → "2026-04-15"
- employee_id SIEMPRE null

MENSAJE: "SALIDA TFLUJO 20:00 15/04/26 T070 VISTAS DEL NORTE (1) T057 RIBERAS DE SACRAMENTO (4)"
```

**Configuración:** `max_tokens: 1200`, `temperature: 0.1`

Los 1200 tokens son suficientes para extraer hasta 10 vehículos con todos sus campos. Con 800 (valor anterior) el JSON se truncaba y fallaba.

---

### Nodo 14: Groq — Extraer Viajes
**Nombre en N8N:** `Groq — Extraer Viajes`  
**Tipo:** Llamada HTTP a Groq  
**Propiedad:** `continueOnFail: true` (si falla, el flujo continúa en vez de morir)

**¿Qué hace?**  
Envía el prompt a Groq y espera que la IA devuelva el array JSON con los viajes extraídos.

**¿Qué devuelve Groq idealmente?**
```json
[
  {
    "client_id": 42,
    "vehicle_id": 5,
    "vehicle_clv": "T070",
    "fecha": "2026-04-15",
    "hora": "20:00:00",
    "ttpn_service_type_id": 1,
    "ttpn_service_id": 3,
    "employee_id": null,
    "colonia": "Vistas del Norte",
    "passenger_count": 1,
    "creation_method": "imported",
    "created_by_id": 42
  },
  {
    "client_id": 42,
    "vehicle_id": 8,
    "vehicle_clv": "T057",
    ...
    "colonia": "Riberas de Sacramento",
    "passenger_count": 4,
    ...
  }
]
```

**¿Qué puede salir mal aquí?**
- La API de Groq puede devolver un error de límite de tasa (`rate limit`) si se enviaron demasiadas peticiones en poco tiempo
- Groq puede truncar la respuesta si hay muchos vehículos (por eso se subió a 1200 tokens)

---

### Nodo 15: Parse Bookings
**Nombre en N8N:** `Parse Bookings`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Lee la respuesta de Groq y la convierte en items separados (uno por vehículo) para que los siguientes nodos los procesen uno a uno.

**Casos que maneja:**

1. **Error de Groq** (rate limit, error de red):
   - Detecta si la respuesta tiene un campo `error`
   - Devuelve: `{ _parse_error: "⚠️ Error del AI: Rate limit reached..." }`

2. **Respuesta mal formada** (JSON incompleto por truncado):
   - El `JSON.parse` falla
   - Devuelve: `{ _parse_error: "⚠️ No se pudo interpretar la respuesta..." }`

3. **Sin viajes detectados** (array vacío):
   - Devuelve: `{ _parse_error: "⚠️ El AI no detectó viajes en el mensaje" }`

4. **Todo correcto**:
   - Devuelve N items (uno por vehículo), cada uno con los datos del viaje
   - Los siguientes nodos se ejecutan una vez por cada item

---

### Nodo 16: Fetch Branch Offices
**Nombre en N8N:** `Fetch Branch Offices`  
**Tipo:** Llamada HTTP

**¿Qué hace?**  
Para cada viaje (item), consulta cuál es la sucursal/oficina del cliente. Esta información es necesaria porque el sistema relaciona pasajeros con `client_branch_office_id`, no directamente con `client_id`.

**Llama a:** `GET /api/v1/client_branch_offices?client_id={id_del_cliente}`

**Se ejecuta una vez por cada viaje** (si hay 7 vehículos = 7 llamadas a la API).

---

### Nodo 17: Build Final Booking
**Nombre en N8N:** `Build Final Booking`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Ensambla el objeto final del viaje listo para enviarlo a la API de Kumi. Es el "armador" final antes de crear el registro.

**Validaciones que hace:**

1. **Si venía un `_parse_error`** (de Parse Bookings):
   - Pasa el error hacia adelante sin intentar crear nada

2. **Si `client_id` es null** (la IA no encontró el cliente):
   - Devuelve: `{ error: "❌ Cliente no encontrado para vehículo T070. Verifica el nombre..." }`
   - NO intenta crear el booking — evita crear registros con cliente equivocado

3. **Si todo está bien:**
   - Toma el `id` de la primera sucursal encontrada como `client_branch_office_id`
   - Calcula la capacidad del vehículo según su prefijo (si no viene `passenger_count`):
     - Vehículos `U*` → 1 pasajero
     - Vehículos `T*` o `V*` → 4 pasajeros
     - Otros → 13 pasajeros
   - Si el mensaje tenía un número entre paréntesis → usa ese número exacto
   - Genera el array de pasajeros placeholder:
     ```json
     [
       { "nombre": "Pasajero", "apaterno": "1", "colonia": "Vistas del Norte", "client_branch_office_id": 5 }
     ]
     ```
   - Elimina campos que son solo para uso interno (`passenger_count`, `colonia`, `vehicle_clv`)

**¿Qué produce?**  
Un objeto completo listo para la API:
```json
{
  "client_id": 42,
  "vehicle_id": 5,
  "fecha": "2026-04-15",
  "hora": "20:00:00",
  "ttpn_service_type_id": 1,
  "ttpn_service_id": 3,
  "employee_id": null,
  "creation_method": "imported",
  "created_by_id": 42,
  "ttpn_booking_passengers_attributes": [
    { "nombre": "Pasajero", "apaterno": "1", "colonia": "Vistas del Norte", "client_branch_office_id": 5 }
  ]
}
```

---

### Nodo 18: Crear Booking
**Nombre en N8N:** `Crear Booking`  
**Tipo:** Llamada HTTP  
**Propiedad:** `continueOnFail: true` (si falla, el flujo continúa)

**¿Qué hace?**  
Envía el viaje armado a la API de Kumi para crearlo en la base de datos.

**Llama a:** `POST /api/v1/ttpn_bookings`

**¿Qué manda?**
```json
{
  "ttpn_booking": {
    "client_id": 42,
    "vehicle_id": 5,
    ...todos los campos del viaje...
  }
}
```

**¿Qué puede responder la API?**
- **Éxito:** `{ "id": 1618060, "client_id": 42, ... }` → el viaje fue creado con su nuevo ID
- **Error:** `{ "errors": { "vehicle_id": ["ya existe un viaje..."] } }` → validación fallida

**Se ejecuta una vez por vehículo.** Si hay 7 vehículos = 7 llamadas a la API de Kumi.

---

### Nodo 19: Collect Results
**Nombre en N8N:** `Collect Results`  
**Tipo:** Código JavaScript

**¿Qué hace?**  
Recopila los resultados de TODOS los intentos de creación (los 7 vehículos) y arma el mensaje de respuesta final para el usuario.

**Casos que maneja:**

1. **Error de IA** (Parse Bookings falló): Muestra directamente el mensaje de error de la IA

2. **Viajes creados exitosamente:** `✅ 6 viaje(s) creado(s) exitosamente (IDs: 1618060, 1618061, ...)`

3. **Viajes rechazados por validación** (cliente no encontrado, etc.): `⚠️ 1 viaje(s) no creado(s): ❌ Cliente no encontrado para vehículo T070...`

4. **Errores de la API de Kumi** (validaciones de Rails): `❌ 1 error(es) de API: {"vehicle_id": ["..."]}` 

5. **Nada creado:** `No se crearon viajes. Verifica el mensaje.`

---

## PARTE 4 — Respuesta final (siempre)

---

### Nodo 20: Respond to Webhook
**Nombre en N8N:** `Respond to Webhook`  
**Tipo:** Respuesta HTTP

**¿Qué hace?**  
Envía la respuesta de regreso al chatbot del FE. Este nodo es el que "cierra" la comunicación.

**¿Qué manda?**  
El objeto JSON del nodo anterior (de la rama que se haya ejecutado), que siempre tiene la forma:
```json
{ "response": "✅ 7 viaje(s) creado(s) exitosamente (IDs: ...)" }
```

**¿Cómo lo muestra el FE?**  
El chatbot lee el campo `response` y lo muestra como mensaje del bot en la interfaz.

---

## Resumen del flujo completo (diagrama de pasos)

```
 1. [Webhook]                    ← Recibe mensaje del chatbot
 2. [Construir Prompt]           ← Arma pregunta de intención para IA
 3. [Groq — Detectar Intención] ← IA lee el mensaje y decide: ¿crear o consultar?
 4. [Parsear Intención]          ← Interpreta la respuesta de la IA
 5. [¿Es Creación?]             ← Bifurcación del flujo

 ─── RAMA CONSULTAR ────────────────────────────────────────────────────
  A. [Llamar API Kumi]           ← Consulta el endpoint detectado
  B. [Preparar para Formatear]  ← Filtra datos relevantes
  C. [Groq — Formatear]         ← IA convierte datos en texto natural
  D. [Extraer Respuesta]        ← Saca el texto de la respuesta de IA

 ─── RAMA CREAR ────────────────────────────────────────────────────────
  6. [Fetch Clients]             ← Descarga lista de clientes
  7. [Collect Clients]           ← Limpia lista + pre-filtra candidatos
  8. [Fetch Vehicles]            ← Descarga lista de vehículos
  9. [Collect Vehicles]          ← Limpia lista de vehículos
 10. [Fetch Service Types]       ← Descarga tipos (Entrada/Salida)
 11. [Fetch Services]            ← Descarga catálogo de servicios
 12. [Collect Catalogs]          ← Une todos los catálogos + etiqueta servicios
 13. [Build Booking Prompt]      ← Arma prompt completo con todas las reglas
 14. [Groq — Extraer Viajes]    ← IA extrae los viajes del mensaje
 15. [Parse Bookings]            ← Separa la respuesta en items (1 por vehículo)
                                   (los pasos 16-18 corren una vez por vehículo)
 16. [Fetch Branch Offices]      ← Busca la sucursal del cliente
 17. [Build Final Booking]       ← Arma el objeto completo del viaje
 18. [Crear Booking]             ← Envía el viaje a la API de Kumi
 19. [Collect Results]           ← Recopila resultados de todos los vehículos
 ────────────────────────────────────────────────────────────────────────

20. [Respond to Webhook]         ← Devuelve la respuesta al chatbot
```

---

## Configuración técnica

### API Key de Groq
Usada en los nodos que llaman a Groq. Es la clave de acceso al servicio de IA.  
**Ubicación en el JSON:** campo `Authorization: Bearer gsk_...` en los nodos Groq

### API Key de Kumi
Usada en los nodos que llaman a la API de Kumi.  
**Ubicación en el JSON:** campo `Authorization: Bearer 03c8701...` en los nodos HTTP de Kumi

### URL base de Kumi
`http://kumi_api:3000` — el nombre `kumi_api` es el nombre del contenedor Docker. Dentro de la red Docker, N8N puede comunicarse con la API por ese nombre.

---

## ¿Qué pasa si algo falla?

| Escenario | Qué pasa | Qué ve el usuario |
|---|---|---|
| Groq no encuentra el cliente | Groq pone `client_id: null` | `⚠️ Cliente no encontrado para vehículo T070...` |
| Groq llega al límite de tokens/minuto | Error de rate limit de Groq | `⚠️ Error del AI: Rate limit reached` |
| JSON de Groq viene cortado (demasiados vehículos) | Parse falla | `⚠️ No se pudo interpretar la respuesta del AI` |
| La API de Kumi rechaza un viaje | Validación de Rails falla | `❌ error(es) de API: {"vehicle_id": [...]}` |
| N8N no puede conectar con la API de Kumi | Timeout o connection refused | El FE muestra: "❌ No pude conectar con el asistente" |

---

## Cambios a futuro (cuando se contrate IA de pago)

Para cambiar el proveedor de IA hay que modificar en el JSON:

1. La URL de los 3 nodos que llaman a Groq:
   - `"url": "https://api.groq.com/openai/v1/chat/completions"` → URL del nuevo proveedor
2. El modelo en los nodos de código:
   - `"model": "llama-3.3-70b-versatile"` → el modelo que se contrate
3. El token de autorización:
   - `"Bearer gsk_..."` → el nuevo API key

**Todo lo demás — lógica, reglas, nodos, conexiones — queda igual.**
