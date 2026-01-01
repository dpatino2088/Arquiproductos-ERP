import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface ProductType {
  id: string;
  name: string;
  code?: string | null;
  archived: boolean;
  deleted: boolean;
  sort_order?: number | null;
}

export function useProductTypes() {
  const [productTypes, setProductTypes] = useState<ProductType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    let isMounted = true;

    async function fetchProductTypes() {
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setProductTypes([]);
          setError(null);
        }
        return;
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        const { data, error: queryError } = await supabase
          .from('ProductTypes')
          .select('id, name, code, archived, deleted, sort_order')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true, nullsFirst: false })
          .order('name', { ascending: true });

        if (queryError) {
          throw queryError;
        }

        if (isMounted) {
          setProductTypes(data || []);
          
          if (import.meta.env.DEV) {
            console.log('✅ ProductTypes loaded:', data?.length || 0, 'types');
            console.log('   Types:', data?.map(pt => pt.name));
          }
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading product types';
        if (import.meta.env.DEV) {
          console.error('❌ Error fetching ProductTypes:', err);
        }
        if (isMounted) {
          setError(errorMessage);
          setProductTypes([]);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchProductTypes();

    return () => {
      isMounted = false;
    };
  }, [activeOrganizationId]);

  // Helper function to find ProductType by name (case-insensitive, flexible matching)
  // Memoized with useCallback to prevent infinite loops
  const findProductTypeByName = useCallback((name: string): ProductType | undefined => {
    if (!name || !productTypes.length) return undefined;
    
    const normalizedName = name.trim();
    
    // Try exact match first
    let found = productTypes.find(pt => 
      pt.name === normalizedName || 
      pt.name?.toLowerCase() === normalizedName.toLowerCase()
    );
    
    // Try partial match
    if (!found) {
      found = productTypes.find(pt => 
        pt.name?.toLowerCase().includes(normalizedName.toLowerCase()) ||
        normalizedName.toLowerCase().includes(pt.name?.toLowerCase() || '')
      );
    }
    
    return found;
  }, [productTypes]);

  return { productTypes, loading, error, findProductTypeByName };
}
