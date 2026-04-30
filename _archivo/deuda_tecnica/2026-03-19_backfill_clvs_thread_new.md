# backfill_clvs — Thread.new sin Sidekiq

**Fecha registrada:** 2026-03-19
**Dominio:** bookings
**Status:** Pendiente

## Descripción

`TtpnBookingsController#backfill_clvs` usa `Thread.new` para ejecutar una tarea larga en background:

```ruby
def backfill_clvs
  days = params[:days].to_i.clamp(1, 365)
  days = 30 if days.zero?
  Thread.new { system({ 'DAYS' => days.to_s }, 'bin/rails', 'cuadre:backfill_ttpn_bookings') }
  render json: { message: '...', subtitle: 'Recarga la página...' }
end
```

El command injection fue corregido (usa array form), pero Thread.new en Railway puede ser problema: los workers de Railway matan procesos idle y un Thread huérfano puede quedar cortado a mitad de la operación.

## Impacto

**Severidad:** Media

- La tarea puede quedar a medias si Railway recicla el proceso durante la ejecución
- No hay retry automático si falla
- No hay visibilidad del progreso ni del resultado

## Solución propuesta

Convertir a job de Sidekiq:

```ruby
# app/jobs/backfill_ttpn_bookings_job.rb
class BackfillTtpnBookingsJob < ApplicationJob
  queue_as :default

  def perform(days)
    days = days.to_i.clamp(1, 365)
    system({ 'DAYS' => days.to_s }, 'bin/rails', 'cuadre:backfill_ttpn_bookings')
  end
end

# En el controller:
def backfill_clvs
  days = params[:days].to_i.clamp(1, 365)
  days = 30 if days.zero?
  BackfillTtpnBookingsJob.perform_later(days)
  render json: { message: '...', subtitle: 'Recarga la página...' }
end
```

## Decidido por

Antonio Castellanos — 2026-03-19. Se documentó como deuda en el mismo sprint de refactor de services layer. La corrección de command injection fue la prioridad; la migración a Sidekiq se postergó.
