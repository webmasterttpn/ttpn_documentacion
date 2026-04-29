# Sistema de Privilegios - Guía de Uso

## 📋 Resumen

Se ha implementado un sistema completo de privilegios que permite controlar el acceso a módulos y acciones específicas del sistema basado en roles de usuario.

## 🎯 Características

### Permisos Granulares por Módulo

Cada módulo puede tener los siguientes permisos:

- **Acceso**: Ver el módulo en el menú y acceder a la página
- **Crear**: Mostrar botón de crear/agregar
- **Editar**: Mostrar acción de edición
- **Eliminar**: Mostrar acción de eliminación
- **Clonar**: Mostrar opción de clonar
- **Importar**: Mostrar componente de importación
- **Exportar**: Mostrar opción de exportar/descargar

### SuperAdmin Automático

Los usuarios con `sadmin = true` y `role_id = 1` (Sistemas) tienen acceso completo a todos los módulos automáticamente, sin necesidad de configurar privilegios.

## 🗄️ Estructura de Base de Datos

### Tabla `privileges`

Catálogo de módulos del sistema (34 módulos creados):

- `module_key`: Identificador único (ej: 'clients_directory')
- `module_name`: Nombre visible (ej: 'Directorio de Clientes')
- `module_group`: Grupo al que pertenece (ej: 'Clientes')
- `route_path`: Ruta en el frontend (ej: '/clients')
- `requires_*`: Flags que indican qué acciones están disponibles

### Tabla `role_privileges`

Permisos asignados a cada rol:

- `role_id`: FK al rol
- `privilege_id`: FK al privilegio
- `can_*`: Permisos específicos activados para este rol

## 🔧 Uso en el Frontend

### 1. En el Menú (Automático)

El menú lateral se filtra automáticamente. Solo se muestran los módulos a los que el usuario tiene acceso.

### 2. En Componentes Vue

#### Opción A: Usando el Composable

```vue
<script setup>
import { usePrivileges } from "composables/usePrivileges";

const privileges = usePrivileges("clients_directory");
</script>

<template>
  <div>
    <!-- Botón de crear (solo si tiene permiso) -->
    <q-btn
      v-if="privileges.canCreate()"
      label="Crear Cliente"
      @click="createClient"
    />

    <!-- Botón de editar -->
    <q-btn v-if="privileges.canEdit()" icon="edit" @click="editClient" />

    <!-- Botón de eliminar -->
    <q-btn v-if="privileges.canDelete()" icon="delete" @click="deleteClient" />

    <!-- Botón de importar -->
    <q-btn
      v-if="privileges.canImport()"
      label="Importar Excel"
      @click="showImportDialog = true"
    />

    <!-- Botón de exportar -->
    <q-btn v-if="privileges.canExport()" label="Exportar" @click="exportData" />
  </div>
</template>
```

#### Opción B: Usando el Store Directamente

```vue
<script setup>
import { usePrivilegesStore } from "stores/privileges-store";

const privilegesStore = usePrivilegesStore();
</script>

<template>
  <q-btn
    v-if="privilegesStore.canCreate('employees_directory')"
    label="Crear Empleado"
  />
</template>
```

## 📝 Mapeo de Rutas a Module Keys

| Ruta                           | Module Key                               |
| ------------------------------ | ---------------------------------------- |
| `/`                            | `dashboard`                              |
| `/clients`                     | `clients_directory`                      |
| `/clients/users`               | `client_users`                           |
| `/employees`                   | `employees_directory`                    |
| `/employees/vacations`         | `employee_vacations`                     |
| `/vehicles`                    | `vehicles_fleet`                         |
| `/ttpn_bookings/captura`       | `ttpn_bookings_capture`                  |
| `/travel_counts`               | `travel_counts`                          |
| `/ttpn_bookings/discrepancies` | `discrepancies`                          |
| ...                            | (ver MainLayout.vue para lista completa) |

## 🔐 Configuración de Privilegios

### Rol de Sistemas (ID: 1)

Ya está configurado con acceso completo a todos los módulos. Ejecutado con:

```bash
bundle exec rails runner db/seeds/role_privileges_sistemas.rb
```

### Otros Roles

Para asignar privilegios a otros roles, necesitarás:

1. **Opción A: Crear página de administración** (pendiente)
   - Interfaz visual para asignar privilegios por rol
   - Ubicación sugerida: `/settings` → Gestión de Roles

