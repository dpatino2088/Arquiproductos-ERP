/**
 * UOM (Unit of Measure) Normalization and Validation
 * 
 * This module provides shared logic for UOM handling across the application.
 * It ensures consistency between frontend validation and database storage.
 */

// Valid UOM options by measure basis
export const UOM_OPTIONS_BY_MEASURE_BASIS = {
  linear_m: ['m', 'ft', 'yd'],
  area: ['m2'],
  unit: ['ea', 'pcs', 'set'],
  fabric: ['m2', 'm', 'yd', 'roll'],
} as const;

// Measure basis options (lowercase)
export const MEASURE_BASIS_OPTIONS = [
  { value: 'linear_m', label: 'Linear (length)' },
  { value: 'area', label: 'Area (m²)' },
  { value: 'unit', label: 'Unit (each)' },
  { value: 'fabric', label: 'Fabric' },
] as const;

/**
 * Normalizes a UOM value to lowercase and trims whitespace
 * @param value - The UOM value to normalize
 * @returns Normalized value or null if input is null/undefined/empty
 */
export function normalizeUom(value?: string | null): string | null {
  if (!value) return null;
  const normalized = value.trim().toLowerCase();
  return normalized || null;
}

/**
 * Normalizes a measure basis value to lowercase and trims whitespace
 * @param value - The measure basis value to normalize
 * @returns Normalized value or null if input is null/undefined/empty
 */
export function normalizeMeasureBasis(value?: string | null): string | null {
  if (!value) return null;
  const normalized = value.trim().toLowerCase();
  return normalized || null;
}

/**
 * Validates if a UOM is valid for a given measure basis
 * @param measureBasis - The measure basis (e.g., 'linear_m', 'area', 'unit', 'fabric')
 * @param uom - The UOM to validate
 * @returns true if the UOM is valid for the measure basis, false otherwise
 */
export function isUomValidForMeasureBasis(
  measureBasis?: string | null,
  uom?: string | null
): boolean {
  if (!measureBasis || !uom) return false;
  
  const mb = normalizeMeasureBasis(measureBasis);
  const unit = normalizeUom(uom);
  
  if (!mb || !unit) return false;
  
  // Check if measure basis is in our valid options
  if (!(mb in UOM_OPTIONS_BY_MEASURE_BASIS)) return false;
  
  // Check if UOM is valid for this measure basis
  const validUoms = UOM_OPTIONS_BY_MEASURE_BASIS[mb as keyof typeof UOM_OPTIONS_BY_MEASURE_BASIS];
  return validUoms.includes(unit as any);
}

/**
 * Gets valid UOM options for a given measure basis
 * @param measureBasis - The measure basis
 * @returns Array of valid UOM options, or empty array if measure basis is invalid
 */
export function getValidUomOptions(measureBasis?: string | null): readonly string[] {
  if (!measureBasis) return [];
  
  const mb = normalizeMeasureBasis(measureBasis);
  if (!mb || !(mb in UOM_OPTIONS_BY_MEASURE_BASIS)) return [];
  
  return UOM_OPTIONS_BY_MEASURE_BASIS[mb as keyof typeof UOM_OPTIONS_BY_MEASURE_BASIS];
}

/**
 * Validates and normalizes a UOM value for a given measure basis
 * @param measureBasis - The measure basis
 * @param uom - The UOM to validate and normalize
 * @returns Normalized UOM if valid, null otherwise
 */
export function validateAndNormalizeUom(
  measureBasis?: string | null,
  uom?: string | null
): string | null {
  if (!uom) return null;
  
  const normalized = normalizeUom(uom);
  if (!normalized) return null;
  
  if (!isUomValidForMeasureBasis(measureBasis, normalized)) {
    return null;
  }
  
  return normalized;
}





