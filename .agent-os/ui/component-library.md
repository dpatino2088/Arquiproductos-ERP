# RHEMO Component Library Reference

## Overview
This document catalogs all reusable components and patterns from the perfected Directory page implementation. Use these exact components to ensure consistency across all pages.

---

## 🎯 **Input Focus Standards** (CRITICAL)

### **Universal Focus Ring Pattern**
**ALL input elements MUST use these exact focus styles for consistency:**

```css
/* Standard Focus Ring (for most inputs) */
focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50

/* Compact Focus Ring (for smaller elements like pagination dropdowns) */
focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50
```

### **Input Elements That MUST Use Focus Ring:**
- Search inputs
- Text inputs
- Select dropdowns
- Textarea elements
- Number inputs
- Date inputs

### **❌ NEVER Use These:**
```css
focus:ring-blue-500        /* Hardcoded blue */
focus:ring-red-500         /* Hardcoded red */
focus:border-transparent   /* Inconsistent border behavior */
```

### **✅ Always Use Primary Color Tokens:**
```css
focus:ring-primary/20      /* 20% opacity primary for ring */
focus:border-primary/50    /* 50% opacity primary for border */
```

### **🎯 Accessibility Color Rules** (CRITICAL)
```tsx
// ✅ CORRECT: Use accessible variants for text on light backgrounds
<span className="text-status-green-accessible bg-status-green-light">Active</span>
<div className="text-status-red-accessible">Error message</div>

// ❌ WRONG: Using original colors for text (poor contrast)
<span className="text-status-green bg-status-green-light">Active</span>
<div className="text-red-600">Error message</div>

// ✅ CORRECT: Original colors for backgrounds, borders, icons
<div className="border-status-green bg-status-green text-white">Button</div>
<StatusIcon className="text-status-blue" />
```

---

## 🧭 **Navigation Components**

### **Submodule Navigation Hook**
```tsx
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';

// In your component
const { registerSubmodules } = useSubmoduleNav();

useEffect(() => {
  registerSubmodules('Section Title', [
    { id: 'unique-id', label: 'Display Name', href: '/full/path', icon: IconComponent }
  ]);
}, [registerSubmodules]);
```

**Styling Requirements:**
- Font: `fontSize: '12px', font-normal`
- Padding: `padding: '0 48px'` for all tabs
- Colors: Active `#14B8A6`, Inactive `#222222`
- Alignment: `justify-start`

---

## 🔍 **Search & Filter Components**

### **Search Bar with Icon**
```tsx
<div className="flex-1 relative">
  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
  <input
    type="text"
    placeholder="Search..."
    value={searchTerm}
    onChange={(e) => setSearchTerm(e.target.value)}
    className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
  />
</div>
```

### **Filter Toggle Button**
```tsx
<button
  onClick={() => setShowFilters(!showFilters)}
  className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
    showFilters ? 'bg-gray-100 text-gray-900' : 'bg-white text-gray-700 hover:bg-gray-50'
  }`}
>
  <Filter style={{ width: '14px', height: '14px' }} />
  Filters
</button>
```

### **View Mode Toggle**
```tsx
<div className="flex border border-gray-200 rounded overflow-hidden">
  <button
    onClick={() => setViewMode('table')}
    className={`p-1.5 transition-colors ${
      viewMode === 'table'
        ? 'bg-gray-100 text-gray-900'
        : 'bg-white text-gray-600 hover:bg-gray-50'
    }`}
  >
    <List className="w-4 h-4" />
  </button>
  <button
    onClick={() => setViewMode('grid')}
    className={`p-1.5 transition-colors ${
      viewMode === 'grid'
        ? 'bg-gray-100 text-gray-900'
        : 'bg-white text-gray-600 hover:bg-gray-50'
    }`}
  >
    <Grid3X3 className="w-4 h-4" />
  </button>
</div>
```

### **Filter Dropdown**
```tsx
<select 
  value={selectedValue}
  onChange={(e) => setSelectedValue(e.target.value)}
  className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
>
  <option value="">All Options</option>
  <option value="option1">Option 1</option>
  <option value="option2">Option 2</option>
</select>
```

---

## 🎨 **Status & Badge Components**

### **Status Badge Function**
```tsx
const getStatusBadge = (status: string) => {
  switch (status) {
    case 'Active':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green-accessible">
          Active
        </span>
      );
    case 'Suspended':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-red-light text-status-red-accessible">
          Suspended
        </span>
      );
    case 'Onboarding':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-blue-light text-status-blue-accessible">
          Onboarding
        </span>
      );
    case 'On Leave':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-amber-light text-status-amber-accessible">
          On Leave
        </span>
      );
    default:
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: 'rgba(158, 158, 158, 0.1)', color: '#9E9E9E' }}>
          {status}
        </span>
      );
  }
};
```

### **Status Indicator Circle**
```tsx
<div 
  className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white"
  style={{
    backgroundColor: 
      status === 'Active' ? '#1FB6A1' :
      status === 'On Leave' ? '#F9A825' :
      status === 'Onboarding' ? '#1976D2' :
      status === 'Suspended' ? '#D32F2F' :
      '#9E9E9E'
  }}>
