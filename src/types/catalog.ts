/**
 * Catalog and Quotes module types
 */

// ENUM types matching PostgreSQL ENUMs
export type MeasureBasis =
  | 'unit'
  | 'linear_m'
  | 'area'
  | 'fabric';

export type FabricPricingMode = 
  | 'per_linear_m'
  | 'per_sqm';

export type CatalogItemType =
  | 'component'
  | 'fabric'
  | 'linear'
  | 'service'
  | 'accessory';

export type QuoteStatus = 
  | 'draft'
  | 'sent'
  | 'approved'
  | 'rejected'
  | 'cancelled';

// CatalogItems interface
// Based on actual database schema
export interface CatalogItem {
  id: string;
  organization_id: string;
  sku: string;
  name: string; // Mapped from item_name for compatibility
  item_name?: string | null;  // Actual column from database
  description?: string | null;
  manufacturer_id?: string | null; // Actual column
  item_category_id?: string | null; // Actual column
  item_type: CatalogItemType;
  measure_basis: MeasureBasis;
  uom: string;
  is_fabric: boolean;
  roll_width_m?: number | null;
  fabric_pricing_mode?: FabricPricingMode | null;
  // Pricing fields
  cost_exw?: number | null; // Base cost (EXW = Ex Works) - actual column name
  default_margin_pct?: number | null; // Default margin percentage for MSRP calculation
  msrp?: number | null; // Manufacturer's Suggested Retail Price
  // Legacy pricing fields (for backward compatibility)
  cost_price: number; // Mapped from cost_exw
  unit_price: number; // Default 0 (doesn't exist in table)
  active: boolean;
  discontinued: boolean;
  collection_id?: string | null; // Deprecated - kept for compatibility, use collection_name instead
  collection_name?: string | null; // Text field - collection name stored directly (no FK)
  variant_id?: string | null; // UUID - may exist in some records
  variant_name?: string | null;  // Text field for variant (actual column)
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  metadata: Record<string, any>; // Default empty (doesn't exist in table)
  created_by?: string | null; // Default null (doesn't exist in table)
  updated_by?: string | null; // Default null (doesn't exist in table)
}

// CatalogItem with collection relation (for queries with JOIN)
export interface CatalogItemWithCollection extends CatalogItem {
  collection?: {
    id: string;
    name: string;
    code?: string | null;
    description?: string | null;
  } | null;
}

// CollectionsCatalog interface (replaces CatalogVariants)
export interface CollectionsCatalog {
  id: string;
  organization_id: string;
  catalog_item_id: string; // FK to CatalogItems (source of truth)
  fabric_id: string; // FK to CatalogItems where is_fabric=true
  sku: string; // Denormalized from CatalogItem
  name: string; // Denormalized from CatalogItem
  description?: string | null; // Denormalized from CatalogItem
  collection: string; // Collection name/grouping
  variant: string; // Variant/color name (replaces color_name)
  roll_width?: number | null;
  roll_length?: number | null;
  roll_uom?: string | null; // "m" or "yd"
  grammage_gsm?: number | null;
  openness_pct?: number | null;
  material?: string | null;
  cost_value?: number | null; // Denormalized from CatalogItem.cost_price
  cost_uom?: string | null; // "m" or "yd"
  active: boolean;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// CollectionsCatalog with related CatalogItem
export interface CollectionsCatalogWithItem extends CollectionsCatalog {
  catalog_item?: CatalogItem;
  fabric_item?: CatalogItem;
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
    discount_total: number;
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
  // Configuration fields
  area?: string | null;
  position?: string | null;
  collection_id?: string | null; // Deprecated - kept for compatibility, use collection_name instead
  collection_name?: string | null; // Text field - collection name stored directly (no FK)
  variant_id?: string | null;
  operating_system_drive_id?: string | null; // FK to CatalogItems for operating system drives
  product_type?: string | null;
  operating_system?: string | null;
  operating_system_manufacturer?: string | null;
  installation_type?: string | null;
  installation_location?: string | null;
  fabric_drop?: string | null;
  // Snapshots (captured at time of quote creation)
  measure_basis_snapshot: MeasureBasis;
  roll_width_m_snapshot?: number | null;
  fabric_pricing_mode_snapshot?: FabricPricingMode | null;
  // Computed values
  computed_qty: number;
  // Price snapshots
  unit_price_snapshot: number;
  unit_cost_snapshot: number;
  // Margin information (for price calculation)
  margin_percentage_used?: number | null; // Actual margin percentage used
  margin_source?: 'category' | 'item' | 'default' | null; // Source of margin
  // Discount information (for customer pricing tiers)
  discount_percentage?: number | null; // Discount percentage applied
  discount_amount?: number | null; // Discount amount (unit_price * discount_percentage / 100)
  discount_source?: 'customer_type' | 'manual_customer' | 'manual_line' | null; // Source of discount
  final_unit_price?: number | null; // Final unit price after discount (unit_price - discount_amount)
  // Line total
  line_total: number;
  // Metadata for additional data (e.g., panel information for multi-panel configurations)
  metadata?: Record<string, any> | null;
  // Audit fields
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

// BOM Components interface
export interface BOMComponent {
  id: string;
  organization_id: string;
  parent_item_id: string;
  component_item_id: string;
  qty_per_unit: number;
  uom: string;
  is_required: boolean;
  sequence_order: number;
  metadata: Record<string, any>;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// Extended BOMComponent with component item details
export interface BOMComponentWithItem extends BOMComponent {
  component_item?: {
    id: string;
    sku: string;
    name: string;
    item_type: CatalogItemType;
    unit_price: number;
    cost_price: number;
    uom: string;
  };
}

// ProductType interface (from Profiles table)
export interface ProductType {
  id: string;
  organization_id: string;
  code: string;
  name: string;
  sort_order?: number | null;
  deleted: boolean;
  created_at: string;
  updated_at?: string | null;
}

// BOMTemplate interface
export interface BOMTemplate {
  id: string;
  organization_id: string;
  product_type_id: string;
  name?: string | null;
  description?: string | null;
  active: boolean;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  // Joined data
  product_type?: ProductType;
}

// Extended BOMComponent to support BOMTemplates
export interface BOMComponentWithTemplate extends Omit<BOMComponent, 'parent_item_id'> {
  bom_template_id: string;
  // Joined data
  component_item?: CatalogItem;
  category?: {
    id: string;
    name: string;
    code: string;
  };
}

