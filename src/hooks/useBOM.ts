import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface BOMComponent {
  id: string;
  organization_id: string;
  parent_item_id?: string | null; // Deprecated: use bom_template_id instead
  bom_template_id?: string | null; // New: FK to BOMTemplates
  component_item_id?: string | null; // Can be null for auto-select components (fabric, etc.)
  component_role?: string | null; // Role of component (fabric, tube, bracket, etc.)
  auto_select?: boolean; // Whether component is auto-selected by rules
  qty_per_unit: number;
  uom: string;
  is_required: boolean;
  sequence_order: number;
  metadata?: Record<string, any> | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
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
    async function fetchBOMComponents() {
      if (!bomTemplateId || !activeOrganizationId) {
        setLoading(false);
        setComponents([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Fetch BOMComponents separately to avoid join issues
        const { data: bomComponentsData, error: fetchError } = await supabase
          .from('BOMComponents')
          .select('*')
          .eq('bom_template_id', bomTemplateId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sequence_order', { ascending: true });

        if (fetchError) {
          throw fetchError;
        }

        if (!bomComponentsData || bomComponentsData.length === 0) {
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

        setComponents(mappedComponents);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading BOM components';
        setError(errorMessage);
        if (import.meta.env.DEV) {
          console.error('Error fetching BOM components:', err);
        }
      } finally {
        setLoading(false);
      }
    }

    fetchBOMComponents();
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
        throw error;
      }

      return (data || []) as BOMPriceCalculation[];
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error calculating BOM price:', err);
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
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    if (!componentData.bom_template_id && !componentData.parent_item_id) {
      throw new Error('Either bom_template_id or parent_item_id is required');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('BOMComponents')
        .insert({
          ...componentData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) {
        throw error;
      }

      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateComponent = async (id: string, updates: Partial<BOMComponent>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('BOMComponents')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        throw error;
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
        throw error;
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

