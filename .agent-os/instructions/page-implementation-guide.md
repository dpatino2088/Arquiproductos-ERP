# Page Implementation Guide

## Overview
This guide provides step-by-step instructions for implementing new pages that follow the RHEMO Page Design System. Use this alongside `page-design-system.md` to ensure perfect consistency.

---

## 🚀 **Quick Start Template**

### **1. Basic Page Structure**
```tsx
import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { 
  // Import required icons from lucide-react
} from 'lucide-react';

interface YourDataType {
  id: string;
  // Define your data structure
}

export default function YourPageName() {
  const { registerSubmodules } = useSubmoduleNav();
  
  // Required state variables (copy these exactly)
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState('defaultField');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  
  // Register submodule navigation
  useEffect(() => {
    registerSubmodules('Section Title', [
      { id: 'tab1', label: 'Tab Name', href: '/path', icon: IconComponent }
    ]);
  }, [registerSubmodules]);

  // Your data and filtering logic here
  
  return (
    <div className="p-6">
      {/* Page Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Page Title</h1>
          <p className="text-xs" style={{ color: '#6B7280' }}>Descriptive subtitle</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Action buttons */}
        </div>
      </div>

      {/* Search & Filters */}
      {/* Copy search bar structure from Directory.tsx */}

      {/* Data Display */}
      {/* Copy table/grid structure from Directory.tsx */}

      {/* Pagination */}
      {/* Copy pagination structure from Directory.tsx */}
    </div>
  );
}
```

---

## ⚠️ **CRITICAL: Input Focus Ring Consistency**

### **Universal Input Focus Standard**
**Every single input element MUST use the same focus ring for professional consistency:**

```css
/* Standard Focus Ring (most inputs) */
focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50

/* Compact Focus Ring (small elements like pagination dropdowns) */
focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50
```

### **Apply to ALL Input Types:**
- `<input>` (text, email, number, date, etc.)
- `<select>` dropdowns
- `<textarea>` elements
- Custom input components

### **❌ Common Mistakes:**
```css
focus:ring-blue-500        /* WRONG - hardcoded color */
focus:ring-red-500         /* WRONG - hardcoded color */
focus:border-transparent   /* WRONG - inconsistent */
```

### **✅ Correct Usage:**
```tsx
// Search input
<input className="... focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50" />

// Filter dropdown
<select className="... focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50">

// Pagination dropdown (smaller)
<select className="... focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50">
```

### **🎯 WCAG AA Color Compliance** (MANDATORY)
```tsx
// ✅ CORRECT: Use accessible variants for text on light backgrounds
<span className="text-status-green-accessible bg-status-green-light">Success</span>
<div className="text-status-red-accessible">Error text</div>

// ✅ CORRECT: Original colors for solid backgrounds
<button className="bg-status-green text-white">Action</button>

// ❌ WRONG: Original colors for text (fails contrast)
<span className="text-status-green">Success text</span>
<div className="text-red-600">Error text</div>
```

### **Required Color Classes:**
- **Text on Light**: Always use `-accessible` suffix (`text-status-green-accessible`)
- **Backgrounds**: Use original colors (`bg-status-green`)
- **Borders/Icons**: Use original colors (`border-status-blue`, `text-status-amber`)
- **Primary Elements**: Automatically WCAG AA compliant (`text-primary`)

---

## 🎨 **Component Patterns to Copy**

### **1. Status Badge Function**
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

### **2. Sorting Handler**
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

### **3. Pagination Logic**
```tsx
// Pagination calculations
const totalPages = Math.ceil(filteredData.length / itemsPerPage);
const startIndex = (currentPage - 1) * itemsPerPage;
const paginatedData = filteredData.slice(startIndex, startIndex + itemsPerPage);

// Reset to first page when search changes
useMemo(() => {
  setCurrentPage(1);
}, [searchTerm]);
```

---

## 📋 **Copy-Paste Components**

### **1. Search Bar** (Copy exactly from Directory.tsx lines 518-572)
```tsx
<div className="mb-4">
  <div className={`bg-white border border-gray-200 py-6 px-6 ${
    showFilters ? 'rounded-t-lg' : 'rounded-lg'
  }`}>
    <div className="flex items-center justify-between gap-3">
      {/* Search Bar */}
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
      
      <div className="flex items-center gap-2">
        {/* Filters Button */}
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
            showFilters ? 'bg-gray-100 text-gray-900' : 'bg-white text-gray-700 hover:bg-gray-50'
          }`}
        >
          <Filter style={{ width: '14px', height: '14px' }} />
          Filters
        </button>

        {/* View Mode Toggle */}
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
      </div>
    </div>
  </div>
