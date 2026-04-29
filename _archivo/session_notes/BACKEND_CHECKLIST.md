# Backend Checklist — Kumi TTPN Admin V2
**Revisión:** 2026-04-05  
**Stack:** Rails 7.1.5 · Ruby 3.3.10 · PostgreSQL · Sidekiq · Redis · JWT · RSpec · Rswag  
**Contexto:** Migración de RailsAdmin → API pura. El FE (Quasar/Vue 3) ya funciona correctamente y consume la API.

---

## SECCIÓN 1 — LIMPIEZA DE ARCHIVOS LEGACY

> Prioridad alta. Reducen ruido en linting, SonarCloud y confusión arquitectural.  
> **Antes de eliminar cualquier carpeta:** verificar que ninguna ruta de `config/routes.rb` apunte al archivo.

### 1.1 Controllers Legacy (raíz de `app/controllers/`) ✅ COMPLETADO

- [x] Eliminados 63 controllers legacy de la raíz (duplicados de `api/v1/`)
- [x] Eliminados `app/controllers/users/` — passwords, registrations, confirmations, omniauth, unlocks (Devise los genera internamente)
- [x] Conservado `app/controllers/users/sessions_controller.rb` — Devise lo usa activamente para login JWT
- [x] Conservado `app/controllers/application_controller.rb` — base para `Users::SessionsController`

### 1.2 Vistas Legacy (`app/views/`) ✅ COMPLETADO

- [x] Eliminadas 346 vistas `.erb` en 65 carpetas legacy
- [x] Conservados: `layouts/mailer.*`, `devise/`, `asignation_mailer/`, `client_user_mailer/`
- [x] Eliminado `layouts/application.html.erb` (no aplica en api_only)
- [x] Eliminados `app/javascript/` (rails_admin.js, application.js)
- [x] Eliminados `app/assets/javascripts/`, `stylesheets/`, `images/`, `config/`
- [x] Eliminado `config/importmap.rails_admin.rb`

### 1.3 Assets Legacy (`app/javascript/` y `app/assets/`)
- [ ] Eliminar `app/javascript/rails_admin.js`
- [ ] Eliminar `app/javascript/application.js` (si no hay vistas que lo usen)
- [ ] Revisar `app/assets/` y eliminar todo lo que no sea para mailers

### 1.4 Importmap de RailsAdmin
- [ ] Eliminar `config/importmap.rails_admin.rb`
- [ ] Eliminar referencia a importmap en `config/application.rb` si existe

### 1.5 Modelos con bloques `rails_admin do ... end` comentados
Los siguientes modelos tienen bloques dead code comentados. Limpiarlos mejora el score SonarCloud:

- [ ] `app/models/cts_increment.rb`
- [ ] `app/models/employees_incidence.rb`
- [ ] `app/models/discrepancy.rb`
- [ ] `app/models/crdh_route.rb`
- [ ] `app/models/vehicle_event.rb`
- [ ] `app/models/ttpn_service_driver_increase.rb`
- [ ] `app/models/cr_day.rb`
- [ ] `app/models/client_ttpn_service.rb`
- [ ] `app/models/employee_appointment.rb`
- [ ] `app/models/client_branch_office.rb`
- [ ] `app/models/incidence.rb`
- [ ] `app/models/cts_driver_increment.rb`
- [ ] `app/models/coo_travel_request.rb`
- [ ] `app/models/ttpn_booking_passenger.rb`
- [ ] `app/models/cts_increment_detail.rb`
- [ ] `app/models/crd_hr.rb`
- [ ] `app/models/crdhr_point.rb`
- [ ] `app/models/client.rb`
- [ ] `app/models/gas_file.rb`
- [ ] `app/models/ve_asignation.rb`
- [ ] `app/models/ability.rb`
- [ ] `app/models/ttpn_service_price.rb`
- [ ] `app/models/drivers_level.rb`

### 1.6 Modelo y Controller Deprecados
- [ ] Eliminar `app/models/ve_asignation.rb` + su migración — reemplazado por `VehicleAsignation`
- [ ] Eliminar `app/models/client_contact.rb` — comentado como "Deprecated - usar client_users"
- [ ] Evaluar si `app/models/ability.rb` (CanCanCan) se usa activamente o se puede eliminar

