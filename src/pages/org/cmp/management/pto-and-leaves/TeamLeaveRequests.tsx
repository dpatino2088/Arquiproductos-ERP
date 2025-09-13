import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Users, 
  Calendar, 
  Search, 
  Filter,
  Plus,
  ChevronLeft,
  ChevronRight,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  MoreHorizontal,
  Mail,
  Phone,
  MapPin,
  Clock,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Eye,
  Edit,
  Trash2,
  User,
  CalendarDays,
  FileText,
  Plane,
  Heart,
  Coffee
} from 'lucide-react';

interface LeaveRequest {
  id: string;
  employeeId: string;
  employeeName: string;
  employeeEmail: string;
  jobTitle: string;
  department: string;
  leaveType: 'Vacation' | 'Sick Leave' | 'Personal Day' | 'Maternity/Paternity' | 'Bereavement' | 'Other';
  startDate: string;
  endDate: string;
  totalDays: number;
  status: 'Pending' | 'Approved' | 'Rejected' | 'Cancelled';
  submittedDate: string;
  reason: string;
  approverName?: string;
  approvedDate?: string;
  rejectionReason?: string;
  avatar?: string;
  phone?: string;
  location: string;
}

// Function to generate avatar initials (100% reliable, works everywhere)
const generateAvatarInitials = (firstName: string, lastName: string) => {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
};

// Function to generate a consistent background color based on name
// Using primary Teal 700 for all avatars for consistency
const generateAvatarColor = (firstName: string, lastName: string) => {
  return '#008383'; // Primary Teal 700
};

