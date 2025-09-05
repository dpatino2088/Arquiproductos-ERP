import React, { useEffect } from 'react';
import { Home } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export default function PersonalDashboard() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Home', [
      { id: 'personal-dashboard', label: 'Dashboard', href: '/me/dashboard', icon: Home }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Personal Dashboard</h1>
        <p className="text-xs text-muted-foreground">Overview of your personal workspace and activities</p>
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
