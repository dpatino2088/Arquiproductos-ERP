import { useMemo, useEffect, useRef } from 'react';
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
  
  // FASE 1: Support both productTypeId (legacy) and product_type_id (unified contract)
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  const prevProductTypeIdRef = useRef<string | null | undefined>(productTypeId);
  const autoSelectAttemptedRef = useRef<string | null>(null); // Track which productTypeId we've attempted auto-select for
  
  // Load BOM Templates for selected product type
  const { templates: bomTemplates, loading: loadingBOMTemplates } = useBOMTemplates(productTypeId || undefined);
  
  // DEBUG: Log templates loading
  console.log('[ProductStep] 🔍 BOM Templates state', { 
    productTypeId, 
    templatesCount: bomTemplates.length, 
    loading: loadingBOMTemplates,
    templates: bomTemplates.map(t => ({ id: t.id, name: t.name, product_type_id: t.product_type_id })),
    currentBomTemplateId: (config as any).bom_template_id,
    shouldAutoSelect: bomTemplates.length === 1 && !(config as any).bom_template_id && productTypeId && !loadingBOMTemplates,
  });
  
  // FASE 1: CRITICAL - Clear bom_template_id when product_type_id changes
  useEffect(() => {
    const prevProductTypeId = prevProductTypeIdRef.current;
    const currentProductTypeId = productTypeId;
    
    const willClear = prevProductTypeId !== undefined && prevProductTypeId !== null && prevProductTypeId !== currentProductTypeId && currentProductTypeId;
    console.log('[ProductStep] Clear bom_template_id effect', {
      prevProductTypeId,
      currentProductTypeId,
      willClear,
    });
    
    // If product type changed (not initial load), clear bom_template_id and reset auto-select tracking
    if (willClear) {
      console.log('[ProductStep] CLEARING bom_template_id because productType changed');
      autoSelectAttemptedRef.current = null; // Reset auto-select tracking
      onUpdate({ bom_template_id: null } as any);
    }
    
    prevProductTypeIdRef.current = currentProductTypeId;
  }, [productTypeId, onUpdate]);
  
  // ✅ FIX A: Auto-select removed from ProductStep - now handled in ProductConfigurator
  // This component only shows UI selector if multiple templates exist
  
  // Build product cards from DB ProductTypes + UI metadata
  const productCards = useMemo(() => {
    if (!productTypes.length) return [];
    
    return productTypes
      .map(pt => {
        // ✅ FIX: Try exact match first, then case-insensitive, then name-based matching
        let metadata = PRODUCT_UI_METADATA[pt.code || ''];
        
        // If no exact match, try case-insensitive match
        if (!metadata && pt.code) {
          const codeUpper = pt.code.toUpperCase();
          metadata = PRODUCT_UI_METADATA[codeUpper];
        }
        
        // If still no match, try matching by name (e.g., "Roller Shade" -> ROLLER)
        if (!metadata && pt.name) {
          const nameUpper = pt.name.toUpperCase();
          // Try to find matching metadata by checking if name contains key words
          for (const [key, meta] of Object.entries(PRODUCT_UI_METADATA)) {
            const keyWords = key.split('_').map(w => w.toLowerCase());
            const nameLower = pt.name.toLowerCase();
            if (keyWords.some(word => nameLower.includes(word))) {
              metadata = meta;
              if (import.meta.env.DEV) {
                console.log(`ProductStep: Matched ProductType "${pt.name}" (code: ${pt.code}) to metadata key "${key}" by name`);
              }
              break;
            }
          }
        }
        
        if (!metadata) {
          if (import.meta.env.DEV) {
            console.warn(`ProductStep: No UI metadata for ProductType code: ${pt.code}, name: ${pt.name}`);
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
  
  // FASE 1: Handle product type selection
  const handleProductTypeSelect = (selectedProductTypeId: string, uiCode: string) => {
    if (import.meta.env.DEV) {
      console.log('[ProductStep] ProductType selected', { productTypeId: selectedProductTypeId, uiCode, currentBomTemplateId: (config as any).bom_template_id });
    }
    
    // FASE 1: Set product_type_id (unified contract) and clear bom_template_id when ProductType changes
    // CRITICAL: Reset auto-select tracking when ProductType changes
    autoSelectAttemptedRef.current = null;
    
    const updates: any = {
      productType: uiCode as any,      // UI code for ProductConfig
      product_type_id: selectedProductTypeId,  // Unified contract field
      productTypeId: selectedProductTypeId,    // Legacy field (for backward compatibility)
      bom_template_id: null,  // CRITICAL: Clear bom_template_id when ProductType changes
    };
    
    console.log('[ProductStep] Calling onUpdate with ProductType selection', { updates });
    onUpdate(updates);
  };
  
  const handleProductTypeDeselect = () => {
    if (import.meta.env.DEV) {
      console.log('[ProductStep] ProductType deselected');
    }
    
    onUpdate({ 
      productType: undefined,
      product_type_id: null,
      productTypeId: undefined,
      bom_template_id: null,
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
            
            // Check if selected by comparing UUID (support both unified contract and legacy)
            const isSelected = (config as any).product_type_id === product.id || 
                              (config as any).productTypeId === product.id || 
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
                  if (import.meta.env.DEV) {
                    console.log('[ProductStep] BOM Template selected', { bomTemplateId: value, productTypeId });
                  }
                  onUpdate({ bom_template_id: value || null } as any);
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
