import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Clock, 
  Calendar, 
  ChevronLeft, 
  ChevronRight,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Clock as ClockIcon,
  ArrowLeft,
  User,
  MapPin,
  Building
} from 'lucide-react';
import { router } from '../../../../../lib/router';

interface TimeEntry {
  id: string;
  clockIn: string;
  clockOut: string | null;
  project: string;
  activity: string;
  hours: number;
  notes?: string;
}

interface DailyAttendance {
  date: string;
  timeEntries: TimeEntry[];
  totalHours: number;
  status: 'present' | 'absent' | 'late' | 'partial' | 'on-break' | 'on-leave';
  location: string;
  notes?: string;
}

interface Employee {
  id: string;
  employeeId: string;
  employeeName: string;
  role: string;
  department: string;
  email: string;
  location: string;
  avatar?: string;
}

export default function EmployeeAttendance() {
  const { setBreadcrumbs, clearSubmoduleNav } = useSubmoduleNav();
  const [currentWeek, setCurrentWeek] = useState(new Date());
  const [employee, setEmployee] = useState<Employee | null>(null);
  const [weeklyAttendance, setWeeklyAttendance] = useState<DailyAttendance[]>([]);

  useEffect(() => {
    // Clear submodule navigation and set breadcrumbs
    clearSubmoduleNav();
    
    // Load employee data from sessionStorage
    const selectedEmployeeData = sessionStorage.getItem('selectedEmployee');
    if (selectedEmployeeData) {
      try {
        const parsedEmployee = JSON.parse(selectedEmployeeData);
        const mappedEmployee: Employee = {
          id: parsedEmployee.id,
          employeeId: parsedEmployee.employeeId,
          employeeName: parsedEmployee.employeeName,
          role: parsedEmployee.role,
          department: parsedEmployee.department,
          email: parsedEmployee.email || `${parsedEmployee.employeeName.toLowerCase().replace(' ', '.')}@company.com`,
          location: parsedEmployee.location || 'Office'
        };
        setEmployee(mappedEmployee);
        
        // Set breadcrumbs
        const slug = mappedEmployee.employeeName.toLowerCase().replace(/\s+/g, '-');
        setBreadcrumbs([
          { label: 'Time & Attendance' },
          { label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance' },
          { label: mappedEmployee.employeeName }
        ]);
      } catch (error) {
        console.error('Error parsing employee data:', error);
        // Fallback employee data
        const fallbackEmployee: Employee = {
          id: '1',
          employeeId: '1',
          employeeName: 'John Doe',
          role: 'Software Developer',
          department: 'Engineering',
          email: 'john.doe@company.com',
          location: 'Office'
        };
        setEmployee(fallbackEmployee);
        setBreadcrumbs([
          { label: 'Time & Attendance' },
          { label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance' },
          { label: 'John Doe' }
        ]);
      }
    }
  }, [setBreadcrumbs, clearSubmoduleNav]);

  // Generate weekly attendance data
  useEffect(() => {
    if (employee) {
      const weekData = generateWeeklyAttendance(employee, currentWeek);
      setWeeklyAttendance(weekData);
    }
  }, [employee, currentWeek]);

  const generateWeeklyAttendance = (emp: Employee, weekStart: Date): DailyAttendance[] => {
    const weekDates = getWeekDates(weekStart);
    const mockData: DailyAttendance[] = [];

    weekDates.forEach((date, index) => {
      const dayOfWeek = date.getDay();
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
      
      if (isWeekend) {
        mockData.push({
          date: date.toISOString().split('T')[0],
          timeEntries: [],
          totalHours: 0,
          status: 'on-leave',
          location: emp.location,
          notes: 'Weekend'
        });
      } else {
        // Generate mock time entries for weekdays
        const timeEntries: TimeEntry[] = [];
        let totalHours = 0;
        let status: DailyAttendance['status'] = 'present';

        // Randomly generate 1-3 time entries per day
        const numEntries = Math.floor(Math.random() * 3) + 1;
        const projects = ['Project Alpha', 'Project Beta', 'Project Gamma', 'Project Delta'];
        const activities = ['Development', 'Code Review', 'Team Meeting', 'Client Call', 'Documentation', 'Testing'];

        for (let i = 0; i < numEntries; i++) {
          const clockIn = `${8 + Math.floor(Math.random() * 2)}:${Math.floor(Math.random() * 60).toString().padStart(2, '0')}`;
          const hours = 2 + Math.random() * 4; // 2-6 hours per entry
          const clockOut = `${parseInt(clockIn.split(':')[0]) + Math.floor(hours)}:${Math.floor((hours % 1) * 60).toString().padStart(2, '0')}`;
          
          timeEntries.push({
            id: `${emp.id}-${date.toISOString().split('T')[0]}-${i}`,
            clockIn,
            clockOut,
            project: projects[Math.floor(Math.random() * projects.length)],
            activity: activities[Math.floor(Math.random() * activities.length)],
            hours: Math.round(hours * 100) / 100,
            notes: `Entry ${i + 1} for ${date.toLocaleDateString()}`
          });
          
          totalHours += hours;
        }

        // Determine status based on total hours
        if (totalHours === 0) {
          status = 'absent';
        } else if (totalHours < 6) {
          status = 'partial';
        } else if (timeEntries[0]?.clockIn && parseInt(timeEntries[0].clockIn.split(':')[0]) > 9) {
          status = 'late';
        }

        mockData.push({
          date: date.toISOString().split('T')[0],
          timeEntries,
          totalHours: Math.round(totalHours * 100) / 100,
          status,
          location: emp.location,
          notes: `${numEntries} time entries`
        });
      }
    });

    return mockData;
  };

  const getWeekDates = (date: Date): Date[] => {
    const weekDates: Date[] = [];
    const startOfWeek = new Date(date);
    const day = startOfWeek.getDay();
    const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
    startOfWeek.setDate(diff);
    
    for (let i = 0; i < 7; i++) {
      const weekDate = new Date(startOfWeek);
      weekDate.setDate(startOfWeek.getDate() + i);
      weekDates.push(weekDate);
    }
    
    return weekDates;
  };

  const navigateWeek = (direction: 'prev' | 'next') => {
    const newWeek = new Date(currentWeek);
    newWeek.setDate(currentWeek.getDate() + (direction === 'next' ? 7 : -7));
    setCurrentWeek(newWeek);
  };

  const goToCurrentWeek = () => {
    setCurrentWeek(new Date());
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'present':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-status-green-light text-status-green">
            Present
          </span>
        );
      case 'absent':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-status-red-light text-status-red">
            Absent
          </span>
        );
      case 'late':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-status-orange-light text-status-orange">
            Late
          </span>
        );
      case 'partial':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-status-blue-light text-status-blue">
            Partial
          </span>
        );
      case 'on-break':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-status-purple-light text-status-purple">
            On Break
          </span>
        );
      case 'on-leave':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-neutral-gray text-white">
            On Leave
          </span>
        );
      default:
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-neutral-gray text-white">
            Unknown
          </span>
        );
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'present':
        return <CheckCircle className="w-4 h-4 text-status-green" />;
      case 'absent':
        return <XCircle className="w-4 h-4 text-status-red" />;
      case 'late':
        return <AlertTriangle className="w-4 h-4 text-status-orange" />;
      case 'partial':
        return <ClockIcon className="w-4 h-4 text-status-blue" />;
      case 'on-break':
        return <ClockIcon className="w-4 h-4 text-status-purple" />;
      default:
        return <ClockIcon className="w-4 h-4 text-neutral-gray" />;
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      weekday: 'short', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  const getWeekRange = () => {
    const weekDates = getWeekDates(currentWeek);
    const startDate = weekDates[0];
    const endDate = weekDates[6];
    return `${startDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${endDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
  };

  const totalWeeklyHours = useMemo(() => {
    return weeklyAttendance.reduce((sum, day) => sum + day.totalHours, 0);
  }, [weeklyAttendance]);

  const handleBackToTeamAttendance = () => {
    router.navigate('/org/cmp/management/time-and-attendance/team-attendance');
  };

  if (!employee) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Loading...</h2>
            <p className="text-muted-foreground">Loading employee data</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <div className="flex items-center gap-4 mb-4">
          <button
            onClick={handleBackToTeamAttendance}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            aria-label="Back to Team Attendance"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">
              {employee.employeeName} - Attendance
            </h1>
            <p className="text-xs text-muted-foreground">Weekly attendance overview</p>
          </div>
        </div>

        {/* Employee Info Card */}
        <div className="bg-white border border-gray-200 rounded-lg p-4 mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-primary rounded-full flex items-center justify-center text-white text-lg font-medium">
              {employee.employeeName.split(' ').map(n => n[0]).join('')}
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-4 mb-2">
                <h2 className="text-lg font-semibold text-gray-900">{employee.employeeName}</h2>
                {getStatusBadge(weeklyAttendance.length > 0 ? weeklyAttendance[0].status : 'present')}
              </div>
              <div className="flex items-center gap-6 text-sm text-gray-600">
                <div className="flex items-center gap-1">
                  <User className="w-4 h-4" />
                  <span>{employee.role}</span>
                </div>
                <div className="flex items-center gap-1">
                  <Building className="w-4 h-4" />
                  <span>{employee.department}</span>
                </div>
                <div className="flex items-center gap-1">
                  <MapPin className="w-4 h-4" />
                  <span>{employee.location}</span>
                </div>
              </div>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-primary">{totalWeeklyHours.toFixed(1)}h</div>
              <div className="text-sm text-gray-500">This Week</div>
            </div>
          </div>
        </div>
      </div>

      {/* Week Navigation */}
      <div className="bg-white border border-gray-200 rounded-lg p-4 mb-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigateWeek('prev')}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              aria-label="Previous week"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <div className="text-center">
              <h3 className="text-lg font-semibold text-gray-900">{getWeekRange()}</h3>
              <p className="text-sm text-gray-500">Week of {currentWeek.toLocaleDateString('en-US', { month: 'long', day: 'numeric' })}</p>
            </div>
            <button
              onClick={() => navigateWeek('next')}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              aria-label="Next week"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
          <button
            onClick={goToCurrentWeek}
            className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            aria-label="Go to current week"
          >
            This Week
          </button>
        </div>
      </div>

      {/* Weekly Attendance */}
      <div className="space-y-4">
        {weeklyAttendance.map((day) => (
          <div key={day.date} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
            {/* Day Header */}
            <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Calendar className="w-5 h-5 text-gray-500" />
                  <div>
                    <h4 className="font-medium text-gray-900">{formatDate(day.date)}</h4>
                    <p className="text-sm text-gray-500">{day.location}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <div className="text-lg font-semibold text-gray-900">{day.totalHours}h</div>
                    <div className="text-sm text-gray-500">Total</div>
                  </div>
                  <div className="flex items-center gap-2">
                    {getStatusIcon(day.status)}
                    {getStatusBadge(day.status)}
                  </div>
                </div>
              </div>
            </div>

            {/* Time Entries */}
            <div className="overflow-x-auto">
              {day.timeEntries.length > 0 ? (
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-200">
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Entry</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Project</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Clock In</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Clock Out</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Hours</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Activity</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {day.timeEntries.map((entry, index) => (
                      <tr key={entry.id} className="border-b border-gray-100 last:border-b-0">
                        <td className="py-2 px-6">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center text-gray-600 text-xs font-medium">
                              {index + 1}
                            </div>
                            <div className="text-sm text-gray-600">Time Entry</div>
                          </div>
                        </td>
                        <td className="py-2 px-4">
                          <span className="text-sm text-gray-900">{entry.project}</span>
                        </td>
                        <td className="py-2 px-4">
                          <span className="text-sm text-gray-900">{entry.clockIn}</span>
                        </td>
                        <td className="py-2 px-4">
                          <span className="text-sm text-gray-900">{entry.clockOut || 'In Progress'}</span>
                        </td>
                        <td className="py-2 px-4">
                          <span className="text-sm font-medium text-gray-900">{entry.hours}h</span>
                        </td>
                        <td className="py-2 px-4">
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
                            {entry.activity}
                          </span>
                        </td>
                        <td className="py-2 px-4">
                          {entry.notes ? (
                            <button
                              className="p-1 hover:bg-gray-100 rounded transition-colors"
                              aria-label={`View notes for ${entry.project}`}
                              title={entry.notes}
                            >
                              <Clock className="w-4 h-4 text-gray-500" />
                            </button>
                          ) : (
                            <span className="text-sm text-gray-400">-</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="text-center py-8">
                  <Clock className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                  <p className="text-gray-500">No time entries for this day</p>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
