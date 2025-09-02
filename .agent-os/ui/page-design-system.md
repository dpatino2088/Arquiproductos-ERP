# RHEMO Page Design System Specification

## Overview
This document defines the complete design system and behavioral patterns for all RHEMO pages, based on the perfected Directory page implementation. Every new page MUST follow these exact specifications to maintain consistency and quality.

---

## 🏗️ **Page Architecture**

### **Layout Structure**
```
┌─────────────────────────────────────────────────────────────┐
│ NAVBAR (Fixed Top)                                         │
├─────────────────────────────────────────────────────────────┤
│ SIDEBAR │ SECONDARY NAV (Submodules) │                      │
│ (Fixed) ├─────────────────────────────┤ MAIN CONTENT       │
│         │                             │ (Scrollable)       │
│         │                             │                    │
│         │                             │                    │
└─────────────────────────────────────────────────────────────┘
```

### **Required Layout Components**
- **Main Container**: `<div className="p-6">` - Standard 24px padding
- **All content** must be contained within this padding structure

---

## 📝 **Page Header Pattern**

### **Header Structure** (MANDATORY - UPDATED)
```tsx
<div className="flex items-center justify-between mb-6">
  <div>
    <h1 className="text-xl font-semibold text-foreground mb-1">[Page Title]</h1>
    <p className="text-xs text-muted-foreground">[Descriptive subtitle]</p>
  </div>
  <div className="flex items-center gap-3">
    {/* Action buttons go here */}
  </div>
</div>
```

### **Typography Standards** (UPDATED)
- **Main Title**: `text-xl font-semibold text-foreground mb-1`
- **Subtitle**: `text-xs text-muted-foreground` (NO hardcoded colors)
- **Spacing**: `mb-6` after header block

### **Typography Classes** (Use these semantic classes)
- **Headings**: `text-title`, `text-heading` 
- **Body Text**: `text-small`, `text-body`
- **Muted Text**: `text-muted-foreground`
- **Secondary Text**: `text-secondary`

### **Action Buttons** (Right Side)
- **Secondary Actions**: `px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm`
- **Primary Actions**: `px-2 py-1 rounded text-white text-sm` with `backgroundColor: '#1FB6A1'`
- **Gap**: `gap-3` between buttons
- **Icon Size**: `width: '14px', height: '14px'`

---

## 🔍 **Search & Filter System**

### **Search Bar Card Structure**
```tsx
<div className="mb-4">
  <div className={`bg-white border border-gray-200 py-6 px-6 ${
    showFilters ? 'rounded-t-lg' : 'rounded-lg'
  }`}>
    {/* Search and controls */}
  </div>
  
  {/* Expandable filters */}
  {showFilters && (
    <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
      {/* Filter content */}
    </div>
  )}
</div>
```

### **Search Input Standards**
- **Container**: `flex-1 relative`
- **Icon**: `Search` component, `absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400`
- **Input**: `w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50`

### **Input Focus Ring Standards** (CRITICAL)
**ALL input elements MUST use the same focus ring for consistency:**
- **Standard Focus Ring**: `focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50`
- **Compact Focus Ring**: `focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50` (for smaller elements like pagination dropdowns)
- **NEVER use**: `focus:ring-blue-500` or any hardcoded color - always use primary color tokens

### **Filter Controls**
- **Filters Button**: `px-2 py-1 border border-gray-300 rounded text-sm`
- **View Toggle Buttons**: `p-1.5 transition-colors` with active/inactive states
- **Dropdown Selects**: `px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50`

---

## 📊 **Data Display Patterns**

### **Table View Standards**
- **Container**: `bg-white border border-gray-200 rounded-lg overflow-hidden mb-4`
- **Header**: `bg-gray-50 border-b border-gray-200`
- **Header Cells**: `text-left py-3 px-6 font-medium text-gray-900 text-xs` (first column), `px-4` for others
- **Body Cells**: `py-4 px-6` (first column), `px-4` for others
- **Row Hover**: `hover:bg-gray-50 transition-colors`
- **Text Sizes**: `text-sm` for main content, `text-xs` for secondary content

