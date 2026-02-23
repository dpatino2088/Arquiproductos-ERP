import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  useDealerAppUsersForOrg,
  useAppUsersByDealer,
  type DealerAppUserWithDealer,
  roleCodeToPortalLabel,
  portalRoleToRoleCode,
  roleCodeToPortalRole,
} from '../../hooks/useAppUsersByDealer';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { fetchRolesByType, useRolesForUserType, type AppUserRole } from '../../lib/roles';
import { User, Mail, Phone, Shield, Plus, X, Send, CheckCircle, MoreVertical, Edit, Trash2, Archive, Copy, Check, Search, Filter, List, Grid3X3 } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { normalizeRole, getRoleLabel, getRoleDescription, type CompanyPortalRole } from '../../portal/portalAccess';

interface StatusBadgeProps {
  status: string;
}

function StatusBadge({ status }: StatusBadgeProps) {
  // Normalize legacy 'invited'/'draft' to 'active' for display
  // Dealer users only use 'active' or 'disabled'
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

  const colors = statusColors[normalizedStatus] ?? statusColors.disabled;

  return (
    <span className={`px-2 py-1 rounded text-xs font-medium capitalize ${colors.bg} ${colors.text} ${colors.border}`}>
      {colors.label}
    </span>
  );
}

interface CreateDealerUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
  /** When set (e.g. Dealer Manager on their dealer), dealer is fixed and selector is hidden. */
  singleDealerId?: string | null;
}

interface EditDealerUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
  user: DealerAppUserWithDealer | null;
}


