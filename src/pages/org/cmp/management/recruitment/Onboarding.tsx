import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';

export default function Onboarding() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Recruitment', [
      { id: 'job-openings', label: 'Job Openings', href: '/org/cmp/management/recruitment/job-openings' },
      { id: 'candidates', label: 'Candidates', href: '/org/cmp/management/recruitment/candidates' },
      { id: 'onboarding', label: 'Onboarding', href: '/org/cmp/management/recruitment/onboarding' }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Onboarding</h1>
        <p className="text-xs text-muted-foreground">Manage new hire onboarding processes and documentation</p>
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
