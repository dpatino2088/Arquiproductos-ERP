/**
 * BOM Builders
 * Each product type has its own BOM generation logic
 */

import { ProductConfig, RollerShadeConfig, DualShadeConfig, TripleShadeConfig, DraperyConfig, AwningConfig, WindowFilmConfig } from '../types';

export interface BOMItem {
  catalog_item_id: string;
  qty: number;
  uom: string;
  unit_price: number;
  extended_price: number;
  source: string; // e.g., 'fabric', 'motor', 'tube', 'accessory'
}

export interface BOMResult {
  items: BOMItem[];
  subtotal: number;
  total: number;
}

/**
 * Build BOM for Roller Shade
 */
export async function buildRollerShadeBOM(
  config: RollerShadeConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement actual BOM logic
  // - Calculate fabric quantity based on width, height, roll width
  // - Add tube/headrail based on width
  // - Add operating system (motor/manual drive)
  // - Add mounting hardware
  // - Add accessories
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Build BOM for Dual Shade
 */
export async function buildDualShadeBOM(
  config: DualShadeConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement dual shade specific logic
  // - Two fabric layers
  // - Dual operating system if motorized
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Build BOM for Triple Shade
 */
export async function buildTripleShadeBOM(
  config: TripleShadeConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement triple shade specific logic
  // - Three fabric layers
  // - Triple operating system if motorized
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Build BOM for Drapery
 */
export async function buildDraperyBOM(
  config: DraperyConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement drapery specific logic
  // - Track system components
  // - Fabric with fullness calculation
  // - Confection hardware (pleats, hooks, etc.)
  // - Mounting hardware
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Build BOM for Awning
 */
export async function buildAwningBOM(
  config: AwningConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement awning specific logic
  // - Fabric with projection calculation
  // - Frame components
  // - Operating system
  // - Mounting hardware
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Build BOM for Window Film
 */
export async function buildWindowFilmBOM(
  config: WindowFilmConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  
  // TODO: Implement window film specific logic
  // - Film material (area-based)
  // - Installation tools/accessories
  
  return {
    items,
    subtotal: 0,
    total: 0,
  };
}

/**
 * Main BOM builder dispatcher
 */
export async function buildBOM(
  config: ProductConfig,
  organizationId: string
): Promise<BOMResult> {
  switch (config.productType) {
    case 'roller-shade':
      return buildRollerShadeBOM(config as RollerShadeConfig, organizationId);
    case 'dual-shade':
      return buildDualShadeBOM(config as DualShadeConfig, organizationId);
    case 'triple-shade':
      return buildTripleShadeBOM(config as TripleShadeConfig, organizationId);
    case 'drapery':
      return buildDraperyBOM(config as DraperyConfig, organizationId);
    case 'awning':
      return buildAwningBOM(config as AwningConfig, organizationId);
    case 'window-film':
      return buildWindowFilmBOM(config as WindowFilmConfig, organizationId);
    default:
      throw new Error(`Unknown product type: ${(config as any).productType}`);
  }
}

