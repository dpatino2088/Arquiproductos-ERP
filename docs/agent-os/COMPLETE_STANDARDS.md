# RHEMO Frontend - Complete Design System Standards

## Overview
This document consolidates all design system standards for the RHEMO frontend application, ensuring consistency across all pages and components.

## Table of Contents
1. [Color System](#color-system)
2. [Status Colors](#status-colors)
3. [Avatar Standards](#avatar-standards)
4. [Search Card Standards](#search-card-standards)
5. [Pagination Standards](#pagination-standards)
6. [Tooltip Standards](#tooltip-standards)
7. [Status Pills Standards](#status-pills-standards)
8. [Icon Standards](#icon-standards)
9. [Button Standards](#button-standards)
10. [Implementation Checklist](#implementation-checklist)

---

## Color System

### Primary Colors
```css
/* Primary Brand Colors */
--teal-700: #008383;  /* Primary brand color - anchor */
--teal-600: #009999;  /* Management view */
--teal-500: #00b3b3;  /* Management view sidebar */

/* Neutral Colors */
--gray-900: #1c1f26;  /* Dark text */
--gray-50: #fdfefe;   /* Light background */
--gray-500: #6b7280;  /* Neutral gray */
```

### Usage Guidelines
- **Primary Teal 700** (`#008383`): Use for primary actions, brand elements, and focus states
- **Gray 500** (`#6b7280`): Use for neutral states, inactive elements, and secondary text
- **Gray 50** (`#fdfefe`): Use for light backgrounds and subtle highlights

---

## Status Colors

### Color Definitions
```css
/* Status colors per design system specification - WCAG 2.2 AA compliant */
--status-green: #15803d;   /* Success/Active - Green 700 */
--status-red: #b91c1c;     /* Error/Critical/Delete - Red 700 */
--status-blue: #2563eb;    /* Info/Neutral actions - Blue 500 */
--status-purple: #9333ea;  /* Purple status - Purple 600 */
--status-yellow: #a16207;  /* Yellow status - Yellow 700 */
--status-orange: #c2410c;  /* Orange status - Orange 700 */
--status-gray: #6b7280;    /* Gray status - Gray 500 */
```

### CSS Classes
```css
/* Text colors */
.text-status-green { color: var(--status-green); }
.text-status-red { color: var(--status-red); }
.text-status-blue { color: var(--status-blue); }
.text-status-purple { color: var(--status-purple); }
.text-status-yellow { color: var(--status-yellow); }
.text-status-orange { color: var(--status-orange); }
.text-status-gray { color: var(--status-gray); }

/* Background colors */
.bg-status-green { background-color: var(--status-green); }
.bg-status-red { background-color: var(--status-red); }
.bg-status-blue { background-color: var(--status-blue); }
.bg-status-purple { background-color: var(--status-purple); }
.bg-status-yellow { background-color: var(--status-yellow); }
.bg-status-orange { background-color: var(--status-orange); }
.bg-status-gray { background-color: var(--status-gray); }

/* Border colors for tooltip arrows */
.border-t-status-green { border-top-color: var(--status-green); }
.border-t-status-red { border-top-color: var(--status-red); }
.border-t-status-blue { border-top-color: var(--status-blue); }
.border-t-status-purple { border-top-color: var(--status-purple); }
.border-t-status-yellow { border-top-color: var(--status-yellow); }
.border-t-status-orange { border-top-color: var(--status-orange); }
.border-t-status-gray { border-top-color: var(--status-gray); }
```

### Usage Guidelines
- **NEVER use hardcoded colors** like `text-red-600`, `bg-blue-500`, etc.
- **ALWAYS use status color classes** like `text-status-red`, `bg-status-blue`, etc.
- **Status colors are for semantic meaning**, not decorative purposes

---

## Avatar Standards

### Background Color
- **ALL avatars without photos** must use `#008383` (Primary Teal 700)
- **NO random colors** or color generation based on names
- **Consistent appearance** across all pages

### Implementation
```typescript
// ✅ CORRECT - Always use Teal 700
const generateAvatarColor = (firstName: string, lastName: string) => {
  return '#008383'; // Primary Teal 700
};

// ❌ WRONG - Random colors
const generateAvatarColor = (firstName: string, lastName: string) => {
  const colors = ['#008383', '#1976D2', '#D32F2F', ...];
  // Random color selection logic
};
```

### Status Dots
- **Size**: 2.5x2.5 for table view, 3x3 for card/modal view
- **Position**: `-bottom-0.5 -right-0.5` (table) or `-bottom-1 -right-1` (card/modal)
- **Border**: `border border-white` (table) or `border-2 border-white` (card/modal)
- **Colors**: Use status colors based on current state

---

## Search Card Standards

### Active Button States
- **Background**: `bg-gray-300`
- **Text**: `text-black`
- **Apply to**: Filter buttons, view mode toggles (List/Grid), sort buttons

### Implementation
```typescript
// ✅ CORRECT - Active state
className={`px-2 py-1 border border-gray-300 rounded transition-colors ${
  isActive ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
}`}

// ❌ WRONG - Old active state
className={`px-2 py-1 border border-gray-300 rounded transition-colors ${
  isActive ? 'bg-gray-100 text-gray-900' : 'bg-white text-gray-700 hover:bg-gray-50'
}`}
```

### Required Elements
- Search input with search icon
- Filter button (always present)
- View mode toggle (List/Grid) when applicable
- Sort options
- Clear filters button

---

## Pagination Standards

### Current Page Button
- **Background**: `bg-gray-300`
- **Text**: `text-black`
- **Border**: `border border-gray-300`

### Implementation
```typescript
// ✅ CORRECT - Current page
className={`px-2 py-1 border border-gray-300 rounded text-xs transition-colors ${
  page === currentPage 
    ? 'bg-gray-300 text-black' 
    : 'bg-white text-gray-700 hover:bg-gray-50'
}`}

// ❌ WRONG - Old current page
className={`px-2 py-1 border border-gray-300 rounded text-xs transition-colors ${
  page === currentPage 
    ? 'bg-teal-100 text-teal-700' 
    : 'bg-white text-gray-700 hover:bg-gray-50'
}`}
```

### Required Elements
- Previous/Next buttons with text
- Page numbers (max 5 visible)
- Items per page selector
- Results counter
- Intelligent page display logic

---

## Tooltip Standards

### Behavior
- **Trigger**: Always `onClick` (toggle behavior)
- **Position**: `bottom-full` with upward-pointing arrow
- **Event Handling**: Always use `e.stopPropagation()`

### Styling
```css
/* Base tooltip styles */
.tooltip {
  @apply absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50;
}

/* Arrow styles - Use direct hex colors for reliability */
.tooltip-arrow {
  @apply absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent;
}
```

### Color Implementation
```typescript
// ✅ CORRECT - Direct hex colors for arrows
<div className={`border-t-[#b91c1c]`}></div>  // Red arrow
<div className={`border-t-[#15803d]`}></div>  // Green arrow
<div className={`border-t-[#2563eb]`}></div>  // Blue arrow

// ❌ WRONG - Custom classes that don't work
<div className={`border-t-status-red`}></div>
```

### Required Elements
- Contextual background color
- Matching arrow color
- Unique tooltip IDs
- Proper z-index (z-50)

---

## Status Pills Standards

### Color Pattern
- **Text**: Always use `text-status-*` classes
- **Background**: Always use `*-50` backgrounds (e.g., `bg-red-50`, `bg-green-50`)

### Implementation
```typescript
// ✅ CORRECT - Status pill pattern
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
  Error
</span>

// ❌ WRONG - Inconsistent colors
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-600">
  Error
</span>
```

### Color Mappings
- **Red**: `bg-red-50 text-status-red`
- **Green**: `bg-green-50 text-status-green`
- **Blue**: `bg-blue-50 text-status-blue`
- **Purple**: `bg-purple-50 text-status-purple`
- **Yellow**: `bg-yellow-50 text-status-yellow`
- **Orange**: `bg-orange-50 text-status-orange`
- **Gray**: `bg-gray-50 text-status-gray`

---

## Icon Standards

### Status Icons
- **ALWAYS use status color classes** for icons accompanying status pills
- **Icon color must match pill text color**
- **NO hardcoded colors** like `text-blue-600`, `text-red-500`, etc.

### Implementation
```typescript
// ✅ CORRECT - Icon matches pill color
const getStatusIcon = (status) => {
  switch (status) {
    case 'active':
      return <CheckCircle className="w-4 h-4 text-status-green" />;
    case 'error':
      return <XCircle className="w-4 h-4 text-status-red" />;
    case 'warning':
      return <AlertTriangle className="w-4 h-4 text-status-yellow" />;
  }
};

// ❌ WRONG - Hardcoded colors
const getStatusIcon = (status) => {
  switch (status) {
    case 'active':
      return <CheckCircle className="w-4 h-4 text-green-600" />;
    case 'error':
      return <XCircle className="w-4 h-4 text-red-500" />;
  }
};
```

### Icon Types
- **Status Icons**: Use status colors
- **Action Icons**: Use appropriate semantic colors
- **Neutral Icons**: Use `text-gray-500` or `text-status-gray`

---

## Button Standards

### Primary Buttons
- **Background**: `bg-status-blue` (Blue 500)
- **Text**: `text-white`
- **Hover**: `hover:bg-blue-600`

### Danger Buttons
- **Background**: `bg-status-red` (Red 700)
- **Text**: `text-white`
- **Hover**: `hover:bg-red-800`

### Secondary Buttons
- **Background**: `bg-white`
- **Text**: `text-gray-700`
- **Border**: `border border-gray-300`
- **Hover**: `hover:bg-gray-50`

---

## Implementation Checklist

### For Every New Page/Component:

#### ✅ Color System
- [ ] Use only status color classes (`text-status-*`, `bg-status-*`)
- [ ] No hardcoded colors (`text-red-600`, `bg-blue-500`, etc.)
- [ ] Primary Teal 700 (`#008383`) for brand elements

#### ✅ Avatars
- [ ] All avatars use `#008383` background
- [ ] Status dots use appropriate status colors
- [ ] Consistent sizing and positioning

#### ✅ Search Cards
- [ ] Active buttons use `bg-gray-300 text-black`
- [ ] Filter button always present
- [ ] View mode toggle when applicable

#### ✅ Pagination
- [ ] Current page uses `bg-gray-300 text-black`
- [ ] Previous/Next buttons with text
- [ ] Items per page selector
- [ ] Results counter

#### ✅ Tooltips
- [ ] Always `onClick` trigger
- [ ] Use `e.stopPropagation()`
- [ ] Direct hex colors for arrows
- [ ] Proper z-index (z-50)

#### ✅ Status Pills
- [ ] Text uses `text-status-*`
- [ ] Background uses `*-50` colors
- [ ] Icons match pill text color

#### ✅ Icons
- [ ] Status icons use status colors
- [ ] No hardcoded icon colors
- [ ] Consistent sizing (w-4 h-4 for most)

#### ✅ Buttons
- [ ] Primary: `bg-status-blue`
- [ ] Danger: `bg-status-red`
- [ ] Secondary: `bg-white border border-gray-300`

### Code Review Checklist
- [ ] No hardcoded colors found
- [ ] All status elements use status colors
- [ ] Tooltips have proper arrows
- [ ] Avatars use Teal 700
- [ ] Active states use gray-300
- [ ] Icons match their context colors

---

## Related Documents
- [Search Card Standards](./SEARCH_CARD_STANDARDS.md)
- [Pagination Standards](./PAGINATION_STANDARDS.md)
- [Tooltip Standards](./TOOLTIP_STANDARDS.md)
- [Security Implementation](./SECURITY_IMPLEMENTATION.md)

---

## Version History
- **v1.0** - Initial standards consolidation
- **v1.1** - Added status color system
- **v1.2** - Added avatar and tooltip standards
- **v1.3** - Added complete implementation checklist

---

*This document should be referenced for all new page and component development to ensure consistency across the RHEMO frontend application.*
