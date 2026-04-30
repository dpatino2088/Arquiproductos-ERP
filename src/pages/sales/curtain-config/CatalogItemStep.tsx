import { useState, useEffect, useMemo } from 'react';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Search, X, Package } from 'lucide-react';
import { useCatalogItems } from '../../../hooks/useCatalog';
import { CatalogItem } from '../../../types/catalog';

interface CatalogItemStepProps {
  config: Partial<ProductConfig>;
  onUpdate: (updates: Partial<ProductConfig>) => void;
}

export default function CatalogItemStep({ config, onUpdate }: CatalogItemStepProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [showDropdown, setShowDropdown] = useState(false);
  const [searchRef, setSearchRef] = useState<HTMLDivElement | null>(null);

  const cfg = config as any;
  const selectedItemId: string | null = cfg.catalog_item_id ?? null;
  const selectedName: string = cfg.name ?? '';
  const selectedSku: string = cfg.sku ?? '';
  const selectedUnitPrice: number = cfg.unit_price ?? 0;
  const qty: number = cfg.qty ?? 1;
  const currentArea: string = cfg.area ?? '';
  const currentPosition: string = cfg.position ?? '';

  const { items: catalogItems, loading: catalogLoading, error: catalogError } = useCatalogItems(undefined, undefined);

  // Resolve color: prefer cfg.color, fall back to lookup by catalog_item_id from loaded catalog
  const selectedColor: string = useMemo(() => {
    if (cfg.color && String(cfg.color).trim()) return String(cfg.color).trim();
    if (!selectedItemId) return '';
    const found = catalogItems.find((it) => it.id === selectedItemId);
    if (!found) return '';
    return String((found as any).color || (found as any).variant_name || '').trim();
  }, [cfg.color, selectedItemId, catalogItems]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (searchRef && !searchRef.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };
    if (showDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [showDropdown, searchRef]);

  // Searchable items: unit-based, active, not fabric
  const searchableItems = useMemo(() => {
    return catalogItems.filter(item => {
      if ((item as any).item_type === 'fabric') return false;
      if ((item as any).item_type === 'linear') return false;
      if (item.is_fabric === true) return false;
      if (item.measure_basis !== 'unit') return false;
      if (!item.id || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id)) return false;
      if (!item.active || item.deleted) return false;
      return true;
    });
  }, [catalogItems]);

  const filteredResults = useMemo(() => {
    if (!searchTerm.trim()) return [];
    const lower = searchTerm.toLowerCase().trim();
    const results = searchableItems.filter(item => {
      const name = String((item as any).item_name || item.name || '').toLowerCase();
      const sku = String(item.sku || '').toLowerCase();
      const desc = String((item as any).description || '').toLowerCase();
      const color = String((item as any).color || '').toLowerCase();
      const variant = String((item as any).variant_name || '').toLowerCase();
      return (
        name.includes(lower)
        || sku.includes(lower)
        || desc.includes(lower)
        || color.includes(lower)
        || variant.includes(lower)
      );
    });
    return results
      .sort((a, b) => {
        const aSku = String(a.sku || '').toLowerCase();
        const bSku = String(b.sku || '').toLowerCase();
        const aName = String((a as any).item_name || a.name || '').toLowerCase();
        const bName = String((b as any).item_name || b.name || '').toLowerCase();
        if (aSku === lower && bSku !== lower) return -1;
        if (bSku === lower && aSku !== lower) return 1;
        if (aSku.startsWith(lower) && !bSku.startsWith(lower)) return -1;
        if (bSku.startsWith(lower) && !aSku.startsWith(lower)) return 1;
        if (aName.startsWith(lower) && !bName.startsWith(lower)) return -1;
        if (bName.startsWith(lower) && !aName.startsWith(lower)) return 1;
        return aName.localeCompare(bName);
      })
      .slice(0, 10);
  }, [searchTerm, searchableItems]);

  const handleSelectItem = (item: CatalogItem) => {
    const itemName = (item as any).item_name || item.name || 'Unknown';
    const unitPrice = (item as any).msrp || item.unit_price || 0;
    const itemColor = (item as any).color || (item as any).variant_name || '';
    setSearchTerm('');
    setShowDropdown(false);
    onUpdate({
      catalog_item_id: item.id,
      name: itemName,
      sku: item.sku || '',
      color: itemColor,
      unit_price: unitPrice,
      qty: qty || 1,
    } as any);
  };

  const handleClearItem = () => {
    onUpdate({
      catalog_item_id: null,
      name: '',
      sku: '',
      color: '',
      unit_price: 0,
    } as any);
  };

  const handleQtyChange = (value: string) => {
    const n = Math.max(1, parseInt(value, 10) || 1);
    onUpdate({ qty: n } as any);
  };

  const lineTotal = selectedUnitPrice * qty;

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <Label className="text-sm font-medium mb-4 block">CATALOG ITEM</Label>

        {/* Area / Position */}
        <div className="grid grid-cols-2 gap-4 pb-4 border-b border-gray-100">
          <div>
            <Label className="text-xs mb-1 block">Area <span className="text-gray-400 font-normal">(optional)</span></Label>
            <Input
              type="text"
              placeholder="e.g. Living Room, Bedroom..."
              value={currentArea}
              onChange={(e) => onUpdate({ area: e.target.value || null } as any)}
            />
          </div>
          <div>
            <Label className="text-xs mb-1 block">Position <span className="text-gray-400 font-normal">(optional)</span></Label>
            <Input
              type="text"
              placeholder="e.g. W.1, W.2..."
              value={currentPosition}
              onChange={(e) => onUpdate({ position: e.target.value || null } as any)}
            />
          </div>
        </div>

        {/* Selected Item */}
        {selectedItemId ? (
          <div className="border border-blue-200 bg-blue-50 rounded-lg p-4">
            <div className="flex items-start justify-between">
              <div className="flex items-start gap-3 flex-1 min-w-0">
                <div className="p-2 bg-blue-100 rounded-lg mt-0.5 flex-shrink-0">
                  <Package className="w-5 h-5 text-blue-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-gray-900">
                    {selectedName}
                    {selectedColor && (
                      <span className="text-gray-500 font-normal"> — {selectedColor}</span>
                    )}
                  </p>
                  {selectedSku && (
                    <p className="text-xs text-gray-500 mt-0.5">SKU: {selectedSku}</p>
                  )}
                  <p className="text-sm text-blue-700 font-medium mt-1">
                    ${selectedUnitPrice.toFixed(2)} / ea
                  </p>
                </div>
              </div>
              <button
                onClick={handleClearItem}
                className="p-1.5 hover:bg-red-100 rounded text-gray-400 hover:text-red-600 transition-colors flex-shrink-0"
                title="Remove item"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Quantity + Total */}
            <div className="mt-4 flex items-center gap-6">
              <div className="flex items-center gap-3">
                <Label className="text-xs font-medium text-gray-700">Quantity</Label>
                <Input
                  type="number"
                  min={1}
                  value={qty}
                  onChange={(e) => handleQtyChange(e.target.value)}
                  className="w-20 text-center"
                />
              </div>
              <div className="flex-1" />
              <div className="text-right">
                <p className="text-xs text-gray-500">Subtotal</p>
                <p className="text-lg font-bold text-gray-900">${lineTotal.toFixed(2)}</p>
              </div>
            </div>
          </div>
        ) : (
          /* Search */
          <div>
            <Label className="text-xs mb-2 block">Search Catalog Item</Label>
            <div className="relative" ref={setSearchRef}>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <Input
                  type="text"
                  placeholder="Search by name, SKU, description..."
                  value={searchTerm}
                  onChange={(e) => {
                    setSearchTerm(e.target.value);
                    setShowDropdown(true);
                  }}
                  onFocus={() => setShowDropdown(true)}
                  className="pl-10 pr-10"
                />
                {searchTerm && (
                  <button
                    onClick={() => { setSearchTerm(''); setShowDropdown(false); }}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    <X className="w-4 h-4" />
                  </button>
                )}
              </div>

              {showDropdown && filteredResults.length > 0 && (
                <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-64 overflow-y-auto">
                  {filteredResults.map((item) => {
                    const itemName = (item as any).item_name || item.name || 'Unknown';
                    const sku = item.sku || '';
                    const unitPrice = (item as any).msrp || item.unit_price || 0;
                    const role = (item as any).item_role || '';
                    const color = (item as any).color || (item as any).variant_name || '';
                    return (
                      <button
                        key={item.id}
                        onClick={() => handleSelectItem(item)}
                        className="w-full text-left px-4 py-3 hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-b-0"
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-gray-900 truncate">
                              {itemName}
                              {color && (
                                <span className="text-gray-500 font-normal"> — {color}</span>
                              )}
                            </p>
                            <div className="flex items-center gap-2 mt-0.5">
                              {sku && <span className="text-xs text-gray-500">SKU: {sku}</span>}
                              {role && <span className="text-xs text-gray-400 capitalize">{role}</span>}
                            </div>
                          </div>
                          <div className="text-right ml-4 flex-shrink-0">
                            <p className="text-sm font-semibold text-gray-900">${unitPrice.toFixed(2)}</p>
                            <p className="text-xs text-gray-400">/ ea</p>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}

              {showDropdown && searchTerm && filteredResults.length === 0 && !catalogLoading && (
                <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg p-4">
                  <p className="text-sm text-gray-500 text-center">
                    {catalogError ? `Error loading items: ${catalogError}` : `No items found for "${searchTerm}"`}
                  </p>
                </div>
              )}
            </div>

            <div className="text-center py-10 text-gray-400">
              <Package className="w-10 h-10 mx-auto mb-2 opacity-40" />
              <p className="text-sm">Search and select a catalog item above.</p>
              <p className="text-xs mt-1">One item per line — adjust quantity after selection.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
