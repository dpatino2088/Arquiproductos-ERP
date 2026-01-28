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

interface PortalUser {
  id: string;
  user_id: string | null;
  user_name: string | null;
  user_email: string | null;
  company_id: string | null;
  contact_id: string | null;
  contact_name: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  status: string;
  created_at: string;
  organization_id: string;
}

interface StatusBadgeProps {
  status: string;
}

function StatusBadge({ status }: StatusBadgeProps) {
  const statusColors: Record<string, { bg: string; text: string }> = {
    draft: { bg: 'bg-gray-50', text: 'text-gray-700' },
    authorized: { bg: 'bg-blue-50', text: 'text-blue-700' },
    invited: { bg: 'bg-yellow-50', text: 'text-yellow-700' },
    active: { bg: 'bg-green-50', text: 'text-green-700' },
    inactive: { bg: 'bg-gray-50', text: 'text-gray-700' },
    disabled: { bg: 'bg-red-50', text: 'text-red-700' },
    pending: { bg: 'bg-yellow-50', text: 'text-yellow-700' },
    suspended: { bg: 'bg-red-50', text: 'text-red-700' },
  };

  const colors = statusColors[status.toLowerCase()] ?? statusColors.inactive;

  return (
    <span className={`px-2 py-1 rounded-full text-xs font-medium ${colors.bg} ${colors.text}`}>
      {status || 'Unknown'}
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
  user: PortalUser | null;
}

interface InvitePortalUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
}

