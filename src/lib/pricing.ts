/**
 * Pricing calculation utilities
 * 
 * This module provides shared functions for pricing calculations using
 * margin-on-sale methodology (NOT markup).
 * 
 * Key formulas:
 * - total_unit_cost = cost_exw + labor_cost + logistics_cost
 * - msrp = total_unit_cost / (1 - margin_pct / 100)
 * 
 * Margin percentage represents % of final sale price, not % over cost.
 */

import { CostSettings } from '../types/pricing';

/**
 * Calculate total unit cost from catalog item
 * Includes: cost_exw + labor_cost + logistics_cost
 */
export function computeTotalUnitCost(item: {
  cost_exw?: number | null;
  labor_cost_per_unit?: number | null;
  shipping_cost_per_unit?: number | null;
  freight_cost?: number | null;
  handling_cost?: number | null;
  import_tax_pct?: number | null;
}): number {
  const costExw = item.cost_exw || 0;
  const laborCost = item.labor_cost_per_unit || 0;
  
  // Logistics costs
  const shippingCost = item.shipping_cost_per_unit || 0;
  const freightCost = item.freight_cost || 0;
  const handlingCost = item.handling_cost || 0;
  const importTax = costExw * ((item.import_tax_pct || 0) / 100);
  
  const logisticsCost = shippingCost + freightCost + handlingCost + importTax;
  
  return costExw + laborCost + logisticsCost;
}

/**
 * Calculate MSRP from total cost and margin percentage (margin-on-sale)
 * 
 * Formula: msrp = total_cost / (1 - margin_pct / 100)
 * 
 * @param totalCost - Total unit cost (cost_exw + labor + logistics)
 * @param marginPct - Margin percentage (0-100), represents % of sale price
 * @returns Calculated MSRP
 */
export function computeMsrpFromMarginOnSale(
  totalCost: number,
  marginPct: number
): number {
  if (totalCost <= 0) return 0;
  if (marginPct >= 100) {
    console.warn('Margin percentage >= 100%, returning total cost');
    return totalCost;
  }
  if (marginPct < 0) {
    console.warn('Margin percentage < 0%, using 0%');
    return totalCost;
  }
  
  // Clamp margin to safe range [0, 95]
  const safeMargin = Math.max(0, Math.min(95, marginPct));
  
  // Margin-on-sale formula: msrp = cost / (1 - margin/100)
  const msrp = totalCost / (1 - safeMargin / 100);
  
  return Number(msrp.toFixed(2));
}

/**
 * Resolve margin percentage with priority:
 * 1. Category margin (if provided)
 * 2. Item margin (if provided)
 * 3. Fallback default (default: 35%)
 * 
 * @param itemMargin - Margin from catalog item
 * @param categoryMargin - Margin from category settings
 * @param fallback - Default margin if none provided (default: 35)
 * @returns Resolved margin percentage
 */
export function resolveMarginPct(
  itemMargin: number | null | undefined,
  categoryMargin: number | null | undefined,
  fallback: number = 35
): number {
  // Priority: Category > Item > Fallback
  if (categoryMargin !== null && categoryMargin !== undefined) {
    return Math.max(0, Math.min(95, categoryMargin));
  }
  if (itemMargin !== null && itemMargin !== undefined) {
    return Math.max(0, Math.min(95, itemMargin));
  }
  return Math.max(0, Math.min(95, fallback));
}

/**
 * Get discount percentage from DealerTier (Platinum/Gold/Silver/Bronze).
 * Single source of truth: DealerTiers table.
 *
 * @param dealerTierId - Dealer tier id (from Dealer.dealer_tier_id)
 * @param tiers - List of DealerTiers (e.g. from useDealerTiers)
 * @returns Discount percentage 0-100; 35 (Bronze default) if tierId is null or not found
 */
