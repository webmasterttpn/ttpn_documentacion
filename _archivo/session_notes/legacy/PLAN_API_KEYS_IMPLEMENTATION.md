# 🔑 Plan de Implementación: Sistema de API Keys y Multi-App

## 📋 Resumen Ejecutivo

Implementar sistema completo de:

1. **API Users** - Usuarios para integraciones externas
2. **API Keys** - Tokens con permisos granulares
3. **Multi-App Access** - Control de acceso por aplicación
4. **Frontend** - Interfaz de gestión
5. **Testing** - RSpec + Factories + Swagger

---

## 🎯 Fase 1: Backend - Modelos y Migraciones

### 1.1 Migración: Agregar campos a `users`

```bash
docker-compose exec app rails generate migration AddAppControlToUsers
```

```ruby
# db/migrate/xxx_add_app_control_to_users.rb
class AddAppControlToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :allowed_apps, :jsonb, default: ['admin_web'], null: false
    add_column :users, :permissions_per_app, :jsonb, default: {}, null: false

    add_index :users, :allowed_apps, using: :gin
    add_index :users, :permissions_per_app, using: :gin

    reversible do |dir|
      dir.up do
        # Dar acceso a admin_web a todos los usuarios existentes
        User.update_all(
          allowed_apps: ['admin_web'],
          permissions_per_app: {
            'admin_web' => {
              'vehicles' => ['read', 'create', 'update', 'delete'],
              'clients' => ['read', 'create', 'update', 'delete']
            }
          }
        )
      end
    end
  end
end
```

### 1.2 Migración: Cambiar `api_keys` a usar `api_user_id`

```bash
docker-compose exec app rails generate migration ChangeApiKeysToUseApiUsers
```

```ruby
# db/migrate/xxx_change_api_keys_to_use_api_users.rb
class ChangeApiKeysToUseApiUsers < ActiveRecord::Migration[7.1]
  def change
    # Eliminar FK antigua
    remove_foreign_key :api_keys, :users if foreign_key_exists?(:api_keys, :users)

    # Renombrar columna
    rename_column :api_keys, :user_id, :api_user_id

    # Agregar nueva FK
    add_foreign_key :api_keys, :api_users

    # Actualizar índice
    remove_index :api_keys, :user_id if index_exists?(:api_keys, :user_id)
    add_index :api_keys, :api_user_id
    add_index :api_keys, [:api_user_id, :active]
  end
end
```

### 1.3 Ejecutar Migraciones

```bash
docker-compose exec app rails db:migrate
```

---

## 🎯 Fase 2: Backend - Modelos

### 2.1 Modelo `User` (actualizar)

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # ... código existente ...

  # Validaciones para multi-app
  validates :allowed_apps, presence: true

  # Apps disponibles en el sistema
  AVAILABLE_APPS = {
    'admin_web' => 'Panel de Administración',
    'mobile_driver' => 'App Móvil Conductores',
    'mobile_client' => 'App Móvil Clientes',
    'dashboard_executive' => 'Dashboard Ejecutivo'
  }.freeze

  # Métodos de instancia
  def can_access_app?(app_name)
    allowed_apps&.include?(app_name.to_s)
  end

  def permissions_for_app(app_name)
    permissions_per_app&.dig(app_name.to_s) || {}
  end

  def grant_app_access!(app_name, permissions = {})
    self.allowed_apps ||= []
    self.allowed_apps << app_name.to_s unless allowed_apps.include?(app_name.to_s)

    self.permissions_per_app ||= {}
    self.permissions_per_app[app_name.to_s] = permissions

    save!
  end

  def revoke_app_access!(app_name)
    self.allowed_apps&.delete(app_name.to_s)
    self.permissions_per_app&.delete(app_name.to_s)
    save!
  end