### 1.7 Job Legacy
- [ ] Eliminar `app/sidekiq/hard_job.rb` — escrito en estilo Sidekiq v5, incompatible con v7

### 1.8 Gemfile — Gems Candidatas a Eliminar
- [ ] `gem 'cancancan'` — si la autorización ya se maneja con el concern `Privilege` y JWT, evaluar si se usa realmente en algún `before_action :authorize!`
- [ ] `gem 'friendly_id'` — verificar si algún modelo usa `extend FriendlyId`. Si no, eliminar
- [ ] `gem 'jbuilder'` — verificar si alguna vista JSON lo usa; si no hay vistas, eliminar
- [ ] `gem 'action_mailbox'` y `gem 'action_text'` en `config/application.rb` — verificar uso real
- [ ] Gems de assets: verificar que `sassc-rails`, `uglifier`, `coffee-rails`, `turbolinks` estén completamente comentadas/removidas del Gemfile.lock

---

## SECCIÓN 2 — ENDPOINTS FALTANTES O INCONSISTENTES

> Cruzamiento entre los servicios del FE y las rutas del BE.

### 2.1 Endpoints que el FE llama y que ya existen ✅
Confirmados en `config/routes.rb`:
- `POST /api/v1/employee_vacations/:id/authorize_vacation` ✅
- `POST /api/v1/employee_vacations/:id/reject_vacation` ✅ (recién agregado)
- `GET /api/v1/fuel_performance/summary` ✅
- `POST /api/v1/payroll_reports` y `POST /api/v1/payroll_reports/download` ✅
- `GET /api/v1/kumi_settings/payroll`, `kumi_settings/vacations` ✅

### 2.2 Endpoints a verificar en el controller (ruta existe pero acción puede estar incompleta)
- [ ] `GET /api/v1/employee_appointments` — verificar que acepta `start_date`/`end_date` como params (el FE los pasa para filtar por mes en calendario)
- [ ] `GET /api/v1/employee_appointments/:id/attendees` — verificar que existe la acción `attendees` en el controller
- [ ] `POST /api/v1/employee_vacations/:id/reject_vacation` — acción recién agregada, necesita `before_action :set_employee_vacation` en la lista del controller
- [ ] `GET /api/v1/invoicings/:id/excel_status` — verificar que exista esta acción (el FE la llama separado de `enqueue_excel`)
- [ ] `GET /api/v1/ttpn_bookings/import/:jobId/status` — verificar formato del jobId en rutas (puede haber conflicto con `:id`)
- [ ] `PUT /api/v1/client_branch_office_ttpn_contacts/bulk_update` — verificar que la acción sea `collection` en rutas, no `member`
- [ ] `PUT /api/v1/privileges/bulk_update` — mismo caso que el anterior
- [ ] `PATCH /api/v1/users/:id/activate` y `deactivate` — el FE usa PATCH, confirmar el verbo en routes

### 2.3 Rutas en routes.rb que el FE NO llama (candidatas a eliminar)
Verificar si son usadas por otros clientes (móvil, integraciones externas) antes de eliminar:
- [ ] `GET /api/v1/ttpn_bookings/office_for_client` — evaluar si se usa
- [ ] `POST /api/v1/ttpn_bookings/backfill_clvs` — parece utilitario de migración, no productivo
- [ ] `POST /api/v1/system_maintenance/run_tasks` — evaluar si se mantiene
- [ ] Todas las rutas del namespace antiguo (fuera de `api/v1/`) que no sean Devise ni Sidekiq dashboard

---

## SECCIÓN 3 — CALIDAD DE CÓDIGO (LINT / SONARCLOUD)

### 3.1 Variables Globales Thread-Unsafe ✅ COMPLETADO

**Crítico para producción con Puma (multi-thread):**

- [x] Eliminar `$actualizando` de `app/controllers/application_controller.rb`
- [x] Eliminar `$actualizandoGas` — era dead code (nunca se leía)
- [x] Eliminar `$cbusiness_unit_id` — era dead code (nunca se leía)
- [x] Reemplazar `$actualizando` en `app/models/travel_count.rb` con `Thread.current[:actualizando]` + `ensure` para limpiar en caso de excepción. `cts_increment.rb` no lo usaba.

### 3.2 Métodos Demasiado Largos (Metrics/MethodLength) ✅ COMPLETADO

SonarCloud y Rubocop penalizan métodos > 30 líneas. Candidatos críticos:

