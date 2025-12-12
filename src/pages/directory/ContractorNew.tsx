import { useState } from 'react';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';

export default function ContractorNew() {
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
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

  return (
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Contractor Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Create a new contractor
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
            onClick={() => {
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
              
              console.log('Save contractor');
              // Show success notification
              useUIStore.getState().addNotification({
                type: 'success',
                title: 'Contractor saved successfully',
                message: 'The contractor has been saved and is now available in your directory.',
              });
              router.navigate('/directory/contractors');
            }}
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
                      <Input id="date_of_hire" name="date_of_hire" type="date" className="py-1 text-xs" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="date_of_birth" className="text-xs">Date of Birth</Label>
                      <Input id="date_of_birth" name="date_of_birth" type="date" className="py-1 text-xs" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="identification_number" className="text-xs">ID Number</Label>
                      <Input id="identification_number" name="identification_number" className="py-1 text-xs" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="company_number" className="text-xs">Company Number</Label>
                      <Input id="company_number" name="company_number" className="py-1 text-xs" />
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
                    <Input id="primary_email" name="primary_email" type="email" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="secondary_email" className="text-xs">Secondary Email</Label>
                    <Input id="secondary_email" name="secondary_email" type="email" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="phone" className="text-xs">Phone</Label>
                    <Input id="phone" name="phone" type="tel" className="py-1 text-xs" />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-3">
                    <Label htmlFor="extension" className="text-xs">Extension</Label>
                    <Input id="extension" name="extension" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="cell_phone" className="text-xs">Cell Phone</Label>
                    <Input id="cell_phone" name="cell_phone" type="tel" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="fax" className="text-xs">Fax</Label>
                    <Input id="fax" name="fax" type="tel" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="preferred_notification_method" className="text-xs">Preferred Notification Method</Label>
                    <Select
                      id="preferred_notification_method"
                      name="preferred_notification_method"
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

