# Graph Report - .  (2026-04-30)

## Corpus Check
- 154 files · ~99,999 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 842 nodes · 1355 edges · 40 communities detected
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 100 edges (avg confidence: 0.82)
- Token cost: 135,500 input · 22,900 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Arquitectura y Documentación Core|Arquitectura y Documentación Core]]
- [[_COMMUNITY_Onboarding y Deploy CICD|Onboarding y Deploy CI/CD]]
- [[_COMMUNITY_PostgreSQL Functions y Bookings|PostgreSQL Functions y Bookings]]
- [[_COMMUNITY_Employees y Clientes Multitenancy|Employees y Clientes Multitenancy]]
- [[_COMMUNITY_Migración Heroku → Railway|Migración Heroku → Railway]]
- [[_COMMUNITY_Flotilla y Combustible|Flotilla y Combustible]]
- [[_COMMUNITY_Recursos Humanos y Stats|Recursos Humanos y Stats]]
- [[_COMMUNITY_Integraciones y API Keys|Integraciones y API Keys]]
- [[_COMMUNITY_Frontend Patrones y Guías|Frontend Patrones y Guías]]
- [[_COMMUNITY_Services Layer y Seguridad|Services Layer y Seguridad]]
- [[_COMMUNITY_Deuda Técnica FE|Deuda Técnica FE]]
- [[_COMMUNITY_Sistema de Cuadre Bookings|Sistema de Cuadre Bookings]]
- [[_COMMUNITY_Python Scripts y Hardening|Python Scripts y Hardening]]
- [[_COMMUNITY_Motor de Ruteo y Auditoría|Motor de Ruteo y Auditoría]]
- [[_COMMUNITY_Captura Bookings FE|Captura Bookings FE]]
- [[_COMMUNITY_Dashboard FE Refactor|Dashboard FE Refactor]]
- [[_COMMUNITY_Chat AI con N8NGroq|Chat AI con N8N/Groq]]
- [[_COMMUNITY_Auth Sessions y Gasolina|Auth Sessions y Gasolina]]
- [[_COMMUNITY_Importación Excel Masiva|Importación Excel Masiva]]
- [[_COMMUNITY_Scripts Python Analytics|Scripts Python Analytics]]
- [[_COMMUNITY_Patrones UI Modales|Patrones UI Modales]]
- [[_COMMUNITY_ActionCable Real-time|ActionCable Real-time]]
- [[_COMMUNITY_Testing API Keys|Testing API Keys]]
- [[_COMMUNITY_Calendario de Citas|Calendario de Citas]]
- [[_COMMUNITY_Swagger Docs|Swagger Docs]]
- [[_COMMUNITY_Diálogo de Citas|Diálogo de Citas]]
- [[_COMMUNITY_Fix PG Search Path|Fix PG Search Path]]
- [[_COMMUNITY_SonarCloud FE Cleanup|SonarCloud FE Cleanup]]
- [[_COMMUNITY_Portal de Proveedores|Portal de Proveedores]]
- [[_COMMUNITY_Vehicle Model|Vehicle Model]]
- [[_COMMUNITY_Sistema Alertas|Sistema Alertas]]
- [[_COMMUNITY_Security Headers|Security Headers]]
- [[_COMMUNITY_Serializers|Serializers]]
- [[_COMMUNITY_N8N Workflow JSON|N8N Workflow JSON]]
- [[_COMMUNITY_useNotify Composable|useNotify Composable]]
- [[_COMMUNITY_Páginas Ruteo FE|Páginas Ruteo FE]]
- [[_COMMUNITY_Páginas Empleados FE|Páginas Empleados FE]]
- [[_COMMUNITY_Python Scripts README|Python Scripts README]]
- [[_COMMUNITY_Clients API Doc|Clients API Doc]]
- [[_COMMUNITY_Auth Móvil Doc|Auth Móvil Doc]]

