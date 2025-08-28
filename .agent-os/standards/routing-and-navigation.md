# Standard: Routing and Navigation

## Overview

Secure routing and navigation with React Router v7, implementing proper authentication guards and route protection.

## Core Requirements

### 1. Router Setup

- Use `createBrowserRouter` for modern Data Router
- Implement nested routes with layouts
- Configure error boundaries per route
- Set up proper fallback routes

### 2. Authentication Guards

- Protect private routes with authentication checks
- Implement role-based access control (RBAC)
- Redirect unauthenticated users to login
- Handle forbidden access scenarios

### 3. Route Protection

- Guest-only routes (login, register)
- Protected routes (dashboard, profile)
- Admin routes with role verification
- Public routes (home, about)

### 4. Navigation Security

- Prevent direct URL access to protected routes
- Implement proper redirects after authentication
- Handle deep linking with return URLs
- Secure navigation state management

## Implementation Guidelines

### Route Structure

```typescript
// Public routes
/ - Home page
/login - Authentication
/register - User registration

// Protected routes
/dashboard - User dashboard
/profile - User profile
/admin/* - Admin panel

// Error routes
/forbidden - Access denied
/not-found - 404 page
```

### Guard Implementation

```typescript
// Authentication guard
const requireAuth = (component: ReactElement) => {
  return <RequireAuth>{component}</RequireAuth>;
};

// Role-based guard
const requireRole = (role: string, fallback: ReactElement) => {
  return <RequireRole role={role} fallback={fallback} />;
};
```

### Error Handling

- Implement error boundaries per route
- Handle authentication errors (401, 403)
- Manage network errors gracefully
- Provide user-friendly error messages

## Security Considerations

- Validate authentication state on route changes
- Implement proper session management
- Prevent unauthorized route access
- Secure navigation history
