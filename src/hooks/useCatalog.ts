import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { CatalogItem, BOMComponent, BOMComponentWithItem, CollectionsCatalog, CollectionsCatalogWithItem } from '../types/catalog';

export function useCatalogItems(collectionId?: string | null) {
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchItems() {
      if (!activeOrganizationId) {
        setLoading(false);
        setItems([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 useCatalogItems: Fetching items for organization:', activeOrganizationId, collectionId ? `collection: ${collectionId}` : '');
        }

        // Build query - use only columns that actually exist in CatalogItems table
        // Based on actual schema: id, organization_id, sku, item_name, description, manufacturer_id, 
        // item_category_id, collection_name, variant_name, item_type, measure_basis, uom, 
        // is_fabric, roll_width_m, fabric_pricing_mode, cost_exw, default_margin_pct, msrp, 
        // active, discontinued, deleted, archived, created_at, updated_at
        // Note: collection_id and variant_id are deprecated - use collection_name and variant_name instead
        // Note: default_margin_pct and msrp are added in migration 19/35
        let query = supabase
          .from('CatalogItems')
          .select('id, organization_id, sku, item_name, description, manufacturer_id, item_category_id, collection_name, variant_name, item_type, measure_basis, uom, is_fabric, roll_width_m, fabric_pricing_mode, cost_exw, default_margin_pct, msrp, active, discontinued, deleted, archived, created_at, updated_at')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        // Filter by collection_name if provided (preferred) or collection_id (for backward compatibility)
        if (collectionId) {
          // Try collection_name first, then fallback to collection_id
          query = query.or(`collection_name.eq.${collectionId},collection_id.eq.${collectionId}`);
        }

        query = query.order('created_at', { ascending: false });

        const { data, error: queryError } = await query;

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching CatalogItems:', queryError);
            console.error('   Error code:', queryError.code);
            console.error('   Error message:', queryError.message);
            console.error('   Error details:', queryError.details);
          }
          throw queryError;
        }

        if (import.meta.env.DEV) {
          console.log('✅ useCatalogItems: Fetched', data?.length || 0, 'items');
          if (data && data.length > 0 && data[0]) {
            const sampleItem = data[0];
            console.log('   Sample item:', {
              id: sampleItem.id,
              sku: sampleItem.sku,
              collection_name: sampleItem.collection_name,
              variant_name: sampleItem.variant_name,
              is_fabric: sampleItem.is_fabric,
            });
            // Count items with collection_name
            const itemsWithCollection = (data || []).filter((item: any) => 
              item.collection_name && String(item.collection_name).trim().length > 0
            );
            console.log('   Items with collection_name:', itemsWithCollection.length);
            if (itemsWithCollection.length > 0) {
              const uniqueCollections = new Set(
                itemsWithCollection.map((item: any) => String(item.collection_name).trim())
              );
              console.log('   Unique collection_names:', Array.from(uniqueCollections));
            }
          }
        }

        // Map data to CatalogItem interface - add fields for compatibility
        const mappedItems: CatalogItem[] = (data || []).map((item: any) => ({
          ...item,
          name: item.item_name || item.sku || '', // Map item_name to name for interface compatibility
          cost_price: item.cost_exw || 0, // Map cost_exw to cost_price
          unit_price: 0, // Default value since unit_price doesn't exist in table
          msrp: item.msrp || null, // Include msrp if it exists
          updated_at: item.updated_at || null, // Include updated_at
          metadata: {}, // Default empty object since metadata doesn't exist
          created_by: null, // Default null
          updated_by: null, // Default null
        }));

        setItems(mappedItems);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading catalog items';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogItems:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchItems();
  }, [activeOrganizationId, collectionId, refreshTrigger]);

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

// ====================================================
// BOM Components Hooks
// ====================================================

/**
 * Hook to fetch BOM components for a parent item
 */
