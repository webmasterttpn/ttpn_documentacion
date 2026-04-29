# 📄 Product Requirements Document (PRD) - Kumi TTPN Admin V2

## 📝 Visión General del Proyecto
**Kumi TTPN Admin V2** es una plataforma integral de gestión empresarial (ERP/Admin) diseñada específicamente para la logística, transporte de personal y control operativo de TTPN. El sistema centraliza la administración de empleados, flota vehicular, gestión de servicios, control de combustible y procesos financieros clave (Nómina y Facturación).

El proyecto migra de un sistema monolítico legacy a una arquitectura moderna **API-First**, permitiendo integraciones con aplicaciones móviles Android para choferes y clientes.

---

## 🛠️ Stack Tecnológico

### Backend (API)
- **Framework:** Ruby on Rails 7.1 (Modo API).
- **Lenguaje:** Ruby 3.3.
- **Base de Datos:** PostgreSQL (Primaria) + Redis (Colas y Caché).
- **Procesamiento Asíncrono:** Sidekiq + Sidekiq Cron.
- **Documentación:** Swagger/OpenAPI (Rswag).
- **Autenticación:** JWT (JSON Web Tokens) para usuarios internos y externos.

### Frontend (User Interface)
- **Framework:** Vue.js 3.
- **UI Kit:** Quasar Framework v2.
- **Estado Global:** Pinia.
- **Tipo de App:** Progressive Web App (PWA) instalable en Android/iOS/Desktop.
- **Estilos:** Vanilla CSS + Diseño Premium (Glassmorphism, Dark Mode Support).
- **Gráficos:** ApexCharts (vue3-apexcharts).

---

## 🏛️ Arquitectura del Sistema

### Backend (Rails API)
El backend sigue una arquitectura de capas tradicional en Rails, optimizada para el rendimiento:
- **Controllers:** Manejo de requests y serialización JSON.
- **Serializers:** Definición estricta de la estructura de salida para optimizar el payload móvil.
- **Services:** Encapsulamiento de lógica de negocio compleja (ej. `CuadreService`, `PayrollGenerator`).
- **Concerns:** Reutilización de código para auditoría (`Trackable`) y caching (`Cacheable`).

### Frontend (Quasar PWA)
El frontend está diseñado para ser reactivo, modular y estar optimizado para el uso como aplicación instalable (PWA):
- **Layouts:** Estructuración visual (Menú lateral, Header con notificaciones y perfil).
- **Pages & Components:** Separación entre contenedores de ruta y piezas visuales reutilizables.
- **Stores (Pinia):** Gestión de estado centralizado (Autenticación, Privilegios, Datos de Sesión).
- **Boot Files:** Inicialización de plugins y configuración de Axios para la comunicación con el BE.

---

## 📂 Estructura de Directorios

### Directorio Backend (`ttpngas/`)
```text
├── app/
│   ├── controllers/api/v1/   # Endpoints REST
│   ├── models/               # Definición de datos y validaciones
│   ├── serializers/          # Formateo de respuestas JSON
│   ├── services/             # Lógica de negocio (Cuadre, Nómina)
│   └── workers/              # Tareas asíncronas (Sidekiq)
├── config/                   # Rutas y configuración de entorno
└── db/                       # Migraciones y Triggers (PostgreSQL)
```

### Directorio Frontend (`ttpn-frontend/`)
```text
├── src/
│   ├── boot/                 # Configuración de Axios, Auth e I18n
│   ├── components/           # Componentes UI reutilizables por módulo
│   ├── layouts/              # Estructuras de página (Main, Auth)
│   ├── pages/                # Vistas principales de la aplicación
│   │   ├── TtpnBookings/     # Captura y Cuadre de servicios
│   │   ├── Employees/        # Gestión de personal
│   │   └── Settings/         # Configuración del sistema
│   ├── router/               # Definición de rutas y Navigation Guards
│   ├── stores/               # Estado global (Auth, Privilegios)
│   └── assets/               # Imágenes, iconos y fuentes
├── src-pwa/                  # Configuración del Service Worker
└── quasar.config.js          # Configuración del build y PWA
```

---

## 🏛️ Arquitectura de Datos y Multi-Tenancy
El sistema es **Multi-tenant** basado en `business_unit_id` (Unidades de Negocio).
- **Aislamiento:** La mayoría de las tablas están filtradas por la unidad de negocio del usuario autenticado.
- **Roles y Privilegios:** Sistema granular basado en módulos. Cada rol tiene privilegios específicos (`can_read`, `can_write`, `can_delete`) sobre cada módulo funcional.

---

## 📦 Módulos Funcionales

