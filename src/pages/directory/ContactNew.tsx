import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useDirectoryContacts, CONTACT_TYPE_LABELS, type ContactType } from '../../hooks/useDirectoryContacts';
import { useDirectoryCustomers } from '../../hooks/useDirectoryCustomers';

// Contact type options: UI shows EN, DB stores EN
const CONTACT_TYPE_OPTIONS: { value: ContactType; label: string }[] = [
  { value: 'architect', label: CONTACT_TYPE_LABELS.architect },
  { value: 'interior_designer', label: CONTACT_TYPE_LABELS.interior_designer },
  { value: 'engineer', label: CONTACT_TYPE_LABELS.engineer },
  { value: 'project_manager', label: CONTACT_TYPE_LABELS.project_manager },
  { value: 'end_customer', label: CONTACT_TYPE_LABELS.end_customer },
];

// Unified schema for contacts (campos explícitos)
const contactSchema = z.object({
  customer_id: z.string().uuid('Invalid customer ID').optional().or(z.literal('')),
  contact_type: z.enum(['architect', 'interior_designer', 'engineer', 'project_manager', 'end_customer']),
  contact_title: z.string().optional(),
  contact_name: z.string().min(1, 'Contact name is required'),
  contact_id_number: z.string().optional(),
  contact_primary_phone: z.string().optional(),
  contact_cell_phone: z.string().optional(),
  contact_alt_phone: z.string().optional(),
  contact_email: z.string().email('Invalid email').optional().or(z.literal('')),
  contact_street_address: z.string().min(1, 'Street address is required'),
  contact_street_address_2: z.string().optional(),
  contact_city: z.string().min(1, 'City is required'),
  contact_state: z.string().min(1, 'State is required'),
  contact_zip_code: z.string().optional(),
  contact_country: z.string().min(1, 'Country is required'),
}).refine((data) => {
  // At least one of primary_phone or email must be provided
  return !!(data.contact_primary_phone?.trim() || data.contact_email?.trim());
}, {
  message: 'Either Primary Phone or Email is required',
  path: ['contact_primary_phone'],
});

type ContactFormData = z.infer<typeof contactSchema>;

