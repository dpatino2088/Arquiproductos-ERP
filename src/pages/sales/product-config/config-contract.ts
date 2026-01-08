/**
 * BOM Template-Driven Configurator - Unified Contract
 * 
 * This file defines the unified ProductConfig type and normalizeConfig helper
 * to ensure consistent config structure across all steps.
 */

export interface UnifiedProductConfig {
  // Core identifiers
  product_type_id: string | null;
  bom_template_id: string | null;
  productType?: 'roller-shade' | 'dual-shade' | 'triple-shade' | 'drapery' | 'awning' | 'window-film'; // UI code for compatibility
  
  // Measurements (always required)
  width_m: number | null;
  height_m: number | null;
  area?: string | null;
  position: number | string;
  quantity?: number;
  
  // BOM-driven fields (from configurator steps)
  hardware_color: string | null; // 'white' | 'black' | 'silver' | 'bronze' | null
  cassette: boolean;
  side_channel: boolean;
  side_channel_type: 'side_only' | 'side_and_bottom' | null;
  drive_type: 'manual' | 'motorized' | null; // For BOM-driven configurator
  tube_type?: string | null; // e.g., 'RTU-42', 'RTU-65'
  
  // Fabric/Variant selection
  fabric_variant_id?: string | null; // CatalogItem ID for fabric variant
  variantId?: string | null; // Legacy alias
  collectionId?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  
  // Legacy fields (for backward compatibility)
  operatingSystem?: 'manual' | 'motorized';
  operation_type?: 'manual' | 'motor';
  operating_system_variant?: string | null;
  bottom_rail_type?: 'standard' | 'wrapped' | null;
  
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

/**
 * Normalize config to ensure defaults and consistency
 * 
 * CRITICAL: This function ensures all required fields have defaults
 * and prevents undefined values from breaking the configurator
 */
export function normalizeConfig(config: Partial<UnifiedProductConfig>): UnifiedProductConfig {
  return {
    // Core identifiers
    product_type_id: config.product_type_id || null,
    bom_template_id: config.bom_template_id || null,
    productType: config.productType,
    
    // Measurements
    width_m: config.width_m ?? null,
    height_m: config.height_m ?? null,
    area: config.area || null,
    position: config.position ?? '',
    quantity: config.quantity ?? 1,
    
    // BOM-driven fields with defaults
    hardware_color: config.hardware_color || null,
    cassette: config.cassette ?? false, // Default: false
    side_channel: config.side_channel ?? false, // Default: false
    side_channel_type: config.side_channel_type || null,
    drive_type: config.drive_type || (config.operatingSystem === 'manual' ? 'manual' : config.operatingSystem === 'motorized' ? 'motorized' : null),
    tube_type: config.tube_type || null,
    
    // Fabric/Variant
    fabric_variant_id: config.fabric_variant_id || config.variantId || null,
    variantId: config.variantId || config.fabric_variant_id || null,
    collectionId: config.collectionId || null,
    collection_name: config.collection_name || null,
    variant_name: config.variant_name || null,
    
    // Legacy fields
    operatingSystem: config.operatingSystem,
    operation_type: config.operation_type || (config.drive_type === 'manual' ? 'manual' : config.drive_type === 'motorized' ? 'motor' : undefined),
    operating_system_variant: config.operating_system_variant || null,
    bottom_rail_type: config.bottom_rail_type || null,
    
    // Accessories
    accessories: config.accessories || [],
  };
}

