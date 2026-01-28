import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import {
  Building,
  Users,
  Settings as SettingsIcon,
  ChevronRight,
  X,
  Shield
} from 'lucide-react';
import OrganizationUser from './OrganizationUser';
import OrganizationUserNew from './OrganizationUserNew';
import OrganizationUserEdit from './OrganizationUserEdit';
import CostEngineSettings from './CostEngineSettings';
import DealerProfile from './DealerProfile';

export default function CompanySettings() {
  const { isMember, loading: roleLoading } = useCurrentOrgRole();
  const [activeSection, setActiveSection] = useState<string>('organization');
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
  const isAddUserMode = currentRoute.includes('/settings/organization-users/new');
  const editUserMatch = currentRoute.match(/\/settings\/organization-users\/edit\/([^/]+)/);
  const editingUserId = editUserMatch ? editUserMatch[1] : null;
  const isAddEditUserMode = isAddUserMode || !!editingUserId;
  
  // Determine if we're in dealer profile edit mode
  const isDealerEditMode = currentRoute.match(/\/settings\/dealer-profile\/edit\/([^/]+)/);
  const isDealerNewMode = currentRoute.includes('/settings/dealer-profile/new');
  const isDealerUserMode = currentRoute.includes('/settings/dealer-profile/user');
  
  // Ensure activeSection matches route for dealer-profile (including user tab)
  useEffect(() => {
    if ((currentRoute.includes('/settings/dealer-profile') || isDealerUserMode) && activeSection !== 'dealer-profile') {
      setActiveSection('dealer-profile');
    }
  }, [currentRoute, isDealerUserMode, activeSection]);

  // Ensure activeSection matches route for cost-engine
  useEffect(() => {
    if (currentRoute.includes('/settings/cost-engine') && activeSection !== 'cost-engine') {
      setActiveSection('cost-engine');
    }
  }, [currentRoute, activeSection]);

  // Proteger Settings: Members no pueden acceder - redirigir inmediatamente sin mostrar error
  useEffect(() => {
    if (!roleLoading && isMember) {
      // Redirigir inmediatamente al dashboard sin mostrar mensaje
      router.navigate('/dashboard');
    }
  }, [isMember, roleLoading]);

  // Si es Member, redirigir inmediatamente (no mostrar nada)
  if (!roleLoading && isMember) {
    return null; // No renderizar nada, la redirección ya está en curso
  }

  // Settings menu configuration based on our app modules
  const settingsMenu = [
    { id: 'organization', label: 'Organization', icon: Users },
    { id: 'dealer-profile', label: 'Dealer Profile', icon: Building },
    { id: 'cost-engine', label: 'Cost Engine', icon: SettingsIcon }
  ];

  // Tab configurations for each section
  const sectionTabs: Record<string, Array<{ id: string; label: string }>> = {
    'organization-user': []
  };

  const currentTabs = sectionTabs[activeSection] || [];

  const handleSectionChange = (sectionId: string): void => {
    setActiveSection(sectionId);
    const newTabs = sectionTabs[sectionId];
    if (newTabs && newTabs.length > 0) {
      setActiveTab(newTabs[0]?.id || 'general');
    }
    
    // Navigate to the corresponding route
    if (sectionId === 'organization') {
      router.navigate('/settings/organization');
    } else if (sectionId === 'dealer-profile') {
      router.navigate('/settings/dealer-profile');
    } else if (sectionId === 'cost-engine') {
      router.navigate('/settings/cost-engine');
    }
  };

  // Handle navigation when in add/edit mode
  useEffect(() => {
    if (isAddEditUserMode) {
      // If we're in add/edit mode, ensure we're on the correct route
      const expectedRoute = isAddUserMode 
        ? '/settings/organization-users/new'
        : `/settings/organization-users/edit/${editingUserId}`;
      
      const currentPath = window.location.pathname;
      if (currentPath !== expectedRoute) {
        router.navigate(expectedRoute, false);
      }
    }
    
    // Ensure activeSection matches route for organization
    if (currentRoute.includes('/settings/organization') || currentRoute.includes('/settings/organization-users')) {
      if (activeSection !== 'organization') {
        setActiveSection('organization');
      }
    }
  }, [isAddEditUserMode, isAddUserMode, editingUserId, currentRoute, activeSection]);

  // Handle close settings and navigate to dashboard
  const handleCloseSettings = () => {
    router.navigate('/dashboard', false);
  };

  // Handle ESC key to close settings
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        handleCloseSettings();
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, []);

  const renderTabContent = () => {
    // If we're in edit user mode, show OrganizationUserEdit
    if (editingUserId) {
      return <OrganizationUserEdit userId={editingUserId} embedded={true} />;
    }
    
    // If we're in add user mode, show OrganizationUserNew embedded
    if (isAddUserMode) {
      return <OrganizationUserNew embedded={true} />;
    }

    if (activeSection === 'organization') {
      return <OrganizationUser />;
    }

    if (activeSection === 'dealer-profile') {
      return <DealerProfile />;
    }

    if (activeSection === 'cost-engine') {
      return <CostEngineSettings />;
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

          <div className="ml-auto">
            <button
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                handleCloseSettings();
              }}
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
                // Highlight organization if we're in add/edit mode
                const isActive = isAddEditUserMode 
                  ? item.id === 'organization'
                  : activeSection === item.id;
                return (
                  <li key={item.id}>
                    <button
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        if (isAddEditUserMode) {
                          router.navigate('/settings/organization');
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
        <div className="flex-1 flex flex-col overflow-auto">
          {/* Settings Content */}
          <div className="flex-1 py-6 px-6">
            {renderTabContent()}
          </div>
        </div>
      </div>
    </div>
  );
}
