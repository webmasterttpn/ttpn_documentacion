# 🔄 Actualización: Contexto Real del Cuadre

**Fecha:** 2026-01-15 14:58  
**Descubrimiento:** Flujo de captura asíncrono y desfasado

---

## 📋 Contexto Real del Negocio

### Flujo Actual de Captura

```
┌─────────────────────────────────────────────────────────────┐
│                    TTPN_BOOKING (Captura)                   │
│                                                             │
│  Fuente: Capturistas (múltiples grupos)                    │
│  Origen: Grupos de WhatsApp                                │
│  Timing: Puede ser ANTES, DURANTE o DESPUÉS del viaje      │
│  Método: Rails (interfaz web)                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Cuadre puede ser:
                           │ - Inmediato (si chofer ya capturó)
                           │ - Posterior (si chofer captura después)
                           │ - Previo (si chofer captura antes)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   TRAVEL_COUNT (Chofer)                     │
│                                                             │
│  Fuente: Choferes                                          │
│  Origen: App Android (PHP inserts)                         │
│  Timing: AL MOMENTO o POSTERIOR (días después)             │
│  Método: PHP directo a BD                                  │
└─────────────────────────────────────────────────────────────┘
```

### Escenarios Reales

#### Escenario 1: Captura Primero, Viaje Después ✅

```
10:00 - Capturista registra reserva (WhatsApp)
10:30 - Chofer realiza el viaje
11:00 - Chofer captura el viaje en app
        ↓
Cuadre: POSTERIOR (1 hora después de captura)
```

#### Escenario 2: Viaje Primero, Captura Después ✅

```
10:00 - Chofer realiza el viaje
10:30 - Chofer captura en app
14:00 - Capturista registra reserva (WhatsApp llegó tarde)
        ↓
Cuadre: RETROACTIVO (3.5 horas después del viaje)
```

#### Escenario 3: Captura Posterior Masiva ⚠️

```
Lunes - Chofer realiza 10 viajes
Martes - Chofer NO captura
Miércoles - Chofer captura los 10 viajes del lunes
            ↓
Cuadre: RETROACTIVO (2 días después)
```

#### Escenario 4: Nunca se Cuadra ❌

```
10:00 - Capturista registra reserva
10:30 - Chofer realiza viaje pero NUNCA captura
        ↓
Resultado: Reserva sin viaje (perdida de información)
```

---

## 🎯 Implicaciones para el Sistema de Cuadre

### ❌ Problemas de la Propuesta Original

1. **Ventanas de Tiempo Fijas**

   - 20 minutos antes/después NO es suficiente
   - Capturas pueden estar DÍAS desfasadas

2. **Cuadre Solo en CREATE**

   - Si la captura llega después, nunca se cuadra
   - Si el viaje llega después, nunca se cuadra

3. **Sin Recuadre Automático**
   - No hay mecanismo para cuadrar registros antiguos
   - Registros sin cuadre se quedan así para siempre

---

## 💡 Nueva Propuesta Adaptada

### Mejora 1: Ventanas de Tiempo Flexibles

```ruby
# config/initializers/cuadre_config.rb
module CuadreConfig
  # Ventanas para cuadre en tiempo real
  VENTANA_TIEMPO_REAL = 30.minutes

  # Ventanas para cuadre retroactivo
  VENTANA_MISMO_DIA = 24.hours
  VENTANA_SEMANA = 7.days
  VENTANA_MES = 30.days

  # Tolerancias de calidad
  TOLERANCIA_EXACTA = 5.minutes      # Score: 100
  TOLERANCIA_BUENA = 30.minutes      # Score: 90
  TOLERANCIA_ACEPTABLE = 2.hours     # Score: 70
  TOLERANCIA_DUDOSA = 24.hours       # Score: 50
  TOLERANCIA_MUY_DUDOSA = 7.days     # Score: 30
end
```

### Mejora 2: Función PostgreSQL con Ventanas Amplias

