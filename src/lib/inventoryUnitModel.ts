export type MeasureBasis = 'unit' | 'linear' | 'area';
export type StockBasis = 'ea' | 'linear_m';
export type PurchaseMode = 'unit_packaged' | 'linear_direct' | 'roll';
export type PurchaseUnit =
  | 'each'
  | 'pack'
  | 'set'
  | 'box'
  | 'case'
  | 'bag'
  | 'bundle'
  | 'carton'
  | 'roll'
  | 'm'
  | 'ft'
  | 'yd'
  | 'kit'
  | 'pair';

export interface InventoryUnitModelInput {
  isRoll: boolean;
  measureBasis: MeasureBasis;
  purchaseUnit?: string | null;
}

export interface InventoryUnitModel {
  stockBasis: StockBasis;
  purchaseMode: PurchaseMode;
}

export interface ConversionToInternalInput {
  qtyInPurchaseUnit: number;
  purchaseMode: PurchaseMode;
  purchaseUnit: string;
  unitsPerPurchaseUnit?: number | null;
  rollLengthValue?: number | null;
  rollLengthUom?: string | null;
}

const UNIT_PACKAGED = new Set([
  'each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton', 'kit', 'pair',
]);

const LINEAR_UNITS = new Set(['m', 'ft', 'yd']);

export function isDirectLinearPurchaseUnit(unit: string | null | undefined): boolean {
  return LINEAR_UNITS.has(String(unit ?? '').toLowerCase());
}

export function isPackagedPurchaseUnit(unit: string | null | undefined): boolean {
  return UNIT_PACKAGED.has(String(unit ?? '').toLowerCase());
}

export function defaultUnitsPerPurchaseUnit(
  purchaseUnit: string | null | undefined,
): number | null {
  const unit = String(purchaseUnit ?? '').toLowerCase();
  if (unit === 'm') return 1;
  if (unit === 'ft') return 0.3048;
  if (unit === 'yd') return 0.9144;
  return null;
}

export function getAllowedPurchaseUnits(
  measureBasis: MeasureBasis,
  isRoll: boolean,
): PurchaseUnit[] {
  if (isRoll) return ['roll'];
  if (measureBasis === 'linear') {
    return ['each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton', 'kit', 'pair', 'm', 'ft', 'yd'];
  }
  return ['each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton', 'kit', 'pair'];
}

function toMeters(value: number, uom: string): number {
  switch ((uom || '').toLowerCase()) {
    case 'm':
      return value;
    case 'ft':
      return value * 0.3048;
    case 'yd':
      return value * 0.9144;
    default:
      return value;
  }
}

function fromMeters(meters: number, targetUom: string): number {
  switch ((targetUom || '').toLowerCase()) {
    case 'm':
      return meters;
    case 'ft':
      return meters / 0.3048;
    case 'yd':
      return meters / 0.9144;
    default:
      return meters;
  }
}

export function resolveInventoryUnitModel(input: InventoryUnitModelInput): InventoryUnitModel {
  const purchaseUnit = (input.purchaseUnit ?? '').toLowerCase();
  if (input.isRoll) {
    // Rolls are stocked in linear meters internally, but vendors may sell by roll
    // or by direct linear units (m/ft/yd).
    if (LINEAR_UNITS.has(purchaseUnit)) {
      return { stockBasis: 'linear_m', purchaseMode: 'linear_direct' };
    }
    return { stockBasis: 'linear_m', purchaseMode: 'roll' };
  }

  if (input.measureBasis === 'linear') {
    if (UNIT_PACKAGED.has(purchaseUnit)) {
      return { stockBasis: 'linear_m', purchaseMode: 'unit_packaged' };
    }
    return { stockBasis: 'linear_m', purchaseMode: 'linear_direct' };
  }

  return { stockBasis: 'ea', purchaseMode: 'unit_packaged' };
}

/**
 * Converts a vendor-facing quantity into internal stock quantity.
 * Internal stock basis is always ea or linear meters.
 */
