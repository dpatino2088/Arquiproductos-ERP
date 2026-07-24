/**
 * BOM role ↔ quantity conventions for edge brackets, intermediates, and mounting clips.
 *
 * Important: BOM Qty is catalog-SKU consumption, not "physical ends".
 * - Individual bracket SKU → fixed Qty 2 (L + R pieces)
 * - Pair/kit SKU → fixed Qty 1 (one kit covers both ends; cut preview expands ends)
 * - Intermediate → per_joint (N−1)
 * - Mounting clip → per_spacing (W / spacing, min 2)
 */

import { normalizeRole } from '../../../lib/bom/roles';
import type { BOMQtyType } from './types';

export type BracketSoldAs = 'individual' | 'pair_kit';

export interface RoleQtySuggestion {
  qty_type: BOMQtyType;
  qty_value: number | null;
  qty_spacing_mm: number | null;
  qty_min: number | null;
  /** When role=bracket, which consumption mode the suggestion represents */
  bracket_sold_as?: BracketSoldAs;
  hint: string;
}

const PAIR_KIT_PURCHASE_UNITS = new Set(['pair', 'kit']);

/** Detect sold-as pair/kit from catalog purchase unit (not bulk box packaging). */
export function isCatalogSoldAsPairKit(item: {
  purchase_uom?: string | null;
  purchase_unit?: string | null;
  units_per_purchase_unit?: number | null;
} | null | undefined): boolean {
  if (!item) return false;
  const unit = String(item.purchase_uom || item.purchase_unit || '')
    .trim()
    .toLowerCase();
  if (PAIR_KIT_PURCHASE_UNITS.has(unit)) return true;
  // set of 2 physical pieces packaged as one sellable unit
  if (unit === 'set' && Number(item.units_per_purchase_unit) === 2) return true;
  return false;
}

export function bracketSoldAsFromQty(qtyValue: number | null | undefined): BracketSoldAs {
  return Number(qtyValue) === 1 ? 'pair_kit' : 'individual';
}

export function qtyForBracketSoldAs(soldAs: BracketSoldAs): number {
  return soldAs === 'pair_kit' ? 1 : 2;
}

export function suggestQtyForRole(
  role: string | null | undefined,
  catalogItem?: {
    purchase_uom?: string | null;
    purchase_unit?: string | null;
    units_per_purchase_unit?: number | null;
  } | null,
): RoleQtySuggestion | null {
  const r = normalizeRole(role) || '';

  if (r === 'bracket' || r === 'brackets') {
    const soldAs: BracketSoldAs = isCatalogSoldAsPairKit(catalogItem) ? 'pair_kit' : 'individual';
    const qty = qtyForBracketSoldAs(soldAs);
    return {
      qty_type: 'fixed',
      qty_value: qty,
      qty_spacing_mm: null,
      qty_min: null,
      bracket_sold_as: soldAs,
      hint:
        soldAs === 'pair_kit'
          ? 'Pair/kit SKU: consume Qty 1 (covers L+R). Cut preview still applies both ends.'
          : 'Individual pieces: consume Qty 2 (left + right). Use Qty 1 only if this SKU is a pair/kit.',
    };
  }

  if (r === 'intermediate_bracket' || r.startsWith('intermediate')) {
    return {
      qty_type: 'per_joint',
      qty_value: 1,
      qty_spacing_mm: null,
      qty_min: null,
      hint: 'Intermediate: Qty = panels − 1 (shared between adjacent panels). 1 panel → 0.',
    };
  }

  if (r === 'mounting_clip') {
    return {
      qty_type: 'per_spacing',
      qty_value: 1,
      qty_spacing_mm: 500,
      qty_min: 2,
      hint: 'Mounting clip: CEIL(width ÷ spacing), minimum 2 (e.g. every 500 mm ≈ W÷0.50 m).',
    };
  }

  return null;
}

/** Visual subgroups inside SHARED — does not change placement_section. */
export type SharedRoleFamily =
  | 'edge_brackets'
  | 'intermediate'
  | 'mounting'
  | 'headbox'
  | 'other';

export function getSharedRoleFamily(role: string | null | undefined): SharedRoleFamily {
  const r = normalizeRole(role) || '';
  if (r === 'bracket' || r === 'brackets' || r === 'sub_bracket') return 'edge_brackets';
  if (r.includes('intermediate')) return 'intermediate';
  if (r === 'mounting_clip' || r === 'mount_profile' || r === 'chain_clip') return 'mounting';
  if (r === 'headbox' || r === 'cassette' || r === 'top_rail') return 'headbox';
  return 'other';
}

export const SHARED_FAMILY_ORDER: SharedRoleFamily[] = [
  'headbox',
  'edge_brackets',
  'intermediate',
  'mounting',
  'other',
];

export const SHARED_FAMILY_LABELS: Record<SharedRoleFamily, string> = {
  headbox: 'SHARED · Headbox / Housing',
  edge_brackets: 'SHARED · Edge Brackets (L/R)',
  intermediate: 'SHARED · Intermediate (N−1)',
  mounting: 'SHARED · Mounting Clips (spacing)',
  other: 'SHARED · Other',
};
