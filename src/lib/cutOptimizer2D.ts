export interface FabricPiece {
  id: string;
  widthMm: number;
  heightMm: number;
  moId?: string;
  moNumber?: string;
  label?: string;
}

export interface PlacedFabricPiece extends FabricPiece {
  x: number;
  y: number;
  rotated: boolean;
  rollIndex: number;
}

export interface Shelf {
  y: number;
  height: number;
  usedWidth: number;
  pieces: PlacedFabricPiece[];
}

export interface FabricRoll {
  index: number;
  widthMm: number;
  lengthMm: number;
  shelves: Shelf[];
  usedLengthMm: number;
  pieces: PlacedFabricPiece[];
  wastePct: number;
}

export interface CutPlan2DResult {
  rolls: FabricRoll[];
  totalRolls: number;
  totalPieces: number;
  totalEfficiencyPct: number;
  totalUsedArea: number;
  totalStockArea: number;
}

/**
 * 2D fabric cutting optimization using shelf-based guillotine cutting.
 * Roll width is fixed, pieces are placed on horizontal shelves along the roll length.
 * Supports optional rotation (width/height swap) for better fit.
 */
export function optimize2D(
  pieces: FabricPiece[],
  rollWidthMm: number,
  rollLengthMm: number,
  allowRotation: boolean = false,
): CutPlan2DResult {
  if (pieces.length === 0 || rollWidthMm <= 0 || rollLengthMm <= 0) {
    return { rolls: [], totalRolls: 0, totalPieces: 0, totalEfficiencyPct: 0, totalUsedArea: 0, totalStockArea: 0 };
  }

  const sorted = [...pieces].sort((a, b) => {
    const aMax = Math.max(a.widthMm, a.heightMm);
    const bMax = Math.max(b.widthMm, b.heightMm);
    return bMax - aMax;
  });

  const rolls: FabricRoll[] = [];

  function createRoll(): FabricRoll {
    const roll: FabricRoll = {
      index: rolls.length,
      widthMm: rollWidthMm,
      lengthMm: rollLengthMm,
      shelves: [],
      usedLengthMm: 0,
      pieces: [],
      wastePct: 100,
    };
    rolls.push(roll);
    return roll;
  }

  function tryPlace(piece: FabricPiece, roll: FabricRoll): PlacedFabricPiece | null {
    const orientations: Array<{ w: number; h: number; rotated: boolean }> = [
      { w: piece.widthMm, h: piece.heightMm, rotated: false },
    ];
    if (allowRotation && piece.widthMm !== piece.heightMm) {
      orientations.push({ w: piece.heightMm, h: piece.widthMm, rotated: true });
    }

    for (const { w, h, rotated } of orientations) {
      if (w > roll.widthMm) continue;

      for (const shelf of roll.shelves) {
        if (h <= shelf.height && shelf.usedWidth + w <= roll.widthMm) {
          const placed: PlacedFabricPiece = {
            ...piece,
            x: shelf.usedWidth,
            y: shelf.y,
            widthMm: w,
            heightMm: h,
            rotated,
            rollIndex: roll.index,
          };
          shelf.usedWidth += w;
          shelf.pieces.push(placed);
          roll.pieces.push(placed);
          return placed;
        }
      }

      if (roll.usedLengthMm + h <= roll.lengthMm && w <= roll.widthMm) {
        const newShelf: Shelf = {
          y: roll.usedLengthMm,
          height: h,
          usedWidth: w,
          pieces: [],
        };
        const placed: PlacedFabricPiece = {
          ...piece,
          x: 0,
          y: newShelf.y,
          widthMm: w,
          heightMm: h,
          rotated,
          rollIndex: roll.index,
        };
        newShelf.pieces.push(placed);
        roll.shelves.push(newShelf);
        roll.usedLengthMm += h;
        roll.pieces.push(placed);
        return placed;
      }
    }
    return null;
  }

  for (const piece of sorted) {
    let placed = false;
    for (const roll of rolls) {
      if (tryPlace(piece, roll)) {
        placed = true;
        break;
      }
    }
    if (!placed) {
      const newRoll = createRoll();
      if (!tryPlace(piece, newRoll)) {
        const oversizeRoll: FabricRoll = {
          index: rolls.length - 1,
          widthMm: Math.max(rollWidthMm, piece.widthMm),
          lengthMm: Math.max(rollLengthMm, piece.heightMm),
          shelves: [{ y: 0, height: piece.heightMm, usedWidth: piece.widthMm, pieces: [] }],
          usedLengthMm: piece.heightMm,
          pieces: [],
          wastePct: 0,
        };
        const placedPiece: PlacedFabricPiece = {
          ...piece, x: 0, y: 0, rotated: false, rollIndex: oversizeRoll.index,
        };
        oversizeRoll.shelves[0].pieces.push(placedPiece);
        oversizeRoll.pieces.push(placedPiece);
        rolls[rolls.length - 1] = oversizeRoll;
      }
    }
  }

  let totalUsedArea = 0;
  let totalStockArea = 0;
  for (const roll of rolls) {
    const usedArea = roll.pieces.reduce((s, p) => s + p.widthMm * p.heightMm, 0);
    const stockArea = roll.widthMm * roll.usedLengthMm;
    totalUsedArea += usedArea;
    totalStockArea += stockArea;
    roll.wastePct = stockArea > 0 ? Math.round((1 - usedArea / stockArea) * 10000) / 100 : 0;
  }

  return {
    rolls,
    totalRolls: rolls.length,
    totalPieces: pieces.length,
    totalEfficiencyPct: totalStockArea > 0 ? Math.round((totalUsedArea / totalStockArea) * 10000) / 100 : 0,
    totalUsedArea,
    totalStockArea,
  };
}
