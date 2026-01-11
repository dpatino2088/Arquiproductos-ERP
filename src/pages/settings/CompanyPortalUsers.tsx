import React, { useState, useEffect, useCallback } from 'react';
import { useCompanyPortalUsers, type CompanyPortalUser } from '../../hooks/useCompanyPortalUsers';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { User, Mail, Phone, Shield, Plus, X, Send, CheckCircle, MoreVertical, Edit, Trash2, Archive, Copy, Check } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { normalizeRole, getRoleLabel, getRoleDescription, type CompanyPortalRole } from '../../portal/portalAccess';

interface StatusBadgeProps {
  status: string;
}

function StatusBadge({ status }: StatusBadgeProps) {
  // Normalize legacy 'invited'/'draft' to 'active' for display
  // Portal users only use 'active' or 'disabled'
  const normalizedStatus = (() => {
    const s = (status || '').toLowerCase().trim();
    if (s === 'invited' || s === 'draft') {
      return 'active';
    }
    return s === 'disabled' ? 'disabled' : 'active';
  })();
  
  const statusColors: Record<string, { bg: string; text: string; border: string; label: string }> = {
    active: { 
      bg: 'bg-green-50', 
      text: 'text-green-700', 
      border: 'border border-green-200',
      label: 'Active'
    },
    disabled: { 
      bg: 'bg-gray-50', 
      text: 'text-gray-700', 
      border: 'border border-gray-200',
      label: 'Disabled'
    }
  };

  const colors = statusColors[normalizedStatus] || statusColors.disabled;

  return (
    <span className={`px-2 py-1 rounded text-xs font-medium capitalize ${colors.bg} ${colors.text} ${colors.border}`}>
      {colors.label}
    </span>
  );
}

interface CreatePortalUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
}

interface EditPortalUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
  user: CompanyPortalUser | null;
}


