# Deuda Técnica — Kumi Chat (N8N + IA)

> Documento vivo. Actualizar conforme se resuelvan o descubran nuevos items.
> Fecha inicial: 2026-04-19

---

## Contexto

El chatbot de Kumi usa N8N como orquestador: el FE manda el mensaje al webhook de N8N,
un nodo clasifica la intención con Groq (LLaMA 70B), selecciona un endpoint del API de Rails,
llama al API y formatea la respuesta. La arquitectura funciona pero tiene limitaciones
estructurales que se documentan aquí.

---

## Problemas encontrados

### DT-01 — Llamadas directas del FE a N8N (CORS)
**Severidad:** Alta — bloquea el chat en producción  
**Estado:** ✅ Resuelto — proxy implementado en `POST /api/v1/chat`  
**Descripción:**  
El navegador llamaba directamente a N8N exponiendo la URL y causando errores CORS.  
**Solución implementada:**  

- `Api::V1::ChatController#create` en Rails recibe el mensaje del FE
- Rails extrae los `allowed_modules` del JWT del usuario y los pasa a N8N
- N8N nunca queda expuesto directamente al browser
- Configurar `N8N_WEBHOOK_URL` en el `.env` de Rails (ver `.env.example`)

---

### DT-02 — AI routing incorrecto (employees vs employee_stats)
**Severidad:** Alta — respuestas erróneas  
**Estado:** ✅ Resuelto — prompt actualizado con reglas explícitas de routing  
**Solución implementada:** El nodo "Construir Prompt" ahora incluye sección "REGLAS CRÍTICAS DE ROUTING"
que distingue explícitamente cuándo usar cada endpoint stats vs listado individual.

---

### DT-03 — Endpoints de listado sin filtros útiles para IA
**Severidad:** Media  
**Estado:** ✅ Resuelto — se implementaron endpoints de stats por módulo  
**Solución implementada:**

- `vehicle_stats` → `/api/v1/vehicle_stats` (flotilla, documentos vencidos, asignaciones)
- `booking_stats` → `/api/v1/booking_stats` (viajes por periodo, tipo servicio, pasajeros)
- `client_stats` → `/api/v1/client_stats` (activos, sucursales, top clientes)
- `employee_stats` ya existía — también corregido en routing (DT-02)

---

### DT-04 — Sin control de acceso por privilegios en el chat
**Severidad:** Media  
**Estado:** ✅ Resuelto — proxy Rails pasa `allowed_modules`, N8N los aplica en el prompt  
**Solución implementada:**

1. `ChatController` extrae `build_privileges` del usuario JWT → filtra módulos con `can_access: true`
2. Pasa `allowed_modules: [...]` al webhook de N8N
3. El nodo "Construir Prompt" usa la lista para restringir los endpoints disponibles en el prompt
4. La IA solo puede seleccionar endpoints de módulos a los que el usuario tiene acceso

---

### DT-05 — `employee_stats` 500 en producción
**Severidad:** Alta  
**Estado:** En investigación — se agregó rescue con mensaje de error explícito  
**Descripción:**  
El endpoint `/api/v1/employee_stats` devuelve 500 en Railway. Se corrigió el uso de `exec_query`
(formato Rails 6 incompatible con Rails 7.1) y se cambió a ActiveRecord puro. Pendiente confirmar
que el deploy resolvió el error.

---

### DT-06 — Dashboard no es consultable por IA
**Severidad:** Baja  
**Estado:** Pendiente  
**Descripción:**  
`/api/v1/dashboard` usa Sidekiq jobs asincrónicos para calcular. La IA no puede hacer polling
de un job_id. El endpoint no es adecuado para consultas síncronas del chat.  
**Solución propuesta:** Crear `GET /api/v1/dashboard/summary` que devuelva un resumen sincrónico
de los datos más recientes (sin Sidekiq), específico para el chat.

---

## Propuesta de KPIs por módulo

### Implementados
| Endpoint | KPIs disponibles |
|---|---|
| `/api/v1/employee_stats?year=` | headcount, rotación, antigüedad, distribución área/puesto, documentos vencidos, citas |

---

### Propuesta pendiente de implementación

#### Vehículos — `GET /api/v1/vehicle_stats`
| KPI | Dato en DB |
|---|---|
| Total de unidades (activas / inactivas) | `Vehicle.status` |
| Distribución por tipo (Van, Auto, Camión) | `Vehicle → VehicleType` |
| Documentos vencidos (póliza, tenencia, verificación) | `VehicleDocument.vigencia` |
| Documentos por vencer (30 días) | `VehicleDocument.vigencia` |
| Unidades sin documentos | LEFT JOIN `vehicle_documents` |
| Unidades con mantenimiento pendiente | `DriverRequest` pendientes |
| Unidades sin asignación activa | `VehicleAsignation` |

#### Combustible — ya existe `fuel_performance/summary` (usable por IA)
| KPI | Dato en DB |
|---|---|
| Rendimiento promedio flotilla (km/l) | `FuelPerformance` calculado |
| Vehículo con mejor/peor rendimiento | idem |
| Total gasto gasolina por periodo | `GasolineCharge.monto` |
| Total litros cargados | `GasolineCharge.cantidad` |

#### Clientes — `GET /api/v1/client_stats`
| KPI | Dato en DB |
|---|---|
| Total clientes activos | `Client.status` |
| Clientes con más viajes en el periodo | `TtpnBooking` agrupado por cliente |
| Sucursales activas / inactivas | `ClientBranchOffice.status` |

#### Servicios TTPN — `GET /api/v1/booking_stats`
| KPI | Dato en DB |
|---|---|
| Total viajes por periodo | `TtpnBooking` + fechas |
| Viajes por tipo de servicio | `TtpnServiceType` |
| Viajes por destino | `TtpnForeignDestiny` |
| Promedio de pasajeros por viaje | `TtpnBooking.passenger_qty` |
| Viajes sin chofer asignado | `employee_id IS NULL` |
| Tasa de ocupación (pasajeros / aforo) | `passenger_qty / aforo` |

#### Dashboard (sync) — `GET /api/v1/dashboard/summary`
| KPI | Dato en DB |
|---|---|
| Viajes del mes actual vs mes anterior | `TtpnBooking` + comparativo |
| Top 5 clientes por viajes | agregación |
| Ingresos estimados del periodo | `TtpnServicePrice` × viajes |

---

## Orden de implementación sugerido

1. **DT-01** — Proxy Rails para el chat (desbloquea DT-04 y elimina CORS)
2. **DT-02** — Refinar prompt N8N (routing correcto, rápido de hacer)
3. **DT-05** — Confirmar que employee_stats funciona en Railway
4. `vehicle_stats` — Alto valor, documentos vencidos es pregunta frecuente
5. `booking_stats` — Core del negocio TTPN
6. **DT-04** — Control de acceso por privilegios (depende de DT-01)
7. `client_stats` y `dashboard/summary` — Menor urgencia

---

## Decisiones de arquitectura pendientes

- **¿Proxy en Rails o CORS en N8N?**  
  Proxy en Rails es más seguro y habilita DT-04. CORS es más rápido pero no resuelve el acceso.
  **Recomendación:** Proxy en Rails.

- **¿Endpoints de stats separados o params en controllers existentes?**  
  Stats separados (patrón `employee_stats`) mantiene los controllers CRUD limpios y
  permite optimizar las queries sin afectar el resto del sistema.  
  **Recomendación:** Controller de stats por dominio.
