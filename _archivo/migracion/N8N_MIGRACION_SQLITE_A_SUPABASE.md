# N8N — Migración SQLite → Supabase PostgreSQL

> Entorno: **pruebas** (Railway N8N + Supabase del proyecto Kumi)
> Fecha: 2026-04-17

---

## ¿Qué hace esto?

N8N usa SQLite por defecto para guardar workflows, credenciales e historial de ejecuciones.
Al migrar a Supabase:
- Los datos sobreviven cualquier redeploy o reinicio en Railway
- El historial de ejecuciones queda centralizado con el resto de los datos del proyecto
- Puedes consultar workflows y logs directamente desde SQL si lo necesitas

**Importante:** SQLite **no se migra automáticamente**. El proceso es:
exportar todo manualmente → cambiar DB → reimportar. En pruebas esto toma ~15 minutos.

---

## Requisitos antes de empezar

- [ ] Tienes acceso al dashboard de Railway del proyecto Kumi → `https://railway.app`
- [ ] Tienes acceso al dashboard de Supabase del proyecto Kumi → `https://supabase.com/dashboard`
- [ ] N8N está corriendo en Railway (aunque sea con SQLite)
- [ ] Tienes a la mano la URL de tu N8N en Railway (algo como `https://n8n-xxxx.up.railway.app`)

---

## FASE 1 — Backup: exportar todo desde N8N actual

> Antes de tocar nada, exporta todo. Son 2 minutos.

### 1.1 Exportar workflows

- [ ] Abre tu N8N: `https://<tu-subdominio>.up.railway.app`
- [ ] En el menú izquierdo haz click en **Workflows**
- [ ] Por cada workflow que tengas:
  - Haz click en el nombre del workflow para abrirlo
  - En la esquina superior derecha busca el menú de tres puntos `⋮` o el botón de menú
  - Selecciona **Download** — se descarga un archivo `.json`
  - Guárdalo en una carpeta en tu escritorio (ej: `~/Desktop/n8n-backup/`)
- [ ] Repite hasta tener un `.json` por cada workflow

### 1.2 Anotar credenciales configuradas

Las credenciales **no se pueden exportar** — están cifradas dentro de N8N. Anótalas manualmente para reconfigurarlas después.

- [ ] En N8N, menú izquierdo → **Credentials**
- [ ] Para cada credencial que veas, anota en papel o en notas privadas:

  | Nombre en N8N | Tipo | Qué necesitarás reingresar |
  |---|---|---|
  | Kumi API | Header Auth | Token de API Key de Kumi |
  | Kumi DB | Postgres | Host, usuario, contraseña |
  | _(otras que tengas)_ | | |

> En pruebas es normal tener pocas o ninguna credencial todavía. Si no tienes ninguna, salta al paso siguiente.

---

## FASE 2 — Preparar Supabase

> Todo el trabajo de esta fase se hace en el **SQL Editor de Supabase**.
> El SQL Editor corre siempre sobre la base de datos `postgres` (la única BD del proyecto).
> Los schemas son como "carpetas" dentro de esa BD — no afectan las tablas de Rails.

### Cómo abrir el SQL Editor

1. Ve a `https://supabase.com/dashboard`
2. Selecciona tu proyecto Kumi
3. En el menú izquierdo busca el ícono de base de datos o directamente **SQL Editor**
4. Verás un editor de texto donde puedes escribir y ejecutar SQL
5. Para ejecutar: pega el código → click en el botón **Run** (o `Ctrl+Enter` / `Cmd+Enter`)

> El SQL Editor siempre ejecuta en la base de datos del proyecto. No necesitas seleccionar un schema — el schema va dentro del mismo SQL que escribes.

---

### 2.1 Crear schema dedicado para N8N

N8N va a crear ~15 tablas propias (`execution_entity`, `workflow_entity`, `credentials_entity`, etc.).
Para que no se mezclen con las tablas de Rails (que están en el schema `public`), creamos un schema separado llamado `n8n`.

**Piénsalo como crear una carpeta nueva dentro de la BD.**

- [ ] Abre el **SQL Editor** de Supabase (instrucciones arriba)
- [ ] Pega este código y click **Run**:

  ```sql
  CREATE SCHEMA IF NOT EXISTS n8n;
  ```

