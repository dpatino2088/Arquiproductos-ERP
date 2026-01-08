/**
 * Fabric Linear Meters Calculation
 * 
 * Formulas for calculating fabric consumption in linear meters (m) based on roll width.
 * Used for BOM components with role='fabric'.
 */

export interface FabricCalculationParams {
  width_m: number; // Product width in meters
  height_m: number; // Product height in meters
  roll_width_m: number; // Fabric roll width in meters (e.g., 2.8)
  fullness?: number; // Fullness factor for drapery (default: 2.0)
  allowance_m?: number; // Hem/waste allowance in meters (default: 0.1)
  product_type?: string; // 'roller-shade' | 'drapery' | etc.
}

/**
 * Calculate fabric linear meters for Roller Shades
 * Formula: fabric_m = (height_m + allowance_m)
 * 
 * For roller shades, fabric is cut to height (no width calculation needed).
 */
export function calculateRollerFabricLinearM(params: FabricCalculationParams): number {
  const { height_m, allowance_m = 0.1 } = params;
  return height_m + allowance_m;
}

/**
 * Calculate fabric linear meters for Drapery
 * Formula: 
 *   panels = ceil((width_m * fullness) / roll_width_m)
 *   fabric_m = panels * (height_m + allowance_m)
 * 
 * For drapery, we need to calculate how many panels fit across the roll width,
 * then multiply by the height needed per panel.
 */
export function calculateDraperyFabricLinearM(params: FabricCalculationParams): number {
  const { width_m, height_m, roll_width_m, fullness = 2.0, allowance_m = 0.1 } = params;
  
  if (!roll_width_m || roll_width_m <= 0) {
    throw new Error('roll_width_m is required and must be > 0 for drapery calculation');
  }
  
  // Calculate number of panels needed
  const total_width_needed = width_m * fullness;
  const panels = Math.ceil(total_width_needed / roll_width_m);
  
  // Calculate linear meters: panels * (height + allowance)
  const fabric_m = panels * (height_m + allowance_m);
  
  return fabric_m;
}

/**
 * Calculate fabric linear meters based on product type
 * Defaults to roller formula if product type is unknown
 */
export function calculateFabricLinearM(params: FabricCalculationParams): number {
  const { product_type } = params;
  
  if (product_type === 'drapery' || product_type === 'curtain') {
    return calculateDraperyFabricLinearM(params);
  }
  
  // Default to roller formula
  return calculateRollerFabricLinearM(params);
}

/**
 * Get fabric calculation preview text
 */
export function getFabricCalculationPreview(params: FabricCalculationParams): string {
  try {
    const fabric_m = calculateFabricLinearM(params);
    const { roll_width_m, product_type } = params;
    
    if (product_type === 'drapery' || product_type === 'curtain') {
      const { width_m, height_m, fullness = 2.0, allowance_m = 0.1 } = params;
      const total_width_needed = width_m * fullness;
      const panels = Math.ceil(total_width_needed / roll_width_m);
      return `Estimated fabric: ${fabric_m.toFixed(2)} m (${panels} panels × ${(height_m + allowance_m).toFixed(2)} m, roll width: ${roll_width_m} m)`;
    }
    
    return `Estimated fabric: ${fabric_m.toFixed(2)} m (height + ${params.allowance_m || 0.1} m allowance)`;
  } catch (error) {
    return `Calculation error: ${error instanceof Error ? error.message : 'Unknown error'}`;
  }
}

