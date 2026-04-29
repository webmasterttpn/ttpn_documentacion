# Estimación de Costos — Integración de IA en Kumi TTPN Admin
**Fecha:** Abril 2026  
**Elaborado por:** Área de Sistemas TTPN  
**Objetivo:** Evaluar el costo mensual y anual de incorporar inteligencia artificial para automatizar la captura y gestión de viajes, considerando un crecimiento proyectado del 25% en clientes al cierre del año.

---

## 1. Contexto del Problema

Actualmente los coordinadores envían información de viajes a capturistas vía **WhatsApp**, en dos formatos:

### Formato A — Texto libre
```
Bafar... Salida 19:00 tiempo extra 07 de Abril

T064  →  Punta naranjos / Jardines de san Agustín
T011  →  Peñas blancas
T053  →  Solidaridad popular
```

### Formato B — Imagen de Excel
Tablas fotográficas con columnas: **SALIDA | VEHÍCULO | CHOFER | PASAJEROS | DIRECCIÓN | TELÉFONO**  
*(Ejemplo: RUTAS TIEMPO EXTRA REXNORD — vehículos T008, T010, VT02 con múltiples pasajeros y domicilios)*

La IA reemplazaría el trabajo de interpretación manual, creando los registros directamente en el sistema desde ambos formatos.

---

## 2. Casos de Uso Evaluados

| # | Caso de Uso | Descripción | Requiere Visión de Imágenes |
|---|---|---|---|
| 1 | **Consulta Chatbot** | Preguntas sobre vehículos, empleados, viajes, pólizas | No |
| 2 | **Captura por Texto** | Crear viajes desde mensaje WhatsApp tipo texto | No |
| 3 | **Captura por Imagen Excel** | OCR de tabla fotográfica + creación automática de viajes | **Sí** |
| 4 | **Ajuste de Viaje** | "Ajusta el viaje T064", "el viaje X no cuadra con chofer" | No |

---

## 3. Tokens Consumidos por Operación

> **¿Qué es un token?** La unidad de cobro de los modelos de IA. Aproximadamente 0.75 palabras en español. Todos los proveedores cobran por millón de tokens (1M).

| Caso | Tokens de Entrada | Tokens de Salida | **Total por Operación** |
|---|---|---|---|
| Consulta Chatbot | ~2,700 | ~400 | **~3,100** |
| Captura por Texto (3–5 viajes) | ~3,250 | ~1,200 | **~4,450** |
| Captura por Imagen Excel (5–8 viajes) | ~4,200 + ~1,100 imagen | ~2,000 | **~6,200** |
| Ajuste de Viaje | ~1,300 | ~300 | **~1,600** |

---

## 4. Volumen Base Actual (Mes 1)

| Operación | Frecuencia Diaria | Tokens/Día | Tokens/Mes |
|---|---|---|---|
| Consultas chatbot | 20 | 62,000 | 1,860,000 |
| Capturas por texto | 30 | 133,500 | 4,005,000 |
| Imágenes Excel | 5 | 31,000 | 930,000 |
| Ajustes de viajes | 10 | 16,000 | 480,000 |
| **Total Mes 1** | **65** | **242,500** | **7,275,000** |

---

## 5. Proyección Anual con Crecimiento del 25%

> Crecimiento lineal: el volumen aumenta progresivamente hasta alcanzar un **25% más** en el Mes 12.  
> Volumen Mes 12: 303,125 tokens/día → 9,093,750 tokens/mes.

| Mes | Tokens/Día | Tokens/Mes | Crecimiento vs. Mes 1 |
|---|---|---|---|
| 1 | 242,500 | 7,275,000 | Base |
| 2 | 248,068 | 7,442,045 | +2.3% |
| 3 | 253,636 | 7,609,091 | +4.6% |
| 4 | 259,205 | 7,776,136 | +6.9% |
| 5 | 264,773 | 7,943,182 | +9.1% |
| 6 | 270,341 | 8,110,227 | +11.4% |
| 7 | 275,909 | 8,277,273 | +13.6% |
| 8 | 281,477 | 8,444,318 | +15.9% |
| 9 | 287,045 | 8,611,364 | +18.4% |
| 10 | 292,614 | 8,778,409 | +20.7% |
| 11 | 298,182 | 8,945,455 | +22.9% |
| 12 | 303,750 | 9,112,500 | +25.2% |
| **TOTAL ANUAL** | — | **~98,325,000** | — |

