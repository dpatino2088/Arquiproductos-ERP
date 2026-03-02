import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { CatalogItem } from '../types/catalog';

interface UseCatalogItemsOptions {
  family?: string;
  productTypeId?: string;
  role?: string; // item_role filter
  categoryId?: string; // category_id filter
  isRoll?: boolean; // solo ítems con is_roll = true (rolls: telas, films, etc.)
}

export function useCatalogItems(
  familyOrOptions?: string | UseCatalogItemsOptions,
  productTypeId?: string
) {
  // ✅ FIX: Soporte para objeto de opciones o parámetros legacy
  let options: UseCatalogItemsOptions;
  if (typeof familyOrOptions === 'object' && familyOrOptions !== null) {
    options = familyOrOptions;
  } else {
    // Legacy: family como string, productTypeId como segundo parámetro
    options = {
      family: familyOrOptions,
      productTypeId,
    };
  }

  const [items, setItems] = useState<CatalogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false); // ✅ Estado para carga progresiva
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  
  const { family, productTypeId: optProductTypeId, role, categoryId, isRoll } = options;

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
    // Force clear any cached data to ensure fresh fetch
    setItems([]);
    setLoading(true);
    setLoadingMore(false);
  }, []);

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
      if (optProductTypeId === null || family === null) {
        // Explicitly set to null means "don't load", undefined means "load all"
        if (isMounted) {
          setLoading(false);
          setItems([]);
          setError(null);
        }
        return;
      }

      // ✅ FIX: Declarar isValidUUID ANTES de usarlo
      // Validate productTypeId is a valid UUID before querying
      const isValidUUID = (str: string | undefined): boolean => {
        if (!str) return false;
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        return uuidRegex.test(str);
      };

      try {
        if (isMounted) {
          setLoading(true);
          setError(null);
        }

        if (import.meta.env.DEV) {
          console.log('🔍 useCatalogItems - Starting fetch:', {
            activeOrganizationId,
            productTypeId: optProductTypeId,
            family,
            role,
            categoryId,
            hasProductTypeId: !!optProductTypeId,
            hasFamily: !!family,
            hasRole: !!role,
            hasCategoryId: !!categoryId,
            isValidUUID: optProductTypeId ? isValidUUID(optProductTypeId) : false,
          });
        }

        // First, try to get items - NO JOIN with CatalogCollections (table may not exist)
        // Note: We select all columns including collection_name and variant_name directly from CatalogItems
        // collection_name and variant_name are already in CatalogItems, no need for JOIN
        let query = supabase
          .from('CatalogItems')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true);

        // ✅ FIX: Aplicar filtros por role y categoryId directamente en CatalogItems
        if (role) {
          query = query.eq('item_role', role);
          if (import.meta.env.DEV) {
            console.log('✅ Filtering CatalogItems by role:', role);
          }
        }
        
        if (categoryId) {
          query = query.eq('category_id', categoryId);
          if (import.meta.env.DEV) {
            console.log('✅ Filtering CatalogItems by categoryId:', categoryId);
          }
        }

        // ✅ TEMPORAL: Deshabilitado filtro por ProductType para debugging
        // Filter by family (fallback for backward compatibility)
        if (family) {
          // Fallback to family column for backward compatibility
          query = query.eq('family', family);
          
          if (import.meta.env.DEV) {
            console.log('🔍 Filtering CatalogItems by family (fallback):', family);
            if (optProductTypeId && !isValidUUID(optProductTypeId)) {
              console.warn('⚠️ Invalid productTypeId format:', optProductTypeId);
            }
          }
        } else {
          // No filters - load all items (for AccessoriesStep search)
          if (import.meta.env.DEV) {
            console.log('🔍 Loading all CatalogItems (no filters)');
          }
        }

        // ✅ Cargar 500 items + sus MSRP antes del primer render; luego el resto en background
        const INITIAL_LOAD_SIZE = 500;
        const BATCH_SIZE = 100;
        const MSRP_BATCH = 100;
        
        let allData: any[] = [];
        let queryError: any = null;
        
        if (import.meta.env.DEV) {
          console.log('🔍 Loading items with progressive rendering...', {
            hasFamily: !!family,
            family,
            role,
            categoryId,
            initialLoad: INITIAL_LOAD_SIZE,
            batchSize: BATCH_SIZE,
            maxItems: 'all',
          });
        }
        
        // Helper function to build query
        const buildQuery = (from: number, to: number) => {
          let pageQuery = supabase
            .from('CatalogItems')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true);
          
          if (role) {
            pageQuery = pageQuery.eq('item_role', role);
          }
          
          if (categoryId) {
            pageQuery = pageQuery.eq('category_id', categoryId);
          }
          
          if (family) {
            pageQuery = pageQuery.eq('family', family);
          }

          if (isRoll === true) {
            pageQuery = pageQuery.eq('is_roll', true);
          }
          
          return pageQuery.order('sku', { ascending: true }).range(from, to);
        };
        
        type MsrpRow = { dealer_price: number; msrp: number; total_cost: number; shipping_cost: number; import_tax_cost: number };
        const enrichItems = (d: any[], m: Map<string, MsrpRow>): CatalogItem[] => (d || []).map((item: any) => {
          const msrpRow = m.get(item.id);
          const finalMsrp = (msrpRow?.msrp != null && !isNaN(msrpRow.msrp)) ? msrpRow.msrp : null;
          let salePrice = 0;
          if (finalMsrp != null) salePrice = finalMsrp;
          else if (item.cost_exw && item.default_margin_pct) salePrice = item.cost_exw * (1 + item.default_margin_pct / 100);
          else if (item.cost_exw) salePrice = item.cost_exw * 1.5;
          const itemName = item.name || item.item_name || item.sku || `Item-${item.id.substring(0, 8)}`;
          const normalizedMeasureBasis = item.measure_basis === 'linear_m' ? 'linear' : (item.measure_basis || 'unit');
          const unitOfMeasure = item.unit_of_measure || item.uom || 'unit';
          return {
            id: item.id, organization_id: item.organization_id, sku: item.sku || '', name: itemName, item_name: item.item_name || item.name || null,
            description: item.description || null, manufacturer_id: item.manufacturer_id || null, manufacturer: item.manufacturer || item.metadata?.manufacturer || null, category_id: item.category_id || null, item_category_id: item.item_category_id || null,
            measure_basis: normalizedMeasureBasis, unit_of_measure: unitOfMeasure, uom: unitOfMeasure, is_fabric: item.is_fabric || false,
            roll_type: (item as any).roll_type || null, collection_name: item.collection_name || null, variant_name: item.variant_name || null,
            roll_width: item.roll_width || item.roll_width_m || null, roll_width_m: item.roll_width_m || item.roll_width || null, fabric_pricing_mode: item.fabric_pricing_mode || null,
            color: item.color || null, item_role: (item as any).item_role || null, cost_exw: item.cost_exw || null, default_margin_pct: item.default_margin_pct || null,
            purchase_mode: (item.purchase_mode as CatalogItem['purchase_mode']) ?? null,
            stock_basis: (item.stock_basis as CatalogItem['stock_basis']) ?? null,
            purchase_uom: item.purchase_uom ?? item.purchase_unit ?? null,
            msrp: finalMsrp, cost_price: item.cost_exw || item.cost_price || 0, unit_price: salePrice,
            is_active: item.is_active !== undefined && item.is_active !== null ? Boolean(item.is_active) : (item.active !== undefined && item.active !== null ? Boolean(item.active) : true),
            active: item.active !== undefined && item.active !== null ? Boolean(item.active) : (item.is_active !== undefined && item.is_active !== null ? Boolean(item.is_active) : true),
            discontinued: item.discontinued || false, image_url: item.image_url || null, deleted: item.deleted || false, archived: item.archived || false,
            created_at: item.created_at || new Date().toISOString(), updated_at: item.updated_at || null, metadata: item.metadata || {}, created_by: item.created_by || null, updated_by: item.updated_by || null,
          } as CatalogItem;
        });
        
        // PASO 1: Cargar primeros 500 items
        const { data: initialData, error: initialError } = await buildQuery(0, INITIAL_LOAD_SIZE - 1);
        if (initialError) {
          queryError = initialError;
          console.error('❌ Error loading initial items:', initialError?.message || String(initialError));
        } else if (initialData) {
          allData = [...initialData];
          if (import.meta.env.DEV) console.log(`✅ Initial load: ${initialData.length} items`);
        }
        
        // Cargar MSRP de los primeros 500 ANTES de renderizar
        const msrpMap = new Map<string, MsrpRow>();
        const initialIds = allData?.map((i: any) => i.id).filter(Boolean) || [];
        if (initialIds.length > 0 && activeOrganizationId) {
          for (let i = 0; i < initialIds.length; i += MSRP_BATCH) {
            const batch = initialIds.slice(i, i + MSRP_BATCH);
            const { data: msrpData } = await supabase
              .from('CatalogItemsMSRP')
              .select('catalog_item_id, dealer_price, msrp, total_cost, shipping_cost, import_tax_cost')
              .eq('organization_id', activeOrganizationId)
              .in('catalog_item_id', batch);
            (msrpData || []).forEach((row: any) => {
              if (row?.catalog_item_id) msrpMap.set(row.catalog_item_id, { dealer_price: Number(row.dealer_price ?? 0), msrp: Number(row.msrp ?? 0), total_cost: Number(row.total_cost ?? 0), shipping_cost: Number(row.shipping_cost ?? 0), import_tax_cost: Number(row.import_tax_cost ?? 0) });
            });
          }
          if (import.meta.env.DEV) console.log(`✅ MSRP loaded for first ${msrpMap.size} items (before first render)`);
        }
        
        const validItemsInitial = enrichItems(allData, msrpMap).filter(it => it?.id && (it.sku || it.name || it.item_name));
        if (isMounted) { setItems(validItemsInitial); setLoading(false); setLoadingMore(true); }
        
        // PASO 2: Resto en background (items + MSRP por batch)
        if (!queryError) {
          let currentOffset = INITIAL_LOAD_SIZE;
          while (isMounted) {
            const { data: batchData, error: batchError } = await buildQuery(currentOffset, currentOffset + BATCH_SIZE - 1);
            if (batchError) break;
            if (!batchData?.length) break;
            allData = [...allData, ...batchData];
            const batchIds = batchData.map((i: any) => i.id).filter(Boolean);
            if (batchIds.length > 0 && activeOrganizationId) {
              const { data: mb } = await supabase.from('CatalogItemsMSRP').select('catalog_item_id, dealer_price, msrp, total_cost, shipping_cost, import_tax_cost').eq('organization_id', activeOrganizationId).in('catalog_item_id', batchIds);
              (mb || []).forEach((row: any) => { if (row?.catalog_item_id) msrpMap.set(row.catalog_item_id, { dealer_price: Number(row.dealer_price ?? 0), msrp: Number(row.msrp ?? 0), total_cost: Number(row.total_cost ?? 0), shipping_cost: Number(row.shipping_cost ?? 0), import_tax_cost: Number(row.import_tax_cost ?? 0) }); });
            }
            const valid = enrichItems(allData, msrpMap).filter(it => it?.id && (it.sku || it.name || it.item_name));
            if (isMounted) setItems(valid);
            currentOffset += batchData.length;
            if (batchData.length < BATCH_SIZE) break;
          }
          if (isMounted) setLoadingMore(false);
        }
        
        const data = allData;
        const normSku = (s: any) => String(s || '').toUpperCase().replace(/[\s\-_]/g, '');
        
        if (queryError) {
          console.error('❌ Error during loading:', queryError?.message || String(queryError));
        } else if (import.meta.env.DEV) {
          console.log(`✅ Finished loading items: ${data.length} total`);
          
          // Debug: verificar algunos SKUs específicos (deshabilitado por defecto para reducir ruido)
          // Los SKUs de drives se cargan desde BOMComponents, no del catálogo general
        }

        // Debug: Verify specific SKUs are loaded
        if (import.meta.env.DEV && data && data.length > 0) {
          const rc3006wh = data.find((item: any) => {
            const sku = normSku(item.sku);
            return sku === 'RC3006WH';
          });
          const rc3006bk = data.find((item: any) => {
            const sku = normSku(item.sku);
            return sku === 'RC3006BK';
          });
          const allRC3006Items = data.filter((item: any) => {
            const sku = normSku(item.sku);
            return sku.startsWith('RC3006');
          });
          
          console.log('═══════════════════════════════════════════');
          console.log('🔍 useCatalogItems - Final Results');
          console.log('═══════════════════════════════════════════');
          console.log('Total items loaded:', data.length);
          console.log('Active Organization ID:', activeOrganizationId);
          console.log('ProductTypeId filter:', optProductTypeId || 'NONE (loading all)');
          console.log('Family filter:', family || 'NONE (loading all)');
          if (rc3006bk) {
            console.log('RC3006-BK:', `SKU: ${rc3006bk.sku}, Name: ${rc3006bk.item_name}, Active: ${rc3006bk.active}, Deleted: ${rc3006bk.deleted}, Archived: ${rc3006bk.archived}`);
          } else {
            console.log('RC3006-BK: ❌ NOT FOUND');
          }
          if (rc3006wh) {
            console.log('RC3006-WH:', `SKU: ${rc3006wh.sku}, Name: ${rc3006wh.item_name}, Active: ${rc3006wh.active}, Deleted: ${rc3006wh.deleted}, Archived: ${rc3006wh.archived}`);
          } else {
            console.log('RC3006-WH: ❌ NOT FOUND');
          }
          console.log('All RC3006-* items found:', allRC3006Items.map((item: any) => item.sku).join(', ') || 'none');
          console.log('═══════════════════════════════════════════');
        }

        // No fallback needed - we're using select('*') directly, no JOINs

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CatalogItems:', queryError?.message || String(queryError));
          }
          throw queryError;
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading catalog items';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogItems:', errorMessage);
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
  }, [activeOrganizationId, refreshTrigger, family, optProductTypeId, role, categoryId, isRoll]);

  return { items, loading, loadingMore, error, refetch };
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

