import React, { useState, useEffect, useMemo, Suspense, lazy } from 'react';
import { useAuth } from './hooks/useAuth';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import { router } from './lib/router';
import { SubmoduleNavProvider } from './hooks/useSubmoduleNav';
import { logger } from './lib/logger';
import { useUIStore } from './stores/ui-store';
import { useAuthStore } from './stores/auth-store';
import { supabase, getUserProfile } from './lib/supabase/client';
import { useSupabaseStatus } from './lib/services/supabase-status';
import { SupabaseStatusBanner } from './hooks/useSupabaseHealth';
import Toast from './components/ui/Toast';

// Code splitting with React.lazy
const ManagementDashboard = lazy(() => {
  logger.debug('Loading ManagementDashboard component');
  return import('./pages/Dashboard');
});



const Inbox = lazy(() => {
  logger.debug('Loading Inbox component');
  return import('./pages/Inbox');
});


// Error pages
const BadRequest = lazy(() => {
  logger.debug('Loading BadRequest component');
  return import('./pages/error-pages/BadRequest');
});

const Unauthorized = lazy(() => {
  logger.debug('Loading Unauthorized component');
  return import('./pages/error-pages/Unauthorized');
});

const Forbidden = lazy(() => {
  logger.debug('Loading Forbidden component');
  return import('./pages/error-pages/Forbidden');
});

const NotFound = lazy(() => {
  logger.debug('Loading NotFound component');
  return import('./pages/error-pages/NotFound');
});

const InternalServerError = lazy(() => {
  logger.debug('Loading InternalServerError component');
  return import('./pages/error-pages/InternalServerError');
});

const BadGateway = lazy(() => {
  logger.debug('Loading BadGateway component');
  return import('./pages/error-pages/BadGateway');
});

const ServiceUnavailable = lazy(() => {
  logger.debug('Loading ServiceUnavailable component');
  return import('./pages/error-pages/ServiceUnavailable');
});

const GatewayTimeout = lazy(() => {
  logger.debug('Loading GatewayTimeout component');
  return import('./pages/error-pages/GatewayTimeout');
});


const Branches = lazy(() => {
  logger.debug('Loading Branches component');
  return import('./pages/branches/Branches');
});

// Directory module pages
const DirectoryContacts = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Contacts component');
    }
    return import('./pages/directory/Contacts').catch((error) => {
      console.error('Failed to load DirectoryContacts:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryContacts lazy import:', error);
    throw error;
  }
});

const DirectoryContactNew = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Contact New component');
    }
    return import('./pages/directory/ContactNew').catch((error) => {
      console.error('Failed to load DirectoryContactNew:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryContactNew lazy import:', error);
    throw error;
  }
});

const DirectoryCustomers = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Customers component');
    }
    return import('./pages/directory/Customers').catch((error) => {
      console.error('Failed to load DirectoryCustomers:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryCustomers lazy import:', error);
    throw error;
  }
});

const DirectoryCustomerNew = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Customer New component');
    }
    return import('./pages/directory/CustomerNew').catch((error) => {
      console.error('Failed to load DirectoryCustomerNew:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryCustomerNew lazy import:', error);
    throw error;
  }
});

const DirectoryVendors = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Vendors component');
    }
    return import('./pages/directory/Vendors').catch((error) => {
      console.error('Failed to load DirectoryVendors:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryVendors lazy import:', error);
    throw error;
  }
});

const DirectoryVendorNew = lazy(() => {
  try {
    if (import.meta.env.DEV) {
      logger.debug('Loading Directory Vendor New component');
    }
    return import('./pages/directory/VendorNew').catch((error) => {
      console.error('Failed to load DirectoryVendorNew:', error);
      throw error;
    });
  } catch (error) {
    console.error('Error in DirectoryVendorNew lazy import:', error);
    throw error;
  }
});

const TestDirectory = lazy(() => {
  logger.debug('Loading Test Directory component');
  return import('./pages/directory/TestDirectory');
});

// Time and Attendance modules removed - no longer using employees table



const CompanyReports = lazy(() => {
  logger.debug('Loading Company Reports component');
  return import('./pages/reports/CompanyReports');
});

// New module pages
const Sales = lazy(() => {
  logger.debug('Loading Sales component');
  return import('./pages/sales/Sales');
});

const Orders = lazy(() => {
  logger.debug('Loading Orders component');
  return import('./pages/sales/Orders');
});

