/**
 * Pricing module types
 */

export interface PricingConfiguration {
  id: string;
  organization_id: string;
  catalog_item_id?: string | null;
  item_category_id?: string | null;
  
  // Base pricing
  cost_exw: number;
  default_margin_pct: number;
  msrp?: number | null;
  
  // Labor costs
  labor_cost_per_unit?: number | null;
  labor_cost_per_hour?: number | null;
  labor_hours_per_unit?: number | null;
  
  // Shipping costs
  shipping_cost_base?: number | null;
  shipping_cost_per_kg?: number | null;
  shipping_cost_per_unit?: number | null;
  shipping_cost_percentage?: number | null;
  
  // Additional costs
  import_tax_pct?: number | null;
  freight_cost?: number | null;
  handling_cost?: number | null;
  
  // Discount tiers
  tier_retail_discount_pct?: number | null;
  tier_standard_discount_pct?: number | null;
  tier_preferred_discount_pct?: number | null;
  tier_vip_discount_pct?: number | null;
  tier_wholesale_discount_pct?: number | null;
  
  // Metadata
  notes?: string | null;
  effective_from?: string | null;
  effective_to?: string | null;
  active: boolean;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

export interface PricingCalculation {
  // Base costs
  cost_exw: number;
  labor_cost: number;
  shipping_cost: number;
  freight_cost: number;
  handling_cost: number;
  import_tax: number;
  
  // Subtotal
  total_cost: number;
  
  // Margin
  margin_pct: number;
  margin_amount: number;
  
  // MSRP
  msrp: number;
  
  // Discount
  discount_tier: string;
  discount_pct: number;
  discount_amount: number;
  
  // Final price
  final_price: number;
}

export type PricingTier = 
  | 'retail'
  | 'standard'
  | 'preferred'
  | 'vip'
  | 'wholesale';

// ====================================================
// Cost Engine v1 Types
// ====================================================

// CostSettings: columnas según dump V9 (sin id, sin currency_code, sin deleted; sin tiers Partner/VIP)
export interface CostSettings {
  organization_id: string;
  labor_pct: number;            // 0-1 (e.g. 0.10 = 10%)
  shipping_pct: number;         // 0-1 (e.g. 0.15 = 15%)
  global_import_tax_pct: number; // 0-1
  minimum_margin_pct: number;   // Pricing floor margin-on-sale (0-1). Default 0.35
  default_msrp_pct: number; // 0-1 (e.g. 0.65 = 65%). Default MSRP %
  import_tax_pct?: number;     // Generated column = global_import_tax_pct
  is_active?: boolean;
  created_at?: string;
  updated_at?: string | null;
}

// QuoteLineCosts interface (Cost breakdown per quote line)
export interface QuoteLineCosts {
  id: string;
  organization_id: string;
  quote_id: string;
  quote_line_id: string;
  currency_code: string;
  // Base cost components
  base_material_cost: number;
  labor_cost: number;
  labor_source: 'auto' | 'manual'; // Cost Engine v1: source of labor_cost
  shipping_cost: number;
  shipping_source: 'auto' | 'manual'; // Cost Engine v1: source of shipping_cost
  import_tax_cost: number;
  import_tax_source: 'auto' | 'manual'; // Cost Engine v1: source of import_tax_cost
  handling_cost: number;
  additional_cost: number;
  // Total
  total_cost: number;
  // Overrides
  is_overridden: boolean;
  override_reason?: string | null;
  override_base_material_cost?: number | null;
  override_labor_cost?: number | null;
  override_shipping_cost?: number | null;
  override_import_tax_cost?: number | null;
  override_handling_cost?: number | null;
  override_additional_cost?: number | null;
  // Audit fields
  calculated_at: string;
  created_at: string;
  updated_at?: string | null;
  deleted: boolean;
  archived: boolean;
}

// Extended QuoteLineCosts with related QuoteLine
export interface QuoteLineCostsWithLine extends QuoteLineCosts {
  quote_line?: {
    id: string;
    qty: number;
    computed_qty: number;
    catalog_item_id: string;
  };
}

// ====================================================
// Import Tax Breakdown Types
// ====================================================

export interface QuoteLineImportTaxBreakdown {
  id: string;
  organization_id: string;
  quote_line_id: string;
  category_id?: string | null;
  category_name?: string | null;
  extended_cost: number;
  import_tax_percentage: number;
  import_tax_amount: number;
  created_at: string;
  updated_at?: string | null;
  deleted: boolean;
  archived: boolean;
}

// ====================================================
// QuoteLineComponents Types
// ====================================================

export interface QuoteLineComponent {
  id: string;
  organization_id: string;
  quote_line_id: string;
  catalog_item_id: string;
  qty: number;
  unit_cost_exw?: number | null;
  created_at: string;
  updated_at?: string | null;
  deleted: boolean;
  archived: boolean;
}

// ====================================================
// ImportTaxRules Types
// ====================================================

export interface ImportTaxRule {
  id: string;
  organization_id: string;
  category_id: string;
  import_tax_pct: number; // DB column name
  // Legacy/alternative names
  import_tax_percentage?: number;
  default_value_percentage?: number | null;
  is_using_default?: boolean;
  // Audit fields
  created_at: string;
  updated_at?: string | null;
  is_active?: boolean;
  active?: boolean;
  deleted?: boolean;
  archived?: boolean;
}

// ====================================================
// CategoryMargins Types
// ====================================================

export interface CategoryMargin {
  id: string;
  organization_id: string;
  category_id: string;
  minimum_margin_pct: number; // Minimum margin (sale-in / dealer price)
  msrp_pct: number; // MSRP % (margin-on-sale for public price)
  margin_percentage?: number;
  default_value_percentage?: number | null;
  is_using_default?: boolean;
  created_at: string;
  updated_at?: string | null;
  is_active?: boolean;
  active?: boolean;
  deleted?: boolean;
  archived?: boolean;
}

