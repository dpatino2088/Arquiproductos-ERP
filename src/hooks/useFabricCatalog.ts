import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FabricVariant {
  id: string;
  sku: string | null;
  item_name: string | null;
  collection_name: string | null;
  variant_name: string | null;
  manufacturer_id?: string | null;
  roll_width_m?: number | null;
  weight_gsm?: number | null;
  can_rotate?: boolean | null;
  can_heatseal?: boolean | null;
  cost_exw?: number | null;
  msrp?: number | null;
  metadata?: any;
}

/**
 * Hook to fetch fabric collections for a given product type
 * Uses single query with JOIN for better performance
 */
export function useFabricCollections(productTypeId?: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const [collections, setCollections] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

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
        // Single query with JOIN instead of two separate queries
        const { data, error } = await supabase
          .from('CatalogItems')
          .select(`
            collection_name,
            CatalogItemProductTypes!inner(product_type_id)
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('is_fabric', true)
          .eq('deleted', false)
          .eq('CatalogItemProductTypes.product_type_id', productTypeId)
          .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
          .eq('CatalogItemProductTypes.deleted', false)
          .not('collection_name', 'is', null)
          .neq('collection_name', '');

        if (error) {
          console.error('useFabricCollections query error:', error);
          throw error;
        }

        // Extract distinct collection names
        const uniqueCollections = Array.from(
          new Set(
            (data || [])
              .map((item) => String(item.collection_name).trim())
              .filter(Boolean)
          )
        ).sort();

        if (import.meta.env.DEV) {
          console.log('useFabricCollections: Results', {
            productTypeId,
            itemsFound: data?.length || 0,
            collectionsCount: uniqueCollections.length,
            collections: uniqueCollections,
          });
        }

        if (mounted) setCollections(uniqueCollections);
      } catch (err: any) {
        console.error('useFabricCollections error:', err);
        if (mounted) setError(err.message || 'Error loading collections');
      } finally {
        if (mounted) setLoading(false);
      }
    }

    fetchCollections();

    return () => {
      mounted = false;
    };
  }, [activeOrganizationId, productTypeId]);

  return { collections, loading, error };
}

/**
 * Hook to fetch fabric variants for a given product type and collection
 * Uses single query with JOIN
 */
export function useFabricVariants(
  productTypeId?: string,
  collectionName?: string
) {
  const { activeOrganizationId } = useOrganizationContext();
  const [variants, setVariants] = useState<FabricVariant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

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
        // Single query with JOIN - select fabric columns
        const { data, error } = await supabase
          .from('CatalogItems')
          .select(`
            id, sku, item_name, collection_name, variant_name,
            manufacturer_id, roll_width_m, weight_gsm, openness, composition,
            can_rotate, can_heatseal, heatseal_price_per_meter,
            cost_exw, msrp, stock_status, metadata,
            CatalogItemProductTypes!inner(product_type_id)
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('is_fabric', true)
          .eq('deleted', false)
          .eq('collection_name', collectionName)
          .eq('CatalogItemProductTypes.product_type_id', productTypeId)
          .eq('CatalogItemProductTypes.organization_id', activeOrganizationId)
          .eq('CatalogItemProductTypes.deleted', false)
          .order('variant_name', { ascending: true });

        if (error) {
          console.error('useFabricVariants query error:', error);
          throw error;
        }

        if (import.meta.env.DEV) {
          console.log('useFabricVariants: Results', {
            productTypeId,
            collectionName,
            variantsCount: data?.length || 0,
            sampleVariants: data?.slice(0, 3).map((v) => v.variant_name),
          });
        }

        if (mounted) setVariants(data || []);
      } catch (err: any) {
        console.error('useFabricVariants error:', err);
        if (mounted) setError(err.message || 'Error loading variants');
      } finally {
        if (mounted) setLoading(false);
      }
    }

    fetchVariants();

    return () => {
      mounted = false;
    };
  }, [activeOrganizationId, productTypeId, collectionName]);

  return { variants, loading, error };
}
