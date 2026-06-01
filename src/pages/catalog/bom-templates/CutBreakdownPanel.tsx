import { useMemo, useState } from 'react';
import RollerCutDiagram, { type ChipBreakdown, type HeadboxMode } from './RollerCutDiagram';
import DraperyCutDiagram from './DraperyCutDiagram';
import {
  buildCompositionForCuttable,
  computeSideTotal,
  formatSideCompositionParts,
  type CompositionByCuttable,
  type SideData,
  type VariantGroup,
} from './cutComposition';
import type { BOMComponentDraft } from './types';

interface CutBreakdownPanelProps {
  components: BOMComponentDraft[];
  previewBreakdown?: PreviewBreakdownItem[] | null;
  previewDriveSide?: 'left' | 'right' | 'both' | null;
  previewPanelCount?: number;
  /** When provided, the in-diagram 1/2/3+ selector becomes controlled and notifies the parent. */
  onPreviewPanelCountChange?: (count: number) => void;
  /**
   * Visual mode for the cassette/headbox in the diagram.
   *  - `none` (default): no headbox in BOM.
   *  - `optional`: BOM has headbox/cassette with `is_required=false` (Roller-only case).
   *  - `required`: BOM has headbox/cassette with `is_required=true` (Dual / Triple, or Roller w/ required HB).
   */
  headboxMode?: HeadboxMode;
  /** When true, render the drapery TRACK diagram instead of the roller panel diagram. */
  isDrapery?: boolean;
  /** Master-carrier opening direction (drapery only). */
  openingDirection?: 'left' | 'right' | 'center' | null;
}

interface CuttableMeta {
  comp: BOMComponentDraft;
  composition: CompositionByCuttable;
  symbol: string;
}

interface PreviewDeduction {
  role?: string;
  sku?: string;
  delta?: number;
  qty?: number;
  total?: number;
  position?: string;
  mode?: 'subtract' | 'add' | 'info' | string;
  condition_key?: string;
  condition_value?: string;
  /** DB: joint-style deduction (N−1 panels); includes qty_type = per_joint */
  intermediate?: boolean;
  qty_type?: string;
}

interface PreviewBreakdownItem {
  role: string;
  label?: string;
  sku?: string;
  axis?: 'width' | 'height' | 'special' | string;
  tolerance_mm?: number;
  resolved_mm?: number;
  /** Base before this cuttable's own deduction (chained from depends_on_role). */
  base_mm?: number;
  /** Base label: 'Width', 'Height', or the chained role name like 'Tube'. */
  base_label?: string;
  total_deduction?: number;
  deductions?: PreviewDeduction[];
}

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;
const normalizeSkuKey = (sku?: string | null) => String(sku || '').trim().toUpperCase();

function normalizeRole(role: string | null | undefined): string {
  return String(role || '').toLowerCase().replace(/[_-]+/g, ' ').trim();
}

function isCuttable(c: BOMComponentDraft): boolean {
  const mb = (c.catalog_item?.measure_basis || '').toLowerCase();
  return mb === 'linear' || mb === 'area';
}

function getBaseSymbol(comp: BOMComponentDraft, axis: 'width' | 'height'): string {
  const dep = (comp.depends_on_role || '').trim();
  if (dep) {
    if (dep.toLowerCase().includes('tube')) return 'T';
    return dep
      .split('_')
      .map(w => w.charAt(0).toUpperCase())
      .join('');
  }
  return axis === 'height' ? 'H' : 'W';
}

function pickByRole(cuttables: CuttableMeta[], token: string): CuttableMeta | null {
  return cuttables.find(c => normalizeRole(c.comp.component_role).includes(token)) || null;
}

function VariantSelector({
  group,
  selected,
  onSelect,
}: {
  group: VariantGroup;
  selected: string;
  onSelect: (value: string) => void;
}) {
  return (
    <select
      value={selected}
      onChange={(e) => onSelect(e.target.value)}
      className="text-[10px] font-mono bg-white border border-slate-300 rounded px-1 py-px hover:border-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-400"
      title={`${group.role} variant (${group.conditionKey})`}
    >
      {group.options.map((o) => (
        <option key={o.conditionValue} value={o.conditionValue}>
          {o.sku} ({o.totalPerSide}mm)
        </option>
      ))}
    </select>
  );
}

function BreakdownLine({
  side,
  selectedVariants,
  onSelectVariant,
  emptyLabel = 'No deductions',
}: {
  side: SideData;
  selectedVariants: Record<string, string>;
  onSelectVariant: (groupKey: string, value: string) => void;
  emptyLabel?: string;
}) {
  const parts = formatSideCompositionParts(side, selectedVariants);
  if (parts.length === 0) {
    return <div className="text-[11px] text-slate-300 italic">{emptyLabel}</div>;
  }
  return (
    <div className="space-y-1">
      {parts.map((p, idx) => (
        <div key={`${p.label}-${p.sku}-${idx}`} className="flex items-center justify-between gap-2 text-[11px]">
          <span className="text-slate-600 font-medium truncate">{p.label}</span>
          {p.isVariantSelector ? (
            <span className="inline-flex items-center gap-1 shrink-0">
              <VariantSelector
                group={p.isVariantSelector}
                selected={selectedVariants[p.isVariantSelector.groupKey] ?? p.isVariantSelector.options[0]?.conditionValue ?? ''}
                onSelect={(v) => onSelectVariant(p.isVariantSelector!.groupKey, v)}
              />
              <span className="font-mono font-semibold text-slate-800">{p.value}mm</span>
            </span>
          ) : (
            <span className="font-mono font-semibold text-slate-800 shrink-0">{p.value}mm</span>
          )}
        </div>
      ))}
    </div>
  );
}