- [x] `InvoicingExcelWorker#build_xlsx` (~180 líneas) — extraído a métodos privados por tipo: `build_tipo_1..4`, `build_tipo_5_6`, `add_viajes_section`, `add_personal_por_planta_section`, `add_personal_por_area_section`, `add_detalle_section`, `define_styles`
- [x] `PayrollProcessWorker#generate_and_attach_excel` — extraído a `build_payroll_worksheet`, `build_timestamps`, `add_payroll_header`, `add_payroll_rows`, `add_payroll_totals`, `query_payroll_employees`
- [x] `EmployeeVacation#valida_periodos` — extraído a `assign_periodo`, `adjust_periodo_for_adelanto`, `setup_business_days_config`, `dias_tomados_en_periodo`, `validate_days_within_limit`
- [x] `DashboardDataService#get_data` — renombrado a `call` (estándar Service Object); `TtpnDataService#get_data` también renombrado
- [ ] Cualquier controller action > 20 líneas — candidato a extraer a Service Object

### 3.3 Números y Strings Mágicos ✅ COMPLETADO

- [x] Constantes de movimientos movidas a `EmployeeMovementType`: `ALTA=1`, `BAJA=2`, `REINGRESO=3`, `BAJA_LISTA_NEGRA=6`, `ALTAS_Y_REINGRESOS`. `Employee` mantiene aliases `MOV_*` para compatibilidad. `EmployeeMovement` usa `EmployeeMovementType::BAJA` directamente.
- [x] `DriverRequest` — agregadas constantes `STATUS_PENDIENTE`, `STATUS_ACEPTADO`, `STATUS_RECHAZADO`, `STATUSES`. Usadas en validación, scopes, métodos `?` y controller.
- [x] `EmployeeAppointment` — constantes `STATUSES` y `TIPOS_CITA` ya existían; eliminado `|| 1` hardcodeado en `set_business_unit_from_current_user`.
- [x] `business_unit_id: 1` hardcodeado eliminado de `ApiKeysController`, `ApiUsersController` y `EmployeeAppointment`. Ahora usa siempre `current_user.business_unit_id`.

### 3.4 Inconsistencias de Patrones
- [ ] `App::V1::BaseController` llama `set_business_unit_id` en cada controller individualmente — mover a `BaseController` como método helper reutilizable
- [ ] Respuestas JSON en controllers: algunos usan `render json: { errors: ... }`, otros `handle_error(...)` — estandarizar usando siempre `handle_error` del BaseController
- [ ] Service objects: algunos usan `def self.call(...)`, otros instancian con `new(...).call` — elegir un estándar y aplicarlo en todos
- [ ] Serializers: mezcla de `ActiveModel::Serializer` y serializers manuales — migrar todos los manual a un patrón consistente (preferir manual para control total y performance)

### 3.5 Código Comentado (SonarCloud lo reporta como "Code Smell")
- [ ] Remover todos los bloques `# rails_admin do ... end` de los 23 modelos listados en Sección 1.5
- [ ] Revisar controllers API V1 por métodos comentados (`# def old_method`)
- [ ] Limpiar `config/routes.rb` de comentarios y recursos duplicados

### 3.6 Seguridad (Brakeman) ✅ COMPLETADO

- [x] Activar `config.force_ssl = true` en `config/environments/production.rb`
- [x] `config/initializers/cors.rb` — `localhost` y `devtunnels.ms` ahora solo se permiten fuera de producción (`unless Rails.env.production?`)
- [x] `config/application.rb` — secret_key_base ya no tiene fallback hardcodeado; usa `ENV["SECRET_KEY_BASE"]` con fallback a `credentials.secret_key_base`
- [x] `puts "DATABASE_URL"` reemplazado por `Rails.logger.debug` condicional solo en development
- [x] `params.permit!` — auditado, no existe en ningún controller de `api/v1/`

---

## SECCIÓN 4 — PERFORMANCE

### 4.1 N+1 Queries ✅ COMPLETADO

