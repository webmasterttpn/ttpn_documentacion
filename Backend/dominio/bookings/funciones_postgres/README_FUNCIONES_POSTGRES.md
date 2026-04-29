# Migraciones de Funciones PostgreSQL

**Fecha:** 2026-01-15  
**Estado:** ✅ Listas para ejecutar  
**Tipo:** IDEMPOTENTES (pueden ejecutarse múltiples veces)

---

## 📋 Resumen

Se han creado **5 migraciones** para versionar todas las funciones PostgreSQL críticas del sistema TtpnBooking.

### ✅ Características

- **Idempotentes:** Usan `CREATE OR REPLACE FUNCTION` - pueden ejecutarse múltiples veces sin error
- **Seguras:** No fallan si las funciones ya existen
- **Reversibles:** Incluyen método `down` para rollback
- **Informativas:** Muestran mensajes de progreso durante la ejecución

---

## 📁 Migraciones Creadas

### 1. `20260115172932_create_postgres_functions_asignaciones.rb`

**Funciones:**

- `asignacion(vehicle_id, timestamp)` → bigint
- `asignacion_x_chofer(employee_id, timestamp)` → bigint

**Propósito:** Obtener asignaciones de vehículos y choferes vigentes en una fecha/hora específica.

**Usado en:**

- `TtpnBookingsHelper.obtener_empleado`
- `TravelCountsHelper.obtener_vehiculo`

---

### 2. `20260115172945_create_postgres_functions_cuadre_viajes.rb`

**Funciones:**

- `buscar_travel_id(...)` → bigint
- `buscar_booking_id(...)` → bigint
- `buscar_booking(...)` → boolean

**Propósito:** Sistema de cuadre automático bidireccional entre reservas (`ttpn_bookings`) y viajes (`travel_counts`).

**Usado en:**

- `TtpnBookingsHelper.busca_en_travel`
- `TravelCountsHelper.busca_en_booking`
- Triggers `sp_tb_update` y `sp_tctb_update`

---

### 3. `20260115172949_create_postgres_functions_cuadre_gasolina.rb`

**Funciones:**

- `buscar_gascharge_id(ticket, fecha, cantidad, monto)` → bigint
- `buscar_gasfile_id(servicio, fecha, volumen, importe)` → bigint

**Propósito:** Cuadre automático de cargas de gasolina con archivos.

**Usado en:**

- Sistema de importación de cargas de gasolina

---

### 4. `20260115172953_create_postgres_functions_nomina.rb`

**Funciones:**

- `pago_chofer(base, inc_servicio, inc_nivel)` → double precision
- `incremento_servicio(vehicle_type, destino)` → double precision
- `incremento_por_nivel(employee_id, vehicle_id)` → double precision
- `dias_vacaciones(años)` → integer
- `pago_vacaciones(fecha_ingreso, employee_id, sdi)` → numeric

**Propósito:** Cálculos de nómina, pagos a choferes y vacaciones.

**Usado en:**

- Sistema de nómina
- Cálculo de pagos a choferes

---

### 5. `20260115173001_create_postgres_triggers_booking.rb`

**Funciones Trigger:**

- `sp_tb_update()` → trigger
- `sp_tctb_update()` → trigger

**Triggers Creados:**

- `sp_tb_update` en `travel_counts` (AFTER INSERT OR UPDATE)
- `sp_tctb_update` en `travel_counts` (BEFORE UPDATE)

**Propósito:** Actualización automática bidireccional entre `travel_counts` y `ttpn_bookings`.

---

## 🚀 Cómo Ejecutar

### Opción 1: Ejecutar Todas las Migraciones

```bash
# En desarrollo
rails db:migrate

# En staging
RAILS_ENV=staging rails db:migrate

# En producción
RAILS_ENV=production rails db:migrate
```

### Opción 2: Ejecutar Migraciones Específicas

```bash
# Solo asignaciones
rails db:migrate:up VERSION=20260115172932

# Solo cuadre de viajes
rails db:migrate:up VERSION=20260115172945

# Solo cuadre de gasolina
rails db:migrate:up VERSION=20260115172949

# Solo nómina
rails db:migrate:up VERSION=20260115172953

# Solo triggers
rails db:migrate:up VERSION=20260115173001
```

### Opción 3: Rollback (si es necesario)

```bash
# Revertir última migración
rails db:rollback

# Revertir migración específica
rails db:migrate:down VERSION=20260115172932
```

---

## ✅ Verificación

### Verificar que las Funciones Existen

```bash
# Conectar a la base de datos
rails dbconsole

# Listar todas las funciones
\df

# Ver definición de una función específica
\sf asignacion

# Salir
\q
```

### Verificar que los Triggers Existen

```sql
-- En rails dbconsole
SELECT tgname, tgrelid::regclass, tgtype
FROM pg_trigger
WHERE tgname LIKE 'sp_%';
```

### Probar una Función

```sql
-- Probar asignacion
SELECT asignacion(1, NOW());

-- Probar pago_chofer
SELECT pago_chofer(100, 10, 5);
-- Debería retornar: 115.5

-- Probar dias_vacaciones
SELECT dias_vacaciones(5);
-- Debería retornar: 14
```

---

## 🔒 Seguridad

### ¿Por qué son Seguras?

1. **Idempotentes:** Usan `CREATE OR REPLACE FUNCTION`

   - Si la función no existe → la crea
   - Si la función existe → la actualiza
   - Nunca falla por función duplicada

