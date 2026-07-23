/**
 * Lightweight "assemble" helpers for BOM cut preview.
 * Pick one option per hardware group so the breakdown validates a single
 * configuration — not the sum of every mutually-exclusive choice in the BOM.
 *
 * Naming: product-facing fields stay stable across all product lines.
 *   Drive   = motor OR manual clutch/mechanism (one picker)
 *   Side    = left / right for that drive
 *   Bracket / Headbox / Panels = same everywhere
 */
import type { BOMComponentDraft } from './types';

/** How a Drive option maps to the cut RPC / condition keys. */
export type DriveKind = 'motor' | 'manual';

export type PreviewOption = {
  value: string;
  label: string;
  /** Catalog item id when known (preferred for RPC motor_item_id). */
  catalogItemId?: string | null;
  sku?: string | null;
  /** Only for Drive group: motor vs manual clutch. */
  driveKind?: DriveKind;
};

export type PreviewOptionGroup = {
  key: 'drive' | 'bracket' | 'headbox';
  label: string;
  /** When true, the dropdown includes a "None" choice (optional headbox). */
  allowNone?: boolean;
  options: PreviewOption[];
};

function normRole(role: string | null | undefined): string {
  return String(role || '').toLowerCase().replace(/[_-]+/g, ' ').trim();
}

function skuOf(c: BOMComponentDraft): string {
  return String(c.catalog_item?.sku || '').trim();
}

function labelOf(c: BOMComponentDraft, fallback: string): string {
  const ci = c.catalog_item;
  if (ci?.name && ci?.sku) return `${ci.name}`;
  if (ci?.sku) return ci.sku;
  if (ci?.name) return ci.name;
  return fallback;
}

/** Top-level parents only. */
function topLevel(components: BOMComponentDraft[]): BOMComponentDraft[] {
  return components.filter((c) => !c.parent_component_id);
}

function isDriveRole(role: string | null | undefined): boolean {
  const r = normRole(role);
  return r === 'motor' || r === 'drive' || r === 'clutch';
}

/**
 * Build pick-one groups from the BOM.
 * - Drive: motors (motor_item_id / role=motor) and/or manual mechanisms
 *   (gear_ratio / role=drive) — one stable "Drive" field for every product
 * - Brackets: 2+ distinct role=bracket SKUs → pick one
 * - Headbox: role headbox|cassette (optional → allow None)
 *
 * subtract/add SUM on the cut; info stays visible but does not change mm.
 */
