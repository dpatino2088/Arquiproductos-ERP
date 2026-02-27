import { useState, useEffect, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDirectoryVendors, type VendorInput } from '../../hooks/useDirectoryVendors';
import { useManufacturers } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Building, Store, Building2 } from 'lucide-react';
import { COUNTRIES } from '../../lib/constants';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

const PAYMENT_TERMS_OPTIONS = [
  { value: 'prepayment', label: 'Pre-payment' },
  { value: 'net_15', label: 'Net 15' },
  { value: 'net_30', label: 'Net 30' },
  { value: 'net_45', label: 'Net 45' },
  { value: 'net_60', label: 'Net 60' },
  { value: 'net_90', label: 'Net 90' },
  { value: 'cod', label: 'COD (Cash on Delivery)' },
  { value: 'cia', label: 'CIA (Cash in Advance)' },
  { value: 'upon_receipt', label: 'Upon Receipt' },
];

const DELIVERY_TERMS_OPTIONS = [
  { value: 'exw', label: 'EXW (Ex Works)' },
  { value: 'fob', label: 'FOB (Free on Board)' },
  { value: 'fca', label: 'FCA (Free Carrier)' },
  { value: 'cif', label: 'CIF (Cost, Insurance & Freight)' },
  { value: 'cpt', label: 'CPT (Carriage Paid To)' },
  { value: 'dap', label: 'DAP (Delivered at Place)' },
  { value: 'ddp', label: 'DDP (Delivered Duty Paid)' },
];

const TRANSPORT_OPTIONS = [
  { value: 'customer_pickup', label: 'Customer Pick Up' },
  { value: 'vendor_delivery', label: 'Vendor Delivery' },
  { value: 'freight', label: 'Freight' },
  { value: 'courier', label: 'Courier / Express' },
  { value: 'ocean', label: 'Ocean Freight' },
  { value: 'air', label: 'Air Freight' },
  { value: 'other', label: 'Other' },
];

const TAX_RULE_OPTIONS = [
  { value: 'taxable', label: 'Local Purchase (Taxable)' },
  { value: 'tax_exempt', label: 'International Purchase (No Tax)' },
];

const VENDOR_DRAFT_KEY = 'partner_vendor_draft';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

const vendorSchema = z.object({
  name: z.string().min(1, 'Vendor name is required'),
  ein: z.string().optional().or(z.literal('')),
  website: z.string().optional().or(z.literal('')),
  email: z.string().email('Invalid email').optional().or(z.literal('')),
  work_phone: z.string().optional().or(z.literal('')),
  fax: z.string().optional().or(z.literal('')),
  street_address_line_1: z.string().optional().or(z.literal('')),
  street_address_line_2: z.string().optional().or(z.literal('')),
  city: z.string().optional().or(z.literal('')),
  state: z.string().optional().or(z.literal('')),
  zip_code: z.string().optional().or(z.literal('')),
  country: z.string().optional().or(z.literal('')),
  billing_street_address_line_1: z.string().optional().or(z.literal('')),
  billing_street_address_line_2: z.string().optional().or(z.literal('')),
  billing_city: z.string().optional().or(z.literal('')),
  billing_state: z.string().optional().or(z.literal('')),
  billing_zip_code: z.string().optional().or(z.literal('')),
  billing_country: z.string().optional().or(z.literal('')),
  notes: z.string().optional().or(z.literal('')),
  primary_contact_name: z.string().optional().or(z.literal('')),
  contact_email: z.string().email('Invalid email').optional().or(z.literal('')),
  contact_phone: z.string().optional().or(z.literal('')),
  payment_terms: z.string().optional().or(z.literal('')),
  delivery_terms: z.string().optional().or(z.literal('')),
  transport: z.string().optional().or(z.literal('')),
  tax_rule: z.enum(['taxable', 'tax_exempt']).optional().or(z.literal('')),
  manufacturer_id: z.string().optional().or(z.literal('')),
});

type VendorFormValues = z.infer<typeof vendorSchema>;

interface PartnerVendorFormProps {
  vendorId?: string | null;
}

