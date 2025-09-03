import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Clock, Calendar, MapPin } from 'lucide-react';

export default function Geolocation() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for time and attendance
    registerSubmodules('Time & Attendance', [
      { id: 'planner', label: 'Planner', href: '/management/time-and-attendance/planner', icon: Calendar },
      { id: 'attendance', label: 'Attendance', href: '/management/time-and-attendance/attendance', icon: Clock },
      { id: 'geolocation', label: 'Geolocation', href: '/management/time-and-attendance/geolocation', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Geolocation</h1>
        <p className="text-xs text-muted-foreground">Track employee location and geofencing</p>
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
