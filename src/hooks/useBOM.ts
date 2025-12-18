import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface BOMComponent {
  id: string;
  organization_id: string;
  parent_item_id?: string | null; // Deprecated: use bom_template_id instead
  bom_template_id?: string | null; // New: FK to BOMTemplates
  component_item_id: string;
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

        const { data, error: fetchError } = await supabase
          .from('BOMComponents')
          .select(`
            *,
            component_item:CatalogItems!BOMComponents_component_item_id_fkey(
              sku,
              item_name,
              cost_exw,
              item_category_id,
              is_fabric,
              collection_name,
              variant_name,
              ItemCategories(
                id,
                name,
                code
              )
            )
          `)
          .eq('bom_template_id', bomTemplateId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sequence_order', { ascending: true });

        if (fetchError) {
          throw fetchError;
        }

        // Map the data to include joined component information
        const mappedComponents: BOMComponent[] = (data || []).map((item: any) => ({
          ...item,
          component_sku: item.component_item?.sku,
          component_name: item.component_item?.item_name,
          component_cost_exw: item.component_item?.cost_exw,
          component_category_id: item.component_item?.item_category_id,
          component_category_name: item.component_item?.ItemCategories?.name,
          component_category_code: item.component_item?.ItemCategories?.code,
          component_is_fabric: item.component_item?.is_fabric,
          component_collection_name: item.component_item?.collection_name,
          component_variant_name: item.component_item?.variant_name,
        }));

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

