import React, { useEffect } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { Home } from 'lucide-react';

export default function Dashboard() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Home', [
      { id: 'dashboard', label: 'Dashboard', href: '/grp/dashboard', icon: Home }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Dashboard</h1>
        <p className="text-xs text-muted-foreground">Group overview and management</p>
      </div>

      <div className="bg-card rounded-lg border border-border p-8 text-center">
        <div className="max-w-md mx-auto">
          <div className="mb-4">
            <div className="w-16 h-16 bg-muted rounded-full flex items-center justify-center mx-auto mb-4">
              <Home className="w-8 h-8 text-muted-foreground" />
            </div>
            <h2 className="text-lg font-semibold text-foreground mb-2">Coming Soon</h2>
            <p className="text-sm text-muted-foreground">
              The Group Dashboard is currently under development. Check back soon for updates!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
