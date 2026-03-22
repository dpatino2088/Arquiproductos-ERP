/**
 * Product Type Definitions
 * Each product type is a completely independent system
 */

export type ProductType = 
  | 'roller-shade'
  | 'dual-shade'
  | 'triple-shade'
  | 'drapery'
  | 'awning'
  | 'window-film'
  | 'honey-comb'
  | 'vertical'
  | 'wood'
  | 'roman-shade'
  | 'catalog';

// Panel interface for multi-panel support (for interconnected curtains)
// Note: height_mm is stored globally in height_mm field, not per panel
// This avoids redundancy since all panels share the same height
export interface Panel {
  width_mm: number;
  // height_mm is NOT stored here - it's stored in the parent config's height_mm field
}

export interface BaseProductConfig {
  productType: ProductType;
  productTypeId?: string; // UUID from ProductTypes table - set by ProductStep
  quote_line_id?: string; // Existing QuoteLine when editing
  area?: string;
  position: number | string;
  quantity?: number;
  manufacturer?: string;
  productLine?: string;
  // Operating system selections (shared)
  manual_drive?: string;
  remote_control?: string;
  manual_drive_role?: string;
  remote_control_role?: string;
}

// Roller Shade Configuration
export interface RollerShadeConfig extends BaseProductConfig {
  productType: 'roller-shade';
  // Measurements - Support for multiple panels (interconnected curtains)
  // If panels array exists, use it; otherwise fallback to width_mm/height_mm (legacy)
  panels?: Panel[]; // Array of panels (1-3 panels supported)
  width_mm?: number; // Legacy: single panel width
  height_mm?: number; // Legacy: single panel height
  fabricDrop?: 'normal' | 'inverted';
  drop_type?: 'regular' | 'reverse'; // New field for HardwareStep
  installationType?: 'inside' | 'outside';
  installationLocation?: 'ceiling' | 'wall';
  // Fabric/Collection
  variantManufacturer?: 'coulisse' | 'vertilux';
  collectionId?: string;
  variantId?: string;
  // Fabric rotation, heatseal, and bottom bar wrap
  fabric_rotation?: boolean;
  fabric_heatseal?: boolean;
  bottom_bar_wrapped?: boolean;
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Manual specific
  clutchSize?: 'S' | 'M' | 'L';
  gear_ratio?: 'standard' | '1:1.5' | '1:3' | string;
  operatingSystemColor?: 'white' | 'black' | 'silver' | 'bronze';
  chainColor?: 'white' | 'black';
  operatingSystemHeight?: 'standard' | 'custom';
  tubeSize?: 'standard' | '42mm' | '65mm' | '80mm';
  // BOM Component Options
  hardwareColor?: 'white' | 'black' | 'silver' | 'bronze';
  cassetteColor?: 'white' | 'black' | 'silver' | 'bronze';
  bottomBar?: 'standard' | 'weighted' | 'none';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Dual Shade Configuration
export interface DualShadeConfig extends BaseProductConfig {
  productType: 'dual-shade';
  // Similar to Roller Shade but with dual layer specifics
  // Support for multiple panels (interconnected curtains)
  panels?: Panel[]; // Array of panels (1-3 panels supported)
  width_mm?: number; // Legacy: single panel width
  height_mm?: number; // Legacy: single panel height
  fabricDrop?: 'normal' | 'inverted';
  installationType?: 'inside' | 'outside';
  installationLocation?: 'ceiling' | 'wall';
  // Dual layer fabrics
  frontFabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  backFabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Manual specific
  clutchSize?: 'S' | 'M' | 'L';
  gear_ratio?: 'standard' | '1:1.5' | '1:3' | string;
  operatingSystemColor?: 'white' | 'black' | 'silver' | 'bronze';
  chainColor?: 'white' | 'black';
  operatingSystemHeight?: 'standard' | 'custom';
  tubeSize?: 'standard' | '42mm' | '65mm' | '80mm';
  // BOM Component Options (Block-based system)
  drive_type?: 'manual' | 'motor';
  bottom_rail_type?: 'standard' | 'wrapped';
  bottom_bar_wrapped?: boolean;
  cassette?: boolean;
  cassette_type?: 'standard' | 'recessed' | 'surface';
  side_channel?: boolean;
  side_channel_type?: 'side_only' | 'side_and_bottom' | null;
  hardware_color?: 'white' | 'black' | 'silver' | 'bronze';
  