</div>
```

---

## 👤 **Avatar Components**

### **Avatar with Initials Fallback**
```tsx
{avatar ? (
  <img 
    src={avatar} 
    alt={`${firstName} ${lastName}`}
    className="w-8 h-8 rounded-full object-cover"
  />
) : (
  <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" style={{ backgroundColor: '#1FB6A1' }}>
    {getInitials(firstName, lastName)}
  </div>
)}

// Helper function
const getInitials = (firstName: string, lastName: string) => {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`;
};
```

### **Avatar with Status Indicator**
```tsx
<div className="relative">
  {/* Avatar component here */}
  <div 
    className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white"
    style={{
      backgroundColor: 
        status === 'Active' ? '#1FB6A1' :
        status === 'On Leave' ? '#F9A825' :
        status === 'Onboarding' ? '#1976D2' :
        status === 'Suspended' ? '#D32F2F' :
        '#9E9E9E'
    }}>
  </div>
</div>
```

---

## 📊 **Table Components**

### **Sortable Table Header**
```tsx
<th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
  <button
    onClick={() => handleSort('fieldName')}
    className="flex items-center gap-1 hover:text-gray-700"
  >
    Column Name
    {sortBy === 'fieldName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
  </button>
</th>
```

### **Table Row with Hover**
```tsx
<tr className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
  <td className="py-4 px-6">
    {/* First column content */}
  </td>
  <td className="py-4 px-4 text-gray-900 text-sm">
    {/* Other column content */}
  </td>
</tr>
```

### **Action Buttons in Table**
```tsx
<td className="py-4 px-4">
  <div className="flex items-center gap-2">
    <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
      <Edit className="w-4 h-4" />
    </button>
    <button className="p-1 text-gray-400 hover:text-red-600 transition-colors">
      <Trash2 className="w-4 h-4" />
    </button>
  </div>
</td>
```

---

## 🃏 **Card Components**

### **Grid Card Layout**
```tsx
<div className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6">
  {/* Card content */}
</div>
```

### **Card Header with Avatar**
```tsx
<div className="flex items-start gap-3 mb-4">
  <div className="relative">
    {/* Avatar with status indicator */}
  </div>
  <div className="flex-1 min-w-0">
    <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
      {name}
    </h3>
    <p className="text-xs text-gray-600 truncate">{title}</p>
    <div className="mt-1">
      {getStatusBadge(status)}
    </div>
  </div>
  <button className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary">
    <MoreHorizontal className="w-4 h-4" />
  </button>
</div>
```

---

## 📄 **Pagination Components**

### **Items Per Page Selector**
```tsx
<div className="flex items-center gap-3">
  <span className="text-xs text-gray-600">Show:</span>
  <select
    value={itemsPerPage}
    onChange={(e) => {
      setItemsPerPage(Number(e.target.value));
      setCurrentPage(1);
    }}
    className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
  >
    <option value={10}>10</option>
    <option value={25}>25</option>
    <option value={50}>50</option>
    <option value={100}>100</option>
  </select>
  <span className="text-xs text-gray-600">
    Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, totalItems)} of {totalItems}
  </span>
</div>
```

### **Page Navigation Buttons**
```tsx
<button
  onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
  disabled={currentPage === 1}
  className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
    currentPage === 1
      ? 'border-gray-200 text-gray-400 cursor-not-allowed'
      : 'border-gray-300 text-gray-700 hover:bg-gray-50'
  }`}
>
  <ChevronLeft className="w-3 h-3" />
  Previous
</button>
```

### **Page Number Button**
```tsx
<button
  onClick={() => setCurrentPage(pageNum)}
  className={`w-6 h-6 text-xs rounded transition-colors flex items-center justify-center ${
    currentPage === pageNum
      ? 'text-white'
      : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
  }`}
  style={currentPage === pageNum ? { backgroundColor: '#1FB6A1' } : {}}
>
  {pageNum}
</button>
```

---

## 🎯 **Action Button Components**

### **Primary Action Button**
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" style={{ backgroundColor: '#1FB6A1' }}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Item
</button>
```

### **Secondary Action Button**
```tsx
<button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
  <Upload style={{ width: '14px', height: '14px' }} />
  Import
</button>
```

---

## 🚫 **Empty State Components**