function CreateDealerUserModal({ isOpen, onClose, onSuccess, organizationId, singleDealerId }: CreateDealerUserModalProps) {
  const { user } = useAuthStore();
  const { addNotification } = useUIStore();

  const { roles: dealerRoles, loading: loadingRoles } = useRolesForUserType('dealer');
  /** Only Dealer Manager and Dealer Member are valid for portal dealer users. */
  const portalDealerRoles = dealerRoles.filter(
    (r) => r.code === 'dealer_manager' || r.code === 'dealer_member'
  );

  // Form state
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [dealer_id, setDealer_id] = useState<string>('');
  const [role, setRole] = useState<string>('dealer_member');
  const [status, setStatus] = useState<string>('authorized');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Dealers (not used when singleDealerId is set)
  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);

  // Loading states
  const [loadingDealers, setLoadingDealers] = useState(false);

  const fixedDealer = singleDealerId ?? null;

  // Load dealers (de la organization actual) only when not fixed to one dealer
  const loadDealers = useCallback(async () => {
    if (!organizationId || fixedDealer) return;
    
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
  }, [organizationId, fixedDealer]);

  // Load data when modal opens
  useEffect(() => {
    if (isOpen) {
      loadDealers();
      setUser_name('');
      setUser_email('');
      setDealer_id(fixedDealer || '');
      setRole('dealer_member');
      setStatus('authorized');
      setSubmitError(null);
    }
  }, [isOpen, loadDealers, fixedDealer]);

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
      const effectiveDealerId = fixedDealer || dealer_id;
      if (!effectiveDealerId) {
        setSubmitError('Dealer is required');
        setIsSubmitting(false);
        return;
      }

      // ✅ Use create-temp-user (temporary password flow)
      const normalizedEmail = trimmedEmail.trim().toLowerCase();
      
      const portalRole = role;
      const { data, error: createError } = await supabase.functions.invoke('create-temp-user', {
        body: {
          kind: 'portal',
          organization_id: organizationId,
          dealer_id: effectiveDealerId,
          email: normalizedEmail,
          name: trimmedName || null,
          role: portalRole,
        },
      });

      const errStr =
        (typeof data?.error === 'string' && data.error) ||
        (typeof (createError as any)?.context === 'string' && (createError as any).context) ||
        (typeof createError?.message === 'string' && createError.message) ||
        (data?.ok === false ? 'Edge Function failed' : null);
      const realMessage = typeof errStr === 'string' ? errStr : 'Failed to create user';
      if (createError || !data?.ok) {
        if (import.meta.env.DEV) console.error('[CreateDealerUserModal] create-temp-user', { data, createError, realMessage });
        throw new Error(realMessage);
      }

      // ✅ Success message - mostrar password temporal si está disponible
      const emailSent = data?.email_sent === true;
      let message = emailSent 
        ? `Usuario creado. Se envió email con credenciales temporales a ${normalizedEmail}.`
        : `Usuario creado. Email no pudo enviarse (configura RESEND_API_KEY y FROM_EMAIL en Supabase).`;
      
      if (data?.temp_password) {
        message += `\n\n🔑 Contraseña temporal: ${data.temp_password}\n\nCopia esta contraseña y compártela con el usuario.`;
        console.log('[CreateDealerUserModal] Temp password:', data.temp_password);
      }

      if (data?.email_error) {
        console.warn('[CreateDealerUserModal] Email error:', data.email_error);
        message += `\n\n⚠️ Error de email: ${data.email_error}`;
      }

      addNotification({
        type: emailSent ? 'success' : 'warning',
        title: 'Usuario Creado',
        message,
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

          {/* Dealer Selection (hidden when singleDealerId = Dealer Manager's own dealer) */}
          {!fixedDealer && (
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
          )}

          {/* Role: only Dealer Manager and Dealer Member for portal dealer users */}
          <div>
            <Label htmlFor="role">Role *</Label>
            <select
              id="role"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              required
              disabled={isSubmitting || loadingRoles}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              {loadingRoles && <option value="">Loading roles…</option>}
              {!loadingRoles && portalDealerRoles.length === 0 && (
                <option value="">No roles configured for this user type</option>
              )}
              {!loadingRoles && portalDealerRoles.length > 0 && (
                <>
                  {!portalDealerRoles.some((r) => r.code === role) && role && (
                    <option value={role} disabled>Unknown role: {role}</option>
                  )}
                  {portalDealerRoles.map((r) => (
                    <option key={r.code} value={r.code}>{r.name}</option>
                  ))}
                </>
              )}
            </select>
            {!loadingRoles && portalDealerRoles.length === 0 && (
              <p className="text-xs text-amber-600 mt-1">No roles configured for this user type. Configure roles in Settings → Roles.</p>
            )}
            {portalDealerRoles.length > 0 && (
              <p className="text-xs text-gray-500 mt-1">{getRoleDescription(role as CompanyPortalRole)}</p>
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
              <option value="active">Active</option>
              <option value="disabled">Disabled</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Active: User can access. Disabled: Access blocked.
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
              disabled={isSubmitting || !user_name.trim() || !user_email.trim() || portalDealerRoles.length === 0}
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

function EditDealerUserModal({ isOpen, onClose, onSuccess, organizationId, user }: EditDealerUserModalProps) {
  const { user: currentUser } = useAuthStore();
  const { addNotification } = useUIStore();

  const { roles: dealerRoles, loading: loadingRoles } = useRolesForUserType('dealer');
  /** Only Dealer Manager and Dealer Member are valid for portal dealer users. */
  const portalDealerRoles = dealerRoles.filter(
    (r) => r.code === 'dealer_manager' || r.code === 'dealer_member'
  );

  // Form state
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [dealer_id, setDealer_id] = useState<string>('');
  const [role, setRole] = useState<string>('dealer_member');
  const [status, setStatus] = useState<string>('active');
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

  // Load data when modal opens or user changes (AppUsers: display_name, email, role_code, status)
  useEffect(() => {
    if (isOpen && user) {
      loadDealers();
      setUser_name(user.display_name || '');
      setUser_email(user.email || '');
      setDealer_id(user.dealer_id || '');
      const rc = (user.role_code ?? '').toLowerCase();
      setRole(rc === 'dealer_manager' || rc === 'member_manager' || rc === 'manager' ? 'dealer_manager' : 'dealer_member');
      const st = (user.status ?? 'active').toLowerCase();
      setStatus(st === 'disabled' ? 'disabled' : st === 'invited' ? 'active' : st);
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
      // Dealer users only use 'active' or 'disabled'
      const normalizedStatus = (status || '').toLowerCase().trim();
      const validStatuses = ['active', 'disabled'];
      const finalStatus = validStatuses.includes(normalizedStatus) ? normalizedStatus : 'active';

      // Validar que dealer_id existe (requerido en nuevo schema)
      if (!dealer_id) {
        setSubmitError('Dealer is required');
        setIsSubmitting(false);
        return;
      }

      const finalRoleCode = (role?.trim() === 'dealer_manager' ? 'dealer_manager' : 'dealer_member') as string;

      const { error: updateError } = await supabase
        .from('AppUsers')
        .update({
          display_name: trimmedName || null,
          email: trimmedEmail,
          dealer_id,
          role_code: finalRoleCode,
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

      // Close modal first
      onClose();
      
      // Immediately refresh the list to show updated data
      // The verification above should have confirmed the update worked
      onSuccess();
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

          {/* Company Selection (Required) */}
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

          {/* Role: only Dealer Manager and Dealer Member for portal dealer users */}
          <div>
            <Label htmlFor="edit_role">Role *</Label>
            <select
              id="edit_role"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              required
              disabled={isSubmitting || loadingRoles}
              className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
            >
              {loadingRoles && <option value="">Loading roles…</option>}
              {!loadingRoles && portalDealerRoles.length === 0 && (
                <option value="">No roles configured for this user type</option>
              )}
              {!loadingRoles && portalDealerRoles.length > 0 && (
                <>
                  {!portalDealerRoles.some((r) => r.code === role) && role && (
                    <option value={role} disabled>Unknown role: {role}</option>
                  )}
                  {portalDealerRoles.map((r) => (
                    <option key={r.code} value={r.code}>{r.name}</option>
                  ))}
                </>
              )}
            </select>
            {!loadingRoles && portalDealerRoles.length === 0 && (
              <p className="text-xs text-amber-600 mt-1">No roles configured for this user type.</p>
            )}
            {portalDealerRoles.length > 0 && (
              <p className="text-xs text-gray-500 mt-1">{getRoleDescription(role as CompanyPortalRole)}</p>
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

export default function DealerUsers() {
  const { activeOrganizationId, activeOrganization } = useOrganizationContext();
  const { userType, portalDealerId, portalRole } = useAccessContext();
  const isPortalManager = userType === 'portal' && portalRole === 'dealer_manager';
  const isPortal = userType === 'portal';

  const orgUsers = useDealerAppUsersForOrg(isPortal ? null : activeOrganizationId);
  const dealerOnlyUsers = useAppUsersByDealer(isPortal ? portalDealerId ?? undefined : undefined, { onlyWhenDealerId: true });

  const users: DealerAppUserWithDealer[] = useMemo(() => {
    if (!isPortal) return orgUsers.users;
    const dealerName = activeOrganization?.name ?? null;
    return dealerOnlyUsers.users.map((u) => ({ ...u, dealer_name: dealerName }));
  }, [isPortal, orgUsers.users, dealerOnlyUsers.users, activeOrganization?.name]);

  const loading = isPortal ? dealerOnlyUsers.isLoading : orgUsers.isLoading;
  const error = isPortal ? dealerOnlyUsers.error : orgUsers.error;
  const refetch = isPortal ? dealerOnlyUsers.refetch : orgUsers.refetch;

  const { user: currentUser } = useAuthStore();
  const { addNotification, setGlobalLoading } = useUIStore();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<DealerAppUserWithDealer | null>(null);
  const [authorizingId, setAuthorizingId] = useState<string | null>(null);
  const [invitingId, setInvitingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [inviteLink, setInviteLink] = useState<string | null>(null);
  const [copiedLinkId, setCopiedLinkId] = useState<string | null>(null);

  const filteredUsers = useMemo(() => {
    if (!searchTerm) return users;
    const search = searchTerm.toLowerCase();
    return users.filter(user =>
      (user.display_name?.toLowerCase() || '').includes(search) ||
      (user.email?.toLowerCase() || '').includes(search) ||
      (user.dealer_name?.toLowerCase() || '').includes(search)
    );
  }, [users, searchTerm]);

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

  const handleArchive = async (user: DealerAppUserWithDealer) => {
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Archive Dealer User',
      message: `Are you sure you want to archive "${user.display_name || user.email || 'this user'}"? The user will be disabled and can be restored later.`,
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
      addNotification({ type: 'success', title: 'User Archived', message: 'Dealer user has been archived successfully.' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to archive user' });
    } finally {
      setArchivingId(null);
      setLoading(false);
    }
  };

  const handleDelete = async (user: DealerAppUserWithDealer) => {
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Delete Dealer User',
      message: `Are you sure you want to permanently delete "${user.display_name || user.email || 'this user'}"? This will also remove the user from authentication so the email can be re-invited. This action cannot be undone.`,
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
          console.warn('[DealerUsers] Auth delete failed:', fnData?.error);
        }
      }

      addNotification({ type: 'success', title: 'User Deleted', message: 'Dealer user has been deleted successfully.' });
      refetch();
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Delete Error', message: err.message || 'Failed to delete user' });
    } finally {
      setDeletingId(null);
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

  if (loading) return <div className="py-6 px-6" />;

  // Show error state
  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading dealer users</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  if (isPortal && !portalDealerId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No dealer associated</p>
          <p className="text-sm text-yellow-700 mt-1">Your user is not linked to a dealer. Contact your administrator.</p>
        </div>
      </div>
    );
  }

  if (!isPortal && !activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to view dealer users.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Dealer Users</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage dealer user access and permissions ({filteredUsers.length} total)
          </p>
        </div>
        <div className="flex items-center gap-3">
          {(activeOrganizationId || (isPortal && portalDealerId)) && (isPortalManager || !isPortal) && (
            <button
              onClick={() => setIsCreateOpen(true)}
              className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus className="w-4 h-4" />
              Add Dealer User
            </button>
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
                placeholder="Search dealer users by name, email, company..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search dealer users"
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

        {/* Advanced Filters (placeholder for future) */}
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <p className="text-sm text-gray-500">Additional filters will be available here.</p>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="table-fit-wrapper">
          <table className="table-fit">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Dealer</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Email</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Role</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Date Added</th>
                <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 px-6 text-center">
                  <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-600 mb-2">No dealer users found</p>
                  <p className="text-sm text-gray-500">
                    {searchTerm ? 'No users match your search criteria.' : 'Dealer users will appear here once they are created.'}
                  </p>
                </td>
              </tr>
            ) : (
              filteredUsers.map((user: DealerAppUserWithDealer) => (
                  <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer">
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                          <User className="w-4 h-4 text-gray-600" />
                        </div>
                        <span className="font-medium text-gray-900 truncate">
                          {user.display_name || 'No name'}
                        </span>
                      </div>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {user.dealer_name || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {user.email || '-'}
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      {(() => {
                        const role = roleCodeToPortalRole(user.role_code);
                        const roleColors: Record<string, { bg: string; text: string; border: string }> = {
                          dealer_manager: { bg: 'bg-purple-50', text: 'text-purple-700', border: 'border border-purple-200' },
                          dealer_member: { bg: 'bg-blue-50', text: 'text-blue-700', border: 'border border-blue-200' },
                        };
                        const colors = roleColors[role] ?? roleColors.dealer_member;
                        return (
                          <span className={`px-2 py-1 rounded text-xs font-medium ${colors.bg} ${colors.text} ${colors.border}`}>
                            {getRoleLabel(role)}
                          </span>
                        );
                      })()}
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={user.status ?? 'disabled'} />
                    </td>
                    
                    {/* Date Added */}
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {user.created_at 
                        ? new Date(user.created_at).toLocaleDateString()
                        : '-'}
                    </td>
                    
                    {/* Actions - only Dealer Manager (portal) or internal users can manage */}
                    <td className="py-4 px-6">
                      <div className="flex items-center justify-end gap-2">
                        {(isPortalManager || !isPortal) && user.status === 'invited' && (
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
                        
                        {(isPortalManager || !isPortal) && user.status === 'invited' && user.email && (
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

                        {/* Edit / Archive / Delete - only for Manager (portal) or internal */}
                        {(isPortalManager || !isPortal) && (
                          <>
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
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleArchive(user);
                              }}
                              disabled={archivingId === user.id || user.status === 'disabled'}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title="Archive user (disable)"
                            >
                              <Archive className="w-4 h-4" />
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDelete(user);
                              }}
                              disabled={deletingId === user.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600 disabled:opacity-50"
                              title="Delete user (soft)"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </>
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

      {/* Create Modal - org required; for portal Manager singleDealerId fixes dealer */}
      {(activeOrganizationId || (isPortal && portalDealerId)) && (
        <CreateDealerUserModal
          isOpen={isCreateOpen}
          onClose={() => setIsCreateOpen(false)}
          onSuccess={() => refetch()}
          organizationId={activeOrganizationId ?? ''}
          singleDealerId={isPortalManager ? portalDealerId : undefined}
        />
      )}

      {/* Edit Modal */}
      {(activeOrganizationId || (isPortal && portalDealerId)) && editingUser && (
        <EditDealerUserModal
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
          organizationId={activeOrganizationId ?? ''}
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