const Quotes = lazy(() => {
  logger.debug('Loading Quotes component');
  return import('./pages/sales/Quotes');
});

const QuoteNew = lazy(() => {
  logger.debug('Loading QuoteNew component');
  return import('./pages/sales/QuoteNew');
});

const Catalog = lazy(() => {
  logger.debug('Loading Catalog component');
  return import('./pages/catalog/Catalog');
});

const Items = lazy(() => {
  logger.debug('Loading Items component');
  return import('./pages/catalog/Items');
});

const Manufacturers = lazy(() => {
  logger.debug('Loading Manufacturers component');
  return import('./pages/catalog/Manufacturers');
});

const Categories = lazy(() => {
  logger.debug('Loading Categories component');
  return import('./pages/catalog/Categories');
});

const Collections = lazy(() => {
  logger.debug('Loading Collections component');
  return import('./pages/catalog/Collections');
});

const BOM = lazy(() => {
  logger.debug('Loading BOM component');
  return import('./pages/catalog/BOM');
});

// Variants component removed - use CollectionsCatalog instead

const CatalogItemNew = lazy(() => {
  logger.debug('Loading CatalogItemNew component');
  return import('./pages/catalog/CatalogItemNew');
});

const Inventory = lazy(() => {
  logger.debug('Loading Inventory component');
  return import('./pages/inventory/Inventory');
});

const Warehouse = lazy(() => {
  logger.debug('Loading Warehouse component');
  return import('./pages/inventory/Warehouse');
});

const Manufacturing = lazy(() => {
  logger.debug('Loading Manufacturing component');
  return import('./pages/manufacturing/Manufacturing');
});

const Financials = lazy(() => {
  logger.debug('Loading Financials component');
  return import('./pages/financials/Financials');
});

const CompanySettings = lazy(() => {
  logger.debug('Loading Company Settings component');
  return import('./pages/settings/CompanySettings');
});

const OrganizationUsers = lazy(() => {
  logger.debug('Loading Organization Users component');
  return import('./pages/settings/OrganizationUsers');
});

const OrganizationUser = lazy(() => {
  logger.debug('Loading Organization User component');
  return import('./pages/settings/OrganizationUser');
});

const OrganizationUserNew = lazy(() => {
  logger.debug('Loading Organization User New component');
  return import('./pages/settings/OrganizationUserNew');
});

// Auth pages
const Login = lazy(() => {
  logger.debug('Loading Login component');
  return import('./pages/auth/Login');
});

const Signup = lazy(() => {
  logger.debug('Loading Signup component');
  return import('./pages/auth/Signup');
});

const CompanyRegistration = lazy(() => {
  logger.debug('Loading Company Registration component');
  return import('./pages/auth/CompanyRegistration');
});

const ResetPassword = lazy(() => {
  logger.debug('Loading Reset Password component');
  return import('./pages/auth/ResetPassword');
});

const AuthCallback = lazy(() => {
  logger.debug('Loading Auth Callback component');
  return import('./pages/auth/AuthCallback');
});

const ResetPasswordForm = lazy(() => {
  logger.debug('Loading Reset Password Form component');
  return import('./pages/auth/ResetPasswordForm');
});

