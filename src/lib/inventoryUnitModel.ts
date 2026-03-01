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
  | 'yd';

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
  'each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton',
]);

const LINEAR_UNITS = new Set(['m', 'ft', 'yd']);

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

