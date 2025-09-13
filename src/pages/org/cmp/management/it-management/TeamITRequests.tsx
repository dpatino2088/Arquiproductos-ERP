import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Users, 
  Laptop, 
  Smartphone,
  Monitor,
  Tablet,
  Search, 
  Filter,
  Plus,
  Edit,
  Trash2,
  ChevronLeft,
  ChevronRight,
  SortAsc,
  SortDesc,
  MoreHorizontal,
  Mail,
  Phone,
  MapPin,
  Calendar,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Clock,
  Eye,
  Settings,
  HardDrive,
  Wifi,
  Battery,
  Shield,
  GitBranch,
  Key,
  FileText,
  Download,
  Upload,
  Lock,
  Unlock,
  RefreshCw,
  DollarSign,
  Building,
  User,
  MessageSquare,
  UserPlus,
  Package,
  CreditCard
} from 'lucide-react';

interface ITRequest {
  id: string;
  requestType: 'Hardware' | 'Software' | 'Access' | 'Support' | 'Other';
  title: string;
  description: string;
  priority: 'Low' | 'Medium' | 'High' | 'Critical';
  status: 'Pending' | 'In Review' | 'Approved' | 'Rejected' | 'In Progress' | 'Completed' | 'Cancelled';
  requestedBy: string;
  requestedByEmail: string;
  requestedByJobTitle: string;
  requestedByDepartment: string;
  requestedByLocation: string;
  assignedTo?: string;
  assignedToEmail?: string;
  assignedToJobTitle?: string;
  assignedToDepartment?: string;
  assignedToLocation?: string;
  requestDate: string;
  dueDate?: string;
  completedDate?: string;
  estimatedCost?: number;
  currency: string;
  category: string;
  subcategory?: string;
  notes?: string;
  attachments?: string[];
  avatar?: string;
  phone?: string;
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
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          Pending
        </span>
      );
    case 'In Review':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          In Review
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
    case 'In Progress':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          In Progress
        </span>
      );
    case 'Completed':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
          Completed
        </span>
      );
    case 'Cancelled':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: 'rgba(158, 158, 158, 0.1)', color: '#9E9E9E' }}>
          Cancelled
        </span>
      );
    default:
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: 'rgba(158, 158, 158, 0.1)', color: '#9E9E9E' }}>
          {status}
        </span>
      );
  }
};

const getPriorityBadge = (priority: string) => {
  switch (priority) {
    case 'Low':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          Low
        </span>
      );
    case 'Medium':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
          Medium
        </span>
      );
    case 'High':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          High
        </span>
      );
    case 'Critical':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
          Critical
        </span>
      );
    default:
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          {priority}
        </span>
      );
  }
};

const getRequestTypeIcon = (requestType: string) => {
  switch (requestType) {
    case 'Hardware':
      return <Laptop className="w-4 h-4 text-status-blue" />;
    case 'Software':
      return <Package className="w-4 h-4 text-status-green" />;
    case 'Access':
      return <Key className="w-4 h-4 text-status-purple" />;
    case 'Support':
      return <MessageSquare className="w-4 h-4 text-status-orange" />;
    case 'Other':
      return <Settings className="w-4 h-4 text-status-blue" />;
    default:
      return <Settings className="w-4 h-4 text-status-blue" />;
  }
};

const getRequestTypeBadge = (requestType: string) => {
  const typeConfig = {
    'Hardware': { bg: 'bg-blue-50', text: 'text-status-blue' },
    'Software': { bg: 'bg-green-50', text: 'text-status-green' },
    'Access': { bg: 'bg-purple-50', text: 'text-status-purple' },
    'Support': { bg: 'bg-orange-50', text: 'text-status-orange' },
    'Other': { bg: 'bg-gray-50', text: 'text-status-gray' }
  };
  
  const config = typeConfig[requestType as keyof typeof typeConfig] || typeConfig['Other'];
  
  return (
    <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {requestType}
    </span>
  );
};