- [x] `EmployeesController#index` — ya tenía includes correctos: `employee_drivers_levels: [:drivers_level]`
- [x] `EmployeesController#show` (`set_employee`) — agregado `{ doc_image_attachment: :blob }` a `employee_documents` para evitar N queries a ActiveStorage blobs
- [x] `EmployeeSerializer#current_salary` — cambiado `.order(created_at: :desc).first` por `.max_by(&:created_at)` (sort en memoria sobre asociación ya cargada)
- [x] `EmployeeAppointmentsController#index` — agregado `:creator, :updater` a includes (serializer usaba `creator_name`/`updater_name`)
- [x] `VehiclesController#set_vehicle` — agregado `:creator, :updater` y `vehicle_documents: { vehicle_doc_image_attachment: :blob }` a includes
- [x] `EmployeeVacationsController#index` — `KumiSetting` se carga UNA vez por request y se pasa al serializer; `dias_tomados` se calcula en memoria sobre `employee_vacations` ya precargado
- [x] `KumiSetting.vacation_days_from_periods` — nuevo método que recibe periodos precargados para no re-consultar BD
- [x] `authorize_vacation`/`reject_vacation` — eliminado `EmployeeVacation.find` duplicado (ya carga `@vacation` el `before_action`)
- [ ] Activar `bullet` gem en development y revisar log — tarea continua

### 4.2 Caché
- [ ] **VehiclesController**: La caché por `business_unit` tiene TTL de 1 hora. Agregar invalidación explícita en `create`, `update`, `destroy` de vehículos con `Rails.cache.delete(cache_key)`.
- [ ] **Avatar URLs**: La caché de 12 horas en `EmployeeSerializer` puede devolver URLs expiradas de ActiveStorage (los signed URLs de S3 expiran antes). Reducir TTL a 1-2 horas o usar URLs de CloudFront con TTL largo.
- [ ] **KumiSetting**: Es un modelo de configuración que raramente cambia. Agregar `cacheable` concern o `Rails.cache.fetch` con TTL largo (24h) y invalidar en update.
- [ ] Evaluar agregar caché de fragmentos para listados de catálogos que no cambian frecuentemente (vehicle_types, labors, drivers_levels, incidences).

### 4.3 Base de Datos — Índices ✅ COMPLETADO

Migración `20260408000001_add_missing_performance_indexes.rb` aplicada:

- [x] `employee_vacations(employee_id, periodo)` — `valida_periodos` WHERE employee_id + periodo
- [x] `employee_movements(employee_id, employee_movement_type_id)` — `fecha_inicio_actual` WHERE type IN (1,3)
- [x] `employee_movements(employee_id, fecha_efectiva)` — ORDER BY fecha_efectiva DESC
- [x] `employee_appointments(employee_id, fecha_inicio)` — queries de calendario
- [x] `gasoline_charges(vehicle_id, fecha)` — FuelPerformance compuesto
- [x] `gasoline_charges(employee_id, fecha)` — stats por empleado
- [x] `travel_counts(payroll_id, status)` — PayrollProcessWorker WHERE payroll_id + status=true
- [x] `employee_salaries(employee_id)` — ya existía
- [x] `ttpn_bookings(fecha, business_unit_id)` — dashboard filtra por `clients.business_unit_id` via JOIN, no columna directa; índice `(fecha, client_id)` existente cubre la query
- [x] `gas_charges` — no tiene `employee_id`; índice `(vehicle_id, fecha)` ya existía

### 4.4 Queries Pesadas
- [ ] **DashboardDataService**: Ejecuta múltiples agregaciones sin límite. Agregar paginación o límites en el rango de fechas aceptado.
- [ ] **FuelPerformance::VehicleCalculator**: Evaluar si puede pre-calcularse con un Job diario y almacenarse, en lugar de calcularse on-demand.
- [ ] **PayrollProcessWorker**: Genera Excel cargando todos los `TtpnBooking` en memoria. Usar `find_each` con `batch_size: 500` en lugar de `.all`.
- [ ] Revisar todos los `.all` sin `.limit` en controllers — agregar paginación con `pagy` gem o al menos límites razonables.

### 4.5 ActiveStorage
- [ ] Confirmar que las variantes de imágenes (avatares) se procesan en background con `variant: true` en el blob storage, no on-demand en cada request.
- [ ] Verificar que `aws-sdk-ec2` es necesario — parece pesado si solo se usa S3.

---

## SECCIÓN 5 — TESTING (RSpec)

### 5.1 Cobertura Actual
- 24 spec files para un proyecto de 326 archivos Ruby → cobertura estimada < 15%
- SimpleCov ya configurado. Objetivo mínimo: **80%** en controllers y models.

