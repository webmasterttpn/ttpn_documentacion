# Correcciones Supabase y SonarCloud — 2026-03-17

## Contexto

El proyecto tenía alertas activas en dos plataformas de calidad:

- **Supabase** (Database Linter) — alertas a nivel de base de datos
- **SonarCloud** — alertas de calidad y mantenibilidad del código Ruby

Todos los cambios son **no disruptivos**: no se alteró lógica de negocio, no se modificaron rutas ni contratos de API, y son compatibles con la versión en staging.

---

## Parte 1 — Supabase

### Problema 1: Function Search Path Mutable

**Qué es:** Supabase alerta cuando una función en el schema `public` no tiene un `search_path` fijo. Esto es un riesgo de seguridad/mantenibilidad porque si alguien crea un schema malicioso con el mismo nombre de tabla, la función podría resolverlo en lugar del schema correcto.

**Archivos afectados:** Ningún archivo de app — se crea una migración nueva.

**Solución:** Migración `20260317000001_fix_function_search_paths.rb`

Usa `ALTER FUNCTION ... SET search_path = public` en las 17 funciones/triggers existentes. Esta operación **no modifica la lógica** de ninguna función, solo fija el parámetro de configuración.

Funciones corregidas:

| Función | Propósito |
|---|---|
| `asignacion(bigint, timestamptz)` | ID de asignación de vehículo vigente |
| `asignacion_x_chofer(bigint, timestamptz)` | ID de asignación por chofer |
| `buscar_travel_id(...)` | Busca viaje en travel_counts que coincida con una reserva |
| `buscar_booking_id(...)` | Busca reserva en ttpn_bookings que coincida con un viaje |
| `buscar_booking(...)` | Verifica si existe reserva coincidente (boolean) |
| `buscar_gascharge_id(...)` | Busca carga de gasolina por ticket/fecha |
| `buscar_gasfile_id(...)` | Busca archivo de gasolina por datos de carga |
| `pago_chofer(...)` | Calcula pago total del chofer con incrementos |
| `incremento_servicio(...)` | Obtiene incremento vigente por tipo de vehículo y destino |
| `incremento_por_nivel(...)` | Incremento según nivel del chofer |
| `dias_vacaciones(bigint)` | Días de vacaciones según antigüedad (LFT) |
| `pago_vacaciones(...)` | Monto de pago de vacaciones |
| `cont_viajes(...)` | Cuenta viajes de un chofer en rango de fechas |
| `cost_viajes(...)` | Suma costos de viajes de un chofer |
| `sp_tb_update()` | Trigger AFTER INSERT/UPDATE en travel_counts |
| `sp_tctb_update()` | Trigger BEFORE UPDATE en travel_counts |
| `sp_tctb_insert()` | Trigger BEFORE INSERT en travel_counts |

**Cómo revertir:**
```bash
rails db:rollback STEP=2
# o ejecutar los RESET search_path del método `down` de la migración
```

---

### Problema 2: Unindexed Foreign Keys en `api_users`

**Qué es:** Las columnas `created_by_id` y `updated_by_id` de la tabla `api_users` tienen una FK declarada (`add_foreign_key "api_users", "users", column: "..."`) pero no tenían índice. Supabase alerta esto porque sin índice, las búsquedas inversas (de `users` hacia `api_users`) hacen un full table scan.

**Solución:** Migración `20260317000002_add_missing_indexes_to_api_users.rb`

```ruby
add_index :api_users, :created_by_id, name: "index_api_users_on_created_by_id"
add_index :api_users, :updated_by_id,  name: "index_api_users_on_updated_by_id"
```

**Impacto:** Cero. Solo agrega índices, no toca datos ni estructura existente.

---

## Parte 2 — SonarCloud

SonarCloud escanea `app/`, `lib/` y `config/` (según `sonar-project.properties`). Los modelos eran la fuente principal de alertas.

---

### `app/models/ability.rb`

**Regla S125 — Código comentado:**
Se eliminaron 5 líneas de variables de debug que quedaron comentadas desde la versión anterior con Devise+cookies:
```ruby
# $business_unit_id = user.business_unit_id
# puts("El usuario actual es #{$business_unit_id}")
# $user_business_unit = user.business_unit_id
# $ulp = user.role_id
# cookies[:bui] = user.business_unit_id
```

**Regla S1854 — Expresiones sin efecto:**
Cada bloque `if user.role? :xxx` terminaba con un string literal (`'sistemas'`, `'admin'`, etc.) que no se asignaba a nada ni se retornaba. SonarCloud los marca como "expression whose result is not used". Se eliminaron.

```ruby
# ANTES
if user.role? :sistemas
  can :manage, :all
  'sistemas'   # ← sin efecto, sonarcloud lo marca
end

# DESPUÉS
if user.role? :sistemas
  can :manage, :all
end
```

**Comportamiento:** Sin cambios. CanCanCan no usa el valor de retorno de `initialize`.

---

### `app/models/employee_vacation.rb`

**Regla S2116 — Método definido dentro de otro método:**
`business_days_between` estaba definido **dentro** de `valida_periodos`. Ruby lo permite pero SonarCloud lo marca como code smell grave porque:
- Redefine el método en cada llamada a `valida_periodos`
- Oculta la visibilidad del método
- Aumenta la complejidad cognitiva del método contenedor