export default function TeamITRequests() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'title' | 'requestType' | 'requestedBy' | 'status' | 'requestDate'>('requestDate');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedRequestType, setSelectedRequestType] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');

  useEffect(() => {
    // Register submodule tabs for IT Management section
    registerSubmodules('IT Management', [
      { id: 'team-devices', label: 'Team Devices', href: '/org/cmp/management/it-management/team-devices', icon: Laptop },
      { id: 'team-licenses', label: 'Team Licenses', href: '/org/cmp/management/it-management/team-licenses', icon: Shield },
      { id: 'team-it-requests', label: 'Team IT Requests', href: '/org/cmp/management/it-management/team-it-requests', icon: MessageSquare }
    ]);
  }, [registerSubmodules]);

  const itRequests: ITRequest[] = [
    {
      id: '1',
      requestType: 'Hardware',
      title: 'New MacBook Pro for Design Team',
      description: 'Need a new MacBook Pro 16" for the new UX designer joining the team. Current laptop is outdated and cannot handle design software requirements.',
      priority: 'High',
      status: 'Pending',
      requestedBy: 'Amanda Foster',
      requestedByEmail: 'amanda.foster@arquiluz.com',
      requestedByJobTitle: 'Senior UX Designer',
      requestedByDepartment: 'Design',
      requestedByLocation: 'San Francisco, CA',
      requestDate: '2024-01-15',
      dueDate: '2024-01-30',
      estimatedCost: 2499.00,
      currency: 'USD',
      category: 'Laptop',
      subcategory: 'MacBook Pro 16"',
      notes: 'Urgent request for new team member onboarding'
    },
    {
      id: '2',
      requestType: 'Software',
      title: 'Adobe Creative Cloud License',
      description: 'Request for Adobe Creative Cloud license for the marketing team. Need access to Photoshop, Illustrator, and After Effects for campaign creation.',
      priority: 'Medium',
      status: 'Approved',
      requestedBy: 'Marcus Chen',
      requestedByEmail: 'marcus.chen@arquiluz.com',
      requestedByJobTitle: 'Full Stack Developer',
      requestedByDepartment: 'Engineering',
      requestedByLocation: 'Austin, TX',
      assignedTo: 'IT Support Team',
      assignedToEmail: 'it-support@arquiluz.com',
      assignedToJobTitle: 'IT Support Specialist',
      assignedToDepartment: 'IT',
      assignedToLocation: 'Austin, TX',
      requestDate: '2024-01-10',
      dueDate: '2024-01-25',
      completedDate: '2024-01-20',
      estimatedCost: 52.99,
      currency: 'USD',
      category: 'Design Software',
      subcategory: 'Adobe Creative Cloud',
      notes: 'License activated and user notified'
    },
    {
      id: '3',
      requestType: 'Access',
      title: 'Database Access Request',
      description: 'Need read-only access to the production database for data analysis and reporting purposes. Will be used for generating monthly reports.',
      priority: 'Medium',
      status: 'In Review',
      requestedBy: 'Elena Rodriguez',
      requestedByEmail: 'elena.rodriguez@arquiluz.com',
      requestedByJobTitle: 'Product Manager',
      requestedByDepartment: 'Product',
      requestedByLocation: 'Miami, FL',
      requestDate: '2024-01-12',
      dueDate: '2024-01-27',
      estimatedCost: 0,
      currency: 'USD',
      category: 'Database Access',
      subcategory: 'Read-Only Access',
      notes: 'Security review in progress'
    },
    {
      id: '4',
      requestType: 'Support',
      title: 'VPN Connection Issues',
      description: 'Experiencing frequent disconnections from VPN when working remotely. Connection drops every 30 minutes and requires re-authentication.',
      priority: 'High',
      status: 'In Progress',
      requestedBy: 'James Wilson',
      requestedByEmail: 'james.wilson@arquiluz.com',
      requestedByJobTitle: 'Marketing Specialist',
      requestedByDepartment: 'Marketing',
      requestedByLocation: 'Seattle, WA',
      assignedTo: 'Network Team',
      assignedToEmail: 'network@arquiluz.com',
      assignedToJobTitle: 'Network Administrator',
      assignedToDepartment: 'IT',
      assignedToLocation: 'Seattle, WA',
      requestDate: '2024-01-08',
      dueDate: '2024-01-22',
      estimatedCost: 0,
      currency: 'USD',
      category: 'Network Support',
      subcategory: 'VPN Issues',
      notes: 'Investigating network configuration'
    },
    {
      id: '5',
      requestType: 'Hardware',
      title: 'Additional Monitor Setup',
      description: 'Need a second monitor for improved productivity. Current single monitor setup is limiting workflow efficiency.',
      priority: 'Low',
      status: 'Completed',
      requestedBy: 'Sophie Anderson',
      requestedByEmail: 'sophie.anderson@arquiluz.com',
      requestedByJobTitle: 'Data Analyst',
      requestedByDepartment: 'Analytics',
      requestedByLocation: 'Denver, CO',
      assignedTo: 'IT Support Team',
      assignedToEmail: 'it-support@arquiluz.com',
      assignedToJobTitle: 'IT Support Specialist',
      assignedToDepartment: 'IT',
      assignedToLocation: 'Denver, CO',
      requestDate: '2024-01-05',
      dueDate: '2024-01-20',
      completedDate: '2024-01-18',
      estimatedCost: 299.99,
      currency: 'USD',
      category: 'Monitor',
      subcategory: 'Dell UltraSharp 27"',
      notes: 'Monitor installed and configured successfully'
    },
    {
      id: '6',
      requestType: 'Software',
      title: 'GitHub Enterprise Access',
      description: 'Request for GitHub Enterprise access for the new DevOps engineer. Need full repository access and ability to create new repositories.',
      priority: 'High',
      status: 'Approved',
      requestedBy: 'Alex Thompson',
      requestedByEmail: 'alex.thompson@arquiluz.com',
      requestedByJobTitle: 'DevOps Engineer',
      requestedByDepartment: 'Engineering',
      requestedByLocation: 'Portland, OR',
      assignedTo: 'DevOps Team',
      assignedToEmail: 'devops@arquiluz.com',
      assignedToJobTitle: 'Senior DevOps Engineer',
      assignedToDepartment: 'Engineering',
      assignedToLocation: 'Portland, OR',
      requestDate: '2024-01-14',
      dueDate: '2024-01-28',
      completedDate: '2024-01-16',
      estimatedCost: 21.00,
      currency: 'USD',
      category: 'Development Tools',
      subcategory: 'GitHub Enterprise',
      notes: 'Access granted and user onboarded'
    },
    {
      id: '7',
      requestType: 'Support',
      title: 'Email Configuration Issues',
      description: 'Having trouble setting up email on new mobile device. Keep getting authentication errors when trying to add corporate email account.',
      priority: 'Medium',
      status: 'Pending',
      requestedBy: 'Maria Garcia',
      requestedByEmail: 'maria.garcia@arquiluz.com',
      requestedByJobTitle: 'HR Coordinator',
      requestedByDepartment: 'Human Resources',
      requestedByLocation: 'Phoenix, AZ',
      requestDate: '2024-01-16',
      dueDate: '2024-01-31',
      estimatedCost: 0,
      currency: 'USD',
      category: 'Email Support',
      subcategory: 'Mobile Configuration',
      notes: 'Waiting for IT support response'
    },
    {
      id: '8',
      requestType: 'Hardware',
      title: 'Standing Desk Request',
      description: 'Request for a standing desk to improve ergonomics and reduce back pain from prolonged sitting. Current desk setup is not adjustable.',
      priority: 'Low',
      status: 'Rejected',
      requestedBy: 'David Park',
      requestedByEmail: 'david.park@arquiluz.com',
      requestedByJobTitle: 'Sales Manager',
      requestedByDepartment: 'Sales',
      requestedByLocation: 'Los Angeles, CA',
      requestDate: '2024-01-11',
      dueDate: '2024-01-26',
      estimatedCost: 450.00,
      currency: 'USD',
      category: 'Office Furniture',
      subcategory: 'Standing Desk',
      notes: 'Request denied - budget constraints. Alternative solutions provided.'
    },
    {
      id: '9',
      requestType: 'Access',
      title: 'Slack Admin Access',
      description: 'Need admin access to Slack workspace to manage channels, users, and integrations for the marketing team.',
      priority: 'Medium',
      status: 'In Review',
      requestedBy: 'Rachel Brown',
      requestedByEmail: 'rachel.brown@arquiluz.com',
      requestedByJobTitle: 'Content Writer',
      requestedByDepartment: 'Marketing',
      requestedByLocation: 'Chicago, IL',
      requestDate: '2024-01-13',
      dueDate: '2024-01-28',
      estimatedCost: 0,
      currency: 'USD',
      category: 'Communication Tools',
      subcategory: 'Slack Admin',
      notes: 'Security review required for admin access'
    },
    {
      id: '10',
      requestType: 'Software',
      title: 'Project Management Tool License',
      description: 'Need additional license for Asana project management tool. Current team has grown and we need more seats for project collaboration.',
      priority: 'High',
      status: 'In Progress',
      requestedBy: 'Kevin Lee',
      requestedByEmail: 'kevin.lee@arquiluz.com',
      requestedByJobTitle: 'QA Engineer',
      assignedTo: 'IT Support Team',
      assignedToEmail: 'it-support@arquiluz.com',
      assignedToJobTitle: 'IT Support Specialist',
      assignedToDepartment: 'IT',
      assignedToLocation: 'Boston, MA',
      requestedByDepartment: 'Engineering',
      requestedByLocation: 'Boston, MA',
      requestDate: '2024-01-09',
      dueDate: '2024-01-24',
      estimatedCost: 10.99,
      currency: 'USD',
      category: 'Project Management',
      subcategory: 'Asana License',
      notes: 'License procurement in progress'
    }
  ];

  const filteredRequests = useMemo(() => {
    return itRequests.filter(request => {
      const matchesSearch = 
        request.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.category.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.requestedBy.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.requestedByJobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        request.requestedByDepartment.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesRequestType = !selectedRequestType || request.requestType === selectedRequestType;
      const matchesStatus = !selectedStatus || request.status === selectedStatus;
      const matchesDepartment = !selectedDepartment || request.requestedByDepartment === selectedDepartment;
      
      return matchesSearch && matchesRequestType && matchesStatus && matchesDepartment;
    });
  }, [itRequests, searchTerm, selectedRequestType, selectedStatus, selectedDepartment]);

  const sortedRequests = useMemo(() => {
    return [...filteredRequests].sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;
      
      switch (sortBy) {
        case 'title':
          aValue = a.title;
          bValue = b.title;
          break;
        case 'requestType':
          aValue = a.requestType;
          bValue = b.requestType;
          break;
        case 'requestedBy':
          aValue = a.requestedBy;
          bValue = b.requestedBy;
          break;
        case 'status':
          aValue = a.status;
          bValue = b.status;
          break;
        case 'requestDate':
          aValue = new Date(a.requestDate).getTime();
          bValue = new Date(b.requestDate).getTime();
          break;
        default:
          aValue = a.requestDate;
          bValue = b.requestDate;
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
    setSelectedRequestType('');
    setSelectedStatus('');
    setSelectedDepartment('');
  };

  const requestTypes = [...new Set(itRequests.map(request => request.requestType))];
  const statuses = [...new Set(itRequests.map(request => request.status))];
  const departments = [...new Set(itRequests.map(request => request.requestedByDepartment))];

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team IT Requests</h1>
        <p className="text-xs text-muted-foreground">Manage and track IT requests from employees</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <MessageSquare className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">{itRequests.filter(r => r.status === 'Pending').length}</div>
              <div className="text-sm text-muted-foreground">Pending</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">{itRequests.filter(r => r.status === 'In Review' || r.status === 'In Progress').length}</div>
              <div className="text-sm text-muted-foreground">In Progress</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">{itRequests.filter(r => r.status === 'Completed').length}</div>
              <div className="text-sm text-muted-foreground">Completed</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <DollarSign className="h-5 w-5" style={{ color: '#9E9E9E' }} />
            <div>
              <div className="text-2xl font-bold">${itRequests.reduce((sum, r) => sum + (r.estimatedCost || 0), 0).toLocaleString()}</div>
              <div className="text-sm text-muted-foreground">Total Cost</div>
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
                placeholder="Search requests, employees, or categories..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search IT requests"
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
                value={selectedRequestType}
                onChange={(e) => setSelectedRequestType(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by request type"
                id="request-type-filter"
              >
                <option value="">All Request Types</option>
                {requestTypes.map(type => (
                  <option key={type} value={type}>{type}</option>
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
                  onClick={() => handleSort('title')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'title' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Title
                  {sortBy === 'title' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('requestType')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'requestType' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Request Type
                  {sortBy === 'requestType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('requestedBy')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'requestedBy' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Requested By
                  {sortBy === 'requestedBy' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  onClick={() => handleSort('requestDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'requestDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Request Date
                  {sortBy === 'requestDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                    onClick={() => handleSort('title')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Request
                    {sortBy === 'title' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('requestType')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Type
                    {sortBy === 'requestType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  Priority
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('requestedBy')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Requested By
                    {sortBy === 'requestedBy' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                    onClick={() => handleSort('requestDate')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Request Date
                    {sortBy === 'requestDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  Cost
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedRequests.map((request) => {
                const [firstName, lastName] = request.requestedBy.split(' ');
                const avatarColor = generateAvatarColor(firstName, lastName);
                const avatarInitials = generateAvatarInitials(firstName, lastName);
                
                return (
                  <tr key={request.id} className="hover:bg-gray-50">
                    <td className="py-2 px-6">
                      <div className="flex items-center gap-3">
                        {getRequestTypeIcon(request.requestType)}
                        <div>
                          <div className="text-sm font-medium text-gray-900">{request.title}</div>
                          <div className="text-xs text-gray-500">{request.category}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-2">
                        {getRequestTypeIcon(request.requestType)}
                        {getRequestTypeBadge(request.requestType)}
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      {getPriorityBadge(request.priority)}
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-3">
                        <div 
                          className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-medium"
                          style={{ backgroundColor: avatarColor }}
                        >
                          {request.avatar ? (
                            <img 
                              src={request.avatar} 
                              alt={request.requestedBy}
                              className="w-8 h-8 rounded-full object-cover"
                            />
                          ) : (
                            avatarInitials
                          )}
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">{request.requestedBy}</div>
                          <div className="text-xs text-gray-500">{request.requestedByJobTitle}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      {getStatusBadge(request.status)}
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900">{new Date(request.requestDate).toLocaleDateString()}</span>
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900 font-medium">
                        {request.estimatedCost ? `${request.currency} ${request.estimatedCost.toFixed(2)}` : 'N/A'}
                      </span>
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-2">
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`View details for ${request.title}`}
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Edit ${request.title}`}
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Delete ${request.title}`}
                        >
                          <Trash2 className="w-4 h-4" />
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
