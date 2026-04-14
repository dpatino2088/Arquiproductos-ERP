import { X, Zap, AlertTriangle, Package, Scissors, Ruler, Printer } from 'lucide-react';
import { generateDraperyWorkOrderPDF, type DraperyWorkOrderData } from '../../lib/pdf/generateDraperyWorkOrderPDF';
import { formatDate } from '../../lib/utils';

export interface PanelCutDetailProps {
  moNumber: string;
  sku: string;
  itemName: string;
  productType: string;
  productWidthMm: number;
  productHeightMm: number;
  cutWidthMm: number;
  cutHeightMm: number;
  rollWidthMm: number;
  heatsealDirection?: 'horizontal' | 'vertical' | 'none';
  customerName?: string;
  soNumber?: string;
  productName?: string;
  rule: {
    tube_wrap_mm: number;
    bottom_wrap_mm: number;
    safety_margin_mm: number;
    top_hem_mm: number;
    bottom_hem_mm: number;
    side_hem_mm: number;
    panel_multiplier: number;
    fullness_factor: number;
    heatseal_price_per_m: number;
    waste_pct: number;
    bottom_bar_wrap_pct: number;
  };
  materials?: Array<{ sku: string; item_name: string; component_role: string; qty: number; uom: string }>;
  materialsLoading?: boolean;
  onClose?: () => void;
}

const PRODUCT_LABELS: Record<string, string> = {
  roller: 'Roller Shade',
  drapery: 'Drapery',
  dual_shade: 'Dual Shade',
  triple_shade: 'Triple Shade',
  roman_shade: 'Roman Shade',
  vertical: 'Vertical',
  honey_comb: 'Honey Comb',
};

