import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useCatalogItems, useDeleteCatalogItem, useCatalogCategories } from '../../hooks/useCatalog';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import ImportCatalog from './ImportCatalog';
import Manufacturers from './Manufacturers';
import Categories from './Categories';
import Collections from './Collections';
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
  Image as ImageIcon,
  Package,
  Wrench,
} from 'lucide-react';
import ImageModal from '../../components/ui/ImageModal';

interface Item {
  id: string;
  sku: string;
  itemName: string;
  description?: string;
  item_type?: string;
  measure_basis?: string;
  uom?: string;
  is_fabric?: boolean;
  unit_price?: number;
  msrp?: number;
  updated_at?: string;
  active?: boolean;
  discontinued?: boolean;
  manufacturer?: string;
  category?: string;
  family?: string;
  image?: string;
}

export default function Items() {
  const { registerSubmodules } = useSubmoduleNav();
  const { items, loading, loadingMore, error, refetch } = useCatalogItems();
  const { categories: catalogCategories } = useCatalogCategories();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [activeTab, setActiveTab] = useState<'items' | 'manufacturer' | 'categories' | 'collection'>('items');

  // Register Catalog submodules when Items component mounts
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
      ]);
    }
  }, [registerSubmodules]);
  const { activeOrganizationId } = useOrganizationContext();
  const { deleteItem, isDeleting } = useDeleteCatalogItem();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'manufacturer' | 'sku' | 'itemName' | 'category' | 'measure_basis' | 'unit_price' | 'active' | 'family'>('sku');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedManufacturer, setSelectedManufacturer] = useState<string[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string[]>([]);
  const [selectedFamily, setSelectedFamily] = useState<string[]>([]);
  // Removed selectedItemType - using selectedCategory instead
  const [selectedMeasureBasis, setSelectedMeasureBasis] = useState<string[]>([]);
  const [selectedActive, setSelectedActive] = useState<string[]>([]);
  const [showImportModal, setShowImportModal] = useState(false);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);


  // Format date to DD/MM/YY format
  const formatDate = (dateString?: string | null): string => {
    if (!dateString) return 'N/A';
    try {
      const date = new Date(dateString);
      const day = String(date.getDate()).padStart(2, '0');
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const year = String(date.getFullYear()).slice(-2);
      return `${day}/${month}/${year}`;
    } catch {
      return 'N/A';
    }
  };

  // Create a map of category_id -> category name
  const categoryMap = useMemo(() => {
    const map = new Map<string, string>();
    catalogCategories.forEach(cat => {
      map.set(cat.id, cat.name);
    });
    return map;
  }, [catalogCategories]);

  // Transform catalog items to display format
  const itemsData: Item[] = useMemo(() => {
    if (!items || items.length === 0) return [];
    
    // ✅ OPTIMIZACIÓN: Filtrar items que no tengan los campos mínimos necesarios
    // Solo procesar items que tengan al menos id y sku
    const validItems = items.filter(item => item && item.id && (item.sku || item.name));
    
    return validItems.map(item => {
      // Get category name from category_id
      const categoryName = item.category_id 
        ? (categoryMap.get(item.category_id) || 'Not specified')
        : (item.metadata?.category || 'Not specified');
      
      // Get MSRP: use the value from CatalogItem (which already has msrp_sale_out from CatalogItemsMSRP)
      // Accept any numeric value (including 0, though 0 will display as $0.00)
      let msrpValue: number | undefined = undefined;
      if (item.msrp != null && item.msrp !== undefined) {
        const numValue = typeof item.msrp === 'number' ? item.msrp : Number(item.msrp);
        if (!isNaN(numValue)) {
          msrpValue = numValue;
        }
      }
      
      // ✅ OPTIMIZACIÓN: Asegurar que active esté siempre definido antes de renderizar
      // Si no está disponible, usar true como default (ya que solo cargamos items activos)
      const activeStatus = item.active !== undefined && item.active !== null 
        ? Boolean(item.active)
        : (item.is_active !== undefined && item.is_active !== null
          ? Boolean(item.is_active)
          : true); // Default a true ya que solo cargamos items con is_active=true
      
      // ✅ OPTIMIZACIÓN: Asegurar que todos los campos visibles tengan valores por defecto antes de renderizar
      return {
        id: item.id || '',
        sku: item.sku || 'N/A',
        itemName: item.name || item.item_name || 'N/A',
        description: item.description || undefined,
        item_type: undefined, // item_type column removed from DB - using category instead
        measure_basis: item.measure_basis || 'N/A',
        uom: item.uom || item.unit_of_measure || 'N/A',
        is_fabric: item.is_fabric || false,
        unit_price: item.unit_price || 0,
        // Keep msrp even if 0, so it can be displayed correctly
        msrp: msrpValue !== undefined ? msrpValue : 0, // Default a 0 si no está disponible
        updated_at: (item as any).updated_at || item.created_at || undefined,
        active: activeStatus, // ✅ Siempre definido antes de renderizar
        discontinued: item.discontinued || false,
        manufacturer: item.metadata?.manufacturer || 'Not specified',
        category: categoryName || 'N/A',
        family: item.metadata?.family || 'Not specified',
        image: item.image_url || item.metadata?.image || null,
      };
    });
  }, [items, categoryMap]);

  // Read category_id from URL params and filter
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const categoryIdParam = urlParams.get('category_id');
    
    if (categoryIdParam) {
      // Find the category name from the map
      const categoryName = categoryMap.get(categoryIdParam);
      if (categoryName) {
        setSelectedCategory([categoryName]);
      }
    }
  }, [categoryMap]);

  // ✅ OPTIMIZACIÓN: Solo usar items que tengan todos los campos básicos cargados
  // Filtrar items incompletos para evitar mostrar campos vacíos
  const displayItems = useMemo(() => {
    return itemsData.filter(item => {
      // Asegurar que tenga al menos id, sku o name
      return item && item.id && (item.sku || item.itemName);
    });
  }, [itemsData]);

  // Filter and sort items
  const filteredItems = useMemo(() => {
    const filtered = displayItems.filter(item => {
      // Search filter - FLEXIBLE (supports SKU with/without hyphens, collection, variant, color)
      const searchLower = searchTerm.toLowerCase().trim();
      const searchNormalized = searchLower.replace(/[-\s]/g, ''); // Remove hyphens and spaces
      
      const matchesSearch = !searchTerm || (() => {
        // Normalize SKU for flexible matching (SCR-3001 = SCR3001 = "SCR 3001")
        const skuNormalized = (item.sku || '').toLowerCase().replace(/[-\s]/g, '');
        
        // Get additional fields from original item data
        const itemData = items?.find(i => i.id === item.id);
        const collectionName = ((itemData as any)?.collection_name || '').toLowerCase();
        const variantName = ((itemData as any)?.variant_name || '').toLowerCase();
        const color = ((itemData as any)?.color || '').toLowerCase();
        
        return (
          // SKU: exact + normalized matching
          (item.sku || '').toLowerCase().includes(searchLower) ||
          skuNormalized.includes(searchNormalized) ||
          // Name
          (item.itemName || '').toLowerCase().includes(searchLower) ||
          // Description
          (item.description || '').toLowerCase().includes(searchLower) ||
          // Collection, Variant, Color
          collectionName.includes(searchLower) ||
          variantName.includes(searchLower) ||
          color.includes(searchLower) ||
          // Measure basis, UOM
          (item.measure_basis || '').toLowerCase().includes(searchLower) ||
          (item.uom || '').toLowerCase().includes(searchLower) ||
          // Manufacturer, Category, Family
          (item.manufacturer || '').toLowerCase().includes(searchLower) ||
          (item.category || '').toLowerCase().includes(searchLower) ||
          (item.family || '').toLowerCase().includes(searchLower)
        );
      })();

      // Manufacturer filter
      const matchesManufacturer = selectedManufacturer.length === 0 || (item.manufacturer && selectedManufacturer.includes(item.manufacturer));

      // Category filter
      const matchesCategory = selectedCategory.length === 0 || (item.category && selectedCategory.includes(item.category));

      // Family filter
      const matchesFamily = selectedFamily.length === 0 || (item.family && selectedFamily.includes(item.family));

      // Measure Basis filter
      const matchesMeasureBasis = selectedMeasureBasis.length === 0 || (item.measure_basis && selectedMeasureBasis.includes(item.measure_basis));

      // Active filter
      const matchesActive = selectedActive.length === 0 || (item.active !== undefined && selectedActive.includes(item.active ? 'Active' : 'Inactive'));

      return matchesSearch && matchesManufacturer && matchesCategory && matchesFamily && matchesMeasureBasis && matchesActive;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string;
      let bValue: string;

      switch (sortBy) {
        case 'manufacturer':
          aValue = (a.manufacturer || '').toLowerCase();
          bValue = (b.manufacturer || '').toLowerCase();
          break;
        case 'sku':
          aValue = (a.sku || '').toLowerCase();
          bValue = (b.sku || '').toLowerCase();
          break;
        case 'itemName':
          aValue = (a.itemName || '').toLowerCase();
          bValue = (b.itemName || '').toLowerCase();
          break;
        case 'category':
          aValue = (a.category || '').toLowerCase();
          bValue = (b.category || '').toLowerCase();
          break;
        case 'family':
          aValue = (a.family || '').toLowerCase();
          bValue = (b.family || '').toLowerCase();
          break;
        case 'category':
          aValue = (a.category || '').toLowerCase();
          bValue = (b.category || '').toLowerCase();
          break;
        case 'measure_basis':
          aValue = (a.measure_basis || '').toLowerCase();
          bValue = (b.measure_basis || '').toLowerCase();
          break;
        case 'unit_price':
          aValue = String(a.unit_price || 0);
          bValue = String(b.unit_price || 0);
          break;
        case 'active':
          aValue = String(a.active ? 1 : 0);
          bValue = String(b.active ? 1 : 0);
          break;
        default:
          aValue = (a.sku || '').toLowerCase();
          bValue = (b.sku || '').toLowerCase();
      }

      // For numeric fields, compare as numbers
      if (sortBy === 'unit_price' || sortBy === 'active') {
        const aNum = parseFloat(aValue);
        const bNum = parseFloat(bValue);
        if (aNum < bNum) return sortOrder === 'asc' ? -1 : 1;
        if (aNum > bNum) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
      
      // For string fields, compare as strings
      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [searchTerm, itemsData, sortBy, sortOrder, selectedManufacturer, selectedCategory, selectedFamily, selectedMeasureBasis, selectedActive]);

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
    // Removed setSelectedItemType - using selectedCategory instead
    setSelectedMeasureBasis([]);
    setSelectedActive([]);
    setSearchTerm('');
  };

  // Handlers for actions
  const handleEditItem = (item: Item, e?: React.MouseEvent) => {
    e?.stopPropagation();
    router.navigate(`/catalog/items/edit/${item.id}`);
  };

  const handleArchiveItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Archivar Item',
      message: `¿Estás seguro de que deseas archivar "${item.itemName}"?`,
      variant: 'warning',
      confirmText: 'Archivar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      if (!activeOrganizationId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error al archivar',
          message: 'No hay organización seleccionada',
        });
        return;
      }
      
      setLoading(true);
      
      // ✅ FIX: CatalogItems no tiene columna 'archived', usar 'is_active: false' en su lugar
      const { error } = await supabase
        .from('CatalogItems')
        .update({ is_active: false })
        .eq('id', item.id)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        console.error('❌ Error archiving item:', error);
        throw error;
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Item archivado',
        message: 'El item ha sido archivado correctamente.',
      });
      
      refetch();
    } catch (error) {
      console.error('❌ Error in handleArchiveItem:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al archivar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Eliminar Item',
      message: `¿Estás seguro de que deseas eliminar "${item.itemName}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
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
    } finally {
      setLoading(false);
    }
  };

  // Get unique filter options
  const manufacturerOptions = Array.from(new Set(displayItems.map(item => item.manufacturer).filter(Boolean)));
  const categoryOptions = Array.from(new Set(displayItems.map(item => item.category).filter(Boolean)));
  const familyOptions = Array.from(new Set(displayItems.map(item => item.family).filter(Boolean)));
  // Category options already handled by selectedCategory
  const measureBasisOptions = Array.from(new Set(displayItems.map(item => item.measure_basis).filter(Boolean)));
  const activeOptions = ['Active', 'Inactive'];

  const totalActiveFilters = selectedManufacturer.length + selectedCategory.length + selectedFamily.length + 
                             selectedMeasureBasis.length + selectedActive.length;

  // ✅ OPTIMIZACIÓN: No renderizar la tabla hasta que los datos estén completamente cargados
  if (loading) {
    return (
      <div className="py-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-title font-semibold text-foreground mb-1">Items</h1>
            <p className="text-small text-muted-foreground">Manage your product catalog, items, and collections</p>
          </div>
        </div>
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading items...</p>
            <p className="text-xs text-gray-500 mt-2">Please wait while we load your catalog</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="py-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-title font-semibold text-foreground mb-1">Items</h1>
            <p className="text-small text-muted-foreground">Manage your product catalog, items, and collections</p>
          </div>
        </div>
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-800">Error loading items: {error}</p>
          <button
            onClick={() => refetch()}
            className="mt-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Items</h1>
          <p className="text-small text-muted-foreground">Manage your product catalog, items, and collections</p>
        </div>
        <div className="flex items-center gap-3">
          {activeTab === 'items' && (
            <>
              <button
                onClick={() => setShowImportModal(true)}
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
            </>
          )}
        </div>
      </div>

      {/* Internal Tabs - Items | Manufacturer | Categories | Collection */}
      <div className="mb-6 border-b border-gray-200">
        <div className="flex gap-6">
          <button
            onClick={() => setActiveTab('items')}
            className={`pb-3 px-1 text-sm font-medium transition-colors border-b-2 ${
              activeTab === 'items'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Items
          </button>
          <button
            onClick={() => setActiveTab('manufacturer')}
            className={`pb-3 px-1 text-sm font-medium transition-colors border-b-2 ${
              activeTab === 'manufacturer'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Manufacturer
          </button>
          <button
            onClick={() => setActiveTab('categories')}
            className={`pb-3 px-1 text-sm font-medium transition-colors border-b-2 ${
              activeTab === 'categories'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Categories
          </button>
          <button
            onClick={() => setActiveTab('collection')}
            className={`pb-3 px-1 text-sm font-medium transition-colors border-b-2 ${
              activeTab === 'collection'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Collection
          </button>
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'items' && (
        <>
      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by SKU, name, collection, variant, color, description, manufacturer..."
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
                {/* Measure Basis Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Measure Basis</span>
                    {selectedMeasureBasis.length > 0 && (
                      <button
                        onClick={() => setSelectedMeasureBasis([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedMeasureBasis.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {measureBasisOptions.map((measureBasis) => (
                      <div
                        key={measureBasis}
                        onClick={() => {
                          if (!measureBasis) return;
                          setSelectedMeasureBasis(prev => 
                            prev.includes(measureBasis) 
                              ? prev.filter((m: string) => m !== measureBasis)
                              : [...prev, measureBasis]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={measureBasis ? selectedMeasureBasis.includes(measureBasis) : false}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{measureBasis}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Active Status Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Status</span>
                    {selectedActive.length > 0 && (
                      <button
                        onClick={() => setSelectedActive([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedActive.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {activeOptions.map((status) => (
                      <div
                        key={status}
                        onClick={() => {
                          setSelectedActive(prev => 
                            prev.includes(status) 
                              ? prev.filter(s => s !== status)
                              : [...prev, status]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedActive.includes(status)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{status}</span>
                      </div>
                    ))}
                  </div>
                </div>
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
                        onClick={() => handleManufacturerToggle(manufacturer || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={manufacturer ? selectedManufacturer.includes(manufacturer) : false}
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
                        onClick={() => handleCategoryToggle(category || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={category ? selectedCategory.includes(category) : false}
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
                        onClick={() => handleFamilyToggle(family || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={family ? selectedFamily.includes(family) : false}
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
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-16">Image</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('sku')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      SKU
                      {sortBy === 'sku' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('itemName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name
                      {sortBy === 'itemName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('category')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Category
                      {sortBy === 'category' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('measure_basis')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Measure Basis
                      {sortBy === 'measure_basis' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">UOM</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">MSRP</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Last Updated</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('active')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'active' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={10} className="py-12 px-6 text-center">
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
                      <td className="py-3 px-4">
                        {item.image ? (
                          <div 
                            className="w-10 h-10 rounded border border-gray-200 overflow-hidden cursor-pointer hover:opacity-80 transition-opacity"
                            onClick={() => setSelectedImage(item.image || null)}
                          >
                            <img 
                              src={item.image} 
                              alt={item.itemName || 'Item image'} 
                              className="w-full h-full object-cover"
                              loading="lazy"
                              decoding="async"
                              onError={(e) => {
                                if (import.meta.env.DEV) {
                                  console.error('Image load error for item:', item.sku, 'URL:', item.image);
                                }
                                (e.target as HTMLImageElement).style.display = 'none';
                              }}
                              onLoad={() => {
                                if (import.meta.env.DEV) {
                                  console.log('✅ Image loaded successfully for item:', item.sku);
                                }
                              }}
                            />
                          </div>
                        ) : (
                          <div className="w-10 h-10 rounded border border-gray-200 bg-gray-50 flex items-center justify-center">
                            <ImageIcon className="w-4 h-4 text-gray-400" />
                          </div>
                        )}
                      </td>
                      {/* ✅ OPTIMIZACIÓN: Todos los campos tienen valores por defecto para evitar mostrar vacíos */}
                      <td className="py-3 px-4 text-gray-900 text-xs font-medium">
                        {item.sku || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.itemName || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                          {item.category || 'N/A'}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.measure_basis || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.uom || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.msrp != null && item.msrp !== undefined && !isNaN(item.msrp)
                          ? `$${item.msrp.toFixed(2)}`
                          : '$0.00'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.updated_at ? formatDate(item.updated_at) : 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {/* ✅ OPTIMIZACIÓN: Asegurar que active esté definido antes de renderizar */}
                        {item.active !== undefined && item.active !== null ? (
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                            item.active 
                              ? 'bg-green-100 text-green-800' 
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {item.active ? 'Active' : 'Inactive'}
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                            Active
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-4" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={(e) => handleEditItem(item, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Edit ${item.itemName}`}
                            title={`Edit ${item.itemName}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleArchiveItem(item, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Archive ${item.itemName}`}
                            title={`Archive ${item.itemName}`}
                          >
                            <Archive className="w-4 h-4" />
                          </button>
                          <button 
                            onClick={(e) => handleDeleteItem(item, e)}
                            disabled={isDeleting}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            aria-label={`Delete ${item.itemName}`}
                            title={`Delete ${item.itemName}`}
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
              {loadingMore && (
                <span className="ml-2 text-xs text-gray-500">
                  <span className="inline-block animate-spin rounded-full h-3 w-3 border-b-2 border-primary mr-1"></span>
                  Loading more items...
                </span>
              )}
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

      {/* Import Modal */}
      <ImportCatalog
        isOpen={showImportModal}
        onClose={() => setShowImportModal(false)}
        onImportComplete={() => {
          setShowImportModal(false);
          refetch();
        }}
      />
        </>
      )}

      {activeTab === 'manufacturer' && <Manufacturers />}
      {activeTab === 'categories' && <Categories />}
      {activeTab === 'collection' && <Collections />}

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

      {/* Image Modal */}
      {selectedImage && (
        <ImageModal 
          imageUrl={selectedImage} 
          alt="Item image"
          onClose={() => setSelectedImage(null)} 
        />
      )}
    </div>
  );
}

