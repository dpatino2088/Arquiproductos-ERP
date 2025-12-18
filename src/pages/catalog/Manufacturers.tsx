import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useManufacturersCRUD } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
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
} from 'lucide-react';

export default function Manufacturers() {
  const { registerSubmodules } = useSubmoduleNav();
  const { manufacturers, loading, error, createManufacturer, updateManufacturer, deleteManufacturer, isCreating, isDeleting } = useManufacturersCRUD();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();

  useEffect(() => {
    // Register Catalog submodules when this component mounts
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'manufacturers', label: 'Manufacturers', href: '/catalog/manufacturers', icon: Building2 },
        { id: 'categories', label: 'Categories', href: '/catalog/categories', icon: FolderTree },
        { id: 'collections', label: 'Collections', href: '/catalog/collections', icon: Book },
      ]);
      if (import.meta.env.DEV) {
        console.log('✅ Manufacturers.tsx: Registered Catalog submodules');
      }
    }
  }, [registerSubmodules]);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'name' | 'code'>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [showNewModal, setShowNewModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ name: '', code: '', notes: '' });

  // Filter and sort
  const filteredManufacturers = useMemo(() => {
    const filtered = manufacturers.filter(m => {
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
  }, [manufacturers, searchTerm, sortBy, sortOrder]);

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
    setFormData({ name: '', code: '', notes: '' });
    setEditingId(null);
    setShowNewModal(true);
  };

  const handleEdit = (manufacturer: any) => {
    setFormData({
      name: manufacturer.name,
      code: manufacturer.code || '',
      notes: manufacturer.notes || '',
    });
    setEditingId(manufacturer.id);
    setShowNewModal(true);
  };

  const handleSave = async () => {
    try {
      if (editingId) {
        await updateManufacturer(editingId, formData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Manufacturer updated',
          message: 'Manufacturer has been updated successfully.',
        });
      } else {
        await createManufacturer(formData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Manufacturer created',
          message: 'Manufacturer has been created successfully.',
        });
      }
      setShowNewModal(false);
      setFormData({ name: '', code: '', notes: '' });
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
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Manufacturers</h1>
          <p className="text-small text-muted-foreground">Manage product manufacturers</p>
        </div>
        <button
          onClick={handleNew}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add New Manufacturer
        </button>
      </div>

      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search manufacturers by name, code, or notes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
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
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
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
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Notes</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredManufacturers.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="py-12 px-6 text-center">
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
                      <td className="py-3 px-4 text-gray-900 text-xs font-medium">
                        {manufacturer.name}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {manufacturer.code || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {manufacturer.notes || 'N/A'}
                      </td>
                      <td className="py-3 px-4" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={() => handleEdit(manufacturer)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title={`Edit ${manufacturer.name}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={() => handleDelete(manufacturer.id, manufacturer.name)}
                            disabled={isDeleting}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            title={`Delete ${manufacturer.name}`}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
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
                setFormData({ name: '', code: '', notes: '' });
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
            </div>

            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={() => {
                  setShowNewModal(false);
                  setFormData({ name: '', code: '', notes: '' });
                  setEditingId(null);
                }}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={!formData.name.trim() || isCreating}
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
}

