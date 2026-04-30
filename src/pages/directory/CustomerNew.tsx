import { useState, useEffect, useCallback, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRY_OPTIONS, COUNTRIES } from '../../lib/constants';
import { X, Trash2, Plus, Edit, Unlink } from 'lucide-react';
import { useDeleteCustomer } from '../../hooks/useDirectory';
import { useDirectoryCustomers } from '../../hooks/useDirectoryCustomers';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';

// Customer type ENUM values (matching PostgreSQL ENUM directory_customer_type_name)
const CUSTOMER_TYPE_OPTIONS = [
  { value: 'contractor', label: 'Contractor' },
  { value: 'architecture_studio', label: 'Architecture Studio' },
  { value: 'design_studio', label: 'Design Studio' },
  { value: 'end_user', label: 'End User' },
] as const;

// Schema for Customer
const customerSchema = z.object({
  customer_type_name: z.enum(['contractor', 'architecture_studio', 'design_studio', 'end_user']).refine(
    (val) => val !== undefined && val !== null,
    { message: 'Customer type is required' }
  ),
  customer_name: z.string().min(1, 'Customer name is required'),
  identification_number: z.string().optional(),
  website: z.string()
    .optional()
    .or(z.literal(''))
    .refine((val) => {
      if (!val || val.trim() === '') return true;
      // Allow URLs with or without protocol
      const urlPattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/i;
      return urlPattern.test(val.trim());
    }, {
      message: 'Invalid URL format. Use format like: example.com or https://example.com'
    }),
  email: z.string().email('Invalid email').optional().or(z.literal('')),
  customer_phone: z.string().optional(), // Usar customer_phone (no company_phone)
  alt_phone: z.string().optional(),
  primary_contact_id: z.string().optional().or(z.literal('')),
  street_address_line_1: z.string().min(1, 'Street address is required'),
  street_address_line_2: z.string().optional(),
  city: z.string().min(1, 'City is required'),
  state: z.string().min(1, 'State is required'),
  zip_code: z.string().optional(),
  country: z.string().min(1, 'Country is required'),
  billing_same_as_location: z.boolean().optional(),
  billing_street_address_line_1: z.string().optional(),
  billing_street_address_line_2: z.string().optional(),
  billing_city: z.string().optional(),
  billing_state: z.string().optional(),
  billing_zip_code: z.string().optional(),
  billing_country: z.string().optional(),
}).refine((data) => {
  // If billing is not same as location, billing fields are required
  if (!data.billing_same_as_location) {
    return !!(data.billing_street_address_line_1?.trim() && 
              data.billing_city?.trim() && 
              data.billing_state?.trim() && 
              data.billing_country?.trim());
  }
  return true;
}, {
  message: 'Billing address fields are required when billing address differs from location',
  path: ['billing_street_address_line_1'],
});

type CustomerFormValues = z.infer<typeof customerSchema>;

interface Contact {
  id: string;
  contact_name: string;
  contact_id_number?: string | null;
  contact_type?: string | null;
}

interface RelatedContact {
  id: string;
  contact_name: string | null;
  contact_email: string | null;
  contact_primary_phone: string | null;
}

interface LinkableContact extends RelatedContact {
  customer_id: string | null;
}

