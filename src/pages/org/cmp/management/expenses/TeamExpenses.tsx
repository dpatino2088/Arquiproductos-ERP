import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { 
  Search, 
  Filter,
  Edit,
  ChevronLeft,
  ChevronRight,
  SortAsc,
  SortDesc,
  CheckCircle,
  AlertTriangle,
  Eye,
  Settings,
  Laptop,
  DollarSign,
  UserPlus,
  Package,
  Receipt,
  Car,
  Plane,
  Utensils,
  Check,
  X
} from 'lucide-react';

interface Expense {
  id: string;
  employeeId: string;
  employeeName: string;
  employeeEmail: string;
  employeeJobTitle: string;
  employeeDepartment: string;
  employeeLocation: string;
  expenseType: 'Travel' | 'Meals' | 'Transportation' | 'Office Supplies' | 'Training' | 'Software' | 'Hardware' | 'Other';
  category: string;
  description: string;
  amount: number;
  currency: string;
  expenseDate: string;
  submissionDate: string;
  status: 'Pending' | 'Under Review' | 'Approved' | 'Rejected' | 'Paid';
  approvedBy?: string;
  approvedByEmail?: string;
  approvedByJobTitle?: string;
  approvedByDepartment?: string;
  approvedByLocation?: string;
  approvalDate?: string;
  rejectionReason?: string;
  paymentDate?: string;
  receiptUrl?: string;
  notes?: string;
  avatar?: string;
  phone?: string;
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
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-orange-light text-status-orange">
          Pending
        </span>
      );
    case 'Under Review':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-orange-light text-status-orange">
          Under Review
        </span>
      );
    case 'Approved':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green">
          Approved
        </span>
      );
    case 'Rejected':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-red-light text-status-red">
          Rejected
        </span>
      );
    case 'Paid':
      return (
        <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-status-green-light text-status-green">
          Paid
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

const getExpenseTypeIcon = (expenseType: string) => {
  switch (expenseType) {
    case 'Travel':
      return <Plane className="w-4 h-4 text-blue-600" />;
    case 'Meals':
      return <Utensils className="w-4 h-4 text-green-600" />;
    case 'Transportation':
      return <Car className="w-4 h-4 text-purple-600" />;
    case 'Office Supplies':
      return <Package className="w-4 h-4 text-orange-600" />;
    case 'Training':
      return <UserPlus className="w-4 h-4 text-indigo-600" />;
    case 'Software':
      return <Settings className="w-4 h-4 text-cyan-600" />;
    case 'Hardware':
      return <Laptop className="w-4 h-4 text-gray-600" />;
    case 'Other':
      return <Receipt className="w-4 h-4 text-gray-600" />;
    default:
      return <Receipt className="w-4 h-4 text-gray-600" />;
  }
};

const getExpenseTypeBadge = (expenseType: string) => {
  const typeConfig = {
    'Travel': { bg: 'bg-blue-100', text: 'text-blue-800' },
    'Meals': { bg: 'bg-green-100', text: 'text-green-800' },
    'Transportation': { bg: 'bg-purple-100', text: 'text-purple-800' },
    'Office Supplies': { bg: 'bg-orange-100', text: 'text-orange-800' },
    'Training': { bg: 'bg-indigo-100', text: 'text-indigo-800' },
    'Software': { bg: 'bg-cyan-100', text: 'text-cyan-800' },
    'Hardware': { bg: 'bg-gray-100', text: 'text-gray-800' },
    'Other': { bg: 'bg-gray-100', text: 'text-gray-800' }
  };
  
  const config = typeConfig[expenseType as keyof typeof typeConfig] || typeConfig['Other'];
  
  return (
    <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
      {expenseType}
    </span>
  );
};

export default function TeamExpenses() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'employeeName' | 'expenseType' | 'amount' | 'status' | 'expenseDate'>('expenseDate');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedExpenseType, setSelectedExpenseType] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');

  useEffect(() => {
    // Register submodule tabs for Expenses section
    registerSubmodules('Expenses', [
      { id: 'team-expenses', label: 'Team Expenses', href: '/org/cmp/management/expenses/team-expenses', icon: Receipt }
    ]);
  }, [registerSubmodules]);

  const expenses: Expense[] = [
    {
      id: '1',
      employeeId: 'emp-001',
      employeeName: 'Amanda Foster',
      employeeEmail: 'amanda.foster@arquiluz.com',
      employeeJobTitle: 'Senior UX Designer',
      employeeDepartment: 'Design',
      employeeLocation: 'San Francisco, CA',
      expenseType: 'Travel',
      category: 'Business Trip',
      description: 'Flight to New York for client meeting and design workshop',
      amount: 450.00,
      currency: 'USD',
      expenseDate: '2024-01-10',
      submissionDate: '2024-01-12',
      status: 'Pending',
      receiptUrl: '/receipts/amanda-flight-nyc.pdf',
      notes: 'Client meeting for Q1 project kickoff'
    },
    {
      id: '2',
      employeeId: 'emp-002',
      employeeName: 'Marcus Chen',
      employeeEmail: 'marcus.chen@arquiluz.com',
      employeeJobTitle: 'Full Stack Developer',
      employeeDepartment: 'Engineering',
      employeeLocation: 'Austin, TX',
      expenseType: 'Meals',
      category: 'Client Dinner',
      description: 'Business dinner with potential client to discuss project requirements',
      amount: 125.50,
      currency: 'USD',
      expenseDate: '2024-01-08',
      submissionDate: '2024-01-09',
      status: 'Approved',
      approvedBy: 'Sarah Johnson',
      approvedByEmail: 'sarah.johnson@arquiluz.com',
      approvedByJobTitle: 'Engineering Manager',
      approvedByDepartment: 'Engineering',
      approvedByLocation: 'Austin, TX',
      approvalDate: '2024-01-10',
      receiptUrl: '/receipts/marcus-client-dinner.pdf',
      notes: 'Successful client acquisition meeting'
    },
    {
      id: '3',
      employeeId: 'emp-003',
      employeeName: 'Elena Rodriguez',
      employeeEmail: 'elena.rodriguez@arquiluz.com',
      employeeJobTitle: 'Product Manager',
      employeeDepartment: 'Product',
      employeeLocation: 'Miami, FL',
      expenseType: 'Transportation',
      category: 'Uber Rides',
      description: 'Multiple Uber rides for client meetings across Miami',
      amount: 85.75,
      currency: 'USD',
      expenseDate: '2024-01-15',
      submissionDate: '2024-01-16',
      status: 'Under Review',
      receiptUrl: '/receipts/elena-uber-miami.pdf',
      notes: 'Client site visits for product research'
    },
    {
      id: '4',
      employeeId: 'emp-004',
      employeeName: 'James Wilson',
      employeeEmail: 'james.wilson@arquiluz.com',
      employeeJobTitle: 'Marketing Specialist',
      employeeDepartment: 'Marketing',
      employeeLocation: 'Seattle, WA',
      expenseType: 'Office Supplies',
      category: 'Marketing Materials',
      description: 'Printing costs for marketing campaign materials',
      amount: 320.00,
      currency: 'USD',
      expenseDate: '2024-01-05',
      submissionDate: '2024-01-07',
      status: 'Paid',
      approvedBy: 'Michael Brown',
      approvedByEmail: 'michael.brown@arquiluz.com',
      approvedByJobTitle: 'Marketing Director',
      approvedByDepartment: 'Marketing',
      approvedByLocation: 'Seattle, WA',
      approvalDate: '2024-01-08',
      paymentDate: '2024-01-15',
      receiptUrl: '/receipts/james-printing-materials.pdf',
      notes: 'Q1 marketing campaign launch materials'
    },
    {
      id: '5',
      employeeId: 'emp-005',
      employeeName: 'Sophie Anderson',
      employeeEmail: 'sophie.anderson@arquiluz.com',
      employeeJobTitle: 'Data Analyst',
      employeeDepartment: 'Analytics',
      employeeLocation: 'Denver, CO',
      expenseType: 'Training',
      category: 'Online Course',
      description: 'Advanced SQL and Data Visualization course subscription',
      amount: 199.99,
      currency: 'USD',
      expenseDate: '2024-01-03',
      submissionDate: '2024-01-04',
      status: 'Approved',
      approvedBy: 'David Lee',
      approvedByEmail: 'david.lee@arquiluz.com',
      approvedByJobTitle: 'Analytics Manager',
      approvedByDepartment: 'Analytics',
      approvedByLocation: 'Denver, CO',
      approvalDate: '2024-01-05',
      receiptUrl: '/receipts/sophie-training-course.pdf',
      notes: 'Professional development for data analysis skills'
    },
    {
      id: '6',
      employeeId: 'emp-006',
      employeeName: 'Alex Thompson',
      employeeEmail: 'alex.thompson@arquiluz.com',
      employeeJobTitle: 'DevOps Engineer',
      employeeDepartment: 'Engineering',
      employeeLocation: 'Portland, OR',
      expenseType: 'Software',
      category: 'Development Tools',
      description: 'Annual subscription for cloud monitoring and deployment tools',
      amount: 150.00,
      currency: 'USD',
      expenseDate: '2024-01-01',
      submissionDate: '2024-01-02',
      status: 'Rejected',
      rejectionReason: 'Tool already covered by company license',
      receiptUrl: '/receipts/alex-software-subscription.pdf',
      notes: 'Requested individual license but company has enterprise agreement'
    },
    {
      id: '7',
      employeeId: 'emp-007',
      employeeName: 'Maria Garcia',
      employeeEmail: 'maria.garcia@arquiluz.com',
      employeeJobTitle: 'HR Coordinator',
      employeeDepartment: 'Human Resources',
      employeeLocation: 'Phoenix, AZ',
      expenseType: 'Travel',
      category: 'Conference',
      description: 'HR Technology Conference registration and travel expenses',
      amount: 750.00,
      currency: 'USD',
      expenseDate: '2024-01-20',
      submissionDate: '2024-01-22',
      status: 'Pending',
      receiptUrl: '/receipts/maria-hr-conference.pdf',
      notes: 'Annual HR conference for professional development'
    },
    {
      id: '8',
      employeeId: 'emp-008',
      employeeName: 'David Park',
      employeeEmail: 'david.park@arquiluz.com',
      employeeJobTitle: 'Sales Manager',
      employeeDepartment: 'Sales',
      employeeLocation: 'Los Angeles, CA',
      expenseType: 'Meals',
      category: 'Team Lunch',
      description: 'Team building lunch for sales team quarterly meeting',
      amount: 180.25,
      currency: 'USD',
      expenseDate: '2024-01-18',
      submissionDate: '2024-01-19',
      status: 'Under Review',
      receiptUrl: '/receipts/david-team-lunch.pdf',
      notes: 'Q1 sales team meeting and strategy session'
    },
    {
      id: '9',
      employeeId: 'emp-009',
      employeeName: 'Rachel Brown',
      employeeEmail: 'rachel.brown@arquiluz.com',
      employeeJobTitle: 'Content Writer',
      employeeDepartment: 'Marketing',
      employeeLocation: 'Chicago, IL',
      expenseType: 'Hardware',
      category: 'Computer Accessories',
      description: 'Ergonomic keyboard and mouse for improved productivity',
      amount: 89.99,
      currency: 'USD',
      expenseDate: '2024-01-14',
      submissionDate: '2024-01-15',
      status: 'Approved',
      approvedBy: 'Michael Brown',
      approvedByEmail: 'michael.brown@arquiluz.com',
      approvedByJobTitle: 'Marketing Director',
      approvedByDepartment: 'Marketing',
      approvedByLocation: 'Seattle, WA',
      approvalDate: '2024-01-16',
      receiptUrl: '/receipts/rachel-ergonomic-accessories.pdf',
      notes: 'Ergonomic equipment for long writing sessions'
    },
    {
      id: '10',
      employeeId: 'emp-010',
      employeeName: 'Kevin Lee',
      employeeEmail: 'kevin.lee@arquiluz.com',
      employeeJobTitle: 'QA Engineer',
      employeeDepartment: 'Engineering',
      employeeLocation: 'Boston, MA',
      expenseType: 'Other',
      category: 'Professional Membership',
      description: 'Annual membership fee for Software Testing Association',
      amount: 75.00,
      currency: 'USD',
      expenseDate: '2024-01-12',
      submissionDate: '2024-01-13',
      status: 'Paid',
      approvedBy: 'Sarah Johnson',
      approvedByEmail: 'sarah.johnson@arquiluz.com',
      approvedByJobTitle: 'Engineering Manager',
      approvedByDepartment: 'Engineering',
      approvedByLocation: 'Austin, TX',
      approvalDate: '2024-01-14',
      paymentDate: '2024-01-20',
      receiptUrl: '/receipts/kevin-professional-membership.pdf',
      notes: 'Professional development and networking opportunities'
    }
  ];

  const filteredExpenses = useMemo(() => {
    return expenses.filter(expense => {
      const matchesSearch = 
        expense.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
        expense.category.toLowerCase().includes(searchTerm.toLowerCase()) ||
        expense.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        expense.employeeJobTitle.toLowerCase().includes(searchTerm.toLowerCase()) ||
        expense.employeeDepartment.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesExpenseType = !selectedExpenseType || expense.expenseType === selectedExpenseType;
      const matchesStatus = !selectedStatus || expense.status === selectedStatus;
      const matchesDepartment = !selectedDepartment || expense.employeeDepartment === selectedDepartment;
      
      return matchesSearch && matchesExpenseType && matchesStatus && matchesDepartment;
    });
  }, [expenses, searchTerm, selectedExpenseType, selectedStatus, selectedDepartment]);

  const sortedExpenses = useMemo(() => {
    return [...filteredExpenses].sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;
      
      switch (sortBy) {
        case 'employeeName':
          aValue = a.employeeName;
          bValue = b.employeeName;
          break;
        case 'expenseType':
          aValue = a.expenseType;
          bValue = b.expenseType;
          break;
        case 'amount':
          aValue = a.amount;
          bValue = b.amount;
          break;
        case 'status':
          aValue = a.status;
          bValue = b.status;
          break;
        case 'expenseDate':
          aValue = new Date(a.expenseDate).getTime();
          bValue = new Date(b.expenseDate).getTime();
          break;
        default:
          aValue = a.expenseDate;
          bValue = b.expenseDate;
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
  }, [filteredExpenses, sortBy, sortOrder]);

  const totalPages = Math.ceil(sortedExpenses.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedExpenses = sortedExpenses.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedExpenseType('');
    setSelectedStatus('');
    setSelectedDepartment('');
  };

  const handleApprove = (expenseId: string) => {
    // TODO: Implement approval logic
    console.log('Approving expense:', expenseId);
  };

  const handleReject = (expenseId: string) => {
    // TODO: Implement rejection logic
    console.log('Rejecting expense:', expenseId);
  };

  const expenseTypes = [...new Set(expenses.map(expense => expense.expenseType))];
  const statuses = [...new Set(expenses.map(expense => expense.status))];
  const departments = [...new Set(expenses.map(expense => expense.employeeDepartment))];

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Expenses</h1>
        <p className="text-xs text-muted-foreground">Manage and approve employee expense reimbursements</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Receipt className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">{expenses.filter(e => e.status === 'Pending').length}</div>
              <div className="text-sm text-muted-foreground">Pending</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">{expenses.filter(e => e.status === 'Under Review').length}</div>
              <div className="text-sm text-muted-foreground">Under Review</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">{expenses.filter(e => e.status === 'Approved').length}</div>
              <div className="text-sm text-muted-foreground">Approved</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <DollarSign className="h-5 w-5" style={{ color: '#9E9E9E' }} />
            <div>
              <div className="text-2xl font-bold">${expenses.reduce((sum, e) => sum + e.amount, 0).toLocaleString()}</div>
              <div className="text-sm text-muted-foreground">Total Amount</div>
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
                placeholder="Search expenses, employees, or categories..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search expenses"
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
                value={selectedExpenseType}
                onChange={(e) => setSelectedExpenseType(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by expense type"
                id="expense-type-filter"
              >
                <option value="">All Expense Types</option>
                {expenseTypes.map(type => (
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
                  onClick={() => handleSort('employeeName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'employeeName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Employee
                  {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('expenseType')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'expenseType' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Expense Type
                  {sortBy === 'expenseType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('amount')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'amount' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Amount
                  {sortBy === 'amount' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  onClick={() => handleSort('expenseDate')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'expenseDate' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Expense Date
                  {sortBy === 'expenseDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                    onClick={() => handleSort('expenseType')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Expense Type
                    {sortBy === 'expenseType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  Description
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('amount')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Amount
                    {sortBy === 'amount' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                  <button
                    onClick={() => handleSort('expenseDate')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Expense Date
                    {sortBy === 'expenseDate' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedExpenses.map((expense) => {
                const [firstName, lastName] = expense.employeeName.split(' ');
                const avatarColor = generateAvatarColor(firstName, lastName);
                const avatarInitials = generateAvatarInitials(firstName, lastName);
                
                return (
                  <tr key={expense.id} className="hover:bg-gray-50">
                    <td className="py-2 px-6">
                      <div className="flex items-center gap-3">
                        <div 
                          className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-medium"
                          style={{ backgroundColor: avatarColor }}
                        >
                          {expense.avatar ? (
                            <img 
                              src={expense.avatar} 
                              alt={expense.employeeName}
                              className="w-8 h-8 rounded-full object-cover"
                            />
                          ) : (
                            avatarInitials
                          )}
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">{expense.employeeName}</div>
                          <div className="text-xs text-gray-500">{expense.employeeJobTitle}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-2">
                        {getExpenseTypeIcon(expense.expenseType)}
                        {getExpenseTypeBadge(expense.expenseType)}
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      <div>
                        <div className="text-sm font-medium text-gray-900">{expense.category}</div>
                        <div className="text-xs text-gray-500 max-w-xs truncate">{expense.description}</div>
                      </div>
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900 font-medium">
                        {expense.currency} {expense.amount.toFixed(2)}
                      </span>
                    </td>
                    <td className="py-2 px-4">
                      <span className="text-sm text-gray-900">{new Date(expense.expenseDate).toLocaleDateString()}</span>
                    </td>
                    <td className="py-2 px-4">
                      {getStatusBadge(expense.status)}
                    </td>
                    <td className="py-2 px-4">
                      <div className="flex items-center gap-2">
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`View details for ${expense.category}`}
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        {expense.status === 'Pending' && (
                          <>
                            <button
                              onClick={() => handleApprove(expense.id)}
                              className="p-1 hover:bg-green-100 rounded transition-colors text-green-600"
                              aria-label={`Approve ${expense.category}`}
                            >
                              <Check className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleReject(expense.id)}
                              className="p-1 hover:bg-red-100 rounded transition-colors text-red-600"
                              aria-label={`Reject ${expense.category}`}
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </>
                        )}
                        {expense.status === 'Under Review' && (
                          <>
                            <button
                              onClick={() => handleApprove(expense.id)}
                              className="p-1 hover:bg-green-100 rounded transition-colors text-green-600"
                              aria-label={`Approve ${expense.category}`}
                            >
                              <Check className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleReject(expense.id)}
                              className="p-1 hover:bg-red-100 rounded transition-colors text-red-600"
                              aria-label={`Reject ${expense.category}`}
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </>
                        )}
                        <button
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                          aria-label={`Edit ${expense.category}`}
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, sortedExpenses.length)} of {sortedExpenses.length}
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
                      className={`px-2 py-1 text-xs border rounded transition-colors ${
                        currentPage === pageNum
                          ? 'border-primary bg-primary text-white'
                          : 'border-gray-300 text-gray-700 hover:bg-gray-50'
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