export function getDealerTierDiscountPct(
  dealerTierId: string | null,
  tiers: { id: string; discount_pct: number }[]
): number {
  if (!dealerTierId) return 35; // Default: Bronze
  const tier = tiers.find((t) => t.id === dealerTierId);
  if (!tier) return 35;
  const pct = Number(tier.discount_pct);
  return Number.isFinite(pct) ? Math.max(0, Math.min(100, pct)) : 35;
}

/**
 * Calculate quote line unit price using MSRP tier pricing with margin guardrail
 *
 * Discount comes from DealerTiers (dealer's tier). CostSettings only used for min_margin_pct.
 *
 * @param catalogItem - Catalog item with pricing fields
 * @param discountPct - Discount percentage 0-100 (from DealerTiers via getDealerTierDiscountPct)
 * @param costSettings - CostSettings for min_margin_pct (guardrail)
 * @param categoryMargin - Optional category margin for guardrail calculation
 */
export function calculateQuoteLinePrice(
  catalogItem: {
    msrp?: number | null;
    cost_exw?: number | null;
    labor_cost_per_unit?: number | null;
    shipping_cost_per_unit?: number | null;
    freight_cost?: number | null;
    handling_cost?: number | null;
    import_tax_pct?: number | null;
    default_margin_pct?: number | null;
  },
  discountPct: number,
  costSettings: CostSettings | null,
  categoryMargin?: number | null
): {
  unitPrice: number;
  basePrice: number;
  discountPct: number;
  priceFromTier: number;
  totalUnitCost: number;
  minMarginPct: number;
  minPriceAllowed: number;
  priceBasis: 'MSRP_TIER' | 'MARGIN_FLOOR';
} {
  const safeDiscountPct = Number.isFinite(discountPct) ? Math.max(0, Math.min(100, discountPct)) : 35;

  // 1. MSRP lista (END USER price)
  const listPrice = catalogItem.msrp || 0;
  if (listPrice <= 0) {
    return {
      unitPrice: 0,
      basePrice: 0,
      discountPct: 0,
      priceFromTier: 0,
      totalUnitCost: 0,
      minMarginPct: 35,
      minPriceAllowed: 0,
      priceBasis: 'MSRP_TIER',
    };
  }
  
  // 2. Use discount from DealerTiers (passed in)
  
  // 3. Precio con descuento por tier (CRÍTICO: aplicar descuento aquí)
  const priceFromTier = safeDiscountPct > 0
    ? listPrice * (1 - safeDiscountPct / 100)
    : listPrice;
  
  // 4. Calculate total unit cost (for margin guardrail)
  const totalUnitCost = computeTotalUnitCost(catalogItem);
  
  // 5. Get minimum margin (guardrail). BD stores 0-1 (e.g. 0.35); we need 0-100 for formula.
  const minMarginPct = costSettings?.minimum_margin_pct != null
    ? costSettings.minimum_margin_pct * 100
    : 35;
  
  // 6. Calculate minimum price allowed (margin-on-sale floor)
  const minPriceAllowed = totalUnitCost > 0 
    ? computeMsrpFromMarginOnSale(totalUnitCost, minMarginPct)
    : 0;
  
  // 7. Precio neto FINAL: max of tier price (con descuento) and guardrail
  // CRÍTICO: Este es el precio que el distribuidor paga
  const finalUnitPrice = Math.max(priceFromTier, minPriceAllowed);
  
  // 8. Determine price basis
  const priceBasis: 'MSRP_TIER' | 'MARGIN_FLOOR' =
    minPriceAllowed > priceFromTier
      ? 'MARGIN_FLOOR'
      : 'MSRP_TIER';
  
  return {
    unitPrice: Number(finalUnitPrice.toFixed(2)),
    basePrice: Number(listPrice.toFixed(2)),
    discountPct: safeDiscountPct,
    priceFromTier: Number(priceFromTier.toFixed(2)),
    totalUnitCost: Number(totalUnitCost.toFixed(2)),
    minMarginPct,
    minPriceAllowed: Number(minPriceAllowed.toFixed(2)),
    priceBasis,
  };
}
