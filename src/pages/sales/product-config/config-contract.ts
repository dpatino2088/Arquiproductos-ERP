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
  productType?: 'roller-shade' | 'dual-shade' | 'triple-shade' | 'drapery' | 'awning' | 'window-film' | 'accessories'; // UI code for compatibility
  
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
    // Core identifiers (productTypeId es el UUID que guarda el paso PRODUCT; product_type_id es snake_case)
    product_type_id: config.product_type_id ?? (config as any).productTypeId ?? null,
    bom_template_id: config.bom_template_id || null,
    productType: config.productType,
    
    // Measurements — derive from width_mm/height_mm when width_m/height_m are missing (MeasurementsStep sets both but React state can lose one)
    width_m: config.width_m ?? ((config as any).width_mm ? (config as any).width_mm / 1000 : null),
    height_m: config.height_m ?? ((config as any).height_mm ? (config as any).height_mm / 1000 : null),
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

/**
 * Normalize ProductConfigurator config for QuoteLines and QuoteLineComponents persistence
 * 
 * RULES:
 * 1. Uses ONLY snake_case keys for persistence
 * 2. Converts cassette_shape → cassette boolean + cassette_shape
 * 3. Normalizes side_channel + bottom_channel → side_channel_type
 * 4. Extracts hardware options (hardware_color, drive_type, tube_type, etc.)
 * 
 * @param rawConfig - Raw config from ProductConfigurator
 * @returns Normalized config with snake_case keys and proper boolean conversion
 */
export function normalizeConfiguratorConfig(rawConfig: any): {
  // Fields for QuoteLines
  quoteLine: {
    product_type_id: string | null;
    bom_template_id: string | null;
    width_m: number | null;
    height_m: number | null;
    quantity: number;
    collection_name: string | null;
    variant_name: string | null;
    fabric_catalog_item_id: string | null;
    // Snapshot fields (for reference)
    operating_system_variant: string | null;
    tube_type: string | null;
    drive_type: string | null;
    bottom_rail_type: string | null;
    cassette: boolean;
    cassette_shape: string | null;
    side_channel: boolean;
    side_channel_type: string | null;
    hardware_color: string | null;
  };
  // Options for QuoteLineComponents(kind='option')
  options: {
    hardware_color?: string;
    drive_type?: string;
    cassette?: { cassette: boolean; cassette_shape?: string };
    side_channel?: { side_channel: boolean; side_channel_type?: string; bottom_channel?: boolean };
    tube_type?: string;
    operating_system_variant?: string;
    bottom_rail_type?: string;
  };
} {
  // 1. Convert cassette_shape to cassette boolean
  const cassette_shape = rawConfig.cassette_shape || rawConfig.cassetteShape || null;
  const cassette = cassette_shape !== null && cassette_shape !== 'none';
  
  // 2. Normalize side_channel + bottom_channel
  const side_channel = rawConfig.side_channel === true;
  const bottom_channel = rawConfig.bottom_channel === true;
  
  // 3. Determine side_channel_type
  let side_channel_type: string | null = null;
  if (side_channel) {
    if (bottom_channel) {
      side_channel_type = 'side_and_bottom';
    } else {
      side_channel_type = 'side_only';
    }
  }
  
  // 4. Extract hardware_color (from multiple possible sources)
  const hardware_color = rawConfig.hardware_color || rawConfig.hardwareColor || rawConfig.operatingSystemColor || null;
  
  // 5. Extract drive_type
  const drive_type = rawConfig.drive_type || rawConfig.operation_type || null;
  
  // 6. Extract tube_type
  const tube_type = rawConfig.tube_type || null;
  
  // 7. Extract operating_system_variant
  const operating_system_variant = rawConfig.operating_system_variant || null;
  
  // 8. Extract bottom_rail_type
  const bottom_rail_type = rawConfig.bottom_rail_type || rawConfig.bottom_bar_finish || null;
  
  // 9. Extract fabric variant
  const fabric_catalog_item_id = rawConfig.fabric_catalog_item_id || rawConfig.variantId || rawConfig.fabric_variant_id || null;
  
  return {
    quoteLine: {
      product_type_id: rawConfig.product_type_id || rawConfig.productTypeId || null,
      bom_template_id: rawConfig.bom_template_id || null,
      width_m: rawConfig.width_m || (rawConfig.width_mm ? rawConfig.width_mm / 1000 : null),
      height_m: rawConfig.height_m || (rawConfig.height_mm ? rawConfig.height_mm / 1000 : null),
      quantity: rawConfig.quantity || 1,
      collection_name: rawConfig.collection_name || rawConfig.collectionName || null,
      variant_name: rawConfig.variant_name || rawConfig.variantName || null,
      fabric_catalog_item_id,
      // Snapshot fields
      operating_system_variant,
      tube_type,
      drive_type,
      bottom_rail_type,
      cassette,
      cassette_shape,
      side_channel,
      side_channel_type,
      hardware_color,
    },
    options: {
      ...(hardware_color ? { hardware_color } : {}),
      ...(drive_type ? { drive_type } : {}),
      ...(cassette || cassette_shape !== 'none' ? { cassette: { cassette, cassette_shape: cassette_shape || undefined } } : {}),
      ...(side_channel ? { side_channel: { side_channel, side_channel_type: side_channel_type || undefined, bottom_channel } } : {}),
      ...(tube_type ? { tube_type } : {}),
      ...(operating_system_variant ? { operating_system_variant } : {}),
      ...(bottom_rail_type ? { bottom_rail_type } : {}),
    },
  };
}