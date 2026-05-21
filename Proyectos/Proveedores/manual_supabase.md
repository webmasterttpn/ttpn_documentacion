# Manual — Supabase Storage para documentos del portal

> **Audiencia**: dev que nunca ha usado Supabase.
> **Resultado**: bucket privado `supplier_docs` creado, credenciales
> configuradas en Rails, archivo de prueba subido y descargado.
> **Tiempo estimado**: 30-45 min la primera vez.

## Por qué Supabase Storage

- Almacena los **PDF y XML CFDI** que los proveedores suben.
- Es alternativa a AWS S3 (que ya usa Kumi para otras cosas) — el
  proyecto está experimentando con Supabase porque ya tenemos Supabase
  para Postgres y simplifica la cuenta.
- **Bucket privado**: los archivos NO son públicos. El backend genera
  URLs firmadas con TTL corto (5 min) para descargas.

## Paso 1 — Cuenta y proyecto en Supabase

### Por qué

Necesitas acceso al **proyecto de Supabase de TTPN**. NO crees uno
propio para tu test — eso es producción/staging y solo Antonio lo
maneja.

### Comando(s)

No hay comando — es UI web.

1. Pide a Antonio que te invite al proyecto de Supabase como
   **developer**.
2. Acepta la invitación en tu correo.
3. Entra a <https://supabase.com/dashboard> y selecciona el proyecto.

### Verificación

En el dashboard, sidebar izquierdo, debes ver: **Database**, **Storage**,
**Auth**, **Edge Functions**, **API**. Si los ves, tienes acceso.

### Si falla

- "No tengo invitación" → recuérdale a Antonio. La invitación expira
  en 7 días.
- "Necesito Pro" → Antonio paga el plan; tu cuenta es solo seat. No
  tienes que pagar nada.

---

## Paso 2 — Crear el bucket `supplier_docs`

### Por qué

Un **bucket** es un contenedor de archivos. Tendremos uno solo
(`supplier_docs`) con carpetas internas por proveedor / año / mes.

### Pasos en la UI

1. Sidebar → **Storage** → botón verde **New bucket**.
2. **Name**: `supplier_docs`
3. **Public bucket**: **DESACTIVADO** (toggle off, queda gris).
   Es **CRÍTICO** que esté privado — los archivos llevan datos
   fiscales sensibles.
4. **File size limit**: `10485760` (10 MB).
5. **Allowed MIME types**: dejar vacío (validamos del lado Rails).
6. Click **Create bucket**.

### Verificación

En **Storage** debes ver el bucket `supplier_docs` listado. Click al
bucket → vista vacía con "No objects yet".

### Si falla

- "Bucket name already exists" → ya alguien lo creó. Verifica con
  Antonio si es el bucket que deben usar. NO crees variantes
  (`supplier_docs_v2`, etc.).

---

## Paso 3 — Crear policy de acceso del bucket

### Por qué

Aunque el bucket es privado, **necesitas una policy explícita** para
que la `service_role` key pueda leer/escribir. Sin policy, Supabase
rechaza todo.

### Pasos

1. **Storage** → click en `supplier_docs` → tab **Policies**.
2. Click **New Policy** → **For full customization**.
3. Pega esta policy:

   ```sql
   CREATE POLICY "service_role_full_access"
   ON storage.objects
   FOR ALL
   USING (bucket_id = 'supplier_docs')
   WITH CHECK (bucket_id = 'supplier_docs');
   ```

4. **Allowed operation**: SELECT, INSERT, UPDATE, DELETE (los 4
   checks marcados).
5. **Target roles**: `service_role` (no `anon`, no `authenticated`).
6. Click **Review** → **Save policy**.

### Verificación

El tab **Policies** debe listar `service_role_full_access` con los
4 íconos verdes (SELECT, INSERT, UPDATE, DELETE).

### Aprende esto antes de seguir

- **`service_role`** es la "super key" — solo el backend la usa.
  Bypassa todas las restricciones de seguridad. NUNCA va al frontend
  ni a un cliente externo.
- **`anon`** es la "key pública" — usada por clientes web sin login.
  El portal NO la usa (todo va por el backend).

---

## Paso 4 — Obtener las credenciales

### Por qué

