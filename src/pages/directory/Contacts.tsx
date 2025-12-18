import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useContacts, useDeleteContact } from '../../hooks/useDirectory';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { 
  Contact, 
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
  Copy,
  Archive,
  Trash2
} from 'lucide-react';

interface ContactItem {
  id: string;
  firstName: string; // This will contain contact_name for compatibility
  lastName: string; // This will be empty for unified model
  email: string;
  company: string; // This will contain customer_name from DirectoryCustomers for company type
  category: string;
  status: 'Active' | 'Inactive' | 'Archived';
  location: string;
  dateAdded: string;
  avatar?: string;
  phone?: string;
  contactType?: 'Business' | 'Personal' | 'Vendor' | 'Customer';
}

// Function to generate avatar initials (100% reliable, works everywhere)
const generateAvatarInitials = (contactName: string) => {
  // For unified model, use first two characters of contact_name
  if (!contactName) return '??';
  const words = contactName.trim().split(/\s+/);
  if (words.length >= 2 && words[0] && words[1]) {
    return `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase();
  }
  return contactName.substring(0, 2).toUpperCase();
};

// Function to generate a consistent background color based on name
// Using primary brand color for all avatars for consistency
const generateAvatarColor = (customerName: string) => {
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

// Function to get badge color for contact type
const getContactTypeBadgeColor = (contactType: string) => {
  switch (contactType) {
    case 'architect':
      return 'bg-purple-50 text-purple-700';
    case 'interior_designer':
      return 'bg-pink-50 text-pink-700';
    case 'project_manager':
      return 'bg-blue-50 text-blue-700';
    case 'consultant':
      return 'bg-green-50 text-green-700';
    case 'dealer':
      return 'bg-orange-50 text-orange-700';
    case 'reseller':
      return 'bg-yellow-50 text-yellow-700';
    case 'partner':
      return 'bg-indigo-50 text-indigo-700';
    default:
      return 'bg-gray-50 text-gray-700';
  }
};

// Function to format contact type label
const formatContactTypeLabel = (contactType: string) => {
  return contactType
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

export default function Contacts() {
  // Debug log to confirm component is rendering
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('✅ Contacts component is rendering');
    }
  }, []);

  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'firstName' | 'company' | 'category' | 'dateAdded'>('firstName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedCategory, setSelectedCategory] = useState<string[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);
  const [selectedContactType, setSelectedContactType] = useState<string[]>([]);
  const [selectedLocation, setSelectedLocation] = useState<string[]>([]);
  const [showCategoryDropdown, setShowCategoryDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showContactTypeDropdown, setShowContactTypeDropdown] = useState(false);
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  const [categorySearchTerm, setCategorySearchTerm] = useState('');
  const [statusSearchTerm, setStatusSearchTerm] = useState('');
  const [contactTypeSearchTerm, setContactTypeSearchTerm] = useState('');
  const [locationSearchTerm, setLocationSearchTerm] = useState('');

  useEffect(() => {
    registerSubmodules('Directory', [
      { id: 'contacts', label: 'Contacts', href: '/directory/contacts' },
      { id: 'customers', label: 'Customers', href: '/directory/customers' },
      { id: 'vendors', label: 'Vendors', href: '/directory/vendors' },
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowCategoryDropdown(false);
        setShowStatusDropdown(false);
        setShowContactTypeDropdown(false);
        setShowLocationDropdown(false);
        // Clear search terms when closing dropdowns
        setCategorySearchTerm('');
        setStatusSearchTerm('');
        setContactTypeSearchTerm('');
        setLocationSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);
  
  // Prevent hook execution without org
  if (!orgLoading && !activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to view contacts.</p>
        </div>
      </div>
    );
  }
  
  // Get contacts from Supabase
  const { data: contactsData, isLoading: contactsLoading, isError: contactsIsError, error: contactsError, refetch } = useContacts();
  const { deleteContact, isDeleting } = useDeleteContact();

  // Debug log
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('🔍 Contacts component - Data:', {
        contactsCount: contactsData.length,
        loading: contactsLoading,
        error: contactsError,
        contacts: contactsData
      });
    }
  }, [contactsData, contactsLoading, contactsError]);

  const filteredContacts = useMemo(() => {
    const filtered = contactsData.filter(contact => {
      // Search filter - safely handle undefined/null values
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        (contact.firstName || '').toLowerCase().includes(searchLower) ||
        (contact.lastName || '').toLowerCase().includes(searchLower) ||
        (contact.email || '').toLowerCase().includes(searchLower) ||
        (contact.company || '').toLowerCase().includes(searchLower) ||
        (contact.category || '').toLowerCase().includes(searchLower)
      );

      // Category filter
      const matchesCategory = selectedCategory.length === 0 || selectedCategory.includes(contact.category);

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(contact.status);

      // Contact type filter (using actual contact_type from database)
      const contactType = (contact as any).contact_type;
      const formattedContactType = contactType ? formatContactTypeLabel(contactType) : '';
      const matchesContactType = selectedContactType.length === 0 || 
        selectedContactType.includes(formattedContactType);

      // Location filter
      const matchesLocation = selectedLocation.length === 0 || selectedLocation.includes(contact.location);

      return matchesSearch && matchesCategory && matchesStatus && matchesContactType && matchesLocation;
    });

    // Apply sorting - safely handle undefined/null values
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'firstName':
          aValue = (a.firstName || '').toLowerCase();
          bValue = (b.firstName || '').toLowerCase();
          break;
        case 'company':
          aValue = (a.company || '').toLowerCase();
          bValue = (b.company || '').toLowerCase();
          break;
        case 'category':
          aValue = (a.category || '').toLowerCase();
          bValue = (b.category || '').toLowerCase();
          break;
        case 'dateAdded':
          aValue = a.dateAdded ? new Date(a.dateAdded) : new Date(0);
          bValue = b.dateAdded ? new Date(b.dateAdded) : new Date(0);
          break;
        default:
          aValue = (a.firstName || '').toLowerCase();
          bValue = (b.firstName || '').toLowerCase();
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
  }, [searchTerm, contactsData, sortBy, sortOrder, selectedCategory, selectedStatus, selectedContactType, selectedLocation]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredContacts.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedContacts = filteredContacts.slice(startIndex, startIndex + itemsPerPage);

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
    setSelectedCategory([]);
    setSelectedStatus([]);
    setSelectedContactType([]);
    setSelectedLocation([]);
    setSearchTerm('');
    setCategorySearchTerm('');
    setStatusSearchTerm('');
    setContactTypeSearchTerm('');
    setLocationSearchTerm('');
  };

  // Helper functions for multi-select
  const handleCategoryToggle = (category: string) => {
    setSelectedCategory(prev => 
      prev.includes(category) 
        ? prev.filter(c => c !== category)
        : [...prev, category]
    );
  };

  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  const handleContactTypeToggle = (contactType: string) => {
    setSelectedContactType(prev => 
      prev.includes(contactType) 
        ? prev.filter(c => c !== contactType)
        : [...prev, contactType]
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
  const getFilteredCategoryOptions = () => {
    // Get unique categories from actual data - safely handle null/undefined
    const categoryOptions = Array.from(new Set(contactsData.map(c => c.category).filter(Boolean).filter(cat => cat != null)));
    if (!categorySearchTerm) return categoryOptions;
    return categoryOptions.filter(cat => 
      (cat || '').toLowerCase().includes(categorySearchTerm.toLowerCase())
    );
  };

  const getFilteredStatusOptions = () => {
    const statusOptions = ['Active', 'Inactive', 'Archived'];
    if (!statusSearchTerm) return statusOptions;
    return statusOptions.filter(status => 
      status.toLowerCase().includes(statusSearchTerm.toLowerCase())
    );
  };

  const getFilteredContactTypeOptions = () => {
    const contactTypeOptions = [
      'Architect',
      'Interior Designer',
      'Project Manager',
      'Consultant',
      'Dealer',
      'Reseller',
      'Partner'
    ];
    if (!contactTypeSearchTerm) return contactTypeOptions;
    return contactTypeOptions.filter(type => 
      type.toLowerCase().includes(contactTypeSearchTerm.toLowerCase())
    );
  };

  const getFilteredLocationOptions = () => {
    const locationOptions = ['San Francisco, CA', 'Seattle, WA', 'Portland, OR', 'Austin, TX', 'New York, NY'];
    if (!locationSearchTerm) return locationOptions;
    return locationOptions.filter(location => 
      location.toLowerCase().includes(locationSearchTerm.toLowerCase())
    );
  };

  // Navigate to contact edit page
  const handleEditContact = (contact: ContactItem, e: React.MouseEvent) => {
    e.stopPropagation();
    router.navigate(`/directory/contacts/edit/${contact.id}`);
  };

  // Handle duplicate contact
  const handleDuplicateContact = async (contact: ContactItem, e: React.MouseEvent) => {
    e.stopPropagation();
    router.navigate(`/directory/contacts/new?duplicate=${contact.id}`);
  };

  // Handle archive contact
  const handleArchiveContact = async (contact: ContactItem, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Archivar Contacto',
      message: `¿Estás seguro de que deseas archivar "${contact.firstName}"?`,
      variant: 'warning',
      confirmText: 'Archivar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      if (!activeOrganizationId) return;
      
      setLoading(true);
      const { error } = await supabase
        .from('DirectoryContacts')
        .update({ archived: true })
        .eq('id', contact.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Contacto archivado',
        message: 'El contacto ha sido archivado correctamente.',
      });
      
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al archivar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  // Handle delete contact
  const handleDeleteContact = async (contact: ContactItem, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Eliminar Contacto',
      message: `¿Estás seguro de que deseas eliminar "${contact.firstName}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteContact(contact.id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Contacto eliminado',
        message: 'El contacto ha sido eliminado correctamente.',
      });
      refetch();
        } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al eliminar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
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
  if (orgLoading || contactsLoading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading contacts...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state
  if (contactsIsError && contactsError) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading contacts</p>
          <p className="text-sm text-red-700">{contactsError}</p>
          {import.meta.env.DEV && (
            <p className="text-xs text-gray-500 mb-4">Please make sure you have selected a company.</p>
          )}
          <button 
            onClick={() => window.location.reload()} 
            className="px-4 py-2 bg-primary text-white rounded hover:opacity-90"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Contacts Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage your ${filteredContacts.length} contacts${filteredContacts.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm">
            <Upload style={{ width: '14px', height: '14px' }} />
            Import
          </button>
          <button 
            onClick={() => router.navigate('/directory/contacts/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            New Contact
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
                placeholder="Search contacts by name, email, company, or category..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search contacts"
                id="contact-search"
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
              {/* Category Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowCategoryDropdown(!showCategoryDropdown)}>
                  <span className="text-gray-700">
                    {selectedCategory.length === 0 ? 'All Categories' : 
                     selectedCategory.length === 1 ? selectedCategory[0] :
                     `${selectedCategory.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showCategoryDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search categories..."
                          value={categorySearchTerm}
                          onChange={(e) => setCategorySearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedCategory.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedCategory([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedCategory.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredCategoryOptions().map((category) => (
                      <div key={category} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleCategoryToggle(category)}>
                        <input type="checkbox" checked={selectedCategory.includes(category)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{category}</span>
                      </div>
                    ))}
                    {getFilteredCategoryOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No categories found
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

              {/* Contact Type Multi-Select */}
              <div className="relative dropdown-container">
                <div className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px] flex items-center justify-between cursor-pointer hover:bg-gray-50" 
                     onClick={() => setShowContactTypeDropdown(!showContactTypeDropdown)}>
                  <span className="text-gray-700">
                    {selectedContactType.length === 0 ? 'All Contact Types' : 
                     selectedContactType.length === 1 ? selectedContactType[0] :
                     `${selectedContactType.length} selected`}
                  </span>
                  <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
                {showContactTypeDropdown && (
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100">
                      <div className="flex items-center gap-2">
                        <input
                          type="text"
                          placeholder="Search contact types..."
                          value={contactTypeSearchTerm}
                          onChange={(e) => setContactTypeSearchTerm(e.target.value)}
                          className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                          onClick={(e) => e.stopPropagation()}
                        />
                        {selectedContactType.length > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedContactType([]);
                            }}
                            className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                          >
                            Clear ({selectedContactType.length})
                          </button>
                        )}
                      </div>
                    </div>
                    {getFilteredContactTypeOptions().map((contactType) => (
                      <div key={contactType} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleContactTypeToggle(contactType)}>
                        <input type="checkbox" checked={selectedContactType.includes(contactType)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700">{contactType}</span>
                      </div>
                    ))}
                    {getFilteredContactTypeOptions().length === 0 && (
                      <div className="px-3 py-2 text-sm text-gray-500 text-center">
                        No contact types found
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
                  onClick={() => handleSort('category')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'category' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Category
                  {sortBy === 'category' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('firstName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Contact Name
                      {sortBy === 'firstName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('company')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Customer
                      {sortBy === 'company' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Primary Phone</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Email</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Country</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">City</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Contact Type</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('dateAdded')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Created At
                      {sortBy === 'dateAdded' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredContacts.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-12 px-6 text-center">
                      <Contact className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No contacts found</p>
                      <p className="text-sm text-gray-500">
                        {contactsData.length === 0 
                          ? 'Start by adding contacts to your directory'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedContacts.map((contact) => (
                    <tr 
                      key={contact.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-4 px-6 text-gray-900 text-sm">
                        <div className="font-medium">{contact.firstName}</div>
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {contact.company || 'N/A'}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        <div className="flex items-center gap-1">
                          <Phone className="w-3 h-3 text-gray-400" />
                          {(contact as any).primary_phone || contact.phone || 'N/A'}
                        </div>
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        <div className="flex items-center gap-1">
                          <Mail className="w-3 h-3 text-gray-400" />
                          {contact.email || 'N/A'}
                        </div>
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {(contact as any).country || contact.location?.split(', ').pop() || 'N/A'}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {(contact as any).city || contact.location?.split(', ')[0] || 'N/A'}
                      </td>
                      <td className="py-4 px-6">
                        <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium ${
                          getContactTypeBadgeColor((contact as any).contact_type || '')
                        }`}>
                          {formatContactTypeLabel((contact as any).contact_type || 'architect')}
                        </span>
                      </td>
                      <td className="py-4 px-6 text-gray-600 text-sm">
                        {(contact as any).created_at 
                          ? new Date((contact as any).created_at).toLocaleDateString() 
                          : contact.dateAdded 
                            ? new Date(contact.dateAdded).toLocaleDateString() 
                            : 'N/A'}
                      </td>
                      <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={(e) => handleEditContact(contact, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Editar ${contact.firstName}`}
                            title={`Editar ${contact.firstName}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleDuplicateContact(contact, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Duplicar ${contact.firstName}`}
                            title={`Duplicar ${contact.firstName}`}
                          >
                            <Copy className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleArchiveContact(contact, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Archivar ${contact.firstName}`}
                            title={`Archivar ${contact.firstName}`}
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleDeleteContact(contact, e)}
                            disabled={isDeleting}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            aria-label={`Eliminar ${contact.firstName}`}
                            title={`Eliminar ${contact.firstName}`}
                          >
                            <Trash2 className="w-4 h-4" />
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
          {filteredContacts.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <Contact className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No contacts found</p>
              <p className="text-sm text-gray-500">
                {contactsData.length === 0 
                  ? 'Start by adding contacts to your directory'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedContacts.map((contact) => (
                <div
                  key={contact.id}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6"
                >
                  {/* Contact Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base" 
                        style={{ backgroundColor: generateAvatarColor(contact.firstName) }}
                      >
                        {generateAvatarInitials(contact.firstName)}
                      </div>
                      <div 
                        className={`absolute -bottom-1 -right-1 ${getDotSize('lg')} rounded-full border-2 border-white`}
                        style={{
                          backgroundColor: 
                            contact.status === 'Active' ? 'var(--avatar-status-green)' :
                            contact.status === 'Inactive' ? 'var(--avatar-status-gray)' :
                            contact.status === 'Archived' ? 'var(--avatar-status-purple)' :
                            'var(--avatar-status-gray)'
                        }}>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors">
                        {contact.firstName}
                      </h3>
                      {contact.company && (
                        <p className="text-xs text-gray-600 truncate">{contact.company}</p>
                      )}
                      <div className="mt-1">
                        {getStatusBadge(contact.status)}
                      </div>
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        handleEditContact(contact, e);
                      }}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Editar ${contact.firstName}`}
                      title={`Editar ${contact.firstName}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Contact Info */}
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Mail className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{contact.email}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Phone className="w-3 h-3 flex-shrink-0" />
                      <span>{contact.phone || '+1 (555) 000-0000'}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <MapPin className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{contact.location}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Added {new Date(contact.dateAdded).toLocaleDateString()}</span>
                    </div>
                  </div>

                  {/* Contact Type Badge */}
                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <div className="flex justify-between items-center">
                      <span className="text-xs text-gray-600">Type:</span>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        getContactTypeBadgeColor((contact as any).contact_type || '')
                      }`}>
                        {formatContactTypeLabel((contact as any).contact_type || 'architect')}
                      </span>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredContacts.length)} of {filteredContacts.length}
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

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
