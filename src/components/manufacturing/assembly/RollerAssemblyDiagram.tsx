import { Fragment, useState } from 'react';
import type { CutBreakdownItem, PanelCut, PanelDeduction } from './AssemblyDetail';

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
  tubeCutMm?: number | null;
  tubeCutsPerPanel?: number[];
  fabricCutMm?: number | null;
  bottomBarCutMm?: number | null;
  bottomBarCutsPerPanel?: number[];
  hardwareColor?: string | null;
  fabricName?: string | null;
  fabricLayers?: number;
  cutBreakdown?: CutBreakdownItem[] | null;
  bomTemplateCode?: string | null;
}

function formatRole(role: string): string {
  return role
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

const posLabel: Record<string, string> = { left: 'Izq', center: 'Centro', right: 'Der' };
const posBg: Record<string, string> = {
  left: 'bg-blue-50 text-blue-700',
  center: 'bg-amber-50 text-amber-700',
  right: 'bg-emerald-50 text-emerald-700',
};

function PanelCutsTable({ panels, isFabric }: { panels: PanelCut[]; isFabric?: boolean }) {
  const [expandedPanel, setExpandedPanel] = useState<number | null>(null);
  const formatSignedDeduction = (value: number) =>
    value === 0 ? '—' : `${value > 0 ? '−' : '+'}${Math.abs(value).toFixed(1)}`;
  if (!panels || panels.length === 0) return null;
  return (
    <div className="mt-1.5 border border-gray-100 rounded overflow-hidden">
      <table className="w-full text-[10px]">
        <thead>
          <tr className="bg-gray-50 text-gray-500">
            <th className="text-left px-2 py-1">Panel</th>
            <th className="text-center px-2 py-1">Pos</th>
            <th className="text-right px-2 py-1">Base</th>
            <th className="text-right px-2 py-1 text-red-500">Desc.</th>
            <th className="text-right px-2 py-1 font-bold text-blue-600">Corte</th>
            {isFabric && <th className="text-right px-2 py-1 text-purple-600">Alto</th>}
          </tr>
        </thead>
        <tbody>
          {panels.map((p) => {
            const deds = (p.deductions ?? []) as PanelDeduction[];
            const hasDeds = deds.length > 0;
            const isOpen = expandedPanel === p.panel;
            const panelDeduction = p.calc_ded ?? p.deduction;
            return (
              <Fragment key={p.panel}>
                <tr
                  className={`border-t border-gray-50 ${hasDeds ? 'cursor-pointer hover:bg-gray-50' : ''}`}
                  onClick={() => hasDeds && setExpandedPanel(isOpen ? null : p.panel)}
                >
                  <td className="px-2 py-1 font-medium text-gray-700">
                    <span className="inline-flex items-center gap-1">
                      {hasDeds && (
                        <svg className={`w-2.5 h-2.5 text-gray-400 transition-transform ${isOpen ? 'rotate-90' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                        </svg>
                      )}
                      #{p.panel}
                    </span>
                  </td>
                  <td className="px-2 py-1 text-center">
                    <span className={`text-[9px] px-1.5 py-0.5 rounded font-medium ${posBg[p.position] ?? ''}`}>
                      {posLabel[p.position] ?? p.position}
                    </span>
                  </td>
                  <td className="px-2 py-1 text-right text-gray-600">{p.base_mm.toFixed(1)}</td>
                  <td className="px-2 py-1 text-right font-semibold text-red-600">
                    {formatSignedDeduction(panelDeduction)}
                  </td>
                  <td className="px-2 py-1 text-right font-bold text-blue-700">{p.cut_mm.toFixed(1)}</td>
                  {isFabric && (
                    <td className="px-2 py-1 text-right text-purple-700">
                      {p.cut_height != null ? p.cut_height.toFixed(1) : '—'}
                    </td>
                  )}
                </tr>
                {isOpen && deds.length > 0 && (
                  <tr>
                    <td colSpan={isFabric ? 6 : 5} className="px-3 py-1.5 bg-gray-50/50">
                      <div className="font-mono text-[10px] space-y-0.5 pl-3">
                        {deds.map((d, i) => (
                          <div key={i} className="flex justify-between text-gray-600">
                            <span>
                              − {formatRole(d.role)}
                              {d.qty > 1 ? ` ×${d.qty}` : ''}
                              <span className="text-gray-400 ml-1">({d.sku})</span>
                              {d.note && <span className="text-[9px] ml-1 text-amber-600">[{d.note}]</span>}
                            </span>
                            {d.mode === 'info' ? (
                              <span className="text-slate-500">Info</span>
                            ) : (
                              <span className="text-red-600">{formatSignedDeduction(d.total)}</span>
                            )}
                          </div>
                        ))}
                        <div className="border-t border-gray-200 pt-0.5 flex justify-between font-semibold text-gray-800">
                          <span>= Corte</span>
                          <span className="text-blue-700">{p.cut_mm.toFixed(1)} mm</span>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function BreakdownItemRow({ item }: { item: CutBreakdownItem }) {
  const [open, setOpen] = useState(false);
  const isFabric = item.role === 'fabric';
  const deductions = item.deductions ?? [];
  const nonConditional = deductions.filter((d) => !d.conditional);
  const conditional = deductions.filter((d) => d.conditional);
  const hasPerPanel = item.per_panel && (item.panel_cuts?.length ?? 0) > 0;
  const panelCount = item.panel_count ?? 1;

  return (
    <div className="border-b border-gray-100 last:border-b-0">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="w-full flex items-center justify-between px-3 py-2 hover:bg-gray-50 transition-colors"
      >
        <div className="flex items-center gap-2 min-w-0">
          <svg
            className={`w-3.5 h-3.5 text-gray-400 shrink-0 transition-transform duration-200 ${open ? 'rotate-90' : ''}`}
            fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
          <span className="text-xs font-bold text-gray-800 truncate">{item.label}</span>
          {item.sku !== '?' && (
            <span className="text-[10px] text-gray-400 font-mono shrink-0">{item.sku}</span>
          )}
          <span
            className={`text-[10px] px-1.5 py-0.5 rounded font-medium shrink-0 ${
              item.axis === 'height'
                ? 'bg-purple-50 text-purple-600'
                : item.axis === 'special'
                  ? 'bg-amber-50 text-amber-600'
                  : 'bg-blue-50 text-blue-600'
            }`}
          >
            {item.axis === 'height' ? '↕ H' : item.axis === 'special' ? '⊞' : '↔ W'}
          </span>
          {hasPerPanel && (
            <span className="text-[9px] px-1.5 py-0.5 rounded bg-gray-100 text-gray-600 font-medium shrink-0">
              {panelCount}p
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 shrink-0">
          {!hasPerPanel && !isFabric && (
            <span className="text-[11px] font-mono font-semibold text-blue-700">
              {item.resolved_mm.toFixed(1)} mm
            </span>
          )}
          {item.match !== undefined && (
            <span
              className={`text-[9px] px-1 py-0.5 rounded font-medium ${
                item.match ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
              }`}
            >
              {item.match ? '✓' : '⚠'}
            </span>
          )}
        </div>
      </button>

      {open && (
        <div className="px-3 pb-2.5 pl-8 space-y-1.5">
          <div className="font-mono text-[11px] leading-relaxed space-y-0.5">
            {isFabric ? (
              <>
                {deductions.map((d, i) => (
                  <div key={i} className="flex justify-between text-gray-600">
                    <span>{d.label ?? formatRole(d.role)}</span>
                    <span className={d.total > 0 ? 'text-green-600' : 'text-red-600'}>
                      {d.total > 0 ? '+' : ''}{d.total.toFixed(1)} mm
                    </span>
                  </div>
                ))}
                {!hasPerPanel && (
                  <>
                    <div className="border-t border-gray-200 pt-1 flex justify-between font-semibold text-gray-900">
                      <span>Ancho corte</span>
                      <span className="text-blue-700">{(item.fabric_width_mm ?? item.resolved_mm).toFixed(1)} mm</span>
                    </div>
                    {item.resolved_height_mm != null && (
                      <div className="flex justify-between font-semibold text-gray-900">
                        <span>Alto corte</span>
                        <span className="text-blue-700">{item.resolved_height_mm.toFixed(1)} mm</span>
                      </div>
                    )}
                  </>
                )}
              </>
            ) : (
              <>
                <div className="flex justify-between text-gray-500 text-[10px]">
                  <span>Ancho total: {item.base_label}</span>
                  <span>{item.base_mm.toFixed(1)} mm</span>
                </div>

                {item.tolerance_mm !== 0 && (
                  <div className="flex justify-between text-gray-600">
                    <span>Tolerancia</span>
                    <span className={item.tolerance_mm > 0 ? 'text-green-600' : 'text-orange-500'}>
                      {item.tolerance_mm > 0 ? '+' : ''}{item.tolerance_mm.toFixed(1)} mm
                    </span>
                  </div>
                )}

                {(nonConditional.length > 0 || conditional.length > 0) && (
                  <div className="text-[10px] text-gray-400 mt-1">Descuentos aplicables:</div>
                )}
                {nonConditional.map((d, i) => (
                  <div key={`f-${i}`} className="flex justify-between text-gray-600">
                    <span>
                      − {formatRole(d.role)}
                      {d.qty > 1 ? ` ×${d.qty}` : ''}
                      <span className="text-gray-400 ml-1 text-[10px]">({d.sku})</span>
                    </span>
                    {d.mode === 'info' ? (
                      <span className="text-slate-500">Info</span>
                    ) : (
                      <span className="text-red-600">−{Math.abs(d.total).toFixed(1)} mm</span>
                    )}
                  </div>
                ))}
                {conditional.length > 0 && (
                  <div className="mt-0.5 pt-0.5 border-t border-dashed border-gray-200">
                    {conditional.map((d, i) => (
                      <div key={`c-${i}`} className="flex justify-between text-gray-500">
                        <span>
                          − {formatRole(d.role)}
                          {d.qty > 1 ? ` ×${d.qty}` : ''}
                          <span className="text-gray-400 ml-1 text-[10px]">({d.sku})</span>
                          <span className="text-[9px] ml-1 text-amber-500">[cond]</span>
                        </span>
                        {d.mode === 'info' ? (
                          <span className="text-slate-400">Info</span>
                        ) : (
                          <span className="text-red-400">−{Math.abs(d.total).toFixed(1)} mm</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {!hasPerPanel && (
                  <>
                    <div className="border-t border-gray-200 pt-1 flex justify-between font-semibold text-gray-900">
                      <span>= Corte</span>
                      <span className="text-blue-700">{item.resolved_mm.toFixed(1)} mm</span>
                    </div>
                    {item.instance_cut_mm != null && !item.match && (
                      <div className="flex justify-between text-[10px] text-red-500">
                        <span>Instancia almacenada</span>
                        <span>{item.instance_cut_mm.toFixed(1)} mm</span>
                      </div>
                    )}
                  </>
                )}
              </>
            )}
          </div>

          {hasPerPanel && (
            <PanelCutsTable panels={item.panel_cuts!} isFabric={isFabric} />
          )}
        </div>
      )}
    </div>
  );
}

function BreakdownSection({ items, templateCode }: { items: CutBreakdownItem[]; templateCode?: string | null }) {
  if (!items || items.length === 0) return null;

  return (
    <div className="border border-gray-200 rounded-lg overflow-hidden">
      <div className="px-3 py-2 bg-gray-50 border-b border-gray-100 flex items-center justify-between">
        <h5 className="text-xs font-semibold text-gray-700">Engineering Breakdown (Auditable)</h5>
        {templateCode && (
          <span className="text-[10px] font-mono text-blue-600 bg-blue-50 px-1.5 py-0.5 rounded">
            {templateCode}
          </span>
        )}
      </div>
      <div>
        {items.map((item) => (
          <BreakdownItemRow key={item.role} item={item} />
        ))}
      </div>
      <div className="px-3 py-1.5 text-[10px] text-gray-400 bg-gray-50 border-t border-gray-100">
        Datos: Template BOM cascade + FabricRules, verificado contra instance lines.
      </div>
    </div>
  );
}

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
  tubeCutMm,
  tubeCutsPerPanel,
  fabricCutMm,
  bottomBarCutMm,
  bottomBarCutsPerPanel,
  hardwareColor,
  fabricName,
  fabricLayers,
  cutBreakdown,
  bomTemplateCode,
}: RollerAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const opSide = operatingSide ?? 'right';
  const brkW = 14;
  const intBrkW = 10;

  const totalPanels = panelCount || 1;
  const isMultiPanel = totalPanels > 1;
  const pWidths = panelWidths && panelWidths.length === totalPanels
    ? panelWidths
    : Array.from({ length: totalPanels }, () => widthMm / totalPanels);

  const pTubeCuts = tubeCutsPerPanel && tubeCutsPerPanel.length === totalPanels
    ? tubeCutsPerPanel
    : null;

  const effectiveTubeCutMm = tubeCutMm != null ? Number(tubeCutMm) : widthMm;

  // Proportional SVG: aspect ratio clamped between 0.5 and 3
  const maxSvgW = 540;
  const aspectRatio = widthMm > 0 && heightMm > 0 ? widthMm / heightMm : 1.5;
  const clamped = Math.max(0.5, Math.min(3, aspectRatio));
  const svgW = maxSvgW;
  const svgH = Math.max(240, Math.min(500, Math.round(maxSvgW / clamped)));

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
  const panelColors = ['#dbeafe', '#ede9fe', '#fce7f3', '#fef3c7', '#d1fae5'];

  const hasCutBreakdown = cutBreakdown && cutBreakdown.length > 0;

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

        {/* Multi-panel: per-panel tubes with intermediate brackets */}
        {isMultiPanel ? (() => {
          const innerW = drawW - brkW * 2;
          const totalIntBrk = (totalPanels - 1) * intBrkW;
          const tubeAreaW = innerW - totalIntBrk;
          let xOff = mx + brkW;

          return pWidths.map((pw, i) => {
            const pTubeW = (pw / widthMm) * tubeAreaW;
            const cutLabel = pTubeCuts ? `${pTubeCuts[i]?.toFixed(0)}` : `${pw.toFixed(0)}`;
            const els = (
              <g key={`tube-panel-${i}`}>
                <rect x={xOff} y={my + cassetteH} width={pTubeW} height={tubeH} rx={2}
                  fill="#d1d5db" stroke="#9ca3af" strokeWidth={1} />
                <text x={xOff + pTubeW / 2} y={my + cassetteH + tubeH / 2 + 3} textAnchor="middle" fontSize={5.5} fill="#4b5563">
                  {cutLabel} mm
                </text>
                {i < totalPanels - 1 && (
                  <>
                    <rect x={xOff + pTubeW} y={my + cassetteH - 3} width={intBrkW} height={bracketH} rx={2}
                      fill="#f59e0b" stroke="#d97706" strokeWidth={0.8} />
                    <text x={xOff + pTubeW + intBrkW / 2} y={my + cassetteH + bracketH + 10} textAnchor="middle" fontSize={4.5} fill="#d97706">
                      Joint
                    </text>
                  </>
                )}
              </g>
            );
            xOff += pTubeW + (i < totalPanels - 1 ? intBrkW : 0);
            return els;
          });
        })() : (
          <>
            <rect x={mx + brkW} y={my + cassetteH} width={drawW - brkW * 2} height={tubeH} rx={2}
              fill="#d1d5db" stroke="#9ca3af" strokeWidth={1} />
            <text x={mx + drawW / 2} y={my + cassetteH + tubeH / 2 + 3} textAnchor="middle" fontSize={6.5} fill="#4b5563">
              TUBE {tubeType ?? ''}
            </text>
          </>
        )}

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

        {/* Fabric panels */}
        {(() => {
          const fabricAreaW = drawW - brkW * 2 - sideChW * 2;
          let xOff = mx + brkW + sideChW;
          const gapW = isMultiPanel ? 3 : 0;
          const totalGaps = isMultiPanel ? (totalPanels - 1) * gapW : 0;
          const netFabricW = fabricAreaW - totalGaps;

          return pWidths.map((pw, i) => {
            const pW = (pw / widthMm) * netFabricW;
            const el = (
              <g key={`fabric-${i}`}>
                <rect x={xOff} y={fabricTop} width={pW} height={fabricH}
                  fill={panelColors[i % panelColors.length]} stroke="#93c5fd" strokeWidth={0.6}
                  strokeDasharray={isMultiPanel ? '4,2' : 'none'} />
                {isMultiPanel && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 + 3} textAnchor="middle" fontSize={7} fill="#3b82f6">
                    Panel {i + 1}
                  </text>
                )}
                {!isMultiPanel && fabricName && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 - 4} textAnchor="middle" fontSize={7} fill="#6b7280" opacity={0.7}>
                    FABRIC
                  </text>
                )}
                {!isMultiPanel && (
                  <text x={xOff + pW / 2} y={fabricTop + fabricH / 2 + 8} textAnchor="middle" fontSize={6} fill="#93c5fd">
                    {fabricName ?? ''}
                  </text>
                )}
              </g>
            );
            xOff += pW + (i < totalPanels - 1 ? gapW : 0);
            return el;
          });
        })()}

        {/* Fabric layers badge (Dual / Triple Shade) */}
        {(fabricLayers ?? 1) > 1 && (
          <g>
            <rect x={mx + drawW - brkW - 56} y={fabricTop + fabricH - 16} width={52} height={13} rx={3}
              fill="#7c3aed" fillOpacity={0.12} stroke="#7c3aed" strokeWidth={0.5} />
            <text x={mx + drawW - brkW - 30} y={fabricTop + fabricH - 7} textAnchor="middle"
              fontSize={6.5} fontWeight="bold" fill="#7c3aed">
              H × {fabricLayers}
            </text>
          </g>
        )}

        {/* Bottom bar */}
        {hasBottomBar && (() => {
          const barAreaW = drawW - brkW * 2 - sideChW * 2;
          if (isMultiPanel) {
            const gapW = 3;
            const totalGaps = (totalPanels - 1) * gapW;
            const netBarW = barAreaW - totalGaps;
            let xOff = mx + brkW + sideChW;
            return pWidths.map((pw, i) => {
              const pW = (pw / widthMm) * netBarW;
              const barEl = (
                <g key={`bar-${i}`}>
                  <rect x={xOff} y={fabricTop + fabricH} width={pW} height={hemBarH} rx={1}
                    fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.6} />
                </g>
              );
              xOff += pW + (i < totalPanels - 1 ? gapW : 0);
              return barEl;
            });
          }
          return (
            <rect x={mx + brkW + sideChW} y={fabricTop + fabricH} width={barAreaW} height={hemBarH} rx={1}
              fill="#d1d5db" stroke="#9ca3af" strokeWidth={0.6} />
          );
        })()}
        {hasBottomBar && !isMultiPanel && (
          <text x={mx + drawW / 2} y={fabricTop + fabricH + hemBarH / 2 + 2.5} textAnchor="middle" fontSize={5.5} fill="#6b7280">
            BOTTOM BAR
          </text>
        )}

        {/* Dimension: Finished Width */}
        <line x1={mx} y1={my - 12} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6} markerEnd="url(#arrowR)" markerStart="url(#arrowL)" />
        <text x={mx + drawW / 2} y={my - 16} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          Finished Width: {scaleForDim(widthMm)} mm
        </text>

        {/* Dimension: Height */}
        <line x1={mx - 18} y1={fabricTop} x2={mx - 18} y2={fabricTop + fabricH + hemBarH} stroke="#374151" strokeWidth={0.6} />
        <text x={mx - 22} y={fabricTop + (fabricH + hemBarH) / 2} textAnchor="middle" fontSize={6.5} fontWeight="bold" fill="#111827"
          transform={`rotate(-90, ${mx - 22}, ${fabricTop + (fabricH + hemBarH) / 2})`}>
          Height: {scaleForDim(heightMm)} mm{(fabricLayers ?? 1) > 1 ? ` (× ${fabricLayers} layers)` : ''}
        </text>

        {/* Dimension: Tube cut */}
        {!isMultiPanel && (
          <>
            <line x1={mx + brkW} y1={my + cassetteH + tubeH + 18} x2={mx + drawW - brkW} y2={my + cassetteH + tubeH + 18}
              stroke="#2563eb" strokeWidth={0.5} markerEnd="url(#arrowBlueR)" markerStart="url(#arrowBlueL)" />
            <text x={mx + drawW / 2} y={my + cassetteH + tubeH + 27} textAnchor="middle" fontSize={6.5} fontWeight="600" fill="#2563eb">
              Tube Cut: {scaleForDim(effectiveTubeCutMm)} mm
            </text>
          </>
        )}

        {/* Arrow markers */}
        <defs>
          <marker id="arrowR" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#374151" />
          </marker>
          <marker id="arrowL" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#374151" />
          </marker>
          <marker id="arrowBlueR" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
            <path d="M0,0 L6,2 L0,4" fill="#2563eb" />
          </marker>
          <marker id="arrowBlueL" markerWidth="6" markerHeight="4" refX="1" refY="2" orient="auto">
            <path d="M6,0 L0,2 L6,4" fill="#2563eb" />
          </marker>
        </defs>

        {/* Hardware color */}
        {hardwareColor && (
          <text x={svgW - mx} y={svgH - 8} textAnchor="end" fontSize={6} fill="#9ca3af">
            Hardware: {hardwareColor}
          </text>
        )}
      </svg>

      {/* Auditable breakdown (from DB function) */}
      {hasCutBreakdown ? (
        <BreakdownSection items={cutBreakdown!} templateCode={bomTemplateCode} />
      ) : (
        <FallbackCutsTable
          widthMm={widthMm}
          effectiveTubeCutMm={effectiveTubeCutMm}
          fabricCutMm={fabricCutMm}
          bottomBarCutMm={bottomBarCutMm}
        />
      )}

      {/* Assembly specs summary */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-1 text-xs px-1">
        <div className="flex justify-between"><span className="text-gray-500">Finished size</span><span className="font-medium">{widthMm} × {heightMm} mm</span></div>
        {!isMultiPanel && (
          <div className="flex justify-between"><span className="text-gray-500">Tube cut</span><span className="font-medium text-blue-700">{effectiveTubeCutMm.toFixed(1)} mm</span></div>
        )}
        <div className="flex justify-between"><span className="text-gray-500">Panels</span><span className="font-medium">{totalPanels}{isMultiPanel ? ` (${totalPanels - 1} joints)` : ''}</span></div>
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

function FallbackCutsTable({
  widthMm, effectiveTubeCutMm, fabricCutMm, bottomBarCutMm,
}: {
  widthMm: number;
  effectiveTubeCutMm: number;
  fabricCutMm?: number | null;
  bottomBarCutMm?: number | null;
}) {
  const tubeDeductionMm = Math.max(0, widthMm - effectiveTubeCutMm);
  return (
    <div className="border border-gray-200 rounded-lg overflow-hidden">
      <div className="px-3 py-2 bg-gray-50 border-b border-gray-100">
        <h5 className="text-xs font-semibold text-gray-700">Engineering Cuts</h5>
      </div>
      <table className="w-full text-xs">
        <thead>
          <tr className="text-[10px] text-gray-500 border-b border-gray-100 bg-gray-50">
            <th className="text-left px-3 py-1.5">Part</th>
            <th className="text-center px-3 py-1.5">Base</th>
            <th className="text-center px-3 py-1.5 font-bold">Deduction</th>
            <th className="text-center px-3 py-1.5 font-bold">Cut</th>
          </tr>
        </thead>
        <tbody>
          <tr className="border-b border-gray-50">
            <td className="px-3 py-1.5 text-gray-700">Tube</td>
            <td className="px-3 py-1.5 text-center">{widthMm.toFixed(1)} mm</td>
            <td className="px-3 py-1.5 text-center font-semibold text-red-600">−{tubeDeductionMm.toFixed(1)} mm</td>
            <td className="px-3 py-1.5 text-center font-bold text-blue-700">{effectiveTubeCutMm.toFixed(1)} mm</td>
          </tr>
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
        Fallback view — detailed breakdown unavailable for this BOM instance.
      </div>
    </div>
  );
}