### **No Results Found**
```tsx
{filteredData.length === 0 && (
  <div className="text-center py-8">
    <Users className="w-8 h-8 text-gray-400 mx-auto mb-3" />
    <h3 className="text-sm font-semibold text-gray-900 mb-1">No items found</h3>
    <p className="text-xs text-gray-600">Try adjusting your search criteria.</p>
  </div>
)}
```

---

## 🔧 **Utility Functions**

### **Sorting Handler**
```tsx
const handleSort = (field: string) => {
  if (sortBy === field) {
    setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
  } else {
    setSortBy(field);
    setSortOrder('asc');
  }
};
```

### **Clear All Filters**
```tsx
const clearAllFilters = () => {
  setSelectedDepartment('');
  setSelectedStatus('');
  setSelectedEmploymentType('');
  setSelectedLocation('');
  setSearchTerm('');
};
```

### **Filtered Data with useMemo**
```tsx
const filteredData = useMemo(() => {
  const filtered = data.filter(item => {
    // Search filter
    const searchLower = searchTerm.toLowerCase();
    const matchesSearch = !searchTerm || (
      item.name.toLowerCase().includes(searchLower) ||
      item.email.toLowerCase().includes(searchLower)
      // Add other searchable fields
    );

    // Other filters
    const matchesFilter1 = !selectedFilter1 || item.field1 === selectedFilter1;
    const matchesFilter2 = !selectedFilter2 || item.field2 === selectedFilter2;

    return matchesSearch && matchesFilter1 && matchesFilter2;
  });

  // Apply sorting
  return filtered.sort((a, b) => {
    let aValue: string | Date;
    let bValue: string | Date;

    switch (sortBy) {
      case 'name':
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
        break;
      case 'date':
        aValue = new Date(a.date);
        bValue = new Date(b.date);
        break;
      default:
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
    }

    if (sortBy === 'date') {
      const dateA = aValue as Date;
      const dateB = bValue as Date;
      return sortOrder === 'asc' ? dateA.getTime() - dateB.getTime() : dateB.getTime() - dateA.getTime();
    } else {
      const strA = aValue as string;
      const strB = bValue as string;
      if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
      if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    }
  });
}, [data, searchTerm, sortBy, sortOrder, selectedFilter1, selectedFilter2]);
```

---

## 📏 **Spacing Standards**

### **Container Padding**
- Page container: `p-6` (24px all sides)
- Card padding: `p-6` (24px all sides)
- Search bar: `py-6 px-6` (24px vertical, 24px horizontal)

### **Gap Standards**
- Action button groups: `gap-3` (12px)
- Form elements: `gap-2` (8px)
- Pagination buttons: `gap-3` for sections, `gap-1` for numbers

### **Margin Standards**
- Header section: `mb-6` (24px bottom)
- Content sections: `mb-4` (16px bottom)
- Badge elements: `mb-1` (4px bottom)

---

## 🎨 **Color Reference**

### **Status Colors** (WCAG AA Compliant)
```css
/* Original Colors (for backgrounds, borders, icons) */
--status-green: #1FB6A1;
--status-red: #D32F2F;
--status-blue: #1976D2;
--status-amber: #F9A825;
--neutral-gray: #9E9E9E;

/* WCAG AA Accessible Text Variants (4.5:1+ contrast) */
--status-green-accessible: #0D5B52;  /* Use for text on light backgrounds */
--status-red-accessible: #991B1B;    /* Use for text on light backgrounds */
--status-blue-accessible: #1E3A8A;   /* Use for text on light backgrounds */
--status-amber-accessible: #B45309;  /* Use for text on light backgrounds */

/* Light Background Variants (10% opacity) */
bg-status-green-light: rgba(31, 182, 161, 0.1);
bg-status-red-light: rgba(211, 47, 47, 0.1);
bg-status-blue-light: rgba(25, 118, 210, 0.1);
bg-status-amber-light: rgba(249, 168, 37, 0.1);

/* Primary Color (User Customizable) */
--brand-primary: 174 70% 30%;  /* WCAG AA compliant HSL */
```

### **Text Colors**
- Primary text: `text-foreground` or `#222222`
- Secondary text: `#6B7280` (accessible gray)
- Muted text: `text-gray-600`
- Light text: `text-gray-400`

---

## ✅ **Usage Guidelines**

1. **Copy components exactly** - Don't modify spacing, colors, or structure
2. **Use consistent naming** - Follow the established naming patterns
3. **Test all states** - Ensure hover, active, and disabled states work
4. **Maintain accessibility** - Keep all ARIA attributes and keyboard navigation
5. **Update this library** - Add new components as they're perfected

This component library ensures every page uses identical, tested, and accessible components that provide a consistent user experience across the entire RHEMO application.
