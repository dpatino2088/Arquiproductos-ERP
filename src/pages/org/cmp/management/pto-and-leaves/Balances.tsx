import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Calendar as CalendarIcon, FileText, TrendingUp } from 'lucide-react';

export default function Balances() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for PTO & Leaves
    registerSubmodules('PTO & Leaves', [
      { id: 'calendar', label: 'Calendar', href: '/management/pto-and-leaves/calendar', icon: CalendarIcon },
      { id: 'requests', label: 'Requests', href: '/management/pto-and-leaves/requests', icon: FileText },
      { id: 'balances', label: 'Balances', href: '/management/pto-and-leaves/balances', icon: TrendingUp }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Balances</h1>
        <p className="text-xs text-muted-foreground">View and manage PTO and leave balances</p>
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
