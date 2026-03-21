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
import { RequireModule } from './components/auth/RequireModule';
import AuthGate from './auth/AuthGate';

// Code splitting with React.lazy
const ManagementDashboard = lazy(() => import('./pages/Dashboard'));
const Inbox = lazy(() => import('./pages/Inbox'));

// Error pages
const BadRequest = lazy(() => import('./pages/error-pages/BadRequest'));
const Unauthorized = lazy(() => import('./pages/error-pages/Unauthorized'));
const Forbidden = lazy(() => import('./pages/error-pages/Forbidden'));
const NotFound = lazy(() => import('./pages/error-pages/NotFound'));
const InternalServerError = lazy(() => import('./pages/error-pages/InternalServerError'));
const BadGateway = lazy(() => import('./pages/error-pages/BadGateway'));
const ServiceUnavailable = lazy(() => import('./pages/error-pages/ServiceUnavailable'));
const GatewayTimeout = lazy(() => import('./pages/error-pages/GatewayTimeout'));

const Branches = lazy(() => import('./pages/branches/Branches'));

// Directory module pages (Contacts/Customers rendered inside Directory for persistent tabs)
const Directory = lazy(() => import('./pages/directory/Directory'));
const DirectoryContactNew = lazy(() => import('./pages/directory/ContactNew'));
const DirectoryCustomerNew = lazy(() => import('./pages/directory/CustomerNew'));
const TestDirectory = lazy(() => import('./pages/directory/TestDirectory'));

// Time and Attendance modules removed - no longer using employees table



const CompanyReports = lazy(() => import('./pages/reports/CompanyReports'));

// New module pages
const Sales = lazy(() => import('./pages/sales/Sales'));
const SalesDirectory = lazy(() => import('./pages/sales/SalesDirectory'));
const Quotes = lazy(() => import('./pages/sales/Quotes'));
const QuoteDetail = lazy(() => import('./pages/sales/QuoteDetail'));
const QuoteNew = lazy(() => import('./pages/sales/QuoteNew'));
const Proposals = lazy(() => import('./pages/sales/Proposals'));
const ProposalPrint = lazy(() => import('./pages/sales/ProposalPrint'));
const SalesOrderDetail = lazy(() => import('./pages/sales/SalesOrderDetail'));

const Catalog = lazy(() => import('./pages/catalog/Catalog'));
const CatalogModule = lazy(() => import('./pages/catalog/CatalogModule'));
const Items = lazy(() => import('./pages/catalog/Items'));
const Manufacturers = lazy(() => import('./pages/catalog/Manufacturers'));
const Categories = lazy(() => import('./pages/catalog/Categories'));
const Collections = lazy(() => import('./pages/catalog/Collections'));
const BOM = lazy(() => import('./pages/catalog/BOM'));
const BOMTemplates = lazy(() => import('./pages/catalog/BOMTemplates'));

const ManufacturingOrders = lazy(() => import('./pages/manufacturing/ManufacturingOrders'));
const ManufacturingOrderDetail = lazy(() => import('./pages/manufacturing/ManufacturingOrderDetail'));
const WorkstationView = lazy(() => import('./pages/manufacturing/WorkstationView'));
const WorkOrdersList = lazy(() => import('./pages/manufacturing/WorkOrdersList'));
const WorkOrderDetail = lazy(() => import('./pages/manufacturing/WorkOrderDetail'));
const ProductionCalendar = lazy(() => import('./pages/manufacturing/ProductionCalendar'));
const FinishedGoods = lazy(() => import('./pages/manufacturing/FinishedGoods'));
const CutOptimization = lazy(() => import('./pages/manufacturing/CutOptimization'));
const DeliveryNoteDetail = lazy(() => import('./pages/manufacturing/DeliveryNoteDetail'));

// Variants component removed - use CollectionsCatalog instead

