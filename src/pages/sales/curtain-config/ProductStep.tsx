import { useMemo, useEffect } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useProductTypes } from '../../../hooks/useProductTypes';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import { useBOMTemplates } from '../../../hooks/useBOMTemplates';

interface ProductStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

// UI metadata for each product type code (display info only)
// Keys MUST match ProductTypes.code in database exactly
const PRODUCT_UI_METADATA: Record<string, {
  uiCode: string;  // The code used in ProductConfig.productType
  maxWidth: number;
  maxHeight: number;
  variations: string;
  additionalInfo: string[];
  isAccessoriesOnly?: boolean;
}> = {
  // DB code: ROLLER
  ROLLER: {
    uiCode: 'roller-shade',
    maxWidth: 2200,
    maxHeight: 3400,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Equipped with double cleaning brushes',
      'Top model with many extras'
    ]
  },
  // DB code: DUAL
  DUAL: {
    uiCode: 'dual-shade',
    maxWidth: 2500,
    maxHeight: 3500,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Dual layer system for enhanced light control',
      'Premium quality materials'
    ]
  },
  // DB code: TRIPLE
  TRIPLE: {
    uiCode: 'triple-shade',
    maxWidth: 3000,
    maxHeight: 4000,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Three-layer system for maximum flexibility',
      'Advanced motorization options available'
    ]
  },
  // DB code: DRAPERY
  DRAPERY: {
    uiCode: 'drapery',
    maxWidth: 3500,
    maxHeight: 4500,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Elegant wave fold design',
      'Wide range of fabric options'
    ]
  },
  // DB code: AWNING
  AWNING: {
    uiCode: 'awning',
    maxWidth: 4000,
    maxHeight: 5000,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Outdoor protection solution',
      'Weather resistant materials'
    ]
  },
  // DB code: FILM
  FILM: {
    uiCode: 'window-film',
    maxWidth: 2000,
    maxHeight: 3000,
    variations: 'Static, Adhesive',
    additionalInfo: [
      'UV protection and privacy',
      'Easy installation'
    ]
  },
  // DB code: ACCESSORIES
  ACCESSORIES: {
    uiCode: 'accessories',
    maxWidth: 0,
    maxHeight: 0,
    variations: 'Individual Items',
    additionalInfo: [
      'Controls, clutches, supports, and other accessories',
      'Items sold separately from main products'
    ],
    isAccessoriesOnly: true
  },
};

export default function ProductStep({ config, onUpdate }: ProductStepProps) {
  // Load ProductTypes from database
  const { productTypes, loading: loadingProductTypes } = useProductTypes();
  
  // Load BOM Templates for selected product type
  const productTypeId = (config as any).productTypeId;
  const { templates: bomTemplates, loading: loadingBOMTemplates } = useBOMTemplates(productTypeId || undefined);
  
  // Auto-select BOM template if exactly 1 is available
  useEffect(() => {
    if (bomTemplates.length === 1 && !(config as any).bom_template_id) {
      onUpdate({ bom_template_id: bomTemplates[0].id } as any);
    }
  }, [bomTemplates, config, onUpdate]);
  
  // Build product cards from DB ProductTypes + UI metadata
  const productCards = useMemo(() => {
    if (!productTypes.length) return [];
    
    return productTypes
      .map(pt => {
        const metadata = PRODUCT_UI_METADATA[pt.code || ''];
        if (!metadata) {
          if (import.meta.env.DEV) {
            console.warn(`ProductStep: No UI metadata for ProductType code: ${pt.code}`);
          }
          return null;
        }
        
        return {
          id: pt.id,                    // DB UUID
          code: pt.code || '',          // DB code (ROLLER, DUAL, etc.)
          uiCode: metadata.uiCode,      // UI code (roller-shade, dual-shade, etc.)
          name: pt.name,                // DB name (Roller Shade, Dual Shade, etc.)
          maxWidth: metadata.maxWidth,
          maxHeight: metadata.maxHeight,
          variations: metadata.variations,
          additionalInfo: metadata.additionalInfo,
          isAccessoriesOnly: metadata.isAccessoriesOnly,
        };
      })
      .filter(Boolean);
  }, [productTypes]);
  
  if (import.meta.env.DEV && productCards.length > 0) {
    console.log('ProductStep: Product cards generated', {
      count: productCards.length,
      cards: productCards.map(c => ({ code: c?.code, name: c?.name, id: c?.id })),
    });
  }
  
  // Handle product type selection
  const handleProductTypeSelect = (productTypeId: string, uiCode: string) => {
    if (import.meta.env.DEV) {
      console.log('ProductStep: Selecting product type', {
        productTypeId,
        uiCode,
      });
    }
    
    onUpdate({ 
      productType: uiCode as any,      // UI code for ProductConfig
      productTypeId: productTypeId,    // DB UUID for filtering
    } as any);
  };
  
  const handleProductTypeDeselect = () => {
    onUpdate({ 
      productType: undefined,
      productTypeId: undefined,
    });
  };
  
  // Show loading state
  if (loadingProductTypes) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
          <div className="text-center text-gray-500 py-8">Loading product types...</div>
        </div>
      </div>
    );
  }
  
  // Show error if no product types
  if (productCards.length === 0) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
          <div className="text-center text-red-500 py-8">
            <p className="text-sm font-medium">No product types available</p>
            <p className="text-xs mt-1">Please configure product types in your organization settings.</p>
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
        
        <div className="grid grid-cols-4 gap-6">
          {productCards.map((product) => {
            if (!product) return null;
            
            // Check if selected by comparing UUID (more reliable than uiCode)
            const isSelected = (config as any).productTypeId === product.id || 
                              config.productType === product.uiCode;
            
            return (
              <div key={product.id} className="flex flex-col items-center">
                <button
                  type="button"
                  onClick={() => {
                    if (isSelected) {
                      handleProductTypeDeselect();
                    } else {
                      handleProductTypeSelect(product.id, product.uiCode);
                    }
                  }}
                  className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                    isSelected
                      ? 'border-2 border-gray-400 bg-gray-600'
                      : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                  }`}
                  style={{ padding: '2px' }}
                >
                  {/* Contenido del card - 5% más chico que el card (95% del tamaño) respetando padding de 2px */}
                  <div className="rounded overflow-hidden border border-gray-200 bg-gray-100 w-full h-full" style={{ width: '95%', height: '95%' }}>
                    {/* TODO: Add image from Supabase storage */}
                  </div>
                </button>
                
                {/* Nombre abajo del card - usa name de la DB */}
                <span className={`text-sm font-semibold block mt-2 text-gray-900`}>
                  {product.name}
                </span>
              </div>
            );
          })}
        </div>
        
        {/* BOM Template Selection - Only show if product type is selected and there are templates */}
        {productTypeId && bomTemplates.length > 0 && (
          <div className="mt-6">
            <Label className="text-sm font-medium mb-2 block">BOM TEMPLATE</Label>
            {bomTemplates.length === 1 ? (
              <p className="text-xs text-gray-500">
                {bomTemplates[0].name} (auto-selected)
              </p>
            ) : (
              <SelectShadcn
                value={(config as any).bom_template_id || ''}
                onValueChange={(value) => {
                  onUpdate({ bom_template_id: value || undefined } as any);
                }}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select BOM template" />
                </SelectTrigger>
                <SelectContent>
                  {bomTemplates.map((template) => (
                    <SelectItem key={template.id} value={template.id}>
                      {template.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
