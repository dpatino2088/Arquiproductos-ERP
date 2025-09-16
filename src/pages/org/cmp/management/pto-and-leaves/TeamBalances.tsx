import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Users, 
  Calendar, 
  Search, 
  Filter,
  Plus,
  Upload,
  Edit,
  Trash2,
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
  Heart,
  Coffee,
  Plane
} from 'lucide-react';

interface EmployeeBalance {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  jobTitle: string;
  department: string;
  status: 'Active' | 'Suspended' | 'Onboarding' | 'On Leave';
  location: string;
  startDate: string;
  avatar?: string;
  phone?: string;
  vacationBalance: {
    total: number;
    used: number;
    remaining: number;
    pending: number;
  };
  sickLeaveBalance: {
    total: number;
    used: number;
    remaining: number;
    pending: number;
  };
  personalDays: {
    total: number;
    used: number;
    remaining: number;
  };
  lastUpdated: string;
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

export default function TeamBalances() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'firstName' | 'jobTitle' | 'department' | 'vacationBalance' | 'sickLeaveBalance'>('firstName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedDepartment, setSelectedDepartment] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedLocation, setSelectedLocation] = useState<string[]>([]);
  const [showDepartmentDropdown, setShowDepartmentDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  const [departmentSearchTerm, setDepartmentSearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [locationSearchTerm, setLocationSearchTerm] = useState('');

  useEffect(() => {
    // Register submodule tabs for PTO and Leaves section
    registerSubmodules('PTO & Leaves', [
      { id: 'team-balances', label: 'Team Balances', href: '/org/cmp/management/pto-and-leaves/team-balances', icon: Users },
      { id: 'requests', label: 'Team Leave Requests', href: '/org/cmp/management/pto-and-leaves/team-leave-requests', icon: Clock },
      { id: 'calendar', label: 'Team Leave Calendar', href: '/org/cmp/management/pto-and-leaves/team-leave-calendar', icon: Calendar }
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowDepartmentDropdown(false);
        setShowStatusDropdown(false);
        setShowLocationDropdown(false);
        // Clear search terms when closing dropdowns
        setDepartmentSearchTerm('');
        setStatusSearchTerm('');
        setLocationSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const employeeBalances: EmployeeBalance[] = [
    {
      id: '1',
      firstName: 'Alex',
      lastName: 'Manager',
      email: 'alex.manager@arquiluz.com',
      jobTitle: 'Chief Executive Officer',
      department: 'Executive',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '12/31/2017',
      avatar: undefined,
      vacationBalance: { total: 25, used: 8, remaining: 17, pending: 2 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 2, remaining: 3 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '2',
      firstName: 'Alex',
      lastName: 'Thompson',
      email: 'alex.thompson@arquiluz.com',
      jobTitle: 'Senior Software Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '3/15/2019',
      avatar: undefined,
      vacationBalance: { total: 20, used: 12, remaining: 8, pending: 1 },
      sickLeaveBalance: { total: 10, used: 3, remaining: 7, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-14'
    },
    {
      id: '3',
      firstName: 'Sarah',
      lastName: 'Johnson',
      email: 'sarah.johnson@arquiluz.com',
      jobTitle: 'Product Manager',
      department: 'Product',
      status: 'Active',
      location: 'New York, NY',
      startDate: '6/1/2020',
      avatar: undefined,
      vacationBalance: { total: 20, used: 5, remaining: 15, pending: 3 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '4',
      firstName: 'Michael',
      lastName: 'Chen',
      email: 'michael.chen@arquiluz.com',
      jobTitle: 'UX Designer',
      department: 'Design',
      status: 'Active',
      location: 'Seattle, WA',
      startDate: '9/10/2020',
      avatar: undefined,
      vacationBalance: { total: 20, used: 18, remaining: 2, pending: 0 },
      sickLeaveBalance: { total: 10, used: 2, remaining: 8, pending: 1 },
      personalDays: { total: 5, used: 3, remaining: 2 },
      lastUpdated: '2024-01-13'
    },
    {
      id: '5',
      firstName: 'Emily',
      lastName: 'Rodriguez',
      email: 'emily.rodriguez@arquiluz.com',
      jobTitle: 'Marketing Specialist',
      department: 'Marketing',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '2/28/2021',
      avatar: undefined,
      vacationBalance: { total: 15, used: 3, remaining: 12, pending: 1 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '6',
      firstName: 'David',
      lastName: 'Kim',
      email: 'david.kim@arquiluz.com',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '11/15/2021',
      avatar: undefined,
      vacationBalance: { total: 15, used: 10, remaining: 5, pending: 2 },
      sickLeaveBalance: { total: 10, used: 4, remaining: 6, pending: 0 },
      personalDays: { total: 5, used: 2, remaining: 3 },
      lastUpdated: '2024-01-14'
    },
    {
      id: '7',
      firstName: 'Lisa',
      lastName: 'Wang',
      email: 'lisa.wang@arquiluz.com',
      jobTitle: 'Data Analyst',
      department: 'Analytics',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '4/20/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 7, remaining: 8, pending: 1 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '8',
      firstName: 'James',
      lastName: 'Wilson',
      email: 'james.wilson@arquiluz.com',
      jobTitle: 'Sales Representative',
      department: 'Sales',
      status: 'Active',
      location: 'New York, NY',
      startDate: '7/8/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 14, remaining: 1, pending: 0 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 4, remaining: 1 },
      lastUpdated: '2024-01-13'
    },
    {
      id: '9',
      firstName: 'Maria',
      lastName: 'Garcia',
      email: 'maria.garcia@arquiluz.com',
      jobTitle: 'HR Manager',
      department: 'Human Resources',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '1/10/2023',
      avatar: undefined,
      vacationBalance: { total: 20, used: 6, remaining: 14, pending: 1 },
      sickLeaveBalance: { total: 10, used: 2, remaining: 8, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '10',
      firstName: 'Robert',
      lastName: 'Taylor',
      email: 'robert.taylor@arquiluz.com',
      jobTitle: 'Frontend Developer',
      department: 'Engineering',
      status: 'On Leave',
      location: 'Seattle, WA',
      startDate: '5/3/2023',
      avatar: undefined,
      vacationBalance: { total: 15, used: 15, remaining: 0, pending: 0 },
      sickLeaveBalance: { total: 10, used: 3, remaining: 7, pending: 0 },
      personalDays: { total: 5, used: 5, remaining: 0 },
      lastUpdated: '2024-01-12'
    },
    {
      id: '11',
      firstName: 'Jennifer',
      lastName: 'Martinez',
      email: 'jennifer.martinez@arquiluz.com',
      jobTitle: 'Content Strategist',
      department: 'Marketing',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '6/8/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 4, remaining: 11, pending: 1 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '12',
      firstName: 'Kevin',
      lastName: 'Brown',
      email: 'kevin.brown@arquiluz.com',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '11/1/2023',
      avatar: undefined,
      vacationBalance: { total: 15, used: 2, remaining: 13, pending: 0 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '13',
      firstName: 'Michelle',
      lastName: 'Garcia',
      email: 'michelle.garcia@arquiluz.com',
      jobTitle: 'HR Coordinator',
      department: 'Human Resources',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '4/3/2021',
      avatar: undefined,
      vacationBalance: { total: 20, used: 9, remaining: 11, pending: 2 },
      sickLeaveBalance: { total: 10, used: 2, remaining: 8, pending: 0 },
      personalDays: { total: 5, used: 2, remaining: 3 },
      lastUpdated: '2024-01-14'
    },
    {
      id: '14',
      firstName: 'Daniel',
      lastName: 'Anderson',
      email: 'daniel.anderson@arquiluz.com',
      jobTitle: 'Product Manager',
      department: 'Product',
      status: 'Active',
      location: 'Seattle, WA',
      startDate: '9/14/2020',
      avatar: undefined,
      vacationBalance: { total: 20, used: 16, remaining: 4, pending: 1 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 3, remaining: 2 },
      lastUpdated: '2024-01-13'
    },
    {
      id: '15',
      firstName: 'Ashley',
      lastName: 'Thomas',
      email: 'ashley.thomas@arquiluz.com',
      jobTitle: 'Frontend Developer',
      department: 'Engineering',
      status: 'Suspended',
      location: 'Portland, OR',
      startDate: '2/28/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 8, remaining: 7, pending: 0 },
      sickLeaveBalance: { total: 10, used: 2, remaining: 8, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-12'
    },
    {
      id: '16',
      firstName: 'Christopher',
      lastName: 'Jackson',
      email: 'christopher.jackson@arquiluz.com',
      jobTitle: 'Sales Representative',
      department: 'Sales',
      status: 'Active',
      location: 'New York, NY',
      startDate: '7/19/2021',
      avatar: undefined,
      vacationBalance: { total: 15, used: 11, remaining: 4, pending: 1 },
      sickLeaveBalance: { total: 10, used: 3, remaining: 7, pending: 0 },
      personalDays: { total: 5, used: 2, remaining: 3 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '17',
      firstName: 'Amanda',
      lastName: 'White',
      email: 'amanda.white@arquiluz.com',
      jobTitle: 'Marketing Specialist',
      department: 'Marketing',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '10/5/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 6, remaining: 9, pending: 2 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '18',
      firstName: 'Matthew',
      lastName: 'Harris',
      email: 'matthew.harris@arquiluz.com',
      jobTitle: 'QA Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '12/12/2021',
      avatar: undefined,
      vacationBalance: { total: 15, used: 3, remaining: 12, pending: 0 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-14'
    },
    {
      id: '19',
      firstName: 'Jessica',
      lastName: 'Clark',
      email: 'jessica.clark@arquiluz.com',
      jobTitle: 'UI Designer',
      department: 'Design',
      status: 'On Leave',
      location: 'Seattle, WA',
      startDate: '3/25/2023',
      avatar: undefined,
      vacationBalance: { total: 15, used: 12, remaining: 3, pending: 0 },
      sickLeaveBalance: { total: 10, used: 4, remaining: 6, pending: 0 },
      personalDays: { total: 5, used: 4, remaining: 1 },
      lastUpdated: '2024-01-13'
    },
    {
      id: '20',
      firstName: 'Andrew',
      lastName: 'Lewis',
      email: 'andrew.lewis@arquiluz.com',
      jobTitle: 'Backend Developer',
      department: 'Engineering',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '8/7/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 7, remaining: 8, pending: 1 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 2, remaining: 3 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '21',
      firstName: 'Nicole',
      lastName: 'Walker',
      email: 'nicole.walker@arquiluz.com',
      jobTitle: 'Data Scientist',
      department: 'Analytics',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '1/15/2023',
      avatar: undefined,
      vacationBalance: { total: 15, used: 5, remaining: 10, pending: 0 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '22',
      firstName: 'Ryan',
      lastName: 'Hall',
      email: 'ryan.hall@arquiluz.com',
      jobTitle: 'Sales Manager',
      department: 'Sales',
      status: 'Active',
      location: 'New York, NY',
      startDate: '5/20/2021',
      avatar: undefined,
      vacationBalance: { total: 20, used: 13, remaining: 7, pending: 2 },
      sickLeaveBalance: { total: 10, used: 2, remaining: 8, pending: 0 },
      personalDays: { total: 5, used: 3, remaining: 2 },
      lastUpdated: '2024-01-14'
    },
    {
      id: '23',
      firstName: 'Stephanie',
      lastName: 'Young',
      email: 'stephanie.young@arquiluz.com',
      jobTitle: 'UX Researcher',
      department: 'Design',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '11/30/2022',
      avatar: undefined,
      vacationBalance: { total: 15, used: 4, remaining: 11, pending: 1 },
      sickLeaveBalance: { total: 10, used: 1, remaining: 9, pending: 0 },
      personalDays: { total: 5, used: 1, remaining: 4 },
      lastUpdated: '2024-01-15'
    },
    {
      id: '24',
      firstName: 'Brandon',
      lastName: 'Allen',
      email: 'brandon.allen@arquiluz.com',
      jobTitle: 'System Administrator',
      department: 'Engineering',
      status: 'Active',
      location: 'Seattle, WA',
      startDate: '6/12/2023',
      avatar: undefined,
      vacationBalance: { total: 15, used: 2, remaining: 13, pending: 0 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-16'
    },
    {
      id: '25',
      firstName: 'Rachel',
      lastName: 'King',
      email: 'rachel.king@arquiluz.com',
      jobTitle: 'Content Manager',
      department: 'Marketing',
      status: 'Onboarding',
      location: 'Portland, OR',
      startDate: '1/8/2024',
      avatar: undefined,
      vacationBalance: { total: 15, used: 0, remaining: 15, pending: 0 },
      sickLeaveBalance: { total: 10, used: 0, remaining: 10, pending: 0 },
      personalDays: { total: 5, used: 0, remaining: 5 },
      lastUpdated: '2024-01-16'
    }
  ];

  // Filter and sort employees
  const filteredEmployees = useMemo(() => {
    return employeeBalances.filter(employee => {
      // Search filter
      const matchesSearch = !searchTerm || 
        employee.firstName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        employee.lastName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        employee.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
        employee.jobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        employee.department.toLowerCase().includes(searchTerm.toLowerCase());

      // Department filter
      const matchesDepartment = selectedDepartment.length === 0 || selectedDepartment.includes(employee.department);

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(employee.status);

      // Location filter
      const matchesLocation = selectedLocation.length === 0 || selectedLocation.includes(employee.location);

      return matchesSearch && matchesDepartment && matchesStatus && matchesLocation;
    });
  }, [searchTerm, employeeBalances, selectedDepartment, selectedStatus, selectedLocation]);

  // Apply sorting
  const sortedEmployees = useMemo(() => {
    return filteredEmployees.sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;

      switch (sortBy) {
        case 'firstName':
          aValue = a.firstName.toLowerCase();
          bValue = b.firstName.toLowerCase();
          break;
        case 'jobTitle':
          aValue = a.jobTitle.toLowerCase();
          bValue = b.jobTitle.toLowerCase();
          break;
        case 'department':
          aValue = a.department.toLowerCase();
          bValue = b.department.toLowerCase();
          break;
        case 'vacationBalance':
          aValue = a.vacationBalance.remaining;
          bValue = b.vacationBalance.remaining;
          break;
        case 'sickLeaveBalance':
          aValue = a.sickLeaveBalance.remaining;
          bValue = b.sickLeaveBalance.remaining;
          break;
        default:
          aValue = a.firstName.toLowerCase();
          bValue = b.firstName.toLowerCase();
      }

      if (typeof aValue === 'number' && typeof bValue === 'number') {
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else {
        const strA = aValue as string;
        const strB = bValue as string;
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [filteredEmployees, sortBy, sortOrder]);

  // Pagination calculations
  const totalPages = Math.ceil(sortedEmployees.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedEmployees = sortedEmployees.slice(startIndex, startIndex + itemsPerPage);

  // Reset to first page when search changes
  useMemo(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedDepartment([]);
    setSelectedStatus([]);
    setSelectedLocation([]);
    setSearchTerm('');
    setDepartmentSearchTerm('');
    setStatusSearchTerm('');
    setLocationSearchTerm('');
  };

  // Helper functions for multi-select
  const handleDepartmentToggle = (department: string) => {
    setSelectedDepartment(prev => 
      prev.includes(department) 
        ? prev.filter(d => d !== department)
        : [...prev, department]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
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
    const departmentOptions = ['Executive', 'Engineering', 'Product', 'Design', 'Marketing', 'Analytics', 'Sales', 'Human Resources'];
    if (!departmentSearchTerm) return departmentOptions;
    return departmentOptions.filter(dept => 
      dept.toLowerCase().includes(departmentSearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Suspended', 'Onboarding', 'On Leave'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredLocationOptions = () => {
    const locationOptions = ['San Francisco, CA', 'New York, NY', 'Seattle, WA', 'Austin, TX', 'Portland, OR'];
    if (!locationSearchTerm) return locationOptions;
    return locationOptions.filter(location => 
      location.toLowerCase().includes(locationSearchTerm.toLowerCase())
    );
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Active':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
            Active
          </span>
        );
      case 'Suspended':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
            Suspended
          </span>
        );
      case 'Onboarding':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
            Onboarding
          </span>
        );
      case 'On Leave':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
            On Leave
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

  const getBalanceColor = (remaining: number, total: number) => {
    const percentage = (remaining / total) * 100;
    if (percentage >= 50) return 'text-status-green';
    if (percentage >= 25) return 'text-status-orange';
    return 'text-status-red';
  };

  const getBalanceBadge = (remaining: number, total: number) => {
    const percentage = (remaining / total) * 100;
    if (percentage >= 50) return 'bg-green-50 text-status-green';
    if (percentage >= 25) return 'bg-yellow-50 text-status-yellow';
    return 'bg-red-50 text-status-red';
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Team Balances</h1>
          <p className="text-xs" style={{ color: '#6B7280' }}>
            Manage PTO and leave balances for {sortedEmployees.length} employees
            {sortedEmployees.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Export
          </button>
          <button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" style={{ backgroundColor: 'var(--teal-brand-hex)' }}>
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Balance
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Plane className="h-5 w-5 text-status-blue" />
            <div>
              <div className="text-2xl font-bold">
                {employeeBalances.reduce((sum, emp) => sum + emp.vacationBalance.remaining, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Vacation Days</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Heart className="h-5 w-5 text-status-red" />
            <div>
              <div className="text-2xl font-bold">
                {employeeBalances.reduce((sum, emp) => sum + emp.sickLeaveBalance.remaining, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Sick Days</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Coffee className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">
                {employeeBalances.reduce((sum, emp) => sum + emp.personalDays.remaining, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Personal Days</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-status-purple" />
            <div>
              <div className="text-2xl font-bold">
                {employeeBalances.reduce((sum, emp) => sum + emp.vacationBalance.pending + emp.sickLeaveBalance.pending, 0)}
              </div>
              <div className="text-sm text-muted-foreground">Pending Requests</div>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center justify-between gap-3">
            {/* Search Bar */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search employees by name, email, job title, or department..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search employees"
                id="employee-search"
              />
            </div>
            
            <div className="flex items-center gap-2">
              {/* Filters Button */}
              <button
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                  showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                <Filter style={{ width: '14px', height: '14px' }} />
                Filters
              </button>

              {/* View Mode Toggle */}
              <div className="flex border border-gray-200 rounded overflow-hidden">
                <button
                  onClick={() => setViewMode('table')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'table'
                      ? 'bg-gray-300 text-black'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                  aria-label="Switch to list view"
                  title="Switch to list view"
                >
                  <List className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'grid'
                      ? 'bg-gray-300 text-black'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                  aria-label="Switch to grid view"
                  title="Switch to grid view"
                >
                  <Grid3X3 className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Advanced Filters */}
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
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

              {/* Status Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowStatusDropdown(!showStatusDropdown)}>
                  <span className="text-gray-700">
                    {selectedStatus.length === 0 ? 'All Status' : 
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
            </div>

            <div className="flex justify-between items-center">
              <button 
                onClick={clearAllFilters}
                className="text-xs text-gray-500 hover:text-gray-700"
              >
                Clear all filters
              </button>
              <div className="flex gap-3 items-center">
                <span className="text-xs text-gray-500">Sort by:</span>
                <button 
                  onClick={() => handleSort('firstName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'firstName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Name
                  {sortBy === 'firstName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  onClick={() => handleSort('vacationBalance')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'vacationBalance' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Vacation
                  {sortBy === 'vacationBalance' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('sickLeaveBalance')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'sickLeaveBalance' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Sick Leave
                  {sortBy === 'sickLeaveBalance' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                      onClick={() => handleSort('firstName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Employee
                      {sortBy === 'firstName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Status</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('vacationBalance')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Vacation Balance
                      {sortBy === 'vacationBalance' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('sickLeaveBalance')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Sick Leave Balance
                      {sortBy === 'sickLeaveBalance' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Personal Days</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Last Updated</th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedEmployees.map((employee) => (
                  <tr key={employee.id} className="border-b border-gray-100 last:border-b-0 hover:bg-gray-50">
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-3">
                        <div 
                          className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium"
                          style={{ backgroundColor: generateAvatarColor(employee.firstName, employee.lastName) }}
                        >
                          {generateAvatarInitials(employee.firstName, employee.lastName)}
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {employee.firstName} {employee.lastName}
                          </div>
                          <div className="text-xs text-gray-500">{employee.jobTitle}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <span className="text-sm text-gray-900">{employee.department}</span>
                    </td>
                    <td className="py-4 px-4">
                      {getStatusBadge(employee.status)}
                    </td>
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-2">
                        <span className={`text-sm font-medium ${getBalanceColor(employee.vacationBalance.remaining, employee.vacationBalance.total)}`}>
                          {employee.vacationBalance.remaining}/{employee.vacationBalance.total}
                        </span>
                        {employee.vacationBalance.pending > 0 && (
                          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
                            +{employee.vacationBalance.pending}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-2">
                        <span className={`text-sm font-medium ${getBalanceColor(employee.sickLeaveBalance.remaining, employee.sickLeaveBalance.total)}`}>
                          {employee.sickLeaveBalance.remaining}/{employee.sickLeaveBalance.total}
                        </span>
                        {employee.sickLeaveBalance.pending > 0 && (
                          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
                            +{employee.sickLeaveBalance.pending}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <span className={`text-sm font-medium ${getBalanceColor(employee.personalDays.remaining, employee.personalDays.total)}`}>
                        {employee.personalDays.remaining}/{employee.personalDays.total}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      <span className="text-sm text-gray-500">
                        {new Date(employee.lastUpdated).toLocaleDateString()}
                      </span>
                    </td>
                    <td className="py-2 px-2 w-24">
                      <div className="flex items-center">
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Edit ${employee.firstName} ${employee.lastName} balance`}
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`View ${employee.firstName} ${employee.lastName} details`}
                        >
                          <MoreHorizontal className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Grid View */}
      {viewMode === 'grid' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
          {paginatedEmployees.map((employee) => (
            <div key={employee.id} className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
              <div className="flex items-center gap-3 mb-4">
                <div 
                  className="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-medium"
                  style={{ backgroundColor: generateAvatarColor(employee.firstName, employee.lastName) }}
                >
                  {generateAvatarInitials(employee.firstName, employee.lastName)}
                </div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-900">
                    {employee.firstName} {employee.lastName}
                  </div>
                  <div className="text-xs text-gray-500">{employee.jobTitle}</div>
                </div>
                {getStatusBadge(employee.status)}
              </div>
              
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-500">Vacation</span>
                  <div className="flex items-center gap-2">
                    <span className={`text-sm font-medium ${getBalanceColor(employee.vacationBalance.remaining, employee.vacationBalance.total)}`}>
                      {employee.vacationBalance.remaining}/{employee.vacationBalance.total}
                    </span>
                    {employee.vacationBalance.pending > 0 && (
                      <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
                        +{employee.vacationBalance.pending}
                      </span>
                    )}
                  </div>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-500">Sick Leave</span>
                  <div className="flex items-center gap-2">
                    <span className={`text-sm font-medium ${getBalanceColor(employee.sickLeaveBalance.remaining, employee.sickLeaveBalance.total)}`}>
                      {employee.sickLeaveBalance.remaining}/{employee.sickLeaveBalance.total}
                    </span>
                    {employee.sickLeaveBalance.pending > 0 && (
                      <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
                        +{employee.sickLeaveBalance.pending}
                      </span>
                    )}
                  </div>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-xs text-gray-500">Personal Days</span>
                  <span className={`text-sm font-medium ${getBalanceColor(employee.personalDays.remaining, employee.personalDays.total)}`}>
                    {employee.personalDays.remaining}/{employee.personalDays.total}
                  </span>
                </div>
              </div>
              
              <div className="flex items-center justify-between mt-4 pt-3 border-t border-gray-100">
                <span className="text-xs text-gray-400">
                  Updated {new Date(employee.lastUpdated).toLocaleDateString()}
                </span>
                <div className="flex items-center gap-1">
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`Edit ${employee.firstName} ${employee.lastName} balance`}
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button
                    className="p-1 hover:bg-gray-100 rounded transition-colors"
                    aria-label={`View ${employee.firstName} ${employee.lastName} details`}
                  >
                    <MoreHorizontal className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, sortedEmployees.length)} of {sortedEmployees.length}
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