import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useItemCategoriesCRUD } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { 
  Search, 
  Plus,
  Edit,
  Trash2,
  ChevronRight,
  Folder,
  FolderOpen,
  SortAsc,
  SortDesc,
  Package,
  Building2,
  FolderTree,
  Book,
} from 'lucide-react';

export default function Categories() {
  const { registerSubmodules } = useSubmoduleNav();
  const { categories, loading, error, createCategory, updateCategory, deleteCategory, isCreating, isDeleting } = useItemCategoriesCRUD();
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
        console.log('✅ Categories.tsx: Registered Catalog submodules');
      }
    }
  }, [registerSubmodules]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showNewModal, setShowNewModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({ name: '', code: '', parent_category_id: '', is_group: false, sort_order: 0 });
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set());

  // Build tree structure
  interface CategoryNode {
    id: string;
    organization_id: string;
    parent_id?: string | null;
    parent_category_id?: string | null;
    name: string;
    code?: string | null;
    is_group?: boolean;
    sort_order: number;
    deleted: boolean;
    archived: boolean;
    created_at: string;
    updated_at?: string | null;
    children: CategoryNode[];
  }

  const categoryTree = useMemo(() => {
    const categoryMap = new Map<string, CategoryNode>(
      categories.map(c => [c.id, { ...c, children: [] as CategoryNode[] }])
    );
    const roots: CategoryNode[] = [];

    categories.forEach(category => {
      const node = categoryMap.get(category.id);
      if (!node) return;
      
      // Use parent_category_id (preferred) or parent_id (legacy)
      const parentId = category.parent_category_id || category.parent_id;
      
      if (parentId && categoryMap.has(parentId)) {
        const parent = categoryMap.get(parentId);
        if (parent) {
          parent.children.push(node);
        }
      } else {
        roots.push(node);
      }
    });

    // Sort roots and children
    const sortNodes = (nodes: CategoryNode[]) => {
      nodes.sort((a, b) => {
        if (a.sort_order !== b.sort_order) return a.sort_order - b.sort_order;
        return a.name.localeCompare(b.name);
      });
      nodes.forEach(node => {
        if (node.children.length > 0) {
          sortNodes(node.children);
        }
      });
    };

    sortNodes(roots);
    return roots;
  }, [categories]);

  // Flatten tree for search
  const flattenTree = (nodes: CategoryNode[], level = 0): Array<CategoryNode & { level: number }> => {
    const result: Array<CategoryNode & { level: number }> = [];
    nodes.forEach(node => {
      result.push({ ...node, level });
      if (node.children && node.children.length > 0) {
        result.push(...flattenTree(node.children, level + 1));
      }
    });
    return result;
  };

  const filteredCategories = useMemo(() => {
    if (!searchTerm) return flattenTree(categoryTree);
    
    const searchLower = searchTerm.toLowerCase();
    return flattenTree(categoryTree).filter(c => 
      c.name.toLowerCase().includes(searchLower) ||
      (c.code && c.code.toLowerCase().includes(searchLower))
    );
  }, [categoryTree, searchTerm]);

  const toggleExpand = (id: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const handleNew = (parentId?: string, isGroup: boolean = false) => {
    setFormData({ 
      name: '', 
      code: '', 
      parent_category_id: parentId || '', 
      is_group: isGroup,
      sort_order: 0 
    });
    setEditingId(null);
    setShowNewModal(true);
  };

  const handleEdit = (category: any) => {
    setFormData({
      name: category.name,
      code: category.code || '',
      parent_category_id: category.parent_category_id || category.parent_id || '',
      is_group: category.is_group || false,
      sort_order: category.sort_order || 0,
    });
    setEditingId(category.id);
    setShowNewModal(true);
  };

  const handleSave = async () => {
    try {
      const data = {
        name: formData.name.trim(),
        code: formData.code.trim() || null,
        parent_category_id: formData.parent_category_id || null,
        is_group: formData.is_group,
        sort_order: formData.sort_order,
      };

      if (editingId) {
        await updateCategory(editingId, data);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Category updated',
          message: 'Category has been updated successfully.',
        });
      } else {
        await createCategory(data);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Category created',
          message: 'Category has been created successfully.',
        });
      }
      setShowNewModal(false);
      setFormData({ name: '', code: '', parent_category_id: '', is_group: false, sort_order: 0 });
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
      title: 'Eliminar Categoría',
      message: `¿Estás seguro de que deseas eliminar "${name}"? Esto también eliminará todas las subcategorías. Esta acción no se puede deshacer.`,
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

  const renderCategory = (category: CategoryNode & { level?: number }, level: number = 0) => {
    const hasChildren = category.children && category.children.length > 0;
    const isExpanded = expandedCategories.has(category.id);
    const indent = level * 24;
    const isGroup = category.is_group || false;

    return (
      <div key={category.id}>
        <div 
          className="flex items-center py-2 px-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
          style={{ paddingLeft: `${16 + indent}px` }}
        >
          <div className="flex items-center flex-1 min-w-0">
            {hasChildren ? (
              <button
                onClick={() => toggleExpand(category.id)}
                className="mr-2 text-gray-400 hover:text-gray-600"
              >
                {isExpanded ? (
                  <FolderOpen className="w-4 h-4" />
                ) : (
                  <Folder className="w-4 h-4" />
                )}
              </button>
            ) : (
              <div className="w-6 mr-2" />
            )}
            <span className="text-xs text-gray-900 font-medium flex-1 truncate">{category.name}</span>
            {category.code && (
              <span className="text-xs text-gray-500 ml-2">{category.code}</span>
            )}
            {isGroup && (
              <span className="ml-2 text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded">
                Group
              </span>
            )}
          </div>
          <div className="flex items-center gap-1 ml-4">
            {!isGroup && (
              <button
                onClick={() => handleNew(category.id, false)}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                title="Add subcategory"
              >
                <Plus className="w-3 h-3" />
              </button>
            )}
            <button
              onClick={() => handleEdit(category)}
              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
              title={`Edit ${category.name}`}
            >
              <Edit className="w-3 h-3" />
            </button>
            <button
              onClick={() => handleDelete(category.id, category.name)}
              disabled={isDeleting}
              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
              title={`Delete ${category.name}`}
            >
              <Trash2 className="w-3 h-3" />
            </button>
          </div>
        </div>
        {hasChildren && isExpanded && (
          <div>
            {category.children.map((child) => renderCategory(child, level + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Categories</h1>
          <p className="text-small text-muted-foreground">Manage product categories (nested structure)</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => handleNew(undefined, true)}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <Plus className="w-4 h-4" />
            Add Parent Group
          </button>
          <button
            onClick={() => handleNew()}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-4 h-4" />
            Add Category
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search categories by name or code..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
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
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          {searchTerm ? (
            <div>
              {filteredCategories.length === 0 ? (
                <div className="py-12 px-6 text-center">
                  <p className="text-gray-600 mb-2">No categories found</p>
                  <p className="text-sm text-gray-500">Try adjusting your search criteria</p>
                </div>
              ) : (
                filteredCategories.map((category) => (
                  <div 
                    key={category.id}
                    className="flex items-center py-2 px-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
                    style={{ paddingLeft: `${16 + category.level * 24}px` }}
                  >
                    <span className="text-xs text-gray-900 font-medium flex-1">{category.name}</span>
                    {category.code && (
                      <span className="text-xs text-gray-500 ml-2">{category.code}</span>
                    )}
                    <div className="flex items-center gap-1 ml-4">
                      <button
                        onClick={() => handleEdit(category)}
                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                        title={`Edit ${category.name}`}
                      >
                        <Edit className="w-3 h-3" />
                      </button>
                      <button
                        onClick={() => handleDelete(category.id, category.name)}
                        disabled={isDeleting}
                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                        title={`Delete ${category.name}`}
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          ) : (
            <div>
              {categoryTree.length === 0 ? (
                <div className="py-12 px-6 text-center">
                  <Folder className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-600 mb-2">No categories found</p>
                  <p className="text-sm text-gray-500">Start by adding categories</p>
                </div>
              ) : (
                categoryTree.map(category => renderCategory(category, 0))
              )}
            </div>
          )}
        </div>
      )}

      {/* New/Edit Modal */}
      {showNewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <button
              onClick={() => {
                setShowNewModal(false);
                setFormData({ name: '', code: '', parent_category_id: '', is_group: false, sort_order: 0 });
                setEditingId(null);
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <span className="text-2xl">&times;</span>
            </button>

            <h2 className="text-xl font-semibold text-gray-900 mb-4">
              {editingId ? 'Edit Category' : 'New Category'}
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

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Is Group (Parent Category)
                </label>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_group}
                    onChange={(e) => setFormData({ ...formData, is_group: e.target.checked, parent_category_id: e.target.checked ? formData.parent_category_id : '' })}
                    className="w-4 h-4"
                  />
                  <span className="text-sm text-gray-700">
                    This is a parent group (not selectable for SKUs)
                  </span>
                </label>
              </div>

              {!formData.is_group && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Parent Category
                  </label>
                  <select
                    value={formData.parent_category_id}
                    onChange={(e) => setFormData({ ...formData, parent_category_id: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  >
                    <option value="">None (Root Category)</option>
                    {categories
                      .filter(c => (c.is_group || false) && (!editingId || c.id !== editingId))
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
                onClick={() => {
                  setShowNewModal(false);
                  setFormData({ name: '', code: '', parent_category_id: '', is_group: false, sort_order: 0 });
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

