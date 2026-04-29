# Plan de Migración: TravelCount.verificar_id

**Fecha:** 2026-01-15  
**Estado:** 🟡 PENDIENTE - Esperar migración a Rails API

---

## 📋 Resumen de la Situación

### Estado Actual

**App Android (Legacy):**

- Usa PHP para INSERT directo a `travel_counts`
- **Bypasea** callbacks de Rails
- `verificar_id` **NO se ejecuta** para estos inserts

**Rails API (En Construcción):**

- Reemplazará gradualmente la app Android
- Usará `TravelCount.create(...)` (ActiveRecord)
- `verificar_id` **SÍ se ejecuta** para estos inserts

### Decisión

**Mantener `verificar_id` temporalmente** hasta que:

1. ✅ Rails API esté completa
2. ✅ App Android migre a usar Rails API
3. ✅ PHP sea deprecado

**Entonces:** Eliminar/refactorizar `verificar_id`

---

## 🎯 Plan de Acción

### Fase 1: Ahora (2026-01-15)

**Estado:** ✅ DOCUMENTADO

- [x] Documentar situación actual
- [x] Identificar problema (crea registros vacíos desde Rails)
- [x] Crear plan de migración
- [x] **NO MODIFICAR** el callback por ahora

**Razón:** PHP aún está en uso, migración gradual en proceso.

---

### Fase 2: Durante Construcción de API

**Estado:** 🔄 EN PROGRESO

- [ ] Construir endpoint `POST /api/v1/travel_counts`
- [ ] Implementar validaciones
- [ ] Asegurar que asigna nómina correctamente
- [ ] Asegurar que inicializa errorcode
- [ ] Probar creación desde API

**Nota:** Durante esta fase, `verificar_id` seguirá ejecutándose para requests desde Rails API.

---

### Fase 3: Migración de App Android

**Estado:** ⏳ PENDIENTE

- [ ] App Android empieza a usar Rails API
- [ ] Deprecar endpoints PHP
- [ ] Monitorear que todo funciona correctamente
- [ ] Verificar que nómina se asigna
- [ ] Verificar que errorcode se inicializa

---

### Fase 4: Después de Migración Completa

**Estado:** ⏳ FUTURO

**Cuando:**

- ✅ 100% de inserts vienen de Rails API
- ✅ PHP completamente deprecado
- ✅ App Android usa solo Rails API

**Entonces hacer:**

#### Opción A: Refactorizar (Recomendado)

```ruby
class TravelCount < ApplicationRecord
  before_create :asignar_nomina_activa
  before_create :inicializar_errorcode

  private

  def asignar_nomina_activa
    nomina = obtener_nomina_activa
    Rails.logger.debug(nomina)
    nomina.each do |n|
      self.payroll_id = n['id'].to_i
    end
  end

  def inicializar_errorcode
    self.errorcode = false
  end
end
```

**Cambios:**

- ✅ Eliminar creación de registros vacíos
- ✅ Separar responsabilidades
- ✅ Preservar lógica de negocio

#### Opción B: Valores por Defecto

```ruby
class TravelCount < ApplicationRecord
  # En la migración:
  # t.boolean :errorcode, default: false

  before_create :asignar_nomina_activa

  private

  def asignar_nomina_activa
    nomina = obtener_nomina_activa
    nomina.each { |n| self.payroll_id = n['id'].to_i }
  end
end
```

**Cambios:**

- ✅ `errorcode` con valor por defecto en BD
- ✅ Solo callback para nómina
- ✅ Más simple

---

## 📊 Comparación: Antes vs Después

### Antes (Estado Actual)

| Origen | Callbacks | verificar_id | Registros Vacíos |
| ------ | --------- | ------------ | ---------------- |
| PHP    | ❌ No     | ❌ No        | ❌ No            |
| Rails  | ✅ Sí     | ✅ Sí        | ✅ Sí (problema) |

### Durante Transición

| Origen       | Callbacks | verificar_id | Registros Vacíos |
| ------------ | --------- | ------------ | ---------------- |
| PHP (legacy) | ❌ No     | ❌ No        | ❌ No            |
| Rails API    | ✅ Sí     | ✅ Sí        | ✅ Sí (temporal) |

