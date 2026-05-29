# Carpeta MIGRACION

Documentación completa para migrar, mantener y auditar la base de datos de Kumi V2.

## Documentos

| Archivo | Propósito |
| --- | --- |
| [PASOS_TRAS_MIGRACION.md](PASOS_TRAS_MIGRACION.md) | **Runbook único del cutover**: 9 pasos en orden estricto (db:migrate, backfills, CLV REBUILD, SQL timezone, SQL retroactivo cuadre, reset_sequences). Leer este primero. |
| [MIGRACION_DB.md](MIGRACION_DB.md) | Guía técnica: Heroku → Supabase, backfills por columna, enfoque CSV para tablas grandes |
| [CAMBIOS_DB.md](CAMBIOS_DB.md) | Registro histórico de todos los cambios en BD desde `transform_to_api`. **Actualizar con cada migración relevante.** |

## Regla de mantenimiento

Cada vez que se cree una migración que:
- Agrega una tabla nueva
- Agrega columnas con impacto en multi-tenancy o seguridad
- Requiere backfill de datos existentes
- Crea funciones o triggers PostgreSQL

→ Agregar una entrada en `CAMBIOS_DB.md` con fecha, migración, descripción y SQL de backfill si aplica.
