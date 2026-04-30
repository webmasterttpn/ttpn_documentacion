# Proceso de Rotación Semestral de API Keys

**Frecuencia:** Cada 6 meses  
**Responsable:** Administrador del sistema  
**Tiempo estimado:** 1–2 horas

---

## Qué rotar y cómo

### 1. AWS IAM — Acceso a S3 (Active Storage)

Variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

1. AWS Console → IAM → Users → usuario de Kumi → Security credentials
2. Crear nueva Access Key
3. Actualizar en Railway (kumi_admin_api): `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`
4. Verificar que el upload de archivos funciona en producción
5. Desactivar la key anterior en AWS IAM (esperar 24h) → eliminarla

---

### 2. Secret Key Base — Firma de sesiones Rails

Variable: `SECRET_KEY_BASE`

> ⚠️ Rotar esta key invalida todas las sesiones activas. Los usuarios deberán volver a hacer login.

1. Generar nuevo valor: `openssl rand -hex 64`
2. Actualizar en Railway: `SECRET_KEY_BASE`
3. Redeploy automático en Railway al guardar la variable

---

### 3. JWT Secret — Firma de tokens de acceso

Variable: `DEVISE_JWT_SECRET_KEY`

> ⚠️ Rotar esta key invalida todos los JWT activos. Los usuarios deberán volver a hacer login.

1. Generar nuevo valor: `openssl rand -hex 64`
2. Actualizar en Railway: `DEVISE_JWT_SECRET_KEY`
3. Redeploy automático en Railway

---

### 4. WhatsApp — Token de API y Webhook Secret

Variables: `WHATSAPP_API_TOKEN`, `WHATSAPP_WEBHOOK_SECRET`, `WHATSAPP_VERIFY_TOKEN`

1. Meta Business Manager → WhatsApp → configuración de la app
2. Generar nuevo token de sistema
3. Actualizar `WHATSAPP_API_TOKEN` en Railway
4. Si se rota el webhook secret: actualizarlo también en Meta Business Manager y en Railway (`WHATSAPP_WEBHOOK_SECRET`)

---

### 5. Webhook Secret Genérico

Variable: `WEBHOOK_SECRET_GENERIC`

1. Generar nuevo valor: `openssl rand -hex 32`
2. Actualizar en Railway y en el sistema externo que lo usa
3. Verificar que los webhooks siguen llegando correctamente

---

### 6. ApiKeys en Base de Datos (N8N y apps externas)

Registros en tabla `api_keys` — gestionados desde el admin de Kumi.

1. Kumi Admin → Configuración → API Keys
2. Para cada key activa: usar "Regenerar" → copiar el nuevo valor
3. Actualizar el nuevo valor en el sistema externo correspondiente (N8N credential manager, etc.)
4. Verificar que la integración sigue funcionando

---

### 7. N8N Encryption Key

Variable: `N8N_ENCRYPTION_KEY` (en el servicio N8N de Railway, no en kumi_admin_api)

> ⚠️ Rotar esta key sin migrar las credenciales encriptadas rompe todos los workflows de N8N.  
> Solo rotar si hay una brecha de seguridad confirmada y con plan de re-encriptación.

Proceso especial — consultar documentación de N8N antes de rotar.

---

## Checklist de cierre

Después de rotar todo, verificar:

- [ ] Upload de archivos a S3 funciona (documentos de vehículos/empleados)
- [ ] Login de usuarios en producción funciona
- [ ] WebSockets (ActionCable) conectan correctamente
- [ ] Webhooks de WhatsApp llegan y se procesan
- [ ] N8N ejecuta sus workflows sin errores
- [ ] ApiKeys externas autenticadas correctamente
- [ ] Keys anteriores de AWS IAM desactivadas/eliminadas
- [ ] Registrar fecha de rotación al final de este documento

---

## Tareas únicas pendientes (no recurrentes)

- [ ] **RLS**: Ejecutar `rls_policies.sql` en Supabase (dev y prod) — ver `INFRA/seguridad/rls_policies.sql`
- [x] **AWS credentials**: Rotadas en IAM y Supabase (2026-04-29) — credenciales expuestas en historial de git por `RAILWAY_STAGING_DEPLOYMENT_GUIDE.md`

---

## Historial de rotaciones

| Fecha      | Responsable | Keys rotadas                   | Notas                                                          |
|------------|-------------|--------------------------------|----------------------------------------------------------------|
| 2026-04-29 | Antonio     | AWS IAM + Supabase DB password | Rotación de emergencia — credenciales expuestas en git history |