const getStatusBadge = (status: string) => {
  switch (status) {
    case 'Pending':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
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
  switch (leaveType) {
    case 'Vacation':
      return <Plane className="w-4 h-4 text-status-blue" />;
    case 'Sick Leave':
      return <Heart className="w-4 h-4 text-status-red" />;
    case 'Personal Day':
      return <Coffee className="w-4 h-4 text-status-purple" />;
    case 'Maternity/Paternity':
      return <User className="w-4 h-4 text-status-purple" />;
    case 'Bereavement':
      return <Heart className="w-4 h-4 text-status-red" />;
    default:
      return <FileText className="w-4 h-4 text-status-gray" />;
  }
};

const getLeaveTypeBadge = (leaveType: string) => {
  const typeConfig = {
    'Vacation': { bg: 'bg-blue-50', text: 'text-status-blue' },
    'Sick Leave': { bg: 'bg-red-50', text: 'text-status-red' },
    'Personal Day': { bg: 'bg-purple-50', text: 'text-status-purple' },
    'Maternity/Paternity': { bg: 'bg-purple-50', text: 'text-status-purple' },
    'Bereavement': { bg: 'bg-red-50', text: 'text-status-red' },
    'Other': { bg: 'bg-gray-50', text: 'text-status-gray' }
  };
  
  const config = typeConfig[leaveType as keyof typeof typeConfig] || typeConfig['Other'];
  
  return (
    <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {leaveType}
    </span>
  );
};

export default function TeamLeaveRequests() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'employeeName' | 'leaveType' | 'startDate' | 'status' | 'submittedDate'>('submittedDate');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedLeaveType, setSelectedLeaveType] = useState<string>('');

  useEffect(() => {
    // Register submodule tabs for PTO and Leaves section
    registerSubmodules('PTO & Leaves', [
      { id: 'team-balances', label: 'Team Balances', href: '/org/cmp/management/pto-and-leaves/team-balances', icon: Users },
      { id: 'requests', label: 'Team Leave Requests', href: '/org/cmp/management/pto-and-leaves/team-leave-requests', icon: Clock },
      { id: 'calendar', label: 'Team Leave Calendar', href: '/org/cmp/management/pto-and-leaves/team-leave-calendar', icon: Calendar }
    ]);
  }, [registerSubmodules]);

  const leaveRequests: LeaveRequest[] = [
    {
      id: '1',
      employeeId: 'emp-001',
      employeeName: 'Amanda Foster',
      employeeEmail: 'amanda.foster@arquiluz.com',
      jobTitle: 'Senior UX Designer',
      department: 'Design',
      leaveType: 'Vacation',
      startDate: '2024-01-15',
      endDate: '2024-01-19',
      totalDays: 5,
      status: 'Pending',
      submittedDate: '2024-01-10',
      reason: 'Family vacation to Hawaii',
      location: 'San Francisco, CA',
      phone: '+1 (555) 123-4567'
    },
    {
      id: '2',
      employeeId: 'emp-002',
      employeeName: 'Marcus Chen',
      employeeEmail: 'marcus.chen@arquiluz.com',
      jobTitle: 'Full Stack Developer',
      department: 'Engineering',
      leaveType: 'Sick Leave',
      startDate: '2024-01-12',
      endDate: '2024-01-12',
      totalDays: 1,
      status: 'Approved',
      submittedDate: '2024-01-11',
      reason: 'Flu symptoms',
      approverName: 'Sarah Johnson',
      approvedDate: '2024-01-11',
      location: 'Austin, TX',
      phone: '+1 (555) 234-5678'
    },
    {
      id: '3',
      employeeId: 'emp-003',
      employeeName: 'Elena Rodriguez',
      employeeEmail: 'elena.rodriguez@arquiluz.com',
      jobTitle: 'Product Manager',
      department: 'Product',
      leaveType: 'Personal Day',
      startDate: '2024-01-18',
      endDate: '2024-01-18',
      totalDays: 1,
      status: 'Approved',
      submittedDate: '2024-01-08',
      reason: 'Personal appointment',
      approverName: 'David Kim',
      approvedDate: '2024-01-09',
      location: 'Miami, FL',
      phone: '+1 (555) 345-6789'
    },
    {
      id: '4',
      employeeId: 'emp-004',
      employeeName: 'James Wilson',
      employeeEmail: 'james.wilson@arquiluz.com',
      jobTitle: 'Marketing Specialist',
      department: 'Marketing',
      leaveType: 'Maternity/Paternity',
      startDate: '2024-02-01',
      endDate: '2024-04-01',
      totalDays: 60,
      status: 'Pending',
      submittedDate: '2024-01-05',
      reason: 'Paternity leave for newborn',
      location: 'Seattle, WA',
      phone: '+1 (555) 456-7890'
    },
    {
      id: '5',
      employeeId: 'emp-005',
      employeeName: 'Sophie Anderson',
      employeeEmail: 'sophie.anderson@arquiluz.com',
      jobTitle: 'Data Analyst',
      department: 'Analytics',
      leaveType: 'Vacation',
      startDate: '2024-01-22',
      endDate: '2024-01-26',
      totalDays: 5,
      status: 'Rejected',
      submittedDate: '2024-01-12',
      reason: 'Ski trip to Colorado',
      rejectionReason: 'Insufficient notice period',
      location: 'Denver, CO',
      phone: '+1 (555) 567-8901'
    },
    {
      id: '6',
      employeeId: 'emp-006',
      employeeName: 'Alex Thompson',
      employeeEmail: 'alex.thompson@arquiluz.com',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      leaveType: 'Bereavement',
      startDate: '2024-01-14',
      endDate: '2024-01-16',
      totalDays: 3,
      status: 'Approved',
      submittedDate: '2024-01-13',
      reason: 'Funeral arrangements',
      approverName: 'Sarah Johnson',
      approvedDate: '2024-01-13',
      location: 'Portland, OR',
      phone: '+1 (555) 678-9012'
    },
    {
      id: '7',
      employeeId: 'emp-007',
      employeeName: 'Maria Garcia',
      employeeEmail: 'maria.garcia@arquiluz.com',
      jobTitle: 'HR Coordinator',
      department: 'Human Resources',
      leaveType: 'Sick Leave',
      startDate: '2024-01-16',
      endDate: '2024-01-17',
      totalDays: 2,
      status: 'Pending',
      submittedDate: '2024-01-15',
      reason: 'Medical procedure',
      location: 'Phoenix, AZ',
      phone: '+1 (555) 789-0123'
    },
    {
      id: '8',
      employeeId: 'emp-008',
      employeeName: 'David Park',
      employeeEmail: 'david.park@arquiluz.com',
      jobTitle: 'Sales Manager',
      department: 'Sales',
      leaveType: 'Vacation',
      startDate: '2024-01-25',
      endDate: '2024-01-29',
      totalDays: 5,
      status: 'Approved',
      submittedDate: '2024-01-10',
      reason: 'Beach vacation',
      approverName: 'Lisa Chen',
      approvedDate: '2024-01-11',
      location: 'Los Angeles, CA',
      phone: '+1 (555) 890-1234'
    },
    {
      id: '9',
      employeeId: 'emp-009',
      employeeName: 'Rachel Brown',
      employeeEmail: 'rachel.brown@arquiluz.com',
      jobTitle: 'Content Writer',
      department: 'Marketing',
      leaveType: 'Personal Day',
      startDate: '2024-01-19',
      endDate: '2024-01-19',
      totalDays: 1,
      status: 'Cancelled',
      submittedDate: '2024-01-14',
      reason: 'Personal errands',
      location: 'Chicago, IL',
      phone: '+1 (555) 901-2345'
    },
    {
      id: '10',
      employeeId: 'emp-010',
      employeeName: 'Kevin Lee',
      employeeEmail: 'kevin.lee@arquiluz.com',
      jobTitle: 'QA Engineer',
      department: 'Engineering',
      leaveType: 'Other',
      startDate: '2024-01-20',
      endDate: '2024-01-20',
      totalDays: 1,
      status: 'Pending',
      submittedDate: '2024-01-16',
      reason: 'Jury duty',
      location: 'Boston, MA',
      phone: '+1 (555) 012-3456'
    }
  ];

  const filteredRequests = useMemo(() => {
    return leaveRequests.filter(request => {
      const matchesSearch = 
        request.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.employeeEmail.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.jobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.department.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.leaveType.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.reason.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesDepartment = !selectedDepartment || request.department === selectedDepartment;
      const matchesStatus = !selectedStatus || request.status === selectedStatus;
      const matchesLeaveType = !selectedLeaveType || request.leaveType === selectedLeaveType;
      
      return matchesSearch && matchesDepartment && matchesStatus && matchesLeaveType;
    });
  }, [leaveRequests, searchTerm, selectedDepartment, selectedStatus, selectedLeaveType]);

  const sortedRequests = useMemo(() => {
    return [...filteredRequests].sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;
      
      switch (sortBy) {
        case 'employeeName':
          aValue = a.employeeName;
          bValue = b.employeeName;
          break;
        case 'leaveType':
          aValue = a.leaveType;
          bValue = b.leaveType;
          break;
        case 'startDate':
          aValue = new Date(a.startDate).getTime();
          bValue = new Date(b.startDate).getTime();
          break;
        case 'status':
          aValue = a.status;
          bValue = b.status;
          break;
        case 'submittedDate':
          aValue = new Date(a.submittedDate).getTime();
          bValue = new Date(b.submittedDate).getTime();
          break;
        default:
          aValue = a.employeeName;
          bValue = b.employeeName;
      }
      
      if (typeof aValue === 'string' && typeof bValue === 'string') {
        return sortOrder === 'asc' 
          ? aValue.localeCompare(bValue)
          : bValue.localeCompare(aValue);
      }
      
      return sortOrder === 'asc' 
        ? (aValue as number) - (bValue as number)
        : (bValue as number) - (aValue as number);
    });
  }, [filteredRequests, sortBy, sortOrder]);

  const totalPages = Math.ceil(sortedRequests.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedRequests = sortedRequests.slice(startIndex, startIndex + itemsPerPage);

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  const clearFilters = () => {
    setSearchTerm('');
    setSelectedDepartment('');
    setSelectedStatus('');
    setSelectedLeaveType('');
  };

  const departments = [...new Set(leaveRequests.map(request => request.department))];
  const statuses = [...new Set(leaveRequests.map(request => request.status))];
  const leaveTypes = [...new Set(leaveRequests.map(request => request.leaveType))];

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Leave Requests</h1>
        <p className="text-xs text-muted-foreground">Manage and track employee leave requests</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">{leaveRequests.filter(r => r.status === 'Pending').length}</div>
              <div className="text-sm text-muted-foreground">Pending</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">{leaveRequests.filter(r => r.status === 'Approved').length}</div>
              <div className="text-sm text-muted-foreground">Approved</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <XCircle className="h-5 w-5 text-status-red" />
            <div>
              <div className="text-2xl font-bold">{leaveRequests.filter(r => r.status === 'Rejected').length}</div>
              <div className="text-sm text-muted-foreground">Rejected</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-gray" />
            <div>
              <div className="text-2xl font-bold">{leaveRequests.filter(r => r.status === 'Cancelled').length}</div>
              <div className="text-sm text-muted-foreground">Cancelled</div>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search employees, leave types, or reasons..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search leave requests"
              />
            </div>
            <div className="flex items-center gap-2">
              <button
                className={`px-3 py-1 border rounded text-sm transition-colors ${
                  showFilters
                    ? 'bg-gray-300 text-black border-gray-300'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
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
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by department"
                id="department-filter"
              >
                <option value="">All Departments</option>
                {departments.map(dept => (
                  <option key={dept} value={dept}>{dept}</option>
                ))}
              </select>
              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by status"
                id="status-filter"
              >
                <option value="">All Statuses</option>
                {statuses.map(status => (
                  <option key={status} value={status}>{status}</option>
                ))}
              </select>
              <select
                value={selectedLeaveType}
                onChange={(e) => setSelectedLeaveType(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by leave type"
                id="leave-type-filter"
              >
                <option value="">All Leave Types</option>
                {leaveTypes.map(type => (
                  <option key={type} value={type}>{type}</option>
                ))}
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
                  Employee
                  {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('leaveType')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'leaveType' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Leave Type
                  {sortBy === 'leaveType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('startDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'startDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Start Date
                  {sortBy === 'startDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('status')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'status' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Status
                  {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('submittedDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'submittedDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Submitted
                  {sortBy === 'submittedDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Table View */}
      {viewMode === 'table' && (
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
                      onClick={() => handleSort('leaveType')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Leave Type
                      {sortBy === 'leaveType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('startDate')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Start Date
                      {sortBy === 'startDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    End Date
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    Days
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
                      onClick={() => handleSort('submittedDate')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Submitted
                      {sortBy === 'submittedDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {paginatedRequests.map((request) => {
                  const [firstName, lastName] = request.employeeName.split(' ');
                  const avatarColor = generateAvatarColor(firstName, lastName);
                  const avatarInitials = generateAvatarInitials(firstName, lastName);
                  
                  return (
                    <tr key={request.id} className="hover:bg-gray-50">
                      <td className="py-2 px-6">
                        <div className="flex items-center gap-3">
                          <div 
                            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-medium"
                            style={{ backgroundColor: avatarColor }}
                          >
                            {request.avatar ? (
                              <img 
                                src={request.avatar} 
                                alt={request.employeeName}
                                className="w-8 h-8 rounded-full object-cover"
                              />
                            ) : (
                              avatarInitials
                            )}
                          </div>
                          <div>
                            <div className="text-sm font-medium text-gray-900">{request.employeeName}</div>
                            <div className="text-xs text-gray-500">{request.jobTitle}</div>
                          </div>
                        </div>
                      </td>
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          {getLeaveTypeIcon(request.leaveType)}
                          {getLeaveTypeBadge(request.leaveType)}
                        </div>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{new Date(request.startDate).toLocaleDateString()}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{new Date(request.endDate).toLocaleDateString()}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm font-medium text-gray-900">{request.totalDays}</span>
                      </td>
                      <td className="py-2 px-4">
                        {getStatusBadge(request.status)}
                      </td>
                      <td className="py-2 px-4">
                        <span className="text-sm text-gray-900">{new Date(request.submittedDate).toLocaleDateString()}</span>
                      </td>
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          <button
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View details for ${request.employeeName}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          {request.status === 'Pending' && (
                            <>
                              <button
                                className="p-1 hover:bg-gray-100 rounded transition-colors"
                                aria-label={`Approve request for ${request.employeeName}`}
                              >
                                <CheckCircle className="w-4 h-4 text-status-green" />
                              </button>
                              <button
                                className="p-1 hover:bg-gray-100 rounded transition-colors"
                                aria-label={`Reject request for ${request.employeeName}`}
                              >
                                <XCircle className="w-4 h-4 text-status-red" />
                              </button>
                            </>
                          )}
                          <button
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`Edit request for ${request.employeeName}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-600">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
              aria-label="Items per page"
              id="items-per-page"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, sortedRequests.length)} of {sortedRequests.length}
            </span>
          </div>
          {totalPages > 1 && (
            <div className="flex items-center gap-3">
              <button
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                disabled={currentPage === 1}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === 1
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                <ChevronLeft className="w-3 h-3" />
                Previous
              </button>
              <div className="flex items-center gap-1">
                {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                  let pageNum;
                  if (totalPages <= 5) {
                    pageNum = i + 1;
                  } else if (currentPage <= 3) {
                    pageNum = i + 1;
                  } else if (currentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + i;
                  } else {
                    pageNum = currentPage - 2 + i;
                  }
                  
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      className={`w-6 h-6 text-xs rounded transition-colors flex items-center justify-center ${
                        currentPage === pageNum
                          ? 'bg-gray-300 text-black'
                          : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              <button
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                disabled={currentPage === totalPages}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === totalPages
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                Next
                <ChevronRight className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}