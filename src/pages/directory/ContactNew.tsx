import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';

// Contact type options matching Supabase ENUM directory_contact_type
const CONTACT_TYPE_OPTIONS = [
  { value: 'architect', label: 'Architect' },
  { value: 'interior_designer', label: 'Interior Designer' },
  { value: 'project_manager', label: 'Project Manager' },
  { value: 'consultant', label: 'Consultant' },
  { value: 'dealer', label: 'Dealer' },
  { value: 'reseller', label: 'Reseller' },
  { value: 'partner', label: 'Partner' },
] as const;

// Unified schema for contacts
const contactSchema = z.object({
  customer_id: z.string().uuid('Customer is required').min(1, 'Customer is required'),
  contact_type: z.enum(['architect', 'interior_designer', 'project_manager', 'consultant', 'dealer', 'reseller', 'partner']),
  title_id: z.string().optional(),
  customer_name: z.string().min(1, 'Customer name is required'),
  identification_number: z.string().optional(),
  primary_phone: z.string().optional(),
  cell_phone: z.string().optional(),
  alt_phone: z.string().optional(),
  email: z.string().email('Invalid email').optional().or(z.literal('')),
  street_address_line_1: z.string().min(1, 'Street address is required'),
  street_address_line_2: z.string().optional(),
  city: z.string().min(1, 'City is required'),
  state: z.string().min(1, 'State is required'),
  zip_code: z.string().optional(),
  country: z.string().min(1, 'Country is required'),
}).refine((data) => {
  // At least one of primary_phone or email must be provided
  return !!(data.primary_phone?.trim() || data.email?.trim());
}, {
  message: 'Either Primary Phone or Email is required',
  path: ['primary_phone'],
});

type ContactFormData = z.infer<typeof contactSchema>;

interface Customer {
  id: string;
  company_name: string;
}

