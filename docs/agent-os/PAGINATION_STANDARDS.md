# Pagination Standards

## Overview
This document defines the exact design and implementation standards for pagination components across all RHEMO pages to ensure visual consistency and proper interaction patterns.

## 🎨 Standard Pagination Structure

### 1. Container Structure
```typescript
{/* Pagination */}
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
  <div className="flex items-center justify-between">
    {/* Left side - Items per page selector */}
    <div className="flex items-center gap-3">
      {/* Items per page controls */}
    </div>
    
    {/* Right side - Page navigation */}
    <div className="flex items-center gap-3">
      {/* Previous, Page numbers, Next buttons */}
    </div>
  </div>
</div>
```

### 2. Items Per Page Selector (Left Side)
```typescript
<div className="flex items-center gap-3">
  <span className="text-xs text-gray-600">Show:</span>
  <select 
    value={itemsPerPage}
    onChange={(e) => {
      setItemsPerPage(Number(e.target.value));
      setCurrentPage(1); // Reset to first page when changing items per page
    }}
    className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
  >
    <option value={5}>5</option>
    <option value={10}>10</option>
    <option value={25}>25</option>
    <option value={50}>50</option>
  </select>
  <span className="text-xs text-gray-600">
    Showing {((currentPage - 1) * itemsPerPage) + 1}-{Math.min(currentPage * itemsPerPage, totalItems)} of {totalItems}
  </span>
</div>
```

### 3. Page Navigation (Right Side)
```typescript
{totalPages > 1 && (
  <div className="flex items-center gap-3">
    {/* Previous Button */}
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

    {/* Page Numbers */}
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
                ? 'bg-gray-300 text-black'
                : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
            }`}
          >
            {pageNum}
          </button>
        );
      })}
    </div>

    {/* Next Button */}
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
```

## 🎯 Active State Standards

### Current Page Button
- **Background**: `bg-gray-300` (`#d1d5db`)
- **Text Color**: `text-black` (`#000000`)
- **Border**: None (no border for active state)
- **Size**: `w-6 h-6` (24px × 24px)

### Inactive Page Buttons
- **Background**: `bg-white` (transparent)
- **Text Color**: `text-gray-700` (`#374151`)
- **Border**: `border border-gray-300`
- **Hover**: `hover:bg-gray-50`
- **Size**: `w-6 h-6` (24px × 24px)

### Navigation Buttons (Previous/Next)
- **Active State**: `border-gray-300 text-gray-700 hover:bg-gray-50`
- **Disabled State**: `border-gray-200 text-gray-400 cursor-not-allowed`
- **Padding**: `px-2 py-1`
- **Text Size**: `text-xs`

## 🎨 Color Palette

### Standard Colors
- **Current Page Background**: `--gray-300: #d1d5db`
- **Current Page Text**: `--black: #000000`
- **Inactive Page Background**: `--white: #ffffff`
- **Inactive Page Text**: `--gray-700: #374151`
- **Inactive Page Border**: `--gray-300: #d1d5db`
- **Hover Background**: `--gray-50: #f9fafb`
- **Disabled Text**: `--gray-400: #9ca3af`
- **Disabled Border**: `--gray-200: #e5e7eb`

### Focus States
- **Focus Ring**: `focus:ring-1 focus:ring-primary/20`
- **Focus Border**: `focus:border-primary/50`

## 📱 Responsive Behavior

### Mobile (< 768px)
- Hide "Previous"/"Next" text, show only icons
- Reduce gap between elements
- Smaller page number buttons if needed
- Stack items per page selector if necessary

### Tablet (768px - 1024px)
- Full text labels for navigation
- Standard spacing and sizing
- Proper touch targets (min 44px)

### Desktop (> 1024px)
- Full functionality with all text labels
- Standard spacing and hover effects
- Keyboard navigation support

## ♿ Accessibility Standards

### ARIA Labels
```typescript
aria-label="Go to previous page"
aria-label="Go to next page"
aria-label={`Go to page ${pageNum}`}
aria-label="Items per page"
```

### Keyboard Navigation
- All buttons must be focusable
- Tab order: Previous → Page numbers → Next
- Enter/Space activation for buttons
- Arrow keys for page navigation (optional enhancement)

### Screen Reader Support
- Descriptive button labels
- Current page announcements
- Total pages and items information
- Disabled state announcements

## 🔧 Implementation Checklist

### Required Elements
- [ ] Items per page selector (5, 10, 25, 50)
- [ ] Items count display ("Showing X-Y of Z")
- [ ] Previous/Next navigation buttons
- [ ] Page number buttons (max 5 visible)
- [ ] Proper disabled states
- [ ] Responsive behavior

