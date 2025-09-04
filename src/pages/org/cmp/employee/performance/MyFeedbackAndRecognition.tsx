import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { ChartNoAxesCombined, MessageSquare, Users } from 'lucide-react';

export default function MyFeedbackAndRecognition() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Performance
    registerSubmodules('Performance', [
      { id: 'my-performance', label: 'My Performance', href: '/employee/performance/my-performance', icon: ChartNoAxesCombined },
      { id: 'my-feedback-recognition', label: 'My Feedback & Recognition', href: '/employee/performance/my-feedback-and-recognition', icon: MessageSquare },
      { id: 'my-one-on-one', label: 'My One-on-One', href: '/employee/performance/my-one-on-one', icon: Users }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Feedback & Recognition</h1>
        <p className="text-xs text-muted-foreground">View feedback received and recognition earned</p>
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
