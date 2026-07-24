import React, { ReactNode, useState, useCallback, useMemo, useEffect, useRef, memo } from 'react';
import { createPortal } from 'react-dom';
import { useAuth } from '../hooks/useAuth';
import { router } from '../lib/router';
import { supabase } from '../lib/supabase/client';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { useUIStore } from '../stores/ui-store';
import { usePreviousPage } from '../hooks/usePreviousPage';
import { useCurrentOrgRole } from '../hooks/useCurrentOrgRole';
import { usePermissions, MODULE_PERMS, canReadPath } from '../hooks/usePermissions';
import { useAccessContext, ModuleKey } from '../hooks/useAccessContext';
import { useActiveDealer } from '../hooks/useActiveDealer';
import { useNotifications } from '../hooks/useNotifications';
import { useOrganizationContext } from '../context/OrganizationContext';
import { OrganizationSwitcher } from './layout/OrganizationSwitcher';
import { ActingAsSwitcher } from './layout/ActingAsSwitcher';
import { 
  getSidebarStyles, 
  getButtonStyles, 
  getHoverStyles, 
  getTextStyles, 
  getLogoTextColor,
  getSettingsUrl,
  getDashboardUrl,
  getViewModeLabel,
  getNavigationButtonProps,
  getDashboardButtonProps,
  getSettingsButtonState,
  createNavItemContent,
} from '../utils/viewModeStyles';
import AdaptioMark from './AdaptioMark';
import { 
  Users, 
  User,
  Clock, 
  Settings, 
  Home, 
  Bell, 
  Search, 
  HelpCircle,
  Building, 
  Building2,
  Printer,
  CalendarCheck,
  Check,
  BookOpen,
  ShoppingBag,
  Book,
  Package,
  Wrench,
  DollarSign,
  Wallet,
  FileText,
  RefreshCw,
  Handshake,
  LifeBuoy,
  Calculator
} from 'lucide-react';
import { useDirectoryLoadStore } from '../stores/directory-load-store';

interface LayoutProps {
  children: ReactNode;
}

/** Tabs por módulo para el menú flotante del sidebar (sidebar siempre colapsado) */
const MODULE_TABS: Record<string, { label: string; href: string }[]> = {
  '/dashboard': [],
  '/directory': [
    { label: 'Customers', href: '/directory/customers' },
    { label: 'Contacts', href: '/directory/contacts' },
  ],
  '/sales/quotes': [
    { label: 'Quotes', href: '/sales/quotes' },
    { label: 'Proposals', href: '/sales/proposals' },
    { label: 'Orders', href: '/sales/orders' },
  ],
  '/sales/proposals': [
    { label: 'Quotes', href: '/sales/quotes' },
    { label: 'Proposals', href: '/sales/proposals' },
    { label: 'Orders', href: '/sales/orders' },
  ],
  '/sales/orders': [
    { label: 'Quotes', href: '/sales/quotes' },
    { label: 'Proposals', href: '/sales/proposals' },
    { label: 'Orders', href: '/sales/orders' },
  ],
  '/catalog': [
    { label: 'Items', href: '/catalog/items' },
    { label: 'BOM', href: '/catalog/bom' },
  ],
  '/inventory': [
    { label: 'Warehouse', href: '/inventory/warehouse' },
    { label: 'Locations', href: '/inventory/locations' },
    { label: 'Purchase Orders', href: '/inventory/purchase-orders' },
    { label: 'Receipts', href: '/inventory/receipts' },
    { label: 'Deliveries', href: '/inventory/deliveries' },
    { label: 'Transactions', href: '/inventory/transactions' },
    { label: 'Adjustments', href: '/inventory/adjustments' },
    { label: 'Material Demand', href: '/inventory/material-demand' },
  ],
  '/manufacturing': [
    { label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders' },
    { label: 'Workstation', href: '/manufacturing/workstations' },
    { label: 'Calendar', href: '/manufacturing/calendar' },
    { label: 'Cut Optimization', href: '/manufacturing/cut-optimization' },
    { label: 'Finished Goods', href: '/manufacturing/finished-goods' },
  ],
  '/financials': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/accounts': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/invoices': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/payments': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/vendor-accounts': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/purchase-orders': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/bills': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/financials/vendor-payments': [
    { label: 'Accounts Receivable', href: '/financials/accounts' },
    { label: 'Accounts Payable', href: '/financials/vendor-accounts' },
  ],
  '/accounting': [
    { label: 'Chart of Accounts', href: '/accounting/chart' },
    { label: 'Journal Entries', href: '/accounting/journal' },
    { label: 'Reports', href: '/accounting/reports' },
  ],
  '/accounting/chart': [
    { label: 'Chart of Accounts', href: '/accounting/chart' },
    { label: 'Journal Entries', href: '/accounting/journal' },
    { label: 'Reports', href: '/accounting/reports' },
  ],
  '/accounting/journal': [
    { label: 'Chart of Accounts', href: '/accounting/chart' },
    { label: 'Journal Entries', href: '/accounting/journal' },
    { label: 'Reports', href: '/accounting/reports' },
  ],
  '/accounting/reports': [
    { label: 'Chart of Accounts', href: '/accounting/chart' },
    { label: 'Journal Entries', href: '/accounting/journal' },
    { label: 'Reports', href: '/accounting/reports' },
  ],
  '/my-financials': [
    { label: 'Invoices', href: '/my-financials/invoices' },
    { label: 'Payments', href: '/my-financials/payments' },
  ],
  '/partners': [
    { label: 'Dealers', href: '/partners/dealers' },
    { label: 'Vendors', href: '/partners/vendors' },
    { label: 'Manufacturers', href: '/partners/manufacturers' },
  ],
  '/service/claims': [
    { label: 'Claims', href: '/service/claims' },
  ],
};

function getPortalFinancialTabs(portalRole: 'dealer_member' | 'dealer_manager' | null | undefined): { label: string; href: string }[] {
  const base = [
    { label: 'Invoices', href: '/my-financials/invoices' },
    { label: 'Payments', href: '/my-financials/payments' },
  ];
  if (portalRole === 'dealer_manager') {
    return [...base, { label: 'Statement', href: '/my-financials/statement' }];
  }
  return base;
}

function getCatalogTabs(can: (permissionCode: string) => boolean): { label: string; href: string }[] {
  const tabs = [{ label: 'Items', href: '/catalog/items' }];
  if (can('catalog.write')) tabs.push({ label: 'BOM', href: '/catalog/bom' });
  return tabs;
}

