import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRY_OPTIONS, COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';

// Schema for Customer
const customerSchema = z.object({
  customer_type_id: z.string().min(1, 'Customer type is required').refine((val) => val !== 'not_selected', {
    message: 'Customer type is required',
  }),
  company_name: z.string().min(1, 'Company name is required'),
  identification_number: z.string().optional(),
  website: z.string().url('Invalid URL').optional().or(z.literal('')),
  email: z.string().email('Invalid email').optional().or(z.literal('')),
  company_phone: z.string().optional(),
  alt_phone: z.string().optional(),
  primary_contact_id: z.string().min(1, 'Primary Contact is required'),
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

interface CustomerType {
  id: string;
  name: string;
}

interface Contact {
  id: string;
  customer_name: string;
  identification_number?: string;
  contact_type: 'individual' | 'company';
}

export default function CustomerNew() {
  const [activeTab, setActiveTab] = useState<'details' | 'billing'>('details');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [customerTypes, setCustomerTypes] = useState<CustomerType[]>([]);
  const [loadingTypes, setLoadingTypes] = useState(true);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [loadingContacts, setLoadingContacts] = useState(true);
  const { activeOrganizationId } = useOrganizationContext();
  
  // Get current user's role and permissions (uses active organization)
  const { canEditCustomers, isViewer, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only
  const isReadOnly = isViewer || !canEditCustomers;

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
      billing_same_as_location: true,
    },
  });

  // Watch billing checkbox and address fields
  const billingSame = watch('billing_same_as_location');
  const street1 = watch('street_address_line_1');
  const street2 = watch('street_address_line_2');
  const city = watch('city');
  const state = watch('state');
  const zip = watch('zip_code');
  const country = watch('country');

  // Show message if no organization is selected
  if (!activeOrganizationId) {
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

  // Load CustomerTypes from Supabase
  useEffect(() => {
    const loadCustomerTypes = async () => {
      if (!activeOrganizationId) {
        setLoadingTypes(false);
        return;
      }

      try {
        setLoadingTypes(true);
        const { data, error } = await supabase
          .from('CustomerTypes')
          .select('id, name')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('name', { ascending: true });

        if (error) {
          console.error('Error loading customer types', error);
        } else if (data) {
          setCustomerTypes(data);
        }
      } catch (err) {
        console.error('Error loading customer types', err);
      } finally {
        setLoadingTypes(false);
      }
    };

    loadCustomerTypes();
  }, [activeOrganizationId]);

  // Load Contacts from Supabase for primary_contact_id dropdown
  useEffect(() => {
    const loadContacts = async () => {
      if (!activeOrganizationId) {
        setLoadingContacts(false);
        return;
      }

      try {
        setLoadingContacts(true);
        const { data, error } = await supabase
          .from('DirectoryContacts')
          .select('id, customer_name, identification_number, contact_type')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('contact_type', { ascending: true })
          .order('customer_name', { ascending: true });

        if (error) {
          console.error('Error loading contacts', error);
        } else if (data) {
          setContacts(data);
        }
      } catch (err) {
        console.error('Error loading contacts', err);
      } finally {
        setLoadingContacts(false);
      }
    };

    loadContacts();
  }, [activeOrganizationId]);

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
      
      if (errors.company_name) missingFields.push('Company Name');
      if (errors.customer_type_id) missingFields.push('Customer Type');
      if (errors.primary_contact_id) missingFields.push('Primary Contact');
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

      // Validate customer_type_id is required
      if (!values.customer_type_id || values.customer_type_id === 'not_selected') {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Missing Required Information',
          message: 'Customer Type is required.',
        });
        setIsSaving(false);
        return;
      }

      if (!activeOrganizationId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'No organization selected. Please select an organization.',
        });
        setIsSaving(false);
        return;
      }

      const customerData = {
        organization_id: activeOrganizationId,
        customer_type_id: values.customer_type_id,
        company_name: values.company_name,
        identification_number: values.identification_number || null,
        website: values.website || null,
        email: values.email || null,
        company_phone: values.company_phone || null,
        alt_phone: values.alt_phone || null,
        primary_contact_id: values.primary_contact_id, // Required field
        street_address_line_1: values.street_address_line_1,
        street_address_line_2: values.street_address_line_2 || null,
        city: values.city || null,
        state: values.state || null,
        zip_code: values.zip_code || null,
        country: values.country || null,
        billing_street_address_line_1: billingAddress.billing_street_address_line_1 || null,
        billing_street_address_line_2: billingAddress.billing_street_address_line_2 || null,
        billing_city: billingAddress.billing_city || null,
        billing_state: billingAddress.billing_state || null,
        billing_zip_code: billingAddress.billing_zip_code || null,
        billing_country: billingAddress.billing_country || null,
        deleted: false,
        archived: false,
      };

      const { data, error } = await supabase
        .from('DirectoryCustomers')
        .insert([customerData])
        .select()
        .single();

      if (error) {
        console.error('Error saving customer:', error);
        throw error;
      }

      console.log('Customer saved successfully:', data);
      
      // Show success notification
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Customer saved successfully',
        message: 'The customer has been saved and is now available in your directory.',
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
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Customer Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Create a new customer
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/customers')}
            className="text-gray-500 hover:text-gray-700 p-1.5 rounded-lg hover:bg-gray-50 transition-colors"
            title="Close"
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>
          <button
            type="button"
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
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
                color: activeTab === 'details' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'details' ? '2px solid var(--primary-brand-hex)' : 'none'
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
                color: activeTab === 'billing' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'billing' ? '2px solid var(--primary-brand-hex)' : 'none'
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
        <div className="p-4">
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
                <Label htmlFor="company_name" className="text-xs" required>Company Name</Label>
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
                <Label htmlFor="customer_type_id" className="text-xs" required>Customer Type</Label>
                <SelectShadcn
                  value={watch('customer_type_id') || ''}
                  onValueChange={(value) => {
                    setValue('customer_type_id', value, { shouldValidate: true });
                  }}
                  disabled={loadingTypes || isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.customer_type_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingTypes ? "Loading customer types..." : customerTypes.length === 0 ? "No customer types found" : "Select customer type"} />
                  </SelectTrigger>
                  <SelectContent>
                    {customerTypes.map((ct) => (
                      <SelectItem key={ct.id} value={ct.id}>
                        {ct.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {errors.customer_type_id && (
                  <p className="text-xs text-red-600 mt-1">{errors.customer_type_id.message}</p>
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
                <Label htmlFor="company_phone" className="text-xs">Company Phone</Label>
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
              <div className="col-span-3">
                <Label htmlFor="primary_contact_id" className="text-xs" required>Primary Contact</Label>
                <SelectShadcn
                  value={watch('primary_contact_id') || ''}
                  onValueChange={(value) => {
                    setValue('primary_contact_id', value, { shouldValidate: true });
                  }}
                  disabled={loadingContacts || isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.primary_contact_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingContacts ? "Loading contacts..." : contacts.length === 0 ? "No contacts found" : "Select primary contact"} />
                  </SelectTrigger>
                  <SelectContent>
                    {contacts.map((contact) => (
                      <SelectItem key={contact.id} value={contact.id}>
                        {contact.customer_name || 'Unnamed Contact'}
                        {contact.identification_number && (
                          <span className="text-xs text-gray-500 ml-2">({contact.identification_number})</span>
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
    </div>
  );
}
