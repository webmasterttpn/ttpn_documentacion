# 📋 GUÍA DE INTEGRACIÓN PHP - CITAS DE EMPLEADOS

## 🎯 **OBJETIVO:**

Documentar cómo insertar citas desde PHP/Android manteniendo compatibilidad con Rails.

---

## 📊 **ESTRUCTURA DE TABLAS:**

### **1. `employee_appointments` (Tabla Principal)**

```sql
CREATE TABLE employee_appointments (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL,           -- Empleado principal (legacy)
  business_unit_id INTEGER DEFAULT 1,
  titulo VARCHAR,
  descripcion TEXT,
  fecha_inicio DATE NOT NULL,
  hora_inicio TIME NOT NULL,
  fecha_fin DATE,
  hora_fin TIME,
  status VARCHAR DEFAULT 'Agendado',      -- 'Agendado', 'Completo', 'Cancelado'
  ubicacion VARCHAR,
  tipo_cita VARCHAR,                      -- 'Reunión', 'Entrevista', etc.
  created_by VARCHAR,
  updated_by VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### **2. `employee_appointment_attendees` (Múltiples Empleados)**

```sql
CREATE TABLE employee_appointment_attendees (
  id SERIAL PRIMARY KEY,
  employee_appointment_id INTEGER NOT NULL REFERENCES employee_appointments(id),
  employee_id INTEGER NOT NULL REFERENCES employees(id),
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(employee_appointment_id, employee_id)
);
```

---

## 🔧 **OPCIÓN 1: CITA CON UN SOLO EMPLEADO (Legacy)**

### **PHP - INSERT Directo:**

```php
<?php
// Conexión a PostgreSQL
$conn = pg_connect("host=localhost dbname=ttpngas_development user=postgres");

// Datos de la cita
$employee_id = 2050;
$titulo = "Capacitación de seguridad";
$descripcion = "Capacitación sobre normas de seguridad";
$fecha_inicio = "2025-01-15";
$hora_inicio = "10:00:00";
$status = "Agendado";
$business_unit_id = 1;

// INSERT directo (compatible con Rails)
$query = "
  INSERT INTO employee_appointments (
    employee_id,
    business_unit_id,
    titulo,
    descripcion,
    fecha_inicio,
    hora_inicio,
    status,
    created_at,
    updated_at
  ) VALUES (
    $1, $2, $3, $4, $5, $6, $7, NOW(), NOW()
  )
  RETURNING id
";

$result = pg_query_params($conn, $query, [
    $employee_id,
    $business_unit_id,
    $titulo,
    $descripcion,
    $fecha_inicio,
    $hora_inicio,
    $status
]);

$row = pg_fetch_assoc($result);
$appointment_id = $row['id'];

echo "Cita creada con ID: $appointment_id\n";

pg_close($conn);
?>
```

---

## 🔧 **OPCIÓN 2: CITA CON MÚLTIPLES EMPLEADOS (Nuevo)**

### **PHP - INSERT con Múltiples Empleados:**

```php
<?php
$conn = pg_connect("host=localhost dbname=ttpngas_development user=postgres");

// Datos de la cita
$employee_id = 2050;  // Empleado principal (obligatorio)
$titulo = "Reunión de equipo";
$descripcion = "Reunión mensual del equipo";
$fecha_inicio = "2025-01-20";
$hora_inicio = "14:00:00";
$hora_fin = "15:00:00";
$status = "Agendado";
$business_unit_id = 1;

// Empleados adicionales (asistentes)
$attendees = [1141, 1500, 1600];  // IDs de empleados

// Iniciar transacción
pg_query($conn, "BEGIN");

