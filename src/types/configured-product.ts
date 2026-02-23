/**
 * ConfiguredProduct Types
 * 
 * Types for ConfiguredProducts table and related functions
 */

export interface ConfiguredProduct {
  id: string;
  organization_id: string;
  quote_id?: string | null;
  bom_template_id: string;
  product_type_id: string;
  
  // Roll Configuration (fabric items are rolls)
  roll_catalog_item_id?: string | null;
  roll_sku?: string | null;
  roll_collection_name?: string | null;
  roll_variant_name?: string | null;
  roll_width?: number | null; // Ancho del rollo total en metros (snapshot)
  
  // Measurements
  width_mm?: number | null;
  height_mm?: number | null;
  quantity: number;
  
  // Component Selections
  hardware_color?: string | null;
  bottom_bar_item_id?: string | null;
  bottom_bar_sku?: string | null;
  headbox_item_id?: string | null;
  headbox_sku?: string | null;
  side_channel_item_id?: string | null;
  side_channel_sku?: string | null;
  bottom_channel_item_id?: string | null;
  bottom_channel_sku?: string | null;
  motor_item_id?: string | null;
  motor_sku?: string | null;
  drive_item_id?: string | null;
  drive_sku?: string | null;
  tube_item_id?: string | null;
  tube_sku?: string | null;
  operating_type?: string | null;
  
  // Pricing (calculated). Usar msrp_product_subtotal (roll + bom + accessories); unit_msrp_total = subtotal + labor.
  roll_msrp_total: number;
  bom_total: number;
  msrp_product_subtotal?: number;
  unit_msrp_total?: number;
  labor_pct: number;
  accessories_total: number;
  total_msrp: number;
  
  // Full configuration snapshot
  config_snapshot: Record<string, any>;
  
  // Metadata
  metadata: Record<string, any>;
  
  // Timestamps
  created_at: string;
  updated_at?: string | null;
  deleted: boolean;
}

export interface CreateConfiguredProductPreviewParams {
  organization_id: string;
  product_type_id: string;
  config_snapshot: Record<string, any>;
  quote_id?: string | null;
}

// BOM Preview Snapshot types (stored in ConfiguredProducts.bom_preview_snapshot)
export interface BOMSnapshotItem {
  id: string;
  kind: 'roll' | 'parent' | 'child' | 'accessory' | 'labor' | 'other';
  role: string;
  level: number;
  selected: boolean;
  catalog_item_id: string | null;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unit_price: number;
  line_total: number;
  children?: BOMSnapshotItem[];
  meta?: Record<string, any>;
}

export interface BOMPreviewSnapshot {
  version: string;
  product_type_id: string;
  bom_template_id: string | null;
  price_basis: 'msrp' | 'dealer';
  currency: string;
  totals: {
    roll_msrp_total: number;
    bom_total: number;
    accessories_total: number;
    labor_pct: number;
    labor_amount: number;
    total_msrp: number;
    roll_total_cost: number;
    bom_total_cost: number;
  };
  items: BOMSnapshotItem[];
}

export interface CreateConfiguredProductPreviewResult {
  configured_product_id: string;
  bom_instance_id: string;
  bom_template_id: string;
  totals: {
    roll_msrp_total: number;
    bom_total: number;
    msrp_product_subtotal?: number;
    labor_pct: number;
    labor_amount?: number;
    accessories_total: number;
    total_msrp: number;
    unit_dealer_price?: number;
    total_cost?: number;
    roll_total_cost?: number;
    bom_total_cost?: number;
  };
  // NEW: BOM Preview Snapshot for UI breakdown display
  bom_preview_snapshot?: BOMPreviewSnapshot | null;
}
