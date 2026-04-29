# 📚 DOCUMENTACIÓN COMPLETA: API de Clientes (Clients)

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Modelos y Relaciones](#modelos-y-relaciones)
4. [Estructura de Datos](#estructura-de-datos)
5. [Nested Attributes](#nested-attributes)
6. [Lógica de Negocio](#lógica-de-negocio)
7. [Ejemplos de Uso](#ejemplos-de-uso)
8. [Plan de Implementación](#plan-de-implementación)

---

## 🎯 Visión General

### Propósito del Sistema

El módulo de **Clients** es el núcleo del sistema de gestión de servicios de transporte. Maneja:

- **Clientes corporativos** con múltiples sucursales
- **Servicios TTPN** contratados por cada cliente
- **Rutas y horarios** específicos por sucursal
- **Incrementos dinámicos** al servicio y al pago de choferes
- **Configuración compleja** de precios por periodo y cantidad de pasajeros

### Complejidad del Sistema

- **10 modelos** interrelacionados
- **5 niveles** de profundidad en nested attributes
- **Múltiples dimensiones** de configuración (tiempo, cantidad, tipo)
- **Generación automática** de identificadores únicos
- **Validaciones complejas** en cascada

---

## 🏗️ Arquitectura del Sistema

### Diagrama de Relaciones

```
┌─────────────────────────────────────────────────────────────────┐
│                           CLIENT                                 │
│  - clv (unique)                                                  │
│  - razon_social, rfc                                            │
│  - Dirección completa                                           │
│  - status, telefono                                             │
│  - business_unit_id (a agregar)                                 │
└────────────┬────────────────────────────┬───────────────────────┘
             │                            │
             │                            │
    ┌────────▼─────────┐         ┌───────▼──────────────┐
    │ BRANCH OFFICES   │         │  TTPN SERVICES       │
    │  (Sucursales)    │         │  (Servicios)         │
    └────────┬─────────┘         └───────┬──────────────┘
             │                            │
             │                   ┌────────┴─────────┐
             │                   │                  │
    ┌────────▼─────────┐  ┌──────▼────────┐ ┌─────▼─────────────┐
    │    CR_DAYS       │  │ CTS_INCREMENT │ │ CTS_DRIVER_       │
    │ (Días servicio)  │  │ (Incremento   │ │ INCREMENT         │
    └────────┬─────────┘  │  al servicio) │ │ (Incremento       │
             │            └──────┬────────┘ │  al chofer)       │
             │                   │          └───────────────────┘
    ┌────────▼─────────┐  ┌──────▼────────────┐
    │    CRD_HRS       │  │ CTS_INCREMENT_    │
    │   (Horarios)     │  │ DETAIL            │
    └────────┬─────────┘  │ (Detalle por      │
             │            │  pasajeros)       │
    ┌────────▼─────────┐  └───────────────────┘
    │  CRDH_ROUTES     │
    │    (Rutas)       │
    └────────┬─────────┘
             │
    ┌────────▼─────────┐
    │  CRDHR_POINTS    │
    │ (Puntos de ruta) │
    └──────────────────┘
```

---

## 📊 Modelos y Relaciones

### 1. CLIENT (Modelo Raíz)

#### Descripción

Representa un cliente corporativo que contrata servicios de transporte.

#### Campos de Base de Datos

```ruby
# Tabla: clients
create_table "clients" do |t|
  t.string   "clv"                    # Clave única del cliente
  t.string   "razon_social"           # Razón social
  t.string   "rfc"                    # RFC fiscal
  t.string   "calle"                  # Dirección: calle
  t.string   "numero"                 # Dirección: número
  t.string   "colonia"                # Dirección: colonia
  t.string   "ciudad"                 # Dirección: ciudad
  t.string   "estado"                 # Dirección: estado
  t.integer  "codigo_postal"          # Dirección: código postal
  t.string   "telefono"               # Teléfono de contacto
  t.boolean  "status"                 # Activo/Inactivo
  t.bigint   "created_by_id"          # Usuario que creó
  t.bigint   "updated_by_id"          # Usuario que actualizó
  t.datetime "created_at"
  t.datetime "updated_at"

  # A AGREGAR:
  t.integer  "business_unit_id"      # Unidad de negocio
end

# Índices
add_index "clients", ["clv"], unique: true
add_index "clients", ["created_by_id"]
add_index "clients", ["updated_by_id"]
```

#### Modelo Ruby

```ruby
class Client < ApplicationRecord
  # === ASOCIACIONES ===
  has_many :client_branch_offices, dependent: :destroy
  has_many :client_ttpn_services, dependent: :destroy
  has_and_belongs_to_many :concessionaires
  belongs_to :business_unit  # A AGREGAR

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :client_branch_offices,
    allow_destroy: true,
    reject_if: proc { |att| att['clv'].blank? }

  accepts_nested_attributes_for :client_ttpn_services,
    allow_destroy: true,
    reject_if: proc { |att| att['ttpn_service_id'].blank? }

  # === VALIDACIONES ===
  validates :clv, presence: true, uniqueness: true
  validates :razon_social, presence: true
  validates :business_unit_id, presence: true  # A AGREGAR

  # === SCOPES ===
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_business_unit, ->(bu_id) { where(business_unit_id: bu_id) if bu_id.present? }

  # Scope complejo para filtrar por business_unit usando concessionaires
  scope :business_unit_filter, lambda {
    joins(:concessionaires)
      .where('clients_concessionaires.client_id = clients.id')
      .where("clients_concessionaires.concessionaire_id = (
        SELECT DISTINCT(cscl1.concessionaire_id)
        FROM clients_concessionaires AS cscl1,
             business_units_concessionaires AS bucs
        WHERE cscl1.concessionaire_id = bucs.concessionaire_id
        AND bucs.business_unit_id = ?)", business_unit_id)
  }

  # === MÉTODOS ===
  def custom_label_method
    clv.to_s
  end

  def full_address
    "#{calle} #{numero}, #{colonia}, #{ciudad}, #{estado} #{codigo_postal}"
  end
end
```

#### Lógica de Negocio

1. **CLV Único**: Cada cliente tiene una clave única que lo identifica
2. **Multi-tenant**: Filtrado automático por `business_unit_id`
3. **Auditoría**: Tracking de quién crea/modifica
4. **Soft Delete**: Usar `status` en lugar de eliminar físicamente
5. **Concessionaires**: Relación muchos a muchos para asignación de clientes

---

### 2. CLIENT_BRANCH_OFFICE (Sucursales)

#### Descripción

Representa una sucursal o planta del cliente donde se prestan servicios.

#### Campos de Base de Datos

```ruby
# Tabla: client_branch_offices
create_table "client_branch_offices" do |t|
  t.integer  "client_id"             # FK a clients
  t.string   "clv"                   # Clave de la sucursal
  t.string   "nombre"                # Nombre de la sucursal
  t.string   "calle"                 # Dirección
  t.string   "colonia"
  t.string   "numero"
  t.string   "ciudad"
  t.string   "codigo_postal"
  t.float    "lat"                   # Latitud GPS
  t.float    "lng"                   # Longitud GPS
  t.string   "gps_uniq"              # UUID único para GPS
  t.boolean  "status"
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class ClientBranchOffice < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :client
  has_many :cr_days, dependent: :destroy
  has_many :employees_incidences

  # === VALIDACIONES ===
  validates :clv, presence: true
  validates :nombre, presence: true
  validates :client_id, presence: true

  # === CALLBACKS ===
  before_create :generate_gps_uniq

  # === MÉTODOS ===
  def custom_label_method
    "#{clv} - #{nombre}"
  end

  def full_address
    "#{calle} #{numero}, #{colonia}, #{ciudad} #{codigo_postal}"
  end

  def coordinates
    { lat: lat, lng: lng }
  end

  private

  def generate_gps_uniq
    self.gps_uniq ||= SecureRandom.uuid
  end
end
```

#### Lógica de Negocio

1. **GPS Tracking**: Cada sucursal tiene coordenadas únicas
2. **UUID Automático**: Se genera `gps_uniq` al crear
3. **Rutas Asociadas**: Las rutas se configuran por sucursal
4. **Múltiples Sucursales**: Un cliente puede tener N sucursales

---

### 3. CLIENT_TTPN_SERVICE (Servicios Contratados)

#### Descripción

Representa un servicio TTPN contratado por el cliente, con sus incrementos asociados.

#### Campos de Base de Datos

```ruby
# Tabla: client_ttpn_services
create_table "client_ttpn_services" do |t|
  t.integer  "client_id"             # FK a clients
  t.integer  "ttpn_service_id"       # FK a ttpn_services
  t.boolean  "status"                # Activo/Inactivo
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class ClientTtpnService < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :client
  belongs_to :ttpn_service

  has_many :cts_increments, dependent: :destroy
  has_many :cts_driver_increments, dependent: :destroy

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :cts_increments,
    allow_destroy: true,
    reject_if: proc { |att| att['fecha_efectiva'].blank? }

  accepts_nested_attributes_for :cts_driver_increments,
    allow_destroy: true,
    reject_if: proc { |att| att['fecha_efectiva'].blank? }

  # === VALIDACIONES ===
  validates :client_id, presence: true
  validates :ttpn_service_id, presence: true
  validates :ttpn_service_id, uniqueness: { scope: :client_id,
    message: "ya está contratado por este cliente" }

  # === MÉTODOS ===
  def custom_label_method
    ttpn_service.clv.to_s
  end

  def active_increment_for_date(date, passengers)
    cts_increments
      .where('fecha_efectiva <= ? AND (fecha_hasta IS NULL OR fecha_hasta >= ?)', date, date)
      .joins(:cts_increment_details)
      .where('cts_increment_details.pasajeros_min <= ? AND cts_increment_details.pasajeros_max >= ?',
             passengers, passengers)
      .first
  end

  def active_driver_increment_for_date(date, vehicle_type_id)
    cts_driver_increments
      .where(vehicle_type_id: vehicle_type_id)
      .where('fecha_efectiva <= ? AND (fecha_hasta IS NULL OR fecha_hasta >= ?)', date, date)
      .where(status: true)
      .first
  end
end
```

#### Lógica de Negocio

1. **Servicio Único**: Un cliente no puede contratar el mismo servicio dos veces
2. **Incrementos por Periodo**: Los incrementos tienen vigencia por fechas
3. **Incrementos por Pasajeros**: Diferentes % según cantidad de pasajeros
4. **Incrementos al Chofer**: Diferentes montos según tipo de vehículo
5. **Búsqueda Activa**: Métodos para encontrar incrementos vigentes

---

### 4. CTS_INCREMENT (Incremento al Servicio)

#### Descripción

Define un periodo de vigencia para incrementos al precio del servicio.

#### Campos de Base de Datos

```ruby
# Tabla: cts_increments
create_table "cts_increments" do |t|
  t.integer  "client_ttpn_service_id"  # FK a client_ttpn_services
  t.date     "fecha_efectiva"          # Inicio de vigencia
  t.date     "fecha_hasta"             # Fin de vigencia (nullable)
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CtsIncrement < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :client_ttpn_service
  has_many :cts_increment_details, dependent: :destroy

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :cts_increment_details,
    allow_destroy: true,
    reject_if: proc { |att| att['incremento'].blank? }

  # === VALIDACIONES ===
  validates :fecha_efectiva, presence: true
  validates :client_ttpn_service_id, presence: true
  validate :fecha_hasta_after_fecha_efectiva
  validate :no_overlapping_periods

  # === SCOPES ===
  scope :active_on, ->(date) {
    where('fecha_efectiva <= ?', date)
      .where('fecha_hasta IS NULL OR fecha_hasta >= ?', date)
  }

  # === MÉTODOS ===
  def custom_label_method
    fecha_efectiva.to_s
  end

  def period_description
    if fecha_hasta.present?
      "#{fecha_efectiva.strftime('%d/%m/%Y')} - #{fecha_hasta.strftime('%d/%m/%Y')}"
    else
      "Desde #{fecha_efectiva.strftime('%d/%m/%Y')}"
    end
  end

  def increment_for_passengers(count)
    cts_increment_details
      .where('pasajeros_min <= ? AND pasajeros_max >= ?', count, count)
      .first
      &.incremento || 0.0
  end

  private

  def fecha_hasta_after_fecha_efectiva
    return if fecha_hasta.blank?
    if fecha_hasta < fecha_efectiva
      errors.add(:fecha_hasta, "debe ser posterior a la fecha efectiva")
    end
  end

  def no_overlapping_periods
    overlapping = client_ttpn_service.cts_increments
      .where.not(id: id)
      .where('fecha_efectiva <= ? AND (fecha_hasta IS NULL OR fecha_hasta >= ?)',
             fecha_hasta || Date.today + 100.years, fecha_efectiva)

    if overlapping.exists?
      errors.add(:base, "El periodo se traslapa con otro incremento existente")
    end
  end
end
```

#### Lógica de Negocio

1. **Periodos de Vigencia**: Cada incremento tiene inicio y fin
2. **Sin Traslapes**: No puede haber periodos que se traslapen
3. **Fecha Abierta**: `fecha_hasta` puede ser NULL (vigencia indefinida)
4. **Múltiples Detalles**: Un periodo puede tener varios rangos de pasajeros
5. **Búsqueda por Fecha**: Scope para encontrar incrementos activos

---

### 5. CTS_INCREMENT_DETAIL (Detalle por Pasajeros)

#### Descripción

Define el porcentaje de incremento según la cantidad de pasajeros.

#### Campos de Base de Datos

```ruby
# Tabla: cts_increment_details
create_table "cts_increment_details" do |t|
  t.integer  "cts_increment_id"      # FK a cts_increments
  t.float    "incremento"            # Porcentaje de incremento
  t.integer  "pasajeros_min"         # Mínimo de pasajeros
  t.integer  "pasajeros_max"         # Máximo de pasajeros
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CtsIncrementDetail < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :cts_increment

  # === VALIDACIONES ===
  validates :incremento, presence: true, numericality: true
  validates :pasajeros_min, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :pasajeros_max, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validate :max_greater_than_min
  validate :no_overlapping_ranges

  # === MÉTODOS ===
  def custom_label_method
    incremento.to_s
  end

  def range_description
    if pasajeros_min == pasajeros_max
      "#{pasajeros_min} pasajero(s)"
    else
      "#{pasajeros_min}-#{pasajeros_max} pasajeros"
    end
  end

  def includes_passenger_count?(count)
    count >= pasajeros_min && count <= pasajeros_max
  end

  private

  def max_greater_than_min
    if pasajeros_max < pasajeros_min
      errors.add(:pasajeros_max, "debe ser mayor o igual al mínimo")
    end
  end

  def no_overlapping_ranges
    overlapping = cts_increment.cts_increment_details
      .where.not(id: id)
      .where('pasajeros_min <= ? AND pasajeros_max >= ?', pasajeros_max, pasajeros_min)

    if overlapping.exists?
      errors.add(:base, "El rango de pasajeros se traslapa con otro existente")
    end
  end
end
```

#### Lógica de Negocio

1. **Rangos de Pasajeros**: Define min y max de pasajeros
2. **Sin Traslapes**: Los rangos no pueden traslaparse
3. **Incremento Porcentual**: El incremento es un porcentaje (float)
4. **Validación de Rangos**: Max debe ser >= Min
5. **Búsqueda por Cantidad**: Método para verificar si aplica a N pasajeros

#### Ejemplo de Uso

```ruby
# Configuración de incrementos por pasajeros
# 1-5 pasajeros: +10%
# 6-10 pasajeros: +15%
# 11-14 pasajeros: +20%

increment = CtsIncrement.create(
  client_ttpn_service_id: 1,
  fecha_efectiva: '2026-01-01',
  fecha_hasta: '2026-12-31',
  cts_increment_details_attributes: [
    { pasajeros_min: 1, pasajeros_max: 5, incremento: 10.0 },
    { pasajeros_min: 6, pasajeros_max: 10, incremento: 15.0 },
    { pasajeros_min: 11, pasajeros_max: 14, incremento: 20.0 }
  ]
)

# Buscar incremento para 7 pasajeros
increment.increment_for_passengers(7)  # => 15.0
```

---

### 6. CTS_DRIVER_INCREMENT (Incremento al Chofer)

#### Descripción

Define incrementos al pago del chofer según el tipo de vehículo utilizado.

#### Campos de Base de Datos

```ruby
# Tabla: cts_driver_increments
create_table "cts_driver_increments" do |t|
  t.integer  "client_ttpn_service_id"  # FK a client_ttpn_services
  t.integer  "vehicle_type_id"         # FK a vehicle_types
  t.float    "incremento"              # Monto del incremento
  t.date     "fecha_efectiva"          # Inicio de vigencia
  t.date     "fecha_hasta"             # Fin de vigencia
  t.boolean  "status"                  # Activo/Inactivo
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CtsDriverIncrement < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :client_ttpn_service
  belongs_to :vehicle_type

  # === VALIDACIONES ===
  validates :incremento, presence: true, numericality: true
  validates :fecha_efectiva, presence: true
  validates :vehicle_type_id, presence: true
  validates :vehicle_type_id, uniqueness: {
    scope: [:client_ttpn_service_id, :fecha_efectiva],
    message: "ya tiene un incremento para esta fecha"
  }
  validate :fecha_hasta_after_fecha_efectiva

  # === SCOPES ===
  scope :active, -> { where(status: true) }
  scope :active_on, ->(date) {
    where('fecha_efectiva <= ?', date)
      .where('fecha_hasta IS NULL OR fecha_hasta >= ?', date)
      .where(status: true)
  }
  scope :for_vehicle_type, ->(type_id) { where(vehicle_type_id: type_id) }

  # === MÉTODOS ===
  def custom_label_method
    vehicle_type.nombre.to_s
  end

  def period_description
    if fecha_hasta.present?
      "#{fecha_efectiva.strftime('%d/%m/%Y')} - #{fecha_hasta.strftime('%d/%m/%Y')}"
    else
      "Desde #{fecha_efectiva.strftime('%d/%m/%Y')}"
    end
  end

  private

  def fecha_hasta_after_fecha_efectiva
    return if fecha_hasta.blank?
    if fecha_hasta < fecha_efectiva
      errors.add(:fecha_hasta, "debe ser posterior a la fecha efectiva")
    end
  end
end
```

#### Lógica de Negocio

1. **Por Tipo de Vehículo**: Cada tipo tiene su propio incremento
2. **Monto Fijo**: A diferencia del servicio, este es un monto fijo
3. **Periodos de Vigencia**: Similar a `cts_increment`
4. **Status Activo**: Puede desactivarse sin eliminar
5. **Único por Tipo/Fecha**: No puede haber duplicados

#### Ejemplo de Uso

```ruby
# Configuración de incrementos al chofer
# Van: +$50 por viaje
# Sprinter: +$75 por viaje
# Autobús: +$100 por viaje

service.cts_driver_increments.create([
  {
    vehicle_type_id: 1,  # Van
    incremento: 50.0,
    fecha_efectiva: '2026-01-01',
    status: true
  },
  {
    vehicle_type_id: 2,  # Sprinter
    incremento: 75.0,
    fecha_efectiva: '2026-01-01',
    status: true
  }
])

# Buscar incremento activo para Van
service.active_driver_increment_for_date(Date.today, 1)  # => 50.0
```

---

### 7. CR_DAY (Días de Servicio)

#### Descripción

Define los días de la semana en que se presta servicio a una sucursal.

#### Campos de Base de Datos

```ruby
# Tabla: cr_days
create_table "cr_days" do |t|
  t.integer  "client_id"                # FK a clients
  t.integer  "client_branch_office_id"  # FK a client_branch_offices
  t.integer  "dia_semana"               # 0-6 (Domingo-Sábado)
  t.boolean  "act_branch"               # Usar sucursal específica?
  t.boolean  "status"                   # Activo/Inactivo
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CrDay < ApplicationRecord
  # === CONSTANTES ===
  DIAS_SEMANA = {
    0 => 'Domingo',
    1 => 'Lunes',
    2 => 'Martes',
    3 => 'Miércoles',
    4 => 'Jueves',
    5 => 'Viernes',
    6 => 'Sábado'
  }.freeze

  # === ASOCIACIONES ===
  belongs_to :client
  belongs_to :client_branch_office, optional: true
  has_many :crd_hrs, dependent: :destroy

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :crd_hrs,
    allow_destroy: true,
    reject_if: proc { |att| att['hora_oficial'].blank? }

  # === VALIDACIONES ===
  validates :dia_semana, presence: true,
    inclusion: { in: 0..6, message: "debe estar entre 0 y 6" }
  validates :client_id, presence: true
  validates :dia_semana, uniqueness: {
    scope: [:client_id, :client_branch_office_id],
    message: "ya está configurado para este cliente/sucursal"
  }
  validate :branch_office_belongs_to_client

  # === SCOPES ===
  scope :for_day, ->(day) { where(dia_semana: day) }
  scope :active, -> { where(status: true) }
  scope :with_branch, -> { where(act_branch: true) }

  # === MÉTODOS ===
  def custom_label_method
    dia_semana.to_s
  end

  def day_name
    DIAS_SEMANA[dia_semana]
  end

  def location_description
    if act_branch && client_branch_office.present?
      client_branch_office.nombre
    else
      "General (#{client.razon_social})"
    end
  end

  private

  def branch_office_belongs_to_client
    return unless act_branch && client_branch_office.present?
    unless client_branch_office.client_id == client_id
      errors.add(:client_branch_office, "no pertenece al cliente seleccionado")
    end
  end
end
```

#### Lógica de Negocio

1. **Días de la Semana**: 0=Domingo, 6=Sábado
2. **Sucursal Opcional**: Puede ser general o específico de sucursal
3. **Horarios Anidados**: Cada día tiene múltiples horarios
4. **Único por Día**: No puede haber duplicados día/cliente/sucursal
5. **Validación de Pertenencia**: La sucursal debe pertenecer al cliente

---

### 8. CRD_HR (Horarios)

#### Descripción

Define horarios específicos de servicio para un día.

#### Campos de Base de Datos

```ruby
# Tabla: crd_hrs
create_table "crd_hrs" do |t|
  t.integer  "cr_day_id"             # FK a cr_days
  t.integer  "ttpn_service_id"       # FK a ttpn_services
  t.integer  "ttpn_service_type_id"  # FK a ttpn_service_types
  t.time     "hora_oficial"          # Hora del servicio
  t.boolean  "status"                # Activo/Inactivo
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CrdHr < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :cr_day
  belongs_to :ttpn_service
  belongs_to :ttpn_service_type
  has_many :crdh_routes, dependent: :destroy

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :crdh_routes,
    allow_destroy: true,
    reject_if: proc { |att| att['ruta_nombre'].blank? }

  # === VALIDACIONES ===
  validates :hora_oficial, presence: true
  validates :ttpn_service_id, presence: true
  validates :ttpn_service_type_id, presence: true
  validates :hora_oficial, uniqueness: {
    scope: [:cr_day_id, :ttpn_service_type_id],
    message: "ya está configurada para este día y tipo de servicio"
  }

  # === SCOPES ===
  scope :active, -> { where(status: true) }
  scope :ordered, -> { order(:hora_oficial) }
  scope :for_service, ->(service_id) { where(ttpn_service_id: service_id) }

  # === MÉTODOS ===
  def custom_label_method
    "#{hora_oficial.strftime('%H:%M')} - #{ttpn_service_type.nombre}"
  end

  def time_description
    hora_oficial.strftime('%I:%M %p')
  end

  def full_description
    "#{cr_day.day_name} - #{time_description} - #{ttpn_service.nombre}"
  end
end
```

#### Lógica de Negocio

1. **Hora Específica**: Define la hora exacta del servicio
2. **Tipo de Servicio**: Puede ser entrada, salida, etc.
3. **Rutas Asociadas**: Cada horario puede tener múltiples rutas
4. **Único por Hora/Tipo**: No duplicados en mismo día/hora/tipo
5. **Ordenamiento**: Se ordenan por hora automáticamente

---

### 9. CRDH_ROUTE (Rutas)

#### Descripción

Define rutas específicas para un horario de servicio.

#### Campos de Base de Datos

```ruby
# Tabla: crdh_routes
create_table "crdh_routes" do |t|
  t.integer  "crd_hr_id"             # FK a crd_hrs
  t.string   "ruta_nombre"           # Nombre de la ruta
  t.string   "ruta_clv"              # UUID único
  t.integer  "d_inicio"              # Día inicio (0-6)
  t.time     "hr_inicio"             # Hora inicio
  t.integer  "d_fin"                 # Día fin (0-6)
  t.time     "hr_fin"                # Hora fin
  t.boolean  "status"                # Activo/Inactivo
  t.datetime "created_at"
  t.datetime "updated_at"
end

add_index "crdh_routes", ["ruta_clv"], unique: true
```

#### Modelo Ruby

```ruby
class CrdhRoute < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :crd_hr
  has_many :crdhr_points, dependent: :destroy

  # === NESTED ATTRIBUTES ===
  accepts_nested_attributes_for :crdhr_points,
    allow_destroy: true,
    reject_if: proc { |att| att['clv'].blank? }

  # === VALIDACIONES ===
  validates :ruta_nombre, presence: true
  validates :ruta_clv, uniqueness: true
  validates :d_inicio, inclusion: { in: 0..6 }
  validates :d_fin, inclusion: { in: 0..6 }

  # === CALLBACKS ===
  before_save :generate_clv

  # === SCOPES ===
  scope :active, -> { where(status: true) }
  scope :ordered, -> { order(:ruta_nombre) }

  # === MÉTODOS ===
  def custom_label_method
    ruta_nombre.to_s
  end

  def day_range_description
    if d_inicio == d_fin
      CrDay::DIAS_SEMANA[d_inicio]
    else
      "#{CrDay::DIAS_SEMANA[d_inicio]} - #{CrDay::DIAS_SEMANA[d_fin]}"
    end
  end

  def time_range_description
    "#{hr_inicio.strftime('%H:%M')} - #{hr_fin.strftime('%H:%M')}"
  end

  def full_description
    "#{ruta_nombre} (#{day_range_description}, #{time_range_description})"
  end

  private

  def generate_clv
    self.ruta_clv ||= SecureRandom.uuid
  end
end
```

#### Lógica de Negocio

1. **UUID Automático**: Se genera `ruta_clv` al guardar
2. **Rango de Días**: Puede abarcar varios días
3. **Rango de Horas**: Define inicio y fin del servicio
4. **Puntos Ordenados**: Cada ruta tiene puntos en orden
5. **Identificador Único**: `ruta_clv` es único globalmente

---

### 10. CRDHR_POINT (Puntos de Ruta)

#### Descripción

Define puntos específicos (paradas) en una ruta.

#### Campos de Base de Datos

```ruby
# Tabla: crdhr_points
create_table "crdhr_points" do |t|
  t.integer  "crdh_route_id"         # FK a crdh_routes
  t.string   "clv"                   # Clave del punto
  t.integer  "orden"                 # Orden en la ruta
  t.string   "calle"                 # Dirección
  t.string   "numero"
  t.string   "colonia"
  t.string   "ciudad"
  t.string   "codigo_postal"
  t.float    "lat"                   # Latitud GPS
  t.float    "lng"                   # Longitud GPS
  t.integer  "dia"                   # Día (0-6)
  t.time     "hora"                  # Hora estimada
  t.boolean  "status"                # Activo/Inactivo
  t.boolean  "punto_control"         # Es punto de control?
  t.datetime "created_at"
  t.datetime "updated_at"
end
```

#### Modelo Ruby

```ruby
class CrdhrPoint < ApplicationRecord
  # === ASOCIACIONES ===
  belongs_to :crdh_route

  # === VALIDACIONES ===
  validates :clv, presence: true
  validates :orden, presence: true, numericality: { only_integer: true }
  validates :clv, uniqueness: { scope: :crdh_route_id }
  validates :orden, uniqueness: { scope: :crdh_route_id }
  validates :dia, inclusion: { in: 0..6 }, allow_nil: true

  # === SCOPES ===
  scope :active, -> { where(status: true) }
  scope :ordered, -> { order(:orden) }
  scope :control_points, -> { where(punto_control: true) }

  # === MÉTODOS ===
  def custom_label_method
    clv.to_s
  end

  def full_address
    parts = [calle, numero, colonia, ciudad, codigo_postal].compact
    parts.join(', ')
  end

  def coordinates
    { lat: lat, lng: lng }
  end

  def time_description
    return "Sin hora" unless hora.present?
    hora.strftime('%H:%M')
  end

  def day_name
    return "Sin día" unless dia.present?
    CrDay::DIAS_SEMANA[dia]
  end

  def is_control_point?
    punto_control == true
  end
end
```

#### Lógica de Negocio

1. **Orden Secuencial**: Los puntos se ordenan por `orden`
2. **Coordenadas GPS**: Cada punto tiene lat/lng
3. **Hora Estimada**: Define cuándo se pasa por el punto
4. **Puntos de Control**: Algunos puntos son críticos para tracking
5. **Únicos por Ruta**: CLV y orden son únicos dentro de la ruta

---

## 🔄 Nested Attributes

### Profundidad de Anidamiento

#### Rama 1: Servicios e Incrementos (4 niveles)

```
Client
└── client_ttpn_services_attributes
    ├── cts_increments_attributes
    │   └── cts_increment_details_attributes
    └── cts_driver_increments_attributes
```

#### Rama 2: Sucursales (2 niveles)

```
Client
└── client_branch_offices_attributes
```

#### Rama 3: Rutas (5 niveles - SEPARADO)

```
CrDay
└── crd_hrs_attributes
    └── crdh_routes_attributes
        └── crdhr_points_attributes
```

### Ejemplo Completo de JSON

```json
{
  "client": {
    "clv": "CLI001",
    "razon_social": "Empresa Ejemplo SA de CV",
    "rfc": "EMP010101ABC",
    "calle": "Av. Principal",
    "numero": "123",
    "colonia": "Centro",
    "ciudad": "Chihuahua",
    "estado": "Chihuahua",
    "codigo_postal": 31000,
    "telefono": "6141234567",
    "status": true,
    "business_unit_id": 1,

    "client_branch_offices_attributes": [
      {
        "clv": "SUC001",
        "nombre": "Planta Norte",
        "calle": "Calle Industrial",
        "numero": "456",
        "colonia": "Parque Industrial",
        "ciudad": "Chihuahua",
        "codigo_postal": 31109,
        "lat": 28.6353,
        "lng": -106.0889,
        "status": true
      },
      {
        "clv": "SUC002",
        "nombre": "Planta Sur",
        "calle": "Av. Tecnológico",
        "numero": "789",
        "colonia": "Sur",
        "ciudad": "Chihuahua",
        "codigo_postal": 31200,
        "lat": 28.6,
        "lng": -106.1,
        "status": true
      }
    ],

    "client_ttpn_services_attributes": [
      {
        "ttpn_service_id": 1,
        "status": true,

        "cts_increments_attributes": [
          {
            "fecha_efectiva": "2026-01-01",
            "fecha_hasta": "2026-06-30",

            "cts_increment_details_attributes": [
              {
                "pasajeros_min": 1,
                "pasajeros_max": 5,
                "incremento": 10.0
              },
              {
                "pasajeros_min": 6,
                "pasajeros_max": 10,
                "incremento": 15.0
              },
              {
                "pasajeros_min": 11,
                "pasajeros_max": 14,
                "incremento": 20.0
              }
            ]
          },
          {
            "fecha_efectiva": "2026-07-01",
            "fecha_hasta": "2026-12-31",

            "cts_increment_details_attributes": [
              {
                "pasajeros_min": 1,
                "pasajeros_max": 5,
                "incremento": 12.0
              },
              {
                "pasajeros_min": 6,
                "pasajeros_max": 10,
                "incremento": 18.0
              },
              {
                "pasajeros_min": 11,
                "pasajeros_max": 14,
                "incremento": 25.0
              }
            ]
          }
        ],

        "cts_driver_increments_attributes": [
          {
            "vehicle_type_id": 1,
            "incremento": 50.0,
            "fecha_efectiva": "2026-01-01",
            "fecha_hasta": "2026-12-31",
            "status": true
          },
          {
            "vehicle_type_id": 2,
            "incremento": 75.0,
            "fecha_efectiva": "2026-01-01",
            "fecha_hasta": "2026-12-31",
            "status": true
          },
          {
            "vehicle_type_id": 3,
            "incremento": 100.0,
            "fecha_efectiva": "2026-01-01",
            "fecha_hasta": "2026-12-31",
            "status": true
          }
        ]
      }
    ]
  }
}
```

---

## 💼 Lógica de Negocio

### Cálculo de Precios

#### 1. Precio Base del Servicio

```ruby
def calculate_service_price(service_id, date, passengers, vehicle_type_id)
  # 1. Obtener precio base del servicio
  base_price = TtpnService.find(service_id).base_price

  # 2. Buscar incremento activo para la fecha y cantidad de pasajeros
  client_service = client.client_ttpn_services.find_by(ttpn_service_id: service_id)
  increment_percentage = client_service.active_increment_for_date(date, passengers)
                                       &.increment_for_passengers(passengers) || 0.0

  # 3. Calcular precio con incremento
  service_price = base_price * (1 + increment_percentage / 100.0)

  # 4. Buscar incremento al chofer
  driver_increment = client_service.active_driver_increment_for_date(date, vehicle_type_id)
                                   &.incremento || 0.0

  {
    base_price: base_price,
    increment_percentage: increment_percentage,
    service_price: service_price,
    driver_increment: driver_increment,
    total_cost: service_price + driver_increment
  }
end
```

#### Ejemplo de Cálculo

```ruby
# Datos:
# - Servicio base: $500
# - 7 pasajeros (rango 6-10): +15%
# - Vehículo tipo Sprinter: +$75

result = calculate_service_price(1, Date.today, 7, 2)

# Resultado:
{
  base_price: 500.0,
  increment_percentage: 15.0,
  service_price: 575.0,      # 500 * 1.15
  driver_increment: 75.0,
  total_cost: 650.0          # 575 + 75
}
```

### Validación de Periodos

```ruby
# Validar que no haya traslapes en incrementos
def validate_no_overlapping_increments
  client.client_ttpn_services.each do |service|
    service.cts_increments.each do |inc1|
      service.cts_increments.where.not(id: inc1.id).each do |inc2|
        if periods_overlap?(inc1, inc2)
          raise "Incrementos traslapados: #{inc1.period_description} y #{inc2.period_description}"
        end
      end
    end
  end
end

def periods_overlap?(period1, period2)
  start1 = period1.fecha_efectiva
  end1 = period1.fecha_hasta || Date.today + 100.years
  start2 = period2.fecha_efectiva
  end2 = period2.fecha_hasta || Date.today + 100.years

  start1 <= end2 && end1 >= start2
end
```

### Búsqueda de Rutas Activas

```ruby
# Encontrar rutas activas para un día y hora específicos
def active_routes_for(day_of_week, time, branch_office_id = nil)
  query = cr_days.where(dia_semana: day_of_week, status: true)

  if branch_office_id.present?
    query = query.where(client_branch_office_id: branch_office_id, act_branch: true)
  else
    query = query.where(act_branch: false)
  end

  routes = []
  query.each do |cr_day|
    cr_day.crd_hrs.active.each do |crd_hr|
      if time_matches?(crd_hr.hora_oficial, time)
        routes.concat(crd_hr.crdh_routes.active.to_a)
      end
    end
  end

  routes
end

def time_matches?(official_time, requested_time)
  # Permitir ±15 minutos de tolerancia
  time_diff = (official_time.to_i - requested_time.to_i).abs
  time_diff <= 15.minutes
end
```

---

## 📝 Ejemplos de Uso

### Crear Cliente Completo

```ruby
client = Client.create(
  clv: "CLI001",
  razon_social: "Empresa Ejemplo SA",
  rfc: "EMP010101ABC",
  calle: "Av. Principal",
  numero: "123",
  status: true,
  business_unit_id: 1,
  created_by_id: current_user.id,

  client_branch_offices_attributes: [
    {
      clv: "SUC001",
      nombre: "Planta Norte",
      lat: 28.6353,
      lng: -106.0889,
      status: true
    }
  ],

  client_ttpn_services_attributes: [
    {
      ttpn_service_id: 1,
      status: true,

      cts_increments_attributes: [
        {
          fecha_efectiva: Date.today,
          fecha_hasta: Date.today + 6.months,

          cts_increment_details_attributes: [
            { pasajeros_min: 1, pasajeros_max: 5, incremento: 10.0 },
            { pasajeros_min: 6, pasajeros_max: 10, incremento: 15.0 }
          ]
        }
      ],

      cts_driver_increments_attributes: [
        {
          vehicle_type_id: 1,
          incremento: 50.0,
          fecha_efectiva: Date.today,
          status: true
        }
      ]
    }
  ]
)
```

### Actualizar Cliente

```ruby
client.update(
  razon_social: "Nueva Razón Social",

  client_ttpn_services_attributes: [
    {
      id: existing_service.id,

      cts_increments_attributes: [
        {
          id: existing_increment.id,
          fecha_hasta: Date.today + 1.year,

          cts_increment_details_attributes: [
            {
              id: existing_detail.id,
              incremento: 12.0  # Actualizar incremento
            },
            {
              pasajeros_min: 11,
              pasajeros_max: 14,
              incremento: 20.0  # Agregar nuevo rango
            }
          ]
        }
      ]
    }
  ]
)
```

### Eliminar Nested Attributes

```ruby
client.update(
  client_ttpn_services_attributes: [
    {
      id: service_to_keep.id,

      cts_increments_attributes: [
        {
          id: increment_to_delete.id,
          _destroy: true  # Marcar para eliminar
        }
      ]
    }
  ]
)
```

### Consultas Complejas

```ruby
# Clientes activos con servicios vigentes
Client.active
      .joins(:client_ttpn_services)
      .where(client_ttpn_services: { status: true })
      .distinct

# Incrementos activos para una fecha
CtsIncrement.active_on(Date.today)
            .includes(:cts_increment_details)

# Rutas para un día específico
client.cr_days.for_day(1)  # Lunes
              .active
              .includes(crd_hrs: { crdh_routes: :crdhr_points })
```

---

## 🚀 Plan de Implementación

### Fase 1: Migración y Modelo Base

**Objetivo**: Preparar la base de datos y modelo básico

#### Tareas:

1. ✅ Crear migración para agregar `business_unit_id` a `clients`
2. ✅ Actualizar modelo `Client` con asociación a `business_unit`
3. ✅ Agregar validaciones básicas
4. ✅ Crear scope `by_business_unit`
5. ✅ Ejecutar migración

#### Código:

```ruby
# db/migrate/XXXXXX_add_business_unit_to_clients.rb
class AddBusinessUnitToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :business_unit_id, :integer
    add_index :clients, :business_unit_id
    add_foreign_key :clients, :business_units

    # Establecer business_unit_id = 1 para registros existentes
    reversible do |dir|
      dir.up do
        execute "UPDATE clients SET business_unit_id = 1 WHERE business_unit_id IS NULL"
      end
    end
  end
end
```

### Fase 2: Controller y Serializer Básico

**Objetivo**: CRUD básico sin nested attributes

#### Tareas:

1. ✅ Crear `Api::V1::ClientsController`
2. ✅ Implementar acciones: index, show, create, update, destroy
3. ✅ Crear `ClientSerializer` básico
4. ✅ Agregar filtros (business_unit, status, búsqueda)
5. ✅ Agregar ruta en `routes.rb`

#### Código:

```ruby
# app/controllers/api/v1/clients_controller.rb
module Api
  module V1
    class ClientsController < Api::V1::BaseController
      before_action :set_client, only: [:show, :update, :destroy]

      def index
        @clients = Client.includes(:client_branch_offices, :client_ttpn_services)
                         .by_business_unit(current_user.business_unit_id)

        # Filtros
        @clients = @clients.where(status: params[:status]) if params[:status].present?

        # Búsqueda
        if params[:search].present?
          search = "%#{params[:search]}%"
          @clients = @clients.where(
            "clv ILIKE ? OR razon_social ILIKE ? OR rfc ILIKE ?",
            search, search, search
          )
        end

        render json: @clients.map { |c| ClientSerializer.new(c).as_json }
      end

      def show
        render json: ClientSerializer.new(@client).as_json
      end

      def create
        @client = Client.new(client_params)
        @client.business_unit_id = current_user.business_unit_id
        @client.created_by_id = current_user.id

        if @client.save
          render json: ClientSerializer.new(@client).as_json, status: :created
        else
          render json: { errors: @client.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        @client.updated_by_id = current_user.id

        if @client.update(client_params)
          render json: ClientSerializer.new(@client).as_json
        else
          render json: { errors: @client.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def destroy
        @client.destroy
        head :no_content
      end

      private

      def set_client
        @client = Client.by_business_unit(current_user.business_unit_id)
                        .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Cliente no encontrado' }, status: :not_found
      end

      def client_params
        params.require(:client).permit(
          :clv, :razon_social, :rfc,
          :calle, :numero, :colonia, :ciudad, :estado, :codigo_postal,
          :telefono, :status
        )
      end
    end
  end
end
```

```ruby
# app/serializers/client_serializer.rb
class ClientSerializer
  def initialize(client)
    @client = client
  end

  def as_json
    {
      id: @client.id,
      clv: @client.clv,
      razon_social: @client.razon_social,
      rfc: @client.rfc,
      direccion: {
        calle: @client.calle,
        numero: @client.numero,
        colonia: @client.colonia,
        ciudad: @client.ciudad,
        estado: @client.estado,
        codigo_postal: @client.codigo_postal
      },
      telefono: @client.telefono,
      status: @client.status,
      business_unit_id: @client.business_unit_id,
      created_at: @client.created_at,
      updated_at: @client.updated_at
    }
  end
end
```

### Fase 3: Nested Attributes - Sucursales

**Objetivo**: Permitir crear/editar sucursales junto con el cliente

#### Tareas:

1. ✅ Actualizar `client_params` para incluir `client_branch_offices_attributes`
2. ✅ Actualizar `ClientSerializer` para incluir sucursales
3. ✅ Probar creación/actualización con nested

#### Código:

```ruby
# Actualizar client_params
def client_params
  params.require(:client).permit(
    :clv, :razon_social, :rfc,
    :calle, :numero, :colonia, :ciudad, :estado, :codigo_postal,
    :telefono, :status,
    client_branch_offices_attributes: [
      :id, :clv, :nombre,
      :calle, :colonia, :numero, :ciudad, :codigo_postal,
      :lat, :lng, :status, :_destroy
    ]
  )
end
```

```ruby
# Actualizar ClientSerializer
def as_json
  {
    # ... campos anteriores ...
    branch_offices: @client.client_branch_offices.map do |bo|
      {
        id: bo.id,
        clv: bo.clv,
        nombre: bo.nombre,
        direccion: {
          calle: bo.calle,
          numero: bo.numero,
          colonia: bo.colonia,
          ciudad: bo.ciudad,
          codigo_postal: bo.codigo_postal
        },
        coordinates: {
          lat: bo.lat,
          lng: bo.lng
        },
        gps_uniq: bo.gps_uniq,
        status: bo.status
      }
    end
  }
end
```

### Fase 4: Nested Attributes - Servicios e Incrementos

**Objetivo**: Permitir configurar servicios con incrementos completos

#### Tareas:

1. ✅ Actualizar `client_params` para incluir servicios e incrementos
2. ✅ Crear serializers para servicios e incrementos
3. ✅ Actualizar `ClientSerializer` para incluir servicios
4. ✅ Probar creación completa con 4 niveles de nested

#### Código:

```ruby
# Actualizar client_params
def client_params
  params.require(:client).permit(
    # ... campos anteriores ...
    client_ttpn_services_attributes: [
      :id, :ttpn_service_id, :status, :_destroy,
      cts_increments_attributes: [
        :id, :fecha_efectiva, :fecha_hasta, :_destroy,
        cts_increment_details_attributes: [
          :id, :incremento, :pasajeros_min, :pasajeros_max, :_destroy
        ]
      ],
      cts_driver_increments_attributes: [
        :id, :vehicle_type_id, :incremento,
        :fecha_efectiva, :fecha_hasta, :status, :_destroy
      ]
    ]
  )
end
```

### Fase 5: Frontend - Listado

**Objetivo**: Página de listado de clientes

#### Tareas:

1. ✅ Crear `ClientsPage.vue`
2. ✅ Implementar tabla con búsqueda y filtros
3. ✅ Agregar botones de acciones (editar, eliminar)
4. ✅ Implementar paginación

### Fase 6: Frontend - Formulario

**Objetivo**: Formulario de creación/edición

#### Tareas:

1. ✅ Crear componente de formulario
2. ✅ Implementar secciones (datos básicos, sucursales, servicios)
3. ✅ Implementar nested forms dinámicos
4. ✅ Agregar validaciones

### Fase 7: Frontend - Incrementos Dinámicos

**Objetivo**: UI para configurar incrementos

#### Tareas:

1. ✅ Componente para incrementos al servicio
2. ✅ Componente para detalles por pasajeros
3. ✅ Componente para incrementos al chofer
4. ✅ Validación de periodos y rangos

---

## ✅ Checklist de Implementación

### Backend

- [ ] Migración `business_unit_id`
- [ ] Modelo `Client` actualizado
- [ ] Controller `ClientsController`
- [ ] Serializer `ClientSerializer`
- [ ] Rutas en `routes.rb`
- [ ] Tests unitarios
- [ ] Tests de integración

### Frontend

- [ ] Página `ClientsPage.vue`
- [ ] Componente `ClientForm.vue`
- [ ] Componente `BranchOfficeForm.vue`
- [ ] Componente `ServiceIncrementForm.vue`
- [ ] Componente `DriverIncrementForm.vue`
- [ ] Validaciones
- [ ] Tests E2E

---

## 📌 Notas Importantes

1. **Rutas (CR\_\*)**: Se manejan en endpoints separados, no en el create/update de clients
2. **UUID Automáticos**: `gps_uniq` y `ruta_clv` se generan automáticamente
3. **Validaciones Complejas**: Periodos y rangos no pueden traslaparse
4. **Soft Delete**: Usar `status: false` en lugar de eliminar
5. **Auditoría**: Siempre llenar `created_by_id` y `updated_by_id`
6. **Business Unit**: Filtrado automático por usuario autenticado

---

**Documento creado**: 2026-01-08  
**Versión**: 1.0  
**Autor**: Sistema de Documentación Automática
