# Pasos y Tareas Tras la Migración a Producción (Kumi V2)

Este documento es una lista de verificación (checklist) crítica para ejecutar inmediatamente después de restaurar o migrar la Base de Datos a producción. Durante el desarrollo de la rama `transform_to_api`, construimos tablas y dependencias obligatorias (Business Units, Control de Privilegios y Auditoría de usuarios). Por tanto, la Base de Datos vieja fallará ante el nuevo backend si no "rellenamos" o "purgamos" estas dependencias huérfanas o valores nulos introducidos.

Para que no batalles con accesos a la Nube, **hemos creado 4 comandos remotos `cURL`** que puedes copiar y pegar de forma independiente desde la terminal de tu computadora local (VSCode/Mac) después de subir el código y migrar la base. Tu servidor de Railway los ejecutará automáticamente.

---

## 1. Asignación de Usuarios Raíz y Unidades de Negocio (Tablas Nuevas)

Al dividir la API, se agregaron `business_unit_id`, `created_by_id` y `updated_by_id` a decenas de tablas como validaciones estrictas de trazabilidad y multi-tenancy. La base vieja los tendrá nulos (`nil`). Este proceso asocia los registros viejos a tu Unidad de Negocio Principal y al Usuario Administrador raíz en todos los catálogos.

**Ejecutar para rellenar (cURL):**

```bash
curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-d '{"task": "backfill_tables"}'
```

---

## 2. Separador de Concesionarios (Campos Apellidos Nuevos)

Antes, el catálogo de concesionarios usaba un solo campo `nombre`. Ahora emplea `a_paterno` y `a_materno`. Este analizador de texto barre los cientos de registros y los fragmenta automáticamente depositándolos en sus columnas correctas.

**Ejecutar para fragmentar (cURL):**

```bash
curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-d '{"task": "concessionaires"}'
```

_(Si prefieres hacerlo dentro de Railway: `bin/rails concessionaires:split_names`)_

---

## 3. Inicializar Módulos de Operaciones y Privilegios (Rol Administrativo)

Al crearse las barreras de autenticación nuevas, se introdujo el concepto de "Privilegios Dinámicos" y Configuraciones Globales de Nómina (`KumiSettings`). Esta rutina inyecta a la Base de Datos los permisos esenciales para cada ventana web creada recientemente y le otorga acceso universal a tu Rol de Sistemas / Administrador para que no te bloquees fuera de las nuevas pantallas.

**Ejecutar configuración (cURL):**

```bash
curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-d '{"task": "setup_modules"}'
```

---

## 4. Recálculo Automático de Llaves de Servicio (CLVs del Excel)

Modificamos la forma en que el Backend construye las llaves largas y llaves de cuadre masivo (`clv_servicio_completa`) conectándolas por guiones con hasta con segundos de precisión. Los viajes importados viejos no las tienen. Este escáner revisa los últimos días que indiques y estampa el código en la Base a quienes carezcan del mismo.

**Ejecutar para sanar inventario (cURL):**

```bash
curl -X POST https://kumi-api.up.railway.app/api/v1/ttpn_bookings/backfill_clvs \
-H "Content-Type: application/json" \
-d '{"days": 30}'
```

_(Puedes correrlo varias veces y no duplicará datos. Si quieres cambiar el barrido histórico masivo de tu empresa pon `"days": 365` o el número que prefieras)._

---

## 5. ¡Ahorrar Tiempo! 👉 Comando TODO-EN-UNO (Master)

Si tu base recién fue migrada de volverse a volcar intacta y necesitas purgar _todo el texto_, _rellenar tablas_, y _crear privilegios_ al mismo tiempo sin correr uno por uno los puntos 1, 2 y 3, puedes simplemente dispararlos en cadena:

```bash
curl -X POST https://kumi-api.up.railway.app/api/v1/system_maintenance/run_tasks \
-H "Content-Type: application/json" \
-d '{"task": "all"}'
```

_(Nota: El paso de los viajes #4 CLVs se corre por separado pues ese acepta parámetros únicos dependiente los días)._

---

### Detalles Adicionales para Validar Tras estas Tareas

1. **Revisar Lista Negra (Blacklists):**
   Los clientes creados exclusivamente como `black_list = true` (del match con Android/Firebase) utilizarán los nuevos campos `full_name` rápido en lugar de atarte un catálogo pesado de flotillas. En API V1 estos retornos serán simplificados (Ver `documentacion/CAMBIOS_API_ANDROID.md` para detalle técnico de este rubro).

2. **Origen de Viajes:**
   Al descargar reportes, `creation_method` dirá cómo nacieron: `"manual"`, `"imported"` o `"cloned"`.

3. **Purga de Fallas (Reinicio Cargas Excel):**
   Si la primera camada de pasajes da error visual, recuerda que la Base pura respeta el archivo. Borra desde el Frontend esos viajes de prueba usando el check de selección múltiple, y tras re-importar, la herramienta `QPs` (passenger_qty) respetará a hierro los conteos físicos de Excel reales.
