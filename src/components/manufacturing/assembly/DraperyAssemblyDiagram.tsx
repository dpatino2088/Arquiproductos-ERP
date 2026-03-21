interface DraperyAssemblyDiagramProps {
  widthMm: number;
  heightMm: number;
  panelCount: number;
  panelWidths?: number[];
  openingDirection: 'left' | 'center' | 'right';
  driveSide?: 'left' | 'right' | null;
  operatingSystem: 'manual' | 'motorized' | 'motor' | null;
  hasTrack: boolean;
  fabricName?: string | null;
  fullnessFactor?: number;
}

export default function DraperyAssemblyDiagram({
  widthMm,
  heightMm,
  panelCount,
  openingDirection,
  driveSide,
  operatingSystem,
  hasTrack,
  fabricName,
  fullnessFactor,
}: DraperyAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const totalPanels = panelCount || 1;
  const fullness = fullnessFactor ?? 2;
  const fabricWidthMm = widthMm * fullness;

  // Motor side: for left/right opening, motor is on the same side as opening.
  // For center, use explicit driveSide from config.
  const motorSide: 'left' | 'right' =
    driveSide ?? (openingDirection === 'right' ? 'right' : 'left');

  // Stack accumulates on the motor side (where the curtain gathers when open)
  const stackSide = motorSide;

  const svgW = 520;
  const svgH = 340;
  const mx = 55;
  const my = 50;
  const drawW = svgW - mx * 2;
  const drawH = svgH - my - 70;

  const trackH = 10;
  const trackY = my;
  const panelTop = trackY + trackH + 6;
  const panelH = drawH - trackH - 16;

  // Bracket sizes: motor side is bigger
  const motorBracketW = 14;
  const motorBracketH = trackH + 14;
  const endBracketW = 8;
  const endBracketH = trackH + 8;

  const leftIsMotor = motorSide === 'left';

  const renderSinglePanel = () => {
    // Stack fraction: the gathered part takes ~30% of width
    const stackFraction = 0.3;
    const stackW = drawW * stackFraction;
    const visibleW = drawW - stackW;

    const stackX = stackSide === 'left' ? mx : mx + visibleW;
    const visibleX = stackSide === 'left' ? mx + stackW : mx;

    const foldCount = 7;

    return (
      <>
        {/* Visible (open) area — dashed outline, no fill */}
        <rect
          x={visibleX} y={panelTop} width={visibleW} height={panelH}
          fill="none" stroke="#9ca3af" strokeWidth={0.8} strokeDasharray="4 3"
        />
        <text
          x={visibleX + visibleW / 2} y={panelTop + panelH / 2 + 2}
          textAnchor="middle" fontSize={7} fill="#9ca3af" fontStyle="italic"
        >
          visible area
        </text>

        {/* Stack (gathered) area — solid fill with fold lines */}
        <rect
          x={stackX} y={panelTop} width={stackW} height={panelH}
          fill="#dbeafe" stroke="#93c5fd" strokeWidth={0.8}
        />
        {Array.from({ length: foldCount }).map((_, i) => {
          const spacing = stackW / (foldCount + 1);
          const xPos = stackX + spacing * (i + 1);
          return (
            <line key={`fold-${i}`}
              x1={xPos} y1={panelTop + 2} x2={xPos} y2={panelTop + panelH - 2}
              stroke="#93c5fd" strokeWidth={0.5} opacity={0.7}
            />
          );
        })}
        <text
          x={stackX + stackW / 2} y={panelTop + panelH / 2 - 6}
          textAnchor="middle" fontSize={7} fontWeight="600" fill="#3b82f6"
        >
          STACK
        </text>
        {fabricName && (
          <text
            x={stackX + stackW / 2} y={panelTop + panelH / 2 + 6}
            textAnchor="middle" fontSize={5.5} fill="#60a5fa"
          >
            {fabricName}
          </text>
        )}

        {/* Arrow showing opening direction */}
        {stackSide === 'left' && (
          <line
            x1={visibleX + 10} y1={panelTop + panelH / 2 + 18}
            x2={visibleX + visibleW - 20} y2={panelTop + panelH / 2 + 18}
            stroke="#6b7280" strokeWidth={0.8} markerEnd="url(#arrowR)"
          />
        )}
        {stackSide === 'right' && (
          <line
            x1={visibleX + visibleW - 10} y1={panelTop + panelH / 2 + 18}
            x2={visibleX + 20} y2={panelTop + panelH / 2 + 18}
            stroke="#6b7280" strokeWidth={0.8} markerEnd="url(#arrowL)"
          />
        )}
      </>
    );
  };

  const renderCenterPanels = () => {
    const halfW = drawW / 2;
    const stackFraction = 0.3;
    const stackW = halfW * stackFraction;
    const visibleW = halfW - stackW;

    const foldCount = 5;

    return (
      <>
        {/* LEFT PANEL */}
        {/* Left stack (gathered at left edge) */}
        <rect
          x={mx} y={panelTop} width={stackW} height={panelH}
          fill="#dbeafe" stroke="#93c5fd" strokeWidth={0.8}
        />
        {Array.from({ length: foldCount }).map((_, i) => {
          const spacing = stackW / (foldCount + 1);
          return (
            <line key={`fl-${i}`}
              x1={mx + spacing * (i + 1)} y1={panelTop + 2}
              x2={mx + spacing * (i + 1)} y2={panelTop + panelH - 2}
              stroke="#93c5fd" strokeWidth={0.4} opacity={0.6}
            />
          );
        })}
        {/* Left visible area */}
        <rect
          x={mx + stackW} y={panelTop} width={visibleW - 1} height={panelH}
          fill="none" stroke="#9ca3af" strokeWidth={0.8} strokeDasharray="4 3"
        />

        {/* RIGHT PANEL */}
        {/* Right visible area */}
        <rect
          x={mx + halfW + 1} y={panelTop} width={visibleW - 1} height={panelH}
          fill="none" stroke="#9ca3af" strokeWidth={0.8} strokeDasharray="4 3"
        />
        {/* Right stack (gathered at right edge) */}
        <rect
          x={mx + drawW - stackW} y={panelTop} width={stackW} height={panelH}
          fill="#ede9fe" stroke="#a78bfa" strokeWidth={0.8}
        />
        {Array.from({ length: foldCount }).map((_, i) => {
          const spacing = stackW / (foldCount + 1);
          return (
            <line key={`fr-${i}`}
              x1={mx + drawW - stackW + spacing * (i + 1)} y1={panelTop + 2}
              x2={mx + drawW - stackW + spacing * (i + 1)} y2={panelTop + panelH - 2}
              stroke="#a78bfa" strokeWidth={0.4} opacity={0.6}
            />
          );
        })}

        {/* Center opening arrows */}
        <line
          x1={mx + halfW - 4} y1={panelTop + panelH / 2}
          x2={mx + stackW + 10} y2={panelTop + panelH / 2}
          stroke="#6b7280" strokeWidth={0.8} markerEnd="url(#arrowL)"
        />
        <line
          x1={mx + halfW + 4} y1={panelTop + panelH / 2}
          x2={mx + drawW - stackW - 10} y2={panelTop + panelH / 2}
          stroke="#6b7280" strokeWidth={0.8} markerEnd="url(#arrowR)"
        />

        {/* Labels */}
        <text x={mx + stackW / 2} y={panelTop + panelH / 2} textAnchor="middle" fontSize={6} fill="#3b82f6">
          Stack L
        </text>
        <text x={mx + drawW - stackW / 2} y={panelTop + panelH / 2} textAnchor="middle" fontSize={6} fill="#7c3aed">
          Stack R
        </text>
      </>
    );
  };

  return (
    <div className="space-y-3">
      <svg viewBox={`0 0 ${svgW} ${svgH}`} className="w-full max-w-[540px]" style={{ fontFamily: 'system-ui, sans-serif' }}>
        <defs>
          <marker id="arrowR" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#374151" />
          </marker>
          <marker id="arrowL" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#374151" />
          </marker>
        </defs>

        {/* ── Track / Rail ── */}
        {hasTrack && (
          <rect
            x={mx} y={trackY} width={drawW} height={trackH} rx={2}
            fill="#d1d5db" stroke="#9ca3af" strokeWidth={1}
          />
        )}
        {hasTrack && (
          <text x={mx + drawW / 2} y={trackY + trackH / 2 + 3} textAnchor="middle" fontSize={6.5} fill="#4b5563">
            TRACK / RAIL
          </text>
        )}

        {/* ── Left bracket ── */}
        {(() => {
          const bw = leftIsMotor ? motorBracketW : endBracketW;
          const bh = leftIsMotor ? motorBracketH : endBracketH;
          const by = trackY + trackH / 2 - bh / 2;
          return (
            <rect
              x={mx - bw + 2} y={by} width={bw} height={bh} rx={2}
              fill={leftIsMotor ? '#d1d5db' : '#bfc5cd'}
              stroke="#6b7280" strokeWidth={0.8}
            />
          );
        })()}

        {/* ── Right bracket ── */}
        {(() => {
          const bw = !leftIsMotor ? motorBracketW : endBracketW;
          const bh = !leftIsMotor ? motorBracketH : endBracketH;
          const by = trackY + trackH / 2 - bh / 2;
          return (
            <rect
              x={mx + drawW - 2} y={by} width={bw} height={bh} rx={2}
              fill={!leftIsMotor ? '#d1d5db' : '#bfc5cd'}
              stroke="#6b7280" strokeWidth={0.8}
            />
          );
        })()}

        {/* ── Motor indicator "M" on the motor-side bracket ── */}
        {isMotor && (() => {
          const bw = motorBracketW;
          const bh = motorBracketH;
          const by = trackY + trackH / 2 - bh / 2;
          const bx = leftIsMotor ? mx - bw + 2 : mx + drawW - 2;
          return (
            <>
              <rect
                x={bx} y={by} width={bw} height={bh} rx={2}
                fill="#fbbf24" stroke="#d97706" strokeWidth={0.8}
              />
              <text
                x={bx + bw / 2} y={by + bh / 2 + 4}
                textAnchor="middle" fontSize={8} fill="#92400e" fontWeight="bold"
              >
                M
              </text>
            </>
          );
        })()}

        {/* ── Carriers (small dots along track) ── */}
        {Array.from({ length: Math.min(totalPanels * 8, 20) }).map((_, i) => {
          const cx = mx + 12 + i * ((drawW - 24) / Math.min(totalPanels * 8, 20));
          return (
            <circle key={`carr-${i}`} cx={cx} cy={trackY + trackH / 2} r={1.5}
              fill="#6b7280" opacity={0.5} />
          );
        })}

        {/* ── Fabric panels ── */}
        {openingDirection === 'center' ? renderCenterPanels() : renderSinglePanel()}

        {/* ── Hem weights at bottom ── */}
        <line
          x1={mx + 4} y1={panelTop + panelH + 3}
          x2={mx + drawW - 4} y2={panelTop + panelH + 3}
          stroke="#9ca3af" strokeWidth={2} strokeLinecap="round"
        />
        <text x={mx + drawW / 2} y={panelTop + panelH + 14} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          HEM WEIGHT
        </text>

        {/* ── Dimension: Overall Width (A) ── */}
        <line x1={mx} y1={my - 16} x2={mx + drawW} y2={my - 16} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx} y1={my - 20} x2={mx} y2={my - 12} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx + drawW} y1={my - 20} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6} />
        <text x={mx + drawW / 2} y={my - 22} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          A = {widthMm.toFixed(0)} mm (Track Width)
        </text>

        {/* ── Dimension: Height (B) ── */}
        <line x1={mx - 24} y1={panelTop} x2={mx - 24} y2={panelTop + panelH} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx - 28} y1={panelTop} x2={mx - 20} y2={panelTop} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx - 28} y1={panelTop + panelH} x2={mx - 20} y2={panelTop + panelH} stroke="#374151" strokeWidth={0.6} />
        <text
          x={mx - 30} y={panelTop + panelH / 2}
          textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827"
          transform={`rotate(-90, ${mx - 30}, ${panelTop + panelH / 2})`}
        >
          B = {heightMm.toFixed(0)} mm
        </text>

        {/* ── Opening direction label ── */}
        <text x={mx + drawW / 2} y={svgH - 16} textAnchor="middle" fontSize={8} fill="#6b7280" fontWeight="bold">
          Opening: {openingDirection.charAt(0).toUpperCase() + openingDirection.slice(1)}
          {isMotor ? `  ·  Motor: ${motorSide.charAt(0).toUpperCase() + motorSide.slice(1)}` : ''}
        </text>
      </svg>

      {/* Specs summary */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-xs px-1">
        <div className="flex justify-between"><span className="text-gray-500">Track width</span><span className="font-medium">{widthMm} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Drop</span><span className="font-medium">{heightMm} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Opening</span><span className="font-medium capitalize">{openingDirection}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Panels</span><span className="font-medium">{totalPanels}</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Fullness</span><span className="font-medium">{fullness}×</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Fabric width (with fullness)</span><span className="font-medium">{Math.round(fabricWidthMm)} mm</span></div>
        <div className="flex justify-between"><span className="text-gray-500">Operating system</span><span className="font-medium">{isMotor ? 'Motorized' : 'Manual'}</span></div>
        {isMotor && <div className="flex justify-between"><span className="text-gray-500">Motor side</span><span className="font-medium capitalize">{motorSide}</span></div>}
      </div>
    </div>
  );
}
