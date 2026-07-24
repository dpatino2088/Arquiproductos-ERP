import { useMemo, useState, useRef, useEffect } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import Input from '../../../components/ui/Input';
import { useManufacturers, useCatalogItemById } from '../../../hooks/useCatalog';
import { useFabricCollections, useFabricVariants } from '../../../hooks/useFabricCatalog';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { supabase } from '../../../lib/supabase/client';
import type { CatalogItemRollSpecsRow } from '../../../services/catalogItemRollSpecs';
import { Search, X } from 'lucide-react';
import CatalogItemImage from '../../../components/ui/CatalogItemImage';
import type { DealerConfiguratorPolicy } from '../../../hooks/useDealerConfiguratorPolicy';
import { useConfiguratorPolicy } from '../../../context/ConfiguratorPolicyContext';
import { prefetchImageUrls } from '../../../lib/imagePrefetch';

interface VariantsStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
  /** Optional override; when inside ProductConfigurator, policy comes from ConfiguratorPolicyContext */
  policy?: DealerConfiguratorPolicy | null;
}

export default function VariantsStep({ config, onUpdate, policy: policyProp }: VariantsStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { policy: policyCtx } = useConfiguratorPolicy();
  const policy = policyProp ?? policyCtx;

  const showCatalog = !policy || policy.allow_variants_catalog;

  const isDrapery = (config as any).productType === 'drapery';
  const trackOnly = !!(config as any).track_only;
  // Dealer/client supplies the fabric ("ghost fabric"): keep the cut list, drop fabric cost.
  const dealerSupplyFabric = !!(config as any).dealer_supply_fabric;
  // Per-dealer permission. No policy (internal context) = allowed. Also keep the toggle visible
  // when the current line already has it enabled, so it can be turned off.
  const allowDealerSupplyFabric = !policy || policy.allow_dealer_supply_fabric === true || dealerSupplyFabric;

  // Get productTypeId from config (set by ProductStep)
  const productTypeId = (config as any).productTypeId || (config as any).product_type_id;
  const collectionName = (config as any).collectionName || (config as any).collection_name || '';
  const manufacturerId = (config as any).manufacturerId || (config as any).manufacturer_id;
  const manufacturerName = (config as any).manufacturerName || (config as any).manufacturer_name;
  const variantId =
    (config as any).variantId ||
    (config as any).fabric_catalog_item_id ||
    (config as any).fabric_variant_id;

  // MSRP from CatalogItemsMSRP (per-org) + its pricing UOM
  const [msrpSaleOut, setMsrpSaleOut] = useState<number | null>(null);
  const [msrpPricingUom, setMsrpPricingUom] = useState<string | null>(null);
  // Roll Specs from CatalogItemRollSpecs (when variant selected)
  const [rollSpecs, setRollSpecs] = useState<CatalogItemRollSpecsRow | null>(null);
  const [loadingRollSpecs, setLoadingRollSpecs] = useState(false);

  // Search state for manufacturers
  const [manufacturerSearch, setManufacturerSearch] = useState('');
  const [showManufacturerDropdown, setShowManufacturerDropdown] = useState(false);
  const manufacturerInputRef = useRef<HTMLInputElement>(null);
  const manufacturerDropdownRef = useRef<HTMLDivElement>(null);

  // Search state for collections
  const [collectionSearch, setCollectionSearch] = useState('');
  const [showCollectionDropdown, setShowCollectionDropdown] = useState(false);
  const collectionInputRef = useRef<HTMLInputElement>(null);
  const collectionDropdownRef = useRef<HTMLDivElement>(null);

  // Manufacturers that have roll items for this product type
  const [manufacturerIdsWithRollForProductType, setManufacturerIdsWithRollForProductType] = useState<Set<string>>(new Set());
  const [manufacturerIdsLoaded, setManufacturerIdsLoaded] = useState(false);

  // Sync manufacturerSearch with manufacturerName
  useEffect(() => {
    if (manufacturerName && !manufacturerSearch) {
      setManufacturerSearch(manufacturerName);
    }
  }, [manufacturerName]);

  // Sync collectionSearch only when collectionName changes from config (no restaurar al borrar)
  const prevCollectionNameRef = useRef<string | undefined>(undefined);
  useEffect(() => {
    if (prevCollectionNameRef.current !== collectionName) {
      prevCollectionNameRef.current = collectionName;
      setCollectionSearch(collectionName || '');
    }
  }, [collectionName]);

  // Fetch manufacturer IDs that have roll items for this product type
  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) {
      setManufacturerIdsLoaded(true);
      setManufacturerIdsWithRollForProductType(new Set());
      return;
    }
    let mounted = true;
    setManufacturerIdsLoaded(false);
    (async () => {
      // Query CatalogItems with CatalogItemProductTypes join to get manufacturers for this product type
      const { data, error } = await supabase
        .from('CatalogItems')
        .select(`
          manufacturer_id,
          CatalogItemProductTypes!inner(product_type_id, organization_id)
        `)
        .eq('organization_id', activeOrganizationId)
        .eq('is_active', true)
        .eq('is_roll', true)
        .eq('CatalogItemProductTypes.product_type_id', productTypeId)
        .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
        .not('manufacturer_id', 'is', null);
      if (!mounted) return;
      if (error) {
        console.error('[VariantsStep] Error fetching manufacturers for product type:', error);
        setManufacturerIdsLoaded(true);
        return;
      }
      const manufacturerIdArray: string[] = (data || [])
        .map((r: { manufacturer_id?: string | null }) => r.manufacturer_id)
        .filter((x: string | null | undefined): x is string => Boolean(x));
      const manufacturerIds = new Set<string>(manufacturerIdArray);
      setManufacturerIdsWithRollForProductType(manufacturerIds);
      setManufacturerIdsLoaded(true);
    })();
    return () => { mounted = false; };
  }, [activeOrganizationId, productTypeId]);

  // Load MSRP Sale Out from CatalogItemsMSRP when variant and org are set
  useEffect(() => {
    if (!variantId || !activeOrganizationId) {
      setMsrpSaleOut(null);
      setMsrpPricingUom(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('CatalogItemsMSRP')
        .select('msrp, pricing_uom')
        .eq('catalog_item_id', variantId)
        .eq('organization_id', activeOrganizationId)
        .maybeSingle();
      if (!cancelled) {
        if (data?.msrp != null && !isNaN(Number(data.msrp))) {
          setMsrpSaleOut(Number(data.msrp));
        } else {
          setMsrpSaleOut(null);
        }
        setMsrpPricingUom(data?.pricing_uom != null ? String(data.pricing_uom) : null);
      }
    })();
    return () => { cancelled = true; };
  }, [variantId, activeOrganizationId]);

  // Load Roll Specs from CatalogItemRollSpecs when variant is selected (with org for RLS)
  useEffect(() => {
    if (!variantId || !activeOrganizationId) {
      setRollSpecs(null);
      setLoadingRollSpecs(false);
      return;
    }
    let cancelled = false;
    setLoadingRollSpecs(true);
    setRollSpecs(null);
    supabase
      .from('CatalogItemRollSpecs')
      .select('*')
      .eq('catalog_item_id', variantId)
      .eq('organization_id', activeOrganizationId)
      .maybeSingle()
      .then(({ data, error }: { data: CatalogItemRollSpecsRow | null; error: Error | null }) => {
        if (cancelled) return;
        if (error) {
          if (import.meta.env.DEV) console.warn('[VariantsStep] Roll specs fetch:', error.message);
          setRollSpecs(null);
          return;
        }
        setRollSpecs((data as CatalogItemRollSpecsRow | null) ?? null);
      })
      .finally(() => {
        if (!cancelled) setLoadingRollSpecs(false);
      });
    return () => { cancelled = true; };
  }, [variantId, activeOrganizationId]);

  // Fetch collections and variants (with optional manufacturer filter)
  const {
    collections,
    loading: loadingCollections,
    error: collectionsError,
  } = useFabricCollections(productTypeId, manufacturerId || undefined);

  const {
    variants,
    loading: loadingVariants,
    error: variantsError,
  } = useFabricVariants(productTypeId, collectionName || undefined, manufacturerId || undefined);

  const { manufacturers, loading: loadingManufacturers } = useManufacturers();

  // Filter manufacturers to only those with roll items for this product type
  const manufacturersForDropdown = useMemo(() => {
    if (!manufacturers) return [];
    if (!manufacturerIdsLoaded) return manufacturers; // Show all while loading
    return manufacturers.filter(m => manufacturerIdsWithRollForProductType.has(m.id));
  }, [manufacturers, manufacturerIdsLoaded, manufacturerIdsWithRollForProductType]);

  // Filter manufacturers by search
  const filteredManufacturers = useMemo(() => {
    if (!manufacturerSearch.trim()) return manufacturersForDropdown;
    const searchLower = manufacturerSearch.toLowerCase();
    return manufacturersForDropdown.filter(m => 
      (m.name || '').toLowerCase().includes(searchLower) ||
      (m.code || '').toLowerCase().includes(searchLower)
    );
  }, [manufacturersForDropdown, manufacturerSearch]);

  // Debug log in DEV (after variants is declared)
  if (import.meta.env.DEV) {
    console.log('VariantsStep render', {
      productTypeId,
      collectionName,
      variantId,
      variantsCount: variants.length,
      loadingVariants,
      variantsError,
      fullConfig: config,
    });
  }

  // Fetch selected variant details
  const { item: selectedCatalogItem, loading: loadingSelectedItem } =
    useCatalogItemById(variantId);

  // Get manufacturer name from variant or from selectedCatalogItem
  const selectedManufacturerName = useMemo(() => {
    const selectedVariant = variants.find(v => v.id === variantId);
    if (selectedVariant?.manufacturer) return selectedVariant.manufacturer;
    if (selectedVariant?.manufacturer_id) {
      const mfg = manufacturers.find((m) => m.id === selectedVariant.manufacturer_id);
      return mfg?.name || '—';
    }
    return '—';
  }, [variantId, variants, manufacturers]);

  // Extract fabric specs from variants or from selectedCatalogItem (fallback when editing / variant not in list)
  // Variant = CatalogItems.variant_name
  const fabricSpecs = useMemo(() => {
    const clean = (v: unknown): string | null => {
      if (v == null) return null;
      const s = String(v).trim();
      if (!s || s === '—') return null;
      return s;
    };
    const selectedVariant = variants.find(v => v.id === variantId);
    if (selectedVariant) {
      return {
        manufacturer: clean(selectedManufacturerName),
        rollWidth: selectedVariant.roll_width ? `${selectedVariant.roll_width}m` : null,
        variantName: clean(selectedVariant.variant_name ?? selectedVariant.color),
        description: clean(selectedVariant.description),
      };
    }
    if (selectedCatalogItem && variantId) {
      const rw = (selectedCatalogItem as any).roll_width_m ?? (selectedCatalogItem as any).roll_width;
      return {
        manufacturer: clean(selectedManufacturerName),
        rollWidth: rw != null ? `${rw}m` : null,
        variantName: clean((selectedCatalogItem as any).variant_name ?? (selectedCatalogItem as any).name),
        description: clean((selectedCatalogItem as any).description),
      };
    }
    return null;
  }, [variantId, variants, selectedManufacturerName, selectedCatalogItem]);

  const rollWidthM = useMemo(() => {
    const selectedVariant = variants.find(v => v.id === variantId);
    const fromVariant = selectedVariant?.roll_width != null ? Number(selectedVariant.roll_width) : null;
    if (fromVariant != null && !isNaN(fromVariant) && fromVariant > 0) return fromVariant;
    const fromCatalog =
      (selectedCatalogItem as any)?.roll_width_m != null
        ? Number((selectedCatalogItem as any).roll_width_m)
        : ((selectedCatalogItem as any)?.roll_width != null ? Number((selectedCatalogItem as any).roll_width) : null);
    if (fromCatalog != null && !isNaN(fromCatalog) && fromCatalog > 0) return fromCatalog;
    return null;
  }, [variantId, variants, selectedCatalogItem]);

  const msrpPerM2 = useMemo(() => {
    if (msrpSaleOut == null || isNaN(msrpSaleOut)) return null;
    const uomNorm = (msrpPricingUom || '').toLowerCase().replace('²', '2');
    if (uomNorm === 'm2' || uomNorm === 'sqm' || uomNorm === 'sq_m') return msrpSaleOut;
    if (uomNorm === 'm') {
      if (rollWidthM != null && rollWidthM > 0) return msrpSaleOut / rollWidthM;
      return null;
    }
    // Fallback for legacy rows without pricing_uom: assume linear meter if roll width exists.
    if (rollWidthM != null && rollWidthM > 0) return msrpSaleOut / rollWidthM;
    return msrpSaleOut;
  }, [msrpSaleOut, msrpPricingUom, rollWidthM]);

  const hasTechnicalData = useMemo(() => {
    return Boolean(
      fabricSpecs?.manufacturer ||
      fabricSpecs?.rollWidth ||
      fabricSpecs?.variantName ||
      fabricSpecs?.description ||
      msrpPerM2 != null ||
      rollSpecs?.can_rotate != null ||
      rollSpecs?.is_weldable != null ||
      (rollSpecs?.raw_material && String(rollSpecs.raw_material).trim() !== '') ||
      rollSpecs?.openness_factor_pct != null ||
      rollSpecs?.weight_g_m2 != null ||
      rollSpecs?.weight_kg_m2 != null ||
      (rollSpecs?.notes && String(rollSpecs.notes).trim() !== '')
    );
  }, [fabricSpecs, msrpPerM2, rollSpecs]);

  // Filter collections based on search
  const filteredCollections = useMemo(() => {
    if (!collectionSearch.trim()) return collections;
    const searchLower = collectionSearch.toLowerCase();
    return collections.filter(name => 
      name.toLowerCase().includes(searchLower)
    );
  }, [collections, collectionSearch]);

  // Keep selection resilient: if selected variant is not in current options,
  // fall back to showing full list and clear stale selection.
  const hasSelectedVariantInList = useMemo(
    () => Boolean(variantId && variants.some((v) => v.id === variantId)),
    [variantId, variants]
  );

  const displayedVariants = useMemo(() => {
    if (!variantId) return variants;
    return hasSelectedVariantInList ? variants.filter((v) => v.id === variantId) : variants;
  }, [variantId, hasSelectedVariantInList, variants]);

  useEffect(() => {
    prefetchImageUrls(displayedVariants.map((v: any) => v?.image_url || null), 12);
  }, [displayedVariants]);

  useEffect(() => {
    if (!variantId || loadingVariants) return;
    if (variants.length === 0) return;
    if (hasSelectedVariantInList) return;
    onUpdate({
      variantId: undefined,
      fabric_catalog_item_id: undefined,
      fabric_variant_id: undefined,
      variantName: undefined,
      variant_name: undefined,
    } as any);
  }, [variantId, loadingVariants, variants, hasSelectedVariantInList, onUpdate]);

  // Close dropdowns when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      const target = event.target as Node;
      // Manufacturer dropdown
      if (
        manufacturerDropdownRef.current &&
        !manufacturerDropdownRef.current.contains(target) &&
        manufacturerInputRef.current &&
        !manufacturerInputRef.current.contains(target)
      ) {
        setShowManufacturerDropdown(false);
      }
      // Collection dropdown
      if (
        collectionDropdownRef.current &&
        !collectionDropdownRef.current.contains(target) &&
        collectionInputRef.current &&
        !collectionInputRef.current.contains(target)
      ) {
        setShowCollectionDropdown(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Handlers
  const handleManufacturerChange = (id: string, name: string) => {
    setManufacturerSearch(name || '');
    setShowManufacturerDropdown(false);
    // When manufacturer changes, clear collection and variant
    setCollectionSearch('');
    onUpdate({
      manufacturerId: id || undefined,
      manufacturer_id: id || undefined,
      manufacturerName: name || undefined,
      manufacturer_name: name || undefined,
      collectionName: undefined,
      collection_name: undefined,
      collectionId: undefined,
      variantId: undefined,
      fabric_catalog_item_id: undefined,
      variantName: undefined,
      variant_name: undefined,
    } as any);
  };

  const handleManufacturerSearchChange = (value: string) => {
    setManufacturerSearch(value);
    setShowManufacturerDropdown(true);
  };

  const handleCollectionChange = (name: string) => {
    setCollectionSearch(name);
    setShowCollectionDropdown(false);
    onUpdate({
      collectionName: name,
      collection_name: name,
      collectionId: `collection-${name
        .toLowerCase()
        .replace(/\s+/g, '-')
        .replace(/[^a-z0-9-]/g, '')}`,
      variantId: undefined,
      fabric_catalog_item_id: undefined,
      variantName: undefined,
      variant_name: undefined,
    } as any);
  };

  const handleCollectionSearchChange = (value: string) => {
    setCollectionSearch(value);
  };

  const trySelectCollectionFromText = (rawValue: string) => {
    const value = rawValue.trim().toLowerCase();
    if (!value) return false;
    const exact = collections.find((name) => name.trim().toLowerCase() === value);
    if (!exact) return false;
    handleCollectionChange(exact);
    return true;
  };

  const handleVariantChange = (variantIdValue: string) => {
    const selectedVariantItem = variants.find((item) => item.id === variantIdValue);
    const variantName =
      selectedVariantItem?.variant_name ||
      (selectedVariantItem as any)?.item_name ||
      selectedVariantItem?.sku ||
      undefined;

    onUpdate({
      variantId: variantIdValue,
      fabric_catalog_item_id: variantIdValue,
      variantName,
      variant_name: variantName,
      collectionName,
      collection_name: collectionName,
    } as any);
  };

  // Show error if no productTypeId
  if (!productTypeId) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>
          <div className="text-center text-red-500 py-8">
            <p className="text-sm font-medium">Missing Product Type</p>
            <p className="text-xs mt-1">
              Please select a product type in the previous step before selecting fabrics.
            </p>
          </div>
        </div>
      </div>
    );
  }

  // DealerConfiguratorPolicy: catalog not allowed
  if (policy && !showCatalog) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>
          <div className="text-center text-gray-500 py-8">
            <p className="text-sm font-medium">Fabric selection is not available for your account.</p>
            <p className="text-xs mt-1">Contact your administrator if you need access.</p>
          </div>
        </div>
      </div>
    );
  }

  const catalogContent = (
    <div className="space-y-6">
        <div>
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>

          {/* Collections Error Display */}
          {collectionsError && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
              Error loading collections: {String(collectionsError)}
            </div>
          )}

          {/* Manufacturer Dropdown with Search */}
          <div className="mb-6 relative">
            <Label htmlFor="manufacturer" className="text-xs mb-1">
              Manufacturer
            </Label>
            <div className="relative">
              <div className="relative">
                <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  ref={manufacturerInputRef}
                  id="manufacturer"
                  type="text"
                  value={manufacturerSearch || manufacturerName || ''}
                  onChange={(e) => handleManufacturerSearchChange(e.target.value)}
                  onFocus={() => setShowManufacturerDropdown(true)}
                  placeholder={loadingManufacturers ? 'Loading...' : 'Search or select manufacturer'}
                  className="pl-8"
                  disabled={loadingManufacturers}
                />
              </div>
              
              {/* Dropdown for filtered manufacturers */}
              {showManufacturerDropdown && !loadingManufacturers && (
                <div
                  ref={manufacturerDropdownRef}
                  className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
                >
                  {/* "All manufacturers" option */}
                  <button
                    type="button"
                    onClick={() => handleManufacturerChange('', '')}
                    className={`w-full text-left px-3 py-2 text-xs hover:bg-gray-100 ${
                      !manufacturerId ? 'bg-gray-200 font-medium' : ''
                    }`}
                  >
                    All manufacturers
                  </button>
                  {filteredManufacturers.length === 0 ? (
                    <div className="px-3 py-2 text-xs text-gray-500">
                      {manufacturerSearch ? 'No manufacturers found' : 'No manufacturers available'}
                    </div>
                  ) : (
                    filteredManufacturers.map((m) => (
                      <button
                        key={m.id}
                        type="button"
                        onClick={() => handleManufacturerChange(m.id, m.name)}
                        className={`w-full text-left px-3 py-2 text-xs hover:bg-gray-100 ${
                          m.id === manufacturerId ? 'bg-gray-200 font-medium' : ''
                        }`}
                      >
                        {m.name}
                      </button>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Collection dropdown: shows all collections on focus, filter by typing */}
          <div className="mb-6 relative">
            <Label htmlFor="collection" className="text-xs mb-1">
              Collection
            </Label>
            <div className="relative">
              <div className="relative">
                <Search className="absolute left-2.5 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  ref={collectionInputRef}
                  id="collection"
                  type="text"
                  value={collectionSearch}
                  onChange={(e) => handleCollectionSearchChange(e.target.value)}
                  onFocus={() => setShowCollectionDropdown(true)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      const matched = trySelectCollectionFromText(collectionSearch);
                      if (matched) {
                        e.preventDefault();
                        setShowCollectionDropdown(false);
                      }
                    } else if (e.key === 'Escape') {
                      setShowCollectionDropdown(false);
                    }
                  }}
                  placeholder={loadingCollections ? 'Loading...' : 'Search or select collection'}
                  className="pl-8"
                  disabled={loadingCollections}
                  autoComplete="off"
                  data-lpignore="true"
                  data-form-type="other"
                />
              </div>

              {/* Dropdown con todas las colecciones (se abre al enfocar; se filtra al escribir) */}
              {showCollectionDropdown && !loadingCollections && !collectionsError && (
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
                          name === collectionName ? 'bg-gray-200 font-medium' : ''
                        }`}
                      >
                        {name}
                      </button>
                    ))
                  )}
                </div>
              )}
            </div>

            {collectionsError && (
              <p className="mt-1 text-xs text-red-600">
                {String(collectionsError)}
              </p>
            )}
          </div>

          {/* Variants Grid - Show when collection is selected */}
          {collectionName && (
            <div className="mb-4">
              <Label className="text-xs mb-3 block">Variants</Label>
              
              {loadingVariants ? (
                <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                  <p className="text-sm">Loading variants...</p>
                </div>
              ) : variantsError ? (
                <div className="text-center text-red-500 py-8 border border-red-200 rounded-lg">
                  <p className="text-sm font-medium">Error loading variants</p>
                  <p className="text-xs mt-1">{String(variantsError)}</p>
                </div>
              ) : variants.length === 0 ? (
                <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                  <p className="text-sm">No variants available for this collection</p>
                </div>
              ) : (
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {displayedVariants.map((variant) => {
                    // Check if this variant is selected
                    const isSelected = variantId === variant.id;
                    
                    return (
                      <div
                        key={variant.id}
                        onClick={() => handleVariantChange(variant.id)}
                        className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                          isSelected
                            ? 'border-2 border-gray-900 shadow-lg'
                            : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                        }`}
                      >
                        {/* X to deselect */}
                        {isSelected && (
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onUpdate({
                                variantId: undefined,
                                fabric_catalog_item_id: undefined,
                                fabric_variant_id: undefined,
                                variantName: undefined,
                                variant_name: undefined,
                              } as any);
                            }}
                            className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                            title="Remove selection"
                          >
                            <X className="w-4 h-4 text-gray-600" />
                          </button>
                        )}
                        {/* Image */}
                        <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                          <CatalogItemImage
                            src={(variant as any).image_url}
                            alt={variant.variant_name || variant.sku || 'Variant'}
                            size="lg"
                            loadingBehavior="eager"
                            className="w-full h-full !rounded-none !border-0"
                          />
                        </div>
                        
                        {/* Card Content */}
                        <div className="p-4 bg-gray-100 flex-1">
                          {/* Variant Name */}
                          <h3 className={`font-semibold text-sm mb-2 truncate ${
                            isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                          }`} title={variant.variant_name || variant.sku || 'Unknown'}>
                            {variant.variant_name || (variant as any).item_name || variant.sku || 'Unknown'}
                          </h3>
                          
                          {/* SKU */}
                          {variant.sku && (
                            <div className="mb-2">
                              <p className="text-xs text-gray-500 mb-0.5">SKU</p>
                              <p className="text-sm text-gray-700 font-mono truncate" title={variant.sku}>
                                {variant.sku}
                              </p>
                            </div>
                          )}
                          
                          {/* Roll Width */}
                          {(variant as any).roll_width && (
                            <div>
                              <p className="text-xs text-gray-500 mb-0.5">Roll Width</p>
                              <p className="text-sm text-gray-700">
                                {Number((variant as any).roll_width).toFixed(2)} m
                              </p>
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* Show message when no collection selected */}
          {!collectionName && !loadingCollections && collections.length > 0 && (
            <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
              <p className="text-sm">Please select a collection to view variants</p>
            </div>
          )}
        </div>

        {/* Fabric Spec Details (incl. CatalogItemRollSpecs) */}
        {variantId && (loadingSelectedItem || loadingRollSpecs || hasTechnicalData) && (
          <div className="border-t border-gray-200 pt-4">
            <Label className="text-sm font-medium mb-3 block">Fabric Spec Details</Label>
            {loadingSelectedItem || loadingRollSpecs ? (
              <div className="text-sm text-gray-500 py-2">Loading...</div>
            ) : (
              <div className="bg-gray-50 rounded-lg p-4">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  {fabricSpecs?.manufacturer ? (
                    <div>
                      <span className="text-gray-600">Manufacturer:</span>
                      <span className="ml-2 font-medium">{fabricSpecs.manufacturer}</span>
                    </div>
                  ) : null}
                  {fabricSpecs?.rollWidth ? (
                    <div>
                      <span className="text-gray-600">Roll Width:</span>
                      <span className="ml-2 font-medium">{fabricSpecs.rollWidth}</span>
                    </div>
                  ) : null}
                  {fabricSpecs?.variantName ? (
                    <div>
                      <span className="text-gray-600">Variant:</span>
                      <span className="ml-2 font-medium">{fabricSpecs.variantName}</span>
                    </div>
                  ) : null}
                  {msrpPerM2 != null && !isNaN(msrpPerM2) ? (
                    <div>
                      <span className="text-gray-600">MSRP / m²:</span>
                      <span className="ml-2 font-medium">${Number(msrpPerM2).toFixed(2)}</span>
                    </div>
                  ) : null}
                  {fabricSpecs?.description ? (
                    <div className="col-span-2">
                      <span className="text-gray-600">Description:</span>
                      <span className="ml-2 font-medium">{fabricSpecs.description}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.can_rotate != null ? (
                    <div>
                      <span className="text-gray-600">Can rotate:</span>
                      <span className="ml-2 font-medium">{rollSpecs.can_rotate ? 'Yes' : 'No'}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.is_weldable != null ? (
                    <div>
                      <span className="text-gray-600">Weldable:</span>
                      <span className="ml-2 font-medium">{rollSpecs.is_weldable ? 'Yes' : 'No'}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.raw_material ? (
                    <div>
                      <span className="text-gray-600">Raw material:</span>
                      <span className="ml-2 font-medium">{rollSpecs.raw_material}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.openness_factor_pct != null && rollSpecs.openness_factor_pct !== '' ? (
                    <div>
                      <span className="text-gray-600">Openness:</span>
                      <span className="ml-2 font-medium">{`${Number(rollSpecs.openness_factor_pct)}%`}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.weight_g_m2 != null && rollSpecs.weight_g_m2 !== '' ? (
                    <div>
                      <span className="text-gray-600">Weight (g/m²):</span>
                      <span className="ml-2 font-medium">{Number(rollSpecs.weight_g_m2)}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.weight_kg_m2 != null && rollSpecs.weight_kg_m2 !== '' ? (
                    <div>
                      <span className="text-gray-600">Weight (kg/m²):</span>
                      <span className="ml-2 font-medium">{Number(rollSpecs.weight_kg_m2)}</span>
                    </div>
                  ) : null}
                  {rollSpecs?.notes ? (
                    <div className="col-span-2">
                      <span className="text-gray-600">Notes:</span>
                      <span className="ml-2 font-medium">{rollSpecs.notes}</span>
                    </div>
                  ) : null}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
  );

  const handleTrackOnlyToggle = (enabled: boolean) => {
    if (enabled) {
      onUpdate({
        track_only: true,
        variantId: undefined,
        fabric_catalog_item_id: undefined,
        variantName: undefined,
        variant_name: undefined,
        collectionName: undefined,
        collection_name: undefined,
      } as any);
    } else {
      onUpdate({ track_only: false } as any);
    }
  };

  const handleDealerSupplyToggle = (enabled: boolean) => {
    if (enabled) {
      // Ghost fabric: drop the selected fabric (no cost) but keep the cut list.
      onUpdate({
        dealer_supply_fabric: true,
        variantId: undefined,
        fabric_catalog_item_id: undefined,
        fabric_variant_id: undefined,
        variantName: undefined,
        variant_name: undefined,
        collectionName: undefined,
        collection_name: undefined,
        collectionId: undefined,
      } as any);
    } else {
      onUpdate({ dealer_supply_fabric: false } as any);
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {isDrapery && (
          <div className="flex items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded-lg">
            <div>
              <p className="text-sm font-medium text-gray-900">Track Only</p>
              <p className="text-xs text-gray-500">Customer supplies their own fabric</p>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={trackOnly}
              onClick={() => handleTrackOnlyToggle(!trackOnly)}
              className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2 ${trackOnly ? 'bg-gray-900' : 'bg-gray-300'}`}
            >
              <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${trackOnly ? 'translate-x-5' : 'translate-x-0'}`} />
            </button>
          </div>
        )}

        {!isDrapery && !trackOnly && allowDealerSupplyFabric && (
          <div className="flex items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded-lg">
            <div>
              <p className="text-sm font-medium text-gray-900">Dealer Supply Fabric</p>
              <p className="text-xs text-gray-500">Client provides the fabric — we still produce the cut list, but the fabric cost is removed from the quote (labor & hardware stay).</p>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={dealerSupplyFabric}
              onClick={() => handleDealerSupplyToggle(!dealerSupplyFabric)}
              className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2 ${dealerSupplyFabric ? 'bg-gray-900' : 'bg-gray-300'}`}
            >
              <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${dealerSupplyFabric ? 'translate-x-5' : 'translate-x-0'}`} />
            </button>
          </div>
        )}

        {trackOnly ? (
          <div className="text-center py-12 space-y-3">
            <div className="mx-auto w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center">
              <svg className="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
              </svg>
            </div>
            <p className="text-sm font-medium text-gray-900">No fabric required</p>
            <p className="text-xs text-gray-500">Only track, hardware, and accessories will be quoted.</p>
          </div>
        ) : dealerSupplyFabric ? (
          <div className="text-center py-12 space-y-3">
            <div className="mx-auto w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center">
              <svg className="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 9.75h16.5m-16.5 0v8.25a1.5 1.5 0 0 0 1.5 1.5h13.5a1.5 1.5 0 0 0 1.5-1.5V9.75m-16.5 0L5.25 4.5h13.5l1.5 5.25M9 13.5h6" />
              </svg>
            </div>
            <p className="text-sm font-medium text-gray-900">Dealer-supplied fabric</p>
            <p className="text-xs text-gray-500 max-w-md mx-auto">The cut list will still be calculated from the measurements and cutting rules. The fabric itself is provided by the client, so its cost is excluded from the quote — labor and hardware remain.</p>
          </div>
        ) : (
          catalogContent
        )}
      </div>
    </div>
  );
}
