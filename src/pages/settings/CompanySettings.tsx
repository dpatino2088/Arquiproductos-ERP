import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { usePreviousPage } from '../../hooks/usePreviousPage';
import { useCompanyStore } from '../../stores/company-store';
import {
  Building,
  Users,
  Settings as SettingsIcon,
  ChevronRight,
  X
} from 'lucide-react';
import OrganizationUser from './OrganizationUser';
import OrganizationProfileView from './OrganizationProfileView';
import OrganizationUserNew from './OrganizationUserNew';

export default function CompanySettings() {
  const { getPreviousPage } = usePreviousPage();
  const { currentCompany } = useCompanyStore();
  const [activeSection, setActiveSection] = useState<string>('organization-user');
  const [activeTab, setActiveTab] = useState<string>('general');
  const [currentRoute, setCurrentRoute] = useState<string>(router.getCurrentRoute() || window.location.pathname);

  // Monitor route changes to detect when we're in new/edit user mode
  useEffect(() => {
    const updateRoute = () => {
      const route = router.getCurrentRoute() || window.location.pathname;
      setCurrentRoute(route);
    };
    
    // Check route on mount
    updateRoute();
    
    // Listen for popstate events (browser back/forward)
    window.addEventListener('popstate', updateRoute);
    
    // Listen for route changes via interval (fallback for programmatic navigation)
    const interval = setInterval(updateRoute, 100);
    
    return () => {
      clearInterval(interval);
      window.removeEventListener('popstate', updateRoute);
    };
  }, []);

  // Determine if we're in add/edit user mode
  const isAddEditUserMode = currentRoute.includes('/settings/organization-users/new') || 
                            currentRoute.match(/\/settings\/organization-users\/edit\/[^/]+/);

  // Handle ESC key to close settings and return to previous page
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        const previousPage = getPreviousPage();
        // Si no hay página anterior, ir al dashboard de management
        const targetPage = previousPage || '/dashboard';
        console.log('ESC pressed, previous page:', previousPage, 'navigating to:', targetPage);
        try {
          router.navigate(targetPage);
        } catch (error) {
          console.error('Router navigation failed:', error);
          // Fallback to direct navigation
          window.location.href = targetPage;
        }
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [getPreviousPage]);

  // Settings menu configuration based on our app modules
  const settingsMenu = [
    { id: 'organization-user', label: 'Organization User', icon: Users },
    { id: 'organization-profile', label: 'Organization Profile', icon: Building }
  ];

  // Tab configurations for each section
  const sectionTabs: Record<string, Array<{ id: string; label: string }>> = {
    'organization-user': [],
    'organization-profile': []
  };

  const currentTabs = sectionTabs[activeSection] || [];

  const handleSectionChange = (sectionId: string): void => {
    setActiveSection(sectionId);
    const newTabs = sectionTabs[sectionId];
    if (newTabs && newTabs.length > 0) {
      setActiveTab(newTabs[0]?.id || 'general');
    }
  };

  const handleCloseSettings = (): void => {
    // Si estamos en modo add/edit, volver a organization-user, no al dashboard
    if (isAddEditUserMode) {
      router.navigate('/settings/organization-user');
      return;
    }
    
    const previousPage = getPreviousPage();
    // Si no hay página anterior, ir al dashboard de management
    const targetPage = previousPage || '/dashboard';
    console.log('Closing settings, previous page:', previousPage, 'navigating to:', targetPage);
    try {
      router.navigate(targetPage);
    } catch (error) {
      console.error('Router navigation failed:', error);
      // Fallback to direct navigation
      window.location.href = targetPage;
    }
  };

  const renderTabContent = () => {
    // If we're in add/edit user mode, show OrganizationUserNew embedded
    if (isAddEditUserMode) {
      return <OrganizationUserNew embedded={true} />;
    }

    if (activeSection === 'organization-user') {
      return <OrganizationUser />;
    }

    if (activeSection === 'organization-profile') {
      return <OrganizationProfileView />;
    }

    // Default content for other sections (shouldn't happen with current menu)
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
        <SettingsIcon className="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <h3 className="text-lg font-semibold text-gray-900 mb-2">
          {settingsMenu.find(item => item.id === activeSection)?.label} Settings
        </h3>
        <p className="text-gray-500">
          Configuration options for {settingsMenu.find(item => item.id === activeSection)?.label.toLowerCase()} will be available here.
        </p>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gray-50 fixed inset-0 z-[100]">
      {/* Settings Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-[100]">
        <div className="flex items-center h-12 px-6">
          <div className="flex items-center gap-3">
            <SettingsIcon className="text-gray-900" style={{ width: '20px', height: '20px' }} />
            <h1 className="text-lg font-semibold text-gray-900">Settings</h1>
          </div>

          <div className="h-6 w-px bg-gray-200 ml-6 mr-6"></div>

          <div className="flex items-center gap-2">
            <Building className="text-gray-900" style={{ width: '18px', height: '18px' }} />
            <span className="text-sm font-medium text-gray-900">{currentCompany?.name || 'No Company'}</span>
          </div>

          <div className="ml-auto">
            <button
              onClick={handleCloseSettings}
              className="text-gray-500 hover:text-gray-700 p-2 rounded-lg hover:bg-gray-50 transition-colors"
              title="Close Settings (ESC)"
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>
        </div>
      </header>

      {/* Settings Layout */}
      <div className="flex h-[calc(100vh-48px)]">
        {/* Settings Sidebar */}
        <div className="bg-white border-r border-gray-200 flex-shrink-0" style={{ width: '240px' }}>
          <div className="px-6 border-b border-gray-200 flex items-center" style={{ height: '48px' }}>
            <p className="text-xs text-gray-500">Manage your system settings and content</p>
          </div>

          <nav className="px-4 pt-6 pb-4">
            <ul className="space-y-1">
              {settingsMenu.map((item) => {
                // Highlight organization-user if we're in add/edit mode
                const isActive = isAddEditUserMode 
                  ? item.id === 'organization-user'
                  : activeSection === item.id;
                return (
                  <li key={item.id}>
                    <button
                      onClick={() => {
                        if (isAddEditUserMode) {
                          router.navigate('/settings/organization-user');
                        } else {
                          handleSectionChange(item.id);
                        }
                      }}
                      className={`w-full flex items-center justify-between px-4 py-2 text-left transition-colors ${
                        isActive
                          ? 'bg-primary text-white shadow-sm'
                          : 'text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <item.icon style={{ width: '16px', height: '16px' }} />
                        <span>{item.label}</span>
                      </div>
                      {isActive && (
                        <ChevronRight className="flex-shrink-0" style={{ width: '16px', height: '16px' }} />
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
          </nav>
      </div>

        {/* Content Area */}
        <div className="flex-1 flex flex-col">
          {/* Secondary Navigation */}
          {currentTabs.length > 0 && (
            <div className="bg-gray-50 border-b border-gray-200 flex-shrink-0 px-6" style={{ height: '48px' }}>
              <div className="flex items-center" style={{ height: '48px' }}>
                <div className="flex items-stretch h-full -mx-2">
                  {currentTabs.map((tab) => (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      className={`font-medium transition-colors flex items-center justify-center px-4 rounded-t-lg ${
                        tab.id === activeTab
                          ? 'bg-white text-primary border-b-2 border-primary'
                          : 'hover:text-primary hover:bg-white/50'
                      }`}
                      style={{
                        fontSize: '14px',
                        height: '46px',
                        minWidth: '140px'
                      }}
                    >
                      {tab.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Settings Content */}
          <div className="flex-1 p-8 overflow-auto">
            <div className="max-w-6xl">
              {!isAddEditUserMode && (
                <div className="mb-6">
                  <h2 className="text-xl font-semibold text-gray-900 mb-2">
                    {settingsMenu.find(item => item.id === activeSection)?.label}
                    {currentTabs.length > 0 && activeTab &&
                      ` - ${currentTabs.find(tab => tab.id === activeTab)?.label}`
                    }
                  </h2>
                  <p className="text-sm text-gray-600">
                    Configure and manage your {settingsMenu.find(item => item.id === activeSection)?.label.toLowerCase()} settings and content.
                  </p>
                </div>
              )}
              {renderTabContent()}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
