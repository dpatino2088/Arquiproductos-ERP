import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X, Mail, User, Shield, Calendar } from 'lucide-react';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCompanies } from '../../hooks/useCompanies';
import { useCompanyPortalUsers, type CompanyPortalUser } from '../../hooks/useCompanyPortalUsers';

// Schema for Dealer (Company)
const dealerSchema = z.object({
  company_name: z.string().min(1, 'Dealer name is required'),
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
  company_email: z.string().email('Invalid email').optional().or(z.literal('')),
  company_phone: z.string().optional(),
  alt_phone: z.string().optional(),
  primary_contact_id: z.string().optional(),
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
});

type DealerFormValues = z.infer<typeof dealerSchema>;

interface Contact {
  id: string;
  contact_name: string;
  contact_id_number?: string | null;
  contact_type?: string | null;
}

export default function DealerProfileForm() {
  const [activeTab, setActiveTab] = useState<'details' | 'billing'>('details');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [dealerId, setDealerId] = useState<string | null>(null);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [loadingContacts, setLoadingContacts] = useState(true);
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin, isViewer, loading: roleLoading } = useCurrentOrgRole();
  const { createCompany, updateCompany } = useCompanies();
  
  // Load dealer users when in edit mode
  const { users: dealerUsers, isLoading: loadingDealerUsers } = useCompanyPortalUsers(dealerId || null);
  
  const canEdit = isSuperAdmin || isOwner || isAdmin;
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
    },
  });

  // Get dealer ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/settings\/dealer-profile\/edit\/([^/]+)/);
    if (match && match[1]) {
      setDealerId(match[1]);
    }
  }, []);

  // Load dealer data when in edit mode
  useEffect(() => {
    const loadDealerData = async () => {
      if (!dealerId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('Companies')
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
          setValue('company_name', data.company_name || '');
          setValue('identification_number', data.identification_number || '');
          setValue('website', data.website || '');
          setValue('company_email', data.company_email || '');
          setValue('company_phone', data.company_phone || '');
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
          setValue('notes', data.notes || '');
          setValue('status', (data.status || 'active') as 'active' | 'disabled');
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

  // Load Contacts from Supabase for primary_contact_id dropdown
  useEffect(() => {
    const loadContacts = async () => {
      if (!activeOrganizationId) {
        setLoadingContacts(false);
        return;
      }

      try {
        setLoadingContacts(true);
        
        const { data: orgCompanies } = await supabase
          .from('Companies')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        const companyIds = (orgCompanies || []).map((c: { id: string }) => c.id);

        let query = supabase
          .from('DirectoryContacts')
          .select('id, contact_name, contact_id_number, contact_type')
          .eq('deleted', false)
          .order('contact_name', { ascending: true });

        if (companyIds.length > 0) {
          query = query.in('company_id', companyIds);
          const { data: companyData } = await query;
          const { data: orgData } = await supabase
            .from('DirectoryContacts')
            .select('id, contact_name, contact_id_number, contact_type')
            .eq('organization_id', activeOrganizationId)
            .is('company_id', null)
            .eq('deleted', false)
            .order('contact_name', { ascending: true });

          const all = [...(companyData || []), ...(orgData || [])];
          const unique = Array.from(new Map(all.map(item => [item.id, item])).values());
          setContacts(unique);
        } else {
          const { data, error } = await query.eq('organization_id', activeOrganizationId);
          
          if (error) {
            console.error('Error loading contacts', error);
            setContacts([]);
          } else if (data) {
            setContacts(data);
          }
        }
      } catch (err) {
        console.error('Error loading contacts', err);
        setContacts([]);
      } finally {
        setLoadingContacts(false);
      }
    };

    loadContacts();
  }, [activeOrganizationId]);

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
        company_name: values.company_name.trim(),
        company_email: values.company_email?.trim().toLowerCase() || null,
        company_phone: values.company_phone?.trim() || null,
        identification_number: values.identification_number?.trim() || null,
        website: normalizeWebsite(values.website),
        alt_phone: values.alt_phone || null,
        primary_contact_id: values.primary_contact_id || null,
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
      };

      if (dealerId) {
        // Update existing dealer - use updateCompany with UpdateCompanyInput
        await updateCompany(dealerId, dealerData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Dealer updated successfully',
          message: 'The dealer has been updated and is now available.',
        });
      } else {
        // Create new dealer - use createCompany with CreateCompanyInput
        await createCompany(dealerData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Dealer created successfully',
          message: 'The dealer has been created and is now available.',
        });
      }
      
      router.navigate('/settings/dealer-profile');
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
            onClick={() => router.navigate('/settings/dealer-profile')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
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
            >
              Billing
            </button>
          </div>
        </div>

        {/* Form Body */}
        <div className="py-6 px-6">
          {activeTab === 'billing' ? (
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
          ) : (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              {/* Top Section */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-6">
                  <Label htmlFor="company_name" className="text-xs" required>Dealer Name</Label>
                  <Input 
                    id="company_name" 
                    {...register('company_name')}
                    className="py-1 text-xs"
                    error={errors.company_name?.message}
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
                  <Label htmlFor="company_email" className="text-xs">Email</Label>
                  <Input 
                    id="company_email" 
                    {...register('company_email')}
                    type="email" 
                    className="py-1 text-xs"
                    error={errors.company_email?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="company_phone" className="text-xs">Phone</Label>
                  <Input 
                    id="company_phone" 
                    {...register('company_phone')}
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
                  <Label htmlFor="primary_contact_id" className="text-xs">Primary Contact</Label>
                  <SelectShadcn
                    value={watch('primary_contact_id') || ''}
                    onValueChange={(value) => setValue('primary_contact_id', value || '')}
                    disabled={loadingContacts || isReadOnly}
                  >
                    <SelectTrigger className="py-1 text-xs">
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
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Dealer Users</h3>
                  <p className="text-xs text-gray-500 mb-4">Users associated with this dealer</p>
                  
                  {loadingDealerUsers ? (
                    <div className="text-center py-8">
                      <p className="text-sm text-gray-500">Loading users...</p>
                    </div>
                  ) : dealerUsers.length === 0 ? (
                    <div className="text-center py-8 bg-gray-50 rounded-lg border border-gray-200">
                      <User className="mx-auto h-12 w-12 text-gray-400 mb-3" />
                      <p className="text-sm text-gray-500 mb-1">No users found</p>
                      <p className="text-xs text-gray-400">This dealer doesn't have any associated users yet.</p>
                    </div>
                  ) : (
                    <div className="overflow-x-auto bg-white border border-gray-200 rounded-lg">
                      <table className="w-full">
                        <thead>
                          <tr className="border-b border-gray-200 bg-gray-50">
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Name</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Email</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Role</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Status</th>
                            <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700">Invited</th>
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
                                    {user.portal_user_name || 'No name'}
                                  </span>
                                </div>
                              </td>
                              <td className="py-2 px-3 text-xs text-gray-600">
                                <div className="flex items-center gap-1.5">
                                  <Mail className="w-3 h-3 text-gray-400" />
                                  {user.portal_user_email}
                                </div>
                              </td>
                              <td className="py-2 px-3 text-xs">
                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                  user.portal_user_role === 'member_manager'
                                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                    : 'bg-gray-50 text-gray-700 border border-gray-200'
                                }`}>
                                  <Shield className="w-3 h-3 mr-1" />
                                  {user.portal_user_role === 'member_manager' ? 'Manager' : 'Member'}
                                </span>
                              </td>
                              <td className="py-2 px-3 text-xs">
                                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                  user.portal_user_status === 'active'
                                    ? 'bg-green-50 text-green-700 border border-green-200'
                                    : user.portal_user_status === 'invited'
                                    ? 'bg-yellow-50 text-yellow-700 border border-yellow-200'
                                    : 'bg-gray-50 text-gray-700 border border-gray-200'
                                }`}>
                                  {user.portal_user_status === 'active' ? 'Active' : 
                                   user.portal_user_status === 'invited' ? 'Invited' : 
                                   user.portal_user_status === 'disabled' ? 'Disabled' : 'Draft'}
                                </span>
                              </td>
                              <td className="py-2 px-3 text-xs text-gray-500">
                                {user.invited_at ? (
                                  <div className="flex items-center gap-1.5">
                                    <Calendar className="w-3 h-3 text-gray-400" />
                                    {new Date(user.invited_at).toLocaleDateString()}
                                  </div>
                                ) : (
                                  <span className="text-gray-400">—</span>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