export function useUpsertCatalogItemBySku() {
  const [isUpserting, setIsUpserting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const upsertItemBySku = async (
    itemData: Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpserting(true);
    try {
      const payload = {
        ...itemData,
        organization_id: activeOrganizationId,
      };

      const { data, error } = await supabase
        .from('CatalogItems')
        .upsert(payload, { onConflict: 'organization_id,sku' })
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsUpserting(false);
    }
  };

  return { upsertItemBySku, isUpserting };
}

export function useUpdateCatalogItem() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateItem = async (id: string, itemData: Partial<CatalogItem>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }
    
    if (import.meta.env.DEV) {
      console.log('🔄 useUpdateCatalogItem called with:', {
        id,
        organization_id: activeOrganizationId,
        itemData,
      });
    }
    
    setIsUpdating(true);
    try {
      // IMPORTANT:
      // - Always scope writes by organization_id (multi-tenant safety + common RLS requirement)
      // - Do NOT rely on `.select().single()` for updates (RLS can allow update but block returning rows)
      const { data, error } = await supabase
        .from('CatalogItems')
        .update(itemData)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        console.error('❌ Supabase update error:', {
          message: error.message,
          code: error.code,
          details: error.details,
          hint: error.hint,
        });
        throw error;
      }

      if (import.meta.env.DEV) {
        console.log('✅ Update successful, affected rows:', data);
      }

      // Best-effort refetch (do not fail the save if this select is blocked)
      try {
        const { data: refetchedData } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('id', id)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        return refetchedData;
      } catch (refetchErr) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ Refetch failed (non-blocking):', refetchErr);
        }
        return null;
      }
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateItem, isUpdating };
}

