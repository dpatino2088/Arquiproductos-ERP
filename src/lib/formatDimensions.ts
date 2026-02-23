/**
 * Format dimensions for display.
 * - Detailed (form): "1200 (w) x 3000 (h) : Para un Paño" or multi-line with "Para 2 Paños" + each panel width on its own line.
 * - Compact (table): "2700 x 3000 mm" or "1200 (w) | 1500 (w) x 3000 (h) mm"
 */

export type DimensionsSource = {
  width_m?: number | null;
  height_m?: number | null;
  width_mm?: number | null;
  height_mm?: number | null;
  measurements?: {
    panels?: Array<{ width_mm?: number }>;
    height_mm?: number;
  };
  panels?: Array<{ width_mm?: number }>;
} | null | undefined;

function getHeightMm(source: DimensionsSource): number | null {
  if (!source) return null;
  return (
    source.measurements?.height_mm ??
    source.height_mm ??
    (source.height_m != null && source.height_m > 0 ? source.height_m * 1000 : null)
  );
}

function getPanels(source: DimensionsSource): Array<{ width_mm?: number }> | null {
  if (!source) return null;
  const panels =
    source.measurements?.panels ??
    (Array.isArray(source.panels) && source.panels.length > 0 ? source.panels : null);
  return panels;
}

/** Para UI apilada: anchos y altura. widths en mm, heightMm en mm. */
export function getDimensionsStructured(source: DimensionsSource): { widths: number[]; heightMm: number } | null {
  if (!source) return null;
  const heightMm = getHeightMm(source);
  const heightR = heightMm != null && heightMm > 0 ? Math.round(heightMm) : null;
  const panels = getPanels(source);
  if (panels && panels.length >= 1 && heightR != null) {
    const widths = panels.map((p) => Math.round(p?.width_mm ?? 0));
    return { widths, heightMm: heightR };
  }
  const wMm =
    source.width_mm ??
    (source.width_m != null && source.width_m > 0 ? source.width_m * 1000 : null);
  if (wMm != null && wMm > 0 && heightR != null) {
    return { widths: [Math.round(wMm)], heightMm: heightR };
  }
  return null;
}

/**
 * Formato detallado: cada paño en su línea.
 * - 1 paño: "1200 (w) x 3000 (h) : Para un Paño"
 * - 2 paños: "1200 (w) x 3000 (h) : Para 2 Paños" + "\n" + "1500 (w)"
 * - 3 paños: primera línea + una línea por cada ancho adicional
 * Devuelve string con \n para que el UI renderice cada línea en bloque.
 */
export function formatDimensionsDisplay(source: DimensionsSource): string {
  if (!source) return '—';

  const heightMm = getHeightMm(source);
  const panels = getPanels(source);

  const heightR = heightMm != null && heightMm > 0 ? Math.round(heightMm) : null;

  if (panels && panels.length >= 1 && heightR != null) {
    const widths = panels.map((p) => p?.width_mm ?? 0);
    const n = widths.length;
    const firstLine = `${Math.round(widths[0])} (w) x ${heightR} (h)`;
    if (n === 1) return firstLine;
    const rest = widths.slice(1).map((w) => `${Math.round(w)} (w)`);
    return [firstLine, ...rest].join('\n');
  }

  const wMm =
    source.width_mm ??
    (source.width_m != null && source.width_m > 0 ? source.width_m * 1000 : null);
  if (wMm != null && wMm > 0 && heightR != null) {
    return `${Math.round(wMm)} (w) x ${heightR} (h)`;
  }

  return '—';
}

/**
 * Formato para PDF Proposal (igual que Quotes / DimensionsStackView).
 * - 1 paño: "1200 x 3000" (mm)
 * - 2 paños: "1200 x 3000\n1500"
 * - 3 paños: "1200 x 3000\n1500\n1800"
 */
export function formatDimensionsForProposalPDF(source: DimensionsSource): string {
  const data = getDimensionsStructured(source);
  if (!data || data.widths.length === 0) return '—';
  const { widths, heightMm } = data;
  const first = `${widths[0]} x ${heightMm}`;
  if (widths.length === 1) return first;
  const rest = widths.slice(1).map((w) => String(w));
  return [first, ...rest].join('\n');
}

/**
 * Formato compacto para tabla: una sola línea.
 * - 1 paño: "2700 x 3000 mm"
 * - Varios: "1200 (w) | 1500 (w) x 3000 (h) mm"
 */
export function formatDimensionsDisplayCompact(source: DimensionsSource): string {
  if (!source) return '—';

  const heightMm = getHeightMm(source);
  const panels = getPanels(source);

  const heightR = heightMm != null && heightMm > 0 ? Math.round(heightMm) : null;

  if (panels && panels.length > 1 && heightR != null) {
    const widths = panels.map((p) => Math.round(p?.width_mm ?? 0)).filter((w) => w > 0);
    if (widths.length > 0) {
      const widthPart = widths.map((w) => `${w} (w)`).join(' | ');
      return `${widthPart} x ${heightR} (h) mm`;
    }
  }

  const wMm =
    source.width_mm ??
    (source.width_m != null && source.width_m > 0 ? source.width_m * 1000 : null);
  if (wMm != null && wMm > 0 && heightR != null) {
    return `${Math.round(wMm)} x ${heightR} mm`;
  }

  return '—';
}
