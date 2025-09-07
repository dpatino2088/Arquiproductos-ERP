import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Building2, UserCheck, FileText, FolderOpen, GraduationCap } from 'lucide-react';

export default function CoursesAndTraining() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Company Knowledge
    registerSubmodules('Company Knowledge', [
      { id: 'about-company', label: 'About the Company', href: '/org/cmp/employee/company-knowledge/about-the-company', icon: Building2 },
      { id: 'my-responsibility', label: 'My Responsibility', href: '/org/cmp/employee/company-knowledge/my-responsibility', icon: UserCheck },
      { id: 'processes-policies', label: 'Processes & Policies', href: '/org/cmp/employee/company-knowledge/processes-and-policies', icon: FileText },
      { id: 'courses-training', label: 'Courses & Training', href: '/org/cmp/employee/company-knowledge/courses-and-training', icon: GraduationCap },
      { id: 'documents-files', label: 'Documents & Files', href: '/org/cmp/employee/company-knowledge/documents-and-files', icon: FolderOpen }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Courses & Training</h1>
        <p className="text-xs text-muted-foreground">Access training courses and educational resources</p>
      </div>

      {/* Content */}
      <div className="flex items-center justify-center min-h-[4000px]">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}
