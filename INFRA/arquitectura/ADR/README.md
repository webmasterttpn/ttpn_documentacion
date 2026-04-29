# Architecture Decision Records (ADR)

Registro de decisiones de arquitectura significativas. Cada ADR documenta por qué se tomó una decisión, qué alternativas se consideraron y qué consecuencias tiene.

## Cuándo escribir un ADR

- Se elige una librería o patrón que no es evidente (ej: por qué devise-jwt y no Doorkeeper)
- Se decide cómo estructurar algo que tendrá impacto duradero (ej: multi-tenancy via `Current`, no via subdominios)
- Se descarta una opción que "parece obvia" para que no se revisite en el futuro
- Se toma una decisión con trade-offs conocidos

## Cuándo NO escribir un ADR

- Decisiones de implementación de bajo nivel (cómo nombrar una variable)
- Cosas que ya están en `CLAUDE.md` como estándar obligatorio
- Decisiones reversibles sin costo significativo

## Nombre del archivo

```text
ADR-001-titulo-en-kebab-case.md
ADR-002-otro-titulo.md
```

Siempre con número de 3 dígitos para que se ordenen correctamente.

## Template

```markdown
# ADR-XXX: Título de la decisión

**Fecha:** YYYY-MM-DD
**Estado:** Propuesto | Aceptado | Deprecado | Reemplazado por ADR-YYY

## Contexto

Qué problema o situación motivó esta decisión. Sin juzgar todavía.

## Opciones consideradas

1. **Opción A** — descripción breve. Pro: ... Contra: ...
2. **Opción B** — descripción breve. Pro: ... Contra: ...

## Decisión

Qué se eligió y por qué.

## Consecuencias

- Qué se gana
- Qué trade-offs se aceptan
- Qué queda pendiente o condicionado a esta decisión
```

## ADRs activos

*(ninguno documentado aún — registrar aquí a medida que se tomen decisiones)*
