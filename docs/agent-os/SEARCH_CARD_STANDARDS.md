# Search Card Standards

## Overview
This document defines the exact design and implementation standards for search cards across all RHEMO pages to ensure visual consistency and proper interaction patterns.

## 🎨 Standard Search Card Structure

### 1. Container Structure
```typescript
{/* Search Card */}
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6 mb-4">
  <div className="flex items-center justify-between">
    {/* Left side - Search input */}
    <div className="flex-1 max-w-md">
      {/* Search input field */}
    </div>
    
    {/* Right side - Action buttons */}
    <div className="flex items-center gap-2">
      {/* Filters, View Mode, Export buttons */}
    </div>
  </div>
</div>
```

### 2. Search Input (Left Side)
```typescript
<div className="relative flex-1 max-w-md">
  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
  <input
    type="text"
    placeholder="Search employees..."
    value={searchTerm}
    onChange={(e) => setSearchTerm(e.target.value)}
    className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
  />
</div>
```

### 3. Action Buttons (Right Side)
```typescript
<div className="flex items-center gap-2">
  {/* Filters Button */}
  <button
    onClick={() => setShowFilters(!showFilters)}
    className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
      showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
    }`}
  >
    <Filter className="w-3.5 h-3.5" />
    Filters
  </button>

  {/* View Mode Toggle */}
  <div className="flex border border-gray-200 rounded overflow-hidden">
    <button
      onClick={() => setViewMode('table')}
      className={`p-1.5 transition-colors ${
        viewMode === 'table'
          ? 'bg-gray-300 text-black'
          : 'bg-white text-gray-600 hover:bg-gray-50'
      }`}
    >
      <List className="w-4 h-4" />
    </button>
    <button
      onClick={() => setViewMode('grid')}
      className={`p-1.5 transition-colors ${
        viewMode === 'grid'
          ? 'bg-gray-300 text-black'
          : 'bg-white text-gray-600 hover:bg-gray-50'
      }`}
    >
      <Grid3X3 className="w-4 h-4" />
    </button>
  </div>
</div>
```

## 🎯 Active State Standards

### Button Active States
All interactive buttons in the search card MUST follow this pattern:

#### **Active/Selected State:**
- **Background**: `bg-gray-300` (`#d1d5db`)
- **Text Color**: `text-black` (`#000000`)
- **Border**: `border-gray-300` (if applicable)

#### **Inactive State:**
- **Background**: `bg-white`
- **Text Color**: `text-gray-700` or `text-gray-600`
- **Border**: `border-gray-300`
- **Hover**: `hover:bg-gray-50`

### Implementation Examples

#### Filters Button
```typescript
className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
  showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
}`}
```

#### View Mode Buttons
```typescript
className={`p-1.5 transition-colors ${
  viewMode === 'table'
    ? 'bg-gray-300 text-black'
    : 'bg-white text-gray-600 hover:bg-gray-50'
}`}
```

#### Export/Action Buttons
```typescript
className="px-3 py-1 bg-white border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors"
```

## 🎨 Color Palette

### Standard Colors
- **Active Background**: `--gray-300: #d1d5db`
- **Active Text**: `--black: #000000`
- **Inactive Background**: `--white: #ffffff`
- **Inactive Text**: `--gray-700: #374151` or `--gray-600: #4b5563`
- **Border**: `--gray-300: #d1d5db`
- **Hover Background**: `--gray-50: #f9fafb`

### Focus States
- **Focus Ring**: `focus:ring-2 focus:ring-primary/20`
- **Focus Border**: `focus:border-primary/50`

## 📱 Responsive Behavior

### Mobile (< 768px)
- Search input takes full width
- Action buttons stack vertically or use dropdown
- Maintain consistent spacing and sizing

### Tablet (768px - 1024px)
- Search input: 50% width
- Action buttons: Horizontal layout
- Proper touch targets (min 44px)

### Desktop (> 1024px)
- Search input: Max width 384px (max-w-md)
- Action buttons: Horizontal layout with proper spacing
- Hover states and transitions

## ♿ Accessibility Standards

### ARIA Labels
```typescript
aria-label="Search employees"
aria-label="Toggle filters"
aria-label="Switch to list view"
aria-label="Switch to grid view"
```

### Keyboard Navigation
- All buttons must be focusable
- Tab order: Search input → Filters → View Mode buttons
- Enter/Space activation for buttons
- Escape to close filters panel

