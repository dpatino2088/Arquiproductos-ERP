import { MeasureBasis, FabricPricingMode } from '../../types/catalog';

/**
 * Computes the computed quantity based on measure basis and dimensions
 * 
 * @param measureBasis - How the item is measured
 * @param qty - Base quantity
 * @param widthM - Width in meters (optional)
 * @param heightM - Height in meters (optional)
 * @param rollWidthM - Roll width in meters (required for fabric)
 * @param fabricPricingMode - Deprecated, not used (kept for backward compatibility)
 * @returns Computed quantity
 */
export function computeComputedQty(
  measureBasis: MeasureBasis,
  qty: number,
  widthM?: number | null,
  heightM?: number | null,
  rollWidthM?: number | null,
  fabricPricingMode?: FabricPricingMode | null // Deprecated, not used
): number {
  switch (measureBasis) {
    case 'unit':
      return qty;

    case 'linear_m':
      // For linear items, use width_m if available, otherwise height_m
      // This covers both cases: tubes (width) and side channels (height)
      if (widthM != null) {
        return qty * widthM;
      } else if (heightM != null) {
        return qty * heightM;
      } else {
        throw new Error('width_m or height_m is required for linear_m measure basis');
      }

    case 'area':
      if (widthM == null || heightM == null) {
        throw new Error('width_m and height_m are required for area measure basis');
      }
      return qty * widthM * heightM;

    case 'fabric':
      if (widthM == null || heightM == null) {
        throw new Error('width_m and height_m are required for fabric measure basis');
      }
      
      if (rollWidthM == null || rollWidthM <= 0) {
        throw new Error('roll_width_m is required and must be > 0 for fabric measure basis');
      }
      
      // For fabric: cost = roll_width_m × height_m (as per business rules)
      // Quantity is calculated as: qty × roll_width_m × height_m
      return qty * rollWidthM * heightM;

    default:
      throw new Error(`Unknown measure_basis: ${measureBasis}`);
  }
}

