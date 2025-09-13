import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Clock, 
  Calendar, 
  MapPin, 
  Users, 
  Plus, 
  Filter, 
  Search, 
  ChevronLeft, 
  ChevronRight,
  Settings,
  AlertTriangle,
  CheckCircle,
  User,
  MoreVertical,
  Edit,
  Trash2,
  Copy,
  Eye
} from 'lucide-react';

interface Employee {
  id: string;
  name: string;
  role: string;
  department: string;
  avatar?: string;
  availability: {
    monday: string[];
    tuesday: string[];
    wednesday: string[];
    thursday: string[];
    friday: string[];
    saturday: string[];
    sunday: string[];
  };
  qualifications: string[];
  hourlyRate: number;
  maxHoursPerWeek: number;
}

interface Shift {
  id: string;
  employeeId: string;
  date: string;
  startTime: string;
  endTime: string;
  role: string;
  location: string;
  status: 'scheduled' | 'confirmed' | 'completed' | 'cancelled';
  notes?: string;
}

export default function TeamPlanner() {
  const { registerSubmodules } = useSubmoduleNav();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [viewMode, setViewMode] = useState<'week' | 'month'>('week');
  const [selectedEmployee, setSelectedEmployee] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [showCreateShift, setShowCreateShift] = useState(false);

  useEffect(() => {
    // Register submodule tabs for time and attendance
    registerSubmodules('Time & Attendance', [
      { id: 'team-planner', label: 'Team Planner', href: '/org/cmp/management/time-and-attendance/team-planner', icon: Calendar },
      { id: 'team-attendance', label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance', icon: Clock },
      { id: 'team-geolocation', label: 'Team Geolocation', href: '/org/cmp/management/time-and-attendance/team-geolocation', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  // Mock data
  const employees: Employee[] = [
    {
      id: '1',
      name: 'Sarah Johnson',
      role: 'Senior Developer',
      department: 'Engineering',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['JavaScript', 'React', 'Node.js'],
      hourlyRate: 75,
      maxHoursPerWeek: 40
    },
    {
      id: '2',
      name: 'Mike Chen',
      role: 'UX Designer',
      department: 'Design',
      availability: {
        monday: ['08:00', '17:00'],
        tuesday: ['08:00', '17:00'],
        wednesday: ['08:00', '17:00'],
        thursday: ['08:00', '17:00'],
        friday: ['08:00', '16:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Figma', 'Sketch', 'Adobe Creative Suite'],
      hourlyRate: 65,
      maxHoursPerWeek: 40
    },
    {
      id: '3',
      name: 'Alex Rodriguez',
      role: 'Project Manager',
      department: 'Management',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Agile', 'Scrum', 'Project Management'],
      hourlyRate: 85,
      maxHoursPerWeek: 40
    }
  ];

  const shifts: Shift[] = [
    {
      id: '1',
      employeeId: '1',
      date: '2025-01-20',
      startTime: '09:00',
      endTime: '17:00',
      role: 'Senior Developer',
      location: 'Office',
      status: 'scheduled'
    },
    {
      id: '2',
      employeeId: '2',
      date: '2025-01-20',
      startTime: '08:00',
      endTime: '16:00',
      role: 'UX Designer',
      location: 'Office',
      status: 'confirmed'
    }
  ];

  const filteredEmployees = useMemo(() => {
    return employees.filter(employee =>
      employee.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      employee.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
      employee.department.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [employees, searchTerm]);

  const getWeekDates = (date: Date) => {
    const start = new Date(date);
    const day = start.getDay();
    const diff = start.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
    start.setDate(diff);
    
    const week = [];
    for (let i = 0; i < 7; i++) {
      const day = new Date(start);
      day.setDate(start.getDate() + i);
      week.push(day);
    }
    return week;
  };

  const weekDates = getWeekDates(currentDate);

  const navigateWeek = (direction: 'prev' | 'next') => {
    const newDate = new Date(currentDate);
    newDate.setDate(currentDate.getDate() + (direction === 'next' ? 7 : -7));
    setCurrentDate(newDate);
  };

  const getShiftsForDate = (date: Date) => {
    const dateStr = date.toISOString().split('T')[0];
    return shifts.filter(shift => shift.date === dateStr);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'scheduled': return 'bg-blue-50 text-status-blue';
      case 'confirmed': return 'bg-green-50 text-status-green';
      case 'completed': return 'bg-green-50 text-status-green';
      case 'cancelled': return 'bg-red-50 text-status-red';
      default: return 'bg-gray-50 text-status-gray';
    }
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Team Planner</h1>
          <p className="text-xs text-muted-foreground">Schedule and manage team shifts efficiently</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors"
            onClick={() => setShowFilters(!showFilters)}
            aria-label="Toggle filters"
          >
            <Filter className="w-4 h-4 inline mr-1" />
            Filters
          </button>
          <button
            className="px-3 py-1 rounded text-white text-sm transition-colors"
            style={{ backgroundColor: '#008383' }}
            onClick={() => setShowCreateShift(true)}
            aria-label="Create new shift"
          >
            <Plus className="w-4 h-4 inline mr-1" />
            Create Shift
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Users className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">{employees.length}</div>
              <div className="text-sm text-muted-foreground">Total Employees</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Calendar className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">{shifts.length}</div>
              <div className="text-sm text-muted-foreground">Scheduled Shifts</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">
                {shifts.filter(s => s.status === 'confirmed').length}
              </div>
              <div className="text-sm text-muted-foreground">Confirmed</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-amber" />
            <div>
              <div className="text-2xl font-bold">0</div>
              <div className="text-sm text-muted-foreground">Conflicts</div>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search employees, roles, or departments..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search employees"
              />
            </div>
            <div className="flex items-center gap-2">
              <button
                className={`px-3 py-1 rounded text-sm transition-colors ${
                  viewMode === 'week' 
                    ? 'text-white' 
                    : 'border border-gray-300 hover:bg-gray-50'
                }`}
                style={{ backgroundColor: viewMode === 'week' ? '#008383' : 'transparent' }}
                onClick={() => setViewMode('week')}
                aria-label="Week view"
              >
                Week
              </button>
              <button
                className={`px-3 py-1 rounded text-sm transition-colors ${
                  viewMode === 'month' 
                    ? 'text-white' 
                    : 'border border-gray-300 hover:bg-gray-50'
                }`}
                style={{ backgroundColor: viewMode === 'month' ? '#008383' : 'transparent' }}
                onClick={() => setViewMode('month')}
                aria-label="Month view"
              >
                Month
              </button>
            </div>
          </div>
        </div>
        
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Department</label>
                <select className="w-full px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50">
                  <option>All Departments</option>
                  <option>Engineering</option>
                  <option>Design</option>
                  <option>Management</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
                <select className="w-full px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50">
                  <option>All Roles</option>
                  <option>Senior Developer</option>
                  <option>UX Designer</option>
                  <option>Project Manager</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select className="w-full px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50">
                  <option>All Status</option>
                  <option>Available</option>
                  <option>Scheduled</option>
                  <option>On Leave</option>
                </select>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Calendar Header */}
      <div className="bg-white border border-gray-200 rounded-lg mb-4">
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigateWeek('prev')}
              className="p-1 hover:bg-gray-100 rounded transition-colors"
              aria-label="Previous week"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <h2 className="text-lg font-semibold">
              {currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
            </h2>
            <button
              onClick={() => navigateWeek('next')}
              className="p-1 hover:bg-gray-100 rounded transition-colors"
              aria-label="Next week"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
          <button
            onClick={() => setCurrentDate(new Date())}
            className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors"
            aria-label="Go to current week"
          >
            Today
          </button>
        </div>

        {/* Week View */}
        {viewMode === 'week' && (
          <div className="grid grid-cols-8">
            {/* Employee Column Header */}
            <div className="p-3 border-r border-gray-200 bg-gray-50">
              <span className="text-sm font-medium text-gray-700">Employee</span>
            </div>
            
            {/* Day Headers */}
            {weekDates.map((date, index) => (
              <div key={index} className="p-3 border-r border-gray-200 bg-gray-50 text-center">
                <div className="text-sm font-medium text-gray-700">
                  {date.toLocaleDateString('en-US', { weekday: 'short' })}
                </div>
                <div className="text-xs text-gray-500">
                  {date.getDate()}
                </div>
              </div>
            ))}
            
            {/* Employee Rows */}
            {filteredEmployees.map((employee) => (
              <div key={employee.id} className="contents">
                {/* Employee Info */}
                <div className="p-3 border-r border-b border-gray-200 flex items-center gap-3">
                  <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                    {employee.name.split(' ').map(n => n[0]).join('')}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-gray-900 truncate">
                      {employee.name}
                    </div>
                    <div className="text-xs text-gray-500 truncate">
                      {employee.role}
                    </div>
                  </div>
                </div>
                
                {/* Day Cells */}
                {weekDates.map((date, dayIndex) => {
                  const dayShifts = getShiftsForDate(date).filter(shift => shift.employeeId === employee.id);
                  return (
                    <div key={dayIndex} className="p-2 border-r border-b border-gray-200 min-h-[60px]">
                      {dayShifts.map((shift) => (
                        <div
                          key={shift.id}
                          className={`p-2 rounded text-xs mb-1 cursor-pointer hover:shadow-sm transition-shadow ${getStatusColor(shift.status)}`}
                          onClick={() => setSelectedEmployee(employee.id)}
                        >
                          <div className="font-medium">{shift.startTime} - {shift.endTime}</div>
                          <div className="text-xs opacity-75">{shift.role}</div>
                        </div>
                      ))}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Employee List */}
      <div className="bg-white border border-gray-200 rounded-lg">
        <div className="p-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold">Team Members</h3>
        </div>
        <div className="divide-y divide-gray-200">
          {filteredEmployees.map((employee) => (
            <div key={employee.id} className="p-4 hover:bg-gray-50 transition-colors">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-primary rounded-full flex items-center justify-center text-white font-medium">
                    {employee.name.split(' ').map(n => n[0]).join('')}
                  </div>
                  <div>
                    <div className="font-medium text-gray-900">{employee.name}</div>
                    <div className="text-sm text-gray-500">{employee.role} • {employee.department}</div>
                    <div className="text-xs text-gray-400">
                      ${employee.hourlyRate}/hr • Max {employee.maxHoursPerWeek}h/week
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`View ${employee.name} details`}
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`Edit ${employee.name}`}
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`More options for ${employee.name}`}
                  >
                    <MoreVertical className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
