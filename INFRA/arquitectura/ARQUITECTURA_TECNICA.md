# 🏗️ Arquitectura Técnica - Kumi TTPN Admin V2

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Arquitectura de Alto Nivel](#arquitectura-de-alto-nivel)
3. [Backend (Rails API)](#backend-rails-api)
4. [Frontend (Quasar PWA)](#frontend-quasar-pwa)
5. [Base de Datos](#base-de-datos)
6. [Autenticación y Autorización](#autenticación-y-autorización)
7. [Jobs en Background](#jobs-en-background)
8. [Caching](#caching)
9. [Deployment](#deployment)
10. [Seguridad](#seguridad)
11. [Performance](#performance)
12. [Monitoreo](#monitoreo)

---

## 🎯 Visión General

Kumi TTPN Admin V2 es una aplicación full-stack moderna diseñada para la gestión de servicios de transporte y logística. La arquitectura sigue el patrón de **API-first** con separación clara entre backend y frontend.

### Principios de Diseño

- **API-First:** El backend expone una API REST que puede ser consumida por múltiples clientes
- **Microservicios Ready:** Arquitectura preparada para evolucionar a microservicios
- **PWA:** Frontend como Progressive Web App para soporte multiplataforma
- **Stateless:** API sin estado para escalabilidad horizontal
- **Event-Driven:** Jobs asíncronos para operaciones pesadas

---

## 🏛️ Arquitectura de Alto Nivel

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTES                              │
├─────────────────────────────────────────────────────────────┤
│  PWA (Quasar)  │  Mobile App  │  Third-party Apps           │
└────────┬────────────────┬─────────────────┬─────────────────┘
         │                │                 │
         └────────────────┴─────────────────┘
                          │
                    ┌─────▼─────┐
                    │   NGINX   │ (Producción)
                    │  Reverse  │
                    │   Proxy   │
                    └─────┬─────┘
                          │
         ┌────────────────┴────────────────┐
         │                                 │
    ┌────▼─────┐                    ┌─────▼────┐
    │  Rails   │                    │  Quasar  │
    │   API    │                    │   PWA    │
    │  :3000   │                    │  :9000   │
    └────┬─────┘                    └──────────┘
         │
    ┌────▼─────────────────────────┐
    │    Application Layer         │
    ├──────────────────────────────┤
    │  Controllers │ Services      │
    │  Serializers │ Workers       │
    └────┬─────────────────────────┘
         │
    ┌────▼─────────────────────────┐
    │     Data Layer               │
    ├──────────────────────────────┤
    │  PostgreSQL │ Redis          │
    │  (Primary)  │ (Cache/Queue)  │
    └──────────────────────────────┘
         │
    ┌────▼─────────────────────────┐
    │   External Services          │
    ├──────────────────────────────┤
    │  AWS S3  │ FCM  │ Email      │
    └──────────────────────────────┘
```

---

## 🔴 Backend (Rails API)

### Estructura de Capas

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│  (Controllers, Serializers)         │
├─────────────────────────────────────┤
│         Business Logic Layer        │
│  (Services, Concerns, Validators)   │
├─────────────────────────────────────┤
│         Data Access Layer           │
│  (Models, Repositories)             │
├─────────────────────────────────────┤
│         Infrastructure Layer        │
│  (Database, Cache, External APIs)   │
└─────────────────────────────────────┘
```

### Componentes Principales

#### 1. Controllers (Presentation Layer)

**Responsabilidades:**

- Recibir requests HTTP
- Validar parámetros
- Delegar lógica de negocio a Services
- Retornar respuestas JSON

**Ejemplo:**

```ruby
module Api
  module V1
    class VehiclesController < Api::V1::BaseController
      before_action :authenticate_user!
      before_action :set_vehicle, only: [:show, :update, :destroy]

      def index
        @vehicles = Vehicle.accessible_by(current_ability)
                          .includes(:vehicle_type, :company)
                          .page(params[:page])

        render json: @vehicles, each_serializer: VehicleSerializer
      end

      def create
        result = Vehicles::CreateService.new(
          vehicle_params,
          current_user
        ).call

        if result.success?
          render json: result.data, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def vehicle_params
        params.require(:vehicle).permit(
          :plates, :brand, :model, :year, :vehicle_type_id
        )
      end
    end
  end
end
```

#### 2. Services (Business Logic Layer)

**Responsabilidades:**

- Encapsular lógica de negocio compleja
- Coordinar múltiples modelos
- Manejar transacciones
- Interactuar con servicios externos

**Patrón de Service Object:**

```ruby
module Vehicles
  class CreateService
    def initialize(params, current_user)
      @params = params
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        vehicle = create_vehicle
        assign_to_company(vehicle)
        schedule_maintenance(vehicle)
        notify_admin(vehicle)

        ServiceResult.success(vehicle)
      end
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(e.record.errors)
    rescue StandardError => e
      Rails.logger.error("Vehicle creation failed: #{e.message}")
      ServiceResult.failure(['Error creating vehicle'])
    end

    private

    def create_vehicle
      Vehicle.create!(@params.merge(created_by: @current_user))
    end

    def assign_to_company(vehicle)
      vehicle.update!(company_id: @current_user.company_id)
    end

    def schedule_maintenance(vehicle)
      Maintenances::ScheduleJob.perform_later(vehicle.id)
    end

    def notify_admin(vehicle)
      AdminMailer.new_vehicle(vehicle).deliver_later
    end
  end
end
```

#### 3. Models (Data Access Layer)

**Responsabilidades:**

- Validaciones de datos
- Asociaciones entre modelos
- Scopes y queries
- Callbacks (usar con moderación)

**Ejemplo:**

```ruby
class Vehicle < ApplicationRecord
  # Associations
  belongs_to :vehicle_type
  belongs_to :company
  has_many :maintenances, dependent: :destroy
  has_many :vehicle_documents, dependent: :destroy

  # Validations
  validates :plates, presence: true, uniqueness: { case_sensitive: false }
  validates :brand, :model, :year, presence: true
  validates :year, numericality: {
    only_integer: true,
    greater_than: 1900,
    less_than_or_equal_to: -> { Date.current.year + 1 }
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_company, ->(company_id) { where(company_id: company_id) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_save :normalize_plates
  after_create :create_initial_documents

  # Instance methods
  def full_name
    "#{brand} #{model} (#{year})"
  end

  def needs_maintenance?
    last_maintenance = maintenances.order(date: :desc).first
    return true if last_maintenance.nil?

    last_maintenance.date < 6.months.ago
  end

  private

  def normalize_plates
    self.plates = plates.upcase.strip
  end

  def create_initial_documents
    VehicleDocumentType.all.each do |doc_type|
      vehicle_documents.create!(document_type: doc_type)
    end
  end
end
```

#### 4. Serializers

**Responsabilidades:**

- Formatear datos para respuestas JSON
- Incluir/excluir campos según contexto
- Manejar relaciones anidadas

**Ejemplo:**

```ruby
class VehicleSerializer
  def initialize(vehicle, options = {})
    @vehicle = vehicle
    @options = options
  end

  def as_json
    {
      id: @vehicle.id,
      plates: @vehicle.plates,
      brand: @vehicle.brand,
      model: @vehicle.model,
      year: @vehicle.year,
      full_name: @vehicle.full_name,
      active: @vehicle.active,
      vehicle_type: vehicle_type_data,
      company: company_data,
      maintenances_count: @vehicle.maintenances.count,
      needs_maintenance: @vehicle.needs_maintenance?,
      created_at: @vehicle.created_at,
      updated_at: @vehicle.updated_at
    }.tap do |hash|
      hash[:maintenances] = maintenances_data if include_maintenances?
    end
  end

  private

  def vehicle_type_data
    return nil unless @vehicle.vehicle_type

    {
      id: @vehicle.vehicle_type.id,
      name: @vehicle.vehicle_type.name
    }
  end

  def company_data
    return nil unless @vehicle.company

    {
      id: @vehicle.company.id,
      name: @vehicle.company.name
    }
  end

  def maintenances_data
    @vehicle.maintenances.recent.map do |maintenance|
      MaintenanceSerializer.new(maintenance).as_json
    end
  end

  def include_maintenances?
    @options[:include_maintenances] == true
  end
end
```

### API Endpoints

#### Convenciones de Rutas

```ruby
# config/routes.rb
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    resources :vehicles do
      member do
        post :activate
        post :deactivate
      end

      collection do
        get :search
        get :export
      end

      resources :maintenances, only: [:index, :create]
    end
  end
end
```

**Rutas Generadas:**

```
GET    /api/v1/vehicles              # index
POST   /api/v1/vehicles              # create
GET    /api/v1/vehicles/:id          # show
PATCH  /api/v1/vehicles/:id          # update
DELETE /api/v1/vehicles/:id          # destroy
POST   /api/v1/vehicles/:id/activate # custom action
GET    /api/v1/vehicles/search       # collection action
GET    /api/v1/vehicles/:vehicle_id/maintenances
```

#### Formato de Respuestas

**Éxito:**

```json
{
  "id": 1,
  "plates": "ABC123",
  "brand": "Toyota",
  "model": "Corolla",
  "year": 2023,
  "active": true,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

**Error:**

```json
{
  "errors": {
    "plates": ["can't be blank"],
    "year": ["must be greater than 1900"]
  }
}
```

**Paginación:**

```json
{
  "data": [...],
  "meta": {
    "current_page": 1,
    "total_pages": 10,
    "total_count": 95,
    "per_page": 10
  }
}
```

---

## 🔵 Frontend (Quasar PWA)

### Arquitectura de Componentes

```
src/
├── layouts/
│   ├── MainLayout.vue          # Layout principal con sidebar
│   └── AuthLayout.vue          # Layout para login/registro
├── pages/
│   ├── vehicles/
│   │   ├── VehiclesPage.vue    # Lista de vehículos
│   │   ├── VehicleDetail.vue   # Detalle de vehículo
│   │   └── VehicleForm.vue     # Formulario crear/editar
│   └── dashboard/
│       └── DashboardPage.vue
├── components/
│   ├── vehicles/
│   │   ├── VehicleCard.vue     # Card de vehículo
│   │   ├── VehicleFilters.vue  # Filtros
│   │   └── VehicleTable.vue    # Tabla
│   └── common/
│       ├── AppHeader.vue
│       ├── AppSidebar.vue
│       └── LoadingSpinner.vue
├── stores/
│   ├── auth.js                 # Estado de autenticación
│   ├── vehicles.js             # Estado de vehículos
│   └── ui.js                   # Estado de UI (sidebar, etc)
├── router/
│   └── routes.js               # Configuración de rutas
└── boot/
    ├── axios.js                # Configuración de Axios
    └── auth.js                 # Inicialización de auth
```

### Pinia Stores (Estado Global)

**Estructura de Store:**

```javascript
// src/stores/vehicles.js
import { defineStore } from "pinia";
import { api } from "boot/axios";
import { Notify } from "quasar";

export const useVehicleStore = defineStore("vehicles", {
  state: () => ({
    vehicles: [],
    currentVehicle: null,
    loading: false,
    error: null,
    filters: {
      search: "",
      active: null,
      vehicleTypeId: null,
    },
    pagination: {
      page: 1,
      perPage: 10,
      totalPages: 1,
      totalCount: 0,
    },
  }),

  getters: {
    activeVehicles: (state) => {
      return state.vehicles.filter((v) => v.active);
    },

    filteredVehicles: (state) => {
      let filtered = state.vehicles;

      if (state.filters.search) {
        const search = state.filters.search.toLowerCase();
        filtered = filtered.filter(
          (v) =>
            v.plates.toLowerCase().includes(search) ||
            v.brand.toLowerCase().includes(search) ||
            v.model.toLowerCase().includes(search)
        );
      }

      if (state.filters.active !== null) {
        filtered = filtered.filter((v) => v.active === state.filters.active);
      }

      if (state.filters.vehicleTypeId) {
        filtered = filtered.filter(
          (v) => v.vehicle_type?.id === state.filters.vehicleTypeId
        );
      }

      return filtered;
    },

    getVehicleById: (state) => (id) => {
      return state.vehicles.find((v) => v.id === id);
    },
  },

  actions: {
    async fetchVehicles(page = 1) {
      this.loading = true;
      this.error = null;

      try {
        const response = await api.get("/api/v1/vehicles", {
          params: {
            page,
            per_page: this.pagination.perPage,
            ...this.filters,
          },
        });

        this.vehicles = response.data.data || response.data;

        if (response.data.meta) {
          this.pagination = {
            ...this.pagination,
            ...response.data.meta,
          };
        }
      } catch (error) {
        this.error = error.message;
        Notify.create({
          type: "negative",
          message: "Error al cargar vehículos",
          caption: error.message,
        });
      } finally {
        this.loading = false;
      }
    },

    async fetchVehicle(id) {
      this.loading = true;

      try {
        const response = await api.get(`/api/v1/vehicles/${id}`);
        this.currentVehicle = response.data;
        return response.data;
      } catch (error) {
        this.error = error.message;
        throw error;
      } finally {
        this.loading = false;
      }
    },

    async createVehicle(vehicleData) {
      try {
        const response = await api.post("/api/v1/vehicles", {
          vehicle: vehicleData,
        });

        this.vehicles.unshift(response.data);

        Notify.create({
          type: "positive",
          message: "Vehículo creado exitosamente",
        });

        return response.data;
      } catch (error) {
        const errorMessage = error.response?.data?.errors || error.message;

        Notify.create({
          type: "negative",
          message: "Error al crear vehículo",
          caption: JSON.stringify(errorMessage),
        });

        throw error;
      }
    },

    async updateVehicle(id, vehicleData) {
      try {
        const response = await api.put(`/api/v1/vehicles/${id}`, {
          vehicle: vehicleData,
        });

        const index = this.vehicles.findIndex((v) => v.id === id);
        if (index !== -1) {
          this.vehicles[index] = response.data;
        }

        if (this.currentVehicle?.id === id) {
          this.currentVehicle = response.data;
        }

        Notify.create({
          type: "positive",
          message: "Vehículo actualizado exitosamente",
        });

        return response.data;
      } catch (error) {
        Notify.create({
          type: "negative",
          message: "Error al actualizar vehículo",
        });
        throw error;
      }
    },

    async deleteVehicle(id) {
      try {
        await api.delete(`/api/v1/vehicles/${id}`);

        this.vehicles = this.vehicles.filter((v) => v.id !== id);

        Notify.create({
          type: "positive",
          message: "Vehículo eliminado exitosamente",
        });
      } catch (error) {
        Notify.create({
          type: "negative",
          message: "Error al eliminar vehículo",
        });
        throw error;
      }
    },

    setFilters(filters) {
      this.filters = { ...this.filters, ...filters };
      this.fetchVehicles(1); // Reset to page 1 when filtering
    },

    clearFilters() {
      this.filters = {
        search: "",
        active: null,
        vehicleTypeId: null,
      };
      this.fetchVehicles(1);
    },
  },

  persist: {
    enabled: true,
    strategies: [
      {
        key: "vehicles",
        storage: localStorage,
        paths: ["filters", "pagination.perPage"],
      },
    ],
  },
});
```

### Componentes Vue

**Ejemplo de Página:**

```vue
<!-- src/pages/vehicles/VehiclesPage.vue -->
<template>
  <q-page padding>
    <div class="row items-center q-mb-md">
      <div class="col">
        <div class="text-h4">Vehículos</div>
      </div>
      <div class="col-auto">
        <q-btn
          color="primary"
          label="Nuevo Vehículo"
          icon="add"
          @click="showCreateDialog = true"
        />
      </div>
    </div>

    <vehicle-filters @filter="handleFilter" />

    <vehicle-table
      :vehicles="filteredVehicles"
      :loading="loading"
      @edit="handleEdit"
      @delete="handleDelete"
    />

    <div class="row justify-center q-mt-md">
      <q-pagination
        v-model="currentPage"
        :max="totalPages"
        direction-links
        @update:model-value="handlePageChange"
      />
    </div>

    <vehicle-form-dialog v-model="showCreateDialog" @submit="handleCreate" />
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useVehicleStore } from "stores/vehicles";
import { useQuasar } from "quasar";
import VehicleFilters from "components/vehicles/VehicleFilters.vue";
import VehicleTable from "components/vehicles/VehicleTable.vue";
import VehicleFormDialog from "components/vehicles/VehicleFormDialog.vue";

const $q = useQuasar();
const vehicleStore = useVehicleStore();

const showCreateDialog = ref(false);
const currentPage = ref(1);

const filteredVehicles = computed(() => vehicleStore.filteredVehicles);
const loading = computed(() => vehicleStore.loading);
const totalPages = computed(() => vehicleStore.pagination.totalPages);

onMounted(() => {
  vehicleStore.fetchVehicles();
});

const handleFilter = (filters) => {
  vehicleStore.setFilters(filters);
};

const handlePageChange = (page) => {
  vehicleStore.fetchVehicles(page);
};

const handleCreate = async (vehicleData) => {
  try {
    await vehicleStore.createVehicle(vehicleData);
    showCreateDialog.value = false;
  } catch (error) {
    console.error("Error creating vehicle:", error);
  }
};

const handleEdit = (vehicle) => {
  // Navigate to edit page or show edit dialog
  $q.notify({
    message: `Editar vehículo ${vehicle.plates}`,
    color: "info",
  });
};

const handleDelete = (vehicleId) => {
  $q.dialog({
    title: "Confirmar",
    message: "¿Estás seguro de eliminar este vehículo?",
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      await vehicleStore.deleteVehicle(vehicleId);
    } catch (error) {
      console.error("Error deleting vehicle:", error);
    }
  });
};
</script>
```

### Configuración de Axios

```javascript
// src/boot/axios.js
import { boot } from "quasar/wrappers";
import axios from "axios";
import { useAuthStore } from "stores/auth";
import { Notify } from "quasar";

const api = axios.create({
  baseURL: process.env.API_URL || "http://localhost:3000",
  timeout: 30000,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

export default boot(({ app, router }) => {
  // Request interceptor
  api.interceptors.request.use(
    (config) => {
      const authStore = useAuthStore();

      if (authStore.token) {
        config.headers.Authorization = `Bearer ${authStore.token}`;
      }

      return config;
    },
    (error) => {
      return Promise.reject(error);
    }
  );

  // Response interceptor
  api.interceptors.response.use(
    (response) => {
      return response;
    },
    (error) => {
      if (error.response) {
        switch (error.response.status) {
          case 401:
            // Unauthorized - redirect to login
            const authStore = useAuthStore();
            authStore.logout();
            router.push("/login");

            Notify.create({
              type: "negative",
              message: "Sesión expirada",
              caption: "Por favor inicia sesión nuevamente",
            });
            break;

          case 403:
            Notify.create({
              type: "negative",
              message: "Acceso denegado",
              caption: "No tienes permisos para realizar esta acción",
            });
            break;

          case 404:
            Notify.create({
              type: "negative",
              message: "Recurso no encontrado",
            });
            break;

          case 422:
            // Validation errors - handled by individual components
            break;

          case 500:
            Notify.create({
              type: "negative",
              message: "Error del servidor",
              caption: "Por favor intenta nuevamente más tarde",
            });
            break;

          default:
            Notify.create({
              type: "negative",
              message: "Error inesperado",
              caption: error.message,
            });
        }
      } else if (error.request) {
        Notify.create({
          type: "negative",
          message: "Error de conexión",
          caption: "No se pudo conectar con el servidor",
        });
      }

      return Promise.reject(error);
    }
  );

  app.config.globalProperties.$axios = axios;
  app.config.globalProperties.$api = api;
});

export { api };
```

---

## 🗄️ Base de Datos

### Esquema Principal

```sql
-- Usuarios y Autenticación
users
  - id (PK)
  - email (unique)
  - encrypted_password
  - name
  - role_id (FK)
  - company_id (FK)
  - active
  - created_at
  - updated_at

roles
  - id (PK)
  - name
  - description
  - permissions (jsonb)

-- Empresas y Sucursales
companies
  - id (PK)
  - name
  - rfc
  - address
  - active
  - created_at
  - updated_at

company_subsidiaries
  - id (PK)
  - company_id (FK)
  - name
  - address
  - phone
  - active

-- Vehículos
vehicles
  - id (PK)
  - plates (unique)
  - brand
  - model
  - year
  - vehicle_type_id (FK)
  - company_id (FK)
  - active
  - created_at
  - updated_at

vehicle_types
  - id (PK)
  - name
  - description
  - capacity

-- Mantenimientos
maintenances
  - id (PK)
  - vehicle_id (FK)
  - company_subsidiary_id (FK)
  - date
  - type
  - description
  - cost
  - created_at
  - updated_at

-- Clientes
clients
  - id (PK)
  - name
  - email
  - phone
  - company_id (FK)
  - active
  - black_list
  - black_list_description
  - created_at
  - updated_at

-- Empleados
employees
  - id (PK)
  - name
  - email
  - phone
  - position
  - company_id (FK)
  - active
  - created_at
  - updated_at
```

### Índices Importantes

```sql
-- Índices para búsquedas frecuentes
CREATE INDEX idx_vehicles_company ON vehicles(company_id);
CREATE INDEX idx_vehicles_active ON vehicles(active);
CREATE INDEX idx_vehicles_plates ON vehicles(plates);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_company ON users(company_id);

CREATE INDEX idx_maintenances_vehicle ON maintenances(vehicle_id);
CREATE INDEX idx_maintenances_date ON maintenances(date);

-- Índices compuestos
CREATE INDEX idx_vehicles_company_active ON vehicles(company_id, active);
CREATE INDEX idx_maintenances_vehicle_date ON maintenances(vehicle_id, date DESC);
```

### Migraciones

**Ejemplo de Migración:**

```ruby
class CreateVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicles do |t|
      t.string :plates, null: false
      t.string :brand, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.references :vehicle_type, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :vehicles, :plates, unique: true
    add_index :vehicles, [:company_id, :active]
  end
end
```

---

## 🔐 Autenticación y Autorización

### JWT Authentication

**Flujo de Autenticación:**

```
1. Usuario envía credenciales → POST /api/v1/auth/login
2. Backend valida credenciales
3. Backend genera JWT token
4. Frontend guarda token en localStorage
5. Frontend envía token en cada request: Authorization: Bearer <token>
6. Backend valida token en cada request
```

**Implementación:**

```ruby
# app/controllers/api/v1/auth_controller.rb
module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login]

      def login
        user = User.find_by(email: params[:email])

        if user&.valid_password?(params[:password])
          token = JsonWebToken.encode(user_id: user.id)

          render json: {
            token: token,
            user: UserSerializer.new(user).as_json
          }, status: :ok
        else
          render json: { error: 'Invalid credentials' }, status: :unauthorized
        end
      end

      def logout
        # Invalidate token (implement token blacklist if needed)
        head :no_content
      end
    end
  end
end

# lib/json_web_token.rb
class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError => e
    nil
  end
end
```

### CanCanCan Authorization

**Definición de Abilities:**

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user

    case user.role&.name
    when 'SuperAdmin'
      can :manage, :all

    when 'Admin'
      can :manage, :all, company_id: user.company_id
      cannot :destroy, Company

    when 'Manager'
      can :read, :all, company_id: user.company_id
      can :manage, Vehicle, company_id: user.company_id
      can :manage, Maintenance, company_id: user.company_id

    when 'User'
      can :read, Vehicle, company_id: user.company_id
      can :read, Maintenance, company_id: user.company_id

    else
      # Guest user
      can :read, :public_data
    end
  end
end
```

**Uso en Controladores:**

```ruby
class VehiclesController < ApplicationController
  load_and_authorize_resource

  def index
    @vehicles = @vehicles.accessible_by(current_ability)
    render json: @vehicles
  end
end
```

---

## ⚙️ Jobs en Background (Sidekiq)

### Configuración

```yaml
# config/sidekiq.yml
:concurrency: 10
:timeout: 25
:queues:
  - critical
  - default
  - mailers
  - low_priority

:schedule:
  check_maintenances:
    cron: "0 2 * * *" # Diario a las 2 AM
    class: CheckMaintenancesJob
    queue: default

  generate_reports:
    cron: "0 0 * * 0" # Semanal, domingos a medianoche
    class: GenerateWeeklyReportsJob
    queue: low_priority
```

### Ejemplo de Worker

```ruby
# app/workers/send_maintenance_reminder_worker.rb
class SendMaintenanceReminderWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform(vehicle_id)
    vehicle = Vehicle.find(vehicle_id)

    return unless vehicle.needs_maintenance?

    # Enviar email
    MaintenanceMailer.reminder(vehicle).deliver_now

    # Crear notificación en la app
    Notification.create!(
      user: vehicle.company.admin,
      title: 'Mantenimiento Requerido',
      message: "El vehículo #{vehicle.plates} requiere mantenimiento",
      vehicle: vehicle
    )

    # Log
    Rails.logger.info("Maintenance reminder sent for vehicle #{vehicle.id}")
  end
end
```

### Jobs Programados

```ruby
# app/jobs/check_maintenances_job.rb
class CheckMaintenancesJob < ApplicationJob
  queue_as :default

  def perform
    Vehicle.active.find_each do |vehicle|
      next unless vehicle.needs_maintenance?

      SendMaintenanceReminderWorker.perform_async(vehicle.id)
    end
  end
end
```

---

## 💾 Caching

### Estrategia de Cache

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  expires_in: 1.hour,
  namespace: 'ttpngas'
}

# Uso en controladores
def index
  @vehicles = Rails.cache.fetch("vehicles/company/#{current_user.company_id}", expires_in: 30.minutes) do
    Vehicle.where(company_id: current_user.company_id).to_a
  end

  render json: @vehicles
end

# Invalidación de cache
after_save :clear_cache

def clear_cache
  Rails.cache.delete("vehicles/company/#{company_id}")
end
```

---

## 🚀 Deployment

### Railway (Backend)

```yaml
# railway.json
{
  "build": { "builder": "DOCKERFILE", "dockerfilePath": "Dockerfile" },
  "deploy":
    {
      "numReplicas": 2,
      "sleepApplication": false,
      "restartPolicyType": "ON_FAILURE",
      "restartPolicyMaxRetries": 10,
    },
}
```

### Netlify (Frontend)

```toml
# netlify.toml
[build]
  command = "quasar build -m pwa"
  publish = "dist/pwa"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  NODE_VERSION = "20"
```

---

## 🔒 Seguridad

### Mejores Prácticas

1. **HTTPS Only** en producción
2. **CORS** configurado correctamente
3. **Rate Limiting** con Rack Attack
4. **SQL Injection** prevenido con ActiveRecord
5. **XSS** prevenido con sanitización
6. **CSRF** tokens en formularios
7. **Secrets** en variables de entorno
8. **Brakeman** para análisis de seguridad

---

## 📊 Performance

### Optimizaciones

1. **N+1 Queries:** Usar `includes` y `joins`
2. **Paginación:** Kaminari para grandes datasets
3. **Índices:** En columnas frecuentemente consultadas
4. **Caching:** Redis para datos frecuentes
5. **Background Jobs:** Para operaciones pesadas
6. **CDN:** Para assets estáticos

---

## 📈 Monitoreo

### Herramientas

- **Scout APM:** Performance monitoring
- **Sentry:** Error tracking
- **Lograge:** Structured logging
- **Sidekiq Web:** Job monitoring

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0
