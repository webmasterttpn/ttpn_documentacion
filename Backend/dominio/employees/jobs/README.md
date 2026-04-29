# Jobs — Dominio Employees

## Estado actual

No hay jobs específicos de empleados en producción. El procesamiento de nómina usa `PayrollProcessWorker` (ver dominio payroll cuando se documente).

## Cuándo crear un job de employees

- Importación masiva de empleados desde CSV/Excel → job con ActionCable broadcast de progreso
- Generación de reportes pesados (IMSS, INFONAVIT) → job + notificación al terminar
- Sincronización con sistema externo (SAP, SICO) → job programado con sidekiq-cron

## Plantilla

Al crear un job de employees:

1. Cola: `default` para importaciones; `payrolls` para nómina.
2. Broadcast al terminar: `ActionCable.server.broadcast("job_status_#{user_id}", ...)`.
3. Documentar en este archivo: nombre del job, cola, qué hace, qué broadcast emite.
