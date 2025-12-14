# Design System - Padding Standards
## Manual de Diseño Gráfico - Sistema de Espaciado

### 🎨 Principio de Diseño
El sistema de padding está diseñado para crear una jerarquía visual clara y consistente, donde los elementos internos (cards, search bars, tablas) controlan su propio espaciado horizontal, mientras que el contenedor principal solo proporciona espaciado vertical.

---

## 📐 Reglas de Padding

### 1. Viewers (Contacts, Customers, Vendors)

#### Contenedor Principal
```css
py-6
```
- **Solo padding vertical** (`py-6` = 1.5rem / 24px arriba y abajo)
- **Sin padding horizontal** - Los elementos internos controlan su propio padding horizontal
- Esto evita duplicación de padding y mantiene alineación consistente

#### Header del Viewer
```css
Sin padding adicional
```
- El header está dentro del contenedor principal sin padding horizontal adicional
- Se alinea naturalmente con el contenido

#### Elementos Internos (Search Bar, Tablas, Paginación)
```css
py-6 px-6
```
- **Padding completo** en todos los elementos con fondo blanco y borde
- Esto incluye:
  - Search Bar: `py-6 px-6`
  - Tablas (contenedor): Sin padding adicional (el padding está en las celdas)
  - Celdas de tabla (`<th>` y `<td>`): `px-6` (padding horizontal simétrico)
  - Paginación: `py-6 px-6`

**Ejemplo de estructura:**
```tsx
<div className="py-6">  {/* Contenedor principal - solo vertical */}
  {/* Header */}
  <div className="flex items-center justify-between mb-6">...</div>
  
  {/* Search Bar */}
  <div className="mb-4">
    <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
      {/* Contenido del search bar */}
    </div>
  </div>
  
  {/* Tabla */}
  <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr>
            <th className="py-3 px-6">...</th>  {/* px-6 en todas las celdas */}
          </tr>
        </thead>
        <tbody>
          <tr>
            <td className="py-4 px-6">...</td>  {/* px-6 en todas las celdas */}
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  
  {/* Paginación */}
  <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
    {/* Contenido de paginación */}
  </div>
</div>
```

---

### 2. Formularios (ContactNew, CustomerNew, VendorNew, OrganizationUserNew)

#### Contenedor Principal
```css
py-6 px-6
```
- **Padding completo** en formularios
- Esto proporciona espacio consistente alrededor de todo el formulario

#### Header del Formulario
```css
Sin padding adicional
```
- El header está dentro del contenedor principal con `px-6`
- Se alinea naturalmente con el contenido del formulario

#### Contenedor Interno del Formulario (Form Body)
```css
py-6 px-6
```
- **Padding completo** en el contenedor interno del formulario
- Esto asegura que el contenido del formulario tenga el mismo espaciado que el search bar

**Ejemplo de estructura:**
```tsx
<div className="py-6 px-6">  {/* Contenedor principal - completo */}
  {/* Header */}
  <div className="flex items-center justify-between mb-6">...</div>
  
  {/* Formulario */}
  <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
    <div className="py-6 px-6">  {/* Contenedor interno - completo */}
      {/* Campos del formulario */}
    </div>
  </div>
</div>
```

---

### 3. Estados Especiales (Loading, Error, Advertencias)

```css
py-6 px-6
```
- **Padding completo** para mantener consistencia con formularios
- Los mensajes internos tienen su propio padding (`p-4`)

---

## 🎯 Alturas de Campos

### Campos de Formulario
```css
py-1 text-xs
```
- **Altura consistente** para todos los inputs, selects y campos de formulario
- Esto asegura alineación visual perfecta entre diferentes tipos de campos

---

## 🔘 Botones de Acción en Tablas

### Regla General para Botones de Acción
Los botones de acción (Edit, Copy, Archive, Delete) en las columnas Actions de las tablas deben seguir estas reglas:

#### Padding de Botones
```css
p-1.5
```
- **Padding uniforme** de `p-1.5` (6px) en todos los botones de acción
- Esto asegura que los botones tengan la misma altura que el botón de cuadrícula (Grid3X3) en la barra de búsqueda
- Alineación vertical perfecta entre botones de acción y controles de vista

#### Padding de Columna Actions
```css
px-6
```
- **Padding simétrico** en la columna Actions:
  - **Izquierda y Derecha**: `px-6` (24px cada lado) - Mantiene alineación con otras columnas
- Esto aplica tanto al header (`<th>`) como a las celdas (`<td>`)
- **Alineación de botones**: Los botones deben usar `justify-end` para que el último botón (borrar) esté alineado con el borde interno derecho del search bar (línea roja)

