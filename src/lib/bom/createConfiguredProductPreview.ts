/**
 * Create ConfiguredProduct Preview
 * 
 * Helper function to create ConfiguredProduct + BOM preview before QuoteLine creation.
 * Uses RPC function create_configured_product_and_bom_preview for atomic operation.
 * 
 * ✅ NUEVA ARQUITECTURA (ConfiguredProduct como source-of-truth):
 * - El configurador crea/actualiza un ConfiguredProduct con config_snapshot completo.
 * - El bom_template_id se resuelve de forma estricta con la función del dump:
 *   public.select_best_bom_template_v2_strict(p_org, p_product_type, p_config)
 * - Luego el QuoteLine se genera/finaliza desde ConfiguredProduct (snapshot).
 */

import { supabase } from '../supabase/client';
import { CreateConfiguredProductPreviewParams, CreateConfiguredProductPreviewResult } from '../../types/configured-product';

function isMissingColumnError(error: any): boolean {
  const code = String(error?.code || '');
  const message = String(error?.message || '');
  // Postgres: undefined_column = 42703
  return code === '42703' || /column .* does not exist/i.test(message);
}

function normalizeOperationType(value: unknown): 'motor' | 'manual' | null {
  const v = String(value ?? '').toLowerCase().trim();
  if (v === 'motor' || v === 'motorized') return 'motor';
  if (v === 'manual') return 'manual';
  return null;
}

async function resolveBomTemplateIdStrict(args: {
  organization_id: string;
  product_type_id: string;
  config_snapshot: any;
}): Promise<string> {
  const { organization_id, product_type_id, config_snapshot } = args;

  const op = normalizeOperationType(
    config_snapshot?.operating_type ??
      config_snapshot?.operation_type ??
      config_snapshot?.drive_type ??
      config_snapshot?.operatingSystem ??
      null
  );

  const bottom_bar_id = config_snapshot?.bottom_bar_item_id ?? null;
  const tube_id = config_snapshot?.tube_item_id ?? null;
  const drive_id = config_snapshot?.drive_item_id ?? null;
  const motor_id = config_snapshot?.motor_item_id ?? null;

  // DB strict matcher expects keys: tube_id, bottom_bar_id, and XOR drive_id/motor_id.
  const p_config: any = {
    tube_id,
    bottom_bar_id,
    // Optional extra discriminators (if DB matcher uses them) — skip 'NONE' (UI tri-state for "Not Included")
    headbox_id: config_snapshot?.headbox_item_id === 'NONE' ? null : (config_snapshot?.headbox_item_id ?? null),
    side_channel_id: config_snapshot?.side_channel_item_id === 'NONE' ? null : (config_snapshot?.side_channel_item_id ?? null),
    bottom_channel_id: config_snapshot?.bottom_channel_item_id === 'NONE' ? null : (config_snapshot?.bottom_channel_item_id ?? null),
    hardware_color: config_snapshot?.hardware_color ?? null,
  };

  // Decide XOR explicitly.
  if (op === 'motor') {
    p_config.motor_id = motor_id;
  } else if (op === 'manual') {
    p_config.drive_id = drive_id;
  } else {
    // Fallback to presence (keeps strict XOR enforced by the DB function).
    if (motor_id) p_config.motor_id = motor_id;
    else p_config.drive_id = drive_id;
  }

  const { data, error } = await supabase.rpc('select_best_bom_template_v2_strict', {
    p_org: organization_id,
    p_product_type: product_type_id,
    p_config,
  });

  if (error) {
    throw new Error(error.message || 'Failed to resolve BOMTemplate (strict)');
  }
  if (!data) {
    throw new Error('Failed to resolve BOMTemplate (strict): RPC returned no template id');
  }
  return String(data);
}

