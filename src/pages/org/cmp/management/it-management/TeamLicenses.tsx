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
  MessageSquare
} from 'lucide-react';

interface License {
  id: string;
  softwareName: string;
  softwareType: 'Operating System' | 'Productivity' | 'Development' | 'Design' | 'Security' | 'Database' | 'Cloud Service' | 'Other';
  vendor: string;
  version: string;
  licenseKey: string;
  licenseType: 'Perpetual' | 'Subscription' | 'Volume' | 'Enterprise' | 'Trial' | 'Free';
  status: 'Active' | 'Expired' | 'Expiring Soon' | 'Suspended' | 'Cancelled' | 'Unused';
  assignedEmployeeId: string;
  assignedEmployeeName: string;
  assignedEmployeeEmail: string;
  assignedEmployeeJobTitle: string;
  assignedEmployeeDepartment: string;
  assignedEmployeeLocation: string;
  purchaseDate: string;
  activationDate: string;
  expirationDate: string;
  renewalDate?: string;
  cost: number;
  currency: string;
  seats: number;
  usedSeats: number;
  notes?: string;
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
    case 'Active':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
          Active
        </span>
      );
    case 'Expired':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
          Expired
        </span>
      );
    case 'Expiring Soon':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          Expiring Soon
        </span>
      );
    case 'Suspended':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
          Suspended
        </span>
      );
    case 'Cancelled':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          Cancelled
        </span>
      );
    case 'Unused':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
          Unused
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

const getSoftwareTypeIcon = (softwareType: string) => {
  switch (softwareType) {
    case 'Operating System':
      return <Monitor className="w-4 h-4 text-status-blue" />;
    case 'Productivity':
      return <FileText className="w-4 h-4 text-status-green" />;
    case 'Development':
      return <Settings className="w-4 h-4 text-status-purple" />;
    case 'Design':
      return <Laptop className="w-4 h-4 text-status-purple" />;
    case 'Security':
      return <Shield className="w-4 h-4 text-status-red" />;
    case 'Database':
      return <HardDrive className="w-4 h-4 text-status-blue" />;
    case 'Cloud Service':
      return <Wifi className="w-4 h-4 text-status-blue" />;
    default:
      return <Settings className="w-4 h-4 text-status-blue" />;
  }
};

const getSoftwareTypeBadge = (softwareType: string) => {
  const typeConfig = {
    'Operating System': { bg: 'bg-blue-50', text: 'text-status-blue' },
    'Productivity': { bg: 'bg-green-50', text: 'text-status-green' },
    'Development': { bg: 'bg-purple-50', text: 'text-status-purple' },
    'Design': { bg: 'bg-purple-50', text: 'text-status-purple' },
    'Security': { bg: 'bg-red-50', text: 'text-status-red' },
    'Database': { bg: 'bg-blue-50', text: 'text-status-blue' },
    'Cloud Service': { bg: 'bg-blue-50', text: 'text-status-blue' },
    'Other': { bg: 'bg-gray-50', text: 'text-status-gray' }
  };
  
  const config = typeConfig[softwareType as keyof typeof typeConfig] || typeConfig['Other'];
  
  return (
    <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {softwareType}
    </span>
  );
};

const getLicenseTypeBadge = (licenseType: string) => {
  const typeConfig = {
    'Perpetual': { bg: 'bg-green-100', text: 'text-green-800' },
    'Subscription': { bg: 'bg-blue-100', text: 'text-blue-800' },
    'Volume': { bg: 'bg-purple-100', text: 'text-purple-800' },
    'Enterprise': { bg: 'bg-indigo-100', text: 'text-indigo-800' },
    'Trial': { bg: 'bg-orange-100', text: 'text-orange-800' },
    'Free': { bg: 'bg-gray-100', text: 'text-gray-800' }
  };
  
  const config = typeConfig[licenseType as keyof typeof typeConfig] || typeConfig['Free'];
  
  return (
    <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {licenseType}
    </span>
  );
};