try {
    // 1. Crear la cita principal
    $query = "
      INSERT INTO employee_appointments (
        employee_id,
        business_unit_id,
        titulo,
        descripcion,
        fecha_inicio,
        hora_inicio,
        hora_fin,
        status,
        created_at,
        updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()
      )
      RETURNING id
    ";

    $result = pg_query_params($conn, $query, [
        $employee_id,
        $business_unit_id,
        $titulo,
        $descripcion,
        $fecha_inicio,
        $hora_inicio,
        $hora_fin,
        $status
    ]);

    $row = pg_fetch_assoc($result);
    $appointment_id = $row['id'];

    // 2. Agregar empleados asistentes
    foreach ($attendees as $attendee_id) {
        $attendee_query = "
          INSERT INTO employee_appointment_attendees (
            employee_appointment_id,
            employee_id,
            created_at,
            updated_at
          ) VALUES (
            $1, $2, NOW(), NOW()
          )
          ON CONFLICT (employee_appointment_id, employee_id) DO NOTHING
        ";

        pg_query_params($conn, $attendee_query, [
            $appointment_id,
            $attendee_id
        ]);
    }

    // Commit
    pg_query($conn, "COMMIT");
    echo "Cita creada con ID: $appointment_id con " . count($attendees) . " asistentes\n";

} catch (Exception $e) {
    pg_query($conn, "ROLLBACK");
    echo "Error: " . $e->getMessage() . "\n";
}

pg_close($conn);
?>
```

---

## 📝 **VALORES PERMITIDOS:**

### **Status:**

- `Agendado` (default)
- `Completo`
- `Cancelado`

### **Tipo de Cita:**

- `Reunión`
- `Entrevista`
- `Revisión`
- `Capacitación`
- `Otro`

---

## ⚠️ **IMPORTANTE - SINCRONIZACIÓN DE IDs:**

### **Problema:**

PHP hace `INSERT` directo con IDs específicos, lo que desincroniza la secuencia de PostgreSQL.

### **Solución:**

Rails tiene un `Concern` que resetea la secuencia automáticamente antes de cada `.create`.

### **Recomendación:**

**NO especificar el ID manualmente en PHP.** Dejar que PostgreSQL lo genere automáticamente:

```php
// ❌ MAL - Especificar ID
INSERT INTO employee_appointments (id, employee_id, ...) VALUES (999, 2050, ...);

// ✅ BIEN - Dejar que PostgreSQL genere el ID
INSERT INTO employee_appointments (employee_id, ...) VALUES (2050, ...) RETURNING id;
```

Si **DEBES** especificar el ID (por compatibilidad con sistema legacy):

```php
// Después del INSERT, resetear la secuencia
pg_query($conn, "SELECT setval('employee_appointments_id_seq', (SELECT MAX(id) FROM employee_appointments))");
```

---

## 🔍 **CONSULTAS ÚTILES:**

### **Ver citas con todos sus asistentes:**

```sql
SELECT
  ea.id,
  ea.titulo,
  ea.fecha_inicio,
  ea.hora_inicio,
  e_principal.nombre AS empleado_principal,
  STRING_AGG(e_asistente.nombre, ', ') AS asistentes
FROM employee_appointments ea
LEFT JOIN employees e_principal ON ea.employee_id = e_principal.id
LEFT JOIN employee_appointment_attendees eaa ON ea.id = eaa.employee_appointment_id
LEFT JOIN employees e_asistente ON eaa.employee_id = e_asistente.id
WHERE ea.fecha_inicio = '2025-01-20'
GROUP BY ea.id, e_principal.nombre
ORDER BY ea.hora_inicio;
```

### **Contar asistentes por cita:**

```sql
SELECT
  ea.id,
  ea.titulo,
  COUNT(eaa.id) as total_asistentes
FROM employee_appointments ea
LEFT JOIN employee_appointment_attendees eaa ON ea.id = eaa.employee_appointment_id
GROUP BY ea.id, ea.titulo;
```

---

## 📊 **EJEMPLO COMPLETO - ANDROID/PHP:**

```php
<?php
class AppointmentManager {
    private $conn;

    public function __construct($db_config) {
        $this->conn = pg_connect(
            "host={$db_config['host']} " .
            "dbname={$db_config['database']} " .
            "user={$db_config['user']} " .
            "password={$db_config['password']}"
        );
    }

