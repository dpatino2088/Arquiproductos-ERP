/**
 * @deprecated Esta página no está montada en el router. La ruta /settings/dealer-users
 * (y /settings/company-portal-users) cargan DealerUsers.tsx. No usar "CustomerPortalUser(s)";
 * el modelo correcto es AppUsers + DealerUsers con dealer_id. Ver md/docs/DEALER_PROFILE_APPUSERS_MIGRATION.md
 */
import React, { useState, useEffect, useCallback } from 'react';
import { useDealerAppUsersForOrg, type DealerAppUserWithDealer, roleCodeToPortalRole } from '../../hooks/useAppUsersByDealer';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import { usePermissions } from '../../hooks/usePermissions';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { User, Mail, Phone, Shield, Plus, X, Send, CheckCircle, MoreVertical, Edit, Trash2, Archive, Copy, Check } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';

interface PortalUser {
  id: string;
  user_id: string | null;
  user_name: string | null;
  user_email: string | null;
  dealer_id: string | null;
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
  user: DealerAppUserWithDealer | null;
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
  const [dealer_id, setDealer_id] = useState<string>(''); // Cambiado: dealer_id en lugar de customer_id
  const [status, setStatus] = useState<string>('authorized');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Dealers
  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);
  
  // Loading states
  const [loadingDealers, setLoadingDealers] = useState(false);

  // Load dealers (de la organization actual)
  const loadDealers = useCallback(async () => {
    if (!organizationId) return;
    
    setLoadingDealers(true);
    try {
      const { data, error } = await supabase
        .from('Dealers')
        .select('id, dealer_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('dealer_name', { ascending: true });

      if (error) {
        console.error('Error loading dealers:', error);
        setDealers([]);
      } else {
        setDealers(data || []);
      }
    } catch (err) {
      console.error('Error loading dealers:', err);
      setDealers([]);
    } finally {
      setLoadingDealers(false);
    }
  }, [organizationId]);

  // Load data when modal opens
  useEffect(() => {
    if (isOpen) {
      loadDealers();
      // Reset form
      setUser_name('');
      setUser_email('');
      setDealer_id(''); // Cambiado: dealer_id
      setStatus('authorized');
      setSubmitError(null);
    }
  }, [isOpen, loadDealers]);

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
      setSubmitError('You must be logged in to create dealer users');
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

      // Validar que dealer_id existe (requerido en nuevo schema)
      if (!dealer_id) {
        setSubmitError('Dealer is required');
        setIsSubmitting(false);
        return;
      }

      const { data: createData, error: createError } = await supabase.functions.invoke('create-temp-user', {
        body: {
          kind: 'portal',
          organization_id: organizationId,
          dealer_id,
          email: trimmedEmail,
          name: trimmedName || null,
          role: 'member',
          status: finalStatus,
        },
      });

      const errStr =
        (typeof createData?.error === 'string' && createData.error) ||
        (typeof (createError as any)?.context === 'string' && (createError as any).context) ||
        (typeof createError?.message === 'string' && createError.message) ||
        (createData?.ok === false ? 'Edge Function failed' : null);
      const realMessage = typeof errStr === 'string' ? errStr : 'Failed to create dealer user';
      if (createError || !createData?.ok) {
        if (import.meta.env.DEV) console.error('[CreatePortalUserModal] create-temp-user', { createData, createError, realMessage });
        throw new Error(realMessage);
      }

      addNotification({
        type: 'success',
        title: 'Dealer User Created',
        message: 'The dealer user has been created successfully.',
      });

      onSuccess();
      onClose();
    } catch (err: any) {
      const errorMessage = err.message || 'Error creating dealer user';
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
          <h2 className="text-xl font-semibold text-gray-900">Add Dealer User</h2>
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
            <Label htmlFor="dealer_id">Dealer *</Label>
            {loadingDealers ? (
              <div className="text-sm text-gray-500 py-2">Loading dealers...</div>
            ) : (
              <select
                id="dealer_id"
                value={dealer_id}
                onChange={(e) => {
                  setDealer_id(e.target.value);
                }}
                required
                disabled={isSubmitting}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
              >
                <option value="">Select a dealer</option>
                {dealers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.dealer_name}
                  </option>
                ))}
              </select>
            )}
            {dealers.length === 0 && !loadingDealers && (
              <p className="text-xs text-gray-500 mt-1">No dealers available. Create a dealer first.</p>
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
              {isSubmitting ? 'Creating...' : 'Create Dealer User'}
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
  const [dealer_id, setDealer_id] = useState<string>(''); // Cambiado: dealer_id
  const [status, setStatus] = useState<string>('invited');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Dealers
  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);
  
  // Loading states
  const [loadingDealers, setLoadingDealers] = useState(false);

  // Load dealers (de la organization actual)
  const loadDealers = useCallback(async () => {
    if (!organizationId) return;
    
    setLoadingDealers(true);
    try {
      const { data, error } = await supabase
        .from('Dealers')
        .select('id, dealer_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('dealer_name', { ascending: true });

      if (error) {
        console.error('Error loading dealers:', error);
        setDealers([]);
      } else {
        setDealers(data || []);
      }
    } catch (err) {
      console.error('Error loading dealers:', err);
      setDealers([]);
    } finally {
      setLoadingDealers(false);
    }
  }, [organizationId]);

  useEffect(() => {
    if (isOpen && user) {
      loadDealers();
      setUser_name(user.display_name || '');
      setUser_email(user.email || '');
      setDealer_id(user.dealer_id || '');
      setStatus(user.status ?? 'invited');
      setSubmitError(null);
    }
  }, [isOpen, user, loadDealers]);

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
      setSubmitError('You must be logged in to edit dealer users');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      // Ensure status is a valid DB value (only 'invited', 'active', 'disabled' allowed)
      const validStatuses = ['invited', 'active', 'disabled'];
      const finalStatus = validStatuses.includes(status.toLowerCase()) ? status.toLowerCase() : 'invited';

      // Validar que dealer_id existe (requerido en nuevo schema)
      if (!dealer_id) {
        setSubmitError('Dealer is required');
        setIsSubmitting(false);
        return;
      }

      const { error: updateError } = await supabase
        .from('AppUsers')
        .update({
          display_name: trimmedName || null,
          email: trimmedEmail,
          dealer_id,
          status: finalStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id)
        .eq('organization_id', organizationId)
        .eq('user_type', 'dealer');

      if (updateError) {
        throw new Error(updateError.message || 'Failed to update dealer user');
      }

      addNotification({
        type: 'success',
        title: 'Dealer User Updated',
        message: 'The dealer user has been updated successfully.',
      });

      onSuccess();
      onClose();
    } catch (err: any) {
      const errorMessage = err.message || 'Error updating dealer user';
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
          <h2 className="text-xl font-semibold text-gray-900">Edit Dealer User</h2>
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

          {/* Dealer Selection (Required) */}
          <div>
            <Label htmlFor="edit_dealer_id">Dealer *</Label>
            {loadingDealers ? (
              <div className="text-sm text-gray-500 py-2">Loading dealers...</div>
            ) : (
              <select
                id="edit_dealer_id"
                value={dealer_id}
                onChange={(e) => setDealer_id(e.target.value)}
                required
                disabled={isSubmitting}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
              >
                <option value="">Select a dealer</option>
                {dealers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.dealer_name}
                  </option>
                ))}
              </select>
            )}
            {dealers.length === 0 && !loadingDealers && (
              <p className="text-xs text-gray-500 mt-1">No dealers available. Create a dealer first.</p>
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
              {isSubmitting ? 'Updating...' : 'Update Dealer User'}
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
  const [dealer_id, setDealer_id] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Dealers
  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);
  const [loadingDealers, setLoadingDealers] = useState(false);

  // Load dealers (de la organization actual)
  const loadDealers = useCallback(async () => {
    if (!organizationId) return;
    
    setLoadingDealers(true);
    try {
      const { data, error } = await supabase
        .from('Dealers')
        .select('id, dealer_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('dealer_name', { ascending: true });

      if (error) {
        console.error('Error loading dealers:', error);
        setDealers([]);
      } else {
        setDealers(data || []);
      }
    } catch (err) {
      console.error('Error loading dealers:', err);
      setDealers([]);
    } finally {
      setLoadingDealers(false);
    }
  }, [organizationId]);

  // Load data when modal opens
  useEffect(() => {
    if (isOpen) {
      loadDealers();
      // Reset form
      setEmail('');
      setName('');
      setDealer_id('');
      setSubmitError(null);
    }
  }, [isOpen, loadDealers]);

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
      // Validar que dealer_id existe (requerido en nuevo schema)
      if (!dealer_id) {
        setSubmitError('Dealer is required');
        setIsSubmitting(false);
        return;
      }

      let portalUserId: string;

      const { data: existingAppUser, error: checkError } = await supabase
        .from('AppUsers')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('user_type', 'dealer')
        .eq('email', trimmedEmail)
        .eq('deleted', false)
        .maybeSingle();

      if (checkError) {
        throw new Error(`Failed to check existing user: ${checkError.message}`);
      }

      if (existingAppUser?.id) {
        portalUserId = existingAppUser.id;
      } else {
        const { data: createData, error: createError } = await supabase.functions.invoke('create-temp-user', {
          body: {
            kind: 'portal',
            organization_id: organizationId,
            dealer_id,
            email: trimmedEmail,
            name: trimmedName || null,
            role: 'member',
            status: 'invited',
          },
        });
        const errStr =
          (typeof createData?.error === 'string' && createData.error) ||
          (typeof (createError as any)?.context === 'string' && (createError as any).context) ||
          (typeof createError?.message === 'string' && createError.message) ||
          (createData?.ok === false ? 'Edge Function failed' : null);
        const realMsg = typeof errStr === 'string' ? errStr : 'Failed to create dealer user';
        if (createError || !createData?.ok) {
          if (import.meta.env.DEV) console.error('[InvitePortalUserModal] create-temp-user', { createData, createError, realMsg });
          throw new Error(realMsg);
        }
        const { data: newAppUser } = await supabase
          .from('AppUsers')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('user_type', 'dealer')
          .eq('email', trimmedEmail)
          .eq('deleted', false)
          .maybeSingle();
        if (!newAppUser?.id) {
          throw new Error('User was created but could not be found. Please refresh and try again.');
        }
        portalUserId = newAppUser.id;
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
          dealer_id,
          portal_user_email: trimmedEmail,
          portal_user_name: trimmedName || null,
          role: 'member',
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
          <h2 className="text-xl font-semibold text-gray-900">Invite Dealer User</h2>
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

          {/* Dealer Selection (Required) */}
          <div>
            <Label htmlFor="invite_dealer_id">Dealer *</Label>
            {loadingDealers ? (
              <div className="text-sm text-gray-500 py-2">Loading dealers...</div>
            ) : (
              <select
                id="invite_dealer_id"
                value={dealer_id}
                onChange={(e) => setDealer_id(e.target.value)}
                required
                disabled={isSubmitting}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
              >
                <option value="">Select a dealer</option>
                {dealers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.dealer_name}
                  </option>
                ))}
              </select>
            )}
            {dealers.length === 0 && !loadingDealers && (
              <p className="text-xs text-gray-500 mt-1">No dealers available. Create a dealer first.</p>
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
              disabled={isSubmitting || !email.trim() || !dealer_id}
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

export default function DealerUsers() {
  const { activeOrganizationId } = useOrganizationContext();
  const { users, isLoading: loading, error, refetch } = useDealerAppUsersForOrg(activeOrganizationId);
  const { user: currentUser } = useAuthStore();
  const { addNotification, setGlobalLoading } = useUIStore();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const { can } = usePermissions();

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [isInviteOpen, setIsInviteOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<DealerAppUserWithDealer | null>(null);
  const [authorizingId, setAuthorizingId] = useState<string | null>(null);
  const [invitingId, setInvitingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [inviteLink, setInviteLink] = useState<string | null>(null);
  const [copiedLinkId, setCopiedLinkId] = useState<string | null>(null);

  const handleAuthorize = async (userId: string) => {
    if (!activeOrganizationId) return;
    try {
      setAuthorizingId(userId);
      const { error } = await supabase
        .from('AppUsers')
        .update({ status: 'active' })
        .eq('id', userId)
        .eq('organization_id', activeOrganizationId)
        .eq('user_type', 'dealer');
      if (error) throw error;
      addNotification({ type: 'success', title: 'User Authorized', message: 'Dealer user has been authorized successfully.' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to authorize user' });
    } finally {
      setAuthorizingId(null);
    }
  };

  const handleEdit = (user: DealerAppUserWithDealer) => {
    setEditingUser(user);
    setIsEditOpen(true);
  };

  const handleDelete = async (user: DealerAppUserWithDealer) => {
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Delete Dealer User',
      message: `Are you sure you want to delete "${user.display_name || user.email}"? This will also remove the user from authentication so the email can be re-invited. This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    setDeletingId(user.id);
    setLoading(true);
    try {
      const duQuery = supabase
        .from('DealerUsers')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', user.dealer_id);
      const { error: duErr } = user.auth_user_id
        ? await duQuery.eq('user_id', user.auth_user_id)
        : await duQuery.ilike('portal_user_email', user.email);
      if (duErr) throw duErr;

      if (user.auth_user_id) {
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
          body: JSON.stringify({ auth_user_id: user.auth_user_id }),
        });
        const fnData = await res.json().catch(() => ({}));
        if (!res.ok || !fnData?.ok) {
          console.warn('[CustomerPortalUsers] Auth delete failed:', fnData?.error);
        }
      }

      addNotification({
        type: 'success',
        title: 'User Deleted',
        message: 'Dealer user has been deleted successfully.',
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

  const handleArchive = async (user: DealerAppUserWithDealer) => {
    if (!activeOrganizationId) return;

    const confirmed = await showConfirm({
      title: 'Archive Dealer User',
      message: `Are you sure you want to archive "${user.display_name ?? user.email}"?`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    setArchivingId(user.id);
    setLoading(true);

    try {
      const { error } = await supabase
        .from('AppUsers')
        .update({ status: 'disabled', updated_at: new Date().toISOString() })
        .eq('id', user.id)
        .eq('organization_id', activeOrganizationId)
        .eq('user_type', 'dealer');
      if (error) throw error;

      addNotification({
        type: 'success',
        title: 'User Archived',
        message: 'Dealer user has been archived successfully.',
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

  const handleResendInvite = async (user: DealerAppUserWithDealer) => {
    if (!activeOrganizationId || !user.email || !user.dealer_id || !currentUser) return;
    setInvitingId(user.id);
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) throw new Error('VITE_SUPABASE_URL is not configured');
      const { data: session } = await supabase.auth.getSession();
      if (!session?.session) throw new Error('You must be logged in to send invites');
      const functionUrl = `${supabaseUrl}/functions/v1/send-customer-portal-invite`;
      const redirectUrl = `${window.location.origin}/auth/callback`;
      const portalRole = roleCodeToPortalRole(user.role_code);
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({
          organization_id: activeOrganizationId,
          dealer_id: user.dealer_id,
          portal_user_email: user.email,
          portal_user_name: user.display_name || null,
          role: portalRole,
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

  if (loading) return <div className="p-6" />;

  // Show error state
  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading dealer users</p>
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
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to view dealer users.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Dealer Users</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage dealer user access and permissions
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
                Invite Dealer User
              </button>
              <button
                onClick={() => setIsCreateOpen(true)}
                className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                <Plus className="w-4 h-4" />
                Add Dealer User
              </button>
            </>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="table-fit-wrapper">
          <table className="table-fit">
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
                    <p className="text-gray-600 mb-2">No dealer users found</p>
                    <p className="text-sm text-gray-500">
                      Dealer users will appear here once they are created.
                    </p>
                  </td>
                </tr>
              ) : (
                users.map((user: DealerAppUserWithDealer) => (
                  <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    <td className="py-4 px-6 text-gray-900 text-sm">
                      {user.display_name ?? '—'}
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {user.email ?? '—'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm">—</td>
                    <td className="py-4 px-6 text-gray-600 text-sm">—</td>
                    
                    <td className="py-4 px-6 text-gray-600 text-sm">—</td>
                    <td className="py-4 px-6">
                      <StatusBadge status={user.status ?? 'unknown'} />
                    </td>
                    
                    {/* Created */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {user.created_at 
                        ? formatDate(user.created_at)
                        : '—'}
                    </td>
                    
                    {/* Actions */}
                    <td className="py-4 px-6">
                      <div className="flex items-center justify-end gap-2">
                        {user.status === 'invited' && (
                          <button
                            onClick={() => handleAuthorize(user.id)}
                            disabled={authorizingId === user.id}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Authorize user"
                          >
                            <CheckCircle className="w-4 h-4" />
                          </button>
                        )}
                        
                        {user.status === 'invited' && user.email && (
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

                        <button
                          onClick={() => handleEdit(user)}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                          title="Edit user"
                        >
                          <Edit className="w-4 h-4" />
                        </button>

                        {can('org.users.manage') && (
                          <button
                            onClick={() => handleArchive(user)}
                            disabled={archivingId === user.id || user.status === 'disabled'}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Archive user"
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                        )}

                        {can('org.users.manage') && (
                          <button
                            onClick={() => handleDelete(user)}
                            disabled={deletingId === user.id}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600 disabled:opacity-50"
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

      {/* Summary */}
      {users.length > 0 && (
        <div className="mt-4 text-sm text-gray-600">
          Showing {users.length} dealer user{users.length !== 1 ? 's' : ''}
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