function sideBreakdown(side: SideData, selectedVariants: Record<string, string>): ChipBreakdown[] {
  const parts = formatSideCompositionParts(side, selectedVariants);
  return parts.map((p) => ({ label: p.label || 'part', sku: p.sku, value: p.value }));
}

function prettifyRole(role: string | undefined): string {
  return normalizeRole(role).replace(/\b\w/g, c => c.toUpperCase()) || 'Part';
}

function mapSectionToPosition(section: string | null | undefined): string | null {
  const s = String(section || '').toLowerCase();
  if (s === 'drive') return 'drive_side';
  if (s === 'passive') return 'passive_side';
  if (s === 'shared') return 'edge';
  // A cuttable that deducts another cuttable (e.g. side_channel → bottom_channel)
  // is physically at the LEFT and RIGHT edges (not centered): one rail per side.
  // Routing it as 'edge' splits the total half/half between left and right panels,
  // which is what the diagram needs to show per-panel chips.
  if (s === 'cuttable') return 'edge';
  return null;
}

function inferPositionFromRole(role: string | null | undefined): string | null {
  const r = normalizeRole(role || '');
  if (!r) return null;
  if (r.includes('intermediate') || r.includes('interconnect') || r.includes('joint')) return 'shared';
  if (r.includes('motor') || r.includes('drive') || r.includes('chain')) return 'drive_side';
  if (r.includes('end plug') || r.includes('idler') || r.includes('bearing') || r.includes('adapter')) return 'passive_side';
  return null;
}

function isIntermediateRole(role: string | null | undefined): boolean {
  const r = normalizeRole(role || '');
  if (!r) return false;
  return r.includes('intermediate') || r.includes('interconnect') || r.includes('joint');
}

function usesJointPanelDeduction(d: PreviewDeduction): boolean {
  if (d.intermediate === true) return true;
  const qt = String(d.qty_type || '').toLowerCase();
  if (qt === 'per_joint') return true;
  return isIntermediateRole(d.role);
}

type ChildContrib = { role: string; sku: string; name?: string; contribDx: number; contribDy: number };

