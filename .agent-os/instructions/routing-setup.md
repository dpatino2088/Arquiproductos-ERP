# Instruction: Routing Setup

## Overview

Implement secure routing with React Router v7, including route guards, loaders, and error boundaries. This setup should provide a robust foundation for protected routes and user authentication.

## Core Requirements

### 1. Router Configuration

- Use `createBrowserRouter` for modern data routing
- Implement nested routes with layouts
- Add error boundaries per route
- Configure route loaders for data fetching

### 2. Route Protection

- Guest-only routes (public access)
- Protected routes (authentication required)
- Role-based routes (admin access)
- Redirect logic for unauthorized access

### 3. Route Loaders

- Prefetch authentication data
- Handle 401/403 responses
- Redirect to appropriate pages
- Cache authentication state

## Implementation Steps

### Step 1: Router Structure

```typescript
// src/routes/router.tsx
import { createBrowserRouter } from "react-router-dom";

export const router = createBrowserRouter([
  {
    path: "/",
    element: <PublicLayout />,
    children: [
      { index: true, element: <Home /> },
      { path: "login", element: <Login /> },
      { path: "design-system", element: <DesignSystemDemo /> },
    ],
  },
  {
    path: "/dashboard",
    element: <AuthLayout />,
    loader: dashboardLoader,
    errorElement: <DashboardError />,
    children: [{ index: true, element: <Dashboard /> }],
  },
  {
    path: "/admin",
    element: <AdminLayout />,
    loader: adminLoader,
    errorElement: <AdminError />,
    children: [{ path: "*", element: <AdminDashboard /> }],
  },
  {
    path: "*",
    element: <NotFound />,
  },
]);
```

### Step 2: Route Guards

```typescript
// src/routes/guards.ts
import { Navigate, useLocation } from "react-router-dom";
import { useAuthStore } from "@/stores/authStore";

export const guards = {
  requireAuth: (Component: React.ComponentType) => {
    return function ProtectedRoute() {
      const { isAuthenticated } = useAuthStore();
      const location = useLocation();

      if (!isAuthenticated) {
        return <Navigate to="/login" state={{ from: location }} replace />;
      }

      return <Component />;
    };
  },

  requireRole: (role: string, fallback: React.ReactElement) => {
    return function RoleProtectedRoute() {
      const { user } = useAuthStore();

      if (!user || user.role !== role) {
        return fallback;
      }

      return <Component />;
    };
  },

  requireGuest: (Component: React.ComponentType) => {
    return function GuestOnlyRoute() {
      const { isAuthenticated } = useAuthStore();

      if (isAuthenticated) {
        return <Navigate to="/dashboard" replace />;
      }

      return <Component />;
    };
  },
};
```

### Step 3: Route Loaders

```typescript
// src/routes/loaders.ts
import { redirect } from "react-router-dom";
import { queryClient } from "@/lib/queryClient";
import { useAuthStore } from "@/stores/authStore";

export async function dashboardLoader() {
  try {
    // Prefetch authentication data
    await queryClient.prefetchQuery({
      queryKey: ["auth", "me"],
      queryFn: () => fetch("/api/auth/me").then((res) => res.json()),
    });

    return null;
  } catch (error: any) {
    if (error.status === 401) {
      // Redirect to login with return URL
      const url = new URL(window.location.href);
      return redirect(`/login?returnUrl=${encodeURIComponent(url.pathname)}`);
    }

    if (error.status === 403) {
      return redirect("/forbidden");
    }

    throw error;
  }
}

export async function adminLoader() {
  try {
    const { user } = useAuthStore.getState();

    if (!user || user.role !== "admin") {
      return redirect("/forbidden");
    }

    return null;
  } catch (error) {
    return redirect("/login");
  }
}
```

### Step 4: Error Boundaries

```typescript
// src/routes/errors/DashboardError.tsx
import { useRouteError } from "react-router-dom";

export function DashboardError() {
  const error = useRouteError();

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-red-600">Dashboard Error</h1>
      <p className="text-gray-600">
        {error instanceof Error
          ? error.message
          : "An unexpected error occurred"}
      </p>
    </div>
  );
}
```

## Best Practices

### 1. Route Organization

- Group related routes together
- Use descriptive route names
- Implement consistent error handling
- Add proper TypeScript types

### 2. Authentication Flow

- Check authentication status in loaders
- Redirect unauthorized users appropriately
- Preserve return URLs for better UX
- Handle authentication errors gracefully

### 3. Performance Optimization

- Prefetch critical data in loaders
- Implement proper caching strategies
- Use React.lazy for code splitting
- Optimize bundle loading

### 4. Error Handling

- Provide meaningful error messages
- Implement fallback UI components
- Log errors for debugging
- Handle network errors gracefully

## Quality Gates

### 1. Route Protection

- All protected routes are properly guarded
- Guest-only routes prevent authenticated access
- Role-based routes enforce proper permissions
- Redirect logic works correctly

### 2. Data Loading

- Route loaders execute properly
- Authentication data is prefetched
- Error responses are handled correctly
- Redirects work as expected

### 3. Error Boundaries

- Error boundaries catch and display errors
- Fallback UI is user-friendly
- Error logging is implemented
- Recovery mechanisms are available

### 4. Performance

- Routes load quickly
- Data prefetching works efficiently
- Bundle splitting is implemented
- Caching strategies are effective

## Next Steps

After completing routing setup:

1. Implement authentication store
2. Add API client with interceptors
3. Create protected components
4. Add route testing
5. Implement error monitoring
