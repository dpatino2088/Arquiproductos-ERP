import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { DollarSign } from 'lucide-react';

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Financials', [
      { id: 'financials', label: 'Financials', href: '/financials', icon: DollarSign }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="py-6">
      <div className="mb-6">
        <h1 className="text-title font-semibold text-foreground mb-1">Financials</h1>
        <p className="text-small text-muted-foreground">Manage your financial operations, accounting, and reports</p>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="text-center py-12">
          <DollarSign className="h-16 w-16 text-gray-400 mx-auto mb-4" />
          <h2 className="text-lg font-semibold text-gray-900 mb-2">Financials Module</h2>
          <p className="text-sm text-gray-600">
            This module is coming soon. Financials functionality will be available here.
          </p>
        </div>
      </div>
    </div>
  );
}

