import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';

const ORGANIZATION_ID = '4de856e8-36ce-480a-952b-a2f5083c69d6';

export interface CatalogPickerRow {
  product_type_id: string;
  product_type_code: string;
  product_type_name: string;
  collection_id: string | null; // NULL for non-fabric items
  collection_name: string | null;
  variant_name: string | null; // Text field from CatalogItems, not FK
  catalog_item_id: string;
  sku: string;
  item_name: string; // From CatalogItems
  catalog_name: string | null;
  description: string | null;
  label: string; // For fabrics: collection_name + variant_name, for others: item_name
  item_type: string;
  measure_basis: string;
  uom: string;
  roll_width_m: number | null;
  is_fabric: boolean;
}

export interface CatalogPickerPayload {
  product_type_id: string;
  product_type_code: string;
  collection_id: string | null;
  collection_name: string | null;
  variant_name: string | null; // Text field, not FK
  catalog_item_id: string;
  sku: string;
  item_name: string;
  catalog_name: string | null;
  label: string; // For fabrics: collection_name + variant_name, for others: item_name
  uom: string;
  measure_basis: string;
  item_type: string;
  roll_width_m: number | null;
  is_fabric: boolean;
}

/**
 * Hook to fetch and cache the full catalog tree structure
 * Returns all ProductType → Collection → Variant → SKU relationships
 * Uses multiple queries and combines them in memory (replicating the exact SQL structure)
 * 
 * @returns {Object} Hook result with:
 * - rows: Complete catalog tree data
 * - loading: Loading state
 * - error: Error message if any
 * - productTypes: Memoized unique product types
 * - collectionsByProductType: Helper to get collections for a product type
 * - variantsByProductTypeAndCollection: Helper to get variants
 * - skusByAll: Helper to get SKUs for product type + collection + variant
 */
