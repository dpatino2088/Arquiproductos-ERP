import { MeasureBasis, FabricPricingMode } from '../../types/catalog';

/**
 * Computes the computed quantity based on measure basis and dimensions
 * 
 * @param measureBasis - How the item is measured
 * @param qty - Base quantity
 * @param widthM - Width in meters (optional)
 * @param heightM - Height in meters (optional)
 * @param rollWidthM - Roll width in meters (required for fabric with per_linear_m)
 * @param fabricPricingMode - Pricing mode for fabric items (required for fabric)
 * @returns Computed quantity
 */
export function computeComputedQty(
  measureBasis: MeasureBasis,
  qty: number,
  widthM?: number | null,
  heightM?: number | null,
  rollWidthM?: number | null,
  fabricPricingMode?: FabricPricingMode | null
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
      
      if (!fabricPricingMode) {
        throw new Error('fabric_pricing_mode is required for fabric measure basis');
      }

      if (fabricPricingMode === 'per_sqm') {
        return qty * widthM * heightM;
      } else if (fabricPricingMode === 'per_linear_m') {
        if (rollWidthM == null || rollWidthM <= 0) {
          throw new Error('roll_width_m is required and must be > 0 for fabric with per_linear_m pricing');
        }
        return qty * (widthM * heightM) / rollWidthM;
      } else {
        throw new Error(`Unknown fabric_pricing_mode: ${fabricPricingMode}`);
      }

    default:
      throw new Error(`Unknown measure_basis: ${measureBasis}`);
  }
}