### **Grid View Standards**
- **Container**: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4`
- **Card**: `bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6`
- **Avatar Size**: `w-12 h-12` for grid, `w-8 h-8` for table
- **Status Indicators**: 3px circles with 2px white border

### **Card Styling Standards** (CRITICAL - Consistent across all pages)
- **Background**: `bg-white` (NOT `bg-card`)
- **Border**: `border border-gray-200` (NOT `border-border`)
- **Border Radius**: `rounded-lg`
- **Hover Effects**: `hover:shadow-lg transition-all duration-200 hover:border-primary/20`
- **Hover Background**: `hover:bg-gray-50` (for list items and interactive elements)
- **Padding**: `p-6` for cards, `p-3` for list items

### **Progress Bar Standards**
- **Background**: `bg-gray-200` (NOT `bg-muted`)
- **Fill**: Use appropriate status colors (`bg-status-green`, etc.)

---

## 🎨 **Color System (MANDATORY)**

### **Status Colors** (From approved tokens - UPDATED)
```css
--status-green: #15803d;    /* Success / Active - Green 700 (UPDATED) */
--status-red: #D32F2F;      /* Error / Critical */
--status-blue: #1976D2;     /* Info / Neutral */
--status-amber: #F9A825;    /* Warning / Pending */
--neutral-gray: #9E9E9E;    /* Disabled / Inactive */
--highlight-bg: #E3F2FD;    /* Hover states, highlighted rows */
```

### **Status Color Usage Rules** (CRITICAL)
- **Active/Success**: Use Green 700 (#15803d) - NOT teal (teal is reserved for primary brand)
- **Error/Critical/Delete**: Use Red (#D32F2F) 
- **Info/Neutral Actions**: Use Blue (#1976D2)
- **Warning/Pending**: Use Amber (#F9A825)
- **Disabled/Inactive**: Use Neutral Gray (#9E9E9E)

### **Light Background Variants** (10% opacity for badges)
```css
.bg-status-green-light { background-color: rgba(21, 128, 61, 0.1); }
.bg-status-red-light { background-color: rgba(211, 47, 47, 0.1); }
.bg-status-blue-light { background-color: rgba(25, 118, 210, 0.1); }
.bg-status-orange-light { background-color: rgba(249, 168, 37, 0.1); }
```

### **Primary Brand Color** (Teal - User Customizable)
```css
--brand-primary: 174 78% 26%;  /* Primary teal #0f766e - HSL format for Tailwind */
--teal-700: #0f766e;           /* Primary brand color in hex */
```

### **Focus Ring System** (CRITICAL - ALL inputs must use primary color)
```css
--ring: var(--brand-primary);           /* Focus ring - primary teal */
--focus-ring: var(--brand-primary);     /* Focus indicator - primary teal */
```

**Standard Focus Ring Classes:**
- `focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50`
- **NEVER use blue focus rings** - always use primary teal

### **Status Badge Implementation** (UPDATED)
```tsx
// Active status example - UPDATED to use Green 700
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green">
  Active
</span>

// Suspended status
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-red-light text-status-red">
  Suspended
</span>

// Onboarding status  
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-blue-light text-status-blue">
  Onboarding
</span>

// On Leave status
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-orange-light text-status-orange">
  On Leave
</span>
```

### **Status Indicator Circles** (UPDATED)
```tsx
<div style={{
  backgroundColor: 
    status === 'Active' ? '#15803d' :      // Green 700 - UPDATED
    status === 'On Leave' ? '#F9A825' :
    status === 'Onboarding' ? '#1976D2' :
    status === 'Suspended' ? '#D32F2F' :
    '#9E9E9E'
}}>
```

---

## 📄 **Pagination System**

### **Pagination Card Structure**
```tsx
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-3">
      <span className="text-xs text-gray-600">Show:</span>
      <select className="border border-gray-200 rounded px-2 py-1 text-xs">
        {/* Options */}
      </select>
      <span className="text-xs text-gray-600">Showing X-Y of Z</span>
    </div>
    
    {totalPages > 1 && (
      <div className="flex items-center gap-3">
        {/* Navigation buttons */}
      </div>
    )}
  </div>
</div>
```

### **Pagination Button Standards**
- **Previous/Next**: `px-2 py-1 border rounded text-xs transition-colors`
- **Page Numbers**: `w-6 h-6 text-xs rounded transition-colors flex items-center justify-center`
- **Active Page**: `text-white` with `backgroundColor: '#1FB6A1'`
- **Spacing**: `gap-3` between Previous, numbers, Next; `gap-1` between number buttons

---

## 🧭 **Navigation Systems**

### **Submodule Navigation** (Secondary Nav)
```tsx
const { registerSubmodules } = useSubmoduleNav();

