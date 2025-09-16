# RHEMO Frontend - Complete Design System Standards

## Overview
This document consolidates all design system standards for the RHEMO frontend application, ensuring consistency across all pages and components.

## Table of Contents
1. [Color System](#color-system)
2. [Status Colors](#status-colors)
3. [Avatar Standards](#avatar-standards)
4. [Search Card Standards](#search-card-standards)
5. [Search Bar Standard](#search-bar-standard)
6. [Multi-Select Filter Standards](#multi-select-filter-standards)
7. [Pagination Standards](#pagination-standards)
8. [Tooltip Standards](#tooltip-standards)
9. [Status Pills Standards](#status-pills-standards)
10. [Icon Standards](#icon-standards)
11. [Button Standards](#button-standards)
12. [Input Field Standards](#input-field-standards)
13. [Implementation Checklist](#implementation-checklist)

## Related Documentation
- [Button Standards](./BUTTON_STANDARDS.md) - Complete button design system
- [Input Field Standards](./INPUT_STANDARDS.md) - Input fields, dropdowns, and form elements
- [Search Card Standards](./SEARCH_CARD_STANDARDS.md) - Search and filter components
- [Pagination Standards](./PAGINATION_STANDARDS.md) - Pagination components
- [Tooltip Standards](./TOOLTIP_STANDARDS.md) - Tooltip components

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

## Search Bar Standard

### Overview
The standard search bar pattern provides a consistent layout for search inputs, clear filters functionality, and action buttons across all pages.

### Standard Structure
```typescript
{/* Search Bar Container */}
<div className="flex items-center gap-4">
  {/* Search Input */}
  <div className="flex-1 relative">
    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
    <input
      type="text"
      placeholder="Search employees, roles, or departments..."
      value={searchTerm}
      onChange={(e) => setSearchTerm(e.target.value)}
      className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
      aria-label="Search records"
    />
  </div>
  
  {/* Action Buttons */}
  <div className="flex items-center gap-2">
    {/* Clear Filters Button - Only show when filters are active */}
    {(selectedStatus.length > 0 || selectedDepartment.length > 0 || selectedLocation.length > 0) && (
      <button
        onClick={clearAllFilters}
        className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm bg-white text-gray-700 hover:bg-gray-50"
        title="Clear all active filters"
      >
        <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
        Clear filters
      </button>
    )}

    {/* Filters Button */}
    <button
      onClick={() => setShowFilters(!showFilters)}
      className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
        showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
      }`}
    >
      <Filter className="w-4 h-4" />
      Filters
    </button>
    
    {/* Additional Action Buttons (Date, Export, etc.) */}
  </div>
</div>
```

### Visual Standards
- **Container**: `flex items-center gap-4`
- **Search Input**: `flex-1` with search icon and proper padding
- **Action Buttons**: `flex items-center gap-2`
- **Clear Filters Button**: 
  - **Background**: `bg-white`
  - **Text Color**: `text-gray-700`
  - **Border**: `border-gray-300`
  - **Hover**: `hover:bg-gray-50`
  - **Icon**: X icon (`w-3 h-3`)
  - **Position**: **BEFORE** the Filters button
  - **Conditional Display**: Only shows when any filter arrays have length > 0

### Required Elements
- [ ] Search input with search icon
- [ ] Clear filters button (conditional)
- [ ] Filters button
- [ ] Additional action buttons as needed
- [ ] Proper spacing and alignment
- [ ] Consistent styling across all pages

**📋 Complete Documentation**: See [SEARCH_CARD_STANDARDS.md](./SEARCH_CARD_STANDARDS.md) for the complete search bar implementation guide.

---

## Multi-Select Filter Standards

### Overview
The new standard for multi-select filters with integrated search functionality provides superior user experience for filtering large datasets with multiple criteria.

### Key Features
- **Multi-Select**: Choose multiple options simultaneously
- **Integrated Search**: Search within dropdown options
- **Consistent Styling**: Matches standard form element heights
- **Responsive Design**: Adapts to all screen sizes
- **Accessibility**: Full keyboard navigation support

### Implementation Pattern
```typescript
// State Management
const [selectedItems, setSelectedItems] = useState<string[]>([]);
const [showDropdown, setShowDropdown] = useState(false);
const [searchTerm, setSearchTerm] = useState('');

// Toggle Function
const handleToggle = (item: string) => {
  setSelectedItems(prev => 
    prev.includes(item) 
      ? prev.filter(i => i !== item)  // Remove
      : [...prev, item]               // Add
  );
};

// Filtering Function
const getFilteredOptions = () => {
  if (!searchTerm) return allOptions;
  return allOptions.filter(option => 
    option.toLowerCase().includes(searchTerm.toLowerCase())
  );
};
```

### Visual Standards
- **Height**: `min-h-[32px]` (matches standard inputs)
- **Padding**: `px-3 py-1` (consistent spacing)
- **Border**: `border border-gray-200 rounded`
- **Search Input**: `text-xs` with `px-2 py-1`
- **Checkboxes**: `w-4 h-4` with `gap-2` spacing

### Required Elements
- [ ] Multi-select dropdown with search
- [ ] Checkbox selection interface
- [ ] Search input within dropdown
- [ ] "No items found" state
- [ ] Click outside to close
- [ ] Clear all filters functionality

**📋 Complete Documentation**: See [SEARCH_CARD_STANDARDS.md](./SEARCH_CARD_STANDARDS.md) for the complete multi-select filter implementation guide.

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

**📋 Complete Button Standards**: See [BUTTON_STANDARDS.md](./BUTTON_STANDARDS.md) for the complete button design system.

### Quick Reference
- **Primary Actions**: `px-2 py-1` with `var(--teal-brand-hex)` background
- **Secondary Actions**: `px-2 py-1` with `bg-gray-200 text-gray-700`
- **Icon Buttons**: `p-1` with `text-gray-400 hover:text-gray-600`
- **Icon Size**: `14px x 14px` for primary buttons, `16px x 16px` for icon-only
- **Font Size**: `text-sm` for primary actions, `text-xs` for small actions

---

## Input Field Standards

### Standard Height
All input fields, dropdowns, and buttons must use the same height for perfect alignment:

```css
/* Standard height for all form elements */
.form-element-standard {
  @apply py-1 px-3 text-sm;
  /* Results in approximately 32px total height */
}
```

### Input Field Specifications
```tsx
<input
  type="text"
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
  placeholder="Enter text..."
/>
```

### Dropdown Specifications
```tsx
<select className="w-48 px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
  <option value="">Select option...</option>
</select>
```

### Button Specifications
```tsx
<button className="px-2 py-1 bg-primary text-white rounded text-sm">
  Button Text
</button>
```

### Key Requirements
- **Height Consistency**: All form elements use `py-1` for identical heights
- **Focus States**: `focus:ring-2 focus:ring-primary focus:border-transparent`
- **Border Radius**: `rounded-md` for all elements
- **Text Size**: `text-sm` for consistency
- **Alignment**: Perfect vertical alignment across all elements

### Implementation Examples
- **Search Cards**: Input + dropdown + button alignment
- **Comment Forms**: Input + dropdowns + send button alignment
- **Filter Forms**: Multiple inputs and dropdowns in perfect alignment

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

#### ✅ Search Bar Standard
- [ ] Search input with search icon
- [ ] Clear filters button (conditional display)
- [ ] Filters button positioned after clear filters
- [ ] Additional action buttons as needed
- [ ] Proper spacing and alignment (`gap-4` for container, `gap-2` for buttons)
- [ ] Consistent styling across all pages

#### ✅ Multi-Select Filters
- [ ] Multi-select dropdown with search functionality
- [ ] Checkbox selection interface
- [ ] Search input within dropdown
- [ ] "No items found" state
- [ ] Click outside to close behavior
- [ ] Clear all filters functionality
- [ ] Consistent height with form elements (`min-h-[32px]`)
- [ ] Proper state management with arrays

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

#### ✅ Input Fields
- [ ] Standard height: `py-1` (matches button height)
- [ ] Consistent styling: `px-3 py-1 border border-gray-300 rounded-md text-sm`
- [ ] Focus states: `focus:ring-2 focus:ring-primary focus:border-transparent`
- [ ] Dropdowns match input height
- [ ] All form elements aligned perfectly

### Code Review Checklist
- [ ] No hardcoded colors found
- [ ] All status elements use status colors
- [ ] Tooltips have proper arrows
- [ ] Avatars use Teal 700
- [ ] Active states use gray-300
- [ ] Icons match their context colors
- [ ] Search bar follows standard structure
- [ ] Clear filters button positioned correctly
- [ ] Multi-select filters use array-based state
- [ ] Search functionality within dropdowns
- [ ] Proper click-outside behavior
- [ ] Consistent filter styling

---

## Related Documents
- [Search Card Standards](./SEARCH_CARD_STANDARDS.md) - **Includes new Multi-Select Filter Standards**
- [Pagination Standards](./PAGINATION_STANDARDS.md)
- [Tooltip Standards](./TOOLTIP_STANDARDS.md)
- [Security Implementation](./SECURITY_IMPLEMENTATION.md)

---

## Version History
- **v1.0** - Initial standards consolidation
- **v1.1** - Added status color system
- **v1.2** - Added avatar and tooltip standards
- **v1.3** - Added complete implementation checklist
- **v1.4** - Added Multi-Select Filter Standards with integrated search functionality
- **v1.5** - Added Search Bar Standard with clear filters button and consistent layout

---

*This document should be referenced for all new page and component development to ensure consistency across the RHEMO frontend application.*
