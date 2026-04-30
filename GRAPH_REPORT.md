# Graph Report - /Users/ttpn_acl/Documents/Ruby/Kumi TTPN Admin V2/Documentacion  (2026-04-30)

## Corpus Check
- 143 files · ~155,976 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 478 nodes · 739 edges · 30 communities detected
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 55 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Decisiones de Arquitectura (ADRs)|Decisiones de Arquitectura (ADRs)]]
- [[_COMMUNITY_Backend Core Modelos, Concerns y Autorización|Backend Core: Modelos, Concerns y Autorización]]
- [[_COMMUNITY_Auth Móvil, JWT y ActionCable|Auth Móvil, JWT y ActionCable]]
- [[_COMMUNITY_Dominio TtpnBooking, Finanzas y PostgreSQL|Dominio TtpnBooking, Finanzas y PostgreSQL]]
- [[_COMMUNITY_Tablas BE, Alertas, Swagger y Deploy|Tablas BE, Alertas, Swagger y Deploy]]
- [[_COMMUNITY_Multi-tenancy, Vehículos y Combustible|Multi-tenancy, Vehículos y Combustible]]
- [[_COMMUNITY_API Clientes, Auth Admin y Servicios TTPN|API Clientes, Auth Admin y Servicios TTPN]]
- [[_COMMUNITY_Cuadre, TtpnBooking Model y Travel Counts|Cuadre, TtpnBooking Model y Travel Counts]]
- [[_COMMUNITY_Deuda Técnica y Services de BookingsCombustible|Deuda Técnica y Services de Bookings/Combustible]]
- [[_COMMUNITY_Arquitectura Técnica, PRD y FilterPanel|Arquitectura Técnica, PRD y FilterPanel]]
- [[_COMMUNITY_Migraciones DB y Configuración Multi-tenancy|Migraciones DB y Configuración Multi-tenancy]]
- [[_COMMUNITY_Seguridad, Python Scripts y SQL Injection|Seguridad, Python Scripts y SQL Injection]]
- [[_COMMUNITY_API Keys, Infraestructura y Portal Base|API Keys, Infraestructura y Portal Base]]
- [[_COMMUNITY_Auth Sessions, Gasolina y Nómina|Auth Sessions, Gasolina y Nómina]]
- [[_COMMUNITY_Frontend Captura de TtpnBookings|Frontend: Captura de TtpnBookings]]
- [[_COMMUNITY_Frontend Dashboard y KPIs|Frontend: Dashboard y KPIs]]
- [[_COMMUNITY_Stats Endpoints, Chat y N8N|Stats Endpoints, Chat y N8N]]
- [[_COMMUNITY_Dominio Configuración (KumiSetting)|Dominio Configuración (KumiSetting)]]
- [[_COMMUNITY_Python Scripts y Dashboard Data Service|Python Scripts y Dashboard Data Service]]
- [[_COMMUNITY_ActionCable Channels y Webhooks|ActionCable Channels y Webhooks]]
- [[_COMMUNITY_API KeyUser Models y Testing|API Key/User Models y Testing]]
- [[_COMMUNITY_N8N Migración y Schema Supabase|N8N: Migración y Schema Supabase]]
- [[_COMMUNITY_Frontend Citas y Calendario|Frontend: Citas y Calendario]]
- [[_COMMUNITY_Supabase Fixes y Migración PostgreSQL|Supabase Fixes y Migración PostgreSQL]]
- [[_COMMUNITY_PRD Vehículos|PRD Vehículos]]
- [[_COMMUNITY_PRD Sistema de Alertas|PRD Sistema de Alertas]]
- [[_COMMUNITY_Security Headers|Security Headers]]
- [[_COMMUNITY_Patrón Serializer|Patrón Serializer]]
- [[_COMMUNITY_Dominio Ruteo|Dominio Ruteo]]
- [[_COMMUNITY_N8N Chat Workflow|N8N Chat Workflow]]