export function derivePreviewOptionGroups(components: BOMComponentDraft[]): PreviewOptionGroup[] {
  const tops = topLevel(components);
  const groups: PreviewOptionGroup[] = [];

  // --- Drive (motorized + manual — same field everywhere) ---
  const motorByCondition = tops.filter((c) => c.condition_key === 'motor_item_id');
  const motorByRole = tops.filter((c) => normRole(c.component_role) === 'motor');
  const motorSource = motorByCondition.length > 0 ? motorByCondition : motorByRole;

  const manualByCondition = tops.filter((c) => c.condition_key === 'gear_ratio');
  const manualByRole = tops.filter((c) => {
    const r = normRole(c.component_role);
    return r === 'drive' || r === 'clutch';
  });
  const manualSource = manualByCondition.length > 0 ? manualByCondition : manualByRole;

  {
    const seen = new Set<string>();
    const options: PreviewOption[] = [];

    for (const c of motorSource) {
      const value = (c.condition_key === 'motor_item_id'
        ? (c.condition_value || skuOf(c) || c.component_item_id)
        : (skuOf(c) || c.component_item_id || c.id)
      )?.trim();
      if (!value || seen.has(`motor:${value}`)) continue;
      seen.add(`motor:${value}`);
      options.push({
        value,
        label: labelOf(c, value),
        catalogItemId: c.component_item_id,
        sku: skuOf(c) || value,
        driveKind: 'motor',
      });
    }

    for (const c of manualSource) {
      const value = (
        c.condition_key === 'gear_ratio'
          ? (c.condition_value || skuOf(c) || c.component_item_id || c.id)
          : (skuOf(c) || c.component_item_id || c.id)
      ).trim();
      if (!value || seen.has(`manual:${value}`)) continue;
      seen.add(`manual:${value}`);
      const gear = c.condition_key === 'gear_ratio' && c.condition_value
        ? String(c.condition_value)
        : null;
      const base = labelOf(c, value);
      options.push({
        value,
        label: gear && !base.includes(gear) ? `${base} (${gear})` : base,
        catalogItemId: c.component_item_id,
        sku: skuOf(c) || value,
        driveKind: 'manual',
      });
    }

    if (options.length > 0) {
      groups.push({ key: 'drive', label: 'Drive', options });
    }
  }

  // --- Bracket system ---
  const brackets = tops.filter((c) => {
    const r = normRole(c.component_role);
    return r === 'bracket' || r === 'brackets';
  });
  {
    const seen = new Set<string>();
    const options: PreviewOption[] = [];
    for (const c of brackets) {
      const value = (
        (c.condition_key && c.condition_value)
          ? c.condition_value
          : (skuOf(c) || c.component_item_id || c.id)
      ).trim();
      if (!value || seen.has(value)) continue;
      seen.add(value);
      options.push({
        value,
        label: labelOf(c, value),
        catalogItemId: c.component_item_id,
        sku: skuOf(c) || value,
      });
    }
    if (options.length >= 2) {
      groups.push({ key: 'bracket', label: 'Brackets', options });
    }
  }

  // --- Headbox / cassette ---
  const headboxes = tops.filter((c) => {
    const r = normRole(c.component_role);
    return r === 'headbox' || r === 'cassette';
  });
  if (headboxes.length > 0) {
    const seen = new Set<string>();
    const options: PreviewOption[] = [];
    let anyOptional = false;
    for (const c of headboxes) {
      if (c.is_required === false) anyOptional = true;
      const value = skuOf(c) || c.component_item_id || c.id;
      if (!value || seen.has(value)) continue;
      seen.add(value);
      options.push({
        value,
        label: labelOf(c, value),
        catalogItemId: c.component_item_id,
        sku: skuOf(c) || value,
      });
    }
    if (options.length > 0) {
      groups.push({
        key: 'headbox',
        label: 'Headbox',
        allowNone: anyOptional || options.length > 1,
        options,
      });
    }
  }

  return groups;
}

export type PreviewAssembleSelection = {
  /** Selected Drive option value (motor id / gear_ratio / SKU). */
  drive?: string;
  bracket?: string;
  /** null = None (optional headbox off); undefined = no group / leave as-is */
  headbox?: string | null;
};

/** Resolve the selected Drive option from groups + selection. */
export function selectedDriveOption(
  selection: PreviewAssembleSelection,
  groups: PreviewOptionGroup[],
): PreviewOption | undefined {
  const g = groups.find((x) => x.key === 'drive');
  if (!g || !selection.drive) return undefined;
  return g.options.find((o) => o.value === selection.drive);
}

function deductionSku(d: { sku?: string | null }): string {
  return String(d.sku || '').trim().toUpperCase();
}

function deductionRole(d: { role?: string | null }): string {
  return normRole(d.role);
}

function isBracketRole(role: string | null | undefined): boolean {
  const r = normRole(role);
  return r === 'bracket' || r === 'brackets';
}

/**
 * Catalog `delta_x_mm` is always ONE physical piece.
 *
 * Both-ends brackets (placement shared → position edge):
 * - qty=2 pieces → 1 full delta per side (total 2×delta) ✓
 * - qty=1         → treated as a PAIR/KIT (still 1 full delta per side, total 2×delta)
 *                  so we never paint 2.5mm from a 5mm unit.
 *
 * Legacy `cut_delta_scope=per_side` already doubled `delta` in SQL; expand qty
 * the same way and expose the per-piece delta for side chips.
 */
