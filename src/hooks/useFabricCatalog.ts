import { useEffect, useState, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FabricVariant {
  id: string;
  sku: string | null;
  name: string | null;
  collection_name: string | null;
  variant_name: string | null;
  manufacturer_id?: string | null;
  manufacturer?: string | null;
  roll_width?: number | null;
  color?: string | null;
  cost_exw?: number | null;
  description?: string | null;
  image_url?: string | null;
}

// ✅ OPTIMIZATION: In-memory cache (3 min TTL for collections/variants)
const collectionsCache = new Map<string, { data: string[]; timestamp: number }>();
const variantsCache = new Map<string, { data: FabricVariant[]; timestamp: number }>();
const CACHE_TTL = 3 * 60 * 1000; // 3 minutes

/**
 * Hook to fetch fabric collections for a given product type
 * Uses single query with JOIN for better performance.
 * Optional manufacturerId filters to collections that have at least one item from that manufacturer.
 */
export function useFabricCollections(productTypeId?: string, manufacturerId?: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const [collections, setCollections] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    const cacheKey = `collections:${activeOrganizationId}:${productTypeId || 'all'}:${manufacturerId || 'all'}`;
    
    // ✅ Check cache first
    const cached = collectionsCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
      if (mounted) {
        setCollections(cached.data);
        setLoading(false);
        
        if (import.meta.env.DEV) {
          console.log(`✅ [useFabricCollections] CACHE HIT`, {
            count: cached.data.length,
            age: `${Math.round((Date.now() - cached.timestamp) / 1000)}s`,
          });
        }
      }
      return;
    }

    async function fetchCollections() {
      if (mounted) {
        setLoading(true);
        setError(null);
      }

      if (!activeOrganizationId || !productTypeId) {
        if (import.meta.env.DEV) {
          console.log('useFabricCollections: Missing params', {
            activeOrganizationId,
            productTypeId,
          });
        }
        if (mounted) {
          setCollections([]);
          setLoading(false);
        }
        return;
      }

      try {
        // Primary query: filter by ProductType when links exist; optionally by manufacturer_id
        let queryWithProductType = supabase
          .from('CatalogItems')
          .select(`
            collection_name,
            CatalogItemProductTypes!inner(product_type_id, organization_id)
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('is_roll', true)
          .eq('is_active', true)
          .eq('CatalogItemProductTypes.product_type_id', productTypeId)
          .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
          .not('collection_name', 'is', null)
          .neq('collection_name', '');
        if (manufacturerId) queryWithProductType = queryWithProductType.eq('manufacturer_id', manufacturerId);

        const { data: dataWithProductType, error: errorWithProductType } = await queryWithProductType;

        if (errorWithProductType) {
          console.error('useFabricCollections query error (with product type):', errorWithProductType);
          throw errorWithProductType;
        }

        let data = dataWithProductType || [];

        // Fallback 0: if manufacturer filter is too restrictive, retry without manufacturer.
        if (data.length === 0 && manufacturerId) {
          const { data: dataWithoutManufacturer, error: errorWithoutManufacturer } = await supabase
            .from('CatalogItems')
            .select(`
              collection_name,
              CatalogItemProductTypes!inner(product_type_id, organization_id)
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('is_roll', true)
            .eq('is_active', true)
            .eq('CatalogItemProductTypes.product_type_id', productTypeId)
            .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
            .not('collection_name', 'is', null)
            .neq('collection_name', '');

          if (errorWithoutManufacturer) {
            console.error('useFabricCollections query error (no manufacturer fallback):', errorWithoutManufacturer);
          } else {
            data = dataWithoutManufacturer || [];
          }
        }

        // Fallback: if no results, fetch all roll collections (direct from CatalogItems)
        if (data.length === 0) {
          if (import.meta.env.DEV) {
            console.warn('useFabricCollections: No collections found with ProductType filter. Falling back to all roll collections.');
          }

          let queryAll = supabase
            .from('CatalogItems')
            .select('collection_name')
            .eq('organization_id', activeOrganizationId)
            .eq('is_roll', true)
            .eq('is_active', true)
            .not('collection_name', 'is', null)
            .neq('collection_name', '');
          if (manufacturerId) queryAll = queryAll.eq('manufacturer_id', manufacturerId);
          const { data: dataAll, error: errorAll } = await queryAll;

          if (errorAll) {
            console.error('useFabricCollections query error (fallback):', errorAll);
            throw errorAll;
          }

          data = dataAll || [];
        }

        // Extract distinct collection names
        const uniqueCollections = Array.from(
          new Set(
            (data as Array<{ collection_name?: string | null }>)
              .map((item) => String(item.collection_name || '').trim())
              .filter(Boolean)
          )
        ).sort();

        if (import.meta.env.DEV) {
          console.log('✅ [useFabricCollections] Fetched from DB', {
            productTypeId,
            itemsFound: data?.length || 0,
            collectionsCount: uniqueCollections.length,
          });
        }

        // ✅ Save to cache
        collectionsCache.set(cacheKey, {
          data: uniqueCollections,
          timestamp: Date.now(),
        });

        if (mounted) setCollections(uniqueCollections);
      } catch (err: any) {
        console.error('[useFabricCollections] error:', err);
        if (mounted) setError(err.message || 'Error loading collections');
      } finally {
        if (mounted) setLoading(false);
      }
    }

    fetchCollections();

    return () => {
      mounted = false;
    };
  }, [activeOrganizationId, productTypeId, manufacturerId]);

  return { collections, loading, error };
}