export function useDeleteCatalogItem() {
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const getBlockedItemIdsByBom = async (ids: string[]): Promise<Set<string>> => {
    const blocked = new Set<string>();
    if (!activeOrganizationId || ids.length === 0) return blocked;

    // 1) Legacy/current BOM components table reference
    const bomComponentsResult = await supabase
      .from('BOMComponents')
      .select('component_item_id')
      .eq('organization_id', activeOrganizationId)
      .in('component_item_id', ids)
      .eq('deleted', false);

    if (!bomComponentsResult.error) {
      (bomComponentsResult.data || []).forEach((row: { component_item_id?: string | null }) => {
        if (row.component_item_id) blocked.add(row.component_item_id);
      });
    } else {
      // Fallback if deleted column is not present in this env/schema
      const fallback = await supabase
        .from('BOMComponents')
        .select('component_item_id')
        .eq('organization_id', activeOrganizationId)
        .in('component_item_id', ids);
      if (!fallback.error) {
        (fallback.data || []).forEach((row: { component_item_id?: string | null }) => {
          if (row.component_item_id) blocked.add(row.component_item_id);
        });
      }
    }

    // 2) Newer BOM slots table reference
    const bomSlotsResult = await supabase
      .from('BOMTemplateSlots')
      .select('catalog_item_id')
      .eq('organization_id', activeOrganizationId)
      .in('catalog_item_id', ids);

    if (!bomSlotsResult.error) {
      (bomSlotsResult.data || []).forEach((row: { catalog_item_id?: string | null }) => {
        if (row.catalog_item_id) blocked.add(row.catalog_item_id);
      });
    }

    return blocked;
  };

  const assertItemsCanBeDeleted = async (ids: string[]) => {
    const blocked = await getBlockedItemIdsByBom(ids);
    if (blocked.size === 0) return;

    const blockedIds = Array.from(blocked);
    const { data } = await supabase
      .from('CatalogItems')
      .select('sku')
      .eq('organization_id', activeOrganizationId)
      .in('id', blockedIds);
    const skuList = (data || []).map((r: { sku?: string | null }) => r.sku).filter(Boolean).slice(0, 8);
    const suffix = blockedIds.length > 8 ? '...' : '';
    const skuText = skuList.length > 0 ? ` (${skuList.join(', ')}${suffix})` : '';
    throw new Error(
      `WARNING_TEMPLATE_LINKED: No se puede eliminar item(s) porque pertenecen a un template BOM. Remueve la referencia del template primero${skuText}.`
    );
  };

  const deleteItem = async (id: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }
    setIsDeleting(true);
    try {
      await assertItemsCanBeDeleted([id]);

      // Same considerations as updateItem: scope by org + don't depend on returned rows
      const { error } = await supabase
        .from('CatalogItems')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        throw new Error(formatSupabaseError(error) || 'Failed to delete item');
      }

      // Best-effort refetch
      try {
        const { data } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('id', id)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        return data;
      } catch {
        return null;
      }
    } finally {
      setIsDeleting(false);
    }
  };

  const deleteItems = async (ids: string[]) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }
    if (!Array.isArray(ids) || ids.length === 0) {
      return;
    }

    setIsDeleting(true);
    try {
      await assertItemsCanBeDeleted(ids);

      const { error } = await supabase
        .from('CatalogItems')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('organization_id', activeOrganizationId)
        .in('id', ids);

      if (error) {
        throw new Error(formatSupabaseError(error) || 'Failed to delete selected items');
      }
    } finally {
      setIsDeleting(false);
    }
  };

  return { deleteItem, deleteItems, isDeleting };
}

