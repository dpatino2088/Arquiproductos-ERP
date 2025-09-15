# Input Field Standards

## Overview
This document defines the comprehensive design system standards for all input fields, dropdowns, and form elements across the RHEMO application. These standards ensure visual consistency and optimal user experience.

## Core Principles
- **Consistency**: All form elements must have identical heights and styling
- **Accessibility**: Proper focus states, contrast ratios, and keyboard navigation
- **Responsiveness**: Elements adapt gracefully across different screen sizes
- **Brand Alignment**: Colors and styling align with the RHEMO design system

## Standard Heights

### Primary Standard
All input fields, dropdowns, and buttons must use the same height for perfect alignment:

```css
/* Standard height for all form elements */
.form-element-standard {
  @apply py-1 px-3 text-sm;
  /* Results in approximately 32px total height */
}
```

### Height Specifications
- **Padding**: `py-1` (4px top/bottom)
- **Text Size**: `text-sm` (14px)
- **Border**: `border` (1px)
- **Total Height**: ~32px (including border)

## Input Field Standards

### Text Inputs
```tsx
<input
  type="text"
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
  placeholder="Enter text..."
/>
```

### Textarea
```tsx
<textarea
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none"
  rows={3}
  placeholder="Enter text..."
/>
```

### Password Inputs
```tsx
<input
  type="password"
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
  placeholder="Enter password..."
/>
```

### Number Inputs
```tsx
<input
  type="number"
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
  placeholder="0"
/>
```

## Dropdown Standards

### Custom Dropdown (Recommended)
For dropdowns that need to open upward (dropup) or have custom styling:

```tsx
<div className="relative dropdown-container">
  <button
    type="button"
    onClick={() => setShowDropdown(!showDropdown)}
    className="w-48 appearance-none bg-white border border-gray-300 rounded-md px-3 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent text-left flex items-center justify-between"
  >
    <span className={selectedValue ? 'text-gray-900' : 'text-gray-500'}>
      {selectedValue || 'Select option...'}
    </span>
    <ChevronDown className={`w-4 h-4 text-gray-400 transition-transform ${showDropdown ? 'rotate-180' : ''}`} />
  </button>
  
  {showDropdown && (
    <div className="absolute bottom-full left-0 right-0 mb-1 bg-white border border-gray-300 rounded-md shadow-lg z-50 max-h-48 overflow-y-auto">
      {/* Dropdown options */}
    </div>
  )}
</div>
```

### Native Select (Fallback)
For simple dropdowns where custom behavior isn't needed:

```tsx
<select className="w-48 appearance-none bg-white border border-gray-300 rounded-md px-3 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
  <option value="">Select option...</option>
  {/* Options */}
</select>
```

## Button Standards

### Primary Action Buttons
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm">
  <Icon className="w-4 h-4" />
  Button Text
</button>
```

### Secondary Buttons
```tsx
<button className="px-2 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors">
  Button Text
</button>
```

### Icon-only Buttons
```tsx
<button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
  <Icon className="w-4 h-4" />
</button>
```

## Form Layout Standards

### Horizontal Form Layout
```tsx
<div className="flex items-center gap-3">
  <div className="flex-1">
    <input className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
  </div>
  <div className="flex items-center gap-2">
    <select className="w-48 px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
      {/* Options */}
    </select>
    <button className="px-2 py-1 bg-primary text-white rounded text-sm">
      Submit
    </button>
  </div>
</div>
```

### Vertical Form Layout
```tsx
<div className="space-y-4">
  <div>
    <label className="block text-sm font-medium text-gray-700 mb-1">
      Label
    </label>
    <input className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
  </div>
  <div>
    <label className="block text-sm font-medium text-gray-700 mb-1">
      Label
    </label>
    <select className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
      {/* Options */}
    </select>
  </div>
</div>
```

## State Standards

### Default State
- **Border**: `border-gray-300`
- **Background**: `bg-white`
- **Text**: `text-gray-900`
- **Placeholder**: `text-gray-500`

### Focus State
- **Ring**: `focus:ring-2 focus:ring-primary`
- **Border**: `focus:border-transparent`
- **Outline**: `focus:outline-none`

### Disabled State
```tsx
<input
  disabled
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm bg-gray-50 text-gray-400 cursor-not-allowed"
/>
```

### Error State
```tsx
<input
  className="w-full px-3 py-1 border border-red-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent"
