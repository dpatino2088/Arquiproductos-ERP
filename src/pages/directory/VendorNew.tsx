import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';

export default function VendorNew() {
  const [activeTab, setActiveTab] = useState<'details' | 'billing'>('details');
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
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

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

  return (
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Vendor Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Create a new vendor
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/vendors')}
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
              
              if (!vendorName.trim()) {
                errors.vendor_name = 'Vendor name is required';
                missingFields.push('Vendor Name');
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
              
              console.log('Save vendor');
              // Show success notification
              useUIStore.getState().addNotification({
                type: 'success',
                title: 'Vendor saved successfully',
                message: 'The vendor has been saved and is now available in your directory.',
              });
              router.navigate('/directory/vendors');
            }}
          >
            Save and Close
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
        <div className="p-4">
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
                      disabled={billingSameAsStreet}
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
                      disabled={billingSameAsStreet}
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
                      disabled={billingSameAsStreet}
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
                      disabled={billingSameAsStreet}
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
                      disabled={billingSameAsStreet}
                    />
                  </div>

                  <div>
                    <Label htmlFor="billing_country" className="text-xs">Billing Country</Label>
                    <SelectShadcn
                      value={billingCountry}
                      onValueChange={(value: string) => setBillingCountry(value)}
                      disabled={billingSameAsStreet}
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
                <Label htmlFor="website" className="text-xs">Website</Label>
                <Input 
                  id="website" 
                  name="website" 
                  type="url" 
                  value={website}
                  onChange={(e) => setWebsite(e.target.value)}
                  className="py-1 text-xs" 
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
                    onValueChange={(value: string) => {
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

