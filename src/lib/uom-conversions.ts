/**
 * UOM (Unit of Measure) Conversion Utilities
 * 
 * Centralized helpers for normalizing rates and quantities to system units:
 * - Linear: m (meters)
 * - Area: m² (square meters)
 * - Unit: ea (each)
 * 
 * Supports: m, cm, mm, in, ft, yd for linear and area conversions
 */

export type LinearUOM = 'm' | 'cm' | 'mm' | 'in' | 'ft' | 'yd';
export type AreaUOM = 'm2' | 'cm2' | 'mm2' | 'in2' | 'ft2' | 'yd2' | 'sqm' | 'sqft' | 'sqyd';
export type UnitUOM = 'ea' | 'pcs' | 'unit' | 'piece';
export type AllUOM = LinearUOM | AreaUOM | UnitUOM;

export type SystemUOM = 'm' | 'm2' | 'ea';

/**
 * Convert any linear measurement to meters
 * 
 * @param value - Numeric value to convert
 * @param uom - Source unit of measure
 * @returns Value in meters
 */
export function toMeters(value: number, uom: string): number {
  const uomLower = uom.toLowerCase().trim();
  
  switch (uomLower) {
    case 'm':
    case 'meter':
    case 'meters':
    case 'mts':
      return value;
    
    case 'cm':
    case 'centimeter':
    case 'centimeters':
      return value / 100;
    
    case 'mm':
    case 'millimeter':
    case 'millimeters':
      return value / 1000;
    
    case 'in':
    case 'inch':
    case 'inches':
      return value * 0.0254;
    
    case 'ft':
    case 'foot':
    case 'feet':
      return value * 0.3048;
    
    case 'yd':
    case 'yard':
    case 'yards':
      return value * 0.9144;
    
    default:
      console.warn(`Unknown linear UOM "${uom}", returning value as-is`);
      return value;
  }
}

/**
 * Convert dimensions to square meters
 * 
 * @param width - Width value
 * @param width_uom - Width unit of measure
 * @param height - Height value
 * @param height_uom - Height unit of measure
 * @returns Area in square meters
 */
export function toSquareMeters(
  width: number,
  width_uom: string,
  height: number,
  height_uom: string
): number {
  const widthInMeters = toMeters(width, width_uom);
  const heightInMeters = toMeters(height, height_uom);
  return widthInMeters * heightInMeters;
}

/**
 * Convert area measurement to square meters
 * 
 * @param value - Numeric value to convert
 * @param uom - Source unit of measure
 * @returns Value in square meters
 */
export function toSquareMetersFromArea(value: number, uom: string): number {
  const uomLower = uom.toLowerCase().trim();
  
  switch (uomLower) {
    case 'm2':
    case 'sqm':
    case 'square_meter':
    case 'square_meters':
    case 'sq_m':
      return value;
    
    case 'cm2':
    case 'square_centimeter':
    case 'square_centimeters':
      return value / 10000;
    
    case 'mm2':
    case 'square_millimeter':
    case 'square_millimeters':
      return value / 1000000;
    
    case 'in2':
    case 'square_inch':
    case 'square_inches':
    case 'sq_in':
      return value * 0.00064516;
    
    case 'ft2':
    case 'sqft':
    case 'square_foot':
    case 'square_feet':
    case 'sq_ft':
      return value * 0.092903;
    
    case 'yd2':
    case 'sqyd':
    case 'square_yard':
    case 'square_yards':
    case 'sq_yd':
      return value * 0.836127;
    
    default:
      console.warn(`Unknown area UOM "${uom}", returning value as-is`);
      return value;
  }
}

/**
 * Normalize a rate/price to system unit
 * 
 * For example:
 * - $10/ft → $32.81/m (linear)
 * - $5/ft² → $53.82/m² (area)
 * - $2/ea → $2/ea (unit - no conversion)
 * 
 * @param value - Rate value in source UOM
 * @param from_uom - Source UOM (what the rate is currently in)
 * @param target_uom - Target system UOM ('m' | 'm2' | 'ea')
 * @returns Rate value in target UOM
 */
