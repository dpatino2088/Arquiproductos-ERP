import { useMemo, useState } from 'react';
import { MapPin, Plus, Edit, Archive, X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { usePermissions } from '../../hooks/usePermissions';
import {
  useOrganizationAddresses,
  type OrganizationAddress,
  type OrganizationAddressInput,
} from '../../hooks/useOrganizationAddresses';
import { useUIStore } from '../../stores/ui-store';

type AddressFormState = {
  name: string;
  street_address_line_1: string;
  street_address_line_2: string;
  city: string;
  state: string;
  zip_code: string;
  country: string;
  notes: string;
  contact_person: string;
  contact_phone: string;
  contact_email: string;
  is_active: boolean;
  is_default_po_ship_to: boolean;
};

const EMPTY_FORM: AddressFormState = {
  name: '',
  street_address_line_1: '',
  street_address_line_2: '',
  city: '',
  state: '',
  zip_code: '',
  country: '',
  notes: '',
  contact_person: '',
  contact_phone: '',
  contact_email: '',
  is_active: true,
  is_default_po_ship_to: false,
};

function toInput(form: AddressFormState): OrganizationAddressInput {
  return {
    name: form.name,
    street_address_line_1: form.street_address_line_1,
    street_address_line_2: form.street_address_line_2,
    city: form.city,
    state: form.state,
    zip_code: form.zip_code,
    country: form.country,
    notes: form.notes,
    contact_person: form.contact_person,
    contact_phone: form.contact_phone,
    contact_email: form.contact_email,
    is_active: form.is_active,
    is_default_po_ship_to: form.is_default_po_ship_to,
  };
}

export default function AddressDirectorySettings() {
  const { can } = usePermissions();
  const addNotification = useUIStore((s) => s.addNotification);
  const { addresses, isLoading, error, createAddress, updateAddress, archiveAddress, isSaving } = useOrganizationAddresses();

  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingAddress, setEditingAddress] = useState<OrganizationAddress | null>(null);
  const [form, setForm] = useState<AddressFormState>(EMPTY_FORM);

  const canWrite = can('settings.write');

  const filteredAddresses = useMemo(() => {
    const query = searchTerm.trim().toLowerCase();
    if (!query) {
      return addresses;
    }
    return addresses.filter((a) => {
      const fullAddress = [
        a.street_address_line_1,
        a.street_address_line_2,
        a.city,
        a.state,
        a.zip_code,
        a.country,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return a.name.toLowerCase().includes(query) || fullAddress.includes(query);
    });
  }, [addresses, searchTerm]);

  const openCreate = () => {
    setEditingAddress(null);
    setForm(EMPTY_FORM);
    setShowModal(true);
  };

  const openEdit = (address: OrganizationAddress) => {
    setEditingAddress(address);
    setForm({
      name: address.name,
      street_address_line_1: address.street_address_line_1 ?? '',
      street_address_line_2: address.street_address_line_2 ?? '',
      city: address.city ?? '',
      state: address.state ?? '',
      zip_code: address.zip_code ?? '',
      country: address.country ?? '',
      notes: address.notes ?? '',
      contact_person: address.contact_person ?? '',
      contact_phone: address.contact_phone ?? '',
      contact_email: address.contact_email ?? '',
      is_active: address.is_active,
      is_default_po_ship_to: address.is_default_po_ship_to,
    });
    setShowModal(true);
  };

  const closeModal = () => {
    setShowModal(false);
    setEditingAddress(null);
    setForm(EMPTY_FORM);
  };

  const handleSave = async () => {
    if (!form.name.trim()) {
      addNotification({ type: 'error', title: 'Validation', message: 'Address name is required.' });
      return;
    }
    if (!form.street_address_line_1.trim()) {
      addNotification({ type: 'error', title: 'Validation', message: 'Street address line 1 is required.' });
      return;
    }

    try {
      if (editingAddress) {
        await updateAddress({ id: editingAddress.id, input: toInput(form) });
        addNotification({ type: 'success', title: 'Address updated', message: 'Address updated successfully.' });
      } else {
        await createAddress(toInput(form));
        addNotification({ type: 'success', title: 'Address created', message: 'Address created successfully.' });
      }
      closeModal();
    } catch (err: unknown) {
      addNotification({
        type: 'error',
        title: 'Save error',
        message: err instanceof Error ? err.message : 'Failed to save address.',
      });
    }
  };

  const handleArchive = async (address: OrganizationAddress) => {
    try {
      await archiveAddress(address.id);
      addNotification({ type: 'success', title: 'Address archived', message: 'Address archived successfully.' });
    } catch (err: unknown) {
      addNotification({
        type: 'error',
        title: 'Archive error',
        message: err instanceof Error ? err.message : 'Failed to archive address.',
      });
    }
  };

  return (
    <div className="py-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Address Directory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage reusable destination addresses (Panama, Miami, etc.)
          </p>
        </div>
        {canWrite && (
          <button
            onClick={openCreate}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 inline-flex items-center gap-2"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus className="w-4 h-4" />
            Add Address
          </button>
        )}
      </div>

      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <Input
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by name or address..."
            className="py-1 text-sm"
          />
        </div>
      </div>

      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        {isLoading ? (
          <div className="text-center py-12 px-6">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
            <p className="text-sm text-gray-600">Loading addresses...</p>
          </div>
        ) : error ? (
          <div className="py-6 px-6">
            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
              <p className="text-sm text-red-800">Error loading addresses: {error}</p>
            </div>
          </div>
        ) : filteredAddresses.length === 0 ? (
          <div className="text-center py-12 px-6">
            <MapPin className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600 mb-2">No addresses found</p>
            <p className="text-sm text-gray-500">Create your destination list to reuse in purchasing.</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Address</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Contact</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Country</th>
                <th className="text-center py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                <th className="text-center py-3 px-6 font-medium text-gray-900 text-xs">Default PO</th>
                {canWrite && <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredAddresses.map((address) => {
                const fullAddress = [
                  address.street_address_line_1,
                  address.street_address_line_2,
                  [address.city, address.state, address.zip_code].filter(Boolean).join(', '),
                ]
                  .filter(Boolean)
                  .join(' · ');
                return (
                  <tr key={address.id} className="hover:bg-gray-50 transition-colors">
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">{address.name}</td>
                    <td className="py-4 px-6 text-gray-700 text-sm">{fullAddress || '—'}</td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {address.contact_person || address.contact_phone || address.contact_email ? (
                        <div className="leading-relaxed">
                          {address.contact_person && <div>{address.contact_person}</div>}
                          {address.contact_phone && <div className="text-xs text-gray-600">{address.contact_phone}</div>}
                          {address.contact_email && <div className="text-xs text-gray-500">{address.contact_email}</div>}
                        </div>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">{address.country || '—'}</td>
                    <td className="py-4 px-6 text-center">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${address.is_active ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-gray-100 text-gray-600 border border-gray-300'}`}>
                        {address.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-center">
                      {address.is_default_po_ship_to ? (
                        <span className="px-2 py-1 rounded text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200">
                          Default
                        </span>
                      ) : (
                        <span className="text-gray-400 text-xs">—</span>
                      )}
                    </td>
                    {canWrite && (
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-2 justify-end">
                          <button
                            onClick={() => openEdit(address)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title="Edit address"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleArchive(address)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title="Archive address"
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-2xl w-full mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">
                {editingAddress ? 'Edit Address' : 'Add Address'}
              </h3>
              <button onClick={closeModal} className="text-gray-400 hover:text-gray-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="grid grid-cols-12 gap-4">
              <div className="col-span-6">
                <Label htmlFor="name" className="text-xs" required>
                  Name
                </Label>
                <Input
                  id="name"
                  value={form.name}
                  onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))}
                  placeholder="Panama Office"
                  className="mt-1"
                />
              </div>
              <div className="col-span-6">
                <Label htmlFor="country" className="text-xs">
                  Country
                </Label>
                <Input
                  id="country"
                  value={form.country}
                  onChange={(e) => setForm((prev) => ({ ...prev, country: e.target.value }))}
                  placeholder="Panama"
                  className="mt-1"
                />
              </div>

              <div className="col-span-12">
                <Label htmlFor="street1" className="text-xs" required>
                  Street Address 1
                </Label>
                <Input
                  id="street1"
                  value={form.street_address_line_1}
                  onChange={(e) => setForm((prev) => ({ ...prev, street_address_line_1: e.target.value }))}
                  placeholder="Street and number"
                  className="mt-1"
                />
              </div>

              <div className="col-span-12">
                <Label htmlFor="street2" className="text-xs">
                  Street Address 2
                </Label>
                <Input
                  id="street2"
                  value={form.street_address_line_2}
                  onChange={(e) => setForm((prev) => ({ ...prev, street_address_line_2: e.target.value }))}
                  placeholder="Suite / building / reference"
                  className="mt-1"
                />
              </div>

              <div className="col-span-4">
                <Label htmlFor="city" className="text-xs">
                  City
                </Label>
                <Input
                  id="city"
                  value={form.city}
                  onChange={(e) => setForm((prev) => ({ ...prev, city: e.target.value }))}
                  className="mt-1"
                />
              </div>
              <div className="col-span-4">
                <Label htmlFor="state" className="text-xs">
                  State
                </Label>
                <Input
                  id="state"
                  value={form.state}
                  onChange={(e) => setForm((prev) => ({ ...prev, state: e.target.value }))}
                  className="mt-1"
                />
              </div>
              <div className="col-span-4">
                <Label htmlFor="zip" className="text-xs">
                  Zip
                </Label>
                <Input
                  id="zip"
                  value={form.zip_code}
                  onChange={(e) => setForm((prev) => ({ ...prev, zip_code: e.target.value }))}
                  className="mt-1"
                />
              </div>

              <div className="col-span-12">
                <Label htmlFor="contact_person" className="text-xs">
                  Contact Person(s)
                </Label>
                <Input
                  id="contact_person"
                  value={form.contact_person}
                  onChange={(e) => setForm((prev) => ({ ...prev, contact_person: e.target.value }))}
                  placeholder="e.g. Carlos Diaz / Receiving Team"
                  className="mt-1"
                />
              </div>

              <div className="col-span-6">
                <Label htmlFor="contact_phone" className="text-xs">
                  Contact Phone
                </Label>
                <Input
                  id="contact_phone"
                  value={form.contact_phone}
                  onChange={(e) => setForm((prev) => ({ ...prev, contact_phone: e.target.value }))}
                  placeholder="+507..."
                  className="mt-1"
                />
              </div>

              <div className="col-span-6">
                <Label htmlFor="contact_email" className="text-xs">
                  Contact Email
                </Label>
                <Input
                  id="contact_email"
                  type="email"
                  value={form.contact_email}
                  onChange={(e) => setForm((prev) => ({ ...prev, contact_email: e.target.value }))}
                  placeholder="receiving@company.com"
                  className="mt-1"
                />
              </div>

              <div className="col-span-12">
                <Label htmlFor="notes" className="text-xs">
                  Notes
                </Label>
                <textarea
                  id="notes"
                  value={form.notes}
                  onChange={(e) => setForm((prev) => ({ ...prev, notes: e.target.value }))}
                  rows={3}
                  className="w-full mt-1 px-3 py-2 border border-gray-200 rounded text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                  placeholder="Optional notes"
                />
              </div>

              <div className="col-span-12 flex items-center gap-6">
                <label className="flex items-center gap-2 text-xs text-gray-700 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm((prev) => ({ ...prev, is_active: e.target.checked }))}
                    className="rounded border-gray-300"
                  />
                  Active
                </label>
                <label className="flex items-center gap-2 text-xs text-gray-700 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_default_po_ship_to}
                    onChange={(e) => setForm((prev) => ({ ...prev, is_default_po_ship_to: e.target.checked }))}
                    className="rounded border-gray-300"
                  />
                  Default for PO ship-to
                </label>
              </div>
            </div>

            <div className="flex items-center gap-2 mt-6">
              <button
                onClick={closeModal}
                className="flex-1 px-4 py-2 border border-gray-300 rounded text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={isSaving}
                className="flex-1 px-4 py-2 bg-primary text-white rounded text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSaving ? 'Saving...' : editingAddress ? 'Update' : 'Create'} Address
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
