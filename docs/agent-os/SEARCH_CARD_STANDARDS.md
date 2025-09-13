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
