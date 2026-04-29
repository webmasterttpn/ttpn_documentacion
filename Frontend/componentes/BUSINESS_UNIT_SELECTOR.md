# 🏢 Business Unit Selector - Documentación

## 📋 Descripción

Sistema que permite a los SuperAdmins cambiar entre diferentes unidades de negocio para ver y administrar datos específicos de cada una. Para usuarios regulares, se auto-selecciona su unidad de negocio asignada.

---

## ✨ Características

- ✅ **Selector visible solo para SuperAdmins** en el header
- ✅ **Auto-selección** para usuarios regulares
- ✅ **Persistencia** en localStorage
- ✅ **Filtrado automático** en todas las peticiones API
- ✅ **Recarga automática** al cambiar de unidad
- ✅ **Notificación visual** al cambiar

---

## 🎯 Cómo Funciona

### Para SuperAdmins

1. **Selector en Header:**
   - Aparece un dropdown en el header (solo desktop)
   - Lista todas las unidades de negocio disponibles
   - Muestra la unidad actualmente seleccionada

2. **Al Seleccionar una Unidad:**
   - Se guarda en `localStorage` como `selected_business_unit_id`
   - Se muestra una notificación
   - La página se recarga automáticamente
   - Todos los datos mostrados son de esa unidad

3. **Persistencia:**
   - La selección se mantiene entre sesiones
   - Se restaura automáticamente al volver a entrar

### Para Usuarios Regulares

1. **Auto-selección:**
   - Se selecciona automáticamente su business_unit asignado
   - No ven el selector (está oculto)
   - Solo ven datos de su unidad

---

## 🔧 Implementación Técnica

### Archivos Creados

#### 1. `useBusinessUnitContext.js` (Composable)

```javascript
// Estado global compartido
const selectedBusinessUnit = ref(null)
const businessUnits = ref([])
const currentUser =
  ref(null) -
  // Funciones principales:
  setCurrentUser(user) -
  loadBusinessUnits() -
  selectBusinessUnit(id) -
  restoreBusinessUnit()
```

#### 2. `BusinessUnitSelector.vue` (Componente)

```vue
<q-select
  v-model="selectedBusinessUnit"
  :options="businessUnits"
  @update:model-value="handleBusinessUnitChange"
/>
```

#### 3. Integración en `MainLayout.vue`

```vue
<BusinessUnitSelector class="gt-sm" />
```

#### 4. Interceptor en `boot/axios.js`

```javascript
api.interceptors.request.use((config) => {
  const selectedBusinessUnitId = localStorage.getItem('selected_business_unit_id')
  if (selectedBusinessUnitId) {
    config.params = {
      ...config.params,
      business_unit_id: selectedBusinessUnitId,
    }
  }
  return config
})
```

---

## 📊 Flujo de Datos

```
1. Usuario entra al sistema
   ↓
2. MainLayout carga usuario actual
   ↓
3. setCurrentUser(authStore.user)
   ↓
4. loadBusinessUnits() - Carga lista de BUs
   ↓
5. restoreBusinessUnit() - Restaura selección guardada
   ↓
6. Si es SuperAdmin: Muestra selector
   Si no: Auto-selecciona su BU
   ↓
7. Usuario cambia BU (solo SuperAdmin)
   ↓
8. selectBusinessUnit(id)
   ↓
9. Guarda en localStorage
   ↓
10. Recarga página
   ↓
11. Interceptor agrega business_unit_id a TODAS las peticiones
   ↓
12. Backend filtra datos por BU
```

---

## 🎨 UI/UX

### Ubicación

- **Desktop:** Header, entre botón "Instalar App" y botones de ayuda
- **Móvil:** Oculto (clase `gt-sm`)

### Estilo

```vue
<q-select outlined dense style="min-width: 250px">
  <template v-slot:prepend>
    <q-icon name="business" />
  </template>
</q-select>
```

### Notificación al Cambiar

```javascript
$q.notify({
  type: 'info',
  message: `Cambiado a: ${buName}`,
  caption: 'Todos los datos mostrarán información de esta unidad',
  icon: 'business',
  position: 'top',
})
```

---

## 🔐 Seguridad

### Backend

El backend SIEMPRE valida:

```ruby
def get_company_id_for_filtering
  company_id = params[:company_id]

  # Solo SuperAdmin puede filtrar por otra company
  if company_id.present? && current_user.sadmin?
    company_id
  else
    # Usuarios regulares solo ven su company
    current_user.business_unit&.company_id
  end
end
```

### Frontend

- El selector solo es visible para SuperAdmins
- Usuarios regulares no pueden cambiar de BU
- La selección se valida en el backend

---

## 📝 Ejemplo de Uso

### SuperAdmin cambia a BU "Chihuahua"

1. **Selecciona en el dropdown:**

   ```
   [Dropdown] → Chihuahua
   ```

2. **Se ejecuta:**

   ```javascript
   selectBusinessUnit(5) // ID de Chihuahua
   localStorage.setItem('selected_business_unit_id', '5')
   window.location.reload()
   ```

3. **Al recargar:**

   ```javascript
   // En axios interceptor
   config.params.business_unit_id = 5

   // Todas las peticiones incluyen:
   GET /api/v1/vehicles?business_unit_id=5
   GET /api/v1/clients?business_unit_id=5
   GET /api/v1/employees?business_unit_id=5
   ```

4. **Backend filtra:**
   ```ruby
   # VehiclesController
   @vehicles = Vehicle.business_unit_filter
                     .where(business_unit_id: params[:business_unit_id])
   ```

---

## 🧪 Testing

### Probar como SuperAdmin

```javascript
// 1. Login como SuperAdmin
// 2. Verificar que aparece el selector
// 3. Cambiar de BU
// 4. Verificar que los datos cambian
// 5. Recargar página
// 6. Verificar que se mantiene la selección
```

### Probar como Usuario Regular

```javascript
// 1. Login como usuario regular
// 2. Verificar que NO aparece el selector
// 3. Verificar que solo ve datos de su BU
```

---

## 🚀 Próximas Mejoras

1. **Indicador Visual Permanente**
   - Badge o chip mostrando BU actual
   - Color diferente por BU

2. **Historial de Cambios**
   - Log de qué BU visitó y cuándo
   - Útil para auditoría

3. **Favoritos**
   - Marcar BUs favoritas
   - Acceso rápido

4. **Comparación**
   - Ver datos de múltiples BUs lado a lado
   - Gráficas comparativas

---

## ✅ Checklist de Implementación

- [x] Composable `useBusinessUnitContext`
- [x] Componente `BusinessUnitSelector`
- [x] Integración en `MainLayout`
- [x] Interceptor en `axios`
- [x] Persistencia en `localStorage`
- [x] Validación de SuperAdmin
- [x] Auto-selección para usuarios regulares
- [x] Notificaciones visuales
- [x] Recarga automática
- [ ] Tests unitarios
- [ ] Tests E2E
- [ ] Documentación de usuario final

---

**Última actualización:** 2025-12-18  
**Versión:** 1.0  
**Estado:** ✅ Funcional
