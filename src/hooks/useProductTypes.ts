import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface ProductType {
  id: string;
  name: string;
  code?: string | null;
  sort_order?: number | null;
  status?: string | null;
}

// ✅ OPTIMIZATION: In-memory cache (5 min TTL)
const productTypesCache = new Map<string, { data: ProductType[]; timestamp: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

export function useProductTypes() {
  const [productTypes, setProductTypes] = useState<ProductType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    let isMounted = true;
    let abortController = new AbortController();

    async function fetchProductTypes() {
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setProductTypes([]);
          setError(null);
        }
        return;
      }

      const cacheKey = `productTypes:${activeOrganizationId}`;
      
      // ✅ Check cache first
      const cached = productTypesCache.get(cacheKey);
      
      if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
        if (isMounted) {
          setProductTypes(cached.data);
          setLoading(false);
          
          if (import.meta.env.DEV) {
            console.log('✅ [useProductTypes] Loaded from CACHE', {
              count: cached.data.length,
              age: `${Math.round((Date.now() - cached.timestamp) / 1000)}s`,
            });
          }
        }
        return;
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        if (import.meta.env.DEV) {
          console.log('[useProductTypes] Fetching from DB...', { activeOrganizationId });
        }

        // NOTE: ProductTypes table does NOT have 'deleted' or 'archived' columns (per DB dump)
        // ✅ FIX: Soportar registros globales (organization_id NULL)
        const { data, error: queryError } = await supabase
          .from('ProductTypes')
          .select('id, name, code, sort_order, status')
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .order('sort_order', { ascending: true, nullsFirst: false })
          .order('name', { ascending: true });

        if (import.meta.env.DEV) {
          console.log('[useProductTypes] Query completed', {
            success: !queryError,
            count: data?.length || 0,
            error: queryError,
          });
        }

        if (queryError) {
          throw queryError;
        }

        // ✅ Save to cache
        productTypesCache.set(cacheKey, {
          data: data || [],
          timestamp: Date.now(),
        });

        if (isMounted) {
          setProductTypes(data || []);
          
          if (import.meta.env.DEV) {
            console.log('✅ [useProductTypes] Fetched from DB', {
              count: data?.length || 0,
              types: data?.map((pt: ProductType) => pt.name),
            });
          }
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading product types';
        if (import.meta.env.DEV) {
          const errorDetails = err instanceof Error 
            ? { message: err.message, name: err.name, stack: err.stack }
            : typeof err === 'object' && err !== null
            ? { message: (err as any).message || String(err), code: (err as any).code, details: (err as any).details }
            : String(err);
          console.error('❌ [useProductTypes] Error:', errorDetails);
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
      abortController.abort(); // Cancel pending requests
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
