# Dominio: Bookings (TtpnBooking + TravelCount)

Sistema core de gestión de viajes y reservas. Es el dominio más complejo del sistema, con funciones PostgreSQL propias, reglas de cuadre automático y deuda técnica documentada.

---

## Estructura de carpetas

```
bookings/
├── README.md                       ← este archivo
├── PROCESO_CUADRE_AUTOMATICO.md    ← Proceso de cuadre entre TtpnBooking y TravelCount
├── IMPLEMENTACION_CLV_SERVICIO.md  ← Implementación de CLV de servicio
├── DEUDA_TECNICA_REGLA_15_MIN.md   ← Deuda técnica conocida: regla de 15 minutos
├── analisis/
│   └── ANALISIS_TTPN_BOOKING.md    ← Análisis completo del modelo TtpnBooking
├── callbacks/
│   └── *.md                        ← Docs de callbacks complejos
├── funciones_postgres/
│   ├── FUNCIONES_POSTGRES_TTPN_BOOKING.md
│   └── CATALOGO_FUNCIONES_POSTGRES.md
├── migraciones/
│   └── *.md                        ← Verificación de migraciones PostgreSQL
└── seguridad/
    ├── PLAN_MEJORAS_SQL_INJECTION.md
    └── REFACTORIZACION_SQL_INJECTION_COMPLETADA.md
```

---

## Conceptos clave

- **TtpnBooking**: reserva de transporte. Tiene `employee_id` (chofer), `vehicle_id`, `clv_servicio`.
- **TravelCount**: registro del viaje ejecutado. Se genera o valida a partir de TtpnBooking.
- **Cuadre**: proceso de comparar y conciliar lo reservado vs lo ejecutado. Ver `PROCESO_CUADRE_AUTOMATICO.md`.
- **Regla de 15 min**: lógica de tolerancia de tiempo con deuda técnica conocida. Ver `DEUDA_TECNICA_REGLA_15_MIN.md`.
- **Funciones PostgreSQL**: lógica compleja que vive en la DB para performance. Ver `funciones_postgres/`.

---

## Archivos Rails relacionados

```
app/models/ttpn_booking.rb
app/models/travel_count.rb
app/controllers/api/v1/ttpn_bookings_controller.rb
app/controllers/api/v1/travel_counts_controller.rb
app/controllers/concerns/booking_stats_calculable.rb
```
