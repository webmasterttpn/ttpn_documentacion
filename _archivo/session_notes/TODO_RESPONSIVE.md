# 📱 TODO - Adaptación Móvil PWA

## 🔴 Urgente - Responsive

### 1. BusinessUnitsPage - Adaptar a Móvil

**Problema:** Usa tabla fija que no se adapta a móviles

**Solución:**

```vue
<q-table
  :grid="$q.screen.lt.md"  // ← Agregar esto
  ...
>
  <!-- Agregar template v-slot:item para vista card -->
  <template v-slot:item="props">
    <div class="q-pa-xs col-xs-12">
      <q-card>
        <!-- Card responsive -->
      </q-card>
    </div>
  </template>
</q-table>
```

**Archivo:** `src/pages/BusinessUnitsPage.vue`

---

### 2. ApiAccessPage - Adaptar a Móvil

**Problema:** Usa tablas fijas que no se adaptan a móviles

**Solución:**

- Aplicar mismo patrón de UsersPage
- `:grid="$q.screen.lt.md"` en ambas tablas (API Users y API Keys)
- Crear templates de cards para móvil

**Archivo:** `src/pages/ApiAccessPage.vue`

---

## 📋 Patrón a Seguir

Basado en `UsersPage.vue` (líneas 5-140):

```vue
<q-table
  :grid="$q.screen.lt.md"  // Auto-switch a cards en móvil
  :rows="rows"
  :columns="columns"
  flat
  bordered
>
  <!-- Vista tabla (desktop) -->
  <template v-slot:body-cell-actions="props">
    <!-- Botones normales -->
  </template>

  <!-- Vista cards (móvil) -->
  <template v-slot:item="props">
    <div class="q-pa-xs col-xs-12 col-sm-6">
      <q-card flat bordered>
        <q-item>
          <q-item-section avatar>
            <q-avatar />
          </q-item-section>
          <q-item-section>
            <q-item-label>{{ props.row.nombre }}</q-item-label>
            <q-item-label caption>{{ props.row.clv }}</q-item-label>
          </q-item-section>
        </q-item>
        <q-card-actions>
          <!-- Botones de acción -->
        </q-card-actions>
      </q-card>
    </div>
  </template>
</q-table>
```

---

## ✅ Checklist

- [ ] BusinessUnitsPage responsive
- [ ] ApiAccessPage - Tabla de API Users responsive
- [ ] ApiAccessPage - Tabla de API Keys responsive
- [ ] Probar en móvil real
- [ ] Probar en tablet
- [ ] Probar rotación de pantalla

---

**Prioridad:** ALTA  
**Estimado:** 1-2 horas  
**Impacto:** Crítico para PWA