// Hook to fetch a single CatalogItem by ID
export function useCatalogItemById(itemId: string | null | undefined) {
  const [item, setItem] = useState<any | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    let isMounted = true;

    async function fetchItem() {
      if (!itemId || !activeOrganizationId) {
        if (isMounted) {
          setItem(null);
          setLoading(false);
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
          .from('CatalogItems')
          .select('*')
          .eq('id', itemId)
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true)
          .maybeSingle();

        if (queryError) {
          throw queryError;
        }

        if (isMounted) {
          setItem(data);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading catalog item';
        if (isMounted) {
          setError(errorMessage);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchItem();

    return () => {
      isMounted = false;
    };
  }, [itemId, activeOrganizationId]);

  return { item, loading, error };
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
  /** Manufacturer IDs of items in this collection (for filtering by manufacturer) */
  manufacturer_ids?: string[];
}

// Helper to format Supabase errors
function formatSupabaseError(e: any): string {
  if (!e) return "";
  if (typeof e === "string") return e;
  return (
    e?.message ??
    e?.error_description ??
    e?.hint ??
    JSON.stringify(e, null, 2)
  );
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
    let isMounted = true;

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
          console.log('🔍 useCatalogCollections - Fetching roll items (is_roll=true)');
        }

        // Query CatalogItems for roll items only (is_roll=true) WITH PAGINATION
        // Collections are derived from collection_name grouping
        // Supabase has a default limit of 1000 rows, so we need to paginate
        let allRollItems: any[] = [];
        let currentPage = 0;
        const pageSize = 1000;
        let hasMore = true;
        let queryError: any = null;
        
        console.log('🔍 Loading roll items with pagination...');
        
        while (hasMore) {
          const from = currentPage * pageSize;
          const to = from + pageSize - 1;
          
          const { data: pageData, error: pageError } = await supabase
            .from('CatalogItems')
            .select(`
              id,
              organization_id,
              manufacturer_id,
              manufacturer,
              collection_name,
              variant_name,
              sku,
              roll_width,
              cost_exw,
              unit_of_measure,
              measure_basis,
              image_url
            `)
            .eq('organization_id', activeOrganizationId)
            .eq('is_roll', true)
            .not('collection_name', 'is', null)
            .not('variant_name', 'is', null)
            .not('sku', 'is', null)
            .order('collection_name', { ascending: true })
            .order('variant_name', { ascending: true })
            .range(from, to);
          
          if (pageError) {
            console.error(`❌ Error loading roll items page ${currentPage + 1}:`, pageError);
            queryError = pageError;
            hasMore = false;
            break;
          }
          
          if (pageData && pageData.length > 0) {
            allRollItems = [...allRollItems, ...pageData];
            console.log(`✅ Loaded roll items page ${currentPage + 1}: ${pageData.length} items (Total: ${allRollItems.length})`);
            
            if (pageData.length < pageSize) {
              hasMore = false;
            } else {
              currentPage++;
            }
          } else {
            hasMore = false;
          }
        }
        
        const data = allRollItems;

        if (queryError) {
          console.error('❌ Collections fetch error:', queryError);
          if (isMounted) {
            setError(formatSupabaseError(queryError));
          }
          return;
        }

        console.log(`✅ Finished loading all roll items: ${data.length} total across ${currentPage + 1} page(s)`);

        // Group by collection_name; accumulate manufacturer_ids for filtering
        const uniqueCollections = new Map<string, { name: string; manufacturerIds: Set<string>; itemCount: number }>();
        
        (data || []).forEach((item: any) => {
          const collectionName = item.collection_name ? String(item.collection_name).trim() : '';
          if (collectionName) {
            if (!uniqueCollections.has(collectionName)) {
              const manIds = new Set<string>();
              if (item.manufacturer_id) manIds.add(item.manufacturer_id);
              uniqueCollections.set(collectionName, {
                name: collectionName,
                manufacturerIds: manIds,
                itemCount: 1,
              });
            } else {
              const existing = uniqueCollections.get(collectionName)!;
              if (item.manufacturer_id) existing.manufacturerIds.add(item.manufacturer_id);
              existing.itemCount++;
            }
          }
        });

        // Convert to CatalogCollection format
        const collectionsData: CatalogCollection[] = Array.from(uniqueCollections.entries()).map(([name, collData], index) => ({
          id: `collection-${name.toLowerCase().replace(/\s+/g, '-')}`,
          organization_id: activeOrganizationId,
          name: name,
          code: name.substring(0, 3).toUpperCase(),
          description: `${collData.itemCount} variants`,
          active: true,
          sort_order: index,
          deleted: false,
          archived: false,
          created_at: new Date().toISOString(),
          updated_at: null,
          manufacturer_ids: Array.from(collData.manufacturerIds),
        }));

        if (import.meta.env.DEV) {
          console.log(`✅ Extracted ${collectionsData.length} collections from roll items`);
        }

        // Sort by name
        const sortedData = [...collectionsData].sort((a, b) => 
          (a.name || '').localeCompare(b.name || '')
        );

        if (isMounted) {
          setCollections(sortedData);
        }
      } catch (err) {
        const errorMessage = formatSupabaseError(err);
        if (import.meta.env.DEV) {
          console.error('❌ Error fetching Collections:', errorMessage);
          console.error('Full error:', err);
        }
        if (isMounted) {
          setError(errorMessage || 'Error loading collections');
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
        // IMPORTANT: Paginate to load ALL items (not just first 1000)
        let allOperatingDrives: any[] = [];
        let drivePage = 0;
        const drivePageSize = 1000;
        let hasMoreDrives = true;
        let queryError: any = null;
        
        console.log('🔍 Loading Operating Drives with pagination...');
        
        while (hasMoreDrives) {
          const driveFrom = drivePage * drivePageSize;
          const driveTo = driveFrom + drivePageSize - 1;
          
          const { data: pageData, error: pageError } = await supabase
            .from('CatalogItems')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true)
            .eq('is_fabric', false) // Operating drives are components, not fabrics
            .order('name', { ascending: true })
            .range(driveFrom, driveTo);
          
          if (pageError) {
            console.error(`❌ Error loading Operating Drives page ${drivePage + 1}:`, pageError);
            queryError = pageError;
            hasMoreDrives = false;
            break;
          }
          
          if (pageData && pageData.length > 0) {
            allOperatingDrives = [...allOperatingDrives, ...pageData];
            console.log(`✅ Loaded Operating Drives page ${drivePage + 1}: ${pageData.length} items (Total: ${allOperatingDrives.length})`);
            
            if (pageData.length < drivePageSize) {
              hasMoreDrives = false;
            } else {
              drivePage++;
            }
          } else {
            hasMoreDrives = false;
          }
        }
        
        const data = allOperatingDrives;
        
        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Operating Drives:', queryError);
          }
          throw queryError;
        }
        
        if (import.meta.env.DEV) {
          console.log(`✅ Finished loading Operating Drives: ${data.length} total across ${drivePage + 1} page(s)`);
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

// Hook para cargar y administrar CatalogCategories
export interface CatalogCategory {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  parent_id?: string | null;
  sort_order: number;
  is_group: boolean;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export type ItemCategory = CatalogCategory;
export type CatalogCategoryCRUD = CatalogCategory;

const CATALOG_CATEGORY_SELECT = 'id, organization_id, name, code, parent_id, sort_order, is_group, deleted, archived, created_at, updated_at';

function sortCatalogCategories(a: CatalogCategory, b: CatalogCategory): number {
  const aParent = a.parent_id ?? '';
  const bParent = b.parent_id ?? '';
  if (aParent !== bParent) return aParent.localeCompare(bParent);
  if ((a.sort_order ?? 0) !== (b.sort_order ?? 0)) return (a.sort_order ?? 0) - (b.sort_order ?? 0);
  return (a.name || '').localeCompare(b.name || '');
}

function mapCatalogCategoryRow(row: any): CatalogCategory {
  return {
    id: row.id,
    organization_id: row.organization_id,
    name: row.name ?? '',
    code: row.code ?? null,
    parent_id: row.parent_id ?? null,
    sort_order: row.sort_order ?? 0,
    is_group: row.parent_id == null ? true : Boolean(row.is_group),
    deleted: Boolean(row.deleted),
    archived: Boolean(row.archived),
    created_at: row.created_at,
    updated_at: row.updated_at ?? null,
  };
}

async function fetchCatalogCategoriesRows(activeOrganizationId: string): Promise<CatalogCategory[]> {
  const { data, error } = await supabase
    .from('CatalogCategories')
    .select(CATALOG_CATEGORY_SELECT)
    .eq('organization_id', activeOrganizationId)
    .eq('deleted', false);

  if (error) throw error;
  return (data || []).map(mapCatalogCategoryRow).sort(sortCatalogCategories);
}

export function useItemCategories() {
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    let mounted = true;

    async function fetchCategories() {
      if (!activeOrganizationId) {
        if (!mounted) return;
        setLoading(false);
        setCategories([]);
        setError(null);
        return;
      }

      try {
        if (mounted) {
          setLoading(true);
          setError(null);
        }
        const rows = await fetchCatalogCategoriesRows(activeOrganizationId);
        if (mounted) setCategories(rows);
      } catch (err) {
        if (!mounted) return;
        setError(err instanceof Error ? err.message : 'Error loading categories');
      } finally {
        if (mounted) setLoading(false);
      }
    }

    fetchCategories();
    return () => {
      mounted = false;
    };
  }, [activeOrganizationId]);

  return { categories, loading, error };
}

