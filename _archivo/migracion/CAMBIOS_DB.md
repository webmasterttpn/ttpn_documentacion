# CAMBIOS_DB — Registro de cambios en base de datos

Historial de cambios significativos en la BD introducidos en `transform_to_api`.
Actualizar este documento cada vez que se agregue una migración relevante.

---

## [2026-04-22] Multi-tenancy en tablas operativas grandes

**Migración:** `20260422185129_add_business_unit_to_operational_core_tables.rb`

**Tablas afectadas:** `vehicles`, `gas_files`, `gas_charges`, `gasoline_charges`, `ttpn_bookings`, `travel_counts`

**Cambio:** Columna `business_unit_id` agregada (nullable) con FK a `business_units` e índice.

**⚠️ Backfill en producción:** La migración NO hace UPDATE masivo (tablas con millones de registros). El backfill se maneja vía CSV pre-poblado antes del import. Ver `MIGRACION_DB.md` pasos 3-4.

```sql
-- Verificar post-importación (deben dar 0)
SELECT 'vehicles', COUNT(*) FROM vehicles WHERE business_unit_id IS NULL
UNION ALL SELECT 'ttpn_bookings', COUNT(*) FROM ttpn_bookings WHERE business_unit_id IS NULL
UNION ALL SELECT 'travel_counts', COUNT(*) FROM travel_counts WHERE business_unit_id IS NULL;
```

---

## [2026-04-22] Multi-tenancy en tablas secundarias

**Migración:** `20260422185201_add_business_unit_to_operational_secondary_tables.rb`

**Tablas afectadas:** `suppliers`, `gas_stations`, `coo_travel_requests`, `coo_travel_employee_requests`, `payrolls`, `invoicings`, `scheduled_maintenances`, `incidences`, `discrepancies`

**Cambio:** Columna `business_unit_id` agregada (nullable) con FK e índice.

**Backfill en producción:** Agregar al CSV o correr después del import:
```sql
UPDATE suppliers SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE gas_stations SET business_unit_id = 1 WHERE business_unit_id IS NULL;
-- ... repetir para cada tabla
```

---

## [2026-04-22] Multi-tenancy en Labors (puestos)

**Migración:** `20260422182302_add_business_unit_to_labors.rb`

**Cambio:** Columna `business_unit_id` agregada a la tabla `labors`.

**Backfill:** Los registros existentes fueron asignados automáticamente a la primera BU (`id = 1`). En producción verificar que los puestos estén distribuidos correctamente entre BUs y corregir manualmente si aplica.

```sql
-- Verificar distribución actual
SELECT business_unit_id, COUNT(*) FROM labors GROUP BY business_unit_id;

-- Reasignar puestos a su BU correcta si es necesario
UPDATE labors SET business_unit_id = 2 WHERE nombre IN ('Chofer Foráneo', 'Capturista');
```

---

## [2026-04-22] Multi-rol de usuarios (roles_users)

**Migración:** `20260422171539_add_unique_index_and_justificacion_to_roles_users.rb`

**Cambios:**
- Índice único `(user_id, role_id)` en `roles_users` — elimina duplicados automáticamente
- Columna `justificacion` (string, nullable) para auditoría de asignaciones dobles

**Backfill:** La migración limpia duplicados automáticamente. No requiere acción manual.

**Impacto en privilegios:** Los privilegios efectivos del usuario son ahora la **unión** de todos sus roles (primario + secundarios). El permiso más permisivo prevalece.

---

## [2026-04-17] Sincronización sadmin ↔ rol sistemas

**Migración:** `20260417000001_fix_sadmin_for_sistemas_role.rb`

**Cambio:** Usuarios con rol `sistemas` reciben `sadmin = true`. Usuarios sin ese rol tienen `sadmin = false`. Garantiza coherencia entre ambos mecanismos de autorización.

---

## [2026-04-16] Corrección de fallback en TtpnBookings

