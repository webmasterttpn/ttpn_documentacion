# 2026-04-29 — Rate Limiting y Auditoría SQL Injection

## Objetivo

Implementar rate limiting en la API Rails (ttpngas) y auditar el código contra inyección SQL.

---

## Rate Limiting — rack-attack

### Archivos creados / modificados

| Archivo | Cambio |
| --- | --- |
| `ttpngas/Gemfile` | `gem 'rack-attack'` en sección AUTH & LOGIC |
| `ttpngas/config/initializers/rack_attack.rb` | Inicializador nuevo (ver detalles abajo) |
| `ttpngas/config/environments/production.rb` | Redis como cache store (`redis_cache_store`) |
| `ttpngas/config/application.rb` | `config.middleware.use Rack::Attack` |
| `ttpngas/spec/support/rack_attack.rb` | MemoryStore + `Rack::Attack.reset!` antes de cada test |

### Throttles configurados

| Throttle | Límite | Período | Discriminador |
| --- | --- | --- | --- |
| Login interno (`POST /auth/login`) | 5 req | 20 s | IP |
| Login portal (`POST /client_auth/login`) | 5 req | 20 s | IP |
| Login Devise legacy (`POST /users/sign_in`) | 5 req | 20 s | IP |
| API general (`/api/`, `/auth/`, `/client_auth/`) | 300 req | 5 min | IP |
| API autenticada (cualquier `Authorization` header) | 600 req | 5 min | Token |
| Blocklist brute force | >20 intentos | 5 min | IP bloqueada 1 hora |

Safelists: `/health`, `/up`, `127.0.0.1`, `::1`.

Respuesta: `429 Too Many Requests` + `Retry-After` (RFC 6585) + JSON `{ "error": "..." }`.

Backend: Redis (misma URL de Sidekiq, namespace `rack_attack`). En tests: `MemoryStore`.

---

## Auditoría SQL Injection

### Alcance

Grep sobre todos los archivos con `.where`, `.joins`, `.find_by`, `.order` y ILIKE en `ttpngas/app/`.

### Resultado

**Sin vulnerabilidades encontradas.**

- Todos los `WHERE` / `ILIKE` usan el placeholder `?` (forma de array con segundo argumento): `where("campo ILIKE ?", "%#{valor}%")` — el binding paramétrico escapa automáticamente.
- No se encontró interpolación `#{}` dentro de strings de SQL.
- Las llamadas a `.order()` usan sintaxis de símbolo (`:desc`, `:asc`) o strings literales hardcodeados — ninguno acepta input de usuario sin whitelist.
- `params.permit!` no aparece en ningún controller activo.

### Recomendación mantenida

Si en el futuro se agrega ordenamiento dinámico (ej. `params[:sort_by]`), aplicar whitelist explícita:

```ruby
SORTABLE_COLUMNS = %w[nombre created_at updated_at].freeze
order_col = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
scope.order("#{order_col} DESC")
```

---

## Calidad

- `bundle exec rubocop config/initializers/rack_attack.rb spec/support/rack_attack.rb` → **0 offenses** (59 autocorregidos).
- `bundle install` → rack-attack 6.8.0 instalado limpio.

---

## Documentación actualizada

- `ttpngas/CLAUDE.md` → sección "Rate Limiting" añadida en Seguridad.
- `Empresa de Desarrollo/Infra/CLAUDE.md` → `rack-attack` añadido al Gemfile del bootstrap + `rack_attack.rb` en la lista de initializers.
