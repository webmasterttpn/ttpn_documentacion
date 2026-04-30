-- =============================================================
-- Row Level Security (RLS) — Kumi TTPN Admin
-- Ejecutar en Supabase SQL Editor (con rol de administrador)
-- =============================================================
--
-- ARQUITECTURA DE ROLES Y CÓMO AFECTA RLS A CADA CONEXIÓN:
--
--   service_role     → Rails API. BYPASSRLS = true. El ORM filtra via
--                      .business_unit_filter. RLS no le aplica.
--
--   postgres          → Superusuario de Supabase. BYPASSRLS = true.
--                      Android (via PHP) conecta como este usuario al puerto
--                      6543 (Transaction Pooler). RLS NO le afecta.
--                      Es SEGURO habilitar RLS sin romper Android/PHP.
--
--   app_user          → Rol para scripts Python con conexión directa a BD.
--                      SIN BYPASSRLS. RLS sí aplica.
--                      N8N NO usa este rol — N8N llama al Rails API via API Key.
--
-- PUERTO 6543 (Transaction Pooler) vs SET LOCAL:
--   El Transaction Pooler (pgbouncer modo transacción) devuelve la conexión
--   al pool al terminar cada transacción. SET LOCAL solo vive dentro de la
--   transacción actual. Por eso es OBLIGATORIO usar BEGIN...COMMIT explícito
--   cuando se conecta vía pooler. Ver sección "CÓMO USAR" al final.
--
-- CUÁNDO EJECUTAR:
--   Una sola vez por ambiente (dev y producción por separado).
--   Al agregar una tabla nueva con business_unit_id, agregar su bloque aquí.
--
-- VERIFICACIÓN POST-EJECUCIÓN:
--   SELECT schemaname, tablename, rowsecurity
--   FROM pg_tables
--   WHERE schemaname = 'public'
--   ORDER BY tablename;
--
-- =============================================================


-- ── PASO 1: Crear rol app_user (si no existe) ────────────────
-- Rol para scripts Python con conexión directa a BD. SIN BYPASSRLS.
-- N8N usa API Keys del Rails API — no conecta directo a la BD.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user WITH LOGIN PASSWORD 'CAMBIAR_EN_PRODUCCION';
  END IF;
END$$;

-- Permisos mínimos: solo SELECT en tablas operativas
-- (ajustar según lo que los scripts Python realmente necesiten)
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_user;


-- ── PASO 2: Habilitar RLS en todas las tablas operativas ──────

ALTER TABLE alert_contacts                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_rules                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_users                       ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_units_concessionaires  ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_employees                ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_users                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients                         ENABLE ROW LEVEL SECURITY;
ALTER TABLE coo_travel_employee_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE coo_travel_requests             ENABLE ROW LEVEL SECURITY;
ALTER TABLE discrepancies                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_requests                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_appointment_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_appointments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees                       ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees_incidences            ENABLE ROW LEVEL SECURITY;
ALTER TABLE gas_charges                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE gas_files                       ENABLE ROW LEVEL SECURITY;
ALTER TABLE gas_stations                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE gasoline_charges                ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidences                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoicings                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE kumi_settings                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE labors                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE payrolls                        ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles                           ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_maintenances          ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_appointments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers                       ENABLE ROW LEVEL SECURITY;
ALTER TABLE travel_counts                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ttpn_bookings                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE users                           ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_asignations             ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles                        ENABLE ROW LEVEL SECURITY;


-- ── PASO 3: Policies por tabla ────────────────────────────────
-- Patrón: solo ver/modificar registros de tu propia BU.
-- La BU se establece con: SET LOCAL app.current_business_unit_id = <id>;
-- (lo hacen los scripts Python antes de cada query)

