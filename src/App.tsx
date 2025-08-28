import React, { useState, useEffect, Suspense, lazy } from 'react';
import { useAuth } from './hooks/useAuth';
import { SecureForm } from './components/ui/SecureForm';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import { router } from './lib/router';
import { SubmoduleNavProvider } from './hooks/useSubmoduleNav';
import { logger } from './lib/logger';
import { useUIStore } from './stores/ui-store';

// Code splitting with React.lazy
const PersonalDashboard = lazy(() => {
  logger.debug('Loading PersonalDashboard component');
  return import('./pages/personal/Dashboard');
});

const ManagementDashboard = lazy(() => {
  logger.debug('Loading ManagementDashboard component');
  return import('./pages/management/Dashboard');
});

const Inbox = lazy(() => {
  logger.debug('Loading Inbox component');
  return import('./pages/Inbox');
});

const Reports = lazy(() => {
  logger.debug('Loading Reports component');
  return import('./pages/management/Reports');
});

const MyInfo = lazy(() => {
  logger.debug('Loading MyInfo component');
  return import('./pages/personal/people/MyInfo');
});

const Directory = lazy(() => {
  logger.debug('Loading Directory component');
  return import('./pages/management/people/Directory');
});

const OrganizationalChart = lazy(() => {
  logger.debug('Loading OrganizationalChart component');
  return import('./pages/management/people/OrganizationalChart');
});

function ThemeToggle() {
  const [theme, setTheme] = React.useState(() => localStorage.getItem('theme') || 'light');
  React.useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);
  return (
    <button
      className="rounded-xl px-4 py-2 shadow-card border border-border bg-primary text-primary-foreground"
      onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
      aria-label="Toggle theme"
    >
      Toggle theme
    </button>
  );
}

function AuthForms() {
  const [isLogin, setIsLogin] = useState(true);
  const { login, register, isLoading, error, clearError } = useAuth();

  const handleSubmit = (data: { email: string; password: string; name?: string; confirmPassword?: string }) => {
    console.log('Form submitted:', data);
    if (isLogin) {
      login({ email: data.email, password: data.password });
    } else {
      register({
        email: data.email,
        password: data.password,
        name: data.name || '',
        confirmPassword: data.confirmPassword || ''
      });
    }
  };

  return (
    <div className="w-full max-w-md mx-auto">
      <div className="mb-6 text-center">
        <h2 className="text-2xl font-bold text-foreground mb-2">
          {isLogin ? 'Welcome Back' : 'Create Account'}
        </h2>
        <p className="text-muted-foreground">
          {isLogin ? 'Sign in to your secure account' : 'Get started with your secure account'}
        </p>
      </div>

      <SecureForm
        type={isLogin ? 'login' : 'register'}
        onSubmit={handleSubmit}
        isLoading={isLoading}
        error={error}
        onClearError={clearError}
      />

      <div className="mt-6 text-center">
        <button
          type="button"
          onClick={() => setIsLogin(!isLogin)}
          className="text-primary hover:underline text-sm"
        >
          {isLogin ? "Don't have an account? Sign up" : 'Already have an account? Sign in'}
        </button>
      </div>
    </div>
  );
}