## God Nodes (most connected - your core abstractions)
1. `Employee` - 28 edges
2. `ARQUITECTURA_TECNICA.md — Reescritura Completa` - 27 edges
3. `Guía para Desarrolladores — Kumi TTPN Admin V2` - 21 edges
4. `Vehicle` - 20 edges
5. `Catálogo Completo de Funciones PostgreSQL` - 19 edges
6. `PRD — Kumi TTPN Admin Platform` - 18 edges
7. `ADR README — Registro de Decisiones de Arquitectura` - 18 edges
8. `Funciones PostgreSQL y Triggers de TtpnBooking` - 16 edges
9. `Análisis Exhaustivo del Modelo TtpnBooking` - 16 edges
10. `SEGURIDAD.md — Documentación de Seguridad` - 16 edges

## Surprising Connections (you probably didn't know these)
- `Concern SequenceSynchronizable (PKs rotas por inserts externos)` --semantically_similar_to--> `Patrón Nested Forms con tabs dinámicos (_destroy, accepts_nested_attributes_for)`  [INFERRED] [semantically similar]
  INFRA/onboarding/GUIA_DESARROLLADOR.md → Frontend/patrones/PATRON_TABS_NESTED_FORMS.md
- `Concern Auditable (created_by / updated_by automático)` --semantically_similar_to--> `BusinessUnitAssignable (concern)`  [INFERRED] [semantically similar]
  INFRA/onboarding/GUIA_DESARROLLADOR.md → Backend/dominio/concerns/business_unit_assignable.md
- `Patrón Service Object (PORO con .call) — Rails` --semantically_similar_to--> `Patrón Orquestador Puro — FE páginas ~130 líneas`  [INFERRED] [semantically similar]
  _archivo/cambios/BE/2026-03-19_services_layer_fuel_performance.md → Frontend/paginas/bookings/TravelCountsPage.md
- `TtpnBooking (modelo Rails)` --diagrams_entity--> `ERD — Kumi TTPN Database Schema`  [EXTRACTED]
  Backend/dominio/bookings/README.md → INFRA/database/ERD.pdf
- `Sesión 2026-04-29 — Auditoría de Seguridad y Hardening` --conceptually_related_to--> `Refactorización Completada — Eliminación de SQL Injection`  [INFERRED]
  _archivo/session_notes/2026-04-29_rate_limiting_sql_injection.md → Backend/dominio/bookings/seguridad/REFACTORIZACION_SQL_INJECTION_COMPLETADA.md

