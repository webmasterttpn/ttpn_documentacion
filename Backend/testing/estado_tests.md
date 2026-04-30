# Resumen de Tests — Sistema de Vehículos y API Keys

> **Snapshot histórico — Diciembre 2025.** Los números de cobertura pueden haber cambiado.
> Para el estado real ejecutar: `COVERAGE=true bundle exec rspec`

## Estado de Tests (snapshot dic 2025)

### Tests Implementados

#### 1. ApiUser Model (20 tests) ✅

```bash
docker-compose exec app bundle exec rspec spec/models/api_user_spec.rb
```

**Resultado:** 20/20 passing (100%)

**Cobertura:**

- Asociaciones (4 tests)
- Validaciones (5 tests)
- Scopes (3 tests)
- Métodos de instancia (8 tests)

#### 2. Vehicle Model (16 tests) ⚠️

```bash
docker-compose exec app bundle exec rspec spec/models/vehicle_spec.rb
```

**Resultado:** 12/16 passing (75%)

**Passing:**

- Asociaciones (5 tests) ✅
- Validaciones (2 tests) ✅
- FriendlyId (2 tests) ✅
- Custom label (1 test) ✅
- Cacheable (1 test) ✅
- Auditable (1 test) ✅

**Failing:**

- Auditable concern con Current.user (1 test) ⚠️
- Business unit filter multitenancy (3 tests) ⚠️
  - Requiere modelo BusinessUnitsConcessionaire

#### 3. Auditable Concern (14 tests) ⚠️

```bash
docker-compose exec app bundle exec rspec spec/models/concerns/auditable_spec.rb
```

**Resultado:** Pendiente de ajustes

#### 4. Vehicles API Request (Tests de Swagger) ✅

```bash
docker-compose exec app bundle exec rspec spec/requests/api/v1/vehicles_spec.rb
```

**Cobertura:**

- GET /api/v1/vehicles ✅
- POST /api/v1/vehicles ✅
- GET /api/v1/vehicles/:id ✅
- PATCH /api/v1/vehicles/:id ✅
- DELETE /api/v1/vehicles/:id ✅

---

## 🎯 Próximos Pasos

### Prioridad Alta

1. **Crear modelo BusinessUnitsConcessionaire**

   - Para que pasen los tests de multitenancy
   - Es crítico para el filtrado por business unit

2. **Arreglar tests de Auditable**
   - Problema con Current.user en tests
   - Necesita configuración especial de Current

### Prioridad Media

3. **Tests de ApiKey model**

   - Validaciones
   - Métodos (#can?, #regenerate!, #revoke!)
   - Autenticación

4. **Request specs de API Keys**
   - ApiUsersController
   - ApiKeysController

### Prioridad Baja

5. **Aumentar cobertura gradualmente**
   - Según vayamos trabajando en nuevos modelos
   - Enfoque en código nuevo, no legacy

---

## 📈 Cobertura Actual

```
ApiUser:    100% ✅
Vehicle:     75% ⚠️
Auditable:   Pendiente
Total:       ~50% (solo código testeado)
```

---

## 🚀 Comandos Útiles

### Ejecutar todos los tests de modelos

```bash
docker-compose exec app bundle exec rspec spec/models
```

### Ejecutar tests con documentación

```bash
docker-compose exec app bundle exec rspec --format documentation
```

### Ejecutar un spec específico

```bash
docker-compose exec app bundle exec rspec spec/models/vehicle_spec.rb:70
```

### Ver cobertura

```bash
docker-compose exec app bundle exec rspec
open coverage/api_keys/index.html
```

---

## ✅ Lo que SÍ está funcionando

1. ✅ **ApiUser** - Completamente testeado
2. ✅ **Vehicle** - Asociaciones y validaciones básicas
3. ✅ **Vehicles API** - Todos los endpoints
4. ✅ **FriendlyId** - Slugs funcionando
5. ✅ **Cacheable** - TTL configurado
6. ✅ **Auditable** - Funciona en producción (solo falla en tests por Current.user)

---

## ⚠️ Pendientes

1. ⚠️ **BusinessUnitsConcessionaire** - Modelo faltante
2. ⚠️ **Current.user en tests** - Configuración especial
3. ⚠️ **ApiKey tests** - Por implementar
4. ⚠️ **Controllers tests** - Por implementar

---

**Última actualización:** 2025-12-18  
**Tests totales:** 50+  
**Tests passing:** 32+  
**Porcentaje:** ~64%
