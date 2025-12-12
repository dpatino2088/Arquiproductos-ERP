import React, { useState, useEffect } from 'react';
import { Plus, Mail, Shield, User, X, Copy } from 'lucide-react';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase';
import { useAuthStore } from '../../stores/auth-store';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';

interface OrganizationUser {
  id: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  created_at: string;
  user_id: string;
  email?: string;
}

interface OrganizationUsersProps {
  organizationId?: string | null;
}

export default function OrganizationUsers({ organizationId: propOrganizationId }: OrganizationUsersProps) {
  const { addNotification } = useUIStore();
  const { user } = useAuthStore();
  const { activeOrganizationId } = useOrganizationContext();
  const effectiveOrgId = propOrganizationId ?? activeOrganizationId;
  const [organizationId, setOrganizationId] = useState<string | null>(effectiveOrgId);
  
  // Get current user's role and permissions (uses active organization if no prop provided)
  const { canManageUsers, loading: roleLoading, role } = useCurrentOrgRole();
  const [users, setUsers] = useState<OrganizationUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isInviting, setIsInviting] = useState(false);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  
  // Invite form state
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState<'admin' | 'member' | 'viewer'>('member');

  // Update organizationId when prop or active organization changes
  useEffect(() => {
    const newOrgId = propOrganizationId ?? activeOrganizationId;
    setOrganizationId(newOrgId);
  }, [propOrganizationId, activeOrganizationId]);

  // Show message if no organization is selected
  if (!organizationId) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">
            Select an organization to continue.
          </p>
        </div>
      </div>
    );
  }

  // Load current organization ID if not provided (legacy support)
  useEffect(() => {
    if (organizationId || !user?.id) return;

    const loadOrganization = async () => {
      try {
        // Get organization from user metadata or from a selected organization context
        // For now, we'll get it from the first organization the user belongs to
        const { data: orgUser, error } = await supabase
          .from('OrganizationUsers')
          .select('organization_id')
          .eq('user_id', user.id)
          .eq('deleted', false)
          .limit(1)
          .maybeSingle(); // Use maybeSingle instead of single to handle no results gracefully

        if (error) {
          // Only log non-404 errors (PGRST116 is "no rows returned")
          if (error.code !== 'PGRST116') {
            console.error('Error loading organization:', error);
            // Don't show error to user if it's just a missing organization
            if (import.meta.env.DEV) {
              console.warn('User may not belong to any organization yet');
            }
          }
          return;
        }

        if (orgUser?.organization_id) {
          setOrganizationId(orgUser.organization_id);
        }
      } catch (err) {
        // Silently handle errors - user may not have an organization yet
        if (import.meta.env.DEV) {
          console.error('Error in loadOrganization:', err);
        }
      }
    };

    loadOrganization();
  }, [user, organizationId]);

  // Load users
  const loadUsers = async () => {
    if (!organizationId) {
      setUsers([]);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    try {
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
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({ organizationId }),
      });

      if (!response.ok) {
        // Fallback: use direct query (without emails)
        const { data, error } = await supabase
          .from('OrganizationUsers')
          .select('id, role, created_at, user_id')
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (error) {
          // If direct query also fails, just return empty array
          if (import.meta.env.DEV) {
            console.warn('Fallback query also failed:', error);
          }
          setUsers([]);
        } else {
          setUsers(data || []);
        }
      } else {
        const result = await response.json();
        setUsers(result.users || []);
      }
    } catch (err: any) {
      // Only log errors in development, don't spam console in production
      if (import.meta.env.DEV) {
        console.error('Error loading users:', err);
      }
      // Silently handle errors - show empty state instead of error notification
      // This prevents error spam when tables don't exist or RLS blocks access
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, [organizationId]);

  // Check if user can invite (owner or admin) - using hook instead
  // This function is kept for backward compatibility but uses the hook result
  const canInvite = async (): Promise<boolean> => {
    return canManageUsers;
  };

  const handleInvite = async () => {
    // Reset error state
    setInviteError(null);

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const trimmedEmail = inviteEmail.trim().toLowerCase();

    if (!trimmedEmail) {
      setInviteError('Please enter an email address');
      return;
    }

    if (!emailRegex.test(trimmedEmail)) {
      setInviteError('Please enter a valid email address');
      return;
    }

    if (!organizationId || !user?.id) {
      setInviteError('Missing required information');
      return;
    }

    // Check permissions
    const hasPermission = await canInvite();
    if (!hasPermission) {
      setInviteError('Only owners and admins can invite users');
      return;
    }

    setIsInviting(true);
    setInviteError(null);

    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      const { data: session } = await supabase.auth.getSession();
      if (!session?.session?.access_token) {
        throw new Error('Not authenticated');
      }

      const functionUrl = `${supabaseUrl}/functions/v1/invite-user-to-organization`;
      
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({
          organizationId,
          email: trimmedEmail,
          role: inviteRole,
          invitedByUserId: user.id,
        }),
      });

      if (!response.ok) {
        // Handle different error scenarios
        let errorMessage = 'Failed to invite user';
        
        try {
          const errorData = await response.json();
          errorMessage = errorData.error || errorMessage;
          
          // Check for permission errors (403)
          if (response.status === 403) {
            errorMessage = 'No tienes permisos para invitar usuarios. Solo owners y admins pueden invitar usuarios.';
          } else if (response.status === 409) {
            errorMessage = errorData.error || 'El usuario ya es miembro de esta organización';
          }
        } catch {
          // If JSON parsing fails, use status-based messages
          if (response.status === 403) {
            errorMessage = 'No tienes permisos para invitar usuarios. Solo owners y admins pueden invitar usuarios.';
          } else if (response.status === 404) {
            errorMessage = 'El endpoint de invitación no está disponible. Por favor, verifica la configuración.';
          } else if (response.status === 0 || response.status === 500) {
            errorMessage = 'Error de conexión con el servidor. Por favor, verifica tu conexión a internet.';
          } else {
            errorMessage = `Error al invitar usuario (${response.status})`;
          }
        }
        
        throw new Error(errorMessage);
      }

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.message || 'Failed to invite user');
      }

      // Update users list
      if (result.users) {
        setUsers(result.users);
      } else {
        // Reload users if not provided in response
        await loadUsers();
      }

      // Show success notification
      addNotification({
        type: 'success',
        title: 'Invitation Sent',
        message: result.isNewUser 
          ? 'Invitation email has been sent successfully' 
          : 'User has been added to the organization',
      });

      // Reset form and close modal
      setInviteEmail('');
      setInviteRole('member');
      setShowInviteModal(false);
      setInviteError(null);
    } catch (err: any) {
      console.error('Error inviting user:', err);
      const errorMessage = err.message || 'Failed to invite user. Please try again.';
      setInviteError(errorMessage);
      // Also show notification for visibility
      addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
      });
    } finally {
      setIsInviting(false);
    }
  };

  const handleUpdateRole = async (userId: string, newRole: 'owner' | 'admin' | 'member' | 'viewer') => {
    if (!organizationId || !user?.id) return;

    const hasPermission = await canInvite();
    if (!hasPermission) {
      addNotification({
        type: 'error',
        title: 'Permission Denied',
        message: 'Only owners and admins can update user roles',
      });
      return;
    }

    try {
      const { error } = await supabase
        .from('OrganizationUsers')
        .update({ role: newRole, updated_at: new Date().toISOString() })
        .eq('organization_id', organizationId)
        .eq('user_id', userId)
        .eq('deleted', false);

      if (error) throw error;

      addNotification({
        type: 'success',
        title: 'Role Updated',
        message: 'User role has been updated successfully',
      });

      loadUsers();
    } catch (err: any) {
      console.error('Error updating role:', err);
      addNotification({
        type: 'error',
        title: 'Error',
        message: 'Failed to update user role',
      });
    }
  };

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

  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-sm text-muted-foreground">Loading users...</div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-semibold text-foreground">Organization Users</h2>
          <p className="text-sm text-muted-foreground mt-1">
            Manage users and their roles in this organization
          </p>
        </div>
        {canManageUsers ? (
          <button
            onClick={() => setShowInviteModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors text-sm"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus className="w-4 h-4" />
            Invite User
          </button>
        ) : (
          <span className="text-xs text-muted-foreground">
            Role: {role ?? 'no role'} — You don't have permission to manage users.
          </span>
        )}
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                User
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Role
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Joined
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {users.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-6 py-8 text-center text-sm text-muted-foreground">
                  No users found. Invite your first user to get started.
                </td>
              </tr>
            ) : (
              users.map((orgUser) => (
                <tr key={orgUser.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                        <User className="w-4 h-4 text-gray-600" />
                      </div>
                      <div className="ml-3">
                        <div className="text-sm font-medium text-foreground">
                          {orgUser.email || orgUser.user_id.substring(0, 8) + '...'}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <select
                      value={orgUser.role}
                      onChange={(e) => handleUpdateRole(orgUser.user_id, e.target.value as any)}
                      className={`text-xs font-medium px-2 py-1 rounded ${getRoleBadgeColor(orgUser.role)} border-0`}
                      disabled={orgUser.user_id === user?.id} // Can't change own role
                    >
                      <option value="owner">Owner</option>
                      <option value="admin">Admin</option>
                      <option value="member">Member</option>
                      <option value="viewer">Viewer</option>
                    </select>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    {new Date(orgUser.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    {/* Actions can be added here */}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Invite Modal */}
      {showInviteModal && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setShowInviteModal(false);
              setInviteError(null);
            }
          }}
        >
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-foreground">Invite User</h3>
              <button
                onClick={() => setShowInviteModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-2">
                  Email
                </label>
                <input
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => {
                    setInviteEmail(e.target.value);
                    setInviteError(null); // Clear error when user types
                  }}
                  className={`w-full px-3 py-2 border rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50 ${
                    inviteError ? 'border-red-300' : 'border-gray-300'
                  }`}
                  placeholder="user@example.com"
                  disabled={isInviting}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-foreground mb-2">
                  Role
                </label>
                <select
                  value={inviteRole}
                  onChange={(e) => setInviteRole(e.target.value as any)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                  disabled={isInviting}
                >
                  <option value="admin">Admin</option>
                  <option value="member">Member</option>
                  <option value="viewer">Viewer</option>
                </select>
                <p className="text-xs text-muted-foreground mt-1">
                  Note: Owner role can only be assigned by app admins
                </p>
              </div>

              {inviteError && (
                <div className="bg-red-50 border border-red-200 rounded-md p-3">
                  <p className="text-sm text-red-800">{inviteError}</p>
                </div>
              )}
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setShowInviteModal(false);
                  setInviteError(null);
                  setInviteEmail('');
                  setInviteRole('member');
                }}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-md text-sm text-foreground hover:bg-gray-50 transition-colors"
                disabled={isInviting}
              >
                Cancel
              </button>
              <button
                onClick={handleInvite}
                disabled={isInviting || !inviteEmail.trim()}
                className="flex-1 px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isInviting ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    <span>Inviting...</span>
                  </>
                ) : (
                  'Invite'
                )}
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

