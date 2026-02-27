import { useState, useEffect, useCallback } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useRolesForUserType } from '../../lib/roles';
import { getRoleDescription, type CompanyPortalRole } from '../../portal/portalAccess';
import { Building, Store, Building2 } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

interface PartnerDealerUserFormProps {
  dealerUserId?: string | null;
}

export default function PartnerDealerUserForm({ dealerUserId }: PartnerDealerUserFormProps) {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuthStore();
  const { addNotification } = useUIStore();
  const { userType, portalDealerId, portalRole } = useAccessContext();
  const isPortalManager = userType === 'portal' && portalRole === 'dealer_manager';

  const { roles: dealerRoles, loading: loadingRoles } = useRolesForUserType('dealer');
  const portalDealerRoles = dealerRoles.filter(
    (r) => r.code === 'dealer_manager' || r.code === 'dealer_member'
  );

  const isEdit = !!dealerUserId;

  const [userName, setUserName] = useState('');
  const [userEmail, setUserEmail] = useState('');
  const [dealerId, setDealerId] = useState('');
  const [role, setRole] = useState('dealer_member');
  const [status, setStatus] = useState('active');
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const [dealers, setDealers] = useState<Array<{ id: string; dealer_name: string }>>([]);
  const [loadingDealers, setLoadingDealers] = useState(false);

  const fixedDealer = isPortalManager ? portalDealerId : null;

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  const loadDealers = useCallback(async () => {
    if (!activeOrganizationId || fixedDealer) return;
    setLoadingDealers(true);
    try {
      const { data, error } = await supabase
        .from('Dealers')
        .select('id, dealer_name')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('dealer_name', { ascending: true });
      setDealers(error ? [] : data || []);
    } catch {
      setDealers([]);
    } finally {
      setLoadingDealers(false);
    }
  }, [activeOrganizationId, fixedDealer]);

  useEffect(() => {
    loadDealers();
    if (fixedDealer) setDealerId(fixedDealer);
  }, [loadDealers, fixedDealer]);

  useEffect(() => {
    if (!dealerUserId) return;
    let mounted = true;
    setIsLoading(true);
    (async () => {
      const { data, error } = await supabase
        .from('AppUsers')
        .select('id, display_name, email, dealer_id, role_code, status')
        .eq('id', dealerUserId)
        .eq('user_type', 'dealer')
        .single();
      if (!mounted || error || !data) {
        setIsLoading(false);
        return;
      }
      setUserName(data.display_name || '');
      setUserEmail(data.email || '');
      setDealerId(data.dealer_id || '');
      const rc = (data.role_code ?? '').toLowerCase();
      setRole(rc === 'dealer_manager' || rc === 'member_manager' || rc === 'manager' ? 'dealer_manager' : 'dealer_member');
      const st = (data.status ?? 'active').toLowerCase();
      setStatus(st === 'disabled' ? 'disabled' : 'active');
      setIsLoading(false);
    })();
    return () => { mounted = false; };
  }, [dealerUserId]);

  const handleSave = async () => {
    const trimmedName = userName.trim();
    const trimmedEmail = userEmail.trim();

    if (!trimmedName) {
      addNotification({ type: 'error', message: 'Name is required' });
      return;
    }
    if (!trimmedEmail) {
      addNotification({ type: 'error', message: 'Email is required' });
      return;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) {
      addNotification({ type: 'error', message: 'Please enter a valid email address' });
      return;
    }
    if (!user?.id) {
      addNotification({ type: 'error', message: 'You must be logged in' });
      return;
    }

    const effectiveDealerId = fixedDealer || dealerId;
    if (!effectiveDealerId) {
      addNotification({ type: 'error', message: 'Dealer is required' });
      return;
    }

    setIsSaving(true);
    try {
      if (isEdit) {
        const normalizedStatus = ['active', 'disabled'].includes(status) ? status : 'active';
        const finalRoleCode = role === 'dealer_manager' ? 'dealer_manager' : 'dealer_member';

        const { error: updateError } = await supabase
          .from('AppUsers')
          .update({
            display_name: trimmedName || null,
            email: trimmedEmail,
            dealer_id: effectiveDealerId,
            role_code: finalRoleCode,
            status: normalizedStatus,
            updated_at: new Date().toISOString(),
          })
          .eq('id', dealerUserId!)
          .eq('organization_id', activeOrganizationId!)
          .eq('user_type', 'dealer');

        if (updateError) throw new Error(updateError.message);

        addNotification({ type: 'success', title: 'Dealer User Updated', message: 'The dealer user has been updated successfully.' });
      } else {
        const normalizedEmail = trimmedEmail.toLowerCase();
        const { data, error: createError } = await supabase.functions.invoke('create-temp-user', {
          body: {
            kind: 'portal',
            organization_id: activeOrganizationId,
            dealer_id: effectiveDealerId,
            email: normalizedEmail,
            name: trimmedName || null,
            role,
          },
        });

        const errStr =
          (typeof data?.error === 'string' && data.error) ||
          (typeof (createError as any)?.context === 'string' && (createError as any).context) ||
          (typeof createError?.message === 'string' && createError.message) ||
          (data?.ok === false ? 'Edge Function failed' : null);

        if (createError || !data?.ok) {
          throw new Error(typeof errStr === 'string' ? errStr : 'Failed to create user');
        }

        const emailSent = data?.email_sent === true;
        let message = emailSent
          ? `User created. Credentials sent to ${normalizedEmail}.`
          : 'User created. Email could not be sent (configure RESEND_API_KEY).';

        if (data?.temp_password) {
          message += ` Temporary password: ${data.temp_password}`;
        }

        addNotification({
          type: emailSent ? 'success' : 'warning',
          title: 'Dealer User Created',
          message,
        });
      }

      router.navigate('/partners/dealers');
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to save dealer user' });
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div className="py-6">
        <div className="flex items-center justify-center py-12">
          <p className="text-sm text-gray-500">Loading dealer user...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
        <div className="min-w-0">
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Dealer User Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {isEdit ? 'Edit dealer user information' : 'Create a new dealer user'}
          </p>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          <button
            type="button"
            onClick={() => router.navigate('/partners/dealers')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          >
            Close
          </button>
          <button
            type="button"
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={handleSave}
            disabled={isSaving || !userName.trim() || !userEmail.trim() || portalDealerRoles.length === 0}
          >
            {isSaving ? 'Saving...' : 'Save and Close'}
          </button>
        </div>
      </div>

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4" style={{ marginLeft: '1.1875rem', marginRight: '1.1875rem' }}>
        <div className="py-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">

            {/* Row 1: Name, Email, Dealer */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-4">
                <Label htmlFor="user_name" className="text-xs" required>Name</Label>
                <Input
                  id="user_name"
                  value={userName}
                  onChange={(e) => setUserName(e.target.value)}
                  className="py-1 text-xs"
                  placeholder="Enter user name"
                  disabled={isSaving}
                />
              </div>
              <div className="col-span-4">
                <Label htmlFor="user_email" className="text-xs" required>Email</Label>
                <Input
                  id="user_email"
                  type="email"
                  value={userEmail}
                  onChange={(e) => setUserEmail(e.target.value)}
                  className="py-1 text-xs"
                  placeholder="user@example.com"
                  disabled={isSaving}
                />
              </div>
              <div className="col-span-4">
                {!fixedDealer && (
                  <>
                    <Label htmlFor="dealer_id" className="text-xs" required>Dealer</Label>
                    {loadingDealers ? (
                      <p className="text-xs text-gray-500 py-2">Loading dealers...</p>
                    ) : (
                      <SelectShadcn
                        value={dealerId || '__none__'}
                        onValueChange={(value) => setDealerId(value === '__none__' ? '' : value)}
                        disabled={isSaving}
                      >
                        <SelectTrigger className="py-1 text-xs">
                          <SelectValue placeholder="Select a dealer" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="__none__">Select a dealer</SelectItem>
                          {dealers.map((d) => (
                            <SelectItem key={d.id} value={d.id}>
                              {d.dealer_name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    )}
                    {dealers.length === 0 && !loadingDealers && (
                      <p className="text-xs text-gray-500 mt-1">No dealers available. Create a dealer first.</p>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Row 2: Role, Status */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-4">
                <Label htmlFor="role" className="text-xs" required>Role</Label>
                {loadingRoles ? (
                  <p className="text-xs text-gray-500 py-2">Loading roles...</p>
                ) : (
                  <SelectShadcn
                    value={role}
                    onValueChange={setRole}
                    disabled={isSaving || loadingRoles}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select role" />
                    </SelectTrigger>
                    <SelectContent>
                      {portalDealerRoles.map((r) => (
                        <SelectItem key={r.code} value={r.code}>
                          {r.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                )}
                {!loadingRoles && portalDealerRoles.length === 0 && (
                  <p className="text-xs text-amber-600 mt-1">No roles configured. Configure roles in Settings.</p>
                )}
                {portalDealerRoles.length > 0 && (
                  <p className="text-xs text-gray-500 mt-1">{getRoleDescription(role as CompanyPortalRole)}</p>
                )}
              </div>
              <div className="col-span-4">
                <Label htmlFor="status" className="text-xs" required>Status</Label>
                <SelectShadcn
                  value={status}
                  onValueChange={setStatus}
                  disabled={isSaving}
                >
                  <SelectTrigger className="py-1 text-xs">
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="active">Active</SelectItem>
                    <SelectItem value="disabled">Disabled</SelectItem>
                  </SelectContent>
                </SelectShadcn>
                <p className="text-xs text-gray-500 mt-1">
                  Active: User can access. Disabled: Access blocked.
                </p>
              </div>
              <div className="col-span-4" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
