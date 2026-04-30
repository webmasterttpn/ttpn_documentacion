# 📋 Organización de Menús - Frontend vs Configuración

## 🎯 Objetivo

Separar los módulos operativos (menú principal) de los catálogos/diccionarios (configuración) para mantener el menú limpio y enfocado.

---

## 📱 MENÚ PRINCIPAL (Operativo - Usuarios Finales)

### 1. Dashboard

- **Ruta:** `/dashboard`
- **Componente:** `DashboardPage.vue`
- **Descripción:** Vista general, KPIs, gráficas

### 2. Clientes

- **Ruta:** `/clients`
- **Componente:** `ClientsPage.vue`
- **Incluye:**
  - Clientes (CRUD)
  - Sucursales (client_branch_offices)
  - Contactos (client_contacts)
  - Servicios TTPN (client_ttpn_services)

### 3. Empleados

- **Ruta:** `/employees`
- **Componente:** `EmployeesPage.vue`
- **Incluye:**
  - Empleados (CRUD)
  - Documentos de empleados
  - Salarios
  - Movimientos
  - Vacaciones
  - Incidencias

### 4. Proveedores

- **Ruta:** `/suppliers`
- **Componente:** `SuppliersPage.vue`
- **Incluye:**
  - Proveedores (CRUD)

### 5. Vehículos

- **Ruta:** `/vehicles`
- **Componente:** `VehiclesPage.vue`
- **Incluye:**
  - Flotilla (CRUD)
  - Documentos de vehículos
  - Asignaciones
  - Mantenimientos
  - Verificaciones

### 6. Combustible

- **Ruta:** `/fuel`
- **Componente:** `FuelPage.vue`
- **Incluye:**
  - Cargas de gasolina
  - Archivos de gas
  - Estaciones de servicio

### 7. Nómina TTPN

- **Ruta:** `/payroll`
- **Componente:** `PayrollPage.vue`
- **Incluye:**
  - Nóminas
  - Cálculos

### 8. Servicios TTPN

- **Ruta:** `/services`
- **Componente:** `ServicesPage.vue`
- **Incluye:**
  - Servicios
  - Reservaciones (bookings)
  - Pasajeros
  - Precios

### 9. Navegación

- **Ruta:** `/navigation`
- **Componente:** `NavigationPage.vue`
- **Incluye:**
  - Rutas
  - Puntos de revisión
  - Días de ruta

### 10. Facturación TTPN

- **Ruta:** `/invoicing`
- **Componente:** `InvoicingPage.vue`
- **Incluye:**
  - Facturas
  - Tipos de factura

---

## ⚙️ CONFIGURACIÓN (Catálogos/Diccionarios - Solo Admin)

### Organización

- **Business Units** (Unidades de Negocio) ✅ YA IMPLEMENTADO
- **Users & Roles** (Usuarios y Roles) ✅ YA IMPLEMENTADO

### Catálogos de Empleados

- **Employee Document Types** (Tipos de Documentos de Empleado)
- **Employee Movement Types** (Tipos de Movimientos)
- **Labors** (Puestos/Labores)
- **Drivers Levels** (Niveles de Conductor)

### Catálogos de Vehículos

- **Vehicle Types** (Tipos de Vehículos) ✅ YA EXISTE
- **Vehicle Document Types** (Tipos de Documentos de Vehículo) ✅ YA EXISTE
- **Concessionaires** (Concesionarias)

### Catálogos de Servicios

- **TTPN Service Types** (Tipos de Servicios TTPN)
- **TTPN Foreign Destinies** (Destinos Foráneos)

### Catálogos de Combustible

- **Gas Stations** (Estaciones de Servicio)

### Integraciones

- **API Access** (Acceso a API) ✅ YA IMPLEMENTADO

---

## 📊 Estructura del Menú Frontend

### MainLayout.vue - Menú Lateral

