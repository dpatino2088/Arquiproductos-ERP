import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useCatalogItems, useDeleteCatalogItem } from '../../hooks/useCatalog';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { 
  Search, 
  Filter,
  Plus,
  Upload,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Edit,
  Copy,
  Eye,
  Trash2,
  Archive,
  User,
  Image as ImageIcon
} from 'lucide-react';

interface Item {
  id: string;
  sku: string;
  itemName: string;
  manufacturer: string;
  category: string;
  family: string;
  image?: string;
}

export default function Items() {
  const { registerSubmodules } = useSubmoduleNav();
  const { items, loading, error, refetch } = useCatalogItems();
  const { activeOrganizationId } = useOrganizationContext();
  const { deleteItem, isDeleting } = useDeleteCatalogItem();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'manufacturer' | 'sku' | 'itemName' | 'category' | 'family'>('sku');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedManufacturer, setSelectedManufacturer] = useState<string[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string[]>([]);
  const [selectedFamily, setSelectedFamily] = useState<string[]>([]);

  useEffect(() => {
    registerSubmodules('Catalog', [
      { id: 'items', label: 'Items', href: '/catalog/items' },
      { id: 'collections', label: 'Collections', href: '/catalog/collections' },
    ]);
  }, [registerSubmodules]);


  // Transform catalog items to display format
  const itemsData: Item[] = useMemo(() => {
    if (!items) return [];
    return items.map(item => ({
      id: item.id,
      sku: item.sku,
      itemName: item.name,
      manufacturer: item.metadata?.manufacturer || 'Not specified',
      category: item.metadata?.category || 'Not specified',
      family: item.metadata?.family || 'Not specified',
      image: item.metadata?.image,
    }));
  }, [items]);

  // Use real data from database
  const displayItems = itemsData;

  // Filter and sort items
  const filteredItems = useMemo(() => {
    const filtered = displayItems.filter(item => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        item.sku.toLowerCase().includes(searchLower) ||
        item.itemName.toLowerCase().includes(searchLower) ||
        item.manufacturer.toLowerCase().includes(searchLower) ||
        item.category.toLowerCase().includes(searchLower) ||
        item.family.toLowerCase().includes(searchLower)
      );

      // Manufacturer filter
      const matchesManufacturer = selectedManufacturer.length === 0 || selectedManufacturer.includes(item.manufacturer);

      // Category filter
      const matchesCategory = selectedCategory.length === 0 || selectedCategory.includes(item.category);

      // Family filter
      const matchesFamily = selectedFamily.length === 0 || selectedFamily.includes(item.family);

      return matchesSearch && matchesManufacturer && matchesCategory && matchesFamily;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string;
      let bValue: string;

      switch (sortBy) {
        case 'manufacturer':
          aValue = a.manufacturer.toLowerCase();
          bValue = b.manufacturer.toLowerCase();
          break;
        case 'sku':
          aValue = a.sku.toLowerCase();
          bValue = b.sku.toLowerCase();
          break;
        case 'itemName':
          aValue = a.itemName.toLowerCase();
          bValue = b.itemName.toLowerCase();
          break;
        case 'category':
          aValue = a.category.toLowerCase();
          bValue = b.category.toLowerCase();
          break;
        case 'family':
          aValue = a.family.toLowerCase();
          bValue = b.family.toLowerCase();
          break;
        default:
          aValue = a.sku.toLowerCase();
          bValue = b.sku.toLowerCase();
      }

      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [searchTerm, itemsData, sortBy, sortOrder, selectedManufacturer, selectedCategory, selectedFamily]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredItems.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedItems = filteredItems.slice(startIndex, startIndex + itemsPerPage);

  // Reset to first page when search changes
  useMemo(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Handle filter toggles
  const handleManufacturerToggle = (manufacturer: string) => {
    setSelectedManufacturer(prev => 
      prev.includes(manufacturer) 
        ? prev.filter(m => m !== manufacturer)
        : [...prev, manufacturer]
    );
  };

  const handleCategoryToggle = (category: string) => {
    setSelectedCategory(prev => 
      prev.includes(category) 
        ? prev.filter(c => c !== category)
        : [...prev, category]
    );
  };

  const handleFamilyToggle = (family: string) => {
    setSelectedFamily(prev => 
      prev.includes(family) 
        ? prev.filter(f => f !== family)
        : [...prev, family]
    );
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedManufacturer([]);
    setSelectedCategory([]);
    setSelectedFamily([]);
    setSearchTerm('');
  };

  // Handlers for actions
  const handleEditItem = (item: Item, e?: React.MouseEvent) => {
    e?.stopPropagation();
    router.navigate(`/catalog/items/edit/${item.id}`);
  };

  const handleArchiveItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    if (!confirm(`¿Estás seguro de que deseas archivar "${item.itemName}"?`)) {
      return;
    }

    try {
      if (!activeOrganizationId) return;
      
      const { error } = await supabase
        .from('CatalogItems')
        .update({ archived: true })
        .eq('id', item.id)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Item archivado',
        message: 'El item ha sido archivado correctamente.',
      });
      
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al archivar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    }
  };

  const handleDeleteItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    if (!confirm(`¿Estás seguro de que deseas eliminar "${item.itemName}"? Esta acción no se puede deshacer.`)) {
      return;
    }

    try {
      await deleteItem(item.id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Item eliminado',
        message: 'El item ha sido eliminado correctamente.',
      });
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al eliminar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    }
  };

  // Get unique filter options
  const manufacturerOptions = Array.from(new Set(displayItems.map(item => item.manufacturer).filter(Boolean)));
  const categoryOptions = Array.from(new Set(displayItems.map(item => item.category).filter(Boolean)));
  const familyOptions = Array.from(new Set(displayItems.map(item => item.family).filter(Boolean)));

  const totalActiveFilters = selectedManufacturer.length + selectedCategory.length + selectedFamily.length;

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Items</h1>
          <p className="text-small text-muted-foreground">Manage your product catalog, items, and collections</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <Upload className="w-4 h-4" />
            Import
          </button>
          <button
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
            onClick={() => router.navigate('/catalog/items/new')}
          >
            <Plus className="w-4 h-4" />
            Add New Items
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
                placeholder="Search items by name, SKU, manufacturer, category, or family..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters || totalActiveFilters > 0
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
              {totalActiveFilters > 0 && (
                <span className="bg-white text-primary rounded-full px-2 py-0.5 text-xs font-semibold">
                  {totalActiveFilters}
                </span>
              )}
            </button>
            <div className="flex items-center gap-1 border border-gray-200 rounded-lg overflow-hidden">
              <button
                onClick={() => setViewMode('table')}
                className={`p-2 transition-colors ${
                  viewMode === 'table'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <List className="w-4 h-4" />
              </button>
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 transition-colors ${
                  viewMode === 'grid'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <Grid3X3 className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Filters Dropdown */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="grid grid-cols-3 gap-4 mb-4">
                {/* Manufacturer Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Manufacturer</span>
                    {selectedManufacturer.length > 0 && (
                      <button
                        onClick={() => setSelectedManufacturer([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedManufacturer.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {manufacturerOptions.map((manufacturer) => (
                      <div
                        key={manufacturer}
                        onClick={() => handleManufacturerToggle(manufacturer)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedManufacturer.includes(manufacturer)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{manufacturer}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Category Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Category</span>
                    {selectedCategory.length > 0 && (
                      <button
                        onClick={() => setSelectedCategory([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedCategory.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {categoryOptions.map((category) => (
                      <div
                        key={category}
                        onClick={() => handleCategoryToggle(category)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedCategory.includes(category)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{category}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Family Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Family</span>
                    {selectedFamily.length > 0 && (
                      <button
                        onClick={() => setSelectedFamily([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedFamily.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {familyOptions.map((family) => (
                      <div
                        key={family}
                        onClick={() => handleFamilyToggle(family)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedFamily.includes(family)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{family}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              <div className="flex justify-between items-center">
                <button 
                  onClick={clearAllFilters}
                  className="text-xs text-gray-500 hover:text-gray-700"
                >
                  Clear all filters
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Table View */}
      {viewMode === 'table' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('manufacturer')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Manufacturer
                      {sortBy === 'manufacturer' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('sku')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      SKU
                      {sortBy === 'sku' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('itemName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Item Name
                      {sortBy === 'itemName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Image</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('category')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Category
                      {sortBy === 'category' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('family')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Family
                      {sortBy === 'family' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <Search className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No items found</p>
                        <p className="text-sm text-gray-500">
                          {displayItems.length === 0 
                            ? 'Start by adding items'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedItems.map((item) => (
                    <tr 
                      key={item.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.manufacturer}
                      </td>
                      <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                        {item.sku}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.itemName}
                      </td>
                      <td className="py-4 px-6 text-gray-400 text-sm">
                        {item.image ? (
                          <img src={item.image} alt={item.itemName} className="w-10 h-10 object-cover rounded" />
                        ) : (
                          <span className="flex items-center justify-center w-10 h-10 bg-gray-100 rounded">
                            <ImageIcon className="w-4 h-4 text-gray-400" />
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.category}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.family}
                      </td>
                      <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={(e) => handleEditItem(item, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Editar ${item.itemName}`}
                            title={`Editar ${item.itemName}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleArchiveItem(item, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Archivar ${item.itemName}`}
                            title={`Archivar ${item.itemName}`}
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleDeleteItem(item, e)}
                            disabled={isDeleting}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            aria-label={`Eliminar ${item.itemName}`}
                            title={`Eliminar ${item.itemName}`}
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredItems.length)} of {filteredItems.length}
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
    </div>
  );
}

