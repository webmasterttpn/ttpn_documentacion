# Nota de sesión — Tiempo de Tolerancia (Configuración de Nómina)

**Fecha:** 2026-05-18

---

## Objetivo

Agregar un parámetro configurable "Tiempo de Tolerancia": las horas que tiene un
chofer para capturar un viaje en la app móvil. Hoy está hardcodeado en el APK (6 horas).

## Decisiones

- **Dónde se guarda:** tabla `kumi_settings`, sin columna ni tabla nueva. Es un renglón
  key-value: `key = payroll.tiempo_tolerancia`, `category = payroll`, `value` string en horas.
  Índice único `[business_unit_id, key]` → un valor por BU.
- **Unidad:** horas (entero). Default 6 (valor histórico del APK).
- **UI:** card separado "Tiempo de Tolerancia" debajo de "Parámetros de Nómina",
  con su propio botón Guardar (no se mezcla con el batch de los otros 3 parámetros).
- **Permisos:** reutiliza el endpoint protegido existente de `kumi_settings`
  (`Api::V1::BaseController` ya exige autenticación). No requiere privilegio extra.

## Cambios

### Backend (`ttpngas`)
- `app/models/kumi_setting.rb` — `PAYROLL_KEYS[:tiempo_tolerancia]`, accesor
  `payroll_tiempo_tolerancia` (default '6' → int), agregado a `initialize_defaults`.
- `app/controllers/api/v1/kumi_settings_controller.rb` — `#payroll` ahora expone
  `tiempo_tolerancia`. El guardado usa el `batch_update` genérico existente.
- `db/seeds/03_users_settings.rb` — ver sección "Bug de seeds" abajo.
- `spec/models/kumi_setting_spec.rb` — 2 specs nuevos (default + valor almacenado).
  RSpec: 25 examples, 0 failures. RuboCop: 0 offenses.

## Bug de seeds detectado y corregido (keys muertas)

**Síntoma reportado:** la tabla `kumi_settings` estaba vacía en Supabase. Verificado:
también 0 renglones en la DB local (`ttpngas_development`). La app funcionaba con
los **defaults del código** (`payroll_dia_pago` etc. devuelven default si no hay fila),
por eso el panel mostraba valores sin que existiera nada persistido. No hubo pérdida
de datos — simplemente nunca se persistió.

**Causa raíz (pre-existente):** el seed escribía keys que el modelo nunca lee:

| Seed escribía | Modelo lee | Coincide |
| --- | --- | --- |
| `payroll_day` (`'friday'`) | `payroll.dia_pago` (numérico) | ❌ |
| `payroll_frequency` (`'weekly'`) | `payroll.periodo` (`'semanal'`) | ❌ |
| *(faltaba)* | `payroll.hora_corte` | ❌ |
| `vacation_days_year1/2` | `vacations.periodos` (JSON) | ❌ |

**Solución (DRY):** el seed ahora itera **todas** las BusinessUnits y llama a
`KumiSetting.initialize_defaults(bu.id)` (fuente única de verdad de las keys), con
guard no-destructivo (`unless payroll_settings.exists?`). Se conserva `timezone`
(general, no cubierto por initialize_defaults). Se eliminaron las entradas con keys
muertas y la línea redundante de `tiempo_tolerancia` (initialize_defaults ya la incluye).

**Persistido en local:** se ejecutó `initialize_defaults` para todas las BU →
10 renglones (5 por BU: dia_pago=4, periodo=semanal, hora_corte=01:30,
tiempo_tolerancia=6, vacations.periodos=JSON LFT 2023).
RuboCop seed: 43→40 ofensas (las 40 son el estilo `puts` pre-existente del archivo).

**Pendiente prod:** ejecutar en Supabase/producción
`BusinessUnit.find_each { |b| KumiSetting.initialize_defaults(b.id) unless b.kumi_settings.payroll_settings.exists? }`
o correr los seeds, para que la tabla deje de depender solo de los defaults del código.

### Frontend (`ttpn-frontend`)
- `src/pages/Settings/Organizacion/PayrollConfigSettings.vue` — card nuevo,
  estado `toleranceConfig`, `savingTolerance`, `saveToleranceConfig` (usa `notifyApiError`).
  ESLint: 0 errores.

## Hardening: scope de API Key en kumi_settings

Se detectó que `KumiSettingsController` **no** incluía `ApiKeyAuthorizable`: cualquier
API Key válida podía leer/escribir settings sin importar su scope (el checkbox
"Configuraciones de Kumi" en la UI de API Keys era decorativo en este endpoint).

**Solución aplicada:**

- `include ApiKeyAuthorizable` en `KumiSettingsController`.
- Override de `action_permission_mapping` para mapear las acciones collection:
  `index/payroll/vacations` → `read`; `update/update_vacations/batch_update/initialize_defaults` → `update`.
  Sin el override, el concern mandaba toda acción no-CRUD a `read` → escalada de
  privilegios (escribir settings con permiso de solo lectura).
- 4 request specs nuevos: 403 sin scope, 200 con read, 403 en batch_update con
  read-only (anti-escalada), 200 en batch_update con update.

**Efecto en el APK:** la API Key que use la app móvil ahora **requiere** el permiso
`kumi_settings → Ver (read)` (grupo "Administración" → "Configuraciones de Kumi" en
la UI de edición de API Key) para leer `GET /api/v1/kumi_settings/payroll`.

RSpec: 35 examples, 0 failures. RuboCop: 0 ofensas nuevas (queda 1 pre-existente
`InferredSpecType` en línea 5, fuera de la zona modificada).

## Pendiente / follow-up

- **APK móvil:** actualmente el plazo de 6 h está hardcodeado en el APK. Para que el
  setting tenga efecto real, la app móvil debe leer `tiempo_tolerancia` desde
  `GET /api/v1/kumi_settings/payroll` en lugar del valor fijo, **y su API Key debe
  tener el permiso `kumi_settings → read`**. Es un cambio en el repo del APK
  (fuera de este monorepo).

## Ver también

- [multi_tenancy_kumi_settings.md](../../INFRA/arquitectura/multi_tenancy_kumi_settings.md) — KumiSetting por BusinessUnit
- [Frontend/paginas/settings/](../../Frontend/paginas/settings/) — páginas de configuración