const CatalogItemNew = lazy(() => import('./pages/catalog/CatalogItemNew'));
const Inventory = lazy(() => import('./pages/inventory/Inventory'));
const Warehouse = lazy(() => import('./pages/inventory/Warehouse'));
const InventoryItemDetail = lazy(() => import('./pages/inventory/InventoryItemDetail'));
const PurchaseOrders = lazy(() => import('./pages/inventory/PurchaseOrders'));
const PurchaseOrderDetail = lazy(() => import('./pages/inventory/PurchaseOrderDetail'));
const Receipts = lazy(() => import('./pages/inventory/Receipts'));
const Transactions = lazy(() => import('./pages/inventory/Transactions'));
const TransactionDetail = lazy(() => import('./pages/inventory/TransactionDetail'));
const Adjustments = lazy(() => import('./pages/inventory/Adjustments'));
const MaterialDemand = lazy(() => import('./pages/inventory/MaterialDemand'));
const Manufacturing = lazy(() => import('./pages/manufacturing/Manufacturing'));
const BillOfMaterials = lazy(() => import('./pages/manufacturing/BillOfMaterials'));
const ApprovedBOMList = lazy(() => import('./pages/catalog/ApprovedBOMList'));
const Financials = lazy(() => import('./pages/financials/Financials'));
const DealerAccounts = lazy(() => import('./pages/financials/DealerAccounts'));
const DealerAccountDetail = lazy(() => import('./pages/financials/DealerAccountDetail'));
const Invoices = lazy(() => import('./pages/financials/Invoices'));
const InvoiceNew = lazy(() => import('./pages/financials/InvoiceNew'));
const InvoiceDetail = lazy(() => import('./pages/financials/InvoiceDetail'));
const FinancialPayments = lazy(() => import('./pages/financials/FinancialPayments'));
const PaymentDetail = lazy(() => import('./pages/financials/PaymentDetail'));
const VendorAccountsList = lazy(() => import('./pages/financials/VendorAccounts'));
const VendorAccountDetail = lazy(() => import('./pages/financials/VendorAccountDetail'));
const BillsList = lazy(() => import('./pages/financials/BillsList'));
const BillNew = lazy(() => import('./pages/financials/BillNew'));
const BillDetail = lazy(() => import('./pages/financials/BillDetail'));
const PurchaseOrdersAP = lazy(() => import('./pages/financials/PurchaseOrdersAP'));
const VendorPaymentsList = lazy(() => import('./pages/financials/VendorPaymentsList'));
const VendorPaymentDetail = lazy(() => import('./pages/financials/VendorPaymentDetail'));
const Partners = lazy(() => import('./pages/partners/Partners'));
const PartnerDealers = lazy(() => import('./pages/partners/PartnerDealers'));
const DealerDetail = lazy(() => import('./pages/partners/DealerDetail'));
const PartnerVendors = lazy(() => import('./pages/partners/PartnerVendors'));
const PartnerVendorForm = lazy(() => import('./pages/partners/PartnerVendorForm'));
const PartnerManufacturers = lazy(() => import('./pages/partners/PartnerManufacturers'));

const CompanySettings = lazy(() => import('./pages/settings/CompanySettings'));

const OrganizationUsers = lazy(() => import('./pages/settings/OrganizationUsers'));
const OrganizationUser = lazy(() => import('./pages/settings/OrganizationUser'));
const OrganizationUserNew = lazy(() => import('./pages/settings/OrganizationUserNew'));
const DealerUsers = lazy(() => import('./pages/settings/DealerUsers'));
const DealerAccount = lazy(() => import('./pages/settings/DealerAccount'));
const Roles = lazy(() => import('./pages/settings/Roles'));
const AdminRoles = lazy(() => import('./pages/admin/Roles'));

