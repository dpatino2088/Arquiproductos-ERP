import React, { useState, useEffect, useCallback, useMemo, useImperativeHandle, forwardRef } from 'react';
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
import { usePermissions } from '../../hooks/usePermissions';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { fetchRolesByType, useRolesForUserType, type AppUserRole } from '../../lib/roles';
import { User, Mail, Phone, Shield, Plus, X, Send, CheckCircle, MoreVertical, Edit, Trash2, Archive, Copy, Check, Search, Filter, List, Grid3X3, Building2 } from 'lucide-react';
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

/** One user account (grouped by auth user / email) with all its dealer memberships. */
export interface GroupedDealerUser {
  key: string;
  /** Oldest membership row — carries the account-level name/email/status shown in the list. */
  primary: DealerAppUserWithDealer;
  /** One row per dealer the user can access, oldest first. */
  memberships: DealerAppUserWithDealer[];
}

interface EditDealerUserModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  organizationId: string;
  user: GroupedDealerUser | null;
  /** Internal users can add/remove dealer access; portal managers only edit role at their dealer. */
  allowDealerManagement: boolean;
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

type MembershipEdit = {
  /** AppUsers row id (existing membership) or null when the dealer is being added. */
  rowId: string | null;
  dealerId: string;
  dealerName: string;
  role: string;
  removed: boolean;
};