```vue
<q-list>
  <!-- Dashboard -->
  <q-item to="/dashboard" icon="dashboard">
    <q-item-section>Dashboard</q-item-section>
  </q-item>

  <!-- Clientes -->
  <q-expansion-item icon="people" label="Clientes">
    <q-item to="/clients">Clientes</q-item>
    <q-item to="/clients/branches">Sucursales</q-item>
  </q-expansion-item>

  <!-- Empleados -->
  <q-expansion-item icon="badge" label="Empleados">
    <q-item to="/employees">Empleados</q-item>
    <q-item to="/employees/vacations">Vacaciones</q-item>
    <q-item to="/employees/incidences">Incidencias</q-item>
  </q-expansion-item>

  <!-- Proveedores -->
  <q-item to="/suppliers" icon="local_shipping">
    <q-item-section>Proveedores</q-item-section>
  </q-item>

  <!-- Vehículos -->
  <q-expansion-item icon="directions_car" label="Vehículos">
    <q-item to="/vehicles">Flotilla</q-item>
    <q-item to="/vehicles/maintenance">Mantenimientos</q-item>
    <q-item to="/vehicles/assignments">Asignaciones</q-item>
  </q-expansion-item>

  <!-- Combustible -->
  <q-expansion-item icon="local_gas_station" label="Combustible">
    <q-item to="/fuel/charges">Cargas</q-item>
    <q-item to="/fuel/files">Archivos</q-item>
  </q-expansion-item>

  <!-- Nómina TTPN -->
  <q-item to="/payroll" icon="payments">
    <q-item-section>Nómina TTPN</q-item-section>
  </q-item>

  <!-- Servicios TTPN -->
  <q-expansion-item icon="airport_shuttle" label="Servicios TTPN">
    <q-item to="/services">Servicios</q-item>
    <q-item to="/services/bookings">Reservaciones</q-item>
  </q-expansion-item>

  <!-- Navegación -->
  <q-item to="/navigation" icon="navigation">
    <q-item-section>Navegación</q-item-section>
  </q-item>

  <!-- Facturación TTPN -->
  <q-item to="/invoicing" icon="receipt_long">
    <q-item-section>Facturación TTPN</q-item-section>
  </q-item>

  <q-separator />

  <!-- Configuración -->
  <q-item to="/settings" icon="settings">
    <q-item-section>Configuración</q-item-section>
  </q-item>
</q-list>
```

### SettingsPage.vue - Tabs de Configuración

```vue
<q-tabs>
  <!-- ORGANIZACIÓN -->
  <q-item-label header>Organización</q-item-label>
  <q-tab name="general" label="General" />
  <q-tab name="users" label="Usuarios y Roles" />
  <q-tab name="business_units" label="Unidades de Negocio" />

  <!-- CATÁLOGOS -->
  <q-item-label header>Catálogos</q-item-label>
  
  <!-- Empleados -->
  <q-tab name="employee_doc_types" label="Docs de Empleados" />
  <q-tab name="employee_movement_types" label="Tipos de Movimientos" />
  <q-tab name="labors" label="Puestos" />
  <q-tab name="drivers_levels" label="Niveles de Conductor" />
  
  <!-- Vehículos -->
  <q-tab name="vehicle_types" label="Tipos de Vehículos" />
  <q-tab name="vehicle_doc_types" label="Docs de Vehículos" />
  <q-tab name="concessionaires" label="Concesionarias" />
  
  <!-- Servicios -->
  <q-tab name="service_types" label="Tipos de Servicios" />
  <q-tab name="foreign_destinies" label="Destinos Foráneos" />
  
  <!-- Combustible -->
  <q-tab name="gas_stations" label="Estaciones de Servicio" />

  <!-- INTEGRACIONES -->
  <q-item-label header>Integraciones</q-item-label>
  <q-tab name="api_access" label="Acceso a API" />
</q-tabs>
```

---

## 🎯 Plan de Implementación

### Fase 1: Catálogos Críticos (1-2 días)

- [ ] Employee Document Types
- [ ] Employee Movement Types
- [ ] Labors (Puestos)
- [ ] Drivers Levels

### Fase 2: Catálogos de Vehículos (1 día)

- [ ] Concessionaires
- [ ] (Vehicle Types y Vehicle Doc Types ya existen)

### Fase 3: Catálogos de Servicios (1 día)

- [ ] TTPN Service Types
- [ ] Foreign Destinies

### Fase 4: Otros Catálogos (1 día)

- [ ] Gas Stations
- [ ] Invoice Types

---

## 📋 Patrón de Implementación de Catálogos

Cada catálogo sigue el mismo patrón simple:

### Backend

```ruby
# app/controllers/api/v1/labors_controller.rb
class Api::V1::LaborsController < Api::V1::BaseController
  def index
    @labors = Labor.all.order(:nombre)
    render json: @labors
  end

  def create
    @labor = Labor.new(labor_params)
    if @labor.save
      render json: @labor, status: :created
    else
      render json: { errors: @labor.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # ... update, destroy
end
```

### Frontend (Componente Reutilizable)

```vue
<!-- src/components/CatalogManager.vue -->
<template>
  <div>
    <q-table :rows="items" :columns="columns" :grid="$q.screen.lt.md">
      <!-- CRUD básico -->
    </q-table>
  </div>
</template>
```

---

## ✅ Resumen de Decisiones

### Menú Principal (10 secciones)

1. Dashboard
2. Clientes
3. Empleados
4. Proveedores
5. Vehículos
6. Combustible
7. Nómina TTPN
8. Servicios TTPN
9. Navegación
10. Facturación TTPN

### Configuración (15+ catálogos)

- Organización (3)
- Catálogos de Empleados (4)
- Catálogos de Vehículos (3)
- Catálogos de Servicios (2)
- Catálogos de Combustible (1)
- Integraciones (1)

### Ventajas

- ✅ Menú principal limpio y enfocado
- ✅ Catálogos organizados en Settings
- ✅ Solo admins ven configuración
- ✅ Fácil de mantener y extender

---

**Próximo Paso:** ¿Empezamos con los catálogos de Empleados o prefieres primero terminar el CRUD de Empleados?
