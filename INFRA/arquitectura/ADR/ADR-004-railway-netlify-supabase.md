# ADR-004 — Railway + Netlify + Supabase en lugar de Heroku

**Fecha:** 2026-04-10  
**Estado:** En migración  
**Autor:** Antonio Castellanos

---

## Contexto

El stack actual en Heroku cuesta $371.88/mes. El dyno Performance-M ($252.88/mes) se usa principalmente porque Heroku duerme los dynos standard y la app necesita estar siempre disponible.

## Decisión

Migrar a:
- **Railway** — Rails API + Redis + Sidekiq + N8N
- **Netlify** — Frontend Quasar (gratuito para el volumen actual)
- **Supabase Pro** ($25/mes) — PostgreSQL (ya en uso, sin cambio)

Costo total estimado: ~$55-70/mes.

## Razones

Railway tiene pricing por compute real (`$0.000463/vCPU-min + $0.0000018/MB-min`) en lugar de dyno fijo. La app en reposo consume casi nada. No duerme procesos.

El frontend es estático (Quasar build → Netlify CDN) — no necesita servidor. Netlify tiene CDN global, deploys automáticos desde GitHub y SSL incluido.

Supabase ya es el motor de base de datos. Pro plan: $25/mes, no pausa, backups automáticos, 7 días de aviso antes de mantenimiento.

## Consecuencias

- Railway gestiona memoria con `puma_worker_killer` + Health Check en `/up` + Restart Policy automático, reemplazando el reset manual de dyno que se hacía en Heroku.
- El remote `heroku` sigue existente en el repositorio BE pero **no se usa para deploys**. El deploy va por `github` remote → Railway auto-deploy.
- N8N se agrega como servicio adicional en Railway (automatizaciones) conectado via `api_keys` M2M.
- Las apps legacy en Heroku (`ttpn.com.mx`, `tulpe.com.mx`, `pacific-river-53404`) suman $36/mes adicionales — se migran en una segunda fase.
- Ver análisis completo de costos en `INFRAESTRUCTURA_RAILWAY_NETLIFY_SUPABASE.md`.