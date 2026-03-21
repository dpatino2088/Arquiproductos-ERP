interface ShadeAssemblyDiagramProps {
  widthMm: number;
  heightMm: number;
  shadeType: 'dual' | 'triple';
  panelCount: number;
  operatingSystem: 'manual' | 'motorized' | 'motor' | null;
  operatingSide?: 'left' | 'right' | null;
  hasCassette: boolean;
  hasSideChannel: boolean;
  tubeType?: string | null;
  hardwareColor?: string | null;
  fabricNames?: (string | null)[];
}

const LAYER_COLORS: Record<string, { fill: string; stroke: string; label: string }> = {
  front:  { fill: '#dbeafe', stroke: '#93c5fd', label: 'Front Fabric' },
  middle: { fill: '#ede9fe', stroke: '#a78bfa', label: 'Middle Fabric' },
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
  tubeType,
  hardwareColor,
  fabricNames,
}: ShadeAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const opSide = operatingSide ?? 'right';
  const layers = shadeType === 'triple' ? ['front', 'middle', 'back'] : ['front', 'back'];
  const totalPanels = panelCount || 1;

  const svgW = 520;
  const svgH = 340;
  const mx = 50;
  const my = 40;
  const drawW = svgW - mx * 2;
  const drawH = svgH - my - 60;

  const cassetteH = hasCassette ? 24 : 0;
  const sideChW = hasSideChannel ? 10 : 0;
  const layerSpacing = 6;
  const tubeH = 12;
  const tubeSpacing = 4;
  const tubesAreaH = layers.length * (tubeH + tubeSpacing);
  const fabricTop = my + cassetteH + tubesAreaH + 6;
  const fabricH = drawH - cassetteH - tubesAreaH - 16;
  const layerW = (drawW - sideChW * 2 - (layers.length - 1) * layerSpacing) / layers.length;

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
        </defs>

        {/* Cassette / Headbox */}
        {hasCassette && (
          <>
            <rect x={mx} y={my} width={drawW} height={cassetteH} rx={3}
              fill="#e5e7eb" stroke="#9ca3af" strokeWidth={1} />
            <text x={mx + drawW / 2} y={my + cassetteH / 2 + 3} textAnchor="middle" fontSize={7} fill="#6b7280">
              HEADBOX ({shadeType === 'triple' ? 'Triple' : 'Dual'} Shade)
            </text>
          </>
        )}

        {/* Multiple tubes — one per layer */}
        {layers.map((layer, i) => {
          const tubeY = my + cassetteH + i * (tubeH + tubeSpacing);
          const layerDef = LAYER_COLORS[layer];
          return (
            <g key={`tube-${layer}`}>
              <rect x={mx + sideChW + 2} y={tubeY} width={drawW - sideChW * 2 - 4} height={tubeH} rx={tubeH / 2}
                fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.8} />
              <text x={mx + drawW / 2} y={tubeY + tubeH / 2 + 3} textAnchor="middle" fontSize={5.5} fill="#4b5563">
                TUBE {i + 1} — {layerDef.label}
              </text>
            </g>
          );
        })}

        {/* Brackets */}
        <rect x={mx - 4} y={my + cassetteH - 3} width={12} height={tubesAreaH + 6} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + 2} y={my + cassetteH + tubesAreaH + 12} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Active (A)' : 'Passive (P)'}
        </text>

        <rect x={mx + drawW - 8} y={my + cassetteH - 3} width={12} height={tubesAreaH + 6} rx={2}
          fill="#9ca3af" stroke="#6b7280" strokeWidth={0.8} />
        <text x={mx + drawW - 2} y={my + cassetteH + tubesAreaH + 12} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          {opSide === 'left' ? 'Passive (P)' : 'Active (A)'}
        </text>

        {/* Motor / Chain */}
        {isMotor ? (
          <>
            <rect
              x={opSide === 'right' ? mx + drawW + 4 : mx - 20}
              y={my + cassetteH}
              width={16} height={tubesAreaH} rx={3}
              fill="#fbbf24" stroke="#d97706" strokeWidth={0.8} />
            <text
              x={opSide === 'right' ? mx + drawW + 12 : mx - 12}
              y={my + cassetteH + tubesAreaH / 2 + 3}
              textAnchor="middle" fontSize={6} fill="#92400e" fontWeight="bold">M</text>
          </>
        ) : (
          <>
            <line
              x1={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y1={my + cassetteH + tubesAreaH}
              x2={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y2={fabricTop + fabricH * 0.5}
              stroke="#9ca3af" strokeWidth={1.5} strokeDasharray="3,2" />
            <text
              x={opSide === 'right' ? mx + drawW + 6 : mx - 6}
              y={fabricTop + fabricH * 0.5 + 10}
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

        {/* Fabric layers — shown as offset stacked rectangles */}
        {layers.map((layer, i) => {
          const layerDef = LAYER_COLORS[layer];
          const lx = mx + sideChW + i * (layerW + layerSpacing);
          const fName = fabricNames?.[i] ?? null;
          return (
            <g key={`fabric-${layer}`}>
              <rect x={lx} y={fabricTop} width={layerW} height={fabricH}
                fill={layerDef.fill} stroke={layerDef.stroke} strokeWidth={0.6} />
              <text x={lx + layerW / 2} y={fabricTop + fabricH / 2 - 4} textAnchor="middle" fontSize={7} fill={layerDef.stroke}>
                {layerDef.label}
              </text>
              {fName && (
                <text x={lx + layerW / 2} y={fabricTop + fabricH / 2 + 8} textAnchor="middle" fontSize={5.5} fill={layerDef.stroke} opacity={0.7}>
                  {fName}
                </text>
              )}
            </g>
          );
        })}

        {/* Dimension: Width */}
        <line x1={mx} y1={my - 12} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6} markerEnd="url(#arrowRS)" markerStart="url(#arrowLS)" />
        <text x={mx + drawW / 2} y={my - 16} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          A = {widthMm.toFixed(0)} mm (Ordered Width)
        </text>

        {/* Dimension: Height */}
        <line x1={mx - 18} y1={fabricTop} x2={mx - 18} y2={fabricTop + fabricH} stroke="#374151" strokeWidth={0.6} />
        <text x={mx - 22} y={fabricTop + fabricH / 2} textAnchor="middle" fontSize={6.5} fontWeight="bold" fill="#111827"
          transform={`rotate(-90, ${mx - 22}, ${fabricTop + fabricH / 2})`}>
          B = {heightMm.toFixed(0)} mm
        </text>

        {/* Hardware color label */}
        {hardwareColor && (
          <text x={svgW - mx} y={svgH - 8} textAnchor="end" fontSize={6} fill="#9ca3af">
            Hardware: {hardwareColor}
          </text>
        )}

        {/* No rotation warning */}
        <text x={mx + drawW / 2} y={svgH - 8} textAnchor="middle" fontSize={6} fill="#dc2626" fontWeight="bold">
          ⚠ No fabric rotation — max panel width = roll width
        </text>
      </svg>

      {/* Specs */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-xs px-1">
        <div className="flex justify-between"><span className="text-gray-500">Ordered size</span><span className="font-medium">{widthMm} × {heightMm} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Type</span><span className="font-medium capitalize">{shadeType} Shade</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Panels</span><span className="font-medium">{totalPanels}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Layers</span><span className="font-medium">{layers.length}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operating system</span><span className="font-medium">{isMotor ? 'Motorized' : 'Manual'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operator side</span><span className="font-medium capitalize">{opSide}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Tube</span><span className="font-medium">{tubeType ?? '—'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Hardware color</span><span className="font-medium capitalize">{hardwareColor ?? '—'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Cassette</span><span className="font-medium">{hasCassette ? 'Yes' : 'No'}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Side channels</span><span className="font-medium">{hasSideChannel ? 'Yes' : 'No'}</span></div>
      </div>
    </div>
  );
}
