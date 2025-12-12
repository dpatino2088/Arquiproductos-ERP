import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useContractors } from '../../hooks/useDirectory';
import { 
  Wrench, 
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
  Award,
  User
} from 'lucide-react';

interface ContractorItem {
  id: string;
  company: string;
  name: string;
  licensesApplied: string[];
  cellPhone: string;
  proficiency1: string;
  proficiency2: string;
  proficiency3: string;
  email?: string;
  status: 'Active' | 'Inactive' | 'On Hold' | 'Archived';
  dateAdded: string;
  location?: string;
}

// Function to generate avatar initials from name
const generateAvatarInitials = (name: string) => {
  const words = name.trim().split(/\s+/);
  if (words.length >= 2 && words[0] && words[1]) {
    return `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase();
  }
  return name.substring(0, 2).toUpperCase();
};

// Function to generate a consistent background color based on name
const generateAvatarColor = (name: string) => {
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

export default function Contractors() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'company' | 'name' | 'proficiency1' | 'proficiency2' | 'proficiency3' | 'dateAdded'>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedProficiency1, setSelectedProficiency1] = useState<string[]>([]);
  const [selectedProficiency2, setSelectedProficiency2] = useState<string[]>([]);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showProficiency1Dropdown, setShowProficiency1Dropdown] = useState(false);
  const [showProficiency2Dropdown, setShowProficiency2Dropdown] = useState(false);
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [proficiency1SearchTerm, setProficiency1SearchTerm] = useState('');
  const [proficiency2SearchTerm, setProficiency2SearchTerm] = useState('');

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
        setShowStatusDropdown(false);
        setShowProficiency1Dropdown(false);
        setShowProficiency2Dropdown(false);
        // Clear search terms when closing dropdowns
        setStatusSearchTerm('');
        setProficiency1SearchTerm('');
        setProficiency2SearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Get contractors from Supabase
  const { contractors: contractorsData, loading: contractorsLoading, error: contractorsError } = useContractors();

  const filteredContractors = useMemo(() => {
    const filtered = contractorsData.filter(contractor => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        contractor.company.toLowerCase().includes(searchLower) ||
        contractor.name.toLowerCase().includes(searchLower) ||
        contractor.cellPhone.toLowerCase().includes(searchLower) ||
        contractor.proficiency1.toLowerCase().includes(searchLower) ||
        contractor.proficiency2.toLowerCase().includes(searchLower) ||
        contractor.proficiency3.toLowerCase().includes(searchLower) ||
        contractor.licensesApplied.some((license: string) => license.toLowerCase().includes(searchLower)) ||
        (contractor.email && contractor.email.toLowerCase().includes(searchLower)) ||
        (contractor.location && contractor.location.toLowerCase().includes(searchLower))
      );

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(contractor.status);

      // Proficiency 1 filter
      const matchesProficiency1 = selectedProficiency1.length === 0 || selectedProficiency1.includes(contractor.proficiency1);

      // Proficiency 2 filter
      const matchesProficiency2 = selectedProficiency2.length === 0 || selectedProficiency2.includes(contractor.proficiency2);

      return matchesSearch && matchesStatus && matchesProficiency1 && matchesProficiency2;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'company':
          aValue = a.company.toLowerCase();
          bValue = b.company.toLowerCase();
          break;
        case 'name':
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
          break;
        case 'proficiency1':
          aValue = a.proficiency1.toLowerCase();
          bValue = b.proficiency1.toLowerCase();
          break;
        case 'proficiency2':
          aValue = a.proficiency2.toLowerCase();
          bValue = b.proficiency2.toLowerCase();
          break;
        case 'proficiency3':
          aValue = a.proficiency3.toLowerCase();
          bValue = b.proficiency3.toLowerCase();
          break;
        case 'dateAdded':
          aValue = new Date(a.dateAdded);
          bValue = new Date(b.dateAdded);
          break;
        default:
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
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
  }, [searchTerm, contractorsData, sortBy, sortOrder, selectedStatus, selectedProficiency1, selectedProficiency2]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredContractors.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedContractors = filteredContractors.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedStatus([]);
    setSelectedProficiency1([]);
    setSelectedProficiency2([]);
    setSearchTerm('');
    setStatusSearchTerm('');
    setProficiency1SearchTerm('');
    setProficiency2SearchTerm('');
  };

  // Helper functions for multi-select
  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleProficiency1Toggle = (proficiency: string) => {
    setSelectedProficiency1(prev => 
      prev.includes(proficiency) 
        ? prev.filter(p => p !== proficiency)
        : [...prev, proficiency]
    );
  };

  const handleProficiency2Toggle = (proficiency: string) => {
    setSelectedProficiency2(prev => 
      prev.includes(proficiency) 
        ? prev.filter(p => p !== proficiency)
        : [...prev, proficiency]
    );
  };

  // Filter options based on search terms
  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Inactive', 'On Hold', 'Archived'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredProficiency1Options = () => {
    const proficiencyOptions = ['Construction Management', 'HVAC Systems', 'Roofing Systems', 'Interior Design', 'Stone Masonry'];
    if (!proficiency1SearchTerm) return proficiencyOptions;
    return proficiencyOptions.filter(proficiency => 
      proficiency.toLowerCase().includes(proficiency1SearchTerm.toLowerCase())
    );
  };

  const getFilteredProficiency2Options = () => {
    const proficiencyOptions = ['Project Planning', 'Plumbing Installation', 'Exterior Finishing', 'Custom Carpentry', 'Concrete Work'];
    if (!proficiency2SearchTerm) return proficiencyOptions;
    return proficiencyOptions.filter(proficiency => 
      proficiency.toLowerCase().includes(proficiency2SearchTerm.toLowerCase())
    );
  };

  // Navigate to contractor detail page (placeholder)
  const handleViewContractor = (contractor: ContractorItem) => {
    // Store contractor data in sessionStorage for the Contractor Info page
    sessionStorage.setItem('selectedContractor', JSON.stringify(contractor));
    
    // Create slug from contractor name
    const slug = contractor.name.toLowerCase().replace(/\s+/g, '-');
    
    // Navigate to contractor detail (you can create this page later)
    // router.navigate(`/directory/contractors/${slug}`);
    console.log('View contractor:', contractor);
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

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Contractors Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredContractors.length} contractors${filteredContractors.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button
            onClick={() => router.navigate('/directory/contractors/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Contractor
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
                placeholder="Search contractors by company, name, phone, proficiency, licenses, or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search contractors"
                id="contractor-search"
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

              {/* Proficiency 1 Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowProficiency1Dropdown(!showProficiency1Dropdown)}>
                  <span className="text-gray-700">
                    {selectedProficiency1.length === 0 ? 'All Proficiency 1' : 
                     selectedProficiency1.length === 1 ? selectedProficiency1[0] :
                     `${selectedProficiency1.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showProficiency1Dropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search proficiency 1..."
                          value={proficiency1SearchTerm}
                          onChange={(e) => setProficiency1SearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedProficiency1.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedProficiency1([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedProficiency1.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredProficiency1Options().map((proficiency) => (
                      <div key={proficiency} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleProficiency1Toggle(proficiency)}>
                        <input type="checkbox" checked={selectedProficiency1.includes(proficiency)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{proficiency}</span>
                      </div>
                    ))}
                    {getFilteredProficiency1Options().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No proficiencies found
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Proficiency 2 Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowProficiency2Dropdown(!showProficiency2Dropdown)}>
                  <span className="text-gray-700">
                    {selectedProficiency2.length === 0 ? 'All Proficiency 2' : 
                     selectedProficiency2.length === 1 ? selectedProficiency2[0] :
                     `${selectedProficiency2.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showProficiency2Dropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search proficiency 2..."
                          value={proficiency2SearchTerm}
                          onChange={(e) => setProficiency2SearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedProficiency2.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedProficiency2([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedProficiency2.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredProficiency2Options().map((proficiency) => (
                      <div key={proficiency} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleProficiency2Toggle(proficiency)}>
                        <input type="checkbox" checked={selectedProficiency2.includes(proficiency)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{proficiency}</span>
                      </div>
                    ))}
                    {getFilteredProficiency2Options().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No proficiencies found
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
                  onClick={() => handleSort('company')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'company' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Company
                  {sortBy === 'company' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
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
                  onClick={() => handleSort('proficiency1')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'proficiency1' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Proficiency 1
                  {sortBy === 'proficiency1' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('proficiency2')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'proficiency2' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Proficiency 2
                  {sortBy === 'proficiency2' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('proficiency3')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'proficiency3' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Proficiency 3
                  {sortBy === 'proficiency3' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                <col style={{ width: '18%' }} /> {/* Company - base * 0.9 */}
                <col style={{ width: '15%' }} /> {/* Name - base * 0.75 */}
                <col style={{ width: '15%' }} /> {/* Licenses Applied - base * 0.75 */}
                <col style={{ width: '12%' }} /> {/* Cell Phone - base * 0.618 */}
                <col style={{ width: '13%' }} /> {/* Proficiency 1 - base * 0.65 */}
                <col style={{ width: '13%' }} /> {/* Proficiency 2 - base * 0.65 */}
                <col style={{ width: '9%' }} />  {/* Proficiency 3 - base * 0.45 */}
                <col style={{ width: '5%' }} />  {/* Actions - fixed small */}
              </colgroup>
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                    <button
                      onClick={() => handleSort('company')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Company
                      {sortBy === 'company' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>
                    <button
                      onClick={() => handleSort('name')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name
                      {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>Licenses Applied</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>Cell Phone</th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>
                    <button
                      onClick={() => handleSort('proficiency1')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Proficiency 1
                      {sortBy === 'proficiency1' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>
                    <button
                      onClick={() => handleSort('proficiency2')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Proficiency 2
                      {sortBy === 'proficiency2' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.45rem', paddingRight: '0.45rem' }}>
                    <button
                      onClick={() => handleSort('proficiency3')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Proficiency 3
                      {sortBy === 'proficiency3' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 font-medium text-gray-900 text-xs" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredContractors.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-12 text-center">
                      <Wrench className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No contractors found</p>
                      <p className="text-sm text-gray-500">
                        {contractorsData.length === 0 
                          ? 'Start by adding contractors to your directory'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedContractors.map((contractor) => (
                    <tr key={contractor.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '1.5rem', paddingRight: '1rem' }}>
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div 
                              className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium" 
                              style={{ backgroundColor: generateAvatarColor(contractor.name) }}
                            >
                              {generateAvatarInitials(contractor.name)}
                            </div>
                            <div 
                              className={`absolute -bottom-0.5 -right-0.5 ${getDotSize('sm')} rounded-full border border-white`}
                              style={{
                                backgroundColor: 
                                  contractor.status === 'Active' ? 'var(--avatar-status-green)' :
                                  contractor.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                                  contractor.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                                  contractor.status === 'Archived' ? 'var(--avatar-status-purple)' :
                                  'var(--avatar-status-gray)'
                              }}>
                            </div>
                          </div>
                          <div>
                            <div className="font-medium text-gray-900 text-sm">
                              {contractor.company}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>{contractor.name}</td>
                      <td className="py-4 text-gray-600 text-sm" style={{ paddingLeft: '0.75rem', paddingRight: '0.75rem' }}>
                        <div className="flex flex-wrap gap-1">
                          {contractor.licensesApplied.map((license: string, index: number) => (
                            <span key={index} className="px-1.5 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700">
                              {license}
                            </span>
                          ))}
                        </div>
                      </td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.618rem', paddingRight: '0.618rem' }}>{contractor.cellPhone}</td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>{contractor.proficiency1}</td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.65rem', paddingRight: '0.65rem' }}>{contractor.proficiency2}</td>
                      <td className="py-4 text-gray-900 text-sm" style={{ paddingLeft: '0.45rem', paddingRight: '0.45rem' }}>{contractor.proficiency3}</td>
                      <td className="py-2" style={{ paddingLeft: '0.382rem', paddingRight: '0.382rem' }}>
                        <div className="flex items-center">
                          <button 
                            onClick={() => handleViewContractor(contractor)}
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${contractor.name}`}
                            title={`View ${contractor.name}`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button 
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`More options for ${contractor.name}`}
                            title={`More options for ${contractor.name}`}
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
          {filteredContractors.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <Wrench className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No contractors found</p>
              <p className="text-sm text-gray-500">
                {contractorsData.length === 0 
                  ? 'Start by adding contractors to your directory'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedContractors.map((contractor) => (
                <div
                  key={contractor.id}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6"
                >
                  {/* Contractor Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base" 
                        style={{ backgroundColor: generateAvatarColor(contractor.name) }}
                      >
                        {generateAvatarInitials(contractor.name)}
                      </div>
                      <div 
                        className={`absolute -bottom-1 -right-1 ${getDotSize('lg')} rounded-full border-2 border-white`}
                        style={{
                          backgroundColor: 
                            contractor.status === 'Active' ? 'var(--avatar-status-green)' :
                            contractor.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                            contractor.status === 'On Hold' ? 'var(--avatar-status-orange)' :
                            contractor.status === 'Archived' ? 'var(--avatar-status-purple)' :
                            'var(--avatar-status-gray)'
                        }}>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
                        {contractor.name}
                      </h3>
                      <p className="text-xs text-gray-600 truncate">{contractor.company}</p>
                      <div className="mt-1">
                        {getStatusBadge(contractor.status)}
                      </div>
                    </div>
                    <button 
                      onClick={() => handleViewContractor(contractor)}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Edit ${contractor.name}`}
                      title={`Edit ${contractor.name}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Contractor Info */}
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Phone className="w-3 h-3 flex-shrink-0" />
                      <span>{contractor.cellPhone}</span>
                    </div>
                    {contractor.email && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Mail className="w-3 h-3 flex-shrink-0" />
                        <span className="truncate">{contractor.email}</span>
                      </div>
                    )}
                    <div className="flex flex-wrap gap-1">
                      {contractor.licensesApplied.map((license: string, index: number) => (
                        <span key={index} className="px-1.5 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700">
                          {license}
                        </span>
                      ))}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Award className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{contractor.proficiency1}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Award className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{contractor.proficiency2}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Award className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{contractor.proficiency3}</span>
                    </div>
                    {contractor.location && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <MapPin className="w-3 h-3 flex-shrink-0" />
                        <span className="truncate">{contractor.location}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Added {new Date(contractor.dateAdded).toLocaleDateString()}</span>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredContractors.length)} of {filteredContractors.length}
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