export function normalizeRateToSystem(
  value: number,
  from_uom: string,
  target_uom: SystemUOM
): number {
  if (value === 0) return 0;
  
  const fromLower = from_uom.toLowerCase().trim();
  
  // If already in target, return as-is
  if (fromLower === target_uom) return value;
  
  // Unit conversions (ea, pcs, unit) - no conversion needed
  if (target_uom === 'ea') {
    const unitUoms = ['ea', 'pcs', 'unit', 'piece', 'each'];
    if (unitUoms.includes(fromLower)) {
      return value;
    }
    console.warn(`Cannot convert rate from "${from_uom}" to "ea"`);
    return value;
  }
  
  // Linear conversions (to meters)
  if (target_uom === 'm') {
    // Rate conversion: if cost is $X per foot, then cost per meter = $X * (meters_per_foot)^-1
    // Example: $10/ft → $10 / 0.3048 = $32.81/m
    const metersPerSourceUnit = toMeters(1, from_uom);
    if (metersPerSourceUnit === 1 && fromLower !== 'm') {
      // Unknown UOM, return as-is
      console.warn(`Cannot convert linear rate from "${from_uom}" to "m"`);
      return value;
    }
    return value / metersPerSourceUnit;
  }
  
  // Area conversions (to square meters)
  if (target_uom === 'm2') {
    // Rate conversion: if cost is $X per sqft, then cost per sqm = $X * (sqm_per_sqft)^-1
    const sqmPerSourceUnit = toSquareMetersFromArea(1, from_uom);
    if (sqmPerSourceUnit === 1 && !['m2', 'sqm', 'square_meter', 'sq_m'].includes(fromLower)) {
      // Unknown UOM, return as-is
      console.warn(`Cannot convert area rate from "${from_uom}" to "m2"`);
      return value;
    }
    return value / sqmPerSourceUnit;
  }
  
  console.warn(`Unknown target UOM "${target_uom}"`);
  return value;
}

/**
 * Determine system UOM based on item properties
 * 
 * @param item - Catalog item properties
 * @returns System UOM ('m' | 'm2' | 'ea')
 */
export function determineSystemUOM(item: {
  is_roll?: boolean;
  is_fabric?: boolean;
  roll_pricing_mode?: 'per_linear_meter' | 'per_square_meter' | 'per_unit' | null;
  measure_basis?: 'unit' | 'linear' | 'area' | null;
  category_code?: string | null;
  role?: string | null;
}): SystemUOM {
  // Rolls (fabric, film, vinyl, etc.)
  if (item.is_roll) {
    if (item.roll_pricing_mode === 'per_square_meter') {
      return 'm2';
    } else if (item.roll_pricing_mode === 'per_linear_meter') {
      return 'm';
    } else if (item.roll_pricing_mode === 'per_unit') {
      return 'ea';
    }
    // Default for rolls without explicit mode: assume per_square_meter for fabric, per_linear_meter for others
    if (item.is_fabric) {
      return 'm2';
    }
    return 'm';
  }
  
  // Linear items (tubes, profiles, tracks, headbox, etc.)
  if (item.measure_basis === 'linear') {
    return 'm';
  }
  
  // Check category or role for linear indicators
  const linearPatterns = ['tube', 'profile', 'track', 'headbox', 'rail', 'cassette', 'bottom', 'side'];
  const categoryOrRole = (item.category_code || item.role || '').toLowerCase();
  if (linearPatterns.some(pattern => categoryOrRole.includes(pattern))) {
    return 'm';
  }
  
  // Area items
  if (item.measure_basis === 'area') {
    return 'm2';
  }
  
  // Unit items (default)
  return 'ea';
}

/**
 * Format system UOM for display
 */
export function formatSystemUOM(uom: SystemUOM): string {
  switch (uom) {
    case 'm':
      return '$/m';
    case 'm2':
      return '$/m²';
    case 'ea':
      return '$/ea';
    default:
      return `$/${uom}`;
  }
}

/**
 * Format user UOM for display
 */
export function formatUserUOM(uom: string | null | undefined): string {
  if (!uom) return '';
  
  const uomLower = uom.toLowerCase().trim();
  
  // Common display formats
  const displayMap: Record<string, string> = {
    'm': 'm',
    'cm': 'cm',
    'mm': 'mm',
    'in': 'in',
    'ft': 'ft',
    'yd': 'yd',
    'm2': 'm²',
    'sqm': 'm²',
    'cm2': 'cm²',
    'mm2': 'mm²',
    'in2': 'in²',
    'ft2': 'ft²',
    'sqft': 'ft²',
    'yd2': 'yd²',
    'sqyd': 'yd²',
    'ea': 'ea',
    'pcs': 'pcs',
    'unit': 'unit',
    'piece': 'pc',
  };
  
  return displayMap[uomLower] || uom;
}

/**
 * Validate that user UOM is compatible with system UOM
 */
export function isCompatibleUOM(user_uom: string, system_uom: SystemUOM): boolean {
  const userLower = user_uom.toLowerCase().trim();
  
  if (system_uom === 'ea') {
    return ['ea', 'pcs', 'unit', 'piece', 'each'].includes(userLower);
  }
  
  if (system_uom === 'm') {
    return ['m', 'cm', 'mm', 'in', 'ft', 'yd', 'meter', 'meters', 'mts'].includes(userLower);
  }
  
  if (system_uom === 'm2') {
    return ['m2', 'sqm', 'cm2', 'mm2', 'in2', 'ft2', 'sqft', 'yd2', 'sqyd', 'square_meter', 'sq_m'].includes(userLower);
  }
  
  return false;
}