---

## 6. Comparativa de Proveedores

### Precios vigentes (Abril 2026)

| Proveedor | Modelo | Precio/1M Entrada | Precio/1M Salida | Procesa Imágenes | Tier Gratuito |
|---|---|---|---|---|---|
| **Groq** | llama-3.3-70b | $0.59 | $0.79 | ❌ No | ✅ 500K tokens/día |
| **Google** | Gemini 2.0 Flash | $0.10 | $0.40 | ✅ Sí | ✅ Créditos iniciales |
| **OpenAI** | GPT-4o mini | $0.15 | $0.60 | ✅ Sí | ✅ $5 iniciales |
| **OpenAI** | GPT-4o | $2.50 | $10.00 | ✅ Sí | ❌ No |
| **Anthropic** | Claude Haiku 4.5 | $0.80 | $4.00 | ✅ Sí | ❌ No |
| **Anthropic** | Claude Sonnet 4.6 | $3.00 | $15.00 | ✅ Sí | ❌ No |

> ⚠️ **Groq no procesa imágenes (Excel fotográfico)**. Requiere combinarse con otro proveedor para el Caso 3.

---

## 7. Costo Mensual por Proveedor con Proyección 25%

*(80% tokens de entrada · 20% tokens de salida)*

| Mes | Tokens/Mes | Groq Pagado | Gemini Flash | GPT-4o mini | Claude Haiku |
|---|---|---|---|---|---|
| 1 | 7,275,000 | $4.60 | **$1.16** | $1.76 | $10.51 |
| 2 | 7,442,045 | $4.71 | **$1.19** | $1.80 | $10.75 |
| 3 | 7,609,091 | $4.82 | **$1.22** | $1.85 | $10.99 |
| 4 | 7,776,136 | $4.92 | **$1.24** | $1.88 | $11.23 |
| 5 | 7,943,182 | $5.03 | **$1.27** | $1.93 | $11.47 |
| 6 | 8,110,227 | $5.13 | **$1.30** | $1.97 | $11.72 |
| 7 | 8,277,273 | $5.24 | **$1.32** | $2.01 | $11.96 |
| 8 | 8,444,318 | $5.35 | **$1.35** | $2.05 | $12.20 |
| 9 | 8,611,364 | $5.45 | **$1.38** | $2.09 | $12.44 |
| 10 | 8,778,409 | $5.56 | **$1.40** | $2.13 | $12.68 |
| 11 | 8,945,455 | $5.66 | **$1.43** | $2.17 | $12.92 |
| 12 | 9,112,500 | $5.77 | **$1.46** | $2.21 | $13.17 |
| **TOTAL ANUAL** | **~98.3M** | **$62** | **$15.72** | **$23.85** | **$141.04** |

---

## 8. Estrategia Recomendada — Arquitectura Híbrida

Combinar **Groq** (texto, gratis) + **Gemini Flash** (imágenes, mínimo costo):

```
WhatsApp → N8N
              ├── Texto / Ajustes / Consultas  ──→  Groq llama-3.3-70b  (GRATIS)
              └── Imagen Excel                 ──→  Gemini 2.0 Flash    (mínimo costo)
```

### ¿Por qué Groq es gratis para texto?
El tier gratuito de Groq permite **500,000 tokens/día = 182.5M tokens/año**.  
Nuestro volumen anual de texto es **~85.5M tokens** → **queda dentro del tier gratuito todo el año**, incluso con el crecimiento del 25%.

### Costo híbrido anual (solo se paga el procesamiento de imágenes en Gemini):

| Mes | Tokens Imagen/Mes | Costo Gemini Imágenes | Costo Groq Texto | **Total Mes** |
|---|---|---|---|---|
| 1 | 930,000 | $0.15 | $0.00 (gratis) | **$0.15** |
| 3 | 988,182 | $0.16 | $0.00 | **$0.16** |
| 6 | 1,053,409 | $0.17 | $0.00 | **$0.17** |
| 9 | 1,118,636 | $0.18 | $0.00 | **$0.18** |
| 12 | 1,183,636 | $0.19 | $0.00 | **$0.19** |
| **TOTAL ANUAL** | **~12.8M** | **~$2.05** | **$0.00** | **~$2.05** |

