# Standard: State and Data Management

## Overview

Global state management using React Query for server state and Zustand for client state, ensuring proper data synchronization and caching.

## Core Requirements

### 1. Server State (React Query)

- Implement React Query for API data management
- Configure proper caching strategies
- Handle loading, error, and success states
- Implement optimistic updates where appropriate

### 2. Client State (Zustand)

- Manage authentication state
- Handle UI state (sidebar, theme, notifications)
- Implement persistent state where needed
- Manage local user preferences

### 3. State Synchronization

- Keep server and client state in sync
- Handle authentication state changes
- Implement proper state invalidation
- Manage optimistic updates

## Implementation Guidelines

### React Query Configuration

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
      gcTime: 10 * 60 * 1000, // 10 minutes
    },
    mutations: {
      retry: 1,
    },
  },
});
```

### Zustand Store Structure

```typescript
// Auth store
interface AuthStore {
  user: User | null;
  accessToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;

  setAuth: (user: User, token: string) => void;
  clearAuth: () => void;
  setLoading: (loading: boolean) => void;
}

// UI store
interface UIStore {
  sidebarOpen: boolean;
  theme: "light" | "dark";
  notifications: Notification[];

  toggleSidebar: () => void;
  setTheme: (theme: "light" | "dark") => void;
  addNotification: (notification: Notification) => void;
}
```

### State Management Patterns

- Use React Query for all API calls
- Implement proper error boundaries
- Handle loading states consistently
- Manage cache invalidation properly

## Best Practices

- Separate server and client state concerns
- Implement proper TypeScript interfaces
- Use React Query DevTools in development
- Implement proper error handling
- Manage loading states consistently
