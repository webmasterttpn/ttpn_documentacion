# 🏗️ Arquitectura de Microservicios - Visión Futura

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Arquitectura Actual vs Futura](#arquitectura-actual-vs-futura)
3. [Microservicios Propuestos](#microservicios-propuestos)
4. [App de Clientes](#app-de-clientes)
5. [Comunicación entre Servicios](#comunicación-entre-servicios)
6. [Base de Datos](#base-de-datos)
7. [API Gateway](#api-gateway)
8. [Autenticación y Autorización](#autenticación-y-autorización)
9. [Event-Driven Architecture](#event-driven-architecture)
10. [Deployment](#deployment)
11. [Roadmap de Migración](#roadmap-de-migración)

---

## 🎯 Visión General

La evolución hacia microservicios permitirá:

- ✅ **Escalabilidad independiente** de cada servicio
- ✅ **Desarrollo paralelo** por equipos especializados
- ✅ **Despliegue independiente** sin afectar todo el sistema
- ✅ **Tecnologías específicas** para cada problema
- ✅ **Resiliencia** - si un servicio falla, los demás siguen funcionando
- ✅ **Integración de apps externas** (app de clientes, partners, etc.)

---

## 🔄 Arquitectura Actual vs Futura

### Arquitectura Actual (Monolito Modular)

```
┌─────────────────────────────────────────────┐
│           KUMI ADMIN (Monolito)             │
├─────────────────────────────────────────────┤
│  • Gestión de Vehículos                     │
│  • Gestión de Empleados                     │
│  • Gestión de Clientes                      │
│  • Mantenimientos                           │
│  • Facturación                              │
│  • Reservas (TTPN Bookings)                 │
│  • Nóminas                                  │
└─────────────────────────────────────────────┘
              ↓
    ┌─────────────────┐
    │   PostgreSQL    │
    └─────────────────┘
```

### Arquitectura Futura (Microservicios)

```
                    ┌──────────────────┐
                    │   API Gateway    │
                    │  (Kong/Nginx)    │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐  ┌────────▼────────┐  ┌───────▼────────┐
│  Auth Service  │  │  Admin Service  │  │  Client App    │
│   (Devise)     │  │  (Rails API)    │  │  Service       │
└────────────────┘  └─────────────────┘  └────────────────┘
        │                    │                    │
        │           ┌────────┼────────┐          │
        │           │        │        │          │
┌───────▼────────┐ ┌▼──────┐ ┌▼─────┐ ┌▼────────▼────────┐
│ Fleet Service  │ │Billing│ │HR    │ │ Booking Service  │
│  (Vehículos)   │ │Service│ │Svc   │ │  (Reservas)      │
└────────────────┘ └───────┘ └──────┘ └──────────────────┘
        │               │        │              │
        │               │        │              │
┌───────▼────────┐ ┌───▼────┐ ┌▼────┐ ┌────────▼─────────┐
│  Fleet DB      │ │Bill DB │ │HR DB│ │  Booking DB      │
│  (PostgreSQL)  │ │(PG)    │ │(PG) │ │  (PostgreSQL)    │
└────────────────┘ └────────┘ └─────┘ └──────────────────┘

        ┌────────────────────────────┐
        │   Event Bus (RabbitMQ)     │
        │   - VehicleAssigned        │
        │   - BookingCreated         │
        │   - MaintenanceScheduled   │
        └────────────────────────────┘
```

---

## 🎯 Microservicios Propuestos

### 1. **Auth Service** (Autenticación Centralizada)

**Responsabilidad:**

- Autenticación de usuarios (Admin, Clientes, Empleados)
- Generación y validación de JWT tokens
- OAuth2 para integraciones externas
- Gestión de permisos y roles

**Tecnología:**

- Rails + Devise + JWT
- Redis para sesiones

**Base de Datos:**

```sql
users
  - id
  - email
  - encrypted_password
  - user_type (admin, client, employee)
  - company_id
  - active

roles
  - id
  - name
  - permissions (jsonb)

user_roles
  - user_id
  - role_id
```

**Endpoints:**

```
POST   /api/v1/auth/login
POST   /api/v1/auth/logout
POST   /api/v1/auth/refresh
POST   /api/v1/auth/register (solo clientes)
GET    /api/v1/auth/me
POST   /api/v1/auth/forgot-password
POST   /api/v1/auth/reset-password
```

---

### 2. **Admin Service** (Gestión Administrativa)

**Responsabilidad:**

- Dashboard y reportes
- Gestión de empresas y sucursales
- Configuraciones generales
- Usuarios administrativos

**Tecnología:**

- Rails API
- PostgreSQL

**Endpoints:**

```
GET    /api/v1/dashboard/stats
GET    /api/v1/companies
POST   /api/v1/companies
GET    /api/v1/subsidiaries
GET    /api/v1/reports/financial
GET    /api/v1/reports/operations
```

---

### 3. **Fleet Service** (Gestión de Flota)

**Responsabilidad:**

- Gestión de vehículos
- Mantenimientos
- Documentos de vehículos
- Asignación de vehículos

**Tecnología:**

- Rails API
- PostgreSQL
- S3 para documentos

**Base de Datos:**

```sql
vehicles
  - id
  - plates
  - brand
  - model
  - year
  - vehicle_type_id
  - company_id
  - status (available, in_use, maintenance)

maintenances
  - id
  - vehicle_id
  - date
  - type
  - cost
  - description

vehicle_documents
  - id
  - vehicle_id
  - document_type
  - file_url
  - expiration_date
```

**Endpoints:**

```
GET    /api/v1/vehicles
POST   /api/v1/vehicles
GET    /api/v1/vehicles/:id
PATCH  /api/v1/vehicles/:id
GET    /api/v1/vehicles/:id/maintenances
POST   /api/v1/vehicles/:id/maintenances
GET    /api/v1/vehicles/available (para reservas)
```

**Eventos Publicados:**

```
VehicleCreated
VehicleUpdated
VehicleAssigned
VehicleAvailable
MaintenanceScheduled
MaintenanceCompleted
```

---

### 4. **Booking Service** (Reservas y Viajes)

**Responsabilidad:**

- Solicitudes de viaje de clientes
- Asignación de vehículos y conductores
- Tracking de viajes en tiempo real
- Historial de viajes

**Tecnología:**

- Rails API o Node.js (para real-time)
- PostgreSQL
- Redis para tracking en tiempo real
- WebSockets para notificaciones

**Base de Datos:**

```sql
bookings
  - id
  - client_id
  - origin
  - destination
  - pickup_date
  - pickup_time
  - passengers
  - status (pending, confirmed, in_progress, completed, cancelled)
  - vehicle_id
  - driver_id
  - estimated_cost
  - final_cost

trip_tracking
  - id
  - booking_id
  - latitude
  - longitude
  - timestamp
  - status

booking_passengers
  - id
  - booking_id
  - name
  - phone
```

**Endpoints:**

**Para Clientes (App Móvil):**

```
POST   /api/v1/bookings (crear solicitud)
GET    /api/v1/bookings (mis viajes)
GET    /api/v1/bookings/:id
PATCH  /api/v1/bookings/:id/cancel
GET    /api/v1/bookings/:id/tracking (real-time)
POST   /api/v1/bookings/:id/rate
GET    /api/v1/bookings/estimate (cotización)
```

**Para Admin:**

```
GET    /api/v1/admin/bookings
PATCH  /api/v1/admin/bookings/:id/assign
PATCH  /api/v1/admin/bookings/:id/confirm
GET    /api/v1/admin/bookings/pending
```

**Eventos Publicados:**

```
BookingCreated
BookingConfirmed
BookingAssigned
TripStarted
TripCompleted
BookingCancelled
```

**Eventos Consumidos:**

```
VehicleAvailable (de Fleet Service)
DriverAvailable (de HR Service)
```

---

### 5. **HR Service** (Recursos Humanos)

**Responsabilidad:**

- Gestión de empleados
- Conductores
- Nóminas
- Vacaciones e incidencias

**Tecnología:**

- Rails API
- PostgreSQL

**Base de Datos:**

```sql
employees
  - id
  - name
  - email
  - phone
  - position
  - company_id
  - driver_license
  - status (available, assigned, off_duty)

payrolls
  - id
  - employee_id
  - period_start
  - period_end
  - gross_salary
  - deductions
  - net_salary

driver_assignments
  - id
  - driver_id
  - vehicle_id
  - booking_id
  - start_time
  - end_time
```

**Endpoints:**

```
GET    /api/v1/employees
POST   /api/v1/employees
GET    /api/v1/drivers/available
POST   /api/v1/drivers/:id/assign
GET    /api/v1/payrolls
POST   /api/v1/payrolls/generate
```

**Eventos Publicados:**

```
DriverAvailable
DriverAssigned
DriverOffDuty
```

---

### 6. **Billing Service** (Facturación)

**Responsabilidad:**

- Facturación de viajes
- Cuentas por cobrar
- Cuentas por pagar
- Reportes financieros

**Tecnología:**

- Rails API
- PostgreSQL

**Base de Datos:**

```sql
invoices
  - id
  - booking_id
  - client_id
  - amount
  - tax
  - total
  - status (pending, paid, overdue)
  - due_date

payments
  - id
  - invoice_id
  - amount
  - payment_method
  - transaction_id
  - paid_at

accounts_receivable
  - id
  - client_id
  - amount
  - due_date
  - status
```

**Endpoints:**

```
GET    /api/v1/invoices
POST   /api/v1/invoices
GET    /api/v1/invoices/:id
POST   /api/v1/invoices/:id/pay
GET    /api/v1/accounts-receivable
GET    /api/v1/accounts-payable
```

**Eventos Consumidos:**

```
TripCompleted (genera factura automáticamente)
```

---

### 7. **Notification Service** (Notificaciones)

**Responsabilidad:**

- Notificaciones push (FCM)
- Emails
- SMS
- Notificaciones in-app

**Tecnología:**

- Node.js (para performance)
- Redis para queue
- Firebase Cloud Messaging
- SendGrid para emails

**Endpoints:**

```
POST   /api/v1/notifications/send
GET    /api/v1/notifications (usuario actual)
PATCH  /api/v1/notifications/:id/read
```

**Eventos Consumidos:**

```
BookingCreated → Notificar admin
BookingConfirmed → Notificar cliente
TripStarted → Notificar cliente
TripCompleted → Notificar cliente y admin
MaintenanceScheduled → Notificar admin
```

---

## 📱 App de Clientes (Nueva Aplicación)

### Características Principales

**Para Clientes Finales:**

1. **Solicitud de Viajes:**

   - Seleccionar origen y destino (mapa)
   - Fecha y hora de recogida
   - Número de pasajeros
   - Tipo de vehículo
   - Cotización instantánea

2. **Tracking en Tiempo Real:**

   - Ver ubicación del vehículo asignado
   - ETA (tiempo estimado de llegada)
   - Información del conductor
   - Chat con conductor

3. **Historial:**

   - Viajes pasados
   - Facturas
   - Calificaciones

4. **Perfil:**
   - Datos personales
   - Métodos de pago
   - Direcciones favoritas

### Stack Tecnológico Propuesto

**Opción 1: PWA con Quasar (Multiplataforma)**

```
Frontend: Quasar (Vue 3)
Maps: Google Maps API / Mapbox
Real-time: WebSockets / Socket.io
Push: Firebase Cloud Messaging
State: Pinia
```

**Opción 2: Apps Nativas**

```
iOS: Swift + SwiftUI
Android: Kotlin + Jetpack Compose
Backend: Mismo API Gateway
```

### Flujo de Solicitud de Viaje

```
1. Cliente abre app
   ↓
2. Selecciona origen/destino en mapa
   ↓
3. App llama a Booking Service:
   POST /api/v1/bookings/estimate
   ↓
4. Muestra cotización al cliente
   ↓
5. Cliente confirma
   ↓
6. App crea booking:
   POST /api/v1/bookings
   ↓
7. Booking Service publica evento:
   BookingCreated
   ↓
8. Admin recibe notificación
   ↓
9. Admin asigna vehículo y conductor
   PATCH /api/v1/admin/bookings/:id/assign
   ↓
10. Booking Service publica:
    BookingAssigned
    ↓
11. Cliente recibe notificación push
    ↓
12. App muestra tracking en tiempo real
    WebSocket: /bookings/:id/tracking
    ↓
13. Conductor inicia viaje
    ↓
14. Cliente ve progreso en mapa
    ↓
15. Viaje completa
    ↓
16. Billing Service genera factura
    ↓
17. Cliente califica servicio
```

---

## 🔗 Comunicación entre Servicios

### Patrones de Comunicación

#### 1. **Síncrona (REST API)**

Para operaciones que requieren respuesta inmediata:

```
Client App → API Gateway → Booking Service
                         ↓
                    Fleet Service (verificar disponibilidad)
```

**Ejemplo:**

```javascript
// Cliente solicita cotización
POST /api/v1/bookings/estimate
{
  "origin": "lat,lng",
  "destination": "lat,lng",
  "pickup_date": "2025-01-20",
  "passengers": 4
}

// Booking Service llama a Fleet Service
GET /api/v1/vehicles/available?date=2025-01-20&passengers=4

// Respuesta al cliente
{
  "estimated_cost": 1500,
  "available_vehicles": 5,
  "estimated_duration": "2h 30m"
}
```

#### 2. **Asíncrona (Event-Driven)**

Para operaciones que no requieren respuesta inmediata:

```
Booking Service → RabbitMQ → Notification Service
                           → Billing Service
                           → Admin Service
```

**Ejemplo:**

```ruby
# Booking Service publica evento
class BookingCreatedEvent
  def initialize(booking)
    @booking = booking
  end

  def publish
    EventBus.publish('booking.created', {
      booking_id: @booking.id,
      client_id: @booking.client_id,
      pickup_date: @booking.pickup_date,
      origin: @booking.origin,
      destination: @booking.destination
    })
  end
end

# Notification Service escucha
EventBus.subscribe('booking.created') do |data|
  NotifyAdminWorker.perform_async(data[:booking_id])
  NotifyClientWorker.perform_async(data[:client_id], 'booking_confirmed')
end

# Billing Service escucha
EventBus.subscribe('trip.completed') do |data|
  GenerateInvoiceWorker.perform_async(data[:booking_id])
end
```

---

## 🗄️ Estrategia de Base de Datos

### Opción 1: Database per Service (Recomendado)

Cada microservicio tiene su propia base de datos:

```
Fleet Service → fleet_db (PostgreSQL)
Booking Service → booking_db (PostgreSQL)
HR Service → hr_db (PostgreSQL)
Billing Service → billing_db (PostgreSQL)
Auth Service → auth_db (PostgreSQL)
```

**Ventajas:**

- ✅ Independencia total
- ✅ Escalabilidad individual
- ✅ Tecnología específica por servicio

**Desafíos:**

- ⚠️ Joins entre servicios no posibles
- ⚠️ Transacciones distribuidas
- ⚠️ Consistencia eventual

**Solución:**

- Usar eventos para sincronización
- Implementar Saga pattern para transacciones distribuidas

### Opción 2: Shared Database (Transición)

Durante la migración, compartir DB pero con schemas separados:

```
PostgreSQL
  ├── schema: fleet
  ├── schema: booking
  ├── schema: hr
  └── schema: billing
```

---

## 🚪 API Gateway

### Responsabilidades

1. **Routing:** Dirigir requests al servicio correcto
2. **Authentication:** Validar JWT tokens
3. **Rate Limiting:** Prevenir abuso
4. **Load Balancing:** Distribuir carga
5. **Logging:** Centralizar logs
6. **CORS:** Manejar políticas de origen

### Configuración Ejemplo (Kong)

```yaml
services:
  - name: booking-service
    url: http://booking-service:3001
    routes:
      - name: bookings
        paths:
          - /api/v1/bookings
        methods:
          - GET
          - POST
          - PATCH
    plugins:
      - name: jwt
      - name: rate-limiting
        config:
          minute: 100

  - name: fleet-service
    url: http://fleet-service:3002
    routes:
      - name: vehicles
        paths:
          - /api/v1/vehicles
    plugins:
      - name: jwt
```

---

## 🔐 Autenticación Multi-Servicio

### JWT con Claims Específicos

```json
{
  "user_id": 123,
  "email": "cliente@example.com",
  "user_type": "client",
  "company_id": 5,
  "roles": ["client"],
  "permissions": ["booking:create", "booking:read"],
  "exp": 1640000000
}
```

### Validación en cada Servicio

```ruby
# lib/jwt_validator.rb
class JwtValidator
  def self.validate(token)
    decoded = JWT.decode(token, ENV['JWT_SECRET'])[0]
    User.new(decoded)
  rescue JWT::DecodeError
    nil
  end
end

# En cada controlador
class BookingsController < ApplicationController
  before_action :authenticate_user!

  def create
    # current_user está disponible
    @booking = Booking.new(booking_params.merge(client_id: current_user.id))
    # ...
  end
end
```

---

## 📡 Event-Driven Architecture

### Event Bus con RabbitMQ

```
┌──────────────────┐
│ Booking Service  │
└────────┬─────────┘
         │ publish: booking.created
         ↓
┌────────────────────────┐
│      RabbitMQ          │
│  Exchange: events      │
└───┬────────┬───────┬───┘
    │        │       │
    │        │       └─→ Billing Service (subscribe)
    │        └─────────→ Notification Service (subscribe)
    └──────────────────→ Admin Service (subscribe)
```

### Implementación

```ruby
# config/initializers/event_bus.rb
class EventBus
  def self.connection
    @connection ||= Bunny.new(ENV['RABBITMQ_URL']).tap(&:start)
  end

  def self.channel
    @channel ||= connection.create_channel
  end

  def self.exchange
    @exchange ||= channel.topic('events', durable: true)
  end

  def self.publish(event_name, data)
    exchange.publish(
      data.to_json,
      routing_key: event_name,
      persistent: true
    )
  end

  def self.subscribe(event_pattern, &block)
    queue = channel.queue('', exclusive: true)
    queue.bind(exchange, routing_key: event_pattern)

    queue.subscribe(block: true) do |_delivery_info, _properties, body|
      data = JSON.parse(body, symbolize_names: true)
      block.call(data)
    end
  end
end

# Uso en Booking Service
class Booking < ApplicationRecord
  after_create :publish_created_event

  private

  def publish_created_event
    EventBus.publish('booking.created', {
      id: id,
      client_id: client_id,
      origin: origin,
      destination: destination,
      pickup_date: pickup_date
    })
  end
end

# Uso en Notification Service
# config/initializers/event_subscribers.rb
Thread.new do
  EventBus.subscribe('booking.*') do |data|
    case data[:event_type]
    when 'created'
      NotifyAdminWorker.perform_async(data[:id])
    when 'confirmed'
      NotifyClientWorker.perform_async(data[:client_id])
    end
  end
end
```

---

## 🚀 Deployment

### Arquitectura en la Nube

```
                    ┌──────────────┐
                    │   Cloudflare │
                    │   (CDN/WAF)  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  API Gateway │
                    │   (Railway)  │
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│ Auth Service   │ │ Booking Svc    │ │ Fleet Service  │
│  (Railway)     │ │  (Railway)     │ │  (Railway)     │
└────────────────┘ └────────────────┘ └────────────────┘
        │                  │                  │
        │                  │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│  Auth DB       │ │  Booking DB    │ │  Fleet DB      │
│  (Supabase)    │ │  (Supabase)    │ │  (Supabase)    │
└────────────────┘ └────────────────┘ └────────────────┘

        ┌────────────────────────────┐
        │   RabbitMQ (CloudAMQP)     │
        └────────────────────────────┘

        ┌────────────────────────────┐
        │   Redis (Upstash)          │
        └────────────────────────────┘
```

### Costos Estimados (Mensual)

```
Railway (5 servicios × $5)    = $25
Supabase (5 DBs × $25)        = $125
CloudAMQP (RabbitMQ)          = $19
Upstash (Redis)               = $10
Cloudflare (CDN)              = $20
Netlify (Frontend)            = $0 (free tier)
                        Total ≈ $199/mes
```

---

## 🗺️ Roadmap de Migración

### Fase 1: Preparación (Actual)

- ✅ Monolito modular con API REST
- ✅ Separación de concerns (Services, Controllers)
- ✅ Event-driven con Sidekiq
- ⏳ Tests completos
- ⏳ Documentación API

### Fase 2: Extracción de Auth Service (3-4 semanas)

1. Crear Auth Service independiente
2. Migrar autenticación a JWT
3. Implementar OAuth2
4. Migrar usuarios y roles
5. Actualizar todos los servicios para usar Auth Service

### Fase 3: Extracción de Booking Service (4-6 semanas)

1. Crear Booking Service
2. Migrar tablas de bookings
3. Implementar API para clientes
4. Desarrollar App de Clientes (PWA)
5. Implementar tracking en tiempo real
6. Integrar con Fleet Service

### Fase 4: Extracción de Fleet Service (3-4 semanas)

1. Crear Fleet Service
2. Migrar vehículos y mantenimientos
3. Implementar eventos (VehicleAvailable, etc.)
4. Integrar con Booking Service

### Fase 5: Extracción de HR Service (2-3 semanas)

1. Crear HR Service
2. Migrar empleados y conductores
3. Implementar asignación de conductores
4. Integrar con Booking Service

### Fase 6: Extracción de Billing Service (3-4 semanas)

1. Crear Billing Service
2. Migrar facturación
3. Implementar generación automática de facturas
4. Integrar con Booking Service

### Fase 7: Notification Service (2 semanas)

1. Crear Notification Service
2. Implementar FCM, Email, SMS
3. Suscribirse a todos los eventos

### Fase 8: API Gateway (1-2 semanas)

1. Configurar Kong/Nginx
2. Implementar routing
3. Configurar rate limiting
4. Centralizar autenticación

---

## 📊 Métricas de Éxito

### KPIs Técnicos

- **Uptime:** > 99.9% por servicio
- **Response Time:** < 200ms (P95)
- **Error Rate:** < 0.1%
- **Deploy Frequency:** Múltiples veces por día
- **MTTR:** < 1 hora

### KPIs de Negocio

- **Bookings por día:** Escalable sin límite
- **Tiempo de asignación:** < 5 minutos
- **Satisfacción del cliente:** > 4.5/5
- **Costo por transacción:** Reducción del 30%

---

## 🎯 Conclusión

Esta arquitectura de microservicios permitirá:

1. **Escalar** cada componente independientemente
2. **Desarrollar** la app de clientes sin afectar el admin
3. **Integrar** nuevos servicios fácilmente
4. **Mantener** y actualizar cada servicio de forma independiente
5. **Desplegar** cambios sin downtime

**La clave es migrar gradualmente**, extrayendo un servicio a la vez, validando que funciona correctamente antes de continuar con el siguiente.

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0  
**Estado:** Documento de Visión Futura