```sql
CREATE OR REPLACE FUNCTION public.buscar_travel_id_flexible(
  p_vehicle_id bigint,
  p_employee_id bigint,
  p_service_type_id bigint,
  p_foreign_destiny_id bigint,
  p_client_id bigint,
  p_fecha_hora timestamp,
  p_ventana_horas integer DEFAULT 24  -- Ventana de 24 horas por defecto
)
RETURNS TABLE(
  travel_id bigint,
  diferencia_minutos integer,
  score integer,
  calidad text
)
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  WITH matches AS (
    SELECT
      tc.id as travel_id,
      EXTRACT(EPOCH FROM ABS((tc.fecha + tc.hora) - p_fecha_hora))::integer / 60 as diferencia_minutos
    FROM travel_counts as tc
    JOIN client_branch_offices as cbo ON cbo.id = tc.client_branch_office_id
    WHERE tc.vehicle_id = p_vehicle_id
      AND tc.employee_id = p_employee_id
      AND tc.ttpn_service_type_id = p_service_type_id
      AND tc.ttpn_foreign_destiny_id = p_foreign_destiny_id
      AND tc.status = true
      AND (tc.viaje_encontrado != true OR tc.viaje_encontrado is null)
      AND cbo.client_id = p_client_id
      -- Ventana amplia configurable
      AND (tc.fecha + tc.hora) BETWEEN
          (p_fecha_hora - (p_ventana_horas || ' hours')::INTERVAL) AND
          (p_fecha_hora + (p_ventana_horas || ' hours')::INTERVAL)
  )
  SELECT
    m.travel_id,
    m.diferencia_minutos,
    -- Score basado en cercanía temporal
    CASE
      WHEN m.diferencia_minutos <= 5 THEN 100
      WHEN m.diferencia_minutos <= 30 THEN 90
      WHEN m.diferencia_minutos <= 120 THEN 70
      WHEN m.diferencia_minutos <= 1440 THEN 50  -- 24 horas
      ELSE 30
    END as score,
    -- Calidad del match
    CASE
      WHEN m.diferencia_minutos <= 5 THEN 'exacto'
      WHEN m.diferencia_minutos <= 30 THEN 'bueno'
      WHEN m.diferencia_minutos <= 120 THEN 'aceptable'
      WHEN m.diferencia_minutos <= 1440 THEN 'dudoso'
      ELSE 'muy_dudoso'
    END as calidad
  FROM matches m
  ORDER BY
    m.diferencia_minutos ASC,  -- Primero: más cercano en tiempo
    m.travel_id DESC           -- Desempate: más reciente
  LIMIT 1;
END;
$function$;
```

### Mejora 3: Sistema de Recuadre Automático

```ruby
# app/services/recuadre_service.rb
class RecuadreService
  # Recuadrar registros sin cuadre
  def self.recuadrar_pendientes(fecha_desde: 7.days.ago, fecha_hasta: Time.current)
    # Bookings sin cuadre
    bookings_pendientes = TtpnBooking.where(
      viaje_encontrado: [false, nil],
      fecha: fecha_desde..fecha_hasta
    )

    # Travel counts sin cuadre
    travels_pendientes = TravelCount.where(
      viaje_encontrado: [false, nil],
      fecha: fecha_desde..fecha_hasta
    )

    resultados = {
      bookings_cuadrados: 0,
      travels_cuadrados: 0,
      bookings_sin_cuadre: 0,
      travels_sin_cuadre: 0
    }

    # Intentar cuadrar bookings
    bookings_pendientes.find_each do |booking|
      resultado = CuadreService.cuadrar_booking_flexible(booking)
      if resultado.encontrado
        resultados[:bookings_cuadrados] += 1
      else
        resultados[:bookings_sin_cuadre] += 1
      end
    end

    # Intentar cuadrar travels
    travels_pendientes.find_each do |travel|
      resultado = CuadreService.cuadrar_travel_flexible(travel)
      if resultado.encontrado
        resultados[:travels_cuadrados] += 1
      else
        resultados[:travels_sin_cuadre] += 1
      end
    end

    resultados
  end

  # Recuadrar un día específico
  def self.recuadrar_dia(fecha)
    recuadrar_pendientes(
      fecha_desde: fecha.beginning_of_day,
      fecha_hasta: fecha.end_of_day
    )
  end

  # Recuadrar última semana
  def self.recuadrar_ultima_semana
    recuadrar_pendientes(fecha_desde: 7.days.ago)
  end
end
```

### Mejora 4: Job Programado de Recuadre

