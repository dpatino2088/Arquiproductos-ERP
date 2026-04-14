import { Fragment, useState } from 'react';
import type { CutBreakdownItem, PanelCut, PanelDeduction } from './AssemblyDetail';

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
  cutBreakdown,
  bomTemplateCode,
}: DraperyAssemblyDiagramProps) {
  const isMotor = operatingSystem === 'motorized' || operatingSystem === 'motor';
  const totalPanels = panelCount || 1;
  const fullness = fullnessFactor ?? 2;
  const fabricWidthMm = widthMm * fullness;

  const motorSide: 'left' | 'right' =
    driveSide ?? (openingDirection === 'right' ? 'right' : 'left');

  const stackSide = motorSide;

  // Proportional SVG
  const maxSvgW = 540;
  const aspectRatio = widthMm > 0 && heightMm > 0 ? widthMm / heightMm : 1.5;
  const clamped = Math.max(0.5, Math.min(3, aspectRatio));
  const svgW = maxSvgW;
  const svgH = Math.max(240, Math.min(500, Math.round(maxSvgW / clamped)));

  const mx = 55;
  const my = 50;
  const drawW = svgW - mx * 2;
  const drawH = svgH - my - 70;

  const trackH = 10;
  const trackY = my;
  const panelTop = trackY + trackH + 6;
  const panelH = drawH - trackH - 16;

  const motorBracketW = 14;
  const motorBracketH = trackH + 14;
  const endBracketW = 8;
  const endBracketH = trackH + 8;

  const leftIsMotor = motorSide === 'left';

  const hasCutBreakdown = cutBreakdown && cutBreakdown.length > 0;

  const renderSinglePanel = () => {
    const stackFraction = 0.3;
    const stackW = drawW * stackFraction;
    const visibleW = drawW - stackW;

    const stackX = stackSide === 'left' ? mx : mx + visibleW;
    const visibleX = stackSide === 'left' ? mx + stackW : mx;

    const foldCount = 7;

    return (
      <>
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
        <rect
          x={mx + stackW} y={panelTop} width={visibleW - 1} height={panelH}
          fill="none" stroke="#9ca3af" strokeWidth={0.8} strokeDasharray="4 3"
        />

        <rect
          x={mx + halfW + 1} y={panelTop} width={visibleW - 1} height={panelH}
          fill="none" stroke="#9ca3af" strokeWidth={0.8} strokeDasharray="4 3"
        />
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

        {/* Track / Rail */}
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

        {/* Left bracket */}
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

        {/* Right bracket */}
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

        {/* Motor indicator */}
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

        {/* Carriers */}
        {Array.from({ length: Math.min(totalPanels * 8, 20) }).map((_, i) => {
          const cx = mx + 12 + i * ((drawW - 24) / Math.min(totalPanels * 8, 20));
          return (
            <circle key={`carr-${i}`} cx={cx} cy={trackY + trackH / 2} r={1.5}
              fill="#6b7280" opacity={0.5} />
          );
        })}

        {/* Fabric panels */}
        {openingDirection === 'center' ? renderCenterPanels() : renderSinglePanel()}

        {/* Hem weights */}
        <line
          x1={mx + 4} y1={panelTop + panelH + 3}
          x2={mx + drawW - 4} y2={panelTop + panelH + 3}
          stroke="#9ca3af" strokeWidth={2} strokeLinecap="round"
        />
        <text x={mx + drawW / 2} y={panelTop + panelH + 14} textAnchor="middle" fontSize={5.5} fill="#6b7280">
          HEM WEIGHT
        </text>

        {/* Dimension: Overall Width */}
        <line x1={mx} y1={my - 16} x2={mx + drawW} y2={my - 16} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx} y1={my - 20} x2={mx} y2={my - 12} stroke="#374151" strokeWidth={0.6} />
        <line x1={mx + drawW} y1={my - 20} x2={mx + drawW} y2={my - 12} stroke="#374151" strokeWidth={0.6} />
        <text x={mx + drawW / 2} y={my - 22} textAnchor="middle" fontSize={7} fontWeight="bold" fill="#111827">
          A = {widthMm.toFixed(0)} mm (Track Width)
        </text>

        {/* Dimension: Height */}
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

        {/* Opening direction label */}
        <text x={mx + drawW / 2} y={svgH - 16} textAnchor="middle" fontSize={8} fill="#6b7280" fontWeight="bold">
          Opening: {openingDirection.charAt(0).toUpperCase() + openingDirection.slice(1)}
          {isMotor ? `  ·  Motor: ${motorSide.charAt(0).toUpperCase() + motorSide.slice(1)}` : ''}
        </text>
      </svg>

      {/* Auditable breakdown */}
      {hasCutBreakdown && <BreakdownSection items={cutBreakdown!} templateCode={bomTemplateCode} />}

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
