import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { HandCoins } from 'lucide-react';

export default function PayrollWizards() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Payroll
    registerSubmodules('Payroll', [
      { id: 'payroll-wizards', label: 'Payroll Wizards', href: '/org/cmp/management/payroll/payroll-wizards', icon: HandCoins }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Payroll Wizards</h1>
        <p className="text-xs text-muted-foreground">Automated payroll processing and management tools</p>
      </div>

      {/* Content */}
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}
