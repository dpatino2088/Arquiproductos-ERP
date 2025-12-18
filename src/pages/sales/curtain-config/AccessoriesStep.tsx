import { useState, useEffect, useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, Minus, Search, X } from 'lucide-react';
import { useCatalogItems } from '../../../hooks/useCatalog';
import { CatalogItem } from '../../../types/catalog';
import { useUIStore } from '../../../stores/ui-store';

interface AccessoriesStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

export default function AccessoriesStep({ config, onUpdate }: AccessoriesStepProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [selectedSearchItem, setSelectedSearchItem] = useState<CatalogItem | null>(null);
  const [searchRef, setSearchRef] = useState<HTMLDivElement | null>(null);
  const { items: catalogItems, loading: catalogLoading } = useCatalogItems();

  // Close search results when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (searchRef && !searchRef.contains(event.target as Node)) {
        setShowSearchResults(false);
      }
    };

    if (showSearchResults) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [showSearchResults, searchRef]);

  const updateAccessoryQty = (itemId: string, name: string, price: number, delta: number) => {
    // Validate itemId is a UUID before proceeding
    if (!itemId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(itemId)) {
      if (import.meta.env.DEV) {
        console.error('❌ updateAccessoryQty - Invalid itemId:', {
          itemId,
          name,
          type: typeof itemId,
        });
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Item ID',
        message: `Cannot add "${name}": Invalid item ID format. Please select the item again from the catalog.`,
      });
      return;
    }
    
    if (!itemId || !name) return;
    
    const currentAccessories = config.accessories || [];
    const existingIndex = currentAccessories.findIndex(a => a.id === itemId);
    
    let updated: typeof currentAccessories;
    if (existingIndex >= 0) {
      const existing = currentAccessories[existingIndex];
      if (!existing) {
        updated = currentAccessories;
      } else {
        const newQty = existing.qty + delta;
        if (newQty <= 0) {
          updated = currentAccessories.filter(a => a.id !== itemId);
        } else {
          updated = [...currentAccessories];
          updated[existingIndex] = { ...existing, qty: newQty };
        }
      }
    } else {
      if (delta > 0 && itemId && name) {
        // Ensure we're storing the UUID, not the name
        updated = [...currentAccessories, { id: itemId, name, price, qty: delta }];
        
        if (import.meta.env.DEV) {
          console.log('✅ Adding new accessory:', {
            id: itemId,
            name,
            price,
            qty: delta,
          });
        }
      } else {
        updated = currentAccessories;
      }
    }
    
    onUpdate({ accessories: updated });
  };


  // Filter catalog items for accessories/components that can be sold separately
  // IMPORTANT: Collections = Fabrics, so we must EXCLUDE fabrics (is_fabric = true)
  // Only show items that:
  // 1. Are NOT fabrics (is_fabric = false)
  // 2. Are sold by unit (measure_basis = 'unit')
  // 3. Have a valid UUID as ID
  // 4. Are active and not deleted
  const searchableCatalogItems = useMemo(() => {
    return catalogItems.filter(item => {
      // CRITICAL: Exclude fabrics (collections are fabrics)
      if (item.is_fabric === true) {
        return false;
      }
      
      // Only items sold by unit (not by area, linear, or fabric)
      if (item.measure_basis !== 'unit') {
        return false;
      }
      
      // Must have a valid UUID as ID
      if (!item.id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id)) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ AccessoriesStep: Filtering out item with invalid UUID:', {
            id: item.id,
            name: item.name,
            sku: item.sku,
            is_fabric: item.is_fabric,
            measure_basis: item.measure_basis,
          });
        }
        return false;
      }
      
      // Must be active and not deleted
      if (!item.active || item.deleted) {
        return false;
      }
      
      return true;
    });
  }, [catalogItems]);

  // Filter search results
  const filteredSearchResults = useMemo(() => {
    if (!searchTerm.trim()) return [];
    
    const searchLower = searchTerm.toLowerCase();
    return searchableCatalogItems.filter(item => 
      item.name.toLowerCase().includes(searchLower) ||
      item.sku.toLowerCase().includes(searchLower) ||
      (item.description && item.description.toLowerCase().includes(searchLower))
    ).slice(0, 10); // Limit to 10 results
  }, [searchTerm, searchableCatalogItems]);

  const handleSearchItemSelect = (item: CatalogItem) => {
    // Debug: Log item details
    if (import.meta.env.DEV) {
      console.log('🔍 AccessoriesStep - handleSearchItemSelect:', {
        itemId: item.id,
        itemName: item.name,
        itemSku: item.sku,
        isUUID: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id || ''),
      });
    }
    
    // Validate that item.id is a valid UUID
    if (!item.id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id)) {
      if (import.meta.env.DEV) {
        console.error('❌ Invalid item ID:', {
          id: item.id,
          name: item.name,
          sku: item.sku,
          type: typeof item.id,
        });
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Item',
        message: `Item "${item.name}" has an invalid ID (${item.id}). Please select a valid catalog item. The ID must be a UUID.`,
      });
      return;
    }
    
    setSelectedSearchItem(item);
    setSearchTerm(item.name);
    setShowSearchResults(false);
    
    // Calculate price: use msrp if available, otherwise calculate from cost_exw + margin
    let price = item.unit_price || 0;
    if (!price || price === 0) {
      if ((item as any).msrp) {
        price = (item as any).msrp;
      } else if ((item as any).cost_exw && (item as any).default_margin_pct) {
        price = (item as any).cost_exw * (1 + (item as any).default_margin_pct / 100);
      }
    }
    
    // Add item to accessories with quantity 1 - ensure we use the UUID, not the name
    updateAccessoryQty(item.id, item.name, price, 1);
    
    if (import.meta.env.DEV) {
      console.log('✅ Accessory added:', {
        id: item.id,
        name: item.name,
        price,
      });
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">ACCESSORIES</Label>
        
        {/* Search field for catalog items */}
        <div className="mb-6">
          <Label className="text-sm font-medium mb-2 block">Search Catalog Items</Label>
          <div className="relative" ref={setSearchRef}>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <Input
                type="text"
                placeholder="Search for controls, clutches, supports, etc..."
                value={searchTerm}
                onChange={(e) => {
                  setSearchTerm(e.target.value);
                  setShowSearchResults(true);
                  if (selectedSearchItem && e.target.value !== selectedSearchItem.name) {
                    setSelectedSearchItem(null);
                  }
                }}
                onFocus={() => setShowSearchResults(true)}
                className="pl-10 pr-10"
              />
              {searchTerm && (
                <button
                  onClick={() => {
                    setSearchTerm('');
                    setShowSearchResults(false);
                    setSelectedSearchItem(null);
                  }}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
            
            {/* Search Results Dropdown */}
            {showSearchResults && filteredSearchResults.length > 0 && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {filteredSearchResults
                  .filter(item => {
                    // Only show items with valid UUID IDs
                    const isValidUUID = item.id && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id);
                    if (!isValidUUID && import.meta.env.DEV) {
                      console.warn('⚠️ Filtering out item with invalid ID:', {
                        id: item.id,
                        name: item.name,
                        sku: item.sku,
                      });
                    }
                    return isValidUUID;
                  })
                  .map((item) => {
                  const isSelected = config.accessories?.some(a => a.id === item.id);
                  return (
                    <button
                      key={item.id}
                      onClick={() => handleSearchItemSelect(item)}
                      disabled={isSelected}
                      className={`w-full text-left px-4 py-2 hover:bg-gray-50 transition-colors ${
                        isSelected ? 'bg-gray-100 opacity-50 cursor-not-allowed' : ''
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-gray-900">{item.name}</p>
                          <p className="text-xs text-gray-500">SKU: {item.sku}</p>
                          {item.description && (
                            <p className="text-xs text-gray-400 mt-1 line-clamp-1">{item.description}</p>
                          )}
                        </div>
                        <div className="text-right ml-4">
                          <p className="text-sm font-medium text-gray-900">€{item.unit_price.toFixed(2)}</p>
                          {isSelected && (
                            <p className="text-xs text-green-600">Added</p>
                          )}
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
            
            {showSearchResults && searchTerm && filteredSearchResults.length === 0 && !catalogLoading && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg p-4">
                <p className="text-sm text-gray-500 text-center">No items found</p>
              </div>
            )}
          </div>
        </div>

        {/* Display selected catalog items */}
        {config.accessories && config.accessories.length > 0 && (
          <div className="mt-6">
            <Label className="text-sm font-medium mb-4 block">SELECTED ITEMS</Label>
            <div className="border border-gray-200 rounded-lg">
                    <table className="w-full">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="text-left py-2 px-4 text-xs font-medium text-gray-700">Item Name</th>
                          <th className="text-center py-2 px-4 text-xs font-medium text-gray-700">Quantity</th>
                          <th className="text-right py-2 px-4 text-xs font-medium text-gray-700">Price</th>
                          <th className="text-right py-2 px-4 text-xs font-medium text-gray-700">Total Price</th>
                    <th className="text-center py-2 px-4 text-xs font-medium text-gray-700">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                  {config.accessories.map((accessory) => {
                      const catalogItem = searchableCatalogItems.find(ci => ci.id === accessory.id);
                      const qty = accessory.qty;
                      // Update price from catalog item if available
                      const currentPrice = catalogItem 
                        ? (catalogItem.msrp || (catalogItem.cost_exw && catalogItem.default_margin_pct 
                          ? catalogItem.cost_exw * (1 + catalogItem.default_margin_pct / 100) 
                          : accessory.price))
                        : accessory.price;
                          return (
                        <tr key={accessory.id} className="bg-primary/5">
                              <td className="py-2 px-4">
                            <div>
                              <span className="text-sm text-gray-900">{accessory.name}</span>
                              {catalogItem?.sku && (
                                <p className="text-xs text-gray-500">SKU: {catalogItem.sku}</p>
                              )}
                                </div>
                              </td>
                              <td className="py-2 px-4 text-center">
                                <div className="flex items-center justify-center gap-2">
                                  <button
                                onClick={() => updateAccessoryQty(accessory.id, accessory.name, accessory.price, -1)}
                                    disabled={qty === 0}
                                    className="p-1 hover:bg-gray-200 rounded disabled:opacity-50"
                                  >
                                    <Minus className="w-3 h-3" />
                                  </button>
                                  <span className="text-sm font-medium w-8">{qty}</span>
                                  <button
                                onClick={() => updateAccessoryQty(accessory.id, accessory.name, accessory.price, 1)}
                                    className="p-1 hover:bg-gray-200 rounded"
                                  >
                                    <Plus className="w-3 h-3" />
                                  </button>
                                </div>
                              </td>
                              <td className="py-2 px-4 text-right text-sm text-gray-700">
                            €{currentPrice.toFixed(2)}
                              </td>
                              <td className="py-2 px-4 text-right text-sm font-medium text-gray-900">
                            €{(currentPrice * qty).toFixed(2)}
                          </td>
                          <td className="py-2 px-4 text-center">
                            <button
                              onClick={() => {
                                const currentAccessories = config.accessories || [];
                                const updated = currentAccessories.filter(a => a.id !== accessory.id);
                                onUpdate({ accessories: updated });
                                if (selectedSearchItem?.id === accessory.id) {
                                  setSelectedSearchItem(null);
                                  setSearchTerm('');
                                }
                              }}
                              className="p-1 hover:bg-red-100 rounded text-red-600"
                              title="Remove item"
                            >
                              <X className="w-4 h-4" />
                            </button>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
            </div>
                  </div>
                )}
      </div>
    </div>
  );
}

