# 🚀 Setup Local - TTPN Gas API

## Prerrequisitos

- Docker Desktop instalado
- Git
- Editor de código (VS Code recomendado)

## 🐳 Instalación con Docker (Recomendado)

### 1. Clonar el repositorio

```bash
cd /Users/ttpn_acl/Documents/Ruby/Kumi\ TTPN\ Admin\ V2/ttpngas
git checkout transform_to_api
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar `.env` con tus configuraciones locales (si es necesario).

### 3. Construir y levantar los contenedores

```bash
# Construir las imágenes
docker-compose build

# Levantar todos los servicios
docker-compose up -d

# Ver logs
docker-compose logs -f app
```

### 4. Configurar la base de datos

```bash
# Crear la base de datos
docker-compose exec app bundle exec rails db:create

# Ejecutar migraciones
docker-compose exec app bundle exec rails db:migrate

# Cargar datos de prueba (opcional)
docker-compose exec app bundle exec rails db:seed
```

### 5. Verificar que todo funciona

```bash
# Verificar que la API responde
curl http://localhost:3000

# Debería retornar: "API TTPN Online"
```

## 🧪 Ejecutar Tests

```bash
# Ejecutar todos los tests
docker-compose exec app bundle exec rspec

# Ejecutar un archivo específico
docker-compose exec app bundle exec rspec spec/models/user_spec.rb

# Ejecutar con coverage
docker-compose exec app bundle exec rspec --format documentation
```

## 🔍 Linting y Code Quality

```bash
# Ejecutar Rubocop
docker-compose exec app bundle exec rubocop

# Auto-corregir problemas
docker-compose exec app bundle exec rubocop -A

# Ejecutar Brakeman (seguridad)
docker-compose exec app bundle exec brakeman
```

## 📊 Servicios Disponibles

| Servicio   | URL                            | Descripción                      |
| ---------- | ------------------------------ | -------------------------------- |
| API        | http://localhost:3000          | Rails API                        |
| Sidekiq    | http://localhost:3000/sidekiq  | Panel de trabajos en background  |
| PostgreSQL | localhost:5432                 | Base de datos                    |
| Redis      | localhost:6379                 | Cache y jobs                     |
| Swagger    | http://localhost:3000/api-docs | Documentación API (próximamente) |

## 🛠️ Comandos Útiles

### Docker Compose

```bash
# Detener todos los servicios
docker-compose down

# Detener y eliminar volúmenes
docker-compose down -v

# Reconstruir un servicio específico
docker-compose up -d --build app

# Ver logs de un servicio
docker-compose logs -f sidekiq

# Ejecutar comandos en el contenedor
docker-compose exec app bash
docker-compose exec app rails console
```

### Rails

```bash
# Consola de Rails
docker-compose exec app rails console

# Generar un controlador
docker-compose exec app rails g controller api/v1/NombreRecurso

# Generar un modelo
docker-compose exec app rails g model NombreModelo

# Crear una migración
docker-compose exec app rails g migration AddColumnToTable

# Rollback de migración
docker-compose exec app rails db:rollback
```

### RSpec

```bash
# Generar spec para un modelo
docker-compose exec app rails g rspec:model NombreModelo

# Generar spec para un controlador
docker-compose exec app rails g rspec:controller api/v1/NombreRecurso
```

## 🐛 Troubleshooting

### El puerto 3000 ya está en uso

```bash
# Encontrar el proceso
lsof -ti:3000

# Matar el proceso
kill -9 $(lsof -ti:3000)
```

### La base de datos no se conecta

```bash
# Verificar que PostgreSQL está corriendo
docker-compose ps db

# Reiniciar el servicio de base de datos
docker-compose restart db

# Ver logs de PostgreSQL
docker-compose logs db
```

### Problemas con las gemas

```bash
# Limpiar y reinstalar
docker-compose down
docker-compose build --no-cache app
docker-compose up -d
```

### Resetear la base de datos

```bash
docker-compose exec app rails db:drop db:create db:migrate db:seed
```

## 📝 Notas Importantes

1. **Siempre trabaja en la branch `transform_to_api`**
2. **No hagas merge a master** hasta que todo esté probado
3. **Ejecuta los tests** antes de hacer commit
4. **Usa Rubocop** para mantener el código limpio
5. **Documenta** los nuevos endpoints en Swagger

## 🔄 Workflow de Desarrollo

1. Crear/modificar código
2. Ejecutar tests: `docker-compose exec app rspec`
3. Ejecutar linter: `docker-compose exec app rubocop -A`
4. Verificar seguridad: `docker-compose exec app brakeman`
5. Commit y push
6. Repetir

## 📚 Próximos Pasos

- [ ] Configurar RSpec
- [ ] Configurar Swagger
- [ ] Migrar controladores restantes
- [ ] Escribir tests
- [ ] Documentar API