```ruby
# app/jobs/recuadre_automatico_job.rb
class RecuadreAutomaticoJob < ApplicationJob
  queue_as :default

  def perform
    # Recuadrar últimos 7 días cada noche
    resultados = RecuadreService.recuadrar_ultima_semana

    # Notificar si hay muchos sin cuadre
    if resultados[:bookings_sin_cuadre] > 10 || resultados[:travels_sin_cuadre] > 10
      AdminMailer.alerta_cuadres_pendientes(resultados).deliver_later
    end

    # Log
    Rails.logger.info "Recuadre automático completado: #{resultados}"
  end
end

# config/schedule.rb (usando whenever gem)
every 1.day, at: '2:00 am' do
  runner "RecuadreAutomaticoJob.perform_later"
end
```

### Mejora 5: CuadreService Flexible

```ruby
# app/services/cuadre_service.rb
class CuadreService
  # Cuadrar con ventana flexible según antigüedad
  def self.cuadrar_booking_flexible(booking)
    # Determinar ventana según antigüedad
    antiguedad_dias = (Date.current - booking.fecha).to_i

    ventana_horas = case antiguedad_dias
    when 0 then 1        # Mismo día: 1 hora
    when 1..2 then 24    # 1-2 días: 24 horas
    when 3..7 then 48    # 3-7 días: 48 horas
    else 168             # >7 días: 1 semana
    end

    sql = <<-SQL
      SELECT * FROM buscar_travel_id_flexible(
        $1, $2, $3, $4, $5, $6::timestamp, $7
      )
    SQL

    bindings = [
      [nil, booking.vehicle_id],
      [nil, booking.employee_id],
      [nil, booking.ttpn_service_type_id],
      [nil, booking.ttpn_service.ttpn_foreign_destiny_id],
      [nil, booking.client_id],
      [nil, "#{booking.fecha} #{booking.hora.strftime('%H:%M')}"],
      [nil, ventana_horas]
    ]

    result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', bindings).first

    if result
      # Actualizar booking
      booking.update_columns(
        viaje_encontrado: true,
        travel_count_id: result['travel_id'],
        cuadre_score: result['score'],
        cuadre_diferencia_minutos: result['diferencia_minutos'],
        cuadre_calidad: result['calidad'],
        cuadre_requiere_revision: result['calidad'].in?(['dudoso', 'muy_dudoso']),
        cuadre_fecha: Time.current
      )

      # Actualizar travel
      TravelCount.where(id: result['travel_id']).update_all(
        viaje_encontrado: true,
        ttpn_booking_id: booking.id,
        cuadre_fecha: Time.current
      )

      # Crear alerta si es dudoso
      if result['calidad'].in?(['dudoso', 'muy_dudoso'])
        CuadreAlert.create!(
          ttpn_booking_id: booking.id,
          travel_count_id: result['travel_id'],
          motivo: "Diferencia de #{result['diferencia_minutos']} minutos (#{result['calidad']})",
          calidad: result['calidad'],
          tipo: 'retroactivo'
        )
      end

      CuadreResult.new(
        encontrado: true,
        id: result['travel_id'],
        diferencia_minutos: result['diferencia_minutos'],
        score: result['score'],
        calidad: result['calidad']
      )
    else
      CuadreResult.new(encontrado: false)
    end
  end
end
```

### Mejora 6: Dashboard con Métricas de Desfase

