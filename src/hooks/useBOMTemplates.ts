import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { BOMTemplate, ProductType } from '../types/catalog';
import { normalizeRole } from '../lib/bom/roles';
import { normalizeSku } from '../lib/bom/normalize';
import { RoleSelection, isUnset, isNone, isSelected, toRoleSelection } from '../lib/bom/selection';

const CACHE_TTL_MS = 30_000;
// ✅ FIX: Cache ahora guarda tanto baseTemplates como templates (filtered)
type CachedResult = {
  baseTemplates: BOMTemplate[];
  templates: BOMTemplate[]; // filteredTemplates
  ts: number;
};
const templatesCache = new Map<string, CachedResult>();
const productTypesCache = new Map<string, ProductType>();

// ✅ CONSTANTE: Roles que NO filtran templates (solo afectan BOM generation)
const NON_TEMPLATE_FILTER_ROLES = new Set<string>([
  'side_channel',
  'bottom_channel',
]);

// ✅ CONSTANTE: Roles que SIEMPRE deben existir en el template (hard-required)
const REQUIRED_TEMPLATE_ROLES = new Set<string>([
  'bottom_bar',
  'tube',
]);

// ====================================================
// UTILS: Safe Error Serialization (B)
// ====================================================
function safeErr(e: any) {
  return {
    message: e?.message,
    details: e?.details,
    hint: e?.hint,
    code: e?.code,
    name: e?.name,
    stack: import.meta.env.DEV ? e?.stack : undefined,
  };
}

/**
 * Additional filters based on config selections
 * Filter by SKU to match the actual CatalogItem.SKU in the slots
 * 
 * FILTER LOGIC:
 * - ProductType (obligatorio)
 * - Color (obligatorio)
 * - Bottom Bar (obligatorio) - filtra por SKU exacto
 * - Headbox (opcional, puede ser none)
 * - Side Channel (opcional, puede ser none)
 * - Bottom Channel (opcional, puede ser none)
 * - Operating Type (obligatorio) - manual/motor (se filtra por drive_sku o motor_sku)
 * - Tube (obligatorio) - filtra por SKU exacto
 */
export interface BOMTemplateFilters {
  // SECUENTIAL FILTERING (orden estricto):
  bottom_bar_item_id?: string | null; // 3. Bottom Bar (OBLIGATORIO)
  bottom_bar_sku?: string | null; // SKU del bottom bar seleccionado

  headbox_item_id?: string | null; // 4. Head Box (OBLIGATORIO para Dual/Triple, OPCIONAL para Roller)
  headbox_sku?: string | null; // SKU del headbox seleccionado

  operation_type?: 'motor' | 'manual' | null; // 5. Operating Type (OBLIGATORIO)
  motor_item_id?: string | null; // Si motor seleccionado
  motor_sku?: string | null; // SKU del motor
  drive_item_id?: string | null; // Si drive manual seleccionado
  drive_sku?: string | null; // SKU del drive manual

  tube_item_id?: string | null; // 6. Tube (OBLIGATORIO - condicionado por ancho)
  tube_sku?: string | null; // SKU del tube seleccionado
  tube_width_limit?: number | null; // Ancho máximo permitido para el tube (ej: 3.50 para 42mm)

  // NO filtran templates (solo BOM generation):
  side_channel_item_id?: string | null;
  side_channel_sku?: string | null;
  bottom_channel_item_id?: string | null;
  bottom_channel_sku?: string | null;
}

/**
 * Hook to fetch BOMTemplates with SECUENTIAL FILTERING
 *
 * @param productTypeId - Product type ID (filtro 1 - obligatorio)
 * @param hardwareColor - Hardware color (filtro 2 - obligatorio)
 * @param filters - Secuential filters: bottom_bar → headbox → operation_type → tube
 */
