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
- `db/seeds/03_users_settings.rb` — seed con default 6.
- `spec/models/kumi_setting_spec.rb` — 2 specs nuevos (default + valor almacenado).
  RSpec: 25 examples, 0 failures. RuboCop: 0 offenses.

### Frontend (`ttpn-frontend`)
- `src/pages/Settings/Organizacion/PayrollConfigSettings.vue` — card nuevo,
  estado `toleranceConfig`, `savingTolerance`, `saveToleranceConfig` (usa `notifyApiError`).
  ESLint: 0 errores.

## Pendiente / follow-up

- **APK móvil:** actualmente el plazo de 6 h está hardcodeado en el APK. Para que el
  setting tenga efecto real, la app móvil debe leer `tiempo_tolerancia` desde
  `GET /api/v1/kumi_settings/payroll` en lugar del valor fijo. Es un cambio en el
  repo del APK (fuera de este monorepo).

## Ver también

- [multi_tenancy_kumi_settings.md](../../INFRA/arquitectura/multi_tenancy_kumi_settings.md) — KumiSetting por BusinessUnit
- [Frontend/paginas/settings/](../../Frontend/paginas/settings/) — páginas de configuración
