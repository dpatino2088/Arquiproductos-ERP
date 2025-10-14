import React, { ReactNode, useState, useCallback, useMemo, useEffect, memo } from 'react';
import { useAuth } from '../hooks/useAuth';
import { router } from '../lib/router';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { useUIStore } from '../stores/ui-store';
import { usePreviousPage } from '../hooks/usePreviousPage';
import { RhemoLogo } from './RhemoLogo';
import { 
  getSidebarStyles, 
  getButtonStyles, 
  getHoverStyles, 
  getTextStyles, 
  getLogoTextColor,
  getNextViewMode,
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
  Receipt,
  Printer,
  HandCoins,
  Briefcase,
  Cpu,
  ChartNoAxesCombined,
  HeartPulse,
  CalendarCheck,
  BookMarked,
  WalletCards
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
  viewMode: 'employee' | 'manager' | 'group';
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
      <item.icon style={{ width: '18px', height: '18px' }} />
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
  { name: 'Recruitment', href: '/org/cmp/management/recruitment/job-openings', icon: Briefcase },
  { name: 'Time & Attendance', href: '/org/cmp/management/time-and-attendance/whos-working', icon: Clock },
  { name: 'PTO & Leave', href: '/org/cmp/management/pto-and-leaves/team-leave-calendar', icon: CalendarCheck },
  { name: 'Company Knowledge', href: '/org/cmp/management/company-knowledge/about-the-company', icon: BookMarked },
  { name: 'Performance', href: '/org/cmp/management/performance/team-goals-and-performance', icon: ChartNoAxesCombined },
  { name: 'Benefits', href: '/org/cmp/management/benefits/team-benefits', icon: WalletCards },
];

const employeeOnlyNavigation = [
  { name: 'Wellness', href: '/wellness', icon: HeartPulse },
  { name: 'Expenses', href: '/org/cmp/employee/expenses/my-expenses', icon: Receipt },
];

const managementExpenses = [
  { name: 'Expenses', href: '/org/cmp/management/expenses/team-expenses', icon: Receipt },
];

const sharedManagementNavigation = [
  { name: 'IT Management', href: '/org/cmp/management/it-management/team-devices', icon: Cpu },
];



