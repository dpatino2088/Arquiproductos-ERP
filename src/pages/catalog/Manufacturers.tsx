import { useEffect, useState, useMemo, useImperativeHandle, forwardRef, useRef } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export interface ManufacturersRef {
  openNewModal: () => void;
}
import { useGranularAccess } from '../../hooks/usePermissions';
import { useManufacturersCRUD } from '../../hooks/useCatalog';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { 
  Search, 
  Plus,
  Edit,
  Trash2,
  Archive,
  SortAsc,
  SortDesc,
  Building2,
  Package,
  FolderTree,
  Book,
  Upload,
  X,
  ImageIcon,
} from 'lucide-react';

interface ManufacturersProps {
  readOnly?: boolean;
}

const Manufacturers = forwardRef<ManufacturersRef, ManufacturersProps>(function Manufacturers({ readOnly = false }, ref) {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { manufacturers, loading, error, createManufacturer, updateManufacturer, deleteManufacturer, isCreating, isDeleting } = useManufacturersCRUD();
  const { canCreate: canCreateCat, canDelete: canDeleteCat } = useGranularAccess('catalog');
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();

  // Show all manufacturers (no filter by is_roll)
  const manufacturersToShow = manufacturers;

  // Register sub-tabs for Manufacturers (only manufacturers now)
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog') && currentPath.includes('manufacturer')) {
      registerSubmodules('Manufacturers', [
        { id: 'manufacturers', label: 'Manufacturers', href: '#manufacturers', icon: Building2 },
      ]);
    }
  }, [registerSubmodules]);

  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'name' | 'code'>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [showNewModal, setShowNewModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ name: '', code: '', notes: '', logo_url: '', vendor_id: '' });
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const logoInputRef = useRef<HTMLInputElement>(null);

  // Vendors for dropdown + vendor map for table column
  const [vendors, setVendors] = useState<{ id: string; name: string }[]>([]);
  const [mfrVendorMap, setMfrVendorMap] = useState<Map<string, { vendor_id: string; vendor_name: string }>>(new Map());

  useEffect(() => {
    if (!activeOrganizationId) return;
    let mounted = true;
    (async () => {
      const { data: dvRows } = await supabase
        .from('DirectoryVendors')
        .select('id, name')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('name');
      if (mounted && dvRows) setVendors(dvRows);

      const { data: vmRows } = await supabase
        .from('VendorManufacturers')
        .select('vendor_id, manufacturer_id')
        .eq('organization_id', activeOrganizationId);
      if (mounted && vmRows && dvRows) {
        const vNameMap = new Map(dvRows.map((v: any) => [v.id, v.name]));
        const map = new Map<string, { vendor_id: string; vendor_name: string }>();
        vmRows.forEach((r: any) => {
          if (!map.has(r.manufacturer_id)) {
            map.set(r.manufacturer_id, { vendor_id: r.vendor_id, vendor_name: String(vNameMap.get(r.vendor_id) ?? '') });
          }
        });
        setMfrVendorMap(map);
      }
    })();
    return () => { mounted = false; };
  }, [activeOrganizationId, showNewModal]);

  // Filter and sort (sobre manufacturersToShow, ya sin los de "cero que mostrar")
  const filteredManufacturers = useMemo(() => {
    const filtered = manufacturersToShow.filter(m => {
      const searchLower = searchTerm.toLowerCase();
      return !searchTerm || 
        m.name.toLowerCase().includes(searchLower) ||
        (m.code && m.code.toLowerCase().includes(searchLower)) ||
        (m.notes && m.notes.toLowerCase().includes(searchLower));
    });

    return filtered.sort((a, b) => {
      let aValue: string;
      let bValue: string;

      if (sortBy === 'name') {
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
      } else {
        aValue = (a.code || '').toLowerCase();
        bValue = (b.code || '').toLowerCase();
      }

      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [manufacturersToShow, searchTerm, sortBy, sortOrder]);

  // Pagination
  const totalPages = Math.ceil(filteredManufacturers.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedManufacturers = filteredManufacturers.slice(startIndex, startIndex + itemsPerPage);

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  const handleNew = () => {
    if (readOnly) {
      router.navigate('/partners/manufacturers');
      return;
    }
    setFormData({ name: '', code: '', notes: '', logo_url: '', vendor_id: '' });
    setEditingId(null);
    setShowNewModal(true);
  };

  useImperativeHandle(ref, () => ({ openNewModal: handleNew }), []);

  const handleEdit = (manufacturer: any) => {
    if (readOnly) {
      router.navigate('/partners/manufacturers');
      return;
    }
    const linked = mfrVendorMap.get(manufacturer.id);
    setFormData({
      name: manufacturer.name,
      code: manufacturer.code || '',
      notes: manufacturer.notes || '',
      logo_url: manufacturer.logo_url || '',
      vendor_id: linked?.vendor_id || '',
    });
    setEditingId(manufacturer.id);
    setShowNewModal(true);
  };

  const handleLogoUpload = async (file: File) => {
    if (!activeOrganizationId) return;
    setUploadingLogo(true);
    try {
      const ext = file.name.split('.').pop()?.toLowerCase() || 'png';
      const path = `${activeOrganizationId}/manufacturers/${Date.now()}.${ext}`;
      const { error: uploadErr } = await supabase.storage
        .from('catalog-images')
        .upload(path, file, { upsert: true, contentType: file.type });
      if (uploadErr) throw uploadErr;
      const { data: urlData } = supabase.storage.from('catalog-images').getPublicUrl(path);
      setFormData(prev => ({ ...prev, logo_url: urlData.publicUrl }));
    } catch (err) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Upload Error', message: err instanceof Error ? err.message : 'Failed to upload logo' });
    } finally {
      setUploadingLogo(false);
    }
  };

  const handleSave = async () => {
    try {
      const { vendor_id, ...mfrData } = formData;
      let savedId = editingId;

      if (editingId) {
        await updateManufacturer(editingId, mfrData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Manufacturer updated',
          message: 'Manufacturer has been updated successfully.',
        });
      } else {
        const created = await createManufacturer(mfrData);
        savedId = (created as any)?.id ?? null;
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Manufacturer created',
          message: 'Manufacturer has been created successfully.',
        });
      }

      // Sync VendorManufacturers
      if (savedId && activeOrganizationId) {
        await supabase
          .from('VendorManufacturers')
          .delete()
          .eq('manufacturer_id', savedId)
          .eq('organization_id', activeOrganizationId);

        if (vendor_id?.trim()) {
          await supabase
            .from('VendorManufacturers')
            .insert({
              vendor_id: vendor_id.trim(),
              manufacturer_id: savedId,
              organization_id: activeOrganizationId,
              is_primary: true,
            });
        }

        // Also update legacy DirectoryVendors.manufacturer_id
        if (vendor_id?.trim()) {
          await supabase
            .from('DirectoryVendors')
            .update({ manufacturer_id: savedId })
            .eq('id', vendor_id.trim())
            .eq('organization_id', activeOrganizationId);
        }
      }

      setShowNewModal(false);
      setFormData({ name: '', code: '', notes: '', logo_url: '', vendor_id: '' });
      setEditingId(null);
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: error instanceof Error ? error.message : 'Unknown error occurred',
      });
    }
  };

  const handleDelete = async (id: string, name: string) => {
    const confirmed = await showConfirm({
      title: 'Eliminar Fabricante',
      message: `¿Estás seguro de que deseas eliminar "${name}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteManufacturer(id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Fabricante eliminado',
        message: 'El fabricante ha sido eliminado correctamente.',
      });
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al eliminar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      {/* Read-only notice */}
      {readOnly && (
        <div className="mb-3 flex items-center justify-between bg-blue-50 border border-blue-200 rounded-lg px-4 py-3 text-sm text-blue-800">
          <span>This is a read-only view. Manage manufacturers in the Partners module.</span>
          <button
            onClick={() => router.navigate('/partners/manufacturers')}
            className="text-blue-600 font-medium hover:underline ml-4 whitespace-nowrap"
          >
            Go to Partners
          </button>
        </div>
      )}

      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search manufacturers by name, code, or notes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Loading manufacturers...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">Error: {error}</p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-center py-3 px-3 font-medium text-gray-900 text-xs w-14">Logo</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('name')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name
                      {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('code')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Code
                      {sortBy === 'code' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Vendor</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Notes</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredManufacturers.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <Building2 className="w-12 h-12 text-gray-400 mb-4" />
                        <p className="text-gray-600 mb-2">No manufacturers found</p>
                        <p className="text-sm text-gray-500">
                          {manufacturers.length === 0 
                            ? 'Start by adding manufacturers'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedManufacturers.map((manufacturer) => (
                    <tr 
                      key={manufacturer.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-2 px-3 text-center">
                        {manufacturer.logo_url ? (
                          <img src={manufacturer.logo_url} alt="" className="h-8 w-10 object-contain mx-auto" />
                        ) : (
                          <Building2 className="w-5 h-5 text-gray-300 mx-auto" />
                        )}
                      </td>
                      <td className="py-3 px-4 text-gray-900 text-xs font-medium">
                        {manufacturer.name}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {manufacturer.code || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-xs">
                        {mfrVendorMap.get(manufacturer.id)?.vendor_name
                          ? <span className="text-gray-900">{mfrVendorMap.get(manufacturer.id)!.vendor_name}</span>
                          : <span className="text-gray-400 italic">Not assigned</span>
                        }
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {manufacturer.notes || 'N/A'}
                      </td>
                      <td className="py-3 px-4" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={() => handleEdit(manufacturer)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title={readOnly ? 'Manage in Partners' : `Edit ${manufacturer.name}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          {!readOnly && canDeleteCat && (
                            <button 
                              onClick={() => handleDelete(manufacturer.id, manufacturer.name)}
                              disabled={isDeleting}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title={`Delete ${manufacturer.name}`}
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination */}
      {filteredManufacturers.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-700">Show:</span>
              <select
                value={itemsPerPage}
                onChange={(e) => {
                  setItemsPerPage(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
                <option value={100}>100</option>
              </select>
              <span className="text-sm text-gray-700">
                Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredManufacturers.length)} of {filteredManufacturers.length}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Previous
              </button>
              <span className="text-sm text-gray-700">
                Page {currentPage} of {totalPages || 1}
              </span>
              <button
                onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                disabled={currentPage >= totalPages}
                className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {/* New/Edit Modal */}
      {showNewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <button
              onClick={() => {
                setShowNewModal(false);
                setFormData({ name: '', code: '', notes: '', logo_url: '', vendor_id: '' });
                setEditingId(null);
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span className="text-2xl">&times;</span>
            </button>

            <h2 className="text-xl font-semibold text-gray-900 mb-4">
              {editingId ? 'Edit Manufacturer' : 'New Manufacturer'}
            </h2>

            <div className="space-y-4">
              {/* Logo Upload */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Brand Logo</label>
                <div className="flex items-center gap-4">
                  <div className="w-20 h-20 rounded-lg border-2 border-dashed border-gray-300 flex items-center justify-center bg-gray-50 overflow-hidden flex-shrink-0">
                    {formData.logo_url ? (
                      <img src={formData.logo_url} alt="Logo" className="w-full h-full object-contain p-1" />
                    ) : (
                      <ImageIcon className="w-8 h-8 text-gray-300" />
                    )}
                  </div>
                  <div className="flex flex-col gap-1.5">
                    <input
                      ref={logoInputRef}
                      type="file"
                      accept="image/png,image/jpeg,image/svg+xml,image/webp"
                      className="hidden"
                      onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) handleLogoUpload(file);
                        e.target.value = '';
                      }}
                    />
                    <button
                      type="button"
                      onClick={() => logoInputRef.current?.click()}
                      disabled={uploadingLogo}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
                    >
                      {uploadingLogo ? (
                        <div className="animate-spin h-3 w-3 border border-gray-400 border-t-transparent rounded-full" />
                      ) : (
                        <Upload className="w-3 h-3" />
                      )}
                      {uploadingLogo ? 'Uploading...' : 'Upload Logo'}
                    </button>
                    {formData.logo_url && (
                      <button
                        type="button"
                        onClick={() => setFormData(prev => ({ ...prev, logo_url: '' }))}
                        className="inline-flex items-center gap-1 px-3 py-1 text-xs text-red-600 hover:text-red-700"
                      >
                        <X className="w-3 h-3" />
                        Remove
                      </button>
                    )}
                    <p className="text-[10px] text-gray-400">PNG, JPG, SVG or WebP. Max 2MB.</p>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  placeholder="Manufacturer name"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Code
                </label>
                <input
                  type="text"
                  value={formData.code}
                  onChange={(e) => setFormData({ ...formData, code: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  placeholder="Manufacturer code (optional)"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Notes
                </label>
                <textarea
                  value={formData.notes}
                  onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  placeholder="Additional notes (optional)"
                  rows={3}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Vendor (Supplier)
                </label>
                <select
                  value={formData.vendor_id}
                  onChange={(e) => setFormData({ ...formData, vendor_id: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent bg-white"
                >
                  <option value="">No vendor assigned</option>
                  {vendors.map((v) => (
                    <option key={v.id} value={v.id}>{v.name}</option>
                  ))}
                </select>
                <p className="text-[10px] text-gray-400 mt-1">Which vendor supplies products from this manufacturer?</p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={() => {
                  setShowNewModal(false);
                  setFormData({ name: '', code: '', notes: '', logo_url: '', vendor_id: '' });
                  setEditingId(null);
                }}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={!formData.name.trim() || isCreating || uploadingLogo}
                className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isCreating ? 'Saving...' : editingId ? 'Update' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
});

export default Manufacturers;
