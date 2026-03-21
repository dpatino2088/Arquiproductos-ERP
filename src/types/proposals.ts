/**
 * Types for Proposals and ProposalLines (customer-facing).
 * Matches public."Proposals" and public."ProposalLines" (V2 schema).
 */

export type ProposalStatus = 'draft' | 'sent' | 'accepted' | 'rejected' | 'cancelled';
export type ProposalLineType = 'from_quote' | 'custom';
export type ProposalOverrideMode =
  | 'inherit'
  | 'discount_pct'
  | 'markup_pct'
  | 'fixed_unit_price'
  | 'fixed_line_total';
/** DB enum: use only these. Standardized on "delivery" (not "transportation"). */
export const PROPOSAL_CUSTOM_CATEGORIES = ['installation', 'delivery', 'service', 'other'] as const;
export type ProposalCustomCategory = (typeof PROPOSAL_CUSTOM_CATEGORIES)[number];

export interface Proposal {
  id: string;
  organization_id: string;
  dealer_id: string;
  quote_id: string;
  customer_id: string | null;
  contact_id: string | null;
  status: ProposalStatus;
  proposal_no: string | null;
  version_no: number;
  currency: string | null;
  valid_until: string | null;
  /** Short proposal description (header). */
  description: string | null;
  /** Notes / Terms and Conditions. */
  notes: string | null;
  /** Snapshot: terms title (for PDF). */
  terms_title?: string | null;
  /** Snapshot: terms content (for PDF). */
  terms_content?: string | null;
  /** Snapshot: source template id. */
  terms_source_template_id?: string | null;
  global_discount_pct: number | null;
  global_fee_amount: number | null;
  /** Discount % applied to installation addons total (e.g. 15 = 15%). */
  global_installation_discount_pct?: number | null;
  /** Fee/surcharge % applied to installation addons total (e.g. 5 = 5%). */
  global_installation_fee_pct?: number | null;
  subtotal_amount: number | null;
  installation_amount?: number | null;
  discount_amount: number | null;
  tax_amount: number | null;
  tax_pct?: number | null;
  exempt_tax?: boolean;
  total_amount: number | null;
  sent_at: string | null;
  snapshot_version?: number;
  created_by_user_id: string | null;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProposalLine {
  id: string;
  organization_id: string;
  dealer_id: string;
  proposal_id: string;
  line_type: ProposalLineType;
  quote_line_id: string | null;
  override_mode: ProposalOverrideMode;
  discount_pct: number | null;
  markup_pct: number | null;
  fixed_unit_price: number | null;
  fixed_line_total: number | null;
  custom_category: ProposalCustomCategory | null;
  area?: string | null;
  position?: string | null;
  description: string | null;
  qty: number | null;
  uom: string | null;
  unit_price: number | null;
  unit_cost?: number | null;
  line_total: number | null;
  line_adjustment_pct: number | null;
  sort_order: number;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  /** Snapshot of QuoteLine + ConfiguredProduct when proposal marked sent. Used by print when present. */
  quote_line_snapshot?: QuoteLineSnapshot | null;
}

/** Snapshot captured when proposal status changes to sent */
export interface QuoteLineSnapshot {
  name?: string | null;
  sku?: string | null;
  qty?: number;
  width_m?: number | null;
  height_m?: number | null;
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  /** Drive system brand/type label (e.g. "Manual Vertilux", "Motorize Lutron") */
  drive_system_label?: string | null;
  measurements?: Record<string, unknown> | null;
  accessories?: unknown;
  base_price_mode?: 'msrp' | 'unit_msrp';
  base_unit_msrp?: number | null;
  base_line_msrp?: number | null;
  captured_at?: string | null;
}

/** Add-on per ProposalLine (e.g. installation, delivery). Stored in ProposalLineAddOns. */
export type ProposalLineAddOnType = 'installation' | 'delivery' | 'measurement' | 'other';
export type ProposalLineAddOnPricingMode = 'markup_pct' | 'fixed_price';

export interface ProposalLineAddOn {
  id: string;
  organization_id: string;
  dealer_id: string;
  proposal_id: string;
  proposal_line_id: string;
  addon_type: ProposalLineAddOnType;
  cost_amount: number;
  pricing_mode: ProposalLineAddOnPricingMode;
  markup_pct: number | null;
  sale_amount: number;
  taxable: boolean;
  sort_order: number;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

/** QuoteLine fields needed for proposal line display and base amount */
export interface QuoteLineForProposal {
  id: string;
  quote_id: string;
  quantity: number;
  name: string | null;
  sku: string | null;
  msrp: number | null;
  unit_msrp: number | null;
  width_m: number | null;
  height_m: number | null;
}