- [ ] Debe aparecer el mensaje: `Success. No rows returned`
- [ ] Verifica que el schema se creó correctamente:
  - En el menú izquierdo de Supabase haz click en **Table Editor**
  - En la parte superior izquierda del Table Editor hay un selector de schema (dice `public` por defecto)
  - Haz click ahí — debe aparecer `n8n` en la lista desplegable

  > Si `n8n` no aparece en esa lista, el schema no se creó. Regresa al SQL Editor y vuelve a ejecutar el comando.

---

### 2.2 Crear usuario PostgreSQL dedicado para N8N

No vamos a usar el usuario `postgres` (que es superadmin y tiene acceso a todo) para N8N.
Creamos un usuario nuevo `n8n_user` que **solo puede tocar el schema `n8n`** — nada de las tablas de Rails.

- [ ] Abre el **SQL Editor** de Supabase
- [ ] **Primero cambia la contraseña en el código antes de ejecutar** — reemplaza `CambiaEstaPassword123!` por una contraseña real tuya
- [ ] Pega todo este bloque junto y click **Run** (se ejecutan todos los comandos de una vez):

  ```sql
  -- 1. Crear el usuario (cambia la contraseña)
  CREATE USER n8n_user WITH PASSWORD 'CambiaEstaPassword123!';

  -- 2. Permitirle entrar al schema n8n
  GRANT USAGE ON SCHEMA n8n TO n8n_user;

  -- 3. Permitirle crear tablas dentro del schema n8n
  --    (N8N necesita crear sus propias tablas al arrancar)
  GRANT CREATE ON SCHEMA n8n TO n8n_user;

  -- 4. Permisos sobre tablas que ya existan en n8n (por si acaso)
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA n8n TO n8n_user;

  -- 5. Permisos automáticos sobre tablas FUTURAS en n8n
  --    (esto es clave: cada vez que N8N cree una tabla nueva, n8n_user tendrá acceso)
  ALTER DEFAULT PRIVILEGES IN SCHEMA n8n GRANT ALL ON TABLES TO n8n_user;

  -- 6. Permisos sobre secuencias (para IDs autoincrementales)
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA n8n TO n8n_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA n8n GRANT ALL ON SEQUENCES TO n8n_user;
  ```

- [ ] Debe aparecer el mensaje: `Success. No rows returned` (o múltiples líneas de éxito)
- [ ] Verifica que el usuario se creó: ejecuta esta consulta en el SQL Editor:

  ```sql
  SELECT usename FROM pg_user WHERE usename = 'n8n_user';
  ```

  Debe devolver una fila con el valor `n8n_user`. Si no devuelve nada, el usuario no se creó.

> **¿Por qué no usar el usuario `postgres`?**
> El usuario `postgres` tiene acceso a todas las tablas de Rails. Si alguien obtuviera esas credenciales tendría acceso a toda la base de datos. `n8n_user` solo puede tocar el schema `n8n` — el daño posible queda aislado.

---

### 2.3 Obtener los datos de conexión de Supabase

Aquí obtienes el "host" y demás datos que necesitará Railway para conectarse.

- [ ] En Supabase, menú izquierdo → click en el ícono de engranaje ⚙️ **Project Settings**
- [ ] En el submenú que aparece, click en **Database**
- [ ] Busca la sección **Connection parameters**
- [ ] Verás dos pestañas: **Session mode** y **Transaction mode** — selecciona **Session mode**

  > **¿Por qué Session mode y no Transaction mode?**
  > N8N necesita conexiones persistentes ("session") y usa una función de PostgreSQL llamada `LISTEN/NOTIFY`. El Transaction mode (puerto 6543) no soporta eso. Si usas el puerto 6543, N8N fallará de formas extrañas.

- [ ] Anota estos valores (los vas a necesitar en la Fase 3):

  | Dato | Dónde está en Supabase | Ejemplo de cómo se ve |
  |---|---|---|
  | **Host** | Campo "Host" | `db.abcdefghijkl.supabase.co` |
  | **Port** | Campo "Port" | `5432` |
  | **Database** | Campo "Database name" | `postgres` |
  | **User** | Escribe: `n8n_user` | `n8n_user` |
  | **Password** | La que pusiste en 2.2 | `CambiaEstaPassword123!` |

  > El Host es único por proyecto — tiene una cadena larga de letras en el medio (ej: `abcdefghijkl`). Eso es el ID de tu proyecto Supabase. Cópialo exactamente.

---