### Styling Requirements
- [ ] Current page: `bg-gray-300 text-black`
- [ ] Inactive pages: `border border-gray-300 text-gray-700 hover:bg-gray-50`
- [ ] Disabled buttons: `border-gray-200 text-gray-400 cursor-not-allowed`
- [ ] Consistent sizing: `w-6 h-6` for page numbers
- [ ] Smooth transitions: `transition-colors`

### Interaction Requirements
- [ ] Click handlers for all buttons
- [ ] Proper disabled state management
- [ ] Reset to page 1 when changing items per page
- [ ] Keyboard navigation support
- [ ] Touch-friendly targets (mobile)

## 📋 Copy-Paste Template

### Complete Pagination Component
```typescript
{/* Pagination */}
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
  <div className="flex items-center justify-between">
    {/* Items Per Page Selector */}
    <div className="flex items-center gap-3">
      <span className="text-xs text-gray-600">Show:</span>
      <select 
        value={itemsPerPage}
        onChange={(e) => {
          setItemsPerPage(Number(e.target.value));
          setCurrentPage(1);
        }}
        className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
        aria-label="Items per page"
      >
        <option value={5}>5</option>
        <option value={10}>10</option>
        <option value={25}>25</option>
        <option value={50}>50</option>
      </select>
      <span className="text-xs text-gray-600">
        Showing {((currentPage - 1) * itemsPerPage) + 1}-{Math.min(currentPage * itemsPerPage, totalItems)} of {totalItems}
      </span>
    </div>
    
    {/* Page Navigation */}
    {totalPages > 1 && (
      <div className="flex items-center gap-3">
        {/* Previous Button */}
        <button
          onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
          disabled={currentPage === 1}
          className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
            currentPage === 1
              ? 'border-gray-200 text-gray-400 cursor-not-allowed'
              : 'border-gray-300 text-gray-700 hover:bg-gray-50'
          }`}
          aria-label="Go to previous page"
        >
          <ChevronLeft className="w-3 h-3" />
          Previous
        </button>

        {/* Page Numbers */}
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
                    ? 'bg-gray-300 text-black'
                    : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
                aria-label={`Go to page ${pageNum}`}
              >
                {pageNum}
              </button>
            );
          })}
        </div>

        {/* Next Button */}
        <button
          onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
          disabled={currentPage === totalPages}
          className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
            currentPage === totalPages
              ? 'border-gray-200 text-gray-400 cursor-not-allowed'
              : 'border-gray-300 text-gray-700 hover:bg-gray-50'
          }`}
          aria-label="Go to next page"
        >
          Next
          <ChevronRight className="w-3 h-3" />
        </button>
      </div>
    )}
  </div>
</div>
```

## 🚀 Advanced Features

### Smart Page Display Logic
```typescript
// Show maximum 5 page numbers with intelligent positioning
const getPageNumbers = (currentPage: number, totalPages: number) => {
  if (totalPages <= 5) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }
  
  if (currentPage <= 3) {
    return [1, 2, 3, 4, 5];
  }
  
  if (currentPage >= totalPages - 2) {
    return Array.from({ length: 5 }, (_, i) => totalPages - 4 + i);
  }
  
  return Array.from({ length: 5 }, (_, i) => currentPage - 2 + i);
};
```

### Performance Optimizations
- Memoize page number calculations
- Debounce items per page changes
- Lazy load page content
- Virtual scrolling for large datasets

## 🔍 Testing Checklist

### Visual Testing
- [ ] Current page has gray-300 background
- [ ] Inactive pages have proper borders
- [ ] Hover states work correctly
- [ ] Disabled states are visually distinct
- [ ] Responsive behavior on all screen sizes

### Functional Testing
- [ ] Page navigation works correctly
- [ ] Items per page changes reset to page 1
- [ ] Disabled buttons don't respond to clicks
- [ ] Keyboard navigation works
- [ ] Screen reader compatibility

### Edge Cases
- [ ] Single page (no pagination shown)
- [ ] Very large page counts
- [ ] Empty data sets
- [ ] Rapid page changes
- [ ] Browser back/forward buttons

---

## 📚 Related Standards

- **Complete Standards**: See `COMPLETE_STANDARDS.md` for master design system documentation
- **Search Card Standards**: See `SEARCH_CARD_STANDARDS.md` for button active states
- **Tooltip Standards**: See `TOOLTIP_STANDARDS.md` for hover interactions
- **Component Standards**: See `COMPREHENSIVE_PRODUCT_ANALYSIS.md` for overall design system

---

*This standard must be followed across all RHEMO pages with pagination. Any deviations require approval from the design system team.*