export default function CustomerNew() {
  const [activeTab, setActiveTab] = useState<'details' | 'billing'>('details');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [customerId, setCustomerId] = useState<string | null>(null);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [loadingContacts, setLoadingContacts] = useState(true);
  const [relatedContacts, setRelatedContacts] = useState<RelatedContact[]>([]);
  const [loadingRelatedContacts, setLoadingRelatedContacts] = useState(false);
  const [showLinkContactModal, setShowLinkContactModal] = useState(false);
  const [linkContactSearch, setLinkContactSearch] = useState('');
  const [linkableContacts, setLinkableContacts] = useState<LinkableContact[]>([]);
  const [loadingLinkableContacts, setLoadingLinkableContacts] = useState(false);
  const [linkingContactId, setLinkingContactId] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { deleteCustomer, isDeleting } = useDeleteCustomer();
  const { createCustomer, updateCustomer, customers: directoryCustomers } = useDirectoryCustomers({ organizationId: activeOrganizationId ?? undefined });
  
  // Get permissions: use AccessContext for portal users, CurrentOrgRole for internal users
  const { canEditDirectory, userType, loading: accessLoading } = useAccessContext();
  const { canEditCustomers, isViewer, loading: roleLoading, isSuperAdmin, isAdmin, isOwner } = useCurrentOrgRole();
  
  // Portal users can always edit Directory (both dealer_member and dealer_manager)
  // Internal users need explicit canEditCustomers permission or be superadmin/admin/owner
  const canEdit = userType === "portal" 
    ? canEditDirectory 
    : (isSuperAdmin || isOwner || isAdmin || canEditCustomers);
  
  // Determine if form should be read-only
  // Portal users: always editable (canEditDirectory is true for both roles)
  // Internal users: editable if superadmin/admin/owner OR has canEditCustomers permission
  const isReadOnly = accessLoading || roleLoading 
    ? false // Optimistic: allow while loading
    : userType === "portal" 
      ? !canEditDirectory // Portal: read-only only if canEditDirectory is false
      : (isViewer || !canEdit); // Internal: read-only if viewer or no edit permission
  
  // Debug logging
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('🔍 CustomerNew - Permissions:', {
        userType,
        canEditDirectory,
        canEditCustomers,
        isSuperAdmin,
        isAdmin,
        isOwner,
        isViewer,
        canEdit,
        isReadOnly,
        roleLoading,
        accessLoading,
      });
    }
  }, [userType, canEditDirectory, canEditCustomers, isSuperAdmin, isAdmin, isOwner, isViewer, canEdit, isReadOnly, roleLoading, accessLoading]);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
    formState: { errors },
  } = useForm<CustomerFormValues>({
    resolver: zodResolver(customerSchema),
    defaultValues: {
      customer_type_name: 'contractor',
      billing_same_as_location: true,
      primary_contact_id: '', // Initialize to empty string to avoid undefined
    },
  });

  // Get customer ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/directory\/customers\/edit\/([^/]+)/);
    if (match && match[1]) {
      setCustomerId(match[1]);
    }
  }, []);

  // Load customer data when in edit mode
  useEffect(() => {
    const loadCustomerData = async () => {
      if (!customerId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('DirectoryCustomers')
          .select('*')
          .eq('id', customerId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) {
          console.error('Error loading customer:', error);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading customer',
            message: 'Could not load customer data. Please try again.',
          });
          return;
        }

        if (data) {
          // Populate form with customer data
          setValue('customer_type_name', (data.customer_type_name || 'contractor') as 'contractor' | 'architecture_studio' | 'design_studio' | 'end_user');
          setValue('customer_name', data.customer_name || '');
          setValue('identification_number', data.identification_number || '');
          setValue('website', data.website || '');
          setValue('email', data.customer_email || ''); // Usar customer_email (columna explícita)
          setValue('customer_phone', data.customer_phone || '');
          setValue('alt_phone', data.alt_phone || '');
          setValue('primary_contact_id', data.primary_contact_id || '');
          setValue('street_address_line_1', data.street_address_line_1 || '');
          setValue('street_address_line_2', data.street_address_line_2 || '');
          setValue('city', data.city || '');
          setValue('state', data.state || '');
          setValue('zip_code', data.zip_code || '');
          setValue('country', data.country || '');
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
        }
      } catch (err) {
        console.error('Error loading customer data:', err);
      }
    };

    loadCustomerData();
  }, [customerId, activeOrganizationId, setValue]);

  // Watch billing checkbox and address fields (MUST be before early returns)
  const billingSame = watch('billing_same_as_location');
  const street1 = watch('street_address_line_1');
  const street2 = watch('street_address_line_2');
  const city = watch('city');
  const state = watch('state');
  const zip = watch('zip_code');
  const country = watch('country');

  // Hook to copy address → billing when checkbox is active (MUST be before early returns)
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

  // Load contacts for Primary Contact dropdown.
  // Business rule: only contacts already related to this customer.
  const loadCustomerContacts = useCallback(async () => {
    if (!activeOrganizationId || !customerId) {
      // On create mode there are no related contacts yet.
      setContacts([]);
      setValue('primary_contact_id', '');
      setLoadingContacts(false);
      return;
    }

    try {
      setLoadingContacts(true);
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('id, contact_name, contact_id_number, contact_type')
        .eq('organization_id', activeOrganizationId)
        .eq('customer_id', customerId)
        .eq('deleted', false)
        .order('contact_name', { ascending: true });
      if (error) throw error;
      setContacts(data ?? []);
    } catch (err) {
      console.error('Error loading contacts', err);
      setContacts([]);
    } finally {
      setLoadingContacts(false);
    }
  }, [activeOrganizationId, customerId, setValue]);

  useEffect(() => {
    loadCustomerContacts();
  }, [loadCustomerContacts]);

  // Load related contacts (contacts linked to this customer) when editing
  const loadRelatedContacts = async () => {
    if (!customerId || !activeOrganizationId) {
      setRelatedContacts([]);
      return;
    }
    setLoadingRelatedContacts(true);
    try {
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('id, contact_name, contact_email, contact_primary_phone')
        .eq('customer_id', customerId)
        .eq('organization_id', activeOrganizationId)
        .or('deleted.is.false,deleted.is.null')
        .order('contact_name', { ascending: true });
      if (error) throw error;
      setRelatedContacts((data as RelatedContact[]) || []);
    } catch (err) {
      console.error('Error loading related contacts', err);
      setRelatedContacts([]);
    } finally {
      setLoadingRelatedContacts(false);
    }
  };

  useEffect(() => {
    loadRelatedContacts();
  }, [customerId, activeOrganizationId]);

  const loadLinkableContacts = useCallback(async () => {
    if (!activeOrganizationId || !customerId) {
      setLinkableContacts([]);
      return;
    }
    setLoadingLinkableContacts(true);
    try {
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('id, customer_id, contact_name, contact_email, contact_primary_phone')
        .eq('organization_id', activeOrganizationId)
        .or('deleted.is.false,deleted.is.null')
        .or(`customer_id.is.null,customer_id.neq.${customerId}`)
        .order('contact_name', { ascending: true })
        .limit(200);
      if (error) throw error;
      setLinkableContacts((data as LinkableContact[]) || []);
    } catch (err) {
      console.error('Error loading linkable contacts', err);
      setLinkableContacts([]);
    } finally {
      setLoadingLinkableContacts(false);
    }
  }, [activeOrganizationId, customerId]);

  useEffect(() => {
    if (!showLinkContactModal) return;
    loadLinkableContacts();
  }, [showLinkContactModal, loadLinkableContacts]);

  const filteredLinkableContacts = useMemo(() => {
    const q = linkContactSearch.trim().toLowerCase();
    if (!q) return linkableContacts;
    return linkableContacts.filter((c) => {
      const hay = `${c.contact_name ?? ''} ${c.contact_email ?? ''} ${c.contact_primary_phone ?? ''}`.toLowerCase();
      return hay.includes(q);
    });
  }, [linkableContacts, linkContactSearch]);

  const customerNameById = useMemo(() => {
    const map = new Map<string, string>();
    for (const c of directoryCustomers ?? []) {
      map.set(c.id, c.customer_name ?? '—');
    }
    return map;
  }, [directoryCustomers]);

  const handleLinkExistingContact = async (contactId: string) => {
    if (!activeOrganizationId || !customerId) return;
    try {
      setLinkingContactId(contactId);
      const { error } = await supabase
        .from('DirectoryContacts')
        .update({ customer_id: customerId, updated_at: new Date().toISOString() })
        .eq('id', contactId)
        .eq('organization_id', activeOrganizationId);
      if (error) throw error;

      // Auto-select as primary if none selected yet.
      const currentPrimary = watch('primary_contact_id');
      if (!currentPrimary) {
        setValue('primary_contact_id', contactId, { shouldValidate: true });
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Contact linked',
        message: 'Contact has been linked to this customer.',
      });
      await Promise.all([loadRelatedContacts(), loadCustomerContacts(), loadLinkableContacts()]);
      setShowLinkContactModal(false);
      setLinkContactSearch('');
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err?.message ?? 'Could not link contact.',
      });
    } finally {
      setLinkingContactId(null);
    }
  };

  const handleUnlinkContact = async (contactId: string, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!activeOrganizationId) return;
    try {
      const { error } = await supabase
        .from('DirectoryContacts')
        .update({ customer_id: null, updated_at: new Date().toISOString() })
        .eq('id', contactId)
        .eq('organization_id', activeOrganizationId);
      if (error) throw error;
      useUIStore.getState().addNotification({ type: 'success', title: 'Contact unlinked', message: 'Contact has been unlinked from this customer.' });
      await Promise.all([loadRelatedContacts(), loadCustomerContacts()]);
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message ?? 'Could not unlink contact.' });
    }
  };

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">
            Select an organization to continue.
          </p>
        </div>
      </div>
    );
  }

  const onSubmit = async (values: CustomerFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No organization selected',
        message: 'Please select an organization to continue.',
      });
      return;
    }

    // Validate form before saving
    const isValid = await trigger();
    if (!isValid) {
      const missingFields: string[] = [];
      
      if (errors.customer_name) missingFields.push('Customer Name');
        if (errors.customer_type_name) missingFields.push('Customer Type');
      if (errors.street_address_line_1) missingFields.push('Street Address');
      if (errors.city) missingFields.push('City');
      if (errors.state) missingFields.push('State');
      if (errors.country) missingFields.push('Country');
      if (errors.billing_street_address_line_1) missingFields.push('Billing Address fields');
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: missingFields.length > 0 
          ? `Please complete the following required fields: ${missingFields.join(', ')}.`
          : 'Please complete all required fields before saving.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      // Copy billing address from location if checkbox is checked
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

      if (!activeOrganizationId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'No organization selected. Please select an organization.',
        });
        setIsSaving(false);
        return;
      }

      const normalizeWebsite = (url: string | undefined | null): string | null => {
        if (!url || url.trim() === '') return null;
        const trimmed = url.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
        return `https://${trimmed}`;
      };

      const customerInput = {
        customer_type_name: values.customer_type_name,
        customer_name: values.customer_name,
        customer_email: values.email?.trim().toLowerCase() || null,
        customer_phone: values.customer_phone?.trim() || null,
        website: normalizeWebsite(values.website) ?? null,
        alt_phone: values.alt_phone?.trim() || null,
        identification_number: values.identification_number?.trim() || null,
        primary_contact_id: values.primary_contact_id || null,
        street_address_line_1: values.street_address_line_1,
        street_address_line_2: values.street_address_line_2?.trim() || null,
        city: values.city?.trim() || null,
        state: values.state?.trim() || null,
        zip_code: values.zip_code?.trim() || null,
        country: values.country?.trim() || null,
        billing_street_address_line_1: billingAddress.billing_street_address_line_1?.trim() || null,
        billing_street_address_line_2: billingAddress.billing_street_address_line_2?.trim() || null,
        billing_city: billingAddress.billing_city?.trim() || null,
        billing_state: billingAddress.billing_state?.trim() || null,
        billing_zip_code: billingAddress.billing_zip_code?.trim() || null,
        billing_country: billingAddress.billing_country?.trim() || null,
      };

      if (customerId) {
        await updateCustomer(customerId, customerInput);
      } else {
        await createCustomer(customerInput);
      }
      
      // Show success notification
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Customer saved successfully',
        message: `The customer has been ${customerId ? 'updated' : 'saved'} and is now available in your directory.`,
      });
      
      // Navigate back to customers list
      router.navigate('/directory/customers');
    } catch (err: any) {
      console.error('Error saving customer:', err);
      const errorMessage = err.message || 'Error saving customer. Please try again.';
      setSaveError(errorMessage);
      
      // Show error notification
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving customer',
        message: 'Something went wrong while saving. Please try again.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="py-6 px-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Customer Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {customerId ? 'Edit customer information' : 'Create a new customer'}
          </p>
        </div>
        
        {/* Action Buttons — pegados al padding derecho (ml-auto) */}
        <div className="flex items-center gap-3 ml-auto">
          <button
            type="button"
            onClick={() => router.navigate('/directory/customers')}
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

      {/* Main Content Card - Matching Contacts table structure exactly */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Tab Toggle Header - Matching Sub bar style from Layout (height: 2.625rem) */}
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
              onClick={() => setActiveTab('details')}
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
              aria-label={`Details${activeTab === 'details' ? ' (current tab)' : ''}`}
            >
              Details
            </button>
            <button
              onClick={() => setActiveTab('billing')}
              className={`transition-colors flex items-center justify-start ${
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
                borderBottom: activeTab === 'billing' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'billing'}
              aria-label={`Billing${activeTab === 'billing' ? ' (current tab)' : ''}`}
            >
              Billing
            </button>
          </div>
        </div>

        {/* Form Body - Matching Contacts content structure */}
        <div className="py-6 px-6">
          {activeTab === 'billing' ? (
            <>
              {/* Billing Address Section */}
              <div className="col-span-12">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing Address</h3>
                
                {/* CHECKBOX: Same as Street Address */}
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

                {/* BILLING ADDRESS */}
                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_1" className="text-xs" required={!billingSame}>Billing Street 1</Label>
                    <Input
                      id="billing_street_address_line_1"
                      {...register('billing_street_address_line_1')}
                      className="py-1 text-xs"
                      disabled={billingSame}
                      error={!billingSame ? errors.billing_street_address_line_1?.message : undefined}
                    />
                  </div>

                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_2" className="text-xs">Billing Street 2</Label>
                    <Input
                      id="billing_street_address_line_2"
                      {...register('billing_street_address_line_2')}
                      className="py-1 text-xs"
                      disabled={billingSame}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_city" className="text-xs" required={!billingSame}>Billing City</Label>
                    <Input
                      id="billing_city"
                      {...register('billing_city')}
                      className="py-1 text-xs"
                      disabled={billingSame}
                      error={!billingSame ? errors.billing_city?.message : undefined}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_state" className="text-xs" required={!billingSame}>Billing State</Label>
                    <Input
                      id="billing_state"
                      {...register('billing_state')}
                      className="py-1 text-xs"
                      disabled={billingSame}
                      error={!billingSame ? errors.billing_state?.message : undefined}
                    />
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="billing_zip_code" className="text-xs">Billing ZIP</Label>
                    <Input
                      id="billing_zip_code"
                      {...register('billing_zip_code')}
                      className="py-1 text-xs"
                      disabled={billingSame}
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
          ) : (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* Customer Mode - Top Section */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-6">
                <Label htmlFor="customer_name" className="text-xs" required>Customer Name</Label>
                <Input 
                  id="customer_name" 
                  {...register('customer_name')}
                      className="py-1 text-xs"
                  error={errors.customer_name?.message}
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
                <Label htmlFor="customer_type_name" className="text-xs" required>Customer Type</Label>
                <SelectShadcn
                  value={watch('customer_type_name') || ''}
                  onValueChange={(value) => {
                    setValue('customer_type_name', value as 'contractor' | 'architecture_studio' | 'design_studio' | 'end_user', { shouldValidate: true });
                  }}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.customer_type_name ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder="Select customer type" />
                  </SelectTrigger>
                  <SelectContent>
                    {CUSTOMER_TYPE_OPTIONS.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {errors.customer_type_name && (
                  <p className="text-xs text-red-600 mt-1">{errors.customer_type_name.message}</p>
                )}
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
                <Label htmlFor="email" className="text-xs">Email</Label>
                <Input 
                  id="email" 
                  {...register('email')}
                  type="email" 
                      className="py-1 text-xs"
                  error={errors.email?.message}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="customer_phone" className="text-xs">Customer Phone</Label>
                <Input 
                  id="customer_phone" 
                  {...register('customer_phone')}
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
              <div className="col-span-3">
                <Label htmlFor="primary_contact_id" className="text-xs">Primary Contact</Label>
                <SelectShadcn
                  value={watch('primary_contact_id') || ''}
                  onValueChange={(value) => {
                    // Ensure value is always a string, never undefined
                    setValue('primary_contact_id', value || '', { shouldValidate: true });
                  }}
                  disabled={loadingContacts || isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.primary_contact_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingContacts ? "Loading contacts..." : contacts.length === 0 ? "No contacts found" : "Select primary contact"} />
                  </SelectTrigger>
                  <SelectContent>
                    {contacts.filter(c => c.id).map((contact) => (
                      <SelectItem key={contact.id} value={contact.id}>
                        {contact.contact_name || 'Unnamed Contact'}
                        {contact.contact_id_number && (
                          <span className="text-xs text-gray-500 ml-2">({contact.contact_id_number})</span>
                        )}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {errors.primary_contact_id && (
                  <p className="text-xs text-red-600 mt-1">{errors.primary_contact_id.message}</p>
                )}
              </div>
            </div>

            {/* Location Section */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                <div className="col-span-6">
                  <Label htmlFor="street_address_line_1" className="text-xs" required>Street Address</Label>
                  <Input 
                    id="street_address_line_1" 
                    {...register('street_address_line_1')}
                      className="py-1 text-xs"
                    error={errors.street_address_line_1?.message}
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
                  <Label htmlFor="city" className="text-xs" required>City</Label>
                  <Input 
                    id="city" 
                    {...register('city')}
                    className="py-1 text-xs"
                    error={errors.city?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="state" className="text-xs" required>State</Label>
                  <Input 
                    id="state" 
                    {...register('state')}
                    className="py-1 text-xs"
                    error={errors.state?.message}
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
                  <Label htmlFor="country" className="text-xs" required>Country</Label>
                  <SelectShadcn
                    value={watch('country') || ''}
                    onValueChange={(value) => setValue('country', value, { shouldValidate: true })}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${errors.country ? 'border-red-300 bg-red-50' : ''}`}>
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
                  {errors.country && (
                    <p className="mt-1 text-xs text-red-600">{errors.country.message}</p>
                  )}
                </div>
              </div>
            </div>
          </div>
          )}
        </div>
      </div>

      {/* Related Contacts — solo en modo edición */}
      {customerId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="py-4 px-6 border-b border-gray-200 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-gray-900">Related Contacts</h3>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setShowLinkContactModal(true)}
                className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors"
              >
                <Plus style={{ width: 14, height: 14 }} />
                Link contact
              </button>
              <button
                type="button"
                onClick={() => router.navigate(`/directory/contacts/new?customerId=${customerId}`)}
                className="px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors"
              >
                New contact
              </button>
            </div>
          </div>
          <div className="px-6 py-4">
            {loadingRelatedContacts ? (
              <p className="text-sm text-gray-500">Loading related contacts…</p>
            ) : relatedContacts.length === 0 ? (
              <p className="text-sm text-gray-500">No contacts linked. Use “Link contact” to add a contact to this customer.</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="border-b border-gray-200">
                  <tr>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Contact Name</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Email</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Primary Phone</th>
                    <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {relatedContacts.map((rc) => (
                    <tr key={rc.id} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="py-3 px-4 text-gray-900">{rc.contact_name ?? '—'}</td>
                      <td className="py-3 px-4 text-gray-700">{rc.contact_email ?? '—'}</td>
                      <td className="py-3 px-4 text-gray-700">{rc.contact_primary_phone ?? '—'}</td>
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1">
                          <button
                            type="button"
                            onClick={(e) => { e.stopPropagation(); router.navigate(`/directory/contacts/edit/${rc.id}`); }}
                            className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                            title="Edit contact"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            onClick={(e) => handleUnlinkContact(rc.id, e)}
                            className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                            title="Unlink from customer"
                          >
                            <Unlink className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {customerId && showLinkContactModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-2xl rounded-lg bg-white border border-gray-200 shadow-lg">
            <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200">
              <h4 className="text-sm font-semibold text-gray-900">Link Existing Contact</h4>
              <button
                type="button"
                onClick={() => {
                  setShowLinkContactModal(false);
                  setLinkContactSearch('');
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-4">
              <Input
                value={linkContactSearch}
                onChange={(e) => setLinkContactSearch(e.target.value)}
                placeholder="Search by name, email, or phone..."
                className="py-1 text-xs mb-3"
              />
              <div className="max-h-80 overflow-auto border border-gray-200 rounded">
                {loadingLinkableContacts ? (
                  <p className="text-sm text-gray-500 p-3">Loading contacts…</p>
                ) : filteredLinkableContacts.length === 0 ? (
                  <p className="text-sm text-gray-500 p-3">No contacts available to link.</p>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 border-b border-gray-200 sticky top-0">
                      <tr>
                        <th className="text-left py-2 px-3 text-xs font-medium text-gray-700">Name</th>
                        <th className="text-left py-2 px-3 text-xs font-medium text-gray-700">Email</th>
                        <th className="text-left py-2 px-3 text-xs font-medium text-gray-700">Phone</th>
                        <th className="text-left py-2 px-3 text-xs font-medium text-gray-700">Current Customer</th>
                        <th className="text-right py-2 px-3 text-xs font-medium text-gray-700">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredLinkableContacts.map((c) => (
                        <tr key={c.id} className="border-b border-gray-100">
                          <td className="py-2 px-3 text-gray-900">{c.contact_name ?? '—'}</td>
                          <td className="py-2 px-3 text-gray-700">{c.contact_email ?? '—'}</td>
                          <td className="py-2 px-3 text-gray-700">{c.contact_primary_phone ?? '—'}</td>
                          <td className="py-2 px-3 text-gray-700">
                            {c.customer_id ? (customerNameById.get(c.customer_id) ?? 'Assigned') : 'Standalone'}
                          </td>
                          <td className="py-2 px-3 text-right">
                            <button
                              type="button"
                              onClick={() => handleLinkExistingContact(c.id)}
                              disabled={linkingContactId === c.id}
                              className="px-2 py-1 text-xs border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                            >
                              {linkingContactId === c.id ? 'Linking…' : 'Link'}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
