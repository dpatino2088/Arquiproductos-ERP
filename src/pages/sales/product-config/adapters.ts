/**
 * Compatibility Adapters
 * Convert between old CurtainConfiguration and new ProductConfig
 */

import { ProductConfig, RollerShadeConfig } from './types';
import { CurtainConfiguration } from '../CurtainConfigurator';

/**
 * Convert old CurtainConfiguration to new ProductConfig
 */
export function adaptToProductConfig(oldConfig: CurtainConfiguration): ProductConfig {
  if (!oldConfig.productType) {
    throw new Error('Product type is required');
  }

  // Map old product types to new ones
  const productTypeMap: Record<string, string> = {
    'roller-shade': 'roller-shade',
    'dual-shade': 'dual-shade',
    'triple-shade': 'triple-shade',
    'drapery-wave': 'drapery',
    'awning': 'awning',
    'window-films': 'window-film',
  };

  const newProductType = productTypeMap[oldConfig.productType] || 'roller-shade';

  // For now, only handle roller-shade (most common)
  if (newProductType === 'roller-shade') {
    const config: RollerShadeConfig = {
      productType: 'roller-shade',
      area: oldConfig.area,
      position: oldConfig.position,
      width_mm: oldConfig.width_mm,
      height_mm: oldConfig.height_mm,
      fabricDrop: oldConfig.fabricDrop,
      installationType: oldConfig.installationType,
      installationLocation: oldConfig.installationLocation,
      variantManufacturer: oldConfig.variantManufacturer,
      collectionId: oldConfig.filmType, // filmType was used for collection
      variantId: oldConfig.ralColor, // ralColor was used for variant
      operatingSystem: oldConfig.operatingSystem,
      operatingSystemManufacturer: oldConfig.operatingSystemManufacturer,
      operatingSystemVariant: oldConfig.operatingSystemVariant,
      operatingSystemSide: oldConfig.operatingSystemSide,
      clutchSize: oldConfig.clutchSize,
      operatingSystemColor: oldConfig.operatingSystemColor,
      chainColor: oldConfig.chainColor,
      operatingSystemHeight: oldConfig.operatingSystemHeight,
      tubeSize: oldConfig.tubeSize,
      accessories: oldConfig.accessories,
    };
    return config;
  }

  // Default fallback
  return {
    productType: newProductType as any,
    position: oldConfig.position,
    area: oldConfig.area,
  } as ProductConfig;
}

/**
 * Convert new ProductConfig to old CurtainConfiguration (for backward compatibility)
 */
export function adaptFromProductConfig(newConfig: ProductConfig): CurtainConfiguration {
  if (newConfig.productType === 'roller-shade') {
    const config = newConfig as RollerShadeConfig;
    return {
      productType: 'roller-shade',
      area: config.area,
      position: config.position,
      width_mm: config.width_mm,
      height_mm: config.height_mm,
      fabricDrop: config.fabricDrop,
      installationType: config.installationType,
      installationLocation: config.installationLocation,
      variantManufacturer: config.variantManufacturer,
      filmType: config.collectionId,
      ralColor: config.variantId,
      operatingSystem: config.operatingSystem,
      operatingSystemManufacturer: config.operatingSystemManufacturer,
      operatingSystemVariant: config.operatingSystemVariant,
      operatingSystemSide: config.operatingSystemSide,
      clutchSize: config.clutchSize,
      operatingSystemColor: config.operatingSystemColor,
      chainColor: config.chainColor,
      operatingSystemHeight: config.operatingSystemHeight,
      tubeSize: config.tubeSize,
      accessories: config.accessories,
    };
  }

  // Default fallback
  return {
    productType: newConfig.productType,
    position: newConfig.position,
    area: newConfig.area,
  };
}

