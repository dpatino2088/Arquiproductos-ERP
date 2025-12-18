import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import Input from '../../../components/ui/Input';
import { useCatalogCollections, useCatalogItems, useManufacturers } from '../../../hooks/useCatalog';

interface VariantsStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

// Collections con sus manufacturers
const COLLECTIONS = [
  { id: 'essential-3000', name: 'Essential_3000', manufacturer: 'coulisse' },
  { id: 'sunset-blackout', name: 'Sunset_Blackout', manufacturer: 'vertilux' },
];

// Variants (Colores) con sus códigos, imágenes y datos de la tela
const VARIANTS = [
  { 
    id: 'chalk-5', 
    collectionId: 'essential-3000',
    name: 'Chalk_5%', 
    code: 'SCR-3005-01-300',
    imageUrl: '/images/variants/chalk-5.jpg',
    manufacturer: 'Coulisse',
    apertura: '5%',
    gramaje: '110 g/m²',
    anchoRollo: '3000 mm',
    puedeRotar: true
  },
  { 
    id: 'ivory-118', 
    collectionId: 'sunset-blackout',
    name: 'Ivory 118.11', 
    code: '0-002-17-02118',
    imageUrl: '/images/variants/ivory-118.jpg',
    manufacturer: 'Vertilux',
    apertura: '3%',
    gramaje: '145 g/m²',
    anchoRollo: '3000 mm',
    puedeRotar: false
  },
  { 
    id: 'white-118', 
    collectionId: 'sunset-blackout',
    name: 'White 118.11', 
    code: '0-002-17-01118',
    imageUrl: '/images/variants/white-118.jpg',
    manufacturer: 'Vertilux',
    apertura: '3%',
    gramaje: '145 g/m²',
    anchoRollo: '3000 mm',
    puedeRotar: true
  },
];

const EMBOSSING_OPTIONS = [
  { value: 'flat', label: 'Flat' },
  { value: 'textured', label: 'Textured' },
  { value: 'pattern', label: 'Pattern' },
];

const G_VALUE_OPTIONS = [
  { value: '5%', label: '5%' },
  { value: '10%', label: '10%' },
  { value: '15%', label: '15%' },
  { value: '20%', label: '20%' },
];

