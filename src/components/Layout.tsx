import React, { ReactNode, useState, useCallback, useMemo, useEffect, memo } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useCompany } from '../hooks/useCompany';
import { useCompanyStore } from '../stores/company-store';
import { router } from '../lib/router';
import { supabase } from '../lib/supabase/client';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { useUIStore } from '../stores/ui-store';
import { usePreviousPage } from '../hooks/usePreviousPage';
import { useCurrentOrgRole } from '../hooks/useCurrentOrgRole';
import { usePermissions, MODULE_PERMS } from '../hooks/usePermissions';
import { useAccessContext, ModuleKey } from '../hooks/useAccessContext';
import { useOrganizationContext } from '../context/OrganizationContext';
import { OrganizationSwitcher } from './layout/OrganizationSwitcher';
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
  createCollapseExpandContent
} from '../utils/viewModeStyles';
import { 
  Users, 
  User,
  Clock, 
  Settings, 
  Home, 
  Bell, 
  Search, 
  HelpCircle,
  ChevronLeft, 
  ChevronRight, 
  Building, 
  Building2,
  Printer,
  CalendarCheck,
  Box,
  Check,
  BookOpen,
  ShoppingBag,
  Book,
  Package,
  Wrench,
  DollarSign,
  FileText
} from 'lucide-react';

interface LayoutProps {
  children: ReactNode;
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
  const { logout, user } = useAuth();
  const { currentCompany, availableCompanies, canSwitchCompany, switchCompany, isLoading } = useCompany();
  const { clearCompanies } = useCompanyStore();
  const [currentOrganization, setCurrentOrganization] = useState<{ id: string; name: string } | null>(null);
  const [currentRoute, setCurrentRoute] = useState(() => router.getCurrentRoute() || '/');
  const { tabs: submoduleTabs, breadcrumbs, clearSubmoduleNav } = useSubmoduleNav();
  const { saveCurrentPageBeforeSettings } = usePreviousPage();
  const { isMember, isSuperAdmin, role: currentRole } = useCurrentOrgRole();
  const { can, loading: permissionsLoading } = usePermissions();
  const { allowedModules, loading: accessLoading, userType } = useAccessContext();
  const { role: orgContextRole } = useOrganizationContext();
  
  // Determine if user is SuperAdmin (check both sources for reliability)
  const isSuperAdminUser = isSuperAdmin || orgContextRole === 'superadmin' || currentRole === 'superadmin';
  
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
  
  // Use UI store for sidebar and view mode state
  const { 
    sidebarCollapsed: isCollapsed, 
    viewMode: storeViewMode, 
    toggleSidebarCollapsed, 
    setViewMode 
  } = useUIStore();
  
  // Ensure viewMode is always valid, default to 'manager'
  const viewMode = storeViewMode || 'manager';

