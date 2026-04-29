# ADR-005 — Quasar + Capacitor para la App Móvil

**Fecha:** 2026-04-10  
**Estado:** Propuesto (pendiente implementación)  
**Autor:** Antonio Castellanos

---

## Contexto

La app móvil actual es Android nativo (Java). Tres opciones para el reemplazo:
1. Mantener Android nativo
2. PWA pura (Quasar PWA mode)
3. Quasar + Capacitor (APK nativo generado desde el mismo codebase web)

## Decisión

**Quasar + Capacitor.** El mismo codebase del panel admin web genera la APK de la app móvil.

## Razones

Las notificaciones push son operacionalmente críticas: un chofer que no recibe aviso de un booking nuevo tiene impacto directo en el servicio. PWA pura tiene soporte limitado en iOS y depende de que el usuario haya instalado la app desde Safari.

Con Capacitor se obtiene:
- FCM nativo para notificaciones push en Android e iOS
- Distribución por APK directa (sin Play Store para despliegues internos)
- Cámara nativa para `vehicle_checks`
- GPS nativo con permisos completos

El codebase del panel admin Quasar ya tiene los composables, servicios y componentes base. La app móvil reutiliza esa infraestructura y solo agrega vistas adaptadas a pantalla pequeña.

**IMEI descartado:** Android 10+ bloquea `TelephonyManager.getDeviceId()`. Se usa `Settings.Secure.ANDROID_ID` como alternativa para binding de dispositivo (se guarda en `employees.imei`).

## Consecuencias

- El desarrollador del panel admin puede mantener también la app móvil — no se necesita un dev Android/Java separado.
- El código Java existente queda obsoleto al completar la migración.
- Las actualizaciones de la app requieren nuevo build APK (a diferencia de PWA que actualiza automáticamente). Pero al ser distribución interna, el tiempo de actualización es controlable.
- Prerequisito: completar la Fase 2 de migración móvil (Rails REST API en lugar de PHP).
- Ver análisis completo en `ANALISIS_PWA_VS_APP_NATIVA.md`.