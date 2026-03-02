import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export type BOMQtyType = 'fixed' | 'per_width' | 'per_height' | 'per_area' | 'by_option';
export type SKUResolutionRule = 'EXACT_SKU' | 'SKU_SUFFIX_COLOR' | 'ROLE_AND_COLOR' | string;
export type HardwareColor = 'none' | 'white' | 'black' | 'silver' | 'bronze' | 'grey' | string;

export interface BOMComponent {
  id: string;
  organization_id: string;
  parent_item_id?: string | null; // Deprecated: use bom_template_id instead
  parent_component_id?: string | null;
  bom_template_id?: string | null; // New: FK to BOMTemplates
  slot_id?: string | null; // Override scope: BOMTemplateSlots.id
  component_scope?: 'template' | 'bom' | null;
  component_item_id?: string | null; // Can be null for auto-select components (fabric, etc.)
  component_role?: string | null; // Role of component (fabric, tube, bracket, etc.)
  component_sub_role?: string | null; // Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)
  auto_select?: boolean; // Whether component is auto-selected by rules
  uom: string;
  is_required: boolean;
  sort_order: number;
  metadata?: Record<string, any> | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  // Auto-select fields
  select_rule?: Record<string, any> | null; // JSONB rule for selecting part
  sku_resolution_rule?: SKUResolutionRule | null; // Rule for resolving SKU
  hardware_color?: HardwareColor | null; // Hardware color (white, black, silver, bronze, grey)
  block_condition?: Record<string, any> | null; // JSONB condition for block activation
  block_type?: string | null; // Type of BOM block: drive, brackets, bottom_rail, cassette, side_channel
  applies_color?: boolean; // Whether this component color depends on hardware_color selection
  qty_type?: BOMQtyType | null; // Quantity type: fixed, per_width, per_area, by_option
  qty_value?: number | null; // Quantity value (for fixed: count, for per_width/per_area: multiplier)
  // Engineering fields
  depends_on_role?: string | null; // Role this component depends on (for cut rules)
  affects_role?: string | null; // Role that this component affects (for cut operations)
  cut_axis?: string | null; // Cut axis: none, width, height, length
  cut_delta_mm?: number | null; // Cut delta in mm
  cut_delta_scope?: string | null; // Cut delta scope: per_side, per_item
  // Engineering v1.5 metadata (future-proof for dynamic delta resolution)
  engineering_delta_source?: 'fixed' | 'derived' | null;
  engineering_attr_key?: string | null;
  engineering_scope?: 'total' | 'per_side' | null;
  engineering_source_role?: string | null;
  // Joined data
  component_sku?: string;
  component_name?: string;
  component_cost_exw?: number;
  component_category_id?: string;
  component_category_name?: string;
  component_is_fabric?: boolean;
  component_collection_name?: string;
  component_variant_name?: string;
}

export interface BOMPriceCalculation {
  component_item_id: string;
  component_sku: string;
  component_name: string;
  qty_needed: number;
  uom: string;
  unit_cost_exw: number;
  extended_cost: number;
  category_id: string | null;
  category_name: string | null;
  is_fabric: boolean;
  collection_name: string | null;
  variant_name: string | null;
}

/**
 * Hook to fetch BOM components for a BOM template
 */