## Hyperedges (group relationships)
- **Cuadre Automático Transaccional (TravelCount + TtpnBooking + Trigger PG + Monolito)** — concepto_sp_tctb_insert, concepto_cuadre_automatico, adr_002_triggers_pg, adr_001_monolito [EXTRACTED 1.00]
- **Hardening Seguridad 2026 (rack-attack + Lockable + CSP + IDOR + Command Injection + pre-commit)** — adr_008_hardening, concepto_rack_attack, concepto_devise_lockable, concepto_csp_frontend, concepto_idor_fix, concepto_command_injection_fix, concepto_pre_commit_hook [EXTRACTED 1.00]
- **Stack de Producción Railway + Supabase + Netlify** — adr_004_railway_netlify, concepto_railway_deploy, concepto_netlify_deploy, concepto_supabase_pro [EXTRACTED 1.00]
- **Pipeline CI/CD completo: GitLab → GitHub → Railway (BE) / Netlify (FE)** — gitlab_remote, github_remote, railway_platform, netlify_platform, rama_transform_to_api, rama_main_fe [EXTRACTED 1.00]
- **Composición estándar de página FE: PageHeader + FilterPanel + AppTable + composables** — fe_page_pattern, component_pageheader, component_filterpanel, component_apptable, composable_use_crud, composable_use_filters, composable_use_privileges [EXTRACTED 1.00]
- **Stack de cuadre de viajes: buscar_booking trigger + TtpnCuadreService + travel_counts + ttpn_bookings** — buscar_booking_trigger, ttpn_cuadre_service, travel_counts_table, ttpn_bookings_table, concern_cuadrable [EXTRACTED 1.00]
- **Sesión de refactor 2026-03-27: TravelCountsPage + TtpnBookingsCapturePage → patrón orquestador + StatsBar + FilterPanel** — page_travel_counts, page_capture_bookings, comp_statsbar, comp_filterpanel, composable_usefilters [EXTRACTED 1.00]
- **Flujo de cutover Heroku → Railway + Supabase: backup, restore, backfill, verificación** — plan_produccion, infra_heroku, infra_railway, infra_supabase, concept_business_unit_multitenancy [EXTRACTED 1.00]
- **Capa de servicios FuelPerformance: VehicleCalculator + TimelineBuilder + PerformersRanker reemplazan fat controller** — be_services_fuel_performance, service_vehicle_calculator, service_timeline_builder, service_performers_ranker, controller_fuel_performance [EXTRACTED 1.00]
- **Plan de capa de servicios BE (5 controllers refactorizados)** — services_layer_ttpn_bookings, services_layer_payroll, services_layer_gasoline_auth, ttpn_booking_filter, payroll_week_calculator [EXTRACTED 1.00]
- **Sistema de Cuadre TtpnBooking ↔ TravelCount** — ttpn_cuadre_service, clv_servicio_field, current_cuadre_flag, ttpn_booking_model, travel_count_model [EXTRACTED 1.00]
- **Hardening de Seguridad 2026-04-29 (8 capas)** — rack_attack, devise_lockable_jwt, command_injection_fix, idor_fix, precommit_secrets_hook, csp_frontend_fix [EXTRACTED 1.00]
- **Cuadre Automático Bidireccional: TtpnBooking ↔ TravelCount** — model_ttpn_booking, model_travel_count, pg_trigger_sp_tb_update, pg_trigger_sp_tctb_update, pg_func_buscar_travel_id, pg_func_buscar_booking_id [EXTRACTED 1.00]
- **Legacy PHP ↔ verificar_id Anti-Pattern ↔ Rails Models** — php_legacy_android, callback_verificar_id, model_travel_count, model_ttpn_booking_passenger [EXTRACTED 1.00]
- **SQL Injection: Plan → Refactorización → Helpers seguros** — plan_mejoras_sql_injection, refactorizacion_sql_injection_completada, helper_ttpn_bookings, helper_travel_counts [EXTRACTED 1.00]
- **Vehicle Assignment Lifecycle: Employee Baja triggers VehicleAsignation via EmployeeMovement** — model_employee, model_employeemovement, model_vehicleasignation [EXTRACTED 1.00]
- **Fuel Performance Analysis: GasCharge feeds FuelPerformanceCache via FuelPerformance services** — model_gascharge, service_fuelperformance_vehiclecalculator, model_fuelperformancecache [EXTRACTED 1.00]
- **Booking Price Resolution: TtpnService + TtpnServicePrice + VehicleType determine booking cost** — model_ttpnservice, model_ttpnserviceprice, model_vehicletype [EXTRACTED 1.00]
- **Employee KPI Calculation Pipeline** — employee_stats_calculable, employee_movement_model, business_unit_filter_scope [EXTRACTED 1.00]
- **N8N AI-Driven Booking Creation Flow** — kumi_chat_workflow, groq_api, ttpn_booking_model [EXTRACTED 1.00]
- **API Authentication Mechanisms** — api_key_model, driver_jwt, base_controller [EXTRACTED 0.90]

## Communities

### Community 0 - "Arquitectura y Documentación Core"
Cohesion: 0.03
Nodes (114): ADR-001 — Monolito Modular en lugar de Microservicios, ADR-001 — Monolito Modular en lugar de Microservicios, ADR-002 — Triggers PG para el Cuadre Automático, ADR-002 — Triggers PG para el Cuadre Automático, ADR-003 — JWTs Separados para Users y Employees, ADR-003 — JWTs Separados para Users y Employees, MobileBaseController (Namespace Rutas Móvil), ADR-004 — Railway + Netlify + Supabase (en lugar de Heroku) (+106 more)

