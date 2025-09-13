# Tooltip Standards - Agent OS

## Overview
Standardized tooltip implementation for consistent user experience across all components.

## Design Principles

### 1. Interaction Method
- **ALWAYS use onClick** - Never use hover for tooltips
- **Toggle behavior** - Click to show, click again to hide
- **Event propagation** - Always use `e.stopPropagation()` to prevent parent events

### 2. Visual Standards

#### Container
```jsx
<div className="relative">
  <div 
    className="cursor-pointer"
    onClick={(e) => {
      e.stopPropagation();
      setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
    }}
  >
    {/* Trigger element (icon, button, etc.) */}
  </div>
  {activeTooltip === tooltipKey && (
    <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 bg-gray-600">
      {/* Tooltip content */}
      <div className="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-600"></div>
    </div>
  )}
</div>
```

#### Positioning
- **Position**: `absolute bottom-full left-1/2 transform -translate-x-1/2`
- **Spacing**: `mb-2` (8px margin bottom)
- **Z-index**: `z-50` for proper layering

#### Styling
- **Padding**: `px-2 py-1` (8px horizontal, 4px vertical)
- **Text**: `text-white text-xs` (white text, 12px size)
- **Background**: Dynamic based on context (see Color Standards)
- **Border radius**: `rounded` (4px radius)
- **Text wrapping**: `whitespace-nowrap` for single-line content

#### Arrow/Pointer
- **Position**: `absolute top-full left-1/2 transform -translate-x-1/2`
- **Size**: `w-0 h-0 border-l-4 border-r-4 border-t-4`
- **Colors**: `border-transparent` + dynamic `border-t-{color}`

### 3. Color Standards

#### Status-based Colors
```jsx
// Success/Approved
bg-green-600 + border-t-green-600

// Error/Alert/Incident
bg-red-600 + border-t-red-600

// Warning/Pending
bg-orange-600 + border-t-orange-600

// Info/Early
bg-blue-600 + border-t-blue-600

// Neutral/Scheduled
bg-gray-600 + border-t-gray-600 (or bg-gray-400 + border-t-gray-400)
```

### 4. State Management

#### Tooltip Key Generation
```jsx
const tooltipKey = `{component}-{id}-{context}`;
// Examples:
// `flag-${recordId}-${employeeName}`
// `schedule-clockin-${recordId}`
// `approval-${sessionId}-${recordId}`
```

#### Active State
```jsx
const [activeTooltip, setActiveTooltip] = useState<string | null>(null);

// Toggle logic
setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
```

### 5. Content Guidelines

#### Text Content
- **Concise**: Keep messages short and direct
- **Clear**: Use simple, understandable language
- **Consistent**: Use standard terminology across the app

#### Multi-line Content
```jsx
<div className="space-y-1">
  {items.map((item, index) => (
    <div key={index}>{item}</div>
  ))}
</div>
```

## Implementation Examples

### 1. Schedule Tooltip (Status-based colors)
```jsx
const formatActualVsScheduled = (actual, scheduled, tooltipId) => {
  const tooltipKey = `schedule-${tooltipId}`;
  const isOnTime = actual === scheduled;
  const isLate = actual > scheduled;
  
  return (
    <div className="relative">
      <div 
        className="cursor-pointer"
        onClick={(e) => {
          e.stopPropagation();
          setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
        }}
      >
        <ScheduleIcon className={`w-3 h-3 ${
          isOnTime ? 'text-green-600' : isLate ? 'text-red-600' : 'text-blue-600'
        }`} />
      </div>
      {activeTooltip === tooltipKey && (
        <div className={`absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 ${
          isOnTime ? 'bg-green-600' : isLate ? 'bg-red-600' : 'bg-blue-600'
        }`}>
          {isOnTime ? `On time (scheduled: ${scheduled})` : 
           isLate ? `Late (scheduled: ${scheduled})` : 
           `Early (scheduled: ${scheduled})`}
          <div className={`absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent ${
            isOnTime ? 'border-t-green-600' : isLate ? 'border-t-red-600' : 'border-t-blue-600'
          }`}></div>
        </div>
      )}
    </div>
  );
};
```

### 2. Flag Tooltip (Multi-content)
```jsx
const renderFlagIcon = (record, tooltipId) => {
  const flags = getRecordFlags(record);
  const tooltipKey = `flag-${tooltipId}-${record.employeeName.replace(/\s+/g, '-')}`;
  const hasIncidents = flags.some(flag => flag.type === 'incident');
  
  return (
    <div className="relative">
      <div 
        className="flex items-center gap-1 cursor-pointer"
        onClick={(e) => {
          e.stopPropagation();
          setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
        }}
      >
        <Flag className={`w-4 h-4 ${hasIncidents ? 'text-red-600' : 'text-green-600'}`} />
        {hasResolved && <Check className="w-3 h-3 text-green-600" />}
      </div>
      {activeTooltip === tooltipKey && (
        <div className={`absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 ${
          hasIncidents ? 'bg-red-600' : 'bg-green-600'
        }`}>
          <div className="space-y-1">
            {flags.map((flag, index) => (
              <div key={index}>{flag.message}</div>
            ))}
          </div>
          <div className={`absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent ${
            hasIncidents ? 'border-t-red-600' : 'border-t-green-600'
          }`}></div>
        </div>
      )}
    </div>
  );
};
```

## Global Click Handler (Optional)

For better UX, implement a global click handler to close tooltips when clicking outside:

```jsx
useEffect(() => {
  const handleClickOutside = () => {
    setActiveTooltip(null);
  };

  document.addEventListener('click', handleClickOutside);
  return () => document.removeEventListener('click', handleClickOutside);
}, []);
```

## Accessibility Considerations

### ARIA Labels
```jsx
<div 
  className="cursor-pointer"
  onClick={handleClick}
  aria-label="Show details"
  role="button"
  tabIndex={0}
>
```

### Keyboard Support
```jsx
onKeyDown={(e) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    handleClick(e);
  }
}}
```

## Testing Guidelines

### Visual Testing
- [ ] Tooltip appears on click
- [ ] Tooltip disappears on second click
- [ ] Tooltip has correct colors based on status
- [ ] Arrow points correctly to trigger element
- [ ] Text is readable and properly formatted

### Interaction Testing
- [ ] Click event doesn't propagate to parent elements
- [ ] Only one tooltip visible at a time
- [ ] Tooltip closes when clicking elsewhere (if global handler implemented)

### Responsive Testing
- [ ] Tooltip doesn't overflow viewport boundaries
- [ ] Text remains readable on mobile devices
- [ ] Touch interactions work properly

## Migration Checklist

When updating existing tooltips:

1. [ ] Change from `onMouseEnter/onMouseLeave` to `onClick`
2. [ ] Add `e.stopPropagation()` to click handler
3. [ ] Update styling to match standards (`px-2 py-1`, `rounded`)
4. [ ] Ensure proper color usage based on context
5. [ ] Test tooltip positioning and arrow alignment
6. [ ] Verify unique tooltip keys to prevent conflicts

---

## 📚 Related Standards

- **Complete Standards**: See `COMPLETE_STANDARDS.md` for master design system documentation
- **Search Card Standards**: See `SEARCH_CARD_STANDARDS.md` for button active states and search card implementation
- **Pagination Standards**: See `PAGINATION_STANDARDS.md` for pagination button styling
- **Component Standards**: See `COMPREHENSIVE_PRODUCT_ANALYSIS.md` for overall design system guidelines

---

**Last Updated**: January 2025  
**Version**: 1.0  
**Status**: Active Standard
