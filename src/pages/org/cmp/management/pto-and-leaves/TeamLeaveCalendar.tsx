import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Users, 
  Calendar, 
  Search, 
  Filter,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Clock,
  MapPin,
  Building,
  Eye,
  Plus,
  CalendarDays,
  User,
  Plane,
  Heart,
  Coffee,
  FileText
} from 'lucide-react';

interface LeaveRequest {
  id: string;
  employeeId: string;
  employeeName: string;
  jobTitle: string;
  department: string;
  location: string;
  leaveType: 'Vacation' | 'Sick Leave' | 'Personal Day' | 'Maternity/Paternity' | 'Bereavement' | 'Other';
  startDate: string;
  endDate: string;
  totalDays: number;
  status: 'Pending' | 'Approved' | 'Rejected' | 'Cancelled';
  reason: string;
  avatar?: string;
}

interface Conflict {
  date: string;
  department: string;
  location: string;
  affectedEmployees: string[];
  severity: 'low' | 'medium' | 'high';
  type: 'department' | 'location' | 'both';
}

// Function to generate avatar initials (100% reliable, works everywhere)
const generateAvatarInitials = (firstName: string, lastName: string) => {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
};

// Function to generate a consistent background color based on name
// Using WCAG 2.2 AA compliant colors (4.5:1 contrast ratio with white text)
const generateAvatarColor = (firstName: string, lastName: string) => {
  const colors = [
    '#008383', '#1976D2', '#D32F2F', '#E65100', '#7B1FA2',
    '#00695C', '#2E7D32', '#E65100', '#C2185B', '#455A64',
    '#5D4037', '#37474F', '#BF360C', '#1A237E', '#4A148C'
  ];
  const name = firstName + lastName;
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return colors[Math.abs(hash) % colors.length];
};

const getStatusBadge = (status: string) => {
  switch (status) {
    case 'Pending':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          Pending
        </span>
      );
    case 'Approved':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
          Approved
        </span>
      );
    case 'Rejected':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
          Rejected
        </span>
      );
    case 'Cancelled':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          Cancelled
        </span>
      );
    default:
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          {status}
        </span>
      );
  }
};

const getLeaveTypeIcon = (leaveType: string) => {
  const iconConfig = {
    'Vacation': { icon: Plane, color: 'text-status-blue' },
    'Sick Leave': { icon: Heart, color: 'text-status-red' },
    'Personal Day': { icon: Coffee, color: 'text-status-purple' },
    'Maternity/Paternity': { icon: User, color: 'text-status-purple' },
    'Bereavement': { icon: Heart, color: 'text-status-red' },
    'Other': { icon: FileText, color: 'text-status-gray' }
  };
  
  const config = iconConfig[leaveType as keyof typeof iconConfig] || iconConfig['Other'];
  const IconComponent = config.icon;
  
  return <IconComponent className={`w-4 h-4 ${config.color}`} />;
};