```ruby
# app/controllers/admin/cuadre_dashboard_controller.rb
class Admin::CuadreDashboardController < ApplicationController
  def index
    @stats = {
      # Cuadres por calidad
      exactos: TtpnBooking.where(cuadre_calidad: 'exacto').count,
      buenos: TtpnBooking.where(cuadre_calidad: 'bueno').count,
      aceptables: TtpnBooking.where(cuadre_calidad: 'aceptable').count,
      dudosos: TtpnBooking.where(cuadre_calidad: 'dudoso').count,
      muy_dudosos: TtpnBooking.where(cuadre_calidad: 'muy_dudoso').count,

      # Sin cuadre
      bookings_sin_cuadre: TtpnBooking.where(viaje_encontrado: [false, nil]).count,
      travels_sin_cuadre: TravelCount.where(viaje_encontrado: [false, nil]).count,

      # Por antigüedad
      sin_cuadre_hoy: TtpnBooking.where(viaje_encontrado: [false, nil], fecha: Date.current).count,
      sin_cuadre_semana: TtpnBooking.where(viaje_encontrado: [false, nil], fecha: 7.days.ago..Date.current).count,
      sin_cuadre_mes: TtpnBooking.where(viaje_encontrado: [false, nil], fecha: 30.days.ago..Date.current).count,

      # Alertas
      alertas_pendientes: CuadreAlert.pendientes.count
    }

    # Gráfica de desfase temporal
    @desfase_distribution = TtpnBooking.where.not(cuadre_diferencia_minutos: nil)
                                       .group("CASE
                                         WHEN cuadre_diferencia_minutos <= 5 THEN '0-5 min'
                                         WHEN cuadre_diferencia_minutos <= 30 THEN '6-30 min'
                                         WHEN cuadre_diferencia_minutos <= 120 THEN '31min-2h'
                                         WHEN cuadre_diferencia_minutos <= 1440 THEN '2h-24h'
                                         ELSE '>24h'
                                       END")
                                       .count
  end

  def recuadrar_dia
    fecha = params[:fecha].to_date
    resultados = RecuadreService.recuadrar_dia(fecha)

    flash[:notice] = "Recuadre completado: #{resultados[:bookings_cuadrados]} bookings, #{resultados[:travels_cuadrados]} travels"
    redirect_to admin_cuadre_dashboard_path
  end

  def recuadrar_semana
    resultados = RecuadreService.recuadrar_ultima_semana

    flash[:notice] = "Recuadre semanal completado: #{resultados[:bookings_cuadrados]} bookings, #{resultados[:travels_cuadrados]} travels"
    redirect_to admin_cuadre_dashboard_path
  end
end
```

---

## 📊 Estrategia de Cuadre Adaptada

### Cuadre en Tiempo Real (CREATE)

```ruby
# Al crear booking o travel
1. Intentar cuadre con ventana de 1 hora
2. Si encuentra → cuadrar inmediatamente
3. Si no encuentra → dejar pendiente para recuadre nocturno
```

### Recuadre Nocturno (Automático)

```ruby
# Cada noche a las 2 AM
1. Buscar todos los registros sin cuadre de últimos 7 días
2. Intentar cuadrar con ventanas amplias (hasta 7 días)
3. Marcar cuadres dudosos para revisión
4. Notificar si hay muchos sin cuadre
```

### Recuadre Manual (Dashboard)

```ruby
# Operador puede:
1. Recuadrar un día específico
2. Recuadrar última semana
3. Ver registros sin cuadre
4. Revisar cuadres dudosos
5. Forzar cuadre manual
```

---

## 🎯 Métricas de Éxito Ajustadas

### KPIs Realistas

1. **Tasa de Cuadre Automático**

   - Objetivo: >85% (considerando desfases)
   - Mismo día: >95%
   - Semana: >90%
   - Mes: >85%

2. **Calidad de Cuadre**

   - Exacto (0-5 min): >40%
   - Bueno (6-30 min): >30%
   - Aceptable (31min-2h): >20%
   - Dudoso (2h-24h): <8%
   - Muy dudoso (>24h): <2%

3. **Tiempo de Cuadre**
   - Inmediato: >50%
   - Mismo día: >80%
   - Semana: >95%

---

## 💡 Recomendaciones Adicionales

### 1. Mejorar Captura de Choferes

```
Problema: Choferes capturan días después
Solución:
- Notificaciones push al finalizar viaje
- Recordatorios diarios de viajes sin capturar
- Gamificación (puntos por captura inmediata)
```

### 2. Validación de Capturistas

```
Problema: Captura puede llegar tarde de WhatsApp
Solución:
- Timestamp de cuándo llegó el WhatsApp
- Alerta si captura es >2 horas después del viaje
- Sugerencias automáticas de viajes sin cuadre
```

### 3. Cuadre Sugerido

```
Al capturar booking:
"Encontramos un viaje similar:
- Vehículo: 5
- Chofer: Juan Pérez
- Hora: 10:05 (5 min diferencia)
¿Es este viaje? [Sí] [No] [Ver más]"
```

---

**Creado por:** Antigravity AI  
**Fecha:** 2026-01-15 14:58  
**Versión:** 2.0 (Adaptada a flujo real)  
**Estado:** 📋 PROPUESTA ACTUALIZADA
