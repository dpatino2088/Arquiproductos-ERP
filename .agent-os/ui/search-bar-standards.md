# Search Bar Standards

## Overview
This document defines the exact design and implementation standards for search bars across all RHEMO pages to ensure visual consistency.

## Standard Search Bar Structure

### 1. Container Structure
```typescript
<div className="mb-4">
  <div className={`bg-white border border-gray-200 py-6 px-6 ${
    showFilters ? 'rounded-t-lg' : 'rounded-lg'
  }`}>
    {/* Search bar content */}
  </div>
  
  {showFilters && (
    <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
      {/* Advanced filters content */}
    </div>
  )}
</div>
```

### 2. Search Input
```typescript
<div className="flex items-center gap-4">
  <div className="flex-1 relative">
    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
    <input
      type="text"
      placeholder="Search employees, roles, or departments..."
      value={searchTerm}
      onChange={(e) => setSearchTerm(e.target.value)}
      className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
      aria-label="Search attendance records"
    />
  </div>
  <div className="flex items-center gap-2">
    {/* Additional controls (date picker, filters button, etc.) */}
  </div>
</div>
```

### 3. Filters Button
```typescript
<button
  className={`px-3 py-1 border rounded text-sm transition-colors ${
    showFilters
      ? 'bg-gray-100 text-gray-900 border-gray-300'
      : 'border-gray-300 hover:bg-gray-50'
  }`}
  onClick={() => setShowFilters(!showFilters)}
  aria-label="Toggle filters"
>
  <Filter className="w-4 h-4 inline mr-1" />
  Filters
</button>
```

### 4. Advanced Filters Section
```typescript
{showFilters && (
  <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
      {/* Filter dropdowns */}
    </div>
    <div className="flex justify-between items-center">
      <button 
        onClick={clearFilters}
        className="text-xs text-gray-500 hover:text-gray-700"
      >
        Clear all filters
      </button>
      <div className="flex gap-3 items-center">
        <span className="text-xs text-gray-500">Sort by:</span>
        {/* Sort buttons */}
      </div>
    </div>
  </div>
)}
```

### 5. Filter Dropdowns
```typescript
<select 
  value={selectedField}
  onChange={(e) => setSelectedField(e.target.value)}
  className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
  aria-label="Filter by field"
  id="field-filter"
>
  <option value="">All Fields</option>
  <option value="option1">Option 1</option>
  <option value="option2">Option 2</option>
</select>
```

### 6. Sort Buttons
```typescript
<button 
  onClick={() => handleSort('fieldName')}
  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
    sortBy === 'fieldName' ? 'text-gray-900 font-medium' : 'text-gray-600'
  }`}
>
  Field Name
  {sortBy === 'fieldName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
</button>
```

## Required Imports
```typescript
import { 
  Search, 
  Filter, 
  SortAsc, 
  SortDesc
} from 'lucide-react';
```

## State Management
```typescript
const [searchTerm, setSearchTerm] = useState('');
const [showFilters, setShowFilters] = useState(false);
const [sortBy, setSortBy] = useState<'field1' | 'field2' | 'field3'>('field1');
const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
// Add filter states as needed
const [selectedField, setSelectedField] = useState('');
```

## Required Functions
```typescript
const handleSort = (field: typeof sortBy) => {
  if (sortBy === field) {
    setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
  } else {
    setSortBy(field);
    setSortOrder('asc');
  }
};

const clearFilters = () => {
  setSelectedField('');
  setSearchTerm('');
  // Clear all other filter states
};
```

## Visual Specifications

### Colors
- **Background**: `bg-white`
- **Border**: `border-gray-200`
- **Input background**: `bg-gray-50`
- **Input border**: `border-gray-200`
- **Focus ring**: `focus:ring-primary/20`
- **Focus border**: `focus:border-primary/50`
- **Text**: `text-gray-900` (active), `text-gray-600` (inactive)
- **Hover**: `hover:text-gray-900`

### Spacing
- **Container padding**: `py-6 px-6`
- **Input padding**: `pl-9 pr-3 py-1`
- **Button padding**: `px-3 py-1`
- **Gap between elements**: `gap-4` (main), `gap-2` (controls), `gap-3` (sort buttons)

### Typography
- **Input text**: `text-sm`
- **Button text**: `text-sm`
- **Sort buttons**: `text-xs`
- **Clear filters**: `text-xs`

### Border Radius
- **Container**: `rounded-lg` (normal), `rounded-t-lg` (with filters)
- **Filters section**: `rounded-b-lg`
- **Input**: `rounded`
- **Buttons**: `rounded`

## Accessibility Requirements

### ARIA Labels
- All inputs must have `aria-label`
- All buttons must have `aria-label`
- All selects must have `aria-label` and `id`

### Keyboard Navigation
- All interactive elements must be keyboard accessible
- Focus management must be proper
- Tab order must be logical

### Screen Reader Support
- All form elements must have proper labels
- State changes must be announced
- Sort order changes must be communicated

## Examples

### Basic Search Bar (No Filters)
```typescript
<div className="mb-4">
  <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
    <div className="flex items-center gap-4">
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
    </div>
  </div>
</div>
```

### Search Bar with Date Picker
```typescript
<div className="mb-4">
  <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
    <div className="flex items-center gap-4">
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
      <div className="flex items-center gap-2">
        <input
          type="date"
          value={selectedDate}
          onChange={(e) => setSelectedDate(e.target.value)}
          className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
          aria-label="Select date"
        />
        <button
          className={`px-3 py-1 border rounded text-sm transition-colors ${
            showFilters
              ? 'bg-gray-100 text-gray-900 border-gray-300'
              : 'border-gray-300 hover:bg-gray-50'
          }`}
          onClick={() => setShowFilters(!showFilters)}
          aria-label="Toggle filters"
        >
          <Filter className="w-4 h-4 inline mr-1" />
          Filters
        </button>
      </div>
    </div>
  </div>
</div>
```

## Implementation Checklist

- [ ] Container uses correct structure with conditional border radius
- [ ] Search input has proper styling and positioning
- [ ] Filters button has correct state styling
- [ ] Advanced filters section uses proper container
- [ ] All dropdowns use consistent styling
- [ ] Sort buttons are text-only (no borders/backgrounds)
- [ ] All ARIA labels are present
- [ ] Focus states are properly implemented
- [ ] Clear filters function resets all states
- [ ] Sort functionality works correctly
- [ ] Responsive design is maintained
- [ ] Colors match design system
- [ ] Spacing follows specifications
- [ ] Typography is consistent

## Notes

- Always use the exact same structure and classes
- Do not modify colors, spacing, or typography
- Ensure all interactive elements are accessible
- Test keyboard navigation
- Verify screen reader compatibility
- Maintain responsive behavior
- Follow the established patterns exactly

This standard ensures that all search bars across the application look and behave identically, providing a consistent user experience.
