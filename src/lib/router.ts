// Simple client-side router for navigation with route guards
export class Router {
  private routes: Map<string, () => void> = new Map();
  private currentRoute: string = '/';
  private viewMode: 'employee' | 'manager' | 'group' | 'vap' = 'employee';
  private listeners: Set<() => void> = new Set();
  private unauthorizedRedirectHandler?: () => void;

  constructor() {
    // Handle browser back/forward buttons
    window.addEventListener('popstate', () => {
      this.navigate(window.location.pathname, false);
    });
  }

  addRoute(path: string, handler: () => void) {
    this.routes.set(path, handler);
  }

  setViewMode(mode: 'employee' | 'manager' | 'group' | 'vap') {
    this.viewMode = mode;
  }

  getViewMode(): 'employee' | 'manager' | 'group' | 'vap' {
    return this.viewMode;
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
    
    // Protected routes require manager, group, or vap view mode
    return this.viewMode === 'manager' || this.viewMode === 'group' || this.viewMode === 'vap';
  }

  navigate(path: string, pushState: boolean = true) {
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
    const handler = this.routes.get(path);
    
    if (handler) {
      handler();
      // Scroll to top after navigation
      window.scrollTo(0, 0);
    } else {
      // Default to dashboard
      const defaultHandler = this.routes.get('/home/dashboard') || this.routes.get('/');
      if (defaultHandler) {
        defaultHandler();
        // Scroll to top after navigation
        window.scrollTo(0, 0);
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