function _UserDashboard() {
  const { user, logout } = useAuth();

  return (
    <div className="w-full max-w-4xl mx-auto">
      <div className="bg-card border border-border rounded-lg p-6 shadow-card">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold text-foreground">Welcome, {user?.name}!</h2>
            <p className="text-muted-foreground">Your secure dashboard</p>
          </div>
          <div className="flex items-center gap-4">
            <ThemeToggle />
            <button
              onClick={logout}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              Sign Out
            </button>
          </div>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold text-foreground mb-2">Account Information</h3>
            <div className="space-y-2 text-sm">
              <p><span className="text-muted-foreground">Email:</span> {user?.email}</p>
              <p><span className="text-muted-foreground">Role:</span> {user?.role}</p>
              <p><span className="text-muted-foreground">User ID:</span> {user?.id}</p>
            </div>
          </div>

          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold text-foreground mb-2">Security Status</h3>
            <div className="space-y-2 text-sm">
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                Authentication: Active
              </p>
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                Session: Valid
              </p>
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                CSRF Protection: Enabled
              </p>
            </div>
          </div>
        </div>

        <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <h3 className="font-semibold text-blue-900 mb-2">Security Features Implemented</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• Input validation and sanitization</li>
            <li>• CSRF token protection</li>
            <li>• Secure password requirements</li>
            <li>• Rate limiting capabilities</li>
            <li>• Content Security Policy (CSP)</li>
            <li>• XSS protection headers</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

function App() {
  const { isAuthenticated, user, isLoading } = useAuth();
  const [currentPage, setCurrentPage] = useState('dashboard');

  console.log('App render - isAuthenticated:', isAuthenticated, 'user:', user, 'isLoading:', isLoading);

  // Setup routing
  useEffect(() => {
    if (isAuthenticated) {
      // Initialize router view mode to match UI store
      const { viewMode } = useUIStore.getState();
      router.setViewMode(viewMode);
      console.log('Router initialized with view mode:', viewMode);
      
      // Set up unauthorized redirect handler
      router.setUnauthorizedRedirectHandler(() => {
        console.log('Unauthorized access attempt blocked - redirecting to personal dashboard');
        setCurrentPage('personal-dashboard');
      });
      
      // Set up routes - default route goes to personal dashboard
      router.addRoute('/', () => setCurrentPage('personal-dashboard'));
      // Legacy routes for backward compatibility
      router.addRoute('/home/dashboard', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/home/inbox', () => setCurrentPage('inbox'));
      router.addRoute('/inbox', () => setCurrentPage('inbox'));
      
      // Personal view routes
      router.addRoute('/personal/dashboard', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/personal/people/my-info', () => setCurrentPage('my-info'));
      
      // Management view routes
      router.addRoute('/management/dashboard', () => setCurrentPage('management-dashboard'));
      router.addRoute('/management/people/directory', () => setCurrentPage('directory'));
      router.addRoute('/management/people/organizational-chart', () => setCurrentPage('org-chart'));
      
      // Management routes
      router.addRoute('/management/reports', () => setCurrentPage('reports'));
      
      // Legacy routes (still supported)
      router.addRoute('/employees', () => setCurrentPage('people'));
      router.addRoute('/reports', () => setCurrentPage('reports')); // Legacy route redirects to same page
      
      // Protected routes (management only)
      router.addRoute('/payroll', () => setCurrentPage('personal-dashboard')); // This will be blocked by route guard
      
      // Other routes - redirect to personal dashboard for now
      router.addRoute('/time-tracking', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/pto', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/security', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/performance', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/benefits', () => setCurrentPage('personal-dashboard'));
      router.addRoute('/settings', () => setCurrentPage('personal-dashboard'));
      
      // Initialize router
      router.init();
      
      // Add listener for route changes to sync with current page
      const unsubscribe = router.addListener(() => {
        // This ensures the UI updates when router redirects
        const currentRoute = router.getCurrentRoute();
        console.log('Route changed to:', currentRoute);
      });
      
      return () => {
        if (unsubscribe) unsubscribe();
      };
    }
  }, [isAuthenticated]);

  // Monitor URL changes and trigger router navigation (for direct navigation like tests)
  useEffect(() => {
    if (!isAuthenticated) return;

    const handleLocationChange = () => {
      const currentPath = window.location.pathname;
      const routerPath = router.getCurrentRoute();
      
      // If URL changed but router hasn't been notified, trigger navigation
      if (currentPath !== routerPath) {
        console.log('Direct navigation detected:', currentPath, '-> triggering router navigation');
        router.navigate(currentPath, false);
      }
    };

    // Check on initial load and when URL changes
    handleLocationChange();
    
    // Set up interval to check for URL changes (fallback for direct navigation)
    const interval = setInterval(handleLocationChange, 100);
    
    return () => clearInterval(interval);
  }, [isAuthenticated, currentPage]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  const renderPage = () => {
    switch (currentPage) {
      case 'personal-dashboard':
        return <PersonalDashboard />;
      case 'management-dashboard':
        return <ManagementDashboard />;
      case 'inbox':
        return <Inbox />;
      case 'my-info':
        return <MyInfo />;
      case 'directory':
        return <Directory />;
      case 'org-chart':
        return <OrganizationalChart />;

      case 'reports':
        return <Reports />;
      default:
        return <PersonalDashboard />;
    }
  };

  return (
    <ErrorBoundary>
      <div className="min-h-dvh bg-background">
        {!isAuthenticated ? (
          <div className="min-h-dvh flex items-center justify-center p-6">
            <AuthForms />
          </div>
        ) : (
          <SubmoduleNavProvider>
            <Layout>
              <ErrorBoundary>
                <Suspense fallback={
                  <div className="flex items-center justify-center min-h-[400px]">
                    <div className="flex flex-col items-center gap-4">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                      <p className="text-sm text-muted-foreground">Loading...</p>
                    </div>
                  </div>
                }>
                  {renderPage()}
                </Suspense>
              </ErrorBoundary>
            </Layout>
          </SubmoduleNavProvider>
        )}
      </div>
    </ErrorBoundary>
  );
}

export default App;
