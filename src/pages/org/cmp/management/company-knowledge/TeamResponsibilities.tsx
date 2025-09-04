import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Building2, Users, Shield } from 'lucide-react';

export default function TeamResponsibilities() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Company Knowledge
    registerSubmodules('Company Knowledge', [
      { id: 'about-company', label: 'About the Company', href: '/cmp/about-the-company', icon: Building2 },
      { id: 'team-responsibilities', label: 'Team Responsibilities', href: '/management/company-knowledge/team-responsibilities', icon: Users },
      { id: 'team-knowledge-compliance', label: 'Team Knowledge Compliance', href: '/management/company-knowledge/team-knowledge-compliance', icon: Shield }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Responsibilities</h1>
        <p className="text-xs text-muted-foreground">Define and manage team roles and responsibilities</p>
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
