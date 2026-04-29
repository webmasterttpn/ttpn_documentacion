# Código para Agregar a ApiAccessPage.vue

## 1. Agregar ANTES del cierre </q-page> (línea 307):

```vue
<!-- Dialog para crear API Key con permisos -->
<q-dialog v-model="showCreateKeyDialog" persistent>
      <q-card style="min-width: 700px; max-width: 800px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">🔑 Crear API Key</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section>
          <div class="text-body2 q-mb-md">
            Usuario API: <strong>{{ selectedApiUserForKey?.name }}</strong>
          </div>

          <q-form @submit="saveApiKey" class="q-gutter-md">
            <q-input
              v-model="keyFormData.name"
              label="Nombre de la clave *"
              outlined
              hint="Ej: Producción, Testing, Desarrollo"
              :rules="[(val) => !!val || 'Campo requerido']"
            />

            <q-input
              v-model="keyFormData.expires_at"
              label="Fecha de expiración (opcional)"
              outlined
              type="date"
            />

            <div class="text-subtitle2 q-mt-md q-mb-sm">Permisos:</div>
            
            <q-scroll-area style="height: 300px" class="bordered">
              <div v-for="(actions, resource) in availablePermissions" :key="resource" class="q-pa-md">
                <div class="text-weight-bold text-primary q-mb-sm">{{ formatResourceName(resource) }}</div>
                <div class="row q-gutter-sm">
                  <q-checkbox
                    v-for="(label, action) in actions"
                    :key="`${resource}-${action}`"
                    v-model="keyFormData.permissions[resource][action]"
                    :label="label"
                    dense
                  />
                </div>
                <q-separator class="q-mt-md" />
              </div>
            </q-scroll-area>

            <div class="row justify-end q-gutter-sm q-mt-md">
              <q-btn label="Cancelar" flat v-close-popup />
              <q-btn
                label="Crear Clave"
                type="submit"
                color="primary"
                unelevated
                :loading="saving"
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
```

## 2. Agregar en el script setup (después de las variables de estado existentes):

```javascript
const showCreateKeyDialog = ref(false);
const selectedApiUserForKey = ref(null);
const availablePermissions = ref({});

const keyFormData = ref({
  name: "",
  expires_at: null,
  permissions: {},
});
```

## 3. Agregar funciones (después de las funciones existentes):

```javascript
const loadAvailablePermissions = async () => {
  try {
    const { data } = await api.get("/api/v1/api_keys/permissions");
    availablePermissions.value = data.available_permissions;

    // Inicializar permisos en false
    const initialPermissions = {};
    Object.keys(data.available_permissions).forEach((resource) => {
      initialPermissions[resource] = {};
      Object.keys(data.available_permissions[resource]).forEach((action) => {
        initialPermissions[resource][action] = false;
      });
    });
    keyFormData.value.permissions = initialPermissions;
  } catch (err) {
    console.error("Error loading permissions:", err);
  }
};

const createApiKey = (apiUser) => {
  selectedApiUserForKey.value = apiUser;
  keyFormData.value = {
    name: "",
    expires_at: null,
    permissions: { ...keyFormData.value.permissions },
  };
  // Resetear todos los permisos a false
  Object.keys(keyFormData.value.permissions).forEach((resource) => {
    Object.keys(keyFormData.value.permissions[resource]).forEach((action) => {
      keyFormData.value.permissions[resource][action] = false;
    });
  });
  showCreateKeyDialog.value = true;
};

const saveApiKey = async () => {
  saving.value = true;
  try {
    const { data } = await api.post("/api/v1/api_keys", {
      api_key: {
        name: keyFormData.value.name,
        api_user_id: selectedApiUserForKey.value.id,
        expires_at: keyFormData.value.expires_at || null,
        permissions: keyFormData.value.permissions,
      },
    });

    newApiKey.value = data.key;
    showCreateKeyDialog.value = false;
    showKeyDialog.value = true;

    $q.notify({
      type: "positive",
      message: "API Key creada exitosamente",
    });

    loadApiKeys();
    loadApiUsers();
  } catch (err) {
    $q.notify({
      type: "negative",
      message:
        err.response?.data?.errors?.join(", ") || "Error al crear API Key",
    });
  } finally {
    saving.value = false;
  }
};

const formatResourceName = (resource) => {
  const names = {
    vehicles: "Vehículos",
    clients: "Clientes",
    employees: "Empleados",
    bookings: "Reservas",
    users: "Usuarios de Plataforma",
    api_users: "Usuarios de API",
  };
  return names[resource] || resource;
};
```

## 4. Agregar en onMounted:

```javascript
onMounted(() => {
  loadApiUsers();
  loadApiKeys();
  loadBusinessUnits();
  loadAvailablePermissions(); // ← AGREGAR ESTA LÍNEA
});
```

## 5. Agregar en el return del setup:

```javascript
return {
  // ... todo lo existente ...
  showCreateKeyDialog,
  selectedApiUserForKey,
  availablePermissions,
  keyFormData,
  createApiKey,
  saveApiKey,
  formatResourceName,
  loadAvailablePermissions,
};
```

## 6. Agregar estilo CSS al final (antes del </style>):

```css
.bordered {
  border: 1px solid #e0e0e0;
  border-radius: 4px;
}
```