/**
 * Hook to fetch fabric variants for a given product type and collection
 * Uses single query with JOIN. Optional manufacturerId filters variants by manufacturer.
 */
export function useFabricVariants(
  productTypeId?: string,
  collectionName?: string,
  manufacturerId?: string
) {
  const { activeOrganizationId } = useOrganizationContext();
  const [variants, setVariants] = useState<FabricVariant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    const cacheKey = `variants:${activeOrganizationId}:${productTypeId || 'all'}:${collectionName || 'all'}:${manufacturerId || 'all'}`;
    
    // ✅ Check cache first
    const cached = variantsCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
      if (mounted) {
        setVariants(cached.data);
        setLoading(false);
        
        if (import.meta.env.DEV) {
          console.log(`✅ [useFabricVariants] CACHE HIT`, {
            collection: collectionName,
            count: cached.data.length,
            age: `${Math.round((Date.now() - cached.timestamp) / 1000)}s`,
          });
        }
      }
      return;
    }

    async function fetchVariants() {
      if (mounted) {
        setLoading(true);
        setError(null);
      }

      if (!activeOrganizationId || !productTypeId || !collectionName) {
        if (import.meta.env.DEV) {
          console.log('useFabricVariants: Missing params', {
            activeOrganizationId,
            productTypeId,
            collectionName,
          });
        }
        if (mounted) {
          setVariants([]);
          setLoading(false);
        }
        return;
      }

      try {
        // Primary query: filter by ProductType when links exist; optionally by manufacturer_id
        let queryWithProductType = supabase
          .from('CatalogItems')
          .select(`
            id, sku, name, collection_name, variant_name,
            manufacturer_id, manufacturer, roll_width, color,
            cost_exw, description, image_url,
            CatalogItemProductTypes!inner(product_type_id, organization_id)
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('is_roll', true)
          .eq('is_active', true)
          .eq('collection_name', collectionName)
          .eq('CatalogItemProductTypes.product_type_id', productTypeId)
          .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
          .not('variant_name', 'is', null)
          .neq('variant_name', '')
          .order('variant_name', { ascending: true });
        if (manufacturerId) queryWithProductType = queryWithProductType.eq('manufacturer_id', manufacturerId);

        const { data: dataWithProductType, error: errorWithProductType } = await queryWithProductType;

        if (errorWithProductType) {
          const errorMsg = errorWithProductType?.message || errorWithProductType?.error_description || errorWithProductType?.hint || 'Error fetching variants';
          const errorDetails = errorWithProductType?.code ? ` (${errorWithProductType.code})` : '';
          console.error('useFabricVariants query error (with product type):', errorMsg + errorDetails, errorWithProductType);
          throw errorWithProductType;
        }

        let data = dataWithProductType || [];

        // Fallback 0: if manufacturer filter is too restrictive, retry without manufacturer.
        if (data.length === 0 && manufacturerId) {
          const { data: dataWithoutManufacturer, error: errorWithoutManufacturer } = await supabase
            .from('CatalogItems')
            .select(`
              id, sku, name, collection_name, variant_name,
              manufacturer_id, manufacturer, roll_width, color,
              cost_exw, description, image_url,
              CatalogItemProductTypes!inner(product_type_id, organization_id)
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('is_roll', true)
            .eq('is_active', true)
            .eq('collection_name', collectionName)
            .eq('CatalogItemProductTypes.product_type_id', productTypeId)
            .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
            .not('variant_name', 'is', null)
            .neq('variant_name', '')
            .order('variant_name', { ascending: true });

          if (errorWithoutManufacturer) {
            console.error('useFabricVariants query error (no manufacturer fallback):', errorWithoutManufacturer);
          } else {
            data = dataWithoutManufacturer || [];
          }
        }

        // Fallback: if no results, fetch all roll variants for the collection
        if (data.length === 0) {
          if (import.meta.env.DEV) {
            console.warn('useFabricVariants: No variants found with ProductType filter. Falling back to all roll variants for collection.');
          }

          let queryAll = supabase
            .from('CatalogItems')
            .select(`
              id, sku, name, collection_name, variant_name,
              manufacturer_id, manufacturer, roll_width, color,
              cost_exw, description, image_url
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('is_roll', true)
            .eq('is_active', true)
            .eq('collection_name', collectionName)
            .not('variant_name', 'is', null)
            .neq('variant_name', '')
            .order('variant_name', { ascending: true });
          if (manufacturerId) queryAll = queryAll.eq('manufacturer_id', manufacturerId);
          const { data: dataAll, error: errorAll } = await queryAll;

          if (errorAll) {
            const errorMsg = errorAll?.message || errorAll?.error_description || errorAll?.hint || 'Error fetching variants (fallback)';
            const errorDetails = errorAll?.code ? ` (${errorAll.code})` : '';
            console.error('useFabricVariants query error (fallback):', errorMsg + errorDetails, errorAll);
            throw errorAll;
          }

          data = dataAll || [];
        }

        if (import.meta.env.DEV) {
          console.log('useFabricVariants: Results', {
            productTypeId,
            collectionName,
            variantsCount: (data as FabricVariant[] | undefined)?.length || 0,
            sampleVariants: (data as FabricVariant[] | undefined)?.slice(0, 3).map((v: FabricVariant) => v.variant_name),
          });
        }

        if (mounted) setVariants(data || []);
      } catch (err: any) {
        console.error('[useFabricVariants] error:', err);
        if (mounted) setError(err.message || 'Error loading variants');
      } finally {
        if (mounted) setLoading(false);
      }
    }

    fetchVariants();

    return () => {
      mounted = false;
    };
  }, [activeOrganizationId, productTypeId, collectionName, manufacturerId]);

  return { variants, loading, error };
}

// ✅ Export function to invalidate cache
export function invalidateFabricCache(pattern?: string) {
  if (pattern) {
    const keysToDelete: string[] = [];
    for (const key of collectionsCache.keys()) {
      if (key.includes(pattern)) keysToDelete.push(key);
    }
    for (const key of variantsCache.keys()) {
      if (key.includes(pattern)) keysToDelete.push(key);
    }
    keysToDelete.forEach(key => {
      collectionsCache.delete(key);
      variantsCache.delete(key);
    });
  } else {
    collectionsCache.clear();
    variantsCache.clear();
  }
  
  if (import.meta.env.DEV) {
    console.log('[useFabricCatalog] Cache invalidated');
  }
}
