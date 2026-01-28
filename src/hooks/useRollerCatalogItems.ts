/**
 * Hook to fetch catalog items for BOM configurator
 * 
 * FILTER CRITERIA (in order):
 * 1. is_fabric=false → Only non-fabric items have color in CatalogItem.color
 * 2. ProductType → CatalogItemProductTypes.product_type_id
 * 3. Color → CatalogItems.color (for hardware items with is_fabric=false)
 * 4. Role → CatalogItems.item_role
 * 
 * ROLES MAPPING:
 * - motor → item_role='motor'
 * - drive (manual) → item_role='drive'
 * - bottom_bar → item_role='bottom_bar'
 * - headbox (cassette) → item_role='headbox'
 * - side_channel → item_role='side_channel'
 * - tube → item_role='tube'
 */

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { CatalogItemOption } from '../lib/bom/types';
import { normalizeRole } from '../lib/bom/roles';

export interface UseRollerCatalogItemsParams {
  organizationId: string | null;
  productTypeId?: string | null;
  role: string;
  color?: string | null;
  enabled?: boolean;
  measureBasis?: string | null;
}

// ✅ OPTIMIZATION: In-memory cache (2 min TTL for catalog items)
const catalogItemsCache = new Map<string, { data: CatalogItemOption[]; timestamp: number }>();
const CACHE_TTL = 2 * 60 * 1000; // 2 minutes

export function useRollerCatalogItems({ organizationId, productTypeId, role, color, enabled = true, measureBasis }: UseRollerCatalogItemsParams) {
  const [items, setItems] = useState<CatalogItemOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!enabled || !organizationId || !role) {
      setItems([]);
      setLoading(false);
      return;
    }
    if (!productTypeId) {
      setItems([]);
      setLoading(false);
      return;
    }

    let isMounted = true;
    const normalizedRole = normalizeRole(role) || role;
    const normalizedColor = color?.trim() || null;
    const cacheKey = `catalogItems:${organizationId}:${productTypeId}:${normalizedRole}:${normalizedColor || 'any'}:${measureBasis || 'any'}`;
    
    // ✅ Check cache first
    const cached = catalogItemsCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
      if (isMounted) {
        setItems(cached.data);
        setLoading(false);
      }
      
      if (import.meta.env.DEV) {
        console.log(`✅ [useRollerCatalogItems] CACHE HIT: ${normalizedRole}`, {
          count: cached.data.length,
          age: `${Math.round((Date.now() - cached.timestamp) / 1000)}s`,
        });
      }
      return;
    }

    const fetchItems = async () => {
      if (!isMounted) return;
      
      setLoading(true);
      setError(null);

      try {
        if (import.meta.env.DEV) {
          console.log(`🔍 [useRollerCatalogItems] FETCH from DB:`, { 
            organizationId, 
            productTypeId, 
            role: normalizedRole, 
            color: normalizedColor,
            measureBasis,
          });
        }

        // Fetch from CatalogItems joined with CatalogItemProductTypes (product type filter FIRST)
        // IMPORTANT: Filter by is_fabric=false for hardware items (they have color in CatalogItem.color)
        let query = supabase
          .from('CatalogItems')
          .select('id, sku, name, color, cost_exw, image_url, item_role, CatalogItemProductTypes!inner(product_type_id)')
          .eq('organization_id', organizationId)
          .eq('is_fabric', false) // ✅ REQUIRED: Only non-fabric items have color in CatalogItem.color
          .ilike('item_role', normalizedRole)
          .eq('is_active', true) // ✅ Solo items activos
          .eq('CatalogItemProductTypes.product_type_id', productTypeId);
        console.log(`🔍 [useRollerCatalogItems] Applying is_fabric=false filter (hardware items only)`);
        console.log(`🔍 [useRollerCatalogItems] Applying ProductType filter: ${productTypeId}`);
        console.log(`🔍 [useRollerCatalogItems] Applying role filter (case-insensitive): ${normalizedRole}`);

        // Apply color filter
        // IMPORTANT: Motor and Tube items often have NULL color, so skip color filter
        if (normalizedColor && !['motor', 'tube'].includes(normalizedRole)) {
          // Use ilike for case-insensitive match (DB may store 'White' vs 'white')
          query = query.ilike('color', normalizedColor);
          console.log(`🔍 [useRollerCatalogItems] Applying color filter: ${normalizedColor}`);
        } else if (['motor', 'tube'].includes(normalizedRole)) {
          console.log(`🔍 [useRollerCatalogItems] Skipping color filter for ${normalizedRole} (often NULL color)`);
        }
        
        // Apply measure_basis filter when provided (e.g., 'linear')
        if (measureBasis) {
          query = query.eq('measure_basis', measureBasis);
          console.log(`🔍 [useRollerCatalogItems] Applying measure_basis filter: ${measureBasis}`);
        }

        const pageSize = 1000;
        let allData: any[] = [];
        let page = 0;
        let fetchError: any = null;

        while (true) {
          const { data, error } = await query
            .order('name', { ascending: true })
            .range(page * pageSize, page * pageSize + pageSize - 1);

          if (error) {
            fetchError = error;
            break;
          }

          allData = allData.concat(data || []);

          if (!data || data.length < pageSize) {
            break;
          }

          page += 1;
        }

        if (fetchError) {
          console.error(`❌ [useRollerCatalogItems] CatalogItems query error:`, fetchError);
          setError(fetchError.message);
          setItems([]);
          return;
        }

        const mappedItems: CatalogItemOption[] = (allData || []).map((item: any) => ({
          id: item.id,
          sku: item.sku,
          name: item.name,
          color: item.color || null,
          cost_exw: item.cost_exw || null,
          image_url: item.image_url || null,
        }));

        if (import.meta.env.DEV) {
          console.log(`✅ [useRollerCatalogItems] SUCCESS: Found ${mappedItems.length} items`, {
            role: normalizedRole,
            productTypeId,
            color: normalizedColor,
            items: mappedItems.slice(0, 3).map(i => ({ name: i.name, sku: i.sku })),
          });
        }

        // ✅ Save to cache
        catalogItemsCache.set(cacheKey, {
          data: mappedItems,
          timestamp: Date.now(),
        });

        if (isMounted) {
          setItems(mappedItems);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading items';
        console.error('❌ [useRollerCatalogItems] Exception:', err);
        if (isMounted) {
          setError(errorMessage);
          setItems([]);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchItems();

    return () => {
      isMounted = false;
    };
  }, [organizationId, productTypeId, role, color, enabled, measureBasis]);

  return { items, loading, error };
}

// ✅ Export function to invalidate cache (call when creating/updating catalog items)
export function invalidateCatalogItemsCache(pattern?: string) {
  if (pattern) {
    const keysToDelete: string[] = [];
    for (const key of catalogItemsCache.keys()) {
      if (key.includes(pattern)) {
        keysToDelete.push(key);
      }
    }
    keysToDelete.forEach(key => catalogItemsCache.delete(key));
    
    if (import.meta.env.DEV) {
      console.log(`[useRollerCatalogItems] Cache invalidated: ${keysToDelete.length} entries for pattern: ${pattern}`);
    }
  } else {
    catalogItemsCache.clear();
    if (import.meta.env.DEV) {
      console.log('[useRollerCatalogItems] Cache cleared completely');
    }
  }
}