### Community 1 - "Onboarding y Deploy CI/CD"
Cohesion: 0.04
Nodes (82): ActionCable AlertsChannel (WebSocket notificaciones real-time), Alerts::DispatcherService (email + push FCM + ActionCable), API Key Auth (autenticación M2M), Axios interceptor JWT + business_unit_id (boot/axios.js), Api::V1::BaseController (autenticación y BU), trigger buscar_booking / sp_tctb_insert (PostgreSQL), business_unit_filter scope (filtrado universal por BU), Business Unit Selector — Documentación (+74 more)

### Community 2 - "PostgreSQL Functions y Bookings"
Cohesion: 0.07
Nodes (66): Actualización Crítica: Todos los verificar_id, Actualización Análisis TravelCount.verificar_id, Análisis de Callbacks Problemáticos - verificar_id, Análisis Exhaustivo del Modelo TtpnBooking, verificar_id (Callback Pattern), Catálogo Completo de Funciones PostgreSQL, Concepto: Cuadre Automático Bidireccional (Reservas ↔ Viajes), Dominio Servicios TTPN (+58 more)

### Community 3 - "Employees y Clientes Multitenancy"
Cohesion: 0.05
Nodes (58): active_headcount_at(date, type_ids) method, AI Prompts Guide — Employees Module, ApiKey (modelo), api_keys.md — Sistema de API Keys, Guía de Pruebas del Sistema de API Keys, ApiUser (modelo), Migración: índices FK faltantes en api_users, Eliminar IDs hardcodeados de roles y tipos de movimiento (2026-04-10) (+50 more)

### Community 4 - "Migración Heroku → Railway"
Cohesion: 0.05
Nodes (57): api_keys + api_users (M2M auth), ActionCable (WebSockets), Sistema de Alertas (AlertRule → Alert → AlertDelivery), Rswag / Swagger API Docs, Tabla travel_counts, Tabla ttpn_bookings, Multi-tenancy: business_unit_id en tablas operativas, CAMBIOS_DB — Registro histórico de cambios en BD (+49 more)

### Community 5 - "Flotilla y Combustible"
Cohesion: 0.05
Nodes (52): AlertsChannel (ActionCable), BusinessUnit (Auth Domain), User (Auth Domain), Canal WebSocket: AlertsChannel, Concepto: Autenticación JWT con Devise + revocación por JTI, Concepto: Multi-tenancy via BusinessUnit + Current, Concern Auditable (created_by / updated_by automático), Concern: BusinessUnitAssignable (+44 more)

### Community 6 - "Recursos Humanos y Stats"
Cohesion: 0.06
Nodes (52): Análisis Detallado Modelo Employee, Autenticación Móvil de Choferes (JWT), JWT de Chofer (Employee), ActionCable (WebSockets), Active Storage (S3), BusinessUnit (Unidad de Negocio), Concern: EmployeeStatsCalculable, EmployeeStatsCalculable (concern) (+44 more)

### Community 7 - "Integraciones y API Keys"
Cohesion: 0.07
Nodes (48): AI Provider: Groq (llama-3.3-70b-versatile), API de Clientes (Clients), Infraestructura API — Kumi como Master Hub, Sistema de API Keys, Swagger / rswag API Documentation Guide, Sistema de Activación por Email - Usuarios de Clientes, Arquitectura ClientUser (Microservicios), Controller: Api::V1::Portal::BaseController (+40 more)

### Community 8 - "Frontend Patrones y Guías"
Cohesion: 0.07
Nodes (46): Ability (CanCanCan) — Autorización, Api::V1::BaseController, Scope: business_unit_filter, Concern: Auditable, Concern: Cacheable, Concern: Cuadrable, Concern: SequenceSynchronizable, Current (ActiveSupport::CurrentAttributes) (+38 more)

