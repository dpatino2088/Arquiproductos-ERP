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
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const fetchBOMTemplates = async () => {
      if (!activeOrganizationId) {
        if (import.meta.env.DEV) {
          console.log('[useBOMTemplates] No activeOrganizationId, returning empty array');
        }
        setLoading(false);
        setTemplates([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // DEBUG: Log activeOrganizationId
        if (import.meta.env.DEV) {
          console.log('[useBOMTemplates] Fetching templates', {
            activeOrganizationId,
            productTypeId,
            expectedTemplateOrgId: '4de856e8-36ce-480a-952b-a2f5083c69d6', // For debugging
            orgIdsMatch: activeOrganizationId === '4de856e8-36ce-480a-952b-a2f5083c69d6',
          });
        }


        // Check if BOMTemplates table exists, if not return empty array
        // IMPORTANT: Only search templates for the specific organization (not shared templates)
        // ✅ FIX: Mostrar todos los no-deleted (no filtrar por active para que se vean todos)
        let query = supabase
          .from('BOMTemplates')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false); // ✅ Solo filtrar por deleted, no por active

        if (productTypeId) {
          query = query.eq('product_type_id', productTypeId);
        }

        query = query.order('created_at', { ascending: false });

        const { data, error: fetchError } = await query;


        // DEBUG: Log query details
        if (import.meta.env.DEV) {
          console.log('[useBOMTemplates] Query executed', {
            activeOrganizationId,
            productTypeId,
            hasFilter: !!productTypeId,
            error: fetchError,
            dataCount: data?.length || 0,
            rawData: data?.map((t: any) => ({ id: t.id, name: t.name, product_type_id: t.product_type_id, active: t.active, deleted: t.deleted, organization_id: t.organization_id })),
          });
        }

        // If table doesn't exist, return empty array (graceful degradation)
        if (fetchError) {

          // Check if error is "table does not exist"
          if (fetchError.code === 'PGRST205' || fetchError.message?.includes('does not exist')) {
            if (import.meta.env.DEV) {
              console.warn('BOMTemplates table does not exist yet. Please run migration 56_create_bom_templates.sql');
            }
            setTemplates([]);
            setError('BOMTemplates table does not exist. Please run migration.');
            return;
          }
          
          // ✅ FIX A: Check for RLS/permission errors
          if (fetchError.code === '42501' || fetchError.message?.includes('permission denied') || fetchError.message?.includes('RLS')) {
            console.error('[useBOMTemplates] RLS/Permission error - templates may exist but user cannot read them', { 
              error: fetchError, 
              activeOrganizationId, 
              productTypeId 
            });
            setError('Permission denied: Cannot read BOMTemplates. Check RLS policies.');
            setTemplates([]);
            return;
          }
          
          if (import.meta.env.DEV) {
            console.error('[useBOMTemplates] Query error', { error: fetchError, activeOrganizationId, productTypeId });
          }
          setError(fetchError.message || 'Error loading BOM templates');
          throw fetchError;
        }
        

        // DEBUG: Log results
        if (import.meta.env.DEV) {
          console.log('[useBOMTemplates] Query results', {
            dataCount: data?.length || 0,
            templates: data?.map((t: any) => ({ id: t.id, name: t.name, product_type_id: t.product_type_id, active: t.active, deleted: t.deleted })),
          });
        }

        // Fetch product types separately to avoid FK issues
        const productTypeIds = [...new Set((data || []).map((item: any) => item.product_type_id).filter(Boolean))];
        let productTypesMap = new Map<string, ProductType>();
        
        if (productTypeIds.length > 0) {
          // CRITICAL: Also include shared ProductTypes (organization_id IS NULL)
          const { data: ptData, error: ptError } = await supabase
            .from('ProductTypes')
            .select('id, code, name, organization_id')
            .in('id', productTypeIds)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .eq('deleted', false);
          
          if (ptError && import.meta.env.DEV) {
            console.warn('[useBOMTemplates] Error fetching ProductTypes', { error: ptError, productTypeIds });
          }
          
          if (ptData) {
            if (import.meta.env.DEV) {
              console.log('[useBOMTemplates] ProductTypes fetched', { count: ptData.length, productTypes: ptData.map((pt: any) => ({ id: pt.id, code: pt.code, name: pt.name, organization_id: pt.organization_id })) });
            }
            productTypesMap = new Map(ptData.map((pt: any) => [pt.id, {
              id: pt.id,
              code: pt.code,
              name: pt.name,
              sort_order: 0, // ProductTypes doesn't have sort_order, use default
            } as ProductType]));
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
    };

  useEffect(() => {
    fetchBOMTemplates();
  }, [activeOrganizationId, productTypeId, refreshTrigger]);

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  return { templates, loading, error, refetch };
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
    // ✅ GATING: No crear sin organization_id
    if (!activeOrganizationId) {
      throw new Error('No organization selected. Please select an organization before creating a template.');
    }

    // ✅ MVP: Validación de campos requeridos
    if (!templateData.product_type_id) {
      throw new Error('product_type_id is required');
    }
    if (!templateData.code || templateData.code.trim() === '') {
      throw new Error('code is required and cannot be empty');
    }

    setIsCreating(true);
    try {
      const payload = {
        ...templateData,
        organization_id: activeOrganizationId, // ✅ SIEMPRE usar activeOrganizationId
        active: true,
        deleted: false,
        archived: false,
        metadata: templateData.metadata || {},
      };

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] Creating template with payload:', payload);
      }

      const { data, error } = await supabase
        .from('BOMTemplates')
        .insert(payload)
        .select('*')
        .single();

      if (error) {
        // ✅ FIX: Manejar error 23505 (duplicate key)
        if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('unique constraint')) {
          // Buscar el registro existente
          const { data: existingTemplate, error: findError } = await supabase
            .from('BOMTemplates')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('code', templateData.code.trim())
            .limit(1)
            .maybeSingle();

          if (findError) {
            console.error('[useBOMTemplates] Error finding existing template:', findError);
            throw new Error(`Code "${templateData.code.trim()}" already exists in this organization. Error finding existing template: ${findError.message}`);
          }

          if (existingTemplate) {
            if (existingTemplate.deleted) {
              // ✅ Revivir template eliminado
              const { data: revivedTemplate, error: updateError } = await supabase
                .from('BOMTemplates')
                .update({
                  deleted: false,
                  active: true,
                  ...templateData,
                  updated_at: new Date().toISOString(),
                })
                .eq('id', existingTemplate.id)
                .eq('organization_id', activeOrganizationId)
                .select('*')
                .single();

              if (updateError) {
                console.error('[useBOMTemplates] Error reviving template:', updateError);
                throw new Error(`Code "${templateData.code.trim()}" exists but is deleted. Error reviving: ${updateError.message}`);
              }

              if (import.meta.env.DEV) {
                console.log('[useBOMTemplates] Template revived successfully:', revivedTemplate);
              }

              return revivedTemplate;
            } else {
              // Template existe y no está eliminado
              throw new Error(`Code "${templateData.code.trim()}" already exists in this organization (ID: ${existingTemplate.id}). Use a different code or edit the existing template.`);
            }
          } else {
            // No se encontró el template (caso raro)
            throw new Error(`Code "${templateData.code.trim()}" violates unique constraint but template not found. Please try again.`);
          }
        }

        // ✅ MVP: Logging de errores visible
        console.error('[useBOMTemplates] SAVE BOM TEMPLATE error:', error);
        throw error;
      }

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] SAVE BOM TEMPLATE success:', data);
      }

      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateTemplate = async (id: string, updates: Partial<BOMTemplate>) => {
    // ✅ GATING: No actualizar sin organization_id
    if (!activeOrganizationId) {
      throw new Error('No organization selected. Please select an organization before updating a template.');
    }

    setIsUpdating(true);
    try {
      const payload = {
        ...updates,
        updated_at: new Date().toISOString(),
      };

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] Updating template:', { id, payload });
      }

      const { data, error } = await supabase
        .from('BOMTemplates')
        .update(payload)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId) // ✅ Filtrar por organization_id
        .select('*')
        .single();

      if (error) {
        // ✅ MVP: Logging de errores visible
        console.error('[useBOMTemplates] UPDATE BOM TEMPLATE error:', error);
        throw error;
      }

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] UPDATE BOM TEMPLATE success:', data);
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

