# EmployeeNameInspector

Componente FE en `src/pages/VehicleAsignations/components/EmployeeNameInspector.vue`.

## Qué hace

En la página **Asignaciones de Vehículos**, modo "filtrar por chofer", muestra el nombre del
empleado seleccionado con tres ayudas para roles **Sistemas / sadmin**:

1. **Resalta en naranja los espacios sobrantes** (leading/trailing) de `nombre`, `apaterno` y
   `amaterno`. Es la causa común de que un chofer no se pueda **autoasignar** desde la app (al dar de
   alta dejaban espacios al final/inicio). Cada espacio se muestra como `␣` con fondo naranja.
2. **Tooltip al hover** con el nombre completo (entre `«»` para ver los espacios) y la **fecha de
   nacimiento**, más un aviso de en qué campos hay espacios.
3. **Clic sobre el nombre** → abre la **edición del empleado en una pestaña nueva**
   (`/employees?edit=ID`).

## Props / Emits

| Prop | Tipo | Descripción |
|---|---|---|
| `employee` | Object | `{ id, nombre, apaterno, amaterno, clv, fecha_nacimiento }` (nombres **crudos**, sin trim) |

| Emit | Payload | Descripción |
|---|---|---|
| `open-edit` | `id` | Solicita abrir la edición del empleado |

## Integración (VehicleAsignationsPage.vue)

- Gate: `canInspectEmployee = authStore.user?.sadmin === true || authStore.user?.role === 'Sistemas'`.
- Carga el empleado completo del seleccionado con `employeesService.find(id)` (para tener nombres
  crudos + `fecha_nacimiento`; el listado usa el serializer minimal que no trae la fecha).
- `openEmployeeEdit(id)` → `window.open(router.resolve({ path: '/employees', query: { edit: id } }).href, '_blank')`.
- Para usuarios sin el rol, se muestra el label plano de siempre (sin inspector).

## Soporte en EmployeesPage

`EmployeesPage.vue` lee `route.query.edit` en `onMounted`: si viene un id válido y el usuario
`canEdit()`, abre el diálogo de edición de ese empleado. **Sin cambios de backend.**