### Community 9 - "Services Layer y Seguridad"
Cohesion: 0.08
Nodes (38): Tech Debt: backfill_clvs usa Thread.new en request HTTP, BackfillTtpnBookingsJob (Sidekiq), Services Layer: TtpnBookings (2026-03-19), Services Layer: FuelPerformance (2026-03-19), Services Layer: PayrollReports (2026-03-20), Fix Command Injection (backfill_clvs + Python job), CSP Frontend: eliminar unsafe-inline y unsafe-eval, Deuda Técnica: backfill_clvs Thread.new sin Sidekiq (+30 more)

### Community 10 - "Deuda Técnica FE"
Cohesion: 0.07
Nodes (37): Introducción capa de servicios — FuelPerformance (2026-03-19), DashboardMatrixTable.vue — componente planificado (Cliente × Mes × Tipo), DashboardPeriodPanel.vue — componente planificado, FilterPanel.vue — componente compartido, StatsBar.vue — componente compartido, useBookingCaptureCatalogs.js — composable TtpnBookingsCapture, useBookingCaptureData.js — composable TtpnBookingsCapture, useDashboardData.js — composable Dashboard planificado (+29 more)

### Community 11 - "Sistema de Cuadre Bookings"
Cohesion: 0.1
Nodes (32): Cuadrable (concern), Current (ActiveSupport::CurrentAttributes) — cuadre_in_progress flag, TravelCount (modelo Rails), TravelCountsController, TravelCountsHelper — busca_en_booking (SQL Nivel 2), TtpnBooking (modelo Rails), TtpnBookingPassenger (modelo Rails), TtpnBookingsHelper — busca_en_travel (SQL Nivel 2) (+24 more)

### Community 12 - "Python Scripts y Hardening"
Cohesion: 0.07
Nodes (30): src/boot/actioncable.js (FE), dashboard/dashboard_data.py, dashboard/dashboard_data.py (script Python), DashboardDataService (Ruby), SEGURIDAD.md — Documentación de Seguridad, EjecutarScriptPythonJob (Sidekiq + Open3), Integración Python dentro de Rails, JobStatusChannel (ActionCable) (+22 more)

### Community 13 - "Motor de Ruteo y Auditoría"
Cohesion: 0.09
Nodes (30): ARQUITECTURA_TECNICA.md — Reescritura completa, Tabla fleet_availability_snapshots, Tabla route_proposals, Services::Routing::DistanceCalculator (OSRM/Haversine), ADR-008 — Hardening de Seguridad 2026, ARQUITECTURA_TECNICA.md — Reescritura Completa, PRD.md — Product Requirements Document, Dominio: Ruteo (+22 more)

### Community 14 - "Captura Bookings FE"
Cohesion: 0.18
Nodes (13): BookingCaptureDeleteDialog.vue, BookingCaptureDetailDialog.vue, BookingCaptureFilters.vue, BookingCaptureImportDialog.vue, BookingCaptureMobileList.vue, BookingCaptureTable.vue, TtpnBookingsCapturePage Refactor, StatsBar.vue (+5 more)

### Community 15 - "Dashboard FE Refactor"
Cohesion: 0.29
Nodes (11): DashboardExportDialog.vue, DashboardKpiCards.vue, DashboardMatrixTable.vue, DashboardPage Refactor Plan, DashboardPage.vue, DashboardPeriodPanel.vue, DashboardRevenueTab.vue, DashboardTrendChart.vue (+3 more)

### Community 16 - "Chat AI con N8N/Groq"
Cohesion: 0.29
Nodes (8): Api::V1::ChatController, Deuda Técnica: Kumi Chat (N8N + IA), GET /api/v1/booking_stats, GET /api/v1/client_stats, GET /api/v1/dashboard/summary, GET /api/v1/employee_stats, GET /api/v1/vehicle_stats, N8N Chat Workflow (clasificador Groq LLaMA 70B)

### Community 17 - "Auth Sessions y Gasolina"
Cohesion: 0.43
Nodes (8): Auth::SessionsController, Services Layer: GasolineCharges y Auth::Sessions (2026-03-20), GasolineChargesController, Gasoline::EmployeeAssignment (service), Gasoline::StatsBuilder (service), Capa de Servicios — Gasoline y Auth (2026-03-20), Sistema de Privilegios (privileges + role_privileges), User#build_privileges (método modelo)

