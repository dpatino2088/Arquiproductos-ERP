import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { 
  Users, 
  Search, 
  Filter,
  Plus,
  Upload,
  Eye,
  MoreVertical,
  ChevronLeft,
  ChevronRight,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Mail,
  Phone,
  MapPin,
  Calendar,
  Edit,
  Building,
  DollarSign
} from 'lucide-react';

interface CustomerItem {
  id: string;
  companyName: string;
  contactName: string;
  email: string;
  phone: string;
  industry: string;
  customerType: 'Enterprise' | 'SMB' | 'Startup' | 'Individual';
  status: 'Active' | 'Inactive' | 'On Hold' | 'Archived';
  location: string;
  dateAdded: string;
  totalRevenue?: number;
  avatar?: string;
}

// Function to generate avatar initials from company name
const generateAvatarInitials = (companyName: string) => {
  const words = companyName.trim().split(/\s+/);
  if (words.length >= 2) {
    return `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase();
  }
  return companyName.substring(0, 2).toUpperCase();
};

// Function to generate a consistent background color based on company name
const generateAvatarColor = (companyName: string) => {
  return 'var(--primary-brand-hex)'; // Primary brand color
};

// Function to get proportional dot size based on avatar size
const getDotSize = (avatarSize: 'sm' | 'md' | 'lg') => {
  switch (avatarSize) {
    case 'sm': // w-8 h-8 (32px)
      return 'w-2.5 h-2.5'; // 10px
    case 'md': // w-10 h-10 (40px)
      return 'w-3.5 h-3.5'; // 14px
    case 'lg': // w-12 h-12 (48px)
      return 'w-4 h-4'; // 16px
    default:
      return 'w-2.5 h-2.5';
  }
};

export default function Customers() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'companyName' | 'industry' | 'customerType' | 'dateAdded'>('companyName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedIndustry, setSelectedIndustry] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedCustomerType, setSelectedCustomerType] = useState<string[]>([]);
  const [selectedLocation, setSelectedLocation] = useState<string[]>([]);
  const [showIndustryDropdown, setShowIndustryDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showCustomerTypeDropdown, setShowCustomerTypeDropdown] = useState(false);
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  const [industrySearchTerm, setIndustrySearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [customerTypeSearchTerm, setCustomerTypeSearchTerm] = useState('');
  const [locationSearchTerm, setLocationSearchTerm] = useState('');

  useEffect(() => {
    registerSubmodules('Directory', [
      { id: 'contacts', label: 'Contacts', href: '/directory/contacts' },
      { id: 'customers', label: 'Customers', href: '/directory/customers' },
      { id: 'sites', label: 'Sites', href: '/directory/sites' },
      { id: 'vendors', label: 'Vendors', href: '/directory/vendors' },
      { id: 'contractors', label: 'Contractors', href: '/directory/contractors' },
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowIndustryDropdown(false);
        setShowStatusDropdown(false);
        setShowCustomerTypeDropdown(false);
        setShowLocationDropdown(false);
        // Clear search terms when closing dropdowns
        setIndustrySearchTerm('');
        setStatusSearchTerm('');
        setCustomerTypeSearchTerm('');
        setLocationSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Mock data for customers - replace with actual data source
  const customers: CustomerItem[] = useMemo(() => [
    {
      id: '1',
      companyName: 'Acme Corporation',
      contactName: 'John Smith',
      email: 'john.smith@acme.com',
      phone: '+1 (555) 123-4567',
      industry: 'Technology',
      customerType: 'Enterprise',
      status: 'Active',
      location: 'San Francisco, CA',
      dateAdded: '2024-01-15',
      totalRevenue: 125000
    },
    {
      id: '2',
      companyName: 'TechCorp Inc',
      contactName: 'Sarah Johnson',
      email: 'sarah.j@techcorp.com',
      phone: '+1 (555) 234-5678',
      industry: 'Software',
      customerType: 'SMB',
      status: 'Active',
      location: 'Seattle, WA',
      dateAdded: '2024-02-20',
      totalRevenue: 45000
    },
    {
      id: '3',
      companyName: 'Global Solutions',
      contactName: 'Michael Brown',
      email: 'm.brown@global.com',
      phone: '+1 (555) 345-6789',
      industry: 'Consulting',
      customerType: 'Enterprise',
      status: 'Active',
      location: 'New York, NY',
      dateAdded: '2024-03-10',
      totalRevenue: 250000
    },
    {
      id: '4',
      companyName: 'StartupCo',
      contactName: 'Emily Davis',
      email: 'emily.davis@startup.io',
      phone: '+1 (555) 456-7890',
      industry: 'E-commerce',
      customerType: 'Startup',
      status: 'On Hold',
      location: 'Austin, TX',
      dateAdded: '2023-12-05',
      totalRevenue: 15000
    },
    {
      id: '5',
      companyName: 'Digital Ventures',
      contactName: 'David Wilson',
      email: 'd.wilson@digital.com',
      phone: '+1 (555) 567-8901',
      industry: 'Marketing',
      customerType: 'SMB',
      status: 'Active',
      location: 'Portland, OR',
      dateAdded: '2024-01-30',
      totalRevenue: 32000
    }
  ], []);

  const filteredCustomers = useMemo(() => {
    const filtered = customers.filter(customer => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        customer.companyName.toLowerCase().includes(searchLower) ||
        customer.contactName.toLowerCase().includes(searchLower) ||
        customer.email.toLowerCase().includes(searchLower) ||
        customer.industry.toLowerCase().includes(searchLower) ||
        customer.phone.toLowerCase().includes(searchLower)
      );

      // Industry filter
      const matchesIndustry = selectedIndustry.length === 0 || selectedIndustry.includes(customer.industry);

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(customer.status);

      // Customer type filter
      const matchesCustomerType = selectedCustomerType.length === 0 || selectedCustomerType.includes(customer.customerType);

      // Location filter
      const matchesLocation = selectedLocation.length === 0 || selectedLocation.includes(customer.location);

      return matchesSearch && matchesIndustry && matchesStatus && matchesCustomerType && matchesLocation;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date | number;
      let bValue: string | Date | number;

      switch (sortBy) {
        case 'companyName':
          aValue = a.companyName.toLowerCase();
          bValue = b.companyName.toLowerCase();
          break;
        case 'industry':
          aValue = a.industry.toLowerCase();
          bValue = b.industry.toLowerCase();
          break;
        case 'customerType':
          aValue = a.customerType.toLowerCase();
          bValue = b.customerType.toLowerCase();
          break;
        case 'dateAdded':
          aValue = new Date(a.dateAdded);
          bValue = new Date(b.dateAdded);
          break;
        default:
          aValue = a.companyName.toLowerCase();
          bValue = b.companyName.toLowerCase();
      }

      if (sortBy === 'dateAdded') {
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
  }, [searchTerm, customers, sortBy, sortOrder, selectedIndustry, selectedStatus, selectedCustomerType, selectedLocation]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredCustomers.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedCustomers = filteredCustomers.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedIndustry([]);
    setSelectedStatus([]);
    setSelectedCustomerType([]);
    setSelectedLocation([]);
    setSearchTerm('');
    setIndustrySearchTerm('');
    setStatusSearchTerm('');
    setCustomerTypeSearchTerm('');
    setLocationSearchTerm('');
  };

  // Helper functions for multi-select
  const handleIndustryToggle = (industry: string) => {
    setSelectedIndustry(prev => 
      prev.includes(industry) 
        ? prev.filter(i => i !== industry)
        : [...prev, industry]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleCustomerTypeToggle = (customerType: string) => {
    setSelectedCustomerType(prev => 
      prev.includes(customerType) 
        ? prev.filter(c => c !== customerType)
        : [...prev, customerType]
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
  const getFilteredIndustryOptions = () => {
    const industryOptions = ['Technology', 'Software', 'Consulting', 'E-commerce', 'Marketing', 'Healthcare', 'Finance', 'Retail'];
    if (!industrySearchTerm) return industryOptions;
    return industryOptions.filter(industry => 
      industry.toLowerCase().includes(industrySearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Inactive', 'On Hold', 'Archived'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredCustomerTypeOptions = () => {
    const customerTypeOptions = ['Enterprise', 'SMB', 'Startup', 'Individual'];
    if (!customerTypeSearchTerm) return customerTypeOptions;
    return customerTypeOptions.filter(type => 
      type.toLowerCase().includes(customerTypeSearchTerm.toLowerCase())
    );
  };

  const getFilteredLocationOptions = () => {
    const locationOptions = ['San Francisco, CA', 'Seattle, WA', 'Portland, OR', 'Austin, TX', 'New York, NY'];
    if (!locationSearchTerm) return locationOptions;
    return locationOptions.filter(location => 
      location.toLowerCase().includes(locationSearchTerm.toLowerCase())
    );
  };

  // Navigate to customer detail page (placeholder)
  const handleViewCustomer = (customer: CustomerItem) => {
    // Store customer data in sessionStorage for the Customer Info page
    sessionStorage.setItem('selectedCustomer', JSON.stringify(customer));
    
    // Create slug from company name
    const slug = customer.companyName.toLowerCase().replace(/\s+/g, '-');
    
    // Navigate to customer detail (you can create this page later)
    // router.navigate(`/directory/customers/${slug}`);
    console.log('View customer:', customer);
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Active':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
            Active
          </span>
        );
      case 'Inactive':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
            Inactive
          </span>
        );
      case 'On Hold':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
            On Hold
          </span>
        );
      case 'Archived':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-50 text-status-purple">
            Archived
          </span>
        );
      default:
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: 'color-mix(in srgb, var(--neutral-gray) 10%, transparent)', color: 'var(--neutral-gray)' }}>
            {status}
          </span>
        );
    }
  };

  const getCustomerTypeBadge = (type: string) => {
    switch (type) {
      case 'Enterprise':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
            Enterprise
          </span>
        );
      case 'SMB':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
            SMB
          </span>
        );
      case 'Startup':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-50 text-status-purple">
            Startup
          </span>
        );
      case 'Individual':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
            Individual
          </span>
        );
      default:
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium" style={{ backgroundColor: 'color-mix(in srgb, var(--neutral-gray) 10%, transparent)', color: 'var(--neutral-gray)' }}>
            {type}
          </span>
        );
    }
  };

  const formatCurrency = (amount?: number) => {
    if (!amount) return 'N/A';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Customers Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredCustomers.length} customers${filteredCustomers.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button
            onClick={() => router.navigate('/directory/customers/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Customer
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
                placeholder="Search customers by company name, contact, email, industry, or phone..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search customers"
                id="customer-search"
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
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
              {/* Industry Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowIndustryDropdown(!showIndustryDropdown)}>
                  <span className="text-gray-700">
                    {selectedIndustry.length === 0 ? 'All Industries' : 
                     selectedIndustry.length === 1 ? selectedIndustry[0] :
                     `${selectedIndustry.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showIndustryDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search industries..."
                          value={industrySearchTerm}
                          onChange={(e) => setIndustrySearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedIndustry.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedIndustry([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedIndustry.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredIndustryOptions().map((industry) => (
                      <div key={industry} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleIndustryToggle(industry)}>
                        <input type="checkbox" checked={selectedIndustry.includes(industry)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{industry}</span>
                      </div>
                    ))}
                    {getFilteredIndustryOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No industries found
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

              {/* Customer Type Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowCustomerTypeDropdown(!showCustomerTypeDropdown)}>
                  <span className="text-gray-700">
                    {selectedCustomerType.length === 0 ? 'All Customer Types' : 
                     selectedCustomerType.length === 1 ? selectedCustomerType[0] :
                     `${selectedCustomerType.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showCustomerTypeDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search customer types..."
                          value={customerTypeSearchTerm}
                          onChange={(e) => setCustomerTypeSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedCustomerType.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedCustomerType([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedCustomerType.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredCustomerTypeOptions().map((customerType) => (
                      <div key={customerType} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleCustomerTypeToggle(customerType)}>
                        <input type="checkbox" checked={selectedCustomerType.includes(customerType)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{customerType}</span>
                      </div>
                    ))}
                    {getFilteredCustomerTypeOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No customer types found
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
                  onClick={() => handleSort('companyName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'companyName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Company
                  {sortBy === 'companyName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('industry')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'industry' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Industry
                  {sortBy === 'industry' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('dateAdded')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'dateAdded' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Date Added
                  {sortBy === 'dateAdded' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
            <table className="w-full table-fixed">
              <colgroup>
                <col style={{ width: '20%' }} /> {/* Customer - base width */}
                <col style={{ width: '15%' }} /> {/* Contact - base * 0.75 */}
                <col style={{ width: '15%' }} /> {/* Industry - base * 0.75 */}
                <col style={{ width: '12%' }} /> {/* Customer Type - base * 0.618 */}
                <col style={{ width: '10%' }} /> {/* Status - base * 0.5 */}
                <col style={{ width: '13%' }} /> {/* Location - base * 0.65 */}
                <col style={{ width: '10%' }} /> {/* Date Added - base * 0.5 */}
                <col style={{ width: '5%' }} />  {/* Actions - fixed small */}
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                    <button
                      onClick={() => handleSort('companyName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Customer
                      {sortBy === 'companyName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>Contact</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>
                    <button
                      onClick={() => handleSort('industry')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Industry
                      {sortBy === 'industry' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>Customer Type</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>Status</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>Location</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>
                    <button
                      onClick={() => handleSort('dateAdded')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Date Added
                      {sortBy === 'dateAdded' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredCustomers.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-12 text-center">
                      <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No customers found</p>
                      <p className="text-sm text-gray-500">
                        {customers.length === 0 
                          ? 'Start by adding customers to your directory'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedCustomers.map((customer) => (
                    <tr key={customer.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div 
                              className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" 
                              style={{ backgroundColor: generateAvatarColor(customer.companyName) }}
                            >
                              {generateAvatarInitials(customer.companyName)}
                            </div>
                            <div 
                              className={`absolute -bottom-0.5 -right-0.5 ${getDotSize('sm')} rounded-full border border-white`}
                              style={{
                                backgroundColor: 
                                  customer.status === 'Active' ? 'var(--avatar-status-green)' :
                                  customer.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                                  customer.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                                  customer.status === 'Archived' ? 'var(--avatar-status-purple)' :
                                  'var(--avatar-status-gray)'
                              }}>
                            </div>
                          </div>
                          <div>
                            <div className="font-medium text-gray-900 text-sm">
                              {customer.companyName}
                            </div>
                            <div className="text-xs" style={{ color: 'var(--gray-500)' }}>{customer.email}</div>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{customer.contactName}</td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{customer.industry}</td>
                      <td className="py-4" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>{getCustomerTypeBadge(customer.customerType)}</td>
                      <td className="py-4" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>{getStatusBadge(customer.status)}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>{customer.location}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>{new Date(customer.dateAdded).toLocaleDateString()}</td>
                      <td className="py-2" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>
                        <div className="flex items-center">
                          <button 
                            onClick={() => handleViewCustomer(customer)}
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${customer.companyName}`}
                            title={`View ${customer.companyName}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button 
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`More options for ${customer.companyName}`}
                            title={`More options for ${customer.companyName}`}
                          >
                            <MoreVertical className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Grid View */}
      {viewMode === 'grid' && (
        <>
          {filteredCustomers.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No customers found</p>
              <p className="text-sm text-gray-500">
                {customers.length === 0 
                  ? 'Start by adding customers to your directory'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedCustomers.map((customer) => (
                <div
                  key={customer.id}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6"
                >
                  {/* Customer Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base" 
                        style={{ backgroundColor: generateAvatarColor(customer.companyName) }}
                      >
                        {generateAvatarInitials(customer.companyName)}
                      </div>
                      <div 
                        className={`absolute -bottom-1 -right-1 ${getDotSize('lg')} rounded-full border-2 border-white`}
                        style={{
                          backgroundColor: 
                            customer.status === 'Active' ? 'var(--avatar-status-green)' :
                            customer.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                            customer.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                            customer.status === 'Archived' ? 'var(--avatar-status-purple)' :
                            'var(--avatar-status-gray)'
                        }}>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
                        {customer.companyName}
                      </h3>
                      <p className="text-xs text-gray-600 truncate">{customer.contactName}</p>
                      <div className="mt-1 flex gap-1">
                        {getStatusBadge(customer.status)}
                        {getCustomerTypeBadge(customer.customerType)}
                      </div>
                    </div>
                    <button 
                      onClick={() => handleViewCustomer(customer)}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Edit ${customer.companyName}`}
                      title={`Edit ${customer.companyName}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Customer Info */}
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Mail className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{customer.email}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Phone className="w-3 h-3 flex-shrink-0" />
                      <span>{customer.phone}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <MapPin className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{customer.location}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Building className="w-3 h-3 flex-shrink-0" />
                      <span>{customer.industry}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Added {new Date(customer.dateAdded).toLocaleDateString()}</span>
                    </div>
                    {customer.totalRevenue && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <DollarSign className="w-3 h-3 flex-shrink-0" />
                        <span className="font-medium">{formatCurrency(customer.totalRevenue)}</span>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredCustomers.length)} of {filteredCustomers.length}
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