function getManufacturingTabs(can: (permissionCode: string) => boolean): { label: string; href: string }[] {
  const tabs: { label: string; href: string }[] = [];
  if (can('manufacturing.mo.read')) tabs.push({ label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders' });
  if (can('manufacturing.wo.read')) tabs.push({ label: 'Workstation', href: '/manufacturing/workstations' });
  if (can('manufacturing.calendar.read')) tabs.push({ label: 'Calendar', href: '/manufacturing/calendar' });
  if (can('manufacturing.cutopt.read') || can('manufacturing.wo.read')) {
    tabs.push({ label: 'Cut Optimization', href: '/manufacturing/cut-optimization' });
  }
  if (can('manufacturing.finished_goods.read')) tabs.push({ label: 'Finished Goods', href: '/manufacturing/finished-goods' });
  return tabs;
}

/** Línea de carga en la parte superior del header. Usa globalLoading del store; retraso mínimo al ocultar para evitar parpadeo. */
const MIN_HIDE_DELAY_MS = 320;
function TopBarLoading() {
  const globalLoading = useUIStore((s) => s.globalLoading);
  const [visible, setVisible] = useState(false);
  const hideTimeoutRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (globalLoading) {
      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current);
        hideTimeoutRef.current = null;
      }
      setVisible(true);
      return;
    }
    if (!visible) return;
    hideTimeoutRef.current = setTimeout(() => {
      hideTimeoutRef.current = null;
      setVisible(false);
    }, MIN_HIDE_DELAY_MS);
    return () => {
      if (hideTimeoutRef.current) clearTimeout(hideTimeoutRef.current);
    };
  }, [globalLoading, visible]);

  if (!visible) return null;
  return (
    <div
      className="absolute left-0 right-0 top-0 h-0.5 rounded-full overflow-hidden bg-gray-200 z-50"
      aria-hidden="true"
    >
      <div
        className="h-full w-1/3 rounded-full bg-primary animate-pulse"
        style={{ animationDuration: '1.2s' }}
      />
    </div>
  );
}

// Memoized navigation item component
const NavigationItem = memo(({ 
  item, 
  isActive, 
  isCollapsed, 
  onClick,
  viewMode
}: {
  item: { name: string; href: string; icon: React.ComponentType<{ style?: React.CSSProperties }> };
  isActive: boolean;
  isCollapsed: boolean;
  onClick: () => void;
  viewMode: 'manager';
}) => {
  const buttonStyles = getButtonStyles(viewMode, isActive);
  const textStyles = getTextStyles(viewMode, isActive);
  const hoverStyles = getHoverStyles(viewMode);

  return (
  <button
    onClick={onClick}
      className="flex items-center font-normal transition-colors group relative w-full"
    style={{
      fontSize: '14px',
      minHeight: '36px',
        padding: '12px 16px 12px 14px',
        ...buttonStyles
    }}
    onMouseEnter={(e) => {
      if (!isActive) {
          e.currentTarget.style.backgroundColor = hoverStyles.backgroundColor;
      }
    }}
    onMouseLeave={(e) => {
      if (!isActive) {
        e.currentTarget.style.backgroundColor = 'transparent';
      }
    }}
    aria-current={isActive ? 'page' : undefined}
      aria-label={`${item.name}${isActive ? ' (current page)' : ''}`}
      aria-describedby={isCollapsed ? `${item.name.toLowerCase().replace(/\s+/g, '-')}-tooltip` : undefined}
    >
      <div 
        className="flex items-center justify-center" 
        style={{ width: '18px', height: '18px', flexShrink: 0 }}
        aria-hidden="true"
      >
      <item.icon style={{ width: '18px', height: '18px', color: textStyles.color }} />
    </div>
    <span 
      className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
      style={{
        opacity: isCollapsed ? 0 : 1,
        pointerEvents: isCollapsed ? 'none' : 'auto',
        fontSize: '14px',
          ...textStyles
      }}
    >
      {item.name}
    </span>
  </button>
  );
});

NavigationItem.displayName = 'NavigationItem';

const baseNavigation = [
  { name: 'Dashboard', href: '/dashboard', icon: Home }, // Will be handled dynamically based on view mode
];