**Ejemplo de implementación:**
```tsx
{/* Header */}
<th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>

{/* Celda */}
<td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
  <div className="flex items-center gap-1 justify-end">
    <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600">
      <Edit className="w-4 h-4" />
    </button>
    <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600">
      <Copy className="w-4 h-4" />
    </button>
    <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600">
      <Archive className="w-4 h-4" />
    </button>
    <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50">
      <Trash2 className="w-4 h-4" />
    </button>
  </div>
</td>
```

**Justificación:**
- Los botones deben estar alineados verticalmente con el botón de cuadrícula (`p-1.5`)
- El padding simétrico (`px-6`) mantiene la alineación con el contenido de otras columnas
- **IMPORTANTE**: Los botones deben usar `justify-end` para que el último botón (borrar) esté alineado con el borde interno derecho del search bar

**Regla de Alineación de la Columna Actions:**
- La celda Actions debe tener `px-6` (padding simétrico igual que otras columnas)
- Los botones deben usar `justify-end` para alinearse a la derecha
- El botón de borrar (último) debe quedar alineado con la línea roja (el padding interno derecho del search bar `px-6`)
- Esta alineación es crítica y NO debe modificarse

---

## 📊 Resumen de Aplicación

| Tipo de Elemento | Padding | Justificación |
|------------------|---------|---------------|
| **Viewer - Contenedor Principal** | `py-6` | Solo vertical para evitar duplicación |
| **Viewer - Header** | Sin padding adicional | Dentro del contenedor principal |
| **Viewer - Search Bar** | `py-6 px-6` | Padding completo en elemento con fondo |
| **Viewer - Tabla (contenedor)** | Sin padding adicional | El padding está en las celdas |
| **Viewer - Celdas de Tabla (`<th>`, `<td>`)** | `px-6` | Padding horizontal simétrico (24px cada lado) |
| **Viewer - Columna Actions (`<th>`, `<td>`)** | `px-6` | Padding simétrico (24px cada lado) - Botones alineados a la derecha con `justify-end` |
| **Viewer - Botones de Acción** | `p-1.5` | Padding uniforme (6px) para alineación con botón de cuadrícula |
| **Viewer - Paginación** | `py-6 px-6` | Padding completo en elemento con fondo |
| **Formulario - Contenedor Principal** | `py-6 px-6` | Padding completo para formularios |
| **Formulario - Header** | Sin padding adicional | Dentro del contenedor principal |
| **Formulario - Contenedor Interno (Form Body)** | `py-6 px-6` | Padding completo para contenido |
| **Campos de Formulario** | `py-1 text-xs` | Altura consistente |

---

## 🔍 Referencia Visual

### Viewer (Contacts, Customers, Vendors)
```
┌─────────────────────────────────────────┐
│  [py-6] ← Solo padding vertical          │
│  ┌───────────────────────────────────┐  │
│  │ Header (sin padding adicional)    │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ [py-6 px-6] Search Bar            │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ Tabla                              │  │
│  │  ┌───────────────────────────────┐ │  │
│  │  │ [px-6] Contenido celdas      │ │  │
│  │  └───────────────────────────────┘ │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ [py-6 px-6] Paginación            │  │
│  └───────────────────────────────────┘  │
│  [py-6] ← Solo padding vertical          │
└─────────────────────────────────────────┘
```

### Formulario (ContactNew, CustomerNew, VendorNew, OrganizationUserNew)
```
┌─────────────────────────────────────────┐
│  [py-6 px-6] ← Padding completo         │
│  ┌───────────────────────────────────┐  │
│  │ Header                            │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ ┌───────────────────────────────┐  │  │
│  │ │ [py-6 px-6] Contenido Form   │  │  │
│  │ └───────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
│  [py-6 px-6] ← Padding completo          │
└─────────────────────────────────────────┘
```

---

## ✅ Archivos Afectados

### Viewers
- `src/pages/directory/Contacts.tsx` ✅
- `src/pages/directory/Customers.tsx` ✅
- `src/pages/directory/Vendors.tsx` ✅

### Formularios
- `src/pages/directory/ContactNew.tsx` ✅
- `src/pages/directory/CustomerNew.tsx` ✅
- `src/pages/directory/VendorNew.tsx` ✅
- `src/pages/settings/OrganizationUserNew.tsx` ✅

---

## 🎨 Principios de Diseño

1. **Jerarquía Visual**: Los elementos con fondo blanco y borde controlan su propio padding horizontal
2. **Consistencia**: El padding del search bar (`py-6 px-6`) es la referencia para todos los elementos internos
3. **Alineación**: El contenedor principal solo proporciona espaciado vertical para evitar desalineación
4. **Claridad**: Cada elemento tiene responsabilidad clara sobre su espaciado
5. **Simetría**: El padding horizontal es siempre simétrico (`px-6` = 24px a cada lado) en todas las columnas, incluyendo Actions
6. **Alineación Vertical**: Los botones de acción deben tener la misma altura que los controles de vista (`p-1.5`)
7. **Alineación de Botones Actions**: Los botones deben usar `justify-end` para que el botón de borrar esté alineado con el borde interno derecho del search bar (línea roja). **Esta regla es crítica y NO debe modificarse**