function CreatePortalUserModal({ isOpen, onClose, onSuccess, organizationId }: CreatePortalUserModalProps) {
  const { user } = useAuthStore();
  const { addNotification } = useUIStore();
  
  // Form state
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [company_id, setCompany_id] = useState<string>(''); // Cambiado: company_id en lugar de customer_id
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
      setCompany_id(''); // Cambiado: company_id
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
      // Normalize status: UI shows "Authorized" but DB stores "invited"
      const normalizedStatus =
        (status || '').toLowerCase() === 'authorized'
          ? 'invited'
          : (status || '').toLowerCase();

      // Ensure status is a valid DB value (only 'invited', 'active', 'disabled' allowed)
      const validStatuses = ['invited', 'active', 'disabled'];
      const finalStatus = validStatuses.includes(normalizedStatus) ? normalizedStatus : 'invited';

      // Validar que company_id existe (requerido en nuevo schema)
      if (!company_id) {
        setSubmitError('Company is required');
        setIsSubmitting(false);
        return;
      }

      const insertPayload = {
        company_id: company_id, // Cambiado: company_id (requerido, NO nullable)
        portal_user_email: trimmedEmail,
        portal_user_status: finalStatus,
        invited_by_user_id: user.id,
        deleted: false,
      };

      const { error: insertError } = await supabase
        .from('CompanyPortalUsers')
        .insert(insertPayload);

      if (insertError) {
        // Enhanced error message showing what was sent
        const errorMsg = insertError.message || 'Failed to create portal user';
        const statusInfo = `Status sent: "${status}" (normalized to "${finalStatus}")`;
        throw new Error(`${errorMsg}. ${statusInfo}. Payload: ${JSON.stringify(insertPayload)}`);
      }

      addNotification({
        type: 'success',
        title: 'Portal User Created',
        message: 'The portal user has been created successfully.',
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

          {/* Customer Selection (Optional) */}
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
              <option value="authorized">Authorized</option>
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
  const [company_id, setCompany_id] = useState<string>(''); // Cambiado: company_id
  const [status, setStatus] = useState<string>('invited');
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
      // Populate form with user data
      setUser_name(user.user_name || '');
      setUser_email((user as any).portal_user_email ?? user.user_email ?? '');
      setCompany_id((user as any).company_id || ''); // Cambiado: company_id
      setStatus((user as any).portal_user_status ?? user.status ?? 'invited');
      setSubmitError(null);
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
      // Ensure status is a valid DB value (only 'invited', 'active', 'disabled' allowed)
      const validStatuses = ['invited', 'active', 'disabled'];
      const finalStatus = validStatuses.includes(status.toLowerCase()) ? status.toLowerCase() : 'invited';

      // Validar que company_id existe (requerido en nuevo schema)
      if (!company_id) {
        setSubmitError('Company is required');
        setIsSubmitting(false);
        return;
      }

      // SOLO columnas explícitas: portal_user_email, portal_user_status, company_id
      const updatePayload = {
        company_id: company_id, // Cambiado: company_id (requerido, NO nullable)
        portal_user_email: trimmedEmail,
        portal_user_status: finalStatus,
        updated_at: new Date().toISOString(),
      };

      const { error: updateError } = await supabase
        .from('CompanyPortalUsers')
        .update(updatePayload)
        .eq('id', user.id)
        .eq('organization_id', organizationId);

      if (updateError) {
        const errorMsg = updateError.message || 'Failed to update portal user';
        throw new Error(`${errorMsg}. Payload: ${JSON.stringify(updatePayload)}`);
      }

      addNotification({
        type: 'success',
        title: 'Portal User Updated',
        message: 'The portal user has been updated successfully.',
      });

      onSuccess();
      onClose();
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

function InvitePortalUserModal({ isOpen, onClose, onSuccess, organizationId }: InvitePortalUserModalProps) {
  const { user: currentUser } = useAuthStore();
  const { addNotification } = useUIStore();
  
  // Form state
  const [email, setEmail] = useState<string>('');
  const [name, setName] = useState<string>('');
  const [company_id, setCompany_id] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Companies (NO DirectoryCustomers)
  const [companies, setCompanies] = useState<Array<{ id: string; company_name: string }>>([]);
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
      setEmail('');
      setName('');
      setCompany_id('');
      setSubmitError(null);
    }
  }, [isOpen, loadCompanies]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validate required fields
    const trimmedEmail = email.trim();
    const trimmedName = name.trim();
    
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
      setSubmitError('You must be logged in to invite users');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      // Validar que company_id existe (requerido en nuevo schema)
      if (!company_id) {
        setSubmitError('Company is required');
        setIsSubmitting(false);
        return;
      }

      // First, create or find CompanyPortalUser record
      let portalUserId: string;

      // Check if portal user already exists
      const { data: existingUser, error: checkError } = await supabase
        .from('CompanyPortalUsers')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('portal_user_email', trimmedEmail)
        .eq('deleted', false)
        .maybeSingle();

      if (checkError && checkError.code !== 'PGRST116') {
        throw new Error(`Failed to check existing user: ${checkError.message}`);
      }

      if (existingUser) {
        portalUserId = existingUser.id;
      } else {
        // Create new portal user record
        const { data: newUser, error: createError } = await supabase
          .from('CompanyPortalUsers')
          .insert({
            // SOLO columnas explícitas: portal_user_email, portal_user_status, company_id
            company_id: company_id,
            portal_user_email: trimmedEmail,
            portal_user_status: 'invited',
            invited_by_user_id: currentUser.id,
            deleted: false,
          })
          .select('id')
          .single();

        if (createError) {
          throw new Error(`Failed to create portal user: ${createError.message}`);
        }

        if (!newUser?.id) {
          throw new Error('Failed to create portal user: No ID returned');
        }

        portalUserId = newUser.id;
      }

      // Call Edge Function to send invite
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
          organization_id: organizationId,
          portal_user_id: portalUserId,
          email: trimmedEmail, // Edge Function espera 'email' en body
          name: trimmedName || null,
          redirect_to: redirectUrl,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to send invite');
      }

      addNotification({
        type: 'success',
        title: 'Invite Sent',
        message: 'Invitation email has been sent successfully.',
      });

      onSuccess();
      onClose();
    } catch (err: any) {
      const errorMessage = err.message || 'Error sending invite';
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
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Invite Portal User</h2>
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

          {/* Email */}
          <div>
            <Label htmlFor="invite_email">Email *</Label>
            <Input
              id="invite_email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={isSubmitting}
              placeholder="Enter user email"
            />
          </div>

          {/* Name */}
          <div>
            <Label htmlFor="invite_name">Name (Optional)</Label>
            <Input
              id="invite_name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={isSubmitting}
              placeholder="Enter user name"
            />
          </div>

          {/* Company Selection (Required) */}
          <div>
            <Label htmlFor="invite_company_id">Company *</Label>
            {loadingCompanies ? (
              <div className="text-sm text-gray-500 py-2">Loading companies...</div>
            ) : (
              <select
                id="invite_company_id"
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
              disabled={isSubmitting || !email.trim() || !company_id}
              className="px-4 py-2 text-sm font-medium text-white rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              {isSubmitting ? 'Sending...' : 'Send Invite'}
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
  const [isInviteOpen, setIsInviteOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<PortalUser | null>(null);
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
        .update({ portal_user_status: 'active' })
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
  const handleEdit = (user: PortalUser) => {
    setEditingUser(user);
    setIsEditOpen(true);
  };

  // Handle Delete action
  const handleDelete = async (user: PortalUser) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Delete Portal User',
      message: `Are you sure you want to delete "${user.user_name || ((user as any).portal_user_email ?? user.user_email)}"? This action cannot be undone.`,
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
  const handleArchive = async (user: PortalUser) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Archive Portal User',
      message: `Are you sure you want to archive "${user.user_name || ((user as any).portal_user_email ?? user.user_email)}"?`,
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
        .update({ portal_user_status: 'disabled', updated_at: new Date().toISOString() })
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
  const handleResendInvite = async (user: PortalUser) => {
    if (!activeOrganizationId || !((user as any).portal_user_email ?? user.user_email) || !currentUser) return;
    
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
          email: (user as any).portal_user_email ?? user.user_email ?? '',
          name: user.user_name || null,
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
            <>
              <button
                onClick={() => setIsInviteOpen(true)}
                className="flex items-center gap-2 px-3 py-1.5 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm"
              >
                <Send className="w-4 h-4" />
                Invite Portal User
              </button>
              <button
                onClick={() => setIsCreateOpen(true)}
                className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                <Plus className="w-4 h-4" />
                Add Portal User
              </button>
            </>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">User Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">User Email</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Contact Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Contact Email</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Contact Phone</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Created</th>
                <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 px-6 text-center">
                    <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-600 mb-2">No portal users found</p>
                    <p className="text-sm text-gray-500">
                      Portal users will appear here once they are created.
                    </p>
                  </td>
                </tr>
              ) : (
                users.map((user: CompanyPortalUser) => (
                  <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    {/* User Name (ALWAYS from user) */}
                    <td className="py-4 px-6 text-gray-900 text-sm">
                      {(user as { user_name?: string }).user_name ?? user.portal_user_name ?? '—'}
                    </td>
                    
                    {/* User Email (ALWAYS from user) */}
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {user.portal_user_email ?? (user as { user_email?: string }).user_email ?? '—'}
                    </td>
                    
                    {/* Contact Name (OPTIONAL - nullable) */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {(user as { contact_name?: string }).contact_name ?? '—'}
                    </td>
                    
                    {/* Contact Email (OPTIONAL - nullable) */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {user.contact_email ?? '—'}
                    </td>
                    
                    {/* Contact Phone (OPTIONAL - nullable) */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {user.contact_phone ?? '—'}
                    </td>
                    
                    {/* Status */}
                    <td className="py-4 px-6">
                      <StatusBadge status={(user as any).portal_user_status ?? user.status ?? 'unknown'} />
                    </td>
                    
                    {/* Created */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {user.created_at 
                        ? new Date(user.created_at).toLocaleDateString()
                        : '—'}
                    </td>
                    
                    {/* Actions */}
                    <td className="py-4 px-6">
                      <div className="flex items-center justify-end gap-2">
                        {/* Authorize button - show if status is 'invited' */}
                        {((user as any).portal_user_status ?? user.status ?? '') === 'invited' && (
                          <button
                            onClick={() => handleAuthorize(user.id)}
                            disabled={authorizingId === user.id}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Authorize user"
                          >
                            <CheckCircle className="w-4 h-4" />
                          </button>
                        )}
                        
                        {/* Resend Invite button - show if status is 'invited' */}
                        {((user as any).portal_user_status ?? user.status ?? '') === 'invited' && ((user as any).portal_user_email ?? user.user_email) && (
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => handleResendInvite(user as unknown as PortalUser)}
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
                          onClick={() => handleEdit(user as unknown as PortalUser)}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                          title="Edit user"
                        >
                          <Edit className="w-4 h-4" />
                        </button>

                        {/* Archive button */}
                        <button
                          onClick={() => handleArchive(user as unknown as PortalUser)}
                          disabled={archivingId === user.id || user.status === 'disabled'}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                          title="Archive user"
                        >
                          <Archive className="w-4 h-4" />
                        </button>

                        {/* Delete button */}
                        <button
                          onClick={() => handleDelete(user as unknown as PortalUser)}
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

      {/* Invite Modal */}
      {activeOrganizationId && (
        <InvitePortalUserModal
          isOpen={isInviteOpen}
          onClose={() => setIsInviteOpen(false)}
          onSuccess={() => {
            refetch();
            setIsInviteOpen(false);
          }}
          organizationId={activeOrganizationId}
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

