# 🧪 Pruebas del Sistema de API Keys

## 📋 Resumen

Este documento describe todas las pruebas implementadas y cómo ejecutarlas.

## 🏗️ Estructura de Pruebas

```
spec/
├── factories.rb                    # Factories para testing
├── models/
│   ├── api_user_spec.rb           # ✅ Pruebas de ApiUser
│   └── api_key_spec.rb            # Pendiente
├── requests/api/v1/
│   ├── api_users_spec.rb          # Pendiente
│   └── api_keys_spec.rb           # Pendiente
└── serializers/
    ├── api_user_serializer_spec.rb # Pendiente
    └── api_key_serializer_spec.rb  # Pendiente
```

## ✅ Pruebas Implementadas

### 1. Factories (spec/factories.rb)

**ApiUser Factory:**

```ruby
create(:api_user)                    # Usuario API básico
create(:api_user, :inactive)         # Usuario inactivo
create(:api_user, :with_api_keys)    # Con 2 API keys
```

**ApiKey Factory:**

```ruby
create(:api_key)                     # Clave básica (read only)
create(:api_key, :expired)           # Clave expirada
create(:api_key, :full_access)       # Acceso completo
create(:api_key, :read_only)         # Solo lectura
```

### 2. Model Specs (spec/models/api_user_spec.rb)

**Cobertura:**

- ✅ Asociaciones (business_unit, api_keys, creator, updater)
- ✅ Validaciones (name, email, company_name)
- ✅ Scopes (active, inactive, by_business_unit)
- ✅ Métodos (#deactivate!, #activate!, #total_requests, #last_activity)

**Total:** 17 ejemplos

## 🚀 Cómo Ejecutar las Pruebas

### Todas las pruebas

```bash
docker-compose exec app bundle exec rspec
```

### Solo modelos

```bash
docker-compose exec app bundle exec rspec spec/models
```

### Solo ApiUser

```bash
docker-compose exec app bundle exec rspec spec/models/api_user_spec.rb
```

### Con formato detallado

```bash
docker-compose exec app bundle exec rspec --format documentation
```

### Con cobertura

```bash
docker-compose exec app bundle exec rspec --format documentation --format html --out coverage/rspec_results.html
```

## 📊 Cobertura Esperada

| Componente         | Cobertura Objetivo | Estado       |
| ------------------ | ------------------ | ------------ |
| ApiUser Model      | 100%               | ✅ Completo  |
| ApiKey Model       | 100%               | ⏳ Pendiente |
| ApiUsersController | 90%                | ⏳ Pendiente |
| ApiKeysController  | 90%                | ⏳ Pendiente |
| Serializers        | 100%               | ⏳ Pendiente |
| Middleware         | 80%                | ⏳ Pendiente |

## 🧪 Pruebas Manuales

### 1. Crear Usuario API

```bash
# Via Rails Console
docker-compose exec app rails console

api_user = ApiUser.create!(
  name: "Test Company",
  email: "test@example.com",
  company_name: "Test Inc",
  business_unit: BusinessUnit.first
)
```

### 2. Crear API Key

```bash
api_key = ApiKey.create!(
  name: "Test Key",
  api_user: api_user,
  permissions: {
    'vehicles' => { 'read' => true }
  }
)

puts "API Key: #{api_key.key}"
```

### 3. Probar Autenticación

```bash
# Desde terminal
curl -X GET "http://localhost:3000/api/v1/vehicles" \
  -H "X-API-Key: TU_CLAVE_AQUI"
```

### 4. Verificar Permisos

```bash
# Con permiso (debería funcionar)
curl -X GET "http://localhost:3000/api/v1/vehicles" \
  -H "X-API-Key: TU_CLAVE_AQUI"

# Sin permiso (debería fallar con 403)
curl -X POST "http://localhost:3000/api/v1/vehicles" \
  -H "X-API-Key: TU_CLAVE_AQUI" \
  -H "Content-Type: application/json" \
  -d '{"vehicle": {"clv": "TEST"}}'
```

## 🔍 Casos de Prueba Importantes

### Caso 1: Usuario Inactivo

```ruby
api_user = create(:api_user, :inactive)
api_key = create(:api_key, api_user: api_user)

# La clave NO debería funcionar
expect(api_key.active_and_valid?).to be false
```

### Caso 2: Clave Expirada

```ruby
api_key = create(:api_key, :expired)

# La clave NO debería funcionar
expect(api_key.expired?).to be true
expect(api_key.active_and_valid?).to be false
```

### Caso 3: Permisos Granulares

```ruby
api_key = create(:api_key, permissions: {
  'vehicles' => { 'read' => true, 'create' => false }
})

# Debería poder leer
expect(api_key.can?('vehicles', 'read')).to be true

# NO debería poder crear
expect(api_key.can?('vehicles', 'create')).to be false
```

### Caso 4: Desactivar Usuario Desactiva Claves

```ruby
api_user = create(:api_user, :with_api_keys)
api_user.deactivate!

# Todas las claves deberían estar inactivas
expect(api_user.api_keys.pluck(:active).uniq).to eq([false])
```

## 📈 Métricas de Calidad

### Ejecutar con SimpleCov

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'

  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Serializers', 'app/serializers'
end
```

```bash
# Ejecutar con cobertura
docker-compose exec app bundle exec rspec

# Ver reporte
open coverage/index.html
```

## 🐛 Debugging Tests

### Ver output detallado

```bash
docker-compose exec app bundle exec rspec --format documentation --backtrace
```

### Ejecutar un solo ejemplo

```bash
docker-compose exec app bundle exec rspec spec/models/api_user_spec.rb:15
```

### Modo interactivo con pry

```ruby
# En el spec
it 'does something' do
  binding.pry  # Pausa aquí
  expect(something).to eq(value)
end
```

## ✅ Checklist de Pruebas

Antes de hacer deploy, verificar:

- [ ] Todas las pruebas pasan (`bundle exec rspec`)
- [ ] Cobertura > 80% (`simplecov`)
- [ ] No hay warnings de deprecación
- [ ] Factories funcionan correctamente
- [ ] Pruebas de integración pasan
- [ ] Pruebas manuales de API funcionan
- [ ] Documentación actualizada

## 📝 Próximos Pasos

1. **Completar specs de ApiKey**

   - Validaciones
   - Métodos (#can?, #regenerate!, #revoke!)
   - Autenticación

2. **Request specs para controladores**

   - ApiUsersController (CRUD + activate/deactivate)
   - ApiKeysController (CRUD + regenerate/revoke)

3. **Specs de serializers**

   - ApiUserSerializer
   - ApiKeySerializer

4. **Integration tests**
   - Flujo completo de autenticación
   - Verificación de permisos
   - Rate limiting (futuro)

## 🔗 Referencias

- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Guide](https://github.com/thoughtbot/factory_bot)
- [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers)
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0  
**Autor:** Sistema de API Keys
