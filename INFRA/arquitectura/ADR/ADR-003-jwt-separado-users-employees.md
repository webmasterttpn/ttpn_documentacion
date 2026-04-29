# ADR-003 — JWTs Separados para Usuarios Admin y Choferes

**Fecha:** 2026-04-11  
**Estado:** Propuesto (pendiente implementación)  
**Autor:** Antonio Castellanos

---

## Contexto

La app móvil necesita autenticación. Los choferes son `Employee`, no `User`. Se podría reutilizar el mismo sistema JWT de los usuarios admin para los choferes.

## Decisión

JWTs completamente separados e incompatibles para cada tipo de actor:

| | JWT de Usuario (Admin) | JWT de Chofer (Móvil) |
|---|---|---|
| Modelo | `User` | `Employee` |
| Payload | `{ user_id, jti, exp }` | `{ employee_id, vehicle_id, jti, exp }` |
| Hereda de | `Api::V1::BaseController` | `Api::V1::MobileBaseController` |
| Namespace rutas | `/api/v1/*` | `/api/v1/mobile/*` |
| Expiración | 24 horas | 7 días |

## Razones

Un chofer con su token **nunca debe poder acceder a endpoints del panel admin**. Si se usa el mismo mecanismo, un bug de autorización podría dar acceso cross-namespace.

Con namespaces y JWTs separados, la separación es estructural: el `MobileBaseController` busca `Employee.find(decoded['employee_id'])` — si el token no tiene ese campo, falla. El `BaseController` busca `User.find(decoded['user_id'])` — un token de chofer no tiene ese campo.

Adicionalmente, el login del chofer es diferente (clave de vehículo + datos personales, no email+password) y la sesión dura más (7 días, porque no tiene sentido que un chofer tenga que re-autenticarse cada día).

## Consecuencias

- Requiere migración: `add_column :employees, :jti, :string`
- Requiere `MobileBaseController` nuevo con su propia lógica de validación JWT
- El campo `employees.imei` (legacy PHP) se reutiliza para guardar el `AndroidID` del dispositivo para binding opcional
- Los endpoints móviles van en namespace `/api/v1/mobile/` — mismos nombres de recurso que el admin (`travel_counts`, `bookings`) pero controllers diferentes
- Ver implementación completa en `AUTH_MOVIL_CHOFERES.md`