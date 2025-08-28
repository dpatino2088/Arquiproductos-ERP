# Instruction: Performance Setup

## Overview

Implement comprehensive performance optimizations to meet Core Web Vitals targets and provide excellent user experience. This setup should include code splitting, lazy loading, caching strategies, and performance monitoring.

## Core Requirements

### 1. Core Web Vitals

- First Contentful Paint (FCP) < 1.8s
- Largest Contentful Paint (LCP) < 2.5s
- First Input Delay (FID) < 100ms
- Cumulative Layout Shift (CLS) < 0.1

### 2. Performance Optimizations

- Code splitting and lazy loading
- Bundle optimization
- Image optimization
- Caching strategies

### 3. Performance Monitoring

- Web Vitals tracking
- Performance metrics
- User experience monitoring
- Performance budgets

## Implementation Steps

### Step 1: Code Splitting and Lazy Loading

```typescript
// src/routes/router.tsx
import { lazy, Suspense } from "react";
import { createBrowserRouter } from "react-router-dom";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";

// Lazy load route components
const Home = lazy(() => import("./pages/Home"));
const Login = lazy(() => import("./pages/Login"));
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Admin = lazy(() => import("./pages/Admin"));

// Loading component for Suspense boundaries
function RouteLoading() {
  return (
    <div className="flex items-center justify-center min-h-screen">
      <LoadingSpinner size="lg" />
    </div>
  );
}

export const router = createBrowserRouter([
  {
    path: "/",
    element: (
      <Suspense fallback={<RouteLoading />}>
        <PublicLayout />
      </Suspense>
    ),
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<RouteLoading />}>
            <Home />
          </Suspense>
        ),
      },
      {
        path: "login",
        element: (
          <Suspense fallback={<RouteLoading />}>
            <Login />
          </Suspense>
        ),
      },
    ],
  },
  {
    path: "/dashboard",
    element: (
      <Suspense fallback={<RouteLoading />}>
        <AuthLayout />
      </Suspense>
    ),
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<RouteLoading />}>
            <Dashboard />
          </Suspense>
        ),
      },
    ],
  },
]);

// src/components/LazyComponent.tsx
import React, { Suspense, lazy } from "react";

interface LazyComponentProps {
  component: () => Promise<{ default: React.ComponentType<any> }>;
  fallback?: React.ReactNode;
  props?: Record<string, any>;
}

export function LazyComponent({
  component,
  fallback = <div>Loading...</div>,
  props = {},
}: LazyComponentProps) {
  const LazyComponent = lazy(component);

  return (
    <Suspense fallback={fallback}>
      <LazyComponent {...props} />
    </Suspense>
  );
}
```

### Step 2: Bundle Optimization

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    target: "es2015",
    minify: "terser",
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom"],
          router: ["react-router-dom"],
          query: ["@tanstack/react-query"],
          ui: ["@headlessui/react", "@heroicons/react"],
        },
      },
    },
    chunkSizeWarningLimit: 1000,
  },
  optimizeDeps: {
    include: ["react", "react-dom", "react-router-dom"],
  },
});

// src/lib/bundleAnalyzer.ts
export function analyzeBundle() {
  if (import.meta.env.DEV) {
    import("rollup-plugin-visualizer").then(({ visualizer }) => {
      console.log("Bundle analyzer available in development mode");
    });
  }
}
```

### Step 3: Image Optimization

```typescript
// src/components/ui/OptimizedImage.tsx
import React, { useState, useCallback } from "react";
import { cn } from "@/lib/utils";

interface OptimizedImageProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  className?: string;
  placeholder?: string;
  loading?: "lazy" | "eager";
  onLoad?: () => void;
  onError?: () => void;
}

export function OptimizedImage({
  src,
  alt,
  width,
  height,
  className,
  placeholder,
  loading = "lazy",
  onLoad,
  onError,
}: OptimizedImageProps) {
  const [isLoaded, setIsLoaded] = useState(false);
  const [hasError, setHasError] = useState(false);

  const handleLoad = useCallback(() => {
    setIsLoaded(true);
    onLoad?.();
  }, [onLoad]);

  const handleError = useCallback(() => {
    setHasError(true);
    onError?.();
  }, [onError]);

  if (hasError) {
    return (
      <div
        className={cn(
          "bg-gray-200 flex items-center justify-center",
          className
        )}
      >
        <span className="text-gray-500 text-sm">Image failed to load</span>
      </div>
    );
  }

  return (
    <div className={cn("relative overflow-hidden", className)}>
      {placeholder && !isLoaded && (
        <div className="absolute inset-0 bg-gray-200 animate-pulse" />
      )}

      <img
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading={loading}
        onLoad={handleLoad}
        onError={handleError}
        className={cn(
          "transition-opacity duration-300",
          isLoaded ? "opacity-100" : "opacity-0"
        )}
      />
    </div>
  );
}

// src/hooks/useImagePreload.ts
import { useState, useEffect } from "react";

