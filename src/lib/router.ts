// Simple client-side router for navigation with route guards
export class Router {
  private routes: Map<string, () => void> = new Map();
  private currentRoute: string = '/';
  private viewMode: 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal' = 'employee';
  private listeners: Set<() => void> = new Set();
  private unauthorizedRedirectHandler?: () => void;
  private viewModeChangeHandler?: (viewMode: 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal') => void;

  constructor() {
    // Handle browser back/forward buttons
    window.addEventListener('popstate', () => {
      this.navigate(window.location.pathname, false);
    });
  }

  addRoute(path: string, handler: () => void) {
    this.routes.set(path, handler);
  }

  // Check if a route pattern matches a given path (handles parameters like :slug)
  private matchesRoute(routePattern: string, path: string): boolean {
    // Convert route pattern to regex
    const regexPattern = routePattern
      .replace(/:\w+/g, '[^/]+') // Replace :param with [^/]+ (any chars except /)
      .replace(/\//g, '\\/'); // Escape forward slashes
    
    
    // Ensure we have a valid regex pattern
    if (!regexPattern || regexPattern === '^$') {
      return false;
    }
    
    try {
      const regex = new RegExp(`^${regexPattern}$`);
      return regex.test(path);
    } catch (error) {
      return false;
    }
  }

  setViewMode(mode: 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal') {
    this.viewMode = mode;
  }

  getViewMode(): 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal' {
    return this.viewMode;
  }

  // Set handler for view mode changes (to sync with UI store)
  setViewModeChangeHandler(handler: (viewMode: 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal') => void) {
    this.viewModeChangeHandler = handler;
  }

  // Infer view mode from URL path
  private inferViewModeFromPath(path: string): 'employee' | 'manager' | 'group' | 'vap' | 'rp' | 'personal' {
    if (path.includes('/org/grp/')) return 'group';
    if (path.includes('/org/vap/')) return 'vap';
    if (path.includes('/org/rp/')) return 'rp';
    if (path.includes('/org/cmp/management/')) return 'manager';
    if (path.includes('/personal/') || path.includes('/me/')) return 'personal';
    if (path.includes('/org/cmp/employee/')) return 'employee';
    
    // Default to employee for other paths
    return 'employee';
  }

  // Set handler for unauthorized access redirects
  setUnauthorizedRedirectHandler(handler: () => void) {
    this.unauthorizedRedirectHandler = handler;
  }

  // Check if a route is protected (management only)
  private isProtectedRoute(path: string): boolean {
    const managementRoutes = [
      '/management/',
      '/payroll'
    ];
    
    return managementRoutes.some(route => path.startsWith(route));
  }

  // Check if user has access to a route
  private hasRouteAccess(path: string): boolean {
    if (!this.isProtectedRoute(path)) {
      return true; // Public routes are always accessible
    }
    
    // Protected routes require manager, group, vap, rp, or personal view mode
    return this.viewMode === 'manager' || this.viewMode === 'group' || this.viewMode === 'vap' || this.viewMode === 'rp' || this.viewMode === 'personal';
  }

  navigate(path: string, pushState: boolean = true) {
    // Infer and update view mode from URL path
    const inferredViewMode = this.inferViewModeFromPath(path);
    const oldViewMode = this.viewMode;
    
    // Update view mode if it changed
    if (inferredViewMode !== oldViewMode) {
      this.viewMode = inferredViewMode;
      
      // Notify view mode change handler (to sync with UI store)
      if (this.viewModeChangeHandler) {
        this.viewModeChangeHandler(inferredViewMode);
      }
      
      if (import.meta.env.DEV) {
        console.log(`View mode changed from ${oldViewMode} to ${inferredViewMode} based on URL: ${path}`);
      }
    }
    
    // Check route access before navigation
    if (!this.hasRouteAccess(path)) {
      console.warn(`Access denied to route: ${path}. Redirecting to employee dashboard.`);
      
      // Redirect to employee dashboard instead
      const redirectPath = '/employee/dashboard';
      
      // Always update the URL when redirecting
      window.history.replaceState({}, '', redirectPath);
      
      // Call unauthorized redirect handler if set
      if (this.unauthorizedRedirectHandler) {
        this.unauthorizedRedirectHandler();
      }
      
      // Navigate to allowed route instead (without pushing to history again)
      this.navigate(redirectPath, false);
      return;
    }
    
    if (pushState) {
      window.history.pushState({}, '', path);
    }
    
    const oldRoute = this.currentRoute;
    this.currentRoute = path;
    
    // First try exact match
    let handler = this.routes.get(path);
    
    // If no exact match, try to find a route with parameters
    if (!handler) {
      for (const [routePattern, routeHandler] of this.routes.entries()) {
        if (this.matchesRoute(routePattern, path)) {
          handler = routeHandler;
          break;
        }
      }
    }
    
    if (handler) {
      handler();
      // Scroll to top after navigation
      window.scrollTo(0, 0);
    } else {
      // No route found - trigger 404 page
      const notFoundHandler = this.routes.get('*');
      if (notFoundHandler) {
        notFoundHandler();
        // Scroll to top after navigation
        window.scrollTo(0, 0);
      } else {
        // Fallback to dashboard if no 404 handler is set
        const defaultHandler = this.routes.get('/');
        if (defaultHandler) {
          defaultHandler();
          // Scroll to top after navigation
          window.scrollTo(0, 0);
        }
      }
    }
    
    // Notify listeners if route actually changed
    if (oldRoute !== this.currentRoute) {
      this.notifyListeners();
    }
  }

  getCurrentRoute(): string {
    return this.currentRoute;
  }

  // Add listener for route changes
  addListener(listener: () => void) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener); // Return cleanup function
  }

  // Notify all listeners
  private notifyListeners() {
    this.listeners.forEach(listener => listener());
  }

  // Initialize with current path
  init() {
    this.navigate(window.location.pathname, false);
  }
}

// Create and export router instance
export const router = new Router();
