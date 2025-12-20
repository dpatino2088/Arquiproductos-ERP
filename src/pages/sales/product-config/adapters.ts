/**
 * Compatibility Adapters
 * Convert between old CurtainConfiguration and new ProductConfig
 */

import { ProductConfig, RollerShadeConfig, Panel } from './types';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { QuoteLine } from '../../../types/catalog';

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
    // Use first panel if panels array exists, otherwise use legacy width_mm/height_mm
    const firstPanel = config.panels && config.panels.length > 0 ? config.panels[0] : null;
    return {
      productType: 'roller-shade',
      area: config.area,
      position: config.position,
      width_mm: firstPanel?.width_mm || config.width_mm,
      // height_mm is stored in parent config, not in panel
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
      operatingSystemColor: (config.operatingSystemColor === 'silver' || config.operatingSystemColor === 'bronze') ? 'white' : (config.operatingSystemColor as 'white' | 'black' | undefined),
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

/**
 * Convert QuoteLine back to ProductConfig for editing
 */
export function adaptQuoteLineToProductConfig(line: QuoteLine & { [key: string]: any }): ProductConfig {
  const productType = (line.product_type || 'roller-shade') as any;
  
  // Check if metadata contains panels information (for multi-panel support)
  const metadata = line.metadata || {};
  const panelsFromMetadata = metadata.panels as Panel[] | undefined;
  const panelIndex = metadata.panel_index as number | undefined;
  const totalPanels = metadata.total_panels as number | undefined;
  
  // Base config
  const baseConfig: Partial<ProductConfig> = {
    productType,
    area: line.area || undefined,
    position: line.position ? (typeof line.position === 'string' ? parseInt(line.position, 10) || line.position : line.position) : undefined,
    quantity: line.qty || 1,
    width_mm: line.width_m ? Math.round(line.width_m * 1000) : undefined,
    height_mm: line.height_m ? Math.round(line.height_m * 1000) : undefined,
  };

  // Product-specific fields
  if (productType === 'roller-shade') {
    // If this is part of a multi-panel configuration, reconstruct panels array
    // Note: panels only store width_mm, height_mm is global
    let panels: Panel[] | undefined;
    if (panelsFromMetadata && Array.isArray(panelsFromMetadata)) {
      // Ensure panels only have width_mm (remove height_mm if present in old data)
      panels = panelsFromMetadata.map((p: any) => ({ width_mm: p.width_mm || 0 }));
    } else if (totalPanels && totalPanels > 1) {
      // If we know there are multiple panels but don't have the full array,
      // create a single panel entry for this line (width only)
      panels = [{
        width_mm: line.width_m ? Math.round(line.width_m * 1000) : 0,
      }];
    }
    
    const config: RollerShadeConfig = {
      ...baseConfig,
      productType: 'roller-shade',
      panels, // Include panels if available
      collectionId: line.collection_id || undefined,
      position: line.position || baseConfig.position || '',
      variantId: line.variant_id || undefined,
      operatingSystem: line.operating_system as any,
      operatingSystemManufacturer: line.operating_system_manufacturer as any,
      operatingSystemVariant: line.operating_system_drive_id || undefined, // Use FK as variant
      installationType: line.installation_type as any,
      installationLocation: line.installation_location as any,
      fabricDrop: line.fabric_drop as any,
    };
    return config;
  }

  // For other product types, return base config
  return baseConfig as ProductConfig;
}