useEffect(() => {
  registerSubmodules('[Section Title]', [
    { id: 'tab1', label: 'Tab 1', href: '/path1', icon: IconComponent },
    { id: 'tab2', label: 'Tab 2', href: '/path2', icon: IconComponent }
  ]);
}, [registerSubmodules]);
```

### **Submodule Tab Styling** (UPDATED)
- **Font**: `fontSize: '12px'`
- **Font Weight**: `font-semibold` (active), `font-normal` (inactive)
- **Padding**: `padding: '0 48px'`
- **Colors**: Active `var(--teal-brand-hex)`, Inactive `var(--graphite-black-hex)`
- **Background**: Active `bg-white`, Inactive hover `hover:bg-white/50`
- **Bottom Border**: Active tabs get `borderBottom: '2px solid var(--teal-700)'` for WCAG compliance

### **Sidebar Navigation Styling** (UPDATED - Microsoft Teams Pattern)
- **Selected State**: Square background with left border indicator (NO rounded corners)
- **Full Width**: Background extends full sidebar width (no container padding)
- **Left Border**: `3px solid` using primary color
  - **Management View**: `var(--teal-600-hex)` (better contrast on dark sidebar)
  - **Employee View**: `var(--teal-brand-hex)` (Teal 700)
- **Background Colors**:
  - **Selected**: `#333333` (management), `#F5F7FA` (employee)
  - **Hover**: Same as selected background
- **Icon Positioning**: Icons positioned exactly 17px from left border (3px border + 14px padding)
- **Button Heights**: 
  - **Standard Navigation**: `minHeight: '36px'`
  - **Home Button**: `minHeight: '40px'` (matches secondary navbar height)
- **Padding**: `padding: '12px 16px 12px 14px'` (ensures 17px icon positioning)
- **Border Implementation**: `borderLeft: '3px solid transparent'` for inactive items
- **WCAG Compliance**: 3:1+ contrast ratio for left border against sidebar background
- **Accessibility**: Uses `aria-current="page"` for active navigation items

### **Logo Positioning** (NEW)
- **Logo Size**: 27px x 27px (larger than navigation icons for brand prominence)
- **Logo Position**: 13px from left border
- **Brand Text**: "RHEMO" positioned at 52px from left border
- **Typography**: Bold "RH" (font-weight: 700), Light "EMO" (font-weight: 200)
- **Color Adaptation**: Uses Teal 600 in management view, Teal 700 in employee view

### **Utility Button Styling** (NEW - Collapse/Expand)
- **No Selected State**: Utility buttons never show as "selected"
- **Hover Only**: Square hover background matching navigation items
- **Same Positioning**: Icons aligned at 17px from left border
- **Transparent Border**: `3px solid transparent` for consistent structure
- **Background**: Hover shows same colors as navigation items

### **Selected Tab Implementation** (WCAG 2.2 AA Compliant)
```tsx
<button
  className={`transition-colors flex items-center justify-start border-r ${
    tab.isActive
      ? 'bg-white font-semibold'
      : 'hover:bg-white/50 font-normal'
  }`}
  style={{
    fontSize: '12px',
    padding: '0 48px',
    height: '100%',
    color: tab.isActive ? 'var(--teal-brand-hex)' : 'var(--graphite-black-hex)',
    borderColor: '#E5E7EB',
    borderBottom: tab.isActive ? '2px solid var(--teal-700)' : 'none'
  }}
  role="tab"
  aria-selected={tab.isActive}
>
  {tab.label}
</button>
```

### **Breadcrumb Standards**
- **Container**: `nav` with `paddingLeft: '48px'`
- **Alignment**: Must align with main content headers

---

## 🎛️ **Interactive Elements**

### **Sorting Controls**
- **Table Headers**: Clickable with `SortAsc`/`SortDesc` icons
- **Filter Section**: Sort buttons with icons
- **Icon Size**: `w-3 h-3` for sort icons

### **View Mode Toggle**
- **Container**: `flex border border-gray-200 rounded overflow-hidden`
- **Buttons**: `p-1.5 transition-colors`
- **Icons**: `List` and `Grid3X3` from lucide-react
- **Active State**: `bg-gray-100 text-gray-900`

### **Empty States**
```tsx
<div className="text-center py-8">
  <IconComponent className="w-8 h-8 text-gray-400 mx-auto mb-3" />
  <h3 className="text-sm font-semibold text-gray-900 mb-1">[Title]</h3>
  <p className="text-xs text-gray-600">[Description]</p>
</div>
```

---

## 📱 **Responsive Behavior**

### **Breakpoints**
- **Grid Columns**: `grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`
- **Filter Layout**: `grid-cols-1 md:grid-cols-2 lg:grid-cols-4`

### **Mobile Adaptations**
- Cards stack vertically on mobile
- Pagination simplifies on small screens
- Search bar remains full-width

---

## 🔧 **State Management Patterns**

### **Required State Variables**
```tsx
const [searchTerm, setSearchTerm] = useState('');
const [showFilters, setShowFilters] = useState(false);
const [currentPage, setCurrentPage] = useState(1);
const [itemsPerPage, setItemsPerPage] = useState(10);
const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
const [sortBy, setSortBy] = useState('defaultField');
const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
```