end
```

### 2.2 Modelo `ApiUser` (nuevo)

```ruby
# app/models/api_user.rb
class ApiUser < ApplicationRecord
  include Auditable

  # Asociaciones
  belongs_to :business_unit
  has_many :api_keys, dependent: :destroy

  # Validaciones
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :company_name, presence: true
  validates :business_unit, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_business_unit, ->(bu_id) { where(business_unit_id: bu_id) }

  # Métodos
  def deactivate!
    update!(active: false)
    api_keys.update_all(active: false)
  end

  def activate!
    update!(active: true)
  end

  def total_requests
    api_keys.sum(:requests_count)
  end

  def last_activity
    api_keys.maximum(:last_used_at)
  end
end
```

### 2.3 Modelo `ApiKey` (actualizar)

```ruby
# app/models/api_key.rb
class ApiKey < ApplicationRecord
  include Auditable

  # Asociaciones
  belongs_to :api_user

  # Validaciones
  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :permissions, presence: true
  validates :api_user, presence: true

  # Callbacks
  before_validation :generate_key, on: :create
  before_create :set_defaults

  # Scopes
  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid_keys, -> { active.where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # Permisos disponibles (EXPANDIDO)
  AVAILABLE_PERMISSIONS = {
    'vehicles' => {
      'read' => 'Ver vehículos',
      'create' => 'Crear vehículos',
      'update' => 'Actualizar vehículos',
      'delete' => 'Eliminar vehículos'
    },
    'clients' => {
      'read' => 'Ver clientes',
      'create' => 'Crear clientes',
      'update' => 'Actualizar clientes',
      'delete' => 'Eliminar clientes'
    },
    'employees' => {
      'read' => 'Ver empleados',
      'create' => 'Crear empleados',
      'update' => 'Actualizar empleados',
      'delete' => 'Eliminar empleados'
    },
    'bookings' => {
      'read' => 'Ver reservas',
      'create' => 'Crear reservas',
      'update' => 'Actualizar reservas',
      'delete' => 'Eliminar reservas'
    },
    'users' => {
      'read' => 'Ver usuarios de plataforma',
      'create' => 'Crear usuarios de plataforma',
      'update' => 'Actualizar usuarios de plataforma',
      'delete' => 'Eliminar usuarios de plataforma'
    },
    'api_users' => {
      'read' => 'Ver usuarios de API',
      'create' => 'Crear usuarios de API',
      'update' => 'Actualizar usuarios de API',
      'delete' => 'Eliminar usuarios de API'
    }
  }.freeze

  # Métodos de instancia
  def valid?
    super && active? && !expired? && api_user.active?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def touch_last_used!
    update_columns(
      last_used_at: Time.current,
      requests_count: requests_count + 1
    )
  end

  def can?(resource, action)
    return false unless valid?
    permissions.dig(resource.to_s, action.to_s) == true
  end

  def revoke!
    update!(active: false)
  end

  def regenerate!
    update!(key: SecureRandom.hex(32))
  end

  # Métodos de clase
  def self.authenticate(key)
    find_by(key: key)&.tap do |api_key|
      return nil unless api_key.valid?
      api_key.touch_last_used!
    end
  end

  private

  def generate_key
    self.key ||= SecureRandom.hex(32)
  end

  def set_defaults
    self.active = true if active.nil?
    self.requests_count = 0 if requests_count.nil?
    self.permissions = {} if permissions.blank?
  end
end
```

---

## 🎯 Fase 3: Backend - Serializers

### 3.1 ApiUserSerializer

```ruby
# app/serializers/api_user_serializer.rb
class ApiUserSerializer
  def initialize(api_user, options = {})
    @api_user = api_user
    @options = options
  end

  def as_json
    {
      id: @api_user.id,
      name: @api_user.name,
      email: @api_user.email,
      company_name: @api_user.company_name,
      active: @api_user.active,
      business_unit: business_unit_data,
      api_keys_count: @api_user.api_keys.count,
      total_requests: @api_user.total_requests,
      last_activity: @api_user.last_activity,
      created_at: @api_user.created_at,
      updated_at: @api_user.updated_at,
      audit: audit_data
    }.tap do |hash|
      hash[:api_keys] = api_keys_data if @options[:include_api_keys]
    end
  end

  private

  def business_unit_data
    return nil unless @api_user.business_unit

    {
      id: @api_user.business_unit.id,
      nombre: @api_user.business_unit.nombre,
      clv: @api_user.business_unit.clv
    }
  end

  def api_keys_data
    @api_user.api_keys.map do |key|
      ApiKeySerializer.new(key).as_json
    end
  end

  def audit_data
    {
      created_at: @api_user.created_at,
      created_by: @api_user.created_by_name,
      updated_at: @api_user.updated_at,
      updated_by: @api_user.updated_by_name
    }
  end
end
```

---

## 🎯 Fase 4: Backend - Controladores

### 4.1 ApiUsersController

```ruby
# app/controllers/api/v1/api_users_controller.rb
module Api
  module V1
    class ApiUsersController < Api::V1::BaseController
      before_action :require_admin!
      before_action :set_api_user, only: [:show, :update, :destroy, :activate, :deactivate]

      # GET /api/v1/api_users
      def index
        @api_users = ApiUser.includes(:business_unit, :api_keys, :creator, :updater)
                            .order(created_at: :desc)

        render json: @api_users.map { |au| ApiUserSerializer.new(au).as_json }
      end

      # GET /api/v1/api_users/:id
      def show
        render json: ApiUserSerializer.new(@api_user, include_api_keys: true).as_json
      end

      # POST /api/v1/api_users
      def create
        @api_user = ApiUser.new(api_user_params)

        if @api_user.save
          render json: ApiUserSerializer.new(@api_user).as_json, status: :created
        else
          render json: { errors: @api_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/api_users/:id
      def update
        if @api_user.update(api_user_params)
          render json: ApiUserSerializer.new(@api_user).as_json
        else
          render json: { errors: @api_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/api_users/:id
      def destroy
        @api_user.destroy
        head :no_content
      end

      # POST /api/v1/api_users/:id/activate
      def activate
        @api_user.activate!
        render json: ApiUserSerializer.new(@api_user).as_json
      end

      # POST /api/v1/api_users/:id/deactivate
      def deactivate
        @api_user.deactivate!
        render json: ApiUserSerializer.new(@api_user).as_json
      end

      private

      def set_api_user
        @api_user = ApiUser.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'API User no encontrado' }, status: :not_found
      end

      def api_user_params
        params.require(:api_user).permit(
          :name,
          :email,
          :company_name,
          :business_unit_id,
          :active
        )
      end

      def require_admin!
        unless current_user&.sadmin?
          render json: { error: 'No autorizado' }, status: :forbidden
        end
      end
    end
  end
end
```

### 4.2 Actualizar ApiKeysController

```ruby
# Cambiar todas las referencias de :user_id a :api_user_id
def api_key_params
  params.require(:api_key).permit(
    :name,
    :api_user_id,  # ← CAMBIO
    :expires_at,
    permissions: {}
  )
end
```

---

## 🎯 Fase 5: Backend - Rutas

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    # API Users
    resources :api_users do
      member do
        post :activate
        post :deactivate
      end
    end

    # API Keys (ya existente, solo actualizar)
    resources :api_keys do
      member do
        post :regenerate
        post :revoke
      end
      collection do
        get :permissions
      end
    end
  end
end
```

---

## 🎯 Fase 6: Testing - RSpec

### 6.1 Factories

```ruby
# spec/factories.rb

# Agregar a factories existentes:
factory :api_user do
  sequence(:name) { |n| "API User #{n}" }
  sequence(:email) { |n| "api_user#{n}@example.com" }
  company_name { 'Test Company' }
  active { true }

  association :business_unit
  association :creator, factory: :user
  association :updater, factory: :user

  trait :inactive do
    active { false }
  end

  trait :with_api_keys do
    after(:create) do |api_user|
      create_list(:api_key, 2, api_user: api_user)
    end
  end
end

# Actualizar factory de api_key:
factory :api_key do
  sequence(:name) { |n| "API Key #{n}" }
  active { true }
  permissions do
    {
      'vehicles' => { 'read' => true },
      'clients' => { 'read' => true }
    }
  end

  association :api_user
  association :creator, factory: :user
  association :updater, factory: :user

  trait :expired do
    expires_at { 1.day.ago }
  end

  trait :full_access do
    permissions do
      {
        'vehicles' => { 'read' => true, 'create' => true, 'update' => true, 'delete' => true },
        'clients' => { 'read' => true, 'create' => true, 'update' => true, 'delete' => true }
      }
    end
  end
end
```

### 6.2 Model Specs

```ruby
# spec/models/api_user_spec.rb
require 'rails_helper'

RSpec.describe ApiUser, type: :model do
  describe 'associations' do
    it { should belong_to(:business_unit) }
    it { should have_many(:api_keys).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:company_name) }
    it { should validate_uniqueness_of(:email) }
  end

  describe '#deactivate!' do
    let(:api_user) { create(:api_user, :with_api_keys) }

    it 'deactivates the api_user and all its keys' do
      api_user.deactivate!

      expect(api_user.reload.active).to be false
      expect(api_user.api_keys.pluck(:active).uniq).to eq([false])
    end
  end

  describe '#total_requests' do
    let(:api_user) { create(:api_user) }
    let!(:key1) { create(:api_key, api_user: api_user, requests_count: 100) }
    let!(:key2) { create(:api_key, api_user: api_user, requests_count: 50) }

    it 'returns sum of all api_keys requests' do
      expect(api_user.total_requests).to eq(150)
    end
  end
end
```

---

## 🎯 Fase 7: Frontend - Quasar

### 7.1 Crear Página de API Access

```bash
# Crear página en Quasar
cd ttpn-frontend
quasar new page ApiAccess
```

```vue
<!-- src/pages/ApiAccessPage.vue -->
<template>
  <q-page padding>
    <div class="q-pa-md">
      <div class="row items-center q-mb-md">
        <div class="col">
          <div class="text-h4">Acceso a API</div>
          <div class="text-subtitle2 text-grey-7">
            Gestiona usuarios y claves de acceso para integraciones externas
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            label="Nuevo Usuario API"
            icon="add"
            @click="showCreateDialog = true"
          />
        </div>
      </div>

      <!-- Tabs -->
      <q-tabs
        v-model="tab"
        dense
        class="text-grey"
        active-color="primary"
        indicator-color="primary"
        align="left"
      >
        <q-tab name="api_users" label="Usuarios API" />
        <q-tab name="api_keys" label="Claves de Acceso" />
      </q-tabs>

      <q-separator />

      <q-tab-panels v-model="tab" animated>
        <!-- API Users Tab -->
        <q-tab-panel name="api_users">
          <api-users-table
            :api-users="apiUsers"
            @edit="editApiUser"
            @delete="deleteApiUser"
            @view-keys="viewApiKeys"
          />
        </q-tab-panel>

        <!-- API Keys Tab -->
        <q-tab-panel name="api_keys">
          <api-keys-table
            :api-keys="apiKeys"
            @regenerate="regenerateKey"
            @revoke="revokeKey"
            @delete="deleteKey"
          />
        </q-tab-panel>
      </q-tab-panels>
    </div>

    <!-- Create/Edit Dialog -->
    <api-user-dialog
      v-model="showCreateDialog"
      :api-user="selectedApiUser"
      @save="saveApiUser"
    />
  </q-page>
</template>

<script>
import { ref, onMounted } from "vue";
import { api } from "src/boot/axios";
import { useQuasar } from "quasar";

export default {
  name: "ApiAccessPage",

  setup() {
    const $q = useQuasar();
    const tab = ref("api_users");
    const apiUsers = ref([]);
    const apiKeys = ref([]);
    const showCreateDialog = ref(false);
    const selectedApiUser = ref(null);

    const loadApiUsers = async () => {
      try {
        const { data } = await api.get("/api/v1/api_users");
        apiUsers.value = data;
      } catch (error) {
        $q.notify({
          type: "negative",
          message: "Error al cargar usuarios API",
        });
      }
    };

    const loadApiKeys = async () => {
      try {
        const { data } = await api.get("/api/v1/api_keys");
        apiKeys.value = data;
      } catch (error) {
        $q.notify({
          type: "negative",
          message: "Error al cargar claves API",
        });
      }
    };

    const saveApiUser = async (apiUser) => {
      try {
        if (apiUser.id) {
          await api.patch(`/api/v1/api_users/${apiUser.id}`, {
            api_user: apiUser,
          });
        } else {
          await api.post("/api/v1/api_users", { api_user: apiUser });
        }

        $q.notify({
          type: "positive",
          message: "Usuario API guardado exitosamente",
        });

        loadApiUsers();
        showCreateDialog.value = false;
      } catch (error) {
        $q.notify({
          type: "negative",
          message:
            error.response?.data?.errors?.join(", ") || "Error al guardar",
        });
      }
    };

    onMounted(() => {
      loadApiUsers();
      loadApiKeys();
    });

    return {
      tab,
      apiUsers,
      apiKeys,
      showCreateDialog,
      selectedApiUser,
      saveApiUser,
      loadApiUsers,
      loadApiKeys,
    };
  },
};
</script>
```

---

## 🎯 Fase 8: Documentación

### 8.1 Actualizar Swagger

```ruby
# spec/requests/api/v1/api_users_spec.rb
require 'swagger_helper'

RSpec.describe 'API V1 API Users', type: :request do
  let(:user) { create(:user, sadmin: true) }
  let(:Authorization) { "Bearer #{generate_token(user)}" }

  path '/api/v1/api_users' do
    get 'Lista todos los usuarios API' do
      tags 'API Users'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      response '200', 'usuarios API encontrados' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   name: { type: :string },
                   email: { type: :string },
                   company_name: { type: :string },
                   active: { type: :boolean }
                 }
               }

        run_test!
      end
    end

    post 'Crear nuevo usuario API' do
      tags 'API Users'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      parameter name: :api_user, in: :body, schema: {
        type: :object,
        properties: {
          api_user: {
            type: :object,
            properties: {
              name: { type: :string },
              email: { type: :string },
              company_name: { type: :string },
              business_unit_id: { type: :integer }
            },
            required: %w[name email company_name business_unit_id]
          }
        }
      }

      response '201', 'usuario API creado' do
        let(:api_user) do
          {
            api_user: {
              name: 'Test API User',
              email: 'test@example.com',
              company_name: 'Test Company',
              business_unit_id: create(:business_unit).id
            }
          }
        end

        run_test!
      end
    end
  end
end
```

---

## ✅ Checklist de Implementación

### Backend

- [ ] Migración: `allowed_apps` y `permissions_per_app` en `users`
- [ ] Migración: `api_users` table
- [ ] Migración: Cambiar `api_keys.user_id` a `api_user_id`
- [ ] Modelo `User` actualizado
- [ ] Modelo `ApiUser` completo
- [ ] Modelo `ApiKey` actualizado
- [ ] Serializer `ApiUserSerializer`
- [ ] Serializer `ApiKeySerializer` actualizado
- [ ] Controller `ApiUsersController`
- [ ] Controller `ApiKeysController` actualizado
- [ ] Rutas configuradas

### Testing

- [ ] Factory `api_user`
- [ ] Factory `api_key` actualizado
- [ ] Model spec `api_user_spec.rb`
- [ ] Model spec `api_key_spec.rb` actualizado
- [ ] Request spec `api_users_spec.rb`
- [ ] Request spec `api_keys_spec.rb` actualizado
- [ ] Swagger docs generados

### Frontend

- [ ] Página `ApiAccessPage.vue`
- [ ] Componente `ApiUsersTable.vue`
- [ ] Componente `ApiKeysTable.vue`
- [ ] Componente `ApiUserDialog.vue`
- [ ] Componente `ApiKeyDialog.vue`
- [ ] Ruta en `router/routes.js`
- [ ] Link en menú de configuración

### Documentación

- [ ] Actualizar `API_KEYS_GUIDE.md`
- [ ] Crear `MULTI_APP_ACCESS.md`
- [ ] Actualizar `README.md`
- [ ] Actualizar `ONBOARDING.md`

---

**Tiempo Estimado:** 4-6 horas
**Prioridad:** Alta
**Dependencias:** Ninguna
