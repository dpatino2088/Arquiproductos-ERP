interface ShadeAssemblyDiagramProps {
  widthMm: number;
  heightMm: number;
  shadeType: 'dual' | 'triple';
  panelCount: number;
  panelWidths?: number[];
  operatingSystem: 'manual' | 'motorized' | 'motor' | null;
  operatingSide?: 'left' | 'right' | null;
  hasCassette: boolean;
  hasSideChannel: boolean;
  hasBottomBar: boolean;
  tubeType?: string | null;
  tubeCutMm?: number | null;
  fabricCutMm?: number | null;
  bottomBarCutMm?: number | null;
  hardwareColor?: string | null;
  fabricNames?: (string | null)[];
}

const LAYER_COLORS = {
  front:  { fill: '#dbeafe', stroke: '#93c5fd', label: 'Front Fabric' },
  back:   { fill: '#fce7f3', stroke: '#f9a8d4', label: 'Back Fabric' },
};

export default function ShadeAssemblyDiagram({
  widthMm,
  heightMm,
  shadeType,
  panelCount,
  operatingSystem,
  operatingSide,
  hasCassette,
  hasSideChannel,
  hasBottomBar,
  tubeType,
  tubeCutMm,
  fabricCutMm,
  bottomBarCutMm,
  hardwareColor,
  fabricNames,
}: ShadeAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const opSide = operatingSide ?? 'right';
  const brkW = 14;
  const totalPanels = panelCount || 1;
  const isDual = shadeType === 'dual';
  const layers = isDual ? ['front', 'back'] as const : ['front'] as const;

  const effectiveTubeCutMm = tubeCutMm != null ? Number(tubeCutMm) : widthMm;
  const tubeDeductionMm = Math.max(0, widthMm - effectiveTubeCutMm);
  const scaleForDim = (mm: number) => `${mm.toFixed(1)}`;

  const svgW = 520;
  const svgH = 340;
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

  const layerGap = isDual ? 6 : 0;
  const perLayerH = isDual ? (fabricH - layerGap) / 2 : fabricH;

  return (
    <div className="space-y-3">
      <svg viewBox={`0 0 ${svgW} ${svgH}`} className="w-full max-w-[540px]" style={{ fontFamily: 'system-ui, sans-serif' }}>
        <defs>
          <marker id="arrowRS" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#374151" />
          </marker>
          <marker id="arrowLS" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#374151" />
          </marker>
          <marker id="arrowBlueRS" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#2563eb" />
          </marker>
          <marker id="arrowBlueLS" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#2563eb" />
          </marker>
        </defs>

        {/* Cassette / Headbox */}
        {hasCassette && (
          <>
            <rect x={mx} y={my} width={drawW} height={cassetteH} rx={3}
              fill="#e5e7eb" stroke="#9ca3af" strokeWidth={1} />
            <text x={mx + drawW / 2} y={my + cassetteH / 2 + 3} textAnchor="middle" fontSize={7} fill="#6b7280">
              CASSETTE / HEADBOX
            </text>
          </>
        )}

        {/* Outer Brackets */}
        <rect x={mx} y={my + cassetteH - 3} width={brkW} height={bracketH} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + brkW / 2} y={my + cassetteH + bracketH + 10} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Active' : 'Passive'}
        </text>

        <rect x={mx + drawW - brkW} y={my + cassetteH - 3} width={brkW} height={bracketH} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + drawW - brkW / 2} y={my + cassetteH + bracketH + 10} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Passive' : 'Active'}
        </text>

        {/* Single tube */}
        <rect x={mx + brkW} y={my + cassetteH} width={drawW - brkW * 2} height={tubeH} rx={2}
          fill="#d1d5db" stroke="#9ca3af" strokeWidth={1} />
        <text x={mx + drawW / 2} y={my + cassetteH + tubeH / 2 + 3} textAnchor="middle" fontSize={6.5} fill="#4b5563">
          TUBE {tubeType ?? ''}
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
            <rect x={mx + brkW} y={fabricTop} width={sideChW} height={fabricH} fill="#e5e7eb" stroke="#9ca3af" strokeWidth={0.6} />
            <rect x={mx + drawW - brkW - sideChW} y={fabricTop} width={sideChW} height={fabricH} fill="#e5e7eb" stroke="#9ca3af" strokeWidth={0.6} />
          </>
        )}

        {/* Fabric layers — stacked vertically (superimposed) */}
        {isDual ? (
          <>
            {layers.map((layer, i) => {
              const lDef = LAYER_COLORS[layer];
              const yStart = fabricTop + i * (perLayerH + layerGap);
              const fAreaW = drawW - brkW * 2 - sideChW * 2;
              const fX = mx + brkW + sideChW;
              const fName = fabricNames?.[i] ?? null;
              return (
                <g key={`fabric-${layer}`}>
                  <rect x={fX} y={yStart} width={fAreaW} height={perLayerH}
                    fill={lDef.fill} stroke={lDef.stroke} strokeWidth={0.8} />
                  <text x={fX + fAreaW / 2} y={yStart + 10} textAnchor="middle" fontSize={6.5} fill={lDef.stroke} fontWeight="600">
                    {lDef.label}
                  </text>
                  {fName && (
                    <text x={fX + fAreaW / 2} y={yStart + perLayerH / 2 + 4} textAnchor="middle" fontSize={6} fill={lDef.stroke} opacity={0.7}>
                      {fName}
                    </text>
                  )}
                </g>
              );
            })}
            {/* Visual indicator: both fabrics roll on same tube */}
            <text x={mx + drawW + 14} y={fabricTop + fabricH / 2 + 3} fontSize={5} fill="#6b7280"
              transform={`rotate(90, ${mx + drawW + 14}, ${fabricTop + fabricH / 2 + 3})`}
              textAnchor="middle" opacity={0.6}>
              Both layers roll on one tube
            </text>
          </>
        ) : (
          /* Triple Shade: single fabric with horizontal vane lines */
          (() => {
            const fAreaW = drawW - brkW * 2 - sideChW * 2;
            const fX = mx + brkW + sideChW;
            const fName = fabricNames?.[0] ?? null;
            const vaneCount = 8;
            const vaneSpacing = fabricH / (vaneCount + 1);
            return (
              <g>
                <rect x={fX} y={fabricTop} width={fAreaW} height={fabricH}
                  fill="#f0fdf4" stroke="#86efac" strokeWidth={0.8} />
                {Array.from({ length: vaneCount }, (_, vi) => {
                  const vy = fabricTop + (vi + 1) * vaneSpacing;
                  return (
                    <line key={`vane-${vi}`} x1={fX + 2} y1={vy} x2={fX + fAreaW - 2} y2={vy}
                      stroke="#86efac" strokeWidth={0.5} strokeDasharray="6,3" />
                  );
                })}
                <text x={fX + fAreaW / 2} y={fabricTop + 10} textAnchor="middle" fontSize={6.5} fill="#16a34a" fontWeight="600">
                  Sheer Fabric (Triple Shade)
                </text>
                {fName && (
                  <text x={fX + fAreaW / 2} y={fabricTop + fabricH / 2 + 4} textAnchor="middle" fontSize={6} fill="#16a34a" opacity={0.7}>
                    {fName}
                  </text>
                )}
              </g>
            );
          })()
        )}

        {/* Bottom bar */}
        {hasBottomBar && (
          <>
            <rect x={mx + brkW + sideChW} y={fabricTop + fabricH} width={drawW - brkW * 2 - sideChW * 2} height={hemBarH} rx={1}
              fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.6} />
            <text x={mx + drawW / 2} y={fabricTop + fabricH + hemBarH / 2 + 2.5} textAnchor="middle" fontSize={5.5} fill="#6b7280">
              BOTTOM BAR
            </text>
          </>
        )}

        {/* Dimension: Finished Width */}
        <line x1={mx} y1={my - 12} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6}
          markerEnd="url(#arrowRS)" markerStart="url(#arrowLS)" />
        <text x={mx + drawW / 2} y={my - 16} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          Finished Width: {scaleForDim(widthMm)} mm
        </text>

        {/* Dimension: Height */}
        <line x1={mx - 18} y1={fabricTop} x2={mx - 18} y2={fabricTop + fabricH + hemBarH} stroke="#374151" strokeWidth={0.6} />
        <text x={mx - 22} y={fabricTop + (fabricH + hemBarH) / 2} textAnchor="middle" fontSize={6.5} fontWeight="bold" fill="#111827"
          transform={`rotate(-90, ${mx - 22}, ${fabricTop + (fabricH + hemBarH) / 2})`}>
          Height: {scaleForDim(heightMm)} mm
        </text>

        {/* Dimension: Tube cut */}
        <line x1={mx + brkW} y1={my + cassetteH + tubeH + 18} x2={mx + drawW - brkW} y2={my + cassetteH + tubeH + 18}
          stroke="#2563eb" strokeWidth={0.5} markerEnd="url(#arrowBlueRS)" markerStart="url(#arrowBlueLS)" />
        <text x={mx + drawW / 2} y={my + cassetteH + tubeH + 27} textAnchor="middle" fontSize={6.5} fontWeight="600" fill="#2563eb">
          Tube Cut: {scaleForDim(effectiveTubeCutMm)} mm
        </text>

        {/* Hardware color */}
        {hardwareColor && (
          <text x={svgW - mx} y={svgH - 8} textAnchor="end" fontSize={6} fill="#9ca3af">
            Hardware: {hardwareColor}
          </text>
        )}
      </svg>

      {/* Engineering Cuts table */}
      <div className="border border-gray-200 rounded-lg overflow-hidden">
        <div className="px-3 py-2 bg-gray-50 border-b border-gray-100">
          <h5 className="text-xs font-semibold text-gray-700 uppercase tracking-wider">Engineering Cuts</h5>
        </div>
        <table className="w-full text-xs">
          <thead>
            <tr className="text-[10px] text-gray-500 border-b border-gray-100 bg-gray-50">
              <th className="text-left px-3 py-1.5">Part</th>
              <th className="text-center px-3 py-1.5">Finished Width</th>
              <th className="text-center px-3 py-1.5 font-bold">Deduction</th>
              <th className="text-center px-3 py-1.5 font-bold">Cut Width</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-gray-50">
              <td className="px-3 py-1.5 text-gray-700">Tube</td>
              <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
              <td className="px-3 py-1.5 text-center font-semibold text-red-600">−{tubeDeductionMm.toFixed(1)} mm</td>
              <td className="px-3 py-1.5 text-center font-bold text-blue-700">{effectiveTubeCutMm.toFixed(1)} mm</td>
            </tr>
            {isDual ? (
              <>
                <tr className="border-b border-gray-50">
                  <td className="px-3 py-1.5 text-gray-700">Front Fabric</td>
                  <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
                  <td className="px-3 py-1.5 text-center font-semibold text-red-600">
                    {fabricCutMm != null ? `−${Math.max(0, widthMm - Number(fabricCutMm)).toFixed(1)} mm` : '—'}
                  </td>
                  <td className="px-3 py-1.5 text-center font-bold text-blue-700">
                    {fabricCutMm != null ? `${Number(fabricCutMm).toFixed(1)} mm` : '—'}
                  </td>
                </tr>
                <tr className="border-b border-gray-50">
                  <td className="px-3 py-1.5 text-gray-700">Back Fabric</td>
                  <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
                  <td className="px-3 py-1.5 text-center font-semibold text-red-600">
                    {fabricCutMm != null ? `−${Math.max(0, widthMm - Number(fabricCutMm)).toFixed(1)} mm` : '—'}
                  </td>
                  <td className="px-3 py-1.5 text-center font-bold text-blue-700">
                    {fabricCutMm != null ? `${Number(fabricCutMm).toFixed(1)} mm` : '—'}
                  </td>
                </tr>
              </>
            ) : (
              <tr className="border-b border-gray-50">
                <td className="px-3 py-1.5 text-gray-700">Fabric</td>
                <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
                <td className="px-3 py-1.5 text-center font-semibold text-red-600">
                  {fabricCutMm != null ? `−${Math.max(0, widthMm - Number(fabricCutMm)).toFixed(1)} mm` : '—'}
                </td>
                <td className="px-3 py-1.5 text-center font-bold text-blue-700">
                  {fabricCutMm != null ? `${Number(fabricCutMm).toFixed(1)} mm` : '—'}
                </td>
              </tr>
            )}
            <tr>
              <td className="px-3 py-1.5 text-gray-700">Bottom Bar</td>
              <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
              <td className="px-3 py-1.5 text-center font-semibold text-red-600">
                {bottomBarCutMm != null ? `−${Math.max(0, widthMm - Number(bottomBarCutMm)).toFixed(1)} mm` : '—'}
              </td>
              <td className="px-3 py-1.5 text-center font-bold text-blue-700">
                {bottomBarCutMm != null ? `${Number(bottomBarCutMm).toFixed(1)} mm` : '—'}
              </td>
            </tr>
          </tbody>
        </table>
        <div className="px-3 py-1.5 text-[10px] text-gray-400 bg-gray-50 border-t border-gray-100">
          Data source: Engineering cuts from BOM instance lines (MO/WO).
        </div>
      </div>

      {/* Assembly specs summary */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-xs px-1">
        <div className="flex justify-between"><span className="text-gray-500">Finished size</span><span className="font-medium">{widthMm} × {heightMm} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Type</span><span className="font-medium capitalize">{shadeType} Shade</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Panels</span><span className="font-medium">{totalPanels}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Layers</span><span className="font-medium">{layers.length}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Tube cut</span><span className="font-medium text-blue-700">{effectiveTubeCutMm.toFixed(1)} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operating system</span><span className="font-medium">{isMotor ? 'Motorized' : 'Manual'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operator side</span><span className="font-medium capitalize">{opSide}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Tube</span><span className="font-medium">{tubeType ?? '—'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Hardware color</span><span className="font-medium capitalize">{hardwareColor ?? '—'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Cassette</span><span className="font-medium">{hasCassette ? 'Yes' : 'No'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Side channels</span><span className="font-medium">{hasSideChannel ? 'Yes' : 'No'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Bottom bar</span><span className="font-medium">{hasBottomBar ? 'Yes' : 'No'}</span></div>
      </div>
    </div>
  );
}
