import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Monitor, Key, FileText } from 'lucide-react';

export default function TeamRequests() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for IT Management
    registerSubmodules('IT Management', [
      { id: 'team-devices', label: 'Team Devices', href: '/org/cmp/management/it-management/team-devices', icon: Monitor },
      { id: 'team-licenses', label: 'Team Licenses', href: '/org/cmp/management/it-management/team-licenses', icon: Key },
      { id: 'team-requests', label: 'Team Requests', href: '/org/cmp/management/it-management/team-requests', icon: FileText }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Requests</h1>
        <p className="text-xs text-muted-foreground">Review and manage IT support requests</p>
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
