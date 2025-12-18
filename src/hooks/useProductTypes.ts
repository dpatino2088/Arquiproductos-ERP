import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { ProductType } from '../types/catalog';

/**
 * Hook to fetch ProductTypes (from Profiles table)
 */
export function useProductTypes() {
  const [productTypes, setProductTypes] = useState<ProductType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchProductTypes() {
      if (!activeOrganizationId) {
        setLoading(false);
        setProductTypes([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Try ProductTypes first, then fallback to Profiles
        // ProductTypes table structure: id, organization_id, code, name, sort_order, deleted, created_at, updated_at
        let { data, error: fetchError } = await supabase
          .from('ProductTypes')
          .select('id, organization_id, code, name, sort_order, deleted, created_at, updated_at')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        // If ProductTypes doesn't exist, try Profiles (without organization_id filter)
        if (fetchError && (fetchError.code === 'PGRST205' || fetchError.message?.includes('does not exist'))) {
          const { data: profilesData, error: profilesError } = await supabase
            .from('Profiles')
            .select('id, code, name, sort_order, deleted, created_at, updated_at')
            .eq('deleted', false)
            .order('sort_order', { ascending: true })
            .order('name', { ascending: true });
          
          if (!profilesError) {
            data = profilesData;
            fetchError = null;
          } else {
            fetchError = profilesError;
          }
        }

        if (fetchError) {
          throw fetchError;
        }

        setProductTypes((data || []) as ProductType[]);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading product types';
        setError(errorMessage);
        if (import.meta.env.DEV) {
          console.error('Error fetching ProductTypes:', err);
        }
      } finally {
        setLoading(false);
      }
    }

    fetchProductTypes();
  }, [activeOrganizationId]);

  return { productTypes, loading, error };
}