export function useBOMComponents(bomTemplateId: string | null) {
  const [components, setComponents] = useState<BOMComponent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    // ✅ FIX: Early return guard to prevent unnecessary fetches
    if (!bomTemplateId || !activeOrganizationId) {
      setLoading(false);
      setComponents([]);
      setError(null);
      return;
    }

    // ✅ FIX: Add logging (DEV-only)
    if (import.meta.env.DEV) {
      console.log('[useBOMComponents] Fetching components', {
        bomTemplateId,
        activeOrganizationId,
        requestId: `${bomTemplateId}-${Date.now()}`,
      });
    }

    async function fetchBOMComponents() {
      try {
        setLoading(true);
        setError(null);

        // ✅ FIX: Skip fetch if already cleared (guard against race conditions)
        if (!bomTemplateId || !activeOrganizationId) {
          return;
        }

        // Fetch BOMComponents separately to avoid join issues
        const { data: bomComponentsData, error: fetchError } = await supabase
          .from('BOMComponents')
          .select(`
            *,
            component_item:component_item_id (
              id,
              sku,
              name
            )
          `)
          .eq('bom_template_id', bomTemplateId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('parent_component_id', { ascending: true })
          .order('sort_order', { ascending: true })
          .order('created_at', { ascending: true });

        if (fetchError) {
        // ✅ FIX: Don't retry on 404/400 errors
        if (fetchError.code === 'PGRST116' || fetchError.code === '42P01' || 
            fetchError.message?.includes('does not exist')) {
          if (import.meta.env.DEV) {
            console.warn('[useBOMComponents] Client error (not retrying):', fetchError.code, fetchError.message);
          }
          setError(null); // Don't show error for expected 404s
          setComponents([]);
          setLoading(false);
          return;
        }
          // ✅ FIX: Formatear error para evitar "[circular]"
          const errorDetails = { 
            message: fetchError.message, 
            code: fetchError.code,
            details: fetchError.details 
          };
          console.error('❌ Error fetching BOM components:', errorDetails);
          // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
          throw new Error(fetchError.message || 'Error fetching BOM components');
        }

        console.log('📦 Fetched BOM components from DB:', bomComponentsData?.length || 0, 'components');
        console.log('📦 BOM components data:', bomComponentsData);

        if (!bomComponentsData || bomComponentsData.length === 0) {
          console.log('⚠️ No BOM components found in database');
          setComponents([]);
          return;
        }

        // Get all unique component_item_ids (filter out nulls - these are auto-select components)
        // Auto-select components (like fabric) don't have component_item_id until resolved
        const componentItemIds = [...new Set(
          bomComponentsData
            .map((comp: any) => comp.component_item_id)
            .filter((id: string | null) => id !== null)
        )];

        // Fetch CatalogItems separately
        let catalogItemsMap = new Map<string, any>();
        if (componentItemIds.length > 0) {
          const { data: catalogItemsData } = await supabase
            .from('CatalogItems')
            .select('*')
            .in('id', componentItemIds)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          if (catalogItemsData) {
            catalogItemsMap = new Map(catalogItemsData.map((item: any) => [item.id, item]));
          }
        }

        // Get all unique category_ids
        const categoryIds = [...new Set(
          Array.from(catalogItemsMap.values())
            .map((item: any) => item.item_category_id)
            .filter((id: string | null) => id !== null)
        )];

        // Fetch ItemCategories separately
        let categoriesMap = new Map<string, any>();
        if (categoryIds.length > 0) {
          const { data: categoriesData } = await supabase
            .from('ItemCategories')
            .select('*')
            .in('id', categoryIds)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          if (categoriesData) {
            categoriesMap = new Map(categoriesData.map((cat: any) => [cat.id, cat]));
          }
        }

        // Map the data to include joined component information
        // Note: Components with auto_select=true and component_item_id=null won't have catalog item data
        // These will be resolved dynamically during BOM generation
        const mappedComponents: BOMComponent[] = (bomComponentsData || []).map((item: any) => {
          const catalogItem = item.component_item_id ? catalogItemsMap.get(item.component_item_id) : null;
          const category = catalogItem ? categoriesMap.get(catalogItem.item_category_id) : null;

          return {
            ...item,
            component_sku: catalogItem?.sku || (item.auto_select ? 'Auto-selected' : null),
            component_name: catalogItem?.item_name || (item.component_role ? `${item.component_role} (auto-select)` : null),
            component_cost_exw: catalogItem?.cost_exw,
            component_category_id: catalogItem?.item_category_id,
            component_category_name: category?.name,
            component_category_code: category?.code,
            component_is_fabric: catalogItem?.is_fabric,
            component_collection_name: catalogItem?.collection_name,
            component_variant_name: catalogItem?.variant_name,
          };
        });

        console.log('✅ Mapped BOM components:', mappedComponents.length, 'components');
        setComponents(mappedComponents);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading BOM components';
        setError(errorMessage);
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = err instanceof Error 
          ? { message: err.message, name: err.name, stack: err.stack }
          : typeof err === 'object' && err !== null
          ? { message: (err as any).message || String(err), code: (err as any).code, details: (err as any).details }
          : String(err);
        console.error('❌ Error fetching BOM components:', errorDetails);
      } finally {
        setLoading(false);
      }
    }

    fetchBOMComponents();
    
    // ✅ FIX: Cleanup function to prevent state updates after unmount
    return () => {
      // Cancel any pending requests if component unmounts
    };
  }, [bomTemplateId, activeOrganizationId]);

  return { components, loading, error };
}

/**
 * Hook to calculate BOM price for a parent item with dimensions
 */
export function useCalculateBOMPrice() {
  const [calculating, setCalculating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const calculatePrice = async (
    parentItemId: string,
    widthM?: number | null,
    heightM?: number | null,
    areaSqm?: number | null
  ): Promise<BOMPriceCalculation[]> => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setCalculating(true);
    try {
      const { data, error } = await supabase.rpc('calculate_bom_price', {
        p_parent_item_id: parentItemId,
        p_organization_id: activeOrganizationId,
        p_width_m: widthM || null,
        p_height_m: heightM || null,
        p_area_sqm: areaSqm || null,
      });

      if (error) {
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error calculating BOM price');
      }

      return (data || []) as BOMPriceCalculation[];
    } catch (err) {
      if (import.meta.env.DEV) {
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = err instanceof Error 
          ? { message: err.message, name: err.name }
          : typeof err === 'object' && err !== null
          ? { message: (err as any).message || String(err), code: (err as any).code, details: (err as any).details }
          : String(err);
        console.error('Error calculating BOM price:', errorDetails);
      }
      throw err;
    } finally {
      setCalculating(false);
    }
  };

  return { calculatePrice, calculating };
}

