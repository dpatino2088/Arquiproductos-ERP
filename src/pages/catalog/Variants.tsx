import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useCatalogVariantsCRUD, useCatalogCollections } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { router } from '../../lib/router';
import { 
  Search, 
  Plus,
  Edit,
  Trash2,
  SortAsc,
  SortDesc,
  Palette,
  Filter,
  Package,
  Building2,
  FolderTree,
  Book
} from 'lucide-react';

export default function Variants() {
  const { registerSubmodules } = useSubmoduleNav();
  const { collections } = useCatalogCollections();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();

  useEffect(() => {
    // DEPRECATED: This component is deprecated. Redirect to collections.
    // Variants functionality has been moved to CollectionsCatalog.
    const currentPath = window.location.pathname;
    if (currentPath === '/catalog/variants' || currentPath.startsWith('/catalog/variants/')) {
      // Redirect to collections page
      router.navigate('/catalog/collections', true);
      return;
    }
    
    // Register Catalog submodules when this component mounts (without variants)
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'manufacturers', label: 'Manufacturers', href: '/catalog/manufacturers', icon: Building2 },
        { id: 'categories', label: 'Categories', href: '/catalog/categories', icon: FolderTree },
        { id: 'collections', label: 'Collections', href: '/catalog/collections', icon: Book },
        // Variants removed - use CollectionsCatalog instead
      ]);
      if (import.meta.env.DEV) {
        console.log('✅ Variants.tsx: Registered Catalog submodules (variants removed)');
      }
    }
  }, [registerSubmodules]);
  const [selectedCollectionId, setSelectedCollectionId] = useState<string>('');
  const { variants, loading, error, createVariant, updateVariant, deleteVariant, isCreating, isDeleting } = useCatalogVariantsCRUD(selectedCollectionId || undefined);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'name' | 'code' | 'color_name' | 'sort_order'>('sort_order');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [showNewModal, setShowNewModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ name: '', code: '', color_name: '', active: true, sort_order: 0, collection_id: '' });

  // Filter and sort
  const filteredVariants = useMemo(() => {
    const filtered = variants.filter(v => {
      const searchLower = searchTerm.toLowerCase();
      return !searchTerm || 
        v.name.toLowerCase().includes(searchLower) ||
        (v.code && v.code.toLowerCase().includes(searchLower)) ||
        (v.color_name && v.color_name.toLowerCase().includes(searchLower));
    });

    return filtered.sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;

      if (sortBy === 'name') {
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
      } else if (sortBy === 'code') {
        aValue = (a.code || '').toLowerCase();
        bValue = (b.code || '').toLowerCase();
      } else if (sortBy === 'color_name') {
        aValue = (a.color_name || '').toLowerCase();
        bValue = (b.color_name || '').toLowerCase();
      } else {
        aValue = a.sort_order;
        bValue = b.sort_order;
      }

      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [variants, searchTerm, sortBy, sortOrder]);

  // Pagination
  const totalPages = Math.ceil(filteredVariants.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedVariants = filteredVariants.slice(startIndex, startIndex + itemsPerPage);

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  const handleNew = () => {
    setFormData({ 
      name: '', 
      code: '', 
      color_name: '', 
      active: true, 
      sort_order: 0, 
      collection_id: selectedCollectionId || '' 
    });
    setEditingId(null);
    setShowNewModal(true);
  };

  const handleEdit = (variant: any) => {
    setFormData({
      name: variant.name,
      code: variant.code || '',
      color_name: variant.color_name || '',
      active: variant.active,
      sort_order: variant.sort_order || 0,
      collection_id: variant.collection_id,
    });
    setEditingId(variant.id);
    setShowNewModal(true);
  };

  const handleSave = async () => {
    try {
      if (!formData.collection_id) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Collection is required',
        });
        return;
      }

      if (editingId) {
        await updateVariant(editingId, formData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Variant updated',
          message: 'Variant has been updated successfully.',
        });
      } else {
        await createVariant(formData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Variant created',
          message: 'Variant has been created successfully.',
        });
      }
      setShowNewModal(false);
      setFormData({ name: '', code: '', color_name: '', active: true, sort_order: 0, collection_id: selectedCollectionId || '' });
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
      title: 'Eliminar Variante',
      message: `¿Estás seguro de que deseas eliminar "${name}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteVariant(id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Variante eliminada',
        message: 'La variante ha sido eliminada correctamente.',
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
          <h1 className="text-title font-semibold text-foreground mb-1">Variants</h1>
          <p className="text-small text-muted-foreground">Manage product variants (colors) by collection</p>
        </div>
        <button
          onClick={handleNew}
          disabled={!selectedCollectionId}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Plus className="w-4 h-4" />
          Add New Variant
        </button>
      </div>

      {/* Search and Filter Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search variants by name, code, or color..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <div className="flex items-center gap-2">
              <Filter className="w-4 h-4 text-gray-400" />
              <select
                value={selectedCollectionId}
                onChange={(e) => {
                  setSelectedCollectionId(e.target.value);
                  setCurrentPage(1);
                }}
                className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              >
                <option value="">All Collections</option>
                {collections.map(collection => (
                  <option key={collection.id} value={collection.id}>
                    {collection.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Loading variants...</p>
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
                      onClick={() => handleSort('sort_order')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Order
                      {sortBy === 'sort_order' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
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
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('color_name')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Color Name
                      {sortBy === 'color_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Collection</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Status</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredVariants.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <Palette className="w-12 h-12 text-gray-400 mb-4" />
                        <p className="text-gray-600 mb-2">No variants found</p>
                        <p className="text-sm text-gray-500">
                          {!selectedCollectionId 
                            ? 'Select a collection to view variants'
                            : variants.length === 0 
                            ? 'Start by adding variants to this collection'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedVariants.map((variant) => {
                    const collection = collections.find(c => c.id === variant.collection_id);
                    return (
                      <tr 
                        key={variant.id} 
                        className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                      >
                        <td className="py-3 px-4 text-gray-700 text-xs">
                          {variant.sort_order}
                        </td>
                        <td className="py-3 px-4 text-gray-900 text-xs font-medium">
                          {variant.name}
                        </td>
                        <td className="py-3 px-4 text-gray-700 text-xs">
                          {variant.code || 'N/A'}
                        </td>
                        <td className="py-3 px-4 text-gray-700 text-xs">
                          {variant.color_name || 'N/A'}
                        </td>
                        <td className="py-3 px-4 text-gray-700 text-xs">
                          {collection?.name || 'N/A'}
                        </td>
                        <td className="py-3 px-4 text-gray-700 text-xs">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                            variant.active 
                              ? 'bg-green-100 text-green-800' 
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {variant.active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="py-3 px-4" onClick={(e) => e.stopPropagation()}>
                          <div className="flex items-center gap-1 justify-end">
                            <button 
                              onClick={() => handleEdit(variant)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title={`Edit ${variant.name}`}
                            >
                              <Edit className="w-4 h-4" />
                            </button>
                            <button 
                              onClick={() => handleDelete(variant.id, variant.name)}
                              disabled={isDeleting}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title={`Delete ${variant.name}`}
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination */}
      {filteredVariants.length > 0 && (
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
                Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredVariants.length)} of {filteredVariants.length}
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
                setFormData({ name: '', code: '', color_name: '', active: true, sort_order: 0, collection_id: selectedCollectionId || '' });
                setEditingId(null);
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span className="text-2xl">&times;</span>
            </button>

            <h2 className="text-xl font-semibold text-gray-900 mb-4">
              {editingId ? 'Edit Variant' : 'New Variant'}
            </h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Collection <span className="text-red-500">*</span>
                </label>
                <select
                  value={formData.collection_id}
                  onChange={(e) => setFormData({ ...formData, collection_id: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  disabled={!!editingId}
                >
                  <option value="">Select a collection</option>
                  {collections.map(collection => (
                    <option key={collection.id} value={collection.id}>
                      {collection.name}
                    </option>
                  ))}
                </select>
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
                  placeholder="Variant name"
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
                  placeholder="Variant code (optional)"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Color Name
                </label>
                <input
                  type="text"
                  value={formData.color_name}
                  onChange={(e) => setFormData({ ...formData, color_name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  placeholder="Color name (optional)"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Sort Order
                </label>
                <input
                  type="number"
                  value={formData.sort_order}
                  onChange={(e) => setFormData({ ...formData, sort_order: parseInt(e.target.value) || 0 })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  placeholder="0"
                />
              </div>

              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="active"
                  checked={formData.active}
                  onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                  className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
                />
                <label htmlFor="active" className="ml-2 text-sm text-gray-700">
                  Active
                </label>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={() => {
                  setShowNewModal(false);
                  setFormData({ name: '', code: '', color_name: '', active: true, sort_order: 0, collection_id: selectedCollectionId || '' });
                  setEditingId(null);
                }}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={!formData.name.trim() || !formData.collection_id || isCreating}
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

