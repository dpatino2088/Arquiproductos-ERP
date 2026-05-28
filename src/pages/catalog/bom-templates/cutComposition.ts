import type { BOMComponentDraft } from './types';

export type Side = 'left' | 'right' | 'intermediate';

export interface CompositionPart {
  componentId: string;
  role: string;
  sku: string;
  /** Per-instance delta in mm (delta_x_mm or delta_y_mm depending on cuttable axis). */
  delta: number;
  /** Number of physical instances on this side (already split for shared roles). */
  qtyPerSide: number;
  /** delta * qtyPerSide. */
  totalPerSide: number;
  /** Optional condition info — used for variant grouping. */
  conditionKey?: string;
  conditionValue?: string;
  /** True when this part comes from a child of a deductor (indented in UI). */
  fromChild?: boolean;
  parentRole?: string;
}

export interface VariantGroup {
  /** Unique key inside a side (role + condition_key). */
  groupKey: string;
  role: string;
  conditionKey: string;
  options: {
    conditionValue: string;
    sku: string;
    delta: number;
    qtyPerSide: number;
    totalPerSide: number;
    componentId: string;
  }[];
}

export interface SideData {
  side: Side;
  /** Non-variant parts (unconditional + multi_panel + optional). */
  parts: CompositionPart[];
  /** Variant groups (alternatives such as motor_item_id, gear_ratio). */
  variants: VariantGroup[];
  /** Sum of `parts.totalPerSide` (variants are added with the selected option separately). */
  baseTotal: number;
}

export interface CompositionByCuttable {
  cuttableId: string;
  cuttableRole: string;
  cuttableSku: string;
  axis: 'width' | 'height';
  left: SideData;
  intermediate: SideData;
  right: SideData;
}

const DRIVE_KEYWORDS = ['motor', 'drive', 'clutch', 'gear'];
const ADAPTER_KEYWORDS = ['adapter'];
const IDLER_KEYWORDS = ['idler'];
const BRACKET_KEYWORDS = ['bracket'];
const INTERMEDIATE_KEYWORDS = ['intermediate', 'connector', 'pin'];
const ENDPLUG_KEYWORDS = ['end cap', 'endcap', 'end plug', 'endplug'];

const NEUTRAL_CONDITIONS = new Set(['', 'multi_panel', 'optional']);

function normRole(role: string | null | undefined): string {
  return String(role || '').toLowerCase().replace(/[_-]+/g, ' ').trim();
}

function matchesAny(role: string, keywords: string[]): boolean {
  return keywords.some(k => role.includes(k));
}

/**
 * Decide which side of the diagram a deduction lives on.
 * - 'shared' = lives on BOTH sides (typically brackets, qty=2 → 1 each side).
 */
function getSideForRole(
  role: string,
  parentRole: string | null | undefined,
): Side | 'shared' {
  const r = normRole(role);
  const pr = normRole(parentRole);

  if (matchesAny(r, INTERMEDIATE_KEYWORDS) && !matchesAny(r, BRACKET_KEYWORDS)) {
    return 'intermediate';
  }
  if (matchesAny(r, INTERMEDIATE_KEYWORDS) && matchesAny(r, BRACKET_KEYWORDS)) {
    return 'intermediate';
  }
  if (matchesAny(r, DRIVE_KEYWORDS) || matchesAny(r, ADAPTER_KEYWORDS)) return 'left';
  if (matchesAny(r, IDLER_KEYWORDS)) return 'right';
  if (matchesAny(r, BRACKET_KEYWORDS)) return 'shared';

  if (matchesAny(r, ENDPLUG_KEYWORDS)) {
    if (matchesAny(pr, BRACKET_KEYWORDS)) return 'shared';
    if (matchesAny(pr, DRIVE_KEYWORDS) || matchesAny(pr, ADAPTER_KEYWORDS)) return 'left';
    if (matchesAny(pr, IDLER_KEYWORDS)) return 'right';
    return 'right';
  }

  if (pr) {
    return getSideForRole(pr, null);
  }
  return 'right';
}

