import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { usePreviousPage } from '../../hooks/usePreviousPage';
import { useCompanyStore } from '../../stores/company-store';
import {
  Building,
  Users,
  CreditCard,
  Plug,
  Settings as SettingsIcon,
  X,
} from 'lucide-react';
import Members from './Members';
import OrganizationUser from './OrganizationUser';

export default function Settings() {
  const { getPreviousPage } = usePreviousPage();
  const { currentCompany, currentCompanyUser } = useCompanyStore();
  const [activeTab, setActiveTab] = useState<string>('organization-profile');

  // Check if user is Owner/Admin
  const isOwnerOrAdmin = currentCompanyUser?.role === 'super_admin' || currentCompanyUser?.role === 'admin';

  // Handle ESC key to close settings and return to previous page
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        const previousPage = getPreviousPage();
        const targetPage = previousPage || '/dashboard';
        console.log('ESC pressed, previous page:', previousPage, 'navigating to:', targetPage);
        try {
          router.navigate(targetPage);
        } catch (error) {
          console.error('Router navigation failed:', error);
          window.location.href = targetPage;
        }
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [getPreviousPage]);

  const handleCloseSettings = (): void => {
    const previousPage = getPreviousPage();
    const targetPage = previousPage || '/dashboard';
    console.log('Closing settings, previous page:', previousPage, 'navigating to:', targetPage);
    try {
      router.navigate(targetPage);
    } catch (error) {
      console.error('Router navigation failed:', error);
      window.location.href = targetPage;
    }
  };

  // Settings tabs configuration
  const settingsTabs = [
    { id: 'organization-profile', label: 'Organization Profile', icon: Building },
    ...(isOwnerOrAdmin ? [{ id: 'members', label: 'Members', icon: Users }] : []),
    ...(isOwnerOrAdmin ? [{ id: 'billing', label: 'Billing', icon: CreditCard }] : []),
    ...(isOwnerOrAdmin ? [{ id: 'integrations', label: 'Integrations', icon: Plug }] : []),
  ];

  const renderTabContent = () => {
    switch (activeTab) {
      case 'organization-profile':
        return <OrganizationUser />;
      case 'members':
        if (!isOwnerOrAdmin) return null;
        return <Members />;
      case 'billing':
        if (!isOwnerOrAdmin) return null;
        return (
          <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
            <CreditCard className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Billing</h3>
            <p className="text-gray-500">Billing settings will be available here in the future.</p>
          </div>
        );
      case 'integrations':
        if (!isOwnerOrAdmin) return null;
        return (
          <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
            <Plug className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Integrations</h3>
            <p className="text-gray-500">Integration settings (Supabase, APIs, etc.) will be available here in the future.</p>
          </div>
        );
      default:
        return <OrganizationUser />;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 fixed inset-0 z-50">
      {/* Settings Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-50">
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
        {/* Content Area */}
        <div className="flex-1 flex flex-col">
          {/* Secondary Navigation - Tabs */}
          {settingsTabs.length > 0 && (
            <div className="bg-gray-50 border-b border-gray-200 flex-shrink-0 px-6" style={{ height: '48px' }}>
              <div className="flex items-center" style={{ height: '48px' }}>
                <div className="flex items-stretch h-full -mx-2">
                  {settingsTabs.map((tab) => (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      className={`font-medium transition-colors flex items-center justify-center gap-2 px-4 rounded-t-lg ${
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
                      <tab.icon style={{ width: '16px', height: '16px' }} />
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
              <div className="mb-6">
                <h2 className="text-xl font-semibold text-gray-900 mb-2">
                  {settingsTabs.find(tab => tab.id === activeTab)?.label}
                </h2>
                <p className="text-sm text-gray-600">
                  {activeTab === 'organization-profile' && 'Manage your organization profile and information.'}
                  {activeTab === 'members' && 'Manage team members, roles, and permissions.'}
                  {activeTab === 'billing' && 'Manage billing and subscription settings.'}
                  {activeTab === 'integrations' && 'Configure integrations with external services.'}
                </p>
              </div>
              {renderTabContent()}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

