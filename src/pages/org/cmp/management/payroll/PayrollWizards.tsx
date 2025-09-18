import { useEffect, useState } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  HandCoins, 
  Calendar,
  CalendarDays,
  CalendarCheck,
  Clock,
  Gift,
  UserX,
  FileText
} from 'lucide-react';

interface PayrollModule {
  id: string;
  label: string;
  icon: any;
  description: string;
  category: 'regular' | 'non-regular';
}

const payrollModules: PayrollModule[] = [
  // REGULAR
  {
    id: 'weekly',
    label: 'Weekly',
    icon: Calendar,
    description: 'Process weekly payroll for all eligible employees',
    category: 'regular'
  },
  {
    id: 'bi-weekly',
    label: 'Bi-Weekly',
    icon: CalendarDays,
    description: 'Process bi-weekly payroll cycles',
    category: 'regular'
  },
  {
    id: 'semi-monthly',
    label: 'Semi Monthly',
    icon: CalendarCheck,
    description: 'Process semi-monthly payroll schedules',
    category: 'regular'
  },
  {
    id: 'monthly',
    label: 'Monthly',
    icon: Clock,
    description: 'Process monthly payroll for salaried employees',
    category: 'regular'
  },
  // NON-REGULAR
  {
    id: 'extraordinary',
    label: 'Extraordinary',
    icon: Gift,
    description: 'Process bonuses, commissions, and special payments',
    category: 'non-regular'
  },
  {
    id: 'vacation',
    label: 'Vacation',
    icon: Calendar,
    description: 'Process vacation pay and time-off payments',
    category: 'non-regular'
  },
  {
    id: 'termination',
    label: 'Termination',
    icon: UserX,
    description: 'Process final payments and termination settlements',
    category: 'non-regular'
  }
];

export default function PayrollWizards() {
  const { registerSubmodules } = useSubmoduleNav();
  const [activeModule, setActiveModule] = useState<string>('weekly');

  useEffect(() => {
    // Clear any existing submodules to hide the secondary navbar
    registerSubmodules('Payroll', []);
  }, [registerSubmodules]);

  const activeModuleData = payrollModules.find(module => module.id === activeModule);
  const regularModules = payrollModules.filter(module => module.category === 'regular');
  const nonRegularModules = payrollModules.filter(module => module.category === 'non-regular');

  return (
    <div className="flex h-[calc(100vh-48px)] -ml-6 -mr-6">
      {/* Secondary Sidebar */}
      <div className="w-56 bg-white border-r border-gray-200 flex-shrink-0">
        {/* Sidebar Header */}
        <div className="px-6 border-b border-gray-200 flex items-center" style={{ height: '48px' }}>
          <h2 className="text-sm font-semibold text-gray-900">Payroll Modules</h2>
        </div>

        {/* Module Navigation */}
        <nav className="px-4 py-4">
          {/* REGULAR Section */}
          <div className="mb-12">
            <h3 className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3 px-3">REGULAR</h3>
            <ul className="space-y-1">
              {regularModules.map((module) => {
                const Icon = module.icon;
                const isActive = activeModule === module.id;
                
                return (
                  <li key={module.id}>
                    <button
                      onClick={() => setActiveModule(module.id)}
                      className={`w-full flex items-center px-3 py-2 text-sm rounded transition-colors ${
                        isActive
                          ? 'bg-primary text-white'
                          : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                      }`}
                    >
                      <span className="font-medium">{module.label}</span>
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>

          {/* NON-REGULAR Section */}
          <div>
            <h3 className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3 px-3">NON-REGULAR</h3>
            <ul className="space-y-1">
              {nonRegularModules.map((module) => {
                const Icon = module.icon;
                const isActive = activeModule === module.id;
                
                return (
                  <li key={module.id}>
                    <button
                      onClick={() => setActiveModule(module.id)}
                      className={`w-full flex items-center px-3 py-2 text-sm rounded transition-colors ${
                        isActive
                          ? 'bg-primary text-white'
                          : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                      }`}
                    >
                      <span className="font-medium">{module.label}</span>
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        </nav>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Secondary Navbar for Payroll Tabs */}
        <div className="border-b border-gray-200 bg-white flex items-center" style={{ height: '48px' }}>
          {/* Payroll Tabs will go here */}
        </div>

        {/* Content Body */}
        <div className="flex-1 bg-gray-50 overflow-y-auto">
          <div>
            {/* Coming Soon Content */}
            <div className="flex items-center justify-center min-h-[400px]">
              <div className="text-center">
                <FileText className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                <h2 className="text-2xl font-semibold text-gray-600 mb-2">
                  {activeModuleData?.label} Payroll
                </h2>
                <p className="text-gray-500 mb-6">
                  {activeModuleData?.description}
                </p>
                <div className="inline-flex items-center gap-2 px-4 py-2 bg-gray-100 rounded-lg">
                  <div className="w-2 h-2 bg-yellow-400 rounded-full animate-pulse"></div>
                  <span className="text-sm text-gray-600">Coming Soon</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
