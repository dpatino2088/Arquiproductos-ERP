import type { ChipBreakdown } from './RollerCutDiagram';

export interface DraperyCutDiagramProps {
  templateLabel?: string;
  /** Axis symbol for the track (normally 'W'). */
  trackSymbol?: string;
  /** Base width before deductions (mm). */
  baseMm?: number;
  /** Resolved track cut after deductions (mm). */
  resolvedMm?: number;
  /** Total deduction applied to the track (mm). */
  totalDeduction?: number;
  /** Manufacturing tolerance (mm), if any. */
  tolerance?: number;
  /** Deduction landing on the left end of the track (mm). */
  leftMm?: number;
  /** Deduction landing on the right end of the track (mm). */
  rightMm?: number;
  leftBreakdown?: ChipBreakdown[];
  rightBreakdown?: ChipBreakdown[];
  /** Side where the motor (and its end cap) sits. */
  motorSide?: 'left' | 'right' | null;
  /** Master-carrier opening direction. 'center' renders two carriers in the middle. */
  opening?: 'left' | 'right' | 'center' | null;
  /**
   * Fullness multiplier label used in the fabric width formula. Defaults to
   * the symbolic 'fullness' since the exact factor (2.0 / 2.3 / 2.8 / 3.0)
   * depends on the fabric style selected at order time.
   */
  fullnessLabel?: string;
}

const VB_W = 1200;
const VB_H = 560;
const STROKE = '#1f2937';
const ARROW = '#2563eb';

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;

function buildTooltip(side: string, breakdown: ChipBreakdown[] | undefined, total: number): string {
  if (!breakdown || breakdown.length === 0) return `${side}: ${total} mm`;
  const lines = breakdown.map((b) => `  ${b.label} (${b.sku}): ${b.value} mm`);
  return `${side}\n${lines.join('\n')}\n  ─────────\n  TOTAL: ${total} mm`;
}