El backend Rails necesita dos valores: `SUPABASE_URL` y
`SUPABASE_SERVICE_KEY`. Los obtienes de la UI.

### Pasos

1. Sidebar → **Project Settings** (engrane abajo) → **API**.
2. Copia los siguientes valores:

   | Variable | Dónde lo ves |
   |---|---|
   | `SUPABASE_URL` | "Project URL" — algo como `https://xxx.supabase.co` |
   | `SUPABASE_SERVICE_KEY` | "service_role" key (la **secreta**, no la `anon`). Click "Reveal" |

3. **NO copies** la `anon` key — esa NO se usa en el portal.

### Verificación

Pruébalas con `curl` (reemplaza con tus valores):

```bash
curl -X GET "$SUPABASE_URL/storage/v1/bucket/supplier_docs" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_KEY"
```

### Salida esperada

```json
{
  "id": "supplier_docs",
  "name": "supplier_docs",
  "public": false,
  "file_size_limit": 10485760,
  ...
}
```

### Si falla

- **401 Unauthorized** → copiaste la `anon` en lugar de `service_role`.
  Vuelve al paso anterior y "Reveal" la `service_role`.
- **404 Not Found** → el bucket no se creó (vuelve al Paso 2).

---

## Paso 5 — Guardar las credenciales en Rails

### Por qué

`SUPABASE_URL` y `SUPABASE_SERVICE_KEY` deben estar en el `.env` del
backend para que Rails las lea.

### Comando(s)

Abre `ttpngas/.env` y agrega:

```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
SUPABASE_BUCKET=supplier_docs
```

Luego reinicia el contenedor del API:

```bash
docker compose restart kumi_api
```

### Verificación

```bash
docker compose exec kumi_api bundle exec rails runner \
  "puts ENV['SUPABASE_URL']; puts ENV['SUPABASE_BUCKET']"
```

Debes ver tus valores impresos.

### Si falla

- **Variables vacías** → el contenedor no recogió el `.env`. Asegúrate
  de que el archivo NO tenga espacios alrededor del `=`
  (`VAR=valor` ✓ vs `VAR = valor` ✗).
- **Salida muestra los valores pero el código no los ve** → reinicia
  el contenedor: `docker compose restart kumi_api`.

### NO commitees el `.env`

```bash
git status ttpngas/.env
```

Debe decir "ignored" o no aparecer. **Si aparece como untracked,
NO lo agregues** — ya está en `.gitignore`.

---

## Paso 6 — Service Ruby para subir y descargar

### Por qué

El backend usa un service propio `Storage::SupabaseStorageService`
que envuelve la API REST de Supabase. Los controllers llaman a este
service, no a Supabase directamente.

### Crear archivo

`ttpngas/app/services/storage/supabase_storage_service.rb`:

```ruby
# frozen_string_literal: true

# Storage::SupabaseStorageService
#
# Wrapper de la API REST de Supabase Storage.
# Métodos públicos:
#   - upload(io, path:, content_type:) → URL de descarga firmada
#   - signed_download_url(path, ttl: 5.minutes) → URL temporal
#   - delete(path) → true/false
#
# Credenciales:
#   ENV['SUPABASE_URL']         (https://xxx.supabase.co)
#   ENV['SUPABASE_SERVICE_KEY'] (service_role key)
#   ENV['SUPABASE_BUCKET']      (default: supplier_docs)
class Storage::SupabaseStorageService
  class UploadError < StandardError; end
  class NotFoundError < StandardError; end

  def initialize
    @base_url = ENV.fetch('SUPABASE_URL')
    @api_key  = ENV.fetch('SUPABASE_SERVICE_KEY')
    @bucket   = ENV.fetch('SUPABASE_BUCKET', 'supplier_docs')
  end

  # Sube un archivo. `io` puede ser un IO, StringIO o File.
  # Path es relativo al bucket (ej. "supplier_42/2026/05/pdf_abc.pdf").
  def upload(io, path:, content_type:)
    response = connection.post("/storage/v1/object/#{@bucket}/#{path}") do |req|
      req.headers['Content-Type'] = content_type
      req.headers['x-upsert'] = 'false' # falla si ya existe
      req.body = io.read
    end
    raise UploadError, "Supabase upload failed: #{response.status} #{response.body}" \
      unless response.success?

    { bucket: @bucket, path: path }
  end

  # URL firmada con TTL (default 5 min).
  def signed_download_url(path, ttl: 5.minutes)
    response = connection.post("/storage/v1/object/sign/#{@bucket}/#{path}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { expiresIn: ttl.to_i }.to_json
    end
    raise NotFoundError, "Archivo no encontrado: #{path}" if response.status == 404
    raise UploadError, "Supabase sign failed: #{response.body}" unless response.success?

    body = JSON.parse(response.body)
    "#{@base_url}/storage/v1#{body['signedURL']}"
  end

  def delete(path)
    response = connection.delete("/storage/v1/object/#{@bucket}/#{path}")
    response.success?
  end

  private

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.request :authorization, 'Bearer', @api_key
      f.headers['apikey'] = @api_key
      f.adapter Faraday.default_adapter
    end
  end
end
```