const NewPassword = lazy(() => {
  logger.debug('Loading New Password component');
  return import('./pages/auth/NewPassword');
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



function App() {
  const { isAuthenticated, user, isLoading } = useAuth();
  const { setViewMode } = useUIStore();
  const [currentPage, setCurrentPage] = useState('dashboard');
  const { init: initAuth } = useAuthStore();

  // Check if current page is error page (memoized - must be before all useEffect)
  const isErrorPage = useMemo(() => [
    'bad-request', 'unauthorized', 'forbidden', 'not-found',
    'internal-server-error', 'bad-gateway', 'service-unavailable', 'gateway-timeout'
  ].includes(currentPage), [currentPage]);

  // Check if current page is auth page (memoized - must be before all useEffect)
  const isAuthPage = useMemo(() => [
    'login', 'signup', 'company-registration', 'reset-password', 'new-password',
    'auth-callback', 'auth-reset-password'
  ].includes(currentPage), [currentPage]);

  // Initialize auth on mount
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        await initAuth();
      } catch (error) {
        logger.error('Error initializing auth', error as Error);
        // Don't break the app if auth init fails
        useAuthStore.getState().setLoading(false);
      }
    };
    
    initializeAuth();
  }, [initAuth]);

  // Start Supabase monitoring
  useEffect(() => {
    useSupabaseStatus.getState().startMonitoring();
    return () => {
      useSupabaseStatus.getState().stopMonitoring();
    };
  }, []);

  // Note: Auth callbacks (recovery, signup, invite) are now handled by AuthCallback component
  // This keeps the logic centralized and prevents conflicts with auto-redirects
  // The AuthCallback component handles:
  // - Password recovery tokens (type=recovery) ? redirects to /auth/reset-password
  // - Email confirmation (type=signup/invite) ? processes and redirects to dashboard

  // Note: auth state changes handled inside auth store init

  if (import.meta.env.DEV) {
  console.log('App render - isAuthenticated:', isAuthenticated, 'user:', user, 'isLoading:', isLoading);
  }

  // Setup routing - Register ALL routes first, then initialize router
  useEffect(() => {
    // Initialize router view mode to match UI store
    const { viewMode } = useUIStore.getState();
    router.setViewMode(viewMode);
    
    // Set up view mode change handler to sync router changes with UI store
    router.setViewModeChangeHandler((newViewMode) => {
      if (import.meta.env.DEV) {
        console.log('Router detected view mode change, updating UI store:', newViewMode);
      }
      setViewMode(newViewMode);
    });
    
    // Set up unauthorized redirect handler
    router.setUnauthorizedRedirectHandler(() => {
      if (import.meta.env.DEV) {
        console.log('Unauthorized access attempt blocked - redirecting to management dashboard');
      }
      setCurrentPage('management-dashboard');
    });

    // Auth routes (available without authentication)
    router.addRoute('/login', () => setCurrentPage('login'));
    router.addRoute('/auth/login', () => setCurrentPage('login'));
    router.addRoute('/signup', () => setCurrentPage('signup'));
    router.addRoute('/auth/signup', () => setCurrentPage('signup'));
    router.addRoute('/company-registration', () => setCurrentPage('company-registration'));
    router.addRoute('/auth/company-registration', () => setCurrentPage('company-registration'));
    router.addRoute('/reset-password', () => setCurrentPage('reset-password'));
    router.addRoute('/auth/reset-password', () => setCurrentPage('auth-reset-password'));
    router.addRoute('/auth/callback', () => setCurrentPage('auth-callback'));
    router.addRoute('/new-password', () => setCurrentPage('new-password'));
    router.addRoute('/auth/new-password', () => setCurrentPage('new-password'));
    
    // Error routes (always available)
    router.addRoute('/400', () => setCurrentPage('bad-request'));
    router.addRoute('/401', () => setCurrentPage('unauthorized'));
    router.addRoute('/403', () => setCurrentPage('forbidden'));
    router.addRoute('/404', () => setCurrentPage('not-found'));
    router.addRoute('/500', () => setCurrentPage('internal-server-error'));
    router.addRoute('/502', () => setCurrentPage('bad-gateway'));
    router.addRoute('/503', () => setCurrentPage('service-unavailable'));
    router.addRoute('/504', () => setCurrentPage('gateway-timeout'));
    
    // 404 route handler for unknown routes (must be last)
    router.addRoute('*', () => {
      // Only show 404 for authenticated routes if user is authenticated
      // For unauthenticated users trying to access protected routes, redirect to login
      const currentPath = window.location.pathname;
      const isAuthRoute = currentPath.startsWith('/login') || 
                         currentPath.startsWith('/signup') || 
                         currentPath.startsWith('/auth/') ||
                         currentPath.startsWith('/reset-password') ||
                         currentPath.startsWith('/company-registration');
      
      if (!isAuthenticated && !isAuthRoute) {
        setCurrentPage('login');
      } else {
        setCurrentPage('not-found');
      }
    });
    
    // Authenticated routes - these check authentication before executing
    router.addRoute('/', () => {
      if (isAuthenticated) {
        setCurrentPage('management-dashboard');
      } else {
        setCurrentPage('login');
      }
    });
    
    router.addRoute('/dashboard', () => {
      if (isAuthenticated) {
        setCurrentPage('management-dashboard');
      } else {
        setCurrentPage('login');
      }
    });
    
    router.addRoute('/inbox', () => {
      if (isAuthenticated) {
        setCurrentPage('inbox');
      } else {
        setCurrentPage('login');
      }
    });
    
    router.addRoute('/branches', () => {
      if (isAuthenticated) {
        setCurrentPage('branches');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Directory routes
    router.addRoute('/directory/contacts', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-contacts');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/contacts/new', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-contact-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/contacts/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-contact-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/customers', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-customers');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/customers/new', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-customer-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/customers/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-customer-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/vendors', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-vendors');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/vendors/new', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-vendor-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/vendors/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-vendor-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/vendors/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-vendor-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory/test', () => {
      if (isAuthenticated) {
        setCurrentPage('test-directory');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/directory', () => {
      if (isAuthenticated) {
        setCurrentPage('directory-contacts');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Sales routes
    router.addRoute('/sales', () => {
      if (isAuthenticated) {
        setCurrentPage('sales');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/orders', () => {
      if (isAuthenticated) {
        setCurrentPage('orders');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/quotes', () => {
      if (isAuthenticated) {
        setCurrentPage('quotes');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/quotes/new', () => {
      if (isAuthenticated) {
        setCurrentPage('quote-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/quotes/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('quote-new');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Catalog routes
    router.addRoute('/catalog', () => {
      if (isAuthenticated) {
        setCurrentPage('catalog');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/items', () => {
      if (isAuthenticated) {
        setCurrentPage('items');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/items/new', () => {
      if (isAuthenticated) {
        setCurrentPage('catalog-item-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/items/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('catalog-item-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/manufacturers', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturers');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/categories', () => {
      if (isAuthenticated) {
        setCurrentPage('categories');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/collections', () => {
      if (isAuthenticated) {
        setCurrentPage('collections');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/catalog/bom', () => {
      if (isAuthenticated) {
        setCurrentPage('bom');
      } else {
        setCurrentPage('login');
      }
    });
    // Variants route removed - redirect to collections instead
    router.addRoute('/catalog/variants', () => {
      if (isAuthenticated) {
        // Redirect to collections page
        router.navigate('/catalog/collections', true);
      } else {
        setCurrentPage('login');
      }
    });
    
    // Inventory routes
    router.addRoute('/inventory', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/warehouse', () => {
      if (isAuthenticated) {
        setCurrentPage('warehouse');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/purchase-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/receipts', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/transactions', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/adjustments', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Manufacturing routes
    router.addRoute('/manufacturing', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/production-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/work-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/bill-of-materials', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/routing', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/work-centers', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Financials routes
    router.addRoute('/financials', () => {
      if (isAuthenticated) {
        setCurrentPage('financials');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Reports routes
    router.addRoute('/reports', () => {
      if (isAuthenticated) {
        setCurrentPage('company-reports');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/reports/company-reports', () => {
      if (isAuthenticated) {
        setCurrentPage('company-reports');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Settings routes - CRITICAL: These must work on refresh
    router.addRoute('/settings', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/company-settings', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/organization-user', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/organization-profile', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/organization-users/new', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/organization-users/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Other routes
    router.addRoute('/time-tracking', () => {
      if (isAuthenticated) {
        setCurrentPage('management-dashboard');
      } else {
        setCurrentPage('login');
      }
    });

    // Initialize router AFTER all routes are registered
    // This ensures refresh works correctly
    router.init();
    
    // Add listener for route changes to sync with current page
    const unsubscribe = router.addListener(() => {
      const currentRoute = router.getCurrentRoute();
      if (import.meta.env.DEV) {
        console.log('Route changed to:', currentRoute);
      }
    });
    
    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, [isAuthenticated, setViewMode]); // Re-register routes when auth state changes

  // Monitor URL changes and trigger router navigation (for direct navigation like tests)
  useEffect(() => {
    if (!isAuthenticated) return;

    const handleLocationChange = () => {
      const currentPath = window.location.pathname;
      const routerPath = router.getCurrentRoute();
      
      // If URL changed but router hasn't been notified, trigger navigation
      if (currentPath !== routerPath) {
        if (import.meta.env.DEV) {
        console.log('Direct navigation detected:', currentPath, '-> triggering router navigation');
        }
        router.navigate(currentPath, false);
      }
    };

    // Check on initial load and when URL changes
    handleLocationChange();
    
    // Set up interval to check for URL changes (fallback for direct navigation)
    const interval = setInterval(handleLocationChange, 100);
    
    return () => clearInterval(interval);
  }, [isAuthenticated, currentPage]);

  // Redirect to login if not authenticated (except for auth pages and error pages)
  useEffect(() => {
    if (!isAuthenticated && !isLoading && !isAuthPage && !isErrorPage) {
      router.navigate('/login', true);
    }
  }, [isAuthenticated, isLoading, isAuthPage, isErrorPage]);


  const renderPage = () => {
    switch (currentPage) {
      
      // Error pages
      case 'bad-request':
        return <BadRequest />;
      case 'unauthorized':
        return <Unauthorized />;
      case 'forbidden':
        return <Forbidden />;
      case 'not-found':
        return <NotFound />;
      case 'internal-server-error':
        return <InternalServerError />;
      case 'bad-gateway':
        return <BadGateway />;
      case 'service-unavailable':
        return <ServiceUnavailable />;
      case 'gateway-timeout':
        return <GatewayTimeout />;
      
      // Dashboard pages
      case 'management-dashboard':
        return <ManagementDashboard />;
      case 'inbox':
        return <Inbox />;
      case 'branches':
        return <Branches />;
      
      // Directory module pages
      case 'directory-contacts':
        return <DirectoryContacts />;
      case 'directory-contact-new':
        return <DirectoryContactNew />;
      case 'directory-customers':
        return <DirectoryCustomers />;
      case 'directory-customer-new':
        return <DirectoryCustomerNew />;
      case 'directory-vendors':
        return <DirectoryVendors />;
      case 'directory-vendor-new':
        return <DirectoryVendorNew />;
      case 'test-directory':
        return <TestDirectory />;
      
      // New module pages
      case 'sales':
        return <Sales />;
      case 'orders':
        return <Orders />;
      case 'quotes':
        return <Quotes />;
      case 'quote-new':
        return <QuoteNew />;
      case 'catalog':
        return <Catalog />;
      case 'items':
        return <Items />;
      case 'catalog-item-new':
        return <CatalogItemNew />;
      case 'manufacturers':
        return <Manufacturers />;
      case 'categories':
        return <Categories />;
      case 'collections':
        return <Collections />;
      case 'bom':
        return <BOM />;
      // Variants case removed - use CollectionsCatalog instead
      case 'inventory':
        return <Inventory />;
      case 'warehouse':
        return <Warehouse />;
      case 'manufacturing':
        return <Manufacturing />;
      case 'financials':
        return <Financials />;

      case 'reports':
        return <CompanyReports />;
      case 'company-reports':
        return <CompanyReports />;
      case 'company-settings':
        return <CompanySettings />;
      case 'organization-users':
        return <OrganizationUsers organizationId={null} />;
      case 'organization-user':
        return <OrganizationUser />;
      case 'organization-profile':
        return <OrganizationUser />; // This route is handled by CompanySettings, but keep for backward compatibility
      // Note: 'organization-user-new' routes now render CompanySettings which handles the embedded form
      
      // Auth pages
      case 'login':
        return <Login />;
      case 'signup':
        return <Signup />;
      case 'company-registration':
        return <CompanyRegistration />;
      case 'reset-password':
        return <ResetPassword />;
      case 'new-password':
        return <NewPassword />;
      case 'auth-callback':
        return <AuthCallback />;
      case 'auth-reset-password':
        return <ResetPasswordForm />;
      
      default:
        return <ManagementDashboard />;
    }
  };

  return (
    <ErrorBoundary>
      <Toast />
      <SupabaseStatusBanner />
      <div className="min-h-dvh bg-background">
        {!isAuthenticated && !isAuthPage ? (
          <div className="min-h-dvh flex items-center justify-center p-6">
            <div className="text-center">
              <p className="text-muted-foreground">Redirecting to login...</p>
            </div>
          </div>
        ) : isAuthPage ? (
          // Auth pages without layout
          <ErrorBoundary>
            <Suspense fallback={null}>
              {renderPage()}
            </Suspense>
          </ErrorBoundary>
        ) : isErrorPage ? (
          // Error pages without layout
          <ErrorBoundary>
            <Suspense fallback={null}>
              {renderPage()}
            </Suspense>
          </ErrorBoundary>
        ) : currentPage === 'company-settings' ? (
          <ErrorBoundary>
            <Suspense fallback={null}>
              <CompanySettings />
            </Suspense>
          </ErrorBoundary>
        ) : (
          // Regular pages with layout
          <SubmoduleNavProvider>
            <Layout>
              <ErrorBoundary>
                <SupabaseStatusBanner />
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
              </ErrorBoundary>
            </Layout>
          </SubmoduleNavProvider>
        )}
      </div>
    </ErrorBoundary>
  );
}

export default App;

