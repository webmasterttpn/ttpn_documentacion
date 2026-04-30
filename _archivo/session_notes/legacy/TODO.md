# 📋 TODO - Lista de Mejoras Pendientes

## ⚠️ IMPORTANTE

**UUID DESCARTADO:** No se implementará migración a UUID. Se mantienen IDs consecutivos por seguridad.

---

## 🔴 Prioridad Alta

### 1. Módulo de Empleados

**Estado:** Planificado  
**Estimado:** 17-22 horas (3-4 días)

- [ ] Backend: EmployeesController
- [ ] Backend: EmployeeSerializer
- [ ] Frontend: EmployeesPage.vue con tabs
- [ ] Nested forms (Documentos, Salarios, Movimientos)
- [ ] Tests básicos

**Referencia:** `documentacion/PLAN_EMPLEADOS.md`

---

### 2. Catálogos de Empleados en Settings

**Estado:** Pendiente  
**Estimado:** 2-3 horas

- [ ] Employee Document Types
- [ ] Employee Movement Types
- [ ] Labors (Puestos)
- [ ] Drivers Levels

---

### 3. Corregir Permisos de SuperAdmin

**Problema:** Todos los usuarios tienen `sadmin: true`

- [ ] Crear migración basada en `role_id`
- [ ] Actualizar usuarios existentes
- [ ] Validación en modelo User

---

## 🟡 Prioridad Media

### 4. Endpoint `/api/v1/users/current` No Devuelve `sadmin`

- [ ] Verificar serializer de User
- [ ] Agregar campo `sadmin`
- [ ] Actualizar BusinessUnitSelector

---

### 5. Crear Modelo BusinessUnitsConcessionaire

- [ ] Crear modelo
- [ ] Verificar tabla existe
- [ ] Completar tests de Vehicle

---

### 6. Completar Tests de ApiKey

**Progreso:** 0%  
**Meta:** 80%+ cobertura

- [ ] Model specs
- [ ] Request specs ApiKeysController
- [ ] Request specs ApiUsersController

---

### 7. Arreglar Tests de Auditable

- [ ] Configurar `Current.user` en RSpec
- [ ] Crear helper de testing
- [ ] Actualizar tests

---

## 🟢 Prioridad Baja

### 8. Responsive PWA Completo

**Estado:** 80% completado

- [x] BusinessUnitsPage
- [x] ApiAccessPage
- [ ] Todas las demás páginas

---

### 9. Mejorar UI del Business Unit Selector

- [ ] Badge mostrando BU actual
- [ ] Colores por BU
- [ ] Animaciones
- [ ] Sin reload de página

---

### 10. Catálogos Adicionales

- [ ] Concessionaires
- [ ] Service Types
- [ ] Gas Stations
- [ ] Invoice Types

---

## 📚 Documentación

### 11. Documentación de Usuario

- [ ] Guía de Business Unit Selector
- [ ] Screenshots y videos
- [ ] FAQ

---

### 12. Actualizar README

- [ ] Sección de Business Unit Selector
- [ ] Sección de API Keys
- [ ] Instrucciones de testing

---

## ✅ Completado

- [x] Sistema de API Keys (Backend + Frontend)
- [x] Business Unit Selector
- [x] Business Units Page (CRUD)
- [x] Optimizaciones de Vehículos (97% más rápido)
- [x] Tests de ApiUser (20/20)
- [x] Responsive: BusinessUnitsPage, ApiAccessPage
- [x] Documentación (25,000+ líneas)
- [x] Organización de Menús (Operativo vs Configuración)

---

## ❌ DESCARTADO

- ~~Migración a UUID~~ - Muy arriesgado, se mantienen IDs consecutivos

---

## 📊 Métricas Actuales

```
Tests:           50+ (32 passing, 64%)
Cobertura:       ~50% (código testeado)
Documentación:   25,000+ líneas
Código:          16,000+ líneas
Archivos:        80+
```

## 🎯 Metas

```
Tests:           100+ (80%+ passing)
Cobertura:       70%+ (código nuevo)
Documentación:   Completa con screenshots
Código:          Refactorizado y limpio
```

---

**Última actualización:** 2025-12-18  
**Versión:** 2.0  
**Decisión importante:** UUID descartado por seguridad