export function normalizeBothEndsBracketDeduction(d: {
  role?: string | null;
  position?: string | null;
  scope?: string | null;
  qty?: number | null;
  delta?: number | null;
  total?: number | null;
}): { qty: number; delta: number; total: number } {
  const qty = Math.max(1, Number(d.qty || 1));
  const delta = Math.abs(Number(d.delta || 0));
  const total = Math.abs(Number(d.total || delta * qty));
  const scope = String(d.scope || 'per_item').toLowerCase();
  const pos = String(d.position || '').toLowerCase();
  const bothEnds = pos === 'edge';

  if (!isBracketRole(d.role) || !bothEnds || delta <= 0) {
    return { qty, delta, total };
  }

  if (scope === 'per_side') {
    const perPiece = delta / 2;
    return { qty: qty * 2, delta: perPiece, total: perPiece * qty * 2 };
  }

  if (qty === 1) {
    return { qty: 2, delta, total: delta * 2 };
  }

  return { qty, delta, total };
}

/**
 * Filter a DB cut-breakdown so exclusive option groups only keep the selected
 * choice. Recalculates total_deduction / resolved_mm per cuttable.
 */
export function filterBreakdownForAssemble(
  breakdown: any[],
  selection: PreviewAssembleSelection,
  groups: PreviewOptionGroup[],
): any[] {
  if (!Array.isArray(breakdown) || breakdown.length === 0) return breakdown;

  const driveGroup = groups.find((g) => g.key === 'drive');
  const bracketGroup = groups.find((g) => g.key === 'bracket');
  const headboxGroup = groups.find((g) => g.key === 'headbox');

  const driveSkus = new Set(
    (driveGroup?.options ?? []).map((o) => String(o.sku || o.value).toUpperCase()),
  );
  const driveValues = new Set(
    (driveGroup?.options ?? []).map((o) => String(o.value).toUpperCase()),
  );
  const bracketSkus = new Set(
    (bracketGroup?.options ?? []).map((o) => String(o.sku || o.value).toUpperCase()),
  );
  const headboxSkus = new Set(
    (headboxGroup?.options ?? []).map((o) => String(o.sku || o.value).toUpperCase()),
  );

  const selectedDrive = selectedDriveOption(selection, groups);
  const selectedDriveSku = selectedDrive
    ? String(selectedDrive.sku || selectedDrive.value).toUpperCase()
    : null;
  const selectedDriveValue = selection.drive
    ? String(selection.drive).toUpperCase()
    : null;
  const selectedBracket = selection.bracket
    ? String(
        bracketGroup?.options.find((o) => o.value === selection.bracket)?.sku
          || selection.bracket,
      ).toUpperCase()
    : null;
  const selectedHeadbox =
    selection.headbox === null
      ? null
      : selection.headbox
        ? String(
            headboxGroup?.options.find((o) => o.value === selection.headbox)?.sku
              || selection.headbox,
          ).toUpperCase()
        : undefined;

  return breakdown
    .filter((row) => {
      if (selectedHeadbox === null) {
        const r = normRole(row.role);
        if (r === 'headbox' || r === 'cassette') return false;
      }
      return true;
    })
    .map((row) => {
      const deductions = Array.isArray(row.deductions) ? row.deductions : [];
      const filtered = deductions
        .filter((d: any) => {
          const sku = deductionSku(d);
          const role = deductionRole(d);

          // One Drive at a time (motor or manual mechanism).
          if (
            driveGroup
            && selectedDriveSku
            && (isDriveRole(role) || driveSkus.has(sku) || driveValues.has(sku))
          ) {
            return sku === selectedDriveSku
              || (selectedDriveValue != null && sku === selectedDriveValue);
          }

          if (bracketGroup && selectedBracket && (role === 'bracket' || bracketSkus.has(sku))) {
            return sku === selectedBracket;
          }

          if (headboxGroup && (role === 'headbox' || role === 'cassette' || headboxSkus.has(sku))) {
            if (selectedHeadbox === null) return false;
            if (selectedHeadbox) return sku === selectedHeadbox;
          }

          return true;
        })
        .map((d: any) => {
          const n = normalizeBothEndsBracketDeduction(d);
          if (n.qty === Number(d.qty || 1) && n.total === Math.abs(Number(d.total || 0))) return d;
          return { ...d, qty: n.qty, delta: n.delta, total: n.total };
        });

      let total = 0;
      for (const d of filtered) {
        if ((d.mode || 'subtract') === 'info') continue;
        const t = Number(d.total ?? 0);
        const mode = d.mode || 'subtract';
        if (mode === 'add') total -= Math.abs(t);
        else total += Math.abs(t);
      }
      const base = Number(row.base_mm ?? 0);
      const resolved = Number.isFinite(base) ? base - total : row.resolved_mm;

      return {
        ...row,
        deductions: filtered,
        total_deduction: total,
        resolved_mm: resolved,
      };
    });
}

