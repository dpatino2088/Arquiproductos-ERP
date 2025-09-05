import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { Printer } from 'lucide-react';

export default function Reports() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Reports', [
      { id: 'reports', label: 'Reports', href: '/grp/reports', icon: Printer }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Reports</h1>
        <p className="text-xs text-muted-foreground">Generate and view group-level reports</p>
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
