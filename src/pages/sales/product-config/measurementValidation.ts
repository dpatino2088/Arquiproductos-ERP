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

// ─────────────────────────────────────────────────────────────────────────────
// Extensible awning (Monobloc / Epsylon) fabrication limits
// Source: manufacturer manual "Instrucciones Monobloc Epsylon v3".
// ─────────────────────────────────────────────────────────────────────────────

export const AWNING_MIN_PROJECTION_MM = 1250;
export const AWNING_MAX_PROJECTION_MM = 4000;
export const AWNING_MAX_LINE_MM = 13000;          // 4 arms max
export const AWNING_MAGNUM_PROJECTION_MM = 3750;  // ≥ 3.75m projection requires Magnum kit
export const AWNING_CEILING_MAX_PROJECTION_MM = 3500; // ceiling install limit (Magnum extrusion support)
export const AWNING_CURRON_LINE_MM = 6000;        // center support (currón) recommended from 6m line

/**
 * Minimum line (total width, mm) per projection step and arm count.
 * Key = projection in mm; value = [min line 2 arms, 3 arms, 4 arms] in mm.
 */
export const AWNING_MIN_LINE_TABLE: Record<number, [number, number, number]> = {
  1250: [1870, 2690, 3500],
  1500: [2120, 3060, 4000],
  1750: [2370, 3440, 4500],
  2000: [2620, 3810, 5000],
  2250: [2890, 4220, 5540],
  2500: [3160, 4620, 6080],
  2750: [3290, 4820, 6340],
  3000: [3620, 5310, 7000],
  3250: [3870, 5690, 7500],
  3500: [4120, 6060, 8000],
  3750: [4370, 6440, 8500],
  4000: [4620, 6810, 9000],
};

/** Arm count by line: 2 arms up to 6.5m, 3 up to 10m, 4 up to 13m. */
export function awningArmsForLine(lineMm: number): 2 | 3 | 4 {
  if (lineMm <= 6500) return 2;
  if (lineMm <= 10000) return 3;
  return 4;
}

/** Round projection up to the next 0.25m table step (conservative lookup). */
function awningProjectionStep(projectionMm: number): number {
  const step = Math.ceil(projectionMm / 250) * 250;
  return Math.min(Math.max(step, AWNING_MIN_PROJECTION_MM), AWNING_MAX_PROJECTION_MM);
}

/** Minimum line (mm) for a given projection and arm count, from the Epsylon table. */
export function awningMinLineMm(projectionMm: number, arms: 2 | 3 | 4): number {
  const row = AWNING_MIN_LINE_TABLE[awningProjectionStep(projectionMm)];
  if (!row) return 0;
  return row[arms - 2];
}

/** Recommended roller tube diameter: Ø70 up to 4m line, Ø80 beyond. */
export function awningTubeDiameter(lineMm: number): 70 | 80 {
  return lineMm <= 4000 ? 70 : 80;
}

/**
 * Motor torque suggestion (Nm) from the Epsylon abaco tables.
 * Indexed by projection step (1.25 → 4.00 in 0.25 steps).
 */
const AWNING_MOTOR_NM_BY_ARMS: Record<2 | 3 | 4, number[]> = {
  // projection:  1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00
  2: [35, 35, 40, 40, 40, 40, 40, 55, 55, 55, 55, 70],
  3: [55, 55, 55, 55, 55, 70, 70, 70, 70, 80, 80, 80],
  4: [70, 70, 80, 80, 80, 80, 80, 100, 100, 100, 100, 100],
};

export function awningMotorNmSuggestion(lineMm: number, projectionMm: number): number | null {
  if (!lineMm || !projectionMm) return null;
  const arms = awningArmsForLine(lineMm);
  const idx = (awningProjectionStep(projectionMm) - AWNING_MIN_PROJECTION_MM) / 250;
  const table = AWNING_MOTOR_NM_BY_ARMS[arms];
  if (idx < 0 || idx >= table.length) return null;
  return table[idx];
}

