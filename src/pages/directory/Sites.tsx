import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { 
  MapPin, 
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
  Map,
  SortAsc,
  SortDesc,
  Mail,
  Phone,
  Calendar,
  Edit,
  Building,
  Globe
} from 'lucide-react';

interface SiteItem {
  id: string;
  siteName: string;
  siteId: string;
  siteAddress: string;
  country: string;
  city?: string;
  state?: string;
  postalCode?: string;
  latitude?: number;
  longitude?: number;
  siteType: 'Branch' | 'Warehouse' | 'Office' | 'Retail' | 'Manufacturing' | 'Distribution';
  status: 'Active' | 'Inactive' | 'Under Construction' | 'Archived';
  dateAdded: string;
  contactName?: string;
  contactEmail?: string;
  contactPhone?: string;
}

// Function to generate avatar initials from site name
const generateAvatarInitials = (siteName: string) => {
  const words = siteName.trim().split(/\s+/);
  if (words.length >= 2) {
    return `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase();
  }
  return siteName.substring(0, 2).toUpperCase();
};

// Function to generate a consistent background color based on site name
const generateAvatarColor = (siteName: string) => {
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

export default function Sites() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid' | 'map'>('table');
  const [sortBy, setSortBy] = useState<'siteName' | 'siteId' | 'country' | 'siteType' | 'dateAdded'>('siteName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedSiteType, setSelectedSiteType] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedCountry, setSelectedCountry] = useState<string[]>([]);
  const [showSiteTypeDropdown, setShowSiteTypeDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showCountryDropdown, setShowCountryDropdown] = useState(false);
  const [siteTypeSearchTerm, setSiteTypeSearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [countrySearchTerm, setCountrySearchTerm] = useState('');

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
        setShowSiteTypeDropdown(false);
        setShowStatusDropdown(false);
        setShowCountryDropdown(false);
        // Clear search terms when closing dropdowns
        setSiteTypeSearchTerm('');
        setStatusSearchTerm('');
        setCountrySearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Mock data for sites - replace with actual data source
  const sites: SiteItem[] = useMemo(() => [
    {
      id: '1',
      siteName: 'Main Headquarters',
      siteId: 'SITE-001',
      siteAddress: '123 Business Park Drive',
      country: 'United States',
      city: 'San Francisco',
      state: 'CA',
      postalCode: '94105',
      latitude: 37.7749,
      longitude: -122.4194,
      siteType: 'Office',
      status: 'Active',
      dateAdded: '2024-01-15',
      contactName: 'John Smith',
      contactEmail: 'john.smith@company.com',
      contactPhone: '+1 (555) 123-4567'
    },
    {
      id: '2',
      siteName: 'West Coast Warehouse',
      siteId: 'SITE-002',
      siteAddress: '456 Industrial Blvd',
      country: 'United States',
      city: 'Seattle',
      state: 'WA',
      postalCode: '98101',
      latitude: 47.6062,
      longitude: -122.3321,
      siteType: 'Warehouse',
      status: 'Active',
      dateAdded: '2024-02-20',
      contactName: 'Sarah Johnson',
      contactEmail: 'sarah.j@company.com',
      contactPhone: '+1 (555) 234-5678'
    },
    {
      id: '3',
      siteName: 'Distribution Center',
      siteId: 'SITE-003',
      siteAddress: '789 Logistics Way',
      country: 'United States',
      city: 'Portland',
      state: 'OR',
      postalCode: '97201',
      latitude: 45.5152,
      longitude: -122.6784,
      siteType: 'Distribution',
      status: 'Active',
      dateAdded: '2024-03-10',
      contactName: 'Michael Brown',
      contactEmail: 'm.brown@company.com',
      contactPhone: '+1 (555) 345-6789'
    },
    {
      id: '4',
      siteName: 'Retail Store Downtown',
      siteId: 'SITE-004',
      siteAddress: '321 Main Street',
      country: 'United States',
      city: 'Austin',
      state: 'TX',
      postalCode: '78701',
      latitude: 30.2672,
      longitude: -97.7431,
      siteType: 'Retail',
      status: 'Active',
      dateAdded: '2023-12-05',
      contactName: 'Emily Davis',
      contactEmail: 'emily.d@company.com',
      contactPhone: '+1 (555) 456-7890'
    },
    {
      id: '5',
      siteName: 'Manufacturing Plant',
      siteId: 'SITE-005',
      siteAddress: '654 Production Ave',
      country: 'United States',
      city: 'Detroit',
      state: 'MI',
      postalCode: '48201',
      latitude: 42.3314,
      longitude: -83.0458,
      siteType: 'Manufacturing',
      status: 'Under Construction',
      dateAdded: '2024-01-30',
      contactName: 'David Wilson',
      contactEmail: 'd.wilson@company.com',
      contactPhone: '+1 (555) 567-8901'
    }
  ], []);

  const filteredSites = useMemo(() => {
    const filtered = sites.filter(site => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        site.siteName.toLowerCase().includes(searchLower) ||
        site.siteId.toLowerCase().includes(searchLower) ||
        site.siteAddress.toLowerCase().includes(searchLower) ||
        site.country.toLowerCase().includes(searchLower) ||
        (site.city && site.city.toLowerCase().includes(searchLower)) ||
        (site.contactName && site.contactName.toLowerCase().includes(searchLower)) ||
        (site.contactEmail && site.contactEmail.toLowerCase().includes(searchLower))
      );

      // Site type filter
      const matchesSiteType = selectedSiteType.length === 0 || selectedSiteType.includes(site.siteType);

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(site.status);

      // Country filter
      const matchesCountry = selectedCountry.length === 0 || selectedCountry.includes(site.country);

      return matchesSearch && matchesSiteType && matchesStatus && matchesCountry;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'siteName':
          aValue = a.siteName.toLowerCase();
          bValue = b.siteName.toLowerCase();
          break;
        case 'siteId':
          aValue = a.siteId.toLowerCase();
          bValue = b.siteId.toLowerCase();
          break;
        case 'country':
          aValue = a.country.toLowerCase();
          bValue = b.country.toLowerCase();
          break;
        case 'siteType':
          aValue = a.siteType.toLowerCase();
          bValue = b.siteType.toLowerCase();
          break;
        case 'dateAdded':
          aValue = new Date(a.dateAdded);
          bValue = new Date(b.dateAdded);
          break;
        default:
          aValue = a.siteName.toLowerCase();
          bValue = b.siteName.toLowerCase();
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
  }, [searchTerm, sites, sortBy, sortOrder, selectedSiteType, selectedStatus, selectedCountry]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredSites.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedSites = filteredSites.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedSiteType([]);
    setSelectedStatus([]);
    setSelectedCountry([]);
    setSearchTerm('');
    setSiteTypeSearchTerm('');
    setStatusSearchTerm('');
    setCountrySearchTerm('');
  };

  // Helper functions for multi-select
  const handleSiteTypeToggle = (siteType: string) => {
    setSelectedSiteType(prev => 
      prev.includes(siteType) 
        ? prev.filter(t => t !== siteType)
        : [...prev, siteType]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleCountryToggle = (country: string) => {
    setSelectedCountry(prev => 
      prev.includes(country) 
        ? prev.filter(c => c !== country)
        : [...prev, country]
    );
  };

  // Filter options based on search terms
  const getFilteredSiteTypeOptions = () => {
    const siteTypeOptions = ['Branch', 'Warehouse', 'Office', 'Retail', 'Manufacturing', 'Distribution'];
    if (!siteTypeSearchTerm) return siteTypeOptions;
    return siteTypeOptions.filter(type => 
      type.toLowerCase().includes(siteTypeSearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Inactive', 'Under Construction', 'Archived'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredCountryOptions = () => {
    const countryOptions = ['United States', 'Canada', 'Mexico', 'United Kingdom', 'Germany', 'France'];
    if (!countrySearchTerm) return countryOptions;
    return countryOptions.filter(country => 
      country.toLowerCase().includes(countrySearchTerm.toLowerCase())
    );
  };

  // Navigate to site detail page (placeholder)
  const handleViewSite = (site: SiteItem) => {
    // Store site data in sessionStorage for the Site Info page
    sessionStorage.setItem('selectedSite', JSON.stringify(site));
    
    // Create slug from site name
    const slug = site.siteName.toLowerCase().replace(/\s+/g, '-');
    
    // Navigate to site detail (you can create this page later)
    // router.navigate(`/directory/sites/${slug}`);
    console.log('View site:', site);
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
      case 'Under Construction':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
            Under Construction
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

  const getSiteTypeBadge = (type: string) => {
    switch (type) {
      case 'Office':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
            Office
          </span>
        );
      case 'Warehouse':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
            Warehouse
          </span>
        );
      case 'Retail':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-50 text-status-purple">
            Retail
          </span>
        );
      case 'Manufacturing':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-orange-50 text-status-orange">
            Manufacturing
          </span>
        );
      case 'Distribution':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
            Distribution
          </span>
        );
      case 'Branch':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-status-gray">
            Branch
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

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Sites Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredSites.length} sites${filteredSites.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button
            onClick={() => router.navigate('/directory/sites/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Site
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
                placeholder="Search sites by name, site ID, address, country, or contact..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search sites"
                id="site-search"
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
                <button
                  onClick={() => setViewMode('map')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'map'
                      ? 'bg-gray-300 text-black'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                  aria-label="Switch to map view"
                  title="Switch to map view"
                >
                  <Map className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Advanced Filters */}
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
              {/* Site Type Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowSiteTypeDropdown(!showSiteTypeDropdown)}>
                  <span className="text-gray-700">
                    {selectedSiteType.length === 0 ? 'All Site Types' : 
                     selectedSiteType.length === 1 ? selectedSiteType[0] :
                     `${selectedSiteType.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showSiteTypeDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search site types..."
                          value={siteTypeSearchTerm}
                          onChange={(e) => setSiteTypeSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedSiteType.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedSiteType([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedSiteType.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredSiteTypeOptions().map((siteType) => (
                      <div key={siteType} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleSiteTypeToggle(siteType)}>
                        <input type="checkbox" checked={selectedSiteType.includes(siteType)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{siteType}</span>
                      </div>
                    ))}
                    {getFilteredSiteTypeOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No site types found
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
                  onClick={() => handleSort('siteName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'siteName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Site Name
                  {sortBy === 'siteName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('siteType')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'siteType' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Site Type
                  {sortBy === 'siteType' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                <col style={{ width: '20%' }} /> {/* Site - base width */}
                <col style={{ width: '12%' }} /> {/* Site ID - base * 0.618 */}
                <col style={{ width: '24%' }} /> {/* Site Address - base * 1.618 */}
                <col style={{ width: '15%' }} /> {/* Country - base * 0.75 */}
                <col style={{ width: '12%' }} /> {/* Site Type - base * 0.618 */}
                <col style={{ width: '10%' }} /> {/* Status - base * 0.5 */}
                <col style={{ width: '10%' }} /> {/* Date Added - base * 0.5 */}
                <col style={{ width: '7%' }} />  {/* Actions - fixed small */}
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                    <button
                      onClick={() => handleSort('siteName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Site
                      {sortBy === 'siteName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>
                    <button
                      onClick={() => handleSort('siteId')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Site ID
                      {sortBy === 'siteId' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '1rem', paddingRight: '1.618rem' }}>Site Address</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>
                    <button
                      onClick={() => handleSort('country')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Country
                      {sortBy === 'country' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>Site Type</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>Status</th>
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
                {filteredSites.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-12 text-center">
                      <MapPin className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No sites found</p>
                      <p className="text-sm text-gray-500">
                        {sites.length === 0 
                          ? 'Start by adding sites to your directory'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedSites.map((site) => (
                    <tr key={site.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div 
                              className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" 
                              style={{ backgroundColor: generateAvatarColor(site.siteName) }}
                            >
                              {generateAvatarInitials(site.siteName)}
                            </div>
                            <div 
                              className={`absolute -bottom-0.5 -right-0.5 ${getDotSize('sm')} rounded-full border border-white`}
                              style={{
                                backgroundColor: 
                                  site.status === 'Active' ? 'var(--avatar-status-green)' :
                                  site.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                                  site.status === 'Under Construction' ? 'var(--avatar-status-orange)' :
                                  site.status === 'Archived' ? 'var(--avatar-status-purple)' :
                                  'var(--avatar-status-gray)'
                              }}>
                            </div>
                          </div>
                          <div>
                            <div className="font-medium text-gray-900 text-sm">
                              {site.siteName}
                            </div>
                            {site.city && site.state && (
                              <div className="text-xs" style={{ color: 'var(--gray-500)' }}>
                                {site.city}, {site.state}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>{site.siteId}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '1rem', paddingRight: '1.618rem' }}>
                        <div className="truncate" title={site.siteAddress}>
                          {site.siteAddress}
                        </div>
                        {site.postalCode && (
                          <div className="text-xs" style={{ color: 'var(--gray-500)' }}>
                            {site.postalCode}
                          </div>
                        )}
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{site.country}</td>
                      <td className="py-4" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>{getSiteTypeBadge(site.siteType)}</td>
                      <td className="py-4" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>{getStatusBadge(site.status)}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '0.5rem', paddingRight: '0.5rem' }}>{new Date(site.dateAdded).toLocaleDateString()}</td>
                      <td className="py-2" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>
                        <div className="flex items-center">
                          <button 
                            onClick={() => handleViewSite(site)}
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${site.siteName}`}
                            title={`View ${site.siteName}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button 
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`More options for ${site.siteName}`}
                            title={`More options for ${site.siteName}`}
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
          {filteredSites.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <MapPin className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No sites found</p>
              <p className="text-sm text-gray-500">
                {sites.length === 0 
                  ? 'Start by adding sites to your directory'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedSites.map((site) => (
                <div
                  key={site.id}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6"
                >
                  {/* Site Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base" 
                        style={{ backgroundColor: generateAvatarColor(site.siteName) }}
                      >
                        {generateAvatarInitials(site.siteName)}
                      </div>
                      <div 
                        className={`absolute -bottom-1 -right-1 ${getDotSize('lg')} rounded-full border-2 border-white`}
                        style={{
                          backgroundColor: 
                            site.status === 'Active' ? 'var(--avatar-status-green)' :
                            site.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                            site.status === 'Under Construction' ? 'var(--avatar-status-orange)' :
                            site.status === 'Archived' ? 'var(--avatar-status-purple)' :
                            'var(--avatar-status-gray)'
                        }}>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
                        {site.siteName}
                      </h3>
                      <p className="text-xs text-gray-600 font-mono">{site.siteId}</p>
                      <div className="mt-1 flex gap-1 flex-wrap">
                        {getStatusBadge(site.status)}
                        {getSiteTypeBadge(site.siteType)}
                      </div>
                    </div>
                    <button 
                      onClick={() => handleViewSite(site)}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Edit ${site.siteName}`}
                      title={`Edit ${site.siteName}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Site Info */}
                  <div className="space-y-2">
                    <div className="flex items-start gap-2 text-xs text-gray-600">
                      <MapPin className="w-3 h-3 flex-shrink-0 mt-0.5" />
                      <span className="truncate">{site.siteAddress}</span>
                    </div>
                    {site.city && site.state && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Building className="w-3 h-3 flex-shrink-0" />
                        <span>{site.city}, {site.state}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Globe className="w-3 h-3 flex-shrink-0" />
                      <span>{site.country}</span>
                    </div>
                    {site.contactEmail && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Mail className="w-3 h-3 flex-shrink-0" />
                        <span className="truncate">{site.contactEmail}</span>
                      </div>
                    )}
                    {site.contactPhone && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Phone className="w-3 h-3 flex-shrink-0" />
                        <span>{site.contactPhone}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Added {new Date(site.dateAdded).toLocaleDateString()}</span>
                    </div>
                    {site.latitude && site.longitude && (
                      <div className="flex items-center gap-2 text-xs text-gray-500">
                        <MapPin className="w-3 h-3 flex-shrink-0" />
                        <span>📍 {site.latitude.toFixed(4)}, {site.longitude.toFixed(4)}</span>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* Map View */}
      {viewMode === 'map' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4" style={{ minHeight: '600px' }}>
          <div className="h-full flex items-center justify-center bg-gray-50">
            <div className="text-center p-12">
              <Map className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Map View</h3>
              <p className="text-sm text-gray-600 mb-4">
                Map integration coming soon. This view will display all sites on an interactive map.
              </p>
              <p className="text-xs text-gray-500">
                {filteredSites.length} site{filteredSites.length !== 1 ? 's' : ''} available for mapping
                {filteredSites.filter(s => s.latitude && s.longitude).length > 0 && (
                  <span className="block mt-1">
                    ({filteredSites.filter(s => s.latitude && s.longitude).length} with coordinates)
                  </span>
                )}
              </p>
              {filteredSites.length === 0 && (
                <p className="text-sm text-gray-500 mt-4">
                  {sites.length === 0 
                    ? 'Start by adding sites to your directory'
                    : 'Try adjusting your search criteria'}
                </p>
              )}
            </div>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredSites.length)} of {filteredSites.length}
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