export function convertPurchaseQtyToInternal(input: ConversionToInternalInput): number {
  const qty = Number(input.qtyInPurchaseUnit ?? 0);
  if (!(qty > 0)) return 0;

  if (input.purchaseMode === 'roll') {
    const lengthPerRoll = Number(input.rollLengthValue ?? 0);
    if (!(lengthPerRoll > 0)) return qty;
    return qty * toMeters(lengthPerRoll, input.rollLengthUom ?? 'm');
  }

  if (input.purchaseMode === 'linear_direct') {
    return toMeters(qty, input.purchaseUnit);
  }

  const unitsPerPurchase = Math.max(1, Number(input.unitsPerPurchaseUnit ?? 1));
  return qty * unitsPerPurchase;
}

export interface ConversionToExternalInput {
  internalQty: number;
  purchaseMode: PurchaseMode;
  purchaseUnit: string;
  unitsPerPurchaseUnit?: number | null;
  rollLengthValue?: number | null;
  rollLengthUom?: string | null;
  moq?: number | null;
}

/**
 * Converts an internal stock quantity (ea or linear meters) into the vendor-facing
 * purchase quantity & unit. Always rounds up so we never order less than needed.
 */
export function convertInternalToPurchaseQty(input: ConversionToExternalInput): {
  orderQty: number;
  lineUnit: string;
  unitCost: (costPerBaseUnit: number) => number;
} {
  const applyMoq = (qty: number): number => {
    const moq = Number(input.moq ?? 0);
    if (!(moq > 0)) return qty;
    return Math.max(qty, moq);
  };

  const qty = Number(input.internalQty ?? 0);
  if (!(qty > 0)) return { orderQty: 0, lineUnit: input.purchaseUnit || 'ea', unitCost: () => 0 };

  if (input.purchaseMode === 'roll') {
    const lengthPerRoll = Number(input.rollLengthValue ?? 0);
    if (!(lengthPerRoll > 0)) return { orderQty: qty, lineUnit: 'roll', unitCost: (c) => c };
    const rollLengthM = toMeters(lengthPerRoll, input.rollLengthUom ?? 'm');
    const orderQty = applyMoq(Math.ceil(qty / rollLengthM));
    return {
      orderQty,
      lineUnit: 'roll',
      unitCost: (costPerUnit) => costPerUnit * lengthPerRoll,
    };
  }

  if (input.purchaseMode === 'linear_direct') {
    const converted = fromMeters(qty, input.purchaseUnit);
    const unitsPerPiece = Math.max(1, Number(input.unitsPerPurchaseUnit ?? 1));
    if (unitsPerPiece > 1) {
      // Round up to full pieces (e.g. tubes of 19ft → order in multiples of 19)
      const pieces = Math.max(1, Math.ceil(converted / unitsPerPiece));
      const orderQty = applyMoq(pieces * unitsPerPiece);
      return {
        orderQty,
        lineUnit: input.purchaseUnit || 'm',
        unitCost: (costPerUnit) => costPerUnit,
      };
    }
    const orderQty = applyMoq(Math.ceil(converted * 100) / 100);
    return {
      orderQty,
      lineUnit: input.purchaseUnit || 'm',
      unitCost: (costPerUnit) => costPerUnit,
    };
  }

  const unitsPerPurchase = Math.max(1, Number(input.unitsPerPurchaseUnit ?? 1));
  if (unitsPerPurchase > 1) {
    const orderQty = applyMoq(Math.max(1, Math.ceil(qty / unitsPerPurchase)));
    return {
      orderQty,
      lineUnit: input.purchaseUnit || 'box',
      unitCost: (costPerUnit) => costPerUnit * unitsPerPurchase,
    };
  }

  return {
    orderQty: applyMoq(Math.ceil(qty)),
    lineUnit: input.purchaseUnit || 'each',
    unitCost: (costPerUnit) => costPerUnit,
  };
}

