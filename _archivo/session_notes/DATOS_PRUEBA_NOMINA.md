# 📋 DATOS PREPARADOS PARA PRUEBAS - ACTUALIZADO

## ✅ **ESTADO ACTUAL** (22 Diciembre 2025 - 11:25 AM)

**Limpieza realizada:**

- ✅ Eliminada nómina incorrecta con 61,051 viajes (Mayo-Julio 2025)
- ✅ Eliminadas nóminas de Julio sin viajes
- ✅ Liberados 81,058 viajes (sin `payroll_id`)

**Resumen:**

- Nóminas totales: 264
- Viajes sin `payroll_id`: **81,058**
- Viajes disponibles para pruebas: **Mayo a Julio 2025**

---

## 📊 **VIAJES DISPONIBLES (Mayo-Julio 2025)**

Los 81,058 viajes liberados cubren el período:

- **Inicio:** 06 Mayo 2025
- **Fin:** 26 Julio 2025
- **Duración:** ~11 semanas

**Distribución aproximada:**

- Mayo 2025: ~26,000 viajes
- Junio 2025: ~31,000 viajes
- Julio 2025: ~24,000 viajes

---

## 🧪 **ESCENARIOS DE PRUEBA SUGERIDOS**

### **ESCENARIO 1: Nóminas Semanales Normales (Mayo 2025)**

#### **Nómina 1: Primera semana de Mayo**

```
Descripción: Nómina Semana 18/2025
Fecha Inicio: 06/05/2025 01:30
Fecha Fin Planificada: 13/05/2025 01:30
Día de Pago: Jueves 15/05/2025
Viajes esperados: ~6,000
```

#### **Nómina 2: Segunda semana de Mayo**

```
Descripción: Nómina Semana 19/2025
Fecha Inicio: 13/05/2025 01:30
Fecha Fin Planificada: 20/05/2025 01:30
Día de Pago: Jueves 22/05/2025
Viajes esperados: ~6,500
```

#### **Nómina 3: Tercera semana de Mayo**

```
Descripción: Nómina Semana 20/2025
Fecha Inicio: 20/05/2025 01:30
Fecha Fin Planificada: 27/05/2025 01:30
Día de Pago: Jueves 29/05/2025
Viajes esperados: ~6,500
```

---

### **ESCENARIO 2: Prueba de Viajes Rezagados**

#### **Paso 1: Crear Nómina 1**

```
Descripción: Nómina Test Rezagados v1
Fecha Inicio: 03/06/2025 01:30
Fecha Fin Planificada: 10/06/2025 01:30
```

#### **Paso 2: Simular viaje rezagado**

Después de crear la nómina, en la consola de Rails:

```ruby
# Crear un viaje "capturado tarde" con fecha dentro del período anterior
TravelCount.create!(
  employee_id: 1,
  client_branch_office_id: 1,
  ttpn_service_type_id: 1,
  vehicle_id: 1,
  fecha: Date.new(2025, 6, 5),
  hora: Time.parse('10:00'),
  costo: 100,
  status: true,
  payroll_id: nil  # Sin nómina
)
```

#### **Paso 3: Crear Nómina 2**

```
Descripción: Nómina Test Rezagados v2
Fecha Inicio: 10/06/2025 01:30
Fecha Fin Planificada: 17/06/2025 01:30
```

**Resultado esperado:**

- ✅ El viaje del 05/06 se asigna automáticamente a la Nómina 1
- ✅ Log muestra "viajes_rezagados_asignados: 1"

---

### **ESCENARIO 3: Escenario Navidad (Simulación con Junio)**

Simula el caso de Navidad usando fechas de Junio:

#### **Nómina 1: Adelantada (Miércoles)**

```
Descripción: Nómina Semana 25/2025 v1
Fecha Inicio: 17/06/2025 01:30
Fecha Fin Planificada: 24/06/2025 01:30
Día de Pago: Miércoles 25/06/2025 (adelantada)
Viajes esperados: ~5,500
```

#### **Nómina 2: Complementaria (Viernes)**

```
Descripción: Nómina Semana 25/2025 v2
Fecha Inicio: 24/06/2025 01:30
Fecha Fin Planificada: 27/06/2025 01:30
Día de Pago: Viernes 27/06/2025 (complemento)
Viajes esperados: ~2,000
```

---

## 🎯 **PRUEBAS A REALIZAR**

### **1. Crear Nómina Normal** ✅

1. Ir a "Nómina" → "Períodos de Nómina"
2. Clic en "Nueva Nómina"
3. Usar datos del ESCENARIO 1 - Nómina 1
4. Observar:
   - ✅ Worker se encola (status: pending)
   - ✅ Progreso: 0% → 10% → 30% → 50% → 70% → 90% → 100%
   - ✅ Status cambia a "completed"
   - ✅ Excel se genera
   - ✅ Botón "Descargar Excel" aparece

