# Instruction: Hooks and Helpers Setup

## Overview

Implement a comprehensive set of custom hooks and utility functions that follow DRY principles and provide reusable functionality across the application. This setup should enhance developer productivity and maintain code consistency.

## Core Requirements

### 1. Custom Hooks

- API-related hooks (useApiQuery, useApiMutation)
- UX enhancement hooks (useRouteFocus, usePageMeta)
- Business logic hooks (usePermissions, useAuth)
- Performance optimization hooks

### 2. Utility Functions

- Type-safe utilities
- Performance utilities
- Formatting utilities
- Validation utilities

### 3. Helper Functions

- Common business logic
- Data transformation
- Error handling
- Configuration management

## Implementation Steps

### Step 1: API Hooks

```typescript
// src/hooks/api/useApiQuery.ts
import { useQuery, UseQueryOptions } from "@tanstack/react-query";
import { apiClient } from "@/services/apiClient";

interface UseApiQueryOptions<TData, TError>
  extends Omit<UseQueryOptions<TData, TError>, "queryFn"> {
  url: string;
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  data?: any;
  headers?: Record<string, string>;
}

export function useApiQuery<TData = any, TError = any>({
  url,
  method = "GET",
  data,
  headers,
  ...options
}: UseApiQueryOptions<TData, TError>) {
  return useQuery({
    queryFn: async () => {
      const response = await apiClient.request({
        method,
        url,
        data,
        headers,
      });
      return response.data;
    },
    ...options,
  });
}

// src/hooks/api/useApiMutation.ts
import { useMutation, UseMutationOptions } from "@tanstack/react-query";
import { apiClient } from "@/services/apiClient";

interface UseApiMutationOptions<TData, TError, TVariables>
  extends Omit<UseMutationOptions<TData, TError, TVariables>, "mutationFn"> {
  url: string;
  method?: "POST" | "PUT" | "PATCH" | "DELETE";
  headers?: Record<string, string>;
}

export function useApiMutation<TData = any, TError = any, TVariables = any>({
  url,
  method = "POST",
  headers,
  ...options
}: UseApiMutationOptions<TData, TError, TVariables>) {
  return useMutation({
    mutationFn: async (variables: TVariables) => {
      const response = await apiClient.request({
        method,
        url,
        data: variables,
        headers,
      });
      return response.data;
    },
    ...options,
  });
}
```

### Step 2: UX Enhancement Hooks

```typescript
// src/hooks/useRouteFocus.ts
import { useEffect, useRef } from "react";
import { useLocation } from "react-router-dom";

export function useRouteFocus() {
  const location = useLocation();
  const headingRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    // Focus the first h1 element when route changes
    if (headingRef.current) {
      headingRef.current.focus();
    } else {
      // Fallback: find first h1 in the page
      const firstHeading = document.querySelector("h1");
      if (firstHeading) {
        firstHeading.focus();
      }
    }
  }, [location.pathname]);

  return headingRef;
}

// src/hooks/usePageMeta.ts
import { useEffect } from "react";

interface PageMetaOptions {
  title: string;
  description?: string;
  keywords?: string;
  ogImage?: string;
  ogUrl?: string;
}

export function usePageMeta({
  title,
  description,
  keywords,
  ogImage,
  ogUrl,
}: PageMetaOptions) {
  useEffect(() => {
    // Update document title
    document.title = title;

    // Update meta description
    let metaDescription = document.querySelector('meta[name="description"]');
    if (!metaDescription) {
      metaDescription = document.createElement("meta");
      metaDescription.setAttribute("name", "description");
      document.head.appendChild(metaDescription);
    }
    metaDescription.setAttribute("content", description || "");

    // Update meta keywords
    if (keywords) {
      let metaKeywords = document.querySelector('meta[name="keywords"]');
      if (!metaKeywords) {
        metaKeywords = document.createElement("meta");
        metaKeywords.setAttribute("name", "keywords");
        document.head.appendChild(metaKeywords);
      }
      metaKeywords.setAttribute("content", keywords);
    }

    // Update Open Graph tags
    if (ogImage) {
      let ogImageMeta = document.querySelector('meta[property="og:image"]');
      if (!ogImageMeta) {
        ogImageMeta = document.createElement("meta");
        ogImageMeta.setAttribute("property", "og:image");
        document.head.appendChild(ogImageMeta);
      }
      ogImageMeta.setAttribute("content", ogImage);
    }

    if (ogUrl) {
      let ogUrlMeta = document.querySelector('meta[property="og:url"]');
      if (!ogUrlMeta) {
        ogUrlMeta = document.createElement("meta");
        ogUrlMeta.setAttribute("property", "og:url");
        document.head.appendChild(ogUrlMeta);
      }
      ogUrlMeta.setAttribute("content", ogUrl);
    }

    // Update og:title and og:description
    let ogTitle = document.querySelector('meta[property="og:title"]');
    if (!ogTitle) {
      ogTitle = document.createElement("meta");
      ogTitle.setAttribute("property", "og:title");
      document.head.appendChild(ogTitle);
    }
    ogTitle.setAttribute("content", title);

    if (description) {
      let ogDescription = document.querySelector(
        'meta[property="og:description"]'
      );
      if (!ogDescription) {
        ogDescription = document.createElement("meta");
        ogDescription.setAttribute("property", "og:description");
        document.head.appendChild(ogDescription);
      }
      ogDescription.setAttribute("content", description);
    }

    // Cleanup function to restore original title if needed
    return () => {
      // You could restore a default title here if needed
    };
  }, [title, description, keywords, ogImage, ogUrl]);
}
```

