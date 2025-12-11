import { useState } from 'react';
import { router } from '../../lib/router';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';

export default function CustomerNew() {
  const [billingSameAsStreet, setBillingSameAsStreet] = useState(false);

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
            className="px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={() => {
              console.log('Save customer');
              router.navigate('/directory/customers');
            }}
          >
            Save and Close
          </button>
        </div>
      </div>

      {/* Main Content Card - Matching Contacts table structure exactly */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Form Body - Matching Contacts content structure */}
        <div className="p-5" style={{ paddingBottom: '29px' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-3">
            {/* Customer Mode - Top Section */}
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
                  <Input id="country" name="country" className="h-9" />
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
          </div>
        </div>
      </div>
    </div>
  );
}

