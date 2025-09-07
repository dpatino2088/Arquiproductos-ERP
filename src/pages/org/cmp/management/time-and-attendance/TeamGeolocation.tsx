import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  MapPin, 
  Search, 
  Filter, 
  SortAsc, 
  SortDesc,
  Eye,
  Navigation,
  Clock,
  User,
  Building,
  Map,
  CheckCircle,
  XCircle,
  AlertTriangle
} from 'lucide-react';

interface EmployeeLocation {
  id: string;
  employeeId: string;
  employeeName: string;
  role: string;
  department: string;
  location: string;
  status: 'present' | 'absent' | 'late' | 'partial' | 'on-break' | 'on-leave';
  lastSeen: string;
  coordinates: {
    lat: number;
    lng: number;
  };
  avatar?: string;
  currentProject?: string;
  workFrom: 'office' | 'remote' | 'field';
}

export default function TeamGeolocation() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDepartment, setSelectedDepartment] = useState('');
  const [selectedLocation, setSelectedLocation] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('');
  const [selectedWorkFrom, setSelectedWorkFrom] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [sortBy, setSortBy] = useState<'employeeName' | 'department' | 'lastSeen' | 'location'>('employeeName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  useEffect(() => {
    registerSubmodules('Time & Attendance', [
      { id: 'team-planner', label: 'Team Planner', href: '/org/cmp/management/time-and-attendance/team-planner', icon: Map },
      { id: 'team-attendance', label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance', icon: Clock },
      { id: 'team-geolocation', label: 'Team Geolocation', href: '/org/cmp/management/time-and-attendance/team-geolocation', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  // Mock employee location data
  const employeeLocations: EmployeeLocation[] = [
    {
      id: '1',
      employeeId: 'EMP001',
      employeeName: 'Sarah Johnson',
      role: 'Senior Developer',
      department: 'Engineering',
      location: 'Office',
      status: 'present',
      lastSeen: '2 minutes ago',
      coordinates: { lat: 40.7128, lng: -74.0060 }, // NYC Office
      currentProject: 'Project Alpha',
      workFrom: 'office'
    },
    {
      id: '2',
      employeeId: 'EMP002',
      employeeName: 'Michael Chen',
      role: 'Product Manager',
      department: 'Product',
      location: 'Remote',
      status: 'present',
      lastSeen: '5 minutes ago',
      coordinates: { lat: 37.7749, lng: -122.4194 }, // San Francisco
      currentProject: 'Project Beta',
      workFrom: 'remote'
    },
    {
      id: '3',
      employeeId: 'EMP003',
      employeeName: 'Emily Rodriguez',
      role: 'UX Designer',
      department: 'Design',
      location: 'Office',
      status: 'on-break',
      lastSeen: '10 minutes ago',
      coordinates: { lat: 40.7128, lng: -74.0060 }, // NYC Office
      currentProject: 'Project Gamma',
      workFrom: 'office'
    },
    {
      id: '4',
      employeeId: 'EMP004',
      employeeName: 'David Kim',
      role: 'Sales Representative',
      department: 'Sales',
      location: 'Field',
      status: 'present',
      lastSeen: '1 minute ago',
      coordinates: { lat: 40.7589, lng: -73.9851 }, // Manhattan
      currentProject: 'Client Meeting',
      workFrom: 'field'
    },
    {
      id: '5',
      employeeId: 'EMP005',
      employeeName: 'Lisa Wang',
      role: 'Marketing Specialist',
      department: 'Marketing',
      location: 'Remote',
      status: 'present',
      lastSeen: '3 minutes ago',
      coordinates: { lat: 34.0522, lng: -118.2437 }, // Los Angeles
      currentProject: 'Campaign Launch',
      workFrom: 'remote'
    },
    {
      id: '6',
      employeeId: 'EMP006',
      employeeName: 'James Wilson',
      role: 'DevOps Engineer',
      department: 'Engineering',
      location: 'Office',
      status: 'late',
      lastSeen: '15 minutes ago',
      coordinates: { lat: 40.7128, lng: -74.0060 }, // NYC Office
      currentProject: 'Infrastructure',
      workFrom: 'office'
    },
    {
      id: '7',
      employeeId: 'EMP007',
      employeeName: 'Maria Garcia',
      role: 'HR Manager',
      department: 'Human Resources',
      location: 'Office',
      status: 'present',
      lastSeen: '1 minute ago',
      coordinates: { lat: 40.7128, lng: -74.0060 }, // NYC Office
      currentProject: 'Recruitment',
      workFrom: 'office'
    },
    {
      id: '8',
      employeeId: 'EMP008',
      employeeName: 'Alex Thompson',
      role: 'Data Analyst',
      department: 'Analytics',
      location: 'Remote',
      status: 'on-leave',
      lastSeen: '2 hours ago',
      coordinates: { lat: 41.8781, lng: -87.6298 }, // Chicago
      currentProject: 'Data Pipeline',
      workFrom: 'remote'
    }
  ];

  const filteredLocations = useMemo(() => {
    let filtered = employeeLocations;

    if (searchTerm) {
      filtered = filtered.filter(emp => 
        emp.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        emp.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
        emp.department.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (selectedDepartment) {
      filtered = filtered.filter(emp => emp.department === selectedDepartment);
    }

    if (selectedLocation) {
      filtered = filtered.filter(emp => emp.location === selectedLocation);
    }

    if (selectedStatus) {
      filtered = filtered.filter(emp => emp.status === selectedStatus);
    }

    if (selectedWorkFrom) {
      filtered = filtered.filter(emp => emp.workFrom === selectedWorkFrom);
    }

    // Sort
    filtered.sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;

      switch (sortBy) {
        case 'employeeName':
          aValue = a.employeeName;
          bValue = b.employeeName;
          break;
        case 'department':
          aValue = a.department;
          bValue = b.department;
          break;
        case 'lastSeen':
          aValue = parseInt(a.lastSeen.replace(/\D/g, ''));
          bValue = parseInt(b.lastSeen.replace(/\D/g, ''));
          break;
        case 'location':
          aValue = a.location;
          bValue = b.location;
          break;
        default:
          aValue = a.employeeName;
          bValue = b.employeeName;
      }

      if (sortOrder === 'asc') {
        return aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
      } else {
        return aValue > bValue ? -1 : aValue < bValue ? 1 : 0;
      }
    });

    return filtered;
  }, [employeeLocations, searchTerm, selectedDepartment, selectedLocation, selectedStatus, selectedWorkFrom, sortBy, sortOrder]);

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

  const getWorkFromBadge = (workFrom: string) => {
    switch (workFrom) {
      case 'office':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
            Office
          </span>
        );
      case 'remote':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-700">
            Remote
          </span>
        );
      case 'field':
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-700">
            Field
          </span>
        );
      default:
        return (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
            Unknown
          </span>
        );
    }
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Geolocation</h1>
        <p className="text-xs text-muted-foreground">Track and monitor team member locations in real-time</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">
                {employeeLocations.filter(emp => emp.status === 'present').length}
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
                {employeeLocations.filter(emp => emp.status === 'absent').length}
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
                {employeeLocations.filter(emp => emp.status === 'late').length}
              </div>
              <div className="text-sm text-muted-foreground">Late</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-status-purple" />
            <div>
              <div className="text-2xl font-bold">
                {employeeLocations.filter(emp => emp.status === 'on-break').length}
              </div>
              <div className="text-sm text-muted-foreground">On Break</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">
                {employeeLocations.filter(emp => emp.status === 'on-leave').length}
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
                <option value="Product">Product</option>
                <option value="Design">Design</option>
                <option value="Sales">Sales</option>
                <option value="Marketing">Marketing</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Analytics">Analytics</option>
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
                <option value="Field">Field</option>
              </select>

              <select 
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by status"
                id="status-filter"
              >
                <option value="">All Status</option>
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
                  onClick={() => handleSort('lastSeen')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'lastSeen' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Last Seen
                  {sortBy === 'lastSeen' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('location')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'location' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Location
                  {sortBy === 'location' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Map Container */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <div className="p-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Employee Locations</h3>
          <p className="text-sm text-gray-500">Real-time location tracking of team members</p>
        </div>
        <div className="h-96 bg-gray-100 flex items-center justify-center">
        <div className="text-center">
            <Map className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h4 className="text-lg font-medium text-gray-900 mb-2">Interactive Map</h4>
            <p className="text-gray-500 mb-4">
              {filteredLocations.length} employee{filteredLocations.length !== 1 ? 's' : ''} found
            </p>
            <div className="text-sm text-gray-400">
              Map integration would show employee locations here
            </div>
          </div>
        </div>
      </div>

      {/* Employee List */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
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
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Work Type</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Location</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('lastSeen')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Last Seen
                    {sortBy === 'lastSeen' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Project</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredLocations.map((employee) => (
                <tr key={employee.id} className="border-b border-gray-100 last:border-b-0 hover:bg-gray-50">
                  <td className="py-2 px-6">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                        {employee.employeeName.split(' ').map(n => n[0]).join('')}
                      </div>
                      <div>
                        <div className="text-sm font-medium text-gray-900">{employee.employeeName}</div>
                        <div className="text-xs text-gray-500">{employee.role}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-2 px-4">
                    <span className="text-sm text-gray-900">{employee.department}</span>
                  </td>
                  <td className="py-2 px-4">
                    {getWorkFromBadge(employee.workFrom)}
                  </td>
                  <td className="py-2 px-4">
                    <span className="text-sm text-gray-900">{employee.location}</span>
                  </td>
                  <td className="py-2 px-4">
                    {getStatusBadge(employee.status)}
                  </td>
                  <td className="py-2 px-4">
                    <span className="text-sm text-gray-900">{employee.lastSeen}</span>
                  </td>
                  <td className="py-2 px-4">
                    <span className="text-sm text-gray-900">{employee.currentProject}</span>
                  </td>
                  <td className="py-2 px-4">
                    <div className="flex items-center gap-2">
                      <button
                        className="p-1 hover:bg-gray-100 rounded transition-colors"
                        aria-label={`View ${employee.employeeName} location details`}
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}