## God Nodes (most connected - your core abstractions)
1. `Guía para Desarrolladores — Kumi TTPN Admin V2` - 21 edges
2. `Employee (Modelo)` - 20 edges
3. `PRD — Kumi TTPN Admin Platform` - 18 edges
4. `Catálogo Completo de Funciones PostgreSQL (32 funciones)` - 17 edges
5. `Runbook de Incidentes Kumi TTPN` - 13 edges
6. `Onboarding Frontend — Kumi Admin PWA` - 13 edges
7. `Análisis Exhaustivo del Modelo TtpnBooking` - 13 edges
8. `EmployeeMovement (Modelo)` - 13 edges
9. `TtpnBookingsCapturePage.vue` - 12 edges
10. `Modelo Vehicle (Rails)` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Sesión 2026-04-29 — Auditoría de Seguridad y Hardening` --conceptually_related_to--> `Refactorización Completada — Eliminación de SQL Injection`  [INFERRED]
  _archivo/session_notes/2026-04-29_rate_limiting_sql_injection.md → Backend/dominio/bookings/seguridad/REFACTORIZACION_SQL_INJECTION_COMPLETADA.md
- `N8N Railway Deploy Guide` --references--> `Railway (Plataforma de Deploy)`  [EXTRACTED]
  N8N/deploy/N8N_RAILWAY_DEPLOY.md → INFRA/infraestructura/RAILWAY_NETLIFY_SUPABASE.md
- `Patrón: Tabs y Nested Forms Dinámicas` --conceptually_related_to--> `Modelo TtpnBooking`  [INFERRED]
  Frontend/patrones/PATRON_TABS_NESTED_FORMS.md → INFRA/onboarding/GUIA_DESARROLLADOR.md
- `Componente: BusinessUnitSelector.vue` --conceptually_related_to--> `Scope: business_unit_filter`  [INFERRED]
  Frontend/componentes/BUSINESS_UNIT_SELECTOR.md → INFRA/onboarding/GUIA_DESARROLLADOR.md
- `Sistema de Privilegios (Frontend + Backend)` --conceptually_related_to--> `Ability (CanCanCan) — Autorización`  [INFERRED]
  Frontend/patrones/SISTEMA_PRIVILEGIOS.md → INFRA/onboarding/GUIA_DESARROLLADOR.md

## Hyperedges (group relationships)
- **Flujo de Cuadre Automático (TravelCount + TtpnBooking + Trigger PG)** — prd_travel_count, prd_ttpn_booking, prd_sp_tctb_insert, prd_cuadre_automatico [EXTRACTED 1.00]
- **Pipeline de Deploy (GitLab → GitHub → Railway/Netlify)** — deploy_gitlab_remote, deploy_github_remote, prd_railway, prd_netlify [EXTRACTED 1.00]
- **Hardening de Seguridad 2026 (rack-attack + Lockable + CSP + IDOR + pre-commit)** — adr_008, seguridad_rate_limiting, seguridad_device_lockable, seguridad_csp, seguridad_idor, seguridad_precommit_hook [EXTRACTED 1.00]
- **Stack de Producción Railway + Supabase + Netlify** — infra_railway, infra_supabase, infra_netlify [EXTRACTED 1.00]
- **Patrón Estándar de Página Frontend** — fe_app_table, fe_filter_panel, fe_page_header [EXTRACTED 1.00]
- **Pipeline de Importación Excel (Frontend + Backend + Job)** — fe_composable_booking_import, ops_booking_import_job, fe_excel_format [EXTRACTED 1.00]

## Communities

### Community 0 - "Decisiones de Arquitectura (ADRs)"
Cohesion: 0.04
Nodes (72): ADR-001 — Monolito Modular en lugar de Microservicios, ADR-002 — Triggers PG para el Cuadre Automático, ADR-003 — JWTs Separados para Users y Employees, MobileBaseController (Namespace Rutas Móvil), ADR-004 — Railway + Netlify + Supabase (en lugar de Heroku), ADR-005 — Quasar + Capacitor para App Móvil, ADR-006 — Sistema de Privilegios por Módulo, ADR-007 — ActionCable sobre Polling HTTP (+64 more)

### Community 1 - "Backend Core: Modelos, Concerns y Autorización"
Cohesion: 0.07
Nodes (46): Ability (CanCanCan) — Autorización, Api::V1::BaseController, Scope: business_unit_filter, Concern: Auditable, Concern: Cacheable, Concern: Cuadrable, Concern: SequenceSynchronizable, Current (ActiveSupport::CurrentAttributes) (+38 more)

### Community 2 - "Auth Móvil, JWT y ActionCable"
Cohesion: 0.08
Nodes (40): Autenticación Móvil de Choferes (JWT), JWT de Chofer (Employee), ActionCable (WebSockets), Active Storage (S3), BusinessUnit (Unidad de Negocio), Concern: EmployeeStatsCalculable, Controller: Api::V1::EmployeeStatsController, Controller: Api::V1::Mobile::AuthController (+32 more)

### Community 3 - "Dominio TtpnBooking, Finanzas y PostgreSQL"
Cohesion: 0.12
Nodes (39): Análisis Exhaustivo del Modelo TtpnBooking, Catálogo Completo de Funciones PostgreSQL (32 funciones), Concepto: Cuadre Automático Bidireccional (Reservas ↔ Viajes), Dominio Finanzas: Nómina, Facturación y Contabilidad, Funciones PostgreSQL y Triggers de TtpnBooking, TravelCountsHelper (Ruby Helper), TtpnBookingsHelper (Ruby Helper), Migración Rails: CreatePostgresFunctionsAsignaciones (+31 more)

### Community 4 - "Tablas BE, Alertas, Swagger y Deploy"
Cohesion: 0.09
Nodes (32): ActionCable (WebSockets), Sistema de Alertas (AlertRule → Alert → AlertDelivery), Rswag / Swagger API Docs, Tabla travel_counts, Tabla ttpn_bookings, Servicio kumi_admin_api (Railway), Servicio kumi_sidekiq (Railway), Guía de Despliegue Railway (ttpngas) (+24 more)

### Community 5 - "Multi-tenancy, Vehículos y Combustible"
Cohesion: 0.1
Nodes (29): Modelo BusinessUnit: Multi-tenancy, Canal WebSocket: AlertsChannel, Concepto: Multi-tenancy via BusinessUnit + Current, Concern: Auditable, Concern: BusinessUnitAssignable, Dominio Combustible, Dominio Vehicles (Flotilla), Dominio Alertas: Reglas, Entregas y WebSocket (+21 more)

### Community 6 - "API Clientes, Auth Admin y Servicios TTPN"
Cohesion: 0.12
Nodes (28): API de Clientes (Clients), Swagger / rswag API Documentation Guide, Modelo User: Autenticación y Permisos, Concepto: Autenticación JWT con Devise + revocación por JTI, Sistema de Activación de Usuarios de Clientes, Arquitectura de Usuarios de Clientes (ClientUsers), Dominio Clientes, Dominio Servicios TTPN (+20 more)

### Community 7 - "Cuadre, TtpnBooking Model y Travel Counts"
Cohesion: 0.14
Nodes (23): Cuadrable (concern), Current (ActiveSupport::CurrentAttributes) — cuadre_in_progress flag, TravelCount (modelo Rails), TravelCountsController, TravelCountsHelper — busca_en_booking (SQL Nivel 2), TtpnBooking (modelo Rails), TtpnBookingPassenger (modelo Rails), TtpnBookingsHelper — busca_en_travel (SQL Nivel 2) (+15 more)

### Community 8 - "Deuda Técnica y Services de Bookings/Combustible"
Cohesion: 0.15
Nodes (20): BackfillTtpnBookingsJob (Sidekiq), Services Layer: TtpnBookings (2026-03-19), Services Layer: FuelPerformance (2026-03-19), Deuda Técnica: backfill_clvs Thread.new sin Sidekiq, Deuda Técnica: FilterPanel 2 páginas sin migrar, Deuda Técnica: Silent Catch Blocks (46 sin useNotify), Deuda Técnica README / Registro, DiscrepanciesPage.vue (+12 more)

### Community 9 - "Arquitectura Técnica, PRD y FilterPanel"
Cohesion: 0.14
Nodes (19): Tabla fleet_availability_snapshots, Tabla route_proposals, ADR-008 — Hardening de Seguridad 2026, ARQUITECTURA_TECNICA.md — Reescritura Completa, PRD.md — Product Requirements Document, FilterPanel — Componente y Composable Estándar de Filtros, FilterPanel.vue (componente), Limpieza SonarCloud P0 — console.* y archivos backup (2026-03-20) (+11 more)

### Community 10 - "Migraciones DB y Configuración Multi-tenancy"
Cohesion: 0.17
Nodes (16): api_keys + api_users (M2M auth), Multi-tenancy: business_unit_id en tablas operativas, CAMBIOS_DB — Registro histórico de cambios en BD, Heroku Rails (producción legacy), jti en users (revocación JWT), kumi_settings (configuración por BU), MIGRACION_DB — Guía Técnica Heroku a Supabase, Por qué migrar de PHP a Ruby on Rails API (+8 more)

### Community 11 - "Seguridad, Python Scripts y SQL Injection"
Cohesion: 0.14
Nodes (16): SEGURIDAD.md — Documentación de Seguridad, Integración Python dentro de Rails, dashboard/dashboard_data.py — Mirror Python de DashboardDataService, scripts/utils/db.py — PostgresClient, EjecutarScriptPythonJob — Puente Ruby→Python (Sidekiq), requirements.txt — Dependencias Python, scripts/ — Carpeta de Scripts Python, Command Injection Fix — backfill_clvs y EjecutarScriptPythonJob (+8 more)

### Community 12 - "API Keys, Infraestructura y Portal Base"
Cohesion: 0.22
Nodes (15): AI Provider: Groq (llama-3.3-70b-versatile), Infraestructura API — Kumi como Master Hub, Sistema de API Keys, Controller: Api::V1::Portal::BaseController, Endpoint: /api/v1/api_keys, Infraestructura: Docker Compose (local), Model: ApiKey, Model: SupplierUser (+7 more)

### Community 13 - "Auth Sessions, Gasolina y Nómina"
Cohesion: 0.2
Nodes (14): Auth::SessionsController, Eliminar IDs hardcodeados de roles y tipos de movimiento (2026-04-10), Services Layer: GasolineCharges y Auth::Sessions (2026-03-20), Services Layer: PayrollReports (2026-03-20), EmployeeMovementType (modelo), GasolineChargesController, Gasoline::EmployeeAssignment, Gasoline::StatsBuilder (+6 more)

### Community 14 - "Frontend: Captura de TtpnBookings"
Cohesion: 0.18
Nodes (13): BookingCaptureDeleteDialog.vue, BookingCaptureDetailDialog.vue, BookingCaptureFilters.vue, BookingCaptureImportDialog.vue, BookingCaptureMobileList.vue, BookingCaptureTable.vue, TtpnBookingsCapturePage Refactor, StatsBar.vue (+5 more)

### Community 15 - "Frontend: Dashboard y KPIs"
Cohesion: 0.29
Nodes (11): DashboardExportDialog.vue, DashboardKpiCards.vue, DashboardMatrixTable.vue, DashboardPage Refactor Plan, DashboardPage.vue, DashboardPeriodPanel.vue, DashboardRevenueTab.vue, DashboardTrendChart.vue (+3 more)

### Community 16 - "Stats Endpoints, Chat y N8N"
Cohesion: 0.29
Nodes (8): Api::V1::ChatController, Deuda Técnica: Kumi Chat (N8N + IA), GET /api/v1/booking_stats, GET /api/v1/client_stats, GET /api/v1/dashboard/summary, GET /api/v1/employee_stats, GET /api/v1/vehicle_stats, N8N Chat Workflow (clasificador Groq LLaMA 70B)

### Community 17 - "Dominio Configuración (KumiSetting)"
Cohesion: 0.29
Nodes (7): Configuración: Empleado, Configuración: Integraciones, Configuración: Organización, Configuración: Usuarios y Permisos, Configuración: Vehicular, Dominio Configuración: Sub-dominios del sistema, Modelo KumiSetting (Rails) — configuración clave-valor por BU

### Community 18 - "Python Scripts y Dashboard Data Service"
Cohesion: 0.6
Nodes (6): Job: EjecutarScriptPythonJob, Script: dashboard/dashboard_data.py, Script: reportes/contables.py, Python Scripts README, Service: DashboardDataService (Ruby), Util: PostgresClient (utils/db.py)

### Community 19 - "ActionCable Channels y Webhooks"
Cohesion: 0.5
Nodes (5): AlertsChannel — Canal de Alertas por Business Unit, JobStatusChannel — Canal ActionCable por Usuario, WebhooksController — Receptor de Webhooks Externos, boot/actioncable.js — Setup de ActionCable en Frontend, WebSockets, ActionCable y Webhooks

### Community 20 - "API Key/User Models y Testing"
Cohesion: 0.5
Nodes (5): ApiKey (modelo Rails), ApiUser (modelo Rails), Vehicle (modelo Rails), Estado de Tests — Vehículos y API Keys (snapshot dic 2025), Guía de Pruebas del Sistema de API Keys

### Community 21 - "N8N: Migración y Schema Supabase"
Cohesion: 1.0
Nodes (3): N8N Migración SQLite a Supabase PostgreSQL, N8N Service (Railway), Supabase Schema n8n

### Community 22 - "Frontend: Citas y Calendario"
Cohesion: 1.0
Nodes (2): Componente: AppointmentDialog.vue, Componentes de Calendario (Citas)

### Community 23 - "Supabase Fixes y Migración PostgreSQL"
Cohesion: 1.0
Nodes (2): Correcciones Supabase y SonarCloud (2026-03-17), Migration: fix_function_search_paths (search_path seguro en PG functions)

### Community 24 - "PRD Vehículos"
Cohesion: 1.0
Nodes (1): Vehicle (Vehículo de la Flotilla)

### Community 25 - "PRD Sistema de Alertas"
Cohesion: 1.0
Nodes (1): Sistema de Alertas (Alert + AlertRule + AlertDelivery)

### Community 26 - "Security Headers"
Cohesion: 1.0
Nodes (1): Security Headers (Rails + Netlify)

### Community 27 - "Patrón Serializer"
Cohesion: 1.0
Nodes (1): Patrón Serializer (minimal vs full)

### Community 28 - "Dominio Ruteo"
Cohesion: 1.0
Nodes (1): Dominio Ruteo: Rutas fijas de transporte de personal

### Community 29 - "N8N Chat Workflow"
Cohesion: 1.0
Nodes (1): N8N Workflow: kumi-chat.json

## Knowledge Gaps
- **148 isolated node(s):** `Sidekiq (Jobs en Background)`, `TtpnBooking (Programación de Servicio)`, `Payroll (Nómina de Choferes)`, `Discrepancy (Registros sin Cuadre)`, `KumiSetting (Configuración por BU)` (+143 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Frontend: Citas y Calendario`** (2 nodes): `Componente: AppointmentDialog.vue`, `Componentes de Calendario (Citas)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Supabase Fixes y Migración PostgreSQL`** (2 nodes): `Correcciones Supabase y SonarCloud (2026-03-17)`, `Migration: fix_function_search_paths (search_path seguro en PG functions)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `PRD Vehículos`** (1 nodes): `Vehicle (Vehículo de la Flotilla)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `PRD Sistema de Alertas`** (1 nodes): `Sistema de Alertas (Alert + AlertRule + AlertDelivery)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Security Headers`** (1 nodes): `Security Headers (Rails + Netlify)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Patrón Serializer`** (1 nodes): `Patrón Serializer (minimal vs full)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Dominio Ruteo`** (1 nodes): `Dominio Ruteo: Rutas fijas de transporte de personal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `N8N Chat Workflow`** (1 nodes): `N8N Workflow: kumi-chat.json`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Infraestructura API — Kumi como Master Hub` connect `API Keys, Infraestructura y Portal Base` to `Auth Móvil, JWT y ActionCable`, `API Clientes, Auth Admin y Servicios TTPN`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Why does `Railway (Plataforma de Deploy)` connect `Tablas BE, Alertas, Swagger y Deploy` to `API Keys, Infraestructura y Portal Base`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Why does `N8N Railway Deploy Guide` connect `API Keys, Infraestructura y Portal Base` to `Tablas BE, Alertas, Swagger y Deploy`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **What connects `Sidekiq (Jobs en Background)`, `TtpnBooking (Programación de Servicio)`, `Payroll (Nómina de Choferes)` to the rest of the system?**
  _148 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Decisiones de Arquitectura (ADRs)` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Backend Core: Modelos, Concerns y Autorización` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Auth Móvil, JWT y ActionCable` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._