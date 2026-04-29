# N8N Setup Checklist — Kumi TTPN Admin

## Fase 1 — Local ✅ Completado

- [x] Carpeta `ttpn_n8n/` creada en el monorepo
- [x] `.env` con `N8N_ENCRYPTION_KEY`, `N8N_HOST`, `WEBHOOK_URL`
- [x] `.env.example` documentado
- [x] `.gitignore` (excluye `data/` y `.env`)
- [x] `docker-compose.yml` configurado con perfil `n8n`
- [x] Red `kumi_network` creada
- [x] Contenedor `kumi_n8n` corriendo en `:5678`
- [x] Repo `webmasterttpn/kumi-admin-n8n` en GitHub con commit inicial

---

## Fase 2 — Configuración inicial de N8N (local)

- [ ] Abrir http://localhost:5678
- [ ] Crear cuenta de administrador N8N (email + password)
- [ ] Guardar credenciales en gestor de contraseñas (son locales, no se sincronizan)
- [ ] Verificar que la pantalla principal de workflows carga sin errores

---

## Fase 3 — Conectar N8N con las fuentes de datos

N8N usa **dos conexiones** según el tipo de operación:

### 3A — Rails API (escrituras con lógica de negocio)

Usar cuando: crear bookings, rutas, importar capturas — operaciones que deben pasar por callbacks y validaciones de Rails.

- [ ] En el panel admin de Kumi → **Configuración → API Keys → Nueva clave**
  - Nombre: `N8N Automation`
  - Tipo: `service`
  - Copiar el token generado (solo se muestra una vez)
- [ ] En N8N → **Credentials → Add Credential**
  - Tipo: `Header Auth`
  - Name: `Kumi API Local`
  - Header Name: `Authorization`
  - Header Value: `Bearer <token>`
- [ ] Probar con HTTP Request node → GET `http://kumi_api:3000/api/v1/vehicles`
  - Respuesta esperada: `200 OK`

### 3B — Supabase directo (lecturas, reportes, alertas)

Usar cuando: reportes de combustible, alertas de rendimiento, notificaciones, dashboards — solo lectura o inserts simples sin lógica de negocio.

- [ ] En N8N → **Credentials → Add Credential**
  - Tipo: `Postgres` (o `Supabase` si usas el nodo nativo)
  - Name: `Kumi DB Local`
  - Host: `host.docker.internal` (desde Docker hacia PostgreSQL del host)
  - Port: `5432`
  - Database: `<nombre_db_desarrollo>`
  - User/Password: los de tu `.env` de ttpngas
- [ ] Probar con un nodo Postgres → `SELECT count(*) FROM ttpn_bookings`
  - Respuesta esperada: número de registros

> **Regla:** si la operación tiene callbacks en Rails (bookings, travel counts, rutas), usa la API. Si solo lees o escribes tablas simples (logs, reportes), usa Supabase/DB directo.

---

## Fase 4 — Primer workflow de prueba

- [ ] Crear workflow: **"Ping API"**
  - Trigger: Manual
  - Node: HTTP Request → GET `http://kumi_api:3000/api/v1/vehicles`
  - Credencial: `Kumi API Local`
  - Ejecutar y verificar respuesta exitosa
- [ ] Guardar y activar el workflow
- [ ] Verificar que aparece en la lista con estado `Active`

---

## Fase 5 — Despliegue en Railway

- [ ] Crear servicio N8N en Railway (ver `N8N_RAILWAY_DEPLOY.md`)
- [ ] Configurar variables de entorno en Railway
  - [ ] `N8N_ENCRYPTION_KEY` → mismo valor que `.env` local
  - [ ] `N8N_HOST` → subdominio asignado por Railway
  - [ ] `N8N_PORT` → `5678`
  - [ ] `N8N_PROTOCOL` → `https`
  - [ ] `WEBHOOK_URL` → `https://<subdominio>.up.railway.app/`
  - [ ] `N8N_RUNNERS_ENABLED` → `true`
- [ ] Crear volumen persistente en `/home/node/.n8n`
- [ ] Generar dominio público en Railway
- [ ] Verificar que N8N arranca: `https://<subdominio>.up.railway.app/healthz`
- [ ] Crear cuenta admin en N8N de producción
- [ ] Duplicar credencial `Kumi API` apuntando a la URL de producción del API

---

## Fase 6 — Workflows de producción (definir con el equipo)

### Vía Rails API (escritura con lógica)

- [ ] **Crear booking automático** — desde formulario externo o app móvil sin acceso directo al admin
- [ ] **Importar capturas masivas** — archivo CSV/Excel → `/api/v1/gasoline_charges/import`
- [ ] **Crear rutas programadas** — generar bookings recurrentes para clientes fijos

### Vía Supabase directo (lectura / reportes)

- [ ] **Notificación de viaje asignado** — poll cada N min sobre `ttpn_bookings` nuevos → WhatsApp/SMS al chofer
- [ ] **Reporte diario de combustible** — query sobre `gasoline_charges` del día → email al encargado
- [ ] **Alerta de rendimiento bajo** — query sobre `fuel_performance` cache o tabla → notificar si kmpl < umbral
- [ ] **Recordatorio de mantenimiento** — query sobre vehículos por kilometraje o fecha → alerta preventiva
- [ ] **Dashboard semanal** — reporte agregado de viajes, combustible y rendimiento → email ejecutivo

---

## Notas importantes

- Los workflows locales **no se sincronizan** automáticamente a Railway — se exportan manualmente (JSON) e importan en producción
- `N8N_ENCRYPTION_KEY` debe ser **idéntica** en local y producción para poder reutilizar credenciales exportadas
- Dentro de Docker, la API se llama por nombre de contenedor: `http://kumi_api:3000`
- En Railway, usar la URL pública del API: `https://<api-subdominio>.up.railway.app`