2. **Opción B: Crear seed manualmente**

   ```ruby
   # Ejemplo: Asignar privilegios al rol "Operador" (role_id = 2)
   operador_role = Role.find(2)

   # Dar acceso solo a lectura de clientes
   RolePrivilege.create!(
     role_id: operador_role.id,
     privilege_id: Privilege.find_by(module_key: 'clients_directory').id,
     can_access: true,
     can_create: false,
     can_edit: false,
     can_delete: false,
     can_clone: false,
     can_import: false,
     can_export: true
   )
   ```

3. **Opción C: Usar Rails Console**

   ```ruby
   rails console

   # Asignar privilegio
   role = Role.find(2)
   privilege = Privilege.find_by(module_key: 'employees_directory')

   RolePrivilege.create!(
     role: role,
     privilege: privilege,
     can_access: true,
     can_create: true,
     can_edit: true,
     can_delete: false,
     can_clone: false,
     can_import: false,
     can_export: true
   )
   ```

## 🧪 Testing

### Verificar privilegios de un usuario

```ruby
# En Rails Console
user = User.find_by(email: 'usuario@ejemplo.com')
user.role.privileges_hash

# Resultado esperado:
# {
#   "clients_directory" => {
#     can_access: true,
#     can_create: true,
#     can_edit: true,
#     ...
#   },
#   ...
# }
```

### Verificar respuesta del login

```bash
curl -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "tu@email.com",
      "password": "tupassword"
    }
  }'
```

Debe devolver:

```json
{
  "message": "Login exitoso",
  "user": {
    "id": 1,
    "email": "tu@email.com",
    "nombre": "Tu Nombre",
    "role_id": 1,
    "role": "sistemas",
    "sadmin": true,
    "business_unit_id": 1
  },
  "privileges": {
    "dashboard": {
      "can_access": true,
      "can_create": false,
      "can_edit": false,
      ...
    },
    "clients_directory": {
      "can_access": true,
      "can_create": true,
      ...
    }
  }
}
```

## 📦 Archivos Creados/Modificados

### Backend

- ✅ `db/migrate/20260217204843_create_privileges_and_role_privileges.rb`
- ✅ `app/models/privilege.rb`
- ✅ `app/models/role_privilege.rb`
- ✅ `app/models/role.rb` (modificado)
- ✅ `app/controllers/users/sessions_controller.rb` (modificado)
- ✅ `db/seeds/privileges.rb`
- ✅ `db/seeds/role_privileges_sistemas.rb`

### Frontend

- ✅ `src/stores/privileges-store.js`
- ✅ `src/stores/auth-store.js` (modificado)
- ✅ `src/composables/usePrivileges.js`
- ✅ `src/layouts/MainLayout.vue` (modificado)

## 🚀 Próximos Pasos

1. **Crear página de administración de privilegios**
   - Interfaz para gestionar roles
   - Interfaz para asignar privilegios a roles
   - Ubicación: `/settings` o `/roles`

2. **Aplicar privilegios en páginas existentes**
   - Ocultar botones de crear/editar/eliminar según permisos
   - Ejemplo: En `ClientsPage.vue`, `EmployeesPage.vue`, etc.

3. **Crear roles adicionales**
   - Operador
   - Supervisor
   - Administrador
   - etc.

4. **Documentar privilegios por rol**
   - Definir qué puede hacer cada rol
   - Crear matriz de permisos

## ⚠️ Notas Importantes

1. **SuperAdmin siempre tiene acceso**: Los usuarios con `sadmin=true` y `role_id=1` tienen acceso completo automáticamente, sin importar los privilegios configurados.

2. **Persistencia**: Los privilegios se guardan en localStorage del navegador, por lo que persisten entre sesiones.

3. **Actualización de privilegios**: Si cambias los privilegios de un rol, el usuario debe hacer logout y login nuevamente para ver los cambios.

4. **Seguridad**: Este sistema solo controla la UI. Debes implementar las mismas validaciones en el backend para cada endpoint.

## 🆘 Troubleshooting

### El menú no se filtra

- Verifica que el usuario tenga privilegios asignados
- Revisa la consola del navegador para errores
- Verifica que el `module_key` en `routeToModuleKey` coincida con el de la base de datos

### Los privilegios no persisten

- Verifica que `persist: true` esté en `privileges-store.js`
- Revisa que `pinia-plugin-persistedstate` esté instalado

### Usuario sin acceso a nada

- Verifica que el rol tenga privilegios asignados en `role_privileges`
- Ejecuta el seed para el rol de Sistemas si es necesario