---

## 9. Resumen Ejecutivo de Costos Anuales

| Opción | Modelo(s) | Costo Anual USD | Costo Anual MXN* | Procesa Imágenes |
|---|---|---|---|---|
| 🏆 **Híbrido Recomendado** | Groq + Gemini Flash | **~$2** | **~$35** | ✅ Sí |
| Gemini Flash (todo) | Gemini 2.0 Flash | ~$16 | ~$275 | ✅ Sí |
| GPT-4o mini (todo) | GPT-4o mini | ~$24 | ~$415 | ✅ Sí |
| Groq pagado (solo texto) | llama-3.3-70b | ~$62 | ~$1,073 | ❌ No |
| Claude Haiku | Claude Haiku 4.5 | ~$141 | ~$2,440 | ✅ Sí |
| Claude Sonnet | Claude Sonnet 4.6 | ~$398 | ~$6,880 | ✅ Sí |

*\*Tipo de cambio aproximado: $17.30 MXN/USD*

---

## 10. Comparativa vs. Capturista Manual

| Concepto | Costo Mensual | Costo Anual |
|---|---|---|
| Capturista dedicada (salario) | $8,000 – $12,000 MXN | $96,000 – $144,000 MXN |
| IMSS + prestaciones (~35%) | $2,800 – $4,200 MXN | $33,600 – $50,400 MXN |
| **Costo total capturista** | **$10,800 – $16,200 MXN** | **$129,600 – $194,400 MXN** |
| — | — | — |
| **IA Híbrida (Groq + Gemini)** | **~$3 MXN** | **~$35 MXN** |
| **Ahorro estimado anual** | — | **$129,565 – $194,365 MXN** |
| **ROI** | — | **>99%** |

> La IA no elimina al coordinador. Sí elimina el cuello de botella de transcripción manual y reduce los errores de captura significativamente.

---

## 11. Capacidades por Proveedor

| Capacidad | Groq | Gemini Flash | GPT-4o mini | Claude Haiku |
|---|---|---|---|---|
| Consultas de texto | ✅ | ✅ | ✅ | ✅ |
| Crear viajes desde texto | ✅ | ✅ | ✅ | ✅ |
| Leer imágenes Excel | ❌ | ✅ | ✅ | ✅ |
| Ajustes de viajes | ✅ | ✅ | ✅ | ✅ |
| Tier gratuito suficiente | ✅ Todo el año | Parcial | Parcial | ❌ |
| Velocidad de respuesta | ⚡⚡⚡ Muy alta | ⚡⚡⚡ Muy alta | ⚡⚡ Alta | ⚡⚡ Alta |
| Calidad de comprensión | Alta | Muy alta | Muy alta | Muy alta |

---

## 12. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Imagen ilegible / baja calidad | Media | Alto | Preview de viajes antes de confirmar |
| Error en CLV o nombre de cliente | Baja | Alto | Validación contra catálogos del sistema |
| Cambio de precios del proveedor | Baja | Medio | Arquitectura intercambiable de modelos |
| Groq supera límite gratuito | Muy baja | Bajo | Upgrade a $5/mes cubre 4x el volumen proyectado |
| Datos sensibles de pasajeros | Media | Alto | Revisar política de privacidad — datos no salen de N8N |

---

## 13. Fases de Implementación

| Fase | Alcance | Estado | Costo IA |
|---|---|---|---|
| **1 — Chatbot consultas** | Preguntas sobre vehículos, empleados, viajes | ✅ Implementado | ~$0/mes |
| **2 — Captura por texto** | Crear viajes desde mensaje WhatsApp texto | 🔄 Siguiente sprint | ~$0/mes |
| **3 — Captura por imagen** | OCR de Excel fotográfico + creación automática | 📋 Planificado | ~$0.15/mes |
| **4 — Canal WhatsApp** | N8N conectado a WhatsApp Business API | 📋 Futuro | ~$0.15/mes + $15 WhatsApp/mes |

---

*Las estimaciones de tokens tienen un margen de ±20%.*  
*Precios de proveedores verificados en Abril 2026 — sujetos a cambios.*  
*Tipo de cambio referencial: $17.30 MXN/USD.*
