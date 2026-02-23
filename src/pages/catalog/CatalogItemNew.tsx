import React, { useState, useEffect, useMemo, useRef } from 'react';
import { useForm, Resolver } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useQueryClient } from '@tanstack/react-query';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useCreateCatalogItem, useUpdateCatalogItem, useCatalogCategories } from '../../hooks/useCatalog';
import { useCatalogItemDetail } from '../../hooks/useCatalogItemDetail';
import { buildCatalogScopeKey } from '../../lib/catalogScopeKey';
import { catalogItemsListKey, catalogItemDetailKey } from '../../lib/queryKeys';
import type { CatalogItem } from '../../types/catalog';
import { useCategoryMargins } from '../../hooks/useCostEngineSettings';
import { supabase } from '../../lib/supabase/client';
import ImageUpload from '../../components/ui/ImageUpload';
import { syncCatalogItemProductTypes } from '../../lib/catalog-item-helpers';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useOnVisibilityChange } from '../../lib/app-persistence';
import { Info } from 'lucide-react';
import { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider } from '../../components/ui/Tooltip';
import {
  fetchCatalogItemSupply,
  upsertCatalogItemSupply,
  type SupplyType,
  type SupplyOrigin,
} from '../../services/catalogItemSupply';
import { CatalogItemRollSpecsSection } from '../../components/catalog/CatalogItemRollSpecsSection';
import { normalizeRateToSystem, toMeters, toSquareMetersFromArea } from '../../lib/uom-conversions';
// UOM conversions handled by backend trigger (trg_catalogitems_write_conversions)
// Frontend only displays conversions from CatalogItemConversions table

/**
 * ============================================================================
 * CATALOG ITEM FORM - REBUILT FROM SCRATCH
 * Based on DB dump: backups/2026-01-14_full.sql
 * ============================================================================
 * 
 * CatalogItems columns (REAL):
 * - id, organization_id, name, sku, unit_of_measure, description, category_id
 * - image_url, measure_basis, collection_name, variant_name
 * - roll_width, roll_pricing_mode, color, is_active
 * - cost_exw (ALWAYS per unit/ea), is_roll, roll_type
 * - purchase_unit (each/pack/set/box/case), units_per_purchase_unit
 * - created_at, updated_at
 * 
 * Note: manufacturer, manufacturer_id exist in DB but NOT used in this form (legacy)
 * 
 * Constraints:
 * - catalogitems_roll_type_requires_is_roll: if roll_type NOT NULL then is_roll must be true
 * - measure_basis: 'unit' | 'linear' | 'area'
 * - roll_type enum: 'fabric' | 'window_film' | 'vinyl' | 'mesh' | 'paper' | 'other'
 *
 * Terminology: always "Roll" for roll-of-material (fabric, film, vinyl). Never "Rail"
 * (rail = hardware: bottom_rail, top_rail, etc. in BOM/curtains).
 */

// Zod Schema - ONLY fields that exist in CatalogItems table
const catalogItemSchema = z.object({
  // Required fields
  sku: z.string().min(1, 'SKU is required'),
  name: z.string().optional(), // For rolls, auto-generated from collection + variant
  unit_of_measure: z.string().min(1, 'Unit of measure is required'),
  measure_basis: z.enum(['unit', 'linear', 'area']),
  
  // Optional fields
  description: z.string().optional().nullable(),
  category_id: z.string().uuid().optional().nullable(),
  image_url: z.string().optional().nullable(),
  
  // Roll fields
  is_roll: z.boolean(),
  roll_type: z.enum(['fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other']).optional().nullable(),
  collection_name: z.string().optional().nullable(),
  variant_name: z.string().optional().nullable(),
  roll_width_value: z.number().min(0).optional().nullable(),
  roll_width_uom: z.enum(['m', 'yd', 'ft', 'in']).optional().nullable(),
  roll_length_value: z.number().min(0).optional().nullable(),
  roll_length_uom: z.enum(['m', 'yd', 'ft', 'in']).optional().nullable(),
  roll_pricing_mode: z.enum(['per_linear_meter', 'per_square_meter', 'per_unit']).optional().nullable(),
  
  // Component fields
  color: z.string().optional().nullable(),
  
  // Pricing
  cost_exw: z.number().min(0).optional().nullable(),
  
  // Purchase unit (for inventory/procurement)
  purchase_unit: z.enum(['each', 'pack', 'set', 'box', 'case']),
  units_per_purchase_unit: z.number().min(1),
  
  // Status
  is_active: z.boolean(),
}).refine((data) => {
  // If NOT roll, name is required
  if (!data.is_roll && (!data.name || data.name.trim() === '')) return false;
  return true;
}, {
  message: 'Name is required for non-roll items',
  path: ['name'],
}).refine((data) => {
  // If is_roll=true, collection_name is required
  if (data.is_roll && (!data.collection_name || data.collection_name.trim() === '')) return false;
  return true;
}, {
  message: 'Collection name is required for roll items',
  path: ['collection_name'],
}).refine((data) => {
  // If is_roll=true, variant_name is required  
  if (data.is_roll && (!data.variant_name || data.variant_name.trim() === '')) return false;
  return true;
}, {
  message: 'Variant name (color) is required for roll items',
  path: ['variant_name'],
}).refine((data) => {
  // If is_roll=true, roll_type is required
  if (data.is_roll && !data.roll_type) return false;
  return true;
}, {
  message: 'Roll type is required for roll items',
  path: ['roll_type'],
}).refine((data) => {
  // If is_roll=true, roll_width_value is required
  if (data.is_roll && (data.roll_width_value == null || data.roll_width_value <= 0)) return false;
  return true;
}, {
  message: 'Roll width is required for roll items',
  path: ['roll_width_value'],
}).refine((data) => {
  // If is_roll=true, roll_length_value is required
  if (data.is_roll && (data.roll_length_value == null || data.roll_length_value <= 0)) return false;
  return true;
}, {
  message: 'Roll length is required for roll items',
  path: ['roll_length_value'],
});

type CatalogItemFormValues = z.infer<typeof catalogItemSchema>;

// Normalize number inputs (valueAsNumber yields NaN when empty) before Zod validation
const catalogItemResolver: Resolver<CatalogItemFormValues> = async (values, context, options) => {
  // Shallow copy and normalize
  const normalized = { ...values };
  
  // Normalize cost_exw: NaN → null
  if (typeof normalized.cost_exw === 'number' && Number.isNaN(normalized.cost_exw)) {
    normalized.cost_exw = null;
  }
  
  // Normalize roll dimensions: NaN → null
  if (typeof normalized.roll_width_value === 'number' && Number.isNaN(normalized.roll_width_value)) {
    normalized.roll_width_value = null;
  }
  if (typeof normalized.roll_length_value === 'number' && Number.isNaN(normalized.roll_length_value)) {
    normalized.roll_length_value = null;
  }
  
  // Normalize units_per_purchase_unit: NaN/null/undefined/< 1 → 1
  const upu = normalized.units_per_purchase_unit;
  if (upu == null || (typeof upu === 'number' && (Number.isNaN(upu) || upu < 1))) {
    normalized.units_per_purchase_unit = 1;
  }
  
  // Ensure purchase_unit has a valid value
  if (!normalized.purchase_unit || !['each', 'pack', 'set', 'box', 'case'].includes(normalized.purchase_unit)) {
    normalized.purchase_unit = 'each';
  }
  
  return zodResolver(catalogItemSchema)(normalized, context, options);
};