function getDeltaForAxis(
  c: BOMComponentDraft,
  axis: 'width' | 'height',
): number {
  const ci = c.catalog_item;
  if (!ci) return 0;
  const v = axis === 'height' ? ci.delta_y_mm : ci.delta_x_mm;
  return Number(v ?? 0);
}

function affectsCuttable(
  c: BOMComponentDraft,
  cuttableRole: string,
  treatNullAsMatch: boolean,
): boolean {
  const ar = (c.affects_role || '').trim();
  if (!ar) return treatNullAsMatch;
  return ar
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .includes(cuttableRole);
}

function isConditional(c: BOMComponentDraft): boolean {
  if (c.condition_key && c.condition_key.trim() !== '') return true;
  if (c.is_required === false) return true;
  if (normRole(c.component_role).includes('intermediate')) return true;
  return false;
}

function condKey(c: BOMComponentDraft): string {
  const ck = (c.condition_key || '').trim();
  if (ck) return ck;
  if (c.is_required === false) return 'optional';
  if (normRole(c.component_role).includes('intermediate')) return 'multi_panel';
  return '';
}

function condValue(c: BOMComponentDraft): string {
  const cv = (c.condition_value || '').trim();
  if (cv) return cv;
  if (c.is_required === false) return 'true';
  if (normRole(c.component_role).includes('intermediate')) return 'true';
  return '';
}

function isVariantContribution(c: BOMComponentDraft): boolean {
  const k = condKey(c);
  return k !== '' && !NEUTRAL_CONDITIONS.has(k);
}

interface RawContribution {
  component: BOMComponentDraft;
  parent: BOMComponentDraft | null;
  side: Side | 'shared';
  delta: number;
  qty: number;
}

function pushPart(
  side: SideData,
  raw: RawContribution,
  qtyPerSide: number,
): void {
  const sku = raw.component.catalog_item?.sku || '?';
  const role = raw.component.component_role || '';
  const totalPerSide = qtyPerSide * raw.delta;

  if (isVariantContribution(raw.component)) {
    const ck = condKey(raw.component);
    const groupKey = `${normRole(role)}|${ck}`;
    let group = side.variants.find(v => v.groupKey === groupKey);
    if (!group) {
      group = { groupKey, role, conditionKey: ck, options: [] };
      side.variants.push(group);
    }
    group.options.push({
      conditionValue: condValue(raw.component),
      sku,
      delta: raw.delta,
      qtyPerSide,
      totalPerSide,
      componentId: raw.component.id,
    });
    return;
  }

  side.parts.push({
    componentId: raw.component.id,
    role,
    sku,
    delta: raw.delta,
    qtyPerSide,
    totalPerSide,
    conditionKey: condKey(raw.component) || undefined,
    conditionValue: condValue(raw.component) || undefined,
    fromChild: raw.parent !== null,
    parentRole: raw.parent?.component_role || undefined,
  });
  side.baseTotal = round2(side.baseTotal + totalPerSide);
}

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;

function newSide(side: Side): SideData {
  return { side, parts: [], variants: [], baseTotal: 0 };
}

/**
 * Build a per-cuttable composition view from the flat BOM components list.
 * Mirrors the `compute_template_cut_breakdown` SQL logic but exposes the
 * per-component pieces (no aggregation) so the UI can render readable
 * "bracket(3) + end_cap(2) + adapter(2) + motor(15) = 22 mm" expressions.
 */