async function resolveBomTemplateIdFrontendStrict(args: {
  organization_id: string;
  product_type_id: string;
  config_snapshot: any;
}): Promise<string> {
  const { organization_id, product_type_id, config_snapshot } = args;

  const op = normalizeOperationType(
    config_snapshot?.operating_type ??
      config_snapshot?.operation_type ??
      config_snapshot?.drive_type ??
      config_snapshot?.operatingSystem ??
      null
  );

  const selections = new Map<string, string>();
  const setIf = (role: string, value: any) => {
    const v = typeof value === 'string' ? value : value ? String(value) : '';
    const id = v.trim();
    if (id) selections.set(role, id);
  };

  // ✅ Required (aligned with v2_strict)
  setIf('bottom_bar', config_snapshot?.bottom_bar_item_id);
  setIf('tube', config_snapshot?.tube_item_id);
  setIf('motor', config_snapshot?.motor_item_id);
  setIf('drive', config_snapshot?.drive_item_id);
  // ✅ Optional discriminators (only if user selected a real item, NOT 'NONE')
  if (config_snapshot?.headbox_item_id && config_snapshot.headbox_item_id !== 'NONE') {
    setIf('headbox', config_snapshot.headbox_item_id);
  }
  if (config_snapshot?.side_channel_item_id && config_snapshot.side_channel_item_id !== 'NONE') {
    setIf('side_channel', config_snapshot.side_channel_item_id);
  }
  if (config_snapshot?.bottom_channel_item_id && config_snapshot.bottom_channel_item_id !== 'NONE') {
    setIf('bottom_channel', config_snapshot.bottom_channel_item_id);
  }

  // Enforce strict required fields (same spirit as v2_strict)
  if (!selections.get('tube')) throw new Error('Missing tube_item_id in config');
  if (!selections.get('bottom_bar')) throw new Error('Missing bottom_bar_item_id in config');

  const hasMotor = selections.has('motor');
  const hasDrive = selections.has('drive');
  if (hasMotor && hasDrive) {
    throw new Error('Config cannot contain both motor_item_id and drive_item_id');
  }
  if (!hasMotor && !hasDrive) {
    throw new Error('Config must contain motor_item_id OR drive_item_id');
  }
  if (op === 'motor' && !hasMotor) throw new Error('Operating type is motor but motor_item_id is missing');
  if (op === 'manual' && !hasDrive) throw new Error('Operating type is manual but drive_item_id is missing');

  // Enforce XOR based on operation type (ignore stale fields if any exist in snapshot)
  if (op === 'motor') selections.delete('drive');
  if (op === 'manual') selections.delete('motor');

  const normalizedColor = (() => {
    const c = config_snapshot?.hardware_color ?? config_snapshot?.hardwareColor ?? config_snapshot?.operatingSystemColor ?? null;
    if (!c) return null;
    const s = String(c).trim();
    if (!s) return null;
    return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
  })();

  // Load templates (be resilient to schema differences)
  let templates: Array<{ id: string; archived?: boolean; deleted?: boolean; is_active?: boolean; hardware_color?: string | null }> = [];
  {
    const candidateIdsRaw = config_snapshot?.candidate_template_ids;
    const candidateIds =
      Array.isArray(candidateIdsRaw) ? candidateIdsRaw.filter((x: any) => typeof x === 'string' && x.trim().length > 0) : [];

    const base = supabase
      .from('BOMTemplates')
      .select('id, archived, deleted, is_active, hardware_color')
      .eq('product_type_id', product_type_id)
      // ✅ support global templates (organization_id NULL)
      .or(`organization_id.eq.${organization_id},organization_id.is.null`);

    const { data, error } = candidateIds.length > 0 ? await base.in('id', candidateIds) : await base;
    if (error) {
      if (!isMissingColumnError(error)) throw new Error(error.message || 'Failed to load BOMTemplates');
      // Retry without is_active/hardware_color if those columns don't exist
      const { data: data2, error: error2 } = await supabase
        .from('BOMTemplates')
        .select('id, archived, deleted')
        .eq('product_type_id', product_type_id)
        .or(`organization_id.eq.${organization_id},organization_id.is.null`);
      if (error2) throw new Error(error2.message || 'Failed to load BOMTemplates');
      const narrowed = candidateIds.length > 0 ? (data2 as any)?.filter((t: any) => candidateIds.includes(t.id)) : data2;
      templates = (narrowed as any) || [];
    } else {
      templates = (data as any) || [];
    }
  }

  // ✅ FIX: Filtrar por hardware_color correctamente
  // Paso 1: Filtrar templates activos
  const activeTemplates = templates.filter((t) => {
    if ((t as any).deleted === true) return false;
    if ((t as any).archived === true) return false;
    if ((t as any).is_active === false) return false;
    return true;
  });

  if (activeTemplates.length === 0) {
    throw new Error('No active BOMTemplates found for this product type');
  }

  // Paso 2: Si el usuario seleccionó un color, filtrar por color
  let colorFilteredTemplates = activeTemplates;
  if (normalizedColor) {
    // Primero: buscar templates con el color exacto
    const exactColorMatches = activeTemplates.filter((t) => {
      const tColor = (t as any).hardware_color;
      if (!tColor) return false; // NULL no es match exacto
      return String(tColor).toLowerCase() === normalizedColor.toLowerCase();
    });

    if (exactColorMatches.length > 0) {
      // Hay templates con el color exacto - usar solo esos
      colorFilteredTemplates = exactColorMatches;
      if (import.meta.env.DEV) {
        console.debug('[resolveBomTemplateIdFrontendStrict] Found templates with exact color match:', {
          color: normalizedColor,
          count: exactColorMatches.length,
          templateIds: exactColorMatches.map(t => t.id),
        });
      }
    } else {
      // No hay templates con el color exacto - fallback a templates sin color (NULL)
      const nullColorTemplates = activeTemplates.filter((t) => !(t as any).hardware_color);
      if (nullColorTemplates.length > 0) {
        colorFilteredTemplates = nullColorTemplates;
        if (import.meta.env.DEV) {
          console.warn('[resolveBomTemplateIdFrontendStrict] No exact color match, using templates without color:', {
            requestedColor: normalizedColor,
            count: nullColorTemplates.length,
          });
        }
      } else {
        // No hay templates con el color ni sin color - error
        throw new Error(`No BOMTemplate found with hardware_color '${normalizedColor}' for this product type`);
      }
    }
  }

  const templateIds = colorFilteredTemplates.map((t) => String(t.id)).filter(Boolean);

  if (templateIds.length === 0) {
    throw new Error('No BOMTemplates found for this product type (after color filter)');
  }

  // Load parent components for templates
  const { data: comps, error: compsErr } = await supabase
    .from('BOMComponents')
    .select('bom_template_id, component_role, component_item_id, parent_component_id')
    // ✅ support global components (organization_id NULL) when templates are global
    .or(`organization_id.eq.${organization_id},organization_id.is.null`)
    .in('bom_template_id', templateIds)
    .eq('deleted', false)
    .eq('archived', false)
    .is('parent_component_id', null);

  if (compsErr) throw new Error(compsErr.message || 'Failed to load BOMComponents');

  const consideredRoles = new Set([
    // required
    'bottom_bar',
    'tube',
    'motor',
    'drive',
    // optional (only if user selected)
    'headbox',
    'side_channel',
    'bottom_channel',
  ]);

  const byTemplate = new Map<string, Map<string, Set<string>>>();
  (comps || []).forEach((c: any) => {
    const tid = String(c.bom_template_id || '').trim();
    const role = String(c.component_role || '').toLowerCase().trim();
    const itemId = c.component_item_id ? String(c.component_item_id).trim() : '';
    if (!tid || !role || !itemId) return;
    if (!consideredRoles.has(role)) return;
    if (!byTemplate.has(tid)) byTemplate.set(tid, new Map());
    const roleMap = byTemplate.get(tid)!;
    if (!roleMap.has(role)) roleMap.set(role, new Set());
    roleMap.get(role)!.add(itemId);
  });

  const matches: string[] = [];
  for (const tid of templateIds) {
    const roleMap = byTemplate.get(tid) || new Map<string, Set<string>>();

    // Require exact role->item matches for all selections we have
    let ok = true;
    for (const [role, selectedItemId] of selections.entries()) {
      if (!consideredRoles.has(role)) continue;
      const candidates = roleMap.get(role);
      if (!candidates || !candidates.has(selectedItemId)) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;

    matches.push(tid);
  }

  if (matches.length === 0) {
    throw new Error('No BOMTemplate match found (frontend fallback)');
  }
  if (matches.length > 1) {
    throw new Error(`Ambiguous BOMTemplate match (frontend fallback): ${matches.length} templates`);
  }
  return matches[0];
}

/**
 * Create ConfiguredProduct with BOM preview
 * 
 * This function:
 * 1. Resolves bom_template_id strictly (DB) when missing
 * 2. Creates ConfiguredProduct with full config snapshot
 * 3. Generates BOMInstance and BOMInstanceLines
 * 4. Calculates totals (roll_msrp_total, bom_total, roll_plus_bom_total, etc.)
 * 
 * @param params - Configuration parameters (config_snapshot should include bom_template_id)
 * @returns ConfiguredProduct ID, BOM Instance ID, and calculated totals
 */
export async function createConfiguredProductPreview(
  params: CreateConfiguredProductPreviewParams
): Promise<CreateConfiguredProductPreviewResult> {
  const { organization_id, product_type_id, config_snapshot, quote_id } = params;

  // Validate required fields
  if (!organization_id) {
    throw new Error('organization_id is required');
  }

  if (!product_type_id) {
    throw new Error('product_type_id is required');
  }

  if (!config_snapshot || typeof config_snapshot !== 'object') {
    throw new Error('config_snapshot is required and must be an object');
  }

  // ✅ NUEVA ARQUITECTURA: ConfiguredProduct es la base.
  // Resolver template de forma estricta desde config_snapshot si no viene.
  let preResolvedTemplateId = config_snapshot.bom_template_id || null;
  if (!preResolvedTemplateId) {
    // Try DB strict matcher first; if it fails due to schema mismatch, fallback to frontend matcher.
    try {
      preResolvedTemplateId = await resolveBomTemplateIdStrict({
        organization_id,
        product_type_id,
        config_snapshot,
      });
    } catch (e: any) {
      const msg = String(e?.message || e || '');
      if (import.meta.env.DEV) {
        console.warn('[createConfiguredProductPreview] DB strict matcher failed, falling back to frontend matcher:', msg);
      }
      preResolvedTemplateId = await resolveBomTemplateIdFrontendStrict({
        organization_id,
        product_type_id,
        config_snapshot,
      });
    }
    (config_snapshot as any).bom_template_id = preResolvedTemplateId; // keep consistent
  }
  
  if (import.meta.env.DEV) {
    console.log('[createConfiguredProductPreview] Using pre-resolved template:', {
      bom_template_id: preResolvedTemplateId,
      has_template: !!preResolvedTemplateId,
    });
  }

  // Call RPC function
  // ✅ CAMBIO: NO pasar quote_line_id (aún no existe)
  // El BOMInstance se creará después cuando se tenga QuoteLine
  try {
    const { data, error } = await supabase.rpc(
      'create_configured_product_and_bom_preview',
      {
        p_org_id: organization_id,
        p_product_type_id: product_type_id,
        p_config_snapshot: config_snapshot, // Incluye bom_template_id pre-resuelto
        p_quote_id: quote_id || null,
        p_quote_line_id: null,  // ✅ NULL: aún no existe QuoteLine
      }
    );

    if (error) {
      console.error('[createConfiguredProductPreview] RPC error:', error);
      // IMPORTANT: The DB function may re-run its own matching logic and fail due to schema drift.
      // We already resolved bom_template_id strictly; fallback to direct ConfiguredProducts insert.
      throw error;
    }

    if (!data) {
      throw new Error('RPC returned no data');
    }

    if (import.meta.env.DEV) {
      console.log('[createConfiguredProductPreview] Success:', {
        configured_product_id: data.configured_product_id,
        bom_instance_id: data.bom_instance_id,  // ✅ Puede ser NULL (se crea después con quote_line_id)
        bom_template_id: data.bom_template_id,
        totals: data.totals,
      });
      if (data.bom_instance_id === null) {
        console.debug('[createConfiguredProductPreview] BOMInstance NO creado en preview (quote_line_id es NULL). Se creará después cuando se tenga QuoteLine.');
      }
    }

    return {
      configured_product_id: data.configured_product_id,
      bom_instance_id: data.bom_instance_id,
      bom_template_id: data.bom_template_id,
      totals: data.totals,
      // ✅ NEW: Include bom_preview_snapshot for UI breakdown display
      bom_preview_snapshot: data.bom_preview_snapshot || null,
    };
  } catch (err: any) {
    // ✅ FALLBACK: si la RPC falla (schema drift, matching interno, etc), crear ConfiguredProduct directo.
    // Esto mantiene `ConfiguredProducts` como source-of-truth aunque la RPC esté desalineada.

    if (!preResolvedTemplateId) {
      // Sin template no podemos crear ConfiguredProduct (NOT NULL)
      throw new Error(
        `Preview RPC failed and bom_template_id is missing in config_snapshot. Original error: ${err?.message || 'Unknown error'}`
      );
    }

    if (import.meta.env.DEV) {
      console.warn('[createConfiguredProductPreview] Falling back to direct ConfiguredProducts insert:', {
        code: err?.code,
        message: err?.message,
        bom_template_id: preResolvedTemplateId,
        isMissingColumn: isMissingColumnError(err),
      });
    }

    const quantity = Number(config_snapshot.quantity ?? 1) || 1;

    // ✅ Completar snapshot de roll si existe (para que totals no queden en 0)
    let roll_sku: string | null = null;
    let roll_collection_name: string | null = null;
    let roll_variant_name: string | null = null;
    let roll_width: number | null = null; // metros

    const rollId = config_snapshot.roll_catalog_item_id ?? null;
    if (rollId) {
      const { data: rollItem } = await supabase
        .from('CatalogItems')
        .select('sku, collection_name, variant_name, roll_width, roll_width_m, is_roll, roll_type')
        .eq('id', rollId)
        .maybeSingle();

      if (rollItem && rollItem.is_roll && rollItem.roll_type === 'fabric') {
        roll_sku = rollItem.sku ?? null;
        roll_collection_name = rollItem.collection_name ?? null;
        roll_variant_name = rollItem.variant_name ?? null;
        roll_width = (rollItem.roll_width_m ?? rollItem.roll_width) ?? null;
      }
    }

    // ✅ Solo columnas que existen: componentes y operating_type están en config_snapshot (JSON)
    // Multi-panel: use total width (sum of all paños) for BOM calculations
    const measurements = config_snapshot?.measurements;
    const widthTotalMm = measurements?.width_total_mm ?? (Array.isArray(measurements?.panels) ? (measurements.panels as any[]).reduce((s, p) => s + (p?.width_mm || 0), 0) : null);
    const widthMmForRow = (widthTotalMm != null && widthTotalMm > 0) ? widthTotalMm : (config_snapshot.width_mm ?? null);
    const insertPayload: any = {
      organization_id,
      quote_id: quote_id || null,
      bom_template_id: preResolvedTemplateId,
      product_type_id,
      width_mm: widthMmForRow ?? config_snapshot.width_mm ?? null,
      height_mm: config_snapshot.height_mm ?? null,
      quantity,
      hardware_color: config_snapshot.hardware_color ?? null,
      config_snapshot,
      roll_catalog_item_id: rollId,
      roll_sku,
      roll_collection_name,
      roll_variant_name,
      roll_width,
      // Totals se rellenan por recalculate/build_bom_preview en backend
      roll_msrp_total: 0,
      bom_total: 0,
      roll_plus_bom_total: 0,
      labor_pct: config_snapshot.labor_pct ?? 0,
      accessories_total: 0,
      total_msrp: 0,
    };

    const { data: inserted, error: insertError } = await supabase
      .from('ConfiguredProducts')
      .insert(insertPayload)
      .select('id, bom_template_id')
      .single();

    if (insertError) {
      console.error('[createConfiguredProductPreview] Fallback insert error:', insertError);
      throw new Error(insertError.message || 'Failed to create ConfiguredProduct (fallback)');
    }

    // ✅ Intentar calcular totales si la función existe/funciona en DB
    try {
      const totals = await recalculateConfiguredProductTotals(inserted.id);
      return {
        configured_product_id: inserted.id,
        bom_instance_id: null as any,
        bom_template_id: inserted.bom_template_id,
        totals: {
          roll_msrp_total: Number(totals?.roll_msrp_total ?? 0),
          bom_total: Number(totals?.bom_total ?? 0),
          roll_plus_bom_total: Number(totals?.roll_plus_bom_total ?? 0),
          labor_pct: Number(totals?.labor_pct ?? 0),
          accessories_total: Number(totals?.accessories_total ?? 0),
          total_msrp: Number(totals?.total_msrp ?? 0),
        },
      };
    } catch (e: any) {
      if (import.meta.env.DEV) {
        console.warn('[createConfiguredProductPreview] Fallback totals calc failed, returning zeros:', e?.message || e);
      }
      return {
        configured_product_id: inserted.id,
        bom_instance_id: null as any, // No BOMInstance in fallback preview
        bom_template_id: inserted.bom_template_id,
        totals: {
          roll_msrp_total: 0,
          bom_total: 0,
          roll_plus_bom_total: 0,
          labor_pct: 0,
          accessories_total: 0,
          total_msrp: 0,
        },
      };
    }
  }
}

/**
 * Get ConfiguredProduct by ID
 */
export async function getConfiguredProduct(
  configuredProductId: string
): Promise<any | null> {
  const { data, error } = await supabase
    .from('ConfiguredProducts')
    .select('*')
    .eq('id', configuredProductId)
    .eq('deleted', false)
    .maybeSingle();

  if (error) {
    console.error('[getConfiguredProduct] Error:', error);
    throw new Error(error.message || 'Failed to get configured product');
  }

  return data;
}

/**
 * Calculate totals for existing ConfiguredProduct
 * 
 * Useful if BOM was updated and needs recalculation
 */
export async function recalculateConfiguredProductTotals(
  configuredProductId: string
): Promise<any> {
  const { data, error } = await supabase.rpc(
    'calculate_configured_product_totals',
    {
      p_configured_product_id: configuredProductId,
    }
  );

  if (error) {
    console.error('[recalculateConfiguredProductTotals] RPC error:', error);
    throw new Error(
      error.message || 'Failed to recalculate configured product totals'
    );
  }

  return data;
}