### Screen Reader Support
- Descriptive button labels
- State announcements for active/inactive
- Search result count announcements

## 🔧 Implementation Checklist

### Required Elements
- [ ] Search input with icon
- [ ] Filters button with active state
- [ ] View mode toggle (table/grid)
- [ ] Proper spacing and alignment
- [ ] Responsive behavior
- [ ] Accessibility attributes

### Styling Requirements
- [ ] Active state: `bg-gray-300 text-black`
- [ ] Inactive state: `bg-white text-gray-700`
- [ ] Hover state: `hover:bg-gray-50`
- [ ] Focus states: `focus:ring-2 focus:ring-primary/20`
- [ ] Consistent border radius and padding

### Interaction Requirements
- [ ] Smooth transitions (`transition-colors`)
- [ ] Proper state management
- [ ] Keyboard navigation support
- [ ] Touch-friendly targets (mobile)

## 📋 Copy-Paste Template

### Complete Search Card
```typescript
{/* Search Card */}
<div className="bg-white border border-gray-200 rounded-lg py-6 px-6 mb-4">
  <div className="flex items-center justify-between">
    {/* Search Input */}
    <div className="relative flex-1 max-w-md">
      <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
      <input
        type="text"
        placeholder="Search employees..."
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
        aria-label="Search employees"
      />
    </div>
    
    {/* Action Buttons */}
    <div className="flex items-center gap-2">
      {/* Filters Button */}
      <button
        onClick={() => setShowFilters(!showFilters)}
        className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
          showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
        }`}
        aria-label="Toggle filters"
      >
        <Filter className="w-3.5 h-3.5" />
        Filters
      </button>

      {/* View Mode Toggle */}
      <div className="flex border border-gray-200 rounded overflow-hidden">
        <button
          onClick={() => setViewMode('table')}
          className={`p-1.5 transition-colors ${
            viewMode === 'table'
              ? 'bg-gray-300 text-black'
              : 'bg-white text-gray-600 hover:bg-gray-50'
          }`}
          aria-label="Switch to list view"
        >
          <List className="w-4 h-4" />
        </button>
        <button
          onClick={() => setViewMode('grid')}
          className={`p-1.5 transition-colors ${
            viewMode === 'grid'
              ? 'bg-gray-300 text-black'
              : 'bg-white text-gray-600 hover:bg-gray-50'
          }`}
          aria-label="Switch to grid view"
        >
          <Grid3X3 className="w-4 h-4" />
        </button>
      </div>
    </div>
  </div>
</div>
```

## 🔍 Search Bar Standard (NEW)

### Overview
The standard search bar pattern includes the search input, clear filters button, and action buttons in a consistent layout across all pages.

### Standard Search Bar Structure
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
    <input
      type="date"
      value={selectedDate}
      onChange={(e) => setSelectedDate(e.target.value)}
      className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
      aria-label="Select date"
    />
  </div>
</div>
```

### Visual Standards for Search Bar
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

---

## 🎯 Multi-Select Filter Standards (NEW)

### Overview
This section defines the new standard for multi-select filters with integrated search functionality. This pattern provides a superior user experience for filtering large datasets with multiple criteria.

### 1. Multi-Select Dropdown Structure
```typescript
{/* Multi-Select Filter */}
<div className="relative dropdown-container">
  <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
       onClick={() => setShowDropdown(!showDropdown)}>
    <span className="text-gray-700">
      {selectedItems.length === 0 ? 'All Items' : 
       selectedItems.length === 1 ? selectedItems[0] :
       `${selectedItems.length} selected`}
    </span>
    <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
    </svg>
  </div>
  {showDropdown && (
    <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
      {/* Search input with clear button */}
      <div className="p-2 border-b border-gray-100">
        <div className="flex items-center gap-2">
          <input
            type="text"
            placeholder="Search items..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
            onClick={(e) => e.stopPropagation()}
          />
          {selectedItems.length > 0 && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                setSelectedItems([]);
              }}
              className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
            >
              Clear ({selectedItems.length})
            </button>
          )}
        </div>
      </div>
      {/* Filtered options */}
      {getFilteredOptions().map((item) => (
        <div key={item} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
             onClick={() => handleToggle(item)}>
          <input type="checkbox" checked={selectedItems.includes(item)} readOnly className="w-4 h-4" />
          <span className="text-sm text-gray-700">{item}</span>
        </div>
      ))}
      {getFilteredOptions().length === 0 && (
        <div className="px-3 py-2 text-sm text-gray-500 text-center">
          No items found
        </div>
      )}
    </div>
  )}
</div>
```

