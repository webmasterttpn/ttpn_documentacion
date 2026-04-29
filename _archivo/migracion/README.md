# Carpeta MIGRACION

Documentación completa para migrar, mantener y auditar la base de datos de Kumi V2.

## Documentos

| Archivo | Propósito |
| --- | --- |
| [PLAN_PRODUCCION.md](PLAN_PRODUCCION.md) | **Playbook completo de cutover** a producción: pre-vuelo, backup, restore, backfill, verificación, rollback |
| [MIGRACION_DB.md](MIGRACION_DB.md) | Guía técnica: Heroku → Supabase, backfills por columna, enfoque CSV para tablas grandes |
| [CAMBIOS_DB.md](CAMBIOS_DB.md) | Registro histórico de todos los cambios en BD desde `transform_to_api`. **Actualizar con cada migración relevante.** |
| [PASOS_TRAS_MIGRACION.md](PASOS_TRAS_MIGRACION.md) | Comandos cURL de tareas post-restauración (backfill_tables, setup_modules, concessionaires, clvs) |

## Regla de mantenimiento

Cada vez que se cree una migración que:
- Agrega una tabla nueva
- Agrega columnas con impacto en multi-tenancy o seguridad
- Requiere backfill de datos existentes
- Crea funciones o triggers PostgreSQL

→ Agregar una entrada en `CAMBIOS_DB.md` con fecha, migración, descripción y SQL de backfill si aplica.
