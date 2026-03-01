import { useEffect, useState, useMemo, useImperativeHandle, forwardRef } from 'react';

export interface CategoriesRef {
  openNew: () => void;
  openNewParent: () => void;
}
interface CategoriesProps {
  itemsForCounts?: Array<{ category_id?: string | null }>;
}
import { useItemCategoriesCRUD } from '../../hooks/useCatalog';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { 
  Search, 
  Plus,
  Edit,
  Trash2,
  Eye,
  ArrowRightLeft,
} from 'lucide-react';

const Categories = forwardRef<CategoriesRef, CategoriesProps>(function Categories({ itemsForCounts = [] }, ref) {
  const { categories, loading, error, createCategory, updateCategory, deleteCategory, isCreating, isDeleting } = useItemCategoriesCRUD();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const { activeOrganizationId } = useOrganizationContext();

  const [searchTerm, setSearchTerm] = useState('');
  const [showNewModal, setShowNewModal] = useState(false);
  const [showMoveItemsModal, setShowMoveItemsModal] = useState(false);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [modalMode, setModalMode] = useState<'category' | 'subcategory'>('category');
  const [selectedParentId, setSelectedParentId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ name: '', code: '', parent_id: '', sort_order: 0 });
  const [moveSourceSubcategory, setMoveSourceSubcategory] = useState<{ id: string; name: string } | null>(null);
  const [moveTargetSubcategoryId, setMoveTargetSubcategoryId] = useState('');
  const [isMovingItems, setIsMovingItems] = useState(false);
  const [itemCounts, setItemCounts] = useState<Map<string, number>>(new Map());

  useEffect(() => {
    if (itemsForCounts.length > 0) {
      const counts = new Map<string, number>();
      itemsForCounts.forEach((item) => {
        const catId = item.category_id;
        if (!catId) return;
        counts.set(catId, (counts.get(catId) || 0) + 1);
      });
      setItemCounts(counts);
      return;
    }

    async function fetchItemCounts() {
      if (!activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('CatalogItems')
          .select('category_id')
          .eq('organization_id', activeOrganizationId)
          .not('category_id', 'is', null);

        if (error) {
          console.error('Error fetching item counts:', error);
          return;
        }

        // Count items per category
        const counts = new Map<string, number>();
        (data || []).forEach((item: any) => {
          const catId = item.category_id;
          counts.set(catId, (counts.get(catId) || 0) + 1);
        });

        setItemCounts(counts);
      } catch (err) {
        console.error('Error fetching item counts:', err);
      }
    }

    fetchItemCounts();
  }, [activeOrganizationId, categories, itemsForCounts]);

  const parentCategories = useMemo(() => {
    return categories
      .filter((c) => c.is_group && !c.parent_id)
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.name.localeCompare(b.name));
  }, [categories]);

  const subcategories = useMemo(() => {
    return categories
      .filter((c) => !c.is_group && Boolean(c.parent_id))
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.name.localeCompare(b.name));
  }, [categories]);

  useEffect(() => {
    if (!parentCategories.length) {
      setSelectedParentId(null);
      return;
    }
    if (!selectedParentId || !parentCategories.some((p) => p.id === selectedParentId)) {
      setSelectedParentId(parentCategories[0].id);
    }
  }, [parentCategories, selectedParentId]);

  const filteredParents = useMemo(() => {
    const searchLower = searchTerm.toLowerCase();
    if (!searchLower) return parentCategories;
    return parentCategories.filter((c) => c.name.toLowerCase().includes(searchLower) || (c.code || '').toLowerCase().includes(searchLower));
  }, [parentCategories, searchTerm]);

  const filteredSubcategories = useMemo(() => {
    const searchLower = searchTerm.toLowerCase();
    const byParent = selectedParentId ? subcategories.filter((c) => c.parent_id === selectedParentId) : subcategories;
    if (!searchLower) return byParent;
    return byParent.filter((c) => c.name.toLowerCase().includes(searchLower) || (c.code || '').toLowerCase().includes(searchLower));
  }, [searchTerm, selectedParentId, subcategories]);

  const subcategoryCountByParent = useMemo(() => {
    const counts = new Map<string, number>();
    subcategories.forEach((sub) => {
      if (!sub.parent_id) return;
      counts.set(sub.parent_id, (counts.get(sub.parent_id) || 0) + 1);
    });
    return counts;
  }, [subcategories]);

  const itemsCountByParent = useMemo(() => {
    const counts = new Map<string, number>();
    subcategories.forEach((sub) => {
      if (!sub.parent_id) return;
      counts.set(sub.parent_id, (counts.get(sub.parent_id) || 0) + (itemCounts.get(sub.id) || 0));
    });
    return counts;
  }, [subcategories, itemCounts]);

  const openCategoryModal = (mode: 'category' | 'subcategory', parentId?: string | null) => {
    setModalMode(mode);
    setShowNewModal(true);
    setEditingCategoryId(null);
    setFormData({
      name: '',
      code: '',
      parent_id: mode === 'subcategory' ? (parentId || selectedParentId || '') : '',
      sort_order: 0,
    });
  };

  const closeModal = () => {
    setShowNewModal(false);
    setEditingCategoryId(null);
    setFormData({ name: '', code: '', parent_id: '', sort_order: 0 });
    setModalMode('category');
  };

  const handleEdit = (category: any) => {
    setEditingCategoryId(category.id);
    setModalMode(category.is_group ? 'category' : 'subcategory');
    setFormData({
      name: category.name || '',
      code: category.code || '',
      parent_id: category.parent_id || '',
      sort_order: category.sort_order || 0,
    });
    setShowNewModal(true);
  };

  const handleSave = async () => {
    try {
      const data = {
        name: formData.name.trim(),
        code: formData.code.trim() || null,
        parent_id: modalMode === 'subcategory' ? (formData.parent_id || null) : null,
        is_group: modalMode === 'category',
        sort_order: formData.sort_order ?? 0,
      };

      if (modalMode === 'subcategory' && !data.parent_id) {
        throw new Error('Subcategory requires a parent category');
      }

      if (editingCategoryId) {
        await updateCategory(editingCategoryId, data);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Category updated',
          message: 'Saved successfully.',
        });
      } else {
        const created = await createCategory(data as any);
        if (modalMode === 'category' && created?.id) {
          setSelectedParentId(created.id);
        }
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Category created',
          message: 'Created successfully.',
        });
      }

      closeModal();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  };

  useImperativeHandle(ref, () => ({
    openNew: () => openCategoryModal('subcategory'),
    openNewParent: () => openCategoryModal('category'),
  }), [selectedParentId]);

  const handleDelete = async (id: string, name: string) => {
    const confirmed = await showConfirm({
      title: 'Eliminar Categoría',
        message: `¿Eliminar "${name}"?`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteCategory(id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Categoría eliminada',
        message: 'La categoría ha sido eliminada correctamente.',
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

  const openMoveItemsModal = (source: { id: string; name: string }) => {
    setMoveSourceSubcategory(source);
    setMoveTargetSubcategoryId('');
    setShowMoveItemsModal(true);
  };

  const closeMoveItemsModal = () => {
    setShowMoveItemsModal(false);
    setMoveSourceSubcategory(null);
    setMoveTargetSubcategoryId('');
  };

  const handleMoveItems = async () => {
    if (!moveSourceSubcategory || !moveTargetSubcategoryId || !activeOrganizationId) return;
    if (moveSourceSubcategory.id === moveTargetSubcategoryId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid destination',
        message: 'Choose a different subcategory.',
      });
      return;
    }

    try {
      setIsMovingItems(true);

      const { count: sourceCount, error: countError } = await supabase
        .from('CatalogItems')
        .select('id', { count: 'exact', head: true })
        .eq('organization_id', activeOrganizationId)
        .eq('category_id', moveSourceSubcategory.id);

      if (countError) {
        throw new Error(countError.message || 'Failed to count source items');
      }

      const toMove = sourceCount || 0;
      if (toMove === 0) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'No items to move',
          message: `Subcategory "${moveSourceSubcategory.name}" has no assigned items.`,
        });
        closeMoveItemsModal();
        return;
      }

      const { error: moveError } = await supabase
        .from('CatalogItems')
        .update({ category_id: moveTargetSubcategoryId, updated_at: new Date().toISOString() })
        .eq('organization_id', activeOrganizationId)
        .eq('category_id', moveSourceSubcategory.id);

      if (moveError) {
        throw new Error(moveError.message || 'Failed to move items');
      }

      setItemCounts((prev) => {
        const next = new Map(prev);
        const sourceCurrent = next.get(moveSourceSubcategory.id) || 0;
        const targetCurrent = next.get(moveTargetSubcategoryId) || 0;
        const moved = Math.min(sourceCurrent, toMove);
        next.set(moveSourceSubcategory.id, Math.max(0, sourceCurrent - moved));
        next.set(moveTargetSubcategoryId, targetCurrent + moved);
        return next;
      });

      const targetName = subcategories.find((s) => s.id === moveTargetSubcategoryId)?.name || 'target';
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Items moved',
        message: `${toMove} item(s) moved from "${moveSourceSubcategory.name}" to "${targetName}".`,
      });
      closeMoveItemsModal();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Move failed',
        message: error instanceof Error ? error.message : 'Unknown error while moving items.',
      });
    } finally {
      setIsMovingItems(false);
    }
  };

  return (
    <div>
      {/* Search Bar — spacing from status bar: mt-4 from parent */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search categories by name or code..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Categories Tree */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Loading categories...</p>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <p className="text-sm text-red-600">Error: {error}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-200 flex items-center justify-between">
              <h3 className="text-sm font-semibold text-gray-900">Categories</h3>
              <button
                onClick={() => openCategoryModal('category')}
                className="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded border border-gray-200 hover:bg-gray-50"
              >
                <Plus className="w-3 h-3" />
                Add
              </button>
            </div>
            {filteredParents.length === 0 ? (
              <div className="py-10 text-center text-sm text-gray-500">No categories found</div>
            ) : (
              <div>
                {filteredParents.map((category) => (
                  <div
                    key={category.id}
                    className={`px-4 py-2 border-b border-gray-100 flex items-center gap-2 ${selectedParentId === category.id ? 'bg-primary/5' : 'hover:bg-gray-50'}`}
                  >
                    <button
                      onClick={() => setSelectedParentId(category.id)}
                      className="flex-1 text-left min-w-0"
                    >
                      <div className="text-xs font-medium text-gray-900 truncate">{category.name}</div>
                      <div className="text-[11px] text-gray-500 truncate">
                        {(subcategoryCountByParent.get(category.id) || 0)} subcategories · {(itemsCountByParent.get(category.id) || 0)} items
                      </div>
                    </button>
                    <button
                      onClick={() => openCategoryModal('subcategory', category.id)}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                      title="Add subcategory"
                    >
                      <Plus className="w-3 h-3" />
                    </button>
                    <button
                      onClick={() => handleEdit(category)}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                      title="Edit category"
                    >
                      <Edit className="w-3 h-3" />
                    </button>
                    <button
                      onClick={() => handleDelete(category.id, category.name)}
                      disabled={isDeleting}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600 disabled:opacity-50"
                      title="Delete category"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-200 flex items-center justify-between">
              <h3 className="text-sm font-semibold text-gray-900">Subcategories</h3>
              <button
                onClick={() => openCategoryModal('subcategory', selectedParentId)}
                disabled={!selectedParentId}
                className="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-50"
              >
                <Plus className="w-3 h-3" />
                Add
              </button>
            </div>
            {!selectedParentId ? (
              <div className="py-10 text-center text-sm text-gray-500">Select a category to see subcategories</div>
            ) : filteredSubcategories.length === 0 ? (
              <div className="py-10 text-center text-sm text-gray-500">No subcategories for this category</div>
            ) : (
              <div>
                {filteredSubcategories.map((sub) => (
                  <div key={sub.id} className="px-4 py-2 border-b border-gray-100 flex items-center gap-2 hover:bg-gray-50">
                    <div className="flex-1 min-w-0">
                      <div className="text-xs font-medium text-gray-900 truncate">{sub.name}</div>
                      <div className="text-[11px] text-gray-500 truncate">
                        {itemCounts.get(sub.id) || 0} items{sub.code ? ` · ${sub.code}` : ''}
                      </div>
                    </div>
                    {(itemCounts.get(sub.id) || 0) > 0 && (
                      <button
                        onClick={() => {
                          window.sessionStorage.setItem(
                            'catalogItemsBackContext',
                            JSON.stringify({
                              fromTab: 'categories',
                              selectedCategoryId: sub.id,
                              savedAt: Date.now(),
                            })
                          );
                          router.navigate(withReturnTo(`/catalog/items?category_id=${sub.id}`));
                        }}
                        className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                        title="View items"
                      >
                        <Eye className="w-3 h-3" />
                      </button>
                    )}
                    <button
                      onClick={() => openMoveItemsModal({ id: sub.id, name: sub.name })}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                      title="Move items to another subcategory"
                    >
                      <ArrowRightLeft className="w-3 h-3" />
                    </button>
                    <button
                      onClick={() => handleEdit(sub)}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                      title="Edit subcategory"
                    >
                      <Edit className="w-3 h-3" />
                    </button>
                    <button
                      onClick={() => handleDelete(sub.id, sub.name)}
                      disabled={isDeleting}
                      className="p-1.5 hover:bg-gray-100 rounded text-gray-600 disabled:opacity-50"
                      title="Delete subcategory"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* New/Edit Modal */}
      {showNewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <button
              onClick={closeModal}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span className="text-2xl">&times;</span>
            </button>

            <h2 className="text-xl font-semibold text-gray-900 mb-4">
              {editingCategoryId
                ? `Edit ${modalMode === 'category' ? 'Category' : 'Subcategory'}`
                : `New ${modalMode === 'category' ? 'Category' : 'Subcategory'}`}
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
                  placeholder="Category name"
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
                  placeholder="Category code (optional)"
                />
              </div>

              {modalMode === 'subcategory' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Parent Category <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.parent_id}
                    onChange={(e) => setFormData({ ...formData, parent_id: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  >
                    <option value="">Select parent category</option>
                    {categories
                      .filter(c => c.is_group && (!editingCategoryId || c.id !== editingCategoryId))
                      .map(category => (
                        <option key={category.id} value={category.id}>
                          {category.name} {category.code && `(${category.code})`}
                        </option>
                      ))}
                  </select>
                </div>
              )}

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
            </div>

            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={closeModal}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={!formData.name.trim() || isCreating || (modalMode === 'subcategory' && !formData.parent_id)}
                className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isCreating ? 'Saving...' : editingCategoryId ? 'Update' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Move Items Modal */}
      {showMoveItemsModal && moveSourceSubcategory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <button
              onClick={closeMoveItemsModal}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span className="text-2xl">&times;</span>
            </button>

            <h2 className="text-xl font-semibold text-gray-900 mb-4">Move items</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">From subcategory</label>
                <input
                  type="text"
                  value={moveSourceSubcategory.name}
                  disabled
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-700"
                />
                <p className="text-xs text-gray-500 mt-1">
                  {itemCounts.get(moveSourceSubcategory.id) || 0} item(s) currently assigned
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  To subcategory <span className="text-red-500">*</span>
                </label>
                <select
                  value={moveTargetSubcategoryId}
                  onChange={(e) => setMoveTargetSubcategoryId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                >
                  <option value="">Select destination subcategory</option>
                  {subcategories
                    .filter((s) => s.id !== moveSourceSubcategory.id)
                    .map((subcategory) => (
                      <option key={subcategory.id} value={subcategory.id}>
                        {subcategory.name}
                      </option>
                    ))}
                </select>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 mt-6">
              <button
                onClick={closeMoveItemsModal}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleMoveItems}
                disabled={!moveTargetSubcategoryId || isMovingItems}
                className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isMovingItems ? 'Moving...' : 'Move items'}
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

export default Categories;