### 2. State Management Pattern
```typescript
// State for selections (arrays for multi-select)
const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
const [selectedDepartment, setSelectedDepartment] = useState<string[]>([]);
const [selectedLocation, setSelectedLocation] = useState<string[]>([]);

// State for dropdown visibility
const [showStatusDropdown, setShowStatusDropdown] = useState(false);
const [showDepartmentDropdown, setShowDepartmentDropdown] = useState(false);
const [showLocationDropdown, setShowLocationDropdown] = useState(false);

// State for search terms within dropdowns
const [statusSearchTerm, setStatusSearchTerm] = useState('');
const [departmentSearchTerm, setDepartmentSearchTerm] = useState('');
const [locationSearchTerm, setLocationSearchTerm] = useState('');
```

### 3. Toggle Functions
```typescript
// Helper functions for multi-select
const handleStatusToggle = (status: string) => {
  setSelectedStatus(prev => 
    prev.includes(status) 
      ? prev.filter(s => s !== status)  // Remove
      : [...prev, status]               // Add
  );
};

const handleDepartmentToggle = (department: string) => {
  setSelectedDepartment(prev => 
    prev.includes(department) 
      ? prev.filter(d => d !== department)
      : [...prev, department]
  );
};

const handleLocationToggle = (location: string) => {
  setSelectedLocation(prev => 
    prev.includes(location) 
      ? prev.filter(l => l !== location)
      : [...prev, location]
  );
};
```

### 4. Filtering Functions
```typescript
// Filter options based on search terms
const getFilteredStatusOptions = () => {
  const statusOptions = ['present', 'on-break', 'on-transfer', 'on-leave', 'absent'];
  if (!statusSearchTerm) return statusOptions;
  return statusOptions.filter(status => 
    status.replace('-', ' ').toLowerCase().includes(statusSearchTerm.toLowerCase())
  );
};

const getFilteredDepartmentOptions = () => {
  const departmentOptions = ['Executive', 'Engineering', 'Human Resources', 'Product', 'Design', 'Marketing', 'Sales', 'Analytics'];
  if (!departmentSearchTerm) return departmentOptions;
  return departmentOptions.filter(dept => 
    dept.toLowerCase().includes(departmentSearchTerm.toLowerCase())
  );
};

const getFilteredLocationOptions = () => {
  const locationOptions = ['San Francisco, CA', 'Seattle, WA', 'Portland, OR', 'Austin, TX', 'New York, NY', 'Miami, FL', 'Boston, MA'];
  if (!locationSearchTerm) return locationOptions;
  return locationOptions.filter(location => 
    location.toLowerCase().includes(locationSearchTerm.toLowerCase())
  );
};
```

### 5. Filter Logic Implementation
```typescript
// Apply filters to data
const filteredData = useMemo(() => {
  return data.filter(item => {
    // Search filter
    const matchesSearch = !searchTerm || 
      item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.email.toLowerCase().includes(searchTerm.toLowerCase());

    // Multi-select filters
    const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(item.status);
    const matchesDepartment = selectedDepartment.length === 0 || selectedDepartment.includes(item.department);
    const matchesLocation = selectedLocation.length === 0 || selectedLocation.includes(item.location);

    return matchesSearch && matchesStatus && matchesDepartment && matchesLocation;
  });
}, [data, searchTerm, selectedStatus, selectedDepartment, selectedLocation]);
```

### 6. Click Outside Handler
```typescript
// Close dropdowns when clicking outside
useEffect(() => {
  const handleClickOutside = (event: MouseEvent) => {
    const target = event.target as HTMLElement;
    if (!target.closest('.dropdown-container')) {
      setShowStatusDropdown(false);
      setShowDepartmentDropdown(false);
      setShowLocationDropdown(false);
      // Clear search terms when closing dropdowns
      setStatusSearchTerm('');
      setDepartmentSearchTerm('');
      setLocationSearchTerm('');
    }
  };

  document.addEventListener('mousedown', handleClickOutside);
  return () => document.removeEventListener('mousedown', handleClickOutside);
}, []);
```

### 7. Clear All Filters
```typescript
// Clear all filters
const clearAllFilters = () => {
  setSelectedDepartment([]);
  setSelectedStatus([]);
  setSelectedLocation([]);
  setSearchTerm('');
  setStatusSearchTerm('');
  setDepartmentSearchTerm('');
  setLocationSearchTerm('');
};
```

