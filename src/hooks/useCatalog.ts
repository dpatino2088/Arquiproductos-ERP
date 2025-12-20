import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { CatalogItem } from '../types/catalog';

export function useCatalogItems(family?: string, productTypeId?: string) {
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    let isMounted = true; // Flag to prevent state updates if component unmounts

    async function fetchItems() {
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setItems([]);
          setError(null);
        }
        return;
      }

      // Allow loading all items when both productTypeId and family are undefined
      // This is needed for AccessoriesStep where we want to search all items
      // Only skip if explicitly provided but invalid
      if (productTypeId === null || family === null) {
        // Explicitly set to null means "don't load", undefined means "load all"
        if (isMounted) {
          setLoading(false);
          setItems([]);
          setError(null);
        }
        return;
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        if (import.meta.env.DEV) {
          console.log('🔍 useCatalogItems - Starting fetch:', {
            activeOrganizationId,
            productTypeId,
            family,
            hasProductTypeId: !!productTypeId,
            hasFamily: !!family,
          });
        }

        // First, try to get items with collection join
        // Note: We select all columns including collection_name and variant_name directly from CatalogItems
        let query = supabase
          .from('CatalogItems')
          .select(`
            *,
            collection:CatalogCollections!CatalogItems_collection_id_fkey(
              id,
              name,
              code
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        // Filter by productTypeId (preferred) or family (fallback for backward compatibility)
        let itemIds: string[] | undefined = undefined;
        
        // Validate productTypeId is a valid UUID before querying
        const isValidUUID = (str: string | undefined): boolean => {
          if (!str) return false;
          const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
          return uuidRegex.test(str);
        };
        
        if (productTypeId && isValidUUID(productTypeId)) {
          try {
            // First, get item IDs from CatalogItemProductTypes relation
            const { data: relatedItems, error: relationError } = await supabase
              .from('CatalogItemProductTypes')
              .select('catalog_item_id')
              .eq('product_type_id', productTypeId)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);
            
            if (relationError) {
              if (import.meta.env.DEV) {
                console.error('❌ Error fetching CatalogItemProductTypes:', relationError);
                console.log('   Falling back to family column...');
              }
              // Fallback to family if relation table doesn't exist or has errors
              if (family) {
                query = query.eq('family', family);
              }
            } else if (relatedItems && relatedItems.length > 0) {
              itemIds = relatedItems.map(r => r.catalog_item_id).filter(id => id); // Filter out any null/undefined
              
              // Only use .in() if we have valid IDs
              if (itemIds.length > 0) {
                query = query.in('id', itemIds);
                
                if (import.meta.env.DEV) {
                  console.log('✅ Filtering CatalogItems by productTypeId:', productTypeId, `(${itemIds.length} items found)`);
                }
              } else {
                // No valid IDs, try fallback
                if (family) {
                  query = query.eq('family', family);
                } else {
                  query = query.eq('id', '00000000-0000-0000-0000-000000000000'); // Impossible UUID
                }
              }
            } else {
              // No items found for this productType, try fallback to family
              if (import.meta.env.DEV) {
                console.warn('⚠️ No items found in CatalogItemProductTypes for productTypeId:', productTypeId);
                console.log('   Trying fallback to family column...');
              }
              
              if (family) {
                query = query.eq('family', family);
              } else {
                // No fallback available, return empty result
                query = query.eq('id', '00000000-0000-0000-0000-000000000000'); // Impossible UUID
              }
            }
          } catch (err) {
            // Catch any unexpected errors and fallback to family
            if (import.meta.env.DEV) {
              console.error('❌ Unexpected error in CatalogItemProductTypes query:', err);
              console.log('   Falling back to family column...');
            }
            if (family) {
              query = query.eq('family', family);
            }
          }
        } else if (family) {
          // Fallback to family column for backward compatibility
          query = query.eq('family', family);
          
          if (import.meta.env.DEV) {
            console.log('🔍 Filtering CatalogItems by family (fallback):', family);
            if (productTypeId && !isValidUUID(productTypeId)) {
              console.warn('⚠️ Invalid productTypeId format:', productTypeId);
            }
          }
        } else {
          // No filters - load all items (for AccessoriesStep search)
          if (import.meta.env.DEV) {
            console.log('🔍 Loading all CatalogItems (no filters)');
          }
        }

        let { data, error: queryError } = await query.order('created_at', { ascending: false });
        
        if (import.meta.env.DEV && !family && !productTypeId) {
          console.log('📊 useCatalogItems - Loaded all items:', {
            itemsFound: data?.length || 0,
            sampleItems: data?.slice(0, 3).map((item: any) => ({
              id: item.id,
              sku: item.sku,
              item_name: item.item_name,
              item_type: item.item_type,
              measure_basis: item.measure_basis,
            })),
          });
        }
        
        if (import.meta.env.DEV && family) {
          console.log('📊 useCatalogItems query result:', {
            family,
            itemsFound: data?.length || 0,
            sampleItems: data?.slice(0, 3).map((item: any) => ({
              sku: item.sku,
              collection_name: item.collection_name,
              variant_name: item.variant_name,
              family: item.family,
            })),
          });
        }

        // If join fails, try without join (fallback)
        if (queryError && (queryError.message?.includes('does not exist') || queryError.code === '42P01' || queryError.message?.includes('relationship'))) {
          let fallbackQuery = supabase
            .from('CatalogItems')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          // Filter by productTypeId (preferred) or family (fallback)
          if (productTypeId) {
            // Try to get item IDs from CatalogItemProductTypes
            const { data: relatedItems } = await supabase
              .from('CatalogItemProductTypes')
              .select('catalog_item_id')
              .eq('product_type_id', productTypeId)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);
            
            if (relatedItems && relatedItems.length > 0) {
              const itemIds = relatedItems.map(r => r.catalog_item_id);
              fallbackQuery = fallbackQuery.in('id', itemIds);
            } else {
              // No items found for this productType, return empty
              fallbackQuery = fallbackQuery.eq('id', '00000000-0000-0000-0000-000000000000'); // Impossible UUID
            }
          } else if (family) {
            fallbackQuery = fallbackQuery.eq('family', family);
          }

          const result = await fallbackQuery.order('created_at', { ascending: false });
          
          data = result.data;
          queryError = result.error;
        }

        // If still error, try Collections table instead of CatalogCollections
        if (queryError && queryError.message?.includes('CatalogCollections')) {
          let collectionsQuery = supabase
            .from('CatalogItems')
            .select(`
              *,
              collection:Collections!CatalogItems_collection_id_fkey(
                id,
                name,
                code
              )
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          // Filter by family if provided
          if (family) {
            collectionsQuery = collectionsQuery.eq('family', family);
          }

          const result = await collectionsQuery.order('created_at', { ascending: false });
          
          data = result.data;
          queryError = result.error;
        }

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CatalogItems:', queryError);
          }
          throw queryError;
        }

        // Map and enrich items - ensure item_name, sku, uom, and sale price are correctly mapped
        const enrichedItems: CatalogItem[] = (data || []).map((item: any) => {
          // Calculate sale price (PRECIO UN Venta):
          // Priority: msrp > (cost_exw * (1 + default_margin_pct/100)) > cost_exw * 1.5 (default 50% margin)
          let salePrice = 0;
          if (item.msrp) {
            salePrice = item.msrp;
          } else if (item.cost_exw && item.default_margin_pct) {
            salePrice = item.cost_exw * (1 + item.default_margin_pct / 100);
          } else if (item.cost_exw) {
            salePrice = item.cost_exw * 1.5; // Default 50% margin if no margin specified
          }
          
          // Map to CatalogItem interface
          const catalogItem: CatalogItem = {
            id: item.id,
            organization_id: item.organization_id,
            sku: item.sku || '',
            name: item.item_name || item.sku || '', // Map item_name to name for compatibility
            item_name: item.item_name || null, // Keep original item_name
            description: item.description || null,
            manufacturer_id: item.manufacturer_id || null,
            item_category_id: item.item_category_id || null,
            item_type: item.item_type || 'accessory',
            measure_basis: item.measure_basis || 'unit',
            uom: item.uom || 'unit', // UOM from database
            is_fabric: item.is_fabric || false,
            roll_width_m: item.roll_width_m || null,
            fabric_pricing_mode: item.fabric_pricing_mode || null,
            cost_exw: item.cost_exw || null,
            default_margin_pct: item.default_margin_pct || null,
            msrp: item.msrp || null,
            // Legacy pricing fields (mapped for backward compatibility)
            cost_price: item.cost_exw || 0,
            unit_price: salePrice, // PRECIO UN Venta (Sale Price)
            active: item.active !== undefined ? item.active : true,
            discontinued: item.discontinued || false,
            collection_id: item.collection_id || null,
            collection_name: item.collection_name || (item.collection?.name || item.collection?.code || null),
            variant_id: item.variant_id || null,
            variant_name: item.variant_name || null,
            deleted: item.deleted || false,
            archived: item.archived || false,
            created_at: item.created_at || new Date().toISOString(),
            updated_at: item.updated_at || null,
            metadata: item.metadata || {},
            created_by: item.created_by || null,
            updated_by: item.updated_by || null,
          };
          
          return catalogItem;
        });

        if (isMounted) {
          setItems(enrichedItems);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading catalog items';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogItems:', err);
        }
        if (isMounted) {
          setError(errorMessage);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchItems();

    return () => {
      isMounted = false; // Cleanup: prevent state updates after unmount
    };
  }, [activeOrganizationId, refreshTrigger, family, productTypeId]);

  return { items, loading, error, refetch };
}

