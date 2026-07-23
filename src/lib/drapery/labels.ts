/**
 * Commercial labels for drapery — keep System (model) and Size (fullness)
 * distinct so "Wave 2.8" is never mistaken for the Wave Drapery product line.
 *
 *   product_line  → Wave Drapery | Ripple Fold | Pinch Pleat
 *   style_code    → Size 2.0 / 2.3 / 2.8  (or Pinch Pleat when style is pinch)
 */

const PRODUCT_LINE_LABELS: Record<string, string> = {
  wave_drapery: 'Wave Drapery',
  wave: 'Wave Drapery',
  ripple_fold: 'Ripple Fold',
  'ripple-fold': 'Ripple Fold',
  pinch_pleat: 'Pinch Pleat',
  'pinch-pleat': 'Pinch Pleat',
  pleated: 'Pinch Pleat',
};

function titleCaseWords(raw: string): string {
  return raw
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Normalize product_line → "Ripple Fold" / "Wave Drapery" / "Pinch Pleat". */
export function formatDraperySystemLabel(productLine?: string | null): string | null {
  const key = String(productLine || '').trim().toLowerCase();
  if (!key) return null;
  if (PRODUCT_LINE_LABELS[key]) return PRODUCT_LINE_LABELS[key];
  return titleCaseWords(key);
}

/**
 * Size / fullness from style_code.
 *   wave_2.8 → "Size 2.8"
 *   pinch_pleat → null (system already says Pinch Pleat)
 */
export function formatDraperySizeLabel(styleCode?: string | null): string | null {
  const raw = String(styleCode || '').trim().toLowerCase();
  if (!raw) return null;
  if (raw.includes('pinch')) return null;
  const m = raw.match(/(\d+(?:\.\d+)?)/);
  if (m) return `Size ${m[1]}`;
  return null;
}

/**
 * Combined style label for Quote / Proposal / PDF.
 * Examples:
 *   Ripple Fold | Size 2.8
 *   Wave Drapery | Size 2.0
 *   Pinch Pleat
 *   Size 2.8   (when product_line missing — never "Wave 2.8" alone)
 */
export function formatDraperyStyleLabel(opts: {
  productLine?: string | null;
  styleCode?: string | null;
}): string {
  const system = formatDraperySystemLabel(opts.productLine);
  const size = formatDraperySizeLabel(opts.styleCode);
  const styleIsPinch = /pinch/i.test(String(opts.styleCode || ''));

  const parts: string[] = [];
  if (system) parts.push(system);
  else if (styleIsPinch) parts.push('Pinch Pleat');
  if (size) parts.push(size);

  // Last resort: unknown style_code without digits/system — title-case but
  // strip a leading lone "Wave " so we don't reintroduce the ambiguity.
  if (parts.length === 0 && opts.styleCode) {
    const fallback = titleCaseWords(String(opts.styleCode));
    if (/^Wave\s+\d/i.test(fallback)) {
      const m = fallback.match(/(\d+(?:\.\d+)?)/);
      return m ? `Size ${m[1]}` : fallback;
    }
    return fallback;
  }

  return parts.join(' | ');
}

/** Track-only commercial name: "Drapery Track | Ripple Fold | Size 2.8". */
export function formatDraperyTrackDescription(opts: {
  productLine?: string | null;
  styleCode?: string | null;
}): string {
  const style = formatDraperyStyleLabel(opts);
  return style ? `Drapery Track | ${style}` : 'Drapery Track';
}
