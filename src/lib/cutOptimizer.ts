export interface CutPiece {
  id: string;
  lengthMm: number;
  moId?: string;
  moNumber?: string;
  sku?: string;
  label?: string;
}

export interface PlacedPiece extends CutPiece {
  positionMm: number;
  stockIndex: number;
}

export interface StockBar {
  index: number;
  pieces: PlacedPiece[];
  usedMm: number;
  wasteMm: number;
  stockLengthMm: number;
}

export interface CutPlan1DResult {
  bars: StockBar[];
  totalStockUnits: number;
  totalUsedMm: number;
  totalWasteMm: number;
  efficiencyPct: number;
  totalPieces: number;
}

/**
 * 1D cutting stock optimization using First Fit Decreasing (FFD).
 * Sorts pieces largest-first, then assigns each to the first bar that fits.
 */
export function optimize1D(
  pieces: CutPiece[],
  stockLengthMm: number,
  kerfMm: number = 3,
): CutPlan1DResult {
  if (pieces.length === 0 || stockLengthMm <= 0) {
    return { bars: [], totalStockUnits: 0, totalUsedMm: 0, totalWasteMm: 0, efficiencyPct: 0, totalPieces: 0 };
  }

  const sorted = [...pieces].sort((a, b) => b.lengthMm - a.lengthMm);
  const bars: StockBar[] = [];

  for (const piece of sorted) {
    const effectiveLength = piece.lengthMm;
    if (effectiveLength > stockLengthMm) {
      // piece doesn't fit in any single bar - create dedicated bar
      const placed: PlacedPiece = { ...piece, positionMm: 0, stockIndex: bars.length };
      bars.push({
        index: bars.length,
        pieces: [placed],
        usedMm: effectiveLength,
        wasteMm: 0,
        stockLengthMm: effectiveLength,
      });
      continue;
    }

    let placed = false;
    for (const bar of bars) {
      const nextPos = bar.usedMm + (bar.pieces.length > 0 ? kerfMm : 0);
      if (nextPos + effectiveLength <= bar.stockLengthMm) {
        const placedPiece: PlacedPiece = { ...piece, positionMm: nextPos, stockIndex: bar.index };
        bar.pieces.push(placedPiece);
        bar.usedMm = nextPos + effectiveLength;
        bar.wasteMm = bar.stockLengthMm - bar.usedMm;
        placed = true;
        break;
      }
    }

    if (!placed) {
      const idx = bars.length;
      const placedPiece: PlacedPiece = { ...piece, positionMm: 0, stockIndex: idx };
      bars.push({
        index: idx,
        pieces: [placedPiece],
        usedMm: effectiveLength,
        wasteMm: stockLengthMm - effectiveLength,
        stockLengthMm,
      });
    }
  }

  const totalUsedMm = bars.reduce((s, b) => s + b.usedMm, 0);
  const totalStockMm = bars.reduce((s, b) => s + b.stockLengthMm, 0);
  const totalWasteMm = totalStockMm - totalUsedMm;

  return {
    bars,
    totalStockUnits: bars.length,
    totalUsedMm,
    totalWasteMm,
    efficiencyPct: totalStockMm > 0 ? Math.round((totalUsedMm / totalStockMm) * 10000) / 100 : 0,
    totalPieces: pieces.length,
  };
}