### 7.1. Main Search Bar Clear Filters Button
```typescript
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
```

#### Visual Standards for Main Clear Button
- **Background**: `bg-white` (white background)
- **Text Color**: `text-gray-700` (dark gray text)
- **Border**: `border-gray-300` (gray border)
- **Hover**: `hover:bg-gray-50` (light gray on hover)
- **Icon**: X icon (`M6 18L18 6M6 6l12 12`)
- **Size**: `w-3 h-3` for icon, `text-sm` for text
- **Spacing**: `gap-2` between icon and text
- **Position**: **BEFORE** the Filters button
- **Conditional Display**: Only shows when any filter arrays have length > 0

### 8. Grid Layout for Filters
```typescript
{/* Advanced Filters */}
{showFilters && (
  <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
      {/* Status Multi-Select */}
      <div className="relative dropdown-container">
        {/* Status dropdown implementation */}
      </div>

      {/* Department Multi-Select */}
      <div className="relative dropdown-container">
        {/* Department dropdown implementation */}
      </div>

      {/* Location Multi-Select */}
      <div className="relative dropdown-container">
        {/* Location dropdown implementation */}
      </div>
    </div>

    <div className="flex justify-between items-center">
      <button 
        onClick={clearAllFilters}
        className="text-xs text-gray-500 hover:text-gray-700 transition-colors"
      >
        Clear all filters
      </button>
    </div>
  </div>
)}
```

### 9. Visual Standards

#### Dropdown Button
- **Height**: `min-h-[32px]` (matches standard input height)
- **Padding**: `px-3 py-1` (consistent with form elements)
- **Border**: `border border-gray-200 rounded`
- **Background**: `bg-white`
- **Hover**: `hover:bg-gray-50`
- **Text**: `text-gray-700`

#### Search Input
- **Size**: `text-xs` (compact)
- **Padding**: `px-2 py-1`
- **Border**: `border border-gray-200 rounded`
- **Focus**: `focus:ring-1 focus:ring-primary/20 focus:border-primary/50`

#### Dropdown Panel
- **Position**: `absolute top-full left-0 right-0 mt-1`
- **Background**: `bg-white border border-gray-200 rounded shadow-lg`
- **Z-Index**: `z-10`
- **Max Height**: `max-h-48 overflow-y-auto`

#### Checkbox Options
- **Size**: `w-4 h-4`
- **Spacing**: `gap-2` between checkbox and text
- **Hover**: `hover:bg-gray-50`
- **Padding**: `px-3 py-2`

### 10. Implementation Checklist

#### Required Elements
- [ ] Multi-select dropdown with search
- [ ] Checkbox selection interface
- [ ] Search input within dropdown
- [ ] Clear all button (shows count when items selected)
- [ ] "No items found" state
- [ ] Click outside to close
- [ ] Clear all filters functionality
- [ ] **Main search bar clear filters button** (shows when any filters are active)

#### State Management
- [ ] Array-based selection state
- [ ] Dropdown visibility state
- [ ] Search term state for each dropdown
- [ ] Proper state cleanup on close

#### Styling Requirements
- [ ] Consistent height with form elements
- [ ] Proper hover and focus states
- [ ] Responsive grid layout
- [ ] Accessible color contrast

#### Interaction Requirements
- [ ] Toggle selection on click
- [ ] Real-time search filtering
- [ ] Keyboard navigation support
- [ ] Touch-friendly targets

## 🚀 Future Enhancements

### Planned Features
1. **Advanced Search**: Date ranges, multiple filters
2. **Search Suggestions**: Autocomplete functionality
3. **Saved Searches**: User-specific search presets
4. **Export Options**: CSV/PDF export from search results

### Performance Considerations
1. **Debounced Search**: Prevent excessive API calls
2. **Search Caching**: Cache recent search results
3. **Lazy Loading**: Load results as user scrolls
4. **Search Analytics**: Track search patterns

---

## 📚 Related Standards

- **Complete Standards**: See `COMPLETE_STANDARDS.md` for master design system documentation
- **Pagination Standards**: See `PAGINATION_STANDARDS.md` for consistent button active states
- **Tooltip Standards**: See `TOOLTIP_STANDARDS.md` for hover interactions
- **Component Standards**: See `COMPREHENSIVE_PRODUCT_ANALYSIS.md` for overall design system

---

*This standard must be followed across all RHEMO pages with search functionality. Any deviations require approval from the design system team.*
