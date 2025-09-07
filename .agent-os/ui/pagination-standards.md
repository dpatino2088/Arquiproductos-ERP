# Pagination Standards

## Overview
This document defines the exact design and implementation standards for pagination components across all RHEMO pages to ensure visual consistency and proper spacing.

## Standard Pagination Structure

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
    {totalPages > 1 && (
      <div className="flex items-center gap-3">
        {/* Previous button, page numbers, Next button */}
      </div>
    )}
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
      setCurrentPage(1);
    }}
    className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
    aria-label="Items per page"
    id="items-per-page"
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
                ? 'text-white'
                : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
            }`}
            style={currentPage === pageNum ? { backgroundColor: 'var(--teal-brand-hex)' } : {}}
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

## Required Imports
```typescript
import { 
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
```

## State Management
```typescript
const [currentPage, setCurrentPage] = useState(1);
const [itemsPerPage, setItemsPerPage] = useState(10);

// Calculate pagination values
const totalPages = Math.ceil(totalItems / itemsPerPage);
const startIndex = (currentPage - 1) * itemsPerPage;
const paginatedItems = allItems.slice(startIndex, startIndex + itemsPerPage);
```

## Spacing Requirements

### 1. Container Spacing
- **Container**: `bg-white border border-gray-200 rounded-lg py-6 px-6`
- **No margin bottom**: Pagination is always the last element
- **No margin top**: Should be directly after table/grid

### 2. Parent Container Spacing
- **Table/Grid container**: Must have `mb-4` to create separation from pagination
- **Search card**: Must have `mb-4` to create separation from table/grid

### 3. Complete Spacing Pattern
```typescript
{/* Search Card */}
<div className="mb-4">
  {/* Search content */}
</div>

{/* Table/Grid Card */}
<div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
  {/* Table/Grid content */}
</div>

{/* Pagination Card */}
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
  {/* Pagination content */}
</div>
```

## Visual Specifications

### Colors
- **Background**: `bg-white`
- **Border**: `border-gray-200`
- **Text**: `text-gray-600` (labels), `text-gray-700` (buttons)
- **Active page**: `var(--teal-brand-hex)` background with white text
- **Disabled**: `text-gray-400` with `cursor-not-allowed`
- **Hover**: `hover:bg-gray-50`

### Spacing
- **Container padding**: `py-6 px-6`
- **Button padding**: `px-2 py-1`
- **Page number size**: `w-6 h-6`
- **Gap between elements**: `gap-3` (main), `gap-1` (page numbers)

### Typography
- **Labels**: `text-xs text-gray-600`
- **Buttons**: `text-xs`
- **Page numbers**: `text-xs`

### Border Radius
- **Container**: `rounded-lg`
- **Buttons**: `rounded`
- **Page numbers**: `rounded`

## Page Number Logic

### Smart Pagination Algorithm
```typescript
const getPageNumbers = (currentPage: number, totalPages: number) => {
  const maxVisible = 5;
  
  if (totalPages <= maxVisible) {
    // Show all pages: [1, 2, 3, 4, 5]
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }
  
  if (currentPage <= 3) {
    // Show first 5 pages: [1, 2, 3, 4, 5]
    return Array.from({ length: maxVisible }, (_, i) => i + 1);
  }
  
  if (currentPage >= totalPages - 2) {
    // Show last 5 pages: [21, 22, 23, 24, 25]
    return Array.from({ length: maxVisible }, (_, i) => totalPages - 4 + i);
  }
  
  // Show 2 before and 2 after current: [3, 4, 5, 6, 7]
  return Array.from({ length: maxVisible }, (_, i) => currentPage - 2 + i);
};
```

### Examples
- **Total 3 pages**: [1] [2] [3]
- **Total 5 pages**: [1] [2] [3] [4] [5]
- **Page 1 of 10**: [1] [2] [3] [4] [5]
- **Page 5 of 10**: [3] [4] [5] [6] [7]
- **Page 10 of 10**: [6] [7] [8] [9] [10]

## Accessibility Requirements

### ARIA Labels
- All buttons must have `aria-label`
- Select element must have `aria-label` and `id`
- Disabled state must be properly communicated

### Keyboard Navigation
- All interactive elements must be keyboard accessible
- Tab order must be logical
- Focus management must be proper

### Screen Reader Support
- State changes must be announced
- Page changes must be communicated
- Item count changes must be announced

## Examples

### Basic Pagination
```typescript
{/* Pagination */}
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
        className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
        aria-label="Items per page"
        id="items-per-page"
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
                style={currentPage === pageNum ? { backgroundColor: 'var(--teal-brand-hex)' } : {}}
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

## Implementation Checklist

- [ ] Container uses correct structure with proper padding
- [ ] Items per page selector has correct styling and options
- [ ] Page counter shows correct range and total
- [ ] Previous/Next buttons have proper disabled states
- [ ] Page numbers use smart pagination algorithm
- [ ] Active page has correct background color
- [ ] All ARIA labels are present
- [ ] Focus states are properly implemented
- [ ] Spacing follows specifications exactly
- [ ] Colors match design system
- [ ] Typography is consistent
- [ ] Border radius is correct
- [ ] Parent containers have proper `mb-4` spacing
- [ ] Pagination container has no margin bottom
- [ ] Responsive design is maintained
- [ ] Keyboard navigation works
- [ ] Screen reader compatibility verified

## Common Mistakes to Avoid

### 1. Spacing Issues
- ❌ **Wrong**: Missing `mb-4` on table/grid container
- ❌ **Wrong**: Adding margin to pagination container
- ✅ **Correct**: Table/grid has `mb-4`, pagination has no margin

### 2. Page Number Logic
- ❌ **Wrong**: Showing all page numbers for large datasets
- ❌ **Wrong**: Fixed page number display
- ✅ **Correct**: Smart pagination with max 5 visible pages

### 3. State Management
- ❌ **Wrong**: Not resetting to page 1 when changing items per page
- ❌ **Wrong**: Not calculating startIndex correctly
- ✅ **Correct**: Reset page and calculate indices properly

### 4. Accessibility
- ❌ **Wrong**: Missing ARIA labels
- ❌ **Wrong**: No disabled state communication
- ✅ **Correct**: Full accessibility implementation

## Notes

- Always use the exact same structure and classes
- Do not modify colors, spacing, or typography
- Ensure all interactive elements are accessible
- Test keyboard navigation thoroughly
- Verify screen reader compatibility
- Maintain responsive behavior
- Follow the established patterns exactly
- Use the smart pagination algorithm for page numbers
- Always include proper spacing between components

This standard ensures that all pagination components across the application look and behave identically, providing a consistent user experience and proper visual spacing.
