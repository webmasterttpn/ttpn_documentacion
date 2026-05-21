# Prompts para generar mockup del Portal de Proveedores

Copia el prompt apropiado (Claude Design o Stitch) y pégalo en la
herramienta. Antes de pegar, ajusta el branding TTPN si quieres
(colores, nombre).

## Prompt para **Claude Design** (claude.ai/design)

```text
Diseña un mockup completo del **Portal de Proveedores TTPN**, una PWA
en español (México) donde los proveedores de una empresa de transporte
gestionan sus facturas. Genera 4 pantallas con vista escritorio +
móvil:

1. **Login**
   - Card centrado, fondo gris claro neutro
   - Logo "TTPN" + título "Portal de Proveedores"
   - Inputs: email, contraseña
   - Botón primario: "Entrar"
   - Link secundario: "¿Olvidaste tu contraseña?"
   - Estado de error: línea roja debajo del input + texto
   - Mobile: card a pantalla completa con padding 16px

2. **Estatus de Facturas** (pantalla principal después del login)
   - Header app con logo TTPN, nombre del proveedor logueado y menú
     dropdown (cerrar sesión, cambiar contraseña)
   - Drawer lateral con menú: Estatus de Facturas / Cargar Documentos
   - Filtros arriba: rango de fecha (calendario), select de estatus
     (Pendiente, En revisión, Aprobada, Rechazada, Programada,
     Pagada parcial, Pagada, Cancelada), select de moneda
   - Botón primario arriba a la derecha: "+ Subir Facturas" (PDF + XML)
   - Tabla con columnas: Folio, Fecha de Recepción, Fecha de
     Vencimiento, Fecha de Pago, Monto Total, Moneda, Estatus,
     UUID CFDI, Número de Orden, Sucursal, Número de Recepción
   - Estatus como chip de color (verde = pagada, azul = programada,
     ámbar = en revisión, gris = pendiente, rojo = rechazada)
   - Paginación abajo
   - Empty state cuando no hay facturas: ícono + "Aún no has subido
     facturas. Empieza con el botón Subir Facturas."
   - Loading: skeleton rows
   - Mobile: tabla colapsa a tarjetas apiladas con info clave

3. **Detalle de factura** (modal/drawer al pickar una fila)
   - Header: folio + estatus chip + botón cerrar
   - Sección "Datos de la factura":
     fecha recepción, fecha de vencimiento, fecha de pago,
     monto total, moneda, método de pago (PUE/PPD), UUID CFDI,
     número de orden, sucursal, número de recepción
   - Si está rechazada: bloque rojo destacado con "Motivo del rechazo"
     y nota del admin
   - Sección "Documentos": dos botones de descarga (PDF y XML)
   - Si es PPD pagada: sección "Complementos de pago" con tabla de
     complementos (UUID, fecha, monto)
   - Mobile: drawer de altura completa con scroll

4. **Cargar Documentos** (uploader bulk)
   - Drag-and-drop zone grande: "Arrastra hasta 40 archivos
     (PDF + XML por factura) o haz click para seleccionar"
   - Lista de archivos seleccionados con preview de nombre +
     status check (✓ válido / ✗ con motivo)
   - Pares emparejados PDF + XML automáticamente por nombre similar
   - Botón principal: "Subir todo" (deshabilitado hasta tener al
     menos 1 par válido)
   - Progress bar durante upload
   - Resultado: "✓ 38 subidas exitosamente / ✗ 2 rechazadas (ver
     motivo)"
   - Mobile: layout vertical, drop zone más compacta

Branding:
- Color primario: azul oscuro corporativo (#1B3A5C o similar)
- Color secundario: blanco / gris muy claro
- Tipografía: Inter o similar sans-serif legible
- Sin recargado visual; estilo limpio tipo "enterprise app"
- Iconografía Material Design

Mobile-first:
- Diseña primero para móvil 375px de ancho, luego escala a desktop
  1280px.
- Toques con áreas mínimas de 44x44px.
- Tipografía 16px mínimo en inputs (evita zoom automático en iOS).

Estados a representar visualmente:
- Empty state (sin facturas)
- Loading (skeletons o spinners)
- Error (banner rojo con CTA)
- Success (toast verde)

Entrega:
- 4 frames principales en escritorio + 4 frames en móvil
- Anota componentes reutilizables (botones, chips de estatus, inputs)
- Especifica spacings (8/16/24/32px)
- Exporta colores como variables (tokens) para que el dev los copie
  directo al theme de Quasar
```

---

## Prompt para **Stitch** (stitch.withgoogle.com)

Stitch es más visual/generativo. Usa un prompt corto y deja que
itere. Pega esto:

```text
Diseña un portal web para proveedores de una empresa de transporte
mexicana ("TTPN — Portal de Proveedores"). 4 pantallas en español:

1. Login (email + contraseña + link recuperar contraseña, layout
   centrado, branding azul oscuro corporativo).

2. Estatus de Facturas: pantalla principal con header de app, menú
   lateral, filtros (rango fecha, estatus, moneda), tabla con
   columnas (Folio, Fecha Recepción, Fecha Vencimiento, Fecha Pago,
   Monto, Moneda, Estatus como chip de color, UUID CFDI, No. Orden,
   Sucursal, No. Recepción), paginación, botón "Subir Facturas".

3. Detalle de factura (modal/drawer): folio, estatus, todos los
   datos fiscales, botones para descargar PDF y XML del CFDI,
   sección de complementos de pago si los tiene, motivo de rechazo
   destacado si aplica.

4. Cargar Documentos: drag-and-drop bulk para hasta 40 facturas
   (PDF + XML por factura), lista de archivos con validación
   visual, progress bar, resultado al final.

Estilo: clean, enterprise, mobile-first. Color primario azul oscuro
corporativo. Iconografía Material Design. Estados de error, loading
y empty state representados.
```

---

## Si el mockup no convence al primer intento

- Itera con "Hazlo más minimalista" / "Más espacio en blanco" /
  "Reduce el contraste del fondo".
- Pide variaciones específicas: "Versión 2 con drawer fijo en
  desktop, versión 3 con tabs arriba".
- Para responsivo: "Muéstrame también la versión 320px ancho".

## Cuando tengas el mockup aprobado

1. Exporta los frames como PNG + el design system (tokens, colores,
   spacings).
2. Pégalos en `mockups/` dentro de este repo de documentación.
3. Reúnete con el dev frontend para revisar 1:1 el mockup vs los
   componentes Quasar disponibles.
4. Cualquier desviación entre mockup y componente Quasar se anota
   en `manual_frontend.md` como "decisión de implementación".