### 5.2 Request Specs (Integración) — Faltantes
Estos son los más valiosos para una API. El FE ya funciona, esto evita regresiones:

- [x] `spec/requests/api/v1/employees_spec.rb` — index, show, create, update, destroy, activate, deactivate
- [x] `spec/requests/api/v1/employee_vacations_spec.rb` — CRUD + authorize_vacation + reject_vacation
- [x] `spec/requests/api/v1/vehicles_spec.rb` — ampliar el existente con create/update/destroy
- [x] `spec/requests/api/v1/ttpn_bookings_spec.rb` — index, create, import
- [x] `spec/requests/api/v1/payrolls_spec.rb`
- [x] `spec/requests/api/v1/invoicings_spec.rb`
- [x] `spec/requests/api/v1/driver_requests_spec.rb` — incluyendo accept/reject
- [x] `spec/requests/api/v1/employee_appointments_spec.rb` — incluyendo attendees
- [x] `spec/requests/api/v1/auth/sessions_spec.rb` — ampliar el existente con logout y me
- [x] `spec/requests/api/v1/roles_spec.rb` — assign_user, role_privileges
- [x] `spec/requests/api/v1/api_keys_spec.rb` — regenerate, revoke, permissions
- [x] `spec/requests/api/v1/kumi_settings_spec.rb` — vacations, payroll, batch_update

### 5.3 Model Specs — Faltantes
- [ ] `spec/models/employee_vacation_spec.rb` — validaciones LFT, cálculo días hábiles, valida_periodos
- [ ] `spec/models/employee_spec.rb` — dias_vacaciones_correspondientes, fecha_inicio_actual, years_worked
- [ ] `spec/models/employee_appointment_spec.rb`
- [ ] `spec/models/driver_request_spec.rb`

### 5.4 Service Specs — Faltantes
- [ ] `spec/services/fuel_performance/timeline_builder_spec.rb`
- [ ] `spec/services/dashboard_data_service_spec.rb`
- [ ] `spec/services/payroll_svc/report_query_spec.rb`

### 5.5 Factories — Completar
- [ ] Revisar `spec/factories.rb` — verificar que existan factories para todos los modelos usados en specs
- [ ] Agregar `factory :employee_vacation`, `:driver_request`, `:employee_appointment`, `:service_appointment`
- [ ] Usar `FactoryBot.lint` en `spec/rails_helper.rb` para detectar factories rotas

### 5.6 Configuración
- [ ] Configurar **SimpleCov** con threshold mínimo: añadir `minimum_coverage 80` para que CI falle si baja de ese nivel
- [ ] Agregar `database_cleaner` con estrategia `transaction` para specs normales y `truncation` solo para los que usan JS

---

## SECCIÓN 6 — DOCUMENTACIÓN API (Rswag / Swagger)

> Rswag ya instalado. El objetivo es tener swagger completo para que el equipo y futuros desarrolladores entiendan la API sin leer el código.

- [ ] Crear `spec/integration/api/v1/auth_spec.rb` — documentar login, logout, me
- [ ] Crear specs Rswag para los 10 endpoints más usados por el FE:
  - [ ] `employees` — index (con filtros: search, labor_id, status), show, create, update
  - [ ] `employee_vacations` — index, create, update, authorize_vacation, reject_vacation
  - [ ] `vehicles` — index, show
  - [ ] `ttpn_bookings` — index (con filtros), create, import
  - [ ] `driver_requests` — index, create, accept, reject
  - [ ] `employee_appointments` — index (con start_date/end_date), create, attendees
  - [ ] `payrolls` — index, create
  - [ ] `invoicings` — index, enqueue_excel, excel_status
  - [ ] `kumi_settings` — vacations, payroll
  - [ ] `roles` — index, role_privileges, assign_user
- [ ] Documentar esquemas de respuesta (response schemas) para cada endpoint
- [ ] Verificar que `swagger/v1/swagger.yaml` se actualiza con `bundle exec rails rswag`

---

## SECCIÓN 7 — ARQUITECTURA Y DEUDA TÉCNICA

### 7.1 Middleware Innecesario
El proyecto tiene `api_only: true` pero agrega manualmente `Cookies`, `Session`, y `Flash` en `config/application.rb`. Esto es necesario solo si Devise todavía gestiona sesiones HTML.

