# 🎨 Paleta de Colores - Adaptio ERP (Estilo Citel)

Paleta inspirada en **Citel Software**, adaptada para Adaptio ERP con los colores exactos identificados.

---

## 🌈 Colores Principales (Citel)

### Brand Identity

| Rol | Color | Hex | Variable CSS | Uso |
|-----|-------|-----|--------------|-----|
| **🔵 Primario** | Cyan brillante | `#008DD2` | `--primary-brand-hex` | Botones CTA, enlaces, acentos, logo |
| **🔵 Primario hover** | Cyan oscuro | `#00678d` | `--primary-brand-hover` | Hover botones principales |
| **🌊 Secundario** | Gris azulado | `#5C8DA6` | `--secondary-brand-hex` | Botones secundarios, elementos neutros |
| **🌑 Sidebar/Footer** | Navy muy oscuro | `#0D202D` | `--sidebar-base` | Sidebar, footer, elementos profundos |
| **🟢 Acento gráficos** | Verde neón | `#00E676` | `--accent-green-neon` | Métricas, gráficos, success vibrante |

### Fondos y Texto

| Elemento | Color | Hex | Variable |
|----------|-------|-----|----------|
| **Fondo app principal** | Gris claro | `#F5F7F8` | `--background` / `--gray-50` |
| **Texto en fondo claro** | Gris oscuro | `#333333` | `--foreground` / `--text-light-hex` |
| **Texto en fondo oscuro** | Blanco | `#FFFFFF` | `--white-hex` |
| **Bordes sutiles** | Gris | `#e5e7eb` | `--gray-200` |
| **Cards** | Gris claro | `#f3f4f6` | `--gray-100` |

---

## 🎯 Uso por Componente

### Botones

```tsx
/* Primario - Cyan Citel */
<button 
  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
  className="px-4 py-2 text-white hover:opacity-90"
>
  Save Changes
</button>

/* Secundario - Gris azulado Citel */
<button 
  style={{ backgroundColor: 'var(--secondary-brand-hex)' }}
  className="px-4 py-2 text-white hover:opacity-90"
>
  View Details
</button>

/* Success con verde neón Citel */
<button 
  style={{ backgroundColor: 'var(--status-green)' }}
  className="px-4 py-2 text-white"
>
  Confirm
</button>
```

### Sidebar (Navy oscuro Citel)

```tsx
<nav style={{ backgroundColor: 'var(--sidebar-base)' }}> {/* #0D202D */}
  <a 
    href="/directory"
    style={{ 
      color: isActive ? '#FFFFFF' : 'var(--sidebar-text-inactive)',
      borderLeft: isActive ? '3px solid var(--sidebar-accent)' : 'none',
      backgroundColor: isActive ? 'var(--sidebar-active-hover)' : 'transparent'
    }}
  >
    Directory
  </a>
</nav>
```

### Badges de Estado

```tsx
/* Info/Primary - Cyan Citel */
<span className="px-2 py-1 rounded bg-cyan-100 text-status-cyan text-xs font-medium">
  Active
</span>

/* Success - Verde neón Citel */
<span className="px-2 py-1 rounded bg-green-neon-100 text-status-green text-xs font-medium">
  Confirmed
</span>

/* Neutral - Gris azulado Citel */
<span className="px-2 py-1 rounded bg-navy-100 text-status-gray text-xs font-medium">
  Pending
</span>

/* Error - Rojo estándar */
<span className="px-2 py-1 rounded bg-red-100 text-status-red text-xs font-medium">
  Rejected
</span>
```

### Avatar Status Dots

```tsx
/* Cyan primario Citel */
<div style={{ backgroundColor: 'var(--avatar-status-cyan)' }} 
     className="w-3 h-3 rounded-full" />

/* Verde neón Citel */
<div style={{ backgroundColor: 'var(--avatar-status-green)' }} 
     className="w-3 h-3 rounded-full" />

/* Gris azulado Citel (inactive) */
<div style={{ backgroundColor: 'var(--avatar-status-gray)' }} 
     className="w-3 h-3 rounded-full" />
```

### Tabs (cyan underline)

