# Referencia de colores y áreas de la aplicación

## 1. Colores de marca (Primary)

| Variable / Clase | Valor | Área / Uso |
|------------------|-------|------------|
| **`--primary-brand-hex`** | `#ea580c` | Color principal de marca. Se usa en: botones principales (Add, Create, Save), logo/icono en header, pestañas activas del breadcrumb, barras de progreso del configurador, botones de acción en modales, skip links (accesibilidad), icono del configurador roller. |
| **`--primary-brand-hover`** | `#c2410c` | Estado hover de botones con `--primary-brand-hex` (p. ej. `.skip-link:hover`). |
| **`--brand-primary`** (HSL) | `20 92% 48%` | Mismo que `#ea580c`. Base para: `--primary`, `--accent`, `--ring`, `--focus-ring`. Usado por Tailwind como `primary`, `accent`, `ring`. |
| **`--primary-500-hex`** | `var(--orange-500)` | Variante 500 del primario. |
| **`--primary-600-hex`** | `var(--orange-600)` | Variante 600 (más oscura) del primario. |
| **`--primary-brand-rgba-10` a `-50`** | Mezclas 10–50% con transparente | Anillos de focus en inputs, botones, formularios y navegación; modo alto contraste. |

**Áreas donde se aplica primary (por componente):**

- **Layout / Header**: logo (`Layout.tsx`), pestañas activas del breadcrumb, fondo del botón de usuario/avatar activo.
- **Botones principales** (`bg-primary`, `var(--primary-brand-hex)`): Collections (Add New Collection), Manufacturers (Add New Manufacturer), BOMTemplates, QuoteNew, QuoteApproved, SaleOrders, Orders, ProductConfigurator, RollerBOMConfigurator, CompaniesSettings, Members, CatalogItemNew, etc.
- **Focus / ring**: `focus:ring-primary`, `focus:ring-primary/20`, `focus:border-primary/50` en inputs, selects, checkboxes y enlaces.
- **Estados de selección**: bordes y texto de ítems seleccionados en ProductStep, HardwareStep, OperatingSystemStep, VariantsStep, FabricStep (`border-primary`, `text-primary`).
- **Spinners de carga**: `border-primary` en loaders en muchas páginas.
- **QuoteLineCostsSectionV1**: botones de recalcular y enlaces de margen (`text-primary`, `bg-primary`).
- **FileUpload / ImageUpload**: borde y fondo al arrastrar (`border-primary`, `bg-primary/5`).
- **ProductionStepsTab, NotesTab**: indicadores/badges con `--primary-brand-hex`.
- **App.tsx**: botón principal del layout (ej. “Get Started” o similar) con `bg-primary`.

---

## 2. Colores semánticos (Tailwind / CSS)

| Variable / Token | Valor base | Área / Uso |
|-----------------|------------|------------|
| **`--foreground`** | `#1c1f26` (gray-900) | Texto principal del cuerpo, títulos, `card-foreground`, `popover-foreground`. |
| **`--background`** | `#fdfefe` (gray-50) | Fondo general del `body`, `card`, `popover`. |
| **`--primary-foreground`** | `#fdfefe` | Texto sobre fondos `primary` (botones primarios, accent). |
| **`--secondary`** | gray-500 | Botones secundarios, `btn-secondary`. |
| **`--muted`** / **`--muted-foreground`** | gray-100 / gray-500 | Fondos y texto secundario suave. |
| **`--accent`** | `--brand-primary` | Acentos (mismo que primary). |
| **`--destructive`** | red-600 | Acciones destructivas (borrar, cancelar peligroso). |
| **`--border`** / **`--input`** | gray-200 | Bordes por defecto e inputs. |
| **`--ring`** | `--brand-primary` | Anillo de foco (Tailwind). |
| **`--card`** / **`--popover`** | gray-50 | Fondos de tarjetas y popovers. |

---

## 3. Sidebar y navegación