### Después de Migración (Futuro)

| Origen    | Callbacks | Lógica           | Registros Vacíos |
| --------- | --------- | ---------------- | ---------------- |
| Rails API | ✅ Sí     | ✅ Refactorizada | ✅ No            |

---

## ⚠️ Consideraciones Importantes

### Durante la Transición

1. **Registros Vacíos Temporales:**

   - Los inserts desde Rails API crearán registros vacíos
   - Es un problema temporal
   - Se resolverá después de la migración

2. **Monitoreo:**

   - Rastrear % de inserts desde PHP vs Rails
   - Cuando PHP = 0%, proceder con refactorización

3. **Limpieza:**
   - Después de refactorizar, limpiar registros vacíos históricos
   - Usar rake task similar a `TtpnBookingPassenger`

---

## 🧪 Criterios para Refactorizar

**Proceder cuando se cumplan TODOS:**

- [ ] Rails API está completa y probada
- [ ] App Android usa 100% Rails API
- [ ] PHP está deprecado (0% de uso)
- [ ] Monitoreo confirma que no hay inserts desde PHP
- [ ] Tests pasan correctamente

**Verificación:**

```sql
-- Verificar que no hay inserts directos desde PHP
-- (Buscar registros sin payroll_id asignado)
SELECT COUNT(*)
FROM travel_counts
WHERE payroll_id IS NULL
  AND created_at > NOW() - INTERVAL '7 days';

-- Si el resultado es 0, PHP está deprecado
```

---

## 📝 Checklist de Migración

### Pre-Migración

- [x] Documentar situación actual
- [x] Identificar problema
- [x] Crear plan de acción
- [ ] Construir Rails API completa
- [ ] Probar API exhaustivamente

### Durante Migración

- [ ] Migrar App Android a Rails API
- [ ] Monitorear % de uso PHP vs Rails
- [ ] Verificar que lógica de negocio funciona
- [ ] Deprecar endpoints PHP gradualmente

### Post-Migración

- [ ] Confirmar 0% uso de PHP
- [ ] Refactorizar `verificar_id`
- [ ] Ejecutar tests
- [ ] Limpiar registros vacíos históricos
- [ ] Desplegar a producción
- [ ] Monitorear por 1 semana

---

## 🎯 Próximos Pasos Inmediatos

1. **Ahora:**

   - ✅ Documentación completa (este archivo)
   - ✅ Mantener `verificar_id` sin cambios
   - ✅ Continuar con construcción de Rails API

2. **Cuando API esté lista:**

   - 🔄 Migrar App Android
   - 🔄 Monitorear uso

3. **Cuando PHP = 0%:**
   - ⏳ Refactorizar `verificar_id`
   - ⏳ Limpiar registros vacíos

---

## 📚 Referencias

- **Análisis original:** `/documentacion/ANALISIS_CALLBACKS_VERIFICAR_ID.md`
- **Contexto actualizado:** `/documentacion/ACTUALIZACION_TRAVEL_COUNT_VERIFICAR_ID.md`
- **Modelo actual:** `/app/models/travel_count.rb`

---

## 💡 Nota para el Futuro

**Cuando llegue el momento de refactorizar:**

1. Revisar este documento
2. Verificar que PHP está deprecado
3. Seguir el plan de refactorización (Opción A o B)
4. Ejecutar tests
5. Limpiar registros vacíos históricos
6. Actualizar documentación

**Código de limpieza futuro:**

```ruby
# lib/tasks/cleanup_travel_counts.rake
namespace :cleanup do
  desc "Limpia registros vacíos de TravelCount"
  task travel_counts: :environment do
    empty_records = TravelCount.where(
      employee_id: nil,
      vehicle_id: nil
    )

    puts "Registros vacíos: #{empty_records.count}"
    empty_records.delete_all
    puts "✅ Limpieza completada"
  end
end
```

---

**Creado por:** Antigravity AI  
**Fecha:** 2026-01-15 12:43  
**Estado:** 📋 PLAN DOCUMENTADO - ACCIÓN FUTURA  
**Próxima Revisión:** Cuando Rails API esté completa