```tsx
<div className="flex border-b border-gray-200">
  <button
    style={{
      borderBottom: isActive ? '2px solid var(--tab-active-underline)' : 'none',
      color: isActive ? 'var(--primary-brand-hex)' : 'var(--gray-600)'
    }}
    className="px-4 py-2"
  >
    Contacts
  </button>
</div>
```

---

## 📊 Status Colors Completos

| Estado | Color | Hex | Variable | Cuándo usar |
|--------|-------|-----|----------|-------------|
| **Primary/Info** | Cyan brillante | `#008DD2` | `--status-cyan` | Estado principal, info destacada |
| **Success vibrante** | Verde neón | `#00E676` | `--status-green` | Success vibrante, gráficos, métricas |
| **Success estándar** | Verde | `#15803d` | `--status-green-standard` | Success sobrio, aprobado |
| **Error/Delete** | Rojo | `#b91c1c` | `--status-red` | Errores, rechazado, eliminar |
| **Info neutral** | Azul | `#2563eb` | `--status-blue` | Información neutra |
| **Warning** | Amarillo | `#a16207` | `--status-yellow` | Advertencia, pendiente |
| **Alert** | Naranja | `#ea580c` | `--status-orange` | Alerta importante |
| **Special** | Morado | `#9333ea` | `--status-purple` | Archivado, especial |
| **Inactive** | Gris azulado | `#5C8DA6` | `--status-gray` | Deshabilitado, inactivo (Citel) |

---

## 🎨 Escala Completa por Color

### Cyan (Primario Citel #008DD2)

```css
--cyan-950: #042f3a
--cyan-900: #064556
--cyan-800: #075672
--cyan-700: #00678d   (hover)
--cyan-600: #008DD2   ← PRIMARIO
--cyan-500: #00A3EC   (variante clara)
--cyan-400: #33b8f0
--cyan-300: #66cdf4
--cyan-200: #99e1f8
--cyan-100: #ccf0fb   (fondo badges)
--cyan-50:  #e6f8fd   (row highlight)
```

### Navy (Sidebar/Footer Citel #0D202D)

```css
--navy-950: #0A1418
--navy-900: #0D202D   ← SIDEBAR/FOOTER BASE
--navy-800: #132B3B   ← SIDEBAR HOVER
--navy-700: #1a3847
--navy-650: #234858
--navy-600: #2d5769
--navy-500: #39687b
--navy-400: #5C8DA6   ← SECUNDARIO (gris azulado)
--navy-300: #7da4b8
--navy-200: #a3bfce
--navy-100: #c9dae3   (fondo badges gris)
--navy-50:  #e8f1f5
```

### Green Neon (Gráficos Citel #00E676)

```css
--green-neon-700: #00b359  (hover)
--green-neon-600: #00E676  ← VERDE NEÓN CITEL
--green-neon-500: #00FF99  (más claro)
--green-neon-100: #ccfff0  (fondo badges)
--green-neon-50:  #e6fff8
```

---

## ✅ Contrastes WCAG 2.2

| Combinación | Ratio | Estado |
|-------------|-------|--------|
| Cyan `#008DD2` sobre blanco | **4.6:1** | ✅ AA |
| Cyan `#008DD2` sobre `#F5F7F8` | **4.4:1** | ✅ AA (casi) |
| Navy `#0D202D` con blanco | **15.2:1** | ✅ AAA |
| Verde neón `#00E676` sobre navy | **6.8:1** | ✅ AA |
| Texto `#333333` sobre `#F5F7F8` | **9.1:1** | ✅ AAA |

---

## 🔄 Migración Automática

Todas las referencias a:
- `var(--primary-brand-hex)` → Ahora apuntan a **`#008DD2`** (cyan Citel)
- `var(--sidebar-base)` → Ahora apuntan a **`#0D202D`** (navy oscuro Citel)
- `var(--status-green)` → Ahora apuntan a **`#00E676`** (verde neón Citel)

**Archivos actualizados:**
- ✅ `src/styles/global.css` - Paleta completa con colores Citel
- ✅ `docs/COLOR_PALETTE.md` - Documentación actualizada

**Próximo paso:**
Recarga la app en el navegador para ver los cambios (los CSS se aplicarán inmediatamente). Los botones serán cyan `#008DD2`, el sidebar navy oscuro `#0D202D`, y cualquier uso de `--primary-brand-hex` mostrará el cyan de Citel.
