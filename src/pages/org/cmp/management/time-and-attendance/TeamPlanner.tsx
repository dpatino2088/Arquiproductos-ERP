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
  Eye,
  Flag,
  SortAsc,
  SortDesc
} from 'lucide-react';

// Function to generate avatar initials
const generateAvatarInitials = (firstName: string, lastName: string) => {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
};

// Function to get proportional dot size based on avatar size
const getDotSize = (avatarSize: 'sm' | 'md' | 'lg') => {
  switch (avatarSize) {
    case 'sm': // w-8 h-8 (32px)
      return 'w-2.5 h-2.5'; // 10px
    case 'md': // w-10 h-10 (40px)
      return 'w-3 h-3'; // 12px
    case 'lg': // w-12 h-12 (48px)
      return 'w-3.5 h-3.5'; // 14px
    default:
      return 'w-2.5 h-2.5';
  }
};

// Function to get status dot color for avatars - Using brighter colors for better visibility
const getStatusDotColor = (status: string) => {
  switch (status) {
    case 'present':
      return 'var(--avatar-status-green)'; // Green 600 - Brighter for avatar dots
    case 'on-break':
      return 'var(--avatar-status-yellow)'; // Yellow 500 - Brighter for avatar dots
    case 'on-transfer':
      return 'var(--avatar-status-blue)'; // Blue 600 - Brighter for avatar dots
    case 'on-leave':
      return 'var(--avatar-status-purple)'; // Purple 600 - Brighter for avatar dots
    case 'absent':
      return 'var(--avatar-status-red)'; // Red 600 - Brighter for avatar dots
    default:
      return 'var(--avatar-status-gray)'; // Gray 300 - Brighter for avatar dots
  }
};

interface Employee {
  id: string;
  name: string;
  role: string;
  department: string;
  avatar?: string;
  status: string;
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
  
