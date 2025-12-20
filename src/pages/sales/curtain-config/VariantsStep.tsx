import { useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import { useCatalogCollections, useCatalogItems, useManufacturers } from '../../../hooks/useCatalog';

interface VariantsStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

export default function VariantsStep({ config, onUpdate }: VariantsStepProps) {
  const productType = (config as any).productType;
  
  // Get productTypeId from config (set by ProductStep)
  const productTypeId = (config as any).productTypeId;
  
  // Map productType to family for fallback (if productTypeId is not available)
  const family = useMemo(() => {
    const FAMILY_MAP: Record<string, string> = {
      'roller-shade': 'Roller Shade',
      'dual-shade': 'Dual Shade',
      'triple-shade': 'Triple Shade',
      'drapery': 'Drapery',
      'awning': 'Awning',
      'window-film': 'Window Film',
    };
    return productType ? FAMILY_MAP[productType] : undefined;
  }, [productType]);
  
  // Load catalog data - filtered by productTypeId (preferred) or family (fallback)
  const { collections: catalogCollections, loading: loadingCollections, error: collectionsError } = 
    useCatalogCollections(family, productTypeId);
  const { items: catalogItems, loading: loadingItems, error: itemsError } = 
    useCatalogItems(family, productTypeId);
  const { manufacturers: catalogManufacturers, loading: loadingManufacturers } = useManufacturers();
  
  // Get current collection and variant IDs from config
  const getCollectionId = () => {
    if (productType === 'roller-shade') {
      return (config as any).collectionId || (config as any).filmType;
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      return (config as any).frontFabric?.collectionId || (config as any).filmType;
    } else if (productType === 'drapery' || productType === 'awning') {
      return (config as any).fabric?.collectionId || (config as any).filmType;
    }
    return (config as any).filmType;
  };
  
  const getVariantId = () => {
    if (productType === 'roller-shade') {
      return (config as any).variantId || (config as any).ralColor;
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      return (config as any).frontFabric?.variantId || (config as any).ralColor;
    } else if (productType === 'drapery' || productType === 'awning') {
      return (config as any).fabric?.variantId || (config as any).ralColor;
    }
    return (config as any).ralColor;
  };
  
  const currentCollectionId = getCollectionId();
  const currentVariantId = getVariantId();
  
  // Filter fabric items from catalogItems
  const allFabricItems = useMemo(() => {
    return catalogItems.filter((item: any) => {
      const isFabric = item.is_fabric === true;
      const hasCollection = item.collection_name ? String(item.collection_name).trim().length > 0 : false;
      const hasVariant = item.variant_name ? String(item.variant_name).trim().length > 0 : false;
      const hasSku = item.sku ? String(item.sku).trim().length > 0 : false;
      const notDeleted = !item.deleted;
      
      return (isFabric || (hasCollection && hasVariant)) && hasCollection && hasVariant && hasSku && notDeleted;
    });
  }, [catalogItems]);
  
  // Filter manufacturers: only those with fabric items for this productType
  const manufacturersWithFabric = useMemo(() => {
    if (!catalogItems.length) return [];
    
    const manufacturerIds = new Set<string>();
    
    catalogItems.forEach((item: any) => {
      const hasFabric = item.is_fabric === true;
      const hasCollection = item.collection_name ? String(item.collection_name).trim().length > 0 : false;
      const hasVariant = item.variant_name ? String(item.variant_name).trim().length > 0 : false;
      
      if (hasFabric && hasCollection && hasVariant && item.manufacturer_id) {
        manufacturerIds.add(item.manufacturer_id);
      }
    });
    
    return catalogManufacturers
      .filter(m => manufacturerIds.has(m.id))
      .map(m => ({
        id: m.name.toLowerCase().replace(/\s+/g, '-'),
        name: m.name,
        code: m.code || m.name.substring(0, 3).toUpperCase(),
        manufacturer_id: m.id,
      }));
  }, [catalogItems, catalogManufacturers]);
  
  // Get selected manufacturer
  const selectedManufacturer = (config as any).variantManufacturer || 
    (productType === 'dual-shade' || productType === 'triple-shade' 
      ? (config as any).frontFabric?.manufacturer 
      : (productType === 'drapery' || productType === 'awning' 
        ? (config as any).fabric?.manufacturer 
        : undefined));
  
  const selectedManufacturerId = useMemo(() => {
    if (!selectedManufacturer) return undefined;
    const mfg = manufacturersWithFabric.find(m => m.id === selectedManufacturer);
    return mfg?.manufacturer_id;
  }, [selectedManufacturer, manufacturersWithFabric]);
  
  // Build collections from catalogItems (already filtered by productTypeId)
  const collections = useMemo(() => {
    const collectionMap = new Map<string, {
      name: string;
      manufacturer_id?: string;
    }>();
    
    catalogItems.forEach((item: any) => {
      const hasFabric = item.is_fabric === true;
      const hasCollection = item.collection_name ? String(item.collection_name).trim().length > 0 : false;
      const hasVariant = item.variant_name ? String(item.variant_name).trim().length > 0 : false;
      
      if (hasFabric && hasCollection && hasVariant) {
        const collectionName = String(item.collection_name).trim();
        const manufacturerId = item.manufacturer_id;
        
        if (!collectionMap.has(collectionName)) {
          collectionMap.set(collectionName, {
            name: collectionName,
            manufacturer_id: manufacturerId,
          });
        }
      }
    });
    
    return Array.from(collectionMap.entries())
      .map(([collectionName, data]) => {
        const matchedCollection = catalogCollections.find(c => 
          c.name === collectionName || c.name?.trim() === collectionName
        );
        
        let manufacturerId: string | undefined;
        if (data.manufacturer_id) {
          const mfg = manufacturersWithFabric.find(m => m.manufacturer_id === data.manufacturer_id);
          manufacturerId = mfg?.id;
        }
        
        return {
          id: matchedCollection?.id || `collection-${collectionName.toLowerCase().replace(/\s+/g, '-')}`,
          name: collectionName,
          code: matchedCollection?.code || collectionName.substring(0, 3).toUpperCase(),
          manufacturer: manufacturerId,
          manufacturer_id: data.manufacturer_id,
        };
      })
      .filter(c => {
        // Filter by selected manufacturer if one is selected
        if (selectedManufacturerId) {
          return c.manufacturer_id === selectedManufacturerId;
        }
        return true;
      });
  }, [catalogItems, catalogCollections, manufacturersWithFabric, selectedManufacturerId]);
  
  // Get current collection name
  const currentCollection = collections.find(c => c.id === currentCollectionId) || 
                            catalogCollections.find(c => c.id === currentCollectionId);
  const currentCollectionName = currentCollection?.name;
  
  // Filter variants by selected collection
  const filteredItemsForVariants = currentCollectionName 
    ? allFabricItems.filter((item: any) => {
        const itemCollectionName = item.collection_name ? String(item.collection_name).trim() : null;
        const targetCollectionName = String(currentCollectionName).trim();
        return itemCollectionName === targetCollectionName;
      })
    : allFabricItems;
  
  // Build variants from filtered items
  const variants = useMemo(() => {
    return filteredItemsForVariants.map((item: any) => {
      const itemCollectionName = item.collection_name ? String(item.collection_name).trim() : '';
      const relatedCollection = collections.find(c => {
        const collectionName = c.name ? String(c.name).trim() : '';
        return collectionName === itemCollectionName;
      });
      
      let manufacturer: string | undefined;
      if (item.manufacturer_id) {
        const mfg = catalogManufacturers.find(m => m.id === item.manufacturer_id);
        manufacturer = mfg?.name;
      } else if (relatedCollection) {
        const mfg = manufacturersWithFabric.find(m => m.id === relatedCollection.manufacturer);
        manufacturer = mfg?.name;
      }
      
      const variantName = (item.variant_name || '').toLowerCase();
      let defaultApertura: string | undefined;
      let defaultGramaje: string | undefined;
      let defaultAnchoRollo = item.roll_width_m ? `${item.roll_width_m}m` : '3000 mm';
      
      const aperturaMatch = item.variant_name?.match(/(\d+)%/);
      if (aperturaMatch) {
        defaultApertura = `${aperturaMatch[1]}%`;
      }
      
      if (variantName.includes('chalk') || variantName.includes('ivory') || variantName.includes('white')) {
        defaultGramaje = variantName.includes('sunset') ? '145 g/m²' : '110 g/m²';
      }
      
      const collectionId = relatedCollection?.id || itemCollectionName;
      
      return {
        id: item.id,
        collectionId: collectionId,
        name: item.variant_name || item.sku,
        code: item.sku,
        color_name: item.variant_name,
        manufacturer: manufacturer || 'N/A',
        apertura: defaultApertura || 'N/A',
        gramaje: defaultGramaje || 'N/A',
        anchoRollo: defaultAnchoRollo || 'N/A',
        puedeRotar: true,
        imageUrl: undefined,
      };
    });
  }, [filteredItemsForVariants, collections, catalogManufacturers, manufacturersWithFabric]);
  
  // Handlers
  const handleManufacturerChange = (manufacturerId: string) => {
    if (productType === 'roller-shade') {
      onUpdate({ variantManufacturer: manufacturerId });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: manufacturerId,
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: manufacturerId,
        } 
      });
    }
  };
  
  const handleCollectionChange = (collectionId: string) => {
    const selectedCollection = collections.find(c => c.id === collectionId) ||
                              catalogCollections.find(c => c.id === collectionId);
    const collectionName = selectedCollection?.name || collectionId;
    
    if (productType === 'roller-shade') {
      onUpdate({ 
        collectionId: collectionId,
        collectionName: collectionName,
        variantId: undefined,
        variantName: undefined 
      });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: selectedManufacturer || currentFabric.manufacturer,
          collectionId: collectionId,
          collectionName: collectionName,
          variantId: undefined,
          variantName: undefined 
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: selectedManufacturer || currentFabric.manufacturer,
          collectionId: collectionId,
          collectionName: collectionName,
          variantId: undefined,
          variantName: undefined 
        } 
      });
    } else {
      onUpdate({ filmType: collectionId, ralColor: undefined });
    }
  };
  
  const handleVariantChange = (variantId: string | undefined) => {
    const selectedVariantItem = allFabricItems.find((item: any) => item.id === variantId);
    const variantName = selectedVariantItem?.variant_name || undefined;
    
    if (productType === 'roller-shade') {
      onUpdate({ 
        variantId: variantId,
        variantName: variantName
      });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: selectedManufacturer || currentFabric.manufacturer,
          variantId: variantId,
          variantName: variantName
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: selectedManufacturer || currentFabric.manufacturer,
          variantId: variantId,
          variantName: variantName
        } 
      });
    } else {
      onUpdate({ ralColor: variantId });
    }
  };
  
  // Get selected variant for display
  const selectedVariant = variants.find(v => v.id === currentVariantId);
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Collection | Variants */}
        <div>
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>
          
          {/* Manufacturer Dropdown */}
          <div className="mb-4">
            <Label htmlFor="manufacturer" className="text-xs mb-1">Manufacturer</Label>
            <SelectShadcn
              value={selectedManufacturer || ''}
              onValueChange={handleManufacturerChange}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select manufacturer" />
              </SelectTrigger>
              <SelectContent>
                {loadingManufacturers ? (
                  <SelectItem value="loading" disabled>Loading manufacturers...</SelectItem>
                ) : manufacturersWithFabric.length === 0 ? (
                  <SelectItem value="no-manufacturers" disabled>No manufacturers available</SelectItem>
                ) : (
                  manufacturersWithFabric.map((mfg) => (
                    <SelectItem key={mfg.id} value={mfg.id}>
                      {mfg.name}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Collection Dropdown */}
          <div className="mb-4">
            <Label htmlFor="collection" className="text-xs mb-1">Collection</Label>
            <SelectShadcn
              value={currentCollectionId || ''}
              onValueChange={handleCollectionChange}
              disabled={!selectedManufacturer}
            >
              <SelectTrigger>
                <SelectValue placeholder={loadingCollections ? "Loading collections..." : "Select collection"} />
              </SelectTrigger>
              <SelectContent>
                {loadingCollections ? (
                  <SelectItem value="loading" disabled>Loading collections...</SelectItem>
                ) : collectionsError ? (
                  <SelectItem value="error" disabled>Error loading collections</SelectItem>
                ) : collections.length === 0 ? (
                  <SelectItem value="no-collections" disabled>
                    {itemsError || collectionsError 
                      ? "Error loading data" 
                      : "No collections available for this product type and manufacturer"}
                  </SelectItem>
                ) : (
                  collections.map((collection) => (
                    <SelectItem key={collection.id} value={collection.id}>
                      {collection.name}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Variants Grid */}
          <div className="mb-4">
            <Label className="text-xs mb-1 block">Variants</Label>
            {!currentCollectionId ? (
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">Please select a collection to view variants</p>
              </div>
            ) : (
              <div className="grid grid-cols-4 gap-6">
                {loadingItems ? (
                  <div className="col-span-4 text-center text-gray-500 py-4">Loading variants...</div>
                ) : itemsError ? (
                  <div className="col-span-4 text-center text-red-500 py-4">
                    <p className="text-sm font-medium">Error loading variants</p>
                    <p className="text-xs mt-1">{String(itemsError)}</p>
                  </div>
                ) : variants.length === 0 ? (
                  <div className="col-span-4 text-center text-gray-500 py-4">
                    <p className="text-sm">No variants available for this collection</p>
                  </div>
                ) : (
                  variants.map((variant) => {
                    const isSelected = currentVariantId === variant.id;
                    return (
                      <div key={variant.id} className="flex flex-col items-center">
                        <button
                          onClick={() => handleVariantChange(isSelected ? undefined : variant.id)}
                          className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                            isSelected
                              ? 'border-2 border-gray-400 bg-gray-600'
                              : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                          }`}
                          style={{ padding: '2px' }}
                        >
                          <div className="absolute top-2 right-2">
                            {isSelected ? (
                              <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                                <span className="text-white text-xs font-bold">✓</span>
                              </div>
                            ) : (
                              <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                            )}
                          </div>
                          {variant.imageUrl ? (
                            <img 
                              src={variant.imageUrl} 
                              alt={variant.name}
                              className="w-full h-full object-cover rounded-lg"
                            />
                          ) : (
                            <div className="w-full h-full bg-gray-200 rounded-lg flex items-center justify-center">
                              <span className="text-xs text-gray-500">{variant.code}</span>
                            </div>
                          )}
                        </button>
                        <p className="text-xs text-gray-700 mt-2 text-center">{variant.name}</p>
                      </div>
                    );
                  })
                )}
              </div>
            )}
          </div>
        </div>
        
        {/* Selected Variant Details */}
        {selectedVariant && (
          <div className="border-t border-gray-200 pt-4">
            <Label className="text-sm font-medium mb-2 block">Selected Variant Details</Label>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-gray-600">Manufacturer:</span>
                <span className="ml-2 font-medium">{selectedVariant.manufacturer}</span>
              </div>
              <div>
                <span className="text-gray-600">Apertura:</span>
                <span className="ml-2 font-medium">{selectedVariant.apertura}</span>
              </div>
              <div>
                <span className="text-gray-600">Gramaje:</span>
                <span className="ml-2 font-medium">{selectedVariant.gramaje}</span>
              </div>
              <div>
                <span className="text-gray-600">Ancho Rollo:</span>
                <span className="ml-2 font-medium">{selectedVariant.anchoRollo}</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
