# Documentación — Kumi TTPN Admin V2

Fuente única de verdad para toda la documentación técnica del proyecto.  
Este repositorio se entrega al cliente como `ttpn_documentacion` (repo privado independiente).

> La carpeta `_archivo/` contiene notas internas y no se incluye en la entrega al cliente.

---

## Estructura

```
Documentacion/
├── INFRA/           → Infraestructura, arquitectura, base de datos, seguridad, onboarding, operaciones
├── Backend/         → API Rails: dominio, servicios, testing, integraciones
├── Frontend/        → Vue/Quasar: componentes, patrones, páginas, integraciones
├── Manuales/        → Manuales de usuario final (con capturas)
├── N8N/             → Automatización: setup, deploy, credenciales
├── Proyectos/       → PRDs y manuales de proyectos satélite (portal de proveedores, etc.)
└── _archivo/        → Notas internas (NO incluir en entrega al cliente)
```

---

## INFRA

| Documento | Descripción |
| --- | --- |
| [PRD.md](INFRA/PRD.md) | Product Requirements Document — visión y alcance |
| [arquitectura/](INFRA/arquitectura/) | ADRs, arquitectura técnica, multi-tenant |
| [infraestructura/](INFRA/infraestructura/) | Deploy, Railway, Netlify, Supabase, staging |
| [seguridad/](INFRA/seguridad/) | RLS, CORS, security headers, checklist producción |
| [onboarding/](INFRA/onboarding/) | Guía de desarrollador, setup BE/FE, nueva app, [workflow Git](INFRA/onboarding/WORKFLOW_GIT.md) |
| [operaciones/](INFRA/operaciones/) | Runbook de incidentes |
| [database/](INFRA/database/) | ERD global (rails-erd), convenciones de esquema, migraciones críticas |
| [Integraciones/](INFRA/Integraciones/) | Integraciones externas — Samsara (GPS/telemática): contexto, mapeo a Kumi e ideas |

---

## Backend

| Documento | Descripción |
| --- | --- |
| [api/](Backend/api/) | Auth móvil, API Keys, Swagger, endpoints de clientes |
| [dominio/](Backend/dominio/) | Modelos, controllers, stats por dominio de negocio |
| [scripts/](Backend/scripts/) | Scripts Python: dashboard, reportes contables |
| [testing/](Backend/testing/) | Estado de tests, guía pruebas API Keys |
| [integracion/](Backend/integracion/) | Python + Sidekiq, webhooks entrantes |

### Dominios de negocio (`Backend/dominio/`)

| Dominio | Modelos principales |
| --- | --- |
| `employees/` | Employee, EmployeeMovement, stats RR.HH. |
| `vehicles/` | Vehicle, VehicleDocument |
| `bookings/` | TtpnBooking, TravelCount |
| `clientes/` | Client y relacionados |
| `proveedores/` | Supplier, GasStation, Concessionaire |
| `combustible/` | GasCharge, GasFile |
| `servicios_ttpn/` | TtpnService, TtpnServiceType, TtpnServicePrice |
| `finanzas/` | Payroll, EmployeeSalary, Invoicing |
| `ruteo/` | CrDay, CrdHr, CrdhRoute, paradas |
| `alertas/` | Alert, AlertRule, AlertDelivery |
| `mantenimiento/` | Mtto::Product, Mtto::Inventory, Mtto::WorkOrder (Control de Inventario de Taller) |
| `configuracion/` | KumiSetting, Role, Privilege |
| `auth/` | User, BusinessUnit |

---

## Frontend

| Documento | Descripción |
| --- | --- |
| [componentes/](Frontend/componentes/) | Componentes reutilizables: AppTable, modals, selector BU |
| [patrones/](Frontend/patrones/) | Búsquedas, tabs anidados, sistema de privilegios |
| [paginas/](Frontend/paginas/) | Páginas por dominio: bookings, dashboard, employees, vehicles, gas, settings, clientes, ruteo, finanzas, alertas |
| [integraciones/](Frontend/integraciones/) | Importación Excel y otras integraciones |

---

## Manuales de usuario

| Documento | Descripción |
| --- | --- |
| [mantenimiento/manual_usuario.md](Manuales/mantenimiento/manual_usuario.md) | Manual del módulo de Mantenimiento (Control de Inventario de Taller) con capturas — incluye recepción **pieza vs. líquido** y costo hundido |

---

## N8N

| Documento | Descripción |
| --- | --- |
| [setup/](N8N/setup/) | Checklist de configuración inicial |
| [deploy/](N8N/deploy/) | Deploy en Railway |
| [credenciales/](N8N/credenciales/) | Gestión de credenciales y testing |

---

## Proyectos satélite

Proyectos nuevos que extienden Kumi y se documentan a parte (PRD,
manuales para developers, prompts de mockup, flujos).

| Proyecto | Descripción |
| --- | --- |
| [Proveedores/](Proyectos/Proveedores/) | Portal de Proveedores TTPN — PWA nueva para que proveedores gestionen sus facturas; extensiones BE/FE en Kumi. Incluye PRD, manuales BE/FE/Docker/Supabase, kumi_admin_changes, 7 flujos, seguridad, troubleshooting |

---

## Cómo agregar documentación

1. Identificar la carpeta correcta según el tipo de artefacto (tabla arriba).
2. Crear el archivo `.md` siguiendo el nombre del dominio o componente.
3. Si el dominio no existe en `Backend/dominio/`, crear la carpeta y registrarla aquí.
4. No crear documentación en los repos individuales (`ttpngas/`, `ttpn-frontend/`) — **siempre aquí**.
