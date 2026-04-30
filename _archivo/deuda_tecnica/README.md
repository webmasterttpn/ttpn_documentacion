# Deuda Técnica

Toda la deuda técnica vive en un único archivo: **[DEUDA_TECNICA.md](DEUDA_TECNICA.md)**

---

## Cómo usarlo

- **Nueva deuda:** agregar una entrada al tope de la sección "Pendientes / En progreso" con el siguiente ID correlativo.
- **Avance parcial:** agregar un bloque `**Avance:**` con fecha y descripción debajo de la entrada existente.
- **Deuda resuelta:** cambiar el `Status` a `✅ Completado — YYYY-MM-DD` y mover la entrada a la sección "Completados".
- **No crear archivos nuevos** — un solo archivo, status actualizable.

## Formato de una entrada

```markdown
### DT-XXX — Título descriptivo
**Registrada:** YYYY-MM-DD | **Dominio:** backend/frontend/infra | **Severidad:** Alta/Media/Baja
**Status:** Pendiente

Descripción breve de la deuda y por qué existe.

**Solución propuesta:** ...

**Avance:**
- YYYY-MM-DD: qué se hizo
```
