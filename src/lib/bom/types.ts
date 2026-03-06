/**
 * BOM Fingerprint Types
 * 
 * These types define the structure of the BOM fingerprint used in the configurator.
 */

export type HeadboxType = 'none' | 'cassette';
export type SystemSize = 's' | 'm' | 'l' | 'xl';
export type SideChannelMode = 'none' | 'side_only' | 'side_plus_bottom';
export type OperatingSystem = 'manual' | 'motor';

/**
 * BOM Fingerprint - configurator state (not used for template matching)
 */
export interface BomFingerprint {
  product_type: string; // 'roller' (from ProductTypes.code)
  headbox_type: HeadboxType;
  system_size: SystemSize;
  color: string; // 'white' | 'black' | etc.
  side_channel_mode: SideChannelMode;
  operating_system: OperatingSystem;
}

/**
 * Roller BOM Configurator State
 */
export interface RollerBOMConfigState {
  // Step 1: ProductType
  product_type_id: string | null;
  product_type_code: string; // 'roller'
  
  // Step 2: Measurements (doesn't affect template, but stored in metadata)
  width_mm: number | null;
  height_mm: number | null;
  mount_type: string | null;
  location: string | null;
  
  // Step 3: Hardware (affects fingerprint)
  headbox_type: HeadboxType;
  system_size: SystemSize;
  color: string;
  bottom_bar_item_id: string | null;
  bottom_bar_wrapped: boolean;
  side_channel_mode: SideChannelMode;
  side_channel_item_id: string | null;
  bottom_channel_item_id: string | null;
  headbox_item_id: string | null; // Only if headbox_type='cassette'
  
  // Step 4: Operating System (affects fingerprint)
  operating_system: OperatingSystem;
  motor_item_id: string | null; // Only if operating_system='motor'
  drive_item_id: string | null; // Only if operating_system='manual'
  tube_item_id: string | null; // Optional, can be set by template

  // Step 5: Fabric
  fabric_item_id: string | null;
}

/**
 * BOM Template Slot (from BOMTemplateSlots table)
 */
export interface BOMTemplateSlot {
  id: string;
  organization_id: string;
  bom_template_id: string;
  item_role: string;
  required: boolean;
  catalog_item_id: string | null;
  qty: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Catalog Item Option (for card selection)
 */
export interface CatalogItemOption {
  id: string;
  sku: string;
  name: string;
  color: string | null;
  cost_exw: number | null;
  image_url: string | null;
}

/**
 * BOM Instance Metadata (stored in BOMInstances.metadata JSONB)
 */
export interface BOMInstanceMetadata {
  measurements: {
    width_mm: number;
    height_mm: number;
    mount_type?: string | null;
    location?: string | null;
  };
  bottom_bar_wrapped: boolean;
  selections: {
    motor_item_id?: string | null;
    drive_item_id?: string | null;
    headbox_item_id?: string | null;
    bottom_bar_item_id?: string | null;
    side_channel_item_id?: string | null;
    bottom_channel_item_id?: string | null;
    tube_item_id?: string | null;
    fabric_item_id?: string | null;
  };
}