/>
```

### Success State
```tsx
<input
  className="w-full px-3 py-1 border border-green-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
/>
```

## Width Standards

### Common Widths
- **Full Width**: `w-full`
- **Auto Width**: `w-auto`
- **Fixed Widths**: `w-48`, `w-56`, `w-64`, `w-72`
- **Min Width**: `w-min`
- **Max Width**: `w-max`

### Responsive Widths
```tsx
<input className="w-full sm:w-48 md:w-56 lg:w-64" />
```

## Border Radius Standards

### Standard Radius
All form elements use `rounded-md` for consistency:

```css
.form-element {
  @apply rounded-md;
  /* 6px border radius */
}
```

### Exceptions
- **Large Elements**: `rounded-lg` for larger forms
- **Small Elements**: `rounded` for compact interfaces

## Color Standards

### Primary Colors
- **Primary**: `var(--teal-brand-hex)` (#008383)
- **Primary Light**: `bg-teal-50`
- **Primary Dark**: `bg-teal-700`

### Neutral Colors
- **Gray 50**: `#f9fafb`
- **Gray 100**: `#f3f4f6`
- **Gray 300**: `#d1d5db`
- **Gray 500**: `#6b7280`
- **Gray 700**: `#374151`
- **Gray 900**: `#111827`

### Status Colors
- **Success**: `#10b981` (emerald-500)
- **Warning**: `#f59e0b` (amber-500)
- **Error**: `#ef4444` (red-500)
- **Info**: `#3b82f6` (blue-500)

## Accessibility Standards

### Focus Management
- **Visible Focus**: All interactive elements must have visible focus states
- **Keyboard Navigation**: Full keyboard accessibility
- **Screen Reader**: Proper ARIA labels and descriptions

### ARIA Attributes
```tsx
<input
  aria-label="Search employees"
  aria-describedby="search-help"
  className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
/>
```

### Error Handling
```tsx
<div>
  <input
    aria-invalid={hasError}
    aria-describedby={hasError ? "error-message" : undefined}
    className={`w-full px-3 py-1 border rounded-md text-sm focus:outline-none focus:ring-2 focus:border-transparent ${
      hasError 
        ? 'border-red-300 focus:ring-red-500' 
        : 'border-gray-300 focus:ring-primary'
    }`}
  />
  {hasError && (
    <p id="error-message" className="mt-1 text-sm text-red-600">
      {errorMessage}
    </p>
  )}
</div>
```

## Implementation Examples

### Search Card Input
```tsx
<div className="flex items-center gap-3">
  <div className="flex-1">
    <input
      type="text"
      placeholder="Search employees..."
      className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
    />
  </div>
  <div className="flex items-center gap-2">
    <select className="w-48 px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
      <option value="">All Departments</option>
      {/* Options */}
    </select>
    <button className="px-2 py-1 bg-primary text-white rounded text-sm">
      Search
    </button>
  </div>
</div>
```

### Comment Input Footer
```tsx
<div className="flex items-center gap-3">
  <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
    JR
  </div>
  <div className="flex-1">
    <input
      type="text"
      placeholder="Reply in thread"
      className="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
    />
  </div>
  <div className="flex items-center gap-2">
    <select className="w-48 px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
      <option value="">Session</option>
      {/* Options */}
    </select>
    <button className="px-2 py-1 bg-primary text-white rounded text-sm">
      Send
    </button>
  </div>
</div>
```

## Migration Checklist

### Before Implementation
- [ ] Audit existing form elements for height inconsistencies
- [ ] Identify all input fields, dropdowns, and buttons
- [ ] Document current styling patterns

### During Implementation
- [ ] Update all input fields to use `py-1` instead of `py-2`
- [ ] Standardize dropdown heights to match inputs
- [ ] Ensure button heights align with form elements
- [ ] Test focus states and accessibility
- [ ] Verify responsive behavior

### After Implementation
- [ ] Test all form interactions
- [ ] Verify visual alignment across components
- [ ] Check accessibility compliance
- [ ] Update component documentation
- [ ] Train team on new standards

## Related Documentation
- [Button Standards](./BUTTON_STANDARDS.md)
- [Complete Standards](./COMPLETE_STANDARDS.md)
- [Search Card Standards](./SEARCH_CARD_STANDARDS.md)

## Version History
- **v1.0** - Initial input field standards
- **v1.1** - Added dropdown standards and accessibility guidelines
- **v1.2** - Standardized heights across all form elements

