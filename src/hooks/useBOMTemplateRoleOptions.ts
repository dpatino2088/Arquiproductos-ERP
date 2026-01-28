/**
 * Hook to get role options (SKUs) from BOMTemplateSlots of candidate templates
 * 
 * This replaces loading options from CatalogItems by role, ensuring that
 * only SKUs that exist in candidate templates are shown.
 * 
 * @param candidateTemplateIds - Array of BOMTemplate IDs to get slots from
 * @param role - The role to filter slots by (e.g., 'bottom_bar', 'tube', 'headbox')
 * @param enabled - Whether to fetch (default: true)
 * 
 * @returns List of CatalogItems with { id, sku, name, image_url, ... } ordered by name/sku
 */
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { normalizeRole } from '../lib/bom/roles';

export interface BOMTemplateRoleOption {
  id: string;
  sku: string;
  name: string;
  image_url: string | null;
  color: string | null;
  cost_exw: number | null;
  category_id: string | null;
  /** true when slot has selection_mode='fixed' (preselected / locked) */
  locked?: boolean;
}

export function useBOMTemplateRoleOptions(
  candidateTemplateIds: string[],
  role: string,
  enabled: boolean = true
) {
  const [items, setItems] = useState<BOMTemplateRoleOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    // ✅ DEBUG: Log de condiciones
    if (import.meta.env.DEV) {
      console.debug('[useBOMTemplateRoleOptions] useEffect triggered', {
        enabled,
        hasActiveOrganizationId: !!activeOrganizationId,
        role,
        candidateTemplateIdsCount: candidateTemplateIds.length,
        candidateTemplateIds: candidateTemplateIds.slice(0, 3),
        willFetch: enabled && !!activeOrganizationId && !!role && candidateTemplateIds.length > 0,
      });
    }
    
    if (!enabled || !activeOrganizationId || !role || candidateTemplateIds.length === 0) {
      if (import.meta.env.DEV) {
        console.debug('[useBOMTemplateRoleOptions] Skipping fetch', {
          reason: !enabled ? 'disabled' : !activeOrganizationId ? 'no org' : !role ? 'no role' : 'no candidates',
        });
      }
      setItems([]);
      setLoading(false);
      setError(null);
      return;
    }

    const fetchOptions = async () => {
      setLoading(true);
      setError(null);

      try {
        const normalizedRole = normalizeRole(role);

        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateRoleOptions] Fetching options', {
            role,
            normalizedRole,
            candidateTemplateIds: candidateTemplateIds.length,
            candidateTemplateIdsSample: candidateTemplateIds.slice(0, 3),
            activeOrganizationId,
            enabled,
          });
        }

        // Step 1: Get slots from BOMTemplateSlots (catalog_item_id OR fixed_catalog_item_id)
        const { data: slotsData, error: slotsError } = await supabase
          .from('BOMTemplateSlots')
          .select('catalog_item_id, fixed_catalog_item_id, selection_mode')
          .eq('organization_id', activeOrganizationId)
          .in('bom_template_id', candidateTemplateIds)
          .ilike('item_role', normalizedRole);

        if (slotsError) {
          throw slotsError;
        }

        const slotsWithItem = (slotsData || []).filter(
          (s: { catalog_item_id?: string | null; fixed_catalog_item_id?: string | null }) =>
            !!(s.catalog_item_id || s.fixed_catalog_item_id)
        );

        if (slotsWithItem.length === 0) {
          if (import.meta.env.DEV) {
            console.debug('[useBOMTemplateRoleOptions] No slots with item found for role', {
              role,
              normalizedRole,
              candidateTemplateIds: candidateTemplateIds.length,
              activeOrganizationId,
            });
          }
          setItems([]);
          setLoading(false);
          return;
        }

        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateRoleOptions] Slots found', {
            role,
            slotsCount: slotsWithItem.length,
            sampleSlots: slotsWithItem.slice(0, 5).map((s: any) => ({
              catalog_item_id: s.catalog_item_id,
              fixed_catalog_item_id: s.fixed_catalog_item_id,
              selection_mode: s.selection_mode,
            })),
          });
        }

        // Step 2: Distinct item ids (catalog_item_id + fixed_catalog_item_id) and locked set
        const lockedItemIds = new Set<string>();
        const ids = new Set<string>();
        slotsWithItem.forEach((s: any) => {
          const cid = s.catalog_item_id || null;
          const fid = s.fixed_catalog_item_id || null;
          if (cid) {
            ids.add(cid);
            if (s.selection_mode === 'fixed') lockedItemIds.add(cid);
          }
          if (fid) {
            ids.add(fid);
            if (s.selection_mode === 'fixed') lockedItemIds.add(fid);
          }
        });
        const distinctItemIds = Array.from(ids);

        if (distinctItemIds.length === 0) {
          setItems([]);
          setLoading(false);
          return;
        }

        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateRoleOptions] Found distinct catalog_item_ids', {
            role,
            normalizedRole,
            count: distinctItemIds.length,
            itemIds: distinctItemIds.slice(0, 5),
            totalSlotsWithItem: slotsWithItem.length,
            lockedCount: lockedItemIds.size,
          });
        }

        // Step 3: Fetch CatalogItems by IDs, filter by is_active=true and organization_id
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateRoleOptions] Fetching CatalogItems', {
            role,
            distinctItemIdsCount: distinctItemIds.length,
            distinctItemIds: distinctItemIds.slice(0, 5),
            activeOrganizationId,
          });
        }
        
        const { data: catalogItems, error: itemsError } = await supabase
          .from('CatalogItems')
          .select('id, sku, name, image_url, color, cost_exw, category_id')
          .in('id', distinctItemIds)
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true)
          .order('name', { ascending: true });

        if (itemsError) {
          if (import.meta.env.DEV) {
            console.error('[useBOMTemplateRoleOptions] CatalogItems query error', {
              error: itemsError.message,
              code: itemsError.code,
              distinctItemIdsCount: distinctItemIds.length,
            });
          }
          throw itemsError;
        }
        
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplateRoleOptions] CatalogItems fetched', {
            role,
            catalogItemsCount: catalogItems?.length || 0,
            catalogItemsWithSKU: catalogItems?.filter((i: { sku?: string }) => i.sku && i.sku.trim() !== '').length || 0,
            sampleItems: catalogItems?.slice(0, 3).map((i: { id: string; sku: string; name?: string }) => ({ id: i.id, sku: i.sku, name: i.name, is_active: true })),
          });
        }

        // Step 4: Map to BOMTemplateRoleOption format (locked if selection_mode='fixed')
        const skuMap = new Map<string, BOMTemplateRoleOption>();
        (catalogItems || []).forEach((item: any) => {
          if (item.sku && item.sku.trim() !== '') {
            const sku = item.sku.trim();
            if (!skuMap.has(sku)) {
              skuMap.set(sku, {
                id: item.id,
                sku,
                name: item.name || sku,
                image_url: item.image_url || null,
                color: item.color || null,
                cost_exw: item.cost_exw ?? null,
                category_id: item.category_id || null,
                locked: lockedItemIds.has(item.id),
              });
            }
          }
        });
        
        // Convertir Map a Array y ordenar
        const mappedItems: BOMTemplateRoleOption[] = Array.from(skuMap.values())
          .sort((a, b) => {
            // Sort by name first, then by SKU
            const nameCompare = (a.name || '').localeCompare(b.name || '');
            if (nameCompare !== 0) return nameCompare;
            return (a.sku || '').localeCompare(b.sku || '');
          });

        // ✅ CRITICAL: Asegurar que setItems se ejecute ANTES de los logs
        setItems(mappedItems);
        
        if (import.meta.env.DEV) {
          // ✅ Crear objetos simples para evitar "[circular]"
          const optionsSummary = mappedItems.slice(0, 10).map(i => ({
            id: i.id,
            sku: i.sku || 'NO_SKU',
            name: i.name || 'NO_NAME',
          }));
          
          console.debug('[useBOMTemplateRoleOptions] Success', {
            role,
            normalizedRole,
            optionsCount: mappedItems.length,
            distinctItemIdsCount: distinctItemIds.length,
            catalogItemsCount: catalogItems?.length || 0,
            uniqueSKUsCount: skuMap.size,
            options: optionsSummary,
            allSKUs: mappedItems.map(i => i.sku || 'NO_SKU').filter(sku => sku !== 'NO_SKU'), // ✅ Mostrar todos los SKUs únicos encontrados
          });
        }
      } catch (err: any) {
        // ✅ FIX: Evitar "[circular]" al loguear errores
        const errorMessage = err?.message || err?.toString() || 'Failed to fetch role options';
        const errorDetails = {
          message: errorMessage,
          code: err?.code,
          details: err?.details,
          hint: err?.hint,
        };
        
        console.error('[useBOMTemplateRoleOptions] Error:', errorDetails);
        setError(errorMessage);
        setItems([]);
      } finally {
        setLoading(false);
      }
    };

    fetchOptions();
  }, [candidateTemplateIds, role, enabled, activeOrganizationId]);

  return { items, loading, error };
}
