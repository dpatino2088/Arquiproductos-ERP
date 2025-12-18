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
  | 'window-film';

// Panel interface for multi-panel support (for interconnected curtains)
// Note: height_mm is stored globally in height_mm field, not per panel
// This avoids redundancy since all panels share the same height
export interface Panel {
  width_mm: number;
  // height_mm is NOT stored here - it's stored in the parent config's height_mm field
}

export interface BaseProductConfig {
  productType: ProductType;
  area?: string;
  position: number | string;
  quantity?: number;
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
  installationType?: 'inside' | 'outside';
  installationLocation?: 'ceiling' | 'wall';
  // Fabric/Collection
  variantManufacturer?: 'coulisse' | 'vertilux';
  collectionId?: string;
  variantId?: string;
  // Operating System
  operatingSystem?: 'manual' | 'motorized';
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Manual specific
  clutchSize?: 'S' | 'M' | 'L';
  operatingSystemColor?: 'white' | 'black';
  chainColor?: 'white' | 'black';
  operatingSystemHeight?: 'standard' | 'custom';
  tubeSize?: 'standard' | '42mm' | '65mm' | '80mm';
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
  operatingSystemManufacturer?: 'motion' | 'lutron' | 'vertilux';
  operatingSystemVariant?: string;
  operatingSystemSide?: 'left' | 'right';
  // Accessories
  accessories?: Array<{ id: string; name: string; qty: number; price: number }>;
}

// Drapery Configuration
export interface DraperyConfig extends BaseProductConfig {
  productType: 'drapery';
  // Track System
  trackSystem?: 'wave' | 'ripple-fold' | 'pleated';
  trackType?: string;
  // Measurements
  width_mm?: number;
  height_mm?: number;
  fullness?: number; // Percentage of fullness (e.g., 200% = double width)
  // Fabric
  fabric?: {
    manufacturer?: 'coulisse' | 'vertilux';
    collectionId?: string;
    variantId?: string;
  };
  // Confection Type
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

// Union type for all product configurations
export type ProductConfig = 
  | RollerShadeConfig
  | DualShadeConfig
  | TripleShadeConfig
  | DraperyConfig
  | AwningConfig
  | WindowFilmConfig;

