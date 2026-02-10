import { useState, useMemo, useEffect } from 'react';
import { useCatalogCollections, useCatalogItems, useManufacturers } from '../../hooks/useCatalog';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';
import { Search, Eye, Plus, Package, ChevronLeft, ChevronRight, Image as ImageIcon, X, Filter } from 'lucide-react';
import ImageModal from '../../components/ui/ImageModal';

export default function Collections() {
  const { activeOrganizationId } = useOrganizationContext();
  const { collections, loading, error, refetch } = useCatalogCollections();
  const { items: catalogItems, loading: loadingItems } = useCatalogItems({ isRoll: true });
  const { manufacturers } = useManufacturers();
  const { productTypes } = useProductTypes();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  const initialLoading = loading && collections.length === 0;
  useEffect(() => {
    setGlobalLoading(initialLoading);
    return () => setGlobalLoading(false);
  }, [initialLoading, setGlobalLoading]);

  const [manufacturerIdsWithIsRoll, setManufacturerIdsWithIsRoll] = useState<Set<string>>(new Set());
  const [manufacturerIdsLoaded, setManufacturerIdsLoaded] = useState(false);
  const [productTypeNamesByItemId, setProductTypeNamesByItemId] = useState<Map<string, string[]>>(new Map());
  const [productTypeMapLoaded, setProductTypeMapLoaded] = useState(false);
  
  const [searchTerm, setSearchTerm] = useState('');
  const [manufacturerId, setManufacturerId] = useState<string>('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [selectedCollectionName, setSelectedCollectionName] = useState<string | null>(null);
  const [selectedImageUrl, setSelectedImageUrl] = useState<string | null>(null);
  const [selectedImageAlt, setSelectedImageAlt] = useState<string>('');

  // Solo manufacturers que tienen al menos un ítem con is_roll=true
  useEffect(() => {
    if (!activeOrganizationId) {
      setManufacturerIdsLoaded(true);
      return;
    }
    let mounted = true;
    setManufacturerIdsLoaded(false);
    (async () => {
      const { data } = await supabase
        .from('CatalogItems')
        .select('manufacturer_id')
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true)
        .eq('is_roll', true)
        .not('manufacturer_id', 'is', null);
      if (!mounted) return;
      setManufacturerIdsWithIsRoll(new Set((data || []).map((r: { manufacturer_id?: string | null }) => r.manufacturer_id).filter((x: string | null | undefined): x is string => Boolean(x))));
      setManufacturerIdsLoaded(true);
    })();
    return () => { mounted = false; };
  }, [activeOrganizationId]);

  const manufacturersWithIsRoll = useMemo(() => {
    if (!manufacturers) return [];
    if (!manufacturerIdsLoaded) return manufacturers;
    return manufacturers.filter(m => manufacturerIdsWithIsRoll.has(m.id));
  }, [manufacturers, manufacturerIdsWithIsRoll, manufacturerIdsLoaded]);

  // Mapa itemId -> [product type name, code, ...] para búsqueda por Product Type
  useEffect(() => {
    if (!activeOrganizationId || !catalogItems.length || !productTypes.length) {
      setProductTypeMapLoaded(true);
      return;
    }
    let mounted = true;
    setProductTypeMapLoaded(false);
    const ids = catalogItems.map(i => i.id).filter(Boolean);
    (async () => {
      const { data } = await supabase
        .from('CatalogItemProductTypes')
        .select('catalog_item_id, product_type_id')
        .eq('organization_id', activeOrganizationId)
        .in('catalog_item_id', ids);
      if (!mounted) return;
      const map = new Map<string, string[]>();
      const ptById = new Map(productTypes.map(p => [p.id, p]));
      (data || []).forEach((r: { catalog_item_id?: string; product_type_id?: string }) => {
        const pt = r.product_type_id ? ptById.get(r.product_type_id) : null;
        const labels = [pt?.name, pt?.code].filter((x): x is string => Boolean(x));
        if (r.catalog_item_id && labels.length) {
          const arr = map.get(r.catalog_item_id) || [];
          map.set(r.catalog_item_id, [...arr, ...labels]);
        }
      });
      setProductTypeNamesByItemId(map);
      setProductTypeMapLoaded(true);
    })();
    return () => { mounted = false; };
  }, [activeOrganizationId, catalogItems, productTypes]);

  // Get variants for a collection
  const getVariantsForCollection = (collectionName: string) => {
    if (!catalogItems || catalogItems.length === 0) return [];
    
    return catalogItems
      .filter(item => item.collection_name === collectionName && item.variant_name && item.sku)
      .map(item => ({
        id: item.id,
        sku: item.sku,
        variant_name: item.variant_name,
        image_url: item.image_url,
        roll_width: item.roll_width,
      }));
  };

  // Filter collections by search and by manufacturer
  const filteredCollections = useMemo(() => {
    if (!collections) return [];
    let result = collections;

    // Filter by manufacturer (collections that have at least one item from this manufacturer)
    if (manufacturerId) {
      result = result.filter(c => {
        const ids = c.manufacturer_ids;
        return ids && ids.length > 0 && ids.includes(manufacturerId);
      });
    }

    // Filter by search: SKU, Collection name, Variant name o Product Type
    if (searchTerm.trim()) {
      const term = searchTerm.toLowerCase().trim();
      result = result.filter(c => {
        const collName = (c.name || '').toLowerCase();
        const code = (c.code || '').toLowerCase();
        const desc = (c.description || '').toLowerCase();
        // Collection name o campos derivados
        if (collName.includes(term) || code.includes(term) || desc.includes(term)) return true;
        // SKU: algún ítem de esta colección tiene SKU que coincida
        if (catalogItems?.some(i => i.collection_name === c.name && (i.sku || '').toLowerCase().includes(term))) return true;
        // Variant name: algún ítem de esta colección tiene variant_name que coincida
        if (catalogItems?.some(i => i.collection_name === c.name && (i.variant_name || '').toLowerCase().includes(term))) return true;
        // Product Type: algún ítem de esta colección tiene un product type (name/code) que coincida
        if (productTypeMapLoaded && catalogItems?.some(i => i.collection_name === c.name && (productTypeNamesByItemId.get(i.id) || []).some(n => (n || '').toLowerCase().includes(term)))) return true;
        return false;
      });
    }

    return result;
  }, [collections, searchTerm, manufacturerId, catalogItems, productTypeNamesByItemId, productTypeMapLoaded]);

  // Pagination
  const totalPages = Math.ceil(filteredCollections.length / itemsPerPage);
  const paginatedCollections = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return filteredCollections.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredCollections, currentPage, itemsPerPage]);

  // Reset page when search or manufacturer filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, manufacturerId]);

  if (loading && collections.length === 0) return <div className="py-6 px-6" />;

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold text-foreground mb-1">Collections</h2>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage product collections ({filteredCollections.length} total)
          </p>
        </div>
        <button
          onClick={() => router.navigate('/catalog/items/new?is_fabric=true')}
          className="px-3 py-1.5 text-sm rounded-lg transition-colors flex items-center gap-1.5"
          style={{ backgroundColor: 'var(--primary-brand-hex)', color: 'white' }}
        >
          <Plus className="w-4 h-4" />
          Add New Collection
        </button>
      </div>

      {/* Filters: Search Bar + Manufacturer */}
      <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg mb-4">
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4">
          {/* Search bar — tal cual, primero */}
          <div className="flex-1 relative min-w-0">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
            <input
              type="text"
              placeholder="Search by SKU, collection name, variant name, or product type..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
              aria-label="Search by SKU, collection name, variant name, or product type"
            />
          </div>
          {/* Manufacturer filter — a la derecha del search */}
          <div className="flex items-center gap-2 flex-shrink-0 min-w-0 sm:min-w-[200px]">
            <Filter className="w-4 h-4 text-gray-500 flex-shrink-0" aria-hidden />
            <label htmlFor="collections-manufacturer-filter" className="text-gray-600 text-sm whitespace-nowrap hidden sm:inline">
              Manufacturer
            </label>
            <select
              id="collections-manufacturer-filter"
              value={manufacturerId}
              onChange={(e) => setManufacturerId(e.target.value)}
              className="w-full min-w-[160px] border border-gray-200 rounded-lg px-3 py-1.5 text-sm bg-gray-50 focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
              aria-label="Filter by manufacturer"
            >
              <option value="">All manufacturers</option>
              {manufacturersWithIsRoll.map((m) => (
                <option key={m.id} value={m.id}>{m.name}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Error State */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
          <p className="text-red-600 text-sm">{error}</p>
        </div>
      )}

      {/* Collections Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Collection Name</th>
                <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Variants</th>
                <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedCollections.length === 0 ? (
                <tr>
                  <td colSpan={3} className="py-12 px-6 text-center">
                    <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-600 mb-2">No collections found</p>
                    <p className="text-sm text-gray-500">
                      {(searchTerm || manufacturerId) ? 'Try adjusting your search or manufacturer filter' : 'Start by adding roll items with collections'}
                    </p>
                  </td>
                </tr>
              ) : (
                paginatedCollections.map((collection) => (
                  <tr 
                    key={collection.id}
                    className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                  >
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      {collection.name}
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {collection.description || '0 variants'}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-1 justify-end">
                        <button
                          onClick={() => setSelectedCollectionName(collection.name)}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                          title={`View ${collection.name} variants`}
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => router.navigate(`/catalog/items/new?is_fabric=true&collection_name=${encodeURIComponent(collection.name)}`)}
                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                          title={`Add variant to ${collection.name}`}
                        >
                          <Plus className="w-4 h-4" />
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

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 mt-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-600">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {((currentPage - 1) * itemsPerPage) + 1}-{Math.min(currentPage * itemsPerPage, filteredCollections.length)} of {filteredCollections.length}
            </span>
          </div>

          {totalPages > 1 && (
            <div className="flex items-center gap-3">
              <button
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                disabled={currentPage === 1}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === 1
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                <ChevronLeft className="w-3 h-3" />
                Previous
              </button>

              <span className="text-xs text-gray-600">
                Page {currentPage} of {totalPages}
              </span>

              <button
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                disabled={currentPage === totalPages}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  currentPage === totalPages
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                Next
                <ChevronRight className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Variants Modal */}
      {selectedCollectionName && (
        <div 
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm" 
          onClick={() => setSelectedCollectionName(null)}
        >
          <div 
            className="bg-white rounded-lg shadow-xl max-w-6xl w-full mx-4 max-h-[90vh] flex flex-col" 
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <div>
                <h2 className="text-xl font-semibold text-gray-900">
                  Variants: {selectedCollectionName}
                </h2>
                <p className="text-sm text-gray-500 mt-1">
                  {getVariantsForCollection(selectedCollectionName).length} variant(s)
                </p>
              </div>
              <button
                onClick={() => setSelectedCollectionName(null)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                aria-label="Close"
              >
                <X className="w-5 h-5 text-gray-600" />
              </button>
            </div>

            {/* Modal Content */}
            <div className="flex-1 overflow-y-auto p-6">
              {loadingItems ? (
                <div className="flex items-center justify-center py-12">
                  <div className="text-center">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
                    <p className="text-sm text-gray-600">Loading variants...</p>
                  </div>
                </div>
              ) : getVariantsForCollection(selectedCollectionName).length === 0 ? (
                <div className="text-center py-12">
                  <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-600 mb-2">No variants found</p>
                  <p className="text-sm text-gray-500">This collection has no variants yet.</p>
                </div>
              ) : (
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {getVariantsForCollection(selectedCollectionName).map((variant) => (
                    <div
                      key={variant.id}
                      className="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-lg transition-all cursor-pointer"
                      onClick={() => {
                        if (variant.image_url) {
                          setSelectedImageUrl(variant.image_url);
                          setSelectedImageAlt(`${variant.variant_name} - ${variant.sku}`);
                        } else {
                          router.navigate(`/catalog/items?sku=${encodeURIComponent(variant.sku)}`);
                        }
                      }}
                    >
                      {/* Image */}
                      <div className="aspect-square bg-gray-100 flex items-center justify-center overflow-hidden">
                        {variant.image_url ? (
                          <img
                            src={variant.image_url}
                            alt={`${variant.variant_name} - ${variant.sku}`}
                            className="w-full h-full object-cover"
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                            }}
                          />
                        ) : (
                          <ImageIcon className="w-16 h-16 text-gray-300" />
                        )}
                      </div>
                      
                      {/* Card Content */}
                      <div className="p-4">
                        {/* Variant Name (Color) */}
                        <h3 className="font-semibold text-gray-900 text-sm mb-2 truncate" title={variant.variant_name ?? undefined}>
                          {variant.variant_name}
                        </h3>
                        
                        {/* SKU */}
                        <div className="mb-2">
                          <p className="text-xs text-gray-500 mb-0.5">SKU</p>
                          <p className="text-sm text-gray-700 font-mono truncate" title={variant.sku ?? undefined}>
                            {variant.sku}
                          </p>
                        </div>
                        
                        {/* Roll Width */}
                        {variant.roll_width && (
                          <div>
                            <p className="text-xs text-gray-500 mb-0.5">Roll Width</p>
                            <p className="text-sm text-gray-700">
                              {Number(variant.roll_width).toFixed(2)} m
                            </p>
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Image Modal */}
      {selectedImageUrl && (
        <ImageModal
          imageUrl={selectedImageUrl}
          alt={selectedImageAlt}
          onClose={() => {
            setSelectedImageUrl(null);
            setSelectedImageAlt('');
          }}
        />
      )}
    </div>
  );
}
