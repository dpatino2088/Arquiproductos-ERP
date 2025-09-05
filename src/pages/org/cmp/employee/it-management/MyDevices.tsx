import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Cpu, Smartphone, Laptop, Monitor } from 'lucide-react';

export default function MyDevices() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for IT Management
    registerSubmodules('IT Management', [
      { id: 'my-devices', label: 'My Devices', href: '/org/cmp/employee/it-management/my-devices', icon: Cpu },
      { id: 'my-licenses', label: 'My Licenses', href: '/org/cmp/employee/it-management/my-licenses', icon: Smartphone },
      { id: 'my-it-requests', label: 'My IT Requests', href: '/org/cmp/employee/it-management/my-it-requests', icon: Laptop }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Devices</h1>
        <p className="text-xs text-muted-foreground">Manage your assigned devices and hardware</p>
      </div>
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="mb-4">
            <Monitor className="w-16 h-16 text-muted-foreground mx-auto" />
          </div>
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}