function splitPreviewSides(
  item: PreviewBreakdownItem,
  driveSide: 'left' | 'right' | 'both' | null | undefined,
  sectionByRoleSku: Map<string, string>,
  sectionByRole: Map<string, string>,
  catalogDeltaByRoleSku: Map<string, { dx: number; dy: number }>,
  childrenByParentRoleSku: Map<string, ChildContrib[]>,
  panelCount: number,
) {
  const leftRows: ChipBreakdown[] = [];
  const centerRows: ChipBreakdown[] = [];
  const rightRows: ChipBreakdown[] = [];
  let left = 0;
  let center = 0;
  let right = 0;

  for (const d of item.deductions ?? []) {
    if ((d.mode || 'subtract') === 'info') continue;
    const jointDeduction = usesJointPanelDeduction(d);
    if (jointDeduction && panelCount <= 1) continue; // N-1 rule: one panel => zero intermediates
    const axis = String(item.axis || '').toLowerCase();
    const isHeight = axis === 'height';
    const baseDelta = Math.abs(Number(d.delta || 0));
    let total = Math.abs(Number(d.total || 0));
    const byCatalog = catalogDeltaByRoleSku.get(`${normalizeRole(d.role || '')}|${normalizeSkuKey(d.sku)}`);
    const catalogPerJoint =
      byCatalog
        ? Math.abs(isHeight ? Number(byCatalog.dy || 0) : Number(byCatalog.dx || 0))
        : 0;
    if (jointDeduction) {
      const perJoint =
        catalogPerJoint > 0
          ? catalogPerJoint
          : baseDelta > 0
            ? baseDelta
            : (panelCount > 1 && total > 0 ? total / Math.max(panelCount - 1, 1) : total);
      total = round2(perJoint * Math.max(panelCount - 1, 0));
    }
    if (total === 0) continue;

    // Children of this parent component (looked up by role+sku in BOM).
    // The DB sums them into the parent's delta, so we must split the displayed
    // row into self + per-child contributions to avoid double counting.
    const childKey = `${normalizeRole(d.role || '')}|${normalizeSkuKey(d.sku)}`;
    const childList = childrenByParentRoleSku.get(childKey) || [];
    const childPerInstanceSum = childList.reduce(
      (acc, c) => acc + (isHeight ? c.contribDy : c.contribDx),
      0,
    );
    // Number of "parent instances" that produce this row.
    // Joint case → (N−1) joints. Otherwise → d.qty (defaults to 1).
    const instances = jointDeduction
      ? Math.max(panelCount - 1, 0)
      : Math.max(1, Number(d.qty || 1));
    const parentSelfPerInstance = round2(Math.max(0, baseDelta - childPerInstanceSum));
    const parentSelfTotal = round2(parentSelfPerInstance * instances);
    const childTotals = childList.map((c) => ({
      role: c.role,
      sku: c.sku,
      total: round2((isHeight ? c.contribDy : c.contribDx) * instances),
    }));
    const parentLabel = prettifyRole(d.role);
    const parentSku = d.sku || '?';

    const roleKey = normalizeRole(d.role || '');
    const skuKey = normalizeSkuKey(d.sku);
    const overridePos = mapSectionToPosition(
      sectionByRoleSku.get(`${roleKey}|${skuKey}`) || sectionByRole.get(roleKey) || null,
    );
    const roleHeuristicPos = inferPositionFromRole(d.role);
    let pos = (overridePos || d.position || roleHeuristicPos || 'edge').toLowerCase();
    if (jointDeduction) pos = 'shared';

    // Build the ordered list of (label, sku, totalForRouting) entries for THIS
    // deduction. Each entry will then be expanded by `instances` copies and
    // optionally split half/half by the position routing below.
    const entries: { label: string; sku: string; perInstance: number }[] = [];
    if (parentSelfPerInstance > 0) {
      entries.push({ label: parentLabel, sku: parentSku, perInstance: parentSelfPerInstance });
    }
    for (let i = 0; i < childList.length; i++) {
      const c = childList[i];
      const perInst = isHeight ? c.contribDy : c.contribDx;
      if (perInst > 0) {
        entries.push({ label: `↳ ${prettifyRole(c.role)}`, sku: c.sku, perInstance: round2(perInst) });
      }
    }
    // Edge case: parent had no self-delta and no resolvable children. Fall back
    // to a single row that represents the whole `total` — never silently drop it.
    if (entries.length === 0) {
      entries.push({ label: parentLabel, sku: parentSku, perInstance: round2(total / Math.max(instances, 1)) });
    }

    const pushExpanded = (rows: ChipBreakdown[], factor: number) => {
      for (const e of entries) {
        const v = round2(e.perInstance * factor);
        for (let i = 0; i < instances; i++) rows.push({ label: e.label, sku: e.sku, value: v });
      }
    };

    void parentSelfTotal; // accounted for through entries × instances
    void childTotals;

    if (pos === 'shared') {
      center = round2(center + total);
      pushExpanded(centerRows, 1);
    } else if (pos === 'edge') {
      const half = round2(total / 2);
      left = round2(left + half);
      right = round2(right + half);
      pushExpanded(leftRows, 0.5);
      pushExpanded(rightRows, 0.5);
    } else if (pos === 'drive_side') {
      if (driveSide === 'right') {
        right = round2(right + total);
        pushExpanded(rightRows, 1);
      } else if (driveSide === 'both') {
        const half = round2(total / 2);
        left = round2(left + half);
        right = round2(right + half);
        pushExpanded(leftRows, 0.5);
        pushExpanded(rightRows, 0.5);
      } else {
        left = round2(left + total);
        pushExpanded(leftRows, 1);
      }
    } else if (pos === 'passive_side') {
      if (driveSide === 'right') {
        left = round2(left + total);
        pushExpanded(leftRows, 1);
      } else if (driveSide === 'left') {
        right = round2(right + total);
        pushExpanded(rightRows, 1);
      }
    } else {
      center = round2(center + total);
      pushExpanded(centerRows, 1);
    }
  }

  return { left, center, right, leftRows, centerRows, rightRows };
}

function SummaryCard({
  title,
  side,
  selectedVariants,
  onSelectVariant,
}: {
  title: string;
  side: SideData;
  selectedVariants: Record<string, string>;
  onSelectVariant: (groupKey: string, value: string) => void;
}) {
  const total = round2(computeSideTotal(side, selectedVariants));
  return (
    <div className="rounded-md border border-slate-200 bg-white p-3 h-full flex flex-col">
      <div className="flex items-center justify-between mb-2">
        <h4 className="text-xs font-semibold text-slate-700">{title}</h4>
        <span className="text-[10px] text-slate-400 uppercase tracking-wide">Value</span>
      </div>
      <div className="flex-1 min-h-0">
        <BreakdownLine side={side} selectedVariants={selectedVariants} onSelectVariant={onSelectVariant} />
      </div>
      <div className="mt-3 border-t border-slate-200 pt-2 flex items-center justify-between">
        <span className="text-[11px] font-semibold text-slate-700">Total</span>
        <span className="font-mono text-[12px] font-semibold text-slate-900">{total}mm</span>
      </div>
    </div>
  );
}

