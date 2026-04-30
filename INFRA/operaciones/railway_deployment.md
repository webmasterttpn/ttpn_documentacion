# Guía de Despliegue en Railway

Proceso para desplegar el backend **ttpngas** en Railway, conectado a Supabase y Redis.

**Rama en producción:** `transform_to_api`

---

## Fase 1: Preparación

Asegurarse de tener los últimos cambios pusheados:

```bash
git push github transform_to_api   # GitHub (Railway escucha aquí)
git push origin transform_to_api   # GitLab (mirror)
```

El `Dockerfile` ejecuta `rails db:prepare` automáticamente al iniciar.

---

## Fase 2: Servicios en Railway

El proyecto tiene 3 servicios en el lienzo de Railway:

| Servicio | Rama | Start command | Dominio público |
|---|---|---|---|
| **kumi_admin_api** (Web API) | `transform_to_api` | por defecto (Dockerfile) | Sí |
| **kumi_sidekiq** (Worker) | `transform_to_api` | `bundle exec sidekiq -c 10 -q default -q mailers` | No |
| **Redis** | — | gestionado por Railway | No |

---

## Fase 3: Variables de Entorno

Configurar en la pestaña **Variables** de cada servicio. Las sensibles van en el **Raw Editor**.

### Variables principales (kumi_admin_api y kumi_sidekiq)

```env
RAILS_ENV=production
RAILS_MAX_THREADS=5
RAILS_MASTER_KEY=[contenido de config/master.key]

DATABASE_URL=[URL de Supabase — Supabase → Project Settings → Database → URI]

REDIS_URL=${{Redis.REDIS_URL}}

FRONTEND_URL=https://kumi.ttpn.com.mx
FRONTEND_URL_EXTRA=https://kumi-admin-api-production.up.railway.app

AWS_ACCESS_KEY_ID=[ver rotacion_api_keys.md]
AWS_SECRET_ACCESS_KEY=[ver rotacion_api_keys.md]
AWS_REGION=us-east-2
AWS_BUCKET_NAME=ttpngas-production

RACK_TIMEOUT_SERVICE_TIMEOUT=25
RACK_TIMEOUT_WAIT_TIMEOUT=30
```

Para la lista completa de variables ver `ttpngas/.env.example`.

### Conectar Redis al Worker

En **Variables** de kumi_sidekiq:
- `REDIS_URL` → `${{Redis.REDIS_URL}}` (autocompletado interno de Railway)

Hacer lo mismo en kumi_admin_api para que la API web pueda encolar jobs.

---

## Fase 4: Migraciones

Railway ejecuta migraciones automáticamente via `db:prepare` en el Dockerfile.

Para correr migraciones manualmente desde local:

```bash
cd ttpngas/
railway run bundle exec rails db:migrate
```

---

## Fase 5: Generar dominio público

Settings → Networking → **Generate Domain** en el servicio kumi_admin_api.  
El Worker (Sidekiq) no necesita dominio público.

---

## Verificación post-deploy

- [ ] `GET /up` retorna 200
- [ ] Login en el frontend funciona
- [ ] Sidekiq procesando jobs (Railway Logs → kumi_sidekiq)
- [ ] ActionCable conecta (WebSockets en consola del browser sin errores)
- [ ] Upload de archivo a S3 funciona
