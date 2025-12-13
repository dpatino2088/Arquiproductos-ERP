import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { 
  User, 
  Search, 
  Filter,
  Plus,
  Mail,
  Shield,
  Eye,
  Edit,
  MoreVertical,
  ChevronLeft,
  ChevronRight,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Calendar
} from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useAuthStore } from '../../stores/auth-store';

interface OrganizationUser {
  id: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  created_at: string;
  user_id: string;
  name?: string;
  email?: string;
}

export default function OrganizationUser() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId, loading: orgLoading, hasOrganizations } = useOrganizationContext();
  const { user } = useAuthStore();
  const { canManageUsers, loading: roleLoading, role } = useCurrentOrgRole();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'email' | 'role' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedRole, setSelectedRole] = useState<string[]>([]);
  const [showRoleDropdown, setShowRoleDropdown] = useState(false);
  const [roleSearchTerm, setRoleSearchTerm] = useState('');
  
  const [users, setUsers] = useState<OrganizationUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'organization-user', label: 'Organization User', href: '/settings/organization-user' },
    ]);
  }, [registerSubmodules]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element;
      if (!target.closest('.dropdown-container')) {
        setShowRoleDropdown(false);
        setRoleSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Load users function
  const loadUsers = async () => {
    if (!activeOrganizationId) {
      setUsers([]);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    try {
      // First, try direct query (simpler and faster if RLS allows it)
      const { data: directData, error: directError } = await supabase
        .from('OrganizationUsers')
        .select('id, role, created_at, user_id, name, email, invited_by')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (!directError && directData) {
        // Success with direct query
        setUsers(directData);
        setIsLoading(false);
        return;
      }

      // If direct query fails, check if it's a recursion error
      if (directError) {
        // Check for stack depth error (RLS recursion)
        if (directError.message?.includes('stack depth') || directError.message?.includes('54001')) {
          if (import.meta.env.DEV) {
            console.error('RLS recursion error detected. Please run fix_organization_users_rls_recursion.sql migration:', directError);
          }
          // Still try Edge Function as fallback
        } else if (import.meta.env.DEV) {
          console.warn('Direct query failed, trying Edge Function:', directError);
        }
      }

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      const { data: session, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError || !session?.session) {
        if (import.meta.env.DEV) {
          console.error('Error getting session:', sessionError);
        }
        setUsers([]);
        setIsLoading(false);
        return;
      }
      
      // Call Edge Function to get users with emails
      const functionUrl = `${supabaseUrl}/functions/v1/get-organization-users`;
      
      try {
        const response = await fetch(functionUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session.session.access_token}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
          },
          body: JSON.stringify({ organizationId: activeOrganizationId }),
        });

        if (response.ok) {
          const result = await response.json();
          if (result.success && result.users) {
            setUsers(result.users);
            setIsLoading(false);
            return;
          }
        }
      } catch (fetchError) {
        if (import.meta.env.DEV) {
          console.warn('Edge Function also failed:', fetchError);
        }
      }

      // If both fail, show empty array but log the error
      if (import.meta.env.DEV) {
        console.error('Both direct query and Edge Function failed. Direct error:', directError);
      }
      setUsers([]);
      
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error loading users:', err);
      }
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  };

  // Load users when organization changes
  useEffect(() => {
    loadUsers();
  }, [activeOrganizationId]);

  // Filter and sort users
  const filteredUsers = useMemo(() => {
    const filtered = users.filter(user => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        (user.name || '').toLowerCase().includes(searchLower) ||
        (user.email || '').toLowerCase().includes(searchLower) ||
        (user.user_id || '').toLowerCase().includes(searchLower) ||
        (user.role || '').toLowerCase().includes(searchLower)
      );

      // Role filter
      const matchesRole = selectedRole.length === 0 || selectedRole.includes(user.role);

      return matchesSearch && matchesRole;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'email':
          aValue = (a.email || '').toLowerCase();
          bValue = (b.email || '').toLowerCase();
          break;
        case 'role':
          aValue = (a.role || '').toLowerCase();
          bValue = (b.role || '').toLowerCase();
          break;
        case 'created_at':
          aValue = a.created_at ? new Date(a.created_at) : new Date(0);
          bValue = b.created_at ? new Date(b.created_at) : new Date(0);
          break;
        default:
          aValue = (a.email || '').toLowerCase();
          bValue = (b.email || '').toLowerCase();
      }

      if (sortBy === 'created_at') {
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
  }, [searchTerm, users, sortBy, sortOrder, selectedRole]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedUsers = filteredUsers.slice(startIndex, startIndex + itemsPerPage);

  // Reset to first page when search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  // Show message if user has no organizations at all
  if (!orgLoading && !hasOrganizations) {
    return <NoOrganizationMessage />;
  }

  // Show message if organization is not selected (but user has organizations)
  if (!orgLoading && !activeOrganizationId && hasOrganizations) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization from the switcher above to view users.</p>
        </div>
      </div>
    );
  }

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
    setSelectedRole([]);
    setSearchTerm('');
    setRoleSearchTerm('');
  };

  // Helper functions for multi-select
  const handleRoleToggle = (role: string) => {
    setSelectedRole(prev => 
      prev.includes(role) 
        ? prev.filter(r => r !== role)
        : [...prev, role]
    );
  };

  // Filter options based on search terms
  const getFilteredRoleOptions = () => {
    const roleOptions = ['owner', 'admin', 'member', 'viewer'];
    if (!roleSearchTerm) return roleOptions;
    return roleOptions.filter(role => 
      role.toLowerCase().includes(roleSearchTerm.toLowerCase())
    );
  };

  // Get role badge color
  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case 'owner':
        return 'bg-purple-100 text-purple-800';
      case 'admin':
        return 'bg-blue-100 text-blue-800';
      case 'member':
        return 'bg-green-100 text-green-800';
      case 'viewer':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  // Show loading state
  if (orgLoading || isLoading || roleLoading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading organization users...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Customer and User</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Manage ${filteredUsers.length} organization users${filteredUsers.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {canManageUsers ? (
            <button 
              onClick={() => router.navigate('/settings/organization-users/new')}
              className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90" 
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus style={{ width: '14px', height: '14px' }} />
              Add User
            </button>
          ) : (
            <span className="text-xs text-muted-foreground">
              Role: {role ?? 'no role'} — You don't have permission to manage users.
            </span>
          )}
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
                placeholder="Search users by email, role..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search users"
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
                  <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded shadow-lg z-10 max-h-48 overflow-y-auto">
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
                    {getFilteredRoleOptions().map((role) => (
                      <div key={role} className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                           onClick={() => handleRoleToggle(role)}>
                        <input type="checkbox" checked={selectedRole.includes(role)} readOnly className="w-4 h-4" />
                        <span className="text-sm text-gray-700 capitalize">{role}</span>
                      </div>
                    ))}
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
                  onClick={() => handleSort('email')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'email' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Email
                  {sortBy === 'email' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                <button 
                  onClick={() => handleSort('created_at')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'created_at' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Date Added
                  {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
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
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('email')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name / Email
                      {sortBy === 'email' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('role')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Role
                      {sortBy === 'role' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('created_at')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Joined
                      {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="py-12 text-center">
                      <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600 mb-2">No users found</p>
                      <p className="text-sm text-gray-500">
                        {users.length === 0 
                          ? 'Start by adding users to your organization'
                          : 'Try adjusting your search criteria'}
                      </p>
                    </td>
                  </tr>
                ) : (
                  paginatedUsers.map((orgUser) => (
                    <tr 
                      key={orgUser.id} 
                      onClick={() => router.navigate(`/settings/organization-users/edit/${orgUser.id}`)}
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer"
                    >
                      <td className="py-4 px-4 text-gray-900 text-sm">
                        <div className="flex items-center gap-3">
                          <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                            <User className="w-4 h-4 text-gray-600" />
                          </div>
                          <div>
                            <div className="font-medium">{orgUser.name || orgUser.email || orgUser.user_id.substring(0, 8) + '...'}</div>
                            {orgUser.name && orgUser.email && (
                              <div className="text-xs text-gray-500">{orgUser.email}</div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <span className={`text-xs font-medium px-2 py-1 rounded capitalize ${getRoleBadgeColor(orgUser.role)}`}>
                          {orgUser.role}
                        </span>
                      </td>
                      <td className="py-4 px-4 text-gray-600 text-sm">
                        {new Date(orgUser.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 px-4">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            router.navigate(`/settings/organization-users/edit/${orgUser.id}`);
                          }}
                          className="text-gray-400 hover:text-primary transition-colors"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
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
          {filteredUsers.length === 0 ? (
            <div className="bg-white border border-gray-200 rounded-lg p-12 text-center mb-4">
              <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No users found</p>
              <p className="text-sm text-gray-500">
                {users.length === 0 
                  ? 'Start by adding users to your organization'
                  : 'Try adjusting your search criteria'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-4">
              {paginatedUsers.map((orgUser) => (
                <div
                  key={orgUser.id}
                  onClick={() => router.navigate(`/settings/organization-users/edit/${orgUser.id}`)}
                  className="bg-white border border-gray-200 hover:shadow-lg transition-all duration-200 hover:border-primary/20 group rounded-lg p-6 cursor-pointer"
                >
                  {/* User Avatar and Basic Info */}
                  <div className="flex items-start gap-3 mb-4">
                    <div className="relative">
                      <div 
                        className="w-12 h-12 rounded-full flex items-center justify-center text-white font-medium text-base bg-gray-200"
                      >
                        <User className="w-6 h-6 text-gray-600" />
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-gray-900 group-hover:text-primary transition-colors truncate">
                        {orgUser.name || orgUser.email || orgUser.user_id.substring(0, 8) + '...'}
                      </h3>
                      {orgUser.name && orgUser.email && (
                        <p className="text-xs text-gray-500 truncate">{orgUser.email}</p>
                      )}
                      <div className="mt-1">
                        <span className={`text-xs font-medium px-2 py-1 rounded capitalize ${getRoleBadgeColor(orgUser.role)}`}>
                          {orgUser.role}
                        </span>
                      </div>
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        router.navigate(`/settings/organization-users/edit/${orgUser.id}`);
                      }}
                      className="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-primary"
                      aria-label={`Edit ${orgUser.email}`}
                      title={`Edit ${orgUser.email}`}
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                  </div>

                  {/* User Info */}
                  <div className="space-y-2">
                    {orgUser.email && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Mail className="w-3 h-3 flex-shrink-0" />
                        <span className="truncate">{orgUser.email}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-xs text-gray-600">
                      <Calendar className="w-3 h-3 flex-shrink-0" />
                      <span>Joined {new Date(orgUser.created_at).toLocaleDateString()}</span>
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
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredUsers.length)} of {filteredUsers.length}
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
