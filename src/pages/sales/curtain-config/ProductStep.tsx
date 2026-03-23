import { useMemo, useEffect, useRef, useState } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useProductTypes } from '../../../hooks/useProductTypes';
import { useUIStore } from '../../../stores/ui-store';
import type { DealerConfiguratorPolicy } from '../../../hooks/useDealerConfiguratorPolicy';
import { useConfiguratorPolicy } from '../../../context/ConfiguratorPolicyContext';
import { useActingAsContext } from '../../../context/ActingAsContext';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import { useBOMTemplates } from '../../../hooks/useBOMTemplates';
import { Image as ImageIcon } from 'lucide-react';
import { useOrganizationContext } from '../../../context/OrganizationContext';

// Imágenes por tipo de producto (public/images)
const PRODUCT_TYPE_IMAGES: Record<string, string> = {
  'Roller Shade': '/images/Roller Shade.png',
  'Dual Shade': '/images/Dual Shade.png',
  'Triple Shade': '/images/Triple Shade.png',
  'Drapery': '/images/Drapery.png',
  'Awning': '/images/Awning.png',
  'Window Film': '/images/Window Film.png',
  'Honey Comb': '/images/Honey Comb.png',
  'Vertical': '/images/Vertical.png',
  'Wood': '/images/Wood.png',
  'Roman Shade': '/images/Roman Shade.png',
  'Accessories': '/images/Accessories.png',
};
// Fallback si el archivo está guardado como "Accesories" (una s)
const ACCESSORIES_IMAGE_PATHS = ['/images/CatalogItems.png', '/images/Accessories.png', '/images/Accesories.png'];

interface ProductStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
  /** When set (acting as dealer with policy), only these product types are shown */
  policy?: DealerConfiguratorPolicy | null;
  /** True while policy is being loaded (acting as dealer). Show skeleton to avoid flash of all types. */
  policyLoading?: boolean;
  /** Navigate to a step by id (e.g. 'accessories' for Accessories Only card) */
  onNavigateToStep?: (stepId: string) => void;
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
  // DB code: HONEY_COMB
  HONEY_COMB: {
    uiCode: 'honey-comb',
    maxWidth: 2400,
    maxHeight: 3000,
    variations: 'Manual, Electric',
    additionalInfo: ['Cellular structure for superior insulation'],
  },
  // DB code: VERTICAL
  VERTICAL: {
    uiCode: 'vertical',
    maxWidth: 4000,
    maxHeight: 4000,
    variations: 'Manual, Electric',
    additionalInfo: ['Vertical slats for wide openings'],
  },
  // DB code: WOOD
  WOOD: {
    uiCode: 'wood',
    maxWidth: 2400,
    maxHeight: 3000,
    variations: 'Manual',
    additionalInfo: ['Natural wood blinds'],
  },
  // DB code: ROMAN_SHADE
  ROMAN_SHADE: {
    uiCode: 'roman-shade',
    maxWidth: 2200,
    maxHeight: 3000,
    variations: 'Manual, Electric',
    additionalInfo: ['Classic Roman fold design'],
  },
  // Note: 'catalog' ProductType is handled by the special showAccessoriesCard below, not here
};

