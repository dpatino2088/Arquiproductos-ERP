import { useState } from 'react';
import { router } from '../../lib/router';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';

export default function ContactNew() {
  const [mode, setMode] = useState<'company' | 'individual'>('individual');
  const [billingSameAsStreet, setBillingSameAsStreet] = useState(false);

  return (
    <div className="p-6">
      {/* Header - Matching Contacts page layout */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {mode === 'company' ? 'Company Details' : 'Contact Details'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {mode === 'company' ? 'Create a new company contact' : 'Create a new individual contact'}
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
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={() => {
              console.log('Save contact');
              router.navigate('/directory/contacts');
            }}
          >
            Save and Close
          </button>
        </div>
      </div>

      {/* Main Content Card - Matching Contacts table structure exactly */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Mode Toggle Header - Matching Sub bar style from Layout (height: 2.625rem) */}
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
              onClick={() => setMode('company')}
              className={`transition-colors flex items-center justify-start border-r ${
                mode === 'company'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: mode === 'company' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: mode === 'company' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={mode === 'company'}
              aria-label={`Company${mode === 'company' ? ' (current tab)' : ''}`}
            >
              Company
            </button>
            <button
              onClick={() => setMode('individual')}
              className={`transition-colors flex items-center justify-start ${
                mode === 'individual'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: mode === 'individual' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: mode === 'individual' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={mode === 'individual'}
              aria-label={`Individual${mode === 'individual' ? ' (current tab)' : ''}`}
            >
              Individual
            </button>
          </div>
        </div>

        {/* Form Body - Matching Contacts content structure */}
        <div className="p-5" style={{ paddingBottom: '29px' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-3">
            {mode === 'individual' ? (
              <>
                {/* Individual Mode - Top Section */}
                {/* Row 1: Identity fields */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-1">
                    <Label htmlFor="title">Title</Label>
                    <Select
                      id="title"
                      name="title"
                      options={[
                        { value: 'not_selected', label: 'Not Selected' },
                        { value: 'mr', label: 'Mr.' },
                        { value: 'mrs', label: 'Mrs.' },
                        { value: 'ms', label: 'Ms.' },
                        { value: 'dr', label: 'Dr.' }
                      ]}
                      className="h-9"
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="first_name" required>First Name</Label>
                    <Input id="first_name" name="first_name" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="last_name" required>Last Name</Label>
                    <Input id="last_name" name="last_name" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="id_number">ID Number</Label>
                    <Input id="id_number" name="id_number" className="h-9" />
                  </div>
                  <div className="col-span-2">
                    <Label htmlFor="customer_type">Customer Type</Label>
                    <Select
                      id="customer_type"
                      name="customer_type"
                      options={[{ value: 'customer', label: 'Customer' }]}
                      className="h-9"
                    />
                  </div>
                </div>

                {/* Row 2: Phones and Email */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-3">
                    <Label htmlFor="primary_phone">Primary Phone</Label>
                    <Input id="primary_phone" name="primary_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="cell_phone">Cell Phone</Label>
                    <Input id="cell_phone" name="cell_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="alt_phone">Alt Phone</Label>
                    <Input id="alt_phone" name="alt_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="email">Email</Label>
                    <Input id="email" name="email" type="email" className="h-9" />
                  </div>
                </div>

                {/* Location Section */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-6">
                      <Label htmlFor="street_address_line_1" required>Street Address</Label>
                      <Input id="street_address_line_1" name="street_address_line_1" className="h-9" />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="street_address_line_2">
                        <span className="text-gray-500" style={{ fontSize: '10px' }}>Street Address 2 (optional)</span>
                      </Label>
                      <Input id="street_address_line_2" name="street_address_line_2" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="city">City</Label>
                      <Input id="city" name="city" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="state">State</Label>
                      <Input id="state" name="state" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="zip_code">Zip Code</Label>
                      <Input id="zip_code" name="zip_code" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="country">Country</Label>
                      <Input id="country" name="country"  className="h-9" />
                    </div>
                  </div>
                </div>

                {/* Billing Address Section */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing Address</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-12 mb-1.5">
                      <Checkbox
                        id="billing_same_as_street"
                        name="billing_same_as_street"
                        label="Same as Street"
                        checked={billingSameAsStreet}
                        onChange={(e) => setBillingSameAsStreet(e.target.checked)}
                      />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="billing_street_address_line_1">Street Address</Label>
                      <Input
                        id="billing_street_address_line_1"
                        name="billing_street_address_line_1"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="billing_street_address_line_2">
                        <span className="text-gray-500" style={{ fontSize: '10px' }}>Street Address 2 (optional)</span>
                      </Label>
                      <Input
                        id="billing_street_address_line_2"
                        name="billing_street_address_line_2"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_city">City</Label>
                      <Input
                        id="billing_city"
                        name="billing_city"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_state">State</Label>
                      <Input
                        id="billing_state"
                        name="billing_state"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_zip_code">Zip Code</Label>
                      <Input
                        id="billing_zip_code"
                        name="billing_zip_code"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_country">Country</Label>
                      <Input
                        id="billing_country"
                        name="billing_country"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <>
                {/* Company Mode - Top Section */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-6">
                    <Label htmlFor="company_name" required>Company Name</Label>
                    <Input id="company_name" name="company_name" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="ein">EIN</Label>
                    <Input id="ein" name="ein" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="customer_type">Customer Type</Label>
                    <Select
                      id="customer_type"
                      name="customer_type"
                      options={[{ value: 'customer', label: 'Customer' }]}
                      className="h-9"
                    />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-3">
                    <Label htmlFor="website">Website</Label>
                    <Input id="website" name="website" type="url" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="email">Email</Label>
                    <Input id="email" name="email" type="email" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="company_phone">Company Phone</Label>
                    <Input id="company_phone" name="company_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="alt_phone">Alt Phone</Label>
                    <Input id="alt_phone" name="alt_phone" type="tel" className="h-9" />
                  </div>
                </div>

                {/* Location Section */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-6">
                      <Label htmlFor="street_address_line_1" required>Street Address</Label>
                      <Input id="street_address_line_1" name="street_address_line_1" className="h-9" />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="street_address_line_2">
                        <span className="text-gray-500" style={{ fontSize: '10px' }}>Street Address 2 (optional)</span>
                      </Label>
                      <Input id="street_address_line_2" name="street_address_line_2" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="city">City</Label>
                      <Input id="city" name="city" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="state">State</Label>
                      <Input id="state" name="state" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="zip_code">Zip Code</Label>
                      <Input id="zip_code" name="zip_code" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="country">Country</Label>
                      <Input id="country" name="country"  className="h-9" />
                    </div>
                  </div>
                </div>

                {/* Billing Address Section */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing Address</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-12 mb-1.5">
                      <Checkbox
                        id="billing_same_as_street"
                        name="billing_same_as_street"
                        label="Same as Street"
                        checked={billingSameAsStreet}
                        onChange={(e) => setBillingSameAsStreet(e.target.checked)}
                      />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="billing_street_address_line_1">Street Address</Label>
                      <Input
                        id="billing_street_address_line_1"
                        name="billing_street_address_line_1"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-6">
                      <Label htmlFor="billing_street_address_line_2">
                        <span className="text-gray-500" style={{ fontSize: '10px' }}>Street Address 2 (optional)</span>
                      </Label>
                      <Input
                        id="billing_street_address_line_2"
                        name="billing_street_address_line_2"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_city">City</Label>
                      <Input
                        id="billing_city"
                        name="billing_city"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_state">State</Label>
                      <Input
                        id="billing_state"
                        name="billing_state"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_zip_code">Zip Code</Label>
                      <Input
                        id="billing_zip_code"
                        name="billing_zip_code"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="billing_country">Country</Label>
                      <Input
                        id="billing_country"
                        name="billing_country"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
                    </div>
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

