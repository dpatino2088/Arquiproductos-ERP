import React, { ReactNode, useState, useCallback, useMemo, useEffect, memo } from 'react';
import { useAuth } from '../hooks/useAuth';
import { router } from '../lib/router';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { useUIStore } from '../stores/ui-store';
import { RhemoLogo } from './RhemoLogo';
import { 
  Users, 
  User,
  Clock, 
  Settings, 
  Home, 
  Bell, 
  Search, 
  ChevronLeft, 
  ChevronRight, 
  Building, 
  HelpCircle,
  Receipt,
  Printer,
  HandCoins,
  Cpu,
  ChartNoAxesCombined,
  HeartPulse,
  BriefcaseBusiness,
  CalendarCheck,
  BookMarked
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
  viewMode = 'employee'
}: {
  item: { name: string; href: string; icon: React.ComponentType<{ style?: React.CSSProperties }> };
  isActive: boolean;
  isCollapsed: boolean;
  onClick: () => void;
  viewMode?: 'employee' | 'manager';
}) => (
  <button
    onClick={onClick}
    className="flex items-center font-normal transition-colors group relative w-full"
    style={{
      fontSize: '14px',
      minHeight: '36px',
      padding: '12px 16px 12px 14px',
      color: isActive ? (viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)') : (viewMode === 'manager' ? 'var(--gray-300)' : 'var(--graphite-black-hex)'),
      backgroundColor: isActive ? (viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)') : 'transparent',
      borderLeft: isActive ? `3px solid ${viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)'}` : '3px solid transparent'
    }}
    onMouseEnter={(e) => {
      if (!isActive) {
        e.currentTarget.style.backgroundColor = viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)';
      }
    }}
    onMouseLeave={(e) => {
      if (!isActive) {
        e.currentTarget.style.backgroundColor = 'transparent';
      }
    }}
    aria-current={isActive ? 'page' : undefined}
  >
    <div className="flex items-center justify-center" style={{ width: '18px', height: '18px', flexShrink: 0 }}>
      <item.icon style={{ width: '18px', height: '18px' }} />
    </div>
    <span 
      className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
      style={{
        opacity: isCollapsed ? 0 : 1,
        pointerEvents: isCollapsed ? 'none' : 'auto',
        fontSize: '14px',
        color: isActive ? (viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)') : 'var(--graphite-black-hex)'
      }}
    >
      {item.name}
    </span>
  </button>
));

NavigationItem.displayName = 'NavigationItem';

const baseNavigation = [
  { name: 'Dashboard', href: '/dashboard', icon: Home }, // Will be handled dynamically based on view mode
  { name: 'Time & Attendance', href: '/management/time-and-attendance/planner', icon: Clock },
  { name: 'PTO & Leave', href: '/management/pto-and-leaves/calendar', icon: CalendarCheck },
  { name: 'Knowledge Hub', href: '/management/company-knowledge/about-the-company', icon: BookMarked },
  { name: 'Performance', href: '/management/performance/team-goals-and-performance', icon: ChartNoAxesCombined },
  { name: 'Benefits', href: '/management/benefits/team-benefits', icon: BriefcaseBusiness },
];

const employeeOnlyNavigation = [
  { name: 'Wellness', href: '/wellness', icon: HeartPulse },
  { name: 'Expenses', href: '/management/expenses/team-expenses', icon: Receipt },
];

const managementExpenses = [
  { name: 'Expenses', href: '/management/expenses/team-expenses', icon: Receipt },
];

const sharedManagementNavigation = [
  { name: 'IT Management', href: '/management/it-management/team-devices', icon: Cpu },
];



