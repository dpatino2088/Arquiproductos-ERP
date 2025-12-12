import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useVendors } from '../../hooks/useDirectory';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { 
  Store, 
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
  Globe,
  DollarSign
} from 'lucide-react';

interface VendorItem {
  id: string;
  vendorName: string;
  vendorId: string;
  phone: string;
  email: string;
  country: string;
  currency: string;
  status: 'Active' | 'Inactive' | 'On Hold' | 'Archived';
  dateAdded: string;
  contactName?: string;
  website?: string;
}

// Function to generate avatar initials from vendor name
const generateAvatarInitials = (vendorName: string) => {
  const words = vendorName.trim().split(/\s+/);
  if (words.length >= 2 && words[0] && words[1]) {
    return `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase();
  }
  return vendorName.substring(0, 2).toUpperCase();
};

// Function to generate a consistent background color based on vendor name
const generateAvatarColor = (vendorName: string) => {
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

export default function Vendors() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'vendorName' | 'vendorId' | 'country' | 'currency' | 'dateAdded'>('vendorName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedCountry, setSelectedCountry] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedCurrency, setSelectedCurrency] = useState<string[]>([]);
  const [showCountryDropdown, setShowCountryDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showCurrencyDropdown, setShowCurrencyDropdown] = useState(false);
  const [countrySearchTerm, setCountrySearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [currencySearchTerm, setCurrencySearchTerm] = useState('');

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
        setShowCountryDropdown(false);
        setShowStatusDropdown(false);
        setShowCurrencyDropdown(false);
        // Clear search terms when closing dropdowns
        setCountrySearchTerm('');
        setStatusSearchTerm('');
        setCurrencySearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Get active organization
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();

  // Prevent hook execution without org
  if (!orgLoading && !activeOrganizationId) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to view vendors.</p>
        </div>
      </div>
    );
  }

  // Get vendors from Supabase
  const { data: vendorsData, isLoading: vendorsLoading, isError: vendorsIsError, error: vendorsError } = useVendors();

  const filteredVendors = useMemo(() => {
    const filtered = vendorsData.filter(vendor => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        vendor.vendorName.toLowerCase().includes(searchLower) ||
        vendor.vendorId.toLowerCase().includes(searchLower) ||
        vendor.email.toLowerCase().includes(searchLower) ||
        vendor.phone.toLowerCase().includes(searchLower) ||
        vendor.country.toLowerCase().includes(searchLower) ||
        vendor.currency.toLowerCase().includes(searchLower) ||
        (vendor.contactName && vendor.contactName.toLowerCase().includes(searchLower))
      );

      // Country filter
      const matchesCountry = selectedCountry.length === 0 || selectedCountry.includes(vendor.country);

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(vendor.status);

      // Currency filter
      const matchesCurrency = selectedCurrency.length === 0 || selectedCurrency.includes(vendor.currency);

      return matchesSearch && matchesCountry && matchesStatus && matchesCurrency;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'vendorName':
          aValue = a.vendorName.toLowerCase();
          bValue = b.vendorName.toLowerCase();
          break;
        case 'vendorId':
          aValue = a.vendorId.toLowerCase();
          bValue = b.vendorId.toLowerCase();
          break;
        case 'country':
          aValue = a.country.toLowerCase();
          bValue = b.country.toLowerCase();
          break;
        case 'currency':
          aValue = a.currency.toLowerCase();
          bValue = b.currency.toLowerCase();
          break;
        case 'dateAdded':
          aValue = new Date(a.dateAdded);
          bValue = new Date(b.dateAdded);
          break;
        default:
          aValue = a.vendorName.toLowerCase();
          bValue = b.vendorName.toLowerCase();
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
  }, [searchTerm, vendorsData, sortBy, sortOrder, selectedCountry, selectedStatus, selectedCurrency]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredVendors.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedVendors = filteredVendors.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedCountry([]);
    setSelectedStatus([]);
    setSelectedCurrency([]);
    setSearchTerm('');
    setCountrySearchTerm('');
    setStatusSearchTerm('');
    setCurrencySearchTerm('');
  };

  // Helper functions for multi-select
  const handleCountryToggle = (country: string) => {
    setSelectedCountry(prev => 
      prev.includes(country) 
        ? prev.filter(c => c !== country)
        : [...prev, country]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleCurrencyToggle = (currency: string) => {
    setSelectedCurrency(prev => 
      prev.includes(currency) 
        ? prev.filter(c => c !== currency)
        : [...prev, currency]
    );
  };

  // Filter options based on search terms
  const getFilteredCountryOptions = () => {
    const countryOptions = ['United States', 'United Kingdom', 'Canada', 'Germany', 'Singapore', 'France', 'Australia', 'Japan'];
    if (!countrySearchTerm) return countryOptions;
    return countryOptions.filter(country => 
      country.toLowerCase().includes(countrySearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Inactive', 'On Hold', 'Archived'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredCurrencyOptions = () => {
    const currencyOptions = ['USD', 'EUR', 'GBP', 'CAD', 'SGD', 'JPY', 'AUD', 'CHF'];
    if (!currencySearchTerm) return currencyOptions;
    return currencyOptions.filter(currency => 
      currency.toLowerCase().includes(currencySearchTerm.toLowerCase())
    );
  };

  // Navigate to vendor detail page
  const handleViewVendor = (vendor: VendorItem) => {
    router.navigate(`/directory/vendors/edit/${vendor.id}`);
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

  // Show loading state
  if (orgLoading || vendorsLoading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading vendors...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state
  if (vendorsIsError && vendorsError) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading vendors</p>
          <p className="text-sm text-red-700">{vendorsError}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Vendors Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredVendors.length} vendors${filteredVendors.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button
            onClick={() => router.navigate('/directory/vendors/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Vendor
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
                placeholder="Search vendors by name, vendor ID, email, phone, country, or currency..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search vendors"
                id="vendor-search"
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
              {/* Country Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowCountryDropdown(!showCountryDropdown)}>
                  <span className="text-gray-700">
                    {selectedCountry.length === 0 ? 'All Countries' : 
                     selectedCountry.length === 1 ? selectedCountry[0] :
                     `${selectedCountry.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showCountryDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search countries..."
                          value={countrySearchTerm}
                          onChange={(e) => setCountrySearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedCountry.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedCountry([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedCountry.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredCountryOptions().map((country) => (
                      <div key={country} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleCountryToggle(country)}>
                        <input type="checkbox" checked={selectedCountry.includes(country)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{country}</span>
                      </div>
                    ))}
                    {getFilteredCountryOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No countries found
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

              {/* Currency Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowCurrencyDropdown(!showCurrencyDropdown)}>
                  <span className="text-gray-700">
                    {selectedCurrency.length === 0 ? 'All Currencies' : 
                     selectedCurrency.length === 1 ? selectedCurrency[0] :
                     `${selectedCurrency.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showCurrencyDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search currencies..."
                          value={currencySearchTerm}
                          onChange={(e) => setCurrencySearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedCurrency.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedCurrency([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedCurrency.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredCurrencyOptions().map((currency) => (
                      <div key={currency} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleCurrencyToggle(currency)}>
                        <input type="checkbox" checked={selectedCurrency.includes(currency)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{currency}</span>
                      </div>
                    ))}
                    {getFilteredCurrencyOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No currencies found
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
                  onClick={() => handleSort('vendorName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'vendorName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Vendor Name
                  {sortBy === 'vendorName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('country')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'country' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Country
                  {sortBy === 'country' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('currency')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'currency' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Currency
                  {sortBy === 'currency' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                <col style={{ width: '20%' }} /> {/* Vendor - base width */}
                <col style={{ width: '12%' }} /> {/* Vendor ID - base * 0.618 */}
                <col style={{ width: '15%' }} /> {/* Phone - base * 0.75 */}
                <col style={{ width: '18%' }} /> {/* Email - base * 0.9 */}
                <col style={{ width: '15%' }} /> {/* Country - base * 0.75 */}
                <col style={{ width: '10%' }} /> {/* Currency - base * 0.5 */}
                <col style={{ width: '5%' }} />  {/* Actions - fixed small */}
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                    <button
                      onClick={() => handleSort('vendorName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Vendor
                      {sortBy === 'vendorName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>
                    <button
                      onClick={() => handleSort('vendorId')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Vendor ID
                      {sortBy === 'vendorId' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>Phone</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.9rem', paddingRight: '0.9rem' }}>Email</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>
                    <button
                      onClick={() => handleSort('country')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Country
                      {sortBy === 'country' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>
                    <button
                      onClick={() => handleSort('currency')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Currency
                      {sortBy === 'currency' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredVendors.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center">
                      <Store className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No vendors found</p>
                      <p className="text-sm text-gray-500">
                        {vendorsData.length === 0 
                          ? 'Start by adding vendors to your directory'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedVendors.map((vendor) => (
                    <tr key={vendor.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div 
                              className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" 
                              style={{ backgroundColor: generateAvatarColor(vendor.vendorName) }}
                            >
                              {generateAvatarInitials(vendor.vendorName)}
                            </div>
                            <div 
                              className={`absolute -bottom-0.5 -right-0.5 ${getDotSize('sm')} rounded-full border border-white`}
                              style={{
                                backgroundColor: 
                                  vendor.status === 'Active' ? 'var(--avatar-status-green)' :
                                  vendor.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                                  vendor.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                                  vendor.status === 'Archived' ? 'var(--avatar-status-purple)' :
                                  'var(--avatar-status-gray)'
                              }}>
                            </div>
                          </div>
                          <div>
                            <div className="font-medium text-gray-900 text-sm">
                              {vendor.vendorName}
                            </div>
                            {vendor.contactName && (
                              <div className="text-xs" style={{ color: 'var(--gray-500)' }}>{vendor.contactName}</div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>{vendor.vendorId}</td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{vendor.phone}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '0.9rem', paddingRight: '0.9rem' }}>
                        <div className="truncate" title={vendor.email}>
                          {vendor.email}
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{vendor.country}</td>
                      <td className="py-4 text-gray-900 text-sm font-medium" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>{vendor.currency}</td>
                      <td className="py-2" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>
                        <div className="flex items-center">
                          <button 
                            onClick={() => handleViewVendor(vendor)}
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${vendor.vendorName}`}
                            title={`View ${vendor.vendorName}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button 
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`More options for ${vendor.vendorName}`}
                            title={`More options for ${vendor.vendorName}`}
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
          {filteredVendors.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <Store className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No vendors found</p>
              <p className="text-sm text-gray-500">
                {vendorsData.length === 0 
                  ? 'Start by adding vendors to your directory'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedVendors.map((vendor) => (
                <div
                  key={vendor.id}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6"
                >
                  {/* Vendor Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base" 
                        style={{ backgroundColor: generateAvatarColor(vendor.vendorName) }}
                      >
                        {generateAvatarInitials(vendor.vendorName)}
                      </div>
                      <div 
                        className={`absolute -bottom-1 -right-1 ${getDotSize('lg')} rounded-full border-2 border-white`}
                        style={{
                          backgroundColor: 
                            vendor.status === 'Active' ? 'var(--avatar-status-green)' :
                            vendor.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                            vendor.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                            vendor.status === 'Archived' ? 'var(--avatar-status-purple)' :
                            'var(--avatar-status-gray)'
                        }}>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
                        {vendor.vendorName}
                      </h3>
                      <p className="text-xs text-gray-600 font-mono">{vendor.vendorId}</p>
                      <div className="mt-1">
                        {getStatusBadge(vendor.status)}
                      </div>
                    </div>
                    <button 
                      onClick={() => handleViewVendor(vendor)}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Edit ${vendor.vendorName}`}
                      title={`Edit ${vendor.vendorName}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Vendor Info */}
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Phone className="w-3 h-3 flex-shrink-0" />
                      <span>{vendor.phone}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Mail className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{vendor.email}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Globe className="w-3 h-3 flex-shrink-0" />
                      <span>{vendor.country}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <DollarSign className="w-3 h-3 flex-shrink-0" />
                      <span className="font-medium">{vendor.currency}</span>
                    </div>
                    {vendor.contactName && (
                      <div className="flex items-center gap-2 text-xs text-gray-500">
                        <span>Contact: {vendor.contactName}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Added {new Date(vendor.dateAdded).toLocaleDateString()}</span>
                    </div>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredVendors.length)} of {filteredVendors.length}
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
