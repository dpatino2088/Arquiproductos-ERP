import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Target, FileText, Award, Users } from 'lucide-react';

export default function TeamReviews() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Performance
    registerSubmodules('Performance', [
      { id: 'team-goals', label: 'Team Goals & Performance', href: '/org/cmp/management/performance/team-goals-and-performance', icon: Target },
      { id: 'team-reviews', label: 'Team Reviews', href: '/org/cmp/management/performance/team-reviews', icon: FileText },
      { id: 'team-feedback', label: 'Team Feedback & Recognition', href: '/org/cmp/management/performance/team-feedback-and-recognition', icon: Award },
      { id: 'team-one-on-one', label: 'Team One-on-One', href: '/org/cmp/management/performance/team-one-on-one', icon: Users }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Reviews</h1>
        <p className="text-xs text-muted-foreground">Conduct and manage team performance reviews</p>
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