function Layout({ children }: LayoutProps) {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const { logout, user } = useAuth();
  const [currentRoute, setCurrentRoute] = useState('/');
  const { tabs: submoduleTabs, breadcrumbs } = useSubmoduleNav();
  
  // Use UI store for sidebar and view mode state
  const { 
    sidebarCollapsed: isCollapsed, 
    viewMode, 
    toggleSidebarCollapsed, 
    setViewMode 
  } = useUIStore();

  // Scroll to top when route changes
  useEffect(() => {
    const routeFromRouter = router.getCurrentRoute();
    if (routeFromRouter !== currentRoute) {
      setCurrentRoute(routeFromRouter);
      // Additional scroll to top to ensure it works
      window.scrollTo(0, 0);
      // Also scroll the main content area if it exists
      const mainElement = document.querySelector('main[role="main"]');
      if (mainElement) {
        mainElement.scrollTop = 0;
      }
    }
  }, [currentRoute]);

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
        // Dashboard is active if we're on any dashboard route or inbox
        return currentRoute.includes('/dashboard') || currentRoute.includes('/inbox');
      case 'People':
        // People is active if we're on any people route
        return currentRoute.includes('/people');
      case 'My Info':
        // My Info is active if we're on any people or my-info route
        return currentRoute.includes('/people') || currentRoute.includes('/my-info');
      case 'Time & Attendance':
        // Time & Attendance is active if we're on any time-and-attendance route
        return currentRoute.includes('/time-and-attendance');
      case 'PTO & Leave':
        // PTO & Leave is active if we're on any pto-and-leaves route
        return currentRoute.includes('/pto-and-leaves');
      case 'Performance':
        // Performance is active if we're on any performance route
        return currentRoute.includes('/performance');
      case 'Knowledge Hub':
        // Knowledge Hub is active if we're on any company-knowledge route
        return currentRoute.includes('/company-knowledge');
      case 'Benefits':
        // Benefits is active if we're on any benefits route
        return currentRoute.includes('/benefits');
      case 'Expenses':
        // Expenses is active if we're on any expenses route
        return currentRoute.includes('/expenses');
      case 'IT Management':
        // IT Management is active if we're on any it-management route
        return currentRoute.includes('/it-management');
      case 'Payroll':
        // Payroll is active if we're on any payroll route
        return currentRoute.includes('/payroll');
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

  // Memoized navigation items based on view mode
  const navigation = useMemo(() => {
    // Create base navigation with People/My Info inserted after Dashboard
    const dashboardItem = baseNavigation[0]; // Dashboard
    const restOfBase = baseNavigation.slice(1); // Everything after Dashboard
    
    if (viewMode === 'manager') {
      const peopleItem = { name: 'People', href: '/people', icon: Users };
      return [dashboardItem, peopleItem, ...restOfBase, ...managementExpenses, { name: 'Payroll', href: '/management/payroll/payroll-wizards', icon: HandCoins }, ...sharedManagementNavigation, { name: 'Reports', href: '/management/reports/company-reports', icon: Printer }];
    } else {
      const myInfoItem = { name: 'My Info', href: '/people', icon: User };
      return [dashboardItem, myInfoItem, ...restOfBase, ...employeeOnlyNavigation, ...sharedManagementNavigation];
    }
  }, [viewMode]);

  const dashboardItem = useMemo(() => 
    navigation.find(item => item?.name === 'Dashboard'), [navigation]
  );
  
  const otherNavItems = useMemo(() => 
    navigation.filter(item => item?.name !== 'Dashboard'), [navigation]
  );

  // Memoized handlers
  const handleCollapseToggle = useCallback(() => {
    toggleSidebarCollapsed();
  }, [toggleSidebarCollapsed]);

  const handleHelpClick = useCallback(() => {
    console.log('Help/Knowledgebase clicked');
  }, []);

  const handleViewToggle = useCallback(() => {
    const newMode = viewMode === 'employee' ? 'manager' : 'employee';
    setViewMode(newMode);
    router.setViewMode(newMode);
    
    // Navigate to appropriate dashboard based on view mode
    const newPath = newMode === 'employee' ? '/employee/dashboard' : '/management/dashboard';
    router.navigate(newPath);
    setCurrentRoute(newPath);
  }, [viewMode]);

  const handleNavigation = useCallback((path: string) => {
    // Handle dynamic navigation based on view mode
    if (path === '/dashboard') {
      const actualPath = viewMode === 'employee' 
        ? '/employee/dashboard' 
        : '/management/dashboard';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/people') {
      const actualPath = viewMode === 'employee' 
        ? '/employee/my-info' 
        : '/management/people/directory';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else {
      router.navigate(path);
      setCurrentRoute(path);
    }
  }, [viewMode]);

  // Memoized sidebar width calculations
  const sidebarWidth = useMemo(() => 
    isCollapsed ? '3.5rem' : '15rem', 
    [isCollapsed]
  );

  const mainMarginLeft = useMemo(() => 
    isCollapsed ? '3.5rem' : '15rem', 
    [isCollapsed]
  );

  const mainPaddingTop = useMemo(() => {
    const hasSecondaryNav = submoduleTabs.length > 0 || breadcrumbs.length > 0;
    return hasSecondaryNav ? '5.8125rem' : '3.3125rem';
  }, [submoduleTabs.length, breadcrumbs.length]);

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
      <div className="flex">
        {/* Sidebar Navigation */}
        <nav 
          className={`min-h-screen fixed left-0 top-0 bottom-0 overflow-y-auto transition-all duration-300 z-50 border-r ${
            isCollapsed ? 'w-14' : 'w-60'
          }`}
          style={{ 
            width: sidebarWidth,
            backgroundColor: viewMode === 'manager' ? 'var(--gray-950)' : 'white',
            borderColor: viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)'
          }}
          role="navigation"
          aria-label="Main navigation"
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
                <RhemoLogo width={27} height={27} viewMode={viewMode} />
              </div>
                          <span
              className="absolute transition-opacity duration-300 whitespace-nowrap font-normal"
              style={{
                left: '52px',
                opacity: isCollapsed ? 0 : 1,
                pointerEvents: isCollapsed ? 'none' : 'auto',
                color: viewMode === 'manager' ? 'var(--gray-100)' : 'var(--gray-950)',
                fontSize: '16px'
              }}
            >
              <span style={{ fontWeight: '700' }}>RH</span><span style={{ fontWeight: '200' }}>EMO</span>
            </span>
            </div>
          </div>

          <div className="pb-4">
            {/* Dashboard Button - Separate */}
            {dashboardItem && (
              <div style={{ marginTop: '-1px' }}>
                                  <button
                    onClick={() => handleNavigation(dashboardItem.href)}
                    className="flex items-center font-normal transition-colors group relative w-full"
                    style={{
                      fontSize: '14px',
                      minHeight: '40px',
                      padding: '11px 16px 11px 14px',
                      color: isNavItemActive(dashboardItem.name, dashboardItem.href) ? (viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)') : (viewMode === 'manager' ? 'var(--gray-300)' : 'var(--graphite-black-hex)'),
                      backgroundColor: isNavItemActive(dashboardItem.name, dashboardItem.href) ? (viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)') : 'transparent',
                      borderLeft: isNavItemActive(dashboardItem.name, dashboardItem.href) ? `3px solid ${viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)'}` : '3px solid transparent'
                    }}
                    onMouseEnter={(e) => {
                      if (!isNavItemActive(dashboardItem.name, dashboardItem.href)) {
                        e.currentTarget.style.backgroundColor = viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isNavItemActive(dashboardItem.name, dashboardItem.href)) {
                        e.currentTarget.style.backgroundColor = 'transparent';
                      }
                    }}
                    title={isCollapsed ? dashboardItem.name : undefined}
                    aria-label={dashboardItem.name}
                  >
                    <div className="flex items-center justify-center" style={{ width: '18px', height: '18px', flexShrink: 0 }}>
                      <dashboardItem.icon style={{ width: '18px', height: '18px' }} />
                    </div>
                    <span 
                      className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
                      style={{ 
                        opacity: isCollapsed ? 0 : 1,
                        pointerEvents: isCollapsed ? 'none' : 'auto'
                      }}
                    >
                      {dashboardItem.name}
                    </span>
                  </button>
              </div>
            )}

            {/* Spacer between Dashboard and other items */}
            <div style={{ height: '18px' }}></div>

            {/* Other Navigation Items */}
            <ul style={{ gap: '1px', marginTop: '-3px' }} className="flex flex-col" role="list">
              {otherNavItems.map((item) => {
                if (!item) return null;
                const isActive = isNavItemActive(item.name, item.href);
                const Icon = item.icon;

                return (
                  <li key={item.name} role="listitem">
                    <button
                        onClick={() => handleNavigation(item.href)}
                        className="flex items-center font-normal transition-colors group relative w-full"
                        style={{
                          fontSize: '14px',
                          minHeight: '36px',
                          padding: '12px 16px 12px 14px',
                          color: isActive ? (viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)') : (viewMode === 'manager' ? 'var(--gray-300)' : 'var(--graphite-black-hex)'),
                          backgroundColor: isActive ? (viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)') : 'transparent',
                          borderLeft: isActive ? `3px solid ${viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)'}` : '3px solid transparent'
                        }}
                        onMouseEnter={(e) => {
                          if (!isActive) {
                            e.currentTarget.style.backgroundColor = viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)';
                          }
                        }}
                        onMouseLeave={(e) => {
                          if (!isActive) {
                            e.currentTarget.style.backgroundColor = 'transparent';
                          }
                        }}
                        title={isCollapsed ? item.name : undefined}
                        aria-label={item.name}
                      >
                        <div className="flex items-center justify-center" style={{ width: '18px', height: '18px', flexShrink: 0 }}>
                          <Icon style={{ width: '18px', height: '18px' }} />
                        </div>
                        <span 
                          className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
                          style={{ 
                            opacity: isCollapsed ? 0 : 1,
                            pointerEvents: isCollapsed ? 'none' : 'auto'
                          }}
                        >
                          {item.name}
                        </span>
                      </button>
                  </li>
                );
              })}
            </ul>
          </div>

          {/* Help, Settings and Collapse/Expand Buttons */}
          <div className="absolute left-0 right-0" style={{ bottom: '1rem' }}>
            <div style={{ gap: '1px' }} className="flex flex-col">


              {/* Settings Button */}
              <button
                onClick={() => handleNavigation('/management/settings/company-settings')}
                className="flex items-center font-normal transition-colors w-full relative"
              style={{
                fontSize: '14px',
                minHeight: '36px',
                padding: '12px 16px 12px 14px',
                color: isNavItemActive('Settings', '/management/settings/company-settings') ? (viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)') : (viewMode === 'manager' ? 'var(--gray-300)' : 'var(--graphite-black-hex)'),
                backgroundColor: isNavItemActive('Settings', '/management/settings/company-settings') ? (viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)') : 'transparent',
                borderLeft: isNavItemActive('Settings', '/management/settings/company-settings') ? `3px solid ${viewMode === 'manager' ? 'var(--teal-500)' : 'var(--teal-800)'}` : '3px solid transparent'
              }}
              onMouseEnter={(e) => {
                if (!isNavItemActive('Settings', '/management/settings/company-settings')) {
                  e.currentTarget.style.backgroundColor = viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isNavItemActive('Settings', '/management/settings/company-settings')) {
                  e.currentTarget.style.backgroundColor = 'transparent';
                }
              }}
              title="Settings"
              aria-label="Settings"
            >
              <div className="flex items-center justify-center" style={{ width: '18px', height: '18px', flexShrink: 0 }}>
                <Settings style={{ width: '18px', height: '18px' }} />
              </div>
              <span 
                className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
                style={{ 
                  opacity: isCollapsed ? 0 : 1,
                  pointerEvents: isCollapsed ? 'none' : 'auto'
                }}
              >
                Settings
              </span>
            </button>

              {/* Collapse/Expand Button */}
              <button
                onClick={handleCollapseToggle}
                className="flex items-center font-normal transition-colors w-full relative"
              style={{
                fontSize: '14px',
                minHeight: '36px',
                padding: '12px 16px 12px 14px',
                color: viewMode === 'manager' ? 'var(--gray-300)' : 'var(--gray-950)',
                borderLeft: '3px solid transparent',
                backgroundColor: 'transparent'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = viewMode === 'manager' ? 'var(--gray-800)' : 'var(--gray-250)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'transparent';
              }}
              aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
              aria-expanded={!isCollapsed}
            >
              <div className="flex items-center justify-center" style={{ width: '18px', height: '18px', flexShrink: 0 }}>
                {isCollapsed ? (
                  <ChevronRight style={{ width: '18px', height: '18px' }} />
                ) : (
                  <ChevronLeft style={{ width: '18px', height: '18px' }} />
                )}
              </div>
              <span 
                className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
                style={{ 
                  opacity: isCollapsed ? 0 : 1,
                  pointerEvents: isCollapsed ? 'none' : 'auto'
                }}
              >
                {isCollapsed ? 'Show Labels' : 'Hide Labels'}
              </span>
            </button>
            </div>
          </div>
        </nav>

        {/* Main Navigation Bar */}
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
            {/* Left side - Company name */}
            <div className="flex items-center" style={{ marginLeft: '-4px', minWidth: '300px' }}>
                      {viewMode === 'employee' ? (
          <User style={{ width: '16px', height: '16px', color: 'var(--gray-950)', marginRight: '12px' }} />
        ) : (
          <Building style={{ width: '16px', height: '16px', color: 'var(--gray-950)', marginRight: '12px' }} />
        )}
              <div className="flex items-center font-medium" style={{ color: 'var(--gray-950)', fontSize: '14px' }}>
                <span>Secure Corp</span>
              </div>
            </div>

            {/* Center - Empty space for future use */}
            <div className="flex-1"></div>

            {/* Right side - User actions */}
            <div className="flex items-center gap-3">
              <span className="font-medium" style={{ color: 'var(--gray-950)', fontSize: '14px' }}>
                {viewMode === 'employee' ? 'Employee View' : 'Management View'}
              </span>

              <button 
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="Search"
              >
                <Search style={{ width: '16px', height: '16px' }} />
              </button>
              
              <button 
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="Notifications"
              >
                <Bell style={{ width: '16px', height: '16px' }} />
              </button>

              <button 
                onClick={handleHelpClick}
                className="p-1 rounded"
                style={{ color: 'var(--gray-950)' }}
                aria-label="Help & Knowledge Base"
                title="Help & Knowledge Base"
              >
                <HelpCircle style={{ width: '16px', height: '16px' }} />
              </button>

              {/* User Menu */}
              <div className="relative" data-user-menu>
                <button 
                  className="rounded-full flex items-center justify-center hover:opacity-80 transition-colors"
                  style={{ 
                    width: '28px', 
                    height: '28px',
                                         backgroundColor: 'var(--teal-brand-hex)'
                  }}
                  aria-label="My Account"
                  data-testid="view-toggle"
                  onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
                >
                  <User style={{ width: '14px', height: '14px', color: 'white' }} />
                </button>

                {/* User Dropdown Menu */}
                {isUserMenuOpen && (
                  <div 
                    className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-50"
                    style={{ top: '100%' }}
                  >
                    {/* User Info Section */}
                    <div className="px-4 py-3 border-b border-gray-100">
                      <div className="text-sm text-gray-500 mb-1">Logged in as</div>
                      <div className="font-medium text-gray-900">{user?.name || 'Demo User'}</div>
                    </div>

                    {/* Menu Items */}
                    <div className="py-1">
                      <button
                        className="w-full px-4 py-2 text-left text-sm text-blue-600 hover:bg-gray-50 flex items-center gap-2"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          // Add navigation to account page if needed
                        }}
                      >
                        <User style={{ width: '16px', height: '16px' }} />
                        My Account
                      </button>
                      
                      <button
                        className="w-full px-4 py-2 text-left text-sm text-blue-600 hover:bg-gray-50 flex items-center gap-2"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          // Add navigation to change password if needed
                        }}
                      >
                        <Settings style={{ width: '16px', height: '16px' }} />
                        Change Password
                      </button>

                      {/* View Mode Toggle */}
                      <div className="border-t border-gray-100 mt-1 pt-1">
                        <div className="px-4 py-2">
                          <div className="text-xs text-gray-500 mb-2">View Mode</div>
                          <button
                            onClick={() => {
                              handleViewToggle();
                              setIsUserMenuOpen(false);
                            }}
                            className="w-full px-3 py-2 text-sm bg-gray-50 hover:bg-gray-100 rounded transition-colors text-left"
                            style={{ color: 'var(--gray-950)' }}
                            data-testid={viewMode === 'employee' ? 'manager-view-btn' : 'employee-view-btn'}
                          >
                            Switch to {viewMode === 'employee' ? 'Manager' : 'Employee'} View
                          </button>
                        </div>
                      </div>

                      <button
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2 border-t border-gray-100 mt-1 pt-3"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          logout();
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

        {/* Secondary Navigation Bar for Submodules */}
        {(submoduleTabs.length > 0 || breadcrumbs.length > 0) && (
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
                <div className="flex items-stretch h-full" role="tablist">
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
                          color: tab.isActive ? 'var(--teal-brand-hex)' : 'var(--graphite-black-hex)',
                          borderColor: 'var(--gray-250)',
                          borderBottom: tab.isActive ? '2px solid var(--teal-700)' : 'none'
                        }}
                        role="tab"
                        aria-selected={tab.isActive}
                        aria-label={tab.label}
                      >
                        {tab.label}
                      </button>
                    );
                  })}
                </div>
              ) : breadcrumbs.length > 0 ? (
                <nav className="flex items-center h-full" style={{ paddingLeft: '1.5rem' }} aria-label="Breadcrumb">
                  <ol className="flex items-center gap-2" style={{ fontSize: '14px', color: 'var(--gray-950)' }}>
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
          className="flex-1 transition-all duration-300"
          style={{
            marginLeft: mainMarginLeft,
            paddingTop: mainPaddingTop,
            padding: `${mainPaddingTop} 1.5rem 1.5rem`,
            backgroundColor: 'var(--gray-200)'
          }}
          role="main"
        >
          {children}
        </main>
      </div>
    </div>
  );
}

export default memo(Layout);