export default function CutBreakdownPanel({
  components,
  previewBreakdown,
  previewDriveSide,
  previewPanelCount = 1,
  onPreviewPanelCountChange,
  headboxMode = 'none',
  isDrapery = false,
  openingDirection = null,
}: CutBreakdownPanelProps) {
  const [selectedVariants, setSelectedVariants] = useState<Record<string, string>>({});
  const onSelectVariant = (groupKey: string, value: string) => {
    setSelectedVariants(prev => ({ ...prev, [groupKey]: value }));
  };

  const previewRows = useMemo(() => (previewBreakdown || []).filter(Boolean), [previewBreakdown]);
  const previewTube = useMemo(
    () => previewRows.find((r) => normalizeRole(r.role).includes('tube')),
    [previewRows],
  );
  const previewBottomBar = useMemo(
    () => previewRows.find((r) => normalizeRole(r.role).includes('bottom bar')),
    [previewRows],
  );
  const previewBottomChannel = useMemo(
    () => previewRows.find((r) => normalizeRole(r.role).includes('bottom channel')),
    [previewRows],
  );
  const previewSideChannel = useMemo(
    () => previewRows.find((r) => normalizeRole(r.role).includes('side channel')),
    [previewRows],
  );
  const previewTrack = useMemo(
    () => previewRows.find((r) => normalizeRole(r.role).includes('track')),
    [previewRows],
  );
  const sectionByRoleSku = useMemo(() => {
    const m = new Map<string, string>();
    for (const c of components.filter((x) => !x.parent_component_id)) {
      const roleKey = normalizeRole(c.component_role || '');
      const sku = c.catalog_item?.sku || '';
      const skuKey = normalizeSkuKey(sku);
      if (!roleKey || !skuKey) continue;
      if (c.placement_section) m.set(`${roleKey}|${skuKey}`, c.placement_section);
    }
    return m;
  }, [components]);
  const sectionByRole = useMemo(() => {
    const m = new Map<string, string>();
    for (const c of components.filter((x) => !x.parent_component_id)) {
      const roleKey = normalizeRole(c.component_role || '');
      if (!roleKey || !c.placement_section) continue;
      if (!m.has(roleKey)) m.set(roleKey, c.placement_section);
    }
    return m;
  }, [components]);
  const catalogDeltaByRoleSku = useMemo(() => {
    const m = new Map<string, { dx: number; dy: number }>();
    for (const c of components.filter((x) => !x.parent_component_id)) {
      const roleKey = normalizeRole(c.component_role || '');
      const sku = c.catalog_item?.sku || '';
      const skuKey = normalizeSkuKey(sku);
      if (!roleKey || !skuKey) continue;
      m.set(`${roleKey}|${skuKey}`, {
        dx: Number(c.catalog_item?.delta_x_mm || 0),
        dy: Number(c.catalog_item?.delta_y_mm || 0),
      });
    }
    return m;
  }, [components]);

  // Per-parent children breakdown — used to expose every SKU (parent + children)
  // as its own row in the breakdown panel. Children inherit the parent's
  // placement section, so they get routed to the same side(s) as their parent.
  const childrenByParentRoleSku = useMemo(() => {
    type ChildInfo = {
      role: string;
      sku: string;
      name?: string;
      /** Per parent-instance contribution on the X axis, mm. */
      contribDx: number;
      /** Per parent-instance contribution on the Y axis, mm. */
      contribDy: number;
    };
    const m = new Map<string, ChildInfo[]>();
    const childrenByParentId = new Map<string, BOMComponentDraft[]>();
    for (const c of components) {
      if (!c.parent_component_id) continue;
      const arr = childrenByParentId.get(c.parent_component_id) || [];
      arr.push(c);
      childrenByParentId.set(c.parent_component_id, arr);
    }
    for (const p of components) {
      if (p.parent_component_id) continue;
      const roleKey = normalizeRole(p.component_role || '');
      const skuKey = normalizeSkuKey(p.catalog_item?.sku || '');
      if (!roleKey || !skuKey) continue;
      const kids = childrenByParentId.get(p.id) || [];
      const infos: ChildInfo[] = [];
      for (const k of kids) {
        const ci = k.catalog_item as any;
        if (!ci) continue;
        const scopeMult = String(k.cut_delta_scope || 'per_item').toLowerCase() === 'per_side' ? 2 : 1;
        const qty = Number(k.qty_value || 1);
        const dx = Math.abs(Number(ci.delta_x_mm || 0)) * scopeMult * qty;
        const dy = Math.abs(Number(ci.delta_y_mm || 0)) * scopeMult * qty;
        if (dx === 0 && dy === 0) continue;
        infos.push({
          role: k.component_role || '',
          sku: ci.sku || '?',
          name: ci.name || '',
          contribDx: round2(dx),
          contribDy: round2(dy),
        });
      }
      if (infos.length > 0) m.set(`${roleKey}|${skuKey}`, infos);
    }
    return m;
  }, [components]);

  // ===== Drapery TRACK diagram (single continuous rail, not per-panel) =====
  if (isDrapery && previewTrack) {
    const trackSymbol = previewTrack.axis === 'height' ? 'H' : 'W';

    // End caps are top-level track deductors with an explicit placement_section:
    //   · 'drive'   → motor end
    //   · 'passive' → opposite end
    //   · 'edge'    → manual cap on both ends (split half/half)
    // So the generic side splitter already routes each one to the correct end
    // by placement (no name heuristics needed).
    const trackSides = splitPreviewSides(
      previewTrack,
      previewDriveSide,
      sectionByRoleSku,
      sectionByRole,
      catalogDeltaByRoleSku,
      childrenByParentRoleSku,
      1,
    );

    // Motor end exists when any deduction lands on the drive side.
    const hasMotor = (previewTrack.deductions ?? []).some(
      (d) => String(d.position || '').toLowerCase() === 'drive_side' || normalizeRole(d.role).includes('motor'),
    );
    const motorSide: 'left' | 'right' | null = hasMotor
      ? (previewDriveSide === 'left' ? 'left' : 'right')
      : null;

    const leftMm = trackSides.left;
    const rightMm = trackSides.right;
    const leftRows = trackSides.leftRows;
    const rightRows = trackSides.rightRows;

    return (
      <div className="space-y-3">
        <DraperyCutDiagram
          templateLabel="Drapery Track Diagram"
          trackSymbol={trackSymbol}
          baseMm={Number(previewTrack.base_mm ?? 0) || undefined}
          resolvedMm={Number(previewTrack.resolved_mm ?? 0) || undefined}
          totalDeduction={round2(Number(previewTrack.total_deduction || 0))}
          tolerance={Number(previewTrack.tolerance_mm || 0)}
          leftMm={leftMm}
          rightMm={rightMm}
          leftBreakdown={leftRows}
          rightBreakdown={rightRows}
          motorSide={motorSide}
          opening={openingDirection}
        />

        <div className="rounded-md border border-slate-200 bg-white p-3 space-y-2">
          <div className="text-xs font-semibold text-slate-700">Cut Formulas (DB Source)</div>
          {previewRows.map((r, rowIdx) => {
            const role = normalizeRole(r.role);
            const placement = sectionByRole.get(role) || '';
            if (placement === 'consumable') return null;
            const symbol = r.axis === 'height' ? 'H' : 'W';
            const ownDed = round2(Number(r.total_deduction || 0));
            const resolved = Number(r.resolved_mm ?? 0);
            const isTrack = role.includes('track');
            return (
              <div key={`db-dr-${r.role}-${r.sku || rowIdx}`} className="flex items-start justify-between gap-2 border-b border-slate-100 pb-2 last:border-0 last:pb-0">
                <div className="min-w-0">
                  <div className="text-[11px] font-medium text-slate-700">{r.label || prettifyRole(r.role)}</div>
                  <div className="text-[10px] text-slate-400 font-mono truncate">{r.sku || '?'}</div>
                </div>
                <div className="text-right font-mono text-[11px] text-slate-800">
                  <div>{symbol} - {ownDed}mm</div>
                  {isTrack && resolved > 0 && (
                    <div className="text-[10px] text-slate-400">cut = {resolved}mm</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  if (previewRows.length > 0) {
    const panelCount = Math.max(1, Number(previewPanelCount || 1));
    const tubeSides = previewTube ? splitPreviewSides(previewTube, previewDriveSide, sectionByRoleSku, sectionByRole, catalogDeltaByRoleSku, childrenByParentRoleSku, panelCount) : null;
    const bbSides = previewBottomBar ? splitPreviewSides(previewBottomBar, previewDriveSide, sectionByRoleSku, sectionByRole, catalogDeltaByRoleSku, childrenByParentRoleSku, panelCount) : null;
    const bcSides = previewBottomChannel ? splitPreviewSides(previewBottomChannel, previewDriveSide, sectionByRoleSku, sectionByRole, catalogDeltaByRoleSku, childrenByParentRoleSku, panelCount) : null;
    const scSides = previewSideChannel ? splitPreviewSides(previewSideChannel, previewDriveSide, sectionByRoleSku, sectionByRole, catalogDeltaByRoleSku, childrenByParentRoleSku, panelCount) : null;

    const tubeSymbol = previewTube?.axis === 'height' ? 'H' : 'W';
    const bbSymbol = previewBottomBar?.axis === 'height' ? 'H' : 'W';
    const bcSymbol = previewBottomChannel?.axis === 'height' ? 'H' : 'W';
    const scSymbol = previewSideChannel?.axis === 'height' ? 'H' : 'W';

    const tubeFormulaSingle = previewTube ? `${tubeSymbol} - ${round2(previewTube.total_deduction || 0)}mm` : null;
    const tubeFormulaMulti = previewTube
      ? `${tubeSymbol}/N - ${round2((tubeSides?.left || 0) / 2 + (tubeSides?.right || 0) / 2 + (tubeSides?.center || 0) - Number(previewTube.tolerance_mm || 0))}mm`
      : null;

    return (
      <div className="space-y-3">
        <RollerCutDiagram
          templateLabel="Unified Cut Diagram"
          driveSide={previewDriveSide}
          headboxMode={headboxMode}
          panelCount={panelCount}
          onPanelCountChange={onPreviewPanelCountChange}
          tube={
            previewTube && tubeSides
              ? {
                  symbol: tubeSymbol,
                  tolerance: Number(previewTube.tolerance_mm || 0),
                  leftMm: tubeSides.left,
                  intermediateMm: tubeSides.center,
                  rightMm: tubeSides.right,
                  leftBreakdown: tubeSides.leftRows,
                  intermediateBreakdown: tubeSides.centerRows,
                  rightBreakdown: tubeSides.rightRows,
                  sku: previewTube.sku || '?',
                }
              : undefined
          }
          bottomBar={
            previewBottomBar && bbSides
              ? {
                  symbol: bbSymbol,
                  tolerance: Number(previewBottomBar.tolerance_mm || 0),
                  leftMm: bbSides.left,
                  intermediateMm: bbSides.center,
                  rightMm: bbSides.right,
                  leftBreakdown: bbSides.leftRows,
                  intermediateBreakdown: bbSides.centerRows,
                  rightBreakdown: bbSides.rightRows,
                  sku: previewBottomBar.sku || '?',
                }
              : undefined
          }
          bottomChannel={
            previewBottomChannel && bcSides
              ? {
                  symbol: bcSymbol,
                  tolerance: Number(previewBottomChannel.tolerance_mm || 0),
                  leftMm: bcSides.left,
                  intermediateMm: bcSides.center,
                  rightMm: bcSides.right,
                  leftBreakdown: bcSides.leftRows,
                  intermediateBreakdown: bcSides.centerRows,
                  rightBreakdown: bcSides.rightRows,
                  sku: previewBottomChannel.sku || '?',
                }
              : undefined
          }
          sideChannel={
            previewSideChannel && scSides
              ? {
                  symbol: scSymbol,
                  tolerance: Number(previewSideChannel.tolerance_mm || 0),
                  topMm: scSides.left,
                  bottomMm: scSides.right,
                  topBreakdown: scSides.leftRows,
                  bottomBreakdown: scSides.rightRows,
                  sku: previewSideChannel.sku || '?',
                  qty: 2,
                }
              : undefined
          }
        />

        {previewTube && tubeSides && (
          <div className="rounded-md border border-slate-200 bg-slate-50/40 p-3 space-y-3">
            <div className="text-xs font-semibold text-slate-700">Tube Breakdown (DB Source)</div>
            <div className="grid gap-3 md:grid-cols-3">
              <div className="rounded-md border border-slate-200 bg-white p-3 h-full">
                <div className="text-xs font-semibold text-slate-700 mb-2">Left</div>
                <div className="space-y-1 text-[11px]">
                  {tubeSides.leftRows.map((r, idx) => (
                    <div key={`db-l-${idx}`} className="flex items-center justify-between">
                      <span className="text-slate-600 truncate">{r.label}</span>
                      <span className="font-mono font-semibold text-slate-800">{r.value}mm</span>
                    </div>
                  ))}
                </div>
                <div className="mt-3 border-t border-slate-200 pt-2 flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-slate-700">Total</span>
                  <span className="font-mono text-[12px] font-semibold text-slate-900">{tubeSides.left}mm</span>
                </div>
              </div>
              <div className="rounded-md border border-slate-200 bg-white p-3 h-full">
                <div className="text-xs font-semibold text-slate-700 mb-2">Center</div>
                <div className="space-y-1 text-[11px]">
                  {tubeSides.centerRows.map((r, idx) => (
                    <div key={`db-c-${idx}`} className="flex items-center justify-between">
                      <span className="text-slate-600 truncate">{r.label}</span>
                      <span className="font-mono font-semibold text-slate-800">{r.value}mm</span>
                    </div>
                  ))}
                </div>
                <div className="mt-3 border-t border-slate-200 pt-2 flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-slate-700">Total</span>
                  <span className="font-mono text-[12px] font-semibold text-slate-900">{tubeSides.center}mm</span>
                </div>
              </div>
              <div className="rounded-md border border-slate-200 bg-white p-3 h-full">
                <div className="text-xs font-semibold text-slate-700 mb-2">Right</div>
                <div className="space-y-1 text-[11px]">
                  {tubeSides.rightRows.map((r, idx) => (
                    <div key={`db-r-${idx}`} className="flex items-center justify-between">
                      <span className="text-slate-600 truncate">{r.label}</span>
                      <span className="font-mono font-semibold text-slate-800">{r.value}mm</span>
                    </div>
                  ))}
                </div>
                <div className="mt-3 border-t border-slate-200 pt-2 flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-slate-700">Total</span>
                  <span className="font-mono text-[12px] font-semibold text-slate-900">{tubeSides.right}mm</span>
                </div>
              </div>
            </div>
            <div className="rounded-md border border-slate-200 bg-white p-3 space-y-1.5">
              <div className="text-[11px] font-semibold text-slate-700">Tube Formula</div>
              {tubeFormulaSingle && <div className="text-[11px] text-slate-700 font-mono">Single panel: {tubeFormulaSingle}</div>}
              {tubeFormulaMulti && <div className="text-[11px] text-slate-700 font-mono">Multi panel: {tubeFormulaMulti}</div>}
            </div>
          </div>
        )}

        <div className="rounded-md border border-slate-200 bg-white p-3 space-y-2">
          <div className="text-xs font-semibold text-slate-700">Cut Formulas (DB Source)</div>
          {(() => {
            // Reference axis bases: top-of-chain cuttables for width/height.
            // Used to render cumulative deductions for chained cuttables
            // (e.g. bottom_bar/bottom_channel that depend_on tube).
            const widthRoot = previewRows.find(
              (x) => (x.axis ?? 'width') === 'width' && (x.base_label === 'Width' || !x.base_label),
            );
            const heightRoot = previewRows.find(
              (x) => x.axis === 'height' && (x.base_label === 'Height' || !x.base_label),
            );
            const roleCounts = new Map<string, number>();
            for (const r of previewRows) {
              const k = normalizeRole(r.role);
              roleCounts.set(k, (roleCounts.get(k) || 0) + 1);
            }
            return previewRows.map((r, rowIdx) => {
              const role = normalizeRole(r.role);
              const placement = sectionByRole.get(role) || '';
              if (placement === 'consumable') return null;
              const isAmbiguousRole = (roleCounts.get(role) || 0) > 1;
              const titleLabel = isAmbiguousRole
                ? `${r.label || prettifyRole(r.role)} · ${r.sku || '?'}`
                : (r.label || prettifyRole(r.role));
              const symbol = r.axis === 'height' ? 'H' : 'W';
              const ownDed = round2(Number(r.total_deduction || 0));
              const chained = !!r.base_label && r.base_label !== 'Width' && r.base_label !== 'Height';
              const root = r.axis === 'height' ? heightRoot : widthRoot;
              const rootBase = Number(root?.base_mm ?? 0);
              const resolved = Number(r.resolved_mm ?? 0);
              const cumulativeDed = chained && rootBase > 0
                ? round2(rootBase - resolved)
                : ownDed;
              const isSideChannel = role.includes('side channel');
              const isBottomChannel = role.includes('bottom channel');
              // Side channels run vertically with one piece per side
              // (left + right). The RPC's total_deduction sums BOTH sides,
              // so divide by 2 to expose the per-piece deduction the
              // shop floor actually cuts ("H - 100mm" per side).
              const perPieceDed = isSideChannel ? round2(cumulativeDed / 2) : cumulativeDed;
              // Bottom channel is cut PER PANEL (one piece per panel) and only
              // the outer edges receive the side_channel deduction. Middle
              // panels get W/N - 0. Use the splitter's left/right values which
              // already isolate the edge contributions.
              const bcPerPanelCuts =
                isBottomChannel && panelCount > 1 && bcSides
                  ? Array.from({ length: panelCount }, (_, i) => {
                      const isFirst = i === 0;
                      const isLast = i === panelCount - 1;
                      const leftEdge = isFirst ? bcSides.left : 0;
                      const rightEdge = isLast ? bcSides.right : 0;
                      return round2(leftEdge + rightEdge);
                    })
                  : null;
              return (
                <div key={`db-f-${r.role}-${r.sku || rowIdx}`} className="flex items-start justify-between gap-2 border-b border-slate-100 pb-2 last:border-0 last:pb-0">
                  <div className="min-w-0">
                    <div className="text-[11px] font-medium text-slate-700">{titleLabel}</div>
                    <div className="text-[10px] text-slate-400 font-mono truncate">{r.sku || '?'}</div>
                  </div>
                  <div className="text-right font-mono text-[11px] text-slate-800">
                    <div>{symbol} - {perPieceDed}mm</div>
                    {chained && !isSideChannel && (
                      <div className="text-[10px] text-slate-400">
                        ({r.base_label} - {ownDed}mm)
                      </div>
                    )}
                    {isSideChannel ? (
                      <div className="text-[10px] text-slate-400">x 2 (per side) × N panels</div>
                    ) : bcPerPanelCuts ? (
                      <div className="space-y-0.5 mt-1">
                        {bcPerPanelCuts.map((ded, i) => (
                          <div key={i} className="text-[10px] text-slate-500">
                            Panel {i + 1}: {symbol}/{panelCount} - {ded}mm
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="text-slate-500">{symbol}/N - {perPieceDed}mm</div>
                    )}
                  </div>
                </div>
              );
            });
          })()}
        </div>
      </div>
    );
  }

  const cuttables = useMemo<CuttableMeta[]>(() => {
    return components
      .filter(c => !c.parent_component_id && isCuttable(c))
      .map(c => {
        const composition = buildCompositionForCuttable(components, c);
        return { comp: c, composition, symbol: getBaseSymbol(c, composition.axis) };
      });
  }, [components]);

  const tube = pickByRole(cuttables, 'tube');
  const bottomBar = pickByRole(cuttables, 'bottom bar');
  const sideChannel = pickByRole(cuttables, 'side channel');
  const bottomChannel = pickByRole(cuttables, 'bottom channel');

  const rows = [tube, bottomBar, sideChannel, bottomChannel].filter(Boolean) as CuttableMeta[];
  const tubeLeft = tube ? round2(computeSideTotal(tube.composition.left, selectedVariants)) : 0;
  const tubeCenter = tube ? round2(computeSideTotal(tube.composition.intermediate, selectedVariants)) : 0;
  const tubeRight = tube ? round2(computeSideTotal(tube.composition.right, selectedVariants)) : 0;
  const tubeTol = Number(tube?.comp.cut_delta_mm || 0);
  const tubeDedSingle = round2(tubeLeft + tubeRight - tubeTol);
  const tubeDedMulti = round2(((tubeLeft + tubeRight) / 2) + tubeCenter - tubeTol);

  const formulas = rows.map((r) => {
    const l = computeSideTotal(r.composition.left, selectedVariants);
    const i = computeSideTotal(r.composition.intermediate, selectedVariants);
    const rr = computeSideTotal(r.composition.right, selectedVariants);
    const tol = Number(r.comp.cut_delta_mm || 0);
    const dedSingle = round2(l + rr - tol);
    const dedMulti = round2(((l + rr) / 2) + i - tol);
    const role = normalizeRole(r.comp.component_role);
    const roleLabel = role.replace(/\b\w/g, c => c.toUpperCase());
    const axisSymbol = r.symbol || 'W';
    const formulaSingle = `${axisSymbol} - ${dedSingle}mm`;
    const formulaMulti = `${axisSymbol}/N - ${dedMulti}mm`;
    return {
      key: r.comp.id,
      role,
      roleLabel,
      formulaSingle,
      formulaMulti,
      sku: r.composition.cuttableSku,
    };
  });

  if (!rows.length) {
    return (
      <p className="text-[11px] text-slate-400 italic px-3 py-2">
        No cuttable components configured.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      <RollerCutDiagram
        templateLabel="Unified Cut Diagram"
        headboxMode={headboxMode}
        panelCount={previewPanelCount}
        onPanelCountChange={onPreviewPanelCountChange}
        tube={
          tube
            ? {
                symbol: tube.symbol,
                tolerance: Number(tube.comp.cut_delta_mm || 0),
                leftMm: computeSideTotal(tube.composition.left, selectedVariants),
                intermediateMm: computeSideTotal(tube.composition.intermediate, selectedVariants),
                rightMm: computeSideTotal(tube.composition.right, selectedVariants),
                leftBreakdown: sideBreakdown(tube.composition.left, selectedVariants),
                intermediateBreakdown: sideBreakdown(tube.composition.intermediate, selectedVariants),
                rightBreakdown: sideBreakdown(tube.composition.right, selectedVariants),
                sku: tube.composition.cuttableSku,
              }
            : undefined
        }
        bottomBar={
          bottomBar
            ? {
                symbol: bottomBar.symbol,
                tolerance: Number(bottomBar.comp.cut_delta_mm || 0),
                leftMm: computeSideTotal(bottomBar.composition.left, selectedVariants),
                intermediateMm: computeSideTotal(bottomBar.composition.intermediate, selectedVariants),
                rightMm: computeSideTotal(bottomBar.composition.right, selectedVariants),
                leftBreakdown: sideBreakdown(bottomBar.composition.left, selectedVariants),
                intermediateBreakdown: sideBreakdown(bottomBar.composition.intermediate, selectedVariants),
                rightBreakdown: sideBreakdown(bottomBar.composition.right, selectedVariants),
                sku: bottomBar.composition.cuttableSku,
              }
            : undefined
        }
        bottomChannel={
          bottomChannel
            ? {
                symbol: bottomChannel.symbol,
                tolerance: Number(bottomChannel.comp.cut_delta_mm || 0),
                leftMm: computeSideTotal(bottomChannel.composition.left, selectedVariants),
                intermediateMm: computeSideTotal(bottomChannel.composition.intermediate, selectedVariants),
                rightMm: computeSideTotal(bottomChannel.composition.right, selectedVariants),
                leftBreakdown: sideBreakdown(bottomChannel.composition.left, selectedVariants),
                intermediateBreakdown: sideBreakdown(bottomChannel.composition.intermediate, selectedVariants),
                rightBreakdown: sideBreakdown(bottomChannel.composition.right, selectedVariants),
                sku: bottomChannel.composition.cuttableSku,
              }
            : undefined
        }
        sideChannel={
          sideChannel
            ? {
                symbol: sideChannel.symbol,
                tolerance: Number(sideChannel.comp.cut_delta_mm || 0),
                topMm: computeSideTotal(sideChannel.composition.left, selectedVariants),
                bottomMm: computeSideTotal(sideChannel.composition.right, selectedVariants),
                topBreakdown: sideBreakdown(sideChannel.composition.left, selectedVariants),
                bottomBreakdown: sideBreakdown(sideChannel.composition.right, selectedVariants),
                sku: sideChannel.composition.cuttableSku,
                qty: Number(sideChannel.comp.qty_value || 2),
              }
            : undefined
        }
      />
      {tube && (
        <div className="rounded-md border border-slate-200 bg-slate-50/40 p-3 space-y-3">
          <div className="text-xs font-semibold text-slate-700">Tube Breakdown</div>
          <div className="grid gap-3 md:grid-cols-3">
            <SummaryCard title="Left" side={tube.composition.left} selectedVariants={selectedVariants} onSelectVariant={onSelectVariant} />
            <SummaryCard title="Center" side={tube.composition.intermediate} selectedVariants={selectedVariants} onSelectVariant={onSelectVariant} />
            <SummaryCard title="Right" side={tube.composition.right} selectedVariants={selectedVariants} onSelectVariant={onSelectVariant} />
          </div>
          <div className="rounded-md border border-slate-200 bg-white p-3 space-y-1.5">
            <div className="text-[11px] font-semibold text-slate-700">Tube Formula</div>
            <div className="text-[11px] text-slate-700 font-mono">Single panel: {tube.symbol} - {tubeDedSingle}mm</div>
            <div className="text-[11px] text-slate-700 font-mono">Multi panel: {tube.symbol}/N - {tubeDedMulti}mm</div>
            <div className="text-[10px] text-slate-500 font-mono">
              Left {tubeLeft}mm + Right {tubeRight}mm + Center {tubeCenter}mm (shared) {tubeTol ? `- Tol ${tubeTol}mm` : ''}
            </div>
          </div>
        </div>
      )}

      <div className="rounded-md border border-slate-200 bg-white p-3 space-y-2">
        <div className="text-xs font-semibold text-slate-700">Cut Formulas</div>
        {formulas.map((f) => (
          <div key={f.key} className="flex items-start justify-between gap-2 border-b border-slate-100 pb-2 last:border-0 last:pb-0">
            <div className="min-w-0">
              <div className="text-[11px] font-medium text-slate-700">{f.roleLabel}</div>
              <div className="text-[10px] text-slate-400 font-mono truncate">{f.sku}</div>
            </div>
            <div className="text-right font-mono text-[11px] text-slate-800">
              <div>{f.formulaSingle}</div>
              {f.role.includes('side channel') ? (
                <div className="text-slate-400">Info only</div>
              ) : (
                <div className="text-slate-500">{f.formulaMulti}</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