export default function ProductStep({ config, onUpdate, policy: policyProp, policyLoading: policyLoadingProp, onNavigateToStep }: ProductStepProps) {
  const { policy: policyCtx, loading: policyLoadingCtx } = useConfiguratorPolicy();
  const { activeDisplayName } = useActingAsContext() ?? {};
  const policy = policyProp ?? policyCtx;
  const policyLoading = policyLoadingProp ?? policyLoadingCtx;
  const showAccessoriesCard = !policy || policy.allow_accessories_only === true;

  const handleAccessoriesSelect = () => {
    onUpdate({
      productType: 'catalog' as any,
      productTypeId: undefined,
      product_type_id: undefined,
      bom_template_id: null,
    } as any);
  };
  // Load ProductTypes from database
  const { productTypes, loading: loadingProductTypes } = useProductTypes();
  useOrganizationContext();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  useEffect(() => {
    setGlobalLoading(loadingProductTypes);
    return () => setGlobalLoading(false);
  }, [loadingProductTypes, setGlobalLoading]);

  // Debug BOM template picker oculto (no se muestra en UI)
  const showTemplatePicker = false;
  const [productImageErrors, setProductImageErrors] = useState<Record<string, boolean>>({});
  const [accessoriesImageIndex, setAccessoriesImageIndex] = useState(0);
  
  // FASE 1: Support both productTypeId (legacy) and product_type_id (unified contract)
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  const prevProductTypeIdRef = useRef<string | null | undefined>(productTypeId);
  const autoSelectAttemptedRef = useRef<string | null>(null); // Track which productTypeId we've attempted auto-select for
  
  // Load BOM Templates for selected product type
  const { templates: bomTemplates, loading: loadingBOMTemplates } = useBOMTemplates(productTypeId || undefined);
  
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
      .filter(pt => pt.code !== 'catalog') // catalog has its own special card
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
          id: pt.id,
          code: pt.code || '',
          uiCode: metadata.uiCode,
          name: pt.name,
          maxWidth: metadata.maxWidth,
          maxHeight: metadata.maxHeight,
          variations: metadata.variations,
          additionalInfo: metadata.additionalInfo,
          isAccessoriesOnly: metadata.isAccessoriesOnly,
          status: pt.status || 'active',
        };
      })
      .filter(Boolean);
  }, [productTypes]);

  // Filter by DealerConfiguratorPolicy when acting as dealer with policy.
  // Case-insensitive: policy codes are normalized to lowercase in the hook; compare with pt.code.toLowerCase().
  // Fail closed: if policy exists and array is empty → show nothing (no product types assigned).
  const visibleProductCards = useMemo(() => {
    if (!policy) return productCards;
    const codes = policy.allowed_product_type_codes ?? [];
    if (codes.length === 0) return [];
    const policyCodesLower = codes.map((c) => c.toLowerCase());
    return productCards.filter(
      (p): p is NonNullable<typeof p> =>
        !!p && policyCodesLower.includes((p.code || '').toLowerCase())
    );
  }, [productCards, policy]);
  
  if (import.meta.env.DEV && productCards.length > 0) {
    console.log('ProductStep: Product cards generated', {
      count: productCards.length,
      visibleCount: visibleProductCards.length,
      policy: policy ? { allowed_product_type_codes: policy.allowed_product_type_codes } : null,
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
    } as any);
  };
  
  // Show loading state (product types or policy when acting as dealer)
  if (loadingProductTypes) return <div className="py-6 px-6" />;
  if (policyLoading) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
          <div className="text-center text-gray-500 py-8">
            <p className="text-sm">Loading permissions…</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error if no product types (after policy filter). Fail closed: policy with empty allowed list = no types assigned.
  if (visibleProductCards.length === 0) {
    const noTypesAssigned = policy && (!policy.allowed_product_type_codes?.length);
    const dealerLabel = activeDisplayName?.trim() ? ` (${activeDisplayName})` : '';
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
          <div className="text-center text-red-500 py-8">
            <p className="text-sm font-medium">
              {noTypesAssigned ? `No product types assigned for this dealer${dealerLabel}.` : 'No product types available'}
            </p>
            <p className="text-xs mt-1">
              {noTypesAssigned
                ? 'Please contact admin.'
                : 'Please configure product types in your organization settings.'}
            </p>
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {visibleProductCards.map((product) => {
            if (!product) return null;
            
            const isComingSoon = product.status === 'coming_soon';
            const selectedProductTypeId = (config as any).product_type_id || (config as any).productTypeId || null;
            // Selection priority: if product_type_id exists, trust it as source of truth.
            // This prevents dual-highlight when legacy productType text is out of sync in edit mode.
            const isSelected = !isComingSoon && (
              selectedProductTypeId
                ? selectedProductTypeId === product.id
                : config.productType === product.uiCode
            );
            
            return (
              <div
                key={product.id}
                onClick={() => {
                  if (isComingSoon) return;
                  if (isSelected) {
                    handleProductTypeDeselect();
                  } else {
                    handleProductTypeSelect(product.id, product.uiCode);
                  }
                }}
                className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all ${
                  isComingSoon
                    ? 'border-gray-200 opacity-60 cursor-not-allowed'
                    : isSelected
                    ? 'border-2 border-gray-900 shadow-lg cursor-pointer'
                    : 'border-gray-200 hover:shadow-lg hover:border-gray-300 cursor-pointer'
                }`}
              >
                <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                  {PRODUCT_TYPE_IMAGES[product.name] && !productImageErrors[product.name] ? (
                    <img
                      src={PRODUCT_TYPE_IMAGES[product.name]}
                      alt={product.name}
                      className="w-full h-full object-contain"
                      onError={() => setProductImageErrors((prev) => ({ ...prev, [product.name]: true }))}
                    />
                  ) : (
                    <ImageIcon className="w-16 h-16 text-gray-300" />
                  )}
                </div>
                
                <div className="p-4 bg-gray-100 flex-1">
                  <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={product.name}>
                    {product.name}
                  </h3>
                  {isComingSoon && (
                    <p className="text-[10px] text-gray-400 text-center mt-1 tracking-wide uppercase">Coming Soon</p>
                  )}
                </div>
              </div>
            );
          })}
          {showAccessoriesCard && (
            <div
              onClick={() => {
                const isCatalogSelected = (config as any).productType === 'catalog';
                if (isCatalogSelected) {
                  handleProductTypeDeselect();
                } else {
                  handleAccessoriesSelect();
                }
              }}
              className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                (config as any).productType === 'catalog'
                  ? 'border-2 border-gray-900 shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                {!productImageErrors['Accessories'] ? (
                  <img
                    src={ACCESSORIES_IMAGE_PATHS[accessoriesImageIndex]}
                    alt="Catalog Items"
                    className="w-full h-full object-contain"
                    onError={() => {
                      if (accessoriesImageIndex + 1 < ACCESSORIES_IMAGE_PATHS.length) {
                        setAccessoriesImageIndex((i) => i + 1);
                      } else {
                        setProductImageErrors((prev) => ({ ...prev, 'Accessories': true }));
                      }
                    }}
                  />
                ) : (
                  <ImageIcon className="w-16 h-16 text-gray-300" />
                )}
              </div>
              <div className="p-4 bg-gray-100 flex-1">
                <h3 className="font-semibold text-sm truncate text-center text-gray-900" title="Catalog Items">
                  Catalog Items
                </h3>
              </div>
            </div>
          )}
        </div>
        
        {/* BOM Template Selection - SOLO en modo DEBUG para admin/superadmin */}
        {showTemplatePicker && productTypeId && bomTemplates.length > 0 && (
          <div className="mt-6 p-3 bg-yellow-50 border border-yellow-200 rounded">
            <Label className="text-sm font-medium mb-2 block text-yellow-800">
              🔧 DEBUG: BOM TEMPLATE (Admin Only)
            </Label>
            <p className="text-xs text-yellow-700 mb-2">
              ⚠️ Solo visible en modo desarrollo. En producción, el template se resuelve automáticamente.
            </p>
            {bomTemplates.length === 1 ? (
              <p className="text-xs text-yellow-600">
                {bomTemplates[0]?.name || 'BOM Template'} (auto-selected)
              </p>
            ) : (
              <SelectShadcn
                value={(config as any).bom_template_id || ''}
                onValueChange={(value) => {
                  if (import.meta.env.DEV) {
                    console.log('[ProductStep] DEBUG: BOM Template manually selected', { bomTemplateId: value, productTypeId });
                  }
                  onUpdate({ bom_template_id: value || null } as any);
                }}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select BOM template (DEBUG)" />
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