export function useCreateCatalogItem() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createItem = async (itemData: Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .insert({
          ...itemData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsCreating(false);
    }
  };

  return { createItem, isCreating };
}

export function useUpdateCatalogItem() {
  const [isUpdating, setIsUpdating] = useState(false);

  const updateItem = async (id: string, itemData: Partial<CatalogItem>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .update(itemData)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateItem, isUpdating };
}

export function useDeleteCatalogItem() {
  const [isDeleting, setIsDeleting] = useState(false);

  const deleteItem = async (id: string) => {
    setIsDeleting(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .update({ deleted: true })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsDeleting(false);
    }
  };

  return { deleteItem, isDeleting };
}

// Hook para cargar CatalogCollections
export interface CatalogCollection {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  description?: string | null;
  active: boolean;
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useCatalogCollections(family?: string, productTypeId?: string) {
  const [collections, setCollections] = useState<CatalogCollection[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    let isMounted = true; // Flag to prevent state updates if component unmounts

    async function fetchCollections() {
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setCollections([]);
          setError(null);
        }
        return;
      }

      // Note: Collections can be fetched without filters (to show all collections)
      // But if we have productTypeId or family, we should filter
      // We'll still try to fetch even without filters, but log it
      if (!productTypeId && !family) {
        if (import.meta.env.DEV) {
          console.log('ℹ️ useCatalogCollections - Fetching all collections (no filters)');
        }
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        if (import.meta.env.DEV) {
          console.log('🔍 useCatalogCollections - Starting fetch:', {
            activeOrganizationId,
            productTypeId,
            family,
            hasProductTypeId: !!productTypeId,
            hasFamily: !!family,
          });
        }

        let collectionsData: CatalogCollection[] = [];

        // First, try to get from CatalogCollections table
        let query = supabase
          .from('CatalogCollections')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        let { data, error: queryError } = await query.eq('active', true);

        // If error and it's about 'active' column, try without it
        if (queryError && queryError.message?.includes('active')) {
          const result = await supabase
            .from('CatalogCollections')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          
          data = result.data;
          queryError = result.error;
        }

        // If still error and it's about table not found, try 'Collections'
        if (queryError && (queryError.message?.includes('does not exist') || queryError.code === '42P01')) {
          query = supabase
            .from('Collections')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          let result = await query.eq('active', true);
          data = result.data;
          queryError = result.error;

          // If 'active' doesn't exist, try without it
          if (queryError && queryError.message?.includes('active')) {
            result = await query;
            data = result.data;
            queryError = result.error;
          }
        }

        // If we got data from tables, use it
        if (data && data.length > 0) {
          collectionsData = data.map((item: any) => ({
            id: item.id,
            organization_id: item.organization_id,
            name: item.name,
            code: item.code || null,
            description: item.description || null,
            active: item.active !== undefined ? item.active : true,
            sort_order: item.sort_order || 0,
            deleted: item.deleted || false,
            archived: item.archived || false,
            created_at: item.created_at,
            updated_at: item.updated_at || null,
          }));
        } else {
          // If no data from tables, extract collections from CatalogItems
          if (import.meta.env.DEV) {
            console.log('📦 No collections found in tables, extracting from CatalogItems...', family ? `(filtered by family: ${family})` : '');
          }

          // First, let's check what family values exist in the database (for debugging)
          if (import.meta.env.DEV && family) {
            const { data: allFamilies } = await supabase
              .from('CatalogItems')
              .select('family')
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .not('family', 'is', null);
            
            const uniqueFamilies = [...new Set((allFamilies || []).map((item: any) => item.family))];
            console.log('🔍 Available family values in CatalogItems:', uniqueFamilies);
            console.log('🔍 Looking for family:', family);
            console.log('🔍 Exact match?', uniqueFamilies.includes(family));
          }

          let itemsQuery = supabase
            .from('CatalogItems')
            .select('collection_name, manufacturer_id, family')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .not('collection_name', 'is', null);

          // Filter by productTypeId (preferred) or family (fallback)
          // Validate productTypeId is a valid UUID before querying
          const isValidUUID = (str: string | undefined): boolean => {
            if (!str) return false;
            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
            return uuidRegex.test(str);
          };
          
          if (productTypeId && isValidUUID(productTypeId)) {
            try {
              // First, get item IDs from CatalogItemProductTypes relation
              const { data: relatedItems, error: relationError } = await supabase
                .from('CatalogItemProductTypes')
                .select('catalog_item_id')
                .eq('product_type_id', productTypeId)
                .eq('organization_id', activeOrganizationId)
                .eq('deleted', false);
              
              if (relationError) {
                if (import.meta.env.DEV) {
                  console.error('Error fetching CatalogItemProductTypes:', relationError);
                }
                // Fallback to family if relation table doesn't exist
                if (family) {
                  itemsQuery = itemsQuery.eq('family', family);
                } else {
                  itemsQuery = itemsQuery.eq('id', '00000000-0000-0000-0000-000000000000');
                }
              } else if (relatedItems && relatedItems.length > 0) {
                const itemIds = relatedItems.map(r => r.catalog_item_id).filter(id => id); // Filter out null/undefined
                
                // Only use .in() if we have valid IDs
                if (itemIds.length > 0) {
                  itemsQuery = itemsQuery.in('id', itemIds);
                  
                  if (import.meta.env.DEV) {
                    console.log('🔍 Filtering CatalogItems by productTypeId:', productTypeId, `(${itemIds.length} items)`);
                  }
                } else {
                  // No valid IDs, return empty result
                  itemsQuery = itemsQuery.eq('id', '00000000-0000-0000-0000-000000000000');
                }
              } else {
                // No items found, try fallback to family
                if (family) {
                  itemsQuery = itemsQuery.eq('family', family);
                } else {
                  itemsQuery = itemsQuery.eq('id', '00000000-0000-0000-0000-000000000000');
                }
              }
            } catch (err) {
              // Catch any unexpected errors and fallback to family
              if (import.meta.env.DEV) {
                console.error('❌ Unexpected error in CatalogItemProductTypes query (fallback):', err);
              }
              if (family) {
                itemsQuery = itemsQuery.eq('family', family);
              } else {
                itemsQuery = itemsQuery.eq('id', '00000000-0000-0000-0000-000000000000');
              }
            }
          } else if (family) {
            itemsQuery = itemsQuery.eq('family', family);
            
            if (import.meta.env.DEV) {
              console.log('🔍 Filtering CatalogItems by family (fallback):', family);
              if (productTypeId && !isValidUUID(productTypeId)) {
                console.warn('⚠️ Invalid productTypeId format:', productTypeId);
              }
            }
          }

          const { data: itemsData, error: itemsError } = await itemsQuery;
          
          if (import.meta.env.DEV) {
            console.log('📊 CatalogItems query result:', {
              family: family || 'none (all families)',
              itemsFound: itemsData?.length || 0,
              sampleItems: itemsData?.slice(0, 5).map((item: any) => ({
                collection_name: item.collection_name,
                family: item.family,
              })),
            });
            
            if (family && (!itemsData || itemsData.length === 0)) {
              console.warn('⚠️ No items found with family:', family);
              console.warn('💡 Tip: Check if family values in database match the expected format');
            }
          }

          if (itemsError) {
            throw itemsError;
          }

          // Extract unique collection names
          const uniqueCollections = new Map<string, { name: string; manufacturer_id?: string }>();
          
          (itemsData || []).forEach((item: any) => {
            const collectionName = item.collection_name ? String(item.collection_name).trim() : '';
            if (collectionName && !uniqueCollections.has(collectionName)) {
              uniqueCollections.set(collectionName, {
                name: collectionName,
                manufacturer_id: item.manufacturer_id,
              });
            }
          });

          // Convert to CatalogCollection format
          collectionsData = Array.from(uniqueCollections.entries()).map(([name, data], index) => ({
            id: `collection-${name.toLowerCase().replace(/\s+/g, '-')}`, // Generate ID from name
            organization_id: activeOrganizationId,
            name: name,
            code: name.substring(0, 3).toUpperCase(),
            description: null,
            active: true,
            sort_order: index,
            deleted: false,
            archived: false,
            created_at: new Date().toISOString(),
            updated_at: null,
          }));

          if (import.meta.env.DEV) {
            console.log(`✅ Extracted ${collectionsData.length} collections from CatalogItems:`, collectionsData.map(c => c.name));
          }
        }

        // Sort manually if sort_order exists, otherwise sort by name
        // Use spread operator to avoid mutating the original array
        const sortedData = [...collectionsData].sort((a, b) => {
          if (a.sort_order !== undefined && b.sort_order !== undefined) {
            if (a.sort_order !== b.sort_order) {
              return (a.sort_order || 999) - (b.sort_order || 999);
            }
          }
          return (a.name || '').localeCompare(b.name || '');
        });

        if (isMounted) {
          setCollections(sortedData);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading collections';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogCollections:', err);
        }
        if (isMounted) {
          setError(errorMessage);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchCollections();

    return () => {
      isMounted = false; // Cleanup: prevent state updates after unmount
    };
  }, [activeOrganizationId, refreshTrigger, family, productTypeId]);