export default function TeamLicenses() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'softwareName' | 'softwareType' | 'assignedEmployeeName' | 'status' | 'expirationDate'>('softwareName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedSoftwareType, setSelectedSoftwareType] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedDepartment, setSelectedDepartment] = useState<string[]>([]);
  const [showSoftwareTypeDropdown, setShowSoftwareTypeDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showDepartmentDropdown, setShowDepartmentDropdown] = useState(false);
  const [softwareTypeSearchTerm, setSoftwareTypeSearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [departmentSearchTerm, setDepartmentSearchTerm] = useState('');

  useEffect(() => {
    // Register submodule tabs for IT Management section
    registerSubmodules('IT Management', [
      { id: 'team-devices', label: 'Team Devices', href: '/org/cmp/management/it-management/team-devices', icon: Laptop },
      { id: 'team-licenses', label: 'Team Licenses', href: '/org/cmp/management/it-management/team-licenses', icon: Shield },
      { id: 'team-it-requests', label: 'Team IT Requests', href: '/org/cmp/management/it-management/team-it-requests', icon: MessageSquare }
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowSoftwareTypeDropdown(false);
        setShowStatusDropdown(false);
        setShowDepartmentDropdown(false);
        // Clear search terms when closing dropdowns
        setSoftwareTypeSearchTerm('');
        setStatusSearchTerm('');
        setDepartmentSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const licenses: License[] = [
    {
      id: '1',
      softwareName: 'Microsoft Office 365',
      softwareType: 'Productivity',
      vendor: 'Microsoft',
      version: '2023',
      licenseKey: 'MS-365-XXXX-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-001',
      assignedEmployeeName: 'Amanda Foster',
      assignedEmployeeEmail: 'amanda.foster@arquiluz.com',
      assignedEmployeeJobTitle: 'Senior UX Designer',
      assignedEmployeeDepartment: 'Design',
      assignedEmployeeLocation: 'San Francisco, CA',
      purchaseDate: '2023-01-15',
      activationDate: '2023-01-20',
      expirationDate: '2024-01-20',
      renewalDate: '2024-01-15',
      cost: 150.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Annual subscription for design team'
    },
    {
      id: '2',
      softwareName: 'Adobe Creative Cloud',
      softwareType: 'Design',
      vendor: 'Adobe',
      version: '2024',
      licenseKey: 'ADOBE-CC-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-002',
      assignedEmployeeName: 'Marcus Chen',
      assignedEmployeeEmail: 'marcus.chen@arquiluz.com',
      assignedEmployeeJobTitle: 'Full Stack Developer',
      assignedEmployeeDepartment: 'Engineering',
      assignedEmployeeLocation: 'Austin, TX',
      purchaseDate: '2023-03-01',
      activationDate: '2023-03-05',
      expirationDate: '2024-03-01',
      renewalDate: '2024-02-15',
      cost: 52.99,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Complete Creative Suite for development'
    },
    {
      id: '3',
      softwareName: 'Visual Studio Professional',
      softwareType: 'Development',
      vendor: 'Microsoft',
      version: '2022',
      licenseKey: 'VS-PRO-XXXX-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-003',
      assignedEmployeeName: 'Elena Rodriguez',
      assignedEmployeeEmail: 'elena.rodriguez@arquiluz.com',
      assignedEmployeeJobTitle: 'Product Manager',
      assignedEmployeeDepartment: 'Product',
      assignedEmployeeLocation: 'Miami, FL',
      purchaseDate: '2023-02-10',
      activationDate: '2023-02-15',
      expirationDate: '2024-02-10',
      renewalDate: '2024-01-25',
      cost: 45.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Professional development environment'
    },
    {
      id: '4',
      softwareName: 'Slack Business+',
      softwareType: 'Productivity',
      vendor: 'Slack Technologies',
      version: 'Latest',
      licenseKey: 'SLACK-BIZ-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-004',
      assignedEmployeeName: 'James Wilson',
      assignedEmployeeEmail: 'james.wilson@arquiluz.com',
      assignedEmployeeJobTitle: 'Marketing Specialist',
      assignedEmployeeDepartment: 'Marketing',
      assignedEmployeeLocation: 'Seattle, WA',
      purchaseDate: '2023-01-01',
      activationDate: '2023-01-01',
      expirationDate: '2024-01-01',
      renewalDate: '2023-12-15',
      cost: 12.50,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Team communication platform'
    },
    {
      id: '5',
      softwareName: 'Windows 11 Pro',
      softwareType: 'Operating System',
      vendor: 'Microsoft',
      version: '11 Pro',
      licenseKey: 'WIN11-PRO-XXXX-XXXX-XXXX',
      licenseType: 'Perpetual',
      status: 'Active',
      assignedEmployeeId: 'emp-005',
      assignedEmployeeName: 'Sophie Anderson',
      assignedEmployeeEmail: 'sophie.anderson@arquiluz.com',
      assignedEmployeeJobTitle: 'Data Analyst',
      assignedEmployeeDepartment: 'Analytics',
      assignedEmployeeLocation: 'Denver, CO',
      purchaseDate: '2023-08-15',
      activationDate: '2023-08-20',
      expirationDate: 'N/A',
      cost: 199.99,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Perpetual license for business use'
    },
    {
      id: '6',
      softwareName: 'AWS Business Support',
      softwareType: 'Cloud Service',
      vendor: 'Amazon Web Services',
      version: 'Business',
      licenseKey: 'AWS-BIZ-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-006',
      assignedEmployeeName: 'Alex Thompson',
      assignedEmployeeEmail: 'alex.thompson@arquiluz.com',
      assignedEmployeeJobTitle: 'DevOps Engineer',
      assignedEmployeeDepartment: 'Engineering',
      assignedEmployeeLocation: 'Portland, OR',
      purchaseDate: '2023-06-01',
      activationDate: '2023-06-01',
      expirationDate: '2024-06-01',
      renewalDate: '2024-05-15',
      cost: 100.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Cloud infrastructure support'
    },
    {
      id: '7',
      softwareName: 'Norton Antivirus Business',
      softwareType: 'Security',
      vendor: 'NortonLifeLock',
      version: '2024',
      licenseKey: 'NORTON-BIZ-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Expiring Soon',
      assignedEmployeeId: 'emp-007',
      assignedEmployeeName: 'Maria Garcia',
      assignedEmployeeEmail: 'maria.garcia@arquiluz.com',
      assignedEmployeeJobTitle: 'HR Coordinator',
      assignedEmployeeDepartment: 'Human Resources',
      assignedEmployeeLocation: 'Phoenix, AZ',
      purchaseDate: '2023-01-15',
      activationDate: '2023-01-20',
      expirationDate: '2024-01-20',
      renewalDate: '2024-01-10',
      cost: 89.99,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Enterprise antivirus protection'
    },
    {
      id: '8',
      softwareName: 'Figma Professional',
      softwareType: 'Design',
      vendor: 'Figma',
      version: 'Latest',
      licenseKey: 'FIGMA-PRO-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-008',
      assignedEmployeeName: 'David Park',
      assignedEmployeeEmail: 'david.park@arquiluz.com',
      assignedEmployeeJobTitle: 'Sales Manager',
      assignedEmployeeDepartment: 'Sales',
      assignedEmployeeLocation: 'Los Angeles, CA',
      purchaseDate: '2023-04-01',
      activationDate: '2023-04-05',
      expirationDate: '2024-04-01',
      renewalDate: '2024-03-15',
      cost: 15.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'UI/UX design collaboration tool'
    },
    {
      id: '9',
      softwareName: 'PostgreSQL Enterprise',
      softwareType: 'Database',
      vendor: 'PostgreSQL Global Development Group',
      version: '15',
      licenseKey: 'POSTGRES-ENT-XXXX',
      licenseType: 'Enterprise',
      status: 'Active',
      assignedEmployeeId: 'emp-009',
      assignedEmployeeName: 'Rachel Brown',
      assignedEmployeeEmail: 'rachel.brown@arquiluz.com',
      assignedEmployeeJobTitle: 'Content Writer',
      assignedEmployeeDepartment: 'Marketing',
      assignedEmployeeLocation: 'Chicago, IL',
      purchaseDate: '2023-05-10',
      activationDate: '2023-05-15',
      expirationDate: '2024-05-10',
      renewalDate: '2024-04-25',
      cost: 500.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Enterprise database management'
    },
    {
      id: '10',
      softwareName: 'GitHub Enterprise',
      softwareType: 'Development',
      vendor: 'GitHub',
      version: 'Enterprise',
      licenseKey: 'GITHUB-ENT-XXXX-XXXX',
      licenseType: 'Subscription',
      status: 'Active',
      assignedEmployeeId: 'emp-010',
      assignedEmployeeName: 'Kevin Lee',
      assignedEmployeeEmail: 'kevin.lee@arquiluz.com',
      assignedEmployeeJobTitle: 'QA Engineer',
      assignedEmployeeDepartment: 'Engineering',
      assignedEmployeeLocation: 'Boston, MA',
      purchaseDate: '2023-07-01',
      activationDate: '2023-07-01',
      expirationDate: '2024-07-01',
      renewalDate: '2024-06-15',
      cost: 21.00,
      currency: 'USD',
      seats: 1,
      usedSeats: 1,
      notes: 'Version control and collaboration'
    }
  ];

  const filteredLicenses = useMemo(() => {
    return licenses.filter(license => {
      const matchesSearch = 
        license.softwareName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.vendor.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.version.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.licenseKey.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.assignedEmployeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.assignedEmployeeJobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        license.assignedEmployeeDepartment.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesSoftwareType = selectedSoftwareType.length === 0 || selectedSoftwareType.includes(license.softwareType);
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(license.status);
      const matchesDepartment = selectedDepartment.length === 0 || selectedDepartment.includes(license.assignedEmployeeDepartment);
      
      return matchesSearch && matchesSoftwareType && matchesStatus && matchesDepartment;
    });
  }, [licenses, searchTerm, selectedSoftwareType, selectedStatus, selectedDepartment]);

  const sortedLicenses = useMemo(() => {
    return [...filteredLicenses].sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;
      
      switch (sortBy) {
        case 'softwareName':
          aValue = a.softwareName;
          bValue = b.softwareName;
          break;
        case 'softwareType':
          aValue = a.softwareType;
          bValue = b.softwareType;
          break;
        case 'assignedEmployeeName':
          aValue = a.assignedEmployeeName;
          bValue = b.assignedEmployeeName;
          break;
        case 'status':
          aValue = a.status;
          bValue = b.status;
          break;
        case 'expirationDate':
          aValue = new Date(a.expirationDate).getTime();
          bValue = new Date(b.expirationDate).getTime();
          break;
        default:
          aValue = a.softwareName;
          bValue = b.softwareName;
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
  }, [filteredLicenses, sortBy, sortOrder]);

  const totalPages = Math.ceil(sortedLicenses.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedLicenses = sortedLicenses.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedSoftwareType([]);
    setSelectedStatus([]);
    setSelectedDepartment([]);
    setSoftwareTypeSearchTerm('');
    setStatusSearchTerm('');
    setDepartmentSearchTerm('');
  };

  // Helper functions for multi-select
  const handleSoftwareTypeToggle = (softwareType: string) => {
    setSelectedSoftwareType(prev => 
      prev.includes(softwareType) 
        ? prev.filter(s => s !== softwareType)
        : [...prev, softwareType]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleDepartmentToggle = (department: string) => {
    setSelectedDepartment(prev => 
      prev.includes(department) 
        ? prev.filter(d => d !== department)
        : [...prev, department]
    );
  };

  // Filter options based on search terms
  const getFilteredSoftwareTypeOptions = () => {
    const softwareTypes = [...new Set(licenses.map(license => license.softwareType))];
    if (!softwareTypeSearchTerm) return softwareTypes;
    return softwareTypes.filter(type => 
      type.toLowerCase().includes(softwareTypeSearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statuses = [...new Set(licenses.map(license => license.status))];
    if (!statusSearchTerm) return statuses;
    return statuses.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredDepartmentOptions = () => {
    const departments = [...new Set(licenses.map(license => license.assignedEmployeeDepartment))];
    if (!departmentSearchTerm) return departments;
    return departments.filter(dept => 
      dept.toLowerCase().includes(departmentSearchTerm.toLowerCase())
    );
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Licenses</h1>
        <p className="text-xs text-muted-foreground">Manage and track software licenses assigned to employees</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Shield className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">{licenses.filter(l => l.status === 'Active').length}</div>
              <div className="text-sm text-muted-foreground">Active Licenses</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">{licenses.filter(l => l.status === 'Expiring Soon').length}</div>
              <div className="text-sm text-muted-foreground">Expiring Soon</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <XCircle className="h-5 w-5 text-status-red" />
            <div>
              <div className="text-2xl font-bold">{licenses.filter(l => l.status === 'Expired').length}</div>
              <div className="text-sm text-muted-foreground">Expired</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <DollarSign className="h-5 w-5" style={{ color: '#9E9E9E' }} />
            <div>
              <div className="text-2xl font-bold">${licenses.reduce((sum, l) => sum + l.cost, 0).toLocaleString()}</div>
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
                placeholder="Search software, employees, or license keys..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search licenses"
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
              {/* Software Type Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowSoftwareTypeDropdown(!showSoftwareTypeDropdown)}>
                  <span className="text-gray-700">
                    {selectedSoftwareType.length === 0 ? 'All Software Types' : 
                     selectedSoftwareType.length === 1 ? selectedSoftwareType[0] :
                     `${selectedSoftwareType.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showSoftwareTypeDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search software types..."
                          value={softwareTypeSearchTerm}
                          onChange={(e) => setSoftwareTypeSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedSoftwareType.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedSoftwareType([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedSoftwareType.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredSoftwareTypeOptions().map((softwareType) => (
                      <div key={softwareType} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleSoftwareTypeToggle(softwareType)}>
                        <input type="checkbox" checked={selectedSoftwareType.includes(softwareType)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{softwareType}</span>
                      </div>
                    ))}
                    {getFilteredSoftwareTypeOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No software types found
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Status Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowStatusDropdown(!showStatusDropdown)}>
                  <span className="text-gray-700">
                    {selectedStatus.length === 0 ? 'All Statuses' : 
                     selectedStatus.length === 1 ? selectedStatus[0] :
                     `${selectedStatus.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showStatusDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search statuses..."
                          value={statusSearchTerm}
                          onChange={(e) => setStatusSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedStatus.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedStatus([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedStatus.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredStatusOptions().map((status) => (
                      <div key={status} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleStatusToggle(status)}>
                        <input type="checkbox" checked={selectedStatus.includes(status)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{status}</span>
                      </div>
                    ))}
                    {getFilteredStatusOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No statuses found
                      </div>
                    )}
                  </div>
                )}
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
                  onClick={() => handleSort('softwareName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'softwareName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Software Name
                  {sortBy === 'softwareName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('softwareType')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'softwareType' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Software Type
                  {sortBy === 'softwareType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('assignedEmployeeName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'assignedEmployeeName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Employee
                  {sortBy === 'assignedEmployeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  onClick={() => handleSort('expirationDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'expirationDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Expiration Date
                  {sortBy === 'expirationDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                    onClick={() => handleSort('softwareName')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Software
                    {sortBy === 'softwareName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('softwareType')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Type
                    {sortBy === 'softwareType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  License Type
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('assignedEmployeeName')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Assigned To
                    {sortBy === 'assignedEmployeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                    onClick={() => handleSort('expirationDate')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Expiration
                    {sortBy === 'expirationDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  Cost
                </th>
                <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedLicenses.map((license) => {
                const [firstName, lastName] = license.assignedEmployeeName.split(' ');
                const avatarColor = generateAvatarColor(firstName, lastName);
                const avatarInitials = generateAvatarInitials(firstName, lastName);
                
                return (
                  <tr key={license.id} className="hover:bg-gray-50">
                    <td className="py-2 px-6">
                      <div className="flex items-center gap-3">
                        {getSoftwareTypeIcon(license.softwareType)}
                        <div>
                          <div className="text-sm font-medium text-gray-900">{license.softwareName}</div>
                          <div className="text-xs text-gray-500">{license.vendor} {license.version}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-2">
                        {getSoftwareTypeIcon(license.softwareType)}
                        {getSoftwareTypeBadge(license.softwareType)}
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      {getLicenseTypeBadge(license.licenseType)}
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-3">
                        <div 
                          className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-medium"
                          style={{ backgroundColor: avatarColor }}
                        >
                          {license.avatar ? (
                            <img 
                              src={license.avatar} 
                              alt={license.assignedEmployeeName}
                              className="w-8 h-8 rounded-full object-cover"
                            />
                          ) : (
                            avatarInitials
                          )}
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">{license.assignedEmployeeName}</div>
                          <div className="text-xs text-gray-500">{license.assignedEmployeeJobTitle}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      {getStatusBadge(license.status)}
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900">
                        {license.expirationDate === 'N/A' ? 'N/A' : new Date(license.expirationDate).toLocaleDateString()}
                      </span>
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900 font-medium">
                        {license.currency} {license.cost.toFixed(2)}
                      </span>
                    </td>
                    <td className="py-2 px-2 w-24">
                      <div className="flex items-center">
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`View details for ${license.softwareName}`}
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Edit ${license.softwareName}`}
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Delete ${license.softwareName}`}
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, sortedLicenses.length)} of {sortedLicenses.length}
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