export function useBOMTemplates(
  productTypeId?: string | null, 
  hardwareColor?: string | null,
  filters?: BOMTemplateFilters
) {
  const [templates, setTemplates] = useState<BOMTemplate[]>([]);
  const [baseTemplates, setBaseTemplates] = useState<BOMTemplate[]>([]); // ✅ RE-ARQUITECTURA: Templates después de filtros base, antes de selections
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const fetchBOMTemplates = async () => {
      // ✅ LOG MÍNIMO al inicio (sin circular) - solo primitives
      if (import.meta.env.DEV) {
        console.debug("[useBOMTemplates input]", {
          product_type_id: productTypeId ?? null,
          hardware_color: hardwareColor ?? null,
          operation_type: filters?.operation_type ?? null,
          bottom_bar_item_id: filters?.bottom_bar_item_id ?? null,
          bottom_bar_sku: filters?.bottom_bar_sku ?? null,
          tube_item_id: filters?.tube_item_id ?? null,
          tube_sku: filters?.tube_sku ?? null,
          headbox_item_id: filters?.headbox_item_id ?? null,
          headbox_sku: filters?.headbox_sku ?? null,
          drive_item_id: filters?.drive_item_id ?? null,
          drive_sku: filters?.drive_sku ?? null,
          motor_item_id: filters?.motor_item_id ?? null,
          motor_sku: filters?.motor_sku ?? null,
        });
      }

      // ✅ GUARDRAIL: No consultar sin organizationId
      if (!activeOrganizationId) {
        if (import.meta.env.DEV) {
          console.error('[useBOMTemplates] ❌ Missing activeOrganizationId; cannot fetch templates');
        }
        setLoading(false);
        setTemplates([]);
        setError('No organizationId in session/profile. Fix auth profile.');
        return;
      }

      if (import.meta.env.DEV) {
        console.debug('[useBOMTemplates] fetch start', {
          activeOrganizationId,
          productTypeId,
        });
      }

      try {
        // Normalize hardware color (capitalize first letter)
        const normalizedColor = hardwareColor 
          ? hardwareColor.trim().charAt(0).toUpperCase() + hardwareColor.trim().slice(1).toLowerCase()
          : null;

        // ✅ Actualizar cache key para incluir todos los filtros (SKUs) para filtrado preciso
        // NOTA: side_channel y bottom_channel NO se incluyen en cache key porque NO filtran templates
        const filtersKey = filters
          ? `:${filters.operation_type || ''}:${filters.headbox_item_id || ''}:${normalizeSku(filters.headbox_sku) || ''}:${filters.motor_item_id || ''}:${normalizeSku(filters.motor_sku) || ''}:${filters.drive_item_id || ''}:${normalizeSku(filters.drive_sku) || ''}:${filters.bottom_bar_item_id || ''}:${normalizeSku(filters.bottom_bar_sku) || ''}:${filters.tube_item_id || ''}:${normalizeSku(filters.tube_sku) || ''}`
          : '';
        const cacheKey = `${activeOrganizationId}:${productTypeId || 'all'}:${normalizedColor || 'all'}${filtersKey}`;
        const cached = templatesCache.get(cacheKey);
        if (cached && Date.now() - cached.ts < CACHE_TTL_MS && refreshTrigger === 0) {
          // ✅ FIX: Cache ahora retorna tanto baseTemplates como templates
          setTemplates(cached.templates);
          setBaseTemplates(cached.baseTemplates);
          setLoading(false);
          setError(null);
          if (import.meta.env.DEV) {
            console.debug('[useBOMTemplates] Cache hit', {
              baseCount: cached.baseTemplates.length,
              filteredCount: cached.templates.length,
            });
          }
          return;
        }

        setLoading(true);
        setError(null);

        // ✅ Log mínimo: inputs de query
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplates] query', {
            activeOrganizationId,
            productTypeId,
            hardwareColor: normalizedColor,
          });
        }


        // DUMP: BOMTemplates tiene is_active, archived, sort_order. NO tiene columna deleted.
        let query = supabase
          .from('BOMTemplates')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true)
          .eq('archived', false);

        if (productTypeId) {
          query = query.eq('product_type_id', productTypeId);
        }

        if (normalizedColor) {
          query = query.eq('hardware_color', normalizedColor);
        }

        query = query.order('sort_order', { ascending: true });

        let { data, error: fetchError } = await query;

        // Si sort_order no existe (42703 / column does not exist), reintentar solo con created_at
        if (fetchError && (fetchError.code === '42703' || fetchError.message?.includes('sort_order') || (fetchError.message?.includes('column') && fetchError.message?.includes('does not exist')))) {
          if (import.meta.env.DEV) {
            console.warn('[BOMTemplates] sort_order column not found, retrying with created_at only');
          }
          query = supabase
            .from('BOMTemplates')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true)
            .eq('archived', false);
          if (productTypeId) query = query.eq('product_type_id', productTypeId);
          if (normalizedColor) query = query.eq('hardware_color', normalizedColor);
          query = query.order('created_at', { ascending: false });
          const retryResult = await query;
          data = retryResult.data;
          fetchError = retryResult.error;
        }


        // ✅ Log mínimo: resultado de query
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplates] query result', {
            hasError: !!fetchError,
            count: data?.length || 0,
          });
        }

        // All templates returned already match the hardware_color (mandatory field)
        // Sort by created_at descending (most recent first)
        // No need for complex sorting since hardware_color is mandatory and already filtered

        // If table doesn't exist, return empty array (graceful degradation)
        if (fetchError) {

          // Check if error is "table does not exist"
          if (fetchError.code === 'PGRST205' || fetchError.message?.includes('does not exist')) {
            if (import.meta.env.DEV) {
              console.warn('BOMTemplates table does not exist yet. Please run migration 56_create_bom_templates.sql');
            }
            setTemplates([]);
            setError('BOMTemplates table does not exist. Please run migration.');
            return;
          }
          
          // ✅ FIX A: Check for RLS/permission errors
          if (fetchError.code === '42501' || fetchError.message?.includes('permission denied') || fetchError.message?.includes('RLS')) {
            console.error('[useBOMTemplates] RLS/Permission error - templates may exist but user cannot read them', { 
              error: fetchError, 
              activeOrganizationId, 
              productTypeId 
            });
            setError('Permission denied: Cannot read BOMTemplates. Check RLS policies.');
            setTemplates([]);
            return;
          }
          
          if (import.meta.env.DEV) {
            // ✅ FIX: Formatear error para evitar "[circular]"
            const errorDetails = { 
              message: fetchError.message, 
              code: fetchError.code,
              details: fetchError.details 
            };
            console.error('[useBOMTemplates] Query error', { error: errorDetails, activeOrganizationId, productTypeId });
          }
          setError(fetchError.message || 'Error loading BOM templates');
          // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
          throw new Error(fetchError.message || 'Error loading BOM templates');
        }
        

        // (logs reducidos para evitar objetos grandes)

        // Fetch product types separately to avoid FK issues
        const productTypeIds = [...new Set((data || []).map((item: any) => item.product_type_id).filter(Boolean))] as string[];
        let productTypesMap = new Map<string, ProductType>();
        
        if (productTypeIds.length > 0) {
          const missingIds = productTypeIds.filter((id) => !productTypesCache.has(id));
          if (missingIds.length > 0) {
            // CRITICAL: Also include shared ProductTypes (organization_id IS NULL)
            // ✅ FIX: ProductTypes NO tiene columna "deleted"
            const { data: ptData, error: ptError } = await supabase
              .from('ProductTypes')
              .select('id, code, name, organization_id')
              .in('id', missingIds)
              .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);
          
            if (ptError) {
              // ✅ (B) Usar safeErr para evitar "[circular]"
              console.warn('[useBOMTemplates] Error fetching ProductTypes', safeErr(ptError));
            }
          
            if (ptData) {
              if (import.meta.env.DEV) {
                console.debug('[useBOMTemplates] ProductTypes fetched', { count: ptData.length });
              }
              ptData.forEach((pt: any) => {
                productTypesCache.set(pt.id, {
                  id: pt.id,
                  code: pt.code,
                  name: pt.name,
                  sort_order: 0,
                } as ProductType);
              });
            }
          }

          const entries = productTypeIds
            .map((id) => [id, productTypesCache.get(id)] as [string, ProductType | undefined])
            .filter(([, val]) => !!val) as Array<[string, ProductType]>;
          productTypesMap = new Map(entries);
        }

        // Map the data to include joined product_type
        let mappedTemplates: BOMTemplate[] = (data || []).map((item: any) => ({
          ...item,
          product_type: productTypesMap.get(item.product_type_id),
        }));

        // ✅ RE-ARQUITECTURA: Guardar baseTemplates (después de filtros estructurales, antes de selections)
        // Base filters: product_type_id, hardware_color, operation_type (si aplica)
        // NO incluye: bottom_bar, tube, motor, drive, headbox (estos son selections)
        const baseTemplatesResult = [...mappedTemplates];
        
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplates] base templates', {
            count: baseTemplatesResult.length,
            productTypeId,
            hardwareColor: normalizedColor,
            operationType: filters?.operation_type || null,
          });
        }

        // ✅ FILTRAR POR SELECCIONES ADICIONALES: Filtrar templates basándose en SKUs exactos de BOMTemplateSlots
        // FILTER LOGIC: ProductType/Color/Bottom Bar(obligatorio)/ Headbox (opcional)/ Operating Type (Obligatorio)/ Tube (obligatorio)
        // NOTA: side_channel y bottom_channel NO filtran templates, solo afectan BOM generation
        const normalizedFilters = filters ? {
          ...filters,
          headbox_sku: normalizeSku(filters.headbox_sku),
          motor_sku: normalizeSku(filters.motor_sku),
          drive_sku: normalizeSku(filters.drive_sku),
          bottom_bar_sku: normalizeSku(filters.bottom_bar_sku),
          tube_sku: normalizeSku(filters.tube_sku),
        } : null;

        const slotMatches = (
          slot: { catalog_item_id?: string | null; fixed_catalog_item_id?: string | null; sku?: string | null },
          expectedItemId: string | null,
          expectedSku: string | null
        ) => {
          const effectiveItemId = slot.fixed_catalog_item_id || slot.catalog_item_id || null;
          if (expectedItemId) return effectiveItemId === expectedItemId;
          if (expectedSku) {
            const s = (slot.sku || '').trim();
            return s.length > 0 && s === expectedSku;
          }
          return true;
        };

        if (normalizedFilters && (normalizedFilters.operation_type || normalizedFilters.headbox_sku || normalizedFilters.motor_sku || normalizedFilters.drive_sku || normalizedFilters.bottom_bar_sku || normalizedFilters.tube_sku || normalizedFilters.headbox_item_id || normalizedFilters.motor_item_id || normalizedFilters.drive_item_id || normalizedFilters.bottom_bar_item_id || normalizedFilters.tube_item_id)) {

          try {
            const templateIds = mappedTemplates.map(t => t.id);
            
            if (templateIds.length > 0) {
              // Obtener todos los slots para estos templates
              const { data: slotsData, error: slotsError } = await supabase
                .from('BOMTemplateSlots')
                .select('bom_template_id, item_role, catalog_item_id, selection_mode, fixed_catalog_item_id, slot_sku')
                .eq('organization_id', activeOrganizationId)
                .in('bom_template_id', templateIds);

              if (import.meta.env.DEV) {
                console.debug('[useBOMTemplates] slots fetched', {
                  slotsCount: slotsData?.length || 0,
                });
              }

              if (slotsError) {
                if (import.meta.env.DEV) {
                  console.warn('[useBOMTemplates] Error fetching slots for filtering:', safeErr(slotsError));
                }
              } else if (slotsData && slotsData.length > 0) {
                // Catalog item ids: catalog_item_id + fixed_catalog_item_id (for SKU lookup)
                const catalogItemIds = [...new Set(
                  slotsData.flatMap((slot: any) =>
                    [slot.catalog_item_id, slot.fixed_catalog_item_id].filter(Boolean)
                  )
                )] as string[];
                
                // ✅ Obtener SKUs de los CatalogItems (SOLO activos, no deleted, no archived)
                let catalogItemsMap = new Map<string, string>();
                if (catalogItemIds.length > 0) {
                  const { data: catalogItemsData, error: catalogItemsError } = await supabase
                    .from('CatalogItems')
                    .select('id, sku, is_active')
                    .eq('organization_id', activeOrganizationId)
                    .in('id', catalogItemIds)
                    .eq('is_active', true);
                  
                  if (catalogItemsError) {
                    if (import.meta.env.DEV) {
                      console.warn('[useBOMTemplates] Error fetching catalog items for SKU filtering:', safeErr(catalogItemsError));
                    }
                  } else if (catalogItemsData) {
                    catalogItemsData.forEach((item: any) => {
                      // ✅ Solo agregar si tiene SKU válido y está activo
                      if (item.sku && item.sku.trim() !== '') {
                        catalogItemsMap.set(item.id, item.sku.trim());
                      }
                    });
                    
                    if (import.meta.env.DEV) {
                      console.debug('[useBOMTemplates] catalog items map', {
                        itemCount: catalogItemsMap.size,
                        totalCatalogItems: catalogItemsData.length,
                      });
                    }
                  }
                }

                // ✅ Agrupar slots por template_id (GUARDAR item_role EXACTO de DB)
                type SlotRow = {
                  item_role: string;
                  role_normalized: string;
                  catalog_item_id: string | null;
                  fixed_catalog_item_id: string | null;
                  selection_mode: string;
                  sku: string | null;
                };
                const slotsByTemplate = new Map<string, { 
                  roles: Set<string>; 
                  slots: Array<SlotRow>;
                }>();
                slotsData.forEach((slot: any) => {
                  const templateId = slot.bom_template_id;
                  const originalRole = slot.item_role || '';
                  const normalizedRoleValue = normalizeRole(originalRole) || originalRole.toLowerCase();
                  const effectiveItemId = slot.fixed_catalog_item_id || slot.catalog_item_id || null;
                  const slotSku = (slot.slot_sku || '').trim() || null;
                  const catalogItemSku = effectiveItemId ? (catalogItemsMap.get(effectiveItemId) || null) : null;
                  const sku = slotSku || catalogItemSku;
                  
                  if (!slotsByTemplate.has(templateId)) {
                    slotsByTemplate.set(templateId, { roles: new Set(), slots: [] });
                  }
                  const templateData = slotsByTemplate.get(templateId)!;
                  templateData.roles.add(normalizedRoleValue.toLowerCase());
                  templateData.roles.add(originalRole.toLowerCase());
                  templateData.slots.push({
                    item_role: originalRole,
                    role_normalized: normalizedRoleValue.toLowerCase(),
                    catalog_item_id: slot.catalog_item_id || null,
                    fixed_catalog_item_id: slot.fixed_catalog_item_id || null,
                    selection_mode: slot.selection_mode || 'user_select',
                    sku,
                  });
                });

                if (import.meta.env.DEV) {
                  console.debug('[useBOMTemplates] slots grouped', {
                    templateCount: slotsByTemplate.size,
                    sampleSlots: Array.from(slotsByTemplate.entries()).slice(0, 2).map(([tid, data]) => ({
                      templateId: tid,
                      slotsCount: data.slots.length,
                      bottomBarSlots: data.slots.filter(s => {
                        const r = (s.item_role || '').toLowerCase().trim();
                        return r === 'bottom_bar';
                      }).map(s => ({
                        catalog_item_id: s.catalog_item_id,
                        sku: s.sku,
                        item_role: s.item_role,
                      })),
                    })),
                  });
                }

                // =====================================================
                // PASO 3: BOTTOM BAR (OBLIGATORIO)
                // =====================================================
                if (normalizedFilters?.bottom_bar_item_id || normalizedFilters?.bottom_bar_sku) {
                  const expectedItemId = normalizedFilters?.bottom_bar_item_id ?? null;
                  const expectedSku = (normalizedFilters?.bottom_bar_sku ?? '').trim() || null;

                  const templatesBeforeBottomBarFilter = mappedTemplates.length;

                  if (import.meta.env.DEV) {
                    console.debug('[useBOMTemplates] HARD FILTER bottom_bar START', {
                      expectedItemId,
                      expectedSku,
                      templatesBefore: templatesBeforeBottomBarFilter,
                      templateIds: mappedTemplates.map(t => t.id),
                    });
                  }

                  mappedTemplates = mappedTemplates.filter(template => {
                    const templateData = slotsByTemplate.get(template.id);
                    const slots = templateData?.slots || [];

                    const isBottomBarSlot = (s: { item_role?: string; role_normalized?: string }) => {
                      const role = (s.item_role || '').toLowerCase().trim();
                      const rn = (s.role_normalized || '').toLowerCase().trim();
                      return role === 'bottom_bar' || rn === 'bottom_bar' || rn === 'bottom bar' || rn.includes('bottom_bar');
                    };

                    // Filtrar slots de bottom_bar
                    const bottomBarSlots = slots.filter(isBottomBarSlot);
                    
                    // Verificar match en cada slot
                    const hasMatch = bottomBarSlots.some((s: { item_role: string; sku: string | null; catalog_item_id: string | null; role_normalized?: string }) => {
                      const matches = slotMatches(s, expectedItemId, expectedSku);
                      
                      if (import.meta.env.DEV) {
                        console.debug('[useBOMTemplates bottom_bar slot check]', {
                          template_id: template.id,
                          slot_catalog_item_id: s.catalog_item_id,
                          slot_sku: s.sku,
                          slot_item_role: s.item_role,
                          expectedItemId,
                          expectedSku,
                          matches,
                        });
                      }
                      
                      return matches;
                    });
                    const hasRoleOnlySlot = bottomBarSlots.some(
                      (s: SlotRow) =>
                        !(s.fixed_catalog_item_id || s.catalog_item_id) && !(s.sku || '').trim()
                    );
                    const hasMatchOrRoleFallback = hasMatch || hasRoleOnlySlot;

                    if (import.meta.env.DEV) {
                      console.debug('[useBOMTemplates bottom_bar match]', {
                        template_id: template.id,
                        template_name: template.name,
                        expectedItemId,
                        expectedSku,
                        bottomBarSlotsCount: bottomBarSlots.length,
                        bottomBarSlots: bottomBarSlots.map((s: SlotRow) => ({
                          catalog_item_id: s.catalog_item_id,
                          fixed_catalog_item_id: s.fixed_catalog_item_id,
                          sku: s.sku,
                          item_role: s.item_role,
                        })),
                        hasMatch,
                        hasRoleOnlySlot,
                        hasMatchOrRoleFallback,
                      });
                    }

                    return hasMatchOrRoleFallback;
                  });

                  if (import.meta.env.DEV) {
                    console.debug('[useBOMTemplates] HARD FILTER bottom_bar END', {
                      templatesBefore: templatesBeforeBottomBarFilter,
                      templatesAfter: mappedTemplates.length,
                      filteredOut: templatesBeforeBottomBarFilter - mappedTemplates.length,
                      remainingTemplateIds: mappedTemplates.map(t => t.id),
                    });
                  }
                }

                // =====================================================
                // PASO 4: HEAD BOX (REQUERIMIENTOS POR PRODUCT TYPE)
                // - Dual/Triple: OBLIGATORIO
                // - Roller: OPCIONAL
                // - Otros: NO APLICA
                // =====================================================
                {
                  const expectedItemId = normalizedFilters?.headbox_item_id ?? null;
                  const expectedSku = (normalizedFilters?.headbox_sku ?? '').trim() || null;

                  // Determinar si headbox es requerido basado en productType
                  const productTypeCode = productTypeId ? productTypesMap.get(productTypeId)?.code : null;
                  const isHeadboxRequired = productTypeCode === 'dual-shade' || productTypeCode === 'triple-shade';
                  const isRollerShade = productTypeCode === 'roller-shade';

                  if (import.meta.env.DEV) {
                    console.debug('[useBOMTemplates] PASO 4: HEAD BOX', {
                      expectedItemId,
                      expectedSku,
                      productTypeCode,
                      isHeadboxRequired,
                      isRollerShade,
                      templatesBefore: mappedTemplates.length,
                    });
                  }

                  mappedTemplates = mappedTemplates.filter(template => {
                    const templateData = slotsByTemplate.get(template.id);
                    const slots = templateData?.slots || [];

                    const isHeadboxSlot = (s: { item_role?: string; role_normalized?: string }) => {
                      const role = (s.item_role || '').toLowerCase().trim();
                      const rn = (s.role_normalized || '').toLowerCase().trim();
                      return role === 'headbox' || rn === 'headbox' || rn === 'cassette' || role.includes('headbox');
                    };

                    const headboxSlots = slots.filter(isHeadboxSlot);
                    const hasMatch = headboxSlots.some(s => slotMatches(s, expectedItemId, expectedSku));

                    // Para Dual/Triple: debe tener headbox y debe coincidir
                    if (isHeadboxRequired) {
                      return hasMatch;
                    }

                    // Para Roller: si NO hay selección, excluir templates con headbox
                    if (isRollerShade && !expectedItemId && !expectedSku) {
                      return headboxSlots.length === 0;
                    }

                    // Para Roller: si hay selección debe coincidir
                    if (isRollerShade) {
                      return hasMatch;
                    }

                    // Otros tipos: no aplica headbox (no filtra)
                    return true;
                  });
                }

                // ✅ FILTRADO SECUENCIAL COMPLETADO
                // Los pasos 3-6 ya se aplicaron arriba en orden estricto
                const templatesCountBeforeFiltering = mappedTemplates.length;
                const filteredTemplatesBeforeScoring = mappedTemplates;

                if (import.meta.env.DEV) {
                  console.log('[useBOMTemplates] 📊 After SKU filtering:', {
                    filters: {
                      operation_type: normalizedFilters?.operation_type,
                      headbox_sku: normalizedFilters?.headbox_sku,
                      bottom_bar_sku: normalizedFilters?.bottom_bar_sku,
                      tube_sku: normalizedFilters?.tube_sku,
                      motor_sku: normalizedFilters?.motor_sku,
                      drive_sku: normalizedFilters?.drive_sku,
                    },
                    beforeCount: templatesCountBeforeFiltering,
                    afterCount: filteredTemplatesBeforeScoring.length,
                    filteredOut: templatesCountBeforeFiltering - filteredTemplatesBeforeScoring.length,
                    remainingTemplateIds: filteredTemplatesBeforeScoring.map(t => t.id),
                    remainingTemplateNames: filteredTemplatesBeforeScoring.map(t => t.name),
                  });
                  
                  // ✅ DEBUG ESPECÍFICO: Resumen del filtro de bottom_bar
                  if (normalizedFilters?.bottom_bar_sku) {
                    console.log(`[useBOMTemplates] 📊 [BOTTOM_BAR_FILTER] Summary:`, {
                      bottom_bar_sku: normalizedFilters.bottom_bar_sku,
                      templatesBefore: templatesCountBeforeFiltering,
                      templatesAfter: filteredTemplatesBeforeScoring.length,
                      templatesFilteredOut: templatesCountBeforeFiltering - filteredTemplatesBeforeScoring.length,
                      remainingTemplates: filteredTemplatesBeforeScoring.map(t => ({
                        id: t.id,
                        name: t.name,
                      })),
                    });
                  }
                }

                // ✅ LÓGICA "MÁS CERCANO": Priorizar templates con más componentes coincidentes
                // Calcular score de cada template (número de componentes que coinciden)
                const templateScores = filteredTemplatesBeforeScoring.map(template => {
                  const templateData = slotsByTemplate.get(template.id);
                  const templateSlotsList = templateData?.slots || [];
                  
                  let matchScore = 0;
                  const matchedComponents: string[] = [];
                  
                  // ✅ CRITICAL: Contar operation_type como coincidencia (obligatorio)
                  if (normalizedFilters?.operation_type) {
                    // ✅ Usar la misma lógica que en el filtrado: buscar slots con item_role exacto
                    const motorSlotsForScoring = templateSlotsList.filter(s => {
                      const exactMatch = s.item_role?.toLowerCase() === 'motor';
                      const normalizedMatch = s.role_normalized === 'motor' || 
                                            s.role_normalized.includes('motor');
                      return exactMatch || normalizedMatch;
                    });
                    
                    const driveSlotsForScoring = templateSlotsList.filter(s => {
                      const exactMatch = s.item_role?.toLowerCase() === 'drive';
                      const normalizedMatch = (s.role_normalized === 'drive' || 
                                              s.role_normalized.includes('drive')) && 
                                             !s.role_normalized.includes('motor');
                      return exactMatch || normalizedMatch;
                    });
                    
                    const hasMotorRole = motorSlotsForScoring.length > 0;
                    const hasDriveRole = driveSlotsForScoring.length > 0;
                    
                  if (normalizedFilters?.operation_type === 'motor' && hasMotorRole && !hasDriveRole) {
                      matchScore++;
                      matchedComponents.push(`operation_type:motor`);
                  } else if (normalizedFilters?.operation_type === 'manual' && hasDriveRole && !hasMotorRole) {
                      matchScore++;
                      matchedComponents.push(`operation_type:manual`);
                    }
                  }
                  
                  // Contar coincidencias por SKU (normalizar para comparación)
                  if (normalizedFilters?.bottom_bar_sku) {
                    const expectedSku = normalizedFilters.bottom_bar_sku;
                    const hasMatch = templateSlotsList.some(s => {
                      const slotSku = (s.sku || '').trim();
                      return slotSku && slotSku === expectedSku;
                    });
                    if (hasMatch) {
                      matchScore++;
                      matchedComponents.push(`bottom_bar:${expectedSku}`);
                    }
                  }
                  
                  // ✅ CRITICAL: Contar headbox_sku en el score (opcional pero importante cuando está seleccionado)
                  if (normalizedFilters?.headbox_sku) {
                    const expectedSku = normalizedFilters.headbox_sku;
                    const hasMatch = templateSlotsList.some(s => {
                      const slotSku = (s.sku || '').trim();
                      return slotSku && slotSku === expectedSku;
                    });
                    if (hasMatch) {
                      matchScore++;
                      matchedComponents.push(`headbox:${expectedSku}`);
                    } else {
                      // ✅ Si headbox_sku está seleccionado pero no coincide, no debería llegar aquí
                      // porque ya fue filtrado arriba, pero por seguridad no sumamos score
                    }
                  }
                  
                  if (normalizedFilters?.motor_sku) {
                    const expectedSku = normalizedFilters.motor_sku;
                    const hasMatch = templateSlotsList.some(s => {
                      const slotSku = (s.sku || '').trim();
                      return slotSku && slotSku === expectedSku;
                    });
                    if (hasMatch) {
                      matchScore++;
                      matchedComponents.push(`motor:${expectedSku}`);
                    }
                  }
                  
                  if (normalizedFilters?.drive_sku) {
                    const expectedSku = normalizedFilters.drive_sku;
                    const hasMatch = templateSlotsList.some(s => {
                      const slotSku = (s.sku || '').trim();
                      return slotSku && slotSku === expectedSku;
                    });
                    if (hasMatch) {
                      matchScore++;
                      matchedComponents.push(`drive:${expectedSku}`);
                    }
                  }
                  
                  if (normalizedFilters?.tube_sku) {
                    const expectedSku = normalizedFilters.tube_sku;
                    const hasMatch = templateSlotsList.some(s => {
                      const slotSku = (s.sku || '').trim();
                      return slotSku && slotSku === expectedSku;
                    });
                    if (hasMatch) {
                      matchScore++;
                      matchedComponents.push(`tube:${expectedSku}`);
                    }
                  }
                  
                  // ✅ NOTA: side_channel y bottom_channel NO se incluyen en scoring
                  // porque NO filtran templates, solo afectan BOM generation
                  
                  return { template, matchScore, matchedComponents };
                });

                // Ordenar por score (más coincidencias primero), luego por criterios adicionales
                templateScores.sort((a, b) => {
                  if (a.matchScore !== b.matchScore) {
                    return b.matchScore - a.matchScore; // Mayor score primero
                  }
                  // Si tienen el mismo score, desambiguar por:
                  // 1. Priorizar templates que coincidan con headbox si está seleccionado
                  if (normalizedFilters?.headbox_sku) {
                    const aHasHeadbox = a.matchedComponents.some(c => c.startsWith('headbox:'));
                    const bHasHeadbox = b.matchedComponents.some(c => c.startsWith('headbox:'));
                    if (aHasHeadbox && !bHasHeadbox) return -1;
                    if (!aHasHeadbox && bHasHeadbox) return 1;
                  }
                  // 2. Finalmente, ordenar por nombre (alfabético) para consistencia
                  // NOTA: side_channel y bottom_channel NO se usan en ordenamiento porque NO filtran templates
                  const aName = a.template.name || '';
                  const bName = b.template.name || '';
                  return aName.localeCompare(bName);
                });

                // Si hay filtros activos, solo retornar templates con score > 0
                // ✅ CRITICAL: Incluir operation_type en hasActiveFilters
                // NOTA: side_channel y bottom_channel NO filtran templates, solo afectan BOM generation
                const hasActiveFilters = normalizedFilters?.operation_type || normalizedFilters?.bottom_bar_sku || normalizedFilters?.headbox_sku || normalizedFilters?.motor_sku || normalizedFilters?.drive_sku || normalizedFilters?.tube_sku;
                if (hasActiveFilters) {
                  const filteredByScore: BOMTemplate[] = templateScores
                    .filter(({ matchScore }) => matchScore > 0)
                    .map(({ template }) => template)
                    .filter((t): t is BOMTemplate => t !== undefined);
                  
                  // ✅ NO AUTO-SELECT: Si hay múltiples templates, dejar todos disponibles
                  // El usuario debe seleccionar explícitamente
                  mappedTemplates = filteredByScore;
                  
                  if (import.meta.env.DEV && filteredByScore.length > 1) {
                    console.log('[useBOMTemplates] ℹ️ Multiple templates available after filtering (no auto-select):', {
                      count: filteredByScore.length,
                      templates: filteredByScore.map(t => ({ id: t.id, name: t.name })),
                    });
                  }
                  
                  if (import.meta.env.DEV) {
                    console.log('[useBOMTemplates] 📊 After scoring with active filters:', {
                      beforeScoring: filteredTemplatesBeforeScoring.length,
                      afterScoring: mappedTemplates.length,
                      scores: templateScores.map(({ template, matchScore, matchedComponents }) => ({
                        templateId: template.id,
                        templateName: template.name,
                        matchScore,
                        matchedComponents,
                      })),
                      finalCount: mappedTemplates.length,
                      finalTemplateIds: mappedTemplates.map(t => t.id),
                      finalTemplateNames: mappedTemplates.map(t => t.name),
                    });
                  }
                } else {
                  mappedTemplates = templateScores.map(({ template }) => template);
                }

                // ✅ VALIDACIÓN: Log final con información de filtrado
                if (import.meta.env.DEV) {
                  console.debug('[useBOMTemplates] candidates after filters', {
                    count: mappedTemplates.length,
                    nonFilterRoles: Array.from(NON_TEMPLATE_FILTER_ROLES),
                    filters: {
                      operation_type: normalizedFilters?.operation_type,
                      bottom_bar_sku: normalizedFilters?.bottom_bar_sku,
                      tube_sku: normalizedFilters?.tube_sku,
                      motor_sku: normalizedFilters?.motor_sku,
                      drive_sku: normalizedFilters?.drive_sku,
                      headbox_sku: normalizedFilters?.headbox_sku,
                      // side_channel y bottom_channel NO filtran templates
                      side_channel_sku: normalizedFilters?.side_channel_sku,
                      bottom_channel_sku: normalizedFilters?.bottom_channel_sku,
                    },
                    scores: templateScores.map(({ template, matchScore, matchedComponents }) => ({
                      templateId: template.id,
                      templateName: template.name,
                      matchScore,
                      matchedComponents,
                    })),
                    finalCount: mappedTemplates.length,
                    finalTemplateIds: mappedTemplates.map(t => t.id),
                    finalTemplateNames: mappedTemplates.map(t => t.name),
                  });
                  
                  // ✅ CRITICAL: Si aún hay múltiples templates, mostrar advertencia (solo primitives, sin [circular])
                  if (mappedTemplates.length > 1) {
                    console.warn('[useBOMTemplates] ⚠️ WARNING: Multiple templates found after filtering!', {
                      count: mappedTemplates.length,
                      templateIds: mappedTemplates.map(t => t.id),
                      templateNames: mappedTemplates.map(t => t.name),
                      filterSummary: {
                        bottom_bar_item_id: normalizedFilters?.bottom_bar_item_id ?? null,
                        bottom_bar_sku: normalizedFilters?.bottom_bar_sku ?? null,
                        operation_type: normalizedFilters?.operation_type ?? null,
                        hardware_color: normalizedColor ?? null,
                      },
                    });
                  }
                }

                if (import.meta.env.DEV) {
                  console.log('[useBOMTemplates] Filtered templates by selections:', {
                    initialCount: (data || []).length,
                    filteredCount: mappedTemplates.length,
                    remainingTemplateIds: mappedTemplates.map(t => t.id),
                    filterSummary: {
                      bottom_bar_item_id: normalizedFilters?.bottom_bar_item_id ?? null,
                      bottom_bar_sku: normalizedFilters?.bottom_bar_sku ?? null,
                      operation_type: normalizedFilters?.operation_type ?? null,
                    },
                  });
                }
              }
            }
          } catch (err) {
            if (import.meta.env.DEV) {
              console.warn('[useBOMTemplates] Error filtering templates by slots:', safeErr(err));
            }
          }
        }

        // ✅ RE-ARQUITECTURA: Guardar filteredTemplates (después de aplicar selections)
        const filteredTemplatesResult = mappedTemplates;
        
        // ✅ VALIDACIÓN OBLIGATORIA: Logs simples (solo counts y 5 ids)
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplates] sets', {
            baseCount: baseTemplatesResult.length,
            filteredCount: filteredTemplatesResult.length,
            baseIds: baseTemplatesResult.slice(0, 5).map(t => t.id),
            filteredIds: filteredTemplatesResult.slice(0, 5).map(t => t.id),
          });
        }
        
        setTemplates(filteredTemplatesResult);
        setBaseTemplates(baseTemplatesResult);
        // ✅ FIX: Cache ahora guarda tanto baseTemplates como templates
        templatesCache.set(cacheKey, {
          baseTemplates: baseTemplatesResult,
          templates: filteredTemplatesResult,
          ts: Date.now(),
        });
        
        // ✅ VALIDACIÓN FINAL: Log de candidatos después de filtros
        if (import.meta.env.DEV) {
          console.debug('[useBOMTemplates] Filtered templates (after selections)', {
            baseCount: baseTemplatesResult.length,
            filteredCount: filteredTemplatesResult.length,
            filteredOut: baseTemplatesResult.length - filteredTemplatesResult.length,
            nonFilterRoles: Array.from(NON_TEMPLATE_FILTER_ROLES),
            filtersApplied: normalizedFilters ? {
              operation_type: normalizedFilters.operation_type,
              bottom_bar_sku: normalizedFilters.bottom_bar_sku,
              headbox_sku: normalizedFilters.headbox_sku,
              motor_sku: normalizedFilters.motor_sku,
              drive_sku: normalizedFilters.drive_sku,
              tube_sku: normalizedFilters.tube_sku,
              // side_channel y bottom_channel NO filtran
            } : null,
            filteredTemplateIds: filteredTemplatesResult.slice(0, 5).map(t => t.id),
          });
        }
      } catch (err) {
        // ✅ (B) Usar safeErr para evitar "[circular]"
        console.error('[useBOMTemplates] Error fetching ProductTypes', safeErr(err));
        const errorMessage = err instanceof Error ? err.message : 'Error loading BOM templates';
        setError(errorMessage);
        setTemplates([]); // para no bloquear UI
        setBaseTemplates([]);
      } finally{
        setLoading(false);
      }
    };

        useEffect(() => {
          fetchBOMTemplates();
        }, [activeOrganizationId, productTypeId, hardwareColor, filters?.operation_type, filters?.headbox_item_id, filters?.headbox_sku, filters?.motor_item_id, filters?.motor_sku, filters?.drive_item_id, filters?.drive_sku, filters?.bottom_bar_item_id, filters?.bottom_bar_sku, filters?.tube_item_id, filters?.tube_sku, filters?.side_channel_item_id, filters?.side_channel_sku, filters?.bottom_channel_item_id, filters?.bottom_channel_sku, refreshTrigger]);

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  // ✅ RE-ARQUITECTURA: Retornar baseTemplates y filteredTemplates separados
  return { 
    templates: templates, // filteredTemplates (después de selections)
    baseTemplates: baseTemplates, // baseTemplates (después de filtros estructurales, antes de selections)
    loading, 
    error, 
    refetch 
  };
}

