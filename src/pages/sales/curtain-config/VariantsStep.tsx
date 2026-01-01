import { useMemo } from 'react';
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
import { useManufacturers, useCatalogItemById } from '../../../hooks/useCatalog';
import { useFabricCollections, useFabricVariants } from '../../../hooks/useFabricCatalog';

interface VariantsStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

export default function VariantsStep({ config, onUpdate }: VariantsStepProps) {
  // Get productTypeId from config (set by ProductStep)
  const productTypeId = (config as any).productTypeId;
  const collectionName = (config as any).collectionName || '';
  const variantId = (config as any).variantId || (config as any).fabric_catalog_item_id;

  // Debug log in DEV
  if (import.meta.env.DEV) {
    console.log('VariantsStep render', {
      productTypeId,
      collectionName,
      variantId,
      fullConfig: config,
    });
  }

  // Fetch collections and variants
  const {
    collections,
    loading: loadingCollections,
    error: collectionsError,
  } = useFabricCollections(productTypeId);

  const {
    variants,
    loading: loadingVariants,
    error: variantsError,
  } = useFabricVariants(productTypeId, collectionName || undefined);

  const { manufacturers } = useManufacturers();

  // Fetch selected variant details
  const { item: selectedCatalogItem, loading: loadingSelectedItem } =
    useCatalogItemById(variantId);

  // Get manufacturer name
  const selectedManufacturerName = useMemo(() => {
    if (!selectedCatalogItem?.manufacturer_id) return '—';
    const mfg = manufacturers.find((m) => m.id === selectedCatalogItem.manufacturer_id);
    return mfg?.name || '—';
  }, [selectedCatalogItem?.manufacturer_id, manufacturers]);

  // Extract fabric specs (columnas directas con fallback a metadata)
  const fabricSpecs = useMemo(() => {
    if (!selectedCatalogItem) return null;

    const metadata = selectedCatalogItem.metadata || {};
    
    // Openness: columna directa o metadata
    const openness = selectedCatalogItem.openness || metadata?.openness || metadata?.apertura || null;
    
    // Weight GSM: columna directa o metadata
    const weightGsm = selectedCatalogItem.weight_gsm || metadata?.weight_gsm || metadata?.gramaje || null;
    
    // Composition: columna directa o metadata
    const composition = selectedCatalogItem.composition || metadata?.composition || null;
    
    // Stock status
    const stockStatus = selectedCatalogItem.stock_status || null;

    return {
      manufacturer: selectedManufacturerName,
      rollWidth: selectedCatalogItem.roll_width_m ? `${selectedCatalogItem.roll_width_m}m` : '—',
      openness: openness || '—',
      weightGsm: weightGsm ? `${weightGsm} g/m²` : '—',
      canRotate: selectedCatalogItem.can_rotate ? 'Yes' : 'No',
      canHeatseal: selectedCatalogItem.can_heatseal ? 'Yes' : 'No',
      composition: composition || '—',
      stockStatus: stockStatus === 'stock' ? 'In Stock' : 
                   stockStatus === 'por_pedido' ? 'On Order' : 
                   stockStatus === 'descontinuado' ? 'Discontinued' : '—',
    };
  }, [selectedCatalogItem, selectedManufacturerName]);

  const fabricRotation = (config as any).fabric_rotation || false;
  const fabricHeatseal = (config as any).fabric_heatseal || false;
  const canRotate = selectedCatalogItem?.can_rotate || false;
  const canHeatseal = selectedCatalogItem?.can_heatseal || false;
  const heatsealPricePerMeter = selectedCatalogItem?.heatseal_price_per_meter || null;

  // Handlers
  const handleCollectionChange = (name: string) => {
    onUpdate({
      collectionName: name,
      collectionId: `collection-${name
        .toLowerCase()
        .replace(/\s+/g, '-')
        .replace(/[^a-z0-9-]/g, '')}`,
      variantId: undefined,
      fabric_catalog_item_id: undefined,
      variantName: undefined,
    } as any);
  };

  const handleVariantChange = (variantIdValue: string) => {
    const selectedVariantItem = variants.find((item) => item.id === variantIdValue);
    const variantName =
      selectedVariantItem?.variant_name ||
      selectedVariantItem?.item_name ||
      selectedVariantItem?.sku ||
      undefined;

    onUpdate({
      variantId: variantIdValue,
      fabric_catalog_item_id: variantIdValue,
      variantName,
      collectionName,
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

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>

          {/* Collection Dropdown */}
          <div className="mb-4">
            <Label htmlFor="collection" className="text-xs mb-1">
              Collection
            </Label>
            <SelectShadcn value={collectionName} onValueChange={handleCollectionChange}>
              <SelectTrigger>
                <SelectValue
                  placeholder={loadingCollections ? 'Loading...' : 'Select collection'}
                />
              </SelectTrigger>
              <SelectContent>
                {loadingCollections ? (
                  <SelectItem value="loading" disabled>
                    Loading collections...
                  </SelectItem>
                ) : collectionsError ? (
                  <SelectItem value="error" disabled>
                    Error: {String(collectionsError)}
                  </SelectItem>
                ) : collections.length === 0 ? (
                  <SelectItem value="no-collections" disabled>
                    No fabric collections found for this product type
                  </SelectItem>
                ) : (
                  collections.map((name) => (
                    <SelectItem key={name} value={name}>
                      {name}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </SelectShadcn>
          </div>

          {/* Variant Grid */}
          <div className="mb-4">
            <Label className="text-xs mb-1 block">Variants</Label>
            {!collectionName ? (
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">Please select a collection to view variants</p>
              </div>
            ) : loadingVariants ? (
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">Loading variants...</p>
              </div>
            ) : variantsError ? (
              <div className="text-center text-red-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm font-medium">Error loading variants</p>
                <p className="text-xs mt-1">{String(variantsError)}</p>
              </div>
            ) : variants.length === 0 ? (
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">No variants available for this collection</p>
              </div>
            ) : (
              <div className="grid grid-cols-4 gap-6">
                {variants.map((variant) => {
                  // Check if this variant is selected
                  const isSelected = variantId === variant.id;
                  
                  return (
                    <div key={variant.id} className="flex flex-col items-center">
                      <button
                        onClick={() => handleVariantChange(variant.id)}
                        className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                          isSelected
                            ? 'border-2 border-gray-400 bg-gray-600'
                            : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                        }`}
                        style={{ padding: '2px' }}
                      >
                        <div
                          className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100"
                          style={{ width: '95%', height: '95%' }}
                        ></div>
                      </button>
                      <p className="text-xs text-gray-700 mt-2 text-center">
                        {variant.variant_name || variant.item_name || variant.sku || 'Unknown'}
                      </p>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Fabric Spec Details */}
        {variantId && fabricSpecs && (
          <div className="border-t border-gray-200 pt-4">
            <Label className="text-sm font-medium mb-3 block">Fabric Spec Details</Label>
            {loadingSelectedItem ? (
              <div className="text-sm text-gray-500 py-2">Loading...</div>
            ) : (
              <div className="bg-gray-50 rounded-lg p-4">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-600">Manufacturer:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.manufacturer}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Roll Width:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.rollWidth}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Openness:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.openness}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Gramaje (GSM):</span>
                    <span className="ml-2 font-medium">{fabricSpecs.weightGsm}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Can Rotate:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.canRotate}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Can Heat Seal:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.canHeatseal}</span>
                  </div>
                  {fabricSpecs.composition !== '—' && (
                    <div className="col-span-2">
                      <span className="text-gray-600">Composition:</span>
                      <span className="ml-2 font-medium">{fabricSpecs.composition}</span>
                    </div>
                  )}
                  <div>
                    <span className="text-gray-600">Stock Status:</span>
                    <span className="ml-2 font-medium">{fabricSpecs.stockStatus}</span>
                  </div>
                </div>

                {canRotate && (
                  <div className="border-t border-gray-200 pt-4 mt-4">
                    <Label className="text-xs font-medium mb-3 block">
                      Fabric Configuration Options
                    </Label>
                    <div className="mb-3">
                      <button
                        type="button"
                        onClick={() => {
                          const checked = !fabricRotation;
                          onUpdate({
                            fabric_rotation: checked,
                            fabric_heatseal: checked ? fabricHeatseal : false,
                          } as any);
                        }}
                        className={`w-full px-3 py-2 rounded-lg text-xs font-medium transition-all text-left ${
                          fabricRotation
                            ? 'bg-gray-800 text-white hover:bg-gray-700'
                            : 'bg-gray-100 text-gray-700 hover:bg-gray-200 border border-gray-300'
                        }`}
                      >
                        Rotate Fabric (Optimize width/height)
                      </button>
                      <p className="text-xs text-gray-500 mt-1">
                        Rotate the fabric to optimize material usage based on dimensions
                      </p>
                    </div>
                    {canHeatseal && fabricRotation && (
                      <div className="mb-3">
                        <button
                          type="button"
                          onClick={() => onUpdate({ fabric_heatseal: !fabricHeatseal } as any)}
                          className={`w-full px-3 py-2 rounded-lg text-xs font-medium transition-all text-left ${
                            fabricHeatseal
                              ? 'bg-gray-800 text-white hover:bg-gray-700'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200 border border-gray-300'
                          }`}
                        >
                          Apply Heat Seal
                        </button>
                        <p className="text-xs text-gray-500 mt-1">
                          {heatsealPricePerMeter
                            ? `Heat seal price: $${heatsealPricePerMeter.toFixed(2)} per meter`
                            : 'Heat seal price will be determined by organization settings'}
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