---

## 📝 Notas para Desarrolladores

- **Nuevos módulos**: Aplicar estas reglas desde el inicio
- **Refactoring**: Cuando se modifiquen módulos existentes, actualizar al nuevo estándar
- **Testing visual**: Verificar que el padding izquierdo y derecho sean consistentes en todos los elementos con fondo blanco
- **Tablas**: Todas las celdas (`<th>` y `<td>`) deben usar `px-6` para mantener alineación con el search bar
- **Columna Actions**: Usar `px-6` - Los botones usan `justify-end` para que el botón de borrar esté alineado con el borde interno derecho del search bar
- **Botones de Acción**: Usar `p-1.5` para alineación vertical con el botón de cuadrícula

---

## 🔧 Reglas de Oro

### Regla 1: Alineación de Contenido
**El contenido de las tablas debe alinearse con el campo de búsqueda del search bar.**

Esto se logra usando `px-6` (24px) en todas las celdas de la tabla, que coincide con el padding horizontal del search bar (`px-6`).

### Regla 2: Botones de Acción
**Los botones de acción deben estar alineados verticalmente con el botón de cuadrícula y el botón de borrar debe estar alineado con el borde interno derecho del search bar.**

- **Padding de botones**: `p-1.5` (6px) - Misma altura que el botón de cuadrícula
- **Padding de columna Actions**: `px-6` (24px cada lado) - Padding simétrico igual que otras columnas
- **Alineación de botones**: Usar `justify-end` para que el último botón (borrar) esté alineado con el borde interno derecho del search bar (línea roja)
- **Contenedor de botones**: DEBE usar `justify-end` - Esta alineación es crítica y NO debe modificarse

### Regla 3: Alineación de la Columna Actions
**REGLAS CRÍTICAS - NO MODIFICAR:**

1. **Header "Actions"**: El texto debe estar alineado con el botón EDIT usando `text-right` (donde empiezan los botones)
2. **Botón de borrar**: El último botón debe estar alineado con el borde interno derecho del search bar (línea roja) usando `justify-end`

Esta regla aplica a todos los viewers (Contacts, Customers, Vendors, y futuros módulos):

- **Header Actions**: `<th className="text-right py-3 px-6">Actions</th>`
  - `text-right`: El texto "Actions" se alinea a la derecha con donde empiezan los botones
  - `px-6`: Padding simétrico igual que otras columnas
  
- **Celda Actions**: `<td className="py-4 px-6">`
  - `px-6`: Padding simétrico igual que otras columnas
  
- **Contenedor de botones**: `<div className="flex items-center gap-1 justify-end">`
  - `justify-end`: Los botones se alinean a la derecha, el botón de borrar queda alineado con el borde interno derecho del search bar

**Resultado**: 
- El header "Actions" está alineado con donde empiezan los botones EDIT (derecha)
- El botón de borrar está alineado con el borde interno derecho del search bar (derecha)
- Todo está alineado a la derecha de la columna

**Ejemplo correcto:**
```tsx
{/* Header con text-right - alineado con donde empiezan los botones */}
<th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>

{/* Celda con justify-end - botón de borrar alineado con el borde derecho */}
<td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
  <div className="flex items-center gap-1 justify-end">
    <button className="p-1.5 ...">
      <Edit className="w-4 h-4" />  {/* Primer botón - alineado con el header */}
    </button>
    {/* otros botones */}
    <button className="p-1.5 ...">
      <Trash2 className="w-4 h-4" />  {/* Último botón - alineado con el borde derecho */}
    </button>
  </div>
</td>
```

**Ejemplos incorrectos (NO usar):**
```tsx
{/* ❌ INCORRECTO: Header con text-left */}
<th className="text-left py-3 px-6">Actions</th>

{/* ❌ INCORRECTO: Sin justify-end, el botón de borrar NO queda alineado con el borde derecho */}
<div className="flex items-center gap-1">

{/* ❌ INCORRECTO: Con justify-start, los botones quedan alineados a la izquierda */}
<div className="flex items-center gap-1 justify-start">
```

**REGLAS CRÍTICAS - NO MODIFICAR:**
1. Header "Actions" DEBE tener `text-right` (alineado con donde empiezan los botones)
2. Contenedor de botones DEBE tener `justify-end` (botón de borrar alineado con el borde derecho)
3. Todo debe estar alineado a la derecha de la columna
4. Esta configuración es la ÚNICA correcta y NO debe modificarse

---

**Última actualización**: Basado en el análisis del módulo Contacts como referencia estándar. Aplicado consistentemente a todos los módulos de Directory y Settings.
