import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Clock, Calendar, MapPin } from 'lucide-react';

export default function MyPlanner() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Time & Attendance
    registerSubmodules('Time & Attendance', [
      { id: 'my-clock', label: 'My Clock', href: '/org/cmp/employee/time-and-attendance/my-clock', icon: Clock },
      { id: 'my-planner', label: 'My Planner', href: '/org/cmp/employee/time-and-attendance/my-planner', icon: Calendar },
      { id: 'my-attendance', label: 'My Attendance', href: '/org/cmp/employee/time-and-attendance/my-attendance', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Planner</h1>
        <p className="text-xs text-muted-foreground">Plan and schedule your time and attendance</p>
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
