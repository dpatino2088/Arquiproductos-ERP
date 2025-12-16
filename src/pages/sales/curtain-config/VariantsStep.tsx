import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import Input from '../../../components/ui/Input';
import { useCatalogCollections, useCatalogVariants, useManufacturers } from '../../../hooks/useCatalog';

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
  const currentCollectionId = getCollectionId();
  const { variants: catalogVariants, loading: loadingVariants, error: variantsError } = useCatalogVariants(currentCollectionId || undefined);
  const { manufacturers: catalogManufacturers, loading: loadingManufacturers } = useManufacturers();
  
  // Log errors for debugging
  if (collectionsError && import.meta.env.DEV) {
    console.error('VariantsStep - Collections error:', collectionsError);
  }
  if (variantsError && import.meta.env.DEV) {
    console.error('VariantsStep - Variants error:', variantsError);
  }
  
  // Mapear manufacturers del Catalog a formato esperado
  const manufacturers = catalogManufacturers.map(m => ({
    id: m.name.toLowerCase().replace(/\s+/g, '-'),
    name: m.name,
    code: m.code || m.name.substring(0, 3).toUpperCase(),
  }));
  
  // Mapear collections del Catalog a formato esperado
  // Nota: CatalogCollections no tiene manufacturer_id directo, 
  // pero podemos usar metadata o relacionar por nombre
  const collections = catalogCollections.map(c => {
    // Intentar obtener manufacturer desde metadata o por nombre de collection
    const collectionMetadata = (c as any).metadata || {};
    const manufacturerFromMetadata = collectionMetadata.manufacturer;
    
    // Mapear manufacturer por nombre si está en metadata
    let manufacturerId: string | undefined;
    if (manufacturerFromMetadata) {
      const mfg = manufacturers.find(m => 
        m.name.toLowerCase() === manufacturerFromMetadata.toLowerCase() ||
        m.name.toLowerCase().includes(manufacturerFromMetadata.toLowerCase()) ||
        manufacturerFromMetadata.toLowerCase().includes(m.name.toLowerCase())
      );
      manufacturerId = mfg?.id;
    }
    
    // Fallback: intentar inferir manufacturer desde el nombre de la collection
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
  
  // Mapear variants del Catalog a formato esperado
  const variants = catalogVariants.map(v => {
    const variantMetadata = (v as any).metadata || {};
    
    // Obtener manufacturer desde el variant o desde la collection relacionada
    let manufacturer: string | undefined;
    if (variantMetadata.manufacturer) {
      manufacturer = variantMetadata.manufacturer;
    } else {
      // Buscar la collection relacionada para obtener su manufacturer
      const relatedCollection = collections.find(c => c.id === v.collection_id);
      if (relatedCollection && relatedCollection.manufacturer) {
        // Obtener el nombre del manufacturer desde el ID
        const mfg = manufacturers.find(m => m.id === relatedCollection.manufacturer);
        manufacturer = mfg?.name;
      }
    }
    
    // Valores por defecto basados en el nombre del variant si no hay metadata
    const variantName = v.name.toLowerCase();
    let defaultApertura: string | undefined;
    let defaultGramaje: string | undefined;
    let defaultAnchoRollo = '3000 mm'; // Valor por defecto común
    
    // Inferir apertura desde el nombre (ej: "Chalk 5%" -> "5%")
    const aperturaMatch = v.name.match(/(\d+)%/);
    if (aperturaMatch) {
      defaultApertura = `${aperturaMatch[1]}%`;
    }
    
    // Inferir gramaje desde el nombre o usar valores por defecto
    if (variantName.includes('chalk') || variantName.includes('ivory') || variantName.includes('white')) {
      defaultGramaje = variantName.includes('sunset') ? '145 g/m²' : '110 g/m²';
    }
    
    return {
      id: v.id,
      collectionId: v.collection_id,
      name: v.name,
      code: v.code || v.name,
      color_name: v.color_name || v.name,
      // Datos adicionales desde metadata si están disponibles, sino usar valores por defecto
      manufacturer: manufacturer || 'N/A',
      apertura: variantMetadata.apertura || variantMetadata.fabricOpening || defaultApertura || 'N/A',
      gramaje: variantMetadata.gramaje || variantMetadata.fabricWeight || defaultGramaje || 'N/A',
      anchoRollo: variantMetadata.anchoRollo || variantMetadata.rollWidth || defaultAnchoRollo || 'N/A',
      puedeRotar: variantMetadata.puedeRotar !== undefined ? variantMetadata.puedeRotar : 
                  variantMetadata.canRotate !== undefined ? variantMetadata.canRotate : true, // Por defecto true
      imageUrl: variantMetadata.imageUrl || variantMetadata.image || undefined,
    };
  });
  
  // Fallback a datos hardcodeados si no hay datos del Catalog
  const useHardcodedData = catalogCollections.length === 0 && !loadingCollections;
  const finalCollections = useHardcodedData ? COLLECTIONS : collections;
  const finalVariants = useHardcodedData ? VARIANTS : variants;
  const finalManufacturers = useHardcodedData ? [
    { id: 'coulisse', name: 'Coulisse', code: 'COU' },
    { id: 'vertilux', name: 'Vertilux', code: 'VER' },
  ] : manufacturers;
  
  const handleCollectionChange = (collectionId: string) => {
    if (productType === 'roller-shade') {
      onUpdate({ collectionId: collectionId, variantId: undefined });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          collectionId: collectionId, 
          variantId: undefined 
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          collectionId: collectionId, 
          variantId: undefined 
        } 
      });
    } else {
      // Fallback para CurtainConfiguration antiguo
      onUpdate({ filmType: collectionId, ralColor: undefined });
    }
  };
  
  const handleVariantChange = (variantId: string | undefined) => {
    if (productType === 'roller-shade') {
      onUpdate({ variantId: variantId });
    } else if (productType === 'dual-shade' || productType === 'triple-shade') {
      const currentFabric = (config as any).frontFabric || {};
      onUpdate({ 
        frontFabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          variantId: variantId 
        } 
      });
    } else if (productType === 'drapery' || productType === 'awning') {
      const currentFabric = (config as any).fabric || {};
      onUpdate({ 
        fabric: { 
          ...currentFabric,
          manufacturer: (config as any).variantManufacturer || currentFabric.manufacturer,
          variantId: variantId 
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
                {loadingVariants ? (
                  <div className="col-span-4 text-center text-gray-500 py-4">Loading variants...</div>
                ) : finalVariants.filter(variant => variant.collectionId === currentCollectionId).length === 0 ? (
                  <div className="col-span-4 text-center text-gray-500 py-4">
                    No variants available for this collection
                  </div>
                ) : (
                  finalVariants
                    .filter(variant => variant.collectionId === currentCollectionId)
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