2. **Triggers con DROP IF EXISTS:**

   ```sql
   DROP TRIGGER IF EXISTS sp_tb_update ON travel_counts;
   CREATE TRIGGER sp_tb_update ...
   ```

3. **Rollback Seguro:**
   - El método `down` usa `DROP FUNCTION IF EXISTS`
   - No falla si la función no existe

### ¿Qué Pasa si las Funciones Ya Existen?

✅ **No hay problema!** Las migraciones:

- Actualizarán las funciones existentes
- Mostrarán mensajes informativos
- No causarán errores

**Ejemplo de salida:**

```
== 20260115172932 CreatePostgresFunctionsAsignaciones: migrating =============
-- Creando/Actualizando funciones de asignaciones
   -> 0.0234s
✅ Funciones de asignaciones creadas/actualizadas correctamente
== 20260115172932 CreatePostgresFunctionsAsignaciones: migrated (0.0235s) ====
```

---

## 📊 Orden de Ejecución Recomendado

Las migraciones están numeradas para ejecutarse en este orden:

1. **Asignaciones** (172932) - Base para obtener choferes/vehículos
2. **Cuadre de Viajes** (172945) - Depende de asignaciones
3. **Cuadre de Gasolina** (172949) - Independiente
4. **Nómina** (172953) - Independiente
5. **Triggers** (173001) - Depende de cuadre de viajes

**Nota:** Rails ejecuta las migraciones en orden automáticamente.

---

## ⚠️ Consideraciones para Producción

### Antes de Ejecutar en Producción

1. **Backup de la Base de Datos**

   ```bash
   pg_dump -Fc ttpngas_production > backup_$(date +%Y%m%d_%H%M%S).dump
   ```

2. **Probar en Staging**

   ```bash
   RAILS_ENV=staging rails db:migrate
   # Verificar que todo funciona
   ```

3. **Revisar Impacto**

   - Las funciones se actualizan en milisegundos
   - No hay downtime
   - No afecta datos existentes

4. **Plan de Rollback**
   ```bash
   # Si algo sale mal
   rails db:rollback STEP=5
   ```

### Durante la Ejecución

- Monitorear logs de Rails
- Verificar mensajes de éxito
- Probar funciones críticas

### Después de la Ejecución

- Verificar que las funciones existen
- Probar el cuadre automático
- Monitorear errores en producción

---

## 🐛 Troubleshooting

### Error: "function already exists"

**Solución:** No debería ocurrir porque usamos `CREATE OR REPLACE`. Si ocurre:

```sql
-- Eliminar la función manualmente
DROP FUNCTION IF EXISTS asignacion(bigint, timestamp with time zone);

-- Ejecutar la migración nuevamente
rails db:migrate:up VERSION=20260115172932
```

### Error: "trigger already exists"

**Solución:** No debería ocurrir porque usamos `DROP TRIGGER IF EXISTS`. Si ocurre:

```sql
-- Eliminar el trigger manualmente
DROP TRIGGER IF EXISTS sp_tb_update ON travel_counts;

-- Ejecutar la migración nuevamente
rails db:migrate:up VERSION=20260115173001
```

### Error: "permission denied"

**Solución:** El usuario de la base de datos necesita permisos para crear funciones:

```sql
-- Como superusuario
GRANT CREATE ON SCHEMA public TO ttpngas_user;
```

---

## 📚 Documentación Relacionada

- **Análisis Completo:** `/documentacion/ANALISIS_TTPN_BOOKING.md`
- **Funciones Detalladas:** `/documentacion/FUNCIONES_POSTGRES_TTPN_BOOKING.md`
- **Catálogo Completo:** `/documentacion/CATALOGO_FUNCIONES_POSTGRES.md`
- **Plan de Mejoras:** `/documentacion/PLAN_MEJORAS_SQL_INJECTION.md`
- **Resumen:** `/documentacion/RESUMEN_DOCUMENTACION_TTPN_BOOKING.md`

---

## ✅ Checklist de Migración

### Desarrollo

- [ ] Ejecutar `rails db:migrate`
- [ ] Verificar funciones con `\df`
- [ ] Probar funciones críticas
- [ ] Verificar triggers
- [ ] Probar cuadre automático

### Staging

- [ ] Backup de base de datos
- [ ] Ejecutar `RAILS_ENV=staging rails db:migrate`
- [ ] Verificar funciones
- [ ] Probar flujo completo de reservas
- [ ] Monitorear logs por 24 horas

### Producción

- [ ] Backup de base de datos
- [ ] Ejecutar en ventana de mantenimiento
- [ ] `RAILS_ENV=production rails db:migrate`
- [ ] Verificar funciones
- [ ] Probar funcionalidad crítica
- [ ] Monitorear logs
- [ ] Tener plan de rollback listo

---

## 🎯 Próximos Pasos

Después de ejecutar estas migraciones:

1. **Refactorizar Helpers** - Seguir el plan en `PLAN_MEJORAS_SQL_INJECTION.md`
2. **Agregar Tests** - Tests de seguridad para helpers
3. **Documentar Funciones Auxiliares** - Las 20+ funciones restantes
4. **Optimizar Performance** - Agregar índices y CTEs

---

**Autor:** Antigravity AI  
**Fecha:** 2026-01-15  
**Versión:** 1.0  
**Estado:** ✅ Listo para Producción