### Verificación end-to-end

```bash
docker compose exec kumi_api bundle exec rails runner "
  svc = Storage::SupabaseStorageService.new
  result = svc.upload(StringIO.new('contenido de prueba'),
                       path: 'test/hola.txt',
                       content_type: 'text/plain')
  puts result.inspect
  url = svc.signed_download_url('test/hola.txt')
  puts url
  puts svc.delete('test/hola.txt')
"
```

### Salida esperada

```text
{:bucket=>\"supplier_docs\", :path=>\"test/hola.txt\"}
https://xxx.supabase.co/storage/v1/object/sign/supplier_docs/test/hola.txt?token=...
true
```

### Si falla

- **`KeyError: key not found: \"SUPABASE_URL\"`** → variable no
  cargada. Verifica `.env` y reinicia el contenedor.
- **HTTP 403** → la policy del bucket no incluye `service_role` o
  está mal configurada. Vuelve al Paso 3.
- **HTTP 400 "InvalidJWT"** → la `SUPABASE_SERVICE_KEY` está mal
  copiada (un caracter de menos o de más). Re-copia del dashboard.

---

## Paso 7 — Convención de paths en el bucket

> Esta es la **convención obligatoria**. No la cambies sin discutirlo
> con Antonio.

```text
supplier_<id>/<YYYY>/<MM>/<tipo>_<uuid>_<nombre_sanitizado>.<ext>
```

Ejemplos:

```text
supplier_42/2026/05/pdf_a1b2c3d4_factura_T5403.pdf
supplier_42/2026/05/xml_e5f6g7h8_cfdi_T5403.xml
supplier_18/2026/06/pdf_z9y8x7w6_complemento_pago_999.pdf
```

Por qué este formato:

- `supplier_<id>` separa físicamente los docs de cada proveedor (auditable).
- `<YYYY>/<MM>` facilita la limpieza histórica (purgar > 5 años por SAT).
- `<tipo>` (pdf/xml) lo distingue de un vistazo.
- `<uuid>` evita colisiones cuando dos archivos tienen el mismo nombre.
- `<nombre_sanitizado>` mantiene legibilidad para el admin.

Helper Ruby para generarlo (ya viene en el modelo `SupplierDocument`):

```ruby
def self.build_path(supplier_id:, kind:, filename:)
  sanitized = filename.gsub(/[^\w.\-]/, '_').downcase
  now = Time.current
  "supplier_#{supplier_id}/#{now.strftime('%Y')}/#{now.strftime('%m')}/" \
    "#{kind}_#{SecureRandom.hex(4)}_#{sanitized}"
end
```

---

## Paso 8 — Rotación y limpieza

| Acción | Cuándo | Quién |
|---|---|---|
| Rotar `SUPABASE_SERVICE_KEY` | Cada 6 meses, o ante cualquier sospecha | Antonio |
| Backup del bucket | Mensual (Supabase Pro lo hace automático) | Antonio |
| Purgar archivos > 5 años | Anual | Job programado (futuro) |
| Eliminar archivos de proveedores dados de baja | Cuando `Supplier.is_active = false` por > 1 año | Job (futuro) |

Por ahora, **no implementes purga automática** — está fuera de
alcance MVP.

---

## Siguiente paso

→ [manual_letter_opener.md](manual_letter_opener.md) — configurar
correos para dev.
