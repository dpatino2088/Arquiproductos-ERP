import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { 
  Users, 
  GitBranch, 
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
  SortDesc
} from 'lucide-react';

interface Employee {
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
}

export default function Directory() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'firstName' | 'jobTitle' | 'department' | 'startDate'>('firstName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedEmploymentType, setSelectedEmploymentType] = useState<string>('');
  const [selectedLocation, setSelectedLocation] = useState<string>('');

  useEffect(() => {
    // Register submodule tabs for management people section
    registerSubmodules('People Directory', [
      { id: 'directory', label: 'Directory', href: '/management/people/directory', icon: Users },
      { id: 'org-chart', label: 'Organizational Chart', href: '/management/people/organizational-chart', icon: GitBranch }
    ]);
  }, [registerSubmodules]);

  const employees: Employee[] = [
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
      avatar: 'https://i.pravatar.cc/150?img=1'
    },
    {
      id: '2',
      firstName: 'Alex',
      lastName: 'Thompson',
      email: 'alex.thompson@arquiluz.com',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      status: 'Suspended',
      location: 'Seattle, WA',
      startDate: '9/11/2022',
      avatar: 'https://i.pravatar.cc/150?img=2'
    },
    {
      id: '3',
      firstName: 'Amanda',
      lastName: 'Foster',
      email: 'amanda.foster@arquiluz.com',
      jobTitle: 'HR Specialist',
      department: 'Human Resources',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '1/9/2022',
      avatar: 'https://i.pravatar.cc/150?img=3'
    },
    {
      id: '4',
      firstName: 'David',
      lastName: 'Kim',
      email: 'david.kim@arquiluz.com',
      jobTitle: 'VP of Product',
      department: 'Product',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '8/4/2019'
    },
    {
      id: '5',
      firstName: 'Emily',
      lastName: 'Davis',
      email: 'emily.davis@arquiluz.com',
      jobTitle: 'Design Lead',
      department: 'Design',
      status: 'Active',
      location: 'New York, NY',
      startDate: '2/13/2021'
    },
    {
      id: '6',
      firstName: 'Jennifer',
      lastName: 'Liu',
      email: 'jennifer.liu@arquiluz.com',
      jobTitle: 'Product Manager',
      department: 'Product',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '1/21/2023'
    },
    {
      id: '7',
      firstName: 'Kevin',
      lastName: 'Chang',
      email: 'kevin.chang@arquiluz.com',
      jobTitle: 'Data Analyst',
      department: 'Analytics',
      status: 'Onboarding',
      location: 'Boston, MA',
      startDate: '12/4/2022'
    },
    {
      id: '8',
      firstName: 'Lisa',
      lastName: 'Anderson',
      email: 'lisa.anderson@arquiluz.com',
      jobTitle: 'Sales Manager',
      department: 'Sales',
      status: 'Active',
      location: 'Miami, FL',
      startDate: '11/29/2020'
    },
    {
      id: '9',
      firstName: 'Marcus',
      lastName: 'Rodriguez',
      email: 'marcus.rodriguez@arquiluz.com',
      jobTitle: 'UX Designer',
      department: 'Design',
      status: 'On Leave',
      location: 'New York, NY',
      startDate: '11/7/2021'
    },
    {
      id: '10',
      firstName: 'Michael',
      lastName: 'Chen',
      email: 'michael.chen@arquiluz.com',
      jobTitle: 'Engineering Manager',
      department: 'Engineering',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '5/17/2020',
      avatar: 'https://i.pravatar.cc/150?img=4'
    },
    {
      id: '11',
      firstName: 'Sarah',
      lastName: 'Wilson',
      email: 'sarah.wilson@arquiluz.com',
      jobTitle: 'Marketing Manager',
      department: 'Marketing',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '5/17/2020',
      avatar: 'https://i.pravatar.cc/150?img=3'
    },
    {
      id: '12',
      firstName: 'James',
      lastName: 'Rodriguez',
      email: 'james.rodriguez@arquiluz.com',
      jobTitle: 'Backend Developer',
      department: 'Engineering',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '3/12/2021',
      avatar: 'https://i.pravatar.cc/150?img=5'
    },
    {
      id: '13',
      firstName: 'Lisa',
      lastName: 'Chen',
      email: 'lisa.chen@arquiluz.com',
      jobTitle: 'UX Designer',
      department: 'Product',
      status: 'On Leave',
      location: 'Seattle, WA',
      startDate: '8/22/2020',
      avatar: 'https://i.pravatar.cc/150?img=6'
    },
    {
      id: '14',
      firstName: 'Robert',
      lastName: 'Taylor',
      email: 'robert.taylor@arquiluz.com',
      jobTitle: 'Sales Director',
      department: 'Sales',
      status: 'Active',
      location: 'New York, NY',
      startDate: '1/15/2019',
      avatar: 'https://i.pravatar.cc/150?img=7'
    },
    {
      id: '15',
      firstName: 'Jennifer',
      lastName: 'Martinez',
      email: 'jennifer.martinez@arquiluz.com',
      jobTitle: 'Content Strategist',
      department: 'Marketing',
      status: 'Onboarding',
      location: 'Portland, OR',
      startDate: '6/8/2022',
      avatar: 'https://i.pravatar.cc/150?img=8'
    },
    {
      id: '16',
      firstName: 'Kevin',
      lastName: 'Brown',
      email: 'kevin.brown@arquiluz.com',
      jobTitle: 'DevOps Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '11/1/2023',
      avatar: 'https://i.pravatar.cc/150?img=9'
    },
    {
      id: '17',
      firstName: 'Michelle',
      lastName: 'Garcia',
      email: 'michelle.garcia@arquiluz.com',
      jobTitle: 'HR Coordinator',
      department: 'Human Resources',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '4/3/2021',
      avatar: 'https://i.pravatar.cc/150?img=10'
    },
    {
      id: '18',
      firstName: 'Daniel',
      lastName: 'Anderson',
      email: 'daniel.anderson@arquiluz.com',
      jobTitle: 'Product Manager',
      department: 'Product',
      status: 'Active',
      location: 'Seattle, WA',
      startDate: '9/14/2020',
      avatar: 'https://i.pravatar.cc/150?img=11'
    },
    {
      id: '19',
      firstName: 'Ashley',
      lastName: 'Thomas',
      email: 'ashley.thomas@arquiluz.com',
      jobTitle: 'Frontend Developer',
      department: 'Engineering',
      status: 'Suspended',
      location: 'Portland, OR',
      startDate: '2/28/2022',
      avatar: 'https://i.pravatar.cc/150?img=12'
    },
    {
      id: '20',
      firstName: 'Christopher',
      lastName: 'Jackson',
      email: 'christopher.jackson@arquiluz.com',
      jobTitle: 'Sales Representative',
      department: 'Sales',
      status: 'Active',
      location: 'New York, NY',
      startDate: '7/19/2021',
      avatar: 'https://i.pravatar.cc/150?img=1'
    },
    {
      id: '21',
      firstName: 'Amanda',
      lastName: 'White',
      email: 'amanda.white@arquiluz.com',
      jobTitle: 'Marketing Specialist',
      department: 'Marketing',
      status: 'Active',
      location: 'San Francisco, CA',
      startDate: '10/5/2022',
      avatar: 'https://i.pravatar.cc/150?img=13'
    },
    {
      id: '22',
      firstName: 'Matthew',
      lastName: 'Harris',
      email: 'matthew.harris@arquiluz.com',
      jobTitle: 'QA Engineer',
      department: 'Engineering',
      status: 'Active',
      location: 'Austin, TX',
      startDate: '12/12/2021',
      avatar: 'https://i.pravatar.cc/150?img=14'
    },
    {
      id: '23',
      firstName: 'Jessica',
      lastName: 'Clark',
      email: 'jessica.clark@arquiluz.com',
      jobTitle: 'UI Designer',
      department: 'Product',
      status: 'On Leave',
      location: 'Seattle, WA',
      startDate: '5/30/2020',
      avatar: 'https://i.pravatar.cc/150?img=15'
    },
    {
      id: '24',
      firstName: 'Ryan',
      lastName: 'Lewis',
      email: 'ryan.lewis@arquiluz.com',
      jobTitle: 'Account Manager',
      department: 'Sales',
      status: 'Active',
      location: 'Portland, OR',
      startDate: '1/8/2023',
      avatar: 'https://i.pravatar.cc/150?img=2'
    },
    {
      id: '25',
      firstName: 'Nicole',
      lastName: 'Walker',
      email: 'nicole.walker@arquiluz.com',
      jobTitle: 'Content Writer',
      department: 'Marketing',
      status: 'Onboarding',
      location: 'New York, NY',
      startDate: '11/15/2023',
      avatar: 'https://i.pravatar.cc/150?img=16'
    }
  ];

  const filteredEmployees = useMemo(() => {
    const filtered = employees.filter(employee => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        employee.firstName.toLowerCase().includes(searchLower) ||
        employee.lastName.toLowerCase().includes(searchLower) ||
        employee.email.toLowerCase().includes(searchLower) ||
        employee.jobTitle.toLowerCase().includes(searchLower) ||
        employee.department.toLowerCase().includes(searchLower)
      );

      // Department filter
      const matchesDepartment = !selectedDepartment || employee.department === selectedDepartment;

      // Status filter
      const matchesStatus = !selectedStatus || employee.status === selectedStatus;

      // Employment type filter (assuming all employees are full-time for now)
      const matchesEmploymentType = !selectedEmploymentType || selectedEmploymentType === 'Full-time';

      // Location filter
      const matchesLocation = !selectedLocation || employee.location === selectedLocation;

      return matchesSearch && matchesDepartment && matchesStatus && matchesEmploymentType && matchesLocation;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

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
        case 'startDate':
          aValue = new Date(a.startDate);
          bValue = new Date(b.startDate);
          break;
        default:
          aValue = a.firstName.toLowerCase();
          bValue = b.firstName.toLowerCase();
      }

      if (sortBy === 'startDate') {
        const dateA = aValue as Date;
        const dateB = bValue as Date;
        return sortOrder === 'asc' ? dateA.getTime() - dateB.getTime() : dateB.getTime() - dateA.getTime();
      } else {
        const strA = aValue as string;
        const strB = bValue as string;
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [searchTerm, employees, sortBy, sortOrder, selectedDepartment, selectedStatus, selectedEmploymentType, selectedLocation]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredEmployees.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedEmployees = filteredEmployees.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedDepartment('');
    setSelectedStatus('');
    setSelectedEmploymentType('');
    setSelectedLocation('');
    setSearchTerm('');
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Active':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: '#1FB6A1', color: 'white' }}>
            Active
          </span>
        );
      case 'Suspended':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: '#FEF2F2', color: '#DC2626' }}>
            Suspended
          </span>
        );
      case 'Onboarding':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: '#EFF6FF', color: '#2563EB' }}>
            Onboarding
          </span>
        );
      case 'On Leave':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: '#FEF3C7', color: '#D97706' }}>
            On Leave
          </span>
        );
      default:
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: '#F3F4F6', color: '#6B7280' }}>
            {status}
          </span>
        );
    }
  };

  const getInitials = (firstName: string, lastName: string) => {
    return `${firstName.charAt(0)}${lastName.charAt(0)}`;
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Employee Directory</h1>
          <p className="text-xs text-gray-400">
            Manage your team of {filteredEmployees.length} employees
            {filteredEmployees.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm" style={{ backgroundColor: '#1FB6A1' }}>
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Person
          </button>
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
                placeholder="Search employees by name, email, job title, or employee ID..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
            
        <div className="flex items-center gap-2">
              {/* Filters Button */}
              <button
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                  showFilters ? 'bg-gray-100 text-gray-900' : 'bg-white text-gray-700 hover:bg-gray-50'
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
                      ? 'bg-gray-100 text-gray-900'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  <List className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'grid'
                      ? 'bg-gray-100 text-gray-900'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
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
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
              <select 
                value={selectedDepartment}
                onChange={(e) => setSelectedDepartment(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">All Departments</option>
                <option value="Executive">Executive</option>
                <option value="Engineering">Engineering</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Product">Product</option>
                <option value="Marketing">Marketing</option>
                <option value="Sales">Sales</option>
              </select>

              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">All Statuses</option>
                <option value="Active">Active</option>
                <option value="Onboarding">Onboarding</option>
                <option value="On Leave">On Leave</option>
                <option value="Suspended">Suspended</option>
              </select>

              <select 
                value={selectedEmploymentType}
                onChange={(e) => setSelectedEmploymentType(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">All Employment Types</option>
                <option value="Full-time">Full-time</option>
                <option value="Part-time">Part-time</option>
                <option value="Contract">Contract</option>
                <option value="Intern">Intern</option>
              </select>

              <select 
                value={selectedLocation}
                onChange={(e) => setSelectedLocation(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">All Locations</option>
                <option value="San Francisco, CA">San Francisco, CA</option>
                <option value="Seattle, WA">Seattle, WA</option>
                <option value="Portland, OR">Portland, OR</option>
                <option value="Austin, TX">Austin, TX</option>
                <option value="New York, NY">New York, NY</option>
              </select>
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
                  onClick={() => handleSort('startDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'startDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Start Date
                  {sortBy === 'startDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Employee Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
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
                    onClick={() => handleSort('jobTitle')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Job Title
                    {sortBy === 'jobTitle' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Location</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('startDate')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Start Date
                    {sortBy === 'startDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginatedEmployees.map((employee, _index) => (
                <tr key={employee.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                                    <td className="py-4 px-4">
                    <div className="flex items-center gap-3">
                      <div className="relative">
                        {employee.avatar ? (
                          <img 
                            src={employee.avatar} 
                            alt={`${employee.firstName} ${employee.lastName}`}
                            className="w-8 h-8 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" style={{ backgroundColor: '#1FB6A1' }}>
                            {getInitials(employee.firstName, employee.lastName)}
                          </div>
                        )}
                        <div className={`absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white ${
                          employee.status === 'Active' ? 'bg-green-500' :
                          employee.status === 'On Leave' ? 'bg-yellow-500' :
                          employee.status === 'Onboarding' ? 'bg-blue-500' :
                          employee.status === 'Suspended' ? 'bg-red-500' :
                          'bg-gray-400'
                        }`}></div>
                      </div>
                      <div>
                        <div className="font-medium text-gray-900 text-sm">
                          {employee.firstName} {employee.lastName}
                        </div>
                        <div className="text-xs text-gray-400">{employee.email}</div>
                      </div>
                  </div>
                  </td>
                  <td className="py-4 px-4 text-gray-900 text-sm">{employee.jobTitle}</td>
                  <td className="py-4 px-4 text-gray-900 text-sm">{employee.department}</td>
                  <td className="py-4 px-4">{getStatusBadge(employee.status)}</td>
                  <td className="py-4 px-4 text-gray-600 text-sm">{employee.location}</td>
                  <td className="py-4 px-4 text-gray-600 text-sm">{employee.startDate}</td>
                  <td className="py-4 px-4">
                    <div className="flex items-center gap-2">
                      <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button className="p-1 text-gray-400 hover:text-red-600 transition-colors">
                        <Trash2 className="w-4 h-4" />
                      </button>
                  </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
                  </div>
                </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-600">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="border border-gray-200 rounded px-2 py-1 text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-sm text-gray-600">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredEmployees.length)} of {filteredEmployees.length}
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
                          ? 'text-white'
                          : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                      }`}
                      style={currentPage === pageNum ? { backgroundColor: '#1FB6A1' } : {}}
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

      {/* Empty State */}
      {filteredEmployees.length === 0 && (
        <div className="text-center py-8">
          <Users className="w-8 h-8 text-gray-400 mx-auto mb-3" />
          <h3 className="text-sm font-semibold text-gray-900 mb-1">No employees found</h3>
          <p className="text-xs text-gray-600">Try adjusting your search criteria.</p>
        </div>
      )}
    </div>
  );
}