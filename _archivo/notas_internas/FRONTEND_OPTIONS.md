# 🎨 Opciones de Desarrollo del Frontend

## Opción 1: Frontend en Docker (Recomendado para Testing Completo)

### Ventajas:

- ✅ Todo el stack con un solo comando
- ✅ Entorno consistente
- ✅ Fácil de compartir con el equipo

### Uso:

```bash
# Desde la raíz del proyecto
docker-compose up -d

# Frontend disponible en: http://localhost:9000
```

---

## Opción 2: Frontend Manual (Recomendado para Desarrollo Activo)

### Ventajas:

- ✅ Hot-reload más rápido
- ✅ Mejor experiencia de desarrollo
- ✅ Acceso directo a herramientas de Quasar

### Uso:

#### 1. Levantar solo el backend en Docker

```bash
# Desde la raíz del proyecto
docker-compose up -d api sidekiq redis

# Esto levanta:
# - API: http://localhost:3000
# - Sidekiq: funcionando
# - Redis: funcionando
```

#### 2. Correr el frontend manualmente

```bash
# En otra terminal
cd ttpn-frontend

# Modo PWA (recomendado)
npm run dev -- -m pwa
# o
quasar dev -m pwa

# Modo SPA (más rápido para desarrollo)
npm run dev
# o
quasar dev
```

#### Puertos por Modo:

- **PWA Mode:** http://localhost:9000
- **SPA Mode:** http://localhost:9000 (puede variar)

---

## Opción 3: Híbrido (Lo Mejor de Ambos Mundos)

### Para desarrollo diario:

```bash
# Terminal 1: Backend en Docker
cd /ruta/al/proyecto
docker-compose up -d api sidekiq redis

# Terminal 2: Frontend manual
cd ttpn-frontend
quasar dev -m pwa
```

### Para testing completo antes de commit:

```bash
# Levantar todo en Docker
docker-compose up -d

# Verificar que todo funciona
curl http://localhost:3000  # API
curl http://localhost:9000  # Frontend
```

---

## 🔧 Configuración de Puertos

### Configuración Actual:

```yaml
# docker-compose.yml
frontend:
  ports:
    - "9000:9000" # PWA mode
```

### Si Quasar usa otro puerto:

1. **Verificar puerto de Quasar:**

```bash
cd ttpn-frontend
quasar dev -m pwa
# Observa en qué puerto inicia (usualmente 9000)
```

2. **Actualizar docker-compose.yml si es necesario:**

```yaml
frontend:
  ports:
    - "PUERTO_LOCAL:9000"
```

---

## 📝 Variables de Entorno

### Frontend (.env en ttpn-frontend/)

```bash
# Apunta al backend
API_URL=http://localhost:3000
```

### Backend (.env en ttpngas/)

```bash
# Permite CORS desde el frontend
FRONTEND_URL=http://localhost:9000
```

---

## 🐛 Troubleshooting

### Frontend no conecta con API

```bash
# Verificar que API esté corriendo
curl http://localhost:3000

# Verificar CORS en backend
# Debe permitir http://localhost:9000
```

### Puerto 9000 ya en uso

```bash
# Encontrar proceso
lsof -ti:9000

# Matar proceso
kill -9 $(lsof -ti:9000)

# O usar otro puerto en quasar.config.js
```

### Hot-reload no funciona en Docker

```bash
# Mejor correr frontend manualmente para desarrollo
cd ttpn-frontend
quasar dev -m pwa
```

---

## 💡 Recomendación

**Para desarrollo diario:**

- Backend en Docker: `docker-compose up -d api sidekiq redis`
- Frontend manual: `cd ttpn-frontend && quasar dev -m pwa`

**Para testing/demo:**

- Todo en Docker: `docker-compose up -d`

**Para CI/CD:**

- Todo en Docker con builds de producción

---

## 🚀 Comandos Rápidos

```bash
# Backend solo
docker-compose up -d api sidekiq redis

# Frontend manual PWA
cd ttpn-frontend && quasar dev -m pwa

# Todo el stack
docker-compose up -d

# Ver logs del frontend en Docker
docker-compose logs -f frontend

# Reconstruir frontend
docker-compose build frontend
docker-compose restart frontend
```

---

**Última actualización:** 2025-12-18
