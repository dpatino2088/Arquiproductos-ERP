import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { BOMTemplate, ProductType } from '../types/catalog';

/**
 * Hook to fetch BOMTemplates
 */
export function useBOMTemplates(productTypeId?: string | null) {
  const [templates, setTemplates] = useState<BOMTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchBOMTemplates() {
      if (!activeOrganizationId) {
        setLoading(false);
        setTemplates([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Check if BOMTemplates table exists, if not return empty array
        let query = supabase
          .from('BOMTemplates')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('active', true);

        if (productTypeId) {
          query = query.eq('product_type_id', productTypeId);
        }

        query = query.order('created_at', { ascending: false });

        const { data, error: fetchError } = await query;

        // If table doesn't exist, return empty array (graceful degradation)
        if (fetchError) {
          // Check if error is "table does not exist"
          if (fetchError.code === 'PGRST205' || fetchError.message?.includes('does not exist')) {
            if (import.meta.env.DEV) {
              console.warn('BOMTemplates table does not exist yet. Please run migration 56_create_bom_templates.sql');
            }
            setTemplates([]);
            return;
          }
          throw fetchError;
        }

        // Fetch product types separately to avoid FK issues
        const productTypeIds = [...new Set((data || []).map((item: any) => item.product_type_id).filter(Boolean))];
        let productTypesMap = new Map<string, ProductType>();
        
        if (productTypeIds.length > 0) {
          const { data: ptData } = await supabase
            .from('Profiles')
            .select('id, code, name, sort_order')
            .in('id', productTypeIds);
          
          if (ptData) {
            productTypesMap = new Map(ptData.map((pt: any) => [pt.id, pt as ProductType]));
          }
        }

        // Map the data to include joined product_type
        const mappedTemplates: BOMTemplate[] = (data || []).map((item: any) => ({
          ...item,
          product_type: productTypesMap.get(item.product_type_id),
        }));

        setTemplates(mappedTemplates);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading BOM templates';
        setError(errorMessage);
        if (import.meta.env.DEV) {
          console.error('Error fetching BOMTemplates:', err);
        }
      } finally {
        setLoading(false);
      }
    }

    fetchBOMTemplates();
  }, [activeOrganizationId, productTypeId]);

  return { templates, loading, error };
}

/**
 * Hook for BOMTemplate CRUD operations
 */
export function useBOMTemplateCRUD() {
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createTemplate = async (
    templateData: Omit<BOMTemplate, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived' | 'active'>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('BOMTemplates')
        .insert({
          ...templateData,
          organization_id: activeOrganizationId,
          active: true,
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

  const updateTemplate = async (id: string, updates: Partial<BOMTemplate>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('BOMTemplates')
        .update({
          ...updates,
          updated_at: new Date().toISOString(),
        })
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

  const deleteTemplate = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('BOMTemplates')
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
    createTemplate,
    updateTemplate,
    deleteTemplate,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