```ruby
# ANTES: dentro de valida_periodos
def valida_periodos
  # ...
  def business_days_between(date1, date2)  # ← anidado
    ...
  end
  self.dias_efectivos = business_days_between(...)
end

# DESPUÉS: extraído como private
def valida_periodos
  # ...
  self.dias_efectivos = business_days_between(...)
end

private

def business_days_between(date1, date2)
  business_days = 0
  date = date2
  while date > date1
    business_days += 1 if date.workday?
    date -= 1.day
  end
  business_days
end
```

**Regla S125 — Código comentado:**
Se eliminó el bloque `rails_admin do ... end` comentado (65 líneas). Este bloque pertenece a la configuración del admin legacy y ya no aplica.

---

### `app/models/ttpn_booking.rb`

**Regla S125 — Código comentado (mayor impacto):**
Se eliminaron aproximadamente 200 líneas de configuración `rails_admin do ... end` comentada al final del archivo. Este bloque cubría las vistas `list`, `create`, `edit` e `import` del admin legacy.

Adicionalmente se limpiaron comentarios inline dispersos:
- `# puts(...)` de debug
- `# if $actualizando == false / # $actualizando = true` (lógica comentada)
- `# $actualizando = false` dentro del bloque `each`
- Bloque `# def my_custom_clone_method ... end` comentado
- Comentarios `# Camioneta nueva sin asignar` / `# Camioneta alguna vez asignada`

**El archivo pasó de 504 líneas a ~290 líneas.**

---

### `app/models/travel_count.rb`

**Regla S125 — Código comentado:**
Se eliminaron dos bloques comentados grandes:

1. **Método `verificar_unidad` completo** (~25 líneas) — lógica de obtención de vehículo por chofer que fue reemplazada por triggers de Postgres. Su `before_validation` estaba comentado, el método también debía estarlo.

2. **Método `before_import_find` completo** (~30 líneas) — método de importación legacy que usaba la variable de vehículo cero directamente. Reemplazado por el trigger `sp_tctb_insert`.

Dentro de `verificar_id` también se eliminaron ~12 líneas de `puts` y lógica comentada de obtención de vehículo.

**El archivo pasó de 183 líneas a ~95 líneas.**

---

### `app/models/scheduled_maintenance.rb`

**Código comentado:**
Se eliminó `# after_update :crearSecuencia` — callback desactivado desde hace tiempo.

**Regla S117 — Nombre de variable no sigue convención (camelCase):**
Ruby usa `snake_case` para variables locales. `tipoVehiculo` aparecía en dos métodos.

**Regla S4144 — Código duplicado:**
La misma consulta a `VehicleDocument` se repetía identicamente en `odometro_actual` y `previsto_para`. Se extrajo a dos métodos privados:

```ruby
private

# Retorna el clv del vehículo (para determinar si es tipo 'T')
def tipo_vehiculo_clv
  Vehicle.find(vehicle_id).clv
end

# Retorna el número de odómetro desde el documento registrado
def odometro_desde_documento
  doc = VehicleDocument
          .where(vehicle_id: vehicle_id, tipo_documento: 'otro', descripcion: 'Odometro')
          .select('numero')
          .first
  doc&.[]('numero')
end
```

El uso de `doc&.[]('numero')` también resuelve el acceso `a[0]['numero']` previo que podía lanzar `NoMethodError` si la query no devolvía resultados.

Los métodos `odometro_actual` y `previsto_para` quedaron simplificados:

```ruby
def odometro_actual
  return if new_record?
  return km_realizado if status?
  return 0 if tipo_vehiculo_clv.start_with?('T', 't')

  odometro_desde_documento.to_i
end

def previsto_para
  return if new_record?
  return "Realizado en #{km_realizado}" if status?

  odometro = tipo_vehiculo_clv.start_with?('T', 't') ? 0 : odometro_desde_documento.to_i
  diferencia = km_programado.to_i - odometro
  diferencia.positive? ? "En #{diferencia} km" : "Atrasado #{diferencia} km"
end
```

---

## Resumen de cambios por tipo

| Tipo de cambio | Archivos | Impacto en SonarCloud |
|---|---|---|
| Migración `search_path` en funciones | 1 migración nueva | Resuelve 17 alertas Supabase |
| Migración índices FK faltantes | 1 migración nueva | Resuelve 2 alertas Supabase |
| Eliminación código comentado | 5 modelos | Resuelve ~30 alertas S125 |
| Expresiones sin efecto | `ability.rb` | Resuelve ~9 alertas S1854 |
| Método anidado extraído | `employee_vacation.rb` | Resuelve 1 alerta S2116 |
| Variable camelCase corregida | `scheduled_maintenance.rb` | Resuelve 2 alertas S117 |
| Código duplicado extraído | `scheduled_maintenance.rb` | Resuelve 1 alerta S4144 + fix acceso `[0]` unsafe |

---

## Migraciones para aplicar

```bash
rails db:migrate
```

Ambas migraciones son idempotentes y seguras en caliente.

---

## Lo que NO se tocó (intencionalmente)

| Elemento | Razón |
|---|---|
| Variables globales `$worker_status`, `$actualizando` | Lógica de estado compartido en flujos de importación — requiere refactor mayor y pruebas extensas |
| Variable de clase `@@importacion` en `TtpnBooking` | Mismo motivo — parte del flujo crítico de importación masiva |
| Método `client_attributes` en `TtpnBooking` | Referencia a `ttpn_booking` probablemente en desuso, pero se necesita confirmar antes de eliminar |
| `validate_version_rules` en `Version` | Alta complejidad cognitiva, pero la lógica de validación es correcta — refactor separado |
| RLS (Row Level Security) en Supabase | La app conecta vía usuario Postgres directo, habilitarlo sin políticas correctas rompería todas las queries |