### Community 18 - "Importación Excel Masiva"
Cohesion: 0.38
Nodes (7): Composable: useTtpnBookingImport, Importación Excel Completa con Sidekiq::Status, Importación Excel — Columnas Flexibles, Formato Excel para Importación de Bookings, Implementación Importación Excel (TtpnBookings), Patrón: Búsquedas Case-Insensitive (ILIKE), TtpnBookingImportJob

### Community 19 - "Scripts Python Analytics"
Cohesion: 0.6
Nodes (6): Job: EjecutarScriptPythonJob, Script: dashboard/dashboard_data.py, Script: reportes/contables.py, Python Scripts README, Service: DashboardDataService (Ruby), Util: PostgresClient (utils/db.py)

### Community 20 - "Patrones UI Modales"
Cohesion: 0.33
Nodes (6): Modal Maximized (clientes complejos con anidación múltiple), Modal Simple Form 600px (patrón estándar), Modal Tabbed CRUD 900px (patrón estándar — flex+max-height+scroll), Estándar de Modales — Análisis y Definición, Patrón Nested Forms con tabs dinámicos (_destroy, accepts_nested_attributes_for), Patrón de Tabs y Nested Forms Dinámicas

### Community 21 - "ActionCable Real-time"
Cohesion: 0.5
Nodes (5): AlertsChannel — Canal de Alertas por Business Unit, JobStatusChannel — Canal ActionCable por Usuario, WebhooksController — Receptor de Webhooks Externos, boot/actioncable.js — Setup de ActionCable en Frontend, WebSockets, ActionCable y Webhooks

### Community 22 - "Testing API Keys"
Cohesion: 0.5
Nodes (5): ApiKey (modelo Rails), ApiUser (modelo Rails), Vehicle (modelo Rails), Estado de Tests — Vehículos y API Keys (snapshot dic 2025), Guía de Pruebas del Sistema de API Keys

### Community 23 - "Calendario de Citas"
Cohesion: 1.0
Nodes (3): Componentes de Calendario (CalendarHeader, DayView, AppointmentCard, MiniCalendar), Calendario de Citas — Componentes Completos, EmployeeAppointmentsPage (módulo de Citas de Empleados)

### Community 24 - "Swagger Docs"
Cohesion: 0.67
Nodes (3): rswag (gem), swagger.md — Guía Swagger/rswag, swagger/v1/swagger.yaml

### Community 25 - "Diálogo de Citas"
Cohesion: 1.0
Nodes (2): Componente: AppointmentDialog.vue, Componentes de Calendario (Citas)

### Community 26 - "Fix PG Search Path"
Cohesion: 1.0
Nodes (2): Correcciones Supabase y SonarCloud (2026-03-17), Migration: fix_function_search_paths (search_path seguro en PG functions)

### Community 27 - "SonarCloud FE Cleanup"
Cohesion: 1.0
Nodes (2): Limpieza SonarCloud P0 FE — console.* y backups, useNotify (composable FE)

### Community 28 - "Portal de Proveedores"
Cohesion: 1.0
Nodes (2): Api::V1::SupplierPortal::BaseController, SupplierUser (model)

### Community 29 - "Vehicle Model"
Cohesion: 1.0
Nodes (1): Vehicle (Vehículo de la Flotilla)

### Community 30 - "Sistema Alertas"
Cohesion: 1.0
Nodes (1): Sistema de Alertas (Alert + AlertRule + AlertDelivery)

### Community 31 - "Security Headers"
Cohesion: 1.0
Nodes (1): Security Headers (Rails + Netlify)

### Community 32 - "Serializers"
Cohesion: 1.0
Nodes (1): Patrón Serializer (minimal vs full)

### Community 33 - "N8N Workflow JSON"
Cohesion: 1.0
Nodes (1): N8N Workflow: kumi-chat.json

