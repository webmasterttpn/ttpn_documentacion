# Runbook E2E — Cuadre TB ↔ TC async

**Fecha:** 2026-05-29
**Objetivo:** validar el comportamiento del cuadre tras Fase 1.B (job async) + refactor service (Nivel 1 = campos+ventana, Nivel 2 = CLV desempata) + fix timezone del trigger PG. Bloqueante para migración 2-jun y nómina 4-jun.

---

## 0. Pre-requisitos

Validar antes de ejecutar:

- [ ] Migration `20260529101804_update_sp_tctb_insert_timezone_aware` aplicada en prod (`railway run -- bundle exec rails db:migrate`).
- [ ] SQL UPDATE quirúrgico aplicado en prod para realinear CLVs de TC histórico (§6.1 de `CUADRE_MAESTRO.md`).
- [ ] Cross-check query post-fix muestra mayoría de pares con `clv_coinciden=true` (los que no son diferencias reales de timing).
- [ ] `Cuadre::TbMatchJob` desplegado en Railway. Verificar con `railway run -- bundle exec rails runner 'puts Cuadre::TbMatchJob.name'`.
- [ ] Sidekiq corriendo. Verificar con `railway logs --service kumi-admin-api-sidekiq` o `railway run -- bundle exec rails runner 'puts Sidekiq.redis(&:ping)'`.
- [ ] Set de datos para pruebas listo: cliente, 2 vehículos, empleado activo, servicio + destino.

---

## 1. Configurar el script

```bash
cd "Kumi TTPN Admin V2/ttpngas/scripts/e2e_cuadre"
cp config.env.example config.env
$EDITOR config.env   # rellenar todos los IDs
```

Llenar en `config.env`:

| Variable | Cómo obtener |
|---|---|
| `JWT` | `POST $RAILS_BASE_URL/auth/sign_in` con email/password de un user con privilegios CRUD sobre `ttpn_bookings` y `travel_counts`. Extraer del header `Authorization` del response. |
| `DATABASE_URL` | `railway variables --service kumi-admin-api` |
| `CLIENT_ID`, `CLIENT_BRANCH_OFFICE_ID` | Cliente de prueba con su sucursal. Ej: el cliente "TEST_E2E" si lo creas para esto. |
| `VEHICLE_ID`, `VEHICLE_ID_2` | 2 vehículos operativos (`clv LIKE 'T%'`). Distintos para escenarios 5/6/12. |
| `EMPLOYEE_ID` | Chofer activo asignado a ambos vehículos en `vehicle_asignations`. |
| `TTPN_SERVICE_TYPE_ID`, `TTPN_SERVICE_ID`, `TTPN_FOREIGN_DESTINY_ID` | Servicio del cliente al destino donde harás las pruebas. |
| `FECHA` | Día de la prueba. Default 2026-05-29. |

---

## 2. Ejecutar

```bash
# Todos los 12 escenarios
./run_e2e.sh all

# Solo algunos
./run_e2e.sh 1 2 3

# Un escenario aislado
./run_e2e.sh 9
```

Cada corrida crea un directorio `results/<timestamp>/` con:

- `summary.md` — bitácora completa con PASS/FAIL por aserción.
- `before_<n>.txt`, `after_<n>.txt` — dump del estado antes/después de cada escenario.
- `initial.txt`, `final.txt` — estado del set al inicio y al final.

---

## 3. Los 12 escenarios

| # | Descripción | Verifica |
|---|---|---|
| 1 | TB-first → TC | 4 viajes (TBs y TCs cruzados) por Nivel 1 |
| 2 | TC-first → TB | TBs encolan job y cuadran con TCs preexistentes |
| 3 | 2 TBs +15min → 2 TCs idénticos | Nivel 1 ambos pares |
| 4 | 2 TCs +15min → 2 TBs idénticos | Nivel 1 ambos pares (no confundir el 2do TC con el 1ro) |
| 5 | 2 TBs <15min vehículos distintos → 2 TCs | Regla `sin_duplicado` requiere veh distintos; bonus prueba mismo veh debe fallar |
| 6 | 2 TCs <15min vehículos distintos → 2 TBs | TC no tiene esa regla; misma idea con vehículos distintos |
| 7 | 2 TBs +15min → TC#1 alineado, TC#2 >30min fuera | TB#1+TC#1 cuadran; TB#2 y TC#2 sin pareja |
| 8 | 2 TCs +15min → TB#1 alineado, TB#2 -30min fuera | TC#1+TB#1 cuadran; TC#2 y TB#2 sin pareja |
| 9 | Edición TB tras cuadre | `clear_stale_tc_link` desvincula; job se re-enqueue; nuevo TC pega |
| 10 | Clonado (`creation_method='cloned'`) | Regla 15min aplica al clon |
| 11 | Importación masiva (`TtpnBookingImportJob`) | Detecta si encola jobs (bug actual) |
| 12 | Race: 2 TBs matchean al mismo TC | Solo uno gana; filtro `viaje_encontrado=[false,nil]` deja al otro sin pareja |

