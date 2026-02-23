import { useEffect, useState, useMemo, useRef } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { SettingsPageHeader } from '../../components/settings/SettingsPageHeader';
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
  Calendar,
  Building,
  Trash2,
  Archive,
  Send,
  CheckCircle
} from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useAuthStore } from '../../stores/auth-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { useUIStore } from '../../stores/ui-store';

interface OrganizationUser {
  id: string;
  organization_id: string;
  user_id: string | null;
  user_email: string;
  user_name: string | null;
  role: 'superadmin' | 'admin' | 'operator' | 'procurement' | 'finance' | 'member' | 'owner' | 'viewer'; // Include all roles
  status: 'invited' | 'active' | 'disabled';
  invited_by_user_id: string | null;
  invited_at: string | null;
  accepted_at: string | null;
  deleted: boolean;
  created_at: string;
  updated_at: string | null;
}

export default function OrganizationUser() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId, loading: orgLoading, hasOrganizations } = useOrganizationContext();
  const { user } = useAuthStore();
  const { canManageUsers, loading: roleLoading, role, isAdmin, isSuperAdmin } = useCurrentOrgRole();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'name' | 'email' | 'role' | 'status' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedRole, setSelectedRole] = useState<string[]>([]);
  const [showRoleDropdown, setShowRoleDropdown] = useState(false);
  const [roleSearchTerm, setRoleSearchTerm] = useState('');
  
  const [users, setUsers] = useState<OrganizationUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [deletingUserId, setDeletingUserId] = useState<string | null>(null);
  const [archivingUserId, setArchivingUserId] = useState<string | null>(null);
  const [authorizingId, setAuthorizingId] = useState<string | null>(null);
  const [invitingId, setInvitingId] = useState<string | null>(null);
  const loadingRef = useRef(false);
  const hasLoadedRef = useRef(false);

  const moduleLoading = orgLoading || isLoading || roleLoading;
  useEffect(() => {
    setGlobalLoading(moduleLoading);
    return () => setGlobalLoading(false);
  }, [moduleLoading, setGlobalLoading]);

  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'organization-user', label: 'Organization User', href: '/settings/organization-user' },
    ]);
  }, [registerSubmodules]);

  // Load users only once when organization changes
  useEffect(() => {
    // Reset when organization changes
    hasLoadedRef.current = false;
    
    if (loadingRef.current) return;
    if (!activeOrganizationId) {
      setUsers([]);
      setIsLoading(false);
      return;
    }
    loadUsers();
  }, [activeOrganizationId]);

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

    if (loadingRef.current) return;
    loadingRef.current = true;
    setIsLoading(true);
    try {
      // ✅ Use RPC function list_organization_users (SECURITY DEFINER, no recursion)
      const { data, error } = await supabase
        .rpc('list_organization_users', {
          p_organization_id: activeOrganizationId
        });

      if (error) {
        // ✅ Improved error handling
        if (import.meta.env.DEV) {
          console.error('❌ Error calling list_organization_users RPC:', {
            errorCode: error.code,
            errorMessage: error.message,
            errorHint: error.hint,
            organizationId: activeOrganizationId,
          });
        }
        
        throw error;
      }

      if (data) {
        // ✅ Map data to component interface
        const mappedUsers: OrganizationUser[] = (data || []).map((row: any) => ({
          id: row.id,
          organization_id: row.organization_id,
          user_id: row.user_id,
          user_email: (row.user_email ?? '').toString().trim(),
          user_name: row.user_name || null,
          role: row.role,
          status: row.status || 'invited',
          invited_by_user_id: row.invited_by_user_id || null,
          invited_at: row.invited_at || null,
          accepted_at: row.accepted_at || null,
          deleted: row.deleted || false,
          created_at: row.created_at,
          updated_at: row.updated_at || null,
        }));
        setUsers(mappedUsers);
        setIsLoading(false);
        return;
      }

      // No data returned
      setUsers([]);
      
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('❌ Error loading users:', err);
      }
      setUsers([]);
    } finally {
      setIsLoading(false);
      loadingRef.current = false;
      hasLoadedRef.current = true;
    }
  };

  // Filter and sort users
  const filteredUsers = useMemo(() => {
    const filtered = users.filter(user => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        (user.user_name || '').toLowerCase().includes(searchLower) ||
        (user.user_email || '').toLowerCase().includes(searchLower) ||
        (user.user_id || '').toLowerCase().includes(searchLower) ||
        (user.role || '').toLowerCase().includes(searchLower)
      );

      // Don't filter deleted users - they should not be returned by RPC
      const isActive = !user.deleted;

      // Role filter
      const matchesRole = selectedRole.length === 0 || selectedRole.includes(user.role);

      return matchesSearch && matchesRole && isActive;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | Date;
      let bValue: string | Date;

      switch (sortBy) {
        case 'name':
          aValue = (a.user_name || a.user_email || '').toLowerCase();
          bValue = (b.user_name || b.user_email || '').toLowerCase();
          break;
        case 'email':
          aValue = (a.user_email || '').toLowerCase();
          bValue = (b.user_email || '').toLowerCase();
          break;
        case 'role':
          aValue = (a.role || '').toLowerCase();
          bValue = (b.role || '').toLowerCase();
          break;
        case 'status':
          aValue = (a.status || '').toLowerCase();
          bValue = (b.status || '').toLowerCase();
          break;
        case 'created_at':
          aValue = a.created_at ? new Date(a.created_at) : new Date(0);
          bValue = b.created_at ? new Date(b.created_at) : new Date(0);
          break;
        default:
          aValue = (a.user_name || a.user_email || '').toLowerCase();
          bValue = (b.user_name || b.user_email || '').toLowerCase();
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
      case 'superadmin':
        return 'bg-purple-100 text-purple-800';
      case 'admin':
        return 'bg-blue-100 text-blue-800';
      case 'operator':
        return 'bg-green-100 text-green-800';
      case 'procurement':
        return 'bg-yellow-100 text-yellow-800';
      case 'finance':
        return 'bg-indigo-100 text-indigo-800';
      case 'member':
      case 'owner':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  // Get status badge - show all statuses correctly
  const getStatusBadge = (status: string) => {
    const normalizedStatus = (status || 'active').toLowerCase().trim();
    
    switch (normalizedStatus) {
      case 'invited':
        return {
          label: 'Invited',
          className: 'bg-yellow-50 text-yellow-700 border border-yellow-200'
        };
      case 'active':
        return {
          label: 'Active',
          className: 'bg-green-50 text-green-700 border border-green-200'
        };
      case 'disabled':
        return {
          label: 'Disabled',
          className: 'bg-gray-50 text-gray-700 border border-gray-200'
        };
      default:
        return {
          label: normalizedStatus,
          className: 'bg-gray-50 text-gray-700 border border-gray-200'
        };
    }
  };

  // Handle Authorize action
  const handleAuthorize = async (userId: string) => {
    if (!activeOrganizationId) return;
    
    setAuthorizingId(userId);
    try {
      const { error } = await supabase
        .from('OrganizationUsers')
        .update({ status: 'active', updated_at: new Date().toISOString() })
        .eq('id', userId)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'User Authorized',
        message: 'Organization user has been authorized.',
      });

      loadUsers();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to authorize user',
      });
    } finally {
      setAuthorizingId(null);
    }
  };

  // Handle Send Invite action
  const handleSendInvite = async (user: OrganizationUser) => {
    if (!activeOrganizationId || !user.user_email || !user) return;
    
    setInvitingId(user.id);
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      const { data: session } = await supabase.auth.getSession();
      if (!session?.session) {
        throw new Error('You must be logged in to send invites');
      }

      const functionUrl = `${supabaseUrl}/functions/v1/invite_user_and_link`;
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({
          organization_id: activeOrganizationId,
          target: 'org',
          record_id: user.id,
          email: user.user_email,
          redirect_to: `${window.location.origin}/auth/callback?next=/dashboard`,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to send invite');
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Invite Sent',
        message: 'Invitation email has been sent successfully.',
      });

      loadUsers();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to send invite',
      });
    } finally {
      setInvitingId(null);
    }
  };

  // Handle delete user
  // Handle Archive action
  const handleArchiveUser = async (userId: string, userEmail?: string) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Archive User',
      message: `Are you sure you want to archive "${userEmail || 'this user'}"? The user will be disabled and can be restored later.`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    setArchivingUserId(userId);
    setLoading(true);

    try {
      const { error } = await supabase
        .from('OrganizationUsers')
        .update({ status: 'disabled', updated_at: new Date().toISOString() })
        .eq('id', userId)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'User Archived',
        message: 'User has been archived successfully.',
      });

      // Reset loading ref to allow reload
      hasLoadedRef.current = false;
      // Reload users
      await loadUsers();
    } catch (err: any) {
      const errorMessage = err.message || 'Error archiving user. Please try again.';
      if (import.meta.env.DEV) {
        console.error('Error in handleArchiveUser:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Archive Error',
        message: errorMessage,
      });
    } finally {
      setArchivingUserId(null);
      setIsLoading(false);
      setLoading(false);
    }
  };

  const handleDeleteUser = async (orgUser: OrganizationUser) => {
    if (!isSuperAdmin) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No permissions',
        message: 'Only Superadmins can delete users.',
      });
      return;
    }

    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No hay organización seleccionada.',
      });
      return;
    }

    const confirmed = await showConfirm({
      title: 'Delete User',
      message: `Are you sure you want to delete user "${orgUser.user_email || orgUser.user_name || orgUser.id}"? This will also remove the user from authentication. This action cannot be undone.`,
      confirmText: 'Delete',
      cancelText: 'Cancel',
      variant: 'danger',
    });

    if (!confirmed) {
      return; // Dialog already closed by showConfirm
    }

    setDeletingUserId(orgUser.id);
    setIsLoading(true);
    setLoading(true); // Set dialog loading state
    
    try {
      if (!activeOrganizationId) {
        throw new Error('No organization selected.');
      }

      // 1) Soft delete via RPC (bypasses RLS)
      const { data, error } = await supabase
        .rpc('delete_organization_user', {
          p_org_user_id: orgUser.id,
          p_organization_id: activeOrganizationId
        });

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error deleting user via RPC:', {
            error,
            userId: orgUser.id,
            organizationId: activeOrganizationId,
            errorCode: error.code,
            errorMessage: error.message,
            errorDetails: error.details,
            errorHint: error.hint,
          });
        }

        throw new Error(error.message || 'Error deleting user. Please try again.');
      }

      // Check RPC response
      if (!data || (typeof data === 'object' && 'success' in data && !data.success)) {
        const errorMsg = (data && typeof data === 'object' && 'error' in data) 
          ? data.error 
          : 'Could not delete user. User not found or already deleted.';
        throw new Error(errorMsg);
      }

      // 2) Delete from Auth so the email can be re-invited
      if (orgUser.user_id) {
        const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
        const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
        const { data: session } = await supabase.auth.getSession();
        const res = await fetch(`${supabaseUrl}/functions/v1/delete-auth-user`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${session?.session?.access_token ?? anonKey}`,
            apikey: anonKey ?? '',
          },
          body: JSON.stringify({ auth_user_id: orgUser.user_id }),
        });
        const fnData = await res.json().catch(() => ({}));
        if (!res.ok || !fnData?.ok) {
          console.warn('[OrganizationUser] Auth delete failed (user already soft-deleted):', fnData?.error);
          // Do not throw - user is already soft-deleted, they cannot access the app
        }
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'User Deleted',
        message: 'User has been deleted successfully.',
      });

      // Reset loading ref to allow reload
      hasLoadedRef.current = false;
      // Reload users
      await loadUsers();
    } catch (err: any) {
      const errorMessage = err.message || 'Error deleting user. Please try again.';
      if (import.meta.env.DEV) {
        console.error('Error in handleDeleteUser:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Delete Error',
        message: errorMessage,
      });
    } finally {
      setDeletingUserId(null);
      setIsLoading(false);
      setLoading(false); // Clear dialog loading state
      closeDialog();
    }
  };

  // Show loading state
  if (orgLoading || isLoading || roleLoading) return <div className="p-6" />;

  return (
    <div className="py-6">
      {/* Page Header */}
      <SettingsPageHeader
        title="Organization Users"
        subtitle="Configure and manage your organization users"
        actionLabel="Add User"
        onAction={() => router.navigate('/settings/organization-users/new')}
        actionDisabled={!canManageUsers}
        contextInfo={filteredUsers.length}
      />

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
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead>
                <tr className="bg-gray-100 border-b border-gray-200">
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('name')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name
                      {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('email')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Email
                      {sortBy === 'email' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('role')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Role
                      {sortBy === 'role' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('created_at')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Date Added
                      {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center">
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
                      <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                            <User className="w-4 h-4 text-gray-600" />
                          </div>
                          <span className="font-medium text-gray-900 truncate">
                            {orgUser.user_name || 'No name'}
                          </span>
                        </div>
                      </td>
                      <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                        {orgUser.user_email || '-'}
                      </td>
                      <td className="py-4 px-6 whitespace-nowrap">
                        <span className={`text-xs font-medium px-2 py-1 rounded capitalize ${getRoleBadgeColor(orgUser.role)}`}>
                          {orgUser.role}
                        </span>
                      </td>
                      <td className="py-4 px-6 whitespace-nowrap">
                        {(() => {
                          const statusBadge = getStatusBadge(orgUser.status);
                          return (
                            <span className={`text-xs font-medium px-2 py-1 rounded ${statusBadge.className}`}>
                              {statusBadge.label}
                            </span>
                          );
                        })()}
                      </td>
                      <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                        {new Date(orgUser.created_at).toLocaleDateString()}
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex items-center justify-end gap-2">
                          {/* Authorize button - show if status is not 'active' */}
                          {orgUser.status !== 'active' && orgUser.status !== 'invited' && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleAuthorize(orgUser.id);
                              }}
                              disabled={authorizingId === orgUser.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title="Authorize user"
                            >
                              <CheckCircle className="w-4 h-4" />
                            </button>
                          )}
                          
                          {/* Send Invite button - show if user_id is NULL and status is 'active' */}
                          {!orgUser.user_id && orgUser.status === 'active' && orgUser.user_email && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleSendInvite(orgUser);
                              }}
                              disabled={invitingId === orgUser.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title="Send invitation email"
                            >
                              <Send className="w-4 h-4" />
                            </button>
                          )}
                          
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              router.navigate(`/settings/organization-users/edit/${orgUser.id}`);
                            }}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title="Edit user"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleArchiveUser(orgUser.id, orgUser.user_email);
                            }}
                            disabled={archivingUserId === orgUser.id || orgUser.status === 'disabled'}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Archive user"
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                          {isSuperAdmin && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteUser(orgUser);
                              }}
                              disabled={deletingUserId === orgUser.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
                              title="Delete user"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
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
                        {orgUser.user_name || orgUser.user_email || orgUser.user_id?.substring(0, 8) + '...' || 'No name'}
                      </h3>
                      {orgUser.user_name && orgUser.user_email && (
                        <p className="text-xs text-gray-500 truncate">{orgUser.user_email}</p>
                      )}
                      {!orgUser.user_name && orgUser.user_email && (
                        <p className="text-xs text-gray-400 truncate italic">No name</p>
                      )}
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        <span className={`text-xs font-medium px-2 py-1 rounded capitalize ${getRoleBadgeColor(orgUser.role)}`}>
                          {orgUser.role}
                        </span>
                        {(() => {
                          const statusBadge = getStatusBadge(orgUser.status);
                          return (
                            <span className={`text-xs font-medium px-2 py-1 rounded ${statusBadge.className}`}>
                              {statusBadge.label}
                            </span>
                          );
                        })()}
                      </div>
                    </div>
                    <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          router.navigate(`/settings/organization-users/edit/${orgUser.id}`);
                        }}
                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                        aria-label={`Edit ${orgUser.user_name || orgUser.user_email || 'user'}`}
                        title={`Edit ${orgUser.user_name || orgUser.user_email || 'user'}`}
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleArchiveUser(orgUser.id, orgUser.user_email);
                        }}
                        disabled={archivingUserId === orgUser.id || orgUser.status === 'disabled'}
                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                        aria-label={`Archive ${orgUser.user_name || orgUser.user_email || 'user'}`}
                        title={`Archive ${orgUser.user_name || orgUser.user_email || 'user'}`}
                      >
                        <Archive className="w-4 h-4" />
                      </button>
                      {isSuperAdmin && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeleteUser(orgUser);
                          }}
                          disabled={deletingUserId === orgUser.id}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
                          aria-label={`Delete ${orgUser.user_name || orgUser.user_email || 'user'}`}
                          title={`Delete ${orgUser.user_name || orgUser.user_email || 'user'}`}
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </div>

                  {/* User Info */}
                  <div className="space-y-2">
                    {orgUser.user_email && (
                      <div className="flex items-center gap-2 text-xs text-gray-600">
                        <Mail className="w-3 h-3 flex-shrink-0" />
                        <span className="truncate">{orgUser.user_email}</span>
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