  // Check if we're in Settings pages - if so, hide the main sidebar
  const isSettingsRoute = currentRoute.includes('/settings');
  
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
    } else if (route.startsWith('/sale-orders')) {
      setLastRouteForModule('/sale-orders', route);
    } else if (route.startsWith('/catalog')) {
      setLastRouteForModule('/catalog', route);
    } else if (route.startsWith('/inventory')) {
      setLastRouteForModule('/inventory', route);
    } else if (route.startsWith('/manufacturing')) {
      setLastRouteForModule('/manufacturing', route);
    } else if (route.startsWith('/financials')) {
      setLastRouteForModule('/financials', route);
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

  // Update current route when router changes
  useEffect(() => {
    const updateRoute = () => {
      setCurrentRoute(router.getCurrentRoute());
    };
    
    // Listen for route changes
    const removeListener = router.addListener(updateRoute);
    
    // Set initial route
    updateRoute();
    
    return () => {
      removeListener();
    };
  }, []);

  // OBSOLETO: Este código está duplicado y usa el schema antiguo.
  // OrganizationContext ya maneja esto correctamente.
  // TODO: Migrar a usar OrganizationContext.organizationName en lugar de currentOrganization state.
  // Por ahora dejamos currentOrganization como null para evitar duplicación.
  useEffect(() => {
    setCurrentOrganization(null);
  }, []);

  // Close user menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('[data-user-menu]')) {
        setIsUserMenuOpen(false);
      }
    };

    if (isUserMenuOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isUserMenuOpen]);

  // Helper function to determine if a navigation item is active
  const isNavItemActive = useCallback((itemName: string, itemHref: string) => {
    switch (itemName) {
      case 'Dashboard':
        // Dashboard is active if we're on root, dashboard route, or inbox
        return currentRoute === '/' || currentRoute === '/dashboard' || currentRoute.includes('/dashboard') || currentRoute.includes('/inbox');
      case 'Directory':
        // Directory is active if we're on any directory route
        return currentRoute.includes('/directory');
      case 'Sales':
        // Sales is active if we're on any sales/quotes route
        return currentRoute.includes('/sales/quotes');
      case 'Sales Orders':
        // Sales Orders is active if we're on any sale-orders route
        return currentRoute.includes('/sale-orders');
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
        // Financials is active if we're on any financials route
        return currentRoute.includes('/financials');
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
      dashboardItem ? { ...dashboardItem, module: undefined } : { name: 'Dashboard', href: '/dashboard', icon: Home },
      { name: 'Directory', href: '/directory', icon: BookOpen, module: 'directory' },
      { name: 'Sales', href: '/sales/quotes', icon: ShoppingBag, module: 'sales' },
      { name: 'Sales Orders', href: '/sale-orders', icon: FileText, module: 'sales' }, // Uses 'sales' module for permissions
      { name: 'Catalog', href: '/catalog', icon: Book, module: 'catalog' },
      { name: 'Manufacturing', href: '/manufacturing', icon: Wrench, module: 'manufacturing' },
      { name: 'Financials', href: '/financials', icon: DollarSign, module: 'financials' },
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
      // Internal users: mostrar todos mientras carga, pero asegurar que SuperAdmin siempre vea todo
      if (userType === "internal" && isSuperAdminUser) {
        return allItems; // SuperAdmin siempre ve todo, incluso durante loading
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
      // IMPORTANTE: Portal users NO deben ver Sales Orders, solo Sales
      if (userType === "portal") {
        // Portal users: explícitamente excluir Sales Orders
        if (item.name === "Sales Orders") {
          return false;
        }
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
        
        // ✅ SUPERADMIN BYPASS: SuperAdmin can see all modules without permission checks
        if (isSuperAdminUser) {
          if (import.meta.env.DEV && item.name === "Financials") {
            console.log("[Sidebar] SuperAdmin - Financials: BYPASSED, showing module");
          }
          return true;
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
  }, [can, permissionsLoading, allowedModules, accessLoading, userType, isSuperAdminUser]);

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

  // Memoized handlers
  const handleCollapseToggle = useCallback(() => {
    toggleSidebarCollapsed();
  }, [toggleSidebarCollapsed]);

  const handleHelpClick = useCallback(() => {
    if (import.meta.env.DEV) {
    console.log('Help/Knowledgebase clicked');
    }
  }, []);

  const handleNavigation = useCallback((path: string) => {
    // ✅ BONUS BLINDAJE: Portal - bloquear navegación a módulos prohibidos desde sidebar o links internos
    if (userType === "portal") {
      const first = (path.split('/')[1] || '').toLowerCase();
      const map: Record<string, ModuleKey> = {
        dashboard: "dashboard",
        directory: "directory",
        sales: "sales",
        catalog: "catalog",
        manufacturing: "manufacturing",
        financials: "financials",
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
      const actualPath = (isListPage ? lastRoute : null) || '/directory/contacts';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/sales' || path === '/sales/quotes') {
      // Navigate to quotes list
      const lastRoute = getLastRouteForModule('/sales');
      const isListPage = lastRoute && (lastRoute === '/sales/quotes' || lastRoute === '/sales');
      const actualPath = (isListPage ? lastRoute : null) || '/sales/quotes';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/sale-orders') {
      // Navigate to sale orders list
      const lastRoute = getLastRouteForModule('/sale-orders');
      const isListPage = lastRoute && lastRoute === '/sale-orders';
      const actualPath = (isListPage ? lastRoute : null) || '/sale-orders';
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
      // Always redirect to Order List (first sub-module) when entering Manufacturing module
      const actualPath = '/manufacturing/order-list';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/financials') {
      const lastRoute = getLastRouteForModule('/financials');
      const actualPath = lastRoute || '/financials';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else {
      router.navigate(path);
      setCurrentRoute(path);
    }
  }, [saveCurrentPageBeforeSettings, getLastRouteForModule, userType, allowedModules]);

  // Memoized sidebar width calculations
  const sidebarWidth = useMemo(() => 
    isCollapsed ? '3.5rem' : '15rem', 
    [isCollapsed]
  );

  const mainMarginLeft = useMemo(() => {
    // If we're in Settings, don't add sidebar margin
    if (isSettingsRoute) return '0px';
    return isCollapsed ? '3.5rem' : '15rem';
  }, [isCollapsed, isSettingsRoute]);

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
      
      <div className="flex">
        {/* Sidebar Navigation - Hide when in Settings */}
        {!isSettingsRoute && (
        <nav 
          id="main-navigation"
          className={`min-h-screen fixed left-0 top-0 bottom-0 overflow-y-auto transition-all duration-300 z-50 border-r ${
            isCollapsed ? 'w-14' : 'w-60'
          }`}
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
                <Box size={27} style={{ color: 'var(--primary-brand-hex)' }} />
              </div>
                          <span
              className="absolute transition-opacity duration-300 whitespace-nowrap font-normal"
              style={{
                left: '52px',
                opacity: isCollapsed ? 0 : 1,
                pointerEvents: isCollapsed ? 'none' : 'auto',
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
              <div style={{ marginTop: '-1px' }}>
                <button
                    {...getDashboardButtonProps(
                      viewMode, 
                      isNavItemActive(dashboardItem.name, dashboardItem.href),
                      () => handleNavigation(dashboardItem.href)
                    )}
                    title={isCollapsed ? dashboardItem.name : undefined}
                    aria-label={`${dashboardItem.name}${isNavItemActive(dashboardItem.name, dashboardItem.href) ? ' (current page)' : ''}`}
                    aria-current={isNavItemActive(dashboardItem.name, dashboardItem.href) ? 'page' : undefined}
                  >
                    {createNavItemContent(dashboardItem.icon, dashboardItem.name, isCollapsed)}
                  </button>
              </div>
            )}

            {/* Spacer between Dashboard and other items */}
            <div style={{ height: '18px' }}></div>

            {/* Other Navigation Items */}
            <div 
              style={{ gap: '1px', marginTop: '-3px' }} 
              className="flex flex-col" 
              role="navigation"
              aria-label="Main navigation items"
            >
              {otherNavItems.map((item) => {
                if (!item) return null;
                const isActive = isNavItemActive(item.name, item.href);
                const Icon = item.icon;

                return (
                    <button
                    key={item.name}
                    {...getNavigationButtonProps(
                      viewMode,
                      isActive,
                      () => handleNavigation(item.href)
                    )}
                        title={isCollapsed ? item.name : undefined}
                        aria-label={item.name}
                      >
                    {createNavItemContent(Icon, item.name, isCollapsed)}
                      </button>
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
                    {createNavItemContent(Settings, 'Settings', isCollapsed)}
                  </button>
                );
              })()}

              {/* Collapse/Expand Button */}
              <button
                {...getNavigationButtonProps(viewMode, false, handleCollapseToggle, {
                  borderLeft: '3px solid transparent'
                })}
                aria-label={isCollapsed ? "Expand sidebar navigation" : "Collapse sidebar navigation"}
              aria-expanded={!isCollapsed}
                aria-controls="main-navigation"
                title={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
            >
              {createCollapseExpandContent(isCollapsed, ChevronRight, ChevronLeft, 'Show Labels', 'Hide Labels')}
            </button>
            </div>
          </div>
        </nav>
        )}

        {/* Main Navigation Bar - Hide when in Settings */}
        {!isSettingsRoute && (
        <header 
          className="bg-white border-b fixed top-0 right-0 z-40 transition-all duration-300"
          style={{
            height: '3.5rem',
            left: mainMarginLeft,
            borderColor: 'var(--gray-250)'
          }}
          role="banner"
        >
          <div className="flex items-center justify-between h-full px-6">
            {/* Left side - Organization Switcher */}
            <div className="flex items-center" style={{ marginLeft: '-4px', minWidth: '300px' }}>
              <OrganizationSwitcher />
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
              
              <button 
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="View notifications"
                title="Notifications"
              >
                <Bell style={{ width: '16px', height: '16px' }} />
              </button>

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
                                         backgroundColor: 'var(--primary-brand-hex)'
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
                    className="absolute right-0 mt-2 w-56 bg-white shadow-lg border border-gray-200 py-2 z-50"
                    style={{ top: '100%' }}
                    role="menu"
                    aria-label="User account menu"
                    aria-orientation="vertical"
                  >
                    {/* User Info Section */}
                    <div className="px-4 py-3 border-b border-gray-100">
                      <div className="text-sm text-gray-500 mb-1">Logged in as</div>
                      <div className="font-medium text-gray-900">{user?.name || user?.email || 'Demo User'}</div>
                      {currentCompany && (
                        <div className="text-xs text-gray-500 mt-1 flex items-center gap-1">
                          <Building2 style={{ width: '12px', height: '12px' }} />
                          {currentCompany.name}
                        </div>
                      )}
                    </div>

                    {/* Organization Section - OCULTO */}
                    {/* {currentOrganization && (
                      <div className="py-1 border-b border-gray-100">
                        <div className="px-4 py-2">
                          <div className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-2">ORGANIZATION</div>
                          <div className="text-sm text-gray-900 font-medium">{currentOrganization.name}</div>
                        </div>
                      </div>
                    )} */}

                    {/* Menu Items */}
                    <div className="py-1">
                      {/* Organization User - Solo visible para Superadmin y Admin */}
                      {!isMember && (
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
                        className="w-full px-4 py-2 text-left text-sm text-blue-600 hover:bg-gray-50 flex items-center gap-2"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          // Add navigation to account page if needed
                        }}
                        role="menuitem"
                        aria-label="Go to my account settings"
                      >
                        <User style={{ width: '16px', height: '16px' }} aria-hidden="true" />
                        My Account
                      </button>
                      


                      <button
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2 border-t border-gray-100 mt-1 pt-3"
                        onClick={async () => {
                          setIsUserMenuOpen(false);
                          try {
                            clearCompanies();
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
            className="border-b fixed right-0 z-30 transition-all duration-300"
            style={{
              top: '3.5rem',
              height: '2.625rem',
              left: mainMarginLeft,
              backgroundColor: 'var(--gray-100)',
              borderColor: 'var(--gray-250)'
            }}
            role="navigation"
            aria-label="Secondary navigation"
          >
            <div className="flex items-center h-full" style={{ paddingRight: '1.5rem' }}>
              {submoduleTabs.length > 0 ? (
                <div id="secondary-navigation" className="flex items-stretch h-full" role="tablist">
                  {submoduleTabs.map((tab) => {
                    return (
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
                          borderBottom: tab.isActive ? '2px solid var(--tab-active-underline)' : 'none'
                        }}
                        role="tab"
                        aria-selected={tab.isActive}
                        aria-label={`${tab.label}${tab.isActive ? ' (current tab)' : ''}`}
                        aria-controls={`${tab.id}-panel`}
                        tabIndex={tab.isActive ? 0 : -1}
                      >
                        {tab.label}
                      </button>
                    );
                  })}
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
          className="flex-1 transition-all duration-300"
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