export default function PanelCutDetail({
  moNumber, sku, itemName, productType,
  productWidthMm, productHeightMm,
  cutWidthMm, cutHeightMm, rollWidthMm,
  heatsealDirection = 'none',
  customerName, soNumber, productName,
  materials, materialsLoading,
  rule, onClose,
}: PanelCutDetailProps) {
  const EDGE_TRIM_MM = 10;
  const usableRollWidthMm = rollWidthMm > 0 ? rollWidthMm - EDGE_TRIM_MM * 2 : 0;
  const numDrops = usableRollWidthMm > 0 ? Math.ceil(cutWidthMm / usableRollWidthMm) : 1;
  const hsDir = heatsealDirection;
  const canJoin = hsDir !== 'none' && rule.heatseal_price_per_m > 0;
  const needsHeatseal = numDrops > 1 && canJoin;
  const notFabricable = numDrops > 1 && hsDir === 'none';

  let heatsealLengthM = 0;
  let heatsealCost = 0;
  const computedTotalDropMm = Math.max(
    0,
    productHeightMm
      + (rule.tube_wrap_mm || 0)
      + (rule.bottom_wrap_mm || 0)
      + (rule.safety_margin_mm || 0)
      + (rule.top_hem_mm || 0)
      + (rule.bottom_hem_mm || 0),
  );
  const effectiveCutHeightMm = computedTotalDropMm > 0 ? computedTotalDropMm : cutHeightMm;
  if (needsHeatseal) {
    if (hsDir === 'horizontal') {
      heatsealLengthM = cutWidthMm / 1000;
    } else {
      heatsealLengthM = effectiveCutHeightMm / 1000;
    }
    heatsealCost = heatsealLengthM * rule.heatseal_price_per_m * (numDrops - 1);
  }

  const totalFabricArea = numDrops * rollWidthMm * effectiveCutHeightMm;
  const panelArea = cutWidthMm * effectiveCutHeightMm;
  const trimWaste = totalFabricArea - panelArea;
  const trimWastePct = totalFabricArea > 0 ? Math.round((trimWaste / totalFabricArea) * 100) : 0;

  const lastDropUsed = cutWidthMm - (numDrops - 1) * usableRollWidthMm;
  const lastDropTrim = usableRollWidthMm - lastDropUsed;

  const isRoller = ['roller', 'dual_shade', 'triple_shade'].includes(productType);
  const isDrapery = productType === 'drapery';

  // --- SVG flat pattern dimensions (proportional to real panel) ---
  const maxSvgDim = 340;
  const marginLeft = 40;
  const marginRight = 50;
  const marginTop = 18;
  const marginBottom = 36;
  const availW = maxSvgDim - marginLeft - marginRight;
  const availH = maxSvgDim - marginTop - marginBottom;
  const panelRatio = cutWidthMm / (effectiveCutHeightMm || 1);
  let rectW: number, rectH: number;
  if (panelRatio > 1) {
    rectW = availW;
    rectH = Math.max(availW / panelRatio, 60);
  } else {
    rectH = availH;
    rectW = Math.max(availH * panelRatio, 60);
  }
  const svgW = rectW + marginLeft + marginRight;
  const svgH = rectH + marginTop + marginBottom;
  const rectX = marginLeft;
  const rectY = marginTop;

  const totalDropMm = effectiveCutHeightMm;
  const zones: Array<{ label: string; mm: number; color: string; textColor: string; type: 'fold' | 'zone' | 'area' }> = [];

  if (rule.safety_margin_mm > 0) zones.push({ label: `Safety +${rule.safety_margin_mm}mm`, mm: rule.safety_margin_mm, color: '#fef3c7', textColor: '#92400e', type: 'zone' });
  if (rule.tube_wrap_mm > 0) zones.push({ label: `Tube wrap +${rule.tube_wrap_mm}mm`, mm: rule.tube_wrap_mm, color: '#e0e7ff', textColor: '#3730a3', type: 'fold' });
  if (rule.top_hem_mm > 0) zones.push({ label: `Top hem +${rule.top_hem_mm}mm`, mm: rule.top_hem_mm, color: '#d1fae5', textColor: '#065f46', type: 'fold' });

  const topZoneMm = zones.reduce((s, z) => s + z.mm, 0);
  const bottomZones: typeof zones = [];
  if (rule.bottom_wrap_mm > 0) bottomZones.push({ label: `Bottom wrap +${rule.bottom_wrap_mm}mm`, mm: rule.bottom_wrap_mm, color: '#e0e7ff', textColor: '#3730a3', type: 'fold' });
  if (rule.bottom_hem_mm > 0) bottomZones.push({ label: `Bottom hem +${rule.bottom_hem_mm}mm`, mm: rule.bottom_hem_mm, color: '#d1fae5', textColor: '#065f46', type: 'fold' });

  const bottomZoneMm = bottomZones.reduce((s, z) => s + z.mm, 0);
  const visibleMm = Math.max(0, totalDropMm - topZoneMm - bottomZoneMm);
  const pxPerMm = rectH / (totalDropMm || 1);
  const cutHeightDeltaMm = Math.round((cutHeightMm || 0) - totalDropMm);
  const hasHeightMismatch = Math.abs(cutHeightDeltaMm) > 1;

  // Side hem zones for drapery
  const hasSideHems = rule.side_hem_mm > 0;
  const sideHemPx = hasSideHems ? Math.max(rectW * 0.08, 10) : 0;

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden shadow-lg">
      {/* Header */}
      <div className="px-4 py-3 border-b border-gray-200 bg-gradient-to-r from-gray-50 to-blue-50 flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Scissors className="w-4 h-4 text-blue-500" />
            <span className="text-sm font-semibold text-gray-900">
              {moNumber} · {productName || PRODUCT_LABELS[productType] || productType} · {productWidthMm}×{productHeightMm}mm
            </span>
          </div>
          <p className="text-[10px] text-gray-500 mt-0.5 ml-6">{sku} — {itemName}</p>
        </div>
        <div className="flex items-center gap-1">
          {isDrapery && (
            <button
              type="button"
              title="Print Drapery Work Order"
              className="p-1 rounded hover:bg-gray-200 text-gray-500 hover:text-gray-700"
              onClick={() => {
                const pdfData: DraperyWorkOrderData = {
                  moNumber, sku, itemName,
                  customerName, soNumber, productName,
                  materials: materials ?? [],
                  date: formatDate(new Date()),
                  productWidthMm, productHeightMm,
                  cutWidthMm, cutHeightMm, rollWidthMm,
                  rule, heatsealDirection: heatsealDirection as DraperyWorkOrderData['heatsealDirection'],
                };
                const pdf = generateDraperyWorkOrderPDF(pdfData);
                pdf.save(`DraperyWO-${moNumber}-${sku}.pdf`);
              }}
            >
              <Printer className="w-4 h-4" />
            </button>
          )}
          {onClose && (
            <button type="button" onClick={onClose} className="p-1 rounded hover:bg-gray-200 text-gray-400 hover:text-gray-600">
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      <div className="p-3 flex gap-4 flex-wrap lg:flex-nowrap items-start">
        {/* =================== SVG FLAT PATTERN =================== */}
        <div className="w-1/2 flex-shrink-0">
          <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2 flex items-center gap-1">
            <Ruler className="w-3 h-3" /> Flat Pattern
          </p>
          <svg viewBox={`0 0 ${svgW} ${svgH}`} style={{ width: '100%' }} className="border border-gray-100 rounded bg-gray-50">
            {/* Outer cut rectangle — dashed border */}
            <rect x={rectX} y={rectY} width={rectW} height={rectH} rx={2}
              fill="none" stroke="#9ca3af" strokeWidth={1.2} strokeDasharray="6 3" />

            {/* Top zones */}
            {(() => {
              let yPos = rectY;
              return zones.map((z, i) => {
                const h = z.mm * pxPerMm;
                const el = (
                  <g key={`top-${i}`}>
                    <rect x={rectX + 0.5} y={yPos + 0.5} width={rectW - 1} height={h} fill={z.color} opacity={0.7} />
                    {z.type === 'fold' && (
                      <line x1={rectX} y1={yPos + h} x2={rectX + rectW} y2={yPos + h}
                        stroke={z.textColor} strokeWidth={1} strokeDasharray="4 3" />
                    )}
                    {h > 8 && (
                      <text x={rectX + rectW / 2} y={yPos + h / 2 + 3} textAnchor="middle" fontSize={7} fill={z.textColor} fontWeight={500}>
                        {z.label}
                      </text>
                    )}
                  </g>
                );
                yPos += h;
                return el;
              });
            })()}

            {/* Visible area */}
            {(() => {
              const visY = rectY + topZoneMm * pxPerMm;
              const visH = visibleMm * pxPerMm;
              return (
                <g>
                  <rect x={rectX + sideHemPx} y={visY} width={rectW - sideHemPx * 2} height={visH}
                    fill="#eff6ff" stroke="#3b82f6" strokeWidth={1.5} rx={1} />
                  <text x={rectX + rectW / 2} y={visY + visH / 2 - 4} textAnchor="middle" fontSize={9} fill="#1d4ed8" fontWeight={600}>
                    Visible Area
                  </text>
                  <text x={rectX + rectW / 2} y={visY + visH / 2 + 8} textAnchor="middle" fontSize={8} fill="#3b82f6">
                    {productHeightMm}mm
                  </text>

                  {/* Side hems */}
                  {hasSideHems && (
                    <>
                      <rect x={rectX + 0.5} y={visY} width={sideHemPx} height={visH} fill="#d1fae5" opacity={0.6} />
                      <rect x={rectX + rectW - sideHemPx - 0.5} y={visY} width={sideHemPx} height={visH} fill="#d1fae5" opacity={0.6} />
                      <line x1={rectX + sideHemPx} y1={visY} x2={rectX + sideHemPx} y2={visY + visH}
                        stroke="#065f46" strokeWidth={0.8} strokeDasharray="3 2" />
                      <line x1={rectX + rectW - sideHemPx} y1={visY} x2={rectX + rectW - sideHemPx} y2={visY + visH}
                        stroke="#065f46" strokeWidth={0.8} strokeDasharray="3 2" />
                      <text x={rectX + sideHemPx / 2} y={visY + visH / 2} textAnchor="middle" fontSize={6} fill="#065f46"
                        transform={`rotate(-90, ${rectX + sideHemPx / 2}, ${visY + visH / 2})`}>
                        {rule.side_hem_mm}mm
                      </text>
                    </>
                  )}
                </g>
              );
            })()}

            {/* Bottom zones */}
            {(() => {
              let yPos = rectY + rectH - bottomZoneMm * pxPerMm;
              return bottomZones.map((z, i) => {
                const h = z.mm * pxPerMm;
                const el = (
                  <g key={`bot-${i}`}>
                    <rect x={rectX + 0.5} y={yPos + 0.5} width={rectW - 1} height={h} fill={z.color} opacity={0.7} />
                    <line x1={rectX} y1={yPos} x2={rectX + rectW} y2={yPos}
                      stroke={z.textColor} strokeWidth={1} strokeDasharray="4 3" />
                    {h > 8 && (
                      <text x={rectX + rectW / 2} y={yPos + h / 2 + 3} textAnchor="middle" fontSize={7} fill={z.textColor} fontWeight={500}>
                        {z.label}
                      </text>
                    )}
                  </g>
                );
                yPos += h;
                return el;
              });
            })()}

            {/* Total drop dimension arrow (right side) */}
            <line x1={rectX + rectW + 8} y1={rectY} x2={rectX + rectW + 8} y2={rectY + rectH}
              stroke="#6b7280" strokeWidth={0.8} />
            <line x1={rectX + rectW + 5} y1={rectY} x2={rectX + rectW + 11} y2={rectY}
              stroke="#6b7280" strokeWidth={0.8} />
            <line x1={rectX + rectW + 5} y1={rectY + rectH} x2={rectX + rectW + 11} y2={rectY + rectH}
              stroke="#6b7280" strokeWidth={0.8} />
            <text x={rectX + rectW + 12} y={rectY + rectH / 2 + 3}
              fontSize={7} fill="#374151" fontWeight={600} textAnchor="start">
              {Math.round(totalDropMm)}mm
            </text>

            {/* Width dimension (bottom) */}
            <line x1={rectX} y1={rectY + rectH + 8} x2={rectX + rectW} y2={rectY + rectH + 8}
              stroke="#6b7280" strokeWidth={0.8} />
            <line x1={rectX} y1={rectY + rectH + 5} x2={rectX} y2={rectY + rectH + 11}
              stroke="#6b7280" strokeWidth={0.8} />
            <line x1={rectX + rectW} y1={rectY + rectH + 5} x2={rectX + rectW} y2={rectY + rectH + 11}
              stroke="#6b7280" strokeWidth={0.8} />
            <text x={rectX + rectW / 2} y={rectY + rectH + 18}
              textAnchor="middle" fontSize={7} fill="#374151" fontWeight={600}>
              {Math.round(cutWidthMm)}mm panel width
            </text>

            {/* Heatseal / join indicators */}
            {numDrops > 1 && hsDir === 'vertical' && (
              <g>
                {Array.from({ length: numDrops - 1 }, (_, i) => {
                  const joinX = rectX + ((i + 1) * rollWidthMm / cutWidthMm) * rectW;
                  if (joinX >= rectX + rectW) return null;
                  return (
                    <g key={`hs-${i}`}>
                      <line x1={joinX} y1={rectY + 2} x2={joinX} y2={rectY + rectH - 2}
                        stroke="#f59e0b" strokeWidth={1.8} strokeDasharray="2 4" />
                      <text x={joinX} y={rectY - 2} textAnchor="middle" fontSize={6} fill="#d97706" fontWeight={600}>
                        ✂ COSTURA
                      </text>
                    </g>
                  );
                })}
              </g>
            )}
            {numDrops > 1 && hsDir === 'horizontal' && (
              <g>
                {Array.from({ length: numDrops - 1 }, (_, i) => {
                  const dropFromBottom = (i + 1) * usableRollWidthMm;
                  const remainderOnTop = totalDropMm - dropFromBottom;
                  if (remainderOnTop <= 0) return null;
                  const joinY = rectY + (remainderOnTop / totalDropMm) * rectH;
                  const primaryH = Math.round(usableRollWidthMm);
                  const secondaryH = Math.round(remainderOnTop);
                  return (
                    <g key={`hs-${i}`}>
                      <line x1={rectX + 2} y1={joinY} x2={rectX + rectW - 2} y2={joinY}
                        stroke="#f59e0b" strokeWidth={1.8} strokeDasharray="2 4" />
                      <text x={rectX + rectW / 2} y={joinY - 3} textAnchor="middle" fontSize={6} fill="#d97706" fontWeight={600}>
                        ⚡ HEATSEAL
                      </text>
                      {/* Secondary (top) dimension */}
                      <text x={rectX - 2} y={rectY + (remainderOnTop / totalDropMm) * rectH / 2 + 3}
                        textAnchor="end" fontSize={6} fill="#92400e" fontWeight={500}>
                        {secondaryH}mm
                      </text>
                      {/* Primary (bottom) dimension */}
                      <text x={rectX - 2} y={joinY + ((rectY + rectH - joinY) / 2) + 3}
                        textAnchor="end" fontSize={6} fill="#1d4ed8" fontWeight={500}>
                        {primaryH}mm
                      </text>
                    </g>
                  );
                })}
              </g>
            )}
            {notFabricable && (
              <g>
                <rect x={rectX + 4} y={rectY + rectH / 2 - 14} width={rectW - 8} height={28} rx={4}
                  fill="#fef2f2" stroke="#ef4444" strokeWidth={1.5} />
                <text x={rectX + rectW / 2} y={rectY + rectH / 2 + 4} textAnchor="middle"
                  fontSize={7} fill="#dc2626" fontWeight={700}>
                  ⚠ EXCEEDS ROLL — NOT FABRICABLE
                </text>
              </g>
            )}
          </svg>
        </div>

        {/* =================== NUMERIC BREAKDOWN =================== */}
        <div className="flex-1 space-y-3 min-w-[200px]">
          {/* Model banner */}
          {isDrapery && productName && (
            <div className="bg-gray-800 text-white px-3 py-1.5 rounded text-xs font-bold tracking-wide uppercase">
              MODEL: {productName.split('·')[0]?.trim() || 'Drapery'}
            </div>
          )}

          {/* Drop breakdown */}
          <div>
            <h5 className="text-xs font-semibold text-gray-700 mb-2 uppercase tracking-wider">Drop Breakdown</h5>
            <div className="space-y-1 text-xs text-gray-600">
              <div className="flex justify-between">
                <span>Ordered height</span>
                <span className="font-mono font-medium text-gray-900">{productHeightMm} mm</span>
              </div>
              {rule.tube_wrap_mm > 0 && (
                <div className="flex justify-between">
                  <span>+ Tube wrap</span>
                  <span className="font-mono text-indigo-600">+{rule.tube_wrap_mm} mm</span>
                </div>
              )}
              {rule.bottom_wrap_mm > 0 && (
                <div className="flex justify-between">
                  <span>+ Bottom wrap</span>
                  <span className="font-mono text-indigo-600">+{rule.bottom_wrap_mm} mm</span>
                </div>
              )}
              {rule.safety_margin_mm > 0 && (
                <div className="flex justify-between">
                  <span>+ Safety margin</span>
                  <span className="font-mono text-amber-600">+{rule.safety_margin_mm} mm</span>
                </div>
              )}
              {rule.top_hem_mm > 0 && (
                <div className="flex justify-between">
                  <span>+ Top hem</span>
                  <span className="font-mono text-green-600">+{rule.top_hem_mm} mm</span>
                </div>
              )}
              {rule.bottom_hem_mm > 0 && (
                <div className="flex justify-between">
                  <span>+ Bottom hem</span>
                  <span className="font-mono text-green-600">+{rule.bottom_hem_mm} mm</span>
                </div>
              )}
              {rule.panel_multiplier > 1 && (
                <div className="flex justify-between">
                  <span>× Panel multiplier</span>
                  <span className="font-mono text-purple-600">×{rule.panel_multiplier}</span>
                </div>
              )}
              <div className="flex justify-between border-t border-gray-200 pt-1 font-semibold text-gray-900">
                <span>Total drop</span>
                <span className="font-mono">{Math.round(totalDropMm)} mm</span>
              </div>
              {hasHeightMismatch && (
                <div className="flex justify-between text-[11px] text-amber-700">
                  <span>Cut job recorded</span>
                  <span className="font-mono">{Math.round(cutHeightMm)} mm ({cutHeightDeltaMm > 0 ? '+' : ''}{cutHeightDeltaMm} mm delta)</span>
                </div>
              )}
            </div>
          </div>

          {/* Width breakdown */}
          <div>
            <h5 className="text-xs font-semibold text-gray-700 mb-2 uppercase tracking-wider">Width Breakdown</h5>
            <div className="space-y-1 text-xs text-gray-600">
              <div className="flex justify-between">
                <span>Ordered width</span>
                <span className="font-mono font-medium text-gray-900">{productWidthMm} mm</span>
              </div>
              {rule.fullness_factor > 1 && (
                <div className="flex justify-between">
                  <span>× Fullness</span>
                  <span className="font-mono text-purple-600">×{rule.fullness_factor}</span>
                </div>
              )}
              {hasSideHems && (
                <div className="flex justify-between">
                  <span>+ Side hems (×2)</span>
                  <span className="font-mono text-green-600">+{rule.side_hem_mm * 2} mm</span>
                </div>
              )}
              <div className="flex justify-between border-t border-gray-200 pt-1 font-semibold text-gray-900">
                <span>Panel width</span>
                <span className="font-mono">{Math.round(cutWidthMm)} mm</span>
              </div>
              <div className="flex justify-between mt-1">
                <span>Roll width</span>
                <span className="font-mono text-gray-900">{Math.round(rollWidthMm)} mm</span>
              </div>
              <div className="flex justify-between text-[11px]">
                <span>− Edge trim ({EDGE_TRIM_MM}mm × 2)</span>
                <span className="font-mono text-red-500">−{EDGE_TRIM_MM * 2} mm</span>
              </div>
              <div className="flex justify-between font-medium">
                <span>Usable roll width</span>
                <span className="font-mono text-gray-900">{Math.round(usableRollWidthMm)} mm</span>
              </div>
              <div className="flex justify-between">
                <span>Drops needed</span>
                <span className="font-mono font-semibold text-gray-900">{numDrops}</span>
              </div>
              {numDrops > 1 && (
                <>
                  <div className="mt-2 pt-2 border-t border-gray-100 space-y-1">
                    <div className="flex justify-between">
                      <span className="text-blue-700 font-medium">Primary drop (bottom)</span>
                      <span className="font-mono font-semibold text-blue-700">{Math.round(usableRollWidthMm)} mm</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-amber-700 font-medium">Secondary drop (top)</span>
                      <span className="font-mono font-semibold text-amber-700">{Math.round(lastDropUsed)} mm</span>
                    </div>
                    {lastDropTrim > 0 && (
                      <div className="flex justify-between text-[11px]">
                        <span>Trim waste per secondary drop</span>
                        <span className="font-mono text-red-500">{Math.round(lastDropTrim)} mm</span>
                      </div>
                    )}
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Heatseal / Not Fabricable */}
          {numDrops > 1 && (
            <div className={`rounded-md px-3 py-2 text-xs ${notFabricable ? 'bg-red-50 border border-red-200' : needsHeatseal ? 'bg-amber-50 border border-amber-200' : 'bg-gray-50 border border-gray-200'}`}>
              {notFabricable ? (
                <div className="flex items-center gap-1.5 font-semibold text-red-600">
                  <AlertTriangle className="w-3.5 h-3.5" />
                  PANEL EXCEEDS ROLL WIDTH — NOT FABRICABLE
                  <span className="font-normal text-red-500 ml-1">({numDrops} drops needed, no join allowed)</span>
                </div>
              ) : needsHeatseal ? (
                <>
                  <div className="flex items-center gap-1.5 font-semibold mb-1 text-amber-600">
                    <Zap className="w-3.5 h-3.5" />
                    {hsDir === 'horizontal' ? 'HEATSEAL' : 'COSTURA / SEW'} Required ({hsDir})
                  </div>
                  <div className="text-gray-600 space-y-0.5">
                    <div className="flex justify-between">
                      <span>Seam {hsDir === 'horizontal' ? 'width' : 'height'}</span>
                      <span className="font-mono">{heatsealLengthM.toFixed(2)} m × {numDrops - 1} join{numDrops > 2 ? 's' : ''}</span>
                    </div>
                  </div>
                </>
              ) : (
                <div className="flex items-center gap-1.5 font-semibold text-gray-500">
                  <Zap className="w-3.5 h-3.5" />
                  Multiple drops — no heatseal cost configured
                </div>
              )}
            </div>
          )}

          {/* Waste */}
          {numDrops > 1 && trimWaste > 0 && (
            <div>
              <h5 className="text-xs font-semibold text-gray-700 mb-2 uppercase tracking-wider">Waste</h5>
              <div className="space-y-1 text-xs text-gray-600">
                <div className="flex justify-between">
                  <span>Total fabric used</span>
                  <span className="font-mono">{(totalFabricArea / 1e6).toFixed(2)} m²</span>
                </div>
                <div className="flex justify-between">
                  <span>Panel area</span>
                  <span className="font-mono">{(panelArea / 1e6).toFixed(2)} m²</span>
                </div>
                <div className="flex justify-between font-semibold text-red-600">
                  <span>Trim waste</span>
                  <span className="font-mono">{(trimWaste / 1e6).toFixed(2)} m² ({trimWastePct}%)</span>
                </div>
              </div>
            </div>
          )}

          {/* Materials from WorkOrder */}
          <div>
            <h5 className="text-xs font-semibold text-gray-700 mb-2 flex items-center gap-1 uppercase tracking-wider">
              <Package className="w-3 h-3" /> Materials & Components
            </h5>
            {materialsLoading ? (
              <p className="text-[11px] text-gray-400 italic">Loading materials...</p>
            ) : materials && materials.length > 0 ? (
              <ul className="space-y-1 text-xs text-gray-600">
                {materials.map((m, i) => (
                  <li key={i} className="flex items-center gap-2">
                    <span className="w-1.5 h-1.5 bg-gray-400 rounded-full flex-shrink-0" />
                    <span className="font-mono text-[10px] text-gray-500">{m.sku}</span>
                    <span className="truncate">{m.item_name}</span>
                    <span className="ml-auto font-mono text-gray-500 whitespace-nowrap">
                      {m.uom === 'ea' ? m.qty : m.qty.toFixed(3)} {m.uom}
                    </span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-[11px] text-gray-400 italic">No materials loaded — see BOM</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