### 1. Gestión de Capital Humano (Empleados)
- **Directorio Central:** Expediente digital con datos personales, laborales y fotografía.
- **Gestión Documental:** Seguimiento de vigencias (licencias, seguros, identificaciones) con carga de archivos.
- **Movimientos:** Historial de altas, bajas y reingresos.
- **Salarios:** Control histórico de SDI (Salario Diario Integrado).
- **Vacaciones:** Solicitud y flujo de autorización de días de descanso.
- **Citas Médicas/Admin:** Calendario para control de exámenes y capacitaciones.
- **Deducciones e Incidencias:** Registro de faltas, retardos, préstamos y otros conceptos que afectan la nómina.

### 2. Flotilla Vehicular (Vehículos)
- **Inventario de Unidades:** Control por placas, económico, marca, modelo y capacidad de pasajeros.
- **Asignaciones:** Vinculación de choferes a unidades específicas con historial.
- **Mantenimiento:**
  - Solicitudes directas del chofer (vía App).
  - Programación de preventivos y correctivos.
- **Revisiones (Checks):** Inspecciones periódicas de estado físico y mecánico.

### 3. Operación y Captura (TTPN Bookings)
Este es el core operativo del negocio:
- **Catálogo de Servicios:** Definición de rutas (RTA), tipos (Entrada/Salida) y precios.
- **Captura de Servicios:** Registro manual de los viajes programados por los clientes.
- **Auto-creación de Pasajeros:** Al crear un servicio, el sistema consulta la capacidad de la unidad asignada (`GET /api/v1/vehicles/:id/capacity`) y genera automáticamente registros de pasajeros vacíos listos para ser llenados, optimizando el tiempo del capturista.
- **Match / Cuadre de Servicios:** 
  - Recibe datos de la App móvil de choferes (**TravelCounts**).
  - Correlaciona automáticamente lo "programado" (Booking) vs lo "ejecutado" (TravelCount).
  - **Algoritmo de Match:** Utiliza una Business Key única llamada `clv_servicio` generada a partir de los ID del cliente, fecha, hora (incluyendo segundos) y ID del servicio.
  - **Estados de Cuadre:**
    1. `Exacto`: Coincidencia total de la clave.
    2. `Aproximado`: Coincidencia dentro de un rango de tiempo tolerable (configurable en `KumiSettings`).
    3. `Discrepancia`: Registros sin pareja que requieren atención manual.

### 4. Control de Combustible
- **Cargas de Gas/Gasolina:** Registro detallado de consumos, kilometrajes y costos por unidad.
- **Estaciones:** Directorio de puntos de carga autorizados.
- **Rendimientos:** Panel de análisis que calcula el KM/Litro real por unidad y detecta anomalías.

### 5. Finanzas y Operaciones de Cierre
- **Facturación:** Procesamiento de servicios realizados para generar archivos de precorte/facturación por cliente.
- **Nómina de Operaciones:** Cálculo masivo de pagos a choferes basado en los servicios "cuadrados" y validados.
- **Exportación:** Generación intensiva de reportes en Excel mediante workers asíncronos para evitar bloqueos del sistema.

---

## 🔌 Integraciones y API
- **App Android (Choferes):** Envío de TravelCounts, recepción de avisos de mantenimiento y ruteo.
- **App Clientes:** Consulta de servicios en tiempo real y solicitudes de transporte.
- **API Keys:** Sistema de acceso para terceros con permisos granulares (Scopes).

---

## 🔐 Seguridad y Auditoría
- **Autenticación (JWT):** 
  - El frontend obtiene un token al hacer login (`POST /api/v1/auth/login`).
  - El token se guarda en `localStorage` (gestionado por Pinia persisted state).
  - Axios intercepta cada petición saliente para incluir el header `Authorization: Bearer <token>`.
  - Existe un interceptor de respuesta que detecta errores `401` para forzar el logout si el token expira.
- **Auditoría:** Registro de creación y modificación de registros críticos (Quién y Cuándo).
- **JWT:** Sesiones seguras y expirables.

---

## 📱 Características PWA
- **Soporte Offline:** Cacheo de recursos estáticos (HTML, JS, CSS) vía Service Worker para carga instantánea.
- **Manifest:** Configurado para comportamiento "Standalone" (sin barra de navegador), íconos de sistema y splash screens.
- **Instalación:** Banner de instalación personalizado para Android y guía visual para iOS.

---

## 🎯 Objetivos de Negocio (K Pis)
1. **Reducir Error Humano:** Automatizar el cuadre de servicios del 40% al 95%.
2. **Eficiencia en Nómina:** Generar precierres de nómina en segundos en lugar de horas.
3. **Control de Activos:** Visibilidad total del rendimiento de combustible y estado de mantenimiento de la flota.
4. **Visibilidad Cliente:** Proporcionar transparencia total a los clientes sobre sus recorridos.

---
**Documentación generada por:** Antigravity AI  
**Última Actualización:** 14 de Marzo, 2026
