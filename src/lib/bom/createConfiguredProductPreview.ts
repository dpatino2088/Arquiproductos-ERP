/**
 * Create ConfiguredProduct Preview
 * 
 * Helper function to create ConfiguredProduct + BOM preview before QuoteLine creation.
 * Uses RPC function create_configured_product_and_bom_preview for atomic operation.
 * 
 * ✅ NUEVA ARQUITECTURA (Matching al final):
 * El bom_template_id ahora viene pre-resuelto en config_snapshot desde el frontend
 * usando matchBOMTemplate() - ya no se hace matching interno en el RPC.
 */

import { supabase } from '../supabase/client';
import { CreateConfiguredProductPreviewParams, CreateConfiguredProductPreviewResult } from '../../types/configured-product';

function isMissingColumnError(error: any): boolean {
  const code = String(error?.code || '');
  const message = String(error?.message || '');
  // Postgres: undefined_column = 42703
  return code === '42703' || /column .* does not exist/i.test(message);
}

/**
 * Create ConfiguredProduct with BOM preview
 * 
 * This function:
 * 1. Uses pre-resolved bom_template_id from config_snapshot (matched by frontend)
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

  // ✅ NUEVA ARQUITECTURA: El bom_template_id viene pre-resuelto desde matchBOMTemplate()
  const preResolvedTemplateId = config_snapshot.bom_template_id || null;
  
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
    };
  } catch (err: any) {
    // ✅ FALLBACK: Si el RPC falla por columna faltante (schema mismatch), crear ConfiguredProduct directo.
    if (!isMissingColumnError(err)) {
      throw new Error(err?.message || 'Failed to create configured product preview');
    }

    if (!preResolvedTemplateId) {
      // Sin template no podemos crear ConfiguredProduct (NOT NULL)
      throw new Error(`Preview RPC failed due to schema mismatch, and bom_template_id is missing in config_snapshot. Original error: ${err?.message || 'Unknown error'}`);
    }

    if (import.meta.env.DEV) {
      console.warn('[createConfiguredProductPreview] Falling back to direct ConfiguredProducts insert due to schema mismatch:', {
        code: err?.code,
        message: err?.message,
        bom_template_id: preResolvedTemplateId,
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
        .select('sku, collection_name, variant_name, roll_width, is_fabric')
        .eq('id', rollId)
        .maybeSingle();

      if (rollItem && rollItem.is_fabric) {
        roll_sku = rollItem.sku ?? null;
        roll_collection_name = rollItem.collection_name ?? null;
        roll_variant_name = rollItem.variant_name ?? null;
        roll_width = rollItem.roll_width ?? null;
      }
    }

    const insertPayload: any = {
      organization_id,
      quote_id: quote_id || null,
      bom_template_id: preResolvedTemplateId,
      product_type_id,
      width_mm: config_snapshot.width_mm ?? null,
      height_mm: config_snapshot.height_mm ?? null,
      quantity,
      hardware_color: config_snapshot.hardware_color ?? null,
      config_snapshot,
      // Mirror key selections for downstream usage
      roll_catalog_item_id: rollId,
      roll_sku,
      roll_collection_name,
      roll_variant_name,
      roll_width,
      bottom_bar_item_id: config_snapshot.bottom_bar_item_id ?? null,
      bottom_bar_sku: config_snapshot.bottom_bar_sku ?? null,
      headbox_item_id: config_snapshot.headbox_item_id ?? null,
      headbox_sku: config_snapshot.headbox_sku ?? null,
      side_channel_item_id: config_snapshot.side_channel_item_id ?? null,
      side_channel_sku: config_snapshot.side_channel_sku ?? null,
      bottom_channel_item_id: config_snapshot.bottom_channel_item_id ?? null,
      bottom_channel_sku: config_snapshot.bottom_channel_sku ?? null,
      motor_item_id: config_snapshot.motor_item_id ?? null,
      motor_sku: config_snapshot.motor_sku ?? null,
      drive_item_id: config_snapshot.drive_item_id ?? null,
      drive_sku: config_snapshot.drive_sku ?? null,
      tube_item_id: config_snapshot.tube_item_id ?? null,
      tube_sku: config_snapshot.tube_sku ?? null,
      operating_type: config_snapshot.operating_type ?? null,
      // Totals will be computed later once DB functions are fixed
      roll_msrp_total: 0,
      bom_total: 0,
      roll_plus_bom_total: 0,
      labor_pct: 0,
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
