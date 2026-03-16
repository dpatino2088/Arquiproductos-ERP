/**
 * flattenSnapshotItems
 *
 * Convierte el array items de bom_preview_snapshot en una lista plana
 * lista para renderizar en tabla (incluye children como filas indentadas).
 *
 * Reglas:
 * - Usa line_total y unit_price del snapshot; NO recalcula qty × unit_price.
 * - children solo aplica a items con kind === 'parent'.
 * - isChild y parentRole permiten indentar en la UI.
 */

export interface BOMSnapshotItem {
  id: string;
  kind: 'roll' | 'parent' | 'child' | 'accessory' | 'labor' | 'other';
  role: string;
  level: number;
  selected: boolean;
  catalog_item_id: string | null;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unit_price: number;
  line_total: number;
  children?: BOMSnapshotItem[];
  meta?: Record<string, unknown>;
}

export interface BOMPreviewSnapshot {
  version: string;
  product_type_id: string;
  bom_template_id: string | null;
  price_basis: 'msrp' | 'dealer';
  currency: string;
  totals: {
    roll_qty?: number;
    roll_msrp_total: number;
    bom_total: number;
    accessories_total: number;
    labor_pct: number;
    labor_amount: number;
    total_msrp: number;
    roll_total_cost?: number;
    bom_total_cost?: number;
    accessories_total_cost?: number;
    unit_product_cost?: number;
    total_cost?: number;
  };
  items: BOMSnapshotItem[];
}

export interface FlatSnapshotRow {
  id: string;
  kind: BOMSnapshotItem['kind'];
  role: string;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unit_price: number;
  line_total: number;
  selected: boolean;
  catalog_item_id: string | null;
  isChild: boolean;
  parentRole?: string;
  level: number;
  meta?: Record<string, unknown>;
}

/**
 * Aplana items + children del bom_preview_snapshot en filas para tabla.
 * Devuelve [] si el snapshot no es válido (version !== '1' o sin items).
 */
export function flattenSnapshotItems(snapshot: BOMPreviewSnapshot | undefined | null): FlatSnapshotRow[] {
  if (!snapshot || snapshot.version !== '1' || !Array.isArray(snapshot.items) || snapshot.items.length === 0) {
    return [];
  }

  const rows: FlatSnapshotRow[] = [];

  const processItem = (item: BOMSnapshotItem, isChild = false, parentRole?: string) => {
    rows.push({
      id: item.id,
      kind: item.kind,
      role: item.role,
      sku: item.sku,
      name: item.name,
      qty: item.qty,
      uom: item.uom,
      unit_price: item.unit_price,
      line_total: item.line_total,
      selected: item.selected,
      catalog_item_id: item.catalog_item_id,
      isChild,
      parentRole,
      level: item.level,
      meta: item.meta,
    });

    if (item.kind === 'parent' && Array.isArray(item.children) && item.children.length > 0) {
      item.children.forEach(child => processItem(child, true, item.role));
    }
  };

  snapshot.items.forEach(item => processItem(item));
  return rows;
}

/**
 * Calcula el total MSRP desde el snapshot.
 * Prioriza totals.total_msrp; fallback: suma de line_total de todas las filas.
 */
export function snapshotTotalMsrp(snapshot: BOMPreviewSnapshot | undefined | null): number {
  if (!snapshot) return 0;
  if (typeof snapshot.totals?.total_msrp === 'number') return snapshot.totals.total_msrp;
  return flattenSnapshotItems(snapshot).reduce((sum, row) => sum + (row.isChild ? 0 : row.line_total), 0);
}

/**
 * Verifica si el snapshot es válido para renderizar (version '1', items no vacíos).
 */
export function isValidSnapshot(snapshot: unknown): snapshot is BOMPreviewSnapshot {
  const s = snapshot as BOMPreviewSnapshot;
  return !!(s?.version) && Array.isArray(s?.items) && s.items.length > 0;
}
