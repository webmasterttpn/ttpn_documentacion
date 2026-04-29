# Dominio: Configuración

Agrupa toda la configuración del sistema dividida por área. Cada sub-dominio tiene su propia carpeta.

## Sub-dominios

| Carpeta | Qué configura |
| --- | --- |
| [organizacion/](organizacion/) | Nombre de la empresa, BU, configuración general |
| [vehicular/](vehicular/) | Tipos de vehículo, tarifas, parámetros de flotilla |
| [empleado/](empleado/) | Días de vacaciones por año, tipos de documento, labores |
| [integraciones/](integraciones/) | API Keys para apps externas, webhooks, N8N |
| [usuarios_permisos/](usuarios_permisos/) | Roles, privilegios, gestión de usuarios |

## Modelo principal compartido

`KumiSetting` — tabla de configuración clave-valor con `business_unit_id` y `category`. Cada sub-dominio usa categorías distintas en esta tabla.

```ruby
KumiSetting.where(business_unit_id: bu.id, category: 'vacaciones')
```

## Archivos Rails relacionados

```text
app/models/kumi_setting.rb
app/models/role.rb
app/models/privilege.rb
app/models/role_privilege.rb
app/models/roles_user.rb
app/controllers/api/v1/kumi_settings_controller.rb
app/controllers/api/v1/roles_controller.rb
app/controllers/api/v1/privileges_controller.rb
```