// Hook para cargar solo subcategorías (leaf nodes)
export function useLeafItemCategories() {
  const { categories, loading, error } = useItemCategories();
  const leafCategories = useMemo(
    () => categories.filter((cat) => !cat.is_group && Boolean(cat.parent_id)),
    [categories]
  );
  return { categories: leafCategories, loading, error };
}

export function useItemCategoriesCRUD() {
  const [categories, setCategories] = useState<CatalogCategoryCRUD[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(async () => {
    if (!activeOrganizationId) {
      setCategories([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const rows = await fetchCatalogCategoriesRows(activeOrganizationId);
      setCategories(rows);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error loading categories');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  const createCategory = async (
    categoryData: Omit<CatalogCategoryCRUD, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const isGroup = Boolean(categoryData.is_group);
      const parentId = isGroup ? null : (categoryData.parent_id || null);
      if (!isGroup && !parentId) {
        throw new Error('A subcategory must have a parent category');
      }

      const { data, error: insertError } = await supabase
        .from('CatalogCategories')
        .insert({
          organization_id: activeOrganizationId,
          name: categoryData.name.trim(),
          code: categoryData.code?.trim() || null,
          parent_id: parentId,
          is_group: isGroup,
          sort_order: categoryData.sort_order ?? 0,
          deleted: false,
          archived: false,
        })
        .select(CATALOG_CATEGORY_SELECT)
        .single();
      if (insertError) throw insertError;
      const created = mapCatalogCategoryRow(data);
      setCategories((prev) => [...prev, created].sort(sortCatalogCategories));
      return created;
    } finally {
      setIsCreating(false);
    }
  };

  const updateCategory = async (id: string, categoryData: Partial<CatalogCategoryCRUD>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsUpdating(true);
    try {
      const nextIsGroup = categoryData.is_group;
      const payload: Record<string, any> = {
        updated_at: new Date().toISOString(),
      };
      if (categoryData.name !== undefined) payload.name = categoryData.name.trim();
      if (categoryData.code !== undefined) payload.code = categoryData.code?.trim() || null;
      if (categoryData.sort_order !== undefined) payload.sort_order = categoryData.sort_order ?? 0;
      if (nextIsGroup !== undefined) payload.is_group = Boolean(nextIsGroup);
      if (categoryData.parent_id !== undefined) {
        payload.parent_id = nextIsGroup ? null : (categoryData.parent_id || null);
      }

      const { data, error: updateError } = await supabase
        .from('CatalogCategories')
        .update(payload)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .select(CATALOG_CATEGORY_SELECT)
        .single();
      if (updateError) throw updateError;

      const updated = mapCatalogCategoryRow(data);
      setCategories((prev) => prev.map((cat) => (cat.id === id ? updated : cat)).sort(sortCatalogCategories));
      return updated;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCategory = async (id: string) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsDeleting(true);
    try {
      const { count: childrenCount, error: childErr } = await supabase
        .from('CatalogCategories')
        .select('id', { count: 'exact', head: true })
        .eq('organization_id', activeOrganizationId)
        .eq('parent_id', id)
        .or('deleted.is.null,deleted.eq.false');
      if (childErr) throw new Error(childErr.message || 'Failed to validate child categories');
      if ((childrenCount || 0) > 0) {
        throw new Error('Cannot delete category with existing subcategories');
      }

      const { count: itemCount, error: itemErr } = await supabase
        .from('CatalogItems')
        .select('id', { count: 'exact', head: true })
        .eq('organization_id', activeOrganizationId)
        .eq('category_id', id);
      if (itemErr) throw new Error(itemErr.message || 'Failed to validate assigned items');
      if ((itemCount || 0) > 0) {
        throw new Error('Cannot delete category with assigned items');
      }

      const { error: deleteErr } = await supabase
        .from('CatalogCategories')
        .update({ deleted: true, archived: true, updated_at: new Date().toISOString() })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);
      if (deleteErr) throw new Error(deleteErr.message || 'Failed to delete category');

      setCategories((prev) => prev.filter((cat) => cat.id !== id));
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

export function useCatalogCategories() {
  const [categories, setCategories] = useState<CatalogCategory[]>([]);
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

        const rows = await fetchCatalogCategoriesRows(activeOrganizationId);
        setCategories(rows);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading categories';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogCategories:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCategories();
  }, [activeOrganizationId]);

  // Helper function to build ordered category tree with path
  const categoryTree = useMemo(() => {
    const byId = new Map(categories.map((c) => [c.id, c]));
    const output: Array<CatalogCategory & { level: number; path: string }> = [];

    const parents = categories
      .filter((c) => c.parent_id == null && c.is_group)
      .sort(sortCatalogCategories);

    const buildPath = (category: CatalogCategory): string => {
      const path: string[] = [category.name];
      let current = category;
      while (current.parent_id) {
        const parent = byId.get(current.parent_id);
        if (!parent) break;
        path.unshift(parent.name);
        current = parent;
      }
      return path.join(' > ');
    };

    parents.forEach((parent) => {
      output.push({ ...parent, level: 0, path: buildPath(parent) });
      const children = categories
        .filter((c) => c.parent_id === parent.id && !c.is_group)
        .sort(sortCatalogCategories);
      children.forEach((child) => {
        output.push({ ...child, level: 1, path: buildPath(child) });
      });
    });

    // Keep orphan leaves visible at the end for recovery workflows
    const parentIds = new Set(parents.map((p) => p.id));
    categories
      .filter((c) => !c.is_group && c.parent_id && !parentIds.has(c.parent_id))
      .sort(sortCatalogCategories)
      .forEach((orphan) => {
        output.push({ ...orphan, level: 1, path: buildPath(orphan) });
      });

    return output;
  }, [categories]);

  // Helper: get only valid subcategories for CatalogItems selection
  const leafCategories = useMemo(() => {
    return categoryTree.filter((cat) => !cat.is_group && Boolean(cat.parent_id));
  }, [categoryTree]);

  return { categories, categoryTree, leafCategories, loading, error };
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

