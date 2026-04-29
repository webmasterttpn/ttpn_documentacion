# Dominio: Vehicles (Flotilla)

Gestión de la flotilla de vehículos: unidades, documentos adjuntos (PDFs/imágenes en S3), asignaciones chofer-unidad y estadísticos operativos.

---

## Modelos principales

| Modelo | Archivo | Descripción |
| --- | --- | --- |
| `Vehicle` | [model.md](model.md) | Unidad de flotilla. Filtro por BU via concessionaires |
| `VehicleDocument` | [documents.md](documents.md) | Documentos adjuntos en S3. URL via `blob.url` |

---

## Estructura de carpetas

```
vehicles/
├── README.md
├── model.md                ← Vehicle
├── documents.md            ← VehicleDocument
├── performance.md          ← Optimizaciones del endpoint
├── controller/
│   └── (pendiente)
└── stats/
    └── (pendiente)
```

---

## Regla crítica: URLs de archivos

**Usar siempre `blob.url` (S3 presignado), nunca `rails_blob_url(only_path: true)`.**

`rails_blob_url(only_path: true)` genera una URL relativa (`/rails/active_storage/...`). En producción, el frontend la resuelve contra el host de Netlify → 404 del SPA router.

`blob.url` retorna una URL absoluta de S3 que funciona en dev y prod.

---

## Archivos Rails relacionados

```
app/models/vehicle.rb
app/models/vehicle_document.rb
app/serializers/vehicle_serializer.rb
app/controllers/api/v1/vehicles_controller.rb
app/controllers/api/v1/vehicle_documents_controller.rb
app/controllers/concerns/vehicle_stats_calculable.rb
```
