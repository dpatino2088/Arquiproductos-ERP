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
 * Get customer type discount percentage from CostSettings
 * 
 * Maps customer_type_name to corresponding discount field in CostSettings
 * 
 * @param customerType - Customer type: 'VIP' | 'Partner' | 'Reseller' | 'Distributor'
 * @param costSettings - CostSettings object with discount fields
 * @returns Discount percentage (0-100)
 */
export function getCustomerTypeDiscount(
  customerType: string,
  costSettings: CostSettings | null
): number {
  if (!costSettings) return 0;
  
  switch (customerType) {
    case 'Distributor':
      return costSettings.discount_distributor_pct || 0;
    case 'Reseller':
      return costSettings.discount_reseller_pct || 0;
    case 'Partner':
      return costSettings.discount_partner_pct || 0;
    case 'VIP':
      return costSettings.discount_vip_pct || 0;
    default:
      return 0;
  }
}

/**
 * Calculate quote line unit price using MSRP tier pricing with margin guardrail
 * 
 * Logic:
 * 1. Start from catalog item MSRP (public price)
 * 2. Apply customer type discount
 * 3. Apply margin guardrail (margin-on-sale as floor)
 * 4. Return the maximum of (tier_price, min_price_allowed)
 * 
 * @param catalogItem - Catalog item with pricing fields
 * @param customerType - Customer type for discount lookup
 * @param costSettings - CostSettings with discounts and min_margin_pct
 * @param categoryMargin - Optional category margin for guardrail calculation
 * @returns Object with calculated price and metadata
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
  customerType: string,
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
  // 1. MSRP lista (END USER price)
  const listPrice = catalogItem.msrp || 0;
  if (listPrice <= 0) {
    // If no MSRP, return 0 (should not happen due to validation in QuoteNew)
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
  
  // 2. Get discount for customer type
  const discountPct = getCustomerTypeDiscount(customerType, costSettings);
  
  // 3. Precio con descuento por tier (CRÍTICO: aplicar descuento aquí)
  const priceFromTier = discountPct > 0
    ? listPrice * (1 - discountPct / 100)
    : listPrice;
  
  // 4. Calculate total unit cost (for margin guardrail)
  const totalUnitCost = computeTotalUnitCost(catalogItem);
  
  // 5. Get minimum margin (guardrail)
  const minMarginPct = costSettings?.min_margin_pct || 35;
  
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
    unitPrice: Number(finalUnitPrice.toFixed(2)), // CRÍTICO: retornar finalUnitPrice, no listPrice
    basePrice: Number(listPrice.toFixed(2)),
    discountPct,
    priceFromTier: Number(priceFromTier.toFixed(2)),
    totalUnitCost: Number(totalUnitCost.toFixed(2)),
    minMarginPct,
    minPriceAllowed: Number(minPriceAllowed.toFixed(2)),
    priceBasis,
  };
}
