# Estándar de Modales — Análisis y Definición

**Fecha:** 2026-03-30
**Estado:** EN ANÁLISIS

---

## Diagnóstico actual

### Por qué Vehicles funciona bien

El dialog de Vehicles usa `width: 900px; max-width: 100vw` **sin** `max-height`.
Funciona porque tiene 2 tabs con contenido moderado — el dialog nunca supera la altura del viewport.

### Por qué Employees pierde el foco

Estructura **idéntica** a Vehicles, pero tiene 5 tabs. El tab "Datos Generales" tiene ~120 líneas de
campos de formulario. Resultado:
- El dialog crece más allá del viewport → el footer queda fuera de pantalla
- Al cambiar de tab largo a tab corto el dialog se encoge → el usuario pierde referencia visual
- En móvil es especialmente problemático

### Por qué Clients ocupa demasiado espacio

Usa `maximized` incondicionalmente en escritorio — toma toda la pantalla para un formulario
que podría mostrarse centrado. Apropiado solo cuando el contenido lo justifica genuinamente.

---

## Patrón estándar propuesto

### Dialog tipo "Tabbed CRUD" (Vehicles, Employees)

```vue
<q-dialog
  v-model="dialogOpen"
  :maximized="$q.screen.lt.sm"
  persistent
  transition-show="scale"
  transition-hide="scale"
>
  <!-- flex column + max-height = toolbar sticky, footer sticky, contenido scrollable -->
  <q-card style="width: 900px; max-width: 100vw; max-height: 90vh; display: flex; flex-direction: column;">

    <!-- ① Toolbar — sticky (flex-shrink: 0) -->
    <q-toolbar class="bg-white text-primary shadow-1" style="flex-shrink: 0;">
      <q-toolbar-title class="text-weight-bold">{{ isEditing ? 'Editar X' : 'Nuevo X' }}</q-toolbar-title>
      <q-btn flat round dense icon="close" v-close-popup color="grey-7" />
    </q-toolbar>

    <!-- ② Tabs — sticky (flex-shrink: 0) -->
    <q-tabs v-model="tab" dense class="text-grey" active-color="primary"
      indicator-color="primary" align="justify" narrow-indicator style="flex-shrink: 0;" />
    <q-separator style="flex-shrink: 0;" />

    <!-- ③ Contenido — scrollable (flex: 1, min-height: 0) -->
    <q-scroll-area style="flex: 1; min-height: 0;">
      <q-tab-panels v-model="tab" animated>
        <q-tab-panel name="general">
          <!-- form fields -->
        </q-tab-panel>
        <!-- más tabs -->
      </q-tab-panels>
    </q-scroll-area>

    <!-- ④ Footer — sticky (flex-shrink: 0) -->
    <q-separator style="flex-shrink: 0;" />
    <q-card-actions align="right" class="bg-white q-pa-md" style="flex-shrink: 0;">
      <q-btn outline label="Cancelar" color="grey-8" v-close-popup />
      <q-btn unelevated color="primary" label="Guardar" @click="save" :loading="saving" />
    </q-card-actions>

  </q-card>
</q-dialog>
```

**Claves del fix:**
- `display: flex; flex-direction: column` en `q-card`
- `max-height: 90vh` en `q-card`
- `flex-shrink: 0` en toolbar, tabs, separador, footer
- `flex: 1; min-height: 0` + `q-scroll-area` en la zona de contenido

### Dialog tipo "Simple Form" (TravelCountsFormDialog, BookingCapture modals)

```vue
<q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
  <q-card style="min-width: 600px; max-width: 95vw; max-height: 90vh; display: flex; flex-direction: column;">
    <q-card-section class="row items-center q-pb-none" style="flex-shrink: 0;">
      <div class="text-h6">Título</div>
      <q-space />
      <q-btn icon="close" flat round dense v-close-popup />
    </q-card-section>
    <q-scroll-area style="flex: 1; min-height: 0; min-height: 300px;">
      <q-card-section>
        <!-- form fields -->
      </q-card-section>
    </q-scroll-area>
    <q-card-actions align="right" style="flex-shrink: 0;">
      <q-btn label="Cancelar" color="grey" flat v-close-popup />
      <q-btn label="Guardar" color="primary" :loading="saving" @click="onSave" />
    </q-card-actions>
  </q-card>
</q-dialog>
```

### Dialog tipo "Detail / Show" (TravelCountsDetailDialog, BookingCaptureDetailDialog)

```vue
<q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
  <q-card style="width: 700px; max-width: 95vw; max-height: 90vh; display: flex; flex-direction: column;">
    <q-toolbar class="bg-primary text-white" style="flex-shrink: 0;">
      <q-toolbar-title class="text-weight-bold">Detalle</q-toolbar-title>
      <q-btn flat round dense icon="close" v-close-popup color="white" />
    </q-toolbar>
    <q-scroll-area style="flex: 1; min-height: 0;">
      <q-card-section>
        <q-list bordered separator>
          <!-- q-items -->
        </q-list>
      </q-card-section>
    </q-scroll-area>
    <q-card-actions align="right" style="flex-shrink: 0;">
      <q-btn label="Cerrar" color="primary" flat v-close-popup />
    </q-card-actions>
  </q-card>
</q-dialog>
```

### Dialog tipo "Maximized" (solo cuando el contenido lo requiere)

Usar **únicamente** cuando el contenido tiene múltiples niveles de anidación con
forms complejos (ej. ClientForm con sucursales → servicios → incrementos → detalles).

```vue
<q-dialog v-model="showDialog" persistent maximized>
  <ClientForm @save="handleSave" @cancel="showDialog = false" />
</q-dialog>
```

### Dialog tipo "Small / Confirm / Upload" (400–500px)

