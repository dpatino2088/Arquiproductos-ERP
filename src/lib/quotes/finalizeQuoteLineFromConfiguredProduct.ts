/**
 * @deprecated DEPRECATED - Use commitConfiguredProductToQuoteLine instead
 * 
 * This file is kept for backward compatibility but should NOT be used.
 * The new flow uses commit_configured_product_to_quote_line RPC.
 */

import { supabase } from '../supabase/client';
import { recalculateConfiguredProductTotals, getConfiguredProduct } from '../bom/createConfiguredProductPreview';

export interface FinalizeQuoteLineFromConfiguredProductParams {
  organizationId: string;
  quoteLineId: string;
  configuredProductId: string;
  quantity?: number;
  discountPct?: number;
  bom_template_id?: string | null;
  product_type_id?: string | null;
  [key: string]: any;
}

export interface FinalizeQuoteLineFromConfiguredProductResult {
  quoteLineId: string;
  bomInstanceId: string | null;
  rollCostSnapshot: number;
  bomCostSnapshot: number;
  rollMsrpSnapshot: number;
  bomMsrpSnapshot: number;
  msrp: number;
  totalCost: number;
  netPrice: number;
}

export async function finalizeQuoteLineFromConfiguredProduct(
  params: FinalizeQuoteLineFromConfiguredProductParams
): Promise<FinalizeQuoteLineFromConfiguredProductResult> {
  const {
    organizationId,
    quoteLineId,
    configuredProductId,
    quantity = 1,
    discountPct = 0,
    bom_template_id,
    product_type_id,
    ...otherFields
  } = params;

  if (!organizationId) throw new Error('organizationId is required');
  if (!quoteLineId) throw new Error('quoteLineId is required');
  if (!configuredProductId) throw new Error('configuredProductId is required');

  await recalculateConfiguredProductTotals(configuredProductId);
  const configuredProduct = await getConfiguredProduct(configuredProductId);
  if (!configuredProduct) {
    throw new Error(`ConfiguredProduct ${configuredProductId} not found`);
  }

  const rollMsrpSnapshot = Number(configuredProduct.roll_msrp_total) || 0;
  const bomMsrpSnapshot = Number(configuredProduct.bom_total) || 0;
  const msrp = Number(configuredProduct.roll_plus_bom_total) || 0;
  const rollCostSnapshot = Number(configuredProduct.roll_total_cost) || 0;
  const bomCostSnapshot = Number(configuredProduct.bom_total_cost) || 0;
  const totalCost = rollCostSnapshot + bomCostSnapshot;
  const laborPctSnapshot = configuredProduct?.labor_pct ? Number(configuredProduct.labor_pct) : null;

  const netPrice = msrp * (1 - (discountPct / 100));

  const { metadata: _, ...filteredOtherFields } = otherFields;

  const updatePayload: any = {
    quantity,
    roll_cost_snapshot: rollCostSnapshot,
    bom_cost_snapshot: bomCostSnapshot,
    roll_msrp_snapshot: rollMsrpSnapshot,
    bom_msrp_snapshot: bomMsrpSnapshot,
    total_cost: totalCost,
    msrp,
    net_price: netPrice,
    pricing_locked: false,
    last_priced_at: new Date().toISOString(),
    ...(laborPctSnapshot !== null && { labor_pct: laborPctSnapshot }),
    ...(bom_template_id ? { bom_template_id } : {}),
    ...(product_type_id ? { product_type_id } : {}),
    configured_product_id: configuredProductId,
    ...filteredOtherFields,
  };

  const { error: updateError } = await supabase
    .from('QuoteLines')
    .update(updatePayload)
    .eq('id', quoteLineId)
    .eq('organization_id', organizationId);

  if (updateError) {
    throw new Error(updateError.message || 'Failed to update QuoteLine');
  }

  let bomInstanceId: string | null = null;
  if (bom_template_id) {
    const { data: bomInstanceData, error: bomError } = await supabase.rpc(
      'create_bom_instance_for_configured_product',
      {
        p_org_id: organizationId,
        p_quote_line_id: quoteLineId,
        p_configured_product_id: configuredProductId,
        p_product_type_id: product_type_id || configuredProduct.product_type_id || null,
      }
    );

    if (bomError) {
      throw new Error(bomError.message || 'Failed to create BOMInstance');
    }
    bomInstanceId = bomInstanceData || null;
  }

  await recalculateConfiguredProductTotals(configuredProductId);
  const updatedConfiguredProduct = await getConfiguredProduct(configuredProductId);
  if (updatedConfiguredProduct) {
    const finalPricing = {
      rollMsrp: Number(updatedConfiguredProduct.roll_msrp_total) || 0,
      bomMsrp: Number(updatedConfiguredProduct.bom_total) || 0,
      totalMsrp: Number(updatedConfiguredProduct.total_msrp) || Number(updatedConfiguredProduct.roll_plus_bom_total) || 0,
      rollCost: Number(updatedConfiguredProduct.roll_total_cost) || 0,
      bomCost: Number(updatedConfiguredProduct.bom_total_cost) || 0,
      totalCost: Number(updatedConfiguredProduct.roll_total_cost || 0) + Number(updatedConfiguredProduct.bom_total_cost || 0),
    };

    await supabase
      .from('QuoteLines')
      .update({
        roll_msrp_snapshot: finalPricing.rollMsrp,
        bom_msrp_snapshot: finalPricing.bomMsrp,
        msrp: finalPricing.totalMsrp,
        roll_cost_snapshot: finalPricing.rollCost,
        bom_cost_snapshot: finalPricing.bomCost,
        total_cost: finalPricing.totalCost,
        pricing_locked: true,
        last_priced_at: new Date().toISOString(),
      })
      .eq('id', quoteLineId)
      .eq('organization_id', organizationId);
  }

  return {
    quoteLineId,
    bomInstanceId,
    rollCostSnapshot,
    bomCostSnapshot,
    rollMsrpSnapshot,
    bomMsrpSnapshot,
    msrp,
    totalCost,
    netPrice,
  };
}
