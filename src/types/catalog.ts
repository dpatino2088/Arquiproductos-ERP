/**
 * Catalog and Quotes module types
 */

// ENUM types matching PostgreSQL ENUMs - NEW SCHEMA
export type MeasureBasis =
  | 'unit'
  | 'linear'  // NEW: 'linear' (not 'linear_m')
  | 'area';

export type FabricPricingMode = 
  | 'per_linear_m'
  | 'per_sqm';

export type CatalogItemType =
  | 'roll'            // Roll goods (fabrics, films, vinyls) - can have is_fabric
  | 'component'       // Components (pieces, each)
  | 'linear_component'; // Linear components (measured by length, default UOM: 'm')

export type StockBasis = 'ea' | 'linear_m';
export type PurchaseMode = 'unit_packaged' | 'linear_direct' | 'roll';

export type QuoteStatus = 
  | 'draft'
  | 'sent'
  | 'approved'
  | 'rejected'
  | 'cancelled';

// CatalogItems interface
// Based on NEW database schema
export interface CatalogItem {
  id: string;
  organization_id: string;
  sku: string;
  name: string; // NEW SCHEMA: 'name' field (required)
  item_name?: string | null;  // Legacy: kept for backward compatibility
  description?: string | null;
  manufacturer_id?: string | null;
  manufacturer?: string | null; // Denormalized manufacturer name (from Manufacturers or metadata)
  category_id?: string | null; // NEW: FK to CatalogCategories.id
  item_category_id?: string | null; // Legacy: kept for backward compatibility
  measure_basis: MeasureBasis; // Required: 'unit' | 'linear' | 'area'
  unit_of_measure: string; // Required: 'unit_of_measure'
  uom?: string; // Legacy: kept for backward compatibility (mapped from unit_of_measure)
  is_fabric: boolean; // Legacy alias for is_roll — kept for backward compatibility
  is_roll?: boolean; // DB column: determines roll vs component
  // Fields when is_roll=true
  roll_type?: 'fabric' | 'window_film' | 'vinyl' | 'mesh' | 'paper' | 'other' | null; // DB enum: public.roll_type
  collection_name?: string | null; // Only when is_roll=true
  variant_name?: string | null;  // Used ONLY when is_roll=true (stores color/variant label)
  roll_width_value?: number | null; // Real DB field: raw dimension value (e.g. 2.8)
  roll_width_uom?: string | null; // Real DB field: dimension unit (m, yd, ft, in)
  roll_width_m?: number | null; // DB field: normalized to meters (computed by trigger from value+uom)
  roll_length_value?: number | null; // Real DB field: roll length raw value
  roll_length_uom?: string | null; // Real DB field: roll length unit (m, yd, ft, in)
  roll_length_m?: number | null; // DB field: normalized to meters (computed by trigger)
  roll_width?: number | null; // Legacy column (still in DB, not used by app)
  fabric_pricing_mode?: FabricPricingMode | null; // Legacy alias for roll_pricing_mode
  roll_pricing_mode?: string | null; // DB column: per_linear_meter, per_square_meter, per_unit
  // Fields when is_fabric=false
  color?: string | null; // Used ONLY when is_fabric=false
  // ✅ FIX: item_role field for component role identification
  item_role?: string | null; // Component role (e.g., 'bottom_bar', 'bracket', 'drive', 'motor', etc.)
  // Pricing fields
  cost_exw?: number | null; // Base cost (EXW = Ex Works) - numeric
  purchase_mode?: PurchaseMode | null; // v2: how the item is purchased from vendor
  stock_basis?: StockBasis | null; // v2: internal stock basis used by inventory
  purchase_uom?: string | null; // v2: vendor-facing unit used for purchase qty input
  default_margin_pct?: number | null; // Default margin percentage for MSRP calculation
  msrp?: number | null; // Manufacturer's Suggested Retail Price
  // Legacy pricing fields (for backward compatibility)
  cost_price?: number; // Legacy: mapped from cost_exw
  unit_price?: number; // Legacy: default 0
  is_active: boolean; // NEW SCHEMA: 'is_active'
  active?: boolean; // Legacy: kept for backward compatibility
  discontinued: boolean;
  image_url?: string | null; // Image URL from Supabase Storage or external URL
  deleted?: boolean; // Optional for backward compatibility
  archived?: boolean; // Optional for backward compatibility
  created_at: string;
  updated_at?: string | null;
  metadata?: Record<string, any>; // Optional metadata
  created_by?: string | null;
  updated_by?: string | null;
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
  exempt_tax?: boolean;
  notes?: string | null;
  description?: string | null;
  po_number?: string | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

// QuoteLines interface
// Note: QuoteLines uses dealer_id (company_id was renamed in 20260207_rename_company_to_dealer).
export interface QuoteLine {
  id: string;
  organization_id: string;
  quote_id: string;
  dealer_id?: string | null;
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
  // PRICING SNAPSHOTS (Source of Truth - captured at time of quote creation)
  list_unit_price_snapshot?: number | null; // MSRP list price (precio de lista público) - BEFORE discounts
  // Snapshots (captured at time of quote creation)
  measure_basis_snapshot: MeasureBasis;
  roll_width_m_snapshot?: number | null;
  fabric_pricing_mode_snapshot?: FabricPricingMode | null;
  // Computed values
  computed_qty: number;
  // Price snapshots
  unit_price_snapshot: number;
  unit_cost_snapshot: number; // Legacy: cost_exw only (kept for compatibility)
  total_unit_cost_snapshot?: number | null; // NEW: Total unit cost (cost_exw + labor + logistics) at quote line creation
  // Margin information (for price calculation)
  margin_percentage_used?: number | null; // Legacy: Actual margin percentage used (kept for compatibility)
  margin_pct_used?: number | null; // NEW: Actual margin percentage achieved (margin-on-sale) based on unit_price_snapshot and total_unit_cost_snapshot
  margin_source?: 'category' | 'item' | 'default' | null; // Source of margin
  // Discount information (for customer pricing tiers)
  discount_percentage?: number | null; // Legacy: Discount percentage applied (kept for compatibility)
  discount_pct_used?: number | null; // NEW: Discount percentage applied based on customer type at quote line creation
  discount_amount?: number | null; // Discount amount (unit_price * discount_percentage / 100)
  discount_source?: 'customer_type' | 'manual_customer' | 'manual_line' | null; // Source of discount
  customer_type_snapshot?: string | null; // NEW: Customer type (VIP, Partner, Reseller, Distributor) at quote line creation time
  price_basis?: 'MSRP_TIER' | 'MARGIN_FLOOR' | 'MANUAL' | null; // NEW: Source of unit price: MSRP_TIER (from customer tier discount), MARGIN_FLOOR (from minimum margin floor), or MANUAL (manually set)
  final_unit_price?: number | null; // Final unit price after discount (unit_price - discount_amount)
  // Line total and MSRP from backend (no client-side calculation)
  line_total: number;
  /** Unit MSRP (precio unitario). Set by backend; UI only reads. */
  unit_msrp?: number | null;
  /** Line total MSRP (unit_msrp * quantity). Set by backend; UI only reads. */
  msrp?: number | null;
  quantity?: number | null;
  roll_msrp_snapshot?: number | null;
  bom_msrp_snapshot?: number | null;
  configured_product_id?: string | null;
  pricing_locked?: boolean | null;
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
  sort_order: number;
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
  code?: string | null; // Unique template code within organization (e.g., ROLLER_MANUAL_BASIC_WHITE)
  name?: string | null;
  description?: string | null;
  hardware_color?: string | null; // Hardware color (White, Black, Silver, Bronze, etc.) to differentiate templates. NULL means template applies to all colors.
  panel_count_min?: number; // Min number of panels (1-3). Default 1.
  panel_count_max?: number; // Max number of panels (1-3). Default 1.
  system_size?: string | null; // Track/rail profile size (48mm, 60mm, etc.)
  metadata?: Record<string, any> | null; // Template metadata: { drive, cassette, hardware_color, system, notes }
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