export default function CatalogItemNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { canEditCustomers: canEdit, loading: roleLoading } = useCurrentOrgRole();
  
  // Track current path so itemId stays in sync with navigation
  const [currentPath, setCurrentPath] = useState<string>(window.location.pathname);
  useEffect(() => {
    const syncPath = () => setCurrentPath(window.location.pathname);
    syncPath();
    const unsubscribe = router.addListener(syncPath);
    window.addEventListener('popstate', syncPath);
    return () => {
      unsubscribe();
      window.removeEventListener('popstate', syncPath);
    };
  }, []);

  const itemId = useMemo(() => {
    const match = currentPath.match(/\/catalog\/items\/edit\/([^/]+)/);
    return match && match[1] ? match[1] : null;
  }, [currentPath]);

  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();
  const queryClient = useQueryClient();
  const scopeKey = useMemo(
    () =>
      buildCatalogScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );
  const defaultListFilters = useMemo(
    () => ({ q: '', categoryId: '', status: 'all', sortKey: 'sku', page: 1, pageSize: 500 }),
    []
  );
  const listCache = queryClient.getQueryData(
    catalogItemsListKey(scopeKey, defaultListFilters)
  ) as CatalogItem[] | undefined;
  const initialItemFromList: CatalogItem | undefined =
    itemId && listCache ? listCache.find((i) => i.id === itemId) : undefined;
  const { data: detailItem } = useCatalogItemDetail(scopeKey, itemId, {
    orgId: activeOrganizationId ?? null,
    initialData: initialItemFromList,
  });
  
  // Hooks
  const { createItem, isCreating } = useCreateCatalogItem();
  const { updateItem, isUpdating } = useUpdateCatalogItem();
  const { leafCategories: catalogCategories, loading: catalogCategoriesLoading } = useCatalogCategories();
  const { productTypes, loading: productTypesLoading } = useProductTypes();
  const { margins: categoryMargins, loading: categoryMarginsLoading } = useCategoryMargins();
  
  // ProductTypes selection state
  const [selectedProductTypeIds, setSelectedProductTypeIds] = useState<string[]>([]);
  
  // Note: Pricing percentages are now managed by CategoryMargins (by category), not per-item
  // CatalogItemsMSRP is a cache of calculated results only
  
  // Form state
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'profile' | 'rates'>(() => {
    // Restore active tab from navigation state if available (supply tab removed)
    const state = window.history.state;
    const t = state?.activeTab;
    return t === 'profile' || t === 'rates' ? t : 'profile';
  });
  // Supply (Supply Type + Origin) — only when editing; stored in CatalogItemSupply
  const [supplyType, setSupplyType] = useState<SupplyType>('stock');
  const [supplyOrigin, setSupplyOrigin] = useState<SupplyOrigin>('local');
  const shouldCloseAfterSaveRef = useRef(false);
  
  // CatalogItemsMSRP: read-only for Rates tab (computed in backend; UI only displays)
  // All monetary values are already in pricing_uom ($/m or $/m²). No conversion needed.
  const [msrpRow, setMsrpRow] = useState<{
    dealer_price: number;
    msrp: number;
    total_cost: number;
    shipping_cost: number;
    import_tax_cost: number;
    minimum_margin_pct: number;
    msrp_pct: number;
    shipping_pct: number;
    import_tax_pct: number;
    pricing_uom: string | null;
    pricing_cost_exw: number | null;
  } | null>(null);
  // Counter to force re-fetch of msrpRow after save
  const [msrpFetchKey, setMsrpFetchKey] = useState(0);
  const [msrpLoading, setMsrpLoading] = useState(false);
  
  // Conversions state (from CatalogItemConversions table)
  const [conversions, setConversions] = useState<{
    cost_exw_per_m: number | null;
    cost_exw_per_m2: number | null;
    cost_exw_per_ea: number | null;
    computed_at: string | null;
  } | null>(null);
  const [conversionsLoading, setConversionsLoading] = useState(false);
  
  // Normalized dimensions (from DB after trigger calculation)
  const [rollDimensions, setRollDimensions] = useState<{
    roll_width_m: number | null;
    roll_length_m: number | null;
  }>({ roll_width_m: null, roll_length_m: null });
  
  const isReadOnly = !canEdit && !roleLoading;
  
  // Helper: Load conversions from CatalogItemConversions
  const loadConversions = async () => {
    if (!itemId || !activeOrganizationId) {
      setConversions(null);
      return;
    }
    
    setConversionsLoading(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItemConversions')
        .select('cost_exw_per_m, cost_exw_per_m2, cost_exw_per_ea, computed_at')
        .eq('catalog_item_id', itemId)
        .eq('organization_id', activeOrganizationId)
        .maybeSingle();
      
      if (error) {
        console.error('Error loading conversions:', error);
        setConversions(null);
      } else if (data) {
        setConversions(data);
      } else {
        setConversions(null);
      }
    } catch (err) {
      console.error('Error loading conversions:', err);
      setConversions(null);
    } finally {
      setConversionsLoading(false);
    }
  };
  
  // Helper: Reload conversions with retry (for after save)
  const reloadConversionsWithRetry = async () => {
    if (!itemId || !activeOrganizationId) return;
    
    for (let i = 0; i < 5; i++) {
      try {
      const { data, error } = await supabase
        .from('CatalogItemConversions')
        .select('cost_exw_per_m, cost_exw_per_m2, cost_exw_per_ea, computed_at')
        .eq('catalog_item_id', itemId)
        .eq('organization_id', activeOrganizationId)
        .maybeSingle();
        
        if (!error && data?.computed_at) {
          setConversions(data);
          return;
        }
      } catch (err) {
        console.error('Retry error loading conversions:', err);
      }
      
      // Wait 250ms before retry
      await new Promise(r => setTimeout(r, 250));
    }
    
    // After all retries, do final load attempt
    await loadConversions();
  };
  
  // React Hook Form
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty, dirtyFields },
    setValue,
    watch,
    reset,
  } = useForm<CatalogItemFormValues>({
    resolver: catalogItemResolver,
    defaultValues: {
      sku: '',
      name: '',
      description: '',
      unit_of_measure: 'ea',
      measure_basis: 'unit',
      category_id: null,
      image_url: null,
      is_roll: false,
      roll_type: null,
      collection_name: null,
      variant_name: null,
      roll_width_value: null,
      roll_width_uom: 'm',
      roll_length_value: null,
      roll_length_uom: 'm',
      roll_pricing_mode: null,
      color: null,
      cost_exw: null,
      purchase_unit: 'each',
      units_per_purchase_unit: 1,
      is_active: true,
    },
  });

  // ✅ FIX: SessionStorage persistence for editing (survives tab changes)
  const sessionKey = itemId ? `catalogItemEdit:${itemId}` : null;
  const sessionTimerRef = useRef<number | null>(null);
  const draftHydratedRef = useRef(false); // Prevent saving empty draft before hydration

  // New Item must ALWAYS start blank (no draft hydration)
  useEffect(() => {
    if (itemId) return;

    // Clear any stale draft that might exist from prior attempts
    window.localStorage.removeItem('catalogItemDraft:new');

    reset({
      sku: '',
      name: '',
      description: '',
      unit_of_measure: 'ea',
      measure_basis: 'unit',
      category_id: null,
      image_url: null,
      is_roll: false,
      roll_type: null,
      collection_name: null,
      variant_name: null,
      roll_width_value: null,
      roll_width_uom: 'm',
      roll_length_value: null,
      roll_length_uom: 'm',
      roll_pricing_mode: null,
      color: null,
      cost_exw: null,
      purchase_unit: 'each',
      units_per_purchase_unit: 1,
      is_active: true,
    });
    setSelectedProductTypeIds([]);
  }, [itemId, reset]);
  
  // Watch values
  const isRoll = !!watch('is_roll');
  const unitOfMeasure = watch('unit_of_measure');
  const rollWidthUom = watch('roll_width_uom');
  const rollLengthUom = watch('roll_length_uom');
  const rollType = watch('roll_type');
  const measureBasis = watch('measure_basis');
  const categoryId = watch('category_id');
  const costExw = watch('cost_exw');
  const pricingMode = watch('roll_pricing_mode');
  
  // CatalogItemsMSRP already stores shipping_cost/import_tax_cost/total_cost/dealer_price/msrp
  // in pricing_uom ($/m or $/m²), because pricing_cost_exw is the UOM-converted base.
  // Factor = 1; just derive the unit label from pricing_uom / roll_pricing_mode.
  const { msrpFactor, msrpUnitLabel } = useMemo(() => {
    const effectiveMode = pricingMode === 'per_unit' ? 'per_linear_meter' : pricingMode;
    let unitLabel = '/ea';
    if (effectiveMode === 'per_linear_meter' || (!pricingMode && measureBasis === 'linear')) {
      unitLabel = '/m';
    } else if (effectiveMode === 'per_square_meter' || (!pricingMode && measureBasis === 'area')) {
      unitLabel = '/m²';
    }
    return { msrpFactor: 1, msrpUnitLabel: unitLabel };
  }, [pricingMode, measureBasis]);

  // Detect if any pricing-relevant field has been changed since last save
  const isPricingDirty = isDirty && !!(
    dirtyFields.cost_exw || dirtyFields.category_id ||
    dirtyFields.unit_of_measure || dirtyFields.roll_pricing_mode ||
    dirtyFields.roll_width_value || dirtyFields.roll_width_uom
  );

  // Display conversions: ALWAYS compute live from form inputs when possible.
  // Rationale: DB conversions can be stale until user clicks Save. This must reflect Cost EXW normalized in meters.
  const costExwNum = Number(costExw) || 0;

  const rollWidthValue = watch('roll_width_value');
  const rollLengthValue = watch('roll_length_value');

  const rollWidthM =
    rollWidthValue != null && rollWidthUom
      ? toMeters(Number(rollWidthValue), rollWidthUom)
      : rollDimensions.roll_width_m;

  const rollLengthM =
    rollLengthValue != null && rollLengthUom
      ? toMeters(Number(rollLengthValue), rollLengthUom)
      : rollDimensions.roll_length_m;

  const unitLower = (unitOfMeasure || '').toLowerCase().trim();
  const isAreaUom =
    unitLower === 'm2' ||
    unitLower === 'sqm' ||
    unitLower === 'ft2' ||
    unitLower === 'sqft' ||
    unitLower === 'yd2' ||
    unitLower === 'sqyd' ||
    unitLower === 'in2' ||
    unitLower === 'cm2' ||
    unitLower === 'mm2';

  const normalizedCostExwPerM = useMemo(() => {
    if (costExwNum <= 0 || !unitOfMeasure) return conversions?.cost_exw_per_m ?? null;

    // If input is an area price (e.g. $/m², $/yd²), convert to $/m by multiplying by roll width.
    if (isAreaUom) {
      if (rollWidthM == null || rollWidthM <= 0) return null;
      const perM2 = normalizeRateToSystem(costExwNum, unitOfMeasure, 'm2');
      return perM2 * rollWidthM;
    }

    // If priced per roll, convert to $/m by dividing by roll length (when available)
    if (unitLower === 'roll') {
      if (rollLengthM == null || rollLengthM <= 0) return null;
      return costExwNum / rollLengthM;
    }

    // Default: treat as linear or unit and normalize directly to $/m
    return normalizeRateToSystem(costExwNum, unitOfMeasure, 'm');
  }, [costExwNum, unitOfMeasure, isAreaUom, rollWidthM, rollLengthM, unitLower, conversions?.cost_exw_per_m]);

  const normalizedCostExwPerM2 = useMemo(() => {
    if (costExwNum <= 0 || !unitOfMeasure) {
      return conversions?.cost_exw_per_m2 ?? (normalizedCostExwPerM != null && rollWidthM != null && rollWidthM > 0 ? normalizedCostExwPerM / rollWidthM : null);
    }

    // If input is already area-based, normalize directly to $/m²
    if (isAreaUom) {
      return normalizeRateToSystem(costExwNum, unitOfMeasure, 'm2');
    }

    // Otherwise derive from $/m ÷ width
    if (normalizedCostExwPerM != null && rollWidthM != null && rollWidthM > 0) {
      return normalizedCostExwPerM / rollWidthM;
    }
    return conversions?.cost_exw_per_m2 ?? null;
  }, [costExwNum, unitOfMeasure, isAreaUom, normalizedCostExwPerM, rollWidthM, conversions?.cost_exw_per_m2]);

  const normalizedCostExwPerEa =
    conversions?.cost_exw_per_ea ??
    (costExwNum > 0 &&
    unitOfMeasure &&
    ['ea', 'each', 'pcs', 'pc', 'unit', 'piece'].includes(unitLower)
      ? costExwNum
      : null);

  // Live MSRP preview: computed in the UI when pricing-relevant fields are dirty.
  // Uses rates (shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct) from the last
  // saved msrpRow snapshot — they only change when CategoryMargins/CostSettings change,
  // not when the user edits cost_exw. The cost base updates live.
  const liveMsrp = useMemo(() => {
    if (!isPricingDirty || !msrpRow) return null;

    const liveCost =
      msrpUnitLabel === '/m'  ? normalizedCostExwPerM  :
      msrpUnitLabel === '/m²' ? normalizedCostExwPerM2 :
      costExwNum;

    if (!liveCost || liveCost <= 0) return null;

    const s = msrpRow.shipping_pct    || 0;
    const t = msrpRow.import_tax_pct  || 0;
    const m = msrpRow.minimum_margin_pct || 0.35;
    const p = msrpRow.msrp_pct         || 0.65;

    const shipping    = Math.round(liveCost * s * 10000) / 10000;
    const importTax   = Math.round(liveCost * (1 + s) * t * 10000) / 10000;
    const totalCost   = Math.round(liveCost * (1 + s) * (1 + t) * 10000) / 10000;
    const dealerPrice = Math.round(totalCost / Math.max(1 - m, 0.0001) * 10000) / 10000;
    const msrpVal     = Math.round(dealerPrice / Math.max(1 - p, 0.0001) * 10000) / 10000;

    return {
      shipping_cost:      shipping,
      import_tax_cost:    importTax,
      total_cost:         totalCost,
      dealer_price:       dealerPrice,
      msrp:               msrpVal,
      minimum_margin_pct: m,
      msrp_pct:           p,
    };
  }, [isPricingDirty, msrpRow, msrpUnitLabel, normalizedCostExwPerM, normalizedCostExwPerM2, costExwNum]);

  // Cost per Full Roll: always Cost EXW normalized to meters × roll length (meters)
  const fullRollCost = useMemo(() => {
    if (!isRoll) return null;
    if (normalizedCostExwPerM == null) return null;
    if (rollLengthM == null || rollLengthM <= 0) return null;
    return normalizedCostExwPerM * rollLengthM;
  }, [isRoll, normalizedCostExwPerM, rollLengthM]);
  
  // Load item data when editing
  useEffect(() => {
    if (!itemId || !activeOrganizationId) return;
    
    async function loadItem() {
      try {
        const { data, error } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('id', itemId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        
        if (error) throw error;
        if (!data) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Item not found',
            message: 'The item you are trying to edit was not found.',
          });
          router.navigate('/catalog/items');
          return;
        }
        
        // Load normalized dimensions for display
        setRollDimensions({
          roll_width_m: data.roll_width_m ? Number(data.roll_width_m) : null,
          roll_length_m: data.roll_length_m ? Number(data.roll_length_m) : null,
        });
        
        // ✅ FIX: Check sessionStorage first (user may have unsaved changes from tab switch)
        const sessionData = sessionKey ? window.sessionStorage.getItem(sessionKey) : null;
        let formValues: CatalogItemFormValues;
        
        const dbValues: CatalogItemFormValues = {
          sku: data.sku || '',
          name: data.name || '',
          description: data.description || '',
          unit_of_measure: data.unit_of_measure || 'ea',
          measure_basis: (data.is_roll && data.measure_basis === 'unit') ? 'linear' : (data.measure_basis || 'unit'),
          category_id: data.category_id || null,
          image_url: data.image_url || null,
          is_roll: data.is_roll || false,
          roll_type: data.roll_type || null,
          collection_name: data.collection_name || null,
          variant_name: data.variant_name || null,
          // Prefer explicit value/uom; fallback to normalized meters if legacy rows lack value/uom
          roll_width_value:
            data.roll_width_value != null
              ? Number(data.roll_width_value)
              : (data.roll_width_m != null ? Number(data.roll_width_m) : null),
          roll_width_uom: data.roll_width_uom || (data.roll_width_value == null && data.roll_width_m != null ? 'm' : 'm'),
          roll_length_value:
            data.roll_length_value != null
              ? Number(data.roll_length_value)
              : (data.roll_length_m != null ? Number(data.roll_length_m) : null),
          roll_length_uom: data.roll_length_uom || (data.roll_length_value == null && data.roll_length_m != null ? 'm' : 'm'),
          roll_pricing_mode: (data.is_roll && data.roll_pricing_mode === 'per_unit') ? 'per_linear_meter' : (data.roll_pricing_mode || null),
          color: data.color || null,
          cost_exw: data.cost_exw ? Number(data.cost_exw) : null,
          purchase_unit: (data.purchase_unit && ['each', 'pack', 'set', 'box', 'case'].includes(data.purchase_unit)) ? data.purchase_unit : 'each',
          units_per_purchase_unit: (data.units_per_purchase_unit && Number(data.units_per_purchase_unit) >= 1) ? Number(data.units_per_purchase_unit) : 1,
          is_active: data.is_active !== undefined ? data.is_active : true,
        };
        
        if (sessionData) {
          try {
            const parsed = JSON.parse(sessionData);
            if (parsed?.values) {
              formValues = { ...dbValues, ...parsed.values };
              if (Array.isArray(parsed?.productTypeIds)) {
                setSelectedProductTypeIds(parsed.productTypeIds);
              }
              
              // If roll fields are missing in session but exist in DB, restore them
              const isRollItem = !!(formValues.is_roll || dbValues.is_roll);
              if (isRollItem) {
                if (!formValues.collection_name && dbValues.collection_name) {
                  formValues.collection_name = dbValues.collection_name;
                }
                if (!formValues.variant_name && dbValues.variant_name) {
                  formValues.variant_name = dbValues.variant_name;
                }
                if (!formValues.roll_type && dbValues.roll_type) {
                  formValues.roll_type = dbValues.roll_type;
                }
                if (!formValues.roll_pricing_mode && dbValues.roll_pricing_mode) {
                  formValues.roll_pricing_mode = dbValues.roll_pricing_mode;
                }
                if (!formValues.unit_of_measure && dbValues.unit_of_measure) {
                  formValues.unit_of_measure = dbValues.unit_of_measure;
                }
                // Restore roll dimensions
                if (formValues.roll_width_value == null && dbValues.roll_width_value != null) {
                  formValues.roll_width_value = dbValues.roll_width_value;
                }
                if (!formValues.roll_width_uom && dbValues.roll_width_uom) {
                  formValues.roll_width_uom = dbValues.roll_width_uom;
                }
                if (formValues.roll_length_value == null && dbValues.roll_length_value != null) {
                  formValues.roll_length_value = dbValues.roll_length_value;
                }
                if (!formValues.roll_length_uom && dbValues.roll_length_uom) {
                  formValues.roll_length_uom = dbValues.roll_length_uom;
                }
              }
              
              draftHydratedRef.current = true;
              if (import.meta.env.DEV) {
                console.log('✅ Restored form state from sessionStorage');
              }
            } else {
              throw new Error('Invalid session data');
            }
          } catch (err) {
            // Invalid session data, use database values
            if (import.meta.env.DEV) {
              console.warn('⚠️ Invalid sessionStorage data, using database values');
            }
            formValues = dbValues;
          }
        } else {
          // No session data, use database values
          formValues = dbValues;
        }
        
        // If roll data exists but is_roll is false (stale session/legacy), force roll mode
        const hasRollData = !!(
          formValues.roll_type ||
          formValues.collection_name ||
          formValues.variant_name ||
          formValues.roll_width_value ||
          formValues.roll_length_value ||
          formValues.roll_pricing_mode
        );
        if (hasRollData && !formValues.is_roll) {
          formValues.is_roll = true;
        }
        
        // Set form values (single reset for reliability)
        reset(formValues);
        draftHydratedRef.current = true;
        
        // Note: MSRP percentages are now managed by CategoryMargins (by category)
        // CatalogItemsMSRP is auto-calculated by triggers, no need to load overrides
        
      } catch (err: any) {
        console.error('❌ Error loading item:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err.message || 'Failed to load item',
        });
      }
    }
    
    loadItem();
  }, [itemId, activeOrganizationId, setValue, sessionKey, reset]);

  // Load Supply (Supply Type + Origin) when editing
  useEffect(() => {
    if (!itemId || !activeOrganizationId) return;
    fetchCatalogItemSupply(itemId, activeOrganizationId)
      .then((data) => {
        if (data) {
          setSupplyType(data.supply_type);
          setSupplyOrigin(data.supply_origin);
        }
      })
      .catch(() => {});
  }, [itemId, activeOrganizationId]);
  
  // ✅ FIX: Persist form state to sessionStorage when editing (survives tab changes)
  useEffect(() => {
    if (!itemId || !sessionKey || !draftHydratedRef.current) return;
    
    const subscription = watch((values) => {
      if (sessionTimerRef.current) {
        window.clearTimeout(sessionTimerRef.current);
      }
      sessionTimerRef.current = window.setTimeout(() => {
        const payload = {
          values,
          productTypeIds: selectedProductTypeIds,
          savedAt: new Date().toISOString(),
        };
        window.sessionStorage.setItem(sessionKey, JSON.stringify(payload));
        if (import.meta.env.DEV) {
          console.log('💾 Saved form state to sessionStorage');
        }
      }, 300);
    });
    
    return () => {
      subscription.unsubscribe();
      if (sessionTimerRef.current) {
        window.clearTimeout(sessionTimerRef.current);
      }
    };
  }, [watch, sessionKey, selectedProductTypeIds, itemId]);
  
  // Keep unit_of_measure in sync for roll items (hidden field)
  useEffect(() => {
    if (!isRoll) return;
    const linearUoms = ['m', 'yd', 'ft'];
    const preferred = rollLengthUom || rollWidthUom || 'm';
    
    if (linearUoms.includes(preferred) && unitOfMeasure !== preferred) {
      setValue('unit_of_measure', preferred);
      return;
    }
    
    if (!linearUoms.includes(unitOfMeasure || '')) {
      setValue('unit_of_measure', 'm');
    }
  }, [isRoll, rollLengthUom, rollWidthUom, unitOfMeasure, setValue]);
  
  // ✅ FIX: Restore state when tab becomes visible again
  useOnVisibilityChange(() => {
    if (!itemId || !sessionKey || !draftHydratedRef.current) return;
    
    const sessionData = window.sessionStorage.getItem(sessionKey);
    if (sessionData) {
      try {
        const parsed = JSON.parse(sessionData);
        if (parsed?.values) {
          reset(parsed.values);
          if (Array.isArray(parsed?.productTypeIds)) {
            setSelectedProductTypeIds(parsed.productTypeIds);
          }
          if (import.meta.env.DEV) {
            console.log('✅ Restored form state from sessionStorage (tab visible)');
          }
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ Error restoring sessionStorage:', err);
        }
      }
    }
  });
  
  // Load ProductTypes relations when editing
  useEffect(() => {
    if (!itemId || !activeOrganizationId) return;
    
    async function loadProductTypeRelations() {
      try {
        const { data, error } = await supabase
          .from('CatalogItemProductTypes')
          .select('product_type_id')
          .eq('catalog_item_id', itemId)
          .eq('organization_id', activeOrganizationId);
        
        if (!error && data) {
          const ids = data.map((rel: any) => rel.product_type_id);
          setSelectedProductTypeIds(ids);
        }
      } catch (err) {
        console.warn('⚠️ Could not load ProductTypes relations (non-blocking)');
      }
    }
    
    loadProductTypeRelations();
  }, [itemId, activeOrganizationId]);

  // Load CatalogItemsMSRP for Rates tab (catalog_item_id). Backend computes; UI only reads and displays.
  useEffect(() => {
    if (!itemId || !activeOrganizationId) {
      setMsrpRow(null);
      return;
    }
    
    let isMounted = true;
    setMsrpLoading(true);
    setMsrpRow(null);
    
    (async () => {
      try {
        const { data, error } = await supabase
          .from('CatalogItemsMSRP')
          .select('dealer_price, msrp, total_cost, shipping_cost, import_tax_cost, minimum_margin_pct, msrp_pct, shipping_pct, import_tax_pct, pricing_uom, pricing_cost_exw')
          .eq('catalog_item_id', itemId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();

        if (error) throw error;

        if (isMounted && data) {
          setMsrpRow({
            dealer_price:       Number(data.dealer_price ?? 0),
            msrp:               Number(data.msrp ?? 0),
            total_cost:         Number(data.total_cost ?? 0),
            shipping_cost:      Number(data.shipping_cost ?? 0),
            import_tax_cost:    Number(data.import_tax_cost ?? 0),
            minimum_margin_pct: Number(data.minimum_margin_pct ?? 0),
            msrp_pct:           Number(data.msrp_pct ?? 0),
            shipping_pct:       Number((data as any).shipping_pct ?? 0),
            import_tax_pct:     Number((data as any).import_tax_pct ?? 0),
            pricing_uom:        (data as any).pricing_uom ?? null,
            pricing_cost_exw:   (data as any).pricing_cost_exw != null ? Number((data as any).pricing_cost_exw) : null,
          });

          // Auto-fix: CIM row exists but prices are zero → stale from UOM change.
          // Trigger recompute silently and re-fetch once done.
          if (Number(data.dealer_price ?? 0) === 0 &&
              Number((data as any).pricing_cost_exw ?? 0) === 0) {
            supabase.rpc('msrp_compute_for_item', { p_item_id: itemId })
              .then(() => { if (isMounted) setMsrpFetchKey(k => k + 1); })
              .catch(() => {});
          }
        }
      } catch (err) {
        if (import.meta.env.DEV) console.warn('⚠️ Could not load CatalogItemsMSRP:', err);
        if (isMounted) setMsrpRow(null);
      } finally {
        if (isMounted) setMsrpLoading(false);
      }
    })();

    return () => { isMounted = false; };
  }, [itemId, activeOrganizationId, msrpFetchKey]);
  
  // Load CatalogItemConversions when itemId changes
  useEffect(() => {
    loadConversions();
  }, [itemId, activeOrganizationId]);
  
  // Handle form submission
  const onSubmit = async (values: CatalogItemFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected',
      });
      return;
    }
    
    // Capture intent at submit start so navigation is correct even after async work
    const closeAfterSave = shouldCloseAfterSaveRef.current;
    
    setIsSaving(true);
    setSaveError(null);
    
    try {
      const resolveRollUnitOfMeasure = (vals: CatalogItemFormValues): string => {
        const candidate = vals.roll_length_uom || vals.roll_width_uom || 'm';
        return ['m', 'yd', 'ft'].includes(candidate) ? candidate : 'm';
      };
      
      const resolvedUnitOfMeasure = values.is_roll
        ? resolveRollUnitOfMeasure(values)
        : values.unit_of_measure;
      
      // Prepare payload - ONLY fields that exist in CatalogItems
      // For rolls: name = collection + variant (user doesn't edit name directly)
      const name = values.is_roll 
        ? `${values.collection_name || ''} ${values.variant_name || ''}`.trim() 
        : (values.name || '').trim();
      
      const payload: any = {
        sku: values.sku.trim(),
        name: name || values.sku.trim(), // Fallback to SKU if name is empty
        description: values.description?.trim() || null,
        unit_of_measure: resolvedUnitOfMeasure,
        measure_basis: values.is_roll && values.measure_basis === 'unit' ? 'linear' : values.measure_basis,
        category_id: values.category_id || null,
        image_url: values.image_url?.trim() || null,
        is_roll: values.is_roll,
        roll_type: values.is_roll ? values.roll_type : null,
        collection_name: values.is_roll ? (values.collection_name?.trim() || null) : null,
        variant_name: values.is_roll ? (values.variant_name?.trim() || null) : null,
        roll_width_value: values.is_roll && values.roll_width_value != null && values.roll_width_value > 0 ? Number(values.roll_width_value) : null,
        roll_width_uom: values.is_roll && values.roll_width_value != null && values.roll_width_value > 0 ? values.roll_width_uom : null,
        roll_length_value: values.is_roll && values.roll_length_value != null && values.roll_length_value > 0 ? Number(values.roll_length_value) : null,
        roll_length_uom: values.is_roll && values.roll_length_value != null && values.roll_length_value > 0 ? values.roll_length_uom : null,
        roll_pricing_mode: values.is_roll ? (values.roll_pricing_mode === 'per_unit' ? 'per_linear_meter' : values.roll_pricing_mode) : null,
        color: !values.is_roll ? (values.color?.trim() || null) : null,
        cost_exw: values.cost_exw != null ? Number(values.cost_exw) : null,
        purchase_unit: values.purchase_unit,
        units_per_purchase_unit: values.units_per_purchase_unit ? Number(values.units_per_purchase_unit) : 1,
        is_active: values.is_active,
      };
      
      console.log('📦 Saving CatalogItem with payload:', payload);
      
      // Defensive: derive itemId from URL if state is out of sync
      const routeMatch = window.location.pathname.match(/\/catalog\/items\/edit\/([^/]+)/);
      const routeItemId = routeMatch && routeMatch[1] ? routeMatch[1] : null;
      const effectiveItemId = itemId || routeItemId;

      let finalItemId = effectiveItemId;
      
      if (effectiveItemId) {
        // Update
        await updateItem(effectiveItemId, payload);
        finalItemId = effectiveItemId;
        // Patch bidireccional: detail + list cache (0 refetch, ERP pattern)
        const updatedItem =
          detailItem &&
          (() => {
            const base = { ...detailItem, id: effectiveItemId };
            return {
              ...base,
              sku: payload.sku,
              name: payload.name ?? base.name,
              description: payload.description ?? base.description,
              unit_of_measure: payload.unit_of_measure,
              measure_basis: payload.measure_basis as CatalogItem['measure_basis'],
              category_id: payload.category_id ?? base.category_id,
              image_url: payload.image_url ?? base.image_url,
              is_active: payload.is_active,
              cost_exw: payload.cost_exw ?? base.cost_exw,
              collection_name: payload.collection_name ?? base.collection_name,
              variant_name: payload.variant_name ?? base.variant_name,
              roll_type: payload.roll_type ?? base.roll_type,
              color: payload.color ?? base.color,
            } as CatalogItem;
          })();
        if (updatedItem) {
          queryClient.setQueryData(
            catalogItemDetailKey(scopeKey, effectiveItemId),
            updatedItem
          );
          queryClient.setQueryData(
            catalogItemsListKey(scopeKey, defaultListFilters),
            (old: CatalogItem[] | undefined) =>
              old?.map((i) => (i.id === effectiveItemId ? { ...i, ...updatedItem } : i)) ?? []
          );
        }
      } else {
        // Create
        const newItem = await createItem(payload);
        if (newItem?.id) {
          finalItemId = newItem.id;
        } else {
          throw new Error('Failed to create item');
        }
      }
      
      // Note: MSRP is calculated by triggers based on CategoryMargins (by category)
      // Trigger on CatalogItems automatically calls recompute_catalog_item_msrp() when cost_exw or category_id change
      // No need to save overrides to CatalogItemsMSRP - percentages come from CategoryMargins
      
      // Sync ProductTypes (non-blocking)
      try {
        if (selectedProductTypeIds.length > 0 && finalItemId) {
          await syncCatalogItemProductTypes(
            finalItemId,
            selectedProductTypeIds,
            null, // no primary concept in simple table
            activeOrganizationId
          );
          console.log('✅ ProductTypes synced');
        }
      } catch (ptErr) {
        console.warn('⚠️ ProductTypes sync failed (non-blocking):', ptErr);
      }

      // Upsert Supply (Supply Type + Origin) — keep existing lead_time/notes or defaults
      if (finalItemId) {
        try {
          const existing = await fetchCatalogItemSupply(finalItemId, activeOrganizationId);
          await upsertCatalogItemSupply({
            catalog_item_id: finalItemId,
            organization_id: activeOrganizationId,
            supply_type: supplyType,
            supply_origin: supplyOrigin,
            lead_time_min_days: existing?.lead_time_min_days ?? 7,
            lead_time_max_days: existing?.lead_time_max_days ?? 8,
            notes: existing?.notes ?? null,
          });
        } catch (supplyErr) {
          console.warn('⚠️ Supply upsert failed (non-blocking):', supplyErr);
        }
      }
      
      // ✅ FIX: Clear sessionStorage after successful save
      if (sessionKey) {
        window.sessionStorage.removeItem(sessionKey);
        if (import.meta.env.DEV) {
          console.log('🧹 Cleared sessionStorage after successful save');
        }
      }
      
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: itemId ? 'Item updated successfully' : 'Item created successfully',
      });
      
      // Reload conversions and normalized dimensions (triggers may take a moment) — don't block navigation on failure
      if (finalItemId) {
        try {
          await reloadConversionsWithRetry();
          
          // Reload normalized dimensions with retry
          for (let i = 0; i < 5; i++) {
            const { data: reloadedData, error } = await supabase
              .from('CatalogItems')
              .select('roll_width_m, roll_length_m')
              .eq('id', finalItemId)
              .eq('organization_id', activeOrganizationId)
              .maybeSingle();
            
            if (!error && reloadedData) {
              setRollDimensions({
                roll_width_m: reloadedData.roll_width_m ? Number(reloadedData.roll_width_m) : null,
                roll_length_m: reloadedData.roll_length_m ? Number(reloadedData.roll_length_m) : null,
              });
              break;
            }
            
            // Wait 250ms before retry
            await new Promise(r => setTimeout(r, 250));
          }
        } catch (_) {
          // Non-blocking; conversions will refresh on next visit
        }
      }
      
      // Always recompute CatalogItemsMSRP after save: covers cost_exw, UOM, measure_basis
      // and category changes. DB trigger alone is not enough for UOM/measure_basis changes.
      if (finalItemId) {
        try {
          await supabase.rpc('msrp_compute_for_item', { p_item_id: finalItemId });
        } catch (_) {
          // Non-blocking
        }
      }

      // Re-fetch CatalogItemsMSRP after save so the Rates tab shows fresh DB values.
      setTimeout(() => setMsrpFetchKey(k => k + 1), 400);

      // Navigate based on user action (use intent captured at submit start)
      shouldCloseAfterSaveRef.current = false;
      if (closeAfterSave) {
        router.navigate('/catalog/items');
      } else if (!itemId && finalItemId) {
        // For new items, navigate to edit mode preserving active tab
        const newPath = `/catalog/items/edit/${finalItemId}`;
        window.history.pushState({ activeTab }, '', newPath);
        router.navigate(newPath);
      }
      // If Save (not close) on existing item, stay on current page with same tab
      
    } catch (err: any) {
      console.error('❌ Error saving item:', err);
      const errorMsg = (() => {
        if (err?.code === '23505' || String(err?.message || '').includes('CatalogItems_organization_id_sku_key')) {
          return 'SKU already exists in this organization. Please use a unique SKU.';
        }
        return err?.message || 'Failed to save item';
      })();
      setSaveError(errorMsg);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMsg,
      });
    } finally {
      setIsSaving(false);
    }
  };
  
  // UOM options by measure basis. For Roll items with linear measure, include 'roll'.
  // Terminology: always "Roll" for roll-of-material (fabric, film, vinyl). Never "Rail" (hardware).
  const getUomOptions = (): string[] => {
    switch (measureBasis) {
      case 'unit':
        return ['ea', 'pcs', 'set', 'pair'];
      case 'linear':
        return isRoll ? ['m', 'yd', 'ft', 'roll'] : ['m', 'yd', 'ft'];
      case 'area':
        return ['m2', 'yd2', 'ft2'];
      default:
        return ['ea'];
    }
  };
  
  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {itemId ? 'Edit Item' : 'New Item'}
          </h1>
          <p className="text-xs text-gray-500">
            {itemId ? 'Edit catalog item' : 'Create a new catalog item'}
          </p>
        </div>
        
        <div className="flex items-center gap-3">
          {/* Close Button */}
          <button
            type="button"
            onClick={() => router.navigate('/catalog/items')}
            disabled={isSaving}
            className="px-4 py-1.5 rounded border border-gray-300 bg-white text-gray-700 text-sm hover:bg-gray-50 disabled:opacity-50"
          >
            Close
          </button>
          
          {/* Save Button (stay on page) */}
          <button
            type="button"
            onClick={() => {
              shouldCloseAfterSaveRef.current = false;
              handleSubmit(onSubmit, (fieldErrors) => {
                // Log each field error safely (avoid circular refs)
                const errorSummary = Object.entries(fieldErrors).map(([field, error]: [string, any]) => ({
                  field,
                  message: error?.message || error?.type || 'Invalid',
                }));
                console.error('❌ Validation errors:', errorSummary);
                useUIStore.getState().addNotification({
                  type: 'error',
                  title: 'Validation Failed',
                  message: `Errors in: ${errorSummary.map(e => e.field).join(', ')}`,
                });
              })();
            }}
            disabled={isSaving || isReadOnly}
            className="btn-save px-4 py-1.5 rounded text-white text-sm hover:opacity-90 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
          
          {/* Save and Close Button */}
          <button
            type="button"
            onClick={() => {
              shouldCloseAfterSaveRef.current = true;
              handleSubmit(onSubmit, (fieldErrors) => {
                // Log each field error safely (avoid circular refs)
                const errorSummary = Object.entries(fieldErrors).map(([field, error]: [string, any]) => ({
                  field,
                  message: error?.message || error?.type || 'Invalid',
                }));
                console.error('❌ Validation errors:', errorSummary);
                useUIStore.getState().addNotification({
                  type: 'error',
                  title: 'Validation Failed',
                  message: `Errors in: ${errorSummary.map(e => e.field).join(', ')}`,
                });
              })();
            }}
            disabled={isSaving || isReadOnly}
            className="btn-save-close px-4 py-1.5 rounded text-sm hover:opacity-90 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save & Close'}
          </button>
        </div>
      </div>
      
      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}
      
      {/* Tabs */}
      <div className="mb-6 border-b border-gray-200">
        <nav className="flex gap-6">
          <button
            onClick={() => setActiveTab('profile')}
            className={`pb-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'profile'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Profile
          </button>
          <button
            onClick={() => setActiveTab('rates')}
            className={`pb-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'rates'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Rates
          </button>
        </nav>
      </div>
      
      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <div className="grid grid-cols-12 gap-4">
          {/* SKU + Roll Item Checkbox */}
          <div className="col-span-3">
            <Label htmlFor="sku" className="text-xs" required>SKU</Label>
            <Input
              id="sku"
              {...register('sku')}
              className="py-1 text-xs w-full"
              error={errors.sku?.message}
              disabled={isReadOnly}
            />
          </div>
          
          <div className="col-span-9 flex items-end justify-between">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                {...register('is_roll')}
                className="w-4 h-4 rounded border-gray-300"
                disabled={isReadOnly}
                onChange={(e) => {
                  register('is_roll').onChange(e);
                  // Auto-configure for rolls
                  if (e.target.checked) {
                    setValue('measure_basis', 'linear');
                    if (!watch('unit_of_measure') || watch('unit_of_measure') === 'ea') {
                      setValue('unit_of_measure', 'm');
                    }
                  } else {
                    // When unchecking, switch to regular item mode but preserve roll data (hidden)
                    // User may toggle back - don't lose their work
                    setValue('measure_basis', 'unit');
                    setValue('unit_of_measure', 'ea');
                  }
                }}
              />
              <span className="text-sm font-medium text-gray-700">Roll Item</span>
              <span className="text-gray-400 ml-1" title="Roll = material en rollo. Se precio por largo (m, yd, ft) y/o por área (m², yd²)">
                <Info className="w-4 h-4 inline" />
              </span>
            </label>

            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                {...register('is_active')}
                className="h-4 w-4"
                disabled={isReadOnly}
                onChange={(e) => {
                  if (!e.target.checked) {
                    const confirmed = window.confirm('Deactivate this item?');
                    if (!confirmed) {
                      setValue('is_active', true);
                      return;
                    }
                  }
                  register('is_active').onChange(e);
                }}
              />
              <span className="text-xs font-medium">Active</span>
            </label>
          </div>
          
          {/* Name - ONLY for non-roll items */}
          {!isRoll && (
            <>
              <div className="col-span-3">
                <Label htmlFor="name" className="text-xs" required>Name</Label>
                <Input
                  id="name"
                  {...register('name')}
                  className="py-1 text-xs w-full"
                  error={errors.name?.message}
                  disabled={isReadOnly}
                />
              </div>
              
              <div className="col-span-3">
                <Label htmlFor="color" className="text-xs">Color</Label>
                <Input
                  id="color"
                  {...register('color')}
                  className="py-1 text-xs w-full"
                  disabled={isReadOnly}
                />
              </div>
              
              <div className="col-span-6" />
            </>
          )}

          {/* Description - non-roll (match Roll Item layout) */}
          {!isRoll && (
            <>
              <div className="col-span-6">
                <Label htmlFor="description" className="text-xs">Description</Label>
                <textarea
                  id="description"
                  {...register('description')}
                  className="w-full border border-gray-300 rounded px-3 py-1.5 text-xs"
                  rows={3}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-6" />
            </>
          )}
          
          {/* Collection + Variant - ONLY for roll items */}
          {isRoll && (
            <>
              <div className="col-span-3">
                <Label htmlFor="collection_name" className="text-xs" required>Collection Name</Label>
                <Input
                  id="collection_name"
                  {...register('collection_name')}
                  className="py-1 text-xs w-full"
                  placeholder="e.g., Sunbrella, Dickson, Serge Ferrari"
                  error={errors.collection_name?.message}
                  disabled={isReadOnly}
                />
              </div>
              
              <div className="col-span-3">
                <Label htmlFor="variant_name" className="text-xs" required>Variant Name (Color)</Label>
                <Input
                  id="variant_name"
                  {...register('variant_name')}
                  className="py-1 text-xs w-full"
                  placeholder="e.g., White 118.11'', Beige Natural"
                  error={errors.variant_name?.message}
                  disabled={isReadOnly}
                />
              </div>

              {/* Keep the right side empty so these align with Category / Roll Type columns */}
              <div className="col-span-6" />
            </>
          )}

          {/* Description - move ABOVE Category row for rolls (ends at Roll Type right edge) */}
          {isRoll && (
            <>
              <div className="col-span-6">
                <Label htmlFor="description" className="text-xs">Description</Label>
                <textarea
                  id="description"
                  {...register('description')}
                  className="w-full border border-gray-300 rounded px-3 py-1.5 text-xs"
                  rows={3}
                  disabled={isReadOnly}
                />
              </div>
              <div className="col-span-6" />
            </>
          )}
          
          {/* Category - Always visible */}
          <div className="col-span-3">
            <Label htmlFor="category_id" className="text-xs">Category</Label>
            <SelectShadcn
              value={watch('category_id') || '__none__'}
              onValueChange={(value) => setValue('category_id', value === '__none__' ? null : value)}
              disabled={isReadOnly || catalogCategoriesLoading}
            >
              <SelectTrigger className="h-auto py-1 text-xs w-1/2">
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">None</SelectItem>
                {catalogCategories.map((cat) => (
                  <SelectItem key={cat.id} value={cat.id}>
                    {cat.path}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          {/* Measure Basis + Unit of Measure (non-roll) - Measure Basis in the middle of the row */}
          {!isRoll && (
            <>
              <div className="col-span-3">
                <Label htmlFor="measure_basis" className="text-xs" required>Measure Basis</Label>
                <SelectShadcn
                  value={watch('measure_basis')}
                  onValueChange={(value) => setValue('measure_basis', value as 'unit' | 'linear' | 'area')}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="unit">Unit (each)</SelectItem>
                    <SelectItem value="linear">Linear (length)</SelectItem>
                    <SelectItem value="area">Area (m²)</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>

              <div className="col-span-3">
                <Label htmlFor="unit_of_measure" className="text-xs" required>Unit of Measure</Label>
                <SelectShadcn
                  value={watch('unit_of_measure')}
                  onValueChange={(value) => setValue('unit_of_measure', value)}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {getUomOptions().map((uom) => (
                      <SelectItem key={uom} value={uom}>{uom === 'roll' ? 'Roll' : uom}</SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>

              <div className="col-span-3" />
            </>
          )}
          
          {/* Roll Type - Only for rolls */}
          {isRoll && (
            <div className="col-span-3">
              <Label htmlFor="roll_type" className="text-xs" required>Roll Type</Label>
              <SelectShadcn
                value={watch('roll_type') || ''}
                onValueChange={(value) => setValue('roll_type', value as any)}
                disabled={isReadOnly}
              >
                <SelectTrigger className="h-auto py-1 text-xs w-full">
                  <SelectValue placeholder="Select type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="fabric">Fabric</SelectItem>
                  <SelectItem value="window_film">Window Film</SelectItem>
                  <SelectItem value="vinyl">Vinyl</SelectItem>
                  <SelectItem value="mesh">Mesh</SelectItem>
                  <SelectItem value="paper">Paper</SelectItem>
                  <SelectItem value="other">Other</SelectItem>
                </SelectContent>
              </SelectShadcn>
              {errors.roll_type && <p className="text-xs text-red-600 mt-1">{errors.roll_type.message}</p>}
            </div>
          )}
          
          {/* Roll Pricing Mode - Only for rolls (per_linear_meter / per_square_meter; per_unit legacy removed) */}
          {isRoll && (
            <div className="col-span-3">
              <Label htmlFor="roll_pricing_mode" className="text-xs">Roll Pricing Mode</Label>
              <SelectShadcn
                value={watch('roll_pricing_mode') === 'per_unit' ? 'per_linear_meter' : (watch('roll_pricing_mode') || '')}
                onValueChange={(value) => setValue('roll_pricing_mode', value as 'per_linear_meter' | 'per_square_meter')}
                disabled={isReadOnly}
              >
                <SelectTrigger className="h-auto py-1 text-xs w-full">
                  <SelectValue placeholder="Select mode" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="per_linear_meter">Per Linear Meter ($/m)</SelectItem>
                  <SelectItem value="per_square_meter">Per Square Meter ($/m²)</SelectItem>
                </SelectContent>
              </SelectShadcn>
              {errors.roll_pricing_mode && (
                <p className="text-xs text-red-600 mt-1">{errors.roll_pricing_mode.message}</p>
              )}
            </div>
          )}

          {/* Measure Basis - Only for rolls (linear/area only; unit not valid for rolls) */}
              {isRoll && (
            <div className="col-span-3">
              <Label htmlFor="measure_basis" className="text-xs" required>Measure Basis</Label>
              <SelectShadcn
                value={watch('measure_basis') === 'unit' ? 'linear' : watch('measure_basis')}
                onValueChange={(value) => setValue('measure_basis', value as 'linear' | 'area')}
                disabled={isReadOnly}
              >
                <SelectTrigger className="h-auto py-1 text-xs w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="linear">Linear (length)</SelectItem>
                  <SelectItem value="area">Area (m²)</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
          )}
          
          {/* Roll Width | Roll Length - New row right after Category */}
          {isRoll ? (
            <>
              <div className="col-span-6">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="roll_width_value" className="text-xs" required>Roll Width</Label>
                    <div className="flex gap-2">
                      <Input
                        id="roll_width_value"
                        type="number"
                        step="0.01"
                        min="0"
                        {...register('roll_width_value', { valueAsNumber: true })}
                        className="py-1 text-xs w-40"
                        placeholder="e.g., 1.37 or 60"
                        disabled={isReadOnly}
                      />
                      <SelectShadcn
                        value={watch('roll_width_uom') || 'm'}
                        onValueChange={(value) => setValue('roll_width_uom', value as any)}
                        disabled={isReadOnly}
                      >
                        <SelectTrigger className="h-auto py-1 text-xs w-6">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="m">m</SelectItem>
                          <SelectItem value="yd">yd</SelectItem>
                          <SelectItem value="ft">ft</SelectItem>
                          <SelectItem value="in">in</SelectItem>
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                    {errors.roll_width_value && (
                      <p className="text-xs text-red-600 mt-1">{errors.roll_width_value.message}</p>
                    )}
                    {rollDimensions.roll_width_m != null && (
                      <p className="text-xs text-gray-500 mt-1">= {rollDimensions.roll_width_m.toFixed(2)} m</p>
                    )}
                  </div>
                  
                  <div>
                    <Label htmlFor="roll_length_value" className="text-xs" required>Roll Length</Label>
                    <div className="flex gap-2">
                      <Input
                        id="roll_length_value"
                        type="number"
                        step="0.01"
                        min="0"
                        {...register('roll_length_value', { valueAsNumber: true })}
                        className="py-1 text-xs w-40"
                        placeholder="e.g., 30 or 100"
                        disabled={isReadOnly}
                      />
                      <SelectShadcn
                        value={watch('roll_length_uom') || 'm'}
                        onValueChange={(value) => setValue('roll_length_uom', value as any)}
                        disabled={isReadOnly}
                      >
                        <SelectTrigger className="h-auto py-1 text-xs w-6">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="m">m</SelectItem>
                          <SelectItem value="yd">yd</SelectItem>
                          <SelectItem value="ft">ft</SelectItem>
                          <SelectItem value="in">in</SelectItem>
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                    {errors.roll_length_value && (
                      <p className="text-xs text-red-600 mt-1">{errors.roll_length_value.message}</p>
                    )}
                    {rollDimensions.roll_length_m != null && (
                      <p className="text-xs text-gray-500 mt-1">= {rollDimensions.roll_length_m.toFixed(2)} m</p>
                    )}
                  </div>
                </div>
              </div>
              
              <div className="col-span-6" />
            </>
          ) : null}

          {/* Specs - ONLY for roll items (below Roll Width/Length row) */}
          {isRoll && (
            <>
              <div className="col-span-6 mt-2 pt-4 border-t border-gray-200">
                {!itemId || !activeOrganizationId ? (
                  <div className="bg-amber-50 border border-amber-200 rounded p-3">
                    <p className="text-xs text-amber-800">Save the item first to edit specs.</p>
                  </div>
                ) : (
                  <CatalogItemRollSpecsSection
                    catalogItemId={itemId}
                    organizationId={activeOrganizationId}
                    readOnly={isReadOnly}
                  />
                )}
              </div>
              <div className="col-span-6 mt-2 pt-4 border-t border-gray-200" />
            </>
          )}
          
          {/* Supply Type + Origin — one row, before Product Types / Image (edit only) */}
          {itemId && activeOrganizationId && (
            <>
              <div className="col-span-3">
                <Label className="text-xs">Supply Type</Label>
                <SelectShadcn
                  value={supplyType}
                  onValueChange={(v) => setSupplyType(v as SupplyType)}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="stock">Stock</SelectItem>
                    <SelectItem value="order">To order</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
              <div className="col-span-3">
                <Label className="text-xs">Origin</Label>
                <SelectShadcn
                  value={supplyOrigin}
                  onValueChange={(v) => setSupplyOrigin(v as SupplyOrigin)}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="local">Local</SelectItem>
                    <SelectItem value="import">Import</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
            </>
          )}

          {/* Product Types */}
          <div className="col-span-12">
            <Label className="text-xs">Product Types</Label>
            {productTypesLoading ? (
              <p className="text-xs text-gray-500 mt-2">Loading...</p>
            ) : productTypes.length === 0 ? (
              <p className="text-xs text-gray-500 mt-2">No product types available</p>
            ) : (
              <div className="mt-2 border border-gray-200 rounded p-3">
                <div className="grid grid-cols-3 gap-2">
                  {productTypes.map((pt) => (
                    <label key={pt.id} className="flex items-center gap-2 text-xs">
                      <input
                        type="checkbox"
                        checked={selectedProductTypeIds.includes(pt.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedProductTypeIds([...selectedProductTypeIds, pt.id]);
                          } else {
                            setSelectedProductTypeIds(selectedProductTypeIds.filter(id => id !== pt.id));
                          }
                        }}
                        disabled={isReadOnly}
                        className="h-4 w-4"
                      />
                      <span>{pt.name} {pt.code && `(${pt.code})`}</span>
                    </label>
                  ))}
                </div>
              </div>
            )}
          </div>
          
          {/* Image (Drop) */}
          <div className="col-span-12">
            <Label className="text-xs">Image</Label>
            <ImageUpload
              label="Item Image"
              currentImageUrl={watch('image_url') || null}
              onImageUploaded={(url) => setValue('image_url', url ?? null)}
              disabled={isReadOnly}
              bucket="catalog-images"
              uploadPath={(file) => {
                const ext = file.name.split('.').pop() || 'png';
                const prefix = activeOrganizationId
                  ? `catalog-items/${activeOrganizationId}/${itemId || 'new'}`
                  : `catalog-items/new`;
                return `${prefix}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
              }}
            />
          </div>
          
          {/* Purchase Unit Fields (for unit items only - procurement/inventory) */}
          {watch('measure_basis') === 'unit' && !isRoll && (
            <>
              <div className="col-span-3">
                <Label htmlFor="purchase_unit" className="text-xs">Purchase Unit</Label>
                <SelectShadcn
                  value={watch('purchase_unit') || 'each'}
                  onValueChange={(value) => setValue('purchase_unit', value as any)}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="each">Each</SelectItem>
                    <SelectItem value="pack">Pack</SelectItem>
                    <SelectItem value="set">Set</SelectItem>
                    <SelectItem value="box">Box</SelectItem>
                    <SelectItem value="case">Case</SelectItem>
                  </SelectContent>
                </SelectShadcn>
                <p className="text-xs text-gray-500 mt-1">How you purchase from supplier</p>
              </div>
              
              <div className="col-span-3">
                <Label htmlFor="units_per_purchase_unit" className="text-xs">Units per Purchase</Label>
                <Input
                  id="units_per_purchase_unit"
                  type="number"
                  step="1"
                  min="1"
                  {...register('units_per_purchase_unit', { valueAsNumber: true })}
                  className="py-1 text-xs w-full"
                  disabled={isReadOnly}
                />
                <p className="text-xs text-gray-500 mt-1">
                  {watch('purchase_unit') === 'pack' && 'Units per pack (e.g., 12)'}
                  {watch('purchase_unit') === 'set' && 'Units per set (e.g., 6)'}
                  {watch('purchase_unit') === 'box' && 'Units per box (e.g., 24)'}
                  {watch('purchase_unit') === 'case' && 'Units per case (e.g., 100)'}
                  {watch('purchase_unit') === 'each' && 'Always 1 for each'}
                </p>
              </div>
              
              <div className="col-span-6" />
            </>
          )}
        </div>
      )}
      
      {/* Rates Tab */}
      {activeTab === 'rates' && (
        <div className="grid grid-cols-12 gap-6">
          {/* Header */}
          <div className="col-span-12">
            <h3 className="text-sm font-semibold">Pricing & Rates</h3>
          </div>
          
          {/* BASE PRICE (Left) - Editable */}
          <div className="col-span-12 lg:col-span-6">
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 h-full">
              <h4 className="text-sm font-semibold text-gray-700 mb-3">Base Price (Editable)</h4>
              
              <div className="space-y-3">
                {/* Cost EXW Input */}
                <div>
                  <Label htmlFor="cost_exw_rate" className="text-xs">Cost EXW (per unit)</Label>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-sm text-gray-600">$</span>
                    <Input
                      id="cost_exw_rate"
                      type="number"
                      step="0.01"
                      min="0"
                      {...register('cost_exw', { valueAsNumber: true })}
                      className="flex-1 text-sm"
                      placeholder="0.00"
                      disabled={isReadOnly}
                    />
                  </div>
                </div>
                
                {/* Current Value Display */}
                {watch('cost_exw') && watch('unit_of_measure') && (
                  <div className="space-y-2">
                    <div className="bg-white border border-gray-300 rounded px-3 py-2">
                      <p className="text-xs text-gray-600">Price per Unit:</p>
                      <p className="text-lg font-semibold text-gray-900">
                        ${Number(watch('cost_exw')).toFixed(2)}/{watch('unit_of_measure') || 'ea'}
                      </p>
                    </div>
                    
                    {/* Show price per pack/set/box if applicable */}
                    {watch('purchase_unit') && watch('purchase_unit') !== 'each' && watch('units_per_purchase_unit') && Number(watch('units_per_purchase_unit')) > 1 && (
                      <div className="bg-blue-50 border border-blue-300 rounded px-3 py-2">
                        <p className="text-xs text-blue-700">Price per {watch('purchase_unit')}:</p>
                        <p className="text-xl font-bold text-blue-900">
                          ${(Number(watch('cost_exw')) * Number(watch('units_per_purchase_unit'))).toFixed(2)}/{watch('purchase_unit')}
                        </p>
                        <p className="text-xs text-gray-600 mt-1">
                          {Number(watch('units_per_purchase_unit'))} units × ${Number(watch('cost_exw')).toFixed(2)}/ea
                        </p>
                      </div>
                    )}
                  </div>
                )}
                
                {/* Roll Dimensions (for rolls only) */}
                {watch('is_roll') && (
                  <div className="mt-4 pt-4 border-t border-blue-300">
                    <h5 className="text-xs font-semibold text-gray-700 mb-2">Roll Dimensions</h5>
                    <div className="grid grid-cols-2 gap-3">
                      {rollDimensions.roll_width_m != null && (
                        <div className="bg-white border border-gray-300 rounded px-3 py-2">
                          <p className="text-xs text-gray-600">Roll Width:</p>
                          <p className="text-sm font-semibold text-gray-900">
                            {rollDimensions.roll_width_m.toFixed(2)} m
                          </p>
                        </div>
                      )}
                      {rollDimensions.roll_length_m != null && (
                        <div className="bg-white border border-gray-300 rounded px-3 py-2">
                          <p className="text-xs text-gray-600">Roll Length:</p>
                          <p className="text-sm font-semibold text-gray-900">
                            {rollDimensions.roll_length_m.toFixed(2)} m
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* CONVERSIONS (Right) - Read-only - Only for rolls and linear/area items */}
          {(watch('is_roll') || watch('measure_basis') === 'linear' || watch('measure_basis') === 'area') && (
            <div className="col-span-12 lg:col-span-6">
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 h-full">
                <h4 className="text-sm font-semibold text-gray-700 mb-3">Conversions (Read-only)</h4>
                
                {conversionsLoading ? (
                  <div className="flex items-center gap-2">
                    <div className="animate-spin h-4 w-4 border-2 border-gray-400 border-t-transparent rounded-full"></div>
                    <p className="text-xs text-gray-500">Loading conversions...</p>
                  </div>
                ) : !itemId ? (
                  <div className="bg-amber-50 border border-amber-200 rounded p-3">
                    <p className="text-xs text-amber-800">
                      💾 Save the item first to see conversions.
                    </p>
                  </div>
                ) : !conversions ? (
                <div className="bg-amber-50 border border-amber-200 rounded p-3">
                  <p className="text-xs text-amber-800">
                    ⏳ No conversions available yet.
                  </p>
                  <p className="text-xs text-gray-700 mt-1">
                    Make sure <strong>cost_exw</strong> and <strong>unit_of_measure</strong> are set, then save.
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  {/* Per Linear Meter (for rolls and linear items) */}
                  {normalizedCostExwPerM != null && (
                    <div className="bg-blue-50 border border-blue-200 rounded px-3 py-2">
                      <p className="text-xs text-gray-700">Per Linear Meter:</p>
                      <p className="text-lg font-semibold text-gray-900">
                        ${normalizedCostExwPerM.toFixed(2)}/m
                      </p>
                    </div>
                  )}
                  
                  {/* Per Square Meter (for rolls with width, or area items) */}
                  {(watch('is_roll') || watch('measure_basis') === 'area') && normalizedCostExwPerM2 != null && (
                    <div className="bg-blue-50 border border-blue-200 rounded px-3 py-2">
                      <p className="text-xs text-gray-700">Per Square Meter:</p>
                      <p className="text-lg font-semibold text-gray-900">
                        ${normalizedCostExwPerM2.toFixed(2)}/m²
                      </p>
                    </div>
                  )}
                  
                  {/* Warning if roll without roll_width */}
                  {watch('is_roll') && normalizedCostExwPerM2 == null && normalizedCostExwPerM != null && (
                    <div className="bg-amber-50 border border-amber-200 rounded px-2 py-1.5">
                      <p className="text-xs text-amber-700">
                        Set <strong>Roll Width</strong> in Profile tab to calculate $/m²
                      </p>
                    </div>
                  )}
                  
                  {/* Cost per Full Roll - using normalized values */}
                  {watch('is_roll') && (
                    fullRollCost != null ? (
                      <div className="bg-blue-50 border border-blue-300 rounded px-3 py-2">
                        <p className="text-xs text-gray-700">Cost per Full Roll:</p>
                        <p className="text-xl font-bold text-gray-900">
                          ${fullRollCost.toFixed(2)}/roll
                        </p>
                        <p className="text-xs text-gray-600 mt-1">
                          {rollLengthM != null && normalizedCostExwPerM != null
                            ? `${rollLengthM.toFixed(2)} m × $${normalizedCostExwPerM.toFixed(2)}/m`
                            : ''}
                        </p>
                      </div>
                    ) : (
                      <div className="bg-amber-50 border border-amber-200 rounded px-3 py-2">
                        <p className="text-xs text-amber-700">Cost per Full Roll:</p>
                        <p className="text-sm text-amber-800">
                          💾 Save to calculate full roll cost
                        </p>
                      </div>
                    )
                  )}
                  
                  <p className="text-xs text-gray-400 pt-2 border-t border-gray-200">
                    Last calculated: {new Date(conversions.computed_at || '').toLocaleString()}
                  </p>
                </div>
              )}
              </div>
            </div>
          )}
          
          
          {/* MSRP: read-only from CatalogItemsMSRP — normalized by roll_pricing_mode (per m, per m², or per ea) */}
          <div className="col-span-12 mt-6">
            <h3 className="text-sm font-semibold mb-3">MSRP</h3>
            {!itemId ? (
              <p className="text-xs text-gray-500 bg-amber-50 border border-amber-200 rounded p-3">
                Save the item first to see MSRP. Values are computed in the backend when cost and category are set.
              </p>
            ) : msrpLoading ? (
              <p className="text-xs text-gray-500">Loading MSRP…</p>
            ) : msrpRow ? (
              (() => {
                // Show live preview when dirty, otherwise DB values
                const display = liveMsrp ?? msrpRow;
                const isLive = !!liveMsrp;
                return (
                  <div className="space-y-3">
                    {/* Porcentajes afuera del bar */}
                    <div className="grid grid-cols-2 gap-4 text-xs max-w-xs">
                      <div>
                        <p className="font-medium text-gray-700">Minimum Margin</p>
                        <p className="text-lg font-semibold text-purple-600">
                          {(display.minimum_margin_pct * 100).toFixed(2)}%
                        </p>
                        <p className="text-xs text-gray-500 mt-1">From category</p>
                      </div>
                      <div>
                        <p className="font-medium text-gray-700">MSRP % Sale Out</p>
                        <p className="text-lg font-semibold text-primary">
                          {(display.msrp_pct * 100).toFixed(2)}%
                        </p>
                        <p className="text-xs text-gray-500 mt-1">From category</p>
                      </div>
                    </div>
                    {/* Bar: Shipping Cost | Import Tax | Total Cost | Dealer Price | MSRP */}
                    <div className="bg-blue-50 border border-blue-200 rounded p-4">
                      {isLive && (
                        <p className="text-xs text-gray-500 mb-3">⚡ Preview — save to persist</p>
                      )}
                      <div className="grid grid-cols-2 sm:grid-cols-5 gap-4 text-xs">
                        <div>
                          <p className="font-medium text-gray-700">Shipping Cost</p>
                          <p className="text-lg font-semibold">${display.shipping_cost.toFixed(2)}{msrpUnitLabel}</p>
                        </div>
                        <div>
                          <p className="font-medium text-gray-700">Import Tax</p>
                          <p className="text-lg font-semibold">${display.import_tax_cost.toFixed(2)}{msrpUnitLabel}</p>
                        </div>
                        <div>
                          <p className="font-medium text-gray-700">Total Cost</p>
                          <p className="text-lg font-semibold">${display.total_cost.toFixed(2)}{msrpUnitLabel}</p>
                        </div>
                        <div>
                          <p className="font-medium text-gray-700">Dealer Price</p>
                          <p className="text-lg font-semibold text-green-600">${display.dealer_price.toFixed(2)}{msrpUnitLabel}</p>
                        </div>
                        <div>
                          <p className="font-medium text-gray-700">MSRP (Retail)</p>
                          <p className="text-lg font-semibold text-primary">${display.msrp.toFixed(2)}{msrpUnitLabel}</p>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })()
            ) : (
              <p className="text-xs text-gray-500 bg-amber-50 border border-amber-200 rounded p-3">
                MSRP will be calculated by the system when cost and category are set. Recompute runs on save via triggers.
              </p>
            )}
          </div>
        </div>
      )}

    </div>
  );
}