### **2. Verificar Asignación de Viajes** ✅

1. Después de crear la nómina
2. Clic en botón "Info" (detalle)
3. Verificar:
   - ✅ Viajes asignados: ~6,000
   - ✅ Log muestra "Nómina Creada"
   - ✅ Progreso: 100%

### **3. Crear Segunda Nómina** ✅

1. Crear ESCENARIO 1 - Nómina 2
2. Verificar:
   - ✅ Nómina 1 se cierra automáticamente
   - ✅ `fecha_hasta` de Nómina 1 = `fecha_inicio` de Nómina 2
   - ✅ Viajes nuevos se asignan a Nómina 2

### **4. Probar Viajes Rezagados** ✅

Seguir ESCENARIO 2 completo

### **5. Probar Reasignación Manual** ✅

1. Crear una nómina
2. Manualmente liberar algunos viajes:

```ruby
TravelCount.where(payroll_id: PAYROLL_ID).limit(10).update_all(payroll_id: nil)
```

3. En el frontend, clic en "Reasignar Rezagados"
4. Verificar que los viajes se reasignan

### **6. Descargar Excel** ✅

1. Esperar a que nómina complete (100%)
2. Clic en "Descargar Excel"
3. Verificar:
   - ✅ Excel se descarga
   - ✅ Contiene todos los empleados del período
   - ✅ Totales son correctos

---

## 🔧 **COMANDOS ÚTILES**

### Ver estado de nóminas:

```bash
docker-compose exec app rails runner "
  Payroll.order(created_at: :desc).limit(10).each do |p|
    puts \"#{p.id}: #{p.descripcion}\"
    puts \"  Status: #{p.processing_status} (#{p.progress}%)\"
    puts \"  Viajes: #{p.travel_counts.count}\"
    puts \"  Período: #{p.fecha_inicio} - #{p.fecha_hasta || 'ABIERTA'}\"
    puts
  end
"
```

### Ver viajes sin payroll_id:

```bash
docker-compose exec app rails runner "
  sin_payroll = TravelCount.where(payroll_id: nil)
  puts \"Total: #{sin_payroll.count}\"
  puts \"Rango: #{sin_payroll.minimum(:fecha)} - #{sin_payroll.maximum(:fecha)}\"
"
```

### Liberar viajes de una nómina:

```bash
docker-compose exec app rails runner "
  Payroll.find(PAYROLL_ID).travel_counts.update_all(payroll_id: nil)
"
```

### Eliminar nómina de prueba:

```bash
docker-compose exec app rails runner "
  p = Payroll.find(PAYROLL_ID)
  p.travel_counts.update_all(payroll_id: nil)  # Liberar viajes primero
  p.destroy
"
```

### Ver logs de Sidekiq:

```bash
docker-compose logs -f sidekiq
```

---

## ⚠️ **NOTAS IMPORTANTES**

1. **Día de Pago:** Actualmente es **Jueves**
2. **Hora de Corte:** **01:30 AM**
3. **Viajes Rezagados:** El sistema detecta automáticamente viajes capturados tarde
4. **Workers:** Asegúrate de que Sidekiq esté corriendo
5. **Polling:** El frontend actualiza cada 2 segundos hasta que completa
6. **Datos Reales:** Estás usando datos de producción (Mayo-Julio 2025)
7. **Backup:** Considera hacer backup antes de pruebas extensivas

---

## 📝 **CHECKLIST DE PRUEBAS**

- [ ] Crear nómina normal (ESCENARIO 1 - Nómina 1)
- [ ] Ver progreso en tiempo real (0% → 100%)
- [ ] Descargar Excel
- [ ] Crear segunda nómina (cierra la anterior)
- [ ] Verificar que nómina anterior se cerró correctamente
- [ ] Probar viajes rezagados (ESCENARIO 2)
- [ ] Reasignar viajes manualmente
- [ ] Ver detalle con logs
- [ ] Probar en móvil (responsive)
- [ ] Verificar que polling se detiene al completar
- [ ] Verificar que polling se detiene al salir de la página
- [ ] Probar escenario Navidad (ESCENARIO 3)

---

## 🎉 **DATOS LISTOS**

**Tienes 81,058 viajes disponibles** de Mayo a Julio 2025 para crear y probar nóminas.

**Recomendación:** Empieza con el ESCENARIO 1 (Mayo 2025) para familiarizarte con el sistema.

**¡Listo para pruebas!** 💰✅
