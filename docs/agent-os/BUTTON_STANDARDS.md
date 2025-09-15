# RHEMO Frontend - Button Standards

## Overview
This document defines the complete button standards for the RHEMO frontend application, ensuring consistency across all pages and components.

## Table of Contents
1. [Button Sizes](#button-sizes)
2. [Button Types](#button-types)
3. [Button Colors](#button-colors)
4. [Button Icons](#button-icons)
5. [Button States](#button-states)
6. [Implementation Examples](#implementation-examples)
7. [Accessibility Guidelines](#accessibility-guidelines)

---

## Button Sizes

### Standard Button Sizes
All buttons in the application must use these standardized sizes:

```css
/* Primary Action Buttons (Add, Create, Save, etc.) */
.btn-primary {
  @apply flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm;
  background-color: var(--teal-brand-hex);
}

/* Secondary Action Buttons (Cancel, Close, etc.) */
.btn-secondary {
  @apply px-2 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors;
}

/* Small Action Buttons (Reply, Edit, etc.) */
.btn-small {
  @apply px-2 py-1 rounded text-xs transition-colors;
}

/* Icon-only Buttons */
.btn-icon {
  @apply p-1 text-gray-400 hover:text-gray-600 transition-colors;
}
```

### Size Specifications
- **Padding**: `px-2 py-1` (8px horizontal, 4px vertical)
- **Border Radius**: `rounded` (4px)
- **Font Size**: `text-sm` (14px) for primary actions, `text-xs` (12px) for small actions
- **Gap**: `gap-2` (8px) between icon and text

---

## Button Types

### 1. Primary Action Buttons
Used for main actions like "Add", "Create", "Save", "Submit"

```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Comment
</button>
```

### 2. Secondary Action Buttons
Used for secondary actions like "Cancel", "Close", "Reset"

```tsx
<button className="px-2 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors">
  Cancel
</button>
```

### 3. Small Action Buttons
Used for inline actions like "Reply", "Edit", "Delete"

```tsx
<button className="px-2 py-1 bg-primary text-white rounded text-xs hover:bg-primary/90 transition-colors">
  Reply
</button>
```

### 4. Icon-Only Buttons
Used for actions that only need an icon

```tsx
<button className="p-1 text-gray-400 hover:text-gray-600 transition-colors" title="Add comment">
  <MessageSquare className="w-4 h-4" />
</button>
```

---

## Button Colors

### Primary Colors
```css
/* Primary Brand Color */
--teal-brand-hex: #008383;  /* Use for primary actions */

/* Secondary Colors */
--gray-200: #e5e7eb;        /* Secondary button background */
--gray-700: #374151;        /* Secondary button text */
--gray-400: #9ca3af;        /* Icon button color */
--gray-600: #4b5563;        /* Icon button hover color */
```

### Color Usage Guidelines
- **Primary Actions**: Use `var(--teal-brand-hex)` for main actions
- **Secondary Actions**: Use `bg-gray-200 text-gray-700` for secondary actions
- **Icon Buttons**: Use `text-gray-400 hover:text-gray-600` for icon-only buttons
- **Disabled States**: Use `opacity-50 cursor-not-allowed` for disabled buttons

---

## Button Icons

### Icon Specifications
- **Size**: `14px x 14px` for primary buttons, `16px x 16px` for icon-only buttons
- **Style**: `style={{ width: '14px', height: '14px' }}` for primary buttons
- **Class**: `className="w-4 h-4"` for icon-only buttons

### Common Icons
```tsx
// Primary Action Icons
<Plus style={{ width: '14px', height: '14px' }} />        // Add, Create
<Check style={{ width: '14px', height: '14px' }} />       // Save, Confirm
<Edit3 style={{ width: '14px', height: '14px' }} />       // Edit, Modify

// Secondary Action Icons
<X style={{ width: '14px', height: '14px' }} />           // Cancel, Close
<Trash2 style={{ width: '14px', height: '14px' }} />      // Delete, Remove

// Icon-Only Buttons
<MessageSquare className="w-4 h-4" />                     // Comment, Message
<MoreVertical className="w-4 h-4" />                      // Menu, Options
<Eye className="w-4 h-4" />                               // View, Preview
```

---

## Button States

### Normal State
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Comment
</button>
```

### Hover State
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:bg-primary/90" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Comment
</button>
```

### Disabled State
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}
        disabled={!isValid}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Comment
</button>
```

### Loading State
```tsx
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}
        disabled={isLoading}>
  {isLoading ? (
    <div className="w-3 h-3 border-2 border-white border-t-transparent rounded-full animate-spin" />
  ) : (
    <Plus style={{ width: '14px', height: '14px' }} />
  )}
  {isLoading ? 'Adding...' : 'Add Comment'}
</button>
```

---

## Implementation Examples

### Form Buttons
```tsx
// Form with primary and secondary actions
<div className="flex justify-end gap-2">
  <button
    onClick={handleCancel}
    className="px-2 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors"
  >
    Cancel
  </button>
  <button
    onClick={handleSave}
    disabled={!isValid}
    className="px-2 py-1 bg-primary text-white rounded text-sm hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
  >
    Save
  </button>
</div>
```

### Action Buttons in Tables
```tsx
// Table row actions
<div className="flex items-center gap-1">
  <button 
    onClick={() => handleView(record.id)}
    className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
    title="View details"
  >
    <Eye className="w-4 h-4" />
  </button>
  <button 
    onClick={() => handleEdit(record.id)}
    className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
    title="Edit record"
  >
    <Edit3 className="w-4 h-4" />
  </button>
  <button 
    onClick={() => handleDelete(record.id)}
    className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
    title="Delete record"
  >
    <Trash2 className="w-4 h-4" />
  </button>
</div>
```

### Header Action Buttons
```tsx
// Page header with primary action
<div className="flex items-center justify-between">
  <h3 className="text-lg font-semibold text-gray-900">Comments</h3>
  <button
    onClick={handleAdd}
    className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm"
    style={{ backgroundColor: 'var(--teal-brand-hex)' }}
  >
    <Plus style={{ width: '14px', height: '14px' }} />
    Add Comment
  </button>
</div>
```

---

## Accessibility Guidelines

### Required Attributes
- **`title`**: Always provide a title attribute for icon-only buttons
- **`disabled`**: Use proper disabled state for non-interactive buttons
- **`aria-label`**: Provide aria-label for buttons without visible text

### Keyboard Navigation
- All buttons must be focusable with Tab key
- Use `focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2` for focus states
- Ensure sufficient color contrast (WCAG 2.2 AA compliant)

### Screen Reader Support
```tsx
// Icon-only button with proper accessibility
<button 
  className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
  title="Add comment"
  aria-label="Add comment to this record"
>
  <MessageSquare className="w-4 h-4" />
</button>
```

---

## Migration Checklist

When updating existing buttons to follow these standards:

- [ ] Update button padding to `px-2 py-1`
- [ ] Update border radius to `rounded`
- [ ] Update font size to `text-sm` or `text-xs`
- [ ] Add proper icon sizing (`14px x 14px` for primary, `16px x 16px` for icon-only)
- [ ] Use `var(--teal-brand-hex)` for primary actions
- [ ] Add proper hover states with `transition-colors`
- [ ] Add disabled states with `opacity-50 cursor-not-allowed`
- [ ] Add `title` attributes for icon-only buttons
- [ ] Test keyboard navigation and screen reader compatibility

---

## Common Patterns

### Button Groups
```tsx
// Horizontal button group
<div className="flex gap-2">
  <button className="px-2 py-1 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors">
    Cancel
  </button>
  <button className="px-2 py-1 bg-primary text-white rounded text-sm hover:bg-primary/90 transition-colors">
    Save
  </button>
</div>
```

### Icon with Text
```tsx
// Primary action with icon and text
<button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" 
        style={{ backgroundColor: 'var(--teal-brand-hex)' }}>
  <Plus style={{ width: '14px', height: '14px' }} />
  Add Employee
</button>
```

### Icon Only
```tsx
// Icon-only action
<button className="p-1 text-gray-400 hover:text-gray-600 transition-colors" title="Edit">
  <Edit3 className="w-4 h-4" />
</button>
```

---

*This document is part of the RHEMO Frontend Design System. For questions or updates, refer to the complete standards documentation.*

