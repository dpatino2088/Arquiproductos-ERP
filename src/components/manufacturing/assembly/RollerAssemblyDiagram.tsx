interface RollerAssemblyDiagramProps {
  widthMm: number;
  heightMm: number;
  panelCount: number;
  panelWidths?: number[];
  operatingSystem: 'manual' | 'motorized' | 'motor' | null;
  operatingSide?: 'left' | 'right' | null;
  hasCassette: boolean;
  hasSideChannel: boolean;
  hasBottomBar: boolean;
  tubeType?: string | null;
  hardwareColor?: string | null;
  fabricName?: string | null;
}

const DEDUCTIONS_35 = { active: 38.1, passive: 38.1, direct_drive: 0, total: 76.2 };
const DEDUCTIONS_45 = { active: 38.1, passive: 38.1, direct_drive: 0, total: 76.2 };
const DEDUCTIONS_35_MOTOR = { active: 41.3, passive: 38.1, direct_drive: 18.5, total: 97.9 };
const DEDUCTIONS_45_MOTOR = { active: 41.3, passive: 38.1, direct_drive: 18.5, total: 97.9 };

export default function RollerAssemblyDiagram({
  widthMm,
  heightMm,
  panelCount,
  panelWidths,
  operatingSystem,
  operatingSide,
  hasCassette,
  hasSideChannel,
  hasBottomBar,
  tubeType,
  hardwareColor,
  fabricName,
}: RollerAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const opSide = operatingSide ?? 'right';

  const tubeSize = tubeType?.includes('65') || tubeType?.includes('80') ? 45 : 35;
  const deductions = isMotor
    ? (tubeSize === 45 ? DEDUCTIONS_45_MOTOR : DEDUCTIONS_35_MOTOR)
    : (tubeSize === 45 ? DEDUCTIONS_45 : DEDUCTIONS_35);

  const totalPanels = panelCount || 1;
  const pWidths = panelWidths && panelWidths.length === totalPanels
    ? panelWidths
    : Array.from({ length: totalPanels }, () => widthMm / totalPanels);

  const svgW = 520;
  const svgH = 320;
  const mx = 50;
  const my = 40;
  const drawW = svgW - mx * 2;
  const drawH = svgH - my - 60;

  const tubeH = 16;
  const cassetteH = hasCassette ? 22 : 0;
  const sideChW = hasSideChannel ? 10 : 0;
  const hemBarH = hasBottomBar ? 8 : 0;
  const fabricTop = my + cassetteH + tubeH + 4;
  const fabricH = drawH - cassetteH - tubeH - hemBarH - 12;
  const bracketH = tubeH + 6;

  const scaleForDim = (mm: number) => `${mm.toFixed(1)}`;

  return (
    <div className="space-y-3">
      <svg viewBox={`0 0 ${svgW} ${svgH}`} className="w-full max-w-[540px]" style={{ fontFamily: 'system-ui, sans-serif' }}>
        {/* Cassette / Headbox */}
        {hasCassette && (
          <rect x={mx} y={my} width={drawW} height={cassetteH} rx={3}
            fill="#e5e7eb" stroke="#9ca3af" strokeWidth={1} />
        )}
        {hasCassette && (
          <text x={mx + drawW / 2} y={my + cassetteH / 2 + 3} textAnchor="middle" fontSize={7} fill="#6b7280">
            CASSETTE / HEADBOX
          </text>
        )}

        {/* Tube */}
        <rect x={mx + sideChW} y={my + cassetteH} width={drawW - sideChW * 2} height={tubeH} rx={tubeH / 2}
          fill="#d1d5db" stroke="#9ca3af" strokeWidth={1} />
        <text x={mx + drawW / 2} y={my + cassetteH + tubeH / 2 + 3} textAnchor="middle" fontSize={6.5} fill="#4b5563">
          TUBE {tubeType ?? ''} ({tubeSize}mm)
        </text>

        {/* Brackets */}
        {/* Left bracket (Passive or Active depending on operatingSide) */}
        <rect x={mx - 4} y={my + cassetteH - 3} width={12} height={bracketH} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + 2} y={my + cassetteH + bracketH + 10} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Active (A)' : 'Passive (P)'}
        </text>

        {/* Right bracket */}
        <rect x={mx + drawW - 8} y={my + cassetteH - 3} width={12} height={bracketH} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + drawW - 2} y={my + cassetteH + bracketH + 10} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Passive (P)' : 'Active (A)'}
        </text>

        {/* Motor / Chain indicator */}
        {isMotor ? (
          <>
            <rect
              x={opSide === 'right' ? mx + drawW + 4 : mx - 20}
              y={my + cassetteH - 1}
              width={16} height={tubeH + 2} rx={3}
              fill="#fbbf24" stroke="#d97706" strokeWidth={0.8} />
            <text
              x={opSide === 'right' ? mx + drawW + 12 : mx - 12}
              y={my + cassetteH + tubeH / 2 + 3}
              textAnchor="middle" fontSize={5} fill="#92400e" fontWeight="bold">M</text>
          </>
        ) : (
          <>
            <line
              x1={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y1={my + cassetteH + tubeH}
              x2={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y2={my + cassetteH + tubeH + fabricH * 0.7}
              stroke="#9ca3af" strokeWidth={1.5} strokeDasharray="3,2" />
            <circle
              cx={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              cy={my + cassetteH + tubeH + fabricH * 0.7 + 4}
              r={3} fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.8} />
            <text
              x={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y={my + cassetteH + tubeH + fabricH * 0.7 + 14}
              textAnchor="middle" fontSize={5} fill="#6b7280">Chain</text>
          </>
        )}

        {/* Side channels */}
        {hasSideChannel && (
          <>
            <rect x={mx} y={fabricTop} width={sideChW} height={fabricH} fill="#e5e7eb" stroke="#9ca3af" strokeWidth={0.6} />
            <rect x={mx + drawW - sideChW} y={fabricTop} width={sideChW} height={fabricH} fill="#e5e7eb" stroke="#9ca3af" strokeWidth={0.6} />
          </>
        )}

        {/* Fabric panels */}
        {(() => {
          const fabricAreaW = drawW - sideChW * 2;
          let xOff = mx + sideChW;
          const panelColors = ['#dbeafe', '#ede9fe', '#fce7f3'];
          return pWidths.map((pw, i) => {
            const pW = (pw / widthMm) * fabricAreaW;
            const el = (
              <g key={i}>
                <rect x={xOff} y={fabricTop} width={pW} height={fabricH}
                  fill={panelColors[i % panelColors.length]} stroke="#93c5fd" strokeWidth={0.6}
                  strokeDasharray={totalPanels > 1 ? '4,2' : 'none'} />
                {totalPanels > 1 && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 + 3} textAnchor="middle" fontSize={7} fill="#3b82f6">
                    Panel {i + 1}
                  </text>
                )}
                {totalPanels === 1 && fabricName && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 - 4} textAnchor="middle" fontSize={7} fill="#6b7280" opacity={0.7}>
                    FABRIC
                  </text>
                )}
                {totalPanels === 1 && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 + 8} textAnchor="middle" fontSize={6} fill="#93c5fd">
                    {fabricName ?? ''}
                  </text>
                )}
              </g>
            );
            xOff += pW;
            return el;
          });
        })()}

        {/* Bottom bar / Hem bar */}
        {hasBottomBar && (
          <rect x={mx + sideChW} y={fabricTop + fabricH} width={drawW - sideChW * 2} height={hemBarH} rx={1}
            fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.6} />
        )}
        {hasBottomBar && (
          <text x={mx + drawW / 2} y={fabricTop + fabricH + hemBarH / 2 + 2.5} textAnchor="middle" fontSize={5.5} fill="#6b7280">
            BOTTOM BAR
          </text>
        )}

        {/* Dimension: Overall Width (A) */}
        <line x1={mx} y1={my - 12} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6} markerEnd="url(#arrowR)" markerStart="url(#arrowL)" />
        <text x={mx + drawW / 2} y={my - 16} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          A = {scaleForDim(widthMm)} mm (Ordered Width)
        </text>

        {/* Dimension: Height (B) */}
        <line x1={mx - 18} y1={fabricTop} x2={mx - 18} y2={fabricTop + fabricH + hemBarH} stroke="#374151" strokeWidth={0.6} />
        <text x={mx - 22} y={fabricTop + (fabricH + hemBarH) / 2} textAnchor="middle" fontSize={6.5} fontWeight="bold" fill="#111827"
          transform={`rotate(-90, ${mx - 22}, ${fabricTop + (fabricH + hemBarH) / 2})`}>
          B = {scaleForDim(heightMm)} mm
        </text>

        {/* Dimension: Tube cut (E) — Width minus deductions */}
        <line x1={mx + 8} y1={my + cassetteH + tubeH + 20} x2={mx + drawW - 8} y2={my + cassetteH + tubeH + 20}
          stroke="#2563eb" strokeWidth={0.5} strokeDasharray="2,2" />
        <text x={mx + drawW / 2} y={my + cassetteH + tubeH + 28} textAnchor="middle" fontSize={6} fill="#2563eb">
          E = Tube Cut = {scaleForDim(widthMm - deductions.total)} mm
        </text>

        {/* Arrow markers */}
        <defs>
          <marker id="arrowR" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#374151" />
          </marker>
          <marker id="arrowL" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#374151" />
          </marker>
        </defs>

        {/* Color legend for hardware */}
        {hardwareColor && (
          <text x={svgW - mx} y={svgH - 8} textAnchor="end" fontSize={6} fill="#9ca3af">
            Hardware: {hardwareColor}
          </text>
        )}
      </svg>

      {/* Deductions table */}
      <div className="border border-gray-200 rounded-lg overflow-hidden">
        <div className="px-3 py-2 bg-gray-50 border-b border-gray-100">
          <h5 className="text-xs font-semibold text-gray-700 uppercase tracking-wider">Deductions</h5>
        </div>
        <table className="w-full text-xs">
          <thead>
            <tr className="text-[10px] text-gray-500 border-b border-gray-100 bg-gray-50">
              <th className="text-left px-3 py-1.5">Tube</th>
              <th className="text-center px-3 py-1.5">Active Side</th>
              {isMotor && <th className="text-center px-3 py-1.5">Direct Drive</th>}
              <th className="text-center px-3 py-1.5">Passive Side</th>
              <th className="text-center px-3 py-1.5 font-bold">Total Deduction</th>
              <th className="text-center px-3 py-1.5 font-bold">Tube Cut</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-gray-50">
              <td className="px-3 py-1.5 text-gray-700">{tubeSize}mm</td>
              <td className="px-3 py-1.5 text-center">{deductions.active.toFixed(1)} mm</td>
              {isMotor && <td className="px-3 py-1.5 text-center">{deductions.direct_drive.toFixed(1)} mm</td>}
              <td className="px-3 py-1.5 text-center">{deductions.passive.toFixed(1)} mm</td>
              <td className="px-3 py-1.5 text-center font-semibold text-red-600">{deductions.total.toFixed(1)} mm</td>
              <td className="px-3 py-1.5 text-center font-bold text-blue-700">{(widthMm - deductions.total).toFixed(1)} mm</td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* Assembly specs summary */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-xs px-1">
        <div className="flex justify-between"><span className="text-gray-500">Ordered size</span><span className="font-medium">{widthMm} × {heightMm} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Panels</span><span className="font-medium">{totalPanels}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operating system</span><span className="font-medium">{isMotor ? 'Motorized' : 'Manual'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operator side</span><span className="font-medium capitalize">{opSide}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Tube</span><span className="font-medium">{tubeType ?? `${tubeSize}mm`}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Hardware color</span><span className="font-medium capitalize">{hardwareColor ?? '—'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Cassette</span><span className="font-medium">{hasCassette ? 'Yes' : 'No'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Side channels</span><span className="font-medium">{hasSideChannel ? 'Yes' : 'No'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Bottom bar</span><span className="font-medium">{hasBottomBar ? 'Yes' : 'No'}</span></div>
      </div>
    </div>
  );
}
