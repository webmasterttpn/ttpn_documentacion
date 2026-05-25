# 2026-05-25 — Dashboard: privilegios por tab + carga perezosa

## Problema (reporte del usuario)

1. En **gestión de privilegios**, aunque "Dashboard" aparece bajo "General", **no se podía seccionar
   y dar permiso por tab** (view por tab).
2. Al entrar al Dashboard se **auto-cargaba todo**, lo que hace que la pantalla **se sienta lenta**.
   Se quiere que **no se cargue nada hasta presionar "Generar"**, y solo lo del tab que aplica.

## Diagnóstico

- El sistema **ya soporta** privilegios por tab: el seed `db/seeds/privileges.rb` define
  `dashboard_revenue`, `dashboard_ttpns`, `dashboard_taller` (grupo "General"), el FE ya los lee con
  `usePrivileges(...)` y la pantalla de gestión los listaría agrupados por `module_group`.
- **Causa raíz:** esos 3 privilegios **nunca se sembraron** en la BD (solo existía `dashboard`). Por
  eso en gestión de privilegios solo se veía una fila y el FE caía al fallback "mostrar todos los tabs".
- Carga: `DashboardPage.vue` hacía `onMounted(onLoad)` → cargaba la matriz de Ingresos al entrar
  (aunque el tab accesible fuera otro). El tab **TTPNs ya era manual** ("Consultar"). El tab **Taller**
  (WorkshopOpsPanel/WorkshopWeeklyTab) auto-carga `onMounted` y se comparte con Finanzas.

## Decisiones (confirmadas con el usuario)

- Disparo de carga: **no cargar nada hasta "Generar"**.
- Alcance: **solo Dashboard** por ahora (luego se replica el patrón a otras páginas pesadas).

## Cambios

### Backend (ttpngas) — privilegios por tab
- Sembrados en **dev local** los 3 privilegios faltantes (`dashboard_revenue`, `dashboard_ttpns`,
  `dashboard_taller`) vía runner idempotente (`find_or_initialize_by(:module_key)`), con sus atributos
  exactos del seed. No se re-corrió el seed completo para no sobrescribir ajustes de otros privilegios.
- Sin cambios de código BE: el modelo `Privilege`, `role_privileges_controller` y la pantalla de
  gestión ya soportan listar/asignar estos privilegios. Solo faltaba la data.

### Frontend (ttpn-frontend) — carga perezosa
- `pages/Dashboard/DashboardPage.vue`:
  - Se **quitó `onMounted(onLoad)`** (y el import de `onMounted`). Nada se carga al entrar.
  - `revenueLoaded` ref: controla el estado vacío del tab Ingresos (prop `:loaded`).
  - Botón header: label dinámico **"Generar"** (icon `play_arrow`) / "Actualizar" tras la primera
    carga; **Exportar** deshabilitado hasta que haya datos. Chip de estado: "Presiona Generar".
- `pages/Dashboard/tabs/DashboardRevenueTab.vue`: nuevo prop `loaded`; el panel de período queda
  siempre visible (es el disparador, botón **Consultar** → `@load`), y el resto (KPIs/charts/matriz)
  se muestra solo con `v-if="loaded"`; estado vacío con CTA si no.
- `pages/Dashboard/tabs/DashboardTtpnsTab.vue`: **sin cambios** (ya era manual).
- `pages/Dashboard/tabs/DashboardTallerTab.vue`: se **gatean** `WorkshopOpsPanel`/`WorkshopWeeklyTab`
  detrás de un botón **Generar** (`generated` ref) + estado vacío. NO se tocaron los componentes
  compartidos con Finanzas.

## Verificación

- ESLint: 0 errores en los 3 archivos tocados.
- `npm run build` (SPA): **Build succeeded**.
- DB local: privilegios dashboard ahora 4 (`dashboard` + 3 tabs).

## Pendiente

- **Prod:** sembrar los 3 privilegios `dashboard_*` en Supabase prod (lo hace el usuario / deploy):
  `rails db:seed` carga el catálogo, o el runner puntual. Tras sembrarlos, asignar **Acceso** por tab
  a los roles que correspondan desde la pantalla de gestión de privilegios.
- **FE push:** pushear a `origin` (GitLab→Netlify) y `github` (lo hace el usuario, según su flujo).
- **Patrón en otras páginas:** replicar la carga perezosa "nada hasta Generar" a otras páginas que
  auto-cargan al montar (diferido; se valida primero la UX del Dashboard).
- Reconsiderar el fallback "sin ningún tab → mostrar todos": una vez que los roles tengan tabs
  asignados, evaluar si conviene que "sin tabs" signifique "no ver ninguno".