function Layout({ children }: LayoutProps) {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const { logout, user } = useAuth();
  const [currentOrganization, setCurrentOrganization] = useState<{ id: string; name: string } | null>(null);
  const [currentRoute, setCurrentRoute] = useState(() => router.getCurrentRoute() || '/');
  const { tabs: submoduleTabs, breadcrumbs, clearSubmoduleNav } = useSubmoduleNav();
  const { saveCurrentPageBeforeSettings } = usePreviousPage();
  const { isMember, isSuperAdmin, role: currentRole } = useCurrentOrgRole();
  const { can, loading: permissionsLoading } = usePermissions();
  const { allowedModules, loading: accessLoading, userType, portalRole } = useAccessContext();
  const { activeOrganization, role: orgContextRole } = useOrganizationContext();

  // Solo Organization Super Admin ve el switcher "Dealer Account" (rol canónico: superadmin)
  const isSuperAdminUser = isSuperAdmin || orgContextRole === 'superadmin' || currentRole === 'superadmin';
  const isAdminUser = orgContextRole === 'admin' || currentRole === 'admin';

  // Acting-as dealer filter: org users who coordinate or manage multi-dealer scope (RLS + lists respect current_dealer_id).
  const showDealerSwitcher =
    userType === 'internal' &&
    (isSuperAdminUser || currentRole === 'admin' || currentRole === 'sales_coordinator');
  const { activeDealerId, activeDealer } = useActiveDealer();
  const normalizeDisplayName = (value: string | null | undefined) =>
    String(value ?? '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  const orgDisplayName = activeOrganization?.name ?? '';
  const dealerDisplayName = activeDealer?.dealer_name ?? '';
  const showSingleScopeName =
    normalizeDisplayName(orgDisplayName).length > 0 &&
    normalizeDisplayName(orgDisplayName) === normalizeDisplayName(dealerDisplayName);
  const scopeDisplayLabel = dealerDisplayName
    ? (showSingleScopeName ? dealerDisplayName : `${orgDisplayName} · ${dealerDisplayName}`)
    : orgDisplayName;
  const currentScopeKey = `${activeOrganization?.id ?? 'none'}:${activeDealerId ?? 'none'}`;
  const {
    loadContacts: directoryLoadContacts,
    loadCustomers: directoryLoadCustomers,
    loadQuotes: directoryLoadQuotes,
    loadProposals: directoryLoadProposals,
    loadOrders: directoryLoadOrders,
    contactsScopeKey: storeContactsScopeKey,
    customersScopeKey: storeCustomersScopeKey,
    quotesScopeKey: storeQuotesScopeKey,
    proposalsScopeKey: storeProposalsScopeKey,
    ordersScopeKey: storeOrdersScopeKey,
  } = useDirectoryLoadStore();
  const isOnDirectory =
    currentRoute.includes('/directory/contacts') || currentRoute.includes('/directory/customers');
  const isOnSalesQuotes = currentRoute.includes('/sales/quotes');
  const isOnSalesProposals = currentRoute.includes('/sales/proposals');
  const isOnSalesOrders = currentRoute.includes('/sales/orders');
  const isOnSales = isOnSalesQuotes || isOnSalesProposals || isOnSalesOrders;

  // Directory: show Apply only when we have an applied scope (non-empty) and it differs from selected dealer
  const hasContactsScope = storeContactsScopeKey != null && storeContactsScopeKey !== '';
  const hasCustomersScope = storeCustomersScopeKey != null && storeCustomersScopeKey !== '';
  const needsApplyDirectory =
    (hasContactsScope && currentScopeKey !== storeContactsScopeKey) ||
    (hasCustomersScope && currentScopeKey !== storeCustomersScopeKey);

  // Sales: show Apply only when the current tab has an applied scope (non-empty) and it differs from selected dealer
  const hasQuotesScope = storeQuotesScopeKey != null && storeQuotesScopeKey !== '';
  const hasProposalsScope = storeProposalsScopeKey != null && storeProposalsScopeKey !== '';
  const hasOrdersScope = storeOrdersScopeKey != null && storeOrdersScopeKey !== '';
  const needsApplySalesCurrentTab =
    (isOnSalesQuotes && hasQuotesScope && currentScopeKey !== storeQuotesScopeKey) ||
    (isOnSalesProposals && hasProposalsScope && currentScopeKey !== storeProposalsScopeKey) ||
    (isOnSalesOrders && hasOrdersScope && currentScopeKey !== storeOrdersScopeKey);
  const hasCurrentSalesLoader =
    (isOnSalesQuotes && directoryLoadQuotes) ||
    (isOnSalesProposals && directoryLoadProposals) ||
    (isOnSalesOrders && directoryLoadOrders);

  const showApplyButton =
    showDealerSwitcher &&
    ((isOnDirectory && needsApplyDirectory && directoryLoadContacts && directoryLoadCustomers) ||
      (isOnSales && needsApplySalesCurrentTab && hasCurrentSalesLoader));

  const {
    notifications,
    unreadCount: unreadBellCount,
    markAsRead: markNotificationAsRead,
    markAllAsRead: markAllNotificationsAsRead,
    loading: notificationsLoading,
  } = useNotifications(25);

  // Debug log for SuperAdmin detection
  if (import.meta.env.DEV) {
    console.log("[Layout] Role check:", {
      isSuperAdmin,
      isSuperAdminUser,
      currentRole,
      orgContextRole,
      userType,
      allowedModules,
      permissionsLoading,
      accessLoading
    });
  }
  
  // Use UI store for view mode state (sidebar siempre colapsado; sin toggle)
  const { 
    viewMode: storeViewMode, 
    setViewMode 
  } = useUIStore();
  
  // Ensure viewMode is always valid, default to 'manager'
  const viewMode = storeViewMode || 'manager';

  // Check if we're in Settings pages - if so, hide the main sidebar. Exception: /settings/dealer-account and /settings/dealer-users show sidebar so Dealer Managers can navigate.
  const isSettingsRoute = currentRoute.includes('/settings')
    && !currentRoute.startsWith('/settings/dealer-account')
    && !currentRoute.startsWith('/settings/dealer-users');
  
  // Debug: Log sidebar visibility status
  if (import.meta.env.DEV) {
    console.log('[Layout] Sidebar visibility:', {
      currentRoute,
      isSettingsRoute,
      shouldShowSidebar: !isSettingsRoute
    });
  }

  // Helper functions to get/set last visited route for a module
  const getLastRouteForModule = useCallback((modulePath: string): string | null => {
    try {
      return sessionStorage.getItem(`lastRoute_${modulePath}`);
    } catch {
      return null;
    }
  }, []);

  const setLastRouteForModule = useCallback((modulePath: string, route: string) => {
    try {
      sessionStorage.setItem(`lastRoute_${modulePath}`, route);
    } catch {
      // Ignore storage errors
    }
  }, []);

  // Helper function to save current route for module persistence
  const saveCurrentRouteForModule = useCallback((route: string) => {
    if (route.startsWith('/directory')) {
      setLastRouteForModule('/directory', route);
    } else if (route.startsWith('/sales')) {
      setLastRouteForModule('/sales', route);
    } else if (route.startsWith('/catalog')) {
      setLastRouteForModule('/catalog', route);
    } else if (route.startsWith('/inventory')) {
      setLastRouteForModule('/inventory', route);
    } else if (route.startsWith('/manufacturing')) {
      // Retired standalone Work Orders list — never persist it.
      if (route === '/manufacturing/work-orders' || route.startsWith('/manufacturing/work-orders?')) {
        // skip
      } else {
        const moMatch = route.match(/^\/manufacturing\/work-orders\/([^/?#]+)/);
        if (moMatch) {
          setLastRouteForModule(
            '/manufacturing',
            `/manufacturing/manufacturing-orders/${moMatch[1]}?tab=work-orders`,
          );
        } else {
          setLastRouteForModule('/manufacturing', route);
        }
      }
    } else if (route.startsWith('/financials')) {
      setLastRouteForModule('/financials', route);
    } else if (route.startsWith('/accounting')) {
      setLastRouteForModule('/accounting', route);
    } else if (route.startsWith('/partners')) {
      setLastRouteForModule('/partners', route);
    }
  }, [setLastRouteForModule]);

  // Scroll to top when route changes and save route for module persistence
  // Also clear submodules when switching between main modules
  useEffect(() => {
    const routeFromRouter = router.getCurrentRoute();
    if (routeFromRouter !== currentRoute) {
      const previousModule = currentRoute.split('/')[1];
      const newModule = routeFromRouter.split('/')[1];
      
      // Always clear submodules when route changes - let the new page register its own
      // This ensures we don't have stale submodules from previous pages
      // Clear immediately to prevent stale submodules from showing
      if (previousModule && newModule && previousModule !== newModule) {
        // Clear immediately when switching between different main modules
        clearSubmoduleNav();
      }
      
      setCurrentRoute(routeFromRouter);
      // Save current route for module persistence
      saveCurrentRouteForModule(routeFromRouter);
      // Additional scroll to top to ensure it works
      window.scrollTo(0, 0);
      // Also scroll the main content area if it exists
      const mainElement = document.querySelector('main[role="main"]');
      if (mainElement) {
        mainElement.scrollTop = 0;
      }
    }
  }, [currentRoute, saveCurrentRouteForModule, clearSubmoduleNav]);

  // Update current route when router changes and persist for module restoration
  useEffect(() => {
    const updateRoute = () => {
      const route = router.getCurrentRoute();
      const previousRoute = previousRouteRef.current;
      const previousModule = previousRoute.split('/')[1];
      const newModule = route.split('/')[1];
      if (previousModule && newModule && previousModule !== newModule) {
        clearSubmoduleNav();
      }
      previousRouteRef.current = route;
      setCurrentRoute(route);
      saveCurrentRouteForModule(route);
    };

    const removeListener = router.addListener(updateRoute);
    updateRoute();

    return () => {
      removeListener();
    };
  }, [saveCurrentRouteForModule, clearSubmoduleNav]);

  // OBSOLETO: Este código está duplicado y usa el schema antiguo.
  // OrganizationContext ya maneja esto correctamente.
  // TODO: Migrar a usar OrganizationContext.organizationName en lugar de currentOrganization state.
  // Por ahora dejamos currentOrganization como null para evitar duplicación.
  useEffect(() => {
    setCurrentOrganization(null);
  }, []);

  // Close top-right menus when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('[data-user-menu]')) {
        setIsUserMenuOpen(false);
      }
      if (!target.closest('[data-notifications-menu]')) {
        setIsNotificationsOpen(false);
      }
    };

    if (isUserMenuOpen || isNotificationsOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isUserMenuOpen, isNotificationsOpen]);

  const getNotificationTargetRoute = useCallback((n: { entity_type: string; entity_id: string }) => {
    switch (n.entity_type) {
      case 'sales_order':
        return `/sales/orders/${n.entity_id}`;
      case 'manufacturing_order':
        return `/manufacturing/manufacturing-orders/${n.entity_id}`;
      case 'purchase_order':
        return `/inventory/purchase-orders/${n.entity_id}`;
      case 'dealer_invoice':
        return `/financials/invoices/${n.entity_id}`;
      default:
        return null;
    }
  }, []);

  // Helper function to determine if a navigation item is active
  const isNavItemActive = useCallback((itemName: string, itemHref: string) => {
    switch (itemName) {
      case 'Dashboard':
        // Dashboard is active if we're on root or dashboard routes
        return currentRoute === '/' || currentRoute === '/dashboard' || currentRoute.includes('/dashboard');
      case 'Directory':
        // Directory is active if we're on any directory route
        return currentRoute.includes('/directory');
      case 'Sales':
        return currentRoute.startsWith('/sales');
      case 'Catalog':
        // Catalog is active if we're on any catalog route
        return currentRoute.includes('/catalog');
      case 'Inventory':
        // Inventory is active if we're on any inventory route
        return currentRoute.includes('/inventory');
      case 'Manufacturing':
        // Manufacturing is active if we're on any manufacturing route
        return currentRoute.includes('/manufacturing');
      case 'Financials':
        // Financials (internal cockpit) excludes My Financials routes
        return currentRoute.includes('/financials') && !currentRoute.startsWith('/my-financials');
      case 'My Financials':
        return currentRoute.startsWith('/my-financials');
      case 'Accounting':
        return currentRoute.startsWith('/accounting');
      case 'Partners':
        return currentRoute.includes('/partners');
      case 'Branches':
        // Branches is active if we're on any branches route
        return currentRoute.includes('/branches');
      case 'My Info':
        // My Info is active if we're on any my-info route
        return currentRoute.includes('/my-info');
      case 'Reports':
        // Reports is active if we're on any reports route
        return currentRoute.includes('/reports');
      case 'Settings':
        // Settings is active if we're on any settings route
        return currentRoute.includes('/settings');
      default:
        // For other items, use exact match or check if current route starts with the href
        return currentRoute === itemHref || currentRoute.startsWith(itemHref + '/');
    }
  }, [currentRoute]);

  // Memoized navigation items for management view (filtered by permissions)
  // Usar MODULE_PERMS para consistencia con el sistema RBAC
  const navigation = useMemo(() => {
    // Create base navigation with new tabs according to design
    const dashboardItem = baseNavigation[0]; // Dashboard
    
    // Navigation items aligned with MODULE_PERMS and AccessContext
    type NavItem = { name: string; href: string; icon: any; module?: ModuleKey };
    const allItems: NavItem[] = [
      dashboardItem ? { ...dashboardItem, module: 'dashboard' as const } : { name: 'Dashboard', href: '/dashboard', icon: Home, module: 'dashboard' as const },
      { name: 'Directory', href: '/directory', icon: BookOpen, module: 'directory' },
      { name: 'Sales', href: '/sales/quotes', icon: ShoppingBag, module: 'sales' },
      { name: 'Service', href: '/service/claims', icon: LifeBuoy, module: 'service' },
      { name: 'My Financials', href: '/my-financials', icon: Wallet, module: 'financials' },
      { name: 'Catalog', href: '/catalog', icon: Book, module: 'catalog' },
      { name: 'Inventory', href: '/inventory', icon: Package, module: 'inventory' },
      { name: 'Manufacturing', href: '/manufacturing', icon: Wrench, module: 'manufacturing' },
      ...(userType === 'internal'
        ? [{ name: 'Financials', href: '/financials', icon: DollarSign, module: 'financials' as const }]
        : []),
      ...(userType === 'internal'
        ? [{ name: 'Accounting', href: '/accounting', icon: Calculator, module: 'financials' as const }]
        : []),
      { name: 'Partners', href: '/partners', icon: Handshake, module: 'partners' },
    ];
    
    // ✅ CORRECCIÓN: Lógica separada para portal vs internal
    // Filter items based on allowedModules (AccessContext) and permissions (RBAC)
    if (accessLoading) {
      // Mientras no sabemos userType, mínimo seguro
      return [allItems[0]]; // solo Dashboard
    }

    if (permissionsLoading) {
      // Ya sabemos userType
      if (userType === "portal") {
        return allItems.filter(i => !i.module || allowedModules.includes(i.module));
      }
      return allItems; // internal: ok mostrar mientras carga permisos
    }
    
    // ✅ LOG B) Debug output
    if (import.meta.env.DEV) {
      console.log("[Sidebar] Filtering navigation:", {
        allowedModules,
        userType,
        isSuperAdmin,
        isSuperAdminUser,
        permissionsLoading,
        allItems: allItems.map(i => ({ name: i.name, module: i.module }))
      });
    }
    
    return allItems.filter(item => {
      // Dashboard is always visible (no module)
      if (!item.module) return true;
      
      // ✅ REGLA CORRECTA: Portal users - solo allowedModules (ignorar RBAC)
      if (userType === "portal") {
        const visible = allowedModules.includes(item.module);
        if (import.meta.env.DEV && item.name === "Financials") {
          console.log("[Sidebar] Portal user - Financials:", visible, "allowedModules:", allowedModules);
        }
        return visible;
      }
      
      // ✅ REGLA CORRECTA: Internal users - allowedModules AND RBAC permissions
      if (userType === "internal") {
        // First check: must be in allowedModules (base list)
        if (!allowedModules.includes(item.module)) {
          if (import.meta.env.DEV && item.name === "Financials") {
            console.log("[Sidebar] Internal user - Financials NOT in allowedModules:", allowedModules);
          }
          return false;
        }
        
        // Second check: RBAC permissions (MODULE_PERMS) for non-superadmin users
        const modulePerms = MODULE_PERMS[item.module as keyof typeof MODULE_PERMS];
        if (!modulePerms) {
          if (import.meta.env.DEV && item.name === "Financials") {
            console.log("[Sidebar] Internal user - Financials: No MODULE_PERMS found");
          }
          return false;
        }
        
        // Check if user has any of the view permissions for this module
        const hasPermission = modulePerms.view.some((perm: string) => can(perm));
        if (import.meta.env.DEV && item.name === "Financials") {
          console.log("[Sidebar] Internal user - Financials:", {
            hasPermission,
            perms: modulePerms.view,
            canCheck: modulePerms.view.map(p => ({ perm: p, can: can(p) }))
          });
        }
        return hasPermission;
      }
      
      // Unknown user type - default deny (except dashboard)
      if (import.meta.env.DEV && item.name === "Financials") {
        console.log("[Sidebar] Unknown userType - Financials: DENIED", userType);
      }
      return false;
    });
  }, [can, permissionsLoading, allowedModules, accessLoading, userType, isSuperAdmin]);

  const dashboardItem = useMemo(() => 
    navigation.find(item => item?.name === 'Dashboard' || item?.name === 'Home'), [navigation]
  );
  
  const otherNavItems = useMemo(() => 
    navigation.filter(item => 
      item?.name !== 'Dashboard' && 
      item?.name !== 'Home' && 
      item?.name !== 'Settings' // Exclude Settings since it's rendered separately
    ), [navigation]
  );

  // Hover para menú flotante con tabs (sidebar siempre colapsado)
  const [hoveredNavHref, setHoveredNavHref] = useState<string | null>(null);
  const [popoverRect, setPopoverRect] = useState<{ left: number; top: number } | null>(null);
  const hoverLeaveTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previousRouteRef = useRef<string>(router.getCurrentRoute() || '/');

  const clearHoverLeaveTimeout = useCallback(() => {
    if (hoverLeaveTimeoutRef.current) {
      clearTimeout(hoverLeaveTimeoutRef.current);
      hoverLeaveTimeoutRef.current = null;
    }
  }, []);

  const handleNavItemMouseEnter = useCallback((item: { name: string; href: string; icon: any }, e: React.MouseEvent) => {
    clearHoverLeaveTimeout();
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    setPopoverRect({ left: rect.right, top: rect.top });
    setHoveredNavHref(item.href);
  }, [clearHoverLeaveTimeout]);

  const clearPopoverAndSelection = useCallback(() => {
    setHoveredNavHref(null);
    setPopoverRect(null);
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  }, []);

  const handleNavItemMouseLeave = useCallback(() => {
    hoverLeaveTimeoutRef.current = setTimeout(() => {
      hoverLeaveTimeoutRef.current = null;
      clearPopoverAndSelection();
    }, 150);
  }, [clearPopoverAndSelection]);

  const handlePopoverMouseEnter = useCallback(() => {
    clearHoverLeaveTimeout();
  }, [clearHoverLeaveTimeout]);

  const handlePopoverMouseLeave = useCallback(() => {
    clearPopoverAndSelection();
  }, [clearPopoverAndSelection]);

  useEffect(() => () => clearHoverLeaveTimeout(), [clearHoverLeaveTimeout]);

  const handleHelpClick = useCallback(() => {
    if (import.meta.env.DEV) {
    console.log('Help/Knowledgebase clicked');
    }
  }, []);

  const handleNavigation = useCallback((path: string) => {
    // ✅ BONUS BLINDAJE: Portal - bloquear navegación a módulos prohibidos desde sidebar o links internos
    if (userType === "portal") {
      const isDealerAccountPath = path.startsWith('/settings/dealer-account');
      if (isDealerAccountPath) {
        router.navigate(path, true);
        setCurrentRoute(path);
        return;
      }
      const first = (path.split('/')[1] || '').toLowerCase();
      const map: Record<string, ModuleKey> = {
        dashboard: "dashboard",
        directory: "directory",
        sales: "sales",
        catalog: "catalog",
        inventory: "inventory",
        manufacturing: "manufacturing",
        financials: "financials",
        partners: "partners",
        service: "service",
        settings: "settings",
      };
      const moduleKey = map[first];

      if (moduleKey && !allowedModules.includes(moduleKey)) {
        if (import.meta.env.DEV) {
          console.log("[Layout] Portal user attempted navigation to forbidden module:", moduleKey, "redirecting to /dashboard");
        }
        router.navigate("/dashboard", true);
        setCurrentRoute("/dashboard");
        return;
      }
    }

    // Save current page before navigating to settings
    if (path.includes('/settings/company-settings')) {
      saveCurrentPageBeforeSettings();
    }
    
    // Handle dynamic navigation - use last visited route if available
    if (path === '/dashboard') {
      const actualPath = '/dashboard';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/directory') {
      // Always redirect to a list page when navigating to Directory module
      // Ignore last route if it was an edit/new page
      const lastRoute = getLastRouteForModule('/directory');
      // Only use lastRoute if it's a list page (contacts or customers), not edit/new pages
      const isListPage = lastRoute && (
        lastRoute === '/directory/contacts' || 
        lastRoute === '/directory/customers'
      );
      const actualPath = (isListPage ? lastRoute : null) || '/directory/customers';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/sales' || path === '/sales/quotes' || path === '/sales/proposals' || path === '/sales/orders') {
      // Tab click or Sales menu: go to the list for that tab; only use lastRoute when opening Sales from sidebar (path === '/sales')
      const listTabs = ['/sales/quotes', '/sales/proposals', '/sales/orders'];
      const isListPath = listTabs.includes(path);
      const actualPath = isListPath
        ? path
        : (() => {
            const lastRoute = getLastRouteForModule('/sales');
            const valid = lastRoute && (listTabs.includes(lastRoute) || /^\/sales\/(quotes|proposals|orders)\//.test(lastRoute));
            return (valid ? lastRoute : null) || '/sales/quotes';
          })();
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/catalog') {
      // Always redirect to Items (first sub-module) when entering Catalog module
      const actualPath = '/catalog/items';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/inventory') {
      const lastRoute = getLastRouteForModule('/inventory');
      const actualPath = lastRoute || '/inventory/warehouse';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/manufacturing') {
      const lastRoute = getLastRouteForModule('/manufacturing');
      // Retired standalone Work Orders list — never restore it as the module landing.
      const safeLast =
        lastRoute && !lastRoute.startsWith('/manufacturing/work-orders')
          ? lastRoute
          : null;
      const actualPath = safeLast || '/manufacturing/manufacturing-orders';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/financials') {
      const lastRoute = getLastRouteForModule('/financials');
      const actualPath = userType === 'portal' ? '/my-financials/invoices' : (lastRoute || '/financials');
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/my-financials') {
      const portalDefault = portalRole === 'dealer_manager' ? '/my-financials/statement' : '/my-financials/invoices';
      const actualPath = userType === 'portal' ? portalDefault : '/my-financials/invoices';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/accounting') {
      const lastRoute = getLastRouteForModule('/accounting');
      const actualPath = lastRoute || '/accounting/chart';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/partners') {
      const lastRoute = getLastRouteForModule('/partners');
      const actualPath = lastRoute || '/partners/dealers';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else {
      router.navigate(path);
      setCurrentRoute(path);
    }
  }, [saveCurrentPageBeforeSettings, getLastRouteForModule, userType, allowedModules, portalRole]);

  // Guard direct URL access to modules without read permission.
  useEffect(() => {
    if (permissionsLoading || accessLoading) return;

    const first = (currentRoute.split('/')[1] || '').toLowerCase();
    const map: Partial<Record<string, ModuleKey>> = {
      dashboard: 'dashboard',
      directory: 'directory',
      sales: 'sales',
      catalog: 'catalog',
      inventory: 'inventory',
      manufacturing: 'manufacturing',
      financials: 'financials',
      'my-financials': 'financials',
      partners: 'partners',
      service: 'service',
      settings: 'settings',
    };
    const moduleKey = map[first];
    if (!moduleKey) return;

    if (userType === 'portal') {
      if (currentRoute.startsWith('/settings/dealer-account')) {
        return;
      }
      if (!allowedModules.includes(moduleKey)) {
        router.navigate('/dashboard', true);
        setCurrentRoute('/dashboard');
      }
      return;
    }

    if (userType === 'internal') {
      if (!allowedModules.includes(moduleKey)) {
        router.navigate('/dashboard', true);
        setCurrentRoute('/dashboard');
        return;
      }
      const routeReadable = canReadPath(can, currentRoute);
      if (!routeReadable) {
        router.navigate('/dashboard', true);
        setCurrentRoute('/dashboard');
      }
    }
  }, [currentRoute, permissionsLoading, accessLoading, userType, allowedModules, can]);

  // Sidebar siempre colapsado: solo iconos; nombres y tabs en menú flotante al hover
  const sidebarWidth = useMemo(() => '3.5rem', []);
  const mainMarginLeft = useMemo(() => {
    if (isSettingsRoute) return '0px';
    return '3.5rem';
  }, [isSettingsRoute]);

  const mainPaddingTop = useMemo(() => {
    const hasSecondaryNav = submoduleTabs.length > 0 || breadcrumbs.length > 0;
    return hasSecondaryNav ? '5.8125rem' : '3.3125rem';
  }, [submoduleTabs.length, breadcrumbs.length]);

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }} data-testid="main-layout">
      {/* Enhanced Skip Links for comprehensive keyboard navigation */}
      <div className="skip-links-container">
        <a 
          href="#main-content" 
          className="skip-link"
          onClick={(e) => {
            e.preventDefault();
            const mainContent = document.getElementById('main-content');
            if (mainContent) {
              mainContent.focus();
              mainContent.scrollIntoView({ behavior: 'smooth' });
            }
          }}
        >
          Skip to main content
        </a>
        
        <a 
          href="#main-navigation" 
          className="skip-link"
          onClick={(e) => {
            e.preventDefault();
            const mainNav = document.getElementById('main-navigation');
            if (mainNav) {
              const firstButton = mainNav.querySelector('button');
              if (firstButton) {
                firstButton.focus();
                firstButton.scrollIntoView({ behavior: 'smooth' });
              }
            }
          }}
        >
          Skip to navigation
        </a>

        {submoduleTabs.length > 0 && (
          <a 
            href="#secondary-navigation" 
            className="skip-link"
            onClick={(e) => {
              e.preventDefault();
              const secondaryNav = document.getElementById('secondary-navigation');
              if (secondaryNav) {
                const firstTab = secondaryNav.querySelector('button');
                if (firstTab) {
                  firstTab.focus();
                  firstTab.scrollIntoView({ behavior: 'smooth' });
                }
              }
            }}
          >
            Skip to page navigation
          </a>
        )}

        <a 
          href="#user-menu" 
          className="skip-link"
          onClick={(e) => {
            e.preventDefault();
            const userMenu = document.getElementById('user-menu');
            if (userMenu) {
              userMenu.focus();
              userMenu.scrollIntoView({ behavior: 'smooth' });
            }
          }}
        >
          Skip to user menu
        </a>
      </div>
      
      <div className="flex min-w-0 overflow-x-hidden">
        {/* Sidebar Navigation - Hide when in Settings */}
        {!isSettingsRoute && (
        <nav 
          id="main-navigation"
          className="min-h-screen fixed left-0 top-0 bottom-0 overflow-y-auto transition-[width] duration-300 ease-in-out z-50 border-r w-14"
          style={{ 
            width: sidebarWidth,
            ...getSidebarStyles(viewMode),
            borderColor: 'var(--primary-brand-hex)'
          }}
          role="navigation"
          aria-label="Main navigation"
          data-testid="main-navigation"
        >
          {/* Logo Section */}
                    <div>
            <div 
              className="flex items-center relative w-full"
              style={{ 
                height: '56px',
                padding: '0 12px 0 13px'
              }}
            >
              <div className="flex items-center justify-center" style={{ width: '27px', height: '27px', flexShrink: 0 }}>
                <AdaptioMark size={27} color="var(--primary-brand-hex)" />
              </div>
                          <span
              className="absolute transition-opacity duration-300 whitespace-nowrap font-normal"
              style={{
                left: '52px',
                opacity: 0,
                pointerEvents: 'none',
                color: getLogoTextColor(viewMode),
                fontSize: '16px'
              }}
            >
              Adaptio
            </span>
            </div>
          </div>

          <div className="pb-4">
            {/* Dashboard Button - Separate */}
            {dashboardItem && (
              <div
                style={{ marginTop: '-1px' }}
                title={dashboardItem.name}
                onMouseEnter={(e) => handleNavItemMouseEnter(dashboardItem, e)}
                onMouseLeave={handleNavItemMouseLeave}
              >
                <button
                    {...getDashboardButtonProps(
                      viewMode,
                      isNavItemActive(dashboardItem.name, dashboardItem.href) || hoveredNavHref === dashboardItem.href,
                      () => handleNavigation(dashboardItem.href)
                    )}
                    aria-label={`${dashboardItem.name}${isNavItemActive(dashboardItem.name, dashboardItem.href) ? ' (current page)' : ''}`}
                    aria-current={isNavItemActive(dashboardItem.name, dashboardItem.href) ? 'page' : undefined}
                  >
                    {createNavItemContent(dashboardItem.icon, dashboardItem.name, true)}
                  </button>
              </div>
            )}

            {/* Spacer between Dashboard and other items */}
            <div style={{ height: '18px' }}></div>

            {/* Other Navigation Items - menú flotante con tabs al hover */}
            <div 
              style={{ gap: '1px', marginTop: '-3px' }} 
              className="flex flex-col" 
              role="navigation"
              aria-label="Main navigation items"
            >
              {otherNavItems.map((item) => {
                if (!item) return null;
                const isHovered = hoveredNavHref === item.href;
                const isActive = isNavItemActive(item.name, item.href) || isHovered;
                const Icon = item.icon;
                const tabs = item.href === '/my-financials'
                  ? getPortalFinancialTabs(portalRole)
                  : item.href === '/catalog'
                  ? getCatalogTabs(can)
                  : item.href === '/manufacturing'
                  ? getManufacturingTabs(can)
                  : item.href === '/financials' && userType === 'portal'
                  ? getPortalFinancialTabs(portalRole)
                  : (MODULE_TABS[item.href] ?? []);

                return (
                  <div
                    key={item.name}
                    className="relative"
                    onMouseEnter={(e) => handleNavItemMouseEnter(item, e)}
                    onMouseLeave={handleNavItemMouseLeave}
                  >
                    <button
                      {...getNavigationButtonProps(
                        viewMode,
                        isActive,
                        () => handleNavigation(item.href)
                      )}
                      title={tabs.length === 0 ? item.name : undefined}
                      aria-label={item.name}
                    >
                      {createNavItemContent(Icon, item.name, true)}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Help, Settings and Collapse/Expand Buttons */}
          <div className="absolute left-0 right-0" style={{ bottom: '1rem' }}>
            <div style={{ gap: '1px' }} className="flex flex-col">


              {/* Settings Button - Solo para INTERNAL */}
              {(() => {
                if (userType !== "internal") return null;  // ✅ portal nunca ve settings
                if (!can('settings.read')) return null;

                const { settingsUrl, isActive } = getSettingsButtonState(viewMode, isNavItemActive);
                return (
                  <button
                    {...getNavigationButtonProps(viewMode, isActive, () => handleNavigation(settingsUrl))}
                    title="Settings"
                    aria-label={`Settings${isActive ? ' (current page)' : ''}`}
                    aria-current={isActive ? 'page' : undefined}
                  >
                    {createNavItemContent(Settings, 'Settings', true)}
                  </button>
                );
              })()}
            </div>
          </div>
        </nav>
        )}

        {/* Menú flotante con tabs: renderizado en portal para no ser recortado por overflow del nav */}
        {!isSettingsRoute && hoveredNavHref && popoverRect && (() => {
          const hoveredItem = otherNavItems.find((i) => i?.href === hoveredNavHref);
          const tabs = hoveredNavHref === '/my-financials'
            ? getPortalFinancialTabs(portalRole)
            : hoveredNavHref === '/catalog'
            ? getCatalogTabs(can)
            : hoveredNavHref === '/manufacturing'
            ? getManufacturingTabs(can)
            : hoveredNavHref === '/financials' && userType === 'portal'
            ? getPortalFinancialTabs(portalRole)
            : (MODULE_TABS[hoveredNavHref] ?? []);
          if (!hoveredItem || tabs.length === 0) return null;
          const popoverContent = (
            <div
              className="py-2 px-3 rounded-r-md shadow-lg border border-gray-700 border-l-0 text-sm min-w-[200px]"
              style={{
                position: 'fixed',
                left: popoverRect.left,
                top: popoverRect.top,
                background: 'var(--sidebar-active-hover, #122d3b)',
                color: 'var(--sidebar-text-inactive, #8fa3ad)',
                zIndex: 9999,
              }}
              role="menu"
              aria-label={`${hoveredItem.name} submenu`}
              onMouseEnter={handlePopoverMouseEnter}
              onMouseLeave={handlePopoverMouseLeave}
            >
              <div className="font-semibold mb-2 pl-3 pr-5 text-white">
                {hoveredItem.name}
              </div>
              <div className="flex flex-col gap-0.5 -mx-3 pl-6 pr-3">
                {tabs.map((tab) => (
                  <a
                    key={tab.href}
                    href={tab.href}
                    className="block py-1.5 pr-5 rounded text-left no-underline text-inherit w-full hover:text-white"
                    onClick={(e) => {
                      e.preventDefault();
                      handleNavigation(tab.href);
                      clearPopoverAndSelection();
                    }}
                  >
                    {tab.label}
                  </a>
                ))}
              </div>
            </div>
          );
          return createPortal(popoverContent, document.body);
        })()}

        {/* Main Navigation Bar - Hide when in Settings */}
        {!isSettingsRoute && (
        <header 
          className="bg-white border-b fixed top-0 right-0 z-40 transition-[left] duration-300 ease-in-out"
          style={{
            height: '3.5rem',
            left: mainMarginLeft,
            borderColor: 'var(--gray-250)'
          }}
          role="banner"
        >
          {/* Top loading bar: línea delgada fija arriba del header, visible mientras globalLoading; mínimo ~300ms visible para evitar parpadeo */}
          <TopBarLoading />
          <div className="flex items-center justify-between h-full px-6">
            {/* Left side - Organization Switcher + Acting As Dealer filter */}
            <div className="flex items-center gap-4 flex-shrink-0" style={{ marginLeft: '-4px', minWidth: '280px' }}>
              <OrganizationSwitcher />
              {showDealerSwitcher && (
                <>
                  <ActingAsSwitcher />
                  {showApplyButton && (
                    <button
                      type="button"
                      onClick={() => {
                        if (isOnSales) {
                          directoryLoadQuotes?.();
                          directoryLoadProposals?.();
                          directoryLoadOrders?.();
                        } else {
                          directoryLoadContacts?.();
                          directoryLoadCustomers?.();
                        }
                      }}
                      className="flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-gray-200 bg-white hover:bg-gray-50 text-sm font-medium text-gray-700"
                      aria-label={
                        isOnSales
                          ? 'Apply dealer filter to quotes, proposals and orders'
                          : 'Apply dealer filter to directory'
                      }
                      title={
                        isOnSales
                          ? 'Apply dealer filter to load quotes, proposals and orders'
                          : 'Apply dealer filter to load contacts or customers'
                      }
                    >
                      <RefreshCw style={{ width: '14px', height: '14px' }} />
                      Apply
                    </button>
                  )}
                </>
              )}
            </div>

            {/* Center - Empty space for future use */}
            <div className="flex-1"></div>

            {/* Right side - User actions */}
            <div className="flex items-center gap-3">
              <button 
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="Open search"
                title="Search"
              >
                <Search style={{ width: '16px', height: '16px' }} />
              </button>
              
              <div className="relative" data-notifications-menu>
                <button
                  className="p-1 rounded relative"
                  style={{ color: 'var(--gray-950)' }}
                  aria-label="View notifications"
                  title="Notifications"
                  aria-expanded={isNotificationsOpen}
                  aria-haspopup="menu"
                  onClick={() => {
                    setIsNotificationsOpen((prev) => !prev);
                    setIsUserMenuOpen(false);
                  }}
                >
                  <Bell style={{ width: '16px', height: '16px' }} />
                  {unreadBellCount > 0 && (
                    <span
                      className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full bg-red-600 text-white text-[10px] leading-4 text-center"
                      aria-label={`${unreadBellCount} unread notifications`}
                    >
                      {unreadBellCount > 99 ? '99+' : unreadBellCount}
                    </span>
                  )}
                </button>

                {isNotificationsOpen && (
                  <div
                    className="absolute right-0 mt-2 w-[360px] max-h-[460px] overflow-auto bg-white shadow-lg border border-gray-200 rounded-md z-50"
                    role="menu"
                    aria-label="Notifications menu"
                  >
                    <div className="px-3 py-2 border-b border-gray-100 flex items-center justify-between">
                      <div className="text-sm font-semibold text-gray-900">Notifications</div>
                      <button
                        type="button"
                        onClick={() => markAllNotificationsAsRead()}
                        className="text-xs text-blue-600 hover:text-blue-700"
                      >
                        Mark all read
                      </button>
                    </div>

                    {notificationsLoading ? (
                      <div className="px-3 py-4 text-sm text-gray-500">Loading...</div>
                    ) : notifications.length === 0 ? (
                      <div className="px-3 py-4 text-sm text-gray-500">No notifications yet.</div>
                    ) : (
                      <div className="divide-y divide-gray-100">
                        {notifications.map((n) => {
                          const targetRoute = getNotificationTargetRoute(n);
                          return (
                            <button
                              key={n.id}
                              type="button"
                              onClick={async () => {
                                await markNotificationAsRead(n.id);
                                setIsNotificationsOpen(false);
                                if (targetRoute) router.navigate(targetRoute);
                              }}
                              className={`w-full text-left px-3 py-2 hover:bg-gray-50 transition-colors ${!n.is_read ? 'bg-blue-50/50' : ''}`}
                            >
                              <div className="flex items-start justify-between gap-2">
                                <div className="text-sm font-medium text-gray-900">{n.title}</div>
                                {!n.is_read ? (
                                  <div className="flex items-center gap-2">
                                    <span className="w-2 h-2 rounded-full bg-blue-600 mt-0.5" />
                                    <button
                                      type="button"
                                      onClick={async (e) => {
                                        e.stopPropagation();
                                        await markNotificationAsRead(n.id);
                                      }}
                                      className="inline-flex items-center gap-1 text-[11px] text-blue-700 hover:text-blue-800 hover:underline"
                                      aria-label="Mark notification as read"
                                      title="Mark as read"
                                    >
                                      <Check style={{ width: '12px', height: '12px' }} />
                                      Mark read
                                    </button>
                                  </div>
                                ) : null}
                              </div>
                              <div className="text-xs text-gray-600 mt-1">{n.message}</div>
                              <div className="text-[11px] text-gray-400 mt-1">
                                {new Date(n.created_at).toLocaleString()}
                              </div>
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}
              </div>

              <button 
                onClick={handleHelpClick}
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="Open help and knowledge base"
                title="Help & Knowledge Base"
              >
                <HelpCircle style={{ width: '16px', height: '16px' }} />
              </button>

              <span className="font-medium" style={{ color: 'var(--gray-950)', fontSize: '14px' }}>
                {user?.name || user?.email || getViewModeLabel(viewMode)}
              </span>


              {/* User Menu */}
              <div className="relative" data-user-menu>
                <button 
                  id="user-menu"
                  className="rounded-full flex items-center justify-center hover:opacity-80 transition-colors"
                  style={{ 
                    width: '28px', 
                    height: '28px',
                    backgroundColor: 'var(--gray-500)'
                  }}
                  aria-label={`My Account${isUserMenuOpen ? ' (menu open)' : ' (menu closed)'}`}
                  aria-expanded={isUserMenuOpen}
                  aria-haspopup="menu"
                  data-testid="view-toggle"
                  title="My Account"
                  onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
                >
                  <User style={{ width: '14px', height: '14px', color: 'white' }} />
                </button>

                {/* User Dropdown Menu */}
                {isUserMenuOpen && (
                  <div 
                    className={`absolute right-0 mt-2 bg-white shadow-lg border border-gray-200 py-2 z-50 ${userType === 'internal' && isSuperAdminUser ? 'w-64' : 'w-56'}`}
                    style={{ top: '100%' }}
                    role="menu"
                    aria-label="User account menu"
                    aria-orientation="vertical"
                  >
                    {/* User Info Section */}
                    <div className="px-4 py-3 border-b border-gray-100">
                      <div className="text-sm text-gray-500 mb-1">Logged in as</div>
                      <div className="font-medium text-gray-900">{user?.name || user?.email || 'Demo User'}</div>
                      {(activeOrganization?.name || activeDealer?.dealer_name) && (
                        <div className="text-xs text-gray-500 mt-1 flex items-center gap-1">
                          <Building2 style={{ width: '12px', height: '12px' }} />
                          {scopeDisplayLabel}
                        </div>
                      )}
                    </div>

                    {/* Menu Items */}
                    <div className="py-1">
                      {/* Dealer Account - solo para Dealer Manager (portal); solo Manager puede cambiar algo */}
                      {userType === 'portal' && portalRole === 'dealer_manager' && (
                        <button
                          className="w-full px-4 py-2 text-left text-sm text-blue-600 hover:bg-gray-50 flex items-center gap-2"
                          onClick={() => {
                            setIsUserMenuOpen(false);
                            router.navigate('/settings/dealer-account');
                          }}
                          role="menuitem"
                          aria-label="Dealer Account"
                        >
                          <Building2 style={{ width: '16px', height: '16px' }} aria-hidden="true" />
                          Dealer Account
                        </button>
                      )}
                      {userType === 'internal' && !isMember && (
                        <button
                          className="w-full px-4 py-2 text-left text-sm text-blue-600 hover:bg-gray-50 flex items-center gap-2"
                          onClick={() => {
                            setIsUserMenuOpen(false);
                            router.navigate('/settings/organization-user');
                          }}
                          role="menuitem"
                          aria-label="Organization User"
                        >
                          <Building2 style={{ width: '16px', height: '16px' }} aria-hidden="true" />
                          Organization User
                        </button>
                      )}
                      
                      <button
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2 border-t border-gray-100 mt-1 pt-3"
                        onClick={async () => {
                          setIsUserMenuOpen(false);
                          try {
                            await logout();
                          } finally {
                            router.navigate('/login', true);
                          }
                        }}
                      >
                        <span style={{ width: '16px', height: '16px', display: 'inline-block' }}>⏻</span>
                        Log out
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </header>
        )}

        {/* Secondary Navigation Bar for Submodules */}
        {!isSettingsRoute && (submoduleTabs.length > 0 || breadcrumbs.length > 0) && (
          <div 
            className="fixed right-0 z-30 transition-[left] duration-300 ease-in-out"
            style={{
              top: '3.5rem',
              height: '2.625rem',
              left: mainMarginLeft,
              backgroundColor: 'var(--gray-100)',
              borderBottom: '1px solid var(--gray-250)'
            }}
            role="navigation"
            aria-label="Secondary navigation"
          >
            <div className="flex items-center h-full" style={{ paddingRight: '1.5rem' }}>
              {submoduleTabs.length > 0 ? (
                <div id="secondary-navigation" className="flex items-stretch h-full" role="tablist">
                  {submoduleTabs.map((tab) => (
                    <button
                      key={tab.id}
                      onClick={tab.onClick}
                      className={`transition-colors flex items-center justify-start border-r ${
                        tab.isActive
                          ? 'bg-white font-semibold'
                          : 'hover:bg-white/50 font-normal'
                      }`}
                      style={{
                        fontSize: '12px',
                        padding: '0 48px',
                        height: '100%',
                        minWidth: '140px',
                        width: 'auto',
                        color: '#1c1f26',
                        borderColor: 'var(--gray-250)',
                        borderBottom: tab.isActive ? '2px solid var(--sidebar-base)' : 'none'
                      }}
                      role="tab"
                      aria-selected={tab.isActive}
                      aria-label={`${tab.label}${tab.isActive ? ' (current tab)' : ''}`}
                      aria-controls={`${tab.id}-panel`}
                      tabIndex={tab.isActive ? 0 : -1}
                    >
                      {tab.label}
                    </button>
                  ))}
                </div>
              ) : breadcrumbs.length > 0 ? (
                <nav className="flex items-center h-full" style={{ paddingLeft: '3rem' }} aria-label="Breadcrumb">
                  <ol className="flex items-center gap-2" style={{ fontSize: '12px', color: 'var(--gray-950)' }}>
                    {breadcrumbs.map((crumb, index) => (
                      <li key={index} className="flex items-center gap-2">
                        {crumb.href ? (
                          <button onClick={() => handleNavigation(crumb.href!)} className="hover:text-primary">
                            {crumb.label}
                          </button>
                        ) : (
                          <span style={{ color: 'var(--gray-950)' }}>{crumb.label}</span>
                        )}
                        {index < breadcrumbs.length - 1 && <span aria-hidden="true">/</span>}
                      </li>
                    ))}
                  </ol>
                </nav>
              ) : null}
            </div>
          </div>
        )}

        {/* Main Content */}
        <main 
          id="main-content"
          className="flex-1 min-w-0 overflow-x-hidden transition-[margin-left] duration-300 ease-in-out"
          style={{
            marginLeft: isSettingsRoute ? '0px' : mainMarginLeft,
            paddingTop: isSettingsRoute ? '0px' : mainPaddingTop,
            padding: isSettingsRoute ? '0 1.5rem 1.5rem' : `${mainPaddingTop} 1.5rem 1.5rem`,
            backgroundColor: isSettingsRoute ? 'transparent' : 'var(--gray-200)'
          }}
          role="main"
          tabIndex={-1}
        >
          {children}
        </main>
      </div>
    </div>
  );
}

export default memo(Layout);