function EditDealerUserModal({ isOpen, onClose, onSuccess, organizationId, user, allowDealerManagement }: EditDealerUserModalProps) {
  const { user: currentUser } = useAuthStore();
  const { addNotification } = useUIStore();

  const { roles: dealerRoles, loading: loadingRoles } = useRolesForUserType('dealer');
  /** Only Dealer Manager and Dealer Member are valid for portal dealer users. */
  const portalDealerRoles = dealerRoles.filter(
    (r) => r.code === 'dealer_manager' || r.code === 'dealer_member'
  );

  // Account-level fields (shared across all memberships of this account)
  const [user_name, setUser_name] = useState<string>('');
  const [user_email, setUser_email] = useState<string>('');
  const [status, setStatus] = useState<string>('active');
  // One entry per dealer the user can access (role can differ per dealer)
  const [membershipEdits, setMembershipEdits] = useState<MembershipEdit[]>([]);
  const [addDealerId, setAddDealerId] = useState('');
  const [addRole, setAddRole] = useState('dealer_member');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Dropdown data: Dealers (for adding access; internal users only)
  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);
  const [loadingDealers, setLoadingDealers] = useState(false);

  const loadDealers = useCallback(async () => {
    if (!organizationId || !allowDealerManagement) return;
    setLoadingDealers(true);
    try {
      const { data, error } = await supabase
        .from('Dealers')
        .select('id, dealer_name')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('dealer_name', { ascending: true });
      setDealers(error ? [] : data || []);
    } catch {
      setDealers([]);
    } finally {
      setLoadingDealers(false);
    }
  }, [organizationId, allowDealerManagement]);

  useEffect(() => {
    if (isOpen && user) {
      loadDealers();
      setUser_name(user.primary.display_name || '');
      setUser_email(user.primary.email || '');
      const st = (user.primary.status ?? 'active').toLowerCase();
      setStatus(st === 'disabled' ? 'disabled' : st === 'invited' ? 'active' : st);
      setMembershipEdits(
        user.memberships.map((m) => ({
          rowId: m.id,
          dealerId: m.dealer_id,
          dealerName: m.dealer_name || '-',
          role: (m.role_code ?? '').toLowerCase() === 'dealer_manager' ? 'dealer_manager' : 'dealer_member',
          removed: false,
        }))
      );
      setAddDealerId('');
      setAddRole('dealer_member');
      setSubmitError(null);
    }
  }, [isOpen, user, loadDealers]);

  const activeEdits = membershipEdits.filter((m) => !m.removed);
  const availableDealers = dealers.filter(
    (d) => !membershipEdits.some((m) => !m.removed && m.dealerId === d.id)
  );

  const handleAddDealer = () => {
    if (!addDealerId) return;
    const dealer = dealers.find((d) => d.id === addDealerId);
    if (!dealer) return;
    // Re-adding a dealer that was just marked removed simply un-removes it.
    const existing = membershipEdits.find((m) => m.dealerId === addDealerId);
    if (existing) {
      setMembershipEdits((prev) =>
        prev.map((m) => (m.dealerId === addDealerId ? { ...m, removed: false, role: addRole } : m))
      );
    } else {
      setMembershipEdits((prev) => [
        ...prev,
        { rowId: null, dealerId: addDealerId, dealerName: dealer.dealer_name, role: addRole, removed: false },
      ]);
    }
    setAddDealerId('');
    setAddRole('dealer_member');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    const trimmedName = user_name.trim();
    const trimmedEmail = user_email.trim();
    if (!trimmedName) { setSubmitError('Name is required'); return; }
    if (!trimmedEmail) { setSubmitError('Email is required'); return; }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) { setSubmitError('Please enter a valid email address'); return; }
    if (!currentUser?.id) { setSubmitError('You must be logged in to edit dealer users'); return; }
    if (activeEdits.length === 0) { setSubmitError('The user must keep access to at least one dealer'); return; }

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      // Dealer users only use 'active' or 'disabled'
      const normalizedStatus = (status || '').toLowerCase().trim();
      const finalStatus = ['active', 'disabled'].includes(normalizedStatus) ? normalizedStatus : 'active';
      const now = new Date().toISOString();
      const existingIds = user.memberships.map((m) => m.id);

      // 1) Account-level fields on every membership row of this account.
      if (existingIds.length > 0) {
        const { error: accErr } = await supabase
          .from('AppUsers')
          .update({ display_name: trimmedName || null, email: trimmedEmail, status: finalStatus, updated_at: now })
          .in('id', existingIds)
          .eq('organization_id', organizationId)
          .eq('user_type', 'dealer');
        if (accErr) throw new Error(accErr.message);
      }

      // 2) Per-dealer role changes.
      for (const m of membershipEdits) {
        if (!m.rowId || m.removed) continue;
        const original = user.memberships.find((x) => x.id === m.rowId);
        const originalRole =
          (original?.role_code ?? '').toLowerCase() === 'dealer_manager' ? 'dealer_manager' : 'dealer_member';
        if (originalRole !== m.role) {
          const { error: roleErr } = await supabase
            .from('AppUsers')
            .update({ role_code: m.role, updated_at: now })
            .eq('id', m.rowId)
            .eq('organization_id', organizationId);
          if (roleErr) throw new Error(roleErr.message);
        }
      }

      // 3) Removed dealers -> soft delete those membership rows.
      const removedIds = membershipEdits.filter((m) => m.removed && m.rowId).map((m) => m.rowId as string);
      if (removedIds.length > 0) {
        const { error: delErr } = await supabase
          .from('AppUsers')
          .update({ deleted: true, updated_at: now })
          .in('id', removedIds)
          .eq('organization_id', organizationId);
        if (delErr) throw new Error(delErr.message);
      }

      // 4) Added dealers -> new membership rows (same account, different dealer).
      const additions = membershipEdits.filter((m) => !m.rowId && !m.removed);
      if (additions.length > 0) {
        const { error: insErr } = await supabase.from('AppUsers').insert(
          additions.map((m) => ({
            organization_id: organizationId,
            user_type: 'dealer',
            dealer_id: m.dealerId,
            auth_user_id: user.primary.auth_user_id ?? null,
            email: trimmedEmail,
            display_name: trimmedName || null,
            role_code: m.role,
            status: finalStatus,
            deleted: false,
          }))
        );
        if (insErr) throw new Error(insErr.message);
      }

      addNotification({
        type: 'success',
        title: 'Dealer User Updated',
        message: 'The dealer user has been updated successfully.',
      });
      onClose();
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

          {/* Dealer access — one entry per dealer the user can work in, each with its own role */}
          <div>
            <Label>Dealer access *</Label>
            <p className="text-xs text-gray-500 mb-2">
              Dealers this user can work in. With more than one, the user switches between them from the account menu (top right).
            </p>
            <div className="border border-gray-200 rounded-md divide-y divide-gray-100">
              {activeEdits.map((m) => (
                <div key={m.dealerId} className="flex items-center gap-3 px-3 py-2">
                  <div className="w-7 h-7 rounded bg-gray-800 text-white flex items-center justify-center text-[11px] font-semibold uppercase shrink-0">
                    {(m.dealerName || '?').slice(0, 2)}
                  </div>
                  <span className="flex-1 text-sm text-gray-900 truncate">{m.dealerName}</span>
                  <select
                    value={m.role}
                    onChange={(e) =>
                      setMembershipEdits((prev) =>
                        prev.map((x) => (x.dealerId === m.dealerId ? { ...x, role: e.target.value } : x))
                      )
                    }
                    disabled={isSubmitting || loadingRoles}
                    className="px-2 py-1 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20"
                    aria-label={`Role at ${m.dealerName}`}
                  >
                    {portalDealerRoles.length === 0 ? (
                      <>
                        <option value="dealer_member">Dealer Member</option>
                        <option value="dealer_manager">Dealer Manager</option>
                      </>
                    ) : (
                      portalDealerRoles.map((r) => (
                        <option key={r.code} value={r.code}>{r.name}</option>
                      ))
                    )}
                  </select>
                  {allowDealerManagement && (
                    <button
                      type="button"
                      onClick={() =>
                        setMembershipEdits((prev) =>
                          prev
                            .map((x) => (x.dealerId === m.dealerId ? { ...x, removed: true } : x))
                            // Un-saved additions disappear immediately; existing rows stay marked for soft-delete on save.
                            .filter((x) => x.rowId || !x.removed)
                        )
                      }
                      disabled={isSubmitting || activeEdits.length <= 1}
                      className="p-1 rounded text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                      title={activeEdits.length <= 1 ? 'The user needs at least one dealer' : 'Remove access to this dealer'}
                    >
                      <X className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
              {allowDealerManagement && (
                <div className="flex items-center gap-2 px-3 py-2 bg-gray-50">
                  <select
                    value={addDealerId}
                    onChange={(e) => setAddDealerId(e.target.value)}
                    disabled={isSubmitting || loadingDealers || availableDealers.length === 0}
                    className="flex-1 px-2 py-1 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-100"
                    aria-label="Add dealer"
                  >
                    <option value="">{availableDealers.length === 0 ? 'No more dealers available' : 'Add dealer…'}</option>
                    {availableDealers.map((d) => (
                      <option key={d.id} value={d.id}>{d.dealer_name}</option>
                    ))}
                  </select>
                  <select
                    value={addRole}
                    onChange={(e) => setAddRole(e.target.value)}
                    disabled={isSubmitting || !addDealerId}
                    className="px-2 py-1 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-100"
                    aria-label="Role at new dealer"
                  >
                    {portalDealerRoles.length === 0 ? (
                      <>
                        <option value="dealer_member">Dealer Member</option>
                        <option value="dealer_manager">Dealer Manager</option>
                      </>
                    ) : (
                      portalDealerRoles.map((r) => (
                        <option key={r.code} value={r.code}>{r.name}</option>
                      ))
                    )}
                  </select>
                  <button
                    type="button"
                    onClick={handleAddDealer}
                    disabled={isSubmitting || !addDealerId}
                    className="flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    Add
                  </button>
                </div>
              )}
            </div>
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

export interface DealerUsersRef {
  openCreateModal: () => void;
}

interface DealerUsersProps {
  hideSectionHeader?: boolean;
  useInlineEdit?: boolean;
}

const DealerUsers = forwardRef<DealerUsersRef, DealerUsersProps>(function DealerUsers({ hideSectionHeader = false, useInlineEdit = false }, ref) {
  const { activeOrganizationId, activeOrganization } = useOrganizationContext();
  const { userType, portalDealerId, portalRole } = useAccessContext();
  const { can } = usePermissions();
  const isPortalManager = userType === 'portal' && portalRole === 'dealer_manager';
  const isPortal = userType === 'portal';
  const canManageDealerUsersInternal = !isPortal && (
    can('org.users.manage') ||
    can('settings.write') ||
    can('partners.write')
  );

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
  const [editingUser, setEditingUser] = useState<GroupedDealerUser | null>(null);
  const [authorizingId, setAuthorizingId] = useState<string | null>(null);
  const [invitingId, setInvitingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [inviteLink, setInviteLink] = useState<string | null>(null);
  const [copiedLinkId, setCopiedLinkId] = useState<string | null>(null);

  useImperativeHandle(ref, () => ({ openCreateModal: () => setIsCreateOpen(true) }), []);

  const filteredUsers = useMemo(() => {
    if (!searchTerm) return users;
    const search = searchTerm.toLowerCase();
    return users.filter(user =>
      (user.display_name?.toLowerCase() || '').includes(search) ||
      (user.email?.toLowerCase() || '').includes(search) ||
      (user.dealer_name?.toLowerCase() || '').includes(search)
    );
  }, [users, searchTerm]);
  const isLegacyUser = useCallback((user: DealerAppUserWithDealer) => user.source === 'legacy' || user.id.startsWith('legacy:'), []);
  const legacyUsersCount = useMemo(() => users.filter((u) => isLegacyUser(u)).length, [users, isLegacyUser]);

  // One row per ACCOUNT: a user with access to several dealers has one AppUsers
  // row per dealer; group them so the list shows the person once with all their
  // dealers, instead of confusing duplicate rows.
  const groupedUsers = useMemo<GroupedDealerUser[]>(() => {
    const map = new Map<string, DealerAppUserWithDealer[]>();
    for (const u of filteredUsers) {
      const key = u.auth_user_id || (u.email || '').toLowerCase() || u.id;
      const arr = map.get(key) ?? [];
      arr.push(u);
      map.set(key, arr);
    }
    const groups: GroupedDealerUser[] = [];
    map.forEach((rows, key) => {
      const sorted = [...rows].sort((a, b) => {
        const ta = a.created_at ? new Date(a.created_at).getTime() : 0;
        const tb = b.created_at ? new Date(b.created_at).getTime() : 0;
        return ta - tb;
      });
      groups.push({ key, primary: sorted[0], memberships: sorted });
    });
    // Newest account first (matches previous list order by created_at desc).
    return groups.sort((a, b) => {
      const ta = a.primary.created_at ? new Date(a.primary.created_at).getTime() : 0;
      const tb = b.primary.created_at ? new Date(b.primary.created_at).getTime() : 0;
      return tb - ta;
    });
  }, [filteredUsers]);

  const handleAuthorize = async (group: GroupedDealerUser) => {
    if (isLegacyUser(group.primary)) {
      addNotification({
        type: 'warning',
        title: 'Legacy user',
        message: 'This user comes from legacy DealerUsers and must be re-invited to AppUsers before authorization actions.',
      });
      return;
    }
    if (!activeOrganizationId) return;
    try {
      setAuthorizingId(group.primary.id);
      const { error } = await supabase
        .from('AppUsers')
        .update({ status: 'active' })
        .in('id', group.memberships.map((m) => m.id))
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

  const handleEdit = (group: GroupedDealerUser) => {
    if (isLegacyUser(group.primary)) {
      addNotification({
        type: 'warning',
        title: 'Legacy user',
        message: 'This user comes from legacy DealerUsers. Re-invite this email to manage it from AppUsers.',
      });
      return;
    }
    if (useInlineEdit) {
      router.navigate(`/partners/dealer-users/edit/${group.primary.id}`);
      return;
    }
    setEditingUser(group);
    setIsEditOpen(true);
  };

  const handleArchive = async (group: GroupedDealerUser) => {
    const user = group.primary;
    if (isLegacyUser(user)) {
      addNotification({
        type: 'warning',
        title: 'Legacy user',
        message: 'This user comes from legacy DealerUsers. Re-invite this email to manage it from AppUsers.',
      });
      return;
    }
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
        .in('id', group.memberships.map((m) => m.id))
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

  const handleDelete = async (group: GroupedDealerUser) => {
    const user = group.primary;
    if (isLegacyUser(user)) {
      addNotification({
        type: 'warning',
        title: 'Legacy user',
        message: 'This user comes from legacy DealerUsers. Re-invite this email to manage it from AppUsers.',
      });
      return;
    }
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Delete Dealer User',
      message: `Are you sure you want to permanently delete "${user.display_name || user.email || 'this user'}"? This removes their access to every dealer and also removes the user from authentication so the email can be re-invited. This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    setDeletingId(user.id);
    setLoading(true);
    try {
      // Soft-delete every membership row of the account.
      const { error: auErr } = await supabase
        .from('AppUsers')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .in('id', group.memberships.map((m) => m.id))
        .eq('organization_id', activeOrganizationId)
        .eq('user_type', 'dealer');
      if (auErr) throw auErr;

      // Legacy DealerUsers rows: one per dealer.
      for (const m of group.memberships) {
        const duQuery = supabase
          .from('DealerUsers')
          .update({ deleted: true, updated_at: new Date().toISOString() })
          .eq('organization_id', activeOrganizationId)
          .eq('dealer_id', m.dealer_id);
        const { error: duErr } = user.auth_user_id
          ? await duQuery.eq('user_id', user.auth_user_id)
          : await duQuery.ilike('portal_user_email', user.email);
        if (duErr) throw duErr;
      }

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
    if (isLegacyUser(user)) {
      addNotification({
        type: 'warning',
        title: 'Legacy user',
        message: 'This user comes from legacy DealerUsers. Re-invite this email from Add Dealer User to move it into AppUsers.',
      });
      return;
    }
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
    <div className={hideSectionHeader ? '' : 'py-6 px-6'}>
      {!hideSectionHeader && (
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">Dealer Users</h1>
            <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
              Manage dealer user access and permissions ({groupedUsers.length} total)
            </p>
          </div>
          <div className="flex items-center gap-3">
            {(activeOrganizationId || (isPortal && portalDealerId)) && (isPortalManager || canManageDealerUsersInternal) && (
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
      )}

      {/* Search and Filters */}
      <div className="mb-4">
        {legacyUsersCount > 0 && (
          <div className="mb-3 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
            <p className="text-sm font-medium text-amber-900">Legacy users detected: {legacyUsersCount}</p>
            <p className="mt-1 text-xs text-amber-800">
              This list reads from `AppUsers` as source of truth and also shows unmatched `DealerUsers` rows to avoid missing users.
              Legacy rows are read-only until re-invited into `AppUsers`.
            </p>
          </div>
        )}
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
              {groupedUsers.length === 0 ? (
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
              groupedUsers.map((group) => {
                const user = group.primary;
                return (
                  <tr key={group.key} className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer">
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                          <User className="w-4 h-4 text-gray-600" />
                        </div>
                        <span className="font-medium text-gray-900 truncate">
                          {user.display_name || 'No name'}
                        </span>
                        {isLegacyUser(user) && (
                          <span className="px-2 py-0.5 rounded border border-amber-300 bg-amber-50 text-[10px] font-medium text-amber-800">
                            Legacy
                          </span>
                        )}
                      </div>
                    </td>
                    {/* Dealers: one chip per dealer the account can work in */}
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      <div className="flex flex-col gap-1">
                        {group.memberships.map((m) => (
                          <span
                            key={m.id}
                            className="inline-flex items-center gap-1.5 w-fit px-2 py-0.5 rounded bg-gray-50 border border-gray-200 text-xs text-gray-700"
                          >
                            <Building2 className="w-3 h-3 text-gray-400" />
                            {m.dealer_name || '-'}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {user.email || '-'}
                    </td>
                    {/* Role per dealer (aligned with the dealer chips) */}
                    <td className="py-4 px-6">
                      <div className="flex flex-col gap-1">
                        {group.memberships.map((m) => {
                          const role = roleCodeToPortalRole(m.role_code);
                          const roleColors: Record<string, { bg: string; text: string; border: string }> = {
                            dealer_manager: { bg: 'bg-purple-50', text: 'text-purple-700', border: 'border border-purple-200' },
                            dealer_member: { bg: 'bg-blue-50', text: 'text-blue-700', border: 'border border-blue-200' },
                          };
                          const colors = roleColors[role] ?? roleColors.dealer_member;
                          return (
                            <span key={m.id} className={`w-fit px-2 py-0.5 rounded text-xs font-medium ${colors.bg} ${colors.text} ${colors.border}`}>
                              {getRoleLabel(role)}
                            </span>
                          );
                        })}
                      </div>
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={user.status ?? 'disabled'} />
                    </td>
                    
                    {/* Date Added */}
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {user.created_at 
                        ? formatDate(user.created_at)
                        : '-'}
                    </td>
                    
                    {/* Actions - only Dealer Manager (portal) or internal users can manage */}
                    <td className="py-4 px-6">
                      <div className="flex items-center justify-end gap-2">
                        {(isPortalManager || canManageDealerUsersInternal) && user.status === 'invited' && !isLegacyUser(user) && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleAuthorize(group);
                            }}
                            disabled={authorizingId === user.id}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title="Authorize user"
                          >
                            <CheckCircle className="w-4 h-4" />
                          </button>
                        )}
                        
                        {(isPortalManager || canManageDealerUsersInternal) && user.status === 'invited' && user.email && !isLegacyUser(user) && (
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
                        {(isPortalManager || canManageDealerUsersInternal) && !isLegacyUser(user) && (
                          <>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleEdit(group);
                              }}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Edit user & dealer access"
                            >
                              <Edit className="w-4 h-4" />
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleArchive(group);
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
                                handleDelete(group);
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
                );
              })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Summary - hide when section header is hidden to match Dealers format */}
      {!hideSectionHeader && users.length > 0 && (
        <div className="mt-4 text-sm text-gray-600">
          Showing {groupedUsers.length} dealer user{groupedUsers.length !== 1 ? 's' : ''}
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
          allowDealerManagement={canManageDealerUsersInternal}
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
});

DealerUsers.displayName = 'DealerUsers';
export default DealerUsers;
