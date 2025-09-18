import { useState, useEffect } from 'react';
import { router } from '../../../../../lib/router';
import { usePreviousPage } from '../../../../../hooks/usePreviousPage';
import {
  Building,
  Users,
  Clock,
  Calendar,
  FileText,
  TrendingUp,
  Heart,
  DollarSign,
  UserCheck,
  Settings as SettingsIcon,
  ChevronRight,
  X,
  BookOpen
} from 'lucide-react';

export default function CompanySettings() {
  const { getPreviousPage } = usePreviousPage();
  const [activeSection, setActiveSection] = useState<string>('time-and-attendance');
  const [activeTab, setActiveTab] = useState<string>('general');

  // Handle ESC key to close settings and return to previous page
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        const previousPage = getPreviousPage();
        // Si no hay página anterior, ir al dashboard de management
        const targetPage = previousPage || '/org/cmp/management/dashboard';
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
    { id: 'time-and-attendance', label: 'Time & Attendance', icon: Clock },
    { id: 'employees', label: 'Employees', icon: Users },
    { id: 'pto-leaves', label: 'PTO & Leaves', icon: Calendar },
    { id: 'company-info', label: 'Company Info', icon: Building },
    { id: 'lighthouse', label: 'Lighthouse', icon: BookOpen },
    { id: 'performance', label: 'Performance', icon: TrendingUp },
    { id: 'benefits', label: 'Benefits', icon: Heart },
    { id: 'payroll', label: 'Payroll', icon: DollarSign },
    { id: 'users', label: 'Users', icon: UserCheck }
  ];

  // Tab configurations for each section
  const sectionTabs: Record<string, Array<{ id: string; label: string }>> = {
    'time-and-attendance': [
      { id: 'general', label: 'General' },
      { id: 'time-tracking', label: 'Time Tracking' },
      { id: 'overtime', label: 'Overtime Rules' },
      { id: 'holidays', label: 'Holidays' },
      { id: 'locations', label: 'Locations' }
    ],
    'employees': [
      { id: 'employee-settings', label: 'Employee Settings' },
      { id: 'permissions', label: 'Permissions' },
      { id: 'workflows', label: 'Workflows' },
      { id: 'departments', label: 'Departments' }
    ],
    'pto-leaves': [
      { id: 'leave-types', label: 'Leave Types' },
      { id: 'accrual-rules', label: 'Accrual Rules' },
      { id: 'approval-flow', label: 'Approval Flow' },
      { id: 'policies', label: 'Policies' }
    ],
    'company-info': [
      { id: 'general', label: 'General' },
      { id: 'branding', label: 'Branding' },
      { id: 'locations', label: 'Locations' },
      { id: 'policies', label: 'Policies' }
    ],
    'lighthouse': [
      { id: 'about-us', label: 'About Us' },
      { id: 'courses', label: 'Courses & Training' },
      { id: 'job-descriptions', label: 'Job Descriptions' },
      { id: 'sops', label: 'Standard Operating Procedures' }
    ],
    'performance': [
      { id: 'goals', label: 'Goals & Objectives' },
      { id: 'reviews', label: 'Performance Reviews' },
      { id: 'feedback', label: 'Feedback System' },
      { id: 'metrics', label: 'Performance Metrics' }
    ],
    'benefits': [
      { id: 'health-insurance', label: 'Health Insurance' },
      { id: 'retirement', label: 'Retirement Plans' },
      { id: 'wellness', label: 'Wellness Programs' },
      { id: 'other-benefits', label: 'Other Benefits' }
    ],
    'payroll': [
      { id: 'salary-structure', label: 'Salary Structure' },
      { id: 'deductions', label: 'Deductions' },
      { id: 'tax-settings', label: 'Tax Settings' },
      { id: 'pay-schedules', label: 'Pay Schedules' }
    ],
    'users': [
      { id: 'user-management', label: 'User Management' },
      { id: 'roles', label: 'Roles & Permissions' },
      { id: 'security', label: 'Security' },
      { id: 'access-control', label: 'Access Control' }
    ]
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
    const previousPage = getPreviousPage();
    // Si no hay página anterior, ir al dashboard de management
    const targetPage = previousPage || '/org/cmp/management/dashboard';
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
    if (activeSection === 'time-and-attendance') {
      switch (activeTab) {
        case 'general':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">General Time & Attendance Settings</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Default Work Hours per Day</label>
                      <input type="number" defaultValue="8" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Default Work Days per Week</label>
                      <input type="number" defaultValue="5" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Time Zone</label>
                      <select className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
                        <option>UTC-8 (Pacific Time)</option>
                        <option>UTC-7 (Mountain Time)</option>
                        <option>UTC-6 (Central Time)</option>
                        <option>UTC-5 (Eastern Time)</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Date Format</label>
                      <select className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
                        <option>MM/DD/YYYY</option>
                        <option>DD/MM/YYYY</option>
                        <option>YYYY-MM-DD</option>
                      </select>
                    </div>
                  </div>
                </div>
                <div className="flex gap-3">
                  <button className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors">
                    Save Changes
                  </button>
                  <button className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors">
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          );

        case 'time-tracking':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <h3 className="text-lg font-semibold text-gray-900">Time Tracking Settings</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                    <div>
                      <h4 className="font-medium text-gray-900">Enable GPS Tracking</h4>
                      <p className="text-sm text-gray-500">Track employee location during clock-in/out</p>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input type="checkbox" className="sr-only peer" defaultChecked />
                      <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/20 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                    </label>
                  </div>
                  <div className="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                    <div>
                      <h4 className="font-medium text-gray-900">Require Photo Verification</h4>
                      <p className="text-sm text-gray-500">Employees must take a photo when clocking in/out</p>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input type="checkbox" className="sr-only peer" />
                      <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/20 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                    </label>
                  </div>
                </div>
              </div>
            </div>
          );

        case 'overtime':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <h3 className="text-lg font-semibold text-gray-900">Overtime Rules</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Daily Overtime Threshold (hours)</label>
                    <input type="number" defaultValue="8" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Weekly Overtime Threshold (hours)</label>
                    <input type="number" defaultValue="40" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                  </div>
                </div>
              </div>
            </div>
          );

        case 'holidays':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <div className="flex justify-between items-center">
                  <h3 className="text-lg font-semibold text-gray-900">Company Holidays</h3>
                  <button className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors">
                    Add Holiday
                  </button>
                </div>
                <div className="space-y-3">
                  <div className="p-4 border border-gray-200 rounded-lg">
                    <h4 className="font-medium text-gray-900">New Year's Day</h4>
                    <p className="text-sm text-gray-500">January 1, 2024</p>
                  </div>
                  <div className="p-4 border border-gray-200 rounded-lg">
                    <h4 className="font-medium text-gray-900">Independence Day</h4>
                    <p className="text-sm text-gray-500">July 4, 2024</p>
                  </div>
                </div>
              </div>
            </div>
          );

        case 'locations':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <div className="flex justify-between items-center">
                  <h3 className="text-lg font-semibold text-gray-900">Work Locations</h3>
                  <button className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors">
                    Add Location
                  </button>
                </div>
                <div className="space-y-3">
                  <div className="p-4 border border-gray-200 rounded-lg">
                    <h4 className="font-medium text-gray-900">Main Office</h4>
                    <p className="text-sm text-gray-500">123 Business Avenue, San Francisco, CA 94105</p>
                  </div>
                  <div className="p-4 border border-gray-200 rounded-lg">
                    <h4 className="font-medium text-gray-900">Warehouse</h4>
                    <p className="text-sm text-gray-500">456 Industrial Blvd, Oakland, CA 94607</p>
                  </div>
                </div>
              </div>
            </div>
          );
      }
    }

    if (activeSection === 'employees') {
      switch (activeTab) {
        case 'employee-settings':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="space-y-6">
                <h3 className="text-lg font-semibold text-gray-900">Employee Settings</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                    <div>
                      <h4 className="font-medium text-gray-900">Allow Self-Service Profile Updates</h4>
                      <p className="text-sm text-gray-500">Employees can update their own profile information</p>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input type="checkbox" className="sr-only peer" defaultChecked />
                      <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/20 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                    </label>
                  </div>
                </div>
              </div>
            </div>
          );
      }
    }

    if (activeSection === 'company-info') {
      switch (activeTab) {
        case 'general':
          return (
            <div className="bg-white border border-gray-200 rounded-lg p-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Company Name</label>
                  <input type="text" defaultValue="Arquiluz S.A." className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Legal Name</label>
                  <input type="text" defaultValue="Arquiluz Sociedad Anonima" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Tax ID</label>
                  <input type="text" defaultValue="123-45-6789" className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Industry</label>
                  <select className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
                    <option>Architecture & Design</option>
                    <option>Technology</option>
                    <option>Construction</option>
                    <option>Consulting</option>
                  </select>
                </div>
              </div>
            </div>
          );
      }
    }

    // Default content for other sections
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
            <span className="text-sm font-medium text-gray-900">Arquiluz S.A.</span>
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
                const isActive = activeSection === item.id;
                return (
                  <li key={item.id}>
                    <button
                      onClick={() => handleSectionChange(item.id)}
                      className={`w-full flex items-center justify-between px-4 py-2 text-left rounded transition-colors ${
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
              {renderTabContent()}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
