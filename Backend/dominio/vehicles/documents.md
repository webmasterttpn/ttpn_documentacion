# VehicleDocument

## Propósito

Documento adjunto a un vehículo (permiso de circulación, póliza de seguro, verificación, etc.). Almacena el archivo en S3 via Active Storage. Expone la URL presignada directamente (sin redirección por Rails).

---

## Campos principales

| Campo            | Tipo    | Descripción                                        |
|------------------|---------|----------------------------------------------------|
| `vehicle_id`     | integer | FK a `Vehicle`. Opcional (nullable para migración).|
| `tipo_documento` | string  | Nombre del tipo. Ej: "Permiso SCT". Obligatorio.   |
| `numero`         | string  | Número o folio del documento. Obligatorio.         |
| `expiracion`     | date    | Fecha de vencimiento.                              |
| `descripcion`    | text    | Observaciones libres.                              |

---

## Asociaciones

| Asociación          | Tipo            | Notas                                                      |
|---------------------|-----------------|------------------------------------------------------------|
| `vehicle`           | `belongs_to`    | Opcional.                                                  |
| `vehicle_doc_image` | Active Storage  | Archivo adjunto (imagen o PDF). Almacenado en S3.          |

---

## Validaciones

- `tipo_documento`: presencia.
- `numero`: presencia.

---

## Métodos

### `doc_image_url`

```ruby
def doc_image_url
  return nil unless vehicle_doc_image.attached?
  vehicle_doc_image.url
rescue StandardError
  nil
end
```

Retorna la URL presignada de S3. **No usar `rails_blob_url(only_path: true)`** — genera una URL relativa que el frontend resuelve contra el host de Netlify, causando 404 en producción.

---

## URL de archivos — regla de oro

Siempre usar `blob.url` (URL absoluta presignada de S3), nunca `rails_blob_url` con `only_path: true`.

Esto aplica igualmente a `EmployeeDocument`, `User#user_avatar`, `Employee#avatar`.

---

## Archivos relacionados

- `app/models/vehicle_document.rb`
- `app/serializers/vehicle_serializer.rb` (serializa `doc_image_url`, `content_type`, `filename`)
- `app/controllers/api/v1/vehicle_documents_controller.rb`