## FASE 3 — Configurar Railway

### 3.1 Agregar variables de entorno en el servicio N8N

- [ ] Abre `https://railway.app` → tu proyecto Kumi
- [ ] Haz click en el servicio que se llama **n8n** (o como lo hayas llamado)
- [ ] En la parte superior, haz click en la pestaña **Variables**
- [ ] Para cada variable de la tabla de abajo: click en **+ New Variable**, escribe el nombre, escribe el valor, Enter

  | Variable | Valor exacto a poner |
  |---|---|
  | `DB_TYPE` | `postgresdb` |
  | `DB_POSTGRESDB_HOST` | El host que anotaste en 2.3 (ej: `db.abcdefghijkl.supabase.co`) |
  | `DB_POSTGRESDB_PORT` | `5432` |
  | `DB_POSTGRESDB_DATABASE` | `postgres` |
  | `DB_POSTGRESDB_USER` | `n8n_user` |
  | `DB_POSTGRESDB_PASSWORD` | La contraseña que pusiste en 2.2 |
  | `DB_POSTGRESDB_SCHEMA` | `n8n` |
  | `DB_POSTGRESDB_SSL_ENABLED` | `true` |
  | `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED` | `false` |

  > **Errores comunes al ingresar el host:**
  > - ❌ `https://db.abcdefghijkl.supabase.co` — no lleva `https://`
  > - ❌ `db.abcdefghijkl.supabase.co/` — no lleva `/` al final
  > - ✅ `db.abcdefghijkl.supabase.co` — solo el dominio, sin más

- [ ] Verifica que las variables que ya tenías siguen ahí y NO las cambies:

  | Variable | Debe seguir igual |
  |---|---|
  | `N8N_ENCRYPTION_KEY` | No tocar — si cambia, N8N no podrá leer credenciales guardadas |
  | `N8N_HOST` | Tu subdominio de Railway |
  | `WEBHOOK_URL` | `https://<tu-subdominio>.up.railway.app/` |
  | `N8N_PROTOCOL` | `https` |
  | `N8N_PORT` | `5678` |
  | `N8N_RUNNERS_ENABLED` | `true` |
  | `NODE_ENV` | `production` |

### 3.2 Forzar redeploy

Railway no redeploya automáticamente solo por cambiar variables (en algunos casos sí, en otros no). Para asegurarte:

- [ ] Estando en el servicio n8n → click en la pestaña **Deployments**
- [ ] Busca el botón **Deploy** o en el último deployment activo haz click en los tres puntos `...` → **Redeploy**
- [ ] Espera ~2 minutos hasta que aparezca el indicador verde de "Active"

---

## FASE 4 — Verificar que N8N arrancó con Supabase

### 4.1 Revisar los logs del deploy

- [ ] En Railway → servicio n8n → pestaña **Logs**
- [ ] Espera a que aparezcan logs nuevos (del deploy reciente)
- [ ] Busca estas líneas — son señal de que funcionó:
  ```
  Initializing n8n process
  Database connection established
  n8n ready on 0.0.0.0, port 5678
  ```

- [ ] Si en cambio ves algo como esto, hay un error de conexión:
  ```
  Error: connect ECONNREFUSED
  Error: password authentication failed for user "n8n_user"
  Error: schema "n8n" does not exist
  ```
  → Ve directamente a la sección **Troubleshooting** al final del documento.

### 4.2 Verificar que N8N creó sus tablas en Supabase

N8N crea sus propias tablas automáticamente la primera vez que se conecta a una BD nueva.

- [ ] Abre Supabase → **Table Editor**
- [ ] Haz click en el selector de schema (dice `public` por defecto, arriba a la izquierda)
- [ ] Selecciona `n8n`
- [ ] Deben aparecer tablas como estas (entre 10 y 20 en total):
  - `workflow_entity`
  - `credentials_entity`
  - `execution_entity`
  - `execution_data`
  - `settings`
  - `user`
  - `variables`

  > Si el schema `n8n` aparece vacío (sin tablas), N8N no pudo conectarse correctamente. Revisa los logs del paso 4.1.

### 4.3 Verificar health check

- [ ] Abre en el navegador:
  ```
  https://<tu-subdominio>.up.railway.app/healthz
  ```
- [ ] Respuesta esperada:
  ```json
  {"status":"ok"}
  ```