### **Filtering Logic**
- Use `useMemo` for filtered data
- Reset to page 1 when search/filters change
- Implement client-side sorting and pagination

---

## ♿ **Accessibility Requirements**

### **WCAG 2.2 AA Compliance** ✅ (UPDATED)
- **Text Contrast**: All text elements meet 4.5:1 contrast ratio minimum
- **Non-text Elements**: UI components and borders meet 3:1 contrast ratio minimum
- **Status Colors**: Green 700 (#15803d) provides 4.5:1+ contrast for text
- **Focus Rings**: Primary teal provides excellent contrast against all backgrounds
- **Selected Tab Borders**: Teal 700 (#0f766e) provides 4.6:1 contrast against white, 4.8:1 against gray
- **Interactive Elements**: Proper ARIA labels on all interactive components
- **Keyboard Navigation**: Full keyboard support with visible focus indicators
- **Screen Reader**: Compatible with assistive technologies

### **WCAG Contrast Requirements** (CRITICAL)
- **Normal Text**: Minimum 4.5:1 contrast ratio
- **Large Text**: Minimum 3:1 contrast ratio
- **Non-text Elements**: Minimum 3:1 contrast ratio (borders, UI components)
- **Focus Indicators**: Must be visible and meet 3:1 contrast against adjacent colors

### **Accessibility Testing**
- **Automated**: axe-core WCAG 2.1 AA compliance testing
- **Manual**: Keyboard navigation and screen reader testing
- **Color Contrast**: Verified 4.5:1+ ratios across all text elements

### **Required ARIA Attributes**
- `role="tab"` for submodule navigation
- `aria-selected` for active tabs
- `aria-label` for icon-only buttons
- `aria-current="page"` for active navigation items

---

## 🧪 **Testing Requirements**

### **Accessibility Testing**
- Must pass axe-core WCAG 2.1 AA tests
- Color contrast validation
- Keyboard navigation testing

### **Performance Standards**
- Bundle size within performance budgets
- Lazy loading for large datasets
- Memoization for expensive calculations

---

## 🚫 **Critical Rules - NO EXCEPTIONS**

### **No Hardcoded Styling Values** (MANDATORY)
- **NO hardcoded colors**: Use design tokens (`text-muted-foreground`, `text-status-green`, etc.)
- **NO hardcoded CSS values**: Use Tailwind classes (`bg-white`, `border-gray-200`, etc.)
- **NO style objects**: Except for dynamic values (status indicators, calculated positions)
- **ALL inputs must use consistent focus rings**: Primary teal color system

### **Consistency Requirements**
- **Card styling**: Always `bg-white border border-gray-200 rounded-lg`
- **Hover states**: Always `hover:bg-gray-50` for list items
- **Status colors**: Green for active/success, NOT teal
- **Focus rings**: Always primary teal, NEVER blue
- **Typography**: Always use semantic classes, NO hardcoded colors

---

## 📋 **Implementation Checklist**

### **Page Setup**
- [ ] Import required hooks (`useSubmoduleNav`, etc.)
- [ ] Set up state management variables
- [ ] Register submodule navigation
- [ ] Implement proper TypeScript interfaces

### **UI Components**
- [ ] Page header with title and actions
- [ ] Search and filter system
- [ ] Data display (table/grid views)
- [ ] Pagination component
- [ ] Empty states

### **Functionality**
- [ ] Search implementation
- [ ] Filter functionality
- [ ] Sorting capabilities
- [ ] View mode switching
- [ ] Pagination logic

### **Quality Assurance**
- [ ] Color contrast validation (4.5:1 text, 3:1 non-text)
- [ ] Accessibility testing (WCAG 2.2 AA)
- [ ] Focus ring consistency (primary teal only)
- [ ] Status color validation (green for active, not teal)
- [ ] No hardcoded values verification
- [ ] Card styling consistency
- [ ] Responsive design verification
- [ ] Performance optimization

---

## 🎯 **Key Success Metrics**

1. **Visual Consistency**: Identical styling across all pages
2. **Behavioral Consistency**: Same interaction patterns
3. **Performance**: Sub-2s load times, smooth interactions
4. **Accessibility**: 100% WCAG AA compliance
5. **Maintainability**: Reusable patterns and components

---

## 💡 **Usage Guidelines**

1. **Always start** with this specification when creating new pages
2. **Copy patterns exactly** - don't deviate from established designs
3. **Test thoroughly** against all requirements before considering complete
4. **Update this document** if you discover better patterns that should be standardized

This specification ensures every RHEMO page delivers the same high-quality, consistent user experience that users expect from a professional enterprise application.