function CreatePortalUserModal({ isOpen, onClose, onSuccess, organizationId }: CreatePortalUserModalProps) {
  const { user } = useAuthStore();
  const { addNotification } = useUIStore();
  
  // Form state
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [company_id, setCompany_id] = useState<string>('');
  const [role, setRole] = useState<CompanyPortalRole>('member');
  const [status, setStatus] = useState<string>('authorized');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Companies (NO DirectoryCustomers)
  const [companies, setCompanies] = useState<Array<{ id: string; company_name: string }>>([]);
  
  // Loading states
  const [loadingCompanies, setLoadingCompanies] = useState(false);

  // Load companies (de la organization actual)
  const loadCompanies = useCallback(async () => {
    if (!organizationId) return;
    
    setLoadingCompanies(true);
    try {
      const { data, error } = await supabase
        .from('Companies')
        .select('id, company_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('company_name', { ascending: true });

      if (error) {
        console.error('Error loading companies:', error);
        setCompanies([]);
      } else {
        setCompanies(data || []);
      }
    } catch (err) {
      console.error('Error loading companies:', err);
      setCompanies([]);
    } finally {
      setLoadingCompanies(false);
    }
  }, [organizationId]);

  // Load data when modal opens
  useEffect(() => {
    if (isOpen) {
      loadCompanies();
      // Reset form
      setUser_name('');
      setUser_email('');
      setCompany_id('');
      setRole('member');
      setStatus('authorized');
      setSubmitError(null);
    }
  }, [isOpen, loadCompanies]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validate required fields
    const trimmedName = user_name.trim();
    const trimmedEmail = user_email.trim();
    
    if (!trimmedName) {
      setSubmitError('Name is required');
      return;
    }

    if (!trimmedEmail) {
      setSubmitError('Email is required');
      return;
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) {
      setSubmitError('Please enter a valid email address');
      return;
    }

    if (!user?.id) {
      setSubmitError('You must be logged in to create portal users');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      // Validate required fields
      if (!company_id) {
        setSubmitError('Company is required');
        setIsSubmitting(false);
        return;
      }

      // Use Edge Function send-invite to create auth user and send invitation email
      const { data, error: inviteError } = await supabase.functions.invoke('send-invite', {
        body: {
          kind: 'portal',
          organization_id: organizationId,
          company_id: company_id,
          email: trimmedEmail.trim().toLowerCase(),
          role: role, // 'member' | 'member_manager'
          name: trimmedName || null,
          redirect_to: `${window.location.origin}/auth/callback`,
        },
      });

      if (inviteError) {
        throw inviteError;
      }

      if (!data?.ok) {
        throw new Error(data?.error || 'Invite failed');
      }

      if (import.meta.env.DEV) {
        console.log('[CreatePortalUserModal] Invite OK:', data);
      }

      addNotification({
        type: 'success',
        title: 'Portal User Invited',
        message: 'Invitation email has been sent successfully.',
      });

      onSuccess();
      onClose();
    } catch (err: any) {
      const errorMessage = err.message || 'Error creating portal user';
      setSubmitError(errorMessage);
      addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Add Portal User</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            disabled={isSubmitting}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {submitError && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-sm text-red-800">{submitError}</p>
            </div>
          )}

          {/* User Name */}
          <div>
            <Label htmlFor="user_name">Name *</Label>
            <Input
              id="user_name"
              type="text"
              value={user_name}
              onChange={(e) => setUser_name(e.target.value)}
              required
              disabled={isSubmitting}
              placeholder="Enter user name"
            />
          </div>

          {/* User Email */}
          <div>
            <Label htmlFor="user_email">Email *</Label>
            <Input
              id="user_email"
              type="email"
              value={user_email}
              onChange={(e) => setUser_email(e.target.value)}
              required
              disabled={isSubmitting}
              placeholder="Enter user email"
            />
          </div>

          {/* Company Selection (Required) */}
          <div>
            <Label htmlFor="company_id">Company *</Label>
            {loadingCompanies ? (
              <div className="text-sm text-gray-500 py-2">Loading companies...</div>
            ) : (
              <select
                id="company_id"
                value={company_id}
                onChange={(e) => {
                  setCompany_id(e.target.value);
                }}
                required
                disabled={isSubmitting}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
              >
                <option value="">Select a company</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.company_name}
                  </option>
                ))}
              </select>
            )}
            {companies.length === 0 && !loadingCompanies && (
              <p className="text-xs text-gray-500 mt-1">No companies available. Create a company first.</p>
            )}
          </div>

          {/* Role */}
          <div>
            <Label htmlFor="role">Role *</Label>
            <select
              id="role"
              value={role}
              onChange={(e) => setRole(e.target.value as CompanyPortalRole)}
              required
              disabled={isSubmitting}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              <option value="member_manager">Member Manager</option>
              <option value="member">Member</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              {getRoleDescription(role)}
            </p>
          </div>

          {/* Status */}
          <div>
            <Label htmlFor="status">Status *</Label>
            <select
              id="status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              required
              disabled={isSubmitting}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              <option value="active">Active</option>
              <option value="disabled">Disabled</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Active: User can access portal. Disabled: Access blocked.
            </p>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !user_name.trim() || !user_email.trim()}
              className="px-4 py-2 text-sm font-medium text-white rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              {isSubmitting ? 'Creating...' : 'Create Portal User'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditPortalUserModal({ isOpen, onClose, onSuccess, organizationId, user }: EditPortalUserModalProps) {
  const { user: currentUser } = useAuthStore();
  const { addNotification } = useUIStore();
  
  // Form state
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [company_id, setCompany_id] = useState<string>('');
  const [role, setRole] = useState<CompanyPortalRole>('member');
  const [status, setStatus] = useState<string>('active');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Companies (NO DirectoryCustomers)
  const [companies, setCompanies] = useState<Array<{ id: string; company_name: string }>>([]);
  
  // Loading states
  const [loadingCompanies, setLoadingCompanies] = useState(false);

  // Load companies (de la organization actual)
  const loadCompanies = useCallback(async () => {
    if (!organizationId) return;
    
    setLoadingCompanies(true);
    try {
      const { data, error } = await supabase
        .from('Companies')
        .select('id, company_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('company_name', { ascending: true });

      if (error) {
        console.error('Error loading companies:', error);
        setCompanies([]);
      } else {
        setCompanies(data || []);
      }
    } catch (err) {
      console.error('Error loading companies:', err);
      setCompanies([]);
    } finally {
      setLoadingCompanies(false);
    }
  }, [organizationId]);

  // Load data when modal opens or user changes
  useEffect(() => {
    if (isOpen && user) {
      loadCompanies();
      // Populate form with user data - use CompanyPortalUser fields directly
      setUser_name(user.portal_user_name || '');
      setUser_email(user.portal_user_email || '');
      setCompany_id(user.company_id || '');
      // Load role directly from user - normalize to handle legacy values
      const currentRole = user.portal_user_role || 'member';
      // Normalize the role to handle any legacy values (e.g., 'manager' -> 'member_manager')
      // But preserve the exact value if it's already valid
      const validRoles: CompanyPortalRole[] = ['member_manager', 'member'];
      const isRoleValid = validRoles.includes(currentRole as CompanyPortalRole);
      const normalizedRole = isRoleValid 
        ? (currentRole as CompanyPortalRole) 
        : normalizeRole(currentRole);
      setRole(normalizedRole);
      // Portal users only use 'active' or 'disabled' status
      const currentStatus = user.portal_user_status?.toLowerCase().trim() || 'active';
      // Normalize legacy 'invited'/'draft' to 'active'
      const normalizedStatus = currentStatus === 'invited' || currentStatus === 'draft' ? 'active' : currentStatus;
      const validStatuses = ['active', 'disabled'];
      setStatus(validStatuses.includes(normalizedStatus) ? normalizedStatus : 'active');
      setSubmitError(null);
      
      if (import.meta.env.DEV) {
        console.log('[EditPortalUserModal] Loading user data:', {
          role: user.role || user.portal_user_role,
          normalizedRole: normalizedRole,
          status: user.status || user.portal_user_status,
        });
      }
    }
  }, [isOpen, user, loadCompanies]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!user?.id) {
      setSubmitError('User ID is required');
      return;
    }

    // Validate required fields
    const trimmedName = user_name.trim();
    const trimmedEmail = user_email.trim();
    
    if (!trimmedName) {
      setSubmitError('Name is required');
      return;
    }

    if (!trimmedEmail) {
      setSubmitError('Email is required');
      return;
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) {
      setSubmitError('Please enter a valid email address');
      return;
    }

    if (!currentUser?.id) {
      setSubmitError('You must be logged in to edit portal users');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      // Portal users only use 'active' or 'disabled'
      const normalizedStatus = (status || '').toLowerCase().trim();
      const validStatuses = ['active', 'disabled'];
      const finalStatus = validStatuses.includes(normalizedStatus) ? normalizedStatus : 'active';

      // Validar que company_id existe (requerido en nuevo schema)
      if (!company_id) {
        setSubmitError('Company is required');
        setIsSubmitting(false);
        return;
      }

      // SOLO columnas explícitas: portal_user_email, portal_user_name, status, company_id, role
      // IMPORTANT: Use 'role' column name (matches actual DB schema), not 'portal_user_role'
      // Ensure role is valid: member_manager or member - validate directly (don't normalize to avoid issues)
      const validRoles: CompanyPortalRole[] = ['member_manager', 'member'];
      const finalRole: CompanyPortalRole = validRoles.includes(role) ? role : 'member';
      
      // Only update organization_id if it's currently null (migration case)
      // Don't update it if it already has a value
      const updatePayload: any = {
        company_id: company_id,
        portal_user_email: trimmedEmail,
        portal_user_name: trimmedName || null,
        role: finalRole, // Use 'role' column name (not 'portal_user_role')
        status: finalStatus, // Use 'status' column name (not 'portal_user_status')
        updated_at: new Date().toISOString(),
      };
      
      // Only include organization_id in UPDATE if it's null in the DB (for migration)
      // Otherwise, let the DB constraint handle it via company_id relationship
      if (!user.organization_id && organizationId) {
        updatePayload.organization_id = organizationId;
      }
      
      if (import.meta.env.DEV) {
        console.log('[EditPortalUserModal] Saving role:', {
          roleFromState: role,
          finalRole: finalRole,
          updatePayload: updatePayload.portal_user_role,
        });
      }

      if (import.meta.env.DEV) {
        console.log('[EditPortalUserModal] Updating portal user with payload:', updatePayload);
      }

      // Build update query - only filter by id (organization_id may be null in DB)
      // Don't filter by organization_id as it may be NULL in existing records
      // Note: We don't use .select() after UPDATE because RLS might prevent returning data
      // If updateError is null, the update was successful
      
      if (import.meta.env.DEV) {
        console.log('[EditPortalUserModal] About to update with payload:', {
          userId: user.id,
          organizationId: organizationId,
          updatePayload,
          roleState: role,
          finalRole: finalRole,
        });
      }
      
      // Use SELECT to get back the updated row for verification
      // This helps us confirm the update worked and see the actual saved values
      const { error: updateError, data: updateData } = await supabase
        .from('CompanyPortalUsers')
        .update(updatePayload)
        .eq('id', user.id)
        .select('id, role, status, organization_id')
        .maybeSingle();

      if (updateError) {
        const errorMsg = updateError.message || 'Failed to update portal user';
        if (import.meta.env.DEV) {
          console.error('[EditPortalUserModal] Update error:', updateError);
          console.error('[EditPortalUserModal] Error details:', {
            code: updateError.code,
            details: updateError.details,
            hint: updateError.hint,
            message: updateError.message,
          });
          console.error('[EditPortalUserModal] Update query details:', {
            userId: user.id,
            organizationId: organizationId,
            updatePayload,
          });
        }
        throw new Error(`${errorMsg}. Payload: ${JSON.stringify(updatePayload)}`);
      }

      if (import.meta.env.DEV) {
        console.log('[EditPortalUserModal] Update completed without errors:', {
          roleFromState: role,
          finalRole: finalRole,
          userId: user.id,
          updatePayload: {
            role: updatePayload.role,
            status: updatePayload.status,
          },
          returnedData: updateData,
        });
      }
      
      // If we got data back from the UPDATE, verify it matches what we sent
      if (updateData) {
        // Check role from returned data (may be 'role' or 'portal_user_role' depending on DB schema)
        const returnedRole = updateData.role || updateData.portal_user_role;
        if (returnedRole !== finalRole) {
          console.warn('[EditPortalUserModal] ⚠️ WARNING: Role mismatch in returned data!', {
            expected: finalRole,
            returned: returnedRole,
            userId: user.id,
          });
        } else {
          if (import.meta.env.DEV) {
            console.log('[EditPortalUserModal] ✅ Role matches in returned data:', returnedRole);
          }
        }
      } else {
        if (import.meta.env.DEV) {
          console.warn('[EditPortalUserModal] ⚠️ No data returned from UPDATE (RLS might be blocking SELECT)');
        }
      }
      
      // Verify the update by fetching the record (this helps debug if RLS is blocking)
      // We do this in a try-catch to avoid breaking the flow if RLS prevents read
      try {
        const { data: verifyData, error: verifyError } = await supabase
          .from('CompanyPortalUsers')
          .select('id, role, status')
          .eq('id', user.id)
          .maybeSingle();
        
        if (verifyError) {
          if (import.meta.env.DEV) {
            console.warn('[EditPortalUserModal] Could not verify update (RLS might prevent read):', {
              error: verifyError,
              code: verifyError.code,
              message: verifyError.message,
              details: verifyError.details,
              hint: verifyError.hint,
            });
          }
        } else if (verifyData) {
          // Check role from returned data (may be 'role' or 'portal_user_role' depending on DB schema)
          const verifiedRole = verifyData.role || verifyData.portal_user_role;
          const verifiedStatus = verifyData.status || verifyData.portal_user_status;
          if (import.meta.env.DEV) {
            console.log('[EditPortalUserModal] Update verified - current DB values:', {
              role: verifiedRole,
              status: verifiedStatus,
              expectedRole: finalRole,
              rolesMatch: verifiedRole === finalRole,
            });
          }
          
          // If the role doesn't match what we tried to save, there might be a constraint issue
          if (verifiedRole !== finalRole) {
            console.warn('[EditPortalUserModal] WARNING: Role mismatch after update!', {
              expected: finalRole,
              actual: verifiedRole,
              userId: user.id,
            });
          }
        } else {
          if (import.meta.env.DEV) {
            console.warn('[EditPortalUserModal] Could not verify update - record not found or RLS blocked');
          }
        }
      } catch (verifyErr) {
        // Silently continue if verification fails - RLS might be blocking
        if (import.meta.env.DEV) {
          console.warn('[EditPortalUserModal] Verification failed:', verifyErr);
        }
      }

      addNotification({
        type: 'success',
        title: 'Portal User Updated',
        message: 'The portal user has been updated successfully.',
      });

      // Close modal first
      onClose();
      
      // Immediately refresh the list to show updated data
      // The verification above should have confirmed the update worked
      onSuccess();
    } catch (err: any) {
      const errorMessage = err.message || 'Error updating portal user';
      setSubmitError(errorMessage);
      addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen || !user) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Edit Portal User</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            disabled={isSubmitting}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {submitError && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-sm text-red-800">{submitError}</p>
            </div>
          )}

          {/* User Name */}
          <div>
            <Label htmlFor="edit_user_name">Name *</Label>
            <Input
              id="edit_user_name"
              type="text"
              value={user_name}
              onChange={(e) => setUser_name(e.target.value)}
              required
              disabled={isSubmitting}
              placeholder="Enter user name"
            />
          </div>

          {/* User Email */}
          <div>
            <Label htmlFor="edit_user_email">Email *</Label>
            <Input
              id="edit_user_email"
              type="email"
              value={user_email}
              onChange={(e) => setUser_email(e.target.value)}
              required
              disabled={isSubmitting}
              placeholder="Enter user email"
            />
          </div>

          {/* Company Selection (Required) */}
          <div>
            <Label htmlFor="edit_company_id">Company *</Label>
            {loadingCompanies ? (
              <div className="text-sm text-gray-500 py-2">Loading companies...</div>
            ) : (
              <select
                id="edit_company_id"
                value={company_id}
                onChange={(e) => setCompany_id(e.target.value)}
                required
                disabled={isSubmitting}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
              >
                <option value="">Select a company</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.company_name}
                  </option>
                ))}
              </select>
            )}
            {companies.length === 0 && !loadingCompanies && (
              <p className="text-xs text-gray-500 mt-1">No companies available. Create a company first.</p>
            )}
          </div>

          {/* Role */}
          <div>
            <Label htmlFor="edit_role">Role *</Label>
            <select
              id="edit_role"
              value={role}
              onChange={(e) => {
                const newRole = e.target.value as CompanyPortalRole;
                if (import.meta.env.DEV) {
                  console.log('[EditPortalUserModal] Role changed:', {
                    oldRole: role,
                    newRole: newRole,
                    rawValue: e.target.value,
                  });
                }
                setRole(newRole);
              }}
              required
              disabled={isSubmitting}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              <option value="member_manager">Member Manager</option>
              <option value="member">Member</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              {getRoleDescription(role)}
            </p>
          </div>

          {/* Status */}
          <div>
            <Label htmlFor="edit_status">Status *</Label>
            <select
              id="edit_status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              required
              disabled={isSubmitting}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              <option value="invited">Invited</option>
              <option value="active">Active</option>
              <option value="disabled">Disabled</option>
            </select>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !user_name.trim() || !user_email.trim()}
              className="px-4 py-2 text-sm font-medium text-white rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              {isSubmitting ? 'Updating...' : 'Update Portal User'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function CompanyPortalUsers() {
  // ✅ Hooks at the TOP (React rules)
  const { activeOrganizationId } = useOrganizationContext();
  const { users, isLoading: loading, error, refetch } = useCompanyPortalUsers();
  const { user: currentUser } = useAuthStore();
  const { addNotification } = useUIStore();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<CompanyPortalUser | null>(null);
  const [authorizingId, setAuthorizingId] = useState<string | null>(null);
  const [invitingId, setInvitingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [inviteLink, setInviteLink] = useState<string | null>(null);
  const [copiedLinkId, setCopiedLinkId] = useState<string | null>(null);

  // Handle Authorize action
  const handleAuthorize = async (userId: string) => {
    if (!activeOrganizationId) return;
    
    try {
      setAuthorizingId(userId);

      const { error } = await supabase
        .from('CompanyPortalUsers')
        .update({ status: 'active' }) // Use 'status' column name (not 'portal_user_status')
        .eq('id', userId)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        throw error;
      }

      addNotification({
        type: 'success',
        title: 'User Authorized',
        message: 'Portal user has been authorized successfully.',
      });

      refetch();
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to authorize user',
      });
    } finally {
      setAuthorizingId(null);
    }
  };

  // Handle Edit action
  const handleEdit = (user: CompanyPortalUser) => {
    setEditingUser(user);
    setIsEditOpen(true);
  };

  // Handle Delete action
  const handleDelete = async (user: CompanyPortalUser) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Delete Portal User',
      message: `Are you sure you want to delete "${user.portal_user_name || user.portal_user_email || 'this user'}"? This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    setDeletingId(user.id);
    setLoading(true);

    try {
      const { error } = await supabase
        .from('CompanyPortalUsers')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .eq('id', user.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      addNotification({
        type: 'success',
        title: 'User Deleted',
        message: 'Portal user has been deleted successfully.',
      });

      refetch();
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to delete user',
      });
    } finally {
      setDeletingId(null);
      setLoading(false);
    }
  };

  // Handle Archive action
  const handleArchive = async (user: CompanyPortalUser) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Archive Portal User',
      message: `Are you sure you want to archive "${user.portal_user_name || user.portal_user_email || 'this user'}"?`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    setArchivingId(user.id);
    setLoading(true);

    try {
      const { error } = await supabase
        .from('CompanyPortalUsers')
        .update({ status: 'disabled', updated_at: new Date().toISOString() }) // Use 'status' column name (not 'portal_user_status')
        .eq('id', user.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      addNotification({
        type: 'success',
        title: 'User Archived',
        message: 'Portal user has been archived successfully.',
      });

      refetch();
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to archive user',
      });
    } finally {
      setArchivingId(null);
      setLoading(false);
    }
  };

  // Handle Copy Invite Link
  const handleCopyLink = async (link: string, userId: string) => {
    try {
      await navigator.clipboard.writeText(link);
      setCopiedLinkId(userId);
      setTimeout(() => setCopiedLinkId(null), 2000);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: 'Failed to copy link to clipboard',
      });
    }
  };

  // Handle Resend Invite action
  const handleResendInvite = async (user: CompanyPortalUser) => {
    if (!activeOrganizationId || !user.portal_user_email || !currentUser) return;
    
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

      const functionUrl = `${supabaseUrl}/functions/v1/send-customer-portal-invite`;
      const redirectUrl = `${window.location.origin}/auth/callback`;
      
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({
          organization_id: activeOrganizationId,
          portal_user_id: user.id,
          email: user.portal_user_email || '',
          name: user.portal_user_name || null,
          redirect_to: redirectUrl,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to resend invite');
      }

      // Store invite link if returned (per user)
      if (result.invite_link) {
        sessionStorage.setItem(`invite_link_${user.id}`, result.invite_link);
      }

      addNotification({
        type: 'success',
        title: 'Invite Resent',
        message: result.invite_link ? 'Invitation email has been resent successfully. Link available below.' : 'Invitation email has been resent successfully.',
      });

      refetch();
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to resend invite',
      });
    } finally {
      setInvitingId(null);
    }
  };

  // Show loading state
  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading portal users...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state
  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading portal users</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  // Show message if no organization
  if (!activeOrganizationId) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to view portal users.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Company Portal Users</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage company portal access and permissions
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => refetch()}
            className="flex items-center gap-2 px-3 py-1.5 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm"
          >
            <Shield className="w-4 h-4" />
            Refresh
          </button>
          {activeOrganizationId && (
            <button
              onClick={() => setIsCreateOpen(true)}
              className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus className="w-4 h-4" />
              Add Portal User
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-100 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Company</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Role</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Email</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Date Added</th>
                <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {users.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 px-6 text-center">
                    <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-600 mb-2">No portal users found</p>
                    <p className="text-sm text-gray-500">
                      Portal users will appear here once they are created.
                    </p>
                  </td>
                </tr>
              ) : (
                users.map((user: CompanyPortalUser) => (
                  <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer">
                    {/* Name */}
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                          <User className="w-4 h-4 text-gray-600" />
                        </div>
                        <span className="font-medium text-gray-900 truncate">
                          {user.portal_user_name || 'No name'}
                        </span>
                      </div>
                    </td>
                    
                    {/* Company */}
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {user.company_name || '-'}
                    </td>
                    
                    {/* Role */}
                    <td className="py-4 px-6 whitespace-nowrap">
                      {(() => {
                        const role = normalizeRole(user.portal_user_role || 'member');
                        const roleColors: Record<string, { bg: string; text: string; border: string }> = {
                          member_manager: {
                            bg: 'bg-purple-50',
                            text: 'text-purple-700',
                            border: 'border border-purple-200',
                          },
                          member: {
                            bg: 'bg-blue-50',
                            text: 'text-blue-700',
                            border: 'border border-blue-200',
                          },
                        };
                        const colors = roleColors[role] || roleColors.member;
                        return (
                          <span className={`px-2 py-1 rounded text-xs font-medium ${colors.bg} ${colors.text} ${colors.border}`}>
                            {getRoleLabel(role)}
                          </span>
                        );
                      })()}
                    </td>
                    
                    {/* Email */}
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {user.portal_user_email || '-'}
                    </td>
                    
                    {/* Status */}
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={user.portal_user_status || 'disabled'} />
                    </td>
                    
                    {/* Date Added */}
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {user.created_at 
                        ? new Date(user.created_at).toLocaleDateString()
                        : '-'}
                    </td>
                    
                    {/* Actions */}
                    <td className="py-4 px-6">
                      <div className="flex items-center justify-end gap-2">
                        {/* Authorize button - show if status is 'invited' */}
                        {user.portal_user_status === 'invited' && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleAuthorize(user.id);
                            }}
                            disabled={authorizingId === user.id}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Authorize user"
                          >
                            <CheckCircle className="w-4 h-4" />
                          </button>
                        )}
                        
                        {/* Resend Invite button - show if status is 'invited' */}
                        {user.portal_user_status === 'invited' && user.portal_user_email && (
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => handleResendInvite(user)}
                              disabled={invitingId === user.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title="Resend invitation email"
                            >
                              <Send className="w-4 h-4" />
                            </button>
                            {/* Show invite link after successful resend */}
                            {(() => {
                              const storedLink = sessionStorage.getItem(`invite_link_${user.id}`);
                              return storedLink ? (
                                <div className="flex items-center gap-1 bg-gray-50 border border-gray-200 rounded px-2 py-1">
                                  <input
                                    type="text"
                                    value={storedLink}
                                    readOnly
                                    className="text-xs bg-transparent border-none outline-none text-gray-700 w-48"
                                    onClick={(e) => e.currentTarget.select()}
                                  />
                                  <button
                                    onClick={() => handleCopyLink(storedLink, user.id)}
                                    className="p-1 hover:bg-gray-200 rounded transition-colors text-gray-600"
                                    title="Copy link"
                                  >
                                    {copiedLinkId === user.id ? (
                                      <Check className="w-3 h-3 text-green-600" />
                                    ) : (
                                      <Copy className="w-3 h-3" />
                                    )}
                                  </button>
                                </div>
                              ) : null;
                            })()}
                          </div>
                        )}

                        {/* Edit button */}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleEdit(user);
                          }}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                          title="Edit user"
                        >
                          <Edit className="w-4 h-4" />
                        </button>

                        {/* Archive button */}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleArchive(user);
                          }}
                          disabled={archivingId === user.id || user.status === 'disabled'}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                          title="Archive user"
                        >
                          <Archive className="w-4 h-4" />
                        </button>

                        {/* Delete button */}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDelete(user);
                          }}
                          disabled={deletingId === user.id}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600 disabled:opacity-50"
                          title="Delete user"
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

      {/* Summary */}
      {users.length > 0 && (
        <div className="mt-4 text-sm text-gray-600">
          Showing {users.length} portal user{users.length !== 1 ? 's' : ''}
        </div>
      )}

      {/* Create Modal */}
      {activeOrganizationId && (
        <CreatePortalUserModal
          isOpen={isCreateOpen}
          onClose={() => setIsCreateOpen(false)}
          onSuccess={() => {
            refetch();
          }}
          organizationId={activeOrganizationId}
        />
      )}

      {/* Edit Modal */}
      {activeOrganizationId && editingUser && (
        <EditPortalUserModal
          isOpen={isEditOpen}
          onClose={() => {
            setIsEditOpen(false);
            setEditingUser(null);
          }}
          onSuccess={() => {
            refetch();
            setIsEditOpen(false);
            setEditingUser(null);
          }}
          organizationId={activeOrganizationId}
          user={editingUser}
        />
      )}


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