| Variable | Valor | Área / Uso |
|----------|-------|------------|
| **`--sidebar-width`** | `240px` | Ancho del sidebar. |
| **`--sidebar-light-background`** | `--gray-50` | Fondo del sidebar en modo claro. |
| **`--sidebar-dark-background`** | `--gray-900` | Fondo del sidebar en modo oscuro (`.dark`). |
| **`--sidebar-background`** | `--sidebar-light-background` | Fondo efectivo del sidebar. |
| **`--sidebar-foreground`** | `--foreground` | Texto e iconos del sidebar. |
| **`--gray-250`** | `#E6EBF0` | Botones del sidebar en vista “employee”. |

---

## 4. Paleta Gray (fondos, texto, bordes)

| Variable | Valor | Uso típico |
|----------|-------|------------|
| **`--gray-50`** | `#fdfefe` | Fondos muy claros, `--white-hex`, cards, `--background`. |
| **`--gray-100`** | `#fafbfc` | Fondos suaves, `--muted`. |
| **`--gray-200`** | `#f5f7fa` | Bordes suaves, `--border`, `--input`, `.border-subtle`. |
| **`--gray-250`** | `#E6EBF0` | Botones del sidebar (vista employee). |
| **`--gray-300`** | `#d1d5db` | Bordes más fuertes, `.border-strong`, `--avatar-status-gray`. |
| **`--gray-400`** | `#9ca3af` | Iconos o texto deshabilitado. |
| **`--gray-500`** | `#6b7280` | Texto secundario, `--muted-foreground`, `--brand-secondary`, `--status-gray`. |
| **`--gray-600`** | `#4f5663` | Texto `text-secondary`. |
| **`--gray-700`** a **`--gray-950`** | `#3d4450` → `#0d1117` | Texto y fondos oscuros; `--graphite-black-hex` = gray-900 (#1c1f26). |

---

## 5. Colores de estado (status)

| Variable | Valor | Área / Uso |
|----------|-------|------------|
| **`--status-green`** | `#15803d` | Éxito, activo, aprobado. Clases: `text-status-green`, `bg-status-green`, `bg-status-green-light`, `border-t-status-green`. |
| **`--status-red`** | `#b91c1c` | Error, crítico, eliminar. `text-status-red`, `bg-status-red`, `bg-status-red-light`, etc. |
| **`--status-blue`** | `#2563eb` | Info, acciones neutras. `text-status-blue`, `bg-status-blue`, `bg-status-blue-light`, etc. |
| **`--status-purple`** | `#9333ea` | Estados especiales (p. ej. leave). `text-status-purple`, `bg-status-purple`, `bg-status-purple-light`, etc. |
| **`--status-yellow`** | `#a16207` | Advertencia. `text-status-yellow`, `bg-status-yellow`, etc. |
| **`--status-orange`** | `#c2410c` | Estado naranja. `text-status-orange`, `bg-status-orange`, `bg-status-orange-light`, etc. |
| **`--status-gray`** | `#6b7280` | Neutral, inactivo. `text-status-gray`, `bg-status-gray`, etc. |

---

## 6. Avatar status (puntos de estado en avatares)

| Variable | Valor | Uso |
|----------|-------|-----|
| **`--avatar-status-green`** | `#16a34a` | Punto “activo” / success en avatar. |
| **`--avatar-status-red`** | `#dc2626` | Punto error/inactivo. |
| **`--avatar-status-yellow`** | `#eab308` | Punto advertencia. |
| **`--avatar-status-purple`** | `#9333ea` | Punto estado especial. |
| **`--avatar-status-blue`** | `#2563eb` | Punto info. |
| **`--avatar-status-orange`** | `#ea580c` | Punto estado naranja. |
| **`--avatar-status-gray`** | `#d1d5db` | Punto neutral. |

Clases: `bg-avatar-status-*` para el fondo del punto.

---

## 7. Paletas por nombre (teal, navy, green, red, blue, orange, purple)

Usadas como base para variables semánticas o utilidades. Algunas referencias:

| Paleta | Variables | Uso principal |
|--------|-----------|----------------|
| **Teal** | `--teal-50` … `--teal-950` | `--row-highlight` (green-50 en práctica), `.text-primary-contrast` (teal-800). Paleta de apoyo al primario. |
| **Navy** | `--navy-50` … `--navy-950` | Utilidades `.text-navy-*`, `.bg-navy-*`, `.border-navy-*` (sidebar, acentos azulados). |
| **Green** | `--green-50` … `--green-950` | `--row-highlight`, fondos y bordes de estado success. |
| **Red** | `--red-50` … `--red-950` | Errores, destructive, alertas. |
| **Blue** | `--blue-50` … `--blue-950` | Info, `--status-blue`, `--highlight-bg`. |
| **Orange** | `--orange-50` … `--orange-950` | Estados naranja, `--status-orange`, `--avatar-status-orange`; algunos componentes usan `orange-500/600` directo. |
| **Purple** | `--purple-50` … `--purple-950` | Estados púrpura, `--status-purple`. |

---

## 8. Utilidades y otros

| Variable / Clase | Valor | Área / Uso |
|------------------|-------|------------|
| **`--focus-ring`** | `--brand-primary` | `box-shadow` de focus en `.focus-ring`. |
| **`--row-highlight`** | `--green-50` | Hover/fila destacada en tablas. |
| **`--highlight-bg`** | `#E3F2FD` | Fondos de hover o filas resaltadas (`.bg-highlight`). |
| **`--neutral-gray`** | `#9E9E9E` | Elementos deshabilitados o inactivos (`.bg-neutral-gray`, `.text-neutral-gray`). |
| **`--graphite-black-hex`** | `--gray-900` (#111827) | Texto oscuro; pestañas inactivas del breadcrumb en `Layout`. |
| **`--white-hex`** | `--gray-50` | Blanco de la app. |

---

## 9. Resumen por “área” de la UI

| Área | Colores usados | Dónde |
|------|----------------|-------|
| **Marca / primario** | `--primary-brand-hex` (#0B5F6A), `--primary-brand-hover`, `primary` | Botones principales, logo, pestañas activas, anillos de foco, selecciones en configuradores, spinners, badges de progreso. |
| **Fondos generales** | `--background`, `--gray-50`, `--gray-100` | `body`, cards, popovers, contenedores. |
| **Texto principal** | `--foreground`, `--gray-900` | Títulos, párrafos, `--card-foreground`. |
| **Texto secundario** | `--muted-foreground`, `--gray-500`, `--gray-600` | Subtítulos, hints, etiquetas. |
| **Sidebar** | `--sidebar-background`, `--sidebar-foreground`, `--gray-250` | Fondo, texto e iconos del menú lateral. |
| **Bordes e inputs** | `--border`, `--input`, `--gray-200`, `--gray-300` | Contornos, campos de formulario. |
| **Estados (éxito, error, info, etc.)** | `--status-*`, `--avatar-status-*` | Badges, indicadores, avatares, mensajes. |
| **Focus y accesibilidad** | `--primary-brand-hex`, `--primary-brand-rgba-*`, `--ring` | Anillos de foco en botones, inputs, enlaces, navegación; modo alto contraste. |
| **Skip links** | `--primary-brand-hex`, `--primary-brand-hover` | Enlaces de salto (accesibilidad). |

---

*Documento generado a partir de `src/styles/global.css`, `tailwind.config.ts` y uso en `src/**/*.{ts,tsx}`. Si cambias `--primary-brand-hex` o `--brand-primary`, se actualizan automáticamente: primary, accent, ring, focus-ring y todas las clases `bg-primary`, `text-primary`, `border-primary`, `focus:ring-primary`, etc.*