**Migración:** `20260416000002_fix_employee_fallback_in_ttpn_bookings.rb`

**Cambio:** Backfill de empleados en bookings que tenían referencias huérfanas tras la migración del modelo de empleados.

---

## [2026-04-16] Strip sadmin de no-sistemas

**Migración:** `20260416000001_strip_sadmin_from_non_sistemas_users.rb`

**Cambio:** Retira `sadmin = true` a usuarios que no tienen el rol `sistemas`, evitando escalación de privilegios silenciosa.

---

## [2026-04-10] Auditoría en travel_counts

**Migración:** `20260410000001_add_audit_fields_to_travel_counts.rb`

**Cambio:** Columnas `created_by_id` y `updated_by_id` en `travel_counts`.

**Backfill requerido en producción:**
```sql
UPDATE travel_counts
SET created_by_id = (SELECT id FROM users WHERE sadmin = true ORDER BY id LIMIT 1)
WHERE created_by_id IS NULL;
```

---

## [2026-04-07] Sistema de Alertas

**Migraciones:** `20260407000001` al `20260407000010`

**Tablas nuevas:**
- `alert_contacts` — destinatarios configurables por BU
- `alert_rules` — reglas con condiciones y umbrales
- `alert_rule_recipients` — relación regla ↔ contacto
- `alerts` — instancias de alertas disparadas
- `alert_reads` — control de leídas por usuario
- `alert_deliveries` — log de envíos (email, push, etc.)

**Privileges seeded:** La migración `20260407000010` inserta los módulos de alertas en el catálogo de `privileges`.

---

## [2026-03-23] Soft-delete en usuarios

**Migración:** `20260323000001_add_is_active_to_users.rb`

**Cambio:** Columna `is_active` (boolean, default: true) en `users`. Los usuarios desactivados mantienen su historial pero no pueden autenticarse.

**Backfill:** Todos los usuarios existentes reciben `is_active = true` automáticamente.

---

## [2026-03-11] Business Unit en Roles

**Migración:** `20260311172720_add_business_unit_to_roles.rb`

**Cambio:** Columna `business_unit_id` en `roles`. Cada rol pertenece a una BU específica.