    /**
     * Crear cita con múltiples empleados
     *
     * @param int $employee_id Empleado principal
     * @param array $data Datos de la cita
     * @param array $attendees IDs de empleados asistentes
     * @return int ID de la cita creada
     */
    public function createAppointment($employee_id, $data, $attendees = []) {
        pg_query($this->conn, "BEGIN");

        try {
            // Crear cita principal
            $query = "
                INSERT INTO employee_appointments (
                    employee_id,
                    business_unit_id,
                    titulo,
                    descripcion,
                    fecha_inicio,
                    hora_inicio,
                    hora_fin,
                    ubicacion,
                    tipo_cita,
                    status,
                    created_at,
                    updated_at
                ) VALUES (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW()
                )
                RETURNING id
            ";

            $result = pg_query_params($this->conn, $query, [
                $employee_id,
                $data['business_unit_id'] ?? 1,
                $data['titulo'] ?? null,
                $data['descripcion'] ?? null,
                $data['fecha_inicio'],
                $data['hora_inicio'],
                $data['hora_fin'] ?? null,
                $data['ubicacion'] ?? null,
                $data['tipo_cita'] ?? null,
                $data['status'] ?? 'Agendado'
            ]);

            $row = pg_fetch_assoc($result);
            $appointment_id = $row['id'];

            // Agregar asistentes
            if (!empty($attendees)) {
                $this->addAttendees($appointment_id, $attendees);
            }

            pg_query($this->conn, "COMMIT");
            return $appointment_id;

        } catch (Exception $e) {
            pg_query($this->conn, "ROLLBACK");
            throw $e;
        }
    }

    /**
     * Agregar asistentes a una cita
     */
    private function addAttendees($appointment_id, $attendees) {
        $query = "
            INSERT INTO employee_appointment_attendees (
                employee_appointment_id,
                employee_id,
                created_at,
                updated_at
            ) VALUES ($1, $2, NOW(), NOW())
            ON CONFLICT (employee_appointment_id, employee_id) DO NOTHING
        ";

        foreach ($attendees as $employee_id) {
            pg_query_params($this->conn, $query, [
                $appointment_id,
                $employee_id
            ]);
        }
    }

    /**
     * Actualizar cita
     */
    public function updateAppointment($appointment_id, $data) {
        $query = "
            UPDATE employee_appointments
            SET
                titulo = $1,
                descripcion = $2,
                fecha_inicio = $3,
                hora_inicio = $4,
                hora_fin = $5,
                ubicacion = $6,
                status = $7,
                updated_at = NOW()
            WHERE id = $8
        ";

        return pg_query_params($this->conn, $query, [
            $data['titulo'] ?? null,
            $data['descripcion'] ?? null,
            $data['fecha_inicio'],
            $data['hora_inicio'],
            $data['hora_fin'] ?? null,
            $data['ubicacion'] ?? null,
            $data['status'] ?? 'Agendado',
            $appointment_id
        ]);
    }

    public function __destruct() {
        pg_close($this->conn);
    }
}

// USO:
$db_config = [
    'host' => 'localhost',
    'database' => 'ttpngas_development',
    'user' => 'postgres',
    'password' => ''
];

$manager = new AppointmentManager($db_config);

// Crear cita con múltiples empleados
$appointment_id = $manager->createAppointment(
    2050,  // Empleado principal
    [
        'titulo' => 'Reunión de seguridad',
        'descripcion' => 'Revisión de protocolos',
        'fecha_inicio' => '2025-01-25',
        'hora_inicio' => '09:00:00',
        'hora_fin' => '10:00:00',
        'tipo_cita' => 'Reunión',
        'status' => 'Agendado'
    ],
    [1141, 1500, 1600]  // Asistentes
);

echo "Cita creada: $appointment_id\n";
?>
```

---

## ✅ **CHECKLIST DE INTEGRACIÓN:**

- [ ] Usar valores en ESPAÑOL para `status` y `tipo_cita`
- [ ] NO especificar `id` manualmente (dejar que PostgreSQL lo genere)
- [ ] Usar `RETURNING id` para obtener el ID generado
- [ ] Usar transacciones para citas con múltiples empleados
- [ ] Validar que `employee_id` exista antes de insertar
- [ ] Usar `NOW()` para `created_at` y `updated_at`
- [ ] Manejar errores con try/catch y ROLLBACK

---

## 🚀 **MIGRACIÓN:**

Para ejecutar la migración de múltiples empleados:

```bash
docker-compose exec app rails db:migrate
```

---

**¡Documentación completa para integración PHP!** 📋