function loadVendorDraft(): { values: VendorFormValues; billingSameAsLocation: boolean } | null {
  try {
    const raw = sessionStorage.getItem(VENDOR_DRAFT_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { values: VendorFormValues; billingSameAsLocation: boolean };
    return parsed?.values ? parsed : null;
  } catch {
    return null;
  }
}

function saveVendorDraft(values: VendorFormValues, billingSameAsLocation: boolean) {
  try {
    sessionStorage.setItem(VENDOR_DRAFT_KEY, JSON.stringify({ values, billingSameAsLocation }));
  } catch {
    // ignore
  }
}

function clearVendorDraft() {
  try {
    sessionStorage.removeItem(VENDOR_DRAFT_KEY);
  } catch {
    // ignore
  }
}

export default function PartnerVendorForm({ vendorId }: PartnerVendorFormProps) {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { createVendor, updateVendor } = useDirectoryVendors();
  const { manufacturers, loading: loadingManufacturers } = useManufacturers();
  const { addNotification } = useUIStore();
  const [isSaving, setIsSaving] = useState(false);
  const [billingSameAsLocation, setBillingSameAsLocation] = useState(true);
  const draftRestoredRef = useRef(false);
  const savedSuccessfullyRef = useRef(false);

  const isEdit = !!vendorId;

  const form = useForm<VendorFormValues>({
    resolver: zodResolver(vendorSchema),
    defaultValues: { country: 'United States', billing_country: 'United States', tax_rule: 'taxable' },
  });

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  // Restore draft for new vendor form when returning to the page
  useEffect(() => {
    if (isEdit || draftRestoredRef.current) return;
    const draft = loadVendorDraft();
    if (!draft) return;
    draftRestoredRef.current = true;
    form.reset(draft.values);
    setBillingSameAsLocation(draft.billingSameAsLocation);
    addNotification({ type: 'success', title: 'Draft Restored', message: 'Draft restored' });
  }, [isEdit, form, addNotification]);

  // Save draft on unmount (e.g. when switching to another Partners tab)
  useEffect(() => {
    if (isEdit) return;
    return () => {
      if (savedSuccessfullyRef.current) return;
      const values = form.getValues();
      const hasData = values.name?.trim() || values.email?.trim() || values.website?.trim() ||
        values.street_address_line_1?.trim() || values.notes?.trim();
      if (hasData) saveVendorDraft(values, billingSameAsLocation);
    };
  }, [isEdit, billingSameAsLocation, form]);

  useEffect(() => {
    if (!vendorId) return;
    let mounted = true;
    (async () => {
      const { data, error } = await supabase
        .from('DirectoryVendors')
        .select('*')
        .eq('id', vendorId)
        .single();
      if (!mounted || error || !data) return;
      form.reset({
        name: data.name || '',
        ein: data.ein || '',
        website: data.website || '',
        email: data.email || '',
        work_phone: data.work_phone || '',
        fax: data.fax || '',
        street_address_line_1: data.street_address_line_1 || '',
        street_address_line_2: data.street_address_line_2 || '',
        city: data.city || '',
        state: data.state || '',
        zip_code: data.zip_code || '',
        country: data.country || 'United States',
        billing_street_address_line_1: data.billing_street_address_line_1 || '',
        billing_street_address_line_2: data.billing_street_address_line_2 || '',
        billing_city: data.billing_city || '',
        billing_state: data.billing_state || '',
        billing_zip_code: data.billing_zip_code || '',
        billing_country: data.billing_country || 'United States',
        notes: data.notes || '',
        primary_contact_name: data.primary_contact_name || '',
        contact_email: data.contact_email || '',
        contact_phone: data.contact_phone || '',
        payment_terms: data.payment_terms || '',
        delivery_terms: data.delivery_terms || '',
        transport: data.transport || '',
        tax_rule: data.tax_rule || 'taxable',
        manufacturer_id: data.manufacturer_id || '',
      });
      const hasBilling = !!(data.billing_street_address_line_1 || data.billing_city || data.billing_state);
      setBillingSameAsLocation(!hasBilling);
    })();
    return () => { mounted = false; };
  }, [vendorId, form]);

  const handleSave = async () => {
    if (!activeOrganizationId) {
      addNotification({ type: 'error', title: 'No organization', message: 'Please select an organization.' });
      return;
    }

    const isValid = await form.trigger();
    if (!isValid) {
      const errs = form.formState.errors;
      const missing: string[] = [];
      if (errs.name) missing.push('Vendor Name');
      if (errs.email) missing.push('Email');
      addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: missing.length > 0
          ? `Please complete: ${missing.join(', ')}.`
          : 'Please complete all required fields.',
      });
      return;
    }

    setIsSaving(true);
    try {
      const values = form.getValues();
      const { manufacturer_id: mfgId, ...rest } = values;
      const payload: VendorInput = {
        ...rest,
        vendor_name: values.name,
        tax_rule: (values.tax_rule as 'taxable' | 'tax_exempt' | '') || 'taxable',
        manufacturer_id: mfgId?.trim() || null,
      };
      if (billingSameAsLocation) {
        payload.billing_street_address_line_1 = values.street_address_line_1;
        payload.billing_street_address_line_2 = values.street_address_line_2;
        payload.billing_city = values.city;
        payload.billing_state = values.state;
        payload.billing_zip_code = values.zip_code;
        payload.billing_country = values.country;
      }

      if (isEdit) {
        await updateVendor.mutateAsync({ id: vendorId!, ...payload });
        addNotification({ type: 'success', title: 'Vendor Updated', message: 'Vendor updated successfully' });
      } else {
        await createVendor.mutateAsync(payload);
        addNotification({ type: 'success', title: 'Vendor Created', message: 'Vendor created successfully' });
        savedSuccessfullyRef.current = true;
        clearVendorDraft();
      }
      router.navigate('/partners/vendors');
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to save vendor' });
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = form.handleSubmit(handleSave);

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
        <div className="min-w-0">
          <h1 className="text-xl font-semibold text-foreground mb-1">
            Vendor Details
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {isEdit ? 'Edit vendor information' : 'Create a new vendor'}
          </p>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          <button
            type="button"
            onClick={() => router.navigate('/partners/vendors')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          >
            Close
          </button>
          <button
            type="button"
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={handleSubmit}
            disabled={isSaving}
          >
            {isSaving ? 'Saving...' : 'Save and Close'}
          </button>
        </div>
      </div>

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4" style={{ marginLeft: '1.1875rem', marginRight: '1.1875rem' }}>
        <div className="py-6" style={{ paddingLeft: '1.1875rem', paddingRight: '1.1875rem' }}>
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">

            {/* Row 1: Name, EIN, Website */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-6">
                <Label htmlFor="name" className="text-xs" required>Vendor Name</Label>
                <Input
                  id="name"
                  {...form.register('name')}
                  className="py-1 text-xs"
                  error={form.formState.errors.name?.message}
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="ein" className="text-xs">EIN / Tax ID</Label>
                <Input
                  id="ein"
                  {...form.register('ein')}
                  className="py-1 text-xs"
                  placeholder="XX-XXXXXXX"
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="website" className="text-xs">Website</Label>
                <Input
                  id="website"
                  {...form.register('website')}
                  className="py-1 text-xs"
                  placeholder="https://"
                />
              </div>
            </div>

            {/* Row 2: Email, Phone, Fax */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-3">
                <Label htmlFor="email" className="text-xs">Email</Label>
                <Input
                  id="email"
                  {...form.register('email')}
                  type="email"
                  className="py-1 text-xs"
                  error={form.formState.errors.email?.message}
                  placeholder="vendor@example.com"
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="work_phone" className="text-xs">Phone</Label>
                <Input
                  id="work_phone"
                  {...form.register('work_phone')}
                  type="tel"
                  className="py-1 text-xs"
                  placeholder="+1 (555) 000-0000"
                />
              </div>
              <div className="col-span-3">
                <Label htmlFor="fax" className="text-xs">Fax</Label>
                <Input
                  id="fax"
                  {...form.register('fax')}
                  type="tel"
                  className="py-1 text-xs"
                />
              </div>
              <div className="col-span-3" />
            </div>

            {/* Contact Section */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Contact</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="primary_contact_name" className="text-xs">Contact Name</Label>
                  <Input
                    id="primary_contact_name"
                    {...form.register('primary_contact_name')}
                    className="py-1 text-xs"
                    placeholder="Full name"
                  />
                </div>
                <div className="col-span-4">
                  <Label htmlFor="contact_email" className="text-xs">Contact Email</Label>
                  <Input
                    id="contact_email"
                    {...form.register('contact_email')}
                    type="email"
                    className="py-1 text-xs"
                    error={form.formState.errors.contact_email?.message}
                    placeholder="contact@vendor.com"
                  />
                </div>
                <div className="col-span-4">
                  <Label htmlFor="contact_phone" className="text-xs">Contact Phone</Label>
                  <Input
                    id="contact_phone"
                    {...form.register('contact_phone')}
                    type="tel"
                    className="py-1 text-xs"
                    placeholder="+1 (555) 000-0000"
                  />
                </div>
              </div>
            </div>

            {/* Manufacturer Related */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Manufacturer Related</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="manufacturer_id" className="text-xs">Manufacturer</Label>
                  <SelectShadcn
                    value={form.watch('manufacturer_id') || '__none__'}
                    onValueChange={(value) => form.setValue('manufacturer_id', value === '__none__' ? '' : value, { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder={loadingManufacturers ? 'Loading...' : 'Select manufacturer (optional)'} />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">None</SelectItem>
                      {manufacturers.map((m) => (
                        <SelectItem key={m.id} value={m.id}>
                          {m.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div className="col-span-8" />
              </div>
            </div>

            {/* Location Section */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Location</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                <div className="col-span-6">
                  <Label htmlFor="street_address_line_1" className="text-xs">Street Address</Label>
                  <Input
                    id="street_address_line_1"
                    {...form.register('street_address_line_1')}
                    className="py-1 text-xs"
                  />
                </div>
                <div className="col-span-6">
                  <Label htmlFor="street_address_line_2" className="text-xs">
                    <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                  </Label>
                  <Input
                    id="street_address_line_2"
                    {...form.register('street_address_line_2')}
                    className="py-1 text-xs"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="city" className="text-xs">City</Label>
                  <Input
                    id="city"
                    {...form.register('city')}
                    className="py-1 text-xs"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="state" className="text-xs">State</Label>
                  <Input
                    id="state"
                    {...form.register('state')}
                    className="py-1 text-xs"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="zip_code" className="text-xs">Zip Code</Label>
                  <Input
                    id="zip_code"
                    {...form.register('zip_code')}
                    className="py-1 text-xs"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="country" className="text-xs">Country</Label>
                  <SelectShadcn
                    value={form.watch('country') || ''}
                    onValueChange={(value) => form.setValue('country', value, { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
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
                </div>
              </div>
            </div>

            {/* Billing Address Section */}
            <div className="col-span-12 mt-4">
              <div className="flex items-center gap-4 mb-3">
                <h3 className="text-sm font-semibold text-gray-900">Billing Address</h3>
                <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={billingSameAsLocation}
                    onChange={(e) => setBillingSameAsLocation(e.target.checked)}
                    className="rounded border-gray-300"
                  />
                  Same as location address
                </label>
              </div>
              {!billingSameAsLocation && (
                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_1" className="text-xs">Street Address</Label>
                    <Input
                      id="billing_street_address_line_1"
                      {...form.register('billing_street_address_line_1')}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-6">
                    <Label htmlFor="billing_street_address_line_2" className="text-xs">
                      <span className="text-gray-500 text-[10px]">Street Address 2 (optional)</span>
                    </Label>
                    <Input
                      id="billing_street_address_line_2"
                      {...form.register('billing_street_address_line_2')}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="billing_city" className="text-xs">City</Label>
                    <Input
                      id="billing_city"
                      {...form.register('billing_city')}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="billing_state" className="text-xs">State</Label>
                    <Input
                      id="billing_state"
                      {...form.register('billing_state')}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="billing_zip_code" className="text-xs">Zip Code</Label>
                    <Input
                      id="billing_zip_code"
                      {...form.register('billing_zip_code')}
                      className="py-1 text-xs"
                    />
                  </div>
                  <div className="col-span-3">
                    <Label htmlFor="billing_country" className="text-xs">Country</Label>
                    <SelectShadcn
                      value={form.watch('billing_country') || ''}
                      onValueChange={(value) => form.setValue('billing_country', value, { shouldValidate: true })}
                    >
                      <SelectTrigger className="py-1 text-xs">
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
                  </div>
                </div>
              )}
            </div>

            {/* Terms Section */}
            <div className="col-span-12 mt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Terms</h3>
              <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="payment_terms" className="text-xs">Payment Terms</Label>
                  <SelectShadcn
                    value={form.watch('payment_terms') || '__none__'}
                    onValueChange={(value) => form.setValue('payment_terms', value === '__none__' ? '' : value, { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select payment terms" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">Not set</SelectItem>
                      {PAYMENT_TERMS_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div className="col-span-4">
                  <Label htmlFor="delivery_terms" className="text-xs">Delivery Terms</Label>
                  <SelectShadcn
                    value={form.watch('delivery_terms') || '__none__'}
                    onValueChange={(value) => form.setValue('delivery_terms', value === '__none__' ? '' : value, { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select delivery terms" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">Not set</SelectItem>
                      {DELIVERY_TERMS_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div className="col-span-4">
                  <Label htmlFor="transport" className="text-xs">Transport</Label>
                  <SelectShadcn
                    value={form.watch('transport') || '__none__'}
                    onValueChange={(value) => form.setValue('transport', value === '__none__' ? '' : value, { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select transport" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">Not set</SelectItem>
                      {TRANSPORT_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div className="col-span-4">
                  <Label htmlFor="tax_rule" className="text-xs">Tax Rule</Label>
                  <SelectShadcn
                    value={form.watch('tax_rule') || 'taxable'}
                    onValueChange={(value) => form.setValue('tax_rule', value as 'taxable' | 'tax_exempt', { shouldValidate: true })}
                  >
                    <SelectTrigger className="py-1 text-xs">
                      <SelectValue placeholder="Select tax rule" />
                    </SelectTrigger>
                    <SelectContent>
                      {TAX_RULE_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </div>
            </div>

            {/* Notes */}
            <div className="col-span-12 mt-4">
              <Label htmlFor="notes" className="text-xs">Notes</Label>
              <textarea
                id="notes"
                {...form.register('notes')}
                rows={3}
                className="w-full px-0 py-1.5 pb-1 text-xs bg-transparent rounded-none transition-colors focus:outline-none border-0 border-b border-gray-300 focus:border-[var(--primary-brand-hex)] focus:ring-0"
                placeholder="Internal notes about this vendor..."
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
