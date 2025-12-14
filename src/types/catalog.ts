/**
 * Catalog and Quotes module types
 */

// ENUM types matching PostgreSQL ENUMs
export type MeasureBasis = 
  | 'unit'
  | 'width_linear'
  | 'height_linear'
  | 'area'
  | 'fabric';

export type FabricPricingMode = 
  | 'per_linear_m'
  | 'per_sqm';

export type QuoteStatus = 
  | 'draft'
  | 'sent'
  | 'approved'
  | 'rejected'
  | 'cancelled';

// CatalogItems interface
export interface CatalogItem {
  id: string;
  organization_id: string;
  sku: string;
  name: string;
  description?: string | null;
  measure_basis: MeasureBasis;
  uom: string;
  is_fabric: boolean;
  roll_width_m?: number | null;
  fabric_pricing_mode?: FabricPricingMode | null;
  unit_price: number;
  cost_price: number;
  active: boolean;
  discontinued: boolean;
  metadata: Record<string, any>;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// Quotes interface
export interface Quote {
  id: string;
  organization_id: string;
  customer_id: string;
  quote_no: string;
  status: QuoteStatus;
  currency: string;
  totals: {
    subtotal: number;
    tax: number;
    total: number;
  };
  notes?: string | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// QuoteLines interface
export interface QuoteLine {
  id: string;
  organization_id: string;
  quote_id: string;
  catalog_item_id: string;
  qty: number;
  width_m?: number | null;
  height_m?: number | null;
  measure_basis_snapshot: MeasureBasis;
  roll_width_m_snapshot?: number | null;
  fabric_pricing_mode_snapshot?: FabricPricingMode | null;
  computed_qty: number;
  unit_price_snapshot: number;
  unit_cost_snapshot: number;
  line_total: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// Extended interfaces with relations (for queries with joins)
export interface QuoteWithCustomer extends Quote {
  customer?: {
    id: string;
    customer_name: string;
  };
}

export interface QuoteLineWithItem extends QuoteLine {
  catalog_item?: {
    id: string;
    sku: string;
    name: string;
  };
}