// Auth pages (NO lazy - son críticas para el flujo)
import Login from './pages/auth/Login';
import Signup from './pages/auth/Signup';
import CompanyRegistration from './pages/auth/CompanyRegistration';
import ResetPassword from './pages/auth/ResetPassword';
import AuthCallback from './pages/auth/AuthCallback';
import ResetPasswordForm from './pages/auth/ResetPasswordForm';
import NewPassword from './pages/auth/NewPassword';
import SetPassword from './pages/auth/SetPassword';
import AcceptInvite from './pages/auth/AcceptInvite';
import AccessDenied from './pages/auth/AccessDenied';
import { SuperAdminActingGate } from './components/SuperAdminActingGate';



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
    'login', 'signup', 'company-registration', 'reset-password', 'new-password', 'set-password',
    'auth-callback', 'auth-reset-password', 'auth-accept', 'accept-invite', 'access-denied'
  ].includes(currentPage), [currentPage]);

  // Initialize auth on mount with safety timeout
  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout> | null = null;
    let isMounted = true;

    const initializeAuth = async () => {
      // Skip auth init on auth flow pages - they handle their own auth
      const path = window.location.pathname;
      const isAuthFlow =
        path.startsWith('/auth/callback') ||
        path.startsWith('/auth/accept') ||
        path.startsWith('/accept-invite') ||
        path.startsWith('/set-password') ||
        path.startsWith('/auth/reset-password') ||
        path.startsWith('/new-password') ||
        path.startsWith('/login') ||
        path.startsWith('/signup');

      if (isAuthFlow) {
        console.log('[App] Skipping auth init on auth flow page:', path);
        useAuthStore.setState({ isLoading: false });
        return;
      }

      try {
        // Set a safety timeout: if initAuth takes more than 10 seconds, force loading=false
        timeoutId = setTimeout(() => {
          if (import.meta.env.DEV) {
            console.warn('[App] initAuth timeout - forcing loading=false after 10s');
          }
          if (isMounted) {
            useAuthStore.getState().setLoading(false);
          }
        }, 10000); // 10 seconds max

        await initAuth();
        
        // Clear timeout if initAuth completes
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
      } catch (error) {
        logger.error('Error initializing auth', error instanceof Error ? error : new Error(String(error)));
        // Don't break the app if auth init fails
        if (isMounted) {
          useAuthStore.getState().setLoading(false);
        }
      } finally {
        // Always clear timeout
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
      }
    };
    
    initializeAuth();

    return () => {
      isMounted = false;
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
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
  
  // ✅ CRITICAL: Redirect magic links to /auth/callback
  // If URL has hash with token/code, redirect to AuthCallback to process it
  useEffect(() => {
    const hash = window.location.hash;
    const hasAuthToken = hash.includes('access_token') || hash.includes('refresh_token');
    const searchParams = new URLSearchParams(window.location.search);
    const hasCode = searchParams.has('code');
    
    if ((hasAuthToken || hasCode) && window.location.pathname === '/') {
      console.log('🔀 Detected auth token/code in URL, redirecting to /auth/callback');
      const newUrl = `/auth/callback${window.location.search}${window.location.hash}`;
      window.history.replaceState(null, '', newUrl);
      router.navigate(newUrl, false);
    }
  }, []);

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
    router.addRoute('/auth/accept', () => setCurrentPage('auth-accept'));
    router.addRoute('/accept-invite', () => setCurrentPage('auth-accept')); // Alias for auth/accept
    router.addRoute('/set-password', () => setCurrentPage('set-password'));
    router.addRoute('/new-password', () => setCurrentPage('new-password'));
    router.addRoute('/auth/new-password', () => setCurrentPage('new-password'));
    router.addRoute('/access-denied', () => setCurrentPage('access-denied'));
    router.addRoute('/select-acting-dealer', () => setCurrentPage('select-acting-dealer'));

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
    router.addRoute('/sales/quotes/:id/edit', () => {
      if (isAuthenticated) {
        setCurrentPage('quote-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/quotes/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('quote-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/proposals', () => {
      if (isAuthenticated) {
        setCurrentPage('proposals');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/proposals/:id/print', () => {
      if (isAuthenticated) {
        setCurrentPage('proposal-print');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/sales/proposals/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('proposals');
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
    router.addRoute('/sales/orders/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('order-detail');
      } else {
        setCurrentPage('login');
      }
    });

    // Catalog routes
    router.addRoute('/catalog', () => {
      if (isAuthenticated) {
        // Redirect to first sub-module (Items)
        router.navigate('/catalog/items', false);
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
    router.addRoute('/inventory/items/:catalog_item_id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/inventory\/items\/([^/]+)/);
        if (match?.[1]) sessionStorage.setItem('currentInventoryItemId', match[1]);
        setCurrentPage('inventory-item-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/purchase-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory-purchase-orders');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/purchase-orders/new', () => {
      if (isAuthenticated) {
        sessionStorage.removeItem('currentPurchaseOrderId');
        setCurrentPage('inventory-purchase-order-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/purchase-orders/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/inventory\/purchase-orders\/([^/]+)/);
        if (match?.[1] && match[1] !== 'new') {
          sessionStorage.setItem('currentPurchaseOrderId', match[1]);
        }
        setCurrentPage('inventory-purchase-order-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/receipts', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory-receipts');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/transactions', () => {
      if (isAuthenticated) {
        setCurrentPage('transactions');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/transactions/new', () => {
      if (isAuthenticated) {
        setCurrentPage('transaction-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/transactions/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/inventory\/transactions\/([^/]+)/);
        if (match?.[1]) sessionStorage.setItem('currentTransactionId', match[1]);
        setCurrentPage('transaction-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/adjustments', () => {
      if (isAuthenticated) {
        setCurrentPage('inventory-adjustments');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/adjustments/new', () => {
      if (isAuthenticated) {
        setCurrentPage('transaction-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/adjustments/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/inventory\/adjustments\/([^/]+)/);
        if (match?.[1] && match[1] !== 'new') {
          sessionStorage.setItem('currentTransactionId', match[1]);
        }
        setCurrentPage('transaction-detail');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/inventory/material-demand', () => {
      if (isAuthenticated) {
        setCurrentPage('material-demand');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Manufacturing routes
    router.addRoute('/manufacturing', () => {
      if (isAuthenticated) {
        router.navigate('/manufacturing/manufacturing-orders', false);
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
    router.addRoute('/manufacturing/manufacturing-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('manufacturing-orders');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/manufacturing-orders/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/manufacturing\/manufacturing-orders\/([^/]+)/);
        const moId = match ? match[1] : null;
        if (moId) {
          setCurrentPage('manufacturing-order-detail');
          // Store MO ID in sessionStorage for the component to access
          sessionStorage.setItem('currentManufacturingOrderId', moId);
        } else {
          setCurrentPage('manufacturing-orders');
        }
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/order-list', () => {
      if (isAuthenticated) {
        router.navigate('/manufacturing/manufacturing-orders', false);
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/material', () => {
      if (isAuthenticated) {
        router.navigate('/manufacturing/manufacturing-orders', false);
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/work-orders', () => {
      if (isAuthenticated) {
        setCurrentPage('work-orders-list');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/work-orders/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/manufacturing\/work-orders\/([^/]+)/);
        const moId = match ? match[1] : null;
        if (moId) {
          sessionStorage.setItem('currentWorkOrderMoId', moId);
          setCurrentPage('work-order-detail');
        } else {
          setCurrentPage('work-orders-list');
        }
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/workstations', () => {
      if (isAuthenticated) {
        setCurrentPage('workstations');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/workstations/:id', () => {
      if (isAuthenticated) {
        const path = window.location.pathname;
        const match = path.match(/\/manufacturing\/workstations\/([^/]+)/);
        const wcId = match ? match[1] : null;
        if (wcId) {
          setCurrentPage('workstation-detail');
          sessionStorage.setItem('currentWorkCenterId', wcId);
        } else {
          setCurrentPage('workstations');
        }
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/calendar', () => {
      if (isAuthenticated) {
        setCurrentPage('production-calendar');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/finished-goods', () => {
      if (isAuthenticated) {
        setCurrentPage('finished-goods');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/cut-optimization', () => {
      if (isAuthenticated) {
        setCurrentPage('cut-optimization');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/delivery-notes/new', () => {
      if (isAuthenticated) {
        setCurrentPage('delivery-note-new');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/manufacturing/delivery-notes/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('delivery-note-detail');
      } else {
        setCurrentPage('login');
      }
    });
    // Legacy route redirect
    router.addRoute('/manufacturing/bill-of-materials', () => {
      if (isAuthenticated) {
        router.navigate('/manufacturing/manufacturing-orders', false);
      } else {
        setCurrentPage('login');
      }
    });
    
    // Financials routes
    router.addRoute('/financials', () => {
      if (isAuthenticated) { setCurrentPage('financials'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/invoices', () => {
      if (isAuthenticated) { setCurrentPage('financials-invoices'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/accounts', () => {
      if (isAuthenticated) { setCurrentPage('financials-accounts'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/accounts/:dealerId', () => {
      if (isAuthenticated) { setCurrentPage('financials-account-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/invoices/new', () => {
      if (isAuthenticated) { setCurrentPage('financials-invoice-new'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/invoices/:id', () => {
      if (isAuthenticated) { setCurrentPage('financials-invoice-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/payments', () => {
      if (isAuthenticated) { setCurrentPage('financials-payments'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/payments/:id', () => {
      if (isAuthenticated) { setCurrentPage('financials-payment-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/vendor-accounts', () => {
      if (isAuthenticated) { setCurrentPage('financials-vendor-accounts'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/vendor-accounts/:vendorId', () => {
      if (isAuthenticated) { setCurrentPage('financials-vendor-account-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/bills', () => {
      if (isAuthenticated) { setCurrentPage('financials-bills'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/bills/new', () => {
      if (isAuthenticated) { setCurrentPage('financials-bill-new'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/bills/:id', () => {
      if (isAuthenticated) { setCurrentPage('financials-bill-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/purchase-orders', () => {
      if (isAuthenticated) { setCurrentPage('financials-purchase-orders'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/vendor-payments', () => {
      if (isAuthenticated) { setCurrentPage('financials-vendor-payments'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/financials/vendor-payments/:id', () => {
      if (isAuthenticated) { setCurrentPage('financials-vendor-payment-detail'); } else { setCurrentPage('login'); }
    });

    // Partners routes
    router.addRoute('/partners', () => {
      if (isAuthenticated) { setCurrentPage('partners'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealers', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealers/new', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealers/edit/:id', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealers/edit/:id/terms', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealers/:id', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealer-detail'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealer-users/new', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/dealer-users/edit/:id', () => {
      if (isAuthenticated) { setCurrentPage('partners-dealers'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/vendors', () => {
      if (isAuthenticated) { setCurrentPage('partners-vendors'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/vendors/new', () => {
      if (isAuthenticated) { setCurrentPage('partners-vendor-form'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/vendors/edit/:id', () => {
      if (isAuthenticated) { setCurrentPage('partners-vendor-form'); } else { setCurrentPage('login'); }
    });
    router.addRoute('/partners/manufacturers', () => {
      if (isAuthenticated) { setCurrentPage('partners-manufacturers'); } else { setCurrentPage('login'); }
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
    router.addRoute('/settings/dealer-users', () => {
      if (isAuthenticated) {
        router.navigate('/settings/dealer-account', false);
        setCurrentPage('dealer-account');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-account', () => {
      if (isAuthenticated) {
        setCurrentPage('dealer-account');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-account/terms', () => {
      if (isAuthenticated) {
        setCurrentPage('dealer-account');
      } else {
        setCurrentPage('login');
      }
    });
    // Legacy: redirect old URL to Dealer Account
    router.addRoute('/settings/company-portal-users', () => {
      if (isAuthenticated) {
        router.navigate('/settings/dealer-account', false);
        setCurrentPage('dealer-account');
      } else {
        setCurrentPage('login');
      }
    });
    
    // Dealer Profile routes
    router.addRoute('/settings/dealer-profile', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-profile/new', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-profile/edit/:id', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-profile/edit/:id/terms', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    // Redirect legacy Dealer User tab to Dealer List (user management is in Dealer Detail)
    router.addRoute('/settings/dealer-profile/user', () => {
      if (isAuthenticated) {
        router.navigate('/settings/dealer-profile', false);
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/organization', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/cost-engine', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/work-centers', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/fabric-rules', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/dealer-tiers', () => {
      if (isAuthenticated) {
        setCurrentPage('company-settings');
        router.navigate('/settings/cost-engine');
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/settings/roles', () => {
      if (isAuthenticated) {
        setCurrentPage('admin-roles');
        router.navigate('/admin/roles', false);
      } else {
        setCurrentPage('login');
      }
    });
    router.addRoute('/admin/roles', () => {
      if (isAuthenticated) {
        setCurrentPage('admin-roles');
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
      const currentPath = `${window.location.pathname}${window.location.search}${window.location.hash}`;
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
    // CRITICAL: Check pathname FIRST before any auth checks
    // This prevents redirect during auth flows
    const currentPath = window.location.pathname;
    
    // List of paths that should NEVER redirect to login
    const authPaths = [
      '/login',
      '/signup',
      '/auth/callback',
      '/auth/accept',
      '/accept-invite',
      '/set-password',
      '/reset-password',
      '/new-password',
      '/auth/reset-password',
      '/company-registration',
      '/access-denied'
    ];
    
    const isAuthPath = authPaths.some(path => currentPath.startsWith(path));
    
    if (isAuthPath) {
      console.log('[App] Skipping login redirect - on auth path:', currentPath);
      return;
    }

    if (!isAuthenticated && !isLoading && !isErrorPage) {
      console.log('[App] Redirecting to login - not authenticated');
      router.navigate('/login', true);
    }
  }, [isAuthenticated, isLoading, isErrorPage]);


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
      
      // Directory module pages (Contacts + Customers in one wrapper to avoid flash on tab switch)
      case 'directory-contacts':
        return <RequireModule module="directory"><Directory activeTab="contacts" /></RequireModule>;
      case 'directory-contact-new':
        return <RequireModule module="directory"><DirectoryContactNew /></RequireModule>;
      case 'directory-customers':
        return <RequireModule module="directory"><Directory activeTab="customers" /></RequireModule>;
      case 'directory-customer-new':
        return <RequireModule module="directory"><DirectoryCustomerNew /></RequireModule>;
      case 'test-directory':
        return <RequireModule module="directory"><TestDirectory /></RequireModule>;
      
      // Sales module pages (protected but accessible to portal)
      case 'sales':
        return <RequireModule module="sales"><Sales /></RequireModule>;
      case 'quotes':
        return <RequireModule module="sales"><SalesDirectory activeTab="quotes" /></RequireModule>;
      case 'quote-detail':
        return <RequireModule module="sales"><QuoteDetail /></RequireModule>;
      case 'quote-new':
        return <RequireModule module="sales"><QuoteNew /></RequireModule>;
      case 'proposals':
      case 'proposal-detail':
        return <RequireModule module="sales"><SalesDirectory activeTab="proposals" /></RequireModule>;
      case 'orders':
        return <RequireModule module="sales"><SalesDirectory activeTab="orders" /></RequireModule>;
      case 'order-detail':
        return <RequireModule module="sales"><SalesOrderDetail /></RequireModule>;
      case 'catalog':
        return <RequireModule module="catalog"><Catalog /></RequireModule>;
      case 'items':
        return <RequireModule module="catalog"><CatalogModule activeTab="items" /></RequireModule>;
      case 'catalog-item-new':
        return <RequireModule module="catalog"><CatalogItemNew /></RequireModule>;
      case 'manufacturers':
        return <RequireModule module="catalog"><Manufacturers /></RequireModule>;
      case 'categories':
        return <RequireModule module="catalog"><Categories /></RequireModule>;
      case 'collections':
        return <RequireModule module="catalog"><Collections /></RequireModule>;
      case 'bom':
        return <RequireModule module="catalog"><CatalogModule activeTab="bom" /></RequireModule>;
      // Variants case removed - use CollectionsCatalog instead
      case 'inventory':
        return <Inventory />;
      case 'warehouse':
        return <Warehouse />;
      case 'inventory-item-detail': {
        const itemId = sessionStorage.getItem('currentInventoryItemId');
        return itemId ? <InventoryItemDetail itemId={itemId} /> : <Warehouse />;
      }
      case 'inventory-purchase-orders':
        return <PurchaseOrders />;
      case 'inventory-purchase-order-detail': {
        const poId = sessionStorage.getItem('currentPurchaseOrderId');
        return poId ? <PurchaseOrderDetail poId={poId} /> : <PurchaseOrderDetail />;
      }
      case 'inventory-receipts':
        return <Receipts />;
      case 'transactions':
        return <Transactions />;
      case 'inventory-adjustments':
        return <Adjustments />;
      case 'transaction-new':
        return <TransactionDetail />;
      case 'transaction-detail': {
        const txId = sessionStorage.getItem('currentTransactionId');
        if (txId) return <TransactionDetail transactionId={txId} />;
        const path = window.location.pathname;
        if (path.startsWith('/inventory/adjustments')) {
          return <Adjustments />;
        }
        return <Transactions />;
      }
      case 'material-demand':
        return <MaterialDemand />;
      case 'manufacturing':
        return <RequireModule module="manufacturing"><Manufacturing /></RequireModule>;
      case 'manufacturing-orders':
        return <RequireModule module="manufacturing"><ManufacturingOrders /></RequireModule>;
      case 'manufacturing-order-detail': {
        const moId = sessionStorage.getItem('currentManufacturingOrderId');
        return <RequireModule module="manufacturing">{moId ? <ManufacturingOrderDetail moId={moId} /> : <ManufacturingOrders />}</RequireModule>;
      }
      case 'work-orders-list':
        return <RequireModule module="manufacturing"><WorkOrdersList /></RequireModule>;
      case 'work-order-detail': {
        const woMoId = sessionStorage.getItem('currentWorkOrderMoId');
        return <RequireModule module="manufacturing">{woMoId ? <WorkOrderDetail moId={woMoId} /> : <WorkOrdersList />}</RequireModule>;
      }
      case 'workstations':
        return <RequireModule module="manufacturing"><WorkstationView /></RequireModule>;
      case 'production-calendar':
        return <RequireModule module="manufacturing"><ProductionCalendar /></RequireModule>;
      case 'finished-goods':
        return <RequireModule module="manufacturing"><FinishedGoods /></RequireModule>;
      case 'cut-optimization':
        return <RequireModule module="manufacturing"><CutOptimization /></RequireModule>;
      case 'delivery-note-new':
      case 'delivery-note-detail':
        return <RequireModule module="manufacturing"><DeliveryNoteDetail /></RequireModule>;
      case 'workstation-detail': {
        const wcId = sessionStorage.getItem('currentWorkCenterId');
        return <RequireModule module="manufacturing"><WorkstationView workCenterId={wcId ?? undefined} /></RequireModule>;
      }
      case 'material':
        return <RequireModule module="manufacturing"><ApprovedBOMList /></RequireModule>;
      case 'bill-of-materials':
        return <RequireModule module="manufacturing"><ApprovedBOMList /></RequireModule>; // Legacy support - redirect to ApprovedBOMList
      case 'financials':
        return <RequireModule module="financials"><Financials /></RequireModule>;
      case 'financials-accounts':
        return <RequireModule module="financials"><DealerAccounts /></RequireModule>;
      case 'financials-account-detail':
        return <RequireModule module="financials"><DealerAccountDetail /></RequireModule>;
      case 'financials-invoices':
        return <RequireModule module="financials"><Invoices /></RequireModule>;
      case 'financials-invoice-new':
        return <RequireModule module="financials"><InvoiceNew /></RequireModule>;
      case 'financials-invoice-detail':
        return <RequireModule module="financials"><InvoiceDetail /></RequireModule>;
      case 'financials-payments':
        return <RequireModule module="financials"><FinancialPayments /></RequireModule>;
      case 'financials-payment-detail':
        return <RequireModule module="financials"><PaymentDetail /></RequireModule>;
      case 'financials-vendor-accounts':
        return <RequireModule module="financials"><VendorAccountsList /></RequireModule>;
      case 'financials-vendor-account-detail':
        return <RequireModule module="financials"><VendorAccountDetail /></RequireModule>;
      case 'financials-bills':
        return <RequireModule module="financials"><BillsList /></RequireModule>;
      case 'financials-bill-new':
        return <RequireModule module="financials"><BillNew /></RequireModule>;
      case 'financials-bill-detail':
        return <RequireModule module="financials"><BillDetail /></RequireModule>;
      case 'financials-purchase-orders':
        return <RequireModule module="financials"><PurchaseOrdersAP /></RequireModule>;
      case 'financials-vendor-payments':
        return <RequireModule module="financials"><VendorPaymentsList /></RequireModule>;
      case 'financials-vendor-payment-detail':
        return <RequireModule module="financials"><VendorPaymentDetail /></RequireModule>;
      case 'partners':
        return <RequireModule module="settings"><Partners /></RequireModule>;
      case 'partners-dealers':
        return <RequireModule module="settings"><PartnerDealers /></RequireModule>;
      case 'partners-dealer-detail':
        return <RequireModule module="settings"><DealerDetail /></RequireModule>;
      case 'partners-vendors':
        return <RequireModule module="settings"><PartnerVendors /></RequireModule>;
      case 'partners-vendor-form': {
        const path = window.location.pathname;
        const match = path.match(/\/partners\/vendors\/edit\/([^/]+)/);
        const vendorId = match?.[1] ?? null;
        return <RequireModule module="settings"><PartnerVendorForm vendorId={vendorId} /></RequireModule>;
      }
      case 'partners-manufacturers':
        return <RequireModule module="settings"><PartnerManufacturers /></RequireModule>;

      case 'reports':
        return <CompanyReports />;
      case 'company-reports':
        return <CompanyReports />;
      case 'company-settings':
        return <RequireModule module="settings"><CompanySettings /></RequireModule>;
      case 'organization-users':
        return <OrganizationUsers organizationId={null} />;
      case 'organization-user':
        return <OrganizationUser />;
      case 'dealer-users':
      case 'dealer-account':
        return <DealerAccount />;
      case 'roles':
      case 'admin-roles':
        return <RequireModule module="settings"><AdminRoles /></RequireModule>;
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
      case 'set-password':
        return <SetPassword />;
      case 'auth-accept':
        return <AcceptInvite />;
      case 'access-denied':
        return <AccessDenied />;
      case 'auth-reset-password':
        return <ResetPasswordForm />;
      case 'select-acting-dealer':
        router.navigate('/');
        return <ManagementDashboard />;

      default:
        return <ManagementDashboard />;
    }
  };

  return (
    <ErrorBoundary>
      <Toast />
      <SupabaseStatusBanner />
      <div className="min-h-dvh bg-background">
        {(() => {
          // Check pathname directly to avoid timing issues
          const currentPath = window.location.pathname;
          const authPaths = [
            '/login', '/signup', '/auth/callback', '/auth/accept', '/accept-invite', '/set-password',
            '/reset-password', '/new-password', '/auth/reset-password',
            '/company-registration', '/access-denied'
          ];
          const isAuthPath = authPaths.some(path => currentPath.startsWith(path));

          if (!isAuthenticated && !isAuthPath && !isLoading) {
            return (
          <div className="min-h-dvh flex items-center justify-center p-6">
            <div className="text-center">
              <p className="text-muted-foreground">Redirecting to login...</p>
            </div>
          </div>
            );
          }

          if (isAuthPage || isLoading || isAuthPath) {
            return (
          <ErrorBoundary>
            <Suspense fallback={
              <div className="min-h-dvh flex items-center justify-center bg-background">
                <div className="flex flex-col items-center gap-4">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
                  <p className="text-sm text-muted-foreground">
                    {isLoading ? 'Verifying access...' : 'Loading...'}
                  </p>
                </div>
              </div>
            }>
              {renderPage()}
            </Suspense>
          </ErrorBoundary>
            );
          }

          if (isErrorPage) {
            return (
          <ErrorBoundary>
            <Suspense fallback={null}>
              {renderPage()}
            </Suspense>
          </ErrorBoundary>
            );
          }

          if (currentPage === 'company-settings') {
            return (
          <ErrorBoundary>
            <Suspense fallback={null}>
              <RequireModule module="settings">
                <CompanySettings />
              </RequireModule>
            </Suspense>
          </ErrorBoundary>
            );
          }

          if (currentPage === 'proposal-print') {
            return (
              <ErrorBoundary>
                <Suspense fallback={<div className="p-6">Loading...</div>}>
                  <RequireModule module="sales">
                    <ProposalPrint />
                  </RequireModule>
                </Suspense>
              </ErrorBoundary>
            );
          }

          if (currentPage === 'select-acting-dealer') {
            router.navigate('/');
            return (
              <ErrorBoundary>
                <ManagementDashboard />
              </ErrorBoundary>
            );
          }

          // Regular pages with layout - protected by AuthGate
          return (
          <AuthGate>
            <SuperAdminActingGate>
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
            </SuperAdminActingGate>
          </AuthGate>
          );
        })()}
      </div>
    </ErrorBoundary>
  );
}

export default App;