export function useImagePreload(src: string) {
  const [isLoaded, setIsLoaded] = useState(false);
  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    if (!src) return;

    const img = new Image();

    img.onload = () => setIsLoaded(true);
    img.onerror = () => setHasError(true);

    img.src = src;

    return () => {
      img.onload = null;
      img.onerror = null;
    };
  }, [src]);

  return { isLoaded, hasError };
}
```

### Step 4: Performance Monitoring

```typescript
// src/lib/webVitals.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from "web-vitals";

interface Metric {
  name: string;
  value: number;
  rating: "good" | "needs-improvement" | "poor";
}

function sendToAnalytics(metric: Metric) {
  // Send metrics to your analytics service
  console.log("Web Vital:", metric);

  // Example: Send to Google Analytics
  if (typeof gtag !== "undefined") {
    gtag("event", metric.name, {
      event_category: "Web Vitals",
      value: Math.round(metric.value),
      event_label: metric.rating,
    });
  }
}

export function reportWebVitals() {
  getCLS(sendToAnalytics);
  getFID(sendToAnalytics);
  getFCP(sendToAnalytics);
  getLCP(sendToAnalytics);
  getTTFB(sendToAnalytics);
}

// src/hooks/usePerformanceMonitor.ts
import { useEffect, useRef } from "react";

export function usePerformanceMonitor() {
  const observerRef = useRef<PerformanceObserver | null>(null);

  useEffect(() => {
    // Monitor long tasks
    if ("PerformanceObserver" in window) {
      observerRef.current = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.duration > 50) {
            console.warn("Long task detected:", entry);
          }
        }
      });

      observerRef.current.observe({ entryTypes: ["longtask"] });
    }

    // Monitor memory usage
    if ("memory" in performance) {
      const memory = (performance as any).memory;
      console.log("Memory usage:", {
        used: Math.round(memory.usedJSHeapSize / 1048576) + " MB",
        total: Math.round(memory.totalJSHeapSize / 1048576) + " MB",
        limit: Math.round(memory.jsHeapSizeLimit / 1048576) + " MB",
      });
    }

    return () => {
      if (observerRef.current) {
        observerRef.current.disconnect();
      }
    };
  }, []);
}

// src/lib/performanceUtils.ts
export function measurePerformance<T>(name: string, fn: () => T): T {
  const start = performance.now();
  const result = fn();
  const end = performance.now();

  console.log(`${name} took ${end - start}ms`);
  return result;
}

export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout;
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

export function throttle<T extends (...args: any[]) => any>(
  func: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle: boolean;
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}
```

### Step 5: Caching Strategies

```typescript
// src/lib/cache.ts
interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

class Cache {
  private storage = new Map<string, CacheEntry<any>>();

  set<T>(key: string, data: T, ttl: number = 5 * 60 * 1000): void {
    this.storage.set(key, {
      data,
      timestamp: Date.now(),
      ttl,
    });
  }

  get<T>(key: string): T | null {
    const entry = this.storage.get(key);

    if (!entry) return null;

    if (Date.now() - entry.timestamp > entry.ttl) {
      this.storage.delete(key);
      return null;
    }

    return entry.data;
  }

  clear(): void {
    this.storage.clear();
  }

  size(): number {
    return this.storage.size;
  }
}

export const cache = new Cache();

// src/hooks/useCache.ts
import { useState, useCallback } from "react";
import { cache } from "@/lib/cache";

export function useCache<T>(key: string, ttl: number = 5 * 60 * 1000) {
  const [data, setData] = useState<T | null>(() => cache.get<T>(key));

  const setCache = useCallback(
    (value: T) => {
      cache.set(key, value, ttl);
      setData(value);
    },
    [key, ttl]
  );

  const clearCache = useCallback(() => {
    cache.clear();
    setData(null);
  }, []);

  return { data, setCache, clearCache };
}
```

## Best Practices

### 1. Code Splitting

- Split by routes and features
- Use dynamic imports for heavy components
- Implement proper loading states
- Monitor bundle sizes

### 2. Performance Monitoring

- Track Core Web Vitals
- Monitor user experience metrics
- Set performance budgets
- Alert on performance regressions

### 3. Caching

- Implement appropriate cache TTLs
- Use memory and localStorage caching
- Clear caches when needed
- Monitor cache hit rates

### 4. Image Optimization

- Use appropriate image formats
- Implement lazy loading
- Provide placeholders
- Optimize image sizes

## Quality Gates

### 1. Core Web Vitals

- FCP < 1.8s
- LCP < 2.5s
- FID < 100ms
- CLS < 0.1

### 2. Bundle Performance

- Total bundle size < 500KB
- JavaScript bundle < 250KB
- CSS bundle < 100KB
- No duplicate dependencies

### 3. Loading Performance

- Initial page load < 2s
- Route transitions < 500ms
- Component rendering < 100ms
- Image loading < 1s

### 4. Runtime Performance

- No memory leaks
- Efficient re-renders
- Smooth animations (60fps)
- Responsive interactions

## Next Steps

After completing performance setup:

1. Implement performance testing
2. Add performance monitoring dashboard
3. Set up performance budgets
4. Optimize critical paths
5. Monitor real user metrics
