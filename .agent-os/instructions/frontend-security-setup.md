# Instruction: Frontend Security Setup

## Overview

Implement minimum security controls for the frontend application, including authentication, authorization, and basic security measures. This setup should provide a secure foundation while maintaining good user experience.

## Core Requirements

### 1. Authentication Security

- Secure token storage and management
- Token refresh mechanism
- Session timeout handling
- Secure logout process

### 2. Authorization Controls

- Role-based access control (RBAC)
- Route-level protection
- Component-level permissions
- API endpoint protection

### 3. Input Validation

- Form input sanitization
- XSS prevention
- CSRF protection
- Input length limits

## Implementation Steps

### Step 1: Authentication Store

```typescript
// src/stores/authStore.ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface User {
  id: string;
  email: string;
  name: string;
  role: "user" | "admin";
  createdAt: string;
  updatedAt: string;
}

interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  authStatus: "idle" | "loading" | "authenticated" | "unauthenticated";
  isAuthenticated: boolean;

  // Actions
  setAuth: (user: User, accessToken: string, refreshToken?: string) => void;
  setToken: (accessToken: string) => void;
  clearAuth: () => void;
  updateUser: (user: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      authStatus: "idle",
      isAuthenticated: false,

      setAuth: (user, accessToken, refreshToken) =>
        set({
          user,
          accessToken,
          refreshToken,
          authStatus: "authenticated",
          isAuthenticated: true,
        }),

      setToken: (accessToken) =>
        set({
          accessToken,
          authStatus: "authenticated",
          isAuthenticated: true,
        }),

      clearAuth: () =>
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          authStatus: "unauthenticated",
          isAuthenticated: false,
        }),

      updateUser: (userData) =>
        set((state) => ({
          user: state.user ? { ...state.user, ...userData } : null,
        })),
    }),
    {
      name: "auth-storage",
      partialize: (state) => ({
        refreshToken: state.refreshToken,
        user: state.user,
      }),
    }
  )
);
```

### Step 2: API Client Security

```typescript
// src/services/apiClient.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from "axios";
import { useAuthStore } from "@/stores/authStore";
import { generateId } from "@/lib/idUtils";

class ApiClient {
  private client: AxiosInstance;
  private refreshPromise: Promise<string> | null = null;

  constructor() {
    this.client = axios.create({
      baseURL: import.meta.env.VITE_API_URL,
      timeout: 10000,
      headers: {
        "Content-Type": "application/json",
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        // Add request ID for tracking
        config.headers["X-Request-ID"] = generateId();

        // Add authorization header
        const token = useAuthStore.getState().accessToken;
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }

        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response: AxiosResponse) => response,
      async (error) => {
        const originalRequest = error.config;

        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;

          try {
            const newToken = await this.refreshToken();
            originalRequest.headers.Authorization = `Bearer ${newToken}`;
            return this.client(originalRequest);
          } catch (refreshError) {
            useAuthStore.getState().clearAuth();
            return Promise.reject(refreshError);
          }
        }

        if (error.response?.status === 403) {
          // Handle forbidden access
          console.warn("Access forbidden:", error.response.data);
        }

        if (error.response?.status === 429) {
          // Handle rate limiting
          const retryAfter = error.response.headers["retry-after"];
          console.warn("Rate limited, retry after:", retryAfter);
        }

        if (error.response?.status >= 500) {
          // Handle server errors
          console.error("Server error:", error.response.data);
        }

        return Promise.reject(error);
      }
    );
  }

  private async refreshToken(): Promise<string> {
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.post("/auth/refresh")
      .then((response) => {
        const { accessToken } = response.data;
        useAuthStore.getState().setToken(accessToken);
        return accessToken;
      })
      .finally(() => {
        this.refreshPromise = null;
      });

    return this.refreshPromise;
  }

  // HTTP methods with proper typing
  async get<T = any>(
    url: string,
    config?: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    return this.client.get(url, config);
  }

  async post<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    return this.client.post(url, data, config);
  }

  async put<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    return this.client.put(url, data, config);
  }

  async patch<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    return this.client.patch(url, data, config);
  }

  async delete<T = any>(
    url: string,
    config?: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    return this.client.delete(url, config);
  }
}

export const apiClient = new ApiClient();
```

### Step 3: Permission Hooks

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
```

### Step 4: Secure Components

```typescript
// src/components/SecureComponent.tsx
import React from "react";
import { usePermissions } from "@/hooks/usePermissions";

interface SecureComponentProps {
  permission: string;
  fallback?: React.ReactNode;
  children: React.ReactNode;
}

export function SecureComponent({
  permission,
  fallback,
  children,
}: SecureComponentProps) {
  const { can } = usePermissions();

  if (!can(permission)) {
    return fallback || null;
  }

  return <>{children}</>;
}

// Usage example
export function AdminPanel() {
  return (
    <SecureComponent permission="admin" fallback={<p>Access denied</p>}>
      <div>Admin content here</div>
    </SecureComponent>
  );
}
```

## Best Practices

### 1. Token Management

- Store tokens securely (httpOnly cookies preferred)
- Implement automatic token refresh
- Clear tokens on logout
- Handle token expiration gracefully

### 2. Input Validation

- Validate all user inputs
- Sanitize HTML content
- Implement CSRF tokens
- Use proper input types and constraints

### 3. Error Handling

- Don't expose sensitive information in errors
- Log security events
- Implement rate limiting
- Handle authentication failures gracefully

### 4. Access Control

- Implement principle of least privilege
- Use role-based access control
- Validate permissions on both client and server
- Audit access attempts

## Quality Gates

### 1. Authentication

- Tokens are stored securely
- Refresh mechanism works correctly
- Logout clears all sensitive data
- Session timeout is handled properly

### 2. Authorization

- Route protection works correctly
- Component-level permissions are enforced
- API calls include proper headers
- Access control is consistent

### 3. Security Headers

- CSRF protection is implemented
- XSS prevention is active
- Input validation is comprehensive
- Error messages don't leak information

### 4. Monitoring

- Security events are logged
- Failed authentication attempts are tracked
- Suspicious activity is detected
- Audit trail is maintained

## Next Steps

After completing security setup:

1. Implement advanced security features (CSP, SRI)
2. Add security monitoring and alerting
3. Implement security testing
4. Add security documentation
5. Conduct security audit