const getLeaveTypeBadge = (leaveType: string) => {
  const typeConfig = {
    'Vacation': { bg: 'bg-blue-50', text: 'text-status-blue', border: 'border-blue-200' },
    'Sick Leave': { bg: 'bg-red-50', text: 'text-status-red', border: 'border-red-200' },
    'Personal Day': { bg: 'bg-purple-50', text: 'text-status-purple', border: 'border-purple-200' },
    'Maternity/Paternity': { bg: 'bg-purple-50', text: 'text-status-purple', border: 'border-purple-200' },
    'Bereavement': { bg: 'bg-red-50', text: 'text-status-red', border: 'border-red-200' },
    'Other': { bg: 'bg-gray-50', text: 'text-status-gray', border: 'border-gray-200' }
  };
  
  const config = typeConfig[leaveType as keyof typeof typeConfig] || typeConfig['Other'];
  
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${config.bg} ${config.text} ${config.border}`}>
      {getLeaveTypeIcon(leaveType)}
      {leaveType}
    </span>
  );
};

const getConflictSeverityBadge = (severity: string) => {
  switch (severity) {
    case 'high':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
          High Risk
        </span>
      );
    case 'medium':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          Medium Risk
        </span>
      );
    case 'low':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
          Low Risk
        </span>
      );
    default:
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          {severity}
        </span>
      );
  }
};

export default function TeamLeaveCalendar() {
  const { registerSubmodules } = useSubmoduleNav();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [viewMode, setViewMode] = useState<'month' | 'week'>('month');
  const [selectedDepartment, setSelectedDepartment] = useState<string[]>([]);
  const [selectedLocation, setSelectedLocation] = useState<string[]>([]);
  const [showDepartmentDropdown, setShowDepartmentDropdown] = useState(false);
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  const [departmentSearchTerm, setDepartmentSearchTerm] = useState('');
  const [locationSearchTerm, setLocationSearchTerm] = useState('');
  const [showConflicts, setShowConflicts] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    // Register submodule tabs for PTO and Leaves section
    registerSubmodules('PTO & Leaves', [
      { id: 'calendar', label: 'Team Leave Calendar', href: '/org/cmp/management/pto-and-leaves/team-leave-calendar', icon: Calendar },
      { id: 'team-balances', label: 'Team Balances', href: '/org/cmp/management/pto-and-leaves/team-balances', icon: Users },
      { id: 'requests', label: 'Team Leave Requests', href: '/org/cmp/management/pto-and-leaves/team-leave-requests', icon: Clock }
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowDepartmentDropdown(false);
        setShowLocationDropdown(false);
        // Clear search terms when closing dropdowns
        setDepartmentSearchTerm('');
        setLocationSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Mock data for leave requests
  const leaveRequests: LeaveRequest[] = [
    {
      id: '1',
      employeeId: 'emp-001',
      employeeName: 'Amanda Foster',
      jobTitle: 'Senior UX Designer',
      department: 'Design',
      location: 'San Francisco, CA',
      leaveType: 'Vacation',
      startDate: '2024-01-15',
      endDate: '2024-01-19',
      totalDays: 5,
      status: 'Approved',
      reason: 'Family vacation to Hawaii'
    },
    {
      id: '2',
      employeeId: 'emp-002',
      employeeName: 'Marcus Chen',
      jobTitle: 'Full Stack Developer',
      department: 'Engineering',
      location: 'Austin, TX',
      leaveType: 'Sick Leave',
      startDate: '2024-01-12',
      endDate: '2024-01-12',
      totalDays: 1,
      status: 'Approved',
      reason: 'Flu symptoms'
    },
    {
      id: '3',
      employeeId: 'emp-003',
      employeeName: 'Elena Rodriguez',
      jobTitle: 'Product Manager',
      department: 'Product',
      location: 'Miami, FL',
      leaveType: 'Personal Day',
      startDate: '2024-01-18',
      endDate: '2024-01-18',
      totalDays: 1,
      status: 'Approved',
      reason: 'Personal appointment'
    },
    {
      id: '4',
      employeeId: 'emp-004',
      employeeName: 'James Wilson',
      jobTitle: 'Marketing Specialist',
      department: 'Marketing',
      location: 'Seattle, WA',
      leaveType: 'Maternity/Paternity',
      startDate: '2024-02-01',
      endDate: '2024-04-01',
      totalDays: 60,
      status: 'Approved',
      reason: 'Paternity leave for newborn'
    },
    {
      id: '5',
      employeeId: 'emp-005',
      employeeName: 'Sophie Anderson',
      jobTitle: 'Data Analyst',
      department: 'Analytics',
      location: 'Denver, CO',
      leaveType: 'Vacation',
      startDate: '2024-01-22',
      endDate: '2024-01-26',
      totalDays: 5,
      status: 'Approved',
      reason: 'Ski trip to Colorado'
    },
    {
      id: '6',
      employeeId: 'emp-006',
      employeeName: 'Alex Thompson',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      location: 'Portland, OR',
      leaveType: 'Bereavement',
      startDate: '2024-01-14',
      endDate: '2024-01-16',
      totalDays: 3,
      status: 'Approved',
      reason: 'Funeral arrangements'
    },
    {
      id: '7',
      employeeId: 'emp-007',
      employeeName: 'Maria Garcia',
      jobTitle: 'HR Coordinator',
      department: 'Human Resources',
      location: 'Phoenix, AZ',
      leaveType: 'Sick Leave',
      startDate: '2024-01-16',
      endDate: '2024-01-17',
      totalDays: 2,
      status: 'Approved',
      reason: 'Medical procedure'
    },
    {
      id: '8',
      employeeId: 'emp-008',
      employeeName: 'David Park',
      jobTitle: 'Sales Manager',
      department: 'Sales',
      location: 'Los Angeles, CA',
      leaveType: 'Vacation',
      startDate: '2024-01-25',
      endDate: '2024-01-29',
      totalDays: 5,
      status: 'Approved',
      reason: 'Beach vacation'
    },
    {
      id: '9',
      employeeId: 'emp-009',
      employeeName: 'Rachel Brown',
      jobTitle: 'Content Writer',
      department: 'Marketing',
      location: 'Chicago, IL',
      leaveType: 'Personal Day',
      startDate: '2024-01-19',
      endDate: '2024-01-19',
      totalDays: 1,
      status: 'Approved',
      reason: 'Personal errands'
    },
    {
      id: '10',
      employeeId: 'emp-010',
      employeeName: 'Kevin Lee',
      jobTitle: 'QA Engineer',
      department: 'Engineering',
      location: 'Boston, MA',
      leaveType: 'Other',
      startDate: '2024-01-20',
      endDate: '2024-01-20',
      totalDays: 1,
      status: 'Approved',
      reason: 'Jury duty'
    }
  ];

  // Mock conflicts data
  const conflicts: Conflict[] = [
    {
      date: '2024-01-15',
      department: 'Design',
      location: 'San Francisco, CA',
      affectedEmployees: ['Amanda Foster'],
      severity: 'low',
      type: 'department'
    },
    {
      date: '2024-01-18',
      department: 'Product',
      location: 'Miami, FL',
      affectedEmployees: ['Elena Rodriguez'],
      severity: 'low',
      type: 'location'
    },
    {
      date: '2024-01-22',
      department: 'Analytics',
      location: 'Denver, CO',
      affectedEmployees: ['Sophie Anderson'],
      severity: 'low',
      type: 'both'
    },
    {
      date: '2024-01-25',
      department: 'Sales',
      location: 'Los Angeles, CA',
      affectedEmployees: ['David Park'],
      severity: 'medium',
      type: 'location'
    }
  ];

  const filteredRequests = useMemo(() => {
    return leaveRequests.filter(request => {
      const matchesSearch = 
        request.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.jobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.department.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.location.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesDepartment = selectedDepartment.length === 0 || selectedDepartment.includes(request.department);
      const matchesLocation = selectedLocation.length === 0 || selectedLocation.includes(request.location);
      
      return matchesSearch && matchesDepartment && matchesLocation;
    });
  }, [leaveRequests, searchTerm, selectedDepartment, selectedLocation]);

  // Helper functions for multi-select
  const handleDepartmentToggle = (department: string) => {
    setSelectedDepartment(prev => 
      prev.includes(department) 
        ? prev.filter(d => d !== department)
        : [...prev, department]
    );
  };

  const handleLocationToggle = (location: string) => {
    setSelectedLocation(prev => 
      prev.includes(location) 
        ? prev.filter(l => l !== location)
        : [...prev, location]
    );
  };

  // Filter options based on search terms
  const getFilteredDepartmentOptions = () => {
    const departments = [...new Set(leaveRequests.map(request => request.department))];
    if (!departmentSearchTerm) return departments;
    return departments.filter(dept => 
      dept.toLowerCase().includes(departmentSearchTerm.toLowerCase())
    );
  };

  const getFilteredLocationOptions = () => {
    const locations = [...new Set(leaveRequests.map(request => request.location))];
    if (!locationSearchTerm) return locations;
    return locations.filter(location => 
      location.toLowerCase().includes(locationSearchTerm.toLowerCase())
    );
  };

  // Summary data for cards
  const departments = [...new Set(leaveRequests.map(request => request.department))];
  const locations = [...new Set(leaveRequests.map(request => request.location))];

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate(prev => {
      const newDate = new Date(prev);
      if (direction === 'prev') {
        newDate.setMonth(prev.getMonth() - 1);
      } else {
        newDate.setMonth(prev.getMonth() + 1);
      }
      return newDate;
    });
  };

  const goToToday = () => {
    setCurrentDate(new Date());
  };

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDayOfWeek = firstDay.getDay();
    
    const days = [];
    
    // Add empty cells for days before the first day of the month
    for (let i = 0; i < startingDayOfWeek; i++) {
      days.push(null);
    }
    
    // Add days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      days.push(new Date(year, month, day));
    }
    
    return days;
  };

  const getRequestsForDate = (date: Date) => {
    const dateStr = date.toISOString().split('T')[0];
    return filteredRequests.filter(request => {
      const startDate = new Date(request.startDate);
      const endDate = new Date(request.endDate);
      return date >= startDate && date <= endDate;
    });
  };

  const getConflictsForDate = (date: Date) => {
    const dateStr = date.toISOString().split('T')[0];
    return conflicts.filter(conflict => conflict.date === dateStr);
  };

  const days = getDaysInMonth(currentDate);
  const monthName = currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Leave Calendar</h1>
        <p className="text-xs text-muted-foreground">Monitor leave schedules and identify potential conflicts</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Calendar className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">{filteredRequests.length}</div>
              <div className="text-sm text-muted-foreground">Total Requests</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">{conflicts.filter(c => c.severity === 'high').length}</div>
              <div className="text-sm text-muted-foreground">High Risk Conflicts</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Building className="h-5 w-5 text-status-blue" />
            <div>
              <div className="text-2xl font-bold">{departments.length}</div>
              <div className="text-sm text-muted-foreground">Departments</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <MapPin className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">{locations.length}</div>
              <div className="text-sm text-muted-foreground">Locations</div>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 mb-6">
        <div className="flex items-center gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search employees, departments, or locations..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              aria-label="Search leave requests"
            />
          </div>
          {/* Department Multi-Select */}
          <div className="relative dropdown-container">
            <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                 onClick={() => setShowDepartmentDropdown(!showDepartmentDropdown)}>
              <span className="text-gray-700">
                {selectedDepartment.length === 0 ? 'All Departments' : 
                 selectedDepartment.length === 1 ? selectedDepartment[0] :
                 `${selectedDepartment.length} selected`}
              </span>
              <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </div>
            {showDepartmentDropdown && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search departments..."
                          value={departmentSearchTerm}
                          onChange={(e) => setDepartmentSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedDepartment.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedDepartment([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedDepartment.length})
                          </button>
                        )}
                      </div>
                    </div>
                {getFilteredDepartmentOptions().map((department) => (
                  <div key={department} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                       onClick={() => handleDepartmentToggle(department)}>
                    <input type="checkbox" checked={selectedDepartment.includes(department)} readOnly className="w-4 h-4" />
                    <span className="text-sm text-gray-700">{department}</span>
                  </div>
                ))}
                {getFilteredDepartmentOptions().length === 0 && (
                  <div className="px-3 py-2 text-sm text-gray-500 text-center">
                    No departments found
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Location Multi-Select */}
          <div className="relative dropdown-container">
            <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                 onClick={() => setShowLocationDropdown(!showLocationDropdown)}>
              <span className="text-gray-700">
                {selectedLocation.length === 0 ? 'All Locations' : 
                 selectedLocation.length === 1 ? selectedLocation[0] :
                 `${selectedLocation.length} selected`}
              </span>
              <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </div>
            {showLocationDropdown && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search locations..."
                          value={locationSearchTerm}
                          onChange={(e) => setLocationSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedLocation.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedLocation([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedLocation.length})
                          </button>
                        )}
                      </div>
                    </div>
                {getFilteredLocationOptions().map((location) => (
                  <div key={location} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                       onClick={() => handleLocationToggle(location)}>
                    <input type="checkbox" checked={selectedLocation.includes(location)} readOnly className="w-4 h-4" />
                    <span className="text-sm text-gray-700">{location}</span>
                  </div>
                ))}
                {getFilteredLocationOptions().length === 0 && (
                  <div className="px-3 py-2 text-sm text-gray-500 text-center">
                    No locations found
                  </div>
                )}
              </div>
            )}
          </div>
          <button
            onClick={() => setShowConflicts(!showConflicts)}
            className={`px-3 py-1 border rounded text-sm transition-colors ${
              showConflicts
                ? 'bg-gray-300 text-black border-gray-300'
                : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
            }`}
            aria-label="Toggle conflict visibility"
          >
            <AlertTriangle className="w-4 h-4 inline mr-1" />
            Show Conflicts
          </button>
        </div>
      </div>

      {/* Calendar Navigation */}
      <div className="bg-white border border-gray-200 rounded-lg py-4 px-6 mb-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigateMonth('prev')}
              className="p-2 hover:bg-gray-100 rounded transition-colors"
              aria-label="Previous month"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <h2 className="text-lg font-semibold text-foreground">{monthName}</h2>
            <button
              onClick={() => navigateMonth('next')}
              className="p-2 hover:bg-gray-100 rounded transition-colors"
              aria-label="Next month"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={goToToday}
              className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors"
            >
              Today
            </button>
            <div className="flex border border-gray-200 rounded overflow-hidden">
              <button
                onClick={() => setViewMode('month')}
                className={`px-3 py-1 text-sm transition-colors ${
                  viewMode === 'month'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                Month
              </button>
              <button
                onClick={() => setViewMode('week')}
                className={`px-3 py-1 text-sm transition-colors ${
                  viewMode === 'week'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                Week
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Calendar Grid */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <div className="grid grid-cols-7 border-b border-gray-200">
          {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
            <div key={day} className="p-3 text-center text-sm font-medium text-gray-500 bg-gray-50">
              {day}
            </div>
          ))}
        </div>
        <div className="grid grid-cols-7">
          {days.map((day, index) => {
            if (!day) {
              return <div key={index} className="h-24 border-r border-b border-gray-200"></div>;
            }
            
            const requests = getRequestsForDate(day);
            const dayConflicts = getConflictsForDate(day);
            const isToday = day.toDateString() === new Date().toDateString();
            const isCurrentMonth = day.getMonth() === currentDate.getMonth();
            
            return (
              <div
                key={day.toISOString()}
                className={`h-24 border-r border-b border-gray-200 p-2 ${
                  isCurrentMonth ? 'bg-white' : 'bg-gray-50'
                } ${isToday ? 'bg-primary/5' : ''}`}
              >
                <div className={`text-sm font-medium mb-1 ${
                  isToday ? 'text-primary' : isCurrentMonth ? 'text-gray-900' : 'text-gray-400'
                }`}>
                  {day.getDate()}
                </div>
                <div className="space-y-1">
                  {requests.slice(0, 2).map(request => {
                    const [firstName, lastName] = request.employeeName.split(' ');
                    const avatarColor = generateAvatarColor(firstName, lastName);
                    const avatarInitials = generateAvatarInitials(firstName, lastName);
                    
                    return (
                      <div
                        key={request.id}
                        className="flex items-center gap-1 text-xs"
                      >
                        <div 
                          className="w-4 h-4 rounded-full flex items-center justify-center text-white text-xs font-medium"
                          style={{ backgroundColor: avatarColor }}
                        >
                          {avatarInitials}
                        </div>
                        <span className="truncate text-gray-700">{request.employeeName}</span>
                        {getLeaveTypeIcon(request.leaveType)}
                      </div>
                    );
                  })}
                  {requests.length > 2 && (
                    <div className="text-xs text-gray-500">
                      +{requests.length - 2} more
                    </div>
                  )}
                  {showConflicts && dayConflicts.length > 0 && (
                    <div className="mt-1">
                      {dayConflicts.map((conflict, idx) => (
                        <div
                          key={idx}
                          className="flex items-center gap-1"
                        >
                          <AlertTriangle className="w-3 h-3 text-status-red" />
                          <span className="text-xs text-status-red font-medium">
                            {conflict.severity} risk
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Conflicts Summary */}
      {showConflicts && conflicts.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-foreground mb-4">Conflict Summary</h3>
          <div className="space-y-3">
            {conflicts.map((conflict, index) => (
              <div key={index} className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                <div className="flex items-center gap-3">
                  <CalendarDays className="w-4 h-4 text-gray-500" />
                  <div>
                    <div className="text-sm font-medium text-gray-900">
                      {new Date(conflict.date).toLocaleDateString()}
                    </div>
                    <div className="text-xs text-gray-500">
                      {conflict.department} • {conflict.location}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <div className="text-sm text-gray-700">
                    {conflict.affectedEmployees.length} employee(s) affected
                  </div>
                  {getConflictSeverityBadge(conflict.severity)}
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`View details for conflict on ${conflict.date}`}
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}