export default function VariantsStep({ config, onUpdate }: VariantsStepProps) {
  // Determinar el tipo de producto
  const productType = (config as any).productType;
  
  // Mapear campos según el tipo de producto
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
  
  // Cargar datos del Catalog
  const { collections: catalogCollections, loading: loadingCollections, error: collectionsError } = useCatalogCollections();
  const { items: catalogItems, loading: loadingItems, error: itemsError } = useCatalogItems();
  const currentCollectionId = getCollectionId();
  
  // Get current collection name to filter CatalogItems
  const currentCollection = catalogCollections.find(c => c.id === currentCollectionId);
  const currentCollectionName = currentCollection?.name || (currentCollection as any)?.collection_name;
  
  // Filter CatalogItems by collection_name and is_fabric=true to get variants
  // Use the same logic as Collections.tsx
  const allFabricItems = catalogItems.filter((item: any) => {
    // Match items that:
    // 1. Are fabrics (is_fabric = true)
    // 2. Have a collection_name (not null/empty after trim)
    // 3. Have a variant_name (not null/empty after trim)
    // 4. Have a sku (not null/empty after trim)
    // 5. Are not deleted
    
    const isFabric = item.is_fabric === true;
    const collectionNameStr = item.collection_name ? String(item.collection_name).trim() : '';
    const hasCollection = collectionNameStr.length > 0;
    const variantNameStr = item.variant_name ? String(item.variant_name).trim() : '';
    const hasVariant = variantNameStr.length > 0;
    const skuStr = item.sku ? String(item.sku).trim() : '';
    const hasSku = skuStr.length > 0;
    const notDeleted = !item.deleted;
    
    return isFabric && hasCollection && hasVariant && hasSku && notDeleted;
  });
  
  const { manufacturers: catalogManufacturers, loading: loadingManufacturers } = useManufacturers();
  
  // Log errors for debugging
  if (collectionsError && import.meta.env.DEV) {
    console.error('VariantsStep - Collections error:', collectionsError);
  }
  if (itemsError && import.meta.env.DEV) {
    console.error('VariantsStep - CatalogItems error:', itemsError);
  }

  // Debug: Log collection_name and variant_name data
  if (import.meta.env.DEV) {
    console.log('VariantsStep - Debug Info:');
    console.log('  - catalogCollections count:', catalogCollections.length);
    console.log('  - catalogItems count:', catalogItems.length);
    console.log('  - allFabricItems count:', allFabricItems.length);
    if (catalogItems.length > 0) {
      const sampleItem = catalogItems[0];
      console.log('  - Sample item:', {
        id: sampleItem.id,
        sku: sampleItem.sku,
        collection_name: (sampleItem as any).collection_name,
        variant_name: (sampleItem as any).variant_name,
        is_fabric: (sampleItem as any).is_fabric,
      });
    }
    if (allFabricItems.length > 0) {
      const sampleFabric = allFabricItems[0];
      console.log('  - Sample fabric item:', {
        id: sampleFabric.id,
        sku: sampleFabric.sku,
        collection_name: (sampleFabric as any).collection_name,
        variant_name: (sampleFabric as any).variant_name,
      });
    }
  }
  
  // Mapear manufacturers del Catalog a formato esperado
  const manufacturers = catalogManufacturers.map(m => ({
    id: m.name.toLowerCase().replace(/\s+/g, '-'),
    name: m.name,
    code: m.code || m.name.substring(0, 3).toUpperCase(),
  }));
  
  // Mapear collections del Catalog a formato esperado
  // Ahora las collections incluyen manufacturer_id directamente desde CatalogItems
  const collections = catalogCollections.map(c => {
    // Obtener manufacturer_id directamente de la collection (ahora está disponible)
    let manufacturerId: string | undefined;
    if (c.manufacturer_id) {
      // Buscar el manufacturer por ID en la lista de manufacturers
      const mfg = catalogManufacturers.find(m => m.id === c.manufacturer_id);
      if (mfg) {
        // Convertir el nombre del manufacturer a formato ID (lowercase, replace spaces with hyphens)
        manufacturerId = mfg.name.toLowerCase().replace(/\s+/g, '-');
      }
    }
    
    // Fallback: intentar inferir manufacturer desde el nombre de la collection (solo si no hay manufacturer_id)
    if (!manufacturerId) {
      const collectionName = c.name.toLowerCase();
      if (collectionName.includes('essential') || collectionName.includes('ess')) {
        manufacturerId = manufacturers.find(m => m.name.toLowerCase() === 'coulisse')?.id;
      } else if (collectionName.includes('sunset')) {
        manufacturerId = manufacturers.find(m => m.name.toLowerCase() === 'vertilux')?.id;
      } else if (collectionName.includes('solar')) {
        manufacturerId = manufacturers.find(m => m.name.toLowerCase() === 'coulisse')?.id;
      }
    }
    
    return {
      id: c.id,
      name: c.name,
      code: c.code || c.name,
      manufacturer: manufacturerId,
    };
  });
  
  // Mapear variants desde CatalogItems a formato esperado
  // Filter by current collection if selected - use same logic as Collections.tsx
  const filteredItemsForVariants = currentCollectionName 
    ? allFabricItems.filter((item: any) => {
        // Convert both to strings and compare (collection_name is now text, not UUID)
        const itemCollectionName = item.collection_name ? String(item.collection_name).trim() : null;
        const targetCollectionName = String(currentCollectionName).trim();
        return itemCollectionName === targetCollectionName;
      })
    : allFabricItems;
  
  const variants = filteredItemsForVariants.map((item: any) => {
      // Find related collection by collection_name - use same logic as Collections.tsx
      const itemCollectionName = item.collection_name ? String(item.collection_name).trim() : '';
      const relatedCollection = collections.find(c => {
        const collectionName = c.name ? String(c.name).trim() : '';
        return collectionName === itemCollectionName;
      });
      
      // Get manufacturer from item or collection
      let manufacturer: string | undefined;
      if (item.manufacturer_id) {
        const mfg = catalogManufacturers.find(m => m.id === item.manufacturer_id);
        manufacturer = mfg?.name;
      } else if (relatedCollection) {
        const mfg = manufacturers.find(m => m.id === relatedCollection.manufacturer);
        manufacturer = mfg?.name;
      }
      
      // Extract technical data from item
      const variantName = (item.variant_name || '').toLowerCase();
      let defaultApertura: string | undefined;
      let defaultGramaje: string | undefined;
      let defaultAnchoRollo = item.roll_width_m ? `${item.roll_width_m}m` : '3000 mm';
      
      // Infer apertura from variant name (e.g., "Chalk 5%" -> "5%")
      const aperturaMatch = item.variant_name?.match(/(\d+)%/);
      if (aperturaMatch) {
        defaultApertura = `${aperturaMatch[1]}%`;
      }
      
      // Use default gramaje values based on variant name
      if (variantName.includes('chalk') || variantName.includes('ivory') || variantName.includes('white')) {
        defaultGramaje = variantName.includes('sunset') ? '145 g/m²' : '110 g/m²';
      }
      
      // Use collection id from relatedCollection, or fallback to collection_name
      // The collection.id should match what's used in the dropdown
      const collectionId = relatedCollection?.id || itemCollectionName;
      
      return {
        id: item.id, // Use catalog_item_id as variant id
        collectionId: collectionId, // Use collection.id for matching with dropdown selection
        name: item.variant_name || item.sku, // Use variant_name
        code: item.sku,
        color_name: item.variant_name, // variant_name replaces color_name
        // Additional data
        manufacturer: manufacturer || 'N/A',
        apertura: defaultApertura || 'N/A',
        gramaje: defaultGramaje || 'N/A',
        anchoRollo: defaultAnchoRollo || 'N/A',
        puedeRotar: true, // Default true
        imageUrl: undefined, // Can be added later if needed
      };
    });
  
  // Fallback a datos hardcodeados si no hay datos del Catalog
  const useHardcodedData = catalogCollections.length === 0 && !loadingCollections && catalogItems.length === 0 && !loadingItems;
  const finalCollections = useHardcodedData ? COLLECTIONS : collections;
  const finalVariants = useHardcodedData ? VARIANTS : variants;
  const finalManufacturers = useHardcodedData ? [
    { id: 'coulisse', name: 'Coulisse', code: 'COU' },
    { id: 'vertilux', name: 'Vertilux', code: 'VER' },
  ] : manufacturers;
  
  const handleCollectionChange = (collectionId: string) => {
    // Get collection name from the selected collection
    const selectedCollection = catalogCollections.find(c => c.id === collectionId);
    const collectionName = selectedCollection?.name || (selectedCollection as any)?.collection_name || collectionId;
    
    if (productType === 'roller-shade') {
      onUpdate({ 
        collectionId: collectionId, // Keep for backward compatibility
        collectionName: collectionName, // New: use collection_name
        variantId: undefined,
        variantName: undefined 
      });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          collectionId: collectionId, // Keep for backward compatibility
          collectionName: collectionName, // New: use collection_name
          variantId: undefined,
          variantName: undefined 
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          collectionId: collectionId, // Keep for backward compatibility
          collectionName: collectionName, // New: use collection_name
          variantId: undefined,
          variantName: undefined 
        } 
      });
    } else {
      // Fallback para CurtainConfiguration antiguo
      onUpdate({ filmType: collectionId, ralColor: undefined });
    }
  };
  
  const handleVariantChange = (variantId: string | undefined) => {
    // Get variant name from the selected variant
    const selectedVariantItem = allFabricItems.find((item: any) => item.id === variantId);
    const variantName = selectedVariantItem?.variant_name || undefined;
    
    if (productType === 'roller-shade') {
      onUpdate({ 
        variantId: variantId, // Keep for backward compatibility (catalog_item_id)
        variantName: variantName // New: use variant_name
      });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          variantId: variantId, // Keep for backward compatibility
          variantName: variantName // New: use variant_name
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          variantId: variantId, // Keep for backward compatibility
          variantName: variantName // New: use variant_name
        } 
      });
    } else {
      // Fallback para CurtainConfiguration antiguo
      onUpdate({ ralColor: variantId });
    }
  };
  
  const handleManufacturerChange = (manufacturer: 'coulisse' | 'vertilux') => {
    const updates: any = { variantManufacturer: manufacturer };
    
    // Clear collection and variant when manufacturer changes
    if (productType === 'roller-shade') {
      updates.collectionId = undefined;
      updates.variantId = undefined;
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      updates.frontFabric = {
        manufacturer: manufacturer,
        collectionId: undefined,
        variantId: undefined
      };
    } else if (productType === 'drapery' || productType === 'awning') {
      updates.fabric = {
        manufacturer: manufacturer,
        collectionId: undefined,
        variantId: undefined
      };
    } else {
      // Fallback para CurtainConfiguration antiguo
      updates.filmType = undefined;
      updates.ralColor = undefined;
    }
    
    onUpdate(updates);
  };
  
  const currentVariantId = getVariantId();
  
  // Obtener el variant seleccionado para mostrar sus datos
  const selectedVariant = finalVariants.find(v => v.id === currentVariantId);
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Collection | Variants */}
        <div>
          <Label className="text-sm font-medium mb-4 block">COLLECTION | VARIANTS</Label>
          
          {/* Field para seleccionar Manufacturer */}
          <div className="mb-4">
            <Label htmlFor="manufacturer" className="text-xs mb-1">Manufacturer</Label>
            <SelectShadcn
              value={(config as any).variantManufacturer || 
                     (productType === 'dual-shade' || productType === 'triple-shade' 
                       ? (config as any).frontFabric?.manufacturer 
                       : (productType === 'drapery' || productType === 'awning' 
                         ? (config as any).fabric?.manufacturer 
                         : undefined)) || ''}
              onValueChange={handleManufacturerChange}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select manufacturer" />
              </SelectTrigger>
              <SelectContent>
                {finalManufacturers.map((mfg) => (
                  <SelectItem key={mfg.id} value={mfg.id}>
                    {mfg.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Field para seleccionar Collection */}
          <div className="mb-4">
            <Label htmlFor="collection" className="text-xs mb-1">Collection</Label>
            <SelectShadcn
              value={currentCollectionId || ''}
              onValueChange={handleCollectionChange}
              disabled={!((config as any).variantManufacturer || 
                (productType === 'dual-shade' || productType === 'triple-shade' 
                  ? (config as any).frontFabric?.manufacturer 
                  : (productType === 'drapery' || productType === 'awning' 
                    ? (config as any).fabric?.manufacturer 
                    : undefined)))}
            >
              <SelectTrigger>
                <SelectValue placeholder={loadingCollections ? "Loading collections..." : "Select collection"} />
              </SelectTrigger>
              <SelectContent>
                {loadingCollections ? (
                  <SelectItem value="loading" disabled>Loading collections...</SelectItem>
                ) : finalCollections.length === 0 ? (
                  <SelectItem value="no-collections" disabled>No collections available</SelectItem>
                ) : (
                  (() => {
                    // Filtrar por manufacturer si está seleccionado
                    const selectedManufacturer = (config as any).variantManufacturer || 
                      (productType === 'dual-shade' || productType === 'triple-shade' 
                        ? (config as any).frontFabric?.manufacturer 
                        : (productType === 'drapery' || productType === 'awning' 
                          ? (config as any).fabric?.manufacturer 
                          : undefined));
                    
                    const filteredCollections = selectedManufacturer 
                      ? finalCollections.filter(collection => collection.manufacturer === selectedManufacturer)
                      : finalCollections;
                    
                    if (filteredCollections.length === 0 && selectedManufacturer) {
                      return <SelectItem value="no-match" disabled>No collections for selected manufacturer</SelectItem>;
                    }
                    
                    return filteredCollections.map((collection) => (
                      <SelectItem key={collection.id} value={collection.id}>
                        {collection.name}
                      </SelectItem>
                    ));
                  })()
                )}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Field para seleccionar Variants (Colores) */}
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
                ) : finalVariants.length === 0 ? (
                  <div className="col-span-4 text-center text-gray-500 py-4">
                    No variants available for this collection
                  </div>
                ) : (
                  finalVariants
                    .map((variant) => {
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
                        {/* Checkbox en esquina superior derecha */}
                        <div className="absolute top-2 right-2">
                          {isSelected ? (
                            <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                              <span className="text-white text-xs font-bold">✓</span>
                            </div>
                          ) : (
                            <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                          )}
                        </div>
                        
                        {/* Imagen - 5% más chica que el card (95% del tamaño) respetando padding de 2px */}
                        <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                          {variant.imageUrl ? (
                            <img
                              src={variant.imageUrl}
                              alt={variant.name}
                              className="w-full h-full object-cover"
                              onError={(e) => {
                                const target = e.target as HTMLImageElement;
                                target.style.display = 'none';
                              }}
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center bg-gray-200">
                              <span className="text-xs text-gray-500">{variant.name}</span>
                            </div>
                          )}
                        </div>
                      </button>
                      
                      {/* SKU/Código abajo del card */}
                      <span className={`text-xs block mt-2 font-mono ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-600'}`}>
                        {variant.code}
                      </span>
                    </div>
                  );
                  })
                )}
              </div>
            )}
          </div>
        </div>

        {/* Datos de la Tela - Se muestran automáticamente cuando se selecciona Collection y Variant */}
        {selectedVariant && (
          <div>
            <Label className="text-sm font-medium mb-4 block">FABRIC DATA</Label>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="manufacturer" className="text-xs mb-1">Manufacturer</Label>
                <Input
                  id="manufacturer"
                  value={selectedVariant.manufacturer}
                  readOnly
                  className="bg-gray-50"
                />
              </div>

              <div>
                <Label htmlFor="apertura" className="text-xs mb-1">Fabric Opening</Label>
                <Input
                  id="apertura"
                  value={selectedVariant.apertura}
                  readOnly
                  className="bg-gray-50"
                />
              </div>

              <div>
                <Label htmlFor="gramaje" className="text-xs mb-1">Fabric Weight</Label>
                <Input
                  id="gramaje"
                  value={selectedVariant.gramaje}
                  readOnly
                  className="bg-gray-50"
                />
              </div>

              <div>
                <Label htmlFor="anchoRollo" className="text-xs mb-1">Roll Width</Label>
                <Input
                  id="anchoRollo"
                  value={selectedVariant.anchoRollo}
                  readOnly
                  className="bg-gray-50"
                />
              </div>

              <div>
                <Label htmlFor="puedeRotar" className="text-xs mb-1">Can Rotate</Label>
                <Input
                  id="puedeRotar"
                  value={selectedVariant.puedeRotar ? 'Yes' : 'No'}
                  readOnly
                  className="bg-gray-50"
                />
              </div>
            </div>
          </div>
        )}

        {/* Card para rotar la tela - Solo se muestra si puedeRotar es true */}
        {selectedVariant && selectedVariant.puedeRotar && (() => {
          const viewToOutside = (config as any).viewToOutside;
          return (
            <div>
              <Label className="text-sm font-medium mb-4 block">ROTATE FABRIC</Label>
              <div className="grid grid-cols-4 gap-6">
                <div className="flex flex-col items-center">
                  <button
                    onClick={() => onUpdate({ viewToOutside: viewToOutside ? undefined : true } as any)}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      viewToOutside
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    {/* Checkbox en esquina superior derecha */}
                    <div className="absolute top-2 right-2">
                      {viewToOutside ? (
                        <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                          <span className="text-white text-xs font-bold">✓</span>
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                      )}
                    </div>
                    
                    {/* Imagen - 5% más chica que el card (95% del tamaño) */}
                    <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                      <div className="w-full h-full flex items-center justify-center">
                        <span className="text-xs text-gray-500">Yes</span>
                      </div>
                    </div>
                  </button>
                  
                  {/* Texto abajo del card */}
                  <span className={`text-sm font-semibold block mt-2 ${viewToOutside ? 'text-gray-900' : 'text-gray-900'}`}>
                    Yes
                  </span>
                </div>

                <div className="flex flex-col items-center">
                  <button
                    onClick={() => onUpdate({ viewToOutside: viewToOutside === false ? undefined : false } as any)}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      viewToOutside === false
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    {/* Checkbox en esquina superior derecha */}
                    <div className="absolute top-2 right-2">
                      {viewToOutside === false ? (
                        <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                          <span className="text-white text-xs font-bold">✓</span>
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                      )}
                    </div>
                    
                    {/* Imagen - 5% más chica que el card (95% del tamaño) */}
                    <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                      <div className="w-full h-full flex items-center justify-center">
                        <span className="text-xs text-gray-500">No</span>
                      </div>
                    </div>
                  </button>
                  
                  {/* Texto abajo del card */}
                  <span className={`text-sm font-semibold block mt-2 ${viewToOutside === false ? 'text-gray-900' : 'text-gray-900'}`}>
                    No
                  </span>
                </div>
              </div>
            </div>
          );
        })()}
      </div>
    </div>
  );
}

