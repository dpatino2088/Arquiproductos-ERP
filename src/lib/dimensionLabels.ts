/**
 * Dimension labels per product type.
 *
 * Extensible awnings (Monobloc) have no height: the second dimension is the
 * frontal PROJECTION (salida), which is stored in height_m / height_mm so the
 * 2D cut engine and persistence work unchanged. Screens must label it
 * "Projection" instead of "Height" for these lines.
 */

/** True when the product stores its projection in the height fields. */
export function isProjectionProduct(productType?: string | null): boolean {
  const pt = String(productType ?? '').trim().toLowerCase().replace(/_/g, '-').replace(/\s+/g, '-');
  // Only the extensible awning uses projection; 'awning-vertical' is a real W×H drop.
  return pt === 'awning';
}

/** Label for the second dimension: 'Projection' for extensible awnings, else 'Height'. */
export function heightDimensionLabel(productType?: string | null): string {
  return isProjectionProduct(productType) ? 'Projection' : 'Height';
}

/** Short label (for compact tables): 'P' for projection, 'H' for height. */
export function heightDimensionShortLabel(productType?: string | null): string {
  return isProjectionProduct(productType) ? 'P' : 'H';
}
