import { useState } from 'react';

export interface ChipBreakdown {
  label: string;
  sku: string;
  value: number;
  /** Present in the BOM but does not change the cut (delta_mode=info). */
  info?: boolean;
}

export interface AxisXData {
  symbol: string;
  tolerance: number;
  leftMm: number;
  intermediateMm: number;
  rightMm: number;
  leftBreakdown?: ChipBreakdown[];
  intermediateBreakdown?: ChipBreakdown[];
  rightBreakdown?: ChipBreakdown[];
  sku?: string;
}

export interface AxisYData {
  symbol: string;
  tolerance: number;
  /** Deduction at the top of the channel. */
  topMm: number;
  /** Deduction at the bottom of the channel. */
  bottomMm: number;
  topBreakdown?: ChipBreakdown[];
  bottomBreakdown?: ChipBreakdown[];
  sku?: string;
  qty?: number;
}

/**
 * Headbox / cassette visual mode.
 *  - `none`: BOM has no headbox/cassette → render plain tube + brackets (current default).
 *  - `optional`: headbox exists in BOM but `is_required=false` (Roller-only case).
 *      Render a labelled "OPTIONAL" cassette band above the tube; tube + brackets stay visible.
 *  - `required`: headbox exists in BOM and `is_required=true` (Dual / Triple, or Roller w/ required HB).
 *      Render a solid cassette that wraps tube+brackets (tube hidden visually).
 */
export type HeadboxMode = 'none' | 'optional' | 'required';

export interface RollerCutDiagramProps {
  templateLabel?: string;
  tube?: AxisXData;
  bottomBar?: AxisXData;
  bottomChannel?: AxisXData;
  sideChannel?: AxisYData;
  driveSide?: 'left' | 'right' | 'both' | null;
  headboxMode?: HeadboxMode;
  /**
   * Optional controlled panel count.
   * When provided together with `onPanelCountChange`, the 1/2/3+ selector
   * becomes controlled and the parent receives change events so it can
   * re-run the breakdown calculation against the new panel count.
   */
  panelCount?: number;
  onPanelCountChange?: (count: number) => void;
  /** When false, hide the in-diagram 1/2/3+ tabs (parent owns Panels dropdown). */
  showPanelControls?: boolean;
}

type PanelMode = '1' | '2' | '3+';

function panelCountToMode(n: number | undefined): PanelMode {
  if (!n || n <= 1) return '1';
  if (n === 2) return '2';
  return '3+';
}

function modeToPanelCount(m: PanelMode): number {
  return m === '1' ? 1 : m === '2' ? 2 : 3;
}

const VB_W = 1200;
const VB_H = 700;
const STROKE = '#1f2937';

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;

function buildTooltip(side: string, breakdown: ChipBreakdown[] | undefined, total: number): string {
  if (!breakdown || breakdown.length === 0) return `${side}: ${total} mm`;
  const lines = breakdown.map((b) => {
    if (b.info) return `  ${b.label} (${b.sku}): info (no cut)`;
    return `  ${b.label} (${b.sku}): ${b.value} mm`;
  });
  return `${side}\n${lines.join('\n')}\n  ─────────\n  TOTAL: ${total} mm`;
}

interface ChipProps {
  x: number;
  y: number;
  w?: number;
  h?: number;
  label: string;
  tooltip?: string;
  fontSize?: number;
}

function Chip({ x, y, w = 60, h = 28, label, tooltip, fontSize = 14 }: ChipProps) {
  return (
    <g style={{ cursor: tooltip ? 'help' : 'default' }}>
      {tooltip && <title>{tooltip}</title>}
      <rect x={x} y={y} width={w} height={h} rx={1} fill="#fff" stroke={STROKE} strokeWidth={1.2} />
      <text
        x={x + w / 2}
        y={y + h / 2 + fontSize * 0.34}
        textAnchor="middle"
        fontSize={fontSize}
        fill={STROKE}
        fontFamily="ui-monospace, monospace"
      >
        {label}
      </text>
    </g>
  );
}

function HLine({ x1, x2, y }: { x1: number; x2: number; y: number }) {
  return <line x1={x1} y1={y} x2={x2} y2={y} stroke={STROKE} strokeWidth={0.7} />;
}

