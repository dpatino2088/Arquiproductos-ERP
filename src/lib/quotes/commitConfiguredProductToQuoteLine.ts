/**
 * commitConfiguredProductToQuoteLine
 * 
 * Frontend helper to commit a ConfiguredProduct to a QuoteLine using the official RPC.
 * This is the ONLY way to create QuoteLines from configured products.
 * 
 * The RPC handles:
 * 1. Validating the ConfiguredProduct belongs to the org
 * 2. Creating the QuoteLine with all fields from ConfiguredProduct
 * 3. Copying pricing snapshots from bom_preview_snapshot (source of truth)
 * 4. Setting pricing_locked=true to prevent recalculation
 * 
 * NOTE: BOMInstance is NOT created. The bom_preview_snapshot in ConfiguredProducts
 * contains all the BOM information needed. Manufacturing will use ConfiguredProducts
 * directly when the Quote is approved.
 */

import { supabase } from '../supabase/client';

export interface CommitConfiguredProductParams {
  organization_id: string;
  quote_id: string;
  configured_product_id: string;
  dealer_id?: string | null;
  position?: string | null;
  area?: string | null;
  fabric_drop?: string | null;
  installation_type?: string | null;
  installation_location?: string | null;
}

export interface CommitConfiguredProductResult {
  quote_line_id: string;
  bom_instance_id: string | null;
}

/**
 * Commits a ConfiguredProduct to a QuoteLine using the official DB RPC.
 * 
 * This function:
 * - Calls commit_configured_product_to_quote_line() RPC
 * - Creates QuoteLine with pricing snapshots from ConfiguredProduct
 * - Creates BOMInstance automatically
 * - Returns the new IDs
 * 
 * @throws Error if RPC fails (validation, DB error, etc.)
 */
export async function commitConfiguredProductToQuoteLine(
  params: CommitConfiguredProductParams
): Promise<CommitConfiguredProductResult> {
  const {
    organization_id,
    quote_id,
    configured_product_id,
    dealer_id = null,
    position = null,
    area = null,
    fabric_drop = null,
    installation_type = null,
    installation_location = null,
  } = params;

  // Validate required params
  if (!organization_id) {
    throw new Error('commitConfiguredProductToQuoteLine: organization_id is required');
  }
  if (!quote_id) {
    throw new Error('commitConfiguredProductToQuoteLine: quote_id is required');
  }
  if (!configured_product_id) {
    throw new Error('commitConfiguredProductToQuoteLine: configured_product_id is required');
  }

  if (import.meta.env.DEV) {
    console.log('[commitConfiguredProductToQuoteLine] Calling RPC', {
      organization_id,
      quote_id,
      configured_product_id,
      dealer_id,
      position,
      area,
      fabric_drop,
      installation_type,
      installation_location,
    });
  }

  // Call the RPC (p_dealer_id after Company -> Dealer rename)
  const { data, error } = await supabase.rpc('commit_configured_product_to_quote_line', {
    p_org_id: organization_id,
    p_quote_id: quote_id,
    p_configured_product_id: configured_product_id,
    p_dealer_id: dealer_id,
    p_position: position,
    p_area: area,
    p_fabric_drop: fabric_drop,
    p_installation_type: installation_type,
    p_installation_location: installation_location,
  });

  if (error) {
    console.error('[commitConfiguredProductToQuoteLine] RPC error:', error);
    throw new Error(`Failed to commit ConfiguredProduct to QuoteLine: ${error.message}`);
  }

  // The RPC returns TABLE(quote_line_id uuid, bom_instance_id uuid)
  // Supabase returns it as an array of objects
  if (!data || !Array.isArray(data) || data.length === 0) {
    console.error('[commitConfiguredProductToQuoteLine] RPC returned no data:', data);
    throw new Error('RPC commit_configured_product_to_quote_line returned no data');
  }

  const result = data[0];
  if (!result.quote_line_id) {
    console.error('[commitConfiguredProductToQuoteLine] RPC returned invalid data:', result);
    throw new Error('RPC commit_configured_product_to_quote_line returned no quote_line_id');
  }

  if (import.meta.env.DEV) {
    console.log('[commitConfiguredProductToQuoteLine] Success:', {
      quote_line_id: result.quote_line_id,
      bom_instance_id: result.bom_instance_id,
    });
  }

  return {
    quote_line_id: result.quote_line_id,
    bom_instance_id: result.bom_instance_id || null,
  };
}