/**
 * Extensible awning validation (Line × Projection).
 * Hard errors: projection out of 1.25–4m, line above 13m, line below the
 * minimum for projection × arms (the I.M. "imposibilidad de montaje" matrix).
 * Soft warnings (factory review): Magnum kit ≥ 3.75m projection, ceiling
 * install above 3.5m projection, center support (currón) from 6m line.
 */
function validateAwningExtensible(config: AnyConfig): { errors: string[]; reasons: string[] } {
  const errors: string[] = [];
  const reasons: string[] = [];

  const lineMm = Math.round(
    Number(config?.width_mm) || (config?.width_m ? Number(config.width_m) * 1000 : 0) || 0
  );
  const projectionMm = Math.round(
    Number(config?.projection_mm) ||
    Number(config?.height_mm) ||
    (config?.height_m ? Number(config.height_m) * 1000 : 0) ||
    0
  );
  const location = String(config?.installationLocation ?? config?.installation_location ?? '').toLowerCase();

  if (projectionMm > 0 && projectionMm < AWNING_MIN_PROJECTION_MM) {
    errors.push(`Projection (${projectionMm}mm) is below the ${AWNING_MIN_PROJECTION_MM}mm minimum.`);
  }
  if (projectionMm > AWNING_MAX_PROJECTION_MM) {
    errors.push(`Projection (${projectionMm}mm) exceeds the ${AWNING_MAX_PROJECTION_MM}mm maximum.`);
  }
  if (lineMm > AWNING_MAX_LINE_MM) {
    errors.push(`Line (${lineMm}mm) exceeds the ${AWNING_MAX_LINE_MM}mm maximum (4 arms).`);
  }

  if (lineMm > 0 && projectionMm >= AWNING_MIN_PROJECTION_MM && projectionMm <= AWNING_MAX_PROJECTION_MM && lineMm <= AWNING_MAX_LINE_MM) {
    const arms = awningArmsForLine(lineMm);
    const minLine = awningMinLineMm(projectionMm, arms);
    if (minLine > 0 && lineMm < minLine) {
      errors.push(
        `Line (${lineMm}mm) is below the ${minLine}mm minimum for a ${(projectionMm / 1000).toFixed(2)}m projection with ${arms} arms (mounting not possible).`
      );
    }
  }

  if (projectionMm >= AWNING_MAGNUM_PROJECTION_MM && projectionMm <= AWNING_MAX_PROJECTION_MM) {
    reasons.push(
      `Projection ≥ ${(AWNING_MAGNUM_PROJECTION_MM / 1000).toFixed(2)}m requires the Magnum kit (steel 40x40x3 square bar + Magnum supports).`
    );
  }
  if (location === 'ceiling' && projectionMm > AWNING_CEILING_MAX_PROJECTION_MM) {
    reasons.push(
      `Ceiling installation supports a maximum ${(AWNING_CEILING_MAX_PROJECTION_MM / 1000).toFixed(1)}m projection.`
    );
  }
  if (lineMm >= AWNING_CURRON_LINE_MM) {
    reasons.push(`Line ≥ ${(AWNING_CURRON_LINE_MM / 1000).toFixed(0)}m — center roller support (currón) required.`);
  }

  return { errors, reasons };
}

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
  // 'awning' = extensible (Line × Projection). 'awning-vertical' follows the
  // generic Width × Height rules below (roller-like drop screen).
  const isAwningExtensible = productType === 'awning';

  if (isAwningExtensible) {
    const { errors, reasons } = validateAwningExtensible(config);
    return {
      valid: errors.length === 0,
      errors,
      warnings: reasons,
      needsFactoryReview: reasons.length > 0,
      factoryReviewReasons: reasons,
    };
  }

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
  } else if (isTubeProduct || productType === 'awning-vertical') {
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
