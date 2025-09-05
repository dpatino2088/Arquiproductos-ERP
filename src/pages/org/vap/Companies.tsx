import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { Building2 } from 'lucide-react';

export default function Companies() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Companies', [
      { id: 'companies', label: 'Companies', href: '/org/vap/companies', icon: Building2 }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Companies</h1>
        <p className="text-xs text-muted-foreground">Manage companies you provide value-added services to</p>
      </div>
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}