/**
 * Hook for BOMTemplate CRUD operations
 */
export function useBOMTemplateCRUD() {
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createTemplate = async (
    templateData: Omit<BOMTemplate, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>
  ) => {
    // ✅ GATING: No crear sin organization_id
    if (!activeOrganizationId) {
      throw new Error('No organization selected. Please select an organization before creating a template.');
    }

    // ✅ MVP: Validación de campos requeridos
    if (!templateData.product_type_id) {
      throw new Error('product_type_id is required');
    }
    if (!templateData.code || templateData.code.trim() === '') {
      throw new Error('code is required and cannot be empty');
    }

    setIsCreating(true);
    try {
      const payload = {
        ...templateData,
        organization_id: activeOrganizationId, // ✅ SIEMPRE usar activeOrganizationId
        is_active: true,
        archived: false,
        metadata: templateData.metadata || {},
      };

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] Creating template with payload:', payload);
      }

      const { data, error } = await supabase
        .from('BOMTemplates')
        .insert(payload)
        .select('*')
        .single();

      if (error) {
        // ✅ FIX: Manejar error 23505 (duplicate key)
        if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('unique constraint')) {
          // Buscar el registro existente
          const { data: existingTemplate, error: findError } = await supabase
            .from('BOMTemplates')
            .select('*')
            .eq('organization_id', activeOrganizationId)
            .eq('code', templateData.code.trim())
            .limit(1)
            .maybeSingle();

          if (findError) {
            // ✅ FIX: Formatear error para evitar "[circular]"
            const errorDetails = { 
              message: findError.message, 
              code: findError.code,
              details: findError.details 
            };
            console.error('[useBOMTemplates] Error finding existing template:', errorDetails);
            throw new Error(`Code "${templateData.code.trim()}" already exists in this organization. Error finding existing template: ${findError.message}`);
          }

          if (existingTemplate) {
            if (!existingTemplate.is_active) {
              // ✅ Revivir template desactivado
              const { data: revivedTemplate, error: updateError } = await supabase
                .from('BOMTemplates')
                .update({
                  is_active: true,
                  ...templateData,
                  updated_at: new Date().toISOString(),
                })
                .eq('id', existingTemplate.id)
                .eq('organization_id', activeOrganizationId)
                .select('*')
                .single();

              if (updateError) {
                // ✅ FIX: Formatear error para evitar "[circular]"
                const errorDetails = { 
                  message: updateError.message, 
                  code: updateError.code,
                  details: updateError.details 
                };
                console.error('[useBOMTemplates] Error reviving template:', errorDetails);
                throw new Error(`Code "${templateData.code.trim()}" exists but is inactive. Error reviving: ${updateError.message}`);
              }

              if (import.meta.env.DEV) {
                console.log('[useBOMTemplates] Template revived successfully:', revivedTemplate);
              }

              return revivedTemplate;
            } else {
              // Template existe y no está eliminado
              throw new Error(`Code "${templateData.code.trim()}" already exists in this organization (ID: ${existingTemplate.id}). Use a different code or edit the existing template.`);
            }
          } else {
            // No se encontró el template (caso raro)
            throw new Error(`Code "${templateData.code.trim()}" violates unique constraint but template not found. Please try again.`);
          }
        }

        // ✅ MVP: Logging de errores visible
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = { 
          message: error.message, 
          code: error.code,
          details: error.details,
          hint: error.hint 
        };
        console.error('[useBOMTemplates] SAVE BOM TEMPLATE error:', errorDetails);
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error saving BOM template');
      }

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] SAVE BOM TEMPLATE success:', data);
      }

      return data;
    } finally {
      setIsCreating(false);
    }
  };

  const updateTemplate = async (id: string, updates: Partial<BOMTemplate>) => {
    // ✅ GATING: No actualizar sin organization_id
    if (!activeOrganizationId) {
      throw new Error('No organization selected. Please select an organization before updating a template.');
    }

    setIsUpdating(true);
    try {
      const payload = {
        ...updates,
        updated_at: new Date().toISOString(),
      };

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] Updating template:', { id, payload });
      }

      const { data, error } = await supabase
        .from('BOMTemplates')
        .update(payload)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId) // ✅ Filtrar por organization_id
        .select('*')
        .single();

      if (error) {
        // ✅ MVP: Logging de errores visible
        // ✅ FIX: Formatear error para evitar "[circular]"
        const errorDetails = { 
          message: error.message, 
          code: error.code,
          details: error.details,
          hint: error.hint 
        };
        console.error('[useBOMTemplates] UPDATE BOM TEMPLATE error:', errorDetails);
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error updating BOM template');
      }

      if (import.meta.env.DEV) {
        console.log('[useBOMTemplates] UPDATE BOM TEMPLATE success:', data);
      }

      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteTemplate = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('BOMTemplates')
        .update({ is_active: false })
        .eq('id', id);

      if (error) {
        // ✅ FIX: Throw Error message, not the entire object (prevents [circular])
        throw new Error(error.message || 'Error deleting template');
      }
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    createTemplate,
    updateTemplate,
    deleteTemplate,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

