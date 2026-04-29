# Actualización de Stats Cards

## 1. Reemplazar las líneas 30-64 en TtpnBookingsCapturePage.vue con:

```vue
      <!-- Stats Cards -->
      <div class="row q-col-gutter-md q-mb-lg">
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer" @click="filterByQuickStat('today')">
            <q-card-section>
              <div class="text-h6">{{ stats.today }}</div>
              <div class="text-caption text-grey">Hoy</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer" @click="filterByQuickStat('week')">
            <q-card-section>
              <div class="text-h6">{{ stats.week }}</div>
              <div class="text-caption text-grey">Esta Semana</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer bg-orange-1" @click="filterByQuickStat('pending')">
            <q-card-section>
              <div class="text-h6 text-orange">{{ stats.pending }}</div>
              <div class="text-caption text-grey">Sin Cuadrar</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer bg-green-1" @click="filterByQuickStat('matched')">
            <q-card-section>
              <div class="text-h6 text-green">{{ stats.matched }}</div>
              <div class="text-caption text-grey">Cuadrados</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer bg-grey-3" @click="filterByQuickStat('inactive')">
            <q-card-section>
              <div class="text-h6 text-grey-7">{{ stats.inactive }}</div>
              <div class="text-caption text-grey">Inactivos</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-2">
          <q-card class="cursor-pointer bg-red-1" @click="filterByQuickStat('inconsistent')">
            <q-card-section>
              <div class="text-h6 text-red">{{ stats.inconsistent }}</div>
              <div class="text-caption text-grey">Inconsistencias</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
```

## 2. Agregar casos en filterByQuickStat (después de la línea 677):

```javascript
    case 'inactive':
      // Filtrar solo inactivos
      filters.value.match_status = null
      // TODO: Agregar filtro específico para status=false
      break
    case 'inconsistent':
      // Filtrar inconsistencias
      filters.value.match_status = null
      // TODO: Agregar filtro específico para status=false y viaje_encontrado=true
      break
```

## 3. Backend ya está actualizado ✅

El backend ya devuelve `inactive` e `inconsistent` en el response de `/stats`.
