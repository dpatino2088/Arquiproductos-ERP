import { useState, useEffect, useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, Minus, Search, X } from 'lucide-react';
import { useCatalogItems } from '../../../hooks/useCatalog';
import { CatalogItem } from '../../../types/catalog';
import { useUIStore } from '../../../stores/ui-store';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface AccessoriesStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

export default function AccessoriesStep({ config, onUpdate }: AccessoriesStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [searchTerm, setSearchTerm] = useState('');
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [searchRef, setSearchRef] = useState<HTMLDivElement | null>(null);
  
  // Load ALL catalog items (no filters) for searching
  const { items: catalogItems, loading: catalogLoading, error: catalogError } = useCatalogItems(undefined, undefined);
  
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

  // Filter catalog items - EXCLUDE:
  // 1. item_type = 'fabric'
  // 2. item_type = 'linear'
  // 3. Only items sold by unit (measure_basis = 'unit')
  // 4. Must be active and not deleted
  const searchableCatalogItems = useMemo(() => {
    return catalogItems.filter(item => {
      // EXCLUDE: Fabric items
      if ((item as any).item_type === 'fabric') {
        return false;
      }
      
      // EXCLUDE: Linear items
      if ((item as any).item_type === 'linear') {
        return false;
      }
      
      // EXCLUDE: Also check is_fabric flag as additional safety
      if (item.is_fabric === true) {
        return false;
      }
      
      // Only items sold by unit
      if (item.measure_basis !== 'unit') {
        return false;
      }
      
      // Must have valid UUID
      if (!item.id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id)) {
        return false;
      }
      
      // Must be active and not deleted
      if (!item.active || item.deleted) {
        return false;
      }
      
      return true;
    });
  }, [catalogItems]);

  // Filter search results - search in SKU, item_name, and description
  const filteredSearchResults = useMemo(() => {
    if (!searchTerm.trim()) return [];
    
    const searchLower = searchTerm.toLowerCase().trim();
    
    const results = searchableCatalogItems.filter(item => {
      // Get actual values from CatalogItems
      const itemName = String((item as any).item_name || item.name || '').trim();
      const sku = String(item.sku || '').trim();
      const description = String((item as any).description || '').trim();
      
      // Search in all fields (case-insensitive)
      const matchesName = itemName.toLowerCase().includes(searchLower);
      const matchesSku = sku.toLowerCase().includes(searchLower);
      const matchesDescription = description.toLowerCase().includes(searchLower);
      
      return matchesName || matchesSku || matchesDescription;
    });
    
    // Sort: exact SKU matches first, then name matches
    const sortedResults = results.sort((a, b) => {
      const aSku = String(a.sku || '').toLowerCase();
      const bSku = String(b.sku || '').toLowerCase();
      const aName = String((a as any).item_name || a.name || '').toLowerCase();
      const bName = String((b as any).item_name || b.name || '').toLowerCase();
      
      // Exact SKU match gets priority
      if (aSku === searchLower && bSku !== searchLower) return -1;
      if (bSku === searchLower && aSku !== searchLower) return 1;
      
      // SKU starts with search term
      if (aSku.startsWith(searchLower) && !bSku.startsWith(searchLower)) return -1;
      if (bSku.startsWith(searchLower) && !aSku.startsWith(searchLower)) return 1;
      
      // Name starts with search term
      if (aName.startsWith(searchLower) && !bName.startsWith(searchLower)) return -1;
      if (bName.startsWith(searchLower) && !aName.startsWith(searchLower)) return 1;
      
      // Alphabetical by name
      return aName.localeCompare(bName);
    });
    
    return sortedResults.slice(0, 10);
  }, [searchTerm, searchableCatalogItems]);

  // Update accessory quantity
  const updateAccessoryQty = (itemId: string, name: string, price: number, delta: number) => {
    if (!itemId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(itemId)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Item ID',
        message: `Cannot add "${name}": Invalid item ID format.`,
      });
      return;
    }
    
    if (!itemId || !name) return;
    
    const currentAccessories = (config as any).accessories || [];
    const existingIndex = currentAccessories.findIndex((a: any) => a.id === itemId);
    
    let updated: typeof currentAccessories;
    if (existingIndex >= 0) {
      const existing = currentAccessories[existingIndex];
      const newQty = existing.qty + delta;
      if (newQty <= 0) {
        updated = currentAccessories.filter((a: any) => a.id !== itemId);
      } else {
        updated = [...currentAccessories];
        updated[existingIndex] = { ...existing, qty: newQty };
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

  // Handle search item selection
  const handleSearchItemSelect = (item: CatalogItem) => {
    if (!item.id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid Item',
        message: `Item has an invalid ID. Please select a valid catalog item.`,
      });
      return;
    }
    
    setSearchTerm('');
    setShowSearchResults(false);
    
    // Calculate price - use unit_price which is already calculated as PRECIO UN Venta
    // Priority: unit_price (sale price) > msrp > calculated from cost_exw + margin
    let price = item.unit_price || 0;
    if (!price || price === 0) {
      if ((item as any).msrp) {
        price = (item as any).msrp;
      } else if ((item as any).cost_exw && (item as any).default_margin_pct) {
        price = (item as any).cost_exw * (1 + (item as any).default_margin_pct / 100);
      } else if ((item as any).cost_exw) {
        price = (item as any).cost_exw * 1.5; // Default 50% margin if no margin specified
      }
    }
    
    const itemName = (item as any).item_name || item.name || 'Unknown';
    updateAccessoryQty(item.id, itemName, price, 1);
  };

  const currentAccessories = (config as any).accessories || [];

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <Label className="text-sm font-medium mb-4 block">ACCESSORIES</Label>
        
        {/* Search Bar */}
        <div className="mb-6">
          <Label className="text-xs mb-2 block">Search Catalog Items</Label>
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
                }}
                onFocus={() => setShowSearchResults(true)}
                className="pl-10 pr-10"
              />
              {searchTerm && (
                <button
                  onClick={() => {
                    setSearchTerm('');
                    setShowSearchResults(false);
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
                  const isSelected = currentAccessories.some((a: any) => a.id === item.id);
                  const itemName = item.item_name || item.name || 'Unknown';
                  const sku = item.sku || '';
                  const uom = item.uom || '';
                  
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
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">{itemName}</p>
                          <div className="flex items-center gap-2 mt-0.5">
                            {sku && (
                              <p className="text-xs text-gray-500">SKU: {sku}</p>
                            )}
                            {uom && (
                              <p className="text-xs text-gray-500">UOM: {uom}</p>
                            )}
                          </div>
                          {(item as any).description && (
                            <p className="text-xs text-gray-400 mt-1 line-clamp-1">{(item as any).description}</p>
                          )}
                        </div>
                        <div className="text-right ml-4 flex-shrink-0">
                          <p className="text-sm font-medium text-gray-900">
                            ${(item.unit_price || 0).toFixed(2)} {uom ? `/${uom}` : ''}
                          </p>
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
                <p className="text-sm text-gray-500 text-center">
                  {catalogError 
                    ? `Error loading items: ${catalogError}` 
                    : `No items found for "${searchTerm}"`}
                </p>
                {import.meta.env.DEV && (
                  <p className="text-xs text-gray-400 mt-2 text-center">
                    Searchable items: {searchableCatalogItems.length} | Total items: {catalogItems.length}
                  </p>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Form Body - Selected Accessories */}
        {currentAccessories.length > 0 && (
          <div className="border-t border-gray-200 pt-6">
            <Label className="text-sm font-medium mb-4 block">SELECTED ACCESSORIES</Label>
            <div className="border border-gray-200 rounded-lg overflow-x-auto">
              <table className="w-full min-w-[800px]">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="text-left py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '12%' }}>SKU</th>
                    <th className="text-left py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '18%' }}>Name</th>
                    <th className="text-left py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '25%' }}>Description</th>
                    <th className="text-center py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '12%' }}>QTY</th>
                    <th className="text-right py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '15%' }}>Precio Unit MSRP</th>
                    <th className="text-right py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '12%' }}>TOTAL MSRP</th>
                    <th className="text-center py-3 px-5 text-xs font-medium text-gray-700 whitespace-nowrap" style={{ width: '6%' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {currentAccessories.map((accessory: any) => {
                    const catalogItem = searchableCatalogItems.find(ci => ci.id === accessory.id);
                    const qty = accessory.qty || 0;
                    
                    // Get MSRP price - priority: msrp > unit_price > calculated from cost_exw + margin
                    const msrpPrice = catalogItem 
                      ? ((catalogItem as any).msrp || 
                         catalogItem.unit_price || 
                         ((catalogItem as any).cost_exw && (catalogItem as any).default_margin_pct 
                           ? (catalogItem as any).cost_exw * (1 + (catalogItem as any).default_margin_pct / 100) 
                           : (catalogItem as any).cost_exw ? (catalogItem as any).cost_exw * 1.5 : accessory.price))
                      : accessory.price;
                    
                    const sku = catalogItem?.sku || '';
                    const itemName = accessory.name || catalogItem?.item_name || catalogItem?.name || 'Unknown';
                    const description = (catalogItem as any)?.description || '';
                    
                    return (
                      <tr key={accessory.id} className="border-t border-gray-100 hover:bg-gray-50">
                        <td className="py-4 px-5">
                          <span className="text-sm text-gray-900 break-words">{sku || '—'}</span>
                        </td>
                        <td className="py-4 px-5">
                          <span className="text-sm text-gray-900 break-words">{itemName}</span>
                        </td>
                        <td className="py-4 px-5">
                          <span className="text-sm text-gray-600 break-words line-clamp-2" title={description || undefined}>
                            {description || '—'}
                          </span>
                        </td>
                        <td className="py-4 px-5 text-center">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => updateAccessoryQty(accessory.id, accessory.name, accessory.price, -1)}
                              disabled={qty <= 1}
                              className="p-1.5 hover:bg-gray-200 rounded disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                              <Minus className="w-3.5 h-3.5" />
                            </button>
                            <span className="text-sm font-medium w-10 text-center">{qty}</span>
                            <button
                              onClick={() => updateAccessoryQty(accessory.id, accessory.name, accessory.price, 1)}
                              className="p-1.5 hover:bg-gray-200 rounded transition-colors"
                            >
                              <Plus className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm text-gray-700 whitespace-nowrap">
                            ${msrpPrice.toFixed(2)}{catalogItem?.uom ? ` /${catalogItem.uom}` : ''}
                          </span>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm font-medium text-gray-900 whitespace-nowrap">
                            ${(msrpPrice * qty).toFixed(2)}
                          </span>
                        </td>
                        <td className="py-4 px-5 text-center">
                          <button
                            onClick={() => {
                              const updated = currentAccessories.filter((a: any) => a.id !== accessory.id);
                              onUpdate({ accessories: updated });
                            }}
                            className="p-1.5 hover:bg-red-100 rounded text-red-600 transition-colors"
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
        
        {currentAccessories.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <p className="text-sm">No accessories added yet.</p>
            <p className="text-xs mt-2">Use the search bar above to find and add accessories.</p>
          </div>
        )}
      </div>
    </div>
  );
}