export default function ContactNew() {
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [contactId, setContactId] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { createContact, updateContact, getContactById } = useDirectoryContacts();
  const { customers, isLoading: loadingCustomers } = useDirectoryCustomers();
  
  // Get permissions: use AccessContext for portal users, CurrentOrgRole for internal users
  const { canEditDirectory, userType, loading: accessLoading } = useAccessContext();
  const { canEditContacts, isViewer, loading: roleLoading, isSuperAdmin, isAdmin, isOwner, role } = useCurrentOrgRole();
  
  // Portal users can always edit Directory (both dealer_member and dealer_manager)
  // Internal users need explicit canEditContacts permission or be superadmin/admin/owner
  const canEdit = userType === "portal" 
    ? canEditDirectory 
    : (isSuperAdmin || isOwner || isAdmin || canEditContacts);
  
  // Determine if form should be read-only
  // Portal users: always editable (canEditDirectory is true for both roles)
  // Internal users: editable if superadmin/admin/owner OR has canEditContacts permission
  const isReadOnly = accessLoading || roleLoading 
    ? false // Optimistic: allow while loading
    : userType === "portal" 
      ? !canEditDirectory // Portal: read-only only if canEditDirectory is false
      : (isViewer || !canEdit); // Internal: read-only if viewer or no edit permission
  
  // Debug logging
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('🔍 ContactNew - Permissions:', {
        userType,
        canEditDirectory,
        role,
        isOwner,
        isAdmin,
        isSuperAdmin,
        canEditContacts,
        isViewer,
        canEdit,
        isReadOnly,
        roleLoading,
        accessLoading,
      });
    }
  }, [userType, canEditDirectory, role, isOwner, isAdmin, isSuperAdmin, canEditContacts, isViewer, canEdit, isReadOnly, roleLoading, accessLoading]);

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
      const contact = await getContactById(id);

      if (contact) {
        form.reset({
          customer_id: contact.customer_id || '',
          contact_type: (contact.contact_type || 'architect') as ContactType,
          contact_title: contact.contact_title || undefined,
          contact_name: contact.contact_name || '',
          contact_id_number: contact.contact_id_number || '',
          contact_primary_phone: contact.contact_primary_phone || '',
          contact_cell_phone: contact.contact_cell_phone || '',
          contact_alt_phone: contact.contact_alt_phone || '',
          contact_email: contact.contact_email || '',
          contact_street_address: contact.contact_street_address || '',
          contact_street_address_2: contact.contact_street_address_2 || '',
          contact_city: contact.contact_city || '',
          contact_state: contact.contact_state || '',
          contact_zip_code: contact.contact_zip_code || '',
          contact_country: contact.contact_country || '',
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
      
      if (errors.contact_name) missingFields.push('Contact Name');
      if (errors.contact_street_address) missingFields.push('Street Address');
      if (errors.contact_city) missingFields.push('City');
      if (errors.contact_state) missingFields.push('State');
      if (errors.contact_country) missingFields.push('Country');
      if (errors.contact_primary_phone) missingFields.push('Primary Phone or Email');
      
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

      // Payload con SOLO columnas explícitas
      const contactInput = {
        customer_id: formData.customer_id && formData.customer_id.trim() ? formData.customer_id : null,
        contact_type: formData.contact_type, // Ya viene en EN (architect, interior_designer, etc.)
        contact_title: formData.contact_title && formData.contact_title !== 'not_selected' ? formData.contact_title : null,
        contact_name: formData.contact_name,
        contact_id_number: formData.contact_id_number || null,
        contact_primary_phone: formData.contact_primary_phone || null,
        contact_cell_phone: formData.contact_cell_phone || null,
        contact_alt_phone: formData.contact_alt_phone || null,
        contact_email: formData.contact_email || null,
        contact_street_address: formData.contact_street_address,
        contact_street_address_2: formData.contact_street_address_2 || null,
        contact_city: formData.contact_city || null,
        contact_state: formData.contact_state || null,
        contact_zip_code: formData.contact_zip_code || null,
        contact_country: formData.contact_country || null,
      };

      if (contactId) {
        // Update existing contact
        await updateContact(contactId, contactInput);
      } else {
        // Create new contact
        await createContact(contactInput);
      }

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
        message: errorMessage,
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = form.handleSubmit(handleSave);

  return (
    <div className="py-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
        <div className="min-w-0">
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Contact Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {contactId ? 'Edit contact information' : 'Create a new contact'}
          </p>
        </div>
        
        {/* Action Buttons — pegados al padding derecho (ml-auto) */}
        <div className="flex items-center gap-3 ml-auto">
          <button
            type="button"
            onClick={() => router.navigate('/directory/contacts')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={handleSubmit}
            disabled={isSaving || isReadOnly}
            title={isReadOnly ? 'You only have read permissions (viewer role)' : undefined}
          >
            {isSaving ? 'Saving...' : isReadOnly ? 'Read Only' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
          <div className="p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
          </div>
        </div>
      )}

      {/* Main Content Card - Matching Contacts table structure exactly */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4" style={{ marginLeft: '1.1875rem', marginRight: '1.1875rem' }}>
        {/* Form Body - Matching Contacts content structure */}
        <div className="py-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* Row 1: Identity fields */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-2">
                <Label htmlFor="contact_title" className="text-xs">Title</Label>
                <Select
                  id="contact_title"
                  {...form.register('contact_title')}
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
                <Label htmlFor="contact_name" className="text-xs" required>Contact Name</Label>
                <Input 
                  id="contact_name" 
                  {...form.register('contact_name')}
                  className="py-1 text-xs"
                  error={form.formState.errors.contact_name?.message}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_id_number" className="text-xs">ID Number</Label>
                <Input 
                  id="contact_id_number" 
                  {...form.register('contact_id_number')}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_type" className="text-xs" required>Contact Type</Label>
                <SelectShadcn
                  value={form.watch('contact_type') || 'architect'}
                  onValueChange={(value) => form.setValue('contact_type', value as ContactType, { shouldValidate: true })}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${form.formState.errors.contact_type ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder="Select contact type">
                      {(() => {
                        const selectedValue = form.watch('contact_type') || 'architect';
                        const selectedOption = CONTACT_TYPE_OPTIONS.find(opt => opt.value === selectedValue);
                        return selectedOption ? selectedOption.label : 'Not Selected';
                      })()}
                    </SelectValue>
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
                <Label htmlFor="contact_primary_phone" className="text-xs">Primary Phone</Label>
                <Input 
                  id="contact_primary_phone" 
                  {...form.register('contact_primary_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  error={form.formState.errors.contact_primary_phone?.message}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_cell_phone" className="text-xs">Cell Phone</Label>
                <Input 
                  id="contact_cell_phone" 
                  {...form.register('contact_cell_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_alt_phone" className="text-xs">Alt Phone</Label>
                <Input 
                  id="contact_alt_phone" 
                  {...form.register('contact_alt_phone')}
                  type="tel" 
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="contact_email" className="text-xs">Email</Label>
                <Input 
                  id="contact_email" 
                  {...form.register('contact_email')}
                  type="email" 
                  className="py-1 text-xs"
                  error={form.formState.errors.contact_email?.message || (form.formState.errors.contact_primary_phone && !form.watch('contact_primary_phone') ? 'Either Primary Phone or Email is required' : undefined)}
                  disabled={isReadOnly}
                />
              </div>
            </div>

            {/* Row 3: Customer */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-4">
                <Label htmlFor="customer_id" className="text-xs">Customer Related</Label>
                <SelectShadcn
                  value={form.watch('customer_id') || '__none__'}
                  onValueChange={(value) => {
                    // Convert "__none__" to empty string for the form
                    const actualValue = value === '__none__' ? '' : value;
                    form.setValue('customer_id', actualValue, { shouldValidate: true });
                  }}
                  disabled={loadingCustomers || isReadOnly}
                >
                  <SelectTrigger className={`text-xs ${form.formState.errors.customer_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingCustomers ? "Loading customers..." : customers.length === 0 ? "No customers available" : "Select customer (optional)"} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none__">None (Standalone Contact)</SelectItem>
                    {customers.length === 0 ? (
                      <div className="px-2 py-1.5 text-xs text-gray-500">
                        {loadingCustomers ? "Loading..." : "No customers available"}
                      </div>
                    ) : (
                      customers.map((customer) => (
                        <SelectItem key={customer.id} value={customer.id}>
                          {customer.customer_name}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </SelectShadcn>
                {form.formState.errors.customer_id && (
                  <p className="mt-1 text-xs text-red-600">{form.formState.errors.customer_id.message}</p>
                )}
                <p className="mt-1 text-xs text-gray-500">
                  Optional: Select a customer to associate this contact with. A contact can exist independently. Note: A customer is required when creating an Organization User.
                </p>
              </div>
            </div>

            {/* Location Section */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                <div className="col-span-6">
                  <Label htmlFor="contact_street_address" className="text-xs" required>Street Address</Label>
                  <Input 
                    id="contact_street_address" 
                    {...form.register('contact_street_address')}
                    className="py-1 text-xs"
                    error={form.formState.errors.contact_street_address?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-6">
                  <Label htmlFor="contact_street_address_2" className="text-xs">
                    <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                  </Label>
                  <Input 
                    id="contact_street_address_2" 
                    {...form.register('contact_street_address_2')}
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="contact_city" className="text-xs" required>City</Label>
                  <Input 
                    id="contact_city" 
                    {...form.register('contact_city')}
                    className="py-1 text-xs"
                    error={form.formState.errors.contact_city?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="contact_state" className="text-xs" required>State</Label>
                  <Input 
                    id="contact_state" 
                    {...form.register('contact_state')}
                    className="py-1 text-xs"
                    error={form.formState.errors.contact_state?.message}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="contact_zip_code" className="text-xs">Zip Code</Label>
                  <Input 
                    id="contact_zip_code" 
                    {...form.register('contact_zip_code')}
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="contact_country" className="text-xs" required>Country</Label>
                  <SelectShadcn
                    value={form.watch('contact_country') || ''}
                    onValueChange={(value) => form.setValue('contact_country', value, { shouldValidate: true })}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${form.formState.errors.contact_country ? 'border-red-300 bg-red-50' : ''}`}>
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
                  {form.formState.errors.contact_country && (
                    <p className="mt-1 text-xs text-red-600">{form.formState.errors.contact_country.message}</p>
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