  return { collections, loading, error, refetch };
}

// Hook for Collections CRUD operations
export function useCatalogCollectionsCRUD() {
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const deleteCollection = async (id: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsDeleting(true);
    try {
      // Try CatalogCollections first, then Collections as fallback
      let { error } = await supabase
        .from('CatalogCollections')
        .update({ deleted: true })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      // If table doesn't exist, try Collections
      if (error && (error.message?.includes('does not exist') || error.code === '42P01')) {
        const result = await supabase
          .from('Collections')
          .update({ deleted: true })
          .eq('id', id)
          .eq('organization_id', activeOrganizationId);
        
        error = result.error;
      }

      if (error) {
        throw error;
      }
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    deleteCollection,
    isDeleting,
  };
}

// Hook para cargar CatalogVariants
export interface CatalogVariant {
  id: string;
  organization_id: string;
  collection_id: string;
  name: string;
  code?: string | null;
  color_name?: string | null;
  active: boolean;
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useCatalogVariants(collectionId?: string) {
  const [variants, setVariants] = useState<CatalogVariant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    let isMounted = true; // Flag to prevent state updates if component unmounts

    async function fetchVariants() {
      if (!activeOrganizationId) {
        if (isMounted) {
          setLoading(false);
          setVariants([]);
          setError(null);
        }
        return;
      }

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        let variantsData: CatalogVariant[] = [];

        // First, try to get from CatalogVariants table
        let query = supabase
          .from('CatalogVariants')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        let { data, error: queryError } = await query.eq('active', true);

        // If error and it's about 'active' column, try without it
        if (queryError && queryError.message?.includes('active')) {
          const result = await supabase
            .from('CatalogVariants')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          
          data = result.data;
          queryError = result.error;
        }

        // If we got data from table, use it
        if (data && data.length > 0) {
          variantsData = data.map((item: any) => ({
            id: item.id,
            organization_id: item.organization_id,
            collection_id: item.collection_id,
            name: item.name,
            code: item.code || null,
            color_name: item.color_name || null,
            active: item.active !== undefined ? item.active : true,
            sort_order: item.sort_order || 0,
            deleted: item.deleted || false,
            archived: item.archived || false,
            created_at: item.created_at,
            updated_at: item.updated_at || null,
          }));

          // Filter by collectionId if provided
          if (collectionId) {
            variantsData = variantsData.filter(v => v.collection_id === collectionId);
          }
        } else {
          // If no data from table, extract variants from CatalogItems
          if (import.meta.env.DEV) {
            console.log('📦 No variants found in table, extracting from CatalogItems...');
          }

          let itemsQuery = supabase
            .from('CatalogItems')
            .select('id, variant_name, collection_name, sku')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .not('variant_name', 'is', null)
            .not('collection_name', 'is', null);

          const { data: itemsData, error: itemsError } = await itemsQuery;

          if (itemsError) {
            throw itemsError;
          }

          // Extract unique variants grouped by collection
          const uniqueVariants = new Map<string, CatalogVariant>();
          
          (itemsData || []).forEach((item: any) => {
            const variantName = item.variant_name ? String(item.variant_name).trim() : '';
            const collectionName = item.collection_name ? String(item.collection_name).trim() : '';
            
            if (variantName && collectionName) {
              // Generate collection_id from collection name (same format as in useCatalogCollections)
              const generatedCollectionId = `collection-${collectionName.toLowerCase().replace(/\s+/g, '-')}`;
              
              // Filter by collectionId if provided
              if (collectionId && generatedCollectionId !== collectionId) {
                return;
              }

              const variantKey = `${generatedCollectionId}-${variantName}`;
              
              if (!uniqueVariants.has(variantKey)) {
                uniqueVariants.set(variantKey, {
                  id: item.id || `variant-${variantKey}`,
                  organization_id: activeOrganizationId,
                  collection_id: generatedCollectionId,
                  name: variantName,
                  code: item.sku || null,
                  color_name: variantName,
                  active: true,
                  sort_order: uniqueVariants.size,
                  deleted: false,
                  archived: false,
                  created_at: new Date().toISOString(),
                  updated_at: null,
                });
              }
            }
          });

          variantsData = Array.from(uniqueVariants.values());

          if (import.meta.env.DEV) {
            console.log(`✅ Extracted ${variantsData.length} variants from CatalogItems for collection ${collectionId || 'all'}:`, 
              variantsData.map(v => v.name));
          }
        }

        // Sort manually if sort_order exists, otherwise sort by name
        // Use spread operator to avoid mutating the original array
        const sortedData = [...variantsData].sort((a, b) => {
          if (a.sort_order !== undefined && b.sort_order !== undefined) {
            if (a.sort_order !== b.sort_order) {
              return (a.sort_order || 999) - (b.sort_order || 999);
            }
          }
          return (a.name || '').localeCompare(b.name || '');
        });

        if (isMounted) {
          setVariants(sortedData);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading variants';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogVariants:', err);
        }
        if (isMounted) {
          setError(errorMessage);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchVariants();

    return () => {
      isMounted = false; // Cleanup: prevent state updates after unmount
    };
  }, [activeOrganizationId, collectionId]);

  return { variants, loading, error };
}

// Hook para cargar Manufacturers
export interface Manufacturer {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  notes?: string | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useManufacturers() {
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchManufacturers() {
      if (!activeOrganizationId) {
        setLoading(false);
        setManufacturers([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('Manufacturers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Manufacturers:', queryError);
          }
          throw queryError;
        }

        setManufacturers(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading manufacturers';
        if (import.meta.env.DEV) {
          console.error('Error fetching Manufacturers:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchManufacturers();
  }, [activeOrganizationId]);

  return { manufacturers, loading, error };
}

// Hook para cargar Operating Drives desde CatalogItems
// Operating Drives son CatalogItems con item_type='component' o 'accessory'
// y metadata que indica que son operating drives
export interface OperatingDrive {
  id: string;
  name: string;
  code?: string;
  manufacturer?: string;
  system?: 'manual' | 'motorized';
  sku: string;
  metadata?: any;
}

export function useOperatingDrives() {
  const [drives, setDrives] = useState<OperatingDrive[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchDrives() {
      if (!activeOrganizationId) {
        setLoading(false);
        setDrives([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Buscar CatalogItems que sean operating drives
        // Pueden ser item_type='component' o 'accessory' con metadata.operatingDrive=true
        // O podemos buscar por category o metadata específico
        const { data, error: queryError } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('active', true)
          .in('item_type', ['component', 'accessory'])
          .order('item_name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Operating Drives:', queryError);
          }
          throw queryError;
        }

        // Filtrar y mapear items que sean operating drives
        // Por ahora, asumimos que todos los components/accessories pueden ser operating drives
        // O podemos usar metadata para identificar específicamente
        const operatingDrives: OperatingDrive[] = (data || [])
          .filter((item: any) => {
            // Filtrar por metadata si existe, o incluir todos los components/accessories
            const metadata = item.metadata || {};
            return metadata.operatingDrive === true || 
                   metadata.category === 'Motors' || 
                   metadata.category === 'Controls' ||
                   item.item_type === 'component'; // Por ahora incluir todos los components
          })
          .map((item: any) => ({
            id: item.id,
            name: item.item_name || item.sku,
            code: item.sku,
            manufacturer: item.metadata?.manufacturer || item.metadata?.category,
            system: item.metadata?.system,
            sku: item.sku,
            metadata: item.metadata,
          }));

        setDrives(operatingDrives);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading operating drives';
        if (import.meta.env.DEV) {
          console.error('Error fetching Operating Drives:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchDrives();
  }, [activeOrganizationId]);

  return { drives, loading, error };
}

// Hook para cargar ItemCategories
export interface ItemCategory {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  is_group: boolean;
  parent_category_id?: string | null;
  sort_order?: number | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useItemCategories() {
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchCategories() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCategories([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('ItemCategories')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching ItemCategories:', queryError);
          }
          throw queryError;
        }

        setCategories(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading categories';
        if (import.meta.env.DEV) {
          console.error('Error fetching ItemCategories:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCategories();
  }, [activeOrganizationId]);

  return { categories, loading, error };
}

// Hook para cargar solo las categorías hoja (leaf categories - no grupos)
export function useLeafItemCategories() {
  const { categories, loading, error } = useItemCategories();
  
  const leafCategories = categories.filter(cat => !cat.is_group);
  
  return { categories: leafCategories, loading, error };
}

// Hook para CRUD de ItemCategories
export function useItemCategoriesCRUD() {
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchCategories() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCategories([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('ItemCategories')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching ItemCategories:', queryError);
          }
          throw queryError;
        }

        setCategories(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading categories';
        if (import.meta.env.DEV) {
          console.error('Error fetching ItemCategories:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCategories();
  }, [activeOrganizationId]);

  const createCategory = async (categoryData: Omit<ItemCategory, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('ItemCategories')
        .insert({
          ...categoryData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) throw error;
      
      // Refresh categories
      setCategories(prev => [...prev, data]);
      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateCategory = async (id: string, categoryData: Partial<ItemCategory>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('ItemCategories')
        .update({
          ...categoryData,
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      
      // Refresh categories
      setCategories(prev => prev.map(cat => cat.id === id ? data : cat));
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCategory = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('ItemCategories')
        .update({ deleted: true })
        .eq('id', id);

      if (error) throw error;
      
      // Refresh categories
      setCategories(prev => prev.filter(cat => cat.id !== id));
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    categories,
    loading,
    error,
    createCategory,
    updateCategory,
    deleteCategory,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// Hook para CRUD de Manufacturers
export function useManufacturersCRUD() {
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchManufacturers() {
      if (!activeOrganizationId) {
        setLoading(false);
        setManufacturers([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('Manufacturers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Manufacturers:', queryError);
          }
          throw queryError;
        }

        setManufacturers(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading manufacturers';
        if (import.meta.env.DEV) {
          console.error('Error fetching Manufacturers:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchManufacturers();
  }, [activeOrganizationId]);

  const createManufacturer = async (manufacturerData: Omit<Manufacturer, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('Manufacturers')
        .insert({
          ...manufacturerData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) throw error;
      
      // Refresh manufacturers
      setManufacturers(prev => [...prev, data]);
      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateManufacturer = async (id: string, manufacturerData: Partial<Manufacturer>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('Manufacturers')
        .update({
          ...manufacturerData,
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      
      // Refresh manufacturers
      setManufacturers(prev => prev.map(m => m.id === id ? data : m));
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteManufacturer = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('Manufacturers')
        .update({ deleted: true })
        .eq('id', id);

      if (error) throw error;
      
      // Refresh manufacturers
      setManufacturers(prev => prev.filter(m => m.id !== id));
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    manufacturers,
    loading,
    error,
    createManufacturer,
    updateManufacturer,
    deleteManufacturer,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