function Chip({
  x,
  y,
  w = 60,
  h = 28,
  label,
  tooltip,
  fontSize = 14,
}: {
  x: number;
  y: number;
  w?: number;
  h?: number;
  label: string;
  tooltip?: string;
  fontSize?: number;
}) {
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

/**
 * Drapery cut diagram — models the TRACK as a single continuous rail (it is not
 * split per-panel). It mirrors the reference layout:
 *   [endcap deduction] ── Track ── [motor-endcap deduction]
 *   End Cap |▭▭▭▭▭▭▭▭▭▭▭▭▭▭| Motor End Cap (M)
 *           └ master carrier (← / →) over the Fabric area
 *
 * All magnitudes come from the breakdown (catalog deltas resolved by the RPC);
 * nothing is invented here.
 */
export default function DraperyCutDiagram({
  templateLabel,
  trackSymbol = 'W',
  baseMm,
  resolvedMm,
  totalDeduction,
  tolerance = 0,
  leftMm = 0,
  rightMm = 0,
  leftBreakdown,
  rightBreakdown,
  motorSide = 'right',
  opening = null,
  fullnessLabel = 'fullness',
}: DraperyCutDiagramProps) {
  const left = round2(leftMm);
  const right = round2(rightMm);
  const ded = round2(typeof totalDeduction === 'number' ? totalDeduction : left + right - tolerance);
  const resolved = typeof resolvedMm === 'number' ? round2(resolvedMm) : null;
  const formula = `${trackSymbol} − ${ded}`;

  const motorOnLeft = motorSide === 'left';
  const motorOnRight = motorSide === 'right';

  // ---- Layout ----
  const PAD_X = 70;
  const CAP_W = 26;
  const TRACK_Y = 96;
  const TRACK_H = 26;
  const trackX0 = PAD_X;
  const trackX1 = VB_W - PAD_X;
  const trackW = trackX1 - trackX0;

  const railX0 = trackX0 + CAP_W;
  const railX1 = trackX1 - CAP_W;

  const FABRIC_Y = TRACK_Y + TRACK_H + 14;
  const FABRIC_H = 300;
  const fabricX0 = railX0 + 6;
  const fabricX1 = railX1 - 6;
  const fabricW = fabricX1 - fabricX0;

  // Top dimension chips
  const TOP_CHIP_Y = 28;
  const TOP_CHIP_H = 28;
  const NUM_CHIP_W = 56;
  const FORMULA_CHIP_W = 140;
  const dimY = TOP_CHIP_Y + TOP_CHIP_H / 2;
  const formulaX = (trackX0 + trackX1) / 2 - FORMULA_CHIP_W / 2;
  const leftChipX = trackX0;
  const rightChipX = trackX1 - NUM_CHIP_W;

  // Motor block
  const M_W = 30;
  const M_H = FABRIC_H * 0.7;
  const mX = motorOnLeft ? trackX0 - M_W - 8 : trackX1 + 8;
  const mY = FABRIC_Y;

  // Master carrier(s)
  const carrierY = FABRIC_Y + 4;
  const CARRIER_W = 12;
  const CARRIER_H = 22;

  const renderCarrier = (cx: number, dir: 'left' | 'right') => {
    const ax = dir === 'left' ? cx - 26 : cx + CARRIER_W + 26;
    const tipX = dir === 'left' ? ax : ax;
    const baseX = dir === 'left' ? cx : cx + CARRIER_W;
    const ay = carrierY + CARRIER_H / 2;
    return (
      <g>
        <rect x={cx} y={carrierY} width={CARRIER_W} height={CARRIER_H} fill="#fff" stroke={STROKE} strokeWidth={1.1} />
        <line x1={baseX} y1={ay} x2={tipX} y2={ay} stroke={ARROW} strokeWidth={1.4} />
        <polygon
          points={
            dir === 'left'
              ? `${tipX},${ay} ${tipX + 7},${ay - 4} ${tipX + 7},${ay + 4}`
              : `${tipX},${ay} ${tipX - 7},${ay - 4} ${tipX - 7},${ay + 4}`
          }
          fill={ARROW}
        />
      </g>
    );
  };

  return (
    <div className="rounded-md border border-slate-200 bg-white p-3">
      <div className="flex items-center justify-between mb-2 gap-3 flex-wrap">
        <div className="text-xs font-semibold text-slate-700">{templateLabel || 'Drapery Track Diagram'}</div>
        <div className="flex items-center gap-2">
          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-slate-800 text-white">TRACK</span>
          {opening && (
            <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-blue-100 text-blue-700 uppercase">
              {opening === 'center' ? 'Center opening' : `${opening} opening`}
            </span>
          )}
        </div>
      </div>

      <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="w-full" preserveAspectRatio="xMidYMid meet">
        {/* === Top dimension row: left end / track formula / right end === */}
        <HLine x1={leftChipX + NUM_CHIP_W} x2={formulaX} y={dimY} />
        <HLine x1={formulaX + FORMULA_CHIP_W} x2={rightChipX} y={dimY} />
        <Chip
          x={leftChipX}
          y={TOP_CHIP_Y}
          w={NUM_CHIP_W}
          h={TOP_CHIP_H}
          label={String(left)}
          tooltip={buildTooltip(motorOnLeft ? 'MOTOR END' : 'END CAP (left)', leftBreakdown, left)}
        />
        <Chip
          x={formulaX}
          y={TOP_CHIP_Y}
          w={FORMULA_CHIP_W}
          h={TOP_CHIP_H}
          label={formula}
          tooltip={`Track cut = ${trackSymbol} − ${left} (left) − ${right} (right)${tolerance ? ` + ${tolerance} (tol)` : ''} = ${trackSymbol} − ${ded} mm${resolved != null && baseMm ? `  ·  @${baseMm}mm → ${resolved}mm` : ''}`}
          fontSize={14}
        />
        <Chip
          x={rightChipX}
          y={TOP_CHIP_Y}
          w={NUM_CHIP_W}
          h={TOP_CHIP_H}
          label={String(right)}
          tooltip={buildTooltip(motorOnRight ? 'MOTOR END' : 'END CAP (right)', rightBreakdown, right)}
        />

        {/* === Track rail with end caps === */}
        {/* left end cap */}
        <rect x={trackX0} y={TRACK_Y} width={CAP_W} height={TRACK_H} fill="#fff" stroke={STROKE} strokeWidth={1.3} />
        {/* rail body */}
        <rect x={railX0} y={TRACK_Y} width={railX1 - railX0} height={TRACK_H} fill="#fff" stroke={STROKE} strokeWidth={1.3} />
        {/* rail detail line */}
        <line x1={railX0 + 4} y1={TRACK_Y + TRACK_H / 2} x2={railX1 - 4} y2={TRACK_Y + TRACK_H / 2} stroke="#94a3b8" strokeWidth={0.7} strokeDasharray="3,3" />
        {/* right end cap */}
        <rect x={trackX1 - CAP_W} y={TRACK_Y} width={CAP_W} height={TRACK_H} fill="#fff" stroke={STROKE} strokeWidth={1.3} />
        <text x={(railX0 + railX1) / 2} y={TRACK_Y - 6} textAnchor="middle" fontSize={12} fill={STROKE} fontFamily="ui-sans-serif, system-ui">
          Track
        </text>

        {/* End cap labels */}
        <text x={trackX0 + CAP_W / 2} y={TRACK_Y + TRACK_H + 14} textAnchor="middle" fontSize={10} fill="#6b7280" fontFamily="ui-sans-serif, system-ui">
          {motorOnLeft ? 'Motor End Cap' : 'End Cap'}
        </text>
        <text x={trackX1 - CAP_W / 2} y={TRACK_Y + TRACK_H + 14} textAnchor="middle" fontSize={10} fill="#6b7280" fontFamily="ui-sans-serif, system-ui">
          {motorOnRight ? 'Motor End Cap' : 'End Cap'}
        </text>

        {/* === Fabric ===
            Rule: fabric width = finished_width × fullness.
              · single side (left/right) → 1 panel, cut = W × fullness
              · center                   → 2 panels (W/2 each), cut = (W/2) × fullness
        */}
        {opening === 'center' ? (
          (() => {
            const GAP = 34;
            const midX = (fabricX0 + fabricX1) / 2;
            const lW = midX - GAP / 2 - fabricX0;
            const rW = fabricX1 - (midX + GAP / 2);
            const sub = `(${trackSymbol}/2) × ${fullnessLabel}`;
            return (
              <g>
                <rect x={fabricX0} y={FABRIC_Y} width={lW} height={FABRIC_H} fill="#f8fafc" stroke={STROKE} strokeWidth={1.2} />
                <rect x={midX + GAP / 2} y={FABRIC_Y} width={rW} height={FABRIC_H} fill="#f8fafc" stroke={STROKE} strokeWidth={1.2} />
                <text x={fabricX0 + lW / 2} y={FABRIC_Y + FABRIC_H / 2} textAnchor="middle" fontSize={15} fill="#475569" fontFamily="ui-sans-serif, system-ui">Fabric</text>
                <text x={fabricX0 + lW / 2} y={FABRIC_Y + FABRIC_H / 2 + 20} textAnchor="middle" fontSize={11} fill="#94a3b8" fontFamily="ui-monospace, monospace">{sub}</text>
                <text x={midX + GAP / 2 + rW / 2} y={FABRIC_Y + FABRIC_H / 2} textAnchor="middle" fontSize={15} fill="#475569" fontFamily="ui-sans-serif, system-ui">Fabric</text>
                <text x={midX + GAP / 2 + rW / 2} y={FABRIC_Y + FABRIC_H / 2 + 20} textAnchor="middle" fontSize={11} fill="#94a3b8" fontFamily="ui-monospace, monospace">{sub}</text>
              </g>
            );
          })()
        ) : (
          <g>
            <rect x={fabricX0} y={FABRIC_Y} width={fabricW} height={FABRIC_H} fill="#f8fafc" stroke={STROKE} strokeWidth={1.2} />
            <text x={(fabricX0 + fabricX1) / 2} y={FABRIC_Y + FABRIC_H / 2} textAnchor="middle" fontSize={15} fill="#475569" fontFamily="ui-sans-serif, system-ui">Fabric</text>
            <text x={(fabricX0 + fabricX1) / 2} y={FABRIC_Y + FABRIC_H / 2 + 20} textAnchor="middle" fontSize={11} fill="#94a3b8" fontFamily="ui-monospace, monospace">{trackSymbol} × {fullnessLabel}</text>
          </g>
        )}

        {/* === Motor block "M" === */}
        {motorSide && (
          <g>
            <rect x={mX} y={mY} width={M_W} height={M_H} fill="#fff" stroke={STROKE} strokeWidth={1.3} />
            <text x={mX + M_W / 2} y={mY + M_H / 2 + 6} textAnchor="middle" fontSize={16} fontWeight={700} fill={STROKE} fontFamily="ui-sans-serif, system-ui">
              M
            </text>
          </g>
        )}

        {/* === Master carrier(s) === */}
        {opening === 'center' ? (
          <g>
            {renderCarrier((fabricX0 + fabricX1) / 2 - CARRIER_W - 4, 'left')}
            {renderCarrier((fabricX0 + fabricX1) / 2 + 4, 'right')}
            <text x={(fabricX0 + fabricX1) / 2} y={carrierY + CARRIER_H + 18} textAnchor="middle" fontSize={11} fill="#1d4ed8" fontFamily="ui-sans-serif, system-ui">
              Master carrier (center)
            </text>
          </g>
        ) : opening === 'left' || opening === 'right' ? (
          <g>
            {renderCarrier(opening === 'left' ? fabricX0 + 10 : fabricX1 - CARRIER_W - 10, opening)}
            <text
              x={opening === 'left' ? fabricX0 + 70 : fabricX1 - 70}
              y={carrierY + CARRIER_H + 18}
              textAnchor="middle"
              fontSize={11}
              fill="#1d4ed8"
              fontFamily="ui-sans-serif, system-ui"
            >
              Master carrier ({opening})
            </text>
          </g>
        ) : null}

        {/* === Resolved cut readout === */}
        {resolved != null && (
          <text x={(railX0 + railX1) / 2} y={FABRIC_Y + FABRIC_H + 28} textAnchor="middle" fontSize={12} fill={STROKE} fontFamily="ui-monospace, monospace">
            Track cut = {formula} = {resolved} mm{baseMm ? `  (@ ${baseMm} mm)` : ''}
          </text>
        )}
        <text x={(railX0 + railX1) / 2} y={FABRIC_Y + FABRIC_H + (resolved != null ? 46 : 28)} textAnchor="middle" fontSize={11} fill="#64748b" fontFamily="ui-monospace, monospace">
          {opening === 'center'
            ? `Fabric = (${trackSymbol}/2) × ${fullnessLabel} per side (2 panels)`
            : `Fabric = ${trackSymbol} × ${fullnessLabel}`}
        </text>
      </svg>
    </div>
  );
}
