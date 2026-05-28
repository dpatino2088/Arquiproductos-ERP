import { useEffect, useState, useRef, useMemo } from 'react';
import { Search, X } from 'lucide-react';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';
import Label from '../../../../../components/ui/Label';
import Input from '../../../../../components/ui/Input';
import CatalogItemImage from '../../../../../components/ui/CatalogItemImage';
import { prefetchImageUrls } from '../../../../../lib/imagePrefetch';

interface FilmVariantsStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

interface FilmRow {
  id: string;
  sku: string;
  name: string;
  image_url: string | null;
  collection_name: string;
  variant_name: string;
  roll_width_m: number;
  roll_length_m: number;
  width_inches: number;
}

interface MsrpInfo {
  dealer_price: number;
  pricing_uom: string | null;
}

const INCHES_TO_M = 0.0254;
const MIN_LINEAR_M = 0.3048;
const normalizeLinearLengthMeters = (value: unknown): number => {
  const raw = Number(value);
  if (!Number.isFinite(raw) || raw <= 0) return MIN_LINEAR_M;
  // Backward compatibility: old snapshots may carry mm instead of m.
  const meters = raw > 100 ? raw / 1000 : raw;
  return Math.max(MIN_LINEAR_M, meters);
};

export default function FilmVariantsStep({ config, onUpdate }: FilmVariantsStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [allItems, setAllItems] = useState<FilmRow[]>([]);
  const [msrpMap, setMsrpMap] = useState<Map<string, MsrpInfo>>(new Map());
  const [loading, setLoading] = useState(true);

  const [collectionSearch, setCollectionSearch] = useState('');
  const [showCollectionDropdown, setShowCollectionDropdown] = useState(false);
  const collectionInputRef = useRef<HTMLInputElement>(null);
  const collectionDropdownRef = useRef<HTMLDivElement>(null);

  const manufacturer: string | null = config.manufacturer ?? null;
  const selectedWidth: number | null = config.film_width ?? null;
  const selectedCollection: string | null = config.film_collection ?? null;
  const selectedVariant: string | null = config.film_variant ?? null;
  const sellMode: string = config.sell_mode ?? 'roll';
  const qty: number = config.qty ?? 1;
  const linearLength: number = normalizeLinearLengthMeters(config.linear_length_m);

  useEffect(() => {
    if (selectedCollection && !collectionSearch) {
      setCollectionSearch(selectedCollection);
    }
  }, [selectedCollection]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    let cancelled = false;

    (async () => {
      setLoading(true);

      let query = supabase
        .from('CatalogItems')
        .select('id, sku, name, image_url, collection_name, variant_name, roll_width_m, roll_length_m')
        .eq('organization_id', activeOrganizationId)
        .eq('item_role', 'window_film')
        .eq('is_active', true)
        .not('collection_name', 'is', null)
        .not('variant_name', 'is', null)
        .order('collection_name')
        .order('variant_name')
        .order('roll_width_m');

      if (manufacturer) query = query.ilike('manufacturer', manufacturer);

      const { data: items } = await query;
      if (cancelled) return;

      const rows: FilmRow[] = (items ?? []).map((i: any) => ({
        id: i.id,
        sku: i.sku,
        name: i.name,
        image_url: i.image_url,
        collection_name: i.collection_name,
        variant_name: i.variant_name,
        roll_width_m: Number(i.roll_width_m),
        roll_length_m: Number(i.roll_length_m),
        width_inches: Math.round(Number(i.roll_width_m) / INCHES_TO_M),
      }));

      const ids = rows.map(r => r.id);
      let msrp = new Map<string, MsrpInfo>();
      if (ids.length > 0) {
        const { data: msrpRows } = await supabase
          .from('CatalogItemsMSRP')
          .select('catalog_item_id, dealer_price, pricing_uom')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', ids);
        if (msrpRows) {
          msrp = new Map(msrpRows.map((r: any) => [r.catalog_item_id, {
            dealer_price: Number(r.dealer_price) || 0,
            pricing_uom: r.pricing_uom ? String(r.pricing_uom).toLowerCase() : null,
          }]));
        }
      }

      if (!cancelled) {
        setAllItems(rows);
        setMsrpMap(msrp);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [activeOrganizationId, manufacturer]);

  // Filter items by selected width
  const filteredItems = useMemo(() => {
    if (!selectedWidth) return allItems;
    return allItems.filter(i => i.width_inches === selectedWidth);
  }, [allItems, selectedWidth]);

  // Collections from filtered items
  const collections = useMemo(() => {
    const set = new Set<string>();
    for (const item of filteredItems) set.add(item.collection_name);
    return Array.from(set).sort();
  }, [filteredItems]);

  const filteredCollections = useMemo(() => {
    if (!collectionSearch.trim()) return collections;
    const q = collectionSearch.toLowerCase();
    return collections.filter(c => c.toLowerCase().includes(q));
  }, [collections, collectionSearch]);

  // Variants for selected collection (filtered by width)
  const variants = useMemo(() => {
    if (!selectedCollection) return [];
    const itemsForColl = filteredItems.filter(i => i.collection_name === selectedCollection);
    const varMap = new Map<string, { image_url: string | null }>();
    for (const item of itemsForColl) {
      if (!varMap.has(item.variant_name)) {
        varMap.set(item.variant_name, { image_url: item.image_url });
      }
    }
    return Array.from(varMap.entries())
      .map(([name, info]) => ({
        name,
        display_name: name,
        image_url: info.image_url,
      }))
      .sort((a, b) => {
        const na = parseInt(a.name, 10);
        const nb = parseInt(b.name, 10);
        if (!isNaN(na) && !isNaN(nb)) return na - nb;
        return a.name.localeCompare(b.name);
      });
  }, [filteredItems, selectedCollection]);

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (
        collectionDropdownRef.current &&
        !collectionDropdownRef.current.contains(e.target as Node) &&
        collectionInputRef.current &&
        !collectionInputRef.current.contains(e.target as Node)
      ) {
        setShowCollectionDropdown(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleCollectionChange = (name: string) => {
    setCollectionSearch(name);
    setShowCollectionDropdown(false);
    onUpdate({
      film_collection: name,
      film_variant: null,
      catalog_item_id: null,
      sku: '',
      name: '',
    });
  };

  const handleCollectionSearchChange = (value: string) => {
    setCollectionSearch(value);
    setShowCollectionDropdown(true);
    if (!value.trim()) {
      onUpdate({
        film_collection: null,
        film_variant: null,
        catalog_item_id: null,
        sku: '',
        name: '',
      });
    }
  };

  const handleVariantSelect = (variantName: string) => {
    // Resolve the catalog_item_id directly since width is already selected
    const match = filteredItems.find(
      i => i.collection_name === selectedCollection && i.variant_name === variantName
    );
    if (match) {
      const msrpInfo = msrpMap.get(match.id);
      const dealerRate = msrpInfo?.dealer_price ?? 0;
      const pricingUom = msrpInfo?.pricing_uom ?? 'm';
      const dealerPerLinearM = pricingUom === 'm2'
        ? dealerRate * match.roll_width_m
        : dealerRate;
      const dealerPerM2 = match.roll_width_m > 0
        ? dealerPerLinearM / match.roll_width_m
        : 0;
      const rollArea = match.roll_width_m * match.roll_length_m;
      const rollDealerTotal = dealerPerLinearM * match.roll_length_m;
      const unitArea = sellMode === 'roll'
        ? rollArea
        : match.roll_width_m * linearLength;
      const unitPrice = sellMode === 'linear'
        ? dealerPerLinearM * linearLength
        : rollDealerTotal;
      onUpdate({
        film_variant: variantName,
        film_model: `${selectedCollection} ${variantName}`,
        name: `${selectedCollection} ${variantName}`,
        catalog_item_id: match.id,
        sku: match.sku,
        roll_width_inches: match.width_inches,
        roll_width_m: match.roll_width_m,
        roll_length_m: match.roll_length_m,
        roll_area_m2: rollArea,
        pricing_uom: 'm',
        dealer_per_m2: dealerPerM2,
        dealer_per_linear_m: dealerPerLinearM,
        roll_dealer_total: rollDealerTotal,
        unit_price: unitPrice,
        area_m2: unitArea,
        min_length_m: 0.3048,
      });
    }
  };

  const handleVariantDeselect = () => {
    onUpdate({
      film_variant: null,
      film_model: '',
      name: '',
      catalog_item_id: null,
      sku: '',
      roll_width_inches: 0,
      roll_width_m: 0,
      roll_length_m: 0,
      roll_area_m2: 0,
      dealer_per_m2: 0,
      dealer_per_linear_m: 0,
      roll_dealer_total: 0,
      unit_price: 0,
      area_m2: 0,
    });
  };

  const displayVariants = selectedVariant
    ? variants.filter(v => v.name === selectedVariant)
    : variants;

  useEffect(() => {
    prefetchImageUrls(displayVariants.map((v) => v.image_url), 12);
  }, [displayVariants]);

  // Price summary
  const selectedItem = useMemo(() => {
    if (!selectedCollection || !selectedVariant) return null;
    return filteredItems.find(
      i => i.collection_name === selectedCollection && i.variant_name === selectedVariant
    ) ?? null;
  }, [filteredItems, selectedCollection, selectedVariant]);

  const computedTotal = useMemo(() => {
    if (!selectedItem) return 0;
    const msrpInfo = msrpMap.get(selectedItem.id);
    const dealerRate = msrpInfo?.dealer_price ?? 0;
    const pricingUom = msrpInfo?.pricing_uom ?? 'm';
    const dealerPerLinearM = pricingUom === 'm2'
      ? dealerRate * selectedItem.roll_width_m
      : dealerRate;
    const unitPrice = sellMode === 'roll'
      ? dealerPerLinearM * selectedItem.roll_length_m
      : dealerPerLinearM * linearLength;
    return unitPrice * qty;
  }, [selectedItem, msrpMap, sellMode, qty, linearLength]);

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="space-y-6">
          <div>
            <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>

            {selectedWidth && (
              <p className="text-xs text-gray-500 mb-4">
                Showing collections and variants available in {selectedWidth}" width.
              </p>
            )}

            {/* Collection Search Dropdown */}
            <div className="mb-6 relative">
              <Label htmlFor="film-collection" className="text-xs mb-1">
                Collection
              </Label>
              <div className="relative">
                <div className="relative">
                  <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                  <Input
                    ref={collectionInputRef}
                    id="film-collection"
                    type="text"
                    value={collectionSearch}
                    onChange={(e) => handleCollectionSearchChange(e.target.value)}
                    onFocus={() => setShowCollectionDropdown(true)}
                    onKeyDown={(e) => {
                      if (e.key === 'Escape') setShowCollectionDropdown(false);
                      if (e.key === 'Enter' && filteredCollections.length === 1) {
                        e.preventDefault();
                        handleCollectionChange(filteredCollections[0]);
                      }
                    }}
                    placeholder={loading ? 'Loading...' : 'Search or select collection'}
                    className="pl-8"
                    disabled={loading}
                    autoComplete="off"
                  />
                </div>

                {showCollectionDropdown && !loading && (
                  <div
                    ref={collectionDropdownRef}
                    className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
                  >
                    {filteredCollections.length === 0 ? (
                      <div className="px-3 py-2 text-xs text-gray-500">
                        {collectionSearch.trim() ? 'No collections found' : 'No collections available'}
                      </div>
                    ) : (
                      filteredCollections.map((name) => (
                        <button
                          key={name}
                          type="button"
                          onClick={() => handleCollectionChange(name)}
                          className={`w-full text-left px-3 py-2 text-xs hover:bg-gray-100 ${
                            name === selectedCollection ? 'bg-gray-200 font-medium' : ''
                          }`}
                        >
                          {name}
                        </button>
                      ))
                    )}
                  </div>
                )}
              </div>
            </div>

            {/* Variants Grid */}
            {selectedCollection && (
              <div className="mb-4">
                <Label className="text-xs mb-3 block">Variants</Label>

                {loading ? (
                  <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                    <p className="text-sm">Loading variants...</p>
                  </div>
                ) : variants.length === 0 ? (
                  <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                    <p className="text-sm">No variants available for this collection{selectedWidth ? ` in ${selectedWidth}"` : ''}</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    {displayVariants.map((variant) => {
                      const isSelected = selectedVariant === variant.name;
                      return (
                        <div
                          key={variant.name}
                          onClick={() => handleVariantSelect(variant.name)}
                          className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                            isSelected
                              ? 'border-2 border-gray-900 shadow-lg'
                              : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                          }`}
                        >
                          {isSelected && (
                            <button
                              type="button"
                              onClick={(e) => { e.stopPropagation(); handleVariantDeselect(); }}
                              className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                              title="Remove selection"
                            >
                              <X className="w-4 h-4 text-gray-600" />
                            </button>
                          )}
                          <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                            <CatalogItemImage
                              src={variant.image_url}
                              alt={variant.display_name}
                              size="lg"
                              loadingBehavior="eager"
                              className="w-full h-full !rounded-none !border-0"
                            />
                          </div>
                          <div className="p-4 bg-gray-100 flex-1">
                            <h3 className="font-semibold text-sm truncate text-gray-900" title={variant.display_name}>
                              {variant.display_name}
                            </h3>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}

            {/* Message when no collection selected */}
            {!selectedCollection && !loading && collections.length > 0 && (
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">Please select a collection to view variants</p>
              </div>
            )}
          </div>

          {/* Price summary when variant selected */}
          {selectedItem && (
            <div className="border-t border-gray-200 pt-4">
              <div className="flex items-center justify-between text-sm">
                <div className="text-gray-600">
                  <span className="font-medium">{selectedItem.sku}</span>
                  <span className="text-gray-400 mx-2">·</span>
                  {sellMode === 'roll'
                    ? `${qty} roll${qty > 1 ? 's' : ''}`
                    : `${qty} × ${linearLength.toFixed(2)}m linear`
                  }
                </div>
                <div className="text-right">
                  <p className="text-xs text-gray-500">Subtotal</p>
                  <p className="text-xl font-bold text-gray-900">${computedTotal.toFixed(2)}</p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