export function useCatalogPicker() {
  const { data: rows, isLoading, error } = useQuery({
    queryKey: ['catalog-picker', ORGANIZATION_ID],
    queryFn: async (): Promise<CatalogPickerRow[]> => {
      // Step 1: Fetch CatalogItemProductTypes (junction table)
      const { data: cipData, error: cipError } = await supabase
        .from('CatalogItemProductTypes')
        .select('product_type_id, catalog_item_id')
        .eq('organization_id', ORGANIZATION_ID)
        .eq('deleted', false);

      if (cipError) {
        throw cipError;
      }

      if (!cipData || cipData.length === 0) {
        return [];
      }

      // Step 2: Extract unique IDs
      const productTypeIds = new Set<string>();
      const catalogItemIds = new Set<string>();
      const collectionIds = new Set<string>();

      cipData.forEach((row: any) => {
        if (row.product_type_id) productTypeIds.add(row.product_type_id);
        if (row.catalog_item_id) catalogItemIds.add(row.catalog_item_id);
      });

      // Step 3: Fetch ProductTypes
      const { data: productTypesData, error: ptError } = await supabase
        .from('ProductTypes')
        .select('id, code, name')
        .in('id', Array.from(productTypeIds))
        .eq('deleted', false);

      if (ptError) {
        throw ptError;
      }

      // Step 4: Fetch CatalogItems (with organization filter for RLS)
      // IMPORTANT: collection_name and variant_name are now text fields in CatalogItems, not FKs
      const { data: catalogItemsData, error: ciError } = await supabase
        .from('CatalogItems')
        .select('id, sku, name, item_name, catalog_name, description, item_type, measure_basis, uom, roll_width_m, is_fabric, collection_name, variant_name')
        .in('id', Array.from(catalogItemIds))
        .eq('organization_id', ORGANIZATION_ID)
        .eq('deleted', false);

      if (ciError) {
        throw ciError;
      }

      // Step 5: Extract unique collection names from CatalogItems (only for fabrics)
      // No longer need to fetch from CollectionsCatalog - collection_name is stored directly
      const collectionNamesSet = new Set<string>();
      catalogItemsData?.forEach((item: any) => {
        if (item.collection_name && item.is_fabric) {
          collectionNamesSet.add(item.collection_name);
        }
      });

      // Step 7: Create lookup maps
      const productTypesMap = new Map(
        (productTypesData || []).map((pt: any) => [pt.id, pt])
      );
      const catalogItemsMap = new Map(
        (catalogItemsData || []).map((ci: any) => [ci.id, ci])
      );

      // Step 6: Combine all data
      // For fabrics: require collection_name and variant_name
      // For non-fabrics: collection_name and variant_name can be NULL
      const result: CatalogPickerRow[] = cipData
        .map((row: any) => {
          const productType = productTypesMap.get(row.product_type_id);
          const catalogItem = catalogItemsMap.get(row.catalog_item_id);
          
          if (!productType || !catalogItem) {
            return null;
          }

          const isFabric = catalogItem.is_fabric === true;
          const collectionName = catalogItem.collection_name || null;

          // For fabrics, we need collection_name and variant_name
          if (isFabric && (!collectionName || !catalogItem.variant_name)) {
            return null;
          }

          // Calculate label based on item type
          let label: string;
          if (isFabric && collectionName && catalogItem.variant_name) {
            // For fabrics: Collection + Variant
            label = `${collectionName} ${catalogItem.variant_name}`;
          } else {
            // For non-fabrics: use item_name, fallback to name, description, or sku
            label = catalogItem.item_name || catalogItem.name || catalogItem.description || catalogItem.sku || '';
          }

          return {
            product_type_id: productType.id,
            product_type_code: productType.code || '',
            product_type_name: productType.name || '',
            collection_id: null as string | null, // No longer used - kept for compatibility
            collection_name: collectionName,
            variant_name: catalogItem.variant_name || null,
            catalog_item_id: catalogItem.id,
            sku: catalogItem.sku || '',
            item_name: catalogItem.item_name || catalogItem.name || '',
            catalog_name: catalogItem.catalog_name || null,
            description: catalogItem.description || null,
            label: label,
            item_type: catalogItem.item_type || '',
            measure_basis: catalogItem.measure_basis || '',
            uom: catalogItem.uom || '',
            roll_width_m: catalogItem.roll_width_m || null,
            is_fabric: isFabric,
          };
        })
        .filter((row): row is CatalogPickerRow => row !== null)
        .sort((a, b) => {
          // Sort by: pt.code, c.name (if fabric), v.variant_name (if fabric), ci.sku
          if (a.product_type_code !== b.product_type_code) {
            return a.product_type_code.localeCompare(b.product_type_code);
          }
          // For fabrics, sort by collection, then variant
          if (a.is_fabric && b.is_fabric) {
            const aCollection = a.collection_name || '';
            const bCollection = b.collection_name || '';
            if (aCollection !== bCollection) {
              return aCollection.localeCompare(bCollection);
            }
            const aVariant = a.variant_name || '';
            const bVariant = b.variant_name || '';
            if (aVariant !== bVariant) {
              return aVariant.localeCompare(bVariant);
            }
          }
          // For non-fabrics or final sort, use item_name or sku
          const aName = a.item_name || a.sku;
          const bName = b.item_name || b.sku;
          return aName.localeCompare(bName);
        });

      return result;
    },
    staleTime: 10 * 60 * 1000, // 10 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  });

  // Memoized helpers for filtering
  const productTypes = useMemo(() => {
    const types = new Map<string, { id: string; code: string; name: string }>();
    (rows || []).forEach((row) => {
      if (!types.has(row.product_type_id)) {
        types.set(row.product_type_id, {
          id: row.product_type_id,
          code: row.product_type_code,
          name: row.product_type_name,
        });
      }
    });
    return Array.from(types.values()).sort((a, b) => a.code.localeCompare(b.code));
  }, [rows]);

  const collectionsByProductType = useMemo(() => {
    return (productTypeId: string) => {
      if (!productTypeId) return [];
      // Use collection_name as both id and name since it's stored directly
      const collections = new Map<string, { id: string; name: string }>();
      (rows || [])
        .filter((row) => row.product_type_id === productTypeId && row.is_fabric && row.collection_name)
        .forEach((row) => {
          if (row.collection_name && !collections.has(row.collection_name)) {
            collections.set(row.collection_name, {
              id: row.collection_name, // Use collection_name as id
              name: row.collection_name,
            });
          }
        });
      return Array.from(collections.values()).sort((a, b) => a.name.localeCompare(b.name));
    };
  }, [rows]);

  const variantsByProductTypeAndCollection = useMemo(() => {
    return (productTypeId: string, collectionName: string) => {
      if (!productTypeId || !collectionName) return [];
      // variant_name is now text, so we use it as the key
      const variants = new Map<string, { id: string; name: string }>();
      (rows || [])
        .filter(
          (row) =>
            row.product_type_id === productTypeId && 
            row.collection_name === collectionName &&
            row.is_fabric &&
            row.variant_name
        )
        .forEach((row) => {
          // Use variant_name as both id and name since it's text
          if (row.variant_name && !variants.has(row.variant_name)) {
            variants.set(row.variant_name, {
              id: row.variant_name, // Use variant_name as id
              name: row.variant_name,
            });
          }
        });
      return Array.from(variants.values()).sort((a, b) => a.name.localeCompare(b.name));
    };
  }, [rows]);

  const skusByAll = useMemo(() => {
    return (productTypeId: string, collectionName: string | null, variantName: string | null) => {
      if (!productTypeId) return [];
      
      // For fabrics: filter by productType, collection_name, and variant
      // For non-fabrics: filter by productType only (collection and variant are null)
      return (rows || [])
        .filter((row) => {
          if (row.product_type_id !== productTypeId) return false;
          
          if (row.is_fabric) {
            // For fabrics, require collection_name and variant match
            return row.collection_name === collectionName && row.variant_name === variantName;
          } else {
            // For non-fabrics, collection and variant should be null
            return !collectionName && !variantName;
          }
        })
        .map((row) => ({
          value: row.catalog_item_id,
          label: row.catalog_name ? `${row.sku} - ${row.catalog_name}` : `${row.sku} - ${row.label}`,
          row,
        }))
        .sort((a, b) => a.row.sku.localeCompare(b.row.sku));
    };
  }, [rows]);

  return {
    rows: rows || [],
    loading: isLoading,
    error: error ? (error instanceof Error ? error.message : 'Failed to load catalog') : null,
    productTypes,
    collectionsByProductType,
    variantsByProductTypeAndCollection,
    skusByAll,
  };
}