```vue
<q-dialog v-model="open">
  <q-card style="width: 500px; max-width: 95vw;">
    <q-card-section class="row items-center q-pb-none">
      <div class="text-h6">Título</div>
      <q-space /><q-btn icon="close" flat round dense v-close-popup />
    </q-card-section>
    <q-card-section><!-- contenido --></q-card-section>
    <q-card-actions align="right">
      <q-btn label="Cancelar" flat v-close-popup />
      <q-btn label="Confirmar" color="primary" @click="confirm" />
    </q-card-actions>
  </q-card>
</q-dialog>
```

---

## Tipos de modal por página (estado actual)

| Página | Modal | Tipo | Estado |
|---|---|---|---|
| VehiclesPage | CRUD Vehículo | Tabbed CRUD 900px | ⚠️ Falta flex+max-height |
| VehiclesPage | Upload documento | Small 400px | ✅ OK |
| VehiclesPage | Visor documento | Maximized fullscreen | ✅ OK |
| EmployeesPage | View empleado | Detail 700px | ⚠️ Falta flex+max-height |
| EmployeesPage | CRUD Empleado | Tabbed CRUD 900px | ❌ Overflow sin control |
| EmployeesPage | Upload documento | Small 400px | ✅ OK |
| EmployeesPage | Visor documento | Maximized fullscreen | ✅ OK |
| ClientsPage | CRUD Cliente | Maximized | ✅ Justificado (muy complejo) |
| ClientsPage | Detail Cliente | Maximized | 🔶 Discutible — podría ser 900px |
| TravelCountsPage | Form CRUD | Simple 600px | ⚠️ Falta flex+max-height |
| TravelCountsPage | Detail | Simple 600px | ⚠️ Falta flex+max-height |
| TravelCountsPage | Import Excel | Small 500px | ✅ OK |
| CapturePage | Import Excel | Small 500px | ✅ OK |
| CapturePage | Detail | Simple 800px | ⚠️ Falta flex+max-height |
| CapturePage | Delete progress | Small persistente | ✅ OK |
| AppointmentDialog | CRUD Cita | Simple 500-600px | ✅ Estructura OK |
| VehicleCheckDialog | CRUD Check | Simple 600px | ✅ Estructura OK |

---

## Componentes anidados identificados por modal

### VehiclesPage — Dialog CRUD Vehículo (tabs: General, Documentos)

| Tab | Componentes candidatos a extraer | Prioridad |
|---|---|---|
| General | `VehicleGeneralForm.vue` — campos básicos del vehículo | Media |
| Documentos | `DocumentSection.vue` — lista de docs con visor y upload | Alta |
| Shared | `DocumentViewer.vue` — visor fullscreen de imágenes/PDF | Alta |
| Shared | `DocumentUploadDialog.vue` — dialog upload 400px | Media |

### EmployeesPage — Dialog CRUD Empleado (tabs: General, Documentos, Salarios, Movimientos, Niveles)

| Tab | Componentes candidatos a extraer | Prioridad |
|---|---|---|
| General | `EmployeeGeneralForm.vue` — datos personales y laborales | Media |
| Documentos | `DocumentSection.vue` — **mismo componente que Vehicles** | Alta |
| Salarios | `SalaryHistorySection.vue` — lista de salarios con add/remove | Media |
| Movimientos | `MovementHistorySection.vue` — lista de movimientos | Media |
| Niveles de Chofer | `DriverLevelsSection.vue` — niveles de chofer | Baja |

### ClientsPage — Dialog CRUD Cliente (maximized, sin tabs pero muy anidado)

| Sección | Componentes candidatos a extraer | Prioridad |
|---|---|---|
| Datos básicos | `ClientBasicForm.vue` | Baja |
| Sucursales | `BranchOfficesSection.vue` — lista editable de sucursales | Media |
| Servicios | `ClientServicesSection.vue` — servicios con incrementos | Baja |
| Incrementos | `ServiceIncrementsSection.vue` — muy complejo | Baja |

### TravelCountsPage — Dialog Form (sin tabs)

| Sección | Notas |
|---|---|
| Form completo | Ya es un componente: `TravelCountsFormDialog.vue` ✅ |
| Sección autorización | Podría ser `AuthorizationSection.vue` si se reutiliza en otros forms |

---

## Plan de acción (orden sugerido)

1. **Fix inmediato** — Aplicar `flex column + max-height + q-scroll-area` a los modales que tienen overflow:
   - `EmployeesPage` dialog CRUD (urgente, reproduce el bug)
   - `VehiclesPage` dialog CRUD (preventivo)
   - `TravelCountsFormDialog`, `BookingCaptureDetailDialog` (preventivo)

2. **Corto plazo** — Extraer `DocumentSection.vue` compartido entre Vehicles y Employees
   (evita duplicación de ~80 líneas idénticas de template)

3. **Mediano plazo** — Extraer componentes de tab por página
   (SalaryHistorySection, MovementHistorySection, DriverLevelsSection para Employees)

4. **Largo plazo** — Analizar si ClientDetails puede reducirse de `maximized` a `900px tabbed`
   cuando los datos anidados sean suficientemente pequeños

---

## Regla de selección de tipo de modal

```
¿El contenido tiene múltiples niveles de edición anidada (ej. cliente → sucursal → servicio)?
  → Maximized

¿El contenido tiene secciones diferenciadas con muchos campos cada una?
  → Tabbed CRUD 900px  (CON flex+max-height+scroll)

¿Es un formulario de ~8–12 campos sin secciones?
  → Simple Form 600px  (CON flex+max-height+scroll)

¿Es lectura de detalles sin edición?
  → Detail 700px  (CON flex+max-height+scroll)

¿Es confirmación, upload, o acción puntual?
  → Small 400–500px  (sin scroll necesario)
```
