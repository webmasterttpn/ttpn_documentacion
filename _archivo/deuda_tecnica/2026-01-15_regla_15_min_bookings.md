# Deuda Técnica — Regla de 15 Minutos en TravelCount (Chofer y Coordinador)

**Fecha de registro:** 2026-04-15
**Prioridad:** Media
**Módulo:** TravelCount / App Android / FE Coordinador

---

## Contexto

La regla de negocio de los **15 minutos** ya está implementada del lado de los bookings (IA, importación, captura manual). El principio es:

> Un viaje doble debe tener al menos 15 minutos de diferencia respecto al anterior del mismo vehículo + cliente + fecha. Si la diferencia es menor, se trata del mismo viaje ya capturado.

Sin embargo, la misma regla también aplica cuando el **chofer** captura servicios desde la app Android y cuando la **capturista** lo hace desde el FE. El comportamiento esperado en esos casos es diferente al de un rechazo directo — requiere confirmación y un flujo de autorización.

---

## Comportamiento esperado por canal

### App Android (Chofer)

1. El chofer intenta registrar un viaje.
2. El sistema detecta que ya existe un TravelCount del mismo vehículo + fecha dentro de ±15 minutos.
3. Se muestra un **diálogo de confirmación** al chofer:
   > "Ya existe un viaje registrado a las HH:MM. ¿Estás tratando de crear un viaje doble?"
4. Si el chofer confirma:
   - El sistema **ajusta automáticamente la hora** del nuevo registro para que tenga exactamente 15 minutos de diferencia respecto al existente (sin que el chofer tenga que hacerlo manualmente).
   - Se genera automáticamente un **mensaje/notificación al coordinador** solicitando autorización del viaje doble.
5. Si el chofer cancela: no se crea nada.

### FE (Capturista / Coordinador)

1. La capturista intenta guardar un booking desde el formulario web.
2. Si se detecta duplicado dentro de ±15 minutos, se muestra una **alerta visual** en la interfaz (modal o toast de advertencia).
3. Si confirma que es un viaje doble:
   - Se ajusta la hora automáticamente (+15 min respecto al existente).
   - Se envía un **correo de notificación al coordinador** para autorización.

---

## Cambios por implementar

### Backend (Rails API)

#### `TravelCount` — validación paralela a `TtpnBooking`

Actualmente `TtpnBooking` tiene:
- `TtpnBooking.find_within_window(...)` — método de clase reutilizable
- Validación `sin_duplicado_en_15_minutos` en `on: :create`

`TravelCount` necesita el equivalente:

```ruby
# En travel_count.rb
def self.find_within_window(vehicle_id:, fecha:, hora:, minutes: 15)
  return nil unless vehicle_id && fecha && hora

  hora_str = hora.is_a?(String) ? hora : hora.strftime('%H:%M:%S')
  where(vehicle_id: vehicle_id, fecha: fecha)
    .where('ABS(EXTRACT(EPOCH FROM (hora::time - ?::time))) < ?', hora_str, minutes * 60)
    .first
end
```

> Nota: TravelCount no filtra por `client_id` porque el chofer no siempre conoce al cliente; el cuadre se hace después.

#### Nuevo endpoint para detección anticipada (Android)

```
GET /api/v1/travel_counts/check_duplicate?vehicle_id=X&fecha=YYYY-MM-DD&hora=HH:MM
```

Respuesta si hay duplicado:
```json
{
  "duplicate": true,
  "existing_id": 123,
  "existing_hora": "08:00",
  "suggested_hora": "08:15"
}
```

Respuesta si no hay duplicado:
```json
{
  "duplicate": false
}
```

El cálculo de `suggested_hora` es: `hora_existente + 15 minutos`.

#### Nuevo endpoint para confirmar viaje doble (Android)

```
POST /api/v1/travel_counts/confirm_double_trip
Body: { travel_count_id: 123, vehicle_id: X, fecha: "YYYY-MM-DD" }
```

Acciones:
1. Busca el TravelCount existente.
2. Crea el nuevo TravelCount con `hora = hora_existente + 15 min`.
3. Genera una notificación/mensaje al coordinador (ver sección de notificaciones abajo).

#### Ajuste automático de hora (helper compartido)

```ruby
# En un concern o service
def suggest_double_trip_hora(existing_hora)
  (existing_hora.is_a?(Time) ? existing_hora : Time.parse(existing_hora)) + 15.minutes
end
```

### Notificaciones al coordinador

Por definir el canal exacto (pendiente de decisión con el equipo):

- **Opción A:** Registro en tabla `notifications` (si existe o se crea).
- **Opción B:** Correo vía `ActionMailer` a la dirección del coordinador de la unidad de negocio.
- **Opción C:** Webhook a N8N para que N8N envíe el mensaje por el canal que corresponda (WhatsApp, email, Slack, etc.).

La notificación debe incluir:
- Nombre del chofer
- Vehículo (CLV)
- Fecha y hora del viaje doble
- Hora del viaje original
- Botón/link de autorización (si se implementa flujo de aprobación)

### Frontend (Quasar PWA)

#### Formulario de captura de bookings

- Al perder el foco en el campo `hora` (o antes de submit), hacer un `GET /check_duplicate` con los valores actuales.
- Si `duplicate: true`, mostrar modal de advertencia con la hora sugerida.
- Si el usuario acepta: rellenar el campo hora con `suggested_hora` y marcar el booking como `viaje_doble: true` para que el backend envíe la notificación.
- Si el usuario cancela: limpiar el campo hora.

El campo `creation_method` en este caso seguiría siendo `manual` — la distinción se haría con un campo separado (ver abajo).

#### Campo `requiere_autorizacion` o `viaje_doble` (opcional)

Evaluar si se agrega un campo booleano en `ttpn_bookings` y `travel_counts` para distinguir los viajes dobles que requieren autorización de coordinador. Esto permitiría:
- Listarlos con un indicador visual en el FE.
- Filtrarlos para revisión del coordinador.
- Marcarlos como "autorizados" una vez aprobados.

---

## Archivos a modificar

| Archivo | Cambio |
|---|---|
| `app/models/travel_count.rb` | Agregar `find_within_window` |
| `app/controllers/api/v1/travel_counts_controller.rb` | Agregar `check_duplicate` y `confirm_double_trip` |
| `config/routes.rb` | Registrar los nuevos endpoints |
| `app/mailers/coordinator_mailer.rb` | Nuevo mailer para notificación de viaje doble (o via N8N) |
| FE: formulario de captura de bookings | Lógica de detección y modal de confirmación |
| FE: formulario de captura de travel counts (si existe en FE) | Igual que el de bookings |
| App Android | Diálogo de confirmación + llamada a `confirm_double_trip` |

---

## Lo que NO cambia

- `TtpnBooking.find_within_window` — ya existe y funciona para bookings.
- La validación `sin_duplicado_en_15_minutos` en el modelo — sigue rechazando duplicados en captura manual/clonada sin confirmación del usuario.
- El flujo de IA (`automatico`) — ya retorna el ID existente sin crear duplicado.
- El flujo de importación — ya usa el fallback de 15 minutos para agregar pasajeros al booking existente.

---

## Dependencias / Decisiones pendientes

- [ ] Definir canal de notificación al coordinador (email, N8N, notificación in-app).
- [ ] Definir si se necesita flujo de "autorización" formal (el coordinador aprueba/rechaza) o solo es un aviso.
- [ ] Definir si `viaje_doble` o `requiere_autorizacion` se agrega como campo en DB (implica migración).
- [ ] Coordinar con el equipo de Android el contrato del nuevo endpoint `check_duplicate`.
