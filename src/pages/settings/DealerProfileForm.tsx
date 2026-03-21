import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X, Mail, User, Shield, Calendar, Plus, Pencil, Trash2 } from 'lucide-react';
import { useAuthStore } from '../../stores/auth-store';
import { getRoleDescription, type CompanyPortalRole } from '../../portal/portalAccess';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import ImageUpload from '../../components/ui/ImageUpload';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDealers } from '../../hooks/useDealers';
import { useDealerTiers } from '../../hooks/useDealerTiers';
import { useProductTypes } from '../../hooks/useProductTypes';
import {
  useAppUsersByDealer,
  type DealerAppUser,
  roleCodeToPortalLabel,
  portalRoleToRoleCode,
  roleCodeToPortalRole,
} from '../../hooks/useAppUsersByDealer';
import { Settings2, FileText } from 'lucide-react';
import DealerTermsTab from './DealerTermsTab';

// Schema for Dealer
const dealerSchema = z.object({
  dealer_name: z.string().min(1, 'Dealer name is required'),
  identification_number: z.string().optional(),
  website: z.string()
    .optional()
    .or(z.literal(''))
    .refine((val) => {
      if (!val || val.trim() === '') return true;
      const urlPattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/i;
      return urlPattern.test(val.trim());
    }, {
      message: 'Invalid URL format. Use format like: example.com or https://example.com'
    }),
  dealer_email: z.string().email('Invalid email').optional().or(z.literal('')),
  dealer_phone: z.string().optional(),
  alt_phone: z.string().optional(),
  primary_contact_id: z.string().optional(),
  primary_contact_app_user_id: z.string().uuid().optional().or(z.literal('')),
  street_address_line_1: z.string().optional(),
  street_address_line_2: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  zip_code: z.string().optional(),
  country: z.string().optional(),
  billing_same_as_location: z.boolean().optional(),
  billing_street_address_line_1: z.string().optional(),
  billing_street_address_line_2: z.string().optional(),
  billing_city: z.string().optional(),
  billing_state: z.string().optional(),
  billing_zip_code: z.string().optional(),
  billing_country: z.string().optional(),
  notes: z.string().optional(),
  status: z.enum(['active', 'disabled']).optional(),
  dealer_tier_id: z.string().uuid().optional().or(z.literal('')),
  logo_url: z.string().optional().or(z.literal('')),
});

type DealerFormValues = z.infer<typeof dealerSchema>;

interface DealerProfileFormProps {
  basePath?: string;
}

