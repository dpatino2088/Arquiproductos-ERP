import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X, Trash2 } from 'lucide-react';
import { useDeleteVendor } from '../../hooks/useDirectory';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useVendorById } from '../../hooks/useDirectory';
import { queryClient } from '../../lib/query-client';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';

export default function VendorNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { canEditVendors, isViewer, loading: roleLoading } = useCurrentOrgRole();
  const [vendorId, setVendorId] = useState<string | null>(null);
  const { deleteVendor, isDeleting } = useDeleteVendor();
  const [activeTab, setActiveTab] = useState<'details' | 'billing'>('details');
  const isReadOnly = isViewer || !canEditVendors;
  const [billingSameAsStreet, setBillingSameAsStreet] = useState(false);
  const [vendorName, setVendorName] = useState('');
  const [identificationNumber, setIdentificationNumber] = useState('');
  const [website, setWebsite] = useState('');
  const [email, setEmail] = useState('');
  const [workPhone, setWorkPhone] = useState('');
  const [fax, setFax] = useState('');
  const [street1, setStreet1] = useState('');
  const [street2, setStreet2] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [zip, setZip] = useState('');
  const [country, setCountry] = useState('');
  const [billingStreet1, setBillingStreet1] = useState('');
  const [billingStreet2, setBillingStreet2] = useState('');
  const [billingCity, setBillingCity] = useState('');
  const [billingState, setBillingState] = useState('');
  const [billingZip, setBillingZip] = useState('');
  const [billingCountry, setBillingCountry] = useState('');
  const [primaryContactId, setPrimaryContactId] = useState<string>('');
  const [contacts, setContacts] = useState<Array<{ id: string; contact_name: string; identification_number?: string }>>([]);
  const [loadingContacts, setLoadingContacts] = useState(true);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  // Get vendor ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/directory\/vendors\/(?:edit\/)?([^/]+)/);
    if (match && match[1] && match[1] !== 'new') {
      setVendorId(match[1]);
    }
  }, []);

  // Use hook to fetch vendor data if editing
  const { vendor, isLoading: isLoadingVendor, isError: isErrorVendor } = useVendorById({
    id: vendorId,
    organizationId: activeOrganizationId,
  });

  // Load contacts from Supabase for primary_contact_id dropdown
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
          .select('id, contact_name, identification_number')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('contact_name', { ascending: true });

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

  // Load vendor data when vendor is fetched
  useEffect(() => {
    if (vendor) {
      // Map vendor_name field
      setVendorName(vendor.vendor_name || '');
      setIdentificationNumber(vendor.identification_number || '');
      setWebsite(vendor.website || '');
      setEmail(vendor.email || '');
      setWorkPhone(vendor.work_phone || '');
      setFax(vendor.fax || '');
      setStreet1(vendor.street_address_line_1 || '');
      setStreet2(vendor.street_address_line_2 || '');
      setCity(vendor.city || '');
      setState(vendor.state || '');
      setZip(vendor.zip_code || '');
      setCountry(vendor.country || '');
      setBillingStreet1(vendor.billing_street_address_line_1 || '');
      setBillingStreet2(vendor.billing_street_address_line_2 || '');
      setBillingCity(vendor.billing_city || '');
      setBillingState(vendor.billing_state || '');
      setBillingZip(vendor.billing_zip_code || '');
      setBillingCountry(vendor.billing_country || '');
      setPrimaryContactId((vendor as any).primary_contact_id || '');
      setBillingSameAsStreet(
        vendor.billing_street_address_line_1 === vendor.street_address_line_1 &&
        vendor.billing_city === vendor.city &&
        vendor.billing_state === vendor.state &&
        vendor.billing_country === vendor.country
      );
    }
  }, [vendor]);

  // Hook to copy address → billing when checkbox is active
  useEffect(() => {
    if (billingSameAsStreet) {
      setBillingStreet1(street1 || '');
      setBillingStreet2(street2 || '');
      setBillingCity(city || '');
      setBillingState(state || '');
      setBillingZip(zip || '');
      setBillingCountry(country || '');
    }
  }, [billingSameAsStreet, street1, street2, city, state, zip, country]);

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to {vendorId ? 'edit' : 'create'} a vendor.</p>
        </div>
      </div>
    );
  }

  // Show message if user doesn't have permissions
  if (!roleLoading && !canEditVendors) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">Acceso denegado</p>
          <p className="text-sm text-red-700 mt-1">
            {isViewer 
              ? 'No tienes permisos para editar vendors. Tu rol es "viewer" (solo lectura).'
              : 'No tienes permisos para gestionar vendors. Solo los roles "owner" y "admin" pueden editar vendors.'}
          </p>
          <button
            onClick={() => router.navigate('/directory/vendors')}
            className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:opacity-90 text-sm"
          >
            Volver a Vendors
          </button>
        </div>
      </div>
    );
  }

  // Show loading state while fetching vendor data or role
  if ((vendorId && isLoadingVendor) || roleLoading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading vendor...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state if failed to load vendor
  if (vendorId && isErrorVendor) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading vendor</p>
          <p className="text-sm text-red-700">Could not load the vendor. Please try again.</p>
          <button
            onClick={() => router.navigate('/directory/vendors')}
            className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:opacity-90"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  const handleSave = async () => {
    // Check permissions
    if (isReadOnly) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Sin permisos',
        message: 'No tienes permisos para guardar vendors.',
      });
      return;
    }

    // Validate required fields
    const errors: Record<string, string> = {};
    const missingFields: string[] = [];
    
    if (!vendorName.trim()) {
      errors.vendor_name = 'Vendor name is required';
      missingFields.push('Vendor Name');
    }
    if (!primaryContactId.trim()) {
      errors.primary_contact_id = 'Primary Contact is required';
      missingFields.push('Primary Contact');
    }
    if (!street1.trim()) {
      errors.street_address_line_1 = 'Street address is required';
      missingFields.push('Street Address');
    }
    if (!city.trim()) {
      errors.city = 'City is required';
      missingFields.push('City');
    }
    if (!state.trim()) {
      errors.state = 'State is required';
      missingFields.push('State');
    }
    if (!country.trim()) {
      errors.country = 'Country is required';
      missingFields.push('Country');
    }
    
    setValidationErrors(errors);
    
    if (missingFields.length > 0) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: `Please complete the following required fields: ${missingFields.join(', ')}.`,
      });
      return;
    }

    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No organization configured',
        message: 'Please configure an organization in Settings > Organization Profile.',
      });
      return;
    }

    try {
      setSaving(true);

      // Validate name is not empty before proceeding
      if (!vendorName.trim()) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Vendor name is required',
          message: 'Please enter a vendor name before saving.',
        });
        setSaving(false);
        return;
      }

      const vendorData: any = {
        organization_id: activeOrganizationId,
        name: vendorName.trim(), // Use 'name' as required by DB schema
        vendor_name: vendorName.trim(), // Keep for backward compatibility if needed
        primary_contact_id: primaryContactId.trim(), // Required field
        identification_number: identificationNumber.trim() || null,
        website: website.trim() || null,
        email: email.trim() || null,
        work_phone: workPhone.trim() || null,
        fax: fax.trim() || null,
        street_address_line_1: street1.trim(),
        street_address_line_2: street2.trim() || null,
        city: city.trim(),
        state: state.trim(),
        zip_code: zip.trim() || null,
        country: country.trim(),
        billing_street_address_line_1: billingSameAsStreet ? street1.trim() : billingStreet1.trim() || null,
        billing_street_address_line_2: billingSameAsStreet ? street2.trim() : billingStreet2.trim() || null,
        billing_city: billingSameAsStreet ? city.trim() : billingCity.trim() || null,
        billing_state: billingSameAsStreet ? state.trim() : billingState.trim() || null,
        billing_zip_code: billingSameAsStreet ? zip.trim() : billingZip.trim() || null,
        billing_country: billingSameAsStreet ? country.trim() : billingCountry.trim() || null,
        updated_at: new Date().toISOString(),
      };

      let result;

      if (vendorId) {
        // Update existing vendor
        result = await supabase
          .from('DirectoryVendors')
          .update(vendorData)
          .eq('id', vendorId)
          .eq('organization_id', activeOrganizationId)
          .select()
          .single();
      } else {
        // Create new vendor
        vendorData.created_at = new Date().toISOString();
        vendorData.deleted = false;
        vendorData.archived = false;

        result = await supabase
          .from('DirectoryVendors')
          .insert([vendorData])
          .select()
          .single();
      }

      if (result.error) {
        if (import.meta.env.DEV) {
          console.error('Error saving vendor:', result.error);
        }
        throw result.error;
      }

      if (import.meta.env.DEV) {
        console.log('Vendor saved successfully:', result.data);
      }
      
      // Invalidate queries to refresh list
      queryClient.invalidateQueries({ queryKey: ['directory-vendors'] });
      
      // Show success notification
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Vendor saved successfully',
        message: `The vendor has been ${vendorId ? 'updated' : 'saved'} and is now available in your directory.`,
      });
      
      router.navigate('/directory/vendors');
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error saving vendor:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving vendor',
        message: err.message || 'Something went wrong while saving. Please try again.',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="py-6 px-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Vendor Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {vendorId ? 'Edit vendor' : 'Create a new vendor'}
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/vendors')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={handleSave}
            disabled={isReadOnly}
            title={isReadOnly ? 'No tienes permisos para guardar vendors' : undefined}
          >
            {isReadOnly ? 'Read Only' : 'Save and Close'}
          </button>
        </div>
      </div>

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
        <div className="py-6 px-6">
          {activeTab === 'billing' ? (
            <>
              {/* Billing Address Section */}
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing Address</h3>
                
                {/* CHECKBOX: Same as Street Address */}
                <div className="flex items-center gap-2 mb-4">
                  <input
                    type="checkbox"
                    id="billing_same_as_street"
                    checked={billingSameAsStreet}
                    onChange={(e) => setBillingSameAsStreet(e.target.checked)}
                    className="h-4 w-4"
                    disabled={isReadOnly}
                  />
                  <label htmlFor="billing_same_as_street" className="text-sm">
                    Billing address is the same as street address
                  </label>
                </div>

                {/* BILLING ADDRESS */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="billing_street_address_line_1" className="text-xs">Billing Street 1</Label>
                    <Input
                      id="billing_street_address_line_1"
                      name="billing_street_address_line_1"
                      value={billingStreet1}
                      onChange={(e) => setBillingStreet1(e.target.value)}
                      className="py-1 text-xs"
                      disabled={billingSameAsStreet || isReadOnly}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_street_address_line_2" className="text-xs">Billing Street 2</Label>
                    <Input
                      id="billing_street_address_line_2"
                      name="billing_street_address_line_2"
                      value={billingStreet2}
                      onChange={(e) => setBillingStreet2(e.target.value)}
                      className="py-1 text-xs"
                      disabled={billingSameAsStreet || isReadOnly}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_city" className="text-xs">Billing City</Label>
                    <Input
                      id="billing_city"
                      name="billing_city"
                      value={billingCity}
                      onChange={(e) => setBillingCity(e.target.value)}
                      className="py-1 text-xs"
                      disabled={billingSameAsStreet || isReadOnly}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_state" className="text-xs">Billing State</Label>
                    <Input
                      id="billing_state"
                      name="billing_state"
                      value={billingState}
                      onChange={(e) => setBillingState(e.target.value)}
                      className="py-1 text-xs"
                      disabled={billingSameAsStreet || isReadOnly}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_zip_code" className="text-xs">Billing ZIP</Label>
                    <Input
                      id="billing_zip_code"
                      name="billing_zip_code"
                      value={billingZip}
                      onChange={(e) => setBillingZip(e.target.value)}
                      className="py-1 text-xs"
                      disabled={billingSameAsStreet || isReadOnly}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_country" className="text-xs">Billing Country</Label>
                    <SelectShadcn
                      value={billingCountry}
                      onValueChange={(value: string) => setBillingCountry(value)}
                      disabled={billingSameAsStreet || isReadOnly}
                    >
                      <SelectTrigger className="py-1 text-xs">
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
                  </div>
                </div>
              </div>
            </>
          ) : (
            <>
              <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* Top Section */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-6">
                <Label htmlFor="vendor_name" className="text-xs" required>Vendor Name</Label>
                  <Input 
                  id="vendor_name" 
                  name="vendor_name" 
                  value={vendorName}
                  onChange={(e) => {
                    setVendorName(e.target.value);
                    if (validationErrors.vendor_name) {
                      setValidationErrors(prev => ({ ...prev, vendor_name: '' }));
                    }
                  }}
                  className="py-1 text-xs"
                  error={validationErrors.vendor_name}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="identification_number" className="text-xs">ID Number</Label>
                <Input 
                  id="identification_number" 
                  name="identification_number" 
                  value={identificationNumber}
                  onChange={(e) => setIdentificationNumber(e.target.value)}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="website" className="text-xs">Website</Label>
                <Input 
                  id="website" 
                  name="website" 
                  type="url" 
                  value={website}
                  onChange={(e) => setWebsite(e.target.value)}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
            </div>

            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-3">
                <Label htmlFor="email" className="text-xs">Email</Label>
                <Input 
                  id="email" 
                  name="email" 
                  type="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="work_phone" className="text-xs">Work Phone</Label>
                <Input 
                  id="work_phone" 
                  name="work_phone" 
                  type="tel" 
                  value={workPhone}
                  onChange={(e) => setWorkPhone(e.target.value)}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="fax" className="text-xs">Fax</Label>
                <Input 
                  id="fax" 
                  name="fax" 
                  type="tel" 
                  value={fax}
                  onChange={(e) => setFax(e.target.value)}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="primary_contact_id" className="text-xs" required>Primary Contact</Label>
                <SelectShadcn
                  value={primaryContactId}
                  onValueChange={(value) => {
                    setPrimaryContactId(value);
                    if (validationErrors.primary_contact_id) {
                      setValidationErrors(prev => ({ ...prev, primary_contact_id: '' }));
                    }
                  }}
                  disabled={loadingContacts || isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${validationErrors.primary_contact_id ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder={loadingContacts ? "Loading contacts..." : contacts.length === 0 ? "No contacts found" : "Select primary contact"} />
                  </SelectTrigger>
                  <SelectContent>
                    {contacts.length === 0 ? (
                      <div className="px-2 py-1.5 text-xs text-gray-500">
                        {loadingContacts ? "Loading..." : "No contacts available. Please create a contact first."}
                      </div>
                    ) : (
                      contacts.filter(c => c.id).map((contact) => (
                        <SelectItem key={contact.id} value={contact.id}>
                          {contact.contact_name || 'Unnamed Contact'}
                          {contact.identification_number && (
                            <span className="text-xs text-gray-500 ml-2">({contact.identification_number})</span>
                          )}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </SelectShadcn>
                {validationErrors.primary_contact_id && (
                  <p className="mt-1 text-xs text-red-600">{validationErrors.primary_contact_id}</p>
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
                    name="street_address_line_1" 
                    value={street1} 
                    onChange={(e) => {
                      setStreet1(e.target.value);
                      if (validationErrors.street_address_line_1) {
                        setValidationErrors(prev => ({ ...prev, street_address_line_1: '' }));
                      }
                    }}
                    className="py-1 text-xs"
                    error={validationErrors.street_address_line_1}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-6">
                  <Label htmlFor="street_address_line_2" className="text-xs">
                    <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                  </Label>
                  <Input 
                    id="street_address_line_2" 
                    name="street_address_line_2" 
                    value={street2} 
                    onChange={(e) => setStreet2(e.target.value)} 
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="city" className="text-xs" required>City</Label>
                  <Input 
                    id="city" 
                    name="city" 
                    value={city} 
                    onChange={(e) => {
                      setCity(e.target.value);
                      if (validationErrors.city) {
                        setValidationErrors(prev => ({ ...prev, city: '' }));
                      }
                    }}
                    className="py-1 text-xs"
                    error={validationErrors.city}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="state" className="text-xs" required>State</Label>
                  <Input 
                    id="state" 
                    name="state" 
                    value={state} 
                    onChange={(e) => {
                      setState(e.target.value);
                      if (validationErrors.state) {
                        setValidationErrors(prev => ({ ...prev, state: '' }));
                      }
                    }}
                    className="py-1 text-xs"
                    error={validationErrors.state}
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="zip_code" className="text-xs">Zip Code</Label>
                  <Input 
                    id="zip_code" 
                    name="zip_code" 
                    value={zip} 
                    onChange={(e) => setZip(e.target.value)} 
                    className="py-1 text-xs"
                    disabled={isReadOnly}
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="country" className="text-xs" required>Country</Label>
                  <SelectShadcn 
                    value={country} 
                    onValueChange={(value: string) => {
                      setCountry(value);
                      if (validationErrors.country) {
                        setValidationErrors(prev => ({ ...prev, country: '' }));
                      }
                    }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${validationErrors.country ? 'border-red-300 bg-red-50' : ''}`}>
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
                  {validationErrors.country && (
                    <p className="mt-1 text-xs text-red-600">{validationErrors.country}</p>
                  )}
                </div>
              </div>
            </div>

            {/* Metadata Section */}
            <div className="col-span-12 mt-4">
              <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                <div className="col-span-3">
                  <Label htmlFor="date_created" className="text-xs">Date Created</Label>
                  <Input id="date_created" name="date_created" className="py-1 text-xs" disabled />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="vendor_id" className="text-xs">Vendor ID</Label>
                  <Input id="vendor_id" name="vendor_id" className="py-1 text-xs" disabled />
                </div>
              </div>
            </div>
          </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

