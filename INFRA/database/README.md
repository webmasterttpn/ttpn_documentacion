# INFRA — Base de Datos

Documentación del esquema global de la base de datos PostgreSQL de Kumi TTPN Admin.

---

## ERD Global

El diagrama entidad-relación se genera automáticamente con `rails-erd` leyendo los modelos ActiveRecord y sus asociaciones.

### Requisitos

```bash
# macOS
brew install graphviz

# Docker / Debian-Ubuntu
apt-get install -y graphviz

# Gem (ya en Gemfile grupo :development)
cd ttpngas && bundle install
```

### Generar el ERD

```bash
# Dentro del container (graphviz está ahí)
docker compose --profile backend run --rm api bash -c "mkdir -p tmp && bundle exec erd"
# → genera ttpngas/tmp/ERD.pdf

# Mover al destino final
mv ttpngas/tmp/ERD.pdf Documentacion/INFRA/database/ERD.pdf
```

La configuración vive en [ttpngas/.erdconfig](../../../ttpngas/.erdconfig):

| Opción | Valor | Descripción |
|---|---|---|
| `notation` | `crowsfoot` | Notación crow's foot (1-a-muchos visual) |
| `orientation` | `horizontal` | Diagrama horizontal (más legible con muchas tablas) |
| `attributes` | content, PKs, FKs, timestamps | Columnas visibles por tabla |
| `filetype` | `pdf` | Formato de salida |
| `filename` | `../Documentacion/INFRA/database/ERD` | Ruta de salida relativa a `ttpngas/` |

### Cuándo regenerar

- Al agregar un modelo nuevo
- Al agregar/eliminar asociaciones (`belongs_to`, `has_many`, `has_one`)
- Al ejecutar migraciones que agregan FKs

---

## Estructura de dominios en BD

| Dominio | Tablas principales | Relación clave |
|---|---|---|
| Auth | `users`, `business_units` | User → BusinessUnit |
| Employees | `employees`, `employee_movements` | Employee → BusinessUnit |
| Vehicles | `vehicles`, `vehicle_documents` | Vehicle → BusinessUnit |
| Bookings | `ttpn_bookings`, `travel_counts` | TtpnBooking → Client, Employee, Vehicle |
| Clientes | `clients` | Client → BusinessUnit |
| Combustible | `gas_charges`, `gas_files` | GasCharge → Vehicle, GasStation |
| Finanzas | `payrolls`, `employee_salaries` | Payroll → Employee |
| Configuración | `kumi_settings`, `roles`, `privileges` | Role → BusinessUnit |
| Alertas | `alerts`, `alert_rules`, `alert_deliveries` | Alert → Employee |
| Ruteo | `cr_days`, `crd_hrs`, `crdh_routes` | CrdhRoute → Employee, Vehicle |

---

## Convenciones de esquema

- PK: `id bigint` (serial), nunca UUID
- FK: `<tabla_singular>_id bigint not null` + índice obligatorio
- Soft delete: columna `status boolean default true` (no se borra físicamente)
- Timestamps: `created_at`, `updated_at` en todas las tablas operativas
- Auditoría: `created_by_id`, `updated_by_id` en tablas que requieren trazabilidad
- Multi-tenant: `business_unit_id` en todas las tablas operativas con RLS pendiente
- Nombres: `snake_case`, plural para tablas, singular para modelos

---

## ERD por dominio

Cada dominio tiene su propio esquema en texto en `Backend/dominio/<dominio>/model.md`.
El ERD global (PDF) es la fuente visual de verdad para relaciones cross-dominio.

---

## Ver también

- [ARQUITECTURA_TECNICA.md](../arquitectura/ARQUITECTURA_TECNICA.md) — stack, decisiones de infraestructura
- [ADR-002 — Triggers PG para cuadre](../arquitectura/ADR/ADR-002-triggers-pg-para-cuadre.md) — lógica de cuadre en BD
- [Backend/dominio/](../../Backend/dominio/) — documentación por dominio con campos y validaciones
- [INFRA/seguridad/SEGURIDAD.md](../seguridad/SEGURIDAD.md) — RLS pendiente sobre estas tablas