export default function RollerCutDiagram({
  templateLabel,
  tube,
  bottomBar,
  bottomChannel,
  sideChannel,
  driveSide,
  headboxMode = 'none',
  panelCount: controlledPanelCount,
  onPanelCountChange,
  showPanelControls = true,
}: RollerCutDiagramProps) {
  const isControlled = typeof controlledPanelCount === 'number' && typeof onPanelCountChange === 'function';
  const [internalMode, setInternalMode] = useState<PanelMode>('1');
  const mode: PanelMode = isControlled
    ? panelCountToMode(controlledPanelCount)
    : internalMode;
  const setMode = (next: PanelMode) => {
    if (isControlled) {
      onPanelCountChange!(modeToPanelCount(next));
    } else {
      setInternalMode(next);
    }
  };
  const panelCount = isControlled ? Math.max(1, controlledPanelCount!) : modeToPanelCount(internalMode);

  const isHeadboxOptional = headboxMode === 'optional';
  const isHeadboxRequired = headboxMode === 'required';
  const hasAnyHeadbox = isHeadboxOptional || isHeadboxRequired;

  // ---- TUBE per-panel chip values ----
  // Per-side intermediate share: `intermediateMm` is the sum across ALL joints
  // (e.g. 15mm × (N−1) panels). Each joint is split 50/50 between its two adjacent panels,
  // so the share that lands on a single side of a single panel is:
  //   intermediateMm / 2 (sides) / jointCount   where jointCount = panelCount − 1
  const jointCount = Math.max(panelCount - 1, 1);
  const tubeSym = tube?.symbol ?? 'W';
  const tubeTol = tube?.tolerance ?? 0;
  const tubeL = tube ? round2(tube.leftMm) : 0;
  const tubeR = tube ? round2(tube.rightMm) : 0;
  const tubeIH = tube ? round2(tube.intermediateMm / (2 * jointCount)) : 0;

  interface PanelChips {
    left: number;
    right: number;
    mid: string;
    midDed: number;
    ttLeft: string;
    ttRight: string;
    ttMid: string;
  }
  const tubePanels: PanelChips[] = [];
  for (let i = 0; i < panelCount; i++) {
    const isFirst = i === 0;
    const isLast = i === panelCount - 1;
    const left = isFirst ? tubeL : tubeIH;
    const right = isLast ? tubeR : tubeIH;
    const ded = round2(left + right - tubeTol);
    const symFrac = panelCount === 1 ? tubeSym : `${tubeSym}/${panelCount}`;
    tubePanels.push({
      left,
      right,
      mid: `${symFrac} − ${ded}`,
      midDed: ded,
      ttLeft: isFirst
        ? buildTooltip('LEFT BRACKET', tube?.leftBreakdown, left)
        : buildTooltip(`SHARED BRACKET (½)`, tube?.intermediateBreakdown, left),
      ttRight: isLast
        ? buildTooltip('RIGHT BRACKET', tube?.rightBreakdown, right)
        : buildTooltip(`SHARED BRACKET (½)`, tube?.intermediateBreakdown, right),
      ttMid: `Panel ${i + 1} tube cut = ${symFrac} − ${left} (left) − ${right} (right)${tubeTol ? ` + ${tubeTol} (tol)` : ''} = ${symFrac} − ${ded} mm`,
    });
  }

  // ---- BOTTOM BAR per-panel chip ----
  const bbSym = bottomBar?.symbol ?? 'W';
  const bbTol = bottomBar?.tolerance ?? 0;
  const bbL = bottomBar ? round2(bottomBar.leftMm) : 0;
  const bbR = bottomBar ? round2(bottomBar.rightMm) : 0;
  const bbIH = bottomBar ? round2(bottomBar.intermediateMm / (2 * jointCount)) : 0;
  const bbBreakdownAll: ChipBreakdown[] = [
    ...(bottomBar?.leftBreakdown ?? []),
    ...(bottomBar?.intermediateBreakdown ?? []),
    ...(bottomBar?.rightBreakdown ?? []),
  ];
  const bbChips: { mid: string; tooltip: string; ded: number }[] = [];
  for (let i = 0; i < panelCount; i++) {
    const left = i === 0 ? bbL : bbIH;
    const right = i === panelCount - 1 ? bbR : bbIH;
    const ded = round2(left + right - bbTol);
    const symFrac = panelCount === 1 ? bbSym : `${bbSym}/${panelCount}`;
    bbChips.push({
      mid: `${symFrac} − ${ded}`,
      tooltip: buildTooltip(`BOTTOM BAR · Panel ${i + 1}`, bbBreakdownAll, ded),
      ded,
    });
  }
  // Hide per-panel dimension annotation (chip + flanking lines) when the
  // bottom bar has no deductions to display. The bar rectangle itself stays
  // visible — only the noisy "W − 0" callout disappears.
  const bbHasAnyDeduction =
    bbChips.some((c) => Math.abs(c.ded) > 0) ||
    bbBreakdownAll.some((b) => Math.abs(Number(b.value || 0)) > 0);

  // Bottom channel and side channel are intentionally not rendered visually in
  // the diagram. They are exposed exclusively through the
  // "Cut Formulas (DB Source)" panel rendered by the parent.
  void bottomChannel;
  void sideChannel;

  // ---- Layout ----
  const PAD_X = 56;
  const B_W = 14;
  const M_LABEL_W = 22;
  const M_LABEL_GAP = 10;

  const reservedRight = M_LABEL_GAP + M_LABEL_W;
  const reservedLeft = M_LABEL_GAP + M_LABEL_W;

  const totalBracketsW = (panelCount + 1) * B_W;
  const availablePanelAreaW = VB_W - 2 * PAD_X - reservedLeft - reservedRight - totalBracketsW;
  const layoutPanelCount = panelCount === 1 ? 2 : panelCount;
  const panelW = availablePanelAreaW / layoutPanelCount;
  const usedPanelAreaW = panelW * panelCount;
  const panelAreaOffsetX = (availablePanelAreaW - usedPanelAreaW) / 2;

  const firstBracketX = PAD_X + reservedLeft + panelAreaOffsetX;

  const bracketXs: number[] = [];
  const panelXs: number[] = [];
  for (let i = 0; i <= panelCount; i++) {
    bracketXs.push(firstBracketX + i * (B_W + panelW));
  }
  for (let i = 0; i < panelCount; i++) {
    panelXs.push(bracketXs[i] + B_W);
  }

  const lastBracketEnd = bracketXs[bracketXs.length - 1] + B_W;
  const mLabelXRight = lastBracketEnd + M_LABEL_GAP;
  const mLabelXLeft = bracketXs[0] - M_LABEL_GAP - M_LABEL_W;
  const effectiveDriveSide: 'left' | 'right' | 'both' =
    driveSide === 'left' || driveSide === 'right' || driveSide === 'both'
      ? driveSide
      : 'right';

  // ---- Vertical positions ----
  // Optional headbox sits ABOVE the tube row as a separate band (img 3, 4).
  // Required headbox WRAPS the tube row entirely (img 1, 2).
  const TOP_CHIP_Y = 18;
  const TOP_CHIP_H = 28;

  const OPT_HB_Y = 60;
  const OPT_HB_H = 26;
  const OPT_HB_GAP = 8;

  const TUBE_Y = isHeadboxOptional ? OPT_HB_Y + OPT_HB_H + OPT_HB_GAP : 86;
  const TUBE_H = 24;
  const BRACKET_Y = TUBE_Y - 6;
  const BRACKET_H = TUBE_H + 12;

  // Required cassette wraps the tube area; bracket "ears" still poke out at edges.
  const REQ_HB_PAD_Y = 6;
  const REQ_HB_Y = BRACKET_Y - REQ_HB_PAD_Y;
  const REQ_HB_H = BRACKET_H + REQ_HB_PAD_Y * 2;

  const WINDOW_GAP = 6;
  const REQ_BRACKET_FOOT_H = 8;
  const WINDOW_Y = isHeadboxRequired
    ? REQ_HB_Y + REQ_HB_H + REQ_BRACKET_FOOT_H + WINDOW_GAP
    : TUBE_Y + TUBE_H + WINDOW_GAP;
  const WINDOW_H = 330;
  const BB_Y = WINDOW_Y + WINDOW_H;
  const BB_H = 14;
  const BB_CHIP_Y = BB_Y + BB_H + 6;

  const NUM_CHIP_W = 50;
  const FORMULA_CHIP_W = 110;

  const dimY = TOP_CHIP_Y + TOP_CHIP_H / 2;
  const bbDimY = BB_CHIP_Y + TOP_CHIP_H / 2;

  // Headbox geometry (spans full bracket area + small overflow on the sides).
  const HB_OVERHANG = 6;
  const HB_LEFT = bracketXs[0] - HB_OVERHANG;
  const HB_RIGHT = lastBracketEnd + HB_OVERHANG;
  const HB_W = HB_RIGHT - HB_LEFT;

  const renderTubeRow = headboxMode !== 'required';

  return (
    <div className="rounded-md border border-slate-200 bg-white p-3">
      <div className="flex items-center justify-between mb-2 gap-3 flex-wrap">
        <div className="text-xs font-semibold text-slate-700">
          {templateLabel || 'BOM Cut Diagram'}
        </div>
        <div className="flex items-center gap-2">
          {hasAnyHeadbox && (
            <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
              isHeadboxRequired ? 'bg-slate-800 text-white' : 'bg-amber-100 text-amber-700'
            }`}>
              {isHeadboxRequired ? 'HEADBOX' : 'HEADBOX · OPTIONAL'}
            </span>
          )}
          {showPanelControls && (
            <div className="inline-flex items-center rounded border border-slate-200 overflow-hidden text-[10px]">
              {(['1', '2', '3+'] as PanelMode[]).map((m) => (
                <button
                  key={m}
                  type="button"
                  onClick={() => setMode(m)}
                  className={`px-2 py-0.5 transition-colors ${
                    mode === m ? 'bg-slate-800 text-white' : 'bg-white text-slate-500 hover:bg-slate-50'
                  }`}
                >
                  {m === '1' ? '1 Panel' : m === '2' ? '2 Panels' : '3+ Panels'}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="w-full" preserveAspectRatio="xMidYMid meet">
        {/* === OPTIONAL headbox band (above tube row) === */}
        {isHeadboxOptional && (
          <g>
            <rect
              x={HB_LEFT}
              y={OPT_HB_Y}
              width={HB_W}
              height={OPT_HB_H}
              fill="#fff"
              stroke={STROKE}
              strokeWidth={1.2}
              strokeDasharray="4,3"
            />
            <text
              x={HB_LEFT + HB_W / 2}
              y={OPT_HB_Y + OPT_HB_H / 2 + 4}
              textAnchor="middle"
              fontSize={11}
              fill="#92400e"
              fontFamily="ui-sans-serif, system-ui"
              fontWeight={600}
              letterSpacing={1.5}
            >
              OPTIONAL
            </text>
          </g>
        )}

        {/* === REQUIRED headbox shell (wraps tube row) === */}
        {isHeadboxRequired && (() => {
          const END_CAP_W = 6;
          const END_CAP_INSET_X = 4;
          const END_CAP_INSET_Y = 4;
          const tubeHintY = REQ_HB_Y + REQ_HB_H / 2;
          const lipY = REQ_HB_Y + REQ_HB_H - 6;
          return (
            <g>
              {/* Outer cassette body */}
              <rect
                x={HB_LEFT}
                y={REQ_HB_Y}
                width={HB_W}
                height={REQ_HB_H}
                fill="#fff"
                stroke={STROKE}
                strokeWidth={1.4}
              />
              {/* Inner end caps (left + right) */}
              <rect
                x={HB_LEFT + END_CAP_INSET_X}
                y={REQ_HB_Y + END_CAP_INSET_Y}
                width={END_CAP_W}
                height={REQ_HB_H - END_CAP_INSET_Y * 2}
                fill="#fff"
                stroke={STROKE}
                strokeWidth={1}
              />
              <rect
                x={HB_RIGHT - END_CAP_INSET_X - END_CAP_W}
                y={REQ_HB_Y + END_CAP_INSET_Y}
                width={END_CAP_W}
                height={REQ_HB_H - END_CAP_INSET_Y * 2}
                fill="#fff"
                stroke={STROKE}
                strokeWidth={1}
              />
              {/* Tube hint line — suggests "tube hidden inside the cassette" */}
              <line
                x1={HB_LEFT + END_CAP_INSET_X + END_CAP_W + 2}
                y1={tubeHintY}
                x2={HB_RIGHT - END_CAP_INSET_X - END_CAP_W - 2}
                y2={tubeHintY}
                stroke="#94a3b8"
                strokeWidth={0.8}
                strokeDasharray="2,2"
              />
              {/* Bottom lip / profile detail */}
              <line x1={HB_LEFT + 4} y1={lipY} x2={HB_RIGHT - 4} y2={lipY} stroke={STROKE} strokeWidth={0.7} />
              <line x1={HB_LEFT + 4} y1={lipY + 2} x2={HB_RIGHT - 4} y2={lipY + 2} stroke={STROKE} strokeWidth={0.4} opacity={0.6} />
            </g>
          );
        })()}

        {/* === Brackets (always under chips).
              - In `none` and `optional` modes: all brackets are visible at their position.
              - In `required` mode:
                  · outer brackets render as small "feet" hanging just below the cassette
                    so they read as the visible mounting point.
                  · internal (shared) brackets render as a vertical "joint connector"
                    that crosses the cassette top-to-bottom, signaling the seam between
                    two adjacent cassette segments.
        */}
        {tube &&
          bracketXs.map((bx, i) => {
            const isOuter = i === 0 || i === bracketXs.length - 1;
            if (isHeadboxRequired) {
              if (isOuter) {
                return (
                  <rect
                    key={`b-${i}`}
                    x={bx}
                    y={REQ_HB_Y + REQ_HB_H}
                    width={B_W}
                    height={REQ_BRACKET_FOOT_H}
                    fill="#fff"
                    stroke={STROKE}
                    strokeWidth={1.2}
                  />
                );
              }
              // Internal shared bracket → joint connector across the cassette
              const jointW = Math.max(8, B_W - 2);
              const jointX = bx + (B_W - jointW) / 2;
              return (
                <g key={`b-${i}`}>
                  {/* Vertical seam slot inside the cassette */}
                  <rect
                    x={jointX}
                    y={REQ_HB_Y + 2}
                    width={jointW}
                    height={REQ_HB_H - 4}
                    fill="#fff"
                    stroke={STROKE}
                    strokeWidth={1.1}
                  />
                  {/* Foot below the cassette to match outer brackets */}
                  <rect
                    x={bx}
                    y={REQ_HB_Y + REQ_HB_H}
                    width={B_W}
                    height={REQ_BRACKET_FOOT_H}
                    fill="#fff"
                    stroke={STROKE}
                    strokeWidth={1.2}
                  />
                </g>
              );
            }
            // none / optional → original bracket render
            return (
              <rect
                key={`b-${i}`}
                x={bx}
                y={BRACKET_Y}
                width={B_W}
                height={BRACKET_H}
                fill="#fff"
                stroke={STROKE}
                strokeWidth={1.2}
              />
            );
          })}

        {/* === Tubes (visible in `none` and `optional` modes) === */}
        {tube && renderTubeRow &&
          panelXs.map((px, i) => (
            <g key={`tube-${i}`}>
              <rect x={px} y={TUBE_Y} width={panelW} height={TUBE_H} fill="#fff" stroke={STROKE} strokeWidth={1.2} />
              <text
                x={px + panelW / 2}
                y={TUBE_Y + TUBE_H / 2 + 5}
                textAnchor="middle"
                fontSize={13}
                fill={STROKE}
                fontFamily="ui-sans-serif, system-ui"
              >
                TUBE
              </text>
            </g>
          ))}

        {/* === Top chip row (per panel: L / Mid / R) === */}
        {tube &&
          panelXs.map((px, i) => {
            const t = tubePanels[i];
            const isFirst = i === 0;
            const isLast = i === panelCount - 1;
            const leftBracketCenter = bracketXs[i] + B_W / 2;
            const rightBracketCenter = bracketXs[i + 1] + B_W / 2;
            const leftChipX = isFirst
              ? leftBracketCenter - NUM_CHIP_W / 2
              : leftBracketCenter;
            const rightChipX = isLast
              ? rightBracketCenter - NUM_CHIP_W / 2
              : rightBracketCenter - NUM_CHIP_W;
            const cx = px + panelW / 2;
            const formulaX = cx - FORMULA_CHIP_W / 2;

            return (
              <g key={`tchips-${i}`}>
                <HLine x1={leftChipX + NUM_CHIP_W} x2={formulaX} y={dimY} />
                <HLine x1={formulaX + FORMULA_CHIP_W} x2={rightChipX} y={dimY} />
                <Chip x={leftChipX} y={TOP_CHIP_Y} w={NUM_CHIP_W} h={TOP_CHIP_H} label={String(t.left)} tooltip={t.ttLeft} />
                <Chip x={formulaX} y={TOP_CHIP_Y} w={FORMULA_CHIP_W} h={TOP_CHIP_H} label={t.mid} tooltip={t.ttMid} fontSize={13} />
                <Chip x={rightChipX} y={TOP_CHIP_Y} w={NUM_CHIP_W} h={TOP_CHIP_H} label={String(t.right)} tooltip={t.ttRight} />
              </g>
            );
          })}

        {/* === Windows / fabric panels (sized exactly to fabric, no brackets here) === */}
        {panelXs.map((px, i) => {
          const panelFormula = tubePanels[i]?.mid ?? `${tubeSym}${panelCount > 1 ? `/${panelCount}` : ''}`;
          return (
            <g key={`window-${i}`}>
              <rect x={px} y={WINDOW_Y} width={panelW} height={WINDOW_H} fill="#fff" stroke={STROKE} strokeWidth={1.2} />
              <text
                x={px + panelW / 2}
                y={WINDOW_Y + WINDOW_H / 2 - 8}
                textAnchor="middle"
                fontSize={16}
                fill={STROKE}
                fontFamily="ui-sans-serif, system-ui"
              >
                Panel {i + 1}
              </text>
              <text
                x={px + panelW / 2}
                y={WINDOW_Y + WINDOW_H / 2 + 14}
                textAnchor="middle"
                fontSize={11}
                fill="#6b7280"
                fontFamily="ui-monospace, monospace"
              >
                {panelFormula}
              </text>
            </g>
          );
        })}

        {/* === Bottom bars (per panel) === */}
        {bottomBar &&
          panelXs.map((px, i) => {
            const cx = px + panelW / 2;
            return (
              <g key={`bb-${i}`}>
                <rect x={px} y={BB_Y} width={panelW} height={BB_H} fill="#fff" stroke={STROKE} strokeWidth={1.2} />
                {bbHasAnyDeduction && (
                  <>
                    <HLine x1={px + 16} x2={cx - FORMULA_CHIP_W / 2} y={bbDimY} />
                    <HLine x1={cx + FORMULA_CHIP_W / 2} x2={px + panelW - 16} y={bbDimY} />
                    <Chip
                      x={cx - FORMULA_CHIP_W / 2}
                      y={BB_CHIP_Y}
                      w={FORMULA_CHIP_W}
                      h={TOP_CHIP_H}
                      label={bbChips[i].mid}
                      tooltip={bbChips[i].tooltip}
                      fontSize={13}
                    />
                  </>
                )}
              </g>
            );
          })}

        {/* === "M" motor label aligned to drive side === */}
        {tube && (effectiveDriveSide === 'left' || effectiveDriveSide === 'both') && (
          <text
            x={mLabelXLeft}
            y={(isHeadboxRequired ? REQ_HB_Y + REQ_HB_H / 2 : TUBE_Y + TUBE_H / 2) + 5}
            fontSize={15}
            fill={STROKE}
            fontWeight={700}
            fontFamily="ui-sans-serif, system-ui"
          >
            M
          </text>
        )}
        {tube && (effectiveDriveSide === 'right' || effectiveDriveSide === 'both') && (
          <text
            x={mLabelXRight}
            y={(isHeadboxRequired ? REQ_HB_Y + REQ_HB_H / 2 : TUBE_Y + TUBE_H / 2) + 5}
            fontSize={15}
            fill={STROKE}
            fontWeight={700}
            fontFamily="ui-sans-serif, system-ui"
          >
            M
          </text>
        )}

      </svg>
    </div>
  );
}
