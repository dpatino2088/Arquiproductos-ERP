# UI Implementation Checklists

## WCAG 2.2 AA Accessibility ♿
- [ ] **Text Contrast**: 4.5:1 minimum ratio for all text
- [ ] **Non-text Contrast**: 3:1 minimum ratio for UI components and borders
- [ ] **Focus Indicators**: Primary teal focus rings (`focus:ring-primary/20`) - NEVER blue
- [ ] **ARIA Roles**: `role="tab"`, `aria-selected`, `aria-label` where needed
- [ ] **Keyboard Navigation**: Full support (Enter/Space/Escape/Tab)
- [ ] **Screen Readers**: Compatible with assistive technologies
- [ ] **Status Colors**: Green 700 (#15803d) for Active/Success - NOT teal

## Design System Compliance 🎨
- [ ] **Status Colors**: Green for success, Red for error, Blue for info, Amber for warning
- [ ] **Card Styling**: `bg-white border border-gray-200 rounded-lg`
- [ ] **Hover States**: `hover:bg-gray-50` for interactive elements
- [ ] **Progress Bars**: `bg-gray-200` background (NOT `bg-muted`)
- [ ] **Typography**: Use semantic classes (`text-muted-foreground`, `text-title`, etc.)
- [ ] **No Hardcoded Values**: All colors via design tokens and Tailwind classes
- [ ] **Sidebar Navigation**: Microsoft Teams-style square backgrounds with left borders
- [ ] **Icon Positioning**: All sidebar icons positioned exactly 17px from left border
- [ ] **Logo Positioning**: Logo at 13px, brand text at 52px from left border
- [ ] **Button Heights**: Standard 36px, Home button 40px to match secondary navbar
- [ ] **Focus Ring Consistency**: Primary teal across ALL inputs

## Selected Tab Styling 🎯
- [ ] **Font Weight**: `font-semibold` for active, `font-normal` for inactive
- [ ] **Bottom Border**: `borderBottom: '2px solid var(--teal-700)'` for active tabs
- [ ] **Background**: `bg-white` for active, `hover:bg-white/50` for inactive
- [ ] **WCAG Compliance**: Border color meets 3:1 contrast against both backgrounds

## Performance 🚀
- [ ] **CSS Bundle**: < 70KB gzipped
- [ ] **Code Splitting**: Lazy load non-critical components
- [ ] **Image Optimization**: Lazy loading and proper formats
- [ ] **Core Web Vitals**: LCP < 2.5s, CLS < 0.1, INP < 200ms

## Theme System 🌈
- [ ] **HSL Variables**: All colors in HSL format for Tailwind compatibility
- [ ] **Persistence**: Theme preferences saved to localStorage
- [ ] **No Hardcoded Colors**: ALL colors via CSS custom properties
- [ ] **Primary Color**: Teal 700 (#008383) as brand primary
- [ ] **Status Semantics**: Proper color-meaning associations

## Component Library 📦
- [ ] **Consistent API**: Props follow established patterns
- [ ] **Accessibility Built-in**: ARIA attributes and keyboard support
- [ ] **Design System**: Components use approved tokens and classes
- [ ] **Error Boundaries**: Graceful failure handling
- [ ] **TypeScript**: Full type safety and IntelliSense support
