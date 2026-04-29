# 📋 Plan de Implementación - Transformación a API

## 🎯 Objetivo General

Transformar el monolito Rails actual en una API REST moderna, preparada para microservicios, con deployment en Railway/Supabase y frontend PWA en Netlify.

---

## 📊 Estado Actual

### ✅ Completado (Fase 0)

- [x] Docker Compose con PostgreSQL, Redis, Sidekiq
- [x] Dockerfile multi-stage optimizado
- [x] Gemfile actualizado con herramientas de desarrollo
- [x] Estructura de documentación creada
- [x] Configuración de Rubocop
- [x] Variables de entorno (.env.example)
- [x] .dockerignore para optimización

### 📈 Progreso de Migración de Controladores

- **Total de controladores:** 67
- **Migrados a API v1:** 11 (16%)
- **Pendientes:** 56 (84%)

#### Controladores Migrados ✅

1. `base_controller.rb`
2. `business_units_controller.rb`
3. `concessionaires_controller.rb`
4. `employees_controller.rb`
5. `employees_incidences_controller.rb`
6. `roles_controller.rb`
7. `users_controller.rb`
8. `vehicle_documents_controller.rb`
9. `vehicle_type_prices_controller.rb`
10. `vehicle_types_controller.rb`
11. `vehicles_controller.rb`

---

## 🗺️ Roadmap de Implementación

### **FASE 1: Configuración y Testing** (1-2 semanas)

#### 1.1 Configurar RSpec y FactoryBot

- [ ] Instalar gems: `bundle install`
- [ ] Inicializar RSpec: `rails generate rspec:install`
- [ ] Configurar FactoryBot
- [ ] Configurar Shoulda Matchers
- [ ] Configurar SimpleCov para coverage
- [ ] Configurar Database Cleaner

#### 1.2 Configurar Swagger/Rswag

- [ ] Inicializar Rswag: `rails generate rswag:install`
- [ ] Configurar rutas de Swagger UI
- [ ] Crear primer spec de API de ejemplo
- [ ] Generar documentación inicial

#### 1.3 Crear Tests Base

- [ ] Factories para modelos principales (User, Employee, Vehicle, Client)
- [ ] Model specs básicos
- [ ] Request specs para controladores migrados
- [ ] Helper para autenticación en tests

#### 1.4 Configurar CI/CD Local

- [ ] Script de pre-commit con Rubocop
- [ ] Script de pre-push con tests
- [ ] Configurar GitHub Actions (cuando se migre)

**Entregables:**

- RSpec configurado y funcionando
- Coverage > 80% en controladores migrados
- Swagger UI accesible en `/api-docs`
- Scripts de CI/CD funcionando

---

### **FASE 2: Refactorización y Limpieza** (2-3 semanas)

#### 2.1 Análisis de Código

- [ ] Ejecutar Rubocop en todo el proyecto
- [ ] Ejecutar Brakeman para análisis de seguridad
- [ ] Identificar código duplicado
- [ ] Identificar N+1 queries con Bullet

#### 2.2 Crear Servicios y Concerns

- [ ] Extraer lógica de negocio a Service Objects
- [ ] Crear Concerns reutilizables
- [ ] Implementar patrón Repository si es necesario
- [ ] Crear Presenters/Serializers consistentes

#### 2.3 Optimización de Queries

- [ ] Agregar includes/joins donde sea necesario
- [ ] Implementar paginación consistente (Kaminari)
- [ ] Optimizar queries lentas
- [ ] Agregar índices faltantes

#### 2.4 Estandarización

- [ ] Formato de respuestas JSON consistente
- [ ] Manejo de errores unificado
- [ ] Validaciones consistentes
- [ ] Logging estructurado

**Entregables:**

- Código limpio según Rubocop
- Sin vulnerabilidades críticas (Brakeman)
- Service Objects documentados
- Performance mejorado (queries optimizadas)