- [ ] Si ves otra cosa → N8N no arrancó correctamente. Revisa logs del paso 4.1.

> Si los tres pasos anteriores pasaron (logs limpios, tablas creadas, health check OK), N8N está listo. Continúa a la Fase 5.

---

## FASE 5 — Crear cuenta y restaurar workflows

### 5.0 Crear cuenta de administrador en N8N

- [ ] Abre en tu navegador: `https://<tu-subdominio>.up.railway.app`
- [ ] Posibles escenarios:
  - **Pide crear cuenta nueva** → Normal. La BD nueva está vacía — no sabe nada de tu cuenta anterior. Crea tu cuenta de administrador aquí.
  - **Muestra login normalmente** → Si ya habías creado cuenta en esta BD antes, ingresa.
  - **Pantalla de error o no carga** → Revisa logs en Railway (paso 4.1).

### 5.1 Reimportar workflows

- [ ] Entra a tu N8N con la cuenta que creaste en el paso 5.0
- [ ] Menú izquierdo → **Workflows**
- [ ] Click en el botón **+** (nuevo workflow) → busca la opción **Import from file** o **Import**
- [ ] Selecciona el primer `.json` que exportaste en la Fase 1
- [ ] El workflow aparece en pantalla — click **Save** si no se guardó solo
- [ ] Repite para cada `.json` de tu backup

### 5.2 Reconfigurar credenciales

Las credenciales no viajan con los workflows — hay que ingresarlas desde cero.

- [ ] En N8N → menú izquierdo → **Credentials** → botón **+ Add credential**

---

#### Credencial A: Kumi API (Rails)

Úsala cuando N8N necesite crear o modificar datos en Kumi (bookings, imports, etc.)

- Tipo de credencial: busca `Header Auth` → selecciona **Header Auth**
- **Credential Name:** `Kumi API`
- **Name:** `Authorization`
- **Value:** `Bearer <pega aquí el token de la API Key de Kumi>`
- Click **Save**

---

#### Credencial B: Kumi DB (Supabase directo)

Úsala cuando N8N necesite leer datos para reportes y alertas, sin pasar por Rails.

- Tipo de credencial: busca `Postgres` → selecciona **Postgres**
- **Credential Name:** `Kumi DB`
- **Host:** el host de Supabase (el mismo del paso 2.3, ej: `db.abcdefghijkl.supabase.co`)
- **Port:** `5432`
- **Database:** `postgres`
- **User:** `postgres` ← este es diferente al `n8n_user`. Aquí usas el usuario principal de Supabase para leer las tablas de Rails.
- **Password:** la contraseña del usuario `postgres` de Supabase (está en Project Settings → Database → Database Password)
- **SSL:** activa el toggle de SSL
- Click **Test** → debe aparecer ✅ `Connection tested successfully`
- Click **Save**

> **Diferencia entre los dos usuarios:**
>
> - `n8n_user` → solo para que N8N guarde sus datos internos (workflows, historial). NO lo uses en workflows.
> - `postgres` → para que los workflows consulten las tablas de la app (bookings, vehículos, etc.)

---

### 5.3 Reasignar credenciales a los workflows

Al reimportar un workflow, los nodos quedan apuntando a credenciales que ya no existen (las de la SQLite anterior). Hay que reasignarlos.

- [ ] Abre cada workflow importado
- [ ] Los nodos con credencial rota aparecen con un aviso rojo o amarillo
- [ ] Haz click en el nodo problemático
- [ ] En el panel de configuración que aparece a la derecha, busca el campo **Credential**
- [ ] Selecciona la credencial correcta del dropdown (las que acabas de crear en 5.2)
- [ ] Click fuera del panel o en **Back** para cerrar
- [ ] Click en **Save** (botón arriba a la derecha del workflow)
- [ ] Repite para cada nodo y cada workflow

---

## FASE 6 — Pruebas finales

- [ ] Ejecuta cada workflow manualmente: abre el workflow → click **Execute Workflow** o **Test workflow**
- [ ] Verifica que los resultados sean correctos (sin errores en los nodos)
- [ ] En N8N menú izquierdo → **Executions** — debe mostrar las ejecuciones recientes (señal de que Supabase está guardando correctamente)
- [ ] Activa los workflows que deban estar activos: en la lista de Workflows, activa el toggle verde de cada uno
- [ ] Confirma en Supabase que las ejecuciones se están guardando:
  - Abre Supabase → **SQL Editor**
  - Ejecuta:

    ```sql
    SELECT count(*) FROM n8n.execution_entity;
    ```

  - El número debe aumentar con cada ejecución que hagas en N8N