/**
 * Hook for BOM CRUD operations
 */
export function useBOMCRUD() {
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createComponent = async (componentData: Omit<BOMComponent, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    // ✅ FIX: Fallback a localStorage si activeOrganizationId no está disponible
    let orgIdToUse = activeOrganizationId;
    if (!orgIdToUse) {
      const storedOrgId = localStorage.getItem('activeOrganizationId');
      if (storedOrgId) {
        orgIdToUse = storedOrgId;
        if (import.meta.env.DEV) {
          console.warn('[useBOM] Using organizationId from localStorage as fallback:', storedOrgId);
        }
      }
    }
    
    if (!orgIdToUse) {
      throw new Error('No organization available. Please refresh the page or contact support.');
    }

    if (!componentData.bom_template_id && !componentData.parent_item_id) {
      throw new Error('Either bom_template_id or parent_item_id is required');
    }

    // ✅ MVP: Validación de campos requeridos
    // ✅ FIX: component_item_id puede ser null para componentes auto-select (fabric, etc.)
    // if (!componentData.component_item_id) {
    //   throw new Error('component_item_id is required');
    // }
    if (!componentData.component_role) {
      throw new Error('component_role is required');
    }
    if (!componentData.qty_type) {
      throw new Error('qty_type is required (fixed, per_width, or per_area)');
    }
    if (componentData.qty_type === 'fixed' && (!componentData.qty_value || componentData.qty_value <= 0)) {
      throw new Error('qty_value is required and must be > 0 when qty_type is fixed');
    }
    if (!componentData.uom) {
      throw new Error('uom is required');
    }

    setIsCreating(true);
    try {
      // ✅ MVP: Forzar auto_select=false siempre
      const payload = {
        ...componentData,
        organization_id: orgIdToUse,
        auto_select: false, // MVP: siempre false
        // BOMComponents.qty_value is NOT NULL in DB (use 1 as safe default)
        qty_value: componentData.qty_value || 1,
        deleted: false,
        archived: false,
      };

      // ✅ MVP: Logging para debugging
      if (import.meta.env.DEV) {
        console.log('[useBOM] SAVE BOM COMPONENT payload:', payload);
      }

      const { data, error } = await supabase
        .from('BOMComponents')
        .insert(payload)
        .select()
        .single();

      if (error) {
        // ✅ MVP: Logging de errores visible
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = { 
          message: error.message, 
          code: error.code,
          details: error.details,
          hint: error.hint 
        };
        console.error('[useBOM] SAVE BOM COMPONENT error:', errorDetails);
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error saving BOM component');
      }

      if (import.meta.env.DEV) {
        console.log('[useBOM] SAVE BOM COMPONENT success:', data);
      }

      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateComponent = async (id: string, updates: Partial<BOMComponent>) => {
    setIsUpdating(true);
    try {
      // ✅ Prefer activeOrganizationId, fallback to localStorage
      let orgIdToUse = activeOrganizationId;
      if (!orgIdToUse) {
        const storedOrgId = localStorage.getItem('activeOrganizationId');
        if (storedOrgId) {
          orgIdToUse = storedOrgId;
          if (import.meta.env.DEV) {
            console.warn('[useBOM] Using organizationId from localStorage as fallback (update):', storedOrgId);
          }
        }
      }

      if (!orgIdToUse) {
        throw new Error('Organization ID is required to update component');
      }

      // ✅ MVP: Forzar auto_select=false siempre
      const payload = {
        ...updates,
        auto_select: false, // MVP: siempre false
      };

      // ✅ MVP: Logging para debugging
      if (import.meta.env.DEV) {
        console.log('[useBOM] UPDATE BOM COMPONENT payload:', { id, payload, organization_id: orgIdToUse });
      }

      // ✅ FIX: Strict UPDATE by id + bom_template_id + organization_id
      const { data, error } = await supabase
        .from('BOMComponents')
        .update(payload)
        .eq('id', id)
        .eq('organization_id', orgIdToUse)
        .select()
        .single();

      if (error) {
        // ✅ MVP: Logging de errores visible
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = { 
          message: error.message, 
          code: error.code,
          details: error.details,
          hint: error.hint 
        };
        console.error('[useBOM] UPDATE BOM COMPONENT error:', errorDetails);
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error updating BOM component');
      }

      if (import.meta.env.DEV) {
        console.log('[useBOM] UPDATE BOM COMPONENT success:', data);
      }

      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteComponent = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('BOMComponents')
        .update({ deleted: true })
        .eq('id', id);

      if (error) {
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error deleting component');
      }
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    createComponent,
    updateComponent,
    deleteComponent,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