CREATE POLICY rls_alert_contacts ON alert_contacts
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_alert_rules ON alert_rules
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_alerts ON alerts
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_api_users ON api_users
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_business_units_concessionaires ON business_units_concessionaires
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_client_employees ON client_employees
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_client_users ON client_users
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_clients ON clients
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_coo_travel_employee_requests ON coo_travel_employee_requests
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_coo_travel_requests ON coo_travel_requests
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_discrepancies ON discrepancies
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_driver_requests ON driver_requests
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_employee_appointment_logs ON employee_appointment_logs
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_employee_appointments ON employee_appointments
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_employees ON employees
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_employees_incidences ON employees_incidences
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_gas_charges ON gas_charges
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_gas_files ON gas_files
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_gas_stations ON gas_stations
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_gasoline_charges ON gasoline_charges
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_incidences ON incidences
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_invoicings ON invoicings
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_kumi_settings ON kumi_settings
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_labors ON labors
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_payrolls ON payrolls
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_roles ON roles
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_scheduled_maintenances ON scheduled_maintenances
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_service_appointments ON service_appointments
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_suppliers ON suppliers
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_travel_counts ON travel_counts
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_ttpn_bookings ON ttpn_bookings
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_users ON users
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_vehicle_asignations ON vehicle_asignations
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);

CREATE POLICY rls_vehicles ON vehicles
  FOR ALL USING (business_unit_id = current_setting('app.current_business_unit_id', true)::int);


-- ── PASO 4: Verificar que RLS quedó activo ────────────────────

SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'alert_contacts','alert_rules','alerts','api_users',
    'business_units_concessionaires','client_employees','client_users',
    'clients','coo_travel_employee_requests','coo_travel_requests',
    'discrepancies','driver_requests','employee_appointment_logs',
    'employee_appointments','employees','employees_incidences',
    'gas_charges','gas_files','gas_stations','gasoline_charges',
    'incidences','invoicings','kumi_settings','labors','payrolls',
    'roles','scheduled_maintenances','service_appointments','suppliers',
    'travel_counts','ttpn_bookings','users','vehicle_asignations','vehicles'
  )
ORDER BY tablename;
-- Resultado esperado: todas las filas con rls_enabled = true


-- ── CÓMO CONECTAN LOS DISTINTOS ACTORES ──────────────────────
--
-- ── N8N ───────────────────────────────────────────────────────
--
--   N8N NO conecta directo a la BD. Llama al Rails API via HTTP
--   usando una API Key (modelo ApiKey / ApiUser en Rails).
--   El filtrado de BU lo hace el ORM de Rails internamente.
--   N8N no necesita SET LOCAL ni rol app_user.
--
-- ── Python (utils/db.py, via app_user con RLS) ───────────────
--
--   Usar puerto 5432 (Session Pooler / conexión directa), NO 6543.
--   SET LOCAL solo vive dentro de la transacción. Con psycopg2:
--
--   with conn.cursor() as cur:
--       cur.execute("SET LOCAL app.current_business_unit_id = %s", (bu_id,))
--       cur.execute("SELECT * FROM employees")
--       return cur.fetchall()
--
--   Si se usa el Transaction Pooler (6543), envolver en transacción explícita:
--
--   with conn:                               # BEGIN implícito de psycopg2
--       with conn.cursor() as cur:
--           cur.execute("SELECT set_config('app.current_business_unit_id', %s, true)", (str(bu_id),))
--           cur.execute("SELECT * FROM employees")
--           return cur.fetchall()
--                                            # COMMIT al salir del bloque with
--
-- ── Comportamiento de seguridad si no se establece la BU ──────
--
--   Si app_user hace una query SIN establecer business_unit_id:
--   current_setting('app.current_business_unit_id', true) devuelve NULL.
--   La policy USING (business_unit_id = NULL::int) nunca es TRUE.
--   Resultado: 0 filas devueltas — falla segura (no expone datos de otras BUs).
--
-- ── Android/PHP (postgres user) ───────────────────────────────
--
--   El usuario postgres tiene BYPASSRLS = true. No necesita SET LOCAL.
--   RLS no afecta sus queries sin importar el puerto ni el modo de conexión.
--   Las pruebas de Android con el pooler en puerto 6543 son completamente seguras.