export default function DealerProfileForm({ basePath = '/settings/dealer-profile' }: DealerProfileFormProps) {
  const [activeTab, setActiveTab] = useState<'details' | 'billing' | 'configurator-permissions' | 'terms'>('details');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [dealerId, setDealerId] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin, isMember, isViewer, loading: roleLoading } = useCurrentOrgRole();
  const { createDealer, updateDealer } = useDealers();
  const { tiers: dealerTiers } = useDealerTiers();
  const { productTypes } = useProductTypes();

  // Configurator Permissions tab: policy state (only when editing a dealer)
  const [configuratorPolicyLoading, setConfiguratorPolicyLoading] = useState(false);
  const [configuratorPolicySaving, setConfiguratorPolicySaving] = useState(false);
  const [configuratorPolicyError, setConfiguratorPolicyError] = useState<string | null>(null);
  const [configuratorPolicy, setConfiguratorPolicy] = useState<{
    allowed_product_type_codes: string[];
    allow_variants_catalog: boolean;
    allow_accessories_only: boolean;
    allow_hardware: boolean;
    allow_operating_system: boolean;
  } | null>(null);

  // Editable form state for Configurator Permissions (synced from policy or defaults when no policy)
  const [configuratorForm, setConfiguratorForm] = useState<{
    allowed_product_type_codes: string[];
    allow_variants_catalog: boolean;
    allow_accessories_only: boolean;
    allow_hardware: boolean;
    allow_operating_system: boolean;
  }>({
    allowed_product_type_codes: [],
    allow_variants_catalog: true,
    allow_accessories_only: false,
    allow_hardware: true,
    allow_operating_system: true,
  });

  // Dealer users from AppUsers (source of truth); only when editing a dealer
  const { users: dealerUsers, isLoading: loadingDealerUsers, refetch: refetchDealerUsers } = useAppUsersByDealer(dealerId || null, { onlyWhenDealerId: true });

  // Add Dealer User modal (create user for this dealer only; create-temp-user writes to AppUsers + DealerUsers)
  const [showAddUserModal, setShowAddUserModal] = useState(false);
  const [addUserName, setAddUserName] = useState('');
  const [addUserEmail, setAddUserEmail] = useState('');
  const [addUserRole, setAddUserRole] = useState<CompanyPortalRole>('dealer_member');
  const [addUserStatus, setAddUserStatus] = useState<'invited' | 'active' | 'disabled'>('invited');
  const [addUserSubmitting, setAddUserSubmitting] = useState(false);
  const [addUserError, setAddUserError] = useState<string | null>(null);

  // Edit Dealer User modal (edits AppUsers row)
  const [editingUser, setEditingUser] = useState<DealerAppUser | null>(null);
  const [editUserName, setEditUserName] = useState('');
  const [editUserEmail, setEditUserEmail] = useState('');
  const [editUserRole, setEditUserRole] = useState<CompanyPortalRole>('dealer_member');
  const [editUserStatus, setEditUserStatus] = useState<'active' | 'disabled'>('active');
  const [editUserSubmitting, setEditUserSubmitting] = useState(false);
  const [editUserError, setEditUserError] = useState<string | null>(null);

  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  
  const canEdit = isSuperAdmin || isOwner || isAdmin || isMember;
  const isReadOnly = roleLoading ? false : (isViewer || !canEdit);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
    formState: { errors },
  } = useForm<DealerFormValues>({
    resolver: zodResolver(dealerSchema),
    defaultValues: {
      billing_same_as_location: true,
      status: 'active',
      primary_contact_id: '',
      primary_contact_app_user_id: '',
      dealer_tier_id: '',
      logo_url: '',
    },
  });

  // Get dealer ID from URL if in edit mode; sync activeTab when URL has /terms
  useEffect(() => {
    const path = window.location.pathname;
    const escapedBase = basePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = path.match(new RegExp(`${escapedBase}/edit/([^/]+)`));
    if (match && match[1]) {
      setDealerId(match[1]);
      if (path.endsWith('/terms')) {
        setActiveTab('terms');
      }
    }
  }, [basePath]);

  // Sync activeTab when navigating via browser back/forward
  useEffect(() => {
    const onRouteChange = () => {
      const path = window.location.pathname;
      if (path.includes(`${basePath}/edit/`) && path.endsWith('/terms')) {
        setActiveTab('terms');
      } else if (path.match(new RegExp(`${basePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/edit/[^/]+$`))) {
        setActiveTab('details');
      }
    };
    window.addEventListener('popstate', onRouteChange);
    return () => window.removeEventListener('popstate', onRouteChange);
  }, []);

  // Load DealerConfiguratorPolicies when editing a dealer (for Configurator Permissions tab)
  useEffect(() => {
    if (!dealerId || !activeOrganizationId) {
      setConfiguratorPolicy(null);
      return;
    }
    let mounted = true;
    setConfiguratorPolicyLoading(true);
    setConfiguratorPolicyError(null);
    (async () => {
      const { data, error } = await supabase
        .from('DealerConfiguratorPolicies')
        .select('allowed_product_type_codes, allow_variants_catalog, allow_accessories_only, allow_hardware, allow_operating_system')
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', dealerId)
        .maybeSingle();
      if (!mounted) return;
      setConfiguratorPolicyLoading(false);
      if (error) {
        setConfiguratorPolicyError(error.message || 'Failed to load configurator policy');
        setConfiguratorPolicy(null);
        return;
      }
      if (data) {
        const codes = Array.isArray(data.allowed_product_type_codes) ? data.allowed_product_type_codes : [];
        const policy = {
          allowed_product_type_codes: codes.map((c: string) => String(c).trim().toLowerCase()).filter(Boolean),
          allow_variants_catalog: data.allow_variants_catalog ?? true,
          allow_accessories_only: data.allow_accessories_only ?? false,
          allow_hardware: data.allow_hardware ?? true,
          allow_operating_system: data.allow_operating_system ?? true,
        };
        setConfiguratorPolicy(policy);
        setConfiguratorForm(policy);
      } else {
        setConfiguratorPolicy(null);
        // No policy: defaults (all product types allowed = all codes from productTypes when they load)
        setConfiguratorForm(prev => ({
          ...prev,
          allowed_product_type_codes: [], // will be synced below when productTypes available
          allow_variants_catalog: true,
          allow_accessories_only: false,
          allow_hardware: true,
          allow_operating_system: true,
        }));
      }
    })();
    return () => { mounted = false; };
  }, [dealerId, activeOrganizationId]);

  // When no policy and productTypes load, default form to "all product types" (all codes)
  useEffect(() => {
    if (configuratorPolicy !== null || !productTypes.length) return;
    const allCodes = productTypes
      .map(pt => (pt.code || '').trim().toLowerCase())
      .filter(Boolean);
    setConfiguratorForm(prev => ({
      ...prev,
      allowed_product_type_codes: allCodes,
    }));
  }, [configuratorPolicy, productTypes]);

  // Load dealer data when in edit mode
  useEffect(() => {
    const loadDealerData = async () => {
      if (!dealerId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('Dealers')
          .select('*')
          .eq('id', dealerId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) {
          console.error('Error loading dealer:', error);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading dealer',
            message: 'Could not load dealer data. Please try again.',
          });
          return;
        }

        if (data) {
          setValue('dealer_name', data.dealer_name || '');
          setValue('identification_number', data.identification_number || '');
          setValue('website', data.website || '');
          setValue('dealer_email', data.dealer_email || '');
          setValue('dealer_phone', data.dealer_phone || '');
          setValue('alt_phone', data.alt_phone || '');
          setValue('primary_contact_id', data.primary_contact_id || '');
          setValue('primary_contact_app_user_id', data.primary_contact_app_user_id || '');
          setValue('street_address_line_1', data.street_address_line_1 || '');
          setValue('street_address_line_2', data.street_address_line_2 || '');
          setValue('city', data.city || '');
          setValue('state', data.state || '');
          setValue('zip_code', data.zip_code || '');
          setValue('country', data.country || '');
          setValue('dealer_tier_id', data.dealer_tier_id || '');
          setValue('billing_same_as_location', 
            data.billing_street_address_line_1 === data.street_address_line_1 &&
            data.billing_city === data.city &&
            data.billing_state === data.state &&
            data.billing_country === data.country
          );
          setValue('billing_street_address_line_1', data.billing_street_address_line_1 || '');
          setValue('billing_street_address_line_2', data.billing_street_address_line_2 || '');
          setValue('billing_city', data.billing_city || '');
          setValue('billing_state', data.billing_state || '');
          setValue('billing_zip_code', data.billing_zip_code || '');
          setValue('billing_country', data.billing_country || '');
          setValue('notes', data.notes || '');
          setValue('status', (data.status || 'active') as 'active' | 'disabled');
          setValue('logo_url', data.logo_url || '');
        }
      } catch (err) {
        console.error('Error loading dealer data:', err);
      }
    };

    loadDealerData();
  }, [dealerId, activeOrganizationId, setValue]);

  // Watch billing checkbox and address fields
  const billingSame = watch('billing_same_as_location');
  const street1 = watch('street_address_line_1');
  const street2 = watch('street_address_line_2');
  const city = watch('city');
  const state = watch('state');
  const zip = watch('zip_code');
  const country = watch('country');

  // Hook to copy address → billing when checkbox is active
  useEffect(() => {
    if (billingSame) {
      setValue('billing_street_address_line_1', street1 || '');
      setValue('billing_street_address_line_2', street2 || '');
      setValue('billing_city', city || '');
      setValue('billing_state', state || '');
      setValue('billing_zip_code', zip || '');
      setValue('billing_country', country || '');
    }
  }, [billingSame, street1, street2, city, state, zip, country, setValue]);

  // Primary Contact options: AppUsers of this dealer with role Dealer Manager
  const primaryContactOptions = useMemo(
    () => dealerUsers.filter((u) => u.role_code === 'dealer_manager'),
    [dealerUsers]
  );

  // Populate edit form when opening (DealerAppUser from AppUsers) — must be before any early return to keep hook count stable
  useEffect(() => {
    if (editingUser) {
      setEditUserName(editingUser.display_name || '');
      setEditUserEmail(editingUser.email || '');
      setEditUserRole(roleCodeToPortalRole(editingUser.role_code));
      const st = (editingUser.status || 'active').toLowerCase();
      setEditUserStatus(st === 'disabled' ? 'disabled' : 'active');
      setEditUserError(null);
    }
  }, [editingUser]);

  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">Select an organization to continue.</p>
        </div>
      </div>
    );
  }

  const onSubmit = async (values: DealerFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No organization selected',
        message: 'Please select an organization to continue.',
      });
      return;
    }

    const isValid = await trigger();
    if (!isValid) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Validation Error',
        message: 'Please complete all required fields before saving.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const billingAddress = values.billing_same_as_location ? {
        billing_street_address_line_1: values.street_address_line_1,
        billing_street_address_line_2: values.street_address_line_2,
        billing_city: values.city,
        billing_state: values.state,
        billing_zip_code: values.zip_code,
        billing_country: values.country,
      } : {
        billing_street_address_line_1: values.billing_street_address_line_1,
        billing_street_address_line_2: values.billing_street_address_line_2,
        billing_city: values.billing_city,
        billing_state: values.billing_state,
        billing_zip_code: values.billing_zip_code,
        billing_country: values.billing_country,
      };

      const normalizeWebsite = (url: string | undefined | null): string | null => {
        if (!url || url.trim() === '') return null;
        const trimmed = url.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
        return `https://${trimmed}`;
      };

      const dealerData: any = {
        organization_id: activeOrganizationId,
        dealer_name: values.dealer_name.trim(),
        dealer_email: values.dealer_email?.trim().toLowerCase() || null,
        dealer_phone: values.dealer_phone?.trim() || null,
        identification_number: values.identification_number?.trim() || null,
        website: normalizeWebsite(values.website),
        alt_phone: values.alt_phone || null,
        primary_contact_id: values.primary_contact_id || null,
        primary_contact_app_user_id: values.primary_contact_app_user_id?.trim() || null,
        street_address_line_1: values.street_address_line_1 || null,
        street_address_line_2: values.street_address_line_2 || null,
        city: values.city || null,
        state: values.state || null,
        zip_code: values.zip_code || null,
        country: values.country || null,
        billing_same_as_location: values.billing_same_as_location ?? true,
        billing_street_address_line_1: billingAddress.billing_street_address_line_1 || null,
        billing_street_address_line_2: billingAddress.billing_street_address_line_2 || null,
        billing_city: billingAddress.billing_city || null,
        billing_state: billingAddress.billing_state || null,
        billing_zip_code: billingAddress.billing_zip_code || null,
        billing_country: billingAddress.billing_country || null,
        notes: values.notes || null,
        status: values.status || 'active',
        dealer_tier_id: (values.dealer_tier_id && values.dealer_tier_id.trim() !== '') ? values.dealer_tier_id.trim() : null,
        logo_url: values.logo_url?.trim() || null,
      };

      if (dealerId) {
        await updateDealer(dealerId, dealerData);
        // Save configurator permissions with the same Save and Close (so tab Configurator Permissions is persisted)
        const { error: rpcError } = await supabase.rpc('upsert_dealer_configurator_policy', {
          p_org_id: activeOrganizationId,
          p_dealer_id: dealerId,
          p_allowed_product_type_codes: configuratorForm.allowed_product_type_codes,
          p_allow_variants_catalog: configuratorForm.allow_variants_catalog,
          p_allow_accessories_only: configuratorForm.allow_accessories_only,
          p_allow_hardware: configuratorForm.allow_hardware,
          p_allow_operating_system: configuratorForm.allow_operating_system,
        });
        if (rpcError) {
          console.error('[DealerProfileForm] Configurator policy save failed', rpcError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Dealer saved, permissions failed',
            message: rpcError.message || 'Configurator permissions could not be saved.',
          });
        }
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Dealer updated successfully',
          message: 'The dealer has been updated and is now available.',
        });
      } else {
        await createDealer(dealerData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Dealer created successfully',
          message: 'The dealer has been created and is now available.',
        });
      }
      
      router.navigate(basePath);
    } catch (err: any) {
      console.error('Error saving dealer:', err);
      const errorMessage = err.message || 'Error saving dealer. Please try again.';
      setSaveError(errorMessage);
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving dealer',
        message: 'Something went wrong while saving. Please try again.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleAddDealerUserSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!dealerId || !activeOrganizationId) return;
    const trimmedName = addUserName.trim();
    const trimmedEmail = addUserEmail.trim().toLowerCase();
    if (!trimmedName) {
      setAddUserError('Name is required');
      return;
    }
    if (!trimmedEmail) {
      setAddUserError('Email is required');
      return;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) {
      setAddUserError('Please enter a valid email address');
      return;
    }
    const { user } = useAuthStore.getState();
    if (!user?.id) {
      setAddUserError('You must be logged in to create users');
      return;
    }
    setAddUserSubmitting(true);
    setAddUserError(null);
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
      const { data: session } = await supabase.auth.getSession();
      if (!supabaseUrl || !anonKey) throw new Error('Supabase URL or anon key not configured');
      const res = await fetch(`${supabaseUrl}/functions/v1/create-temp-user`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session?.session?.access_token ?? anonKey}`,
          apikey: anonKey,
        },
        body: JSON.stringify({
          kind: 'portal',
          organization_id: activeOrganizationId,
          dealer_id: dealerId,
          email: trimmedEmail,
          name: trimmedName || null,
          role: addUserRole,
          status: addUserStatus,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        const msg = typeof data?.error === 'string' ? data.error : data?.message ?? `HTTP ${res.status}`;
        if (import.meta.env.DEV) console.error('[create-temp-user]', res.status, data);
        throw new Error(msg);
      }
      if (!data?.ok) {
        const msg = typeof data?.error === 'string' ? data.error : 'Edge Function failed';
        throw new Error(msg);
      }
      const emailSent = data?.email_sent === true;
      let message = emailSent
        ? `User created. An email with temporary credentials was sent to ${trimmedEmail}.`
        : `User created. Email could not be sent (check RESEND_API_KEY and FROM_EMAIL in Supabase).`;
      if (data?.temp_password) {
        message += `\n\nTemporary password: ${data.temp_password}\n\nShare this password with the user.`;
      }
      useUIStore.getState().addNotification({
        type: emailSent ? 'success' : 'warning',
        title: 'User created',
        message,
      });
      refetchDealerUsers();
      setShowAddUserModal(false);
      setAddUserName('');
      setAddUserEmail('');
      setAddUserRole('dealer_member');
      setAddUserStatus('invited');
    } catch (err: any) {
      const msg = err?.message || 'Error creating user';
      setAddUserError(msg);
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: msg });
    } finally {
      setAddUserSubmitting(false);
    }
  };

  const handleEditDealerUserSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUser || !dealerId || !activeOrganizationId) return;
    const trimmedName = editUserName.trim();
    const trimmedEmail = editUserEmail.trim().toLowerCase();
    if (!trimmedName) { setEditUserError('Name is required'); return; }
    if (!trimmedEmail) { setEditUserError('Email is required'); return; }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) { setEditUserError('Please enter a valid email address'); return; }
    setEditUserSubmitting(true);
    setEditUserError(null);
    try {
      const { error } = await supabase
        .from('AppUsers')
        .update({
          display_name: trimmedName,
          email: trimmedEmail,
          role_code: portalRoleToRoleCode(editUserRole),
          status: editUserStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', editingUser.id)
        .eq('organization_id', activeOrganizationId)
        .eq('user_type', 'dealer')
        .eq('dealer_id', dealerId);
      if (error) throw error;
      useUIStore.getState().addNotification({ type: 'success', title: 'User updated', message: 'Dealer user has been updated.' });
      refetchDealerUsers();
      setEditingUser(null);
    } catch (err: any) {
      setEditUserError(err?.message || 'Failed to update user');
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message });
    } finally {
      setEditUserSubmitting(false);
    }
  };

  const handleDeleteDealerUser = async (user: DealerAppUser) => {
    if (!activeOrganizationId) return;
    const confirmed = await showConfirm({
      title: 'Delete user',
      message: `Are you sure you want to delete "${user.display_name || user.email || 'this user'}"? This will also remove the user from authentication so the email can be re-invited. This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    setLoading(true);
    try {
      // 1) Soft delete DealerUsers (trigger will sync to AppUsers)
      const duQuery = supabase
        .from('DealerUsers')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', user.dealer_id);
      const { error: duErr } = user.auth_user_id
        ? await duQuery.eq('user_id', user.auth_user_id)
        : await duQuery.ilike('portal_user_email', user.email);
      if (duErr) throw duErr;

      // 2) Delete from Auth so the email can be re-invited
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
          console.warn('[DealerProfileForm] Auth delete failed (user already soft-deleted):', fnData?.error);
        }
      }

      useUIStore.getState().addNotification({ type: 'success', title: 'User deleted', message: 'Dealer user has been deleted.' });
      refetchDealerUsers();
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message || 'Failed to delete user.' });
    } finally {
      setLoading(false);
      closeDialog();
    }
  };

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Dealer Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {dealerId ? 'Edit dealer information' : 'Create a new dealer'}
          </p>
        </div>
        
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate(basePath)}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isReadOnly}
            title={isReadOnly ? 'You only have read permissions (viewer role)' : undefined}
          >
            {isSaving ? 'Saving...' : isReadOnly ? 'Read Only' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Tab Toggle Header */}
        <div 
          className="border-b"
          style={{
            height: '2.625rem',
            backgroundColor: 'var(--gray-100)',
            borderColor: 'var(--gray-250)'
          }}
        >
          <div className="flex items-stretch h-full" role="tablist">
            <button
              onClick={() => {
                setActiveTab('details');
                if (dealerId) router.navigate(`${basePath}/edit/${dealerId}`, false);
              }}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'details'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'details' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'details'}
            >
              Details
            </button>
            <button
              onClick={() => {
                setActiveTab('billing');
                if (dealerId) router.navigate(`${basePath}/edit/${dealerId}`, false);
              }}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'billing'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'billing' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'billing'}
            >
              Billing
            </button>
            {dealerId && (
              <>
                <button
                  onClick={() => {
                    setActiveTab('configurator-permissions');
                    if (dealerId) router.navigate(`${basePath}/edit/${dealerId}`, false);
                  }}
                  className={`transition-colors flex items-center justify-start border-r ${
                    activeTab === 'configurator-permissions'
                      ? 'bg-white font-semibold'
                      : 'hover:bg-white/50 font-normal'
                  }`}
                  style={{
                    fontSize: '12px',
                    padding: '0 48px',
                    height: '100%',
                    minWidth: '140px',
                    width: 'auto',
                    color: 'var(--graphite-black-hex)',
                    borderColor: 'var(--gray-250)',
                    borderBottom: activeTab === 'configurator-permissions' ? '2px solid var(--tab-active-underline)' : 'none'
                  }}
                  role="tab"
                  aria-selected={activeTab === 'configurator-permissions'}
                >
                  Configurator Permissions
                </button>
                <button
                  onClick={() => {
                    setActiveTab('terms');
                    if (dealerId) router.navigate(`${basePath}/edit/${dealerId}/terms`, false);
                  }}
                  className={`transition-colors flex items-center justify-start ${
                    activeTab === 'terms'
                      ? 'bg-white font-semibold'
                      : 'hover:bg-white/50 font-normal'
                  }`}
                  style={{
                    fontSize: '12px',
                    padding: '0 48px',
                    height: '100%',
                    minWidth: '140px',
                    width: 'auto',
                    color: 'var(--graphite-black-hex)',
                    borderColor: 'var(--gray-250)',
                    borderBottom: activeTab === 'terms' ? '2px solid var(--tab-active-underline)' : 'none'
                  }}
                  role="tab"
                  aria-selected={activeTab === 'terms'}
                >
                  <FileText className="w-4 h-4 mr-1.5" />
                  Terms & Conditions
                </button>
              </>
            )}
          </div>
        </div>

        {/* Form Body */}
        <div className="py-6 px-6">
          {activeTab === 'terms' && dealerId ? (
            <DealerTermsTab dealerId={dealerId} />
          ) : activeTab === 'billing' ? (
            <>
              <div className="col-span-12">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing Address</h3>
                
                <div className="flex items-center gap-2 mb-4">
                  <input
                    type="checkbox"
                    id="billing_same_as_location"
                    {...register('billing_same_as_location')}
                    checked={billingSame}
                    onChange={(e) => setValue('billing_same_as_location', e.target.checked)}
                    className="h-4 w-4"
                    disabled={isReadOnly}
                  />
                  <label htmlFor="billing_same_as_location" className="text-xs">
                    Billing address is the same as Location
                  </label>
                </div>

                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_1" className="text-xs" required={!billingSame}>Billing Street 1</Label>
                    <Input
                      id="billing_street_address_line_1"
                      {...register('billing_street_address_line_1')}
                      className="py-1 text-xs"
                      disabled={billingSame || isReadOnly}
                      error={!billingSame ? errors.billing_street_address_line_1?.message : undefined}
                    />
                  </div>

                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_2" className="text-xs">Billing Street 2</Label>
                    <Input
                      id="billing_street_address_line_2"
                      {...register('billing_street_address_line_2')}
                      className="py-1 text-xs"
                      disabled={billingSame || isReadOnly}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_city" className="text-xs" required={!billingSame}>Billing City</Label>
                    <Input
                      id="billing_city"
                      {...register('billing_city')}
                      className="py-1 text-xs"
                      disabled={billingSame || isReadOnly}
                      error={!billingSame ? errors.billing_city?.message : undefined}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_state" className="text-xs" required={!billingSame}>Billing State</Label>
                    <Input
                      id="billing_state"
                      {...register('billing_state')}
                      className="py-1 text-xs"
                      disabled={billingSame || isReadOnly}
                      error={!billingSame ? errors.billing_state?.message : undefined}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_zip_code" className="text-xs">Billing ZIP</Label>
                    <Input
                      id="billing_zip_code"
                      {...register('billing_zip_code')}
                      className="py-1 text-xs"
                      disabled={billingSame || isReadOnly}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_country" className="text-xs" required={!billingSame}>Billing Country</Label>
                    <SelectShadcn
                      value={watch('billing_country') || ''}
                      onValueChange={(value) =>
                        setValue('billing_country', value, { shouldValidate: true })
                      }
                      disabled={billingSame || isReadOnly}
                    >
                      <SelectTrigger className={`py-1 text-xs ${!billingSame && errors.billing_country ? 'border-red-300 bg-red-50' : ''}`}>
                        <SelectValue placeholder="Select billing country" />
                      </SelectTrigger>
                      <SelectContent>
                        {COUNTRIES.map((c) => (
                          <SelectItem key={c} value={c}>
                            {c}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                    {!billingSame && errors.billing_country && (
                      <p className="mt-1 text-xs text-red-600">{errors.billing_country.message}</p>
                    )}
                  </div>
                </div>
              </div>
            </>
          ) : activeTab === 'configurator-permissions' ? (
            <div className="space-y-6">
              <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                <Settings2 className="w-4 h-4" />
                Configurator Permissions
              </h3>
              <p className="text-xs text-gray-600">
                Restrict what this dealer can configure. If no policy is saved, the dealer has full access.
              </p>
              {configuratorPolicyError && (
                <div className="p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
                  {configuratorPolicyError}
                </div>
              )}
              {configuratorPolicyLoading ? (
                <div className="text-sm text-gray-500 py-4">Loading permissions…</div>
              ) : (
                <>
                  <div>
                    <Label className="text-xs font-medium text-gray-700 mb-2 block">Product Types</Label>
                    <p className="text-xs text-gray-500 mb-3">Select which product types this dealer can offer.</p>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                      {productTypes.map((pt) => {
                        const code = (pt.code || '').trim().toLowerCase();
                        if (!code) return null;
                        const checked = configuratorForm.allowed_product_type_codes.includes(code);
                        return (
                          <label key={pt.id} className="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={checked}
                              onChange={() => {
                                setConfiguratorForm(prev => ({
                                  ...prev,
                                  allowed_product_type_codes: checked
                                    ? prev.allowed_product_type_codes.filter(c => c !== code)
                                    : [...prev.allowed_product_type_codes, code],
                                }));
                              }}
                              className="h-4 w-4 rounded border-gray-300"
                              disabled={isReadOnly}
                            />
                            <span className="text-sm text-gray-800">{pt.name || code}</span>
                          </label>
                        );
                      })}
                    </div>
                    {productTypes.length === 0 && (
                      <p className="text-xs text-gray-500">No product types in this organization.</p>
                    )}
                  </div>
                  <div>
                    <Label className="text-xs font-medium text-gray-700 mb-2 block">Variant Permissions</Label>
                    <div className="space-y-2">
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={configuratorForm.allow_variants_catalog}
                          onChange={(e) => setConfiguratorForm(prev => ({ ...prev, allow_variants_catalog: e.target.checked }))}
                          className="h-4 w-4 rounded border-gray-300"
                          disabled={isReadOnly}
                        />
                        <span className="text-sm text-gray-800">Allow Catalog Variants</span>
                      </label>
                    </div>
                  </div>
                  <div>
                    <Label className="text-xs font-medium text-gray-700 mb-2 block">Steps Control</Label>
                    <div className="space-y-2">
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={configuratorForm.allow_hardware}
                          onChange={(e) => setConfiguratorForm(prev => ({ ...prev, allow_hardware: e.target.checked }))}
                          className="h-4 w-4 rounded border-gray-300"
                          disabled={isReadOnly}
                        />
                        <span className="text-sm text-gray-800">Allow Hardware Step</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={configuratorForm.allow_operating_system}
                          onChange={(e) => setConfiguratorForm(prev => ({ ...prev, allow_operating_system: e.target.checked }))}
                          className="h-4 w-4 rounded border-gray-300"
                          disabled={isReadOnly}
                        />
                        <span className="text-sm text-gray-800">Allow Operating System Step</span>
                      </label>
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={configuratorForm.allow_accessories_only}
                          onChange={(e) => setConfiguratorForm(prev => ({ ...prev, allow_accessories_only: e.target.checked }))}
                          className="h-4 w-4 rounded border-gray-300"
                          disabled={isReadOnly}
                        />
                        <span className="text-sm text-gray-800">Catalog Items Mode</span>
                      </label>
                    </div>
                  </div>
                  <p className="text-xs text-gray-500 pt-2">
                    Use &quot;Save and Close&quot; at the top to save these permissions.
                  </p>
                </>
              )}
            </div>
          ) : (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              {/* Top Section */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-6">
<Label htmlFor="dealer_name" className="text-xs" required>Dealer Name</Label>
                  <Input
                    id="dealer_name"
                    {...register('dealer_name')}
                    className="py-1 text-xs"
                    error={errors.dealer_name?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="identification_number" className="text-xs">ID Number</Label>
                  <Input 
                    id="identification_number" 
                    {...register('identification_number')}
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="status" className="text-xs">Status</Label>
                  <SelectShadcn
                    value={watch('status') || 'active'}
                    onValueChange={(value) => setValue('status', value as 'active' | 'disabled')}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select status" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="active">Active</SelectItem>
                      <SelectItem value="disabled">Disabled</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div className="col-span-12 mt-2">
                  <Label htmlFor="dealer_tier_id" className="text-xs">Tier</Label>
                  <SelectShadcn
                    value={watch('dealer_tier_id') || '__default__'}
                    onValueChange={(value) => setValue('dealer_tier_id', value === '__default__' ? '' : value)}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select tier" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__default__">Default: Bronze (35%)</SelectItem>
                      {dealerTiers.map((t) => (
                        <SelectItem key={t.id} value={t.id}>
                          {t.name} ({t.discount_pct}%)
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  <p className="text-xs text-gray-500 mt-0.5">Discount tier for pricing. If not set, Bronze is used.</p>
                </div>
              </div>

              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-3">
                  <Label htmlFor="website" className="text-xs">Website</Label>
                  <Input 
                    id="website" 
                    {...register('website')}
                    type="url" 
                    className="py-1 text-xs"
                    error={errors.website?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="dealer_email" className="text-xs">Email</Label>
                  <Input 
                    id="dealer_email" 
                    {...register('dealer_email')}
                    type="email" 
                    className="py-1 text-xs"
                    error={errors.dealer_email?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="dealer_phone" className="text-xs">Phone</Label>
                  <Input 
                    id="dealer_phone" 
                    {...register('dealer_phone')}
                    type="tel" 
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="alt_phone" className="text-xs">Alt Phone</Label>
                  <Input 
                    id="alt_phone" 
                    {...register('alt_phone')}
                    type="tel" 
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
              </div>

              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-6">
                  <Label htmlFor="primary_contact_app_user_id" className="text-xs">Primary Contact</Label>
                  <SelectShadcn
                    value={watch('primary_contact_app_user_id') || ''}
                    onValueChange={(value) => setValue('primary_contact_app_user_id', value || '')}
                    disabled={!dealerId || loadingDealerUsers || isReadOnly}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue
                        placeholder={
                          !dealerId
                            ? 'Save dealer first to set primary contact'
                            : loadingDealerUsers
                              ? 'Loading users...'
                              : primaryContactOptions.length === 0
                                ? 'No Dealer Managers yet. Add a user with role Manager.'
                                : 'Select primary contact'
                        }
                      />
                    </SelectTrigger>
                    <SelectContent>
                      {primaryContactOptions.map((appUser) => (
                        <SelectItem key={appUser.id} value={appUser.id}>
                          {appUser.display_name || appUser.email || 'Unnamed'}
                          {appUser.email && (
                            <span className="text-xs text-gray-500 ml-2">({appUser.email})</span>
                          )}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  <p className="text-xs text-gray-500 mt-0.5">AppUser with role Dealer Manager for this dealer.</p>
                </div>
                <div className="col-span-6">
                  <Label htmlFor="notes" className="text-xs">Notes</Label>
                  <textarea
                    id="notes"
                    {...register('notes')}
                    className="w-full px-2.5 py-1.5 text-xs border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:bg-gray-50 disabled:cursor-not-allowed"
                    rows={3}
                    disabled={isReadOnly}
                  />
                </div>
              </div>

              {/* Location Section */}
              <div className="col-span-12 mt-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-6">
                    <Label htmlFor="street_address_line_1" className="text-xs">Street Address</Label>
                    <Input 
                      id="street_address_line_1" 
                      {...register('street_address_line_1')}
                      className="py-1 text-xs"
                      disabled={isReadOnly}
                    />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="street_address_line_2" className="text-xs">
                      <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                    </Label>
                    <Input 
                      id="street_address_line_2" 
                      {...register('street_address_line_2')}
                      className="py-1 text-xs"
                      disabled={isReadOnly}
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="city" className="text-xs">City</Label>
                    <Input 
                      id="city" 
                      {...register('city')}
                      className="py-1 text-xs"
                      disabled={isReadOnly}
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="state" className="text-xs">State</Label>
                    <Input 
                      id="state" 
                      {...register('state')}
                      className="py-1 text-xs"
                      disabled={isReadOnly}
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="zip_code" className="text-xs">Zip Code</Label>
                    <Input 
                      id="zip_code" 
                      {...register('zip_code')}
                      className="py-1 text-xs"
                      disabled={isReadOnly}
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="country" className="text-xs">Country</Label>
                    <SelectShadcn
                      value={watch('country') || ''}
                      onValueChange={(value) => setValue('country', value)}
                      disabled={isReadOnly}
                    >
                      <SelectTrigger className="py-1 text-xs">
                        <SelectValue placeholder="Select country" />
                      </SelectTrigger>
                      <SelectContent>
                        {COUNTRIES.map((c) => (
                          <SelectItem key={c} value={c}>
                            {c}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                </div>
              </div>

              {/* Dealer Users Section - Only show in edit mode */}
              {dealerId && (
                <div className="col-span-12 mt-6">
                  <div className="flex items-center justify-between mb-3">
                    <div>
                      <h3 className="text-sm font-semibold text-gray-900">Dealer Users</h3>
                      <p className="text-xs text-gray-500 mt-0.5">Users associated with this dealer</p>
                    </div>
                    {canEdit && (
                      <button
                        type="button"
                        onClick={() => {
                          setAddUserError(null);
                          setAddUserName('');
                          setAddUserEmail('');
                          setAddUserRole('dealer_member');
                          setAddUserName(''); setAddUserEmail(''); setAddUserRole('dealer_member'); setAddUserStatus('invited'); setAddUserError(null); setShowAddUserModal(true);
                        }}
                        className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        Add User
                      </button>
                    )}
                  </div>
                  
                  {loadingDealerUsers ? (
                    <div className="text-center py-8">
                      <p className="text-sm text-gray-500">Loading users...</p>
                    </div>
                  ) : dealerUsers.length === 0 ? (
                    <div className="text-center py-8 bg-gray-50 rounded-lg border border-gray-200">
                      <User className="mx-auto h-12 w-12 text-gray-400 mb-3" />
                      <p className="text-sm text-gray-500 mb-1">No users found</p>
                      <p className="text-xs text-gray-400 mb-4">This dealer doesn't have any associated users yet.</p>
                      {canEdit && (
                        <button
                          type="button"
                          onClick={() => {
                            setAddUserError(null);
                            setAddUserName('');
                            setAddUserEmail('');
                            setAddUserRole('dealer_member');
                            setAddUserName(''); setAddUserEmail(''); setAddUserRole('dealer_member'); setAddUserStatus('invited'); setAddUserError(null); setShowAddUserModal(true);
                          }}
                          className="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                        >
                          <Plus className="w-4 h-4" />
                          Add User
                        </button>
                      )}
                    </div>
                  ) : (
                    <div className="table-fit-wrapper bg-white border border-gray-200 rounded-lg">
                      <table className="table-fit">
                        <thead>
                          <tr className="border-b border-gray-200 bg-gray-50">
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Name</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Email</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Role</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Status</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Invited</th>
                            {canEdit && <th className="text-right py-2 px-3 text-xs font-semibold text-gray-700">Actions</th>}
                          </tr>
                        </thead>
                        <tbody>
                          {dealerUsers.map((user) => (
                            <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50">
                              <td className="py-2 px-3 text-xs text-gray-900">
                                <div className="flex items-center gap-2">
                                  <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                                    <User className="w-4 h-4" style={{ color: 'var(--primary-brand-hex)' }} />
                                  </div>
                                  <span className="font-medium">
                                    {user.display_name || 'No name'}
                                  </span>
                                </div>
                              </td>
                              <td className="py-2 px-3 text-xs text-gray-600">
                                <div className="flex items-center gap-1.5">
                                  <Mail className="w-3 h-3 text-gray-400" />
                                  {user.email}
                                </div>
                              </td>
                              <td className="py-2 px-3 text-xs">
                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                  user.role_code === 'dealer_manager'
                                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                    : 'bg-gray-50 text-gray-700 border border-gray-200'
                                }`}>
                                  <Shield className="w-3 h-3 mr-1" />
                                  {roleCodeToPortalLabel(user.role_code)}
                                </span>
                              </td>
                              <td className="py-2 px-3 text-xs">
                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                  user.status === 'active'
                                    ? 'bg-green-50 text-green-700 border border-green-200'
                                    : user.status === 'invited'
                                    ? 'bg-yellow-50 text-yellow-700 border border-yellow-200'
                                    : 'bg-gray-50 text-gray-700 border border-gray-200'
                                }`}>
                                  {user.status === 'active' ? 'Active' : 
                                   user.status === 'invited' ? 'Invited' : 
                                   user.status === 'disabled' ? 'Disabled' : user.status}
                                </span>
                              </td>
                              <td className="py-2 px-3 text-xs text-gray-500">
                                {user.created_at ? (
                                  <div className="flex items-center gap-1.5">
                                    <Calendar className="w-3 h-3 text-gray-400" />
                                    {formatDate(user.created_at)}
                                  </div>
                                ) : (
                                  <span className="text-gray-400">—</span>
                                )}
                              </td>
                              {canEdit && (
                                <td className="py-2 px-3 text-right">
                                  <div className="flex items-center justify-end gap-1">
                                    <button
                                      type="button"
                                      onClick={() => setEditingUser(user)}
                                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                                      title="Edit user"
                                    >
                                      <Pencil className="w-4 h-4" />
                                    </button>
                                    <button
                                      type="button"
                                      onClick={() => handleDeleteDealerUser(user)}
                                      className="p-1.5 hover:bg-red-50 rounded text-red-600"
                                      title="Delete user"
                                    >
                                      <Trash2 className="w-4 h-4" />
                                    </button>
                                  </div>
                                </td>
                              )}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}

                  {/* Add Dealer User modal */}
                  {showAddUserModal && (
                    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
                      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden">
                        <div className="flex items-center justify-between p-4 border-b border-gray-200">
                          <h3 className="text-lg font-semibold text-gray-900">Add user to this dealer</h3>
                          <button
                            type="button"
                            onClick={() => !addUserSubmitting && setShowAddUserModal(false)}
                            className="text-gray-400 hover:text-gray-600 p-1"
                            disabled={addUserSubmitting}
                          >
                            <X className="w-5 h-5" />
                          </button>
                        </div>
                        <form onSubmit={handleAddDealerUserSubmit} className="p-4 space-y-4">
                          {addUserError && (
                            <div className="bg-red-50 border border-red-200 rounded-lg p-2 text-sm text-red-800">
                              {addUserError}
                            </div>
                          )}
                          <div>
                            <Label htmlFor="add_user_name">Name *</Label>
                            <Input
                              id="add_user_name"
                              type="text"
                              value={addUserName}
                              onChange={(e) => setAddUserName(e.target.value)}
                              placeholder="Full name"
                              disabled={addUserSubmitting}
                            />
                          </div>
                          <div>
                            <Label htmlFor="add_user_email">Email *</Label>
                            <Input
                              id="add_user_email"
                              type="email"
                              value={addUserEmail}
                              onChange={(e) => setAddUserEmail(e.target.value)}
                              placeholder="user@example.com"
                              disabled={addUserSubmitting}
                            />
                          </div>
                          <div>
                            <Label htmlFor="add_user_role">Role</Label>
                            <select
                              id="add_user_role"
                              value={addUserRole}
                              onChange={(e) => setAddUserRole(e.target.value as CompanyPortalRole)}
                              disabled={addUserSubmitting}
                              className="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                            >
                              <option value="dealer_manager">Dealer Manager</option>
                              <option value="dealer_member">Dealer Member</option>
                            </select>
                            <p className="text-xs text-gray-500 mt-1">{getRoleDescription(addUserRole)}</p>
                          </div>
                          <div>
                            <Label htmlFor="add_user_status">Status</Label>
                            <select
                              id="add_user_status"
                              value={addUserStatus}
                              onChange={(e) => setAddUserStatus(e.target.value as 'invited' | 'active' | 'disabled')}
                              disabled={addUserSubmitting}
                              className="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                            >
                              <option value="invited">Invited</option>
                              <option value="active">Active</option>
                              <option value="disabled">Disabled</option>
                            </select>
                            <p className="text-xs text-gray-500 mt-1">
                              Invited: pending acceptance. Active: can sign in. Disabled: no access.
                            </p>
                          </div>
                          <div className="flex justify-end gap-2 pt-2">
                            <button
                              type="button"
                              onClick={() => !addUserSubmitting && setShowAddUserModal(false)}
                              disabled={addUserSubmitting}
                              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
                            >
                              Cancel
                            </button>
                            <button
                              type="submit"
                              disabled={addUserSubmitting}
                              className="px-3 py-1.5 text-sm font-medium text-white rounded-md disabled:opacity-50"
                              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                            >
                              {addUserSubmitting ? 'Creating...' : 'Create user'}
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                  )}

                  {/* Edit Dealer User modal */}
                  {editingUser && (
                    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
                      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden">
                        <div className="flex items-center justify-between p-4 border-b border-gray-200">
                          <h3 className="text-lg font-semibold text-gray-900">Edit user</h3>
                          <button
                            type="button"
                            onClick={() => !editUserSubmitting && setEditingUser(null)}
                            className="text-gray-400 hover:text-gray-600 p-1"
                            disabled={editUserSubmitting}
                          >
                            <X className="w-5 h-5" />
                          </button>
                        </div>
                        <form onSubmit={handleEditDealerUserSubmit} className="p-4 space-y-4">
                          {editUserError && (
                            <div className="bg-red-50 border border-red-200 rounded-lg p-2 text-sm text-red-800">
                              {editUserError}
                            </div>
                          )}
                          <div>
                            <Label htmlFor="edit_user_name">Name *</Label>
                            <Input
                              id="edit_user_name"
                              type="text"
                              value={editUserName}
                              onChange={(e) => setEditUserName(e.target.value)}
                              placeholder="Full name"
                              disabled={editUserSubmitting}
                            />
                          </div>
                          <div>
                            <Label htmlFor="edit_user_email">Email *</Label>
                            <Input
                              id="edit_user_email"
                              type="email"
                              value={editUserEmail}
                              onChange={(e) => setEditUserEmail(e.target.value)}
                              placeholder="user@example.com"
                              disabled={editUserSubmitting}
                            />
                          </div>
                          <div>
                            <Label htmlFor="edit_user_role">Role</Label>
                            <select
                              id="edit_user_role"
                              value={editUserRole}
                              onChange={(e) => setEditUserRole(e.target.value as CompanyPortalRole)}
                              disabled={editUserSubmitting}
                              className="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                            >
                              <option value="dealer_manager">Dealer Manager</option>
                              <option value="dealer_member">Dealer Member</option>
                            </select>
                            <p className="text-xs text-gray-500 mt-1">{getRoleDescription(editUserRole)}</p>
                          </div>
                          <div>
                            <Label htmlFor="edit_user_status">Status</Label>
                            <select
                              id="edit_user_status"
                              value={editUserStatus}
                              onChange={(e) => setEditUserStatus(e.target.value as 'active' | 'disabled')}
                              disabled={editUserSubmitting}
                              className="w-full px-3 py-2 text-sm border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                            >
                              <option value="active">Active</option>
                              <option value="disabled">Disabled</option>
                            </select>
                          </div>
                          <div className="flex justify-end gap-2 pt-2">
                            <button
                              type="button"
                              onClick={() => !editUserSubmitting && setEditingUser(null)}
                              disabled={editUserSubmitting}
                              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
                            >
                              Cancel
                            </button>
                            <button
                              type="submit"
                              disabled={editUserSubmitting}
                              className="btn-save px-3 py-1.5 text-sm font-medium text-white rounded-md disabled:opacity-50"
                            >
                              {editUserSubmitting ? 'Saving...' : 'Save'}
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Dealer Logo - Only show in edit mode. Drag and drop like Items. */}
              {dealerId && activeOrganizationId && (
                <div className="col-span-12 mt-6">
                  <h3 className="text-sm font-semibold text-gray-900 mb-1">Dealer Logo</h3>
                  <p className="text-xs text-gray-500 mb-3">Logo shown on Proposal (top left) and in print/PDF. Click or drag and drop an image.</p>
                  <div className="max-w-xs">
                    <ImageUpload
                      label=""
                      currentImageUrl={watch('logo_url')?.trim() || null}
                      onImageUploaded={(url) => setValue('logo_url', url ?? '', { shouldValidate: true })}
                      disabled={isReadOnly}
                      bucket="catalog-images"
                      uploadPath={(file) => {
                        const ext = file.name.split('.').pop() || 'png';
                        return `dealer-logos/${activeOrganizationId}/${dealerId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
                      }}
                    />
                  </div>
                </div>
              )}

            </div>
          )}
        </div>
      </div>
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