**Backfill requerido en producción:**
```sql
UPDATE roles SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

---

## [2026-02-26] JTI en Users (revocación JWT)

**Migración:** `20260226000000_add_jti_to_users.rb`

**Cambio:** Columna `jti` (UUID único) en `users`. Permite invalidar tokens JWT individualmente al cambiar el jti.

**Backfill crítico — usuarios sin jti no pueden autenticarse:**
```bash
bin/rails runner "User.where(jti: nil).find_each { |u| u.update_columns(jti: SecureRandom.uuid) }"
```

---

## [2026-02-17] Sistema de Privilegios

**Migración:** `20260217204843_create_privileges_and_role_privileges.rb`

**Tablas nuevas:**
- `privileges` — catálogo maestro de módulos del sistema con flags de acciones disponibles
- `role_privileges` — permisos específicos por rol (can_access, can_create, can_edit, can_delete, can_clone, can_import, can_export)

**Post-migración:** Ejecutar `setup_modules` para poblar el catálogo inicial de privileges y asignarlos al rol `sistemas`.

---

## [2026-01-06] Business Unit en DriverRequests y ServiceAppointments

**Migraciones:**
- `20260106222557_add_business_unit_id_to_driver_requests.rb`
- `20260106222611_add_business_unit_id_to_service_appointments.rb`

**Backfill:** Incluido en el task `backfill_tables`.

---

## [2026-01-15] Funciones y Triggers PostgreSQL

**Migraciones:** `20260115172932` al `20260115173001`

**Funciones creadas:**
- `calcular_asignaciones_activas()` — asignaciones de vehículo en curso
- `cuadre_viajes()` — reconciliación automática viaje ↔ nómina
- `cuadre_gasolina()` — reconciliación de cargos de combustible
- `buscar_nomina_para_viaje()` — match nómina ↔ viaje
- `calcular_contadores()` — contadores de operación

**Trigger:**
- `before_insert_travel_counts` — valida y asigna `clv_servicio` al insertar

> Estas funciones requieren permisos de superusuario en Supabase. Ver MIGRACION_DB.md paso 8.

---

## [2025-12-22] KumiSettings (configuración por BU)

**Migración:** `20251222181947_create_kumi_settings.rb`

**Tabla nueva:** `kumi_settings` — configuración clave-valor por `business_unit_id`.
- Índice único `(business_unit_id, key)` — sin duplicados por tenant
- Ver `documentacion/MULTI_TENANCY_KUMI_SETTINGS.md` para detalle completo

**Post-migración:** Ejecutar `setup_modules` para inicializar defaults de nómina por cada BU.

---

## [2025-12-22] PayrollLogs y campos de procesamiento

**Migraciones:** `20251222164110`, `20251222164635`, `20251220023442`

**Cambios en `payrolls`:**
- `processing_status` (string) — estado del procesamiento asíncrono
- `planned_end` (datetime) — fin estimado
- `started_at`, `finished_at`, `error_message`

**Tabla nueva:** `payroll_logs` — bitácora de eventos por nómina.

---

## [2025-12-18] Auditoría global (created_by / updated_by)

**Migración:** `20251218203315_add_audit_fields_to_existing_tables.rb`

**Columnas agregadas a múltiples tablas:** `created_by_id`, `updated_by_id` (FK a `users`)

**Tablas afectadas:** `vehicles`, `gas_files`, `gas_charges`, `ttpn_bookings`, `travel_counts`, `employees`, `payrolls`, y otras.

**Backfill:** Task `backfill_tables` los rellena con el usuario administrador principal.

---

## [2025-12-18] API Keys y API Users

**Migraciones:** `20251218205550`, `20251218211354`, `20251218211832`, `20251218212755`

**Tablas nuevas:**
- `api_keys` — claves de acceso M2M para integraciones externas (N8N, etc.)
- `api_users` — usuarios de tipo máquina, sin credenciales de sesión

**Columnas nuevas en `users`:**
- `allowed_apps` (jsonb array) — apps a las que tiene acceso
- `permissions_per_app` (jsonb object) — permisos específicos por app

---

## [2026-04-22] Multi-tenancy en tablas de detalle

**Migración:** `20260422190000_add_business_unit_to_detail_tables.rb`

**Tablas afectadas:** `employees_incidences`, `client_employees`, `employee_appointment_logs`

**Cambio:** Columna `business_unit_id` agregada (nullable) con FK e índice. Estas tablas tenían filtrado implícito via JOIN a su tabla padre, pero podían sufrir leaks si se consultaban directamente sin el JOIN.

**Backfill en producción:**
```sql
UPDATE employees_incidences   SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE client_employees       SET business_unit_id = 1 WHERE business_unit_id IS NULL;
UPDATE employee_appointment_logs SET business_unit_id = 1 WHERE business_unit_id IS NULL;
```

**Modelos actualizados:** `EmployeesIncidence`, `ClientEmployee`, `EmployeeAppointmentLog` — scope `business_unit_filter` + `before_create :assign_business_unit`.

**Controller actualizado:** `employees_incidences_controller.rb` — `index` y `set_employees_incidence` usan `business_unit_filter` directo en vez de JOIN manual.

**PHP:** `Gasto_INSERT_EMPLOYEE_INCIDENCE.php`, `Gasto_INSERT_CLIENT_EMPLOYEES.php`, `Gasto_INSERT_EMPLOYEE_APPOINTMENT_LOG.php` requieren agregar `business_unit_id = 1`.

---

## [2026-04-22] Seguridad BU — Remoción de bypass sadmin y fix Current.business_unit

**Commits:** `d18c80d`, `b992345`, `49c5ded`

### Problema corregido

Tres vulnerabilidades de multi-tenancy en el código backend:

1. **`Current.business_unit` nunca se asignaba para usuarios JWT** — `base_controller.rb`
   calculaba `@business_unit_id` pero no lo pasaba a `Current`. Los scopes `business_unit_filter`
   devolvían `none` en vez de filtrar correctamente.

2. **Bypass sadmin en 4 scopes de modelo** — `labor.rb`, `user.rb`, `vehicle.rb`, `concessionaire.rb`
   tenían `return all if Current.user&.sadmin?` que ignoraba el filtro de BU para el sadmin,
   permitiéndole ver datos de cualquier BU sin importar cuál tenía seleccionada.

3. **Controllers usando `current_user.business_unit_id`** en vez de `@business_unit_id` —
   `driver_requests`, `service_appointments`, `vehicle_asignations` y concerns de stats
   ignoraban la BU seleccionada por el sadmin.

### Archivos modificados

| Archivo | Cambio |
| ------- | ------ |
| `app/controllers/api/v1/base_controller.rb` | Agrega `Current.business_unit = BusinessUnit.find_by(id: @business_unit_id)` en `set_business_unit_id` |
| `app/models/labor.rb` | Remueve `return all if Current.user&.sadmin?` |
| `app/models/user.rb` | Remueve `return all if Current.user&.sadmin?` |
| `app/models/vehicle.rb` | Remueve `return all if Current.user&.sadmin?` |
| `app/models/concessionaire.rb` | Remueve `return all if Current.user&.sadmin?` |
| `app/controllers/api/v1/driver_requests_controller.rb` | Usa `@business_unit_id` en lugar de `current_user.business_unit_id` |
| `app/controllers/api/v1/service_appointments_controller.rb` | Ídem |
| `app/controllers/api/v1/vehicle_asignations_controller.rb` | Ídem |
| `app/controllers/concerns/booking_stats_calculable.rb` | Agrega `TtpnBooking.business_unit_filter` |
| `app/controllers/concerns/vehicle_stats_calculable.rb` | Agrega `Vehicle.business_unit_filter` en todos los queries |
| `app/services/payroll_svc/report_query.rb` | Agrega `Employee.business_unit_filter` |

### Impacto en producción

**No requiere migración de DB.** Solo cambios de código — ya desplegados en Railway.

El sadmin ahora ve exactamente los datos de la BU que selecciona en el FE (Settings → General).
Un usuario no-sadmin siempre ve solo los datos de su propia BU.

---

## RESUMEN DE ESTADO MULTI-TENANCY

| Tabla | business_unit_id | Scope en modelo | Notas |
|---|---|---|---|
| `users` | ✅ | ✅ `business_unit_filter` | |
| `roles` | ✅ | ✅ `business_unit_filter` | |
| `labors` | ✅ | ✅ `business_unit_filter` | Agregado 2026-04-22 |
| `employees` | ✅ | ✅ | |
| `clients` | ✅ | ✅ | |
| `vehicle_asignations` | ✅ | ✅ | |
| `driver_requests` | ✅ | ✅ | |
| `service_appointments` | ✅ | ✅ | |
| `kumi_settings` | ✅ | ✅ | Índice único por BU+key |
| `alert_contacts` | ✅ | ✅ | |
| `alert_rules` | ✅ | ✅ | |
| `vehicles` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `gas_files` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `gas_charges` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `gasoline_charges` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `ttpn_bookings` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `travel_counts` | ✅ | ✅ `business_unit_filter` | Migración 20260422185129 |
| `suppliers` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `gas_stations` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `coo_travel_requests` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `coo_travel_employee_requests` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `payrolls` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `invoicings` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `scheduled_maintenances` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `incidences` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
| `discrepancies` | ✅ | ✅ `business_unit_filter` | Migración 20260422185201 |