### Community 34 - "useNotify Composable"
Cohesion: 1.0
Nodes (1): useNotify composable (notificaciones Quasar)

### Community 35 - "Páginas Ruteo FE"
Cohesion: 1.0
Nodes (1): Frontend Páginas: Dominio Ruteo

### Community 36 - "Páginas Empleados FE"
Cohesion: 1.0
Nodes (1): Frontend Páginas: Dominio Empleados

### Community 37 - "Python Scripts README"
Cohesion: 1.0
Nodes (1): Scripts Python — Kumi TTPN Admin

### Community 38 - "Clients API Doc"
Cohesion: 1.0
Nodes (1): CLIENTS_API.md — Módulo Clients

### Community 39 - "Auth Móvil Doc"
Cohesion: 1.0
Nodes (1): AUTH_MOVIL.md — Autenticación de Choferes

## Knowledge Gaps
- **250 isolated node(s):** `Sidekiq (Jobs en Background)`, `TtpnBooking (Programación de Servicio)`, `Payroll (Nómina de Choferes)`, `Discrepancy (Registros sin Cuadre)`, `KumiSetting (Configuración por BU)` (+245 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Diálogo de Citas`** (2 nodes): `Componente: AppointmentDialog.vue`, `Componentes de Calendario (Citas)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Fix PG Search Path`** (2 nodes): `Correcciones Supabase y SonarCloud (2026-03-17)`, `Migration: fix_function_search_paths (search_path seguro en PG functions)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `SonarCloud FE Cleanup`** (2 nodes): `Limpieza SonarCloud P0 FE — console.* y backups`, `useNotify (composable FE)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Portal de Proveedores`** (2 nodes): `Api::V1::SupplierPortal::BaseController`, `SupplierUser (model)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Vehicle Model`** (1 nodes): `Vehicle (Vehículo de la Flotilla)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Sistema Alertas`** (1 nodes): `Sistema de Alertas (Alert + AlertRule + AlertDelivery)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Security Headers`** (1 nodes): `Security Headers (Rails + Netlify)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Serializers`** (1 nodes): `Patrón Serializer (minimal vs full)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `N8N Workflow JSON`** (1 nodes): `N8N Workflow: kumi-chat.json`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `useNotify Composable`** (1 nodes): `useNotify composable (notificaciones Quasar)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Páginas Ruteo FE`** (1 nodes): `Frontend Páginas: Dominio Ruteo`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Páginas Empleados FE`** (1 nodes): `Frontend Páginas: Dominio Empleados`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Python Scripts README`** (1 nodes): `Scripts Python — Kumi TTPN Admin`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Clients API Doc`** (1 nodes): `CLIENTS_API.md — Módulo Clients`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Auth Móvil Doc`** (1 nodes): `AUTH_MOVIL.md — Autenticación de Choferes`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sesión: Rate Limiting y SQL Injection (2026-04-29)` connect `Services Layer y Seguridad` to `Arquitectura y Documentación Core`, `Employees y Clientes Multitenancy`?**
  _High betweenness centrality (0.244) - this node is a cross-community bridge._
- **Why does `Vehicle` connect `Flotilla y Combustible` to `Onboarding y Deploy CI/CD`, `PostgreSQL Functions y Bookings`, `Employees y Clientes Multitenancy`, `Recursos Humanos y Stats`?**
  _High betweenness centrality (0.243) - this node is a cross-community bridge._
- **Why does `ADR-008 — Hardening de Seguridad 2026` connect `Arquitectura y Documentación Core` to `Services Layer y Seguridad`, `Motor de Ruteo y Auditoría`?**
  _High betweenness centrality (0.226) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Employee` (e.g. with `PayrollProcessWorker (Sidekiq Job)` and `VehicleDocument`) actually correct?**
  _`Employee` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Sidekiq (Jobs en Background)`, `TtpnBooking (Programación de Servicio)`, `Payroll (Nómina de Choferes)` to the rest of the system?**
  _250 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Arquitectura y Documentación Core` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Onboarding y Deploy CI/CD` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._