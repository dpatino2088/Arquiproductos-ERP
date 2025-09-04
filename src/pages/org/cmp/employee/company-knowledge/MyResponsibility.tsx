import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Building2, UserCheck, FileText, FolderOpen, GraduationCap } from 'lucide-react';

export default function MyResponsibility() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Company Knowledge
    registerSubmodules('Company Knowledge', [
      { id: 'about-company', label: 'About the Company', href: '/cmp/about-the-company', icon: Building2 },
      { id: 'my-responsibility', label: 'My Responsibility', href: '/employee/company-knowledge/my-responsibility', icon: UserCheck },
      { id: 'processes-policies', label: 'Processes & Policies', href: '/employee/company-knowledge/processes-and-policies', icon: FileText },
      { id: 'courses-training', label: 'Courses & Training', href: '/employee/company-knowledge/courses-and-training', icon: GraduationCap },
      { id: 'documents-files', label: 'Documents & Files', href: '/employee/company-knowledge/documents-and-files', icon: FolderOpen }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Responsibility</h1>
        <p className="text-xs text-muted-foreground">View your specific responsibilities and role within the company</p>
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
