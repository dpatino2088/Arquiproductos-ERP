import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Clock, 
  Calendar, 
  MapPin, 
  Search, 
  Filter, 
  ChevronLeft, 
  ChevronRight,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Clock as ClockIcon,
  MoreVertical,
  Edit,
  Eye,
  SortAsc,
  SortDesc,
  ChevronDown,
  ChevronRight as ChevronRightIcon
} from 'lucide-react';

interface TimeEntry {
  id: string;
  clockIn: string;
  clockOut: string | null;
  project: string;
  activity: string;
  hours: number;
  notes?: string;
}

interface AttendanceRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  role: string;
  department: string;
  date: string;
  timeEntries: TimeEntry[];
  totalHours: number;
  status: 'present' | 'absent' | 'late' | 'partial' | 'on-break' | 'on-leave';
  location: string;
  notes?: string;
  avatar?: string;
}

export default function TeamAttendance() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'employeeName' | 'department' | 'clockIn' | 'totalHours' | 'status' | 'location'>('employeeName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedLocation, setSelectedLocation] = useState<string>('');
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());

  useEffect(() => {
    // Register submodule tabs for time and attendance
    registerSubmodules('Time & Attendance', [
      { id: 'team-planner', label: 'Team Planner', href: '/org/cmp/management/time-and-attendance/team-planner', icon: Calendar },
      { id: 'team-attendance', label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance', icon: Clock },
      { id: 'team-geolocation', label: 'Team Geolocation', href: '/org/cmp/management/time-and-attendance/team-geolocation', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  // Mock attendance data
  const attendanceRecords: AttendanceRecord[] = [
    {
      id: '1',
      employeeId: '1',
      employeeName: 'Sarah Johnson',
      role: 'Senior Developer',
      department: 'Engineering',
      date: selectedDate,
      timeEntries: [
        {
          id: '1-1',
          clockIn: '09:15',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Frontend Development',
          hours: 2.75,
          notes: 'Working on user interface'
        },
        {
          id: '1-2',
          clockIn: '13:00',
          clockOut: '17:30',
          project: 'Project Beta',
          activity: 'Code Review',
          hours: 4.5,
          notes: 'Reviewing team code'
        }
      ],
      totalHours: 7.25,
      status: 'present',
      location: 'Office',
      notes: 'Regular day'
    },
    {
      id: '2',
      employeeId: '2',
      employeeName: 'Mike Chen',
      role: 'UX Designer',
      department: 'Design',
      date: selectedDate,
      timeEntries: [
        {
          id: '2-1',
          clockIn: '08:45',
          clockOut: '12:30',
          project: 'Project Alpha',
          activity: 'UI Design',
          hours: 3.75,
          notes: 'Creating wireframes'
        },
        {
          id: '2-2',
          clockIn: '13:30',
          clockOut: '17:15',
          project: 'Project Gamma',
          activity: 'User Research',
          hours: 3.75,
          notes: 'Conducting user interviews'
        }
      ],
      totalHours: 7.5,
      status: 'present',
      location: 'Office'
    },
    {
      id: '3',
      employeeId: '3',
      employeeName: 'Alex Rodriguez',
      role: 'Project Manager',
      department: 'Management',
      date: selectedDate,
      timeEntries: [
        {
          id: '3-1',
          clockIn: '09:30',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Team Meeting',
          hours: 2.5,
          notes: 'Sprint planning'
        },
        {
          id: '3-2',
          clockIn: '13:00',
          clockOut: '15:00',
          project: 'Project Beta',
          activity: 'Client Call',
          hours: 2,
          notes: 'Project status update'
        },
        {
          id: '3-3',
          clockIn: '15:30',
          clockOut: '18:00',
          project: 'Project Gamma',
          activity: 'Documentation',
          hours: 2.5,
          notes: 'Creating project reports'
        }
      ],
      totalHours: 7,
      status: 'late',
      location: 'Office',
      notes: 'Traffic delay'
    },
    {
      id: '4',
      employeeId: '4',
      employeeName: 'Emma Wilson',
      role: 'Marketing Specialist',
      department: 'Marketing',
      date: selectedDate,
      timeEntries: [],
      totalHours: 0,
      status: 'absent',
      location: 'Remote',
      notes: 'Sick leave'
    },
    {
      id: '5',
      employeeId: '5',
      employeeName: 'David Kim',
      role: 'DevOps Engineer',
      department: 'Engineering',
      date: selectedDate,
      timeEntries: [
        {
          id: '5-1',
          clockIn: '10:00',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Deployment',
          hours: 2,
          notes: 'Production deployment'
        },
        {
          id: '5-2',
          clockIn: '14:00',
          clockOut: '16:00',
          project: 'Project Beta',
          activity: 'Infrastructure',
          hours: 2,
          notes: 'Server maintenance'
        }
      ],
      totalHours: 4,
      status: 'partial',
      location: 'Office',
      notes: 'Doctor appointment'
    },
    {
      id: '8',
      employeeId: '8',
      employeeName: 'Jennifer Lee',
      role: 'Product Manager',
      department: 'Product',
      date: selectedDate,
      timeEntries: [
        {
          id: '8-1',
          clockIn: '09:00',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Product Planning',
          hours: 3,
          notes: 'Feature roadmap'
        }
      ],
      totalHours: 3,
      status: 'on-break',
      location: 'Office',
      notes: 'Lunch break'
    },
    {
      id: '6',
      employeeId: '6',
      employeeName: 'Lisa Thompson',
      role: 'HR Manager',
      department: 'Human Resources',
      date: selectedDate,
      timeEntries: [],
      totalHours: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Vacation'
    },
    {
      id: '7',
      employeeId: '7',
      employeeName: 'Robert Garcia',
      role: 'Sales Director',
      department: 'Sales',
      date: selectedDate,
      timeEntries: [],
      totalHours: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Personal leave'
    }
  ];

  const filteredRecords = useMemo(() => {
    let filtered = attendanceRecords.filter(record => {
      const matchesSearch = 
        record.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        record.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
        record.department.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesDepartment = !selectedDepartment || record.department === selectedDepartment;
      const matchesStatus = !selectedStatus || record.status === selectedStatus;
      const matchesLocation = !selectedLocation || record.location === selectedLocation;
      
      return matchesSearch && matchesDepartment && matchesStatus && matchesLocation;
    });

    // Sort records
    filtered.sort((a, b) => {
      const aValue = a[sortBy as keyof AttendanceRecord];
      const bValue = b[sortBy as keyof AttendanceRecord];
      
      if (sortOrder === 'asc') {
        return aValue > bValue ? 1 : -1;
      } else {
        return aValue < bValue ? 1 : -1;
      }
    });

    return filtered;
  }, [attendanceRecords, searchTerm, selectedDepartment, selectedStatus, selectedLocation, sortBy, sortOrder]);

  const paginatedRecords = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return filteredRecords.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredRecords, currentPage, itemsPerPage]);

  const totalPages = Math.ceil(filteredRecords.length / itemsPerPage);

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'present':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green">
            Present
          </span>
        );
      case 'absent':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-red-light text-status-red">
            Absent
          </span>
        );
      case 'late':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-orange-light text-status-orange">
            Late
          </span>
        );
      case 'partial':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-blue-light text-status-blue">
            Partial
          </span>
        );
      case 'on-break':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-purple-light text-status-purple">
            On Break
          </span>
        );
      case 'on-leave':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-neutral-gray text-white">
            On Leave
          </span>
        );
      default:
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-neutral-gray text-white">
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

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  const clearFilters = () => {
    setSelectedDepartment('');
    setSelectedStatus('');
    setSelectedLocation('');
    setSearchTerm('');
  };

  const toggleRowExpansion = (recordId: string) => {
    const newExpandedRows = new Set(expandedRows);
    if (newExpandedRows.has(recordId)) {
      newExpandedRows.delete(recordId);
    } else {
      newExpandedRows.add(recordId);
    }
    setExpandedRows(newExpandedRows);
  };

  const getFirstClockIn = (timeEntries: TimeEntry[]) => {
    if (timeEntries.length === 0) return null;
    return timeEntries[0].clockIn;
  };

  const getLastClockOut = (timeEntries: TimeEntry[]) => {
    if (timeEntries.length === 0) return null;
    const lastEntry = timeEntries[timeEntries.length - 1];
    return lastEntry.clockOut;
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Attendance</h1>
        <p className="text-xs text-muted-foreground">Track and manage team attendance records</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'present').length}
              </div>
              <div className="text-sm text-muted-foreground">Present</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <XCircle className="h-5 w-5 text-status-red" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'absent').length}
              </div>
              <div className="text-sm text-muted-foreground">Absent</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'late').length}
              </div>
              <div className="text-sm text-muted-foreground">Late</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <ClockIcon className="h-5 w-5 text-status-purple" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'on-break').length}
              </div>
              <div className="text-sm text-muted-foreground">On Break</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <ClockIcon className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'on-leave').length}
              </div>
              <div className="text-sm text-muted-foreground">PTO & Leave</div>
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
                aria-label="Search attendance records"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Select date"
              />
              <button
                className={`px-3 py-1 border rounded text-sm transition-colors ${
                  showFilters
                    ? 'bg-gray-100 text-gray-900 border-gray-300'
                    : 'border-gray-300 hover:bg-gray-50'
                }`}
                onClick={() => setShowFilters(!showFilters)}
                aria-label="Toggle filters"
              >
                <Filter className="w-4 h-4 inline mr-1" />
                Filters
              </button>
            </div>
          </div>
        </div>
        
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
              <select 
                value={selectedDepartment}
                onChange={(e) => setSelectedDepartment(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by department"
                id="department-filter"
              >
                <option value="">All Departments</option>
                <option value="Engineering">Engineering</option>
                <option value="Design">Design</option>
                <option value="Management">Management</option>
                <option value="Marketing">Marketing</option>
                <option value="Product">Product</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Sales">Sales</option>
              </select>

              <select 
                value={selectedLocation}
                onChange={(e) => setSelectedLocation(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by location"
                id="location-filter"
              >
                <option value="">All Locations</option>
                <option value="Office">Office</option>
                <option value="Remote">Remote</option>
              </select>

              <select 
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by status"
                id="status-filter"
              >
                <option value="">All Statuses</option>
                <option value="present">Present</option>
                <option value="absent">Absent</option>
                <option value="late">Late</option>
                <option value="partial">Partial</option>
                <option value="on-break">On Break</option>
                <option value="on-leave">On Leave</option>
              </select>
            </div>

            <div className="flex justify-between items-center">
              <button 
                onClick={clearFilters}
                className="text-xs text-gray-500 hover:text-gray-700"
              >
                Clear all filters
              </button>
              <div className="flex gap-3 items-center">
                <span className="text-xs text-gray-500">Sort by:</span>
                <button 
                  onClick={() => handleSort('employeeName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'employeeName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Name
                  {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('department')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'department' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Department
                  {sortBy === 'department' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('clockIn')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'clockIn' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Clock In
                  {sortBy === 'clockIn' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('totalHours')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'totalHours' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Hours
                  {sortBy === 'totalHours' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Table View */}
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('employeeName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Employee
                      {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('department')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Department
                      {sortBy === 'department' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('clockIn')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Clock In
                      {sortBy === 'clockIn' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Clock Out</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('totalHours')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total Hours
                      {sortBy === 'totalHours' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('location')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Location
                      {sortBy === 'location' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {paginatedRecords.map((record) => (
                  <>
                    <tr key={record.id} className="hover:bg-gray-50 transition-colors">
                        <td className="py-2 px-6">
                          <div className="flex items-center gap-3">
                            <button
                              onClick={() => record.timeEntries.length > 0 && toggleRowExpansion(record.id)}
                              className={`p-1 rounded transition-colors ${
                                record.timeEntries.length > 0 
                                  ? 'hover:bg-gray-100' 
                                  : 'invisible'
                              }`}
                              aria-label={record.timeEntries.length > 0 ? 
                                `${expandedRows.has(record.id) ? 'Collapse' : 'Expand'} ${record.employeeName} time entries` : 
                                'No time entries to expand'
                              }
                            >
                              {record.timeEntries.length > 0 ? (
                                expandedRows.has(record.id) ? (
                                  <ChevronDown className="w-4 h-4" />
                                ) : (
                                  <ChevronRightIcon className="w-4 h-4" />
                                )
                              ) : (
                                <ChevronRightIcon className="w-4 h-4" />
                              )}
                            </button>
                            <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                              {record.employeeName.split(' ').map(n => n[0]).join('')}
                            </div>
                            <div className="text-sm font-medium text-gray-900">{record.employeeName}</div>
                          </div>
                        </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{record.department}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{getFirstClockIn(record.timeEntries) || '--'}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{getLastClockOut(record.timeEntries) || '--'}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{record.totalHours}h</span>
                      </td>
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          {getStatusIcon(record.status)}
                          {getStatusBadge(record.status)}
                        </div>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{record.location}</span>
                      </td>
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          <button
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${record.employeeName} details`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`Edit ${record.employeeName} record`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`More options for ${record.employeeName}`}
                          >
                            <MoreVertical className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                    
                    {/* Expanded time entries */}
                    {expandedRows.has(record.id) && record.timeEntries.length > 0 && (
                      <tr className="bg-gray-50">
                        <td colSpan={8} className="py-4 px-6">
                          <div className="space-y-3">
                            <h4 className="text-sm font-medium text-gray-900 mb-3">Time Entries</h4>
                            <div className="space-y-2">
                              {record.timeEntries.map((entry, index) => (
                                <div key={entry.id} className="bg-white border border-gray-200 rounded-lg p-4">
                                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                                    <div>
                                      <div className="text-xs text-gray-500 mb-1">Time</div>
                                      <div className="text-sm font-medium text-gray-900">
                                        {entry.clockIn} - {entry.clockOut || 'In Progress'}
                                      </div>
                                    </div>
                                    <div>
                                      <div className="text-xs text-gray-500 mb-1">Project</div>
                                      <div className="text-sm text-gray-900">{entry.project}</div>
                                    </div>
                                    <div>
                                      <div className="text-xs text-gray-500 mb-1">Activity</div>
                                      <div className="text-sm text-gray-900">{entry.activity}</div>
                                    </div>
                                    <div>
                                      <div className="text-xs text-gray-500 mb-1">Hours</div>
                                      <div className="text-sm font-medium text-gray-900">{entry.hours}h</div>
                                    </div>
                                  </div>
                                  {entry.notes && (
                                    <div className="mt-3">
                                      <div className="text-xs text-gray-500 mb-1">Notes</div>
                                      <div className="text-sm text-gray-700">{entry.notes}</div>
                                    </div>
                                  )}
                                </div>
                              ))}
                            </div>
                          </div>
                        </td>
                      </tr>
                    )}
                  </>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-600">Show:</span>
            <select 
              value={itemsPerPage}
              onChange={(e) => setItemsPerPage(Number(e.target.value))}
              className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
            >
              <option value={5}>5</option>
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {((currentPage - 1) * itemsPerPage) + 1}-{Math.min(currentPage * itemsPerPage, filteredRecords.length)} of {filteredRecords.length}
            </span>
          </div>
          
          {totalPages > 1 && (
            <div className="flex items-center gap-3">
              <button
                onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                disabled={currentPage === 1}
                className="px-2 py-1 border rounded text-xs transition-colors disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                aria-label="Previous page"
              >
                <ChevronLeft className="w-3 h-3" />
              </button>
              
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
                <button
                  key={page}
                  onClick={() => setCurrentPage(page)}
                  className={`w-6 h-6 text-xs rounded transition-colors flex items-center justify-center ${
                    currentPage === page
                      ? 'text-white'
                      : 'hover:bg-gray-50'
                  }`}
                  style={{ backgroundColor: currentPage === page ? '#008383' : 'transparent' }}
                  aria-label={`Go to page ${page}`}
                >
                  {page}
                </button>
              ))}
              
              <button
                onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                disabled={currentPage === totalPages}
                className="px-2 py-1 border rounded text-xs transition-colors disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                aria-label="Next page"
              >
                <ChevronRight className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
