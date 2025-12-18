import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { CategoryMargin } from '../types/pricing';

/**
 * Hook to fetch all category margins for the active organization
 */
export function useCategoryMargins() {
  const [margins, setMargins] = useState<CategoryMargin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchMargins() {
      if (!activeOrganizationId) {
        setLoading(false);
        setMargins([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('CategoryMargins')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CategoryMargins:', queryError.message);
          }
          throw queryError;
        }

        setMargins(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading category margins';
        if (import.meta.env.DEV) {
          console.error('Error fetching CategoryMargins:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchMargins();
  }, [activeOrganizationId, refreshTrigger]);

  return { margins, loading, error, refetch };
}

/**
 * Hook for CategoryMargins CRUD operations
 */
export function useCategoryMarginsCRUD() {
  const { margins, loading, error, refetch } = useCategoryMargins();
  const { activeOrganizationId } = useOrganizationContext();

  const createMargin = async (
    data: Omit<CategoryMargin, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data: result, error: err } = await supabase
      .from('CategoryMargins')
      .insert({
        ...data,
        organization_id: activeOrganizationId,
      })
      .select()
      .single();

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error creating CategoryMargin:', err.message);
      }
      throw err;
    }

    await refetch();
    return result;
  };

  const updateMargin = async (id: string, data: Partial<CategoryMargin>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    const { data: result, error: err } = await supabase
      .from('CategoryMargins')
      .update(data)
      .eq('id', id)
      .eq('organization_id', activeOrganizationId)
      .select()
      .single();

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error updating CategoryMargin:', err.message);
      }
      throw err;
    }

    await refetch();
    return result;
  };

  const deleteMargin = async (id: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    // Soft delete
    const { error: err } = await supabase
      .from('CategoryMargins')
      .update({ deleted: true })
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);

    if (err) {
      if (import.meta.env.DEV) {
        console.error('Error deleting CategoryMargin:', err.message);
      }
      throw err;
    }

    await refetch();
  };

  return {
    margins,
    loading,
    error,
    refetch,
    createMargin,
    updateMargin,
    deleteMargin,
  };
}

/**
 * Helper function to get margin percentage for a specific category
 * Returns the category margin if it exists and is active, otherwise returns null
 */
export function useCategoryMargin(categoryId: string | null | undefined) {
  const { margins, loading } = useCategoryMargins();
  
  if (!categoryId || loading) {
    return { marginPercentage: null, loading };
  }

  const categoryMargin = margins.find(
    m => m.category_id === categoryId && m.active && !m.deleted
  );

  return {
    marginPercentage: categoryMargin?.margin_percentage ?? null,
    loading,
  };
}