function Layout({ children }: LayoutProps) {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const { logout, user } = useAuth();
  const [currentRoute, setCurrentRoute] = useState('/');
  const { tabs: submoduleTabs, breadcrumbs } = useSubmoduleNav();
  const { saveCurrentPageBeforeSettings } = usePreviousPage();
  
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
      case 'Recruitment':
        // Recruitment is active if we're on any recruitment route
        return currentRoute.includes('/recruitment');
      case 'Employees':
        // Employees is active if we're on any employees route
        return currentRoute.includes('/employees');
      case 'My Info':
        // My Info is active if we're on any employees or my-info route
        return currentRoute.includes('/employees') || currentRoute.includes('/my-info');
      case 'Time & Attendance':
        // Time & Attendance is active if we're on any time-and-attendance route
        return currentRoute.includes('/time-and-attendance');
      case 'PTO & Leave':
        // PTO & Leave is active if we're on any pto-and-leaves route
        return currentRoute.includes('/pto-and-leaves');
      case 'Performance':
        // Performance is active if we're on any performance route
        return currentRoute.includes('/performance');
      case 'Company Knowledge':
        // Company Knowledge is active if we're on any company-knowledge route or cmp/about-the-company
        return currentRoute.includes('/company-knowledge') || currentRoute.includes('/cmp/about-the-company');
      case 'Benefits':
        // Benefits is active if we're on any benefits route
        return currentRoute.includes('/benefits');
      case 'Expenses':
        // Expenses is active if we're on any expenses route
        return currentRoute.includes('/expenses');
      case 'IT Management':
        // IT Management is active if we're on any it-management route
        return currentRoute.includes('/it-management');
      case 'Wellness':
        // Wellness is active if we're on any wellness route
        return currentRoute.includes('/wellness');
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
    
    if (viewMode === 'group') {
      // Group view navigation - Home, Companies, Reports, Settings
      const homeItem = { name: 'Home', href: '/org/grp/dashboard', icon: Home };
      const companiesItem = { name: 'Companies', href: '/org/grp/companies', icon: Building2 };
      const reportsItem = { name: 'Reports', href: '/org/grp/reports', icon: Printer };
      const settingsItem = { name: 'Settings', href: '/org/grp/settings', icon: Settings };
      return [homeItem, companiesItem, reportsItem, settingsItem];
    } else if (viewMode === 'manager') {
      const employeesItem = { name: 'Employees', href: '/employees', icon: Users };
      // Insert People after Recruiting (index 1) and before Time & Attendance (index 2)
      const recruitingItem = restOfBase[0]; // Recruitment
      const remainingItems = restOfBase.slice(1); // Everything after Recruiting
      return [dashboardItem, recruitingItem, employeesItem, ...remainingItems, ...managementExpenses, { name: 'Payroll', href: '/org/cmp/management/payroll/payroll-wizards', icon: HandCoins }, ...sharedManagementNavigation, { name: 'Reports', href: '/org/cmp/management/reports/company-reports', icon: Printer }];
    } else {
      // Employee view navigation in specific order
      const myInfoItem = { name: 'My Info', href: '/org/cmp/employee/my-info', icon: User };
      const timeAttendanceItem = { name: 'Time & Attendance', href: '/org/cmp/employee/time-and-attendance/my-clock', icon: Clock };
      const ptoLeaveItem = { name: 'PTO & Leaves', href: '/org/cmp/employee/pto-and-leaves/my-balance', icon: CalendarCheck };
      const companyKnowledgeItem = { name: 'Company Knowledge', href: '/org/cmp/employee/company-knowledge/about-the-company', icon: BookMarked };
      const performanceItem = { name: 'Performance', href: '/org/cmp/employee/performance/my-performance', icon: ChartNoAxesCombined };
      const benefitsItem = { name: 'Benefits', href: '/org/cmp/employee/benefits/my-benefits', icon: WalletCards };
      const wellnessItem = { name: 'Wellness', href: '/org/cmp/employee/wellness/fitness', icon: HeartPulse };
      const expensesItem = { name: 'Expenses', href: '/org/cmp/employee/expenses/my-expenses', icon: Receipt };
      const itManagementItem = { name: 'IT Management', href: '/org/cmp/employee/it-management/my-devices', icon: Cpu };
      
      return [
        dashboardItem, 
        myInfoItem, 
        timeAttendanceItem, 
        ptoLeaveItem, 
        companyKnowledgeItem, 
        performanceItem, 
        benefitsItem, 
        wellnessItem,
        expensesItem, 
        itManagementItem
      ];
    }
  }, [viewMode]);

  const dashboardItem = useMemo(() => 
    navigation.find(item => item?.name === 'Dashboard' || item?.name === 'Home'), [navigation]
  );
  
  const otherNavItems = useMemo(() => 
    navigation.filter(item => 
      item?.name !== 'Dashboard' && 
      item?.name !== 'Home' && 
      !(viewMode === 'group' && item?.name === 'Settings') // Exclude Settings in group view since it's rendered separately
    ), [navigation, viewMode]
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

  const handleViewToggle = useCallback(() => {
    const newMode = getNextViewMode(viewMode);
    setViewMode(newMode);
    router.setViewMode(newMode);
    
    // Navigate to appropriate dashboard based on view mode
    const newPath = getDashboardUrl(newMode);
    router.navigate(newPath);
    setCurrentRoute(newPath);
  }, [viewMode]);

  const handleNavigation = useCallback((path: string) => {
    // Save current page before navigating to settings
    if (path.includes('/settings/company-settings')) {
      saveCurrentPageBeforeSettings();
    }
    
    // Handle dynamic navigation based on view mode
    if (path === '/dashboard') {
      const actualPath = getDashboardUrl(viewMode);
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else if (path === '/employees') {
      const actualPath = viewMode === 'employee' 
        ? '/org/cmp/employee/my-info' 
        : '/org/cmp/management/employees/directory';
      router.navigate(actualPath);
      setCurrentRoute(actualPath);
    } else {
      router.navigate(path);
      setCurrentRoute(path);
    }
  }, [viewMode, saveCurrentPageBeforeSettings]);

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
        {/* Sidebar Navigation */}
        <nav 
          id="main-navigation"
          className={`min-h-screen fixed left-0 top-0 bottom-0 overflow-y-auto transition-all duration-300 z-50 border-r ${
            isCollapsed ? 'w-14' : 'w-60'
          }`}
          style={{ 
            width: sidebarWidth,
            ...getSidebarStyles(viewMode)
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
                <RhemoLogo width={27} height={27} viewMode={viewMode} />
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
              <span style={{ fontWeight: '700' }}>RH</span><span style={{ fontWeight: '200' }}>EMO</span>
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


              {/* Settings Button - Only show in manager and group views */}
              {viewMode !== 'employee' && (() => {
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
                {getViewModeLabel(viewMode)}
              </span>


              {/* User Menu */}
              <div className="relative" data-user-menu>
                <button 
                  id="user-menu"
                  className="rounded-full flex items-center justify-center hover:opacity-80 transition-colors"
                  style={{ 
                    width: '28px', 
                    height: '28px',
                                         backgroundColor: 'var(--teal-brand-hex)'
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
                    className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-50"
                    style={{ top: '100%' }}
                    role="menu"
                    aria-label="User account menu"
                    aria-orientation="vertical"
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
                        role="menuitem"
                        aria-label="Go to my account settings"
                      >
                        <User style={{ width: '16px', height: '16px' }} aria-hidden="true" />
                        My Account
                      </button>
                      

                      {/* View Mode Toggle */}
                      <div className="border-t border-gray-100 mt-1 pt-1">
                        <div className="px-4 py-2">
                          <div className="text-xs text-gray-500 mb-2" role="group" aria-label="View mode selection">View Mode</div>
                          <div className="space-y-1">
                            {/* Group View Button */}
                            <button
                              onClick={() => {
                                if (viewMode !== 'group') {
                                  setViewMode('group');
                                  router.setViewMode('group');
                                  router.navigate('/org/grp/dashboard');
                                  setCurrentRoute('/org/grp/dashboard');
                                  setIsUserMenuOpen(false);
                                }
                              }}
                              className={`w-full px-3 py-2 text-sm rounded transition-colors text-left ${
                                viewMode === 'group' 
                                  ? 'bg-blue-100 text-blue-800 font-medium cursor-default' 
                                  : 'bg-gray-50 hover:bg-gray-100'
                              }`}
                              style={{ color: viewMode === 'group' ? 'var(--blue-800)' : 'var(--gray-950)' }}
                              data-testid="group-view-btn"
                              disabled={viewMode === 'group'}
                              role="menuitemradio"
                              aria-checked={viewMode === 'group'}
                              aria-label={`Switch to Group View${viewMode === 'group' ? ' (currently selected)' : ''}`}
                            >
                              Group View {viewMode === 'group' && '✓'}
                            </button>
                            
                            {/* Management View Button */}
                            <button
                              onClick={() => {
                                if (viewMode !== 'manager') {
                                  setViewMode('manager');
                                  router.setViewMode('manager');
                                  router.navigate('/org/cmp/management/dashboard');
                                  setCurrentRoute('/org/cmp/management/dashboard');
                                  setIsUserMenuOpen(false);
                                }
                              }}
                              className={`w-full px-3 py-2 text-sm rounded transition-colors text-left ${
                                viewMode === 'manager' 
                                  ? 'bg-blue-100 text-blue-800 font-medium cursor-default' 
                                  : 'bg-gray-50 hover:bg-gray-100'
                              }`}
                              style={{ color: viewMode === 'manager' ? 'var(--blue-800)' : 'var(--gray-950)' }}
                              data-testid="manager-view-btn"
                              disabled={viewMode === 'manager'}
                            >
                              Management View {viewMode === 'manager' && '✓'}
                            </button>
                            
                            {/* Employee View Button */}
                            <button
                              onClick={() => {
                                if (viewMode !== 'employee') {
                                  setViewMode('employee');
                                  router.setViewMode('employee');
                                  router.navigate('/org/cmp/employee/dashboard');
                                  setCurrentRoute('/org/cmp/employee/dashboard');
                                  setIsUserMenuOpen(false);
                                }
                              }}
                              className={`w-full px-3 py-2 text-sm rounded transition-colors text-left ${
                                viewMode === 'employee' 
                                  ? 'bg-blue-100 text-blue-800 font-medium cursor-default' 
                                  : 'bg-gray-50 hover:bg-gray-100'
                              }`}
                              style={{ color: viewMode === 'employee' ? 'var(--blue-800)' : 'var(--gray-950)' }}
                              data-testid="employee-view-btn"
                              disabled={viewMode === 'employee'}
                            >
                              Employee View {viewMode === 'employee' && '✓'}
                            </button>
                            
                          </div>
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
                                                     color: tab.isActive ? 'var(--teal-brand-hex)' : 'var(--graphite-black-hex)',
                          borderColor: 'var(--gray-250)',
                          borderBottom: tab.isActive ? '2px solid var(--teal-700)' : 'none'
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
            marginLeft: mainMarginLeft,
            paddingTop: mainPaddingTop,
            padding: `${mainPaddingTop} 1.5rem 1.5rem`,
            backgroundColor: 'var(--gray-200)'
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