  // Legacy fields
  hardwareColor?: 'white' | 'black' | 'silver' | 'bronze';
  cassetteColor?: 'white' | 'black' | 'silver' | 'bronze';
  bottomBar?: 'standard' | 'weighted' | 'none';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Triple Shade Configuration
export interface TripleShadeConfig extends BaseProductConfig {
  productType: 'triple-shade';
  // Support for multiple panels (interconnected curtains)
  panels?: Panel[]; // Array of panels (1-3 panels supported)
  width_mm?: number; // Legacy: single panel width
  height_mm?: number; // Legacy: single panel height
  installationType?: 'inside' | 'outside';
  installationLocation?: 'ceiling' | 'wall';
  // Triple layer fabrics
  frontFabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  middleFabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  backFabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operation_type?: 'manual' | 'motor'; // New field for block-based BOM
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Manual specific
  clutchSize?: 'S' | 'M' | 'L';
  gear_ratio?: 'standard' | '1:1.5' | '1:3' | string;
  operatingSystemColor?: 'white' | 'black' | 'silver' | 'bronze';
  chainColor?: 'white' | 'black';
  operatingSystemHeight?: 'standard' | 'custom';
  tubeSize?: 'standard' | '42mm' | '65mm' | '80mm';
  tube_type?: 'RTU-38' | 'RTU-42' | 'RTU-50' | 'RTU-65' | 'RTU-80'; // New field for block-based BOM
  motor_family?: string; // New field for motor family
  drop_type?: 'regular' | 'reverse'; // New field for HardwareStep
  // BOM Component Options (Block-based system)
  drive_type?: 'manual' | 'motor';
  bottom_rail_type?: 'standard' | 'wrapped';
  bottom_bar_wrapped?: boolean;
  cassette?: boolean;
  side_channel?: boolean;
  hardware_color?: 'white' | 'black' | 'silver' | 'bronze';
  
  // Legacy fields
  hardwareColor?: 'white' | 'black' | 'silver' | 'bronze';
  cassetteColor?: 'white' | 'black' | 'silver' | 'bronze';
  bottomBar?: 'standard' | 'weighted' | 'none';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Drapery Configuration
export interface DraperyConfig extends BaseProductConfig {
  productType: 'drapery';
  // Drapery style — drives FabricRules lookup (fabric_group based)
  styleCode?: 'wave_2.0' | 'wave_2.3' | 'wave_2.8' | 'pinch_pleat' | string;
  systemSize?: string; // Track/rail profile size (e.g. '48mm', '60mm')
  // Legacy fields (kept for backward compatibility)
  trackSystem?: 'wave' | 'ripple-fold' | 'pleated';
  trackType?: string;
  // Measurements
  width_mm?: number;
  height_mm?: number;
  fullness?: number; // Display-only — read from FabricRules, not user input
  // Opening & Drive Side — filters BOMTemplates
  openingDirection?: 'left' | 'right' | 'center';
  driveSide?: 'left' | 'right';
  // Track Only — customer supplies their own fabric
  track_only?: boolean;
  // Fabric
  fabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
    rollWidthCm?: number;
  };
  // Bottom hem override (user-selectable per quote line)
  bottom_hem_cm?: number;
  bottom_hem_profile?: 'serged' | 'hem_5' | 'hem_10' | 'hem_15' | string;
  // Legacy confection type
  confectionType?: 'standard' | 'pinch-pleat' | 'goblet' | 'euro-pleat';
  // Mounting
  mountingType?: 'ceiling' | 'wall' | 'inside-recess';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Awning Configuration
export interface AwningConfig extends BaseProductConfig {
  productType: 'awning';
  // Measurements
  width_mm?: number;
  projection_mm?: number; // How far it extends
  height_mm?: number;
  // Fabric
  fabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  // Mounting
  mountingType?: 'wall' | 'ceiling' | 'fascia';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Window Film Configuration
export interface WindowFilmConfig extends BaseProductConfig {
  productType: 'window-film';
  // Film Type
  filmType?: 'static' | 'adhesive' | 'decorative';
  filmCategory?: string;
  // Opacity/Properties
  opacity?: number; // 0-100
  uvProtection?: boolean;
  heatRejection?: boolean;
  privacy?: boolean;
  // Glass Measurements
  width_mm?: number;
  height_mm?: number;
  // Installation Type
  installationType?: 'inside' | 'outside';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Catalog Item configuration — one SKU × quantity, creates a ConfiguredProduct
export interface CatalogItemConfig extends BaseProductConfig {
  productType: 'catalog';
  catalog_item_id: string;
  name: string;
  sku: string;
  qty: number;
  unit_price: number;
}

// Union type for all product configurations
export type ProductConfig = 
  | RollerShadeConfig
  | DualShadeConfig
  | TripleShadeConfig
  | DraperyConfig
  | AwningConfig
  | WindowFilmConfig
  | CatalogItemConfig;

