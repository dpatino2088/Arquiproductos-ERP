# Standard: Performance

## Overview

Implement performance optimizations to ensure fast loading times, smooth user interactions, and optimal resource usage.

## Core Requirements

### 1. Code Splitting

- Implement route-based code splitting
- Use React.lazy for component lazy loading
- Implement proper loading states
- Optimize bundle sizes

### 2. Memoization

- Use React.memo for expensive components
- Implement useMemo for expensive calculations
- Use useCallback for stable function references
- Optimize re-renders

### 3. Resource Optimization

- Optimize images and assets
- Implement proper caching strategies
- Use CDN for static assets
- Minimize network requests

### 4. Performance Monitoring

- Implement Web Vitals tracking
- Monitor Core Web Vitals
- Track performance metrics
- Set performance budgets

## Implementation Guidelines

### Code Splitting

```typescript
// Route-based code splitting
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Profile = lazy(() => import("./pages/Profile"));

// Component lazy loading
const ExpensiveComponent = lazy(
  () => import("./components/ExpensiveComponent")
);
```

### Memoization

```typescript
// Memoize expensive components
const ExpensiveList = React.memo(({ items, onItemClick }) => {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id} onClick={() => onItemClick(item)}>
          {item.name}
        </li>
      ))}
    </ul>
  );
});

// Memoize expensive calculations
const expensiveValue = useMemo(() => {
  return items.reduce((acc, item) => acc + item.value, 0);
}, [items]);

// Stable callback references
const handleItemClick = useCallback(
  (item) => {
    onItemClick(item);
  },
  [onItemClick]
);
```

### Performance Monitoring

```typescript
import { getCLS, getFID, getFCP, getLCP, getTTFB } from "web-vitals";

export function reportWebVitals() {
  getCLS(console.log);
  getFID(console.log);
  getFCP(console.log);
  getLCP(console.log);
  getTTFB(console.log);
}
```

## Performance Targets

- First Contentful Paint (FCP): < 1.8s
- Largest Contentful Paint (LCP): < 2.5s
- First Input Delay (FID): < 100ms
- Cumulative Layout Shift (CLS): < 0.1

## Best Practices

- Always measure performance before and after optimizations
- Use React DevTools Profiler for performance analysis
- Implement proper loading states for lazy components
- Monitor bundle sizes and implement size limits
- Use performance budgets in CI/CD
