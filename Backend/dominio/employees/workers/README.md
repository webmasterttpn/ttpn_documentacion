# Workers — Dominio Employees

Workers de Sidekiq activos en el dominio de empleados.

## PayrollProcessWorker

**Archivo:** `app/workers/payroll_process_worker.rb`
**Cola:** `:payrolls`
**Función:** Procesar nóminas en background con progreso en tiempo real.

**Flujo:**
1. Controller recibe solicitud de cálculo → encola el worker → retorna `job_id`.
2. Worker calcula nómina → broadcast de progreso cada N empleados.
3. Al terminar: broadcast `job_done` con datos o `job_failed` con error.
4. FE escucha `JobStatusChannel` filtrando por `job_id`.

**Broadcast:**
```ruby
ActionCable.server.broadcast(
  "job_status_#{user_id}",
  { type: 'job_done', job_id: jid, data: resultado }
)
```

**Estado:** Activo y estable.

---

## Agregar un nuevo worker

Documentar aquí:
- Nombre del worker y archivo
- Cola
- Qué hace
- Qué broadcast emite (si aplica)
- Cómo se encola (desde qué controller / cron)
