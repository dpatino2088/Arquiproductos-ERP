import React, { useEffect } from 'react';
import { Settings as SettingsIcon } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export default function PersonalSettings() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'personal-settings', label: 'Settings', href: '/me/settings', icon: SettingsIcon }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Settings</h1>
        <p className="text-xs text-muted-foreground">Configure your personal preferences and account settings</p>
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