- [ ] Evaluar: si solo se usa Devise para confirmación de email y reset de contraseña (mailers), los middlewares de sesión no son necesarios para la API. Pueden eliminarse.
- [ ] Si se elimina Devise sessions: remover `devise_for :users` de routes y reemplazar con la lógica JWT que ya existe en `Api::V1::Auth::SessionsController`.

### 7.2 `Api::V1::BaseController` — Mejoras
- [ ] Agregar `rescue_from StandardError` con log en producción (actualmente errores inesperados devuelven 500 sin mensaje útil)
- [ ] Extraer `current_business_unit_id` a un concern `BusinessUnitScoped` para que sea reutilizable
- [ ] Agregar rate limiting básico (gem `rack-attack`) para endpoints de auth

### 7.3 Concern `Auditable`
- [ ] Confirmar que `Current.user` siempre está seteado cuando se escribe en la BD — si un Job de Sidekiq crea/actualiza registros, `Current.user` será nil. Agregar `Current.user = User.system_user` o manejo explícito.

### 7.4 Rutas
- [ ] `config/routes.rb` tiene 365 líneas. Separar en archivos con `draw`:
  ```ruby
  # config/routes.rb
  Rails.application.routes.draw do
    draw :auth
    draw :employees
    draw :vehicles
    draw :bookings
    draw :settings
    # ...
  end
  ```
- [ ] Eliminar el bloque de `resources :employee_vacations` duplicado (aparece dos veces en routes.rb: una vez en los recursos simples y otra con member actions)

### 7.5 Configuración de Entorno
- [ ] Mover `config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "f4a4...")` a `credentials.yml.enc` o solo a variable de entorno. Un fallback hardcodeado en código fuente es un hallazgo crítico de SonarCloud.
- [ ] Eliminar el `puts "DATABASE_URL: ..."` de `config/application.rb`
- [ ] Verificar que `.env` no está comiteado (revisar `.gitignore`)

---

## SECCIÓN 8 — PRIORIZACIÓN SUGERIDA

<!-- markdownlint-disable MD060 -->
| Estado | Prioridad | Sección | Impacto |
|--------|-----------|---------|---------|
| ✅ | Critico | 3.1 Variables globales thread-unsafe | Bugs en producción con múltiples requests |
| ✅ | Critico | 3.6 Seguridad (CORS, force_ssl, secret hardcodeado) | Vulnerabilidades activas |
| ✅ | Alto | 2.2 Verificar endpoints incompletos | FE puede tener errores silenciosos |
| ✅ | Alto | 1.1 + 1.2 Eliminar controllers y vistas legacy | 60+ archivos muertos, score SonarCloud |
| ✅ | Alto | 4.1 N+1 Queries en serializers | Performance degradada en listas grandes |
| ✅ | Medio | 5.2 Request specs faltantes | Sin red de seguridad para cambios futuros |
| ✅ | Medio | 3.2 Métodos largos (workers) | Mantenibilidad |
| ✅ | Medio | 3.3 Enums y constantes | Legibilidad y SonarCloud |
| ✅ | Normal | 6. Documentación Rswag | DX para el equipo |
| ✅ | Normal | 4.3 Índices de BD | Performance en escala |
| ⬜ | Normal | 7.4 Rutas separadas por archivo | Organización |
| ⬜ | Normal | 1.8 Gems innecesarias | Tiempo de boot |
<!-- markdownlint-enable MD060 -->

---

## NOTAS DE DECISIÓN

- **¿Eliminar Devise completamente?** Solo si se abandona el reset de contraseña por email. Si se mantiene el mailer de reset, conservar Devise pero sin las rutas de sesión HTML.
- **¿Migrar todos los serializers a manual?** Sí, a largo plazo. `ActiveModel::Serializer` 0.10 está en modo mantenimiento mínimo. El patrón manual ya establecido en `EmployeeSerializer` y `VehicleSerializer` es más explícito y controlable.
- **¿Agregar `pagy` para paginación?** Sí, especialmente para `ttpn_bookings`, `employees`, y `payrolls` que pueden tener miles de registros.
- **¿Usar `jsonapi-serializer` en lugar de serializers manuales?** Evaluar — agrega estructura JSON:API que el FE no espera actualmente. Mantener serializers manuales es más seguro para no romper el FE.