---

## 4. Validar resultados

### 4.1 Bitácora resumida

```bash
cat results/<timestamp>/summary.md
```

Contar `PASS` vs `FAIL`:

```bash
grep -c "PASS" results/<timestamp>/summary.md
grep -c "FAIL" results/<timestamp>/summary.md
```

### 4.2 Sidekiq queue + dead set

Tras la corrida:

```bash
railway run --service kumi-admin-api bundle exec rails runner \
  'puts "default=#{Sidekiq::Queue.new(:default).size} dead=#{Sidekiq::DeadSet.new.size}"'
```

- `default=0` esperado tras `wait_job` (3 segundos). Si queda algo, Sidekiq se atascó.
- `dead=0` esperado. Si algo cayó al dead set, leer los failed jobs para diagnosticar.

### 4.3 Estado final del set

```bash
cat results/<timestamp>/final.txt
```

Cada fila debe corresponder a un escenario. Filas con `viaje_encontrado=t` cruzadas, filas con `viaje_encontrado=f` sin pareja (escenarios 7, 8, 9, 12).

---

## 5. Qué hacer si algo falla

| Síntoma | Diagnóstico | Acción |
|---|---|---|
| Escenario 11 reporta WARN "jobs encolados" | `TtpnBookingImportJob` NO setea `import_mode` | Editar el job agregando `Current.import_mode = true` al inicio del `perform` con `ensure` que lo restaure. Push + redeploy. Re-correr escenario 11. |
| Escenario 12 muestra 2 TBs cuadrando con el mismo TC | Race condition real en `vincular` | Envolver `vincular` en transacción con `FOR UPDATE` sobre TC. Patch separado. |
| Escenario 9 deja TB con `viaje_encontrado=true` tras edición | `clear_stale_tc_link` no detectó el cambio | Verificar que `@viaje_anterior` se setea en `extra_campos` cuando MATCH_FIELDS cambia. |
| Escenarios 1-4 fallan masivamente | Posible problema de set de datos (cliente+sucursal+vehículo+empleado no compatibles) | Verificar manualmente que los IDs en `config.env` corresponden a registros activos con las relaciones esperadas. |
| Curl PHP devuelve 'respuesta=100' | El INSERT a `travel_counts` no afectó filas | Probable problema de FK (CLIENT_BRANCH_OFFICE_ID o VEHICLE_ID inválido). Validar IDs en `config.env`. |
| Curl Rails devuelve 401 | JWT expiró | Re-obtener con `POST /auth/sign_in`. Los tokens devise-jwt expiran en X horas (ver config). |
| Curl Rails devuelve 422 en escenarios que esperaban éxito | Validación rechazó el payload (regla 15min, campos faltantes, etc.) | Revisar el JSON del response, ajustar payload. |

---

## 6. Limpieza

El script aplica `CLEANUP_MODE` al final:

- `soft` (default): `status=false` a los registros creados en la hora previa. Preserva auditoría.
- `hard`: `DELETE`. Solo si el set de prueba no tiene auditoría asociada.
- `none`: deja los datos para inspección manual.

Si necesitas limpiar manualmente:

```sql
UPDATE ttpn_bookings SET status=false
  WHERE fecha='2026-05-29' AND vehicle_id IN (<VEH>, <VEH2>)
    AND created_at >= NOW() - INTERVAL '2 hours';

UPDATE travel_counts SET status=false
  WHERE fecha='2026-05-29' AND vehicle_id IN (<VEH>, <VEH2>)
    AND created_at >= NOW() - INTERVAL '2 hours';
```

---

## 7. Después de las pruebas

- Si todos los escenarios pasan: sistema listo para cutover 2-jun. Mover este archivo a `_archivo/pruebas/aprobadas/` y crear nota de sesión.
- Si escenario 11 confirmó bug `import_mode`: fix en `TtpnBookingImportJob`, push, re-correr solo escenario 11.
- Si escenario 12 confirmó race: patch en `TtpnCuadreService#vincular` o en el job, re-correr solo escenario 12.
- Documentar en nota de sesión `Documentacion/_archivo/session_notes/2026-05-29_e2e_cuadre_resultados.md` con el `summary.md` y conclusiones.

Ver `Documentacion/Backend/dominio/bookings/CUADRE_MAESTRO.md` para el contexto técnico completo.
