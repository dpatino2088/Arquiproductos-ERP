import { useState, useEffect } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase';
import { useCompanyStore } from '../../stores/company-store';
import { useUIStore } from '../../stores/ui-store';
import { COUNTRIES } from '../../lib/constants';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';

interface Contact {
  id: string;
  customer_name: string;
  identification_number?: string;
}

interface Customer {
  id: string;
  company_name: string;
}

interface Contractor {
  id: string;
  contractor_company_name: string;
}

export default function SiteNew() {
  const { currentCompany } = useCompanyStore();
  const [activeTab, setActiveTab] = useState<'site' | 'primary_contact' | 'billing'>('site');
  const [siteName, setSiteName] = useState('');
  const [zone, setZone] = useState('');
  const [relatedCustomerId, setRelatedCustomerId] = useState<string | null>(null);
  const [relatedContactId, setRelatedContactId] = useState<string | null>(null);
  const [relatedContractorId, setRelatedContractorId] = useState<string | null>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [contractors, setContractors] = useState<Contractor[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(false);
  const [loadingContacts, setLoadingContacts] = useState(false);
  const [loadingContractors, setLoadingContractors] = useState(false);
  const [billingSameAsStreet, setBillingSameAsStreet] = useState(false);
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
            Site Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Create a new site
          </p>
        </div>
        
        {/* Action Buttons - Matching Contacts page */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/directory/sites')}
            className="text-gray-500 hover:text-gray-700 p-1.5 rounded-lg hover:bg-gray-50 transition-colors"
            title="Close"
          >
            <X style={{ width: '18px', height: '18px' }} />
          </button>
          <button
            type="button"
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={async () => {
              // Validate required fields
              const errors: Record<string, string> = {};
              const missingFields: string[] = [];
              
              if (!siteName.trim()) {
                errors.site_name = 'Site name is required';
                missingFields.push('Site Name');
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
              
              // Save site to Supabase
              if (!currentCompany?.id) {
                useUIStore.getState().addNotification({
                  type: 'error',
                  title: 'No organization configured',
                  message: 'Please configure an organization in Settings > Organization Profile.',
                });
                return;
              }

              try {
                const siteData = {
                  organization_id: currentCompany.id,
                  site_name: siteName.trim(),
                  zone: zone.trim() || null,
                  customer_id: relatedCustomerId || null,
                  contact_id: relatedContactId || null,
                  contractor_id: relatedContractorId || null,
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
                  deleted: false,
                  archived: false,
                };

                const { data, error } = await supabase
                  .from('DirectorySites')
                  .insert([siteData])
                  .select()
                  .single();

                if (error) {
                  console.error('Error saving site:', error);
                  throw error;
                }

                console.log('Site saved successfully:', data);
                
                // Show success notification
                useUIStore.getState().addNotification({
                  type: 'success',
                  title: 'Site saved successfully',
                  message: 'The site has been saved and is now available in your directory.',
                });
                
                router.navigate('/directory/sites');
              } catch (err: any) {
                console.error('Error saving site:', err);
                useUIStore.getState().addNotification({
                  type: 'error',
                  title: 'Error saving site',
                  message: err.message || 'Something went wrong while saving. Please try again.',
                });
              }
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
              onClick={() => setActiveTab('site')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'site'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'site' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'site' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'site'}
              aria-label={`Site${activeTab === 'site' ? ' (current tab)' : ''}`}
            >
              Site
            </button>
            <button
              onClick={() => setActiveTab('primary_contact')}
              className={`transition-colors flex items-center justify-start border-r ${
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
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'primary_contact' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'primary_contact'}
              aria-label={`Primary Contact${activeTab === 'primary_contact' ? ' (current tab)' : ''}`}
            >
              Primary Contact
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
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {activeTab === 'site' ? (
              <>
                {/* Site Tab Content */}
                {/* SECTION: SITE INFORMATION - Row 1 */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-6">
                    <Label htmlFor="site_name" className="text-xs" required>Site Name</Label>
                    <Input 
                      id="site_name" 
                      name="site_name" 
                      value={siteName}
                      onChange={(e) => {
                        setSiteName(e.target.value);
                        if (validationErrors.site_name) {
                          setValidationErrors(prev => ({ ...prev, site_name: '' }));
                        }
                      }}
                      className="py-1 text-xs"
                      error={validationErrors.site_name}
                    />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="zone" className="text-xs">Zone</Label>
                    <Input 
                      id="zone" 
                      name="zone" 
                      value={zone}
                      onChange={(e) => setZone(e.target.value)}
                      className="py-1 text-xs" 
                    />
                  </div>
                </div>

                {/* SECTION: RELATED ENTITIES - Row 2 (Optional) */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3 mt-4">
                  <div className="col-span-4">
                    <Label htmlFor="related_customer_id" className="text-xs">Related Customer (Optional)</Label>
                    <SelectShadcn
                      value={relatedCustomerId || 'none'}
                      onValueChange={(value) => setRelatedCustomerId(value === 'none' ? null : value)}
                      disabled={loadingCustomers}
                    >
                      <SelectTrigger className="py-1 text-xs">
                        <SelectValue placeholder={loadingCustomers ? "Loading..." : customers.length === 0 ? "No customers available" : "Select customer (optional)"} />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">None</SelectItem>
                        {customers.map((customer) => (
                          <SelectItem key={customer.id} value={customer.id}>
                            {customer.company_name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="related_contact_id" className="text-xs">Related Contact (Optional)</Label>
                    <SelectShadcn
                      value={relatedContactId || 'none'}
                      onValueChange={(value) => setRelatedContactId(value === 'none' ? null : value)}
                      disabled={loadingContacts}
                    >
                      <SelectTrigger className="py-1 text-xs">
                        <SelectValue placeholder={loadingContacts ? "Loading..." : contacts.length === 0 ? "No contacts available" : "Select contact (optional)"} />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">None</SelectItem>
                        {contacts.map((contact) => (
                          <SelectItem key={contact.id} value={contact.id}>
                            {contact.customer_name}
                            {contact.identification_number && (
                              <span className="text-xs text-gray-500 ml-2">({contact.identification_number})</span>
                            )}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="related_contractor_id" className="text-xs">Related Contractor (Optional)</Label>
                    <SelectShadcn
                      value={relatedContractorId || 'none'}
                      onValueChange={(value) => setRelatedContractorId(value === 'none' ? null : value)}
                      disabled={loadingContractors}
                    >
                      <SelectTrigger className="py-1 text-xs">
                        <SelectValue placeholder={loadingContractors ? "Loading..." : contractors.length === 0 ? "No contractors available" : "Select contractor (optional)"} />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">None</SelectItem>
                        {contractors.map((contractor) => (
                          <SelectItem key={contractor.id} value={contractor.id}>
                            {contractor.contractor_company_name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                </div>

                {/* SECTION: LOCATION */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                    {/* Row 2 */}
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
                    {/* Row 3 */}
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
                        value={country || undefined} 
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
              </>
            ) : activeTab === 'billing' ? (
              <>
                {/* Billing Address Section */}
                <div className="col-span-12">
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
                        value={billingCountry || undefined}
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
                {/* Primary Contact Tab Content */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  {/* Row 1: Primary Contact fields */}
                  <div className="col-span-4">
                    <Label htmlFor="primary_contact_name" className="text-xs">Name</Label>
                    <Input id="primary_contact_name" name="primary_contact_name" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="primary_contact_phone" className="text-xs">Phone</Label>
                    <Input id="primary_contact_phone" name="primary_contact_phone" type="tel" className="py-1 text-xs" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="primary_contact_email" className="text-xs">Email</Label>
                    <Input id="primary_contact_email" name="primary_contact_email" type="email" className="py-1 text-xs" />
                  </div>
                </div>

                {/* Row 2: Site ID */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <Label htmlFor="site_id" className="text-xs">Site ID</Label>
                    <Input id="site_id" name="site_id" className="py-1 text-xs" disabled />
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