export function useBOMComponents(parentItemId: string | null) {
  const [components, setComponents] = useState<BOMComponentWithItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchComponents() {
      if (!activeOrganizationId || !parentItemId) {
        setLoading(false);
        setComponents([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('BOMComponents')
          .select(`
            *,
            component_item:CatalogItems!BOMComponents_component_item_id_fkey (
              id,
              sku,
              item_name,
              item_type,
              cost_exw,
              msrp,
              uom,
              measure_basis
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('parent_item_id', parentItemId)
          .eq('deleted', false)
          .order('sequence_order', { ascending: true })
          .order('created_at', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching BOMComponents:', queryError);
          }
          throw queryError;
        }

        // Transform data to include component_item details
        const transformedData = (data || []).map((item: any) => ({
          ...item,
          component_item: item.component_item || null,
        }));

        setComponents(transformedData);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading BOM components';
        if (import.meta.env.DEV) {
          console.error('Error fetching BOMComponents:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchComponents();
  }, [activeOrganizationId, parentItemId, refreshTrigger]);

  return { components, loading, error, refetch };
}

/**
 * Hook to create a BOM component
 */
export function useCreateBOMComponent() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createComponent = async (componentData: Omit<BOMComponent, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const insertData = {
        ...componentData,
        organization_id: activeOrganizationId,
      };

      const { data, error } = await supabase
        .from('BOMComponents')
        .insert(insertData)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error creating BOMComponent:', error);
        }
        throw error;
      }

      return data;
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error creating BOMComponent:', err);
      }
      throw err;
    } finally {
      setIsCreating(false);
    }
  };

  return { createComponent, isCreating };
}

/**
 * Hook to update a BOM component
 */
export function useUpdateBOMComponent() {
  const [isUpdating, setIsUpdating] = useState(false);

  const updateComponent = async (id: string, componentData: Partial<BOMComponent>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('BOMComponents')
        .update(componentData)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error updating BOMComponent:', error);
        }
        throw error;
      }

      return data;
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error updating BOMComponent:', err);
      }
      throw err;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateComponent, isUpdating };
}

/**
 * Hook to delete a BOM component (soft delete)
 */
export function useDeleteBOMComponent() {
  const [isDeleting, setIsDeleting] = useState(false);

  const deleteComponent = async (id: string) => {
    setIsDeleting(true);
    try {
      const { data, error } = await supabase
        .from('BOMComponents')
        .update({ deleted: true })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error deleting BOMComponent:', error);
        }
        throw error;
      }

      return data;
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error deleting BOMComponent:', err);
      }
      throw err;
    } finally {
      setIsDeleting(false);
    }
  };

  return { deleteComponent, isDeleting };
}

// Hook para cargar Collections
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

export function useCatalogCollections() {
  const [collections, setCollections] = useState<CatalogCollection[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCollections() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCollections([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 Fetching Collections for organization:', activeOrganizationId);
        }

        // Get unique collections from CatalogItems using collection_name
        // Since CollectionsCatalog table doesn't exist, we derive collections from CatalogItems
        // Filter by is_fabric=true and collection_name IS NOT NULL
        // Include manufacturer_id to allow filtering by manufacturer
        const { data: catalogItems, error: queryError } = await supabase
          .from('CatalogItems')
          .select('collection_name, is_fabric, manufacturer_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('is_fabric', true) // Only get fabric items
          .not('collection_name', 'is', null); // collection_name must not be null

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching Collections from CatalogItems:', queryError);
            console.error('   Error code:', queryError.code);
            console.error('   Error message:', queryError.message);
            console.error('   Error details:', queryError.details);
            console.error('   Active Organization ID:', activeOrganizationId);
          }
          throw queryError;
        }

        if (import.meta.env.DEV) {
          console.log('🔍 Raw catalogItems fetched:', catalogItems?.length || 0, 'items');
          if (catalogItems && catalogItems.length > 0) {
            console.log('   Sample items:', catalogItems.slice(0, 3).map((item: any) => ({
              collection_name: item.collection_name,
              is_fabric: item.is_fabric,
            })));
          }
        }

        // Extract unique collection names (only for fabrics)
        // Filter out empty strings and null values
        // Store manufacturer_id for each collection (use the most common manufacturer_id for each collection)
        const uniqueCollections = new Map<string, { name: string; is_fabric: boolean; manufacturer_id?: string | null }>();
        const collectionManufacturers = new Map<string, Map<string, number>>(); // collection_name -> { manufacturer_id -> count }
        
        (catalogItems || []).forEach((item: any) => {
          // Double-check: ensure collection_name exists and is not empty
          if (item.collection_name) {
            const collectionName = String(item.collection_name).trim();
            // Only add if collection_name is not empty after trim
            if (collectionName.length > 0) {
              // Verify is_fabric is true (should already be filtered by query, but double-check)
              if (item.is_fabric === true || item.is_fabric === 'true' || item.is_fabric === 1) {
                // Track manufacturer_id for this collection
                if (item.manufacturer_id) {
                  if (!collectionManufacturers.has(collectionName)) {
                    collectionManufacturers.set(collectionName, new Map());
                  }
                  const manufacturerCounts = collectionManufacturers.get(collectionName)!;
                  const manufacturerId = String(item.manufacturer_id);
                  manufacturerCounts.set(manufacturerId, (manufacturerCounts.get(manufacturerId) || 0) + 1);
                }
                
                if (!uniqueCollections.has(collectionName)) {
                  uniqueCollections.set(collectionName, {
                    name: collectionName,
                    is_fabric: true,
                    manufacturer_id: item.manufacturer_id || null,
                  });
                }
              }
            }
          }
        });
        
        // Update collections with the most common manufacturer_id for each collection
        uniqueCollections.forEach((collection, collectionName) => {
          const manufacturerCounts = collectionManufacturers.get(collectionName);
          if (manufacturerCounts && manufacturerCounts.size > 0) {
            // Find the manufacturer_id with the highest count
            let maxCount = 0;
            let mostCommonManufacturerId: string | null = null;
            manufacturerCounts.forEach((count, manufacturerId) => {
              if (count > maxCount) {
                maxCount = count;
                mostCommonManufacturerId = manufacturerId;
              }
            });
            collection.manufacturer_id = mostCommonManufacturerId;
          }
        });

        if (import.meta.env.DEV) {
          console.log('✅ Collections fetched from CatalogItems:', uniqueCollections.size, 'unique collections');
          if (uniqueCollections.size > 0) {
            const firstCollection = Array.from(uniqueCollections.values())[0];
            console.log('   Sample collection:', firstCollection);
          } else {
            console.warn('⚠️  No collections found for organization:', activeOrganizationId);
            console.warn('   This could mean:');
            console.warn('   1. No fabric items with collection_name exist yet');
            console.warn('   2. RLS policies are blocking access');
            console.warn('   3. All items are marked as deleted');
          }
        }

        // Sort by collection name and map to CatalogCollection interface
        // Use collection_name as both id and name since we're deriving from CatalogItems
        const sortedData = Array.from(uniqueCollections.values())
          .sort((a, b) => a.name.localeCompare(b.name));
        
        // Map to CatalogCollection interface
        // Generate synthetic IDs using collection_name (since we don't have real IDs from CollectionsCatalog)
        const mappedData = sortedData.map((item: any) => ({
          id: item.name, // Use collection_name as id since CollectionsCatalog doesn't exist
          organization_id: activeOrganizationId,
          name: item.name, // collection_name is the name
          code: null, // Not available from CatalogItems
          description: null, // Not available from CatalogItems
          active: true, // Default to active
          sort_order: 0, // Default sort order
          deleted: false,
          archived: false,
          created_at: new Date().toISOString(), // Synthetic timestamp
          updated_at: null,
          manufacturer_id: item.manufacturer_id || null, // Include manufacturer_id from CatalogItems
        }));

        setCollections(mappedData);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading collections';
        if (import.meta.env.DEV) {
          console.error('Error fetching Collections:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCollections();
  }, [activeOrganizationId, refreshTrigger]);

  return { collections, loading, error, refetch };
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
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchVariants() {
      if (!activeOrganizationId) {
        setLoading(false);
        setVariants([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 Fetching CatalogVariants for organization:', activeOrganizationId, collectionId ? `collection: ${collectionId}` : '');
        }

        // Use CollectionVariants table (not CatalogVariants)
        // Select only columns that exist: id, organization_id, collection_id, variant_name
        let query = supabase
          .from('CollectionVariants')
          .select('id, organization_id, collection_id, variant_name, deleted, archived, created_at, updated_at')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('variant_name', { ascending: true });

        if (collectionId) {
          query = query.eq('collection_id', collectionId);
        }

        const { data, error: queryError } = await query;

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching CatalogVariants:', queryError);
            console.error('   Error code:', queryError.code);
            console.error('   Error message:', queryError.message);
            console.error('   Error details:', queryError.details);
          }
          throw queryError;
        }

        if (import.meta.env.DEV) {
          console.log('✅ CollectionVariants fetched:', data?.length || 0, 'variants');
        }

        // Map to CatalogVariant interface, handling field name differences
        // CollectionVariants uses variant_name, not name
        const mappedData = (data || []).map((item: any) => ({
          id: item.id,
          organization_id: item.organization_id,
          collection_id: item.collection_id,
          name: item.variant_name || '', // Map variant_name to name
          code: item.code || null, // May not exist
          color_name: item.variant_name || null, // Use variant_name as color_name
          active: item.active !== undefined ? item.active : true, // May not exist
          sort_order: item.sort_order !== undefined ? item.sort_order : 0, // May not exist
          deleted: item.deleted || false,
          archived: item.archived || false,
          created_at: item.created_at,
          updated_at: item.updated_at || null,
        }));

        setVariants(mappedData);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading variants';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogVariants:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchVariants();
  }, [activeOrganizationId, collectionId, refreshTrigger]);

  return { variants, loading, error, refetch };
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
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

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
  }, [activeOrganizationId, refreshTrigger]);

  return { manufacturers, loading, error, refetch };
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
        // Nota: item_type puede no existir en el esquema actual, usar metadata como fallback
        let query = supabase
          .from('CatalogItems')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('active', true);
        
        // Intentar filtrar por item_type si existe, sino usar metadata
        // Por ahora, obtener todos los items activos y filtrar después
        const { data, error: queryError } = await query.order('name', { ascending: true });

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
            const itemType = item.item_type || metadata.item_type_inferred;
            return metadata.operatingDrive === true || 
                   metadata.category === 'Motors' || 
                   metadata.category === 'Controls' ||
                   itemType === 'component' ||
                   itemType === 'accessory'; // Incluir components y accessories
          })
          .map((item: any) => ({
            id: item.id,
            name: item.name,
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

// ====================================================
// Manufacturers CRUD Hooks
// ====================================================

export function useManufacturersCRUD() {
  const { manufacturers, loading, error, refetch } = useManufacturers();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createManufacturer = async (data: Omit<Manufacturer, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('Manufacturers')
        .insert({ ...data, organization_id: activeOrganizationId })
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateManufacturer = async (id: string, data: Partial<Manufacturer>) => {
    setIsUpdating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('Manufacturers')
        .update(data)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteManufacturer = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('Manufacturers')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    manufacturers,
    loading,
    error,
    refetch,
    createManufacturer,
    updateManufacturer,
    deleteManufacturer,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// ItemCategories CRUD Hooks
// ====================================================

export interface ItemCategory {
  id: string;
  organization_id: string;
  parent_id?: string | null; // Legacy - kept for backward compatibility
  parent_category_id?: string | null; // New - preferred field name
  name: string;
  code?: string | null;
  is_group?: boolean; // true = parent bucket (not selectable for SKUs)
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useItemCategories() {
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCategories() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCategories([]);
        return;
      }

      try {
        setLoading(true);
        const { data, error: err } = await supabase
          .from('ItemCategories')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (err) throw err;
        setCategories(data || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error loading categories');
      } finally {
        setLoading(false);
      }
    }

    fetchCategories();
  }, [activeOrganizationId, refreshTrigger]);

  return { categories, loading, error, refetch };
}

// Hook to get only leaf categories (is_group = false) for dropdowns
export function useLeafItemCategories() {
  const { categories, loading, error, refetch } = useItemCategories();
  const leafCategories = useMemo(() => {
    // Filter leaf categories (is_group = false) and remove duplicates
    const filtered = categories.filter(cat => !cat.is_group && !cat.deleted);
    
    // Remove duplicates by id (keep first occurrence)
    const uniqueById = Array.from(
      new Map(filtered.map(cat => [cat.id, cat])).values()
    );
    
    // Also remove duplicates by code within same organization (keep first occurrence)
    const uniqueByCode = Array.from(
      new Map(uniqueById.map(cat => [`${cat.organization_id}-${cat.code}`, cat])).values()
    );
    
    // Sort by sort_order, then by name for consistent display
    return uniqueByCode.sort((a, b) => {
      if (a.sort_order !== b.sort_order) {
        return (a.sort_order || 0) - (b.sort_order || 0);
      }
      return (a.name || '').localeCompare(b.name || '');
    });
  }, [categories]);

  return { categories: leafCategories, loading, error, refetch };
}

export function useItemCategoriesCRUD() {
  const { categories, loading, error, refetch } = useItemCategories();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createCategory = async (data: Omit<ItemCategory, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      // Map parent_id to parent_category_id if provided
      const insertData: any = { ...data, organization_id: activeOrganizationId };
      if (data.parent_id && !data.parent_category_id) {
        insertData.parent_category_id = data.parent_id;
      }
      if (data.parent_category_id) {
        insertData.parent_category_id = data.parent_category_id;
      }
      // Remove parent_id from insert (use parent_category_id instead)
      delete insertData.parent_id;
      
      const { data: result, error: err } = await supabase
        .from('ItemCategories')
        .insert(insertData)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateCategory = async (id: string, data: Partial<ItemCategory>) => {
    setIsUpdating(true);
    try {
      // Map parent_id to parent_category_id if provided
      const updateData: any = { ...data };
      if (data.parent_id !== undefined && data.parent_category_id === undefined) {
        updateData.parent_category_id = data.parent_id || null;
      }
      // Remove parent_id from update (use parent_category_id instead)
      delete updateData.parent_id;
      
      const { data: result, error: err } = await supabase
        .from('ItemCategories')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCategory = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('ItemCategories')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    categories,
    loading,
    error,
    refetch,
    createCategory,
    updateCategory,
    deleteCategory,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// Collections CRUD Hooks
// ====================================================

export function useCatalogCollectionsCRUD() {
  const { collections, loading, error, refetch } = useCatalogCollections();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createCollection = async (data: Omit<CatalogCollection, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      // Collections are now derived from CatalogItems, not stored in CollectionsCatalog
      // To create a collection, you need to create a CatalogItem with that collection_name
      // For now, we'll throw an error indicating this needs to be done through CatalogItems
      throw new Error('Collections are now derived from CatalogItems. To create a collection, create a CatalogItem with the desired collection_name.');
    } finally {
      setIsCreating(false);
    }
  };

  const updateCollection = async (id: string, data: Partial<CatalogCollection>) => {
    setIsUpdating(true);
    try {
      // Collections are now derived from CatalogItems
      // To update a collection name, we need to update all CatalogItems with that collection_name
      if (data.name && data.name !== id) {
        // Update all CatalogItems with the old collection_name to the new collection_name
        const { error: err } = await supabase
          .from('CatalogItems')
          .update({ collection_name: data.name })
          .eq('organization_id', activeOrganizationId)
          .eq('collection_name', id)
          .eq('deleted', false);
        
        if (err) throw err;
        refetch();
        return { id: data.name, name: data.name } as any;
      }
      // If no name change, just refetch
      refetch();
      return { id, name: id } as any;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCollection = async (id: string) => {
    setIsDeleting(true);
    try {
      // Collections are now derived from CatalogItems
      // To "delete" a collection, we remove collection_name from all items with that collection_name
      const { error: err } = await supabase
        .from('CatalogItems')
        .update({ collection_name: null })
        .eq('organization_id', activeOrganizationId)
        .eq('collection_name', id)
        .eq('deleted', false);
      
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    collections,
    loading,
    error,
    refetch,
    createCollection,
    updateCollection,
    deleteCollection,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// CollectionVariants CRUD Hooks (uses CollectionVariants table)
// ====================================================

export function useCatalogVariantsCRUD(collectionId?: string) {
  const { variants, loading, error, refetch } = useCatalogVariants(collectionId);
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createVariant = async (data: Omit<CatalogVariant, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    if (!data.collection_id) throw new Error('Collection ID is required');
    setIsCreating(true);
    try {
      // Map CatalogVariant interface to CollectionVariants table structure
      // CollectionVariants uses variant_name, not name
      const insertData = {
        organization_id: activeOrganizationId,
        collection_id: data.collection_id,
        variant_name: data.name || data.color_name || '', // Use name or color_name as variant_name
      };
      
      const { data: result, error: err } = await supabase
        .from('CollectionVariants')
        .insert(insertData)
        .select()
        .single();
      if (err) throw err;
      refetch();
      
      // Map result back to CatalogVariant interface
      return {
        id: result.id,
        organization_id: result.organization_id,
        collection_id: result.collection_id,
        name: result.variant_name || '',
        code: null,
        color_name: result.variant_name || null,
        active: true,
        sort_order: 0,
        deleted: result.deleted || false,
        archived: result.archived || false,
        created_at: result.created_at,
        updated_at: result.updated_at || null,
      };
    } finally {
      setIsCreating(false);
    }
  };

  const updateVariant = async (id: string, data: Partial<CatalogVariant>) => {
    setIsUpdating(true);
    try {
      // Map CatalogVariant fields to CollectionVariants structure
      const updateData: any = {};
      if (data.name !== undefined) updateData.variant_name = data.name;
      if (data.color_name !== undefined) updateData.variant_name = data.color_name;
      if (data.collection_id !== undefined) updateData.collection_id = data.collection_id;
      
      const { data: result, error: err } = await supabase
        .from('CollectionVariants')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      
      // Map result back to CatalogVariant interface
      return {
        id: result.id,
        organization_id: result.organization_id,
        collection_id: result.collection_id,
        name: result.variant_name || '',
        code: null,
        color_name: result.variant_name || null,
        active: true,
        sort_order: 0,
        deleted: result.deleted || false,
        archived: result.archived || false,
        created_at: result.created_at,
        updated_at: result.updated_at || null,
      };
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteVariant = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('CollectionVariants')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    variants,
    loading,
    error,
    refetch,
    createVariant,
    updateVariant,
    deleteVariant,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// CollectionsCatalog Hooks (replaces CatalogVariants)
// ====================================================

/**
 * Hook to fetch CollectionsCatalog records
 * @param collectionName Optional filter by collection name
 * @param fabricId Optional filter by fabric_id
 */
export function useCollectionsCatalog(collectionName?: string, fabricId?: string) {
  const [items, setItems] = useState<CollectionsCatalogWithItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchItems() {
      if (!activeOrganizationId) {
        setLoading(false);
        setItems([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 Fetching CollectionsCatalog for organization:', activeOrganizationId, collectionName ? `collection: ${collectionName}` : '', fabricId ? `fabric: ${fabricId}` : '');
        }

        // CollectionsCatalog is now an entity table with: id, name, manufacturer_id
        // We don't use this hook for the new structure, but keep it for backward compatibility
        // This hook should return empty or be deprecated
        // For getting variants, use CatalogItems with variant_name field instead
        let query = supabase
          .from('CollectionsCatalog')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('name', { ascending: true });

        // Note: collectionName and fabricId filters don't apply to entity table structure
        // This hook is kept for backward compatibility but may return empty

        const { data, error: queryError } = await query;

        if (queryError) {
          // Handle expected errors (table doesn't exist, RLS, etc.)
          const isExpectedError = 
            queryError.code === 'PGRST116' || // No rows returned
            queryError.code === '42501' || // Permission denied (RLS)
            queryError.code === '42P01' || // Relation does not exist
            queryError.code === 'PGRST202' || // Table not found
            queryError.message?.includes('relation') ||
            queryError.message?.includes('does not exist') ||
            queryError.message?.includes('permission denied') ||
            queryError.message?.includes('row-level security');

          if (isExpectedError) {
            // Silently return empty array for expected errors
            if (import.meta.env.DEV) {
              console.warn('⚠️ CollectionsCatalog table may not exist yet. Run the migration create_collections_catalog_table.sql');
            }
            setItems([]);
            setLoading(false);
            return;
          }

          if (import.meta.env.DEV) {
            console.error('❌ Error fetching CollectionsCatalog:', queryError);
            console.error('   Error code:', queryError.code);
            console.error('   Error message:', queryError.message);
            console.error('   Error details:', queryError.details);
          }
          throw queryError;
        }

        if (import.meta.env.DEV) {
          console.log('✅ CollectionsCatalog fetched:', data?.length || 0, 'items');
        }

        setItems((data || []) as CollectionsCatalogWithItem[]);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading collections catalog';
        if (import.meta.env.DEV) {
          console.error('Error fetching CollectionsCatalog:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchItems();
  }, [activeOrganizationId, collectionName, fabricId, refreshTrigger]);

  return { items, loading, error, refetch };
}

/**
 * Hook for CollectionsCatalog CRUD operations
 */
export function useCollectionsCatalogCRUD(collectionName?: string, fabricId?: string) {
  const { items, loading, error, refetch } = useCollectionsCatalog(collectionName, fabricId);
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createItem = async (data: Omit<CollectionsCatalog, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    if (!data.catalog_item_id) throw new Error('Catalog Item ID is required');
    if (!data.fabric_id) throw new Error('Fabric ID is required');
    if (!data.collection) throw new Error('Collection is required');
    if (!data.variant) throw new Error('Variant is required');
    
    setIsCreating(true);
    try {
      // The trigger will auto-populate from CatalogItem
      const { data: result, error: err } = await supabase
        .from('CollectionsCatalog')
        .insert({ 
          ...data, 
          organization_id: activeOrganizationId,
          // sku, name, description, cost_value, etc. will be auto-populated by trigger
        })
        .select(`
          *,
          catalog_item:CatalogItems!catalog_item_id(*),
          fabric_item:CatalogItems!fabric_id(*)
        `)
        .single();
      
      if (err) {
        if (import.meta.env.DEV) {
          console.error('Error creating CollectionsCatalog:', err);
        }
        throw err;
      }
      
      refetch();
      return result as CollectionsCatalogWithItem;
    } finally {
      setIsCreating(false);
    }
  };

  const updateItem = async (id: string, data: Partial<CollectionsCatalog>) => {
    setIsUpdating(true);
    try {
      // The trigger will sync from CatalogItem if catalog_item_id changes
      const { data: result, error: err } = await supabase
        .from('CollectionsCatalog')
        .update(data)
        .eq('id', id)
        .select(`
          *,
          catalog_item:CatalogItems!catalog_item_id(*),
          fabric_item:CatalogItems!fabric_id(*)
        `)
        .single();
      
      if (err) {
        if (import.meta.env.DEV) {
          console.error('Error updating CollectionsCatalog:', err);
        }
        throw err;
      }
      
      refetch();
      return result as CollectionsCatalogWithItem;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteItem = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('CollectionsCatalog')
        .update({ deleted: true })
        .eq('id', id);
      
      if (err) {
        if (import.meta.env.DEV) {
          console.error('Error deleting CollectionsCatalog:', err);
        }
        throw err;
      }
      
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    items,
    loading,
    error,
    refetch,
    createItem,
    updateItem,
    deleteItem,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

