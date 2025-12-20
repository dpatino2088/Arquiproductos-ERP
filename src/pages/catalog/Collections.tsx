import { useState, useMemo, useRef, useEffect } from 'react';
import { useCatalogCollections, useCatalogCollectionsCRUD, useCatalogItems } from '../../hooks/useCatalog';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Search, Edit, Trash2, X, Plus, Book, Package, Building2, FolderTree } from 'lucide-react';
import { logger } from '../../lib/logger';

export default function Collections() {
  const { registerSubmodules } = useSubmoduleNav();
  const { collections, loading, error, refetch } = useCatalogCollections();
  const { items: catalogItems, loading: loadingItems, error: catalogItemsError } = useCatalogItems();
  const { deleteCollection } = useCatalogCollectionsCRUD();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [isDeleting, setIsDeleting] = useState(false);
  const itemsPerPage = 24;
  const cardRefs = useRef<{ [key: string]: HTMLDivElement | null }>({});

  // Don't register submodules here - Catalog.tsx handles that
  // This component is now used as a tab content within Items.tsx

  // Debug: log when catalogItems change
  useEffect(() => {
    if (import.meta.env.DEV && catalogItems) {
      console.log('📦 Collections.tsx: catalogItems loaded', {
        total: catalogItems.length,
        with_variant_name: catalogItems.filter((item: any) => item.variant_name && String(item.variant_name).trim() !== '').length,
        with_collection_name: catalogItems.filter((item: any) => item.collection_name).length,
        sample: catalogItems.slice(0, 3).map((item: any) => ({
          sku: item.sku,
          variant_name: item.variant_name,
          collection_name: item.collection_name,
        })),
      });
    }
  }, [catalogItems]);

  // Filter collections by search term
  const filteredCollections = useMemo(() => {
    if (!collections || collections.length === 0) return [];
    
    if (!searchTerm.trim()) return collections;
    
    const term = searchTerm.toLowerCase();
    return collections.filter(collection => {
      const name = ((collection as any).collection_name || collection.name || '').toLowerCase();
      const code = (collection.code || '').toLowerCase();
      const description = (collection.description || '').toLowerCase();
      
      return name.includes(term) || code.includes(term) || description.includes(term);
    });
  }, [collections, searchTerm]);

  // Pagination
  const totalPages = Math.ceil(filteredCollections.length / itemsPerPage);
  const paginatedCollections = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return filteredCollections.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredCollections, currentPage]);

  // Get variants and SKUs for a collection
  const getCollectionVariants = useMemo(() => {
    return (collectionName: string) => {
      if (!catalogItems || catalogItems.length === 0) {
        if (import.meta.env.DEV) {
          console.log('⚠️ getCollectionVariants: No catalogItems available');
        }
        return [];
      }

      if (import.meta.env.DEV) {
        console.log(`🔍 getCollectionVariants called for collection: ${collectionName}`);
        console.log(`   Total catalogItems: ${catalogItems.length}`);
        console.log(`   Items with collection_name matching ${collectionName}:`, 
          catalogItems.filter((item: any) => String(item.collection_name) === String(collectionName)).length
        );
        console.log(`   Items with variant_name:`, 
          catalogItems.filter((item: any) => item.variant_name && String(item.variant_name).trim() !== '').length
        );
      }

      const items = catalogItems
        .filter((item: any) => {
          // Match items that:
          // 1. Have the correct collection_name (must match exactly)
          // 2. Have a variant_name (not null/empty after trim)
          // 3. Have a sku (not null/empty after trim)
          // 4. Are not deleted
          // Note: We don't require is_fabric=true anymore, as variants can exist for non-fabric items too
          
          // Convert both to strings and compare (collection_name is now text, not UUID)
          const itemCollectionName = item.collection_name ? String(item.collection_name).trim() : null;
          const targetCollectionName = String(collectionName).trim();
          const hasCollection = itemCollectionName === targetCollectionName;
          
          // For fabrics, we need variant_name (this is the name/display value)
          // For non-fabrics, we would use item_name, but variants are only for fabrics
          const isFabric = item.is_fabric === true;
          const variantNameStr = item.variant_name ? String(item.variant_name).trim() : '';
          const hasVariant = variantNameStr.length > 0;
          
          // Check sku exists and is not empty after trim
          const skuStr = item.sku ? String(item.sku).trim() : '';
          const hasSku = skuStr.length > 0;
          
          const notDeleted = !item.deleted;
          
          // Only include fabrics with variant_name
          const matches = hasCollection && isFabric && hasVariant && hasSku && notDeleted;
          
          if (import.meta.env.DEV && matches) {
            console.log('📦 Found fabric item for collection:', {
              collectionName,
              itemId: item.id,
              variant_name: item.variant_name, // This is the name for fabrics
              sku: item.sku,
              is_fabric: item.is_fabric,
              collection_name: item.collection_name,
            });
          }
          
          // Debug: log items that have collection_name but don't match
          if (import.meta.env.DEV && item.collection_name && !matches && hasCollection) {
            console.log('⚠️ Item has collection but not included:', {
              collectionName,
              itemId: item.id,
              sku: item.sku,
              variant_name: item.variant_name,
              item_name: item.item_name,
              is_fabric: item.is_fabric,
              hasVariant,
              hasSku,
              notDeleted,
              reason: !isFabric ? 'not a fabric' : !hasVariant ? 'no variant_name' : !hasSku ? 'no sku' : notDeleted ? 'deleted' : 'unknown',
            });
          }
          
          return matches;
        })
        .map((item: any) => ({
          variant_name: String(item.variant_name || '').trim(),
          sku: String(item.sku || '').trim(),
        }))
        .filter((item: { variant_name: string; sku: string }) => 
          item.variant_name && item.variant_name.length > 0 && item.sku && item.sku.length > 0
        );

      if (import.meta.env.DEV) {
        console.log(`🔍 Collection ${collectionName}: Found ${items.length} items with variants`);
        if (items.length > 0) {
          console.log('   Sample items:', items.slice(0, 5));
          console.log('   All variant names found:', items.map((i: any) => i.variant_name).filter((v: string, i: number, arr: string[]) => arr.indexOf(v) === i));
        } else {
          // Debug: show why items are being filtered out
          const allItemsForCollection = catalogItems.filter((item: any) => 
            String(item.collection_name) === String(collectionName) && !item.deleted
          );
          console.log(`   ⚠️ No items found, but ${allItemsForCollection.length} items exist for this collection`);
          if (allItemsForCollection.length > 0) {
            console.log('   Sample items for this collection:', allItemsForCollection.slice(0, 3).map((item: any) => ({
              sku: item.sku,
              variant_name: item.variant_name,
              has_variant: !!(item.variant_name && String(item.variant_name).trim()),
              has_sku: !!(item.sku && String(item.sku).trim()),
              deleted: item.deleted,
            })));
          }
        }
      }

      // Group by variant_name and collect all SKUs
      const grouped = items.reduce((acc: Record<string, string[]>, item: { variant_name: string; sku: string }) => {
        const variantName = (item.variant_name || '').trim();
        const sku = (item.sku || '').trim();
        
        if (variantName && variantName.length > 0 && sku && sku.length > 0) {
          if (!acc[variantName]) {
            acc[variantName] = [];
          }
          
          // Only add SKU if it's not already in the array
          if (!acc[variantName]!.includes(sku)) {
            acc[variantName]!.push(sku);
          }
        }
        return acc;
      }, {} as Record<string, string[]>);

      const result = Object.entries(grouped)
        .map(([variant_name, skus]) => ({
          variant_name: variant_name.trim(),
          skus: Array.from(new Set(skus)).filter(sku => sku && sku.length > 0), // Remove duplicates and empty SKUs
        }))
        .filter(v => v.variant_name && v.variant_name.length > 0 && v.skus.length > 0) // Only keep variants with at least one SKU
        .sort((a, b) => a.variant_name.localeCompare(b.variant_name));

      if (import.meta.env.DEV) {
        console.log(`✅ Collection ${collectionName}: ${result.length} unique variants`, result);
        if (result.length === 0 && items.length > 0) {
          console.warn(`⚠️ Collection ${collectionName}: Found ${items.length} items but 0 variants after grouping. Check variant_name values.`);
        }
      }

      return result;
    };
  }, [catalogItems]);

  const handleEdit = (collection: any) => {
    // Collections are now derived from CatalogItems
    // Navigate to items page filtered by this collection
    const collectionName = (collection as any).collection_name || collection.name || '';
    router.navigate(`/catalog/items?collection_name=${encodeURIComponent(collectionName)}&is_fabric=true`);
  };

  const handleEditVariant = (collectionName: string, variantName: string | undefined, skus: string[]) => {
    // Navigate to items page filtered by collection and variant
    // If there's only one SKU, go directly to edit that item
    if (skus.length === 1 && skus[0]) {
      router.navigate(`/catalog/items?sku=${encodeURIComponent(skus[0])}`);
    } else {
      // Multiple SKUs - navigate to items filtered by collection and variant
      const variantParam = variantName ? `&variant_name=${encodeURIComponent(variantName)}` : '';
      router.navigate(`/catalog/items?collection_name=${encodeURIComponent(collectionName)}${variantParam}&is_fabric=true`);
    }
  };

  const handleEditItem = (sku: string) => {
    // Navigate to edit the specific item by SKU
    router.navigate(`/catalog/items?sku=${encodeURIComponent(sku)}`);
  };

  const handleDelete = async (id: string, name: string) => {
    const confirmed = await showConfirm({
      title: 'Delete Collection',
      message: `Are you sure you want to delete "${name}"? This action cannot be undone.`,
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    
    if (confirmed) {
      try {
        setIsDeleting(true);
        setLoading(true);
        await deleteCollection(id);
        await refetch();
        logger.info('Collection deleted', { id, name });
      } catch (err) {
        logger.error('Error deleting collection', err instanceof Error ? err : new Error(String(err)));
      } finally {
        setIsDeleting(false);
        setLoading(false);
      }
    }
  };

  const handleAddNew = () => {
    // Navigate to create new item with is_fabric=true pre-filled
    // Collections are now derived from CatalogItems, so we create an item instead
    router.navigate('/catalog/items/new?is_fabric=true');
  };

  if (loading && collections.length === 0) {
    return (
      <div className="py-6">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Collections</h1>
          <p className="text-sm text-gray-600 mt-1">Manage product collections</p>
        </div>
        <button
          onClick={handleAddNew}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add New Collection
        </button>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search collections by name, code, or description..."
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setCurrentPage(1);
            }}
            className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
          />
        </div>
      </div>

      {/* Error State */}
      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-sm text-red-600">Error loading collections: {error}</p>
        </div>
      )}

      {/* Collections Grid */}
      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      ) : error ? (
        <div className="text-center py-12">
          <p className="text-gray-500">Error loading collections. Please try again.</p>
        </div>
      ) : filteredCollections.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500">
            {searchTerm ? 'No collections found matching your search.' : 'No collections found.'}
          </p>
        </div>
      ) : (
        <div className="relative">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4 mb-4">
            {paginatedCollections.map((collection) => {
              const isSelected = selectedCollectionId === collection.id;
              const collectionName = (collection as any).collection_name || collection.name || 'Unnamed Collection';
              const variants = getCollectionVariants(collectionName);
              
              return (
                <div 
                  key={collection.id} 
                  className="relative w-full"
                  ref={(el) => {
                    cardRefs.current[collection.id] = el;
                  }}
                >
                  {/* Collection Card */}
                  <div
                    className={`relative w-full p-3 border-2 rounded-lg transition-all cursor-pointer ${
                      isSelected
                        ? 'border-gray-400 bg-gray-600 text-white'
                        : 'border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    onClick={() => {
                      if (isSelected) {
                        setSelectedCollectionId(null);
                      } else {
                        setSelectedCollectionId(collection.id);
                      }
                    }}
                  >
                    <div className="flex items-center justify-between">
                      <span className={`text-sm font-semibold ${isSelected ? 'text-white' : 'text-gray-900'}`}>
                        {collectionName}
                      </span>
                    </div>
                    <div className="mt-2 space-y-1">
                      {variants.length > 0 ? (
                        <div className="text-xs">
                          <span className={isSelected ? 'text-gray-200' : 'text-gray-500'}>
                            {variants.length} variant{variants.length !== 1 ? 's' : ''}
                          </span>
                        </div>
                      ) : (
                        <div className="text-xs">
                          <span className={isSelected ? 'text-gray-300' : 'text-gray-400'}>No variants</span>
                        </div>
                      )}
                      {/* Price display */}
                      {(() => {
                        // Get average price from collection items
                        const collectionItems = catalogItems.filter((item: any) => 
                          item.collection_name === collectionName && 
                          item.is_fabric === true &&
                          !item.deleted
                        );
                        const prices = collectionItems
                          .map((item: any) => item.msrp || item.cost_exw)
                          .filter((p: any) => p && p > 0);
                        
                        if (prices.length > 0) {
                          const avgPrice = prices.reduce((a: number, b: number) => a + b, 0) / prices.length;
                          const minPrice = Math.min(...prices);
                          const maxPrice = Math.max(...prices);
                          
                          return (
                            <div className={`text-xs font-medium ${isSelected ? 'text-white' : 'text-gray-700'}`}>
                              {minPrice === maxPrice ? (
                                <span>€{avgPrice.toFixed(2)}</span>
                              ) : (
                                <span>€{minPrice.toFixed(2)} - €{maxPrice.toFixed(2)}</span>
                              )}
                            </div>
                          );
                        }
                        return null;
                      })()}
                    </div>
                    
                    {/* Action buttons */}
                    <div className="absolute top-2 right-2 flex gap-1" onClick={(e) => e.stopPropagation()}>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEdit(collection);
                        }}
                        className={`p-1 rounded transition-colors ${
                          isSelected 
                            ? 'hover:bg-gray-500 text-white' 
                            : 'hover:bg-gray-100 text-gray-600'
                        }`}
                        title={`Edit ${collectionName}`}
                      >
                        <Edit className="w-3 h-3" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDelete(collection.id, collectionName);
                        }}
                        disabled={isDeleting}
                        className={`p-1 rounded transition-colors disabled:opacity-50 ${
                          isSelected 
                            ? 'hover:bg-gray-500 text-white' 
                            : 'hover:bg-gray-100 text-gray-600'
                        }`}
                        title={`Delete ${collectionName}`}
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>

                  {/* Floating Label with Variants and SKUs */}
                  {isSelected && (
                    <div
                      className="absolute z-50 bg-white border-2 border-gray-300 rounded-lg p-4 shadow-xl w-full"
                      style={{
                        top: 'calc(100% + 8px)',
                        left: '0',
                        right: '0',
                        boxSizing: 'border-box',
                      }}
                      onClick={(e) => e.stopPropagation()}
                    >
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="text-sm font-bold text-gray-900">{collectionName}</h3>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedCollectionId(null);
                          }}
                          className="p-1 hover:bg-gray-100 rounded transition-colors"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      </div>
                      
                      {loadingItems ? (
                        <div className="py-4 text-center">
                          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-gray-400 mx-auto mb-2"></div>
                          <p className="text-xs text-gray-500">Loading variants...</p>
                        </div>
                      ) : variants.length > 0 ? (
                        <div className="space-y-3 max-h-[400px] overflow-y-auto">
                          <p className="text-xs text-gray-600 mb-3 font-medium">
                            Variants ({variants.length}):
                          </p>
                          {variants.map((variant, idx) => (
                            <div key={idx} className="border-b border-gray-200 pb-3 last:border-b-0 last:pb-0">
                              <div className="flex items-center justify-between mb-2">
                                <p className="text-sm font-bold text-gray-900">
                                  {variant.variant_name || 'Unnamed Variant'}
                                </p>
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleEditVariant(collectionName, variant.variant_name, variant.skus);
                                  }}
                                  className="p-1 hover:bg-gray-100 rounded transition-colors text-gray-600 hover:text-gray-900"
                                  title={`Edit variant ${variant.variant_name}`}
                                >
                                  <Edit className="w-4 h-4" />
                                </button>
                              </div>
                              <div className="flex flex-wrap gap-1">
                                {variant.skus.map((sku, skuIdx) => (
                                  <button
                                    key={skuIdx}
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      handleEditItem(sku);
                                    }}
                                    className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200 hover:bg-blue-100 hover:border-blue-300 transition-colors cursor-pointer"
                                    title={`Edit item ${sku}`}
                                  >
                                    {sku}
                                  </button>
                                ))}
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="py-4 text-center">
                          <p className="text-sm text-gray-500">No variants available for this collection</p>
                          {catalogItemsError && (
                            <p className="text-xs text-red-500 mt-2">Error loading items: {catalogItemsError}</p>
                          )}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between mt-4">
              <div className="text-sm text-gray-600">
                Showing {(currentPage - 1) * itemsPerPage + 1} to {Math.min(currentPage * itemsPerPage, filteredCollections.length)} of {filteredCollections.length} collections
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1 border border-gray-300 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                >
                  Previous
                </button>
                <button
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1 border border-gray-300 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        onConfirm={handleConfirm}
        onClose={closeDialog}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
