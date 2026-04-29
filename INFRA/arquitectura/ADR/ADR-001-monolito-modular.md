# ADR-001 — Monolito Modular en lugar de Microservicios

**Fecha:** 2026-04-10  
**Estado:** Aceptado  
**Autor:** Antonio Castellanos

---

## Contexto

Al escalar el sistema, surgió la pregunta: ¿debemos separar en microservicios (Empleados, Viajes, Nómina, Facturación como servicios independientes)?

## Decisión

Mantener un solo proceso Rails con una sola base de datos PostgreSQL. Los frontends son múltiples (Kumi Admin, App Móvil, Portal Clientes) pero el backend es uno solo.

## Razones

El trigger `sp_tctb_insert` en `travel_counts` ejecuta en la misma transacción:

```sql
NEW.viaje_encontrado := buscar_booking(vehicle_id, employee_id, ...)
NEW.ttpn_booking_id  := buscar_booking_id(...)
NEW.payroll_id       := buscar_nomina()
```

Esto tarda ~2ms. Con microservicios y BDs separadas serían 3 round-trips HTTP: ~150-400ms y sin rollback transaccional si uno falla a mitad.

Además, el cuadre de nómina cruza `travel_counts ↔ ttpn_bookings ↔ payrolls ↔ discrepancies ↔ invoices`. Separar eso requiere un saga pattern que tomaría meses.

El equipo es de 2-4 personas. Los microservicios requieren CI/CD, monitoreo, versionado de contratos y trazabilidad distribuida por cada servicio — más infraestructura que producto.

La escala actual no lo justifica: <100 usuarios concurrentes, un solo servidor Railway que maneja todo sin problemas.

## Consecuencias

- El código debe organizarse en módulos internos bien definidos aunque estén en el mismo proceso.
- Cuando el equipo llegue a 5-8 devs, modularizar con namespaces (`app/domains/viajes/`, `app/domains/nomina/`, etc.).
- Si `travel_counts` llega a 10M+ registros y las queries de cuadre tardan segundos, evaluar un read replica — no microservicios.