# 2026-04-30 — Filtro BU en Vehicles + Inicio Proyecto Ejecutivos

## Resumen ejecutivo

Sesión en dos bloques: (1) corrección del filtro de BusinessUnit en vehículos, que mostraba todos los registros al sadmin sin importar la BU activa; (2) inicio de la documentación del proyecto Agente de Voz para Autos Ejecutivos.

---

## 1. Fix: Vehicle#business_unit_filter

### Problema detectado

Al entrar como sadmin con BU=3 activa, se mostraban todos los vehículos del sistema porque el scope hacía `return all if Current.user&.sadmin?` sin considerar la BU activa del contexto.

### Modelo de datos aclarado en sesión

- `Concessionaire` = dueño legal del vehículo (puede ser persona física o empresa)
- Concesionarios empresa (TTPN, TULPE, TTPN-E) están vinculados a BUs via `business_units_concessionaires`
- Concesionarios persona física no tienen vínculo a ninguna BU
- `vehicle.business_unit_id` = BU que administra/opera el vehículo (asignada al crear, desde `Current.business_unit`)
- Préstamo entre BUs: agregar el concesionario de la BU prestadora al vehículo (ej: TTPN-E vinculado a BU=1 y BU=3)

### Reglas del nuevo scope

```
Mostrar vehículo si:
  A) vehicle.business_unit_id == current_bu.id   → vehículos administrados por esta BU
  B) algún concesionario del vehículo está vinculado a current_bu via business_units_concessionaires → préstamo
```

Sadmin sin BU activa (`Current.business_unit.nil?`) → ve todo.
Sadmin con BU activa → mismas reglas que cualquier usuario de esa BU.

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `app/models/vehicle.rb` | Scope reescrito con regla A + B; validación `at_least_one_concessionaire` |
| `app/controllers/api/v1/vehicles_controller.rb` | Auto-fill de concesionario en `create` si llega vacío |
| `db/migrate/20260430000001_populate_vehicle_business_unit_id.rb` | Pobla `business_unit_id` históricos NULL desde concesionario → BU (solo si vínculo unívoco) |

### Comportamiento de datos históricos post-migración

- Vehículos con concesionario vinculado a exactamente 1 BU → `business_unit_id` asignado automáticamente
- Vehículos con concesionarios persona física (sin vínculo a BU) → quedan NULL, solo visibles como sadmin sin BU activa

---

## 2. Nuevo: Documentación Ejecutivos

Se creó `Documentacion/Ejecutivos/` como carpeta de diseño previo al desarrollo del proyecto Agente de Voz para Autos Ejecutivos.

### Decisiones de arquitectura confirmadas

- Administración dentro de Kumi como nueva BusinessUnit (`autos_ejecutivos`)
- Empleados → choferes (modelo `Employee` existente)
- Vehículos → catálogo ejecutivo nuevo
- Reservaciones → `TtpnBooking` reutilizado
- Nuevo: calendario de viajes
- Disponibilidad: vehículo sin asignación OR asignado sin viaje en el slot

### Stack del agente de voz

Retell AI (STT/TTS) + Twilio (telefonía) + Claude Sonnet (LLM) + Kumi API Rails (tools) + N8N (post-call)

### Funcionalidades documentadas

- Detección automática de idioma (español/inglés) — nativo en Claude, instrucción en system prompt
- Correo de notificación al administrador siempre en español, vía N8N webhook `call-ended`
- 7 tools del agente con endpoints Kumi definidos
- 38 preguntas pendientes de negocio y técnicas antes de codear

### Documentos creados

- `Ejecutivos/REQUERIMIENTOS.md` — documento vivo, en discusión

---

## Pendientes derivados de esta sesión

- [ ] Verificar en Railway que la migración `20260430000001` corra en el próximo deploy
- [ ] Asignar manualmente `business_unit_id` a vehículos que quedaron NULL (concesionarios persona física)
- [ ] Vincular TTPN-E a BU=3 en `business_units_concessionaires` para activar el préstamo
- [ ] Continuar documentación de Ejecutivos: `ARQUITECTURA.md`, `MODELOS.md`
