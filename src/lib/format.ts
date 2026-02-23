/**
 * Formatting utilities for UI display.
 * Display-only: no calculations or business logic.
 */

/**
 * Formats a number as USD money string.
 * @example formatMoney(88.82) → "$88.82"
 */
export function formatMoney(n: number | null | undefined): string {
  if (n == null || Number.isNaN(n)) return '$0.00';
  return '$' + Number(n).toFixed(2);
}

/**
 * Normalizes UOM for display (e.g. m2 → m²).
 * Source of truth for qty/uom is bom_preview_snapshot.items; this only formats for UI.
 */
export function formatUom(uom: string | null | undefined): string {
  if (uom == null || uom === '') return 'ea';
  const normalized = String(uom).trim().toLowerCase();
  if (normalized === 'm2' || normalized === 'm²') return 'm²';
  if (normalized === 'sqm' || normalized === 'sq_m') return 'm²';
  return uom;
}
