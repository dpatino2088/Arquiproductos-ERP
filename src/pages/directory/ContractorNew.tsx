import { useState } from 'react';
import { router } from '../../lib/router';
import { X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import Label from '../../components/ui/Label';

export default function ContractorNew() {
  const [activeTab, setActiveTab] = useState<'contractor' | 'primary_contact'>('contractor');

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
              console.log('Save contractor');
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
        <div className="p-5" style={{ paddingBottom: '29px' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-3">
            {activeTab === 'contractor' ? (
              <>
                {/* Contractor Tab Content */}
                {/* Top Section */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-6">
                    <Label htmlFor="contractor_company_name" required>Contractor Company Name</Label>
                    <Input id="contractor_company_name" name="contractor_company_name" className="h-9" />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="contact_name">Contact Name</Label>
                    <Input id="contact_name" name="contact_name" className="h-9" />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <Label htmlFor="position">Position</Label>
                    <Input id="position" name="position" className="h-9" />
                  </div>
                </div>

                {/* Location Section */}
                <div className="col-span-12 mt-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-6">
                      <Label htmlFor="street_address_line_1">Street Address</Label>
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
                      <Input id="country" name="country" defaultValue="Panamá" className="h-9" />
                    </div>
                  </div>
                </div>

                {/* Additional Fields Section */}
                <div className="col-span-12 mt-4">
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-3">
                      <Label htmlFor="date_of_hire">Date of Hire</Label>
                      <Input id="date_of_hire" name="date_of_hire" type="date" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="date_of_birth">Date of Birth</Label>
                      <Input id="date_of_birth" name="date_of_birth" type="date" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="ein">EIN</Label>
                      <Input id="ein" name="ein" className="h-9" />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="company_number">Company Number</Label>
                      <Input id="company_number" name="company_number" className="h-9" />
                    </div>
                  </div>
                </div>

                {/* Metadata Section */}
                <div className="col-span-12 mt-4">
                  <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                    <div className="col-span-3">
                      <Label htmlFor="date_created">Date Created</Label>
                      <Input id="date_created" name="date_created" className="h-9" disabled />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="contractor_id">Contractor ID</Label>
                      <Input id="contractor_id" name="contractor_id" className="h-9" disabled />
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <>
                {/* Primary Contact Tab Content */}
                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <Label htmlFor="primary_email" required>Primary Email</Label>
                    <Input id="primary_email" name="primary_email" type="email" className="h-9" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="secondary_email">Secondary Email</Label>
                    <Input id="secondary_email" name="secondary_email" type="email" className="h-9" />
                  </div>
                  <div className="col-span-4">
                    <Label htmlFor="phone">Phone</Label>
                    <Input id="phone" name="phone" type="tel" className="h-9" />
                  </div>
                </div>

                <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-3">
                    <Label htmlFor="extension">Extension</Label>
                    <Input id="extension" name="extension" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="cell_phone">Cell Phone</Label>
                    <Input id="cell_phone" name="cell_phone" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="fax">Fax</Label>
                    <Input id="fax" name="fax" type="tel" className="h-9" />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="preferred_notification_method">Preferred Notification Method</Label>
                    <Select
                      id="preferred_notification_method"
                      name="preferred_notification_method"
                      options={[
                        { value: 'not_selected', label: 'Not Selected' },
                        { value: 'email', label: 'Email' },
                        { value: 'phone', label: 'Phone' },
                        { value: 'sms', label: 'SMS' }
                      ]}
                      className="h-9"
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