---

### **FASE 3: Migración de Controladores** (3-4 semanas)

#### 3.1 Priorización de Controladores

**Alta Prioridad (Core Business):**

1. `clients_controller` - Gestión de clientes
2. `ttpn_bookings_controller` - Reservas
3. `invoicings_controller` - Facturación
4. `payrolls_controller` - Nóminas
5. `scheduled_maintenances_controller` - Mantenimientos

**Media Prioridad (Operaciones):** 6. `gas_stations_controller` - Gasolineras 7. `gasoline_charges_controller` - Cargas de gasolina 8. `suppliers_controller` - Proveedores 9. `service_appointments_controller` - Citas de servicio 10. `travel_counts_controller` - Conteos de viajes

**Baja Prioridad (Configuración):**

- Todos los controladores de configuración y catálogos restantes

#### 3.2 Proceso de Migración por Controlador

Para cada controlador:

1. [ ] Crear archivo en `app/controllers/api/v1/`
2. [ ] Heredar de `Api::V1::BaseController`
3. [ ] Implementar acciones RESTful
4. [ ] Crear serializer/presenter
5. [ ] Escribir request specs
6. [ ] Documentar en Swagger
7. [ ] Ejecutar Rubocop
8. [ ] Code review

#### 3.3 Testing de Controladores Migrados

- [ ] Request specs completos
- [ ] Tests de autorización
- [ ] Tests de validación
- [ ] Tests de edge cases

**Entregables:**

- 100% de controladores migrados a API v1
- Tests con coverage > 90%
- Documentación Swagger completa
- Código limpio y refactorizado

---

### **FASE 4: Autenticación y Autorización** (1-2 semanas)

#### 4.1 Implementar JWT

- [ ] Configurar Devise JWT
- [ ] Endpoint de login (POST /api/v1/auth/login)
- [ ] Endpoint de logout (DELETE /api/v1/auth/logout)
- [ ] Endpoint de refresh token
- [ ] Endpoint de registro (si aplica)

#### 4.2 Autorización con CanCanCan

- [ ] Revisar y actualizar abilities
- [ ] Implementar scopes por rol
- [ ] Tests de autorización
- [ ] Documentar permisos

#### 4.3 Seguridad

- [ ] Implementar rate limiting (Rack Attack)
- [ ] CORS configurado correctamente
- [ ] Headers de seguridad
- [ ] Sanitización de inputs

**Entregables:**

- Autenticación JWT funcionando
- Autorización por roles implementada
- Tests de seguridad pasando
- Documentación de autenticación

---

### **FASE 5: Background Jobs y Workers** (1 semana)

#### 5.1 Revisar Jobs Existentes

- [ ] Auditar jobs de Sidekiq actuales
- [ ] Identificar jobs obsoletos
- [ ] Optimizar jobs lentos

#### 5.2 Implementar Nuevos Jobs

- [ ] Job de envío de emails
- [ ] Job de generación de reportes
- [ ] Job de sincronización de datos
- [ ] Job de limpieza de datos antiguos

#### 5.3 Monitoring

- [ ] Dashboard de Sidekiq accesible
- [ ] Alertas de jobs fallidos
- [ ] Métricas de performance

**Entregables:**

- Jobs optimizados y documentados
- Sidekiq configurado correctamente
- Monitoring implementado

---

### **FASE 6: Preparación para Deployment** (1-2 semanas)

#### 6.1 Configuración de Railway

- [ ] Crear proyecto en Railway
- [ ] Configurar variables de entorno
- [ ] Configurar build y deploy
- [ ] Configurar health checks

#### 6.2 Migración a Supabase

- [ ] Crear proyecto en Supabase
- [ ] Migrar esquema de base de datos
- [ ] Configurar backups
- [ ] Migrar datos (si aplica)

#### 6.3 CI/CD con GitHub Actions

