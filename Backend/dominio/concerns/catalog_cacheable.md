# Concern: CatalogCacheable

`app/controllers/concerns/catalog_cacheable.rb`

## Qué hace

Cachea colecciones de catálogo / dropdowns con una **clave versionada por los
datos**, en lugar de una clave fija con solo TTL.

La clave incluye un *fingerprint* barato de la tabla completa:

```
catalog/<key>/<max(updated_at)>-<count>
```

Cualquier cambio en los datos (alta, edición o baja) produce un fingerprint
distinto → clave nueva → se sirve data fresca automáticamente.

## Problema que resuelve

Antes cada catálogo cacheaba con una clave fija + TTL e invalidaba a mano en
create/update/destroy. Eso fallaba en dos casos:

1. **Escrituras externas** (app móvil, PHP legacy, SQL directo) que NO pasan por
   Rails → nunca disparaban la invalidación manual → el dropdown quedaba stale.
2. **Catálogo vacío "pegado"**: servía `[]` hasta que expiraba el TTL (1 h),
   dejando dropdowns vacíos aunque ya hubiera datos.

Con la clave versionada por datos ya **no hace falta invalidar manualmente**: el
`count` cambia ante altas/bajas (incluso externas) y el `max(updated_at)` ante
ediciones que tocan el timestamp.

## Uso

```ruby
class Api::V1::ReviewPointsController < Api::V1::BaseController
  include CatalogCacheable

  def index
    @review_points = cached_catalog(ReviewPoint, 'review_points') do
      ReviewPoint.where(status: true).order(:nombre).to_a
    end
    render json: @review_points
  end
end
```

- `model`: la clase ActiveRecord del catálogo (para el fingerprint de la tabla
  completa).
- `key`: prefijo de la clave; incluye aquí cualquier variante por params
  (p. ej. `"vehicle_type_prices/#{vehicle_type_id}/#{active}"`).
- `expires_in`: TTL de respaldo (default 1 h).
- El bloque devuelve la colección ya materializada (`.to_a`).

En cache **HIT** solo corren 2 queries baratas (`max(updated_at)` + `count`,
ambas indexables); el bloque (query completa + carga) corre solo en **MISS**.

## Requisitos

- La tabla debe tener `updated_at` (para el fingerprint de ediciones).
- Ya **no** se invalida cache manualmente en create/update/destroy.

## Limitación conocida

Una edición externa que NO bumpea `updated_at` y NO cambia el `count`
(p. ej. `UPDATE ... SET ...` en SQL crudo sin tocar `updated_at`, sobre una fila
que no es la de `max(updated_at)`) no cambia el fingerprint → podría servir stale
hasta el TTL. Las altas/bajas (cambian `count`) y las ediciones que tocan
`updated_at` (Rails siempre; PHP normalmente) sí invalidan.

## Controllers que lo usan

- `Api::V1::ReviewPointsController`
- `Api::V1::VehicleDocumentTypesController`
- `Api::V1::VehicleTypePricesController`
