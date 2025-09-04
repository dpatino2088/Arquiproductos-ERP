import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { useUIStore } from '../../../stores/ui-store';
import { Building2, Users, Shield, UserCheck, FileText, FolderOpen, GraduationCap } from 'lucide-react';

export default function AboutTheCompany() {
  const { registerSubmodules } = useSubmoduleNav();
  const { viewMode } = useUIStore();

  useEffect(() => {
    if (viewMode === 'employee') {
      // Register submodule tabs for Employee Company Knowledge
      registerSubmodules('Company Knowledge', [
        { id: 'about-company', label: 'About the Company', href: '/cmp/about-the-company', icon: Building2 },
        { id: 'my-responsibility', label: 'My Responsibility', href: '/employee/company-knowledge/my-responsibility', icon: UserCheck },
        { id: 'processes-policies', label: 'Processes & Policies', href: '/employee/company-knowledge/processes-and-policies', icon: FileText },
        { id: 'courses-training', label: 'Courses & Training', href: '/employee/company-knowledge/courses-and-training', icon: GraduationCap },
        { id: 'documents-files', label: 'Documents & Files', href: '/employee/company-knowledge/documents-and-files', icon: FolderOpen }
      ]);
    } else {
      // Register submodule tabs for Management Company Knowledge
      registerSubmodules('Company Knowledge', [
        { id: 'about-company', label: 'About the Company', href: '/cmp/about-the-company', icon: Building2 },
        { id: 'team-responsibilities', label: 'Team Responsibilities', href: '/management/company-knowledge/team-responsibilities', icon: Users },
        { id: 'team-knowledge-compliance', label: 'Team Knowledge Compliance', href: '/management/company-knowledge/team-knowledge-compliance', icon: Shield }
      ]);
    }
  }, [registerSubmodules, viewMode]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">About the Company</h1>
        <p className="text-xs text-muted-foreground">Company information, mission, values, and organizational details</p>
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