- [ ] Configurar workflow de tests
- [ ] Configurar workflow de deploy
- [ ] Configurar notificaciones
- [ ] Documentar proceso

#### 6.4 Monitoring y Logging

- [ ] Configurar Scout APM (ya instalado)
- [ ] Configurar logging centralizado
- [ ] Configurar alertas
- [ ] Dashboard de métricas

**Entregables:**

- API desplegada en Railway
- Base de datos en Supabase
- CI/CD funcionando
- Monitoring activo

---

### **FASE 7: Documentación Final** (1 semana)

#### 7.1 Documentación Técnica

- [ ] Diagrama de arquitectura actualizado
- [ ] Diagrama de base de datos
- [ ] Documentación de API completa
- [ ] Guías de deployment

#### 7.2 Documentación de Desarrollo

- [ ] Guía de contribución
- [ ] Convenciones de código
- [ ] Guía de testing
- [ ] Troubleshooting

#### 7.3 Runbooks

- [ ] Procedimientos de deployment
- [ ] Procedimientos de rollback
- [ ] Procedimientos de backup/restore
- [ ] Procedimientos de incident response

**Entregables:**

- Documentación completa y actualizada
- Diagramas visuales
- Runbooks operacionales
- Knowledge base

---

## 📅 Timeline Estimado

| Fase                    | Duración    | Semanas Acumuladas |
| ----------------------- | ----------- | ------------------ |
| Fase 1: Testing         | 1-2 semanas | 2                  |
| Fase 2: Refactorización | 2-3 semanas | 5                  |
| Fase 3: Migración       | 3-4 semanas | 9                  |
| Fase 4: Auth            | 1-2 semanas | 11                 |
| Fase 5: Jobs            | 1 semana    | 12                 |
| Fase 6: Deployment      | 1-2 semanas | 14                 |
| Fase 7: Docs            | 1 semana    | 15                 |

**Total: ~15 semanas (3-4 meses)**

---

## 🎯 Criterios de Éxito

### Técnicos

- [ ] 100% de controladores migrados a API v1
- [ ] Coverage de tests > 90%
- [ ] 0 vulnerabilidades críticas (Brakeman)
- [ ] 0 ofensas de Rubocop
- [ ] Performance: P95 < 200ms
- [ ] Uptime > 99.9%

### Funcionales

- [ ] Todas las funcionalidades del monolito funcionando
- [ ] API documentada en Swagger
- [ ] Frontend PWA conectado y funcionando
- [ ] Jobs de background ejecutándose correctamente

### Operacionales

- [ ] CI/CD automatizado
- [ ] Monitoring y alertas configurados
- [ ] Backups automáticos
- [ ] Documentación completa

---

## 🚨 Riesgos y Mitigaciones

| Riesgo                        | Probabilidad | Impacto | Mitigación                             |
| ----------------------------- | ------------ | ------- | -------------------------------------- |
| Pérdida de datos en migración | Baja         | Alto    | Backups frecuentes, testing exhaustivo |
| Breaking changes en API       | Media        | Alto    | Versionamiento, tests de integración   |
| Performance degradado         | Media        | Medio   | Profiling, optimización de queries     |
| Bugs en producción            | Media        | Alto    | Tests completos, staging environment   |
| Retrasos en timeline          | Alta         | Medio   | Buffer de tiempo, priorización clara   |

---

## 📞 Contacto y Soporte

- **Desarrollador Principal:** [Tu nombre]
- **Branch de Trabajo:** `transform_to_api`
- **Repositorio:** (Por migrar a GitHub)

---

## 📝 Notas

- Este plan es iterativo y se ajustará según avancemos
- Cada fase debe completarse antes de pasar a la siguiente
- Los tests son obligatorios para cada feature
- El código debe pasar Rubocop antes de commit
- Documentar todo cambio significativo

---

**Última actualización:** 2025-12-18
**Versión:** 1.0
**Estado:** En progreso - Fase 0 completada
