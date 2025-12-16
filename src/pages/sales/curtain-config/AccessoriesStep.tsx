import { useState, useEffect, useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, Minus, Search, X } from 'lucide-react';
import { useCatalogItems } from '../../../hooks/useCatalog';
import { CatalogItem } from '../../../types/catalog';

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
        updated = [...currentAccessories, { id: itemId, name, price, qty: delta }];
      } else {
        updated = currentAccessories;
      }
    }
    
    onUpdate({ accessories: updated });
  };


  // Filter catalog items for accessories/components that can be sold separately
  const searchableCatalogItems = useMemo(() => {
    return catalogItems.filter(item => {
      // Filter items that are accessories or components
      const itemType = (item.metadata as any)?.item_type || item.metadata?.item_type_inferred;
      const isAccessoryOrComponent = itemType === 'accessory' || itemType === 'component' || 
                                      item.measure_basis === 'unit'; // Items sold by unit
      return isAccessoryOrComponent && item.active && !item.deleted;
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
    setSelectedSearchItem(item);
    setSearchTerm(item.name);
    setShowSearchResults(false);
    // Add item to accessories with quantity 1
    updateAccessoryQty(item.id, item.name, item.unit_price, 1);
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
                {filteredSearchResults.map((item) => {
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
                            €{accessory.price.toFixed(2)}
                          </td>
                          <td className="py-2 px-4 text-right text-sm font-medium text-gray-900">
                            €{(accessory.price * qty).toFixed(2)}
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