/** Components visible for the current assemble selection (client composition path). */
export function filterComponentsForAssemble(
  components: BOMComponentDraft[],
  selection: PreviewAssembleSelection,
  groups: PreviewOptionGroup[],
): BOMComponentDraft[] {
  const driveGroup = groups.find((g) => g.key === 'drive');
  const bracketGroup = groups.find((g) => g.key === 'bracket');
  const headboxGroup = groups.find((g) => g.key === 'headbox');

  const selectedDrive = selection.drive ?? null;
  const selectedDriveOpt = selectedDriveOption(selection, groups);
  const selectedDriveSku = selectedDriveOpt?.sku || selectedDrive;
  const selectedBracket = selection.bracket ?? null;
  const selectedHeadbox = selection.headbox;

  const driveValues = new Set((driveGroup?.options ?? []).map((o) => o.value));
  const driveSkus = new Set((driveGroup?.options ?? []).map((o) => String(o.sku || o.value)));
  const bracketValues = new Set((bracketGroup?.options ?? []).map((o) => o.value));
  const headboxValues = new Set((headboxGroup?.options ?? []).map((o) => o.value));

  const keepIds = new Set<string>();

  for (const c of components) {
    if (c.parent_component_id) continue;
    const role = normRole(c.component_role);
    const sku = skuOf(c);
    const driveVal =
      c.condition_key === 'motor_item_id' || c.condition_key === 'gear_ratio'
        ? (c.condition_value || sku)
        : sku;
    const bracketVal = sku || c.component_item_id || c.id;
    const headboxVal = sku || c.component_item_id || c.id;

    if (isDriveRole(role) && driveGroup && selectedDrive) {
      const key =
        c.condition_key === 'motor_item_id' || c.condition_key === 'gear_ratio'
          ? (c.condition_value || sku)
          : sku;
      if (key !== selectedDrive && driveVal !== selectedDrive && sku !== selectedDriveSku) continue;
    } else if (
      driveGroup
      && selectedDrive
      && (driveValues.has(driveVal) || driveSkus.has(sku))
      && driveVal !== selectedDrive
      && sku !== selectedDriveSku
    ) {
      continue;
    }

    if ((role === 'bracket' || role === 'brackets') && bracketGroup && selectedBracket) {
      if (bracketVal !== selectedBracket && sku !== selectedBracket) continue;
    } else if (bracketGroup && selectedBracket && bracketValues.has(bracketVal) && bracketVal !== selectedBracket) {
      continue;
    }

    if ((role === 'headbox' || role === 'cassette') && headboxGroup) {
      if (selectedHeadbox === null) continue;
      if (selectedHeadbox && headboxVal !== selectedHeadbox && sku !== selectedHeadbox) continue;
    } else if (headboxGroup && selectedHeadbox !== undefined && headboxValues.has(headboxVal)) {
      if (selectedHeadbox === null) continue;
      if (selectedHeadbox && headboxVal !== selectedHeadbox) continue;
    }

    keepIds.add(c.id);
  }

  for (const c of components) {
    if (c.parent_component_id && keepIds.has(c.parent_component_id)) {
      keepIds.add(c.id);
    }
  }

  return components.filter((c) => {
    if (keepIds.has(c.id)) return true;
    if (c.parent_component_id && keepIds.has(c.parent_component_id)) return true;
    const role = normRole(c.component_role);
    if (isDriveRole(role) && driveGroup) return false;
    if ((role === 'bracket' || role === 'brackets') && bracketGroup) return false;
    if ((role === 'headbox' || role === 'cassette') && headboxGroup) return false;
    if (!c.parent_component_id) return true;
    return false;
  });
}