### Step 3: Business Logic Hooks

```typescript
// src/hooks/usePermissions.ts
import { useAuthStore } from "@/stores/authStore";

export function usePermissions() {
  const { user } = useAuthStore();

  const can = (permission: string): boolean => {
    if (!user) return false;

    // Define permission matrix
    const permissions: Record<string, string[]> = {
      admin: ["read", "write", "delete", "admin"],
      user: ["read", "write"],
      guest: ["read"],
    };

    const userPermissions = permissions[user.role] || [];
    return userPermissions.includes(permission);
  };

  const hasRole = (role: string): boolean => {
    return user?.role === role;
  };

  const isOwner = (resourceUserId: string): boolean => {
    return user?.id === resourceUserId;
  };

  return {
    can,
    hasRole,
    isOwner,
    user,
  };
}

// src/hooks/useLocalStorage.ts
import { useState, useEffect } from "react";

export function useLocalStorage<T>(key: string, initialValue: T) {
  // Get from local storage then parse stored json or return initialValue
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(error);
      return initialValue;
    }
  });

  // Return a wrapped version of useState's setter function that persists the new value to localStorage
  const setValue = (value: T | ((val: T) => T)) => {
    try {
      // Allow value to be a function so we have the same API as useState
      const valueToStore =
        value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(error);
    }
  };

  return [storedValue, setValue] as const;
}
```

### Step 4: Utility Functions

```typescript
// src/lib/utils.ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: Date | string): string {
  return new Intl.DateTimeFormat("es-ES", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(date));
}

export function formatCurrency(amount: number, currency = "USD"): string {
  return new Intl.NumberFormat("es-ES", {
    style: "currency",
    currency,
  }).format(amount);
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

// src/lib/formUtils.ts
import { zodResolver } from "@hookform/resolvers/zod";
import type { Resolver } from "react-hook-form";

export function createZodResolver<T extends Record<string, any>>(
  schema: any
): Resolver<T> {
  return zodResolver(schema);
}

export function getFieldError(
  errors: any,
  fieldName: string
): string | undefined {
  const fieldError = errors[fieldName];
  return fieldError?.message;
}

export function isFieldValid(errors: any, fieldName: string): boolean {
  return !errors[fieldName];
}

export function getFormErrors(errors: any): string[] {
  return Object.values(errors)
    .map((error: any) => error?.message)
    .filter(Boolean);
}

// src/lib/idUtils.ts
import { v4 as uuidv4, v5 as uuidv5 } from "uuid";

export function generateId(): string {
  return uuidv4();
}

export function generateNamespaceId(
  name: string,
  namespace = "remo-app"
): string {
  return uuidv5(name, namespace);
}

export function generateShortId(): string {
  return uuidv4().substring(0, 8);
}

export function generateSlug(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export function generateFileName(
  originalName: string,
  extension: string
): string {
  const timestamp = Date.now();
  const randomId = generateShortId();
  return `${timestamp}-${randomId}.${extension}`;
}
```

## Best Practices

### 1. Hook Design

- Follow React hooks naming conventions
- Keep hooks focused and single-purpose
- Use proper dependency arrays
- Handle cleanup and side effects

### 2. Utility Functions

- Make functions pure when possible
- Provide proper TypeScript types
- Include JSDoc documentation
- Handle edge cases gracefully

### 3. Performance

- Use useMemo and useCallback appropriately
- Avoid unnecessary re-renders
- Implement proper memoization
- Optimize expensive operations

### 4. Testing

- Test hooks in isolation
- Mock external dependencies
- Test edge cases and error conditions
- Ensure proper cleanup

## Quality Gates

### 1. Functionality

- All hooks work correctly
- Utilities handle edge cases
- Error handling is implemented
- Performance is optimized

### 2. Type Safety

- TypeScript types are correct
- Generic types are properly constrained
- No type errors or warnings
- Proper return types

### 3. Performance

- Hooks don't cause unnecessary re-renders
- Utilities are efficient
- Memory leaks are prevented
- Bundle size is optimized

### 4. Maintainability

- Code is well-documented
- Functions are single-purpose
- Naming is clear and consistent
- Error handling is comprehensive

## Next Steps

After completing hooks and helpers setup:

1. Add comprehensive testing
2. Implement performance monitoring
3. Add error tracking
4. Create usage examples
5. Document best practices
