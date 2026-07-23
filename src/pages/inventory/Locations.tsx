import { useEffect, useMemo, useState } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { buildDirectoryScopeKey } from '../../lib/directoryScopeKey';
import { useWarehouses } from '../../hooks/useWarehouses';
import {
  useWarehouseLocations,
  useCreateWarehouseLocation,
  useUpdateWarehouseLocation,
  type WarehouseLocationWithWarehouse,
} from '../../hooks/useWarehouseLocations';
import { Plus, Search, X, Pencil } from 'lucide-react';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

import { INVENTORY_SUBMODULES } from './inventorySubmodules';

interface FormState {
  id: string | null;
  warehouse_id: string;
  zone: string;
  rack: string;
  level: string;
  bin: string;
  is_pickable: boolean;
  is_active: boolean;
  notes: string;
}

const EMPTY_FORM: FormState = {
  id: null,
  warehouse_id: '',
  zone: '',
  rack: '',
  level: '',
  bin: '',
  is_pickable: true,
  is_active: true,
  notes: '',
};

export default function Locations() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();
  const { warehouses, defaultWarehouse } = useWarehouses(activeOrganizationId);

  const scopeKey = useMemo(
    () =>
      buildDirectoryScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );

  const [filterWarehouseId, setFilterWarehouseId] = useState<string>('');
  const [search, setSearch] = useState('');
  const [includeInactive, setIncludeInactive] = useState(false);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);

  const { locations, isLoading, isFetching } = useWarehouseLocations({
    organizationId: activeOrganizationId,
    warehouseId: filterWarehouseId || null,
    scopeKey,
    includeInactive,
  });

  const createMutation = useCreateWarehouseLocation();
  const updateMutation = useUpdateWarehouseLocation();
  const isSaving = createMutation.isPending || updateMutation.isPending;

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  const filtered = useMemo(() => {
    if (!search.trim()) {return locations;}
    const q = search.toLowerCase();
    return locations.filter((row) =>
      [row.location_code, row.zone, row.rack, row.level, row.bin, row.warehouse_name, row.notes]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q))
    );
  }, [locations, search]);

  function startCreate() {
    setForm({
      ...EMPTY_FORM,
      warehouse_id: filterWarehouseId || defaultWarehouse?.id || warehouses[0]?.id || '',
    });
    setError(null);
    setFormOpen(true);
  }

  function startEdit(row: WarehouseLocationWithWarehouse) {
    setForm({
      id: row.id,
      warehouse_id: row.warehouse_id,
      zone: row.zone ?? '',
      rack: row.rack ?? '',
      level: row.level ?? '',
      bin: row.bin ?? '',
      is_pickable: row.is_pickable,
      is_active: row.is_active,
      notes: row.notes ?? '',
    });
    setError(null);
    setFormOpen(true);
  }

  function closeForm() {
    setFormOpen(false);
    setError(null);
  }

  async function handleSave() {
    setError(null);
    if (!activeOrganizationId) {
      setError('No active organization');
      return;
    }
    if (!form.warehouse_id) {
      setError('Warehouse is required');
      return;
    }
    const hasAnyPart =
      form.zone.trim() || form.rack.trim() || form.level.trim() || form.bin.trim();
    if (!hasAnyPart) {
      setError('At least one of Zone / Rack / Level / Bin is required');
      return;
    }
    try {
      if (form.id) {
        await updateMutation.mutateAsync({
          id: form.id,
          organization_id: activeOrganizationId,
          warehouse_id: form.warehouse_id,
          zone: form.zone.trim() || null,
          rack: form.rack.trim() || null,
          level: form.level.trim() || null,
          bin: form.bin.trim() || null,
          is_pickable: form.is_pickable,
          is_active: form.is_active,
          notes: form.notes.trim() || null,
        });
      } else {
        await createMutation.mutateAsync({
          organization_id: activeOrganizationId,
          warehouse_id: form.warehouse_id,
          zone: form.zone.trim() || null,
          rack: form.rack.trim() || null,
          level: form.level.trim() || null,
          bin: form.bin.trim() || null,
          is_pickable: form.is_pickable,
          is_active: form.is_active,
          notes: form.notes.trim() || null,
        });
      }
      setFormOpen(false);
    } catch (e) {
      setError((e as Error).message ?? 'Failed to save location');
    }
  }

  return (
    <div className="px-6 py-6">
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Storage Locations (Bins)</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {filtered.length} location{filtered.length === 1 ? '' : 's'} ·{' '}
            {includeInactive ? 'including inactive' : 'active only'}
          </p>
        </div>
        <button
          type="button"
          onClick={startCreate}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
        >
          <Plus className="w-4 h-4" />
          New Location
        </button>
      </div>

      <div className="mb-4 bg-white border border-gray-200 py-4 px-4 rounded-lg">
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex-1 relative min-w-[240px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by code, zone, rack, level, bin, warehouse..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
            />
          </div>
          {warehouses.length > 0 && (
            <div className="w-[200px] shrink-0">
              <Select
                value={filterWarehouseId || '__all__'}
                onValueChange={(v) => setFilterWarehouseId(v === '__all__' ? '' : v)}
              >
                <SelectTrigger className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px]">
                  <SelectValue placeholder="All Warehouses" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__all__">All Warehouses</SelectItem>
                  {warehouses.map((w) => (
                    <SelectItem key={w.id} value={w.id}>
                      {w.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
          <label className="flex items-center gap-2 text-sm text-gray-700 select-none">
            <input
              type="checkbox"
              checked={includeInactive}
              onChange={(e) => setIncludeInactive(e.target.checked)}
            />
            Show inactive
          </label>
        </div>
      </div>

      {isLoading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 bg-white shadow-sm overflow-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b sticky top-0 z-10">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Code</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Zone</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Rack</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Level</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Bin</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Pickable</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-4 py-8 text-center text-gray-500">
                    No locations defined. Click <em>New Location</em> to create your first bin.
                  </td>
                </tr>
              ) : (
                filtered.map((row) => (
                  <tr key={row.id} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-700">{row.warehouse_name ?? '—'}</td>
                    <td className="px-4 py-3 font-medium text-gray-900">{row.location_code}</td>
                    <td className="px-4 py-3 text-gray-600">{row.zone ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{row.rack ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{row.level ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{row.bin ?? '—'}</td>
                    <td className="px-4 py-3 text-center text-gray-600">
                      {row.is_pickable ? 'Yes' : 'No'}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          row.is_active
                            ? 'bg-green-50 text-green-700'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {row.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center">
                      <button
                        type="button"
                        onClick={() => startEdit(row)}
                        className="inline-flex items-center justify-center p-1.5 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded"
                        aria-label={`Edit ${row.location_code}`}
                        title={`Edit ${row.location_code}`}
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {!isLoading && isFetching ? (
            <div className="border-t bg-gray-50/80 px-4 py-2 text-xs text-gray-600">Updating...</div>
          ) : null}
        </div>
      )}

      {formOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-lg mx-4">
            <div className="flex items-center justify-between px-5 py-3 border-b">
              <h2 className="text-base font-semibold text-gray-900">
                {form.id ? 'Edit Location' : 'New Location'}
              </h2>
              <button type="button" onClick={closeForm} className="p-1 text-gray-500 hover:text-gray-700" aria-label="Close">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="px-5 py-4 space-y-3">
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Warehouse *</label>
                <select
                  value={form.warehouse_id}
                  onChange={(e) => setForm({ ...form, warehouse_id: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                  disabled={!!form.id}
                >
                  <option value="">Select warehouse...</option>
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-4 gap-3">
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">Zone</label>
                  <input
                    type="text"
                    value={form.zone}
                    onChange={(e) => setForm({ ...form, zone: e.target.value })}
                    placeholder="A"
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">Rack</label>
                  <input
                    type="text"
                    value={form.rack}
                    onChange={(e) => setForm({ ...form, rack: e.target.value })}
                    placeholder="R3"
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">Level</label>
                  <input
                    type="text"
                    value={form.level}
                    onChange={(e) => setForm({ ...form, level: e.target.value })}
                    placeholder="L2"
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">Bin</label>
                  <input
                    type="text"
                    value={form.bin}
                    onChange={(e) => setForm({ ...form, bin: e.target.value })}
                    placeholder="B1"
                    className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                  />
                </div>
              </div>
              <p className="text-xs text-gray-500">
                Code will be auto-generated as <code>Zone-Rack-Level-Bin</code> (skipping empty parts).
              </p>

              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Notes</label>
                <input
                  type="text"
                  value={form.notes}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded text-sm bg-white"
                />
              </div>

              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={form.is_pickable}
                    onChange={(e) => setForm({ ...form, is_pickable: e.target.checked })}
                  />
                  Pickable
                </label>
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                  />
                  Active
                </label>
              </div>

              {error && (
                <div className="text-xs text-red-700 bg-red-50 border border-red-200 rounded px-3 py-2">
                  {error}
                </div>
              )}
            </div>
            <div className="flex items-center justify-end gap-2 px-5 py-3 border-t bg-gray-50">
              <button
                type="button"
                onClick={closeForm}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded bg-white hover:bg-gray-100"
                disabled={isSaving}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSave}
                className="px-3 py-1.5 text-sm font-medium text-white bg-gray-800 rounded hover:bg-gray-700 disabled:opacity-60"
                disabled={isSaving}
              >
                {isSaving ? 'Saving...' : form.id ? 'Save changes' : 'Create location'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
