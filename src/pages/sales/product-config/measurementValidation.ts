/**
 * Measurement validation rules (shared across all product configurators).
 *
 * Hard limits (block progression):
 *   - Each panel width >= 600mm (anything narrower is not manufacturable).
 *   - Height >= 200mm (cannot be zero / tiny).
 *
 * Soft limits → flag the line as "needs factory review" (does NOT block):
 *   - Roller / dual / triple: a single panel wider than the tube length (5800mm).
 *   - Product WITH headbox: total width wider than the headbox length (5800mm),
 *     because the headbox is one continuous piece.
 *   - Roller / dual / triple WITHOUT headbox split across multiple tubes (panels) —
 *     manufacturable as several sections but must be verified by the factory.
 *   - Drapery wider than 10000mm (max track even with joins).
 */

export const MIN_PANEL_WIDTH_MM = 600;
export const MIN_HEIGHT_MM = 200;
export const MAX_TUBE_WIDTH_MM = 5800;     // roller/dual/triple per-panel (tube length)
export const MAX_HEADBOX_WIDTH_MM = 5800;  // headbox is a single continuous piece
export const MAX_DRAPERY_WIDTH_MM = 10000; // drapery max width (with joins)

const TUBE_PRODUCT_TYPES = ['roller-shade', 'dual-shade', 'triple-shade'];

export interface MeasurementValidationResult {
  /** false => hard error, progression must be blocked */
  valid: boolean;
  /** Hard blocking errors (min limits) */
  errors: string[];
  /** Non-blocking warnings (same as factory review reasons) */
  warnings: string[];
  /** True when the line should be flagged for factory review by size */
  needsFactoryReview: boolean;
  /** Human-readable reasons for the factory review flag */
  factoryReviewReasons: string[];
}

type AnyConfig = Record<string, any>;

function normalizeProductType(config: AnyConfig): string {
  return String(config?.productType ?? config?.product_type ?? '').toLowerCase();
}

/** Panel widths in mm (from panels / measurements.panels, falling back to width_mm). */
export function getPanelWidthsMm(config: AnyConfig): number[] {
  const panels = Array.isArray(config?.panels)
    ? config.panels
    : (Array.isArray(config?.measurements?.panels) ? config.measurements.panels : null);
  if (panels && panels.length > 0) {
    return panels.map((p: any) => Math.round(Number(p?.width_mm) || 0));
  }
  const w = Number(config?.width_mm) || (config?.width_m ? Number(config.width_m) * 1000 : 0);
  return [Math.round(w || 0)];
}

function getHeightMm(config: AnyConfig): number {
  const h =
    Number(config?.height_mm) ||
    (config?.height_m ? Number(config.height_m) * 1000 : 0) ||
    Number(config?.measurements?.height_mm) ||
    0;
  return Math.round(h || 0);
}

export function validateMeasurements(
  config: AnyConfig,
  opts?: { hasHeadbox?: boolean }
): MeasurementValidationResult {
  const productType = normalizeProductType(config);
  const isDrapery = productType.includes('drapery');
  const isTubeProduct = TUBE_PRODUCT_TYPES.includes(productType);

  const panelWidths = getPanelWidthsMm(config);
  const heightMm = getHeightMm(config);
  const totalWidth = panelWidths.reduce((s, w) => s + (w > 0 ? w : 0), 0);
  const filledPanels = panelWidths.filter((w) => w > 0);
  const multiPanel = filledPanels.length > 1;

  const errors: string[] = [];
  const reasons: string[] = [];

  // --- Hard minimums ---
  panelWidths.forEach((w, i) => {
    if (w > 0 && w < MIN_PANEL_WIDTH_MM) {
      errors.push(
        panelWidths.length > 1
          ? `Panel ${i + 1} width (${w}mm) is below the ${MIN_PANEL_WIDTH_MM}mm minimum.`
          : `Width (${w}mm) is below the ${MIN_PANEL_WIDTH_MM}mm minimum.`
      );
    }
  });
  if (heightMm > 0 && heightMm < MIN_HEIGHT_MM) {
    errors.push(`Height (${heightMm}mm) is below the ${MIN_HEIGHT_MM}mm minimum.`);
  }

  // --- Soft limits → factory review ---
  if (isDrapery) {
    if (totalWidth > MAX_DRAPERY_WIDTH_MM) {
      reasons.push(`Drapery width (${totalWidth}mm) exceeds the ${MAX_DRAPERY_WIDTH_MM}mm maximum.`);
    }
  } else if (isTubeProduct) {
    panelWidths.forEach((w, i) => {
      if (w > MAX_TUBE_WIDTH_MM) {
        reasons.push(
          `Panel ${i + 1} width (${w}mm) exceeds the ${MAX_TUBE_WIDTH_MM}mm tube length.`
        );
      }
    });
    if (opts?.hasHeadbox) {
      if (totalWidth > MAX_HEADBOX_WIDTH_MM) {
        reasons.push(
          `Total width (${totalWidth}mm) exceeds the ${MAX_HEADBOX_WIDTH_MM}mm headbox length.`
        );
      }
    } else if (multiPanel) {
      reasons.push(
        `Multi-panel (${filledPanels.length} sections) — requires factory verification of tube splicing.`
      );
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings: reasons,
    needsFactoryReview: reasons.length > 0,
    factoryReviewReasons: reasons,
  };
}