export function buildCompositionForCuttable(
  components: BOMComponentDraft[],
  cuttable: BOMComponentDraft,
): CompositionByCuttable {
  const role = cuttable.component_role || '';
  const cutAxisRaw = (cuttable.cut_axis || '').toLowerCase();
  const heightRoles = ['side_channel', 'chain', 'belt', 'brush'];
  const axis: 'width' | 'height' =
    cutAxisRaw === 'height' || heightRoles.includes(role) ? 'height' : 'width';

  const result: CompositionByCuttable = {
    cuttableId: cuttable.id,
    cuttableRole: role,
    cuttableSku: cuttable.catalog_item?.sku || '?',
    axis,
    left: newSide('left'),
    intermediate: newSide('intermediate'),
    right: newSide('right'),
  };

  const childrenByParent = new Map<string, BOMComponentDraft[]>();
  for (const c of components) {
    if (c.parent_component_id) {
      const arr = childrenByParent.get(c.parent_component_id) || [];
      arr.push(c);
      childrenByParent.set(c.parent_component_id, arr);
    }
  }

  const addContribution = (raw: RawContribution) => {
    const target =
      raw.side === 'shared'
        ? null
        : raw.side === 'left'
          ? result.left
          : raw.side === 'right'
            ? result.right
            : result.intermediate;

    if (target) {
      pushPart(target, raw, raw.qty);
    } else {
      // shared → split into halves on left and right (each gets 1 instance per pair)
      const halfQty = raw.qty / 2;
      pushPart(result.left, raw, halfQty);
      pushPart(result.right, raw, halfQty);
    }
  };

  for (const top of components) {
    if (top.parent_component_id) continue;
    if (top.id === cuttable.id) continue;

    const isAffectingCuttable = affectsCuttable(top, role, false);

    if (isAffectingCuttable) {
      const delta = getDeltaForAxis(top, axis);
      const qty = Number(top.qty_value || 1);
      if (delta !== 0) {
        addContribution({
          component: top,
          parent: null,
          side: getSideForRole(top.component_role || '', null),
          delta,
          qty,
        });
      }
      const kids = childrenByParent.get(top.id) || [];
      for (const kid of kids) {
        if (!affectsCuttable(kid, role, true)) continue;
        const kDelta = getDeltaForAxis(kid, axis);
        if (kDelta === 0) continue;
        const kQty = Number(kid.qty_value || 1);
        const parentSide = getSideForRole(top.component_role || '', null);
        const childSide = getSideForRole(kid.component_role || '', top.component_role);
        const finalSide = childSide === 'shared' && parentSide !== 'shared' ? parentSide : childSide;
        addContribution({
          component: kid,
          parent: top,
          side: finalSide,
          delta: kDelta,
          qty: parentSide === 'shared' ? kQty : kQty,
        });
      }
    }
  }

  const ownChildren = childrenByParent.get(cuttable.id) || [];
  for (const oc of ownChildren) {
    const ocDelta = getDeltaForAxis(oc, axis);
    if (ocDelta === 0) continue;
    const ocQty = Number(oc.qty_value || 1);
    addContribution({
      component: oc,
      parent: cuttable,
      side: getSideForRole(oc.component_role || '', null),
      delta: ocDelta,
      qty: ocQty,
    });
  }

  return result;
}

/**
 * Compute the total deduction for a side, picking the selected option for
 * each variant group. Returns mm.
 */
export function computeSideTotal(
  side: SideData,
  selectedVariants: Record<string, string>,
): number {
  let total = side.baseTotal;
  for (const group of side.variants) {
    if (!group.options.length) continue;
    const selected = selectedVariants[group.groupKey] ?? group.options[0].conditionValue;
    const opt = group.options.find(o => o.conditionValue === selected) || group.options[0];
    total = round2(total + opt.totalPerSide);
  }
  return round2(total);
}

/**
 * Pretty-print a side composition as: "bracket 3 + end_cap 2 + adapter 2 + motor 15"
 */
export function formatSideCompositionParts(
  side: SideData,
  selectedVariants: Record<string, string>,
): { label: string; sku: string; value: number; isVariantSelector?: VariantGroup }[] {
  const items: { label: string; sku: string; value: number; isVariantSelector?: VariantGroup }[] = [];
  for (const p of side.parts) {
    items.push({ label: p.role || 'part', sku: p.sku, value: round2(p.totalPerSide) });
  }
  for (const group of side.variants) {
    if (!group.options.length) continue;
    const selected = selectedVariants[group.groupKey] ?? group.options[0].conditionValue;
    const opt = group.options.find(o => o.conditionValue === selected) || group.options[0];
    items.push({
      label: group.role || 'variant',
      sku: opt.sku,
      value: round2(opt.totalPerSide),
      isVariantSelector: group,
    });
  }
  return items;
}
