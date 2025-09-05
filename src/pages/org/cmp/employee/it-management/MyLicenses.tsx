import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';

export default function MyLicenses() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for IT Management
    registerSubmodules('IT Management', [
      { id: 'my-devices', label: 'My Devices', href: '/org/cmp/employee/it-management/my-devices' },
      { id: 'my-licenses', label: 'My Licenses', href: '/org/cmp/employee/it-management/my-licenses' },
      { id: 'my-it-requests', label: 'My IT Requests', href: '/org/cmp/employee/it-management/my-it-requests' }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Licenses</h1>
        <p className="text-xs text-muted-foreground">Manage your software licenses and subscriptions</p>
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
