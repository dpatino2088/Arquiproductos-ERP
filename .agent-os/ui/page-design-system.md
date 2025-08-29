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

### **Header Structure** (MANDATORY)
```tsx
<div className="flex items-center justify-between mb-6">
  <div>
    <h1 className="text-xl font-semibold text-foreground mb-1">[Page Title]</h1>
    <p className="text-xs" style={{ color: '#6B7280' }}>[Descriptive subtitle]</p>
  </div>
  <div className="flex items-center gap-3">
    {/* Action buttons go here */}
  </div>
</div>
```

### **Typography Standards**
- **Main Title**: `text-xl font-semibold text-foreground mb-1`
- **Subtitle**: `text-xs` with `color: '#6B7280'` (accessible gray)
- **Spacing**: `mb-6` after header block

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

---

## 🎨 **Color System (MANDATORY)**

### **Status Colors** (From approved tokens)
```css
--status-green: #1FB6A1;    /* Success / Active */
--status-red: #D32F2F;      /* Error / Critical */
--status-blue: #1976D2;     /* Info / Neutral */
--status-amber: #F9A825;    /* Warning / Pending */
--neutral-gray: #9E9E9E;    /* Disabled / Inactive */
```

### **Accessible Variants** (WCAG AA Compliant - For text on light backgrounds)
```css
--status-green-accessible: #0D5B52;  /* WCAG AA compliant green */
--status-red-accessible: #991B1B;    /* WCAG AA compliant red */
--status-blue-accessible: #1E3A8A;   /* WCAG AA compliant blue */
--status-amber-accessible: #B45309;  /* WCAG AA compliant amber */
```

### **Primary Color** (User Customizable)
```css
--brand-primary: 174 70% 30%;  /* WCAG AA compliant teal - HSL format */
```

### **Status Badge Implementation**
```tsx
// Active status example
<span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green-accessible">
  Active
</span>
```

### **Status Indicator Circles**
```tsx
<div style={{
  backgroundColor: 
    status === 'Active' ? '#1FB6A1' :
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

### **Submodule Tab Styling**
- **Font**: `fontSize: '12px', font-normal`
- **Padding**: `padding: '0 48px'` (first tab), `padding: '0 48px'` (others)
- **Colors**: Active `#14B8A6`, Inactive `#222222`
- **Alignment**: `justify-start` (left-aligned)

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

### **WCAG AA Compliance** ✅
- **Color Contrast**: All text elements meet 4.5:1 contrast ratio minimum
- **Status Elements**: Use accessible variants (`-accessible` suffix) for text
- **Primary Colors**: Darkened to HSL(174 70% 30%) for compliance
- **Interactive Elements**: Proper ARIA labels on all interactive components
- **Keyboard Navigation**: Full keyboard support with visible focus indicators
- **Screen Reader**: Compatible with assistive technologies

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
- [ ] Color contrast validation
- [ ] Accessibility testing
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