---

## Referencia rápida — variables Railway al terminar

Al finalizar, el servicio N8N en Railway debe tener **todas** estas variables configuradas:

```
# ── Base de datos (nuevas) ───────────────────────────────
DB_TYPE                               = postgresdb
DB_POSTGRESDB_HOST                    = db.xxxxxxxxxxxxxxxx.supabase.co
DB_POSTGRESDB_PORT                    = 5432
DB_POSTGRESDB_DATABASE                = postgres
DB_POSTGRESDB_USER                    = n8n_user
DB_POSTGRESDB_PASSWORD                = <tu contraseña>
DB_POSTGRESDB_SCHEMA                  = n8n
DB_POSTGRESDB_SSL_ENABLED             = true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED = false

# ── N8N (no tocar) ───────────────────────────────────────
N8N_ENCRYPTION_KEY                    = <igual que antes>
N8N_HOST                              = <tu-subdominio>.up.railway.app
N8N_PORT                              = 5678
N8N_PROTOCOL                          = https
WEBHOOK_URL                           = https://<tu-subdominio>.up.railway.app/
N8N_RUNNERS_ENABLED                   = true
NODE_ENV                              = production
```

---

## Troubleshooting

### Error: `connect ECONNREFUSED` o `connection refused`

N8N no puede llegar al servidor de Supabase.

1. Revisa `DB_POSTGRESDB_HOST` — no debe tener `https://` ni `/` al final
2. Revisa que el puerto sea `5432` y no `6543`
3. En Supabase → Project Settings → Database → verifica que Direct Connection esté habilitado (no paused)

---

### Error: `password authentication failed for user "n8n_user"`

La contraseña es incorrecta.

1. En Railway, revisa que `DB_POSTGRESDB_PASSWORD` esté escrita exactamente igual a la que pusiste en el paso 2.2 (sin espacios extra, sin comillas)
2. Si tienes dudas, crea la contraseña de nuevo en Supabase SQL Editor:

   ```sql
   ALTER USER n8n_user WITH PASSWORD 'NuevaPassword456!';
   ```

   Y actualiza la variable en Railway.

---

### Error: `schema "n8n" does not exist`

El schema no se creó o el usuario no tiene acceso a él.

1. En Supabase SQL Editor, verifica que existe:

   ```sql
   SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'n8n';
   ```

2. Si no devuelve nada, créalo de nuevo:

   ```sql
   CREATE SCHEMA IF NOT EXISTS n8n;
   GRANT USAGE ON SCHEMA n8n TO n8n_user;
   GRANT CREATE ON SCHEMA n8n TO n8n_user;
   ALTER DEFAULT PRIVILEGES IN SCHEMA n8n GRANT ALL ON TABLES TO n8n_user;
   ALTER DEFAULT PRIVILEGES IN SCHEMA n8n GRANT ALL ON SEQUENCES TO n8n_user;
   ```

3. Haz redeploy en Railway.

---

### Error SSL: `self signed certificate in certificate chain`

- Verifica que `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED` = `false` (con esa ortografía exacta)

---

### Los workflows importados tienen nodos con ícono rojo

Normal — apuntan a credenciales de la SQLite anterior que ya no existen. Sigue el paso 5.3 para reasignarlas.

---

### N8N pide crear cuenta nueva al entrar

Normal. La nueva BD en Supabase está vacía — no sabe nada de tu cuenta anterior. Crea la cuenta de administrador nuevamente y luego reimporta los workflows (Fase 5).

---

## Estado de la migración

Marca cada fase al completarla:

- [ ] **Fase 1** — Backup completado (workflows exportados, credenciales anotadas)
- [ ] **Fase 2** — Supabase preparado (schema `n8n` creado, usuario `n8n_user` creado, datos de conexión anotados)
- [ ] **Fase 3** — Variables configuradas en Railway y redeploy lanzado
- [ ] **Fase 4** — N8N arrancó, tablas creadas en Supabase, health check OK
- [ ] **Fase 5** — Workflows reimportados, credenciales reconfiguradas
- [ ] **Fase 6** — Pruebas exitosas, ejecuciones guardándose en Supabase ✅
