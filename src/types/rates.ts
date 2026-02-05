/**
 * Types for catalog item rates/pricing
 * 
 * System UOM is the normalized unit for the system:
 * - m for linear items (tubes, tracks, profiles)
 * - m² for area items (rolls with per_sqm mode, fabrics)
 * - ea for unit items (pieces, accessories)
 * 
 * User UOM is the original unit entered by the user (optional, for reference)
 */

import { SystemUOM } from '../lib/uom-conversions';

/**
 * Rate model for catalog items
 */
export interface CatalogItemRate {
  /** Normalized rate value in system UOM */
  rate_value_system: number;
  
  /** System unit of measure ('m' | 'm2' | 'ea') */
  rate_uom_system: SystemUOM;
  
  /** Original rate value entered by user (optional, for reference) */
  rate_value_input?: number | null;
  
  /** Original unit of measure entered by user (optional, for reference) */
  rate_uom_input?: string | null;
  
  /** Roll pricing mode (how roll is priced) */
  roll_pricing_mode?: 'per_linear_meter' | 'per_square_meter' | 'per_unit' | null;
}

/**
 * Extended catalog item with rate information
 */
export interface CatalogItemWithRate {
  id: string;
  sku: string;
  name: string;
  unit_of_measure: string;
  measure_basis: 'unit' | 'linear' | 'area';
  
  is_roll: boolean;
  is_fabric: boolean;
  roll_pricing_mode?: 'per_linear_meter' | 'per_square_meter' | 'per_unit' | null;
  roll_width?: number | null;
  
  category_id?: string | null;
  category_code?: string | null;
  
  /** Current cost_exw from database (legacy single value) */
  cost_exw?: number | null;
  
  /** Rate information (normalized) */
  rate?: CatalogItemRate;
}

/**
 * Validation result for rate input
 */
export interface RateValidationResult {
  valid: boolean;
  error?: string;
  warnings?: string[];
}

/**
 * Validate rate input based on item type
 */
export function validateRate(
  item: Pick<CatalogItemWithRate, 'is_roll' | 'is_fabric' | 'roll_pricing_mode' | 'measure_basis'>,
  rate: Partial<CatalogItemRate>
): RateValidationResult {
  const warnings: string[] = [];
  
  // Validate rolls
  if (item.is_roll) {
    if (!rate.roll_pricing_mode && !item.roll_pricing_mode) {
      return {
        valid: false,
        error: 'Roll pricing mode is required for roll items',
      };
    }
    
    const expectedSystemUOM = 
      (rate.roll_pricing_mode === 'per_square_meter' || item.roll_pricing_mode === 'per_square_meter') 
        ? 'm2' 
        : (rate.roll_pricing_mode === 'per_unit' || item.roll_pricing_mode === 'per_unit')
        ? 'ea'
        : 'm';
    
    if (rate.rate_uom_system && rate.rate_uom_system !== expectedSystemUOM) {
      return {
        valid: false,
        error: `System UOM must be "${expectedSystemUOM}" for roll pricing mode "${rate.roll_pricing_mode || item.roll_pricing_mode}"`,
      };
    }
  }
  
  // Validate linear items
  const linearMeasureBasis = item.measure_basis === 'linear';
  if (linearMeasureBasis && rate.rate_uom_system && rate.rate_uom_system !== 'm') {
    return {
      valid: false,
      error: 'System UOM must be "m" for linear items (tubes, profiles, tracks, etc.)',
    };
  }
  
  // Validate unit items
  const unitMeasureBasis = item.measure_basis === 'unit';
  if (unitMeasureBasis && rate.rate_uom_system && rate.rate_uom_system !== 'ea') {
    return {
      valid: false,
      error: 'System UOM must be "ea" for unit items',
    };
  }
  
  // Validate rate value
  if (rate.rate_value_system !== undefined && rate.rate_value_system < 0) {
    return {
      valid: false,
      error: 'Rate value cannot be negative',
    };
  }
  
  // Warning: user UOM provided without value
  if (rate.rate_uom_input && !rate.rate_value_input) {
    warnings.push('User UOM specified but no user rate value provided');
  }
  
  return {
    valid: true,
    warnings: warnings.length > 0 ? warnings : undefined,
  };
}