export default function ContactNew() {
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [contactId, setContactId] = useState<string | null>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  const { activeOrganizationId } = useOrganizationContext();
  
  // Get current user's role and permissions (uses active organization)
  const { canEditCustomers, isViewer, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only
  const isReadOnly = isViewer || !canEditCustomers;

  // Get contact ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/directory\/contacts\/edit\/([^/]+)/);
    if (match && match[1]) {
      setContactId(match[1]);
      loadContactData(match[1]);
    }
  }, []);

  const form = useForm<ContactFormData>({
    resolver: zodResolver(contactSchema),
    defaultValues: {
      contact_type: 'architect',
      customer_id: '',
    },
  });

  // Load customers for the current organization
  useEffect(() => {
    const loadCustomers = async () => {
      if (!activeOrganizationId) {
        setLoadingCustomers(false);
        return;
      }

      try {
        setLoadingCustomers(true);
        const { data, error } = await supabase
          .from('DirectoryCustomers')
          .select('id, company_name')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('company_name', { ascending: true });

        if (error) {
          console.error('Error loading customers:', error);
        } else if (data) {
          setCustomers(data);
        }
      } catch (err) {
        console.error('Error loading customers:', err);
      } finally {
        setLoadingCustomers(false);
      }
    };

    loadCustomers();
  }, [activeOrganizationId]);

  // Check for customerId in URL params (when coming from customer context)
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const customerIdFromUrl = urlParams.get('customerId');
    if (customerIdFromUrl && !contactId) {
      form.setValue('customer_id', customerIdFromUrl, { shouldValidate: true });
    }
  }, [contactId, form]);

  // Load contact data for edit mode
  const loadContactData = async (id: string) => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        console.error('Error loading contact:', error);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error loading contact',
          message: 'Could not load contact data. Please try again.',
        });
        router.navigate('/directory/contacts');
        return;
      }

      if (data) {
        form.reset({
          customer_id: data.customer_id || '',
          contact_type: (data.contact_type || 'architect') as any,
          title_id: data.title_id || undefined,
          customer_name: data.customer_name || '',
          identification_number: data.identification_number || '',
          primary_phone: data.primary_phone || '',
          cell_phone: data.cell_phone || '',
          alt_phone: data.alt_phone || '',
          email: data.email || '',
          street_address_line_1: data.street_address_line_1 || '',
          street_address_line_2: data.street_address_line_2 || '',
          city: data.city || '',
          state: data.state || '',
          zip_code: data.zip_code || '',
          country: data.country || '',
        });
      }
    } catch (err: any) {
      console.error('Error loading contact:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error loading contact',
        message: 'Could not load contact data. Please try again.',
      });
      router.navigate('/directory/contacts');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async () => {
    // Check for organization ID
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No organization selected',
        message: 'Please configure an organization in Settings > Organization Profile.',
      });
      return;
    }

    // Validate form before saving
    const isValid = await form.trigger();
    if (!isValid) {
      const errors = form.formState.errors;
      const missingFields: string[] = [];
      
      if (errors.customer_id) missingFields.push('Customer');
      if (errors.customer_name) missingFields.push('Customer Name');
      if (errors.street_address_line_1) missingFields.push('Street Address');
      if (errors.city) missingFields.push('City');
      if (errors.state) missingFields.push('State');
      if (errors.country) missingFields.push('Country');
      if (errors.primary_phone) missingFields.push('Primary Phone or Email');
      
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
      const formData = form.getValues();

      const contactData = {
        organization_id: activeOrganizationId,
        customer_id: formData.customer_id,
        contact_type: formData.contact_type,
        title_id: formData.title_id && formData.title_id !== 'not_selected' ? formData.title_id : null,
        customer_name: formData.customer_name,
        identification_number: formData.identification_number || null,
        primary_phone: formData.primary_phone || null,
        cell_phone: formData.cell_phone || null,
        alt_phone: formData.alt_phone || null,
        email: formData.email || null,
        street_address_line_1: formData.street_address_line_1,
        street_address_line_2: formData.street_address_line_2 || null,
        city: formData.city || null,
        state: formData.state || null,
        zip_code: formData.zip_code || null,
        country: formData.country || null,
        deleted: false,
        archived: false,
      };

      let result;
      if (contactId) {
        // Update existing contact
        result = await supabase
          .from('DirectoryContacts')
          .update({
            ...contactData,
            updated_at: new Date().toISOString(),
          })
          .eq('id', contactId)
          .select()
          .single();
      } else {
        // Create new contact
        result = await supabase
          .from('DirectoryContacts')
          .insert([contactData])
          .select()
          .single();
      }

      const { data, error } = result;

      if (error) {
        console.error('Error saving contact:', error);
        throw error;
      }

      console.log('Contact saved successfully:', data);
      
      // Show success notification
      useUIStore.getState().addNotification({
        type: 'success',
        title: contactId ? 'Contact updated successfully' : 'Contact saved successfully',
        message: contactId 
          ? 'The contact has been updated successfully.'
          : 'The contact has been saved and is now available in your directory.',
      });
      
      // Navigate back to contacts list
      router.navigate('/directory/contacts');
    } catch (err: any) {
      console.error('Error saving contact:', err);
      const errorMessage = err.message || 'Error saving contact. Please try again.';
      setSaveError(errorMessage);
      
      // Show error notification
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving contact',
        message: 'Something went wrong while saving. Please try again.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = form.handleSubmit(handleSave);

  return (
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Contact Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {contactId ? 'Edit contact information' : 'Create a new contact'}
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/contacts')}
            className="text-gray-500 hover:text-gray-700 p-1.5 rounded-lg hover:bg-gray-50 transition-colors"
            title="Close"
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>
          <button
            type="button"
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={handleSubmit}
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
        {/* Form Body - Matching Contacts content structure */}
        <div className="p-4">
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* Row 1: Identity fields */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-2">
                <Label htmlFor="title" className="text-xs">Title</Label>
                <Select
                  id="title"
                  {...form.register('title_id')}
                  options={[
                    { value: 'not_selected', label: 'Not Selected' },
                    { value: 'mr', label: 'Mr.' },
                    { value: 'mrs', label: 'Mrs.' },
                    { value: 'ms', label: 'Ms.' },
                    { value: 'dr', label: 'Dr.' }
                  ]}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-4">
                <Label htmlFor="customer_name" className="text-xs" required>Customer Name</Label>
                <Input 
                  id="customer_name" 
                  {...form.register('customer_name')}
                  className="py-1 text-xs"
                  error={form.formState.errors.customer_name?.message}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="identification_number" className="text-xs">ID Number</Label>
                <Input 
                  id="identification_number" 
                  {...form.register('identification_number')}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_type" className="text-xs" required>Contact Type</Label>
                <SelectShadcn
                  value={form.watch('contact_type') || 'architect'}
                  onValueChange={(value) => form.setValue('contact_type', value as any, { shouldValidate: true })}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${form.formState.errors.contact_type ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder="Select contact type" />
                  </SelectTrigger>
                  <SelectContent>
                    {CONTACT_TYPE_OPTIONS.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {form.formState.errors.contact_type && (
                  <p className="mt-1 text-xs text-red-600">{form.formState.errors.contact_type.message}</p>
                )}
              </div>
            </div>

            {/* Row 2: Phones and Email */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-3">
                <Label htmlFor="primary_phone" className="text-xs">Primary Phone</Label>
                <Input 
                  id="primary_phone" 
                  {...form.register('primary_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  error={form.formState.errors.primary_phone?.message}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="cell_phone" className="text-xs">Cell Phone</Label>
                <Input 
                  id="cell_phone" 
                  {...form.register('cell_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="alt_phone" className="text-xs">Alt Phone</Label>
                <Input 
                  id="alt_phone" 
                  {...form.register('alt_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="email" className="text-xs">Email</Label>
                <Input 
                  id="email" 
                  {...form.register('email')}
                  type="email" 
                  className="py-1 text-xs"
                  error={form.formState.errors.email?.message || (form.formState.errors.primary_phone && !form.watch('primary_phone') ? 'Either Primary Phone or Email is required' : undefined)}
                  disabled={isReadOnly}
                />
              </div>
            </div>

            {/* Row 3: Customer */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-4">
                <Label htmlFor="customer_id" className="text-xs" required>Customer</Label>
                <SelectShadcn
                  value={form.watch('customer_id') || ''}
                  onValueChange={(value) => form.setValue('customer_id', value, { shouldValidate: true })}
                  disabled={loadingCustomers || isReadOnly}
                >
                  <SelectTrigger className={`text-xs ${form.formState.errors.customer_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingCustomers ? "Loading customers..." : customers.length === 0 ? "No customers available" : "Select customer"} />
                  </SelectTrigger>
                  <SelectContent>
                    {customers.length === 0 ? (
                      <div className="px-2 py-1.5 text-xs text-gray-500">
                        {loadingCustomers ? "Loading..." : "No customers available. Please create a customer first."}
                      </div>
                    ) : (
                      customers.map((customer) => (
                        <SelectItem key={customer.id} value={customer.id}>
                          {customer.company_name}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </SelectShadcn>
                {form.formState.errors.customer_id && (
                  <p className="mt-1 text-xs text-red-600">{form.formState.errors.customer_id.message}</p>
                )}
                <p className="mt-1 text-xs text-gray-500">
                  A contact must belong to a customer. Select the customer this contact is associated with.
                </p>
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
                    {...form.register('street_address_line_1')}
                    className="py-1 text-xs"
                    error={form.formState.errors.street_address_line_1?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-6">
                  <Label htmlFor="street_address_line_2" className="text-xs">
                    <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                  </Label>
                  <Input 
                    id="street_address_line_2" 
                    {...form.register('street_address_line_2')}
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="city" className="text-xs" required>City</Label>
                  <Input 
                    id="city" 
                    {...form.register('city')}
                    className="py-1 text-xs"
                    error={form.formState.errors.city?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="state" className="text-xs" required>State</Label>
                  <Input 
                    id="state" 
                    {...form.register('state')}
                    className="py-1 text-xs"
                    error={form.formState.errors.state?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="zip_code" className="text-xs">Zip Code</Label>
                  <Input 
                    id="zip_code" 
                    {...form.register('zip_code')}
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="country" className="text-xs" required>Country</Label>
                  <SelectShadcn
                    value={form.watch('country') || ''}
                    onValueChange={(value) => form.setValue('country', value, { shouldValidate: true })}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${form.formState.errors.country ? 'border-red-300 bg-red-50' : ''}`}>
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
                  {form.formState.errors.country && (
                    <p className="mt-1 text-xs text-red-600">{form.formState.errors.country.message}</p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
