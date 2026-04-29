# 🔄 Cómo Ver los Cambios del Business Unit Selector

## ✅ Verificación Rápida

### 1. Limpiar Caché del Navegador

```
Ctrl + Shift + R (Windows/Linux)
Cmd + Shift + R (Mac)
```

O manualmente:

1. Abrir DevTools (F12)
2. Clic derecho en el botón de recargar
3. Seleccionar "Vaciar caché y recargar de forma forzada"

---

### 2. Verificar que Quasar está Corriendo

```bash
# En terminal, deberías ver:
App • Opening default browser at http://localhost:9000/
```

Si no está corriendo:

```bash
cd ttpn-frontend
quasar dev -m pwa
```

---

### 3. Navegar a la Ubicación Correcta

**Ruta:** `http://localhost:9000/#/settings`

**Pasos:**

1. Login al sistema
2. Click en el menú lateral → **Configuración** (icono de tuerca)
3. En el sidebar izquierdo, click en **General**
4. Scroll down en el panel derecho

**Deberías ver:**

```
┌─────────────────────────────────┐
│ Nombre de la organización       │
│ Transportación Turística...     │
│ [Editar]                        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Logotipo                        │
│ ○ Logo por defecto              │
│ ○ Utilizar logo del enlace      │
│ ○ Subir                         │
│ [Preview del logo]              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Unidad de Negocio          ← NUEVO!
│ Selecciona la unidad...         │
│ [Dropdown con TTPN/TULPE]       │
└─────────────────────────────────┘
```

---

## 🐛 Si NO Ves el Selector

### Opción 1: Verificar en Consola del Navegador

1. Abrir DevTools (F12)
2. Ir a la pestaña **Console**
3. Buscar errores en rojo
4. Compartir cualquier error que veas

### Opción 2: Verificar Network

1. DevTools → **Network**
2. Recargar la página
3. Buscar `/api/v1/business_units`
4. Verificar que devuelve status 200 con datos

### Opción 3: Verificar Componente

1. DevTools → **Vue DevTools** (si está instalado)
2. Buscar componente `BusinessUnitSelector`
3. Ver si está montado

---

## 📱 Archivos Modificados

```
Frontend:
✅ src/components/BusinessUnitSelector.vue (creado)
✅ src/composables/useBusinessUnitContext.js (creado)
✅ src/pages/SettingsPage.vue (modificado)
✅ src/pages/BusinessUnitsPage.vue (creado)
✅ src/boot/axios.js (modificado)

Backend:
✅ app/controllers/api/v1/business_units_controller.rb (existe)
```

---

## 🔍 Debug Rápido

### En la Consola del Navegador:

```javascript
// Verificar si el componente existe
document.querySelector('.business-unit-selector')

// Verificar datos en localStorage
localStorage.getItem('selected_business_unit_id')

// Verificar endpoint
fetch('http://localhost:3000/api/v1/business_units', {
  credentials: 'include',
})
  .then((r) => r.json())
  .then(console.log)
```

---

## ✅ Checklist de Verificación

- [ ] Quasar dev está corriendo
- [ ] Navegador en http://localhost:9000
- [ ] Logged in al sistema
- [ ] En Settings → General
- [ ] Caché limpiado (Ctrl+Shift+R)
- [ ] No hay errores en consola
- [ ] Endpoint /api/v1/business_units responde

---

## 🆘 Si Sigue Sin Funcionar

1. **Detener Quasar:**

   ```bash
   # Ctrl+C en el terminal de quasar
   ```

2. **Limpiar y Reiniciar:**

   ```bash
   rm -rf .quasar
   quasar dev -m pwa
   ```

3. **Verificar que los archivos existen:**

   ```bash
   ls -la src/components/BusinessUnitSelector.vue
   ls -la src/composables/useBusinessUnitContext.js
   ```

4. **Ver logs de Quasar en tiempo real**
   - Dejar abierto el terminal donde corre `quasar dev`
   - Ver si hay errores cuando navegas a Settings

---

**Última actualización:** 2025-12-18  
**Ubicación:** Settings → General → Tarjeta "Unidad de Negocio"
