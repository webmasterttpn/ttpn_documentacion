# ADR-006 — Sistema de Privilegios por Módulo en lugar de Roles Simples

**Fecha:** 2026-04-10  
**Estado:** Aceptado  
**Autor:** Antonio Castellanos

---

## Contexto

El sistema original usaba `role_id` directamente en el código para controlar acceso:

```ruby
# Patrón viejo — eliminado
if current_user.role_id == 1  # hardcoded "sistemas"
  # ...
end
```

Con 10+ roles distintos y módulos que necesitan control granular (ver pero no crear, crear pero no eliminar), este enfoque no escala.

## Decisión

Sistema de dos capas:

**Capa 1 — Roles:** definen el perfil del usuario (Administrador, RH, Coordinador, etc.)  
**Capa 2 — Privilegios:** definen qué puede hacer en cada módulo (acceso, crear, editar, eliminar, clonar, importar, exportar)

```
Role → RolePrivilege → Privilege (module_key, requires_create, requires_edit, ...)
```

Al hacer login, el BE retorna el objeto `privileges` completo. El FE lo almacena en Pinia y lo consulta con `usePrivileges('module_key')`.

## Razones

El control de acceso basado en roles simples (`role_id == 1`) es frágil: agregar un rol nuevo requiere encontrar y modificar todos los `if role_id == X` en el codebase. Con el sistema de privilegios, agregar un rol nuevo es cuestión de asignarle los privilegios correspondientes en la UI de Settings.

Además, los mismos módulos necesitan permisos distintos por contexto: el coordinador puede ver bookings pero no eliminarlos, el admin puede todo.

## Consecuencias

- **El FE nunca verifica `role_id` directamente.** Si se encuentra un `role_id` hardcodeado en el FE, es un bug.
- Los nuevos módulos deben registrar su `Privilege` en el seed (`db/seeds/`) con los flags correctos (`requires_create`, `requires_edit`, etc.).
- Al crear un nuevo rol, asignarle privilegios desde `Settings → Usuarios y Permisos → Roles`.
- El objeto `privileges` en el JWT tiene TTL de 24h — si se cambian los permisos de un usuario, este debe hacer logout y login para verlos aplicados.
- `sadmin? == true` en `User` bypasea todo el sistema de privilegios: tiene acceso completo a todo.