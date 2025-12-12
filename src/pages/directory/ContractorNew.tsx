import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useContractorById } from '../../hooks/useDirectory';
import { queryClient } from '../../lib/query-client';

export default function ContractorNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const [contractorId, setContractorId] = useState<string | null>(null);

  // Get contractor ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/directory\/contractors\/(?:edit\/)?([^/]+)/);
    if (match && match[1] && match[1] !== 'new') {
      setContractorId(match[1]);
    }
  }, []);

  // Use hook to fetch contractor data if editing
  const { contractor, isLoading: isLoadingContractor, isError: isErrorContractor } = useContractorById({
    id: contractorId,
    organizationId: activeOrganizationId,
  });

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to {contractorId ? 'edit' : 'create'} a contractor.</p>
        </div>
      </div>
    );
  }

  // Show loading state while fetching contractor data
  if (contractorId && isLoadingContractor) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading contractor...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state if failed to load contractor
  if (contractorId && isErrorContractor) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading contractor</p>
          <p className="text-sm text-red-700">Could not load the contractor. Please try again.</p>
          <button
            onClick={() => router.navigate('/directory/contractors')}
            className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:opacity-90"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  const [activeTab, setActiveTab] = useState<'contractor' | 'primary_contact'>('contractor');
  const [contractorName, setContractorName] = useState('');
  const [contactName, setContactName] = useState('');
  const [position, setPosition] = useState('');
  const [street1, setStreet1] = useState('');
  const [street2, setStreet2] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [zip, setZip] = useState('');
  const [country, setCountry] = useState('');
  const [primaryEmail, setPrimaryEmail] = useState('');
  const [secondaryEmail, setSecondaryEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [extension, setExtension] = useState('');
  const [cellPhone, setCellPhone] = useState('');
  const [fax, setFax] = useState('');
  const [preferredNotificationMethod, setPreferredNotificationMethod] = useState('');
  const [dateOfHire, setDateOfHire] = useState('');
  const [dateOfBirth, setDateOfBirth] = useState('');
  const [identificationNumber, setIdentificationNumber] = useState('');
  const [companyNumber, setCompanyNumber] = useState('');
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  // Load contractor data when contractor is fetched
  useEffect(() => {
    if (contractor) {
      setContractorName(contractor.contractor_company_name || '');
      setContactName(contractor.contact_name || '');
      setPosition(contractor.position || '');
      setStreet1(contractor.street_address_line_1 || '');
      setStreet2(contractor.street_address_line_2 || '');
      setCity(contractor.city || '');
      setState(contractor.state || '');
      setZip(contractor.zip_code || '');
      setCountry(contractor.country || '');
      setPrimaryEmail(contractor.primary_email || '');
      setSecondaryEmail(contractor.secondary_email || '');
      setPhone(contractor.phone || '');
      setExtension(contractor.extension || '');
      setCellPhone(contractor.cell_phone || '');
      setFax(contractor.fax || '');
      setPreferredNotificationMethod(contractor.preferred_notification_method || '');
      setDateOfHire(contractor.date_of_hire || '');
      setDateOfBirth(contractor.date_of_birth || '');
      setIdentificationNumber(contractor.ein || '');
      setCompanyNumber(contractor.company_number || '');
    }
  }, [contractor]);

  const handleSave = async () => {
    // Validate required fields
    const errors: Record<string, string> = {};
    const missingFields: string[] = [];
    
    if (!contractorName.trim()) {
      errors.contractor_company_name = 'Contractor company name is required';
      missingFields.push('Contractor Company Name');
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

      const contractorData: any = {
        organization_id: activeOrganizationId,
        contractor_company_name: contractorName.trim(),
        contact_name: contactName.trim() || null,
        position: position.trim() || null,
        street_address_line_1: street1.trim(),
        street_address_line_2: street2.trim() || null,
        city: city.trim(),
        state: state.trim(),
        zip_code: zip.trim() || null,
        country: country.trim(),
        primary_email: primaryEmail.trim() || null,
        secondary_email: secondaryEmail.trim() || null,
        phone: phone.trim() || null,
        extension: extension.trim() || null,
        cell_phone: cellPhone.trim() || null,
        fax: fax.trim() || null,
        preferred_notification_method: preferredNotificationMethod.trim() || null,
        date_of_hire: dateOfHire || null,
        date_of_birth: dateOfBirth || null,
        ein: identificationNumber.trim() || null,
        company_number: companyNumber.trim() || null,
        updated_at: new Date().toISOString(),
      };

      let result;

      if (contractorId) {
        // Update existing contractor
        result = await supabase
          .from('DirectoryContractors')
          .update(contractorData)
          .eq('id', contractorId)
          .eq('organization_id', activeOrganizationId)
          .select()
          .single();
      } else {
        // Create new contractor
        contractorData.created_at = new Date().toISOString();
        contractorData.deleted = false;
        contractorData.archived = false;

        result = await supabase
          .from('DirectoryContractors')
          .insert([contractorData])
          .select()
          .single();
      }

      if (result.error) {
        if (import.meta.env.DEV) {
          console.error('Error saving contractor:', result.error);
        }
        throw result.error;
      }

      if (import.meta.env.DEV) {
        console.log('Contractor saved successfully:', result.data);
      }
      
      // Invalidate queries to refresh list
      queryClient.invalidateQueries({ queryKey: ['directory-contractors'] });
      
      // Show success notification
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Contractor saved successfully',
        message: `The contractor has been ${contractorId ? 'updated' : 'saved'} and is now available in your directory.`,
      });
      
      router.navigate('/directory/contractors');
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error saving contractor:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving contractor',
        message: err.message || 'Something went wrong while saving. Please try again.',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Contractor Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {contractorId ? 'Edit contractor' : 'Create a new contractor'}
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/contractors')}
            className="text-gray-500 hover:text-gray-700 p-1.5 rounded-lg hover:bg-gray-50 transition-colors"
            title="Close"
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>
          <button
            type="button"
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={handleSave}
            disabled={saving}
          >
            Save and Close
          </button>
        </div>
      </div>

      {/* Main Content Card - Matching Contacts table structure exactly */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Tab Header - Matching Sub bar style from Layout (height: 2.625rem) */}
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
              onClick={() => setActiveTab('contractor')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'contractor'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'contractor' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'contractor' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'contractor'}
              aria-label={`Contractor${activeTab === 'contractor' ? ' (current tab)' : ''}`}
            >
              Contractor
            </button>
            <button
              onClick={() => setActiveTab('primary_contact')}
              className={`transition-colors flex items-center justify-start ${
                activeTab === 'primary_contact'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'primary_contact' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'primary_contact' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'primary_contact'}
              aria-label={`Primary Contact${activeTab === 'primary_contact' ? ' (current tab)' : ''}`}
            >
              Primary Contact
            </button>
          </div>
        </div>

        {/* Form Body - Matching Contacts content structure */}
        <div className="p-4">
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {activeTab === 'contractor' ? (
              <>
                {/* Contractor Tab Content */}
                {/* Top Section */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-6">
                    <Label htmlFor="contractor_company_name" className="text-xs" required>Contractor Company Name</Label>
                    <Input 
                      id="contractor_company_name" 
                      name="contractor_company_name" 
                      value={contractorName}
                      onChange={(e) => {
                        setContractorName(e.target.value);
                        if (validationErrors.contractor_company_name) {
                          setValidationErrors(prev => ({ ...prev, contractor_company_name: '' }));
                        }
                      }}
                      className="py-1 text-xs"
                      error={validationErrors.contractor_company_name}
                    />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="contact_name" className="text-xs">Contact Name</Label>
                    <Input 
                      id="contact_name" 
                      name="contact_name" 
                      value={contactName}
                      onChange={(e) => setContactName(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <Label htmlFor="position" className="text-xs">Position</Label>
                    <Input 
                      id="position" 
                      name="position" 
                      value={position}
                      onChange={(e) => setPosition(e.target.value)}
                      className="py-1 text-xs" 
                    />
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
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="country" className="text-xs" required>Country</Label>
                      <SelectShadcn 
                        value={country} 
                        onValueChange={(value) => {
                          setCountry(value);
                          if (validationErrors.country) {
                            setValidationErrors(prev => ({ ...prev, country: '' }));
                          }
                        }}
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

                {/* Additional Fields Section */}
                <div className="col-span-12 mt-4">
                  <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                    <div className="col-span-3">
                      <Label htmlFor="date_of_hire" className="text-xs">Date of Hire</Label>
                      <Input 
                        id="date_of_hire" 
                        name="date_of_hire" 
                        type="date" 
                        value={dateOfHire}
                        onChange={(e) => setDateOfHire(e.target.value)}
                        className="py-1 text-xs" 
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="date_of_birth" className="text-xs">Date of Birth</Label>
                      <Input 
                        id="date_of_birth" 
                        name="date_of_birth" 
                        type="date" 
                        value={dateOfBirth}
                        onChange={(e) => setDateOfBirth(e.target.value)}
                        className="py-1 text-xs" 
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
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="company_number" className="text-xs">Company Number</Label>
                      <Input 
                        id="company_number" 
                        name="company_number" 
                        value={companyNumber}
                        onChange={(e) => setCompanyNumber(e.target.value)}
                        className="py-1 text-xs" 
                      />
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
                      <Label htmlFor="contractor_id" className="text-xs">Contractor ID</Label>
                      <Input id="contractor_id" name="contractor_id" className="py-1 text-xs" disabled />
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <>
                {/* Primary Contact Tab Content */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <Label htmlFor="primary_email" className="text-xs" required>Primary Email</Label>
                    <Input 
                      id="primary_email" 
                      name="primary_email" 
                      type="email" 
                      value={primaryEmail}
                      onChange={(e) => setPrimaryEmail(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="secondary_email" className="text-xs">Secondary Email</Label>
                    <Input 
                      id="secondary_email" 
                      name="secondary_email" 
                      type="email" 
                      value={secondaryEmail}
                      onChange={(e) => setSecondaryEmail(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="phone" className="text-xs">Phone</Label>
                    <Input 
                      id="phone" 
                      name="phone" 
                      type="tel" 
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-3">
                    <Label htmlFor="extension" className="text-xs">Extension</Label>
                    <Input 
                      id="extension" 
                      name="extension" 
                      value={extension}
                      onChange={(e) => setExtension(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="cell_phone" className="text-xs">Cell Phone</Label>
                    <Input 
                      id="cell_phone" 
                      name="cell_phone" 
                      type="tel" 
                      value={cellPhone}
                      onChange={(e) => setCellPhone(e.target.value)}
                      className="py-1 text-xs" 
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
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="preferred_notification_method" className="text-xs">Preferred Notification Method</Label>
                    <Select
                      id="preferred_notification_method"
                      name="preferred_notification_method"
                      value={preferredNotificationMethod}
                      onChange={(e) => setPreferredNotificationMethod(e.target.value)}
                      options={[
                        { value: 'not_selected', label: 'Not Selected' },
                        { value: 'email', label: 'Email' },
                        { value: 'phone', label: 'Phone' },
                        { value: 'sms', label: 'SMS' }
                      ]}
                      className="py-1 text-xs"
                    />
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