/**
 * Fallback function in case the RPC doesn't exist yet in the DB.
 * Uses the legacy createQuoteLineFromConfiguredProduct approach.
 * 
 * This should be removed once the migration is applied.
 */
export async function commitConfiguredProductToQuoteLineFallback(
  params: CommitConfiguredProductParams
): Promise<CommitConfiguredProductResult> {
  // Import dynamically to avoid circular dependencies
  const { createQuoteLineFromConfiguredProduct } = await import('./createQuoteLineFromConfiguredProduct');
  
  if (import.meta.env.DEV) {
    console.warn('[commitConfiguredProductToQuoteLine] Using FALLBACK (legacy) method');
  }

  // First, get the ConfiguredProduct to extract necessary data
  const { data: configuredProduct, error: cpError } = await supabase
    .from('ConfiguredProducts')
    .select('*')
    .eq('id', params.configured_product_id)
    .eq('organization_id', params.organization_id)
    .single();

  if (cpError || !configuredProduct) {
    throw new Error(`ConfiguredProduct ${params.configured_product_id} not found`);
  }

  // Call legacy function
  const result = await createQuoteLineFromConfiguredProduct({
    quoteId: params.quote_id,
    organizationId: params.organization_id,
    dealerId: params.dealer_id || undefined,
    configuredProductId: params.configured_product_id,
    bom_template_id: configuredProduct.bom_template_id,
    product_type_id: configuredProduct.product_type_id,
    catalog_item_id: configuredProduct.roll_catalog_item_id,
    width_m: configuredProduct.width_mm ? configuredProduct.width_mm / 1000 : undefined,
    height_m: configuredProduct.height_mm ? configuredProduct.height_mm / 1000 : undefined,
    quantity: configuredProduct.quantity || 1,
    hardware_color: configuredProduct.hardware_color,
    drive_type: configuredProduct.operating_type ?? (configuredProduct.config_snapshot as any)?.operating_type ?? (configuredProduct.config_snapshot as any)?.drive_type ?? (configuredProduct.config_snapshot as any)?.operation_type,
    position: params.position || undefined,
    area: params.area || undefined,
    roll_cost_snapshot: configuredProduct.roll_total_cost || 0,
    bom_cost_snapshot: configuredProduct.bom_total_cost || 0,
    roll_msrp_snapshot: configuredProduct.roll_msrp_total || 0,
    bom_msrp_snapshot: configuredProduct.bom_total || 0,
    total_cost: (configuredProduct.roll_total_cost || 0) + (configuredProduct.bom_total_cost || 0),
    msrp: configuredProduct.total_msrp || 0,
  });

  return {
    quote_line_id: result.quoteLineId,
    bom_instance_id: null,
  };
}

/**
 * Main entry point that tries RPC first, then falls back to legacy if needed.
 */
export async function commitConfiguredProduct(
  params: CommitConfiguredProductParams
): Promise<CommitConfiguredProductResult> {
  try {
    // Try the official RPC first
    return await commitConfiguredProductToQuoteLine(params);
  } catch (err: any) {
    // If RPC doesn't exist (function not found), use fallback
    const msg = err.message?.toLowerCase() || '';
    const isUuidCastError = msg.includes('invalid input syntax for type uuid');
    if (msg.includes('function') && (msg.includes('does not exist') || msg.includes('not found'))) {
      console.warn('[commitConfiguredProduct] RPC not found, using fallback:', err.message);
      return await commitConfiguredProductToQuoteLineFallback(params);
    }
    if (isUuidCastError) {
      console.warn('[commitConfiguredProduct] RPC failed due to UUID cast, using fallback:', err.message);
      return await commitConfiguredProductToQuoteLineFallback(params);
    }
    // Otherwise, re-throw the error
    throw err;
  }
}
