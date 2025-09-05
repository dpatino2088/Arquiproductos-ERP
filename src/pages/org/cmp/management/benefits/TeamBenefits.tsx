import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { BriefcaseBusiness, FileText } from 'lucide-react';

export default function TeamBenefits() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Benefits
    registerSubmodules('Benefits', [
      { id: 'team-benefits', label: 'Team Benefits', href: '/org/cmp/management/benefits/team-benefits', icon: BriefcaseBusiness },
      { id: 'team-requests', label: 'Team Requests', href: '/org/cmp/management/benefits/team-requests', icon: FileText }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Benefits</h1>
        <p className="text-xs text-muted-foreground">Manage and oversee team benefits and compensation</p>
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