</div>
```

### **2. Pagination Component** (Copy exactly from Directory.tsx lines 852-935)
```tsx
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-3">
      <span className="text-xs text-gray-600">Show:</span>
      <select
        value={itemsPerPage}
        onChange={(e) => {
          setItemsPerPage(Number(e.target.value));
          setCurrentPage(1);
        }}
        className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500"
      >
        <option value={10}>10</option>
        <option value={25}>25</option>
        <option value={50}>50</option>
        <option value={100}>100</option>
      </select>
      <span className="text-xs text-gray-600">
        Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredData.length)} of {filteredData.length}
      </span>
    </div>

    {totalPages > 1 && (
      <div className="flex items-center gap-3">
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

        <div className="flex items-center gap-1">
          {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
            let pageNum;
            if (totalPages <= 5) {
              pageNum = i + 1;
            } else if (currentPage <= 3) {
              pageNum = i + 1;
            } else if (currentPage >= totalPages - 2) {
              pageNum = totalPages - 4 + i;
            } else {
              pageNum = currentPage - 2 + i;
            }

            return (
              <button
                key={pageNum}
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
            );
          })}
        </div>

        <button
          onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
          disabled={currentPage === totalPages}
          className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
            currentPage === totalPages
              ? 'border-gray-200 text-gray-400 cursor-not-allowed'
              : 'border-gray-300 text-gray-700 hover:bg-gray-50'
          }`}
        >
          Next
          <ChevronRight className="w-3 h-3" />
        </button>
      </div>
    )}
  </div>
</div>
```

---

## 🔧 **Customization Points**

### **What to Change for Each Page**
1. **Data Interface**: Define your specific data structure
2. **Search Fields**: Update search logic for your data fields
3. **Filter Options**: Customize filter dropdowns for your data
4. **Sort Fields**: Define which fields can be sorted
5. **Table Columns**: Customize table headers and cell content
6. **Grid Card Content**: Customize card layout for your data
7. **Action Buttons**: Add page-specific action buttons

### **What to NEVER Change**
1. **Spacing and padding values**
2. **Color codes and CSS classes**
3. **Font sizes and typography**
4. **Component structure and hierarchy**
5. **State management patterns**
6. **Accessibility attributes**

---

## ✅ **Implementation Checklist**

### **Before You Start**
- [ ] Read `page-design-system.md` thoroughly
- [ ] Identify your data structure and requirements
- [ ] Plan your submodule navigation structure

### **During Implementation**
- [ ] Copy base template structure
- [ ] Implement data fetching/management
- [ ] Copy search bar component exactly
- [ ] Copy pagination component exactly
- [ ] Customize table/grid content only
- [ ] Test all interactive elements

### **Before Completion**
- [ ] Verify visual consistency with Directory page
- [ ] Test search and filter functionality
- [ ] Test pagination on different data sizes
- [ ] Test view mode switching
- [ ] **Run accessibility tests** (WCAG AA compliance)
- [ ] **Verify color contrast** (4.5:1+ ratio for all text)
- [ ] **Test focus rings** (all inputs use primary color)
- [ ] Test responsive behavior
- [ ] **Validate status badges** (use `-accessible` variants)
- [ ] **Test keyboard navigation**

---

## 🚨 **Common Mistakes to Avoid**

1. **Changing padding/margin values** - Always use exact values from specification
2. **Using different color codes** - Always use approved color tokens
3. **Using original colors for text** - Always use `-accessible` variants for text on light backgrounds
4. **Modifying font sizes** - Stick to specified typography scale
5. **Breaking component structure** - Maintain exact HTML hierarchy
6. **Skipping accessibility attributes** - Always include ARIA labels
7. **Poor color contrast** - Verify 4.5:1+ contrast ratios for all text
8. **Inconsistent focus rings** - All inputs must use primary color focus rings
9. **Not testing edge cases** - Test with empty data, single items, etc.

---

## 📞 **Getting Help**

When implementing pages:
1. **Start with Directory.tsx** as your reference implementation
2. **Copy components exactly** - don't try to improve them
3. **Test frequently** against the Directory page for consistency
4. **Use this guide** as your step-by-step checklist

Remember: The goal is perfect consistency across all pages. When in doubt, copy exactly from Directory.tsx.
