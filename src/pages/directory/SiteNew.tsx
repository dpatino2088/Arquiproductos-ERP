import { useState } from 'react';
import { router } from '../../lib/router';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Checkbox from '../../components/ui/Checkbox';
import Label from '../../components/ui/Label';

export default function SiteNew() {
  const [billingSameAsStreet, setBillingSameAsStreet] = useState(false);
  const [activeTab, setActiveTab] = useState<'site' | 'primary_contact'>('site');

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
            onClick={() => {
              console.log('Save site');
              router.navigate('/directory/sites');
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
        <div className="p-5" style={{ paddingBottom: '29px' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-3">
            {activeTab === 'site' ? (
              <>
                {/* Site Tab Content */}
                {/* SECTION: SITE INFORMATION - Row 1 */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-6">
                    <Label htmlFor="site_name" required>Site Name</Label>
                    <Input id="site_name" name="site_name" className="h-9" />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="zone">Zone</Label>
                    <Input id="zone" name="zone" className="h-9" />
                  </div>
                </div>

                {/* SECTION: LOCATION */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    {/* Row 2 */}
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
                    {/* Row 3 */}
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
                      <Input id="country" name="country" defaultValue="Panamá" className="h-9" />
                    </div>
                  </div>
                </div>

                {/* SECTION: BILLING */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Billing</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    {/* Row 4 */}
                    <div className="col-span-6">
                      <Label htmlFor="billing_contact">Billing Contact</Label>
                      <Input id="billing_contact" name="billing_contact" className="h-9" />
                    </div>
                    {/* Row 5 */}
                    <div className="col-span-12 mb-1.5">
                      <Checkbox
                        id="billing_same_as_street"
                        name="billing_same_as_street"
                        label="Same as Street"
                        checked={billingSameAsStreet}
                        onChange={(e) => setBillingSameAsStreet(e.target.checked)}
                      />
                    </div>
                    {/* Row 6 */}
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
                    {/* Row 7 */}
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
                        defaultValue="Panamá"
                        className="h-9"
                        disabled={billingSameAsStreet}
                      />
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
                    <Label htmlFor="primary_contact_name">Name</Label>
                    <Input id="primary_contact_name" name="primary_contact_name" className="h-9" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="primary_contact_phone">Phone</Label>
                    <Input id="primary_contact_phone" name="primary_contact_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="primary_contact_email">Email</Label>
                    <Input id="primary_contact_email" name="primary_contact_email" type="email" className="h-9" />
                  </div>
                </div>

                {/* Row 2: Site ID */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-2 col-start-3">
                    <Label htmlFor="site_id">Site ID</Label>
                    <Input id="site_id" name="site_id" className="h-9" disabled />
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