  // Multi-select filter states
  const [selectedDepartment, setSelectedDepartment] = useState<string[]>([]);
  const [selectedRole, setSelectedRole] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  
  // Dropdown visibility states
  const [showDepartmentDropdown, setShowDepartmentDropdown] = useState(false);
  const [showRoleDropdown, setShowRoleDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  
  // Search terms within dropdowns
  const [departmentSearchTerm, setDepartmentSearchTerm] = useState('');
  const [roleSearchTerm, setRoleSearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  
  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  
  // Sorting states
  const [sortBy, setSortBy] = useState<'name' | 'department' | 'role'>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  useEffect(() => {
    // Register submodule tabs for time and attendance
    registerSubmodules('Time & Attendance', [
      { id: 'whos-working', label: "Who's Working", href: '/org/cmp/management/time-and-attendance/whos-working', icon: Users },
      { id: 'team-planner', label: 'Team Planner', href: '/org/cmp/management/time-and-attendance/team-planner', icon: Calendar },
      { id: 'team-attendance', label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance', icon: Clock },
      { id: 'attendance-flags', label: 'Attendance Flags', href: '/org/cmp/management/time-and-attendance/attendance-flags', icon: Flag }
    ]);
  }, [registerSubmodules]);

  // Mock data
  const employees: Employee[] = [
    {
      id: '1',
      name: 'Sarah Johnson',
      role: 'Senior Developer',
      department: 'Engineering',
      status: 'present',
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
      status: 'on-break',
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
      status: 'present',
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
    },
    {
      id: '4',
      name: 'David Kim',
      role: 'Frontend Developer',
      department: 'Engineering',
      status: 'on-transfer',
      availability: {
        monday: ['10:00', '19:00'],
        tuesday: ['10:00', '19:00'],
        wednesday: ['10:00', '19:00'],
        thursday: ['10:00', '19:00'],
        friday: ['10:00', '19:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Vue.js', 'JavaScript', 'CSS'],
      hourlyRate: 70,
      maxHoursPerWeek: 40
    },
    {
      id: '5',
      name: 'Lisa Wang',
      role: 'Backend Developer',
      department: 'Engineering',
      status: 'present',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Python', 'Django', 'PostgreSQL'],
      hourlyRate: 80,
      maxHoursPerWeek: 40
    },
    {
      id: '6',
      name: 'James Wilson',
      role: 'DevOps Engineer',
      department: 'Engineering',
      status: 'absent',
      availability: {
        monday: ['08:00', '17:00'],
        tuesday: ['08:00', '17:00'],
        wednesday: ['08:00', '17:00'],
        thursday: ['08:00', '17:00'],
        friday: ['08:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['AWS', 'Docker', 'Kubernetes'],
      hourlyRate: 90,
      maxHoursPerWeek: 40
    },
    {
      id: '7',
      name: 'Maria Garcia',
      role: 'UI Designer',
      department: 'Design',
      status: 'on-leave',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Adobe XD', 'InVision', 'Prototyping'],
      hourlyRate: 60,
      maxHoursPerWeek: 40
    },
    {
      id: '8',
      name: 'Robert Taylor',
      role: 'Product Manager',
      department: 'Management',
      status: 'present',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Product Strategy', 'User Research', 'Analytics'],
      hourlyRate: 95,
      maxHoursPerWeek: 40
    },
    {
      id: '9',
      name: 'Jennifer Brown',
      role: 'QA Engineer',
      department: 'Engineering',
      status: 'on-break',
      availability: {
        monday: ['10:00', '19:00'],
        tuesday: ['10:00', '19:00'],
        wednesday: ['10:00', '19:00'],
        thursday: ['10:00', '19:00'],
        friday: ['10:00', '19:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Selenium', 'Jest', 'Manual Testing'],
      hourlyRate: 65,
      maxHoursPerWeek: 40
    },
    {
      id: '10',
      name: 'Christopher Lee',
      role: 'Full Stack Developer',
      department: 'Engineering',
      status: 'present',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['React', 'Node.js', 'MongoDB'],
      hourlyRate: 85,
      maxHoursPerWeek: 40
    },
    {
      id: '11',
      name: 'Amanda Davis',
      role: 'Marketing Manager',
      department: 'Marketing',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Digital Marketing', 'SEO', 'Analytics'],
      hourlyRate: 70,
      maxHoursPerWeek: 40
    },
    {
      id: '12',
      name: 'Kevin Martinez',
      role: 'Sales Representative',
      department: 'Sales',
      availability: {
        monday: ['08:00', '17:00'],
        tuesday: ['08:00', '17:00'],
        wednesday: ['08:00', '17:00'],
        thursday: ['08:00', '17:00'],
        friday: ['08:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['CRM', 'Lead Generation', 'Negotiation'],
      hourlyRate: 55,
      maxHoursPerWeek: 40
    },
    {
      id: '13',
      name: 'Rachel Green',
      role: 'Content Writer',
      department: 'Marketing',
      availability: {
        monday: ['10:00', '19:00'],
        tuesday: ['10:00', '19:00'],
        wednesday: ['10:00', '19:00'],
        thursday: ['10:00', '19:00'],
        friday: ['10:00', '19:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Copywriting', 'SEO Writing', 'Content Strategy'],
      hourlyRate: 50,
      maxHoursPerWeek: 40
    },
    {
      id: '14',
      name: 'Thomas Anderson',
      role: 'Data Analyst',
      department: 'Analytics',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['SQL', 'Python', 'Tableau'],
      hourlyRate: 75,
      maxHoursPerWeek: 40
    },
    {
      id: '15',
      name: 'Nicole White',
      role: 'HR Specialist',
      department: 'Human Resources',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Recruitment', 'Employee Relations', 'HRIS'],
      hourlyRate: 60,
      maxHoursPerWeek: 40
    },
    {
      id: '16',
      name: 'Daniel Clark',
      role: 'Mobile Developer',
      department: 'Engineering',
      availability: {
        monday: ['10:00', '19:00'],
        tuesday: ['10:00', '19:00'],
        wednesday: ['10:00', '19:00'],
        thursday: ['10:00', '19:00'],
        friday: ['10:00', '19:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['React Native', 'iOS', 'Android'],
      hourlyRate: 80,
      maxHoursPerWeek: 40
    },
    {
      id: '17',
      name: 'Samantha Turner',
      role: 'Graphic Designer',
      department: 'Design',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Photoshop', 'Illustrator', 'Brand Design'],
      hourlyRate: 55,
      maxHoursPerWeek: 40
    },
    {
      id: '18',
      name: 'Mark Johnson',
      role: 'System Administrator',
      department: 'IT',
      availability: {
        monday: ['08:00', '17:00'],
        tuesday: ['08:00', '17:00'],
        wednesday: ['08:00', '17:00'],
        thursday: ['08:00', '17:00'],
        friday: ['08:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Windows Server', 'Linux', 'Network Security'],
      hourlyRate: 70,
      maxHoursPerWeek: 40
    },
    {
      id: '19',
      name: 'Laura Miller',
      role: 'Business Analyst',
      department: 'Analytics',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Requirements Analysis', 'Process Improvement', 'Documentation'],
      hourlyRate: 65,
      maxHoursPerWeek: 40
    },
    {
      id: '20',
      name: 'Alex Thompson',
      role: 'Customer Success Manager',
      department: 'Customer Success',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Customer Relations', 'Account Management', 'Retention'],
      hourlyRate: 60,
      maxHoursPerWeek: 40
    },
    {
      id: '21',
      name: 'Jessica Adams',
      role: 'Financial Analyst',
      department: 'Finance',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Financial Modeling', 'Excel', 'Budgeting'],
      hourlyRate: 70,
      maxHoursPerWeek: 40
    },
    {
      id: '22',
      name: 'Ryan Cooper',
      role: 'Security Engineer',
      department: 'IT',
      availability: {
        monday: ['10:00', '19:00'],
        tuesday: ['10:00', '19:00'],
        wednesday: ['10:00', '19:00'],
        thursday: ['10:00', '19:00'],
        friday: ['10:00', '19:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Cybersecurity', 'Penetration Testing', 'Compliance'],
      hourlyRate: 95,
      maxHoursPerWeek: 40
    },
    {
      id: '23',
      name: 'Michelle Lewis',
      role: 'Operations Manager',
      department: 'Operations',
      availability: {
        monday: ['08:00', '17:00'],
        tuesday: ['08:00', '17:00'],
        wednesday: ['08:00', '17:00'],
        thursday: ['08:00', '17:00'],
        friday: ['08:00', '17:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Process Optimization', 'Supply Chain', 'Quality Control'],
      hourlyRate: 75,
      maxHoursPerWeek: 40
    },
    {
      id: '24',
      name: 'Brandon Wright',
      role: 'Technical Writer',
      department: 'Engineering',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Technical Documentation', 'API Documentation', 'User Guides'],
      hourlyRate: 55,
      maxHoursPerWeek: 40
    },
    {
      id: '25',
      name: 'Stephanie Hall',
      role: 'Training Coordinator',
      department: 'Human Resources',
      availability: {
        monday: ['09:00', '18:00'],
        tuesday: ['09:00', '18:00'],
        wednesday: ['09:00', '18:00'],
        thursday: ['09:00', '18:00'],
        friday: ['09:00', '18:00'],
        saturday: [],
        sunday: []
      },
      qualifications: ['Training Development', 'LMS', 'Employee Onboarding'],
      hourlyRate: 50,
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

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedDepartment([]);
    setSelectedRole([]);
    setSelectedStatus([]);
    setSearchTerm('');
    setDepartmentSearchTerm('');
    setRoleSearchTerm('');
    setStatusSearchTerm('');
    setCurrentPage(1); // Reset to first page when clearing filters
  };

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Select All functions for each filter
  const handleDepartmentSelectAll = () => {
    const allDepartments = getFilteredDepartmentOptions();
    setSelectedDepartment(allDepartments);
  };

  const handleRoleSelectAll = () => {
    const allRoles = getFilteredRoleOptions();
    setSelectedRole(allRoles);
  };

  const handleStatusSelectAll = () => {
    const allStatuses = getFilteredStatusOptions();
    setSelectedStatus(allStatuses);
  };

  // Helper functions for multi-select
  const handleDepartmentToggle = (department: string) => {
    setSelectedDepartment(prev => 
      prev.includes(department) 
        ? prev.filter(d => d !== department)
        : [...prev, department]
    );
  };

  const handleRoleToggle = (role: string) => {
    setSelectedRole(prev => 
      prev.includes(role) 
        ? prev.filter(r => r !== role)
        : [...prev, role]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  // Filter options based on search terms
  const getFilteredDepartmentOptions = () => {
    const departments = [...new Set(employees.map(e => e.department))];
    return departments.filter(dept => 
      dept.toLowerCase().includes(departmentSearchTerm.toLowerCase())
    );
  };

  const getFilteredRoleOptions = () => {
    const roles = [...new Set(employees.map(e => e.role))];
    return roles.filter(role => 
      role.toLowerCase().includes(roleSearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statuses = ['confirmed', 'pending', 'cancelled'];
    return statuses.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const filteredEmployees = useMemo(() => {
    const filtered = employees.filter(employee => {
      const matchesSearch = employee.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      employee.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
                           employee.department.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesDepartment = selectedDepartment.length === 0 || selectedDepartment.includes(employee.department);
      const matchesRole = selectedRole.length === 0 || selectedRole.includes(employee.role);
      
      return matchesSearch && matchesDepartment && matchesRole;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string;
      let bValue: string;

      switch (sortBy) {
        case 'name':
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
          break;
        case 'department':
          aValue = a.department.toLowerCase();
          bValue = b.department.toLowerCase();
          break;
        case 'role':
          aValue = a.role.toLowerCase();
          bValue = b.role.toLowerCase();
          break;
        default:
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
      }

      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [employees, searchTerm, selectedDepartment, selectedRole, sortBy, sortOrder]);

  // Pagination calculations
  const totalItems = filteredEmployees.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const paginatedEmployees = filteredEmployees.slice(startIndex, endIndex);

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

  const goToCurrentWeek = () => {
    setCurrentDate(new Date());
  };

  const getWeekRange = () => {
    const start = weekDates[0];
    const end = weekDates[6];
    return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
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
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Users className="h-5 w-5 text-teal-600" />
            <div className="text-2xl font-bold text-gray-900">{employees.length}</div>
              <div className="text-sm text-muted-foreground">Total Employees</div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Calendar className="h-5 w-5 text-blue-600" />
            <div className="text-2xl font-bold text-gray-900">{shifts.length}</div>
              <div className="text-sm text-muted-foreground">Scheduled Shifts</div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-green-600" />
            <div className="text-2xl font-bold text-gray-900">
                {shifts.filter(s => s.status === 'confirmed').length}
              </div>
              <div className="text-sm text-muted-foreground">Confirmed</div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-red-600" />
            <div className="text-2xl font-bold text-gray-900">0</div>
              <div className="text-sm text-muted-foreground">Conflicts</div>
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
                placeholder="Search employees by name, email, job title, or employee ID..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search employees"
                id="employee-search"
              />
            </div>
            
            <div className="flex items-center gap-2">
              {/* Clear Filters Button - Only show when filters are active */}
              {(selectedDepartment.length > 0 || selectedRole.length > 0 || selectedStatus.length > 0) && (
              <button
                  onClick={clearAllFilters}
                  className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm bg-white text-gray-700 hover:bg-gray-50"
                  title="Clear all active filters"
                >
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  Clear filters
                </button>
              )}

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
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto">
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
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDepartmentSelectAll();
                          }}
                          className="text-xs text-blue-600 hover:text-blue-800 whitespace-nowrap"
                        >
                          Select All
                        </button>
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
                    <div className="py-1">
                      {getFilteredDepartmentOptions().map((department) => (
                        <label key={department} className="flex items-center px-3 py-1 hover:bg-gray-50 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={selectedDepartment.includes(department)}
                            onChange={() => handleDepartmentToggle(department)}
                            className="mr-2 rounded border-gray-300 text-primary focus:ring-primary/20"
                          />
                          <span className="text-sm text-gray-700">{department}</span>
                        </label>
                      ))}
            </div>
          </div>
        )}
      </div>

              {/* Role Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowRoleDropdown(!showRoleDropdown)}>
                  <span className="text-gray-700">
                    {selectedRole.length === 0 ? 'All Roles' : 
                     selectedRole.length === 1 ? selectedRole[0] :
                     `${selectedRole.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showRoleDropdown && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search roles..."
                          value={roleSearchTerm}
                          onChange={(e) => setRoleSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleRoleSelectAll();
                          }}
                          className="text-xs text-blue-600 hover:text-blue-800 whitespace-nowrap"
                        >
                          Select All
                        </button>
                        {selectedRole.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedRole([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedRole.length})
                          </button>
                        )}
                      </div>
                    </div>
                    <div className="py-1">
                      {getFilteredRoleOptions().map((role) => (
                        <label key={role} className="flex items-center px-3 py-1 hover:bg-gray-50 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={selectedRole.includes(role)}
                            onChange={() => handleRoleToggle(role)}
                            className="mr-2 rounded border-gray-300 text-primary focus:ring-primary/20"
                          />
                          <span className="text-sm text-gray-700">{role}</span>
                        </label>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Status Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowStatusDropdown(!showStatusDropdown)}>
                  <span className="text-gray-700">
                    {selectedStatus.length === 0 ? 'All Statuses' : 
                     selectedStatus.length === 1 ? selectedStatus[0].replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase()) :
                     `${selectedStatus.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showStatusDropdown && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto">
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
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleStatusSelectAll();
                          }}
                          className="text-xs text-blue-600 hover:text-blue-800 whitespace-nowrap"
                        >
                          Select All
                        </button>
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
                    <div className="py-1">
                      {getFilteredStatusOptions().map((status) => (
                        <label key={status} className="flex items-center px-3 py-1 hover:bg-gray-50 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={selectedStatus.includes(status)}
                            onChange={() => handleStatusToggle(status)}
                            className="mr-2 rounded border-gray-300 text-primary focus:ring-primary/20"
                          />
                          <span className="text-sm text-gray-700 capitalize">{status}</span>
                        </label>
                      ))}
                    </div>
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
                  onClick={() => handleSort('name')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'name' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Name
                  {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  onClick={() => handleSort('role')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'role' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Role
                  {sortBy === 'role' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
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
              <p className="text-sm text-gray-500">Week of {weekDates[0].toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</p>
            </div>
            <button
              onClick={() => navigateWeek('next')}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              aria-label="Next week"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          <button
              onClick={goToCurrentWeek}
              className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            aria-label="Go to current week"
          >
              This Week
          </button>
          </div>
        </div>
        </div>

      {/* Calendar */}
      <div className="bg-white border border-gray-200 rounded-lg mb-4 overflow-hidden">
        {/* Week View */}
        {viewMode === 'week' && (
          <div>
            {/* Header Row */}
            <div className="flex">
            {/* Employee Column Header */}
              <div className="w-64 p-3 pl-6 border-r border-gray-200 bg-gray-50">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8"></div>
              <span className="text-sm font-medium text-gray-700">Employee</span>
                </div>
            </div>
            
            {/* Day Headers */}
            {weekDates.map((date, index) => (
                <div key={index} className={`flex-1 p-3 bg-gray-50 flex items-center justify-center ${index < weekDates.length - 1 ? 'border-r border-gray-200' : ''}`}>
                  <div className="flex items-center justify-center gap-1">
                <div className="text-sm font-medium text-gray-700">
                  {date.toLocaleDateString('en-US', { weekday: 'short' })}
                </div>
                    <div className="text-sm text-gray-500">
                  {date.getDate()}
                    </div>
                </div>
              </div>
            ))}
            </div>
            
            {/* Employee Rows */}
            {paginatedEmployees.map((employee, employeeIndex) => (
              <div key={employee.id} className="flex">
                {/* Employee Info */}
                <div className={`w-64 p-3 pl-6 border-r border-gray-200 flex items-center gap-3 ${employeeIndex < paginatedEmployees.length - 1 ? 'border-b border-gray-200' : ''}`}>
                  <div className="relative">
                    <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                      {generateAvatarInitials(employee.name.split(' ')[0], employee.name.split(' ')[1] || '')}
                    </div>
                    <div 
                      className={`absolute -bottom-0.5 -right-0.5 ${getDotSize('sm')} rounded-full border border-white`}
                      style={{ backgroundColor: getStatusDotColor(employee.status) }}>
                    </div>
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
                      <div key={dayIndex} className={`flex-1 p-2 min-h-[60px] flex flex-col items-center justify-center ${dayIndex < weekDates.length - 1 ? 'border-r border-gray-200' : ''} ${employeeIndex < paginatedEmployees.length - 1 ? 'border-b border-gray-200' : ''}`}>
                      {dayShifts.length > 0 ? (
                        dayShifts.map((shift) => (
                          <div
                            key={shift.id}
                            className={`p-2 rounded text-xs mb-1 cursor-pointer hover:shadow-sm transition-shadow ${getStatusColor(shift.status)}`}
                            onClick={() => setSelectedEmployee(employee.id)}
                          >
                            <div className="font-medium">{shift.startTime} - {shift.endTime}</div>
                            <div className="text-xs opacity-75">{shift.role}</div>
                          </div>
                        ))
                      ) : (
                        <button 
                          className="w-6 h-6 border border-gray-200 rounded flex items-center justify-center hover:bg-gray-50 transition-colors"
                          onClick={() => {
                            // TODO: Add shift functionality
                            console.log('Add shift for', employee.name, 'on', date.toDateString());
                          }}
                          aria-label={`Add shift for ${employee.name}`}
                        >
                          <Plus className="w-3 h-3 text-gray-400" />
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
              <div className="flex items-center justify-between">
          {/* Items Per Page Selector */}
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
            >
              <option value={5}>5</option>
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {((currentPage - 1) * itemsPerPage) + 1}-{Math.min(currentPage * itemsPerPage, totalItems)} of {totalItems}
            </span>
                  </div>
          
          {/* Page Navigation */}
          {totalPages > 1 && (
            <div className="flex items-center gap-3">
              {/* Previous Button */}
                  <button
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                disabled={currentPage === 1}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === 1
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
                aria-label="Go to previous page"
              >
                <ChevronLeft className="w-3 h-3" />
                Previous
                  </button>

              {/* Page Numbers */}
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
                      aria-label={`Go to page ${pageNum}`}
                    >
                      {pageNum}
                  </button>
                  );
                })}
              </div>

              {/* Next Button */}
                  <button
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                disabled={currentPage === totalPages}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === totalPages
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
                aria-label="Go to next page"
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
