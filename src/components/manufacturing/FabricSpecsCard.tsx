import { Ruler, Package, FileText } from 'lucide-react';

interface FabricSpec {
  product_type: string;
  display_name: string;
  top_allowance_mm: number;
  bottom_allowance_mm: number;
  side_allowance_mm: number;
  hem_bar_pocket_mm: number;
  safety_margin_mm: number;
  additional_materials: Array<{ name: string; qty: number; uom: string }>;
  notes: string | null;
}

interface FabricSpecsCardProps {
  spec: FabricSpec;
  orderedWidthMm?: number;
  orderedHeightMm?: number;
}

export default function FabricSpecsCard({ spec, orderedWidthMm, orderedHeightMm }: FabricSpecsCardProps) {
  const totalHeight = (orderedHeightMm ?? 0)
    + spec.top_allowance_mm
    + spec.bottom_allowance_mm
    + spec.hem_bar_pocket_mm
    + spec.safety_margin_mm;
  const totalWidth = (orderedWidthMm ?? 0) + spec.side_allowance_mm * 2;

  const hasAllowances = spec.top_allowance_mm > 0 || spec.bottom_allowance_mm > 0
    || spec.side_allowance_mm > 0 || spec.hem_bar_pocket_mm > 0 || spec.safety_margin_mm > 0;

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
        <div className="flex items-center gap-2">
          <Ruler className="w-4 h-4 text-gray-500" />
          <h4 className="text-sm font-semibold text-gray-900">{spec.display_name} — Construction Details</h4>
        </div>
      </div>

      <div className="p-4 flex gap-6">
        {/* Visual diagram */}
        {hasAllowances && (
          <div className="flex-shrink-0">
            <svg viewBox="0 0 200 280" width="160" height="224" className="border border-gray-100 rounded bg-gray-50">
              {/* Outer cut rectangle */}
              <rect x="20" y="20" width="160" height="240" rx="2"
                fill="none" stroke="#9ca3af" strokeWidth="1" strokeDasharray="4 2" />

              {/* Top allowance */}
              {spec.top_allowance_mm > 0 && (
                <>
                  <rect x="20" y="20" width="160" height="30" fill="#fef3c7" opacity="0.6" />
                  <text x="100" y="38" textAnchor="middle" className="text-[8px]" fill="#92400e">
                    Top: {spec.top_allowance_mm}mm
                  </text>
                </>
              )}

              {/* Bottom allowance */}
              {spec.bottom_allowance_mm > 0 && (
                <>
                  <rect x="20" y="210" width="160" height="30" fill="#fef3c7" opacity="0.6" />
                  <text x="100" y="228" textAnchor="middle" className="text-[8px]" fill="#92400e">
                    Bottom: {spec.bottom_allowance_mm}mm
                  </text>
                </>
              )}

              {/* Hem bar pocket */}
              {spec.hem_bar_pocket_mm > 0 && (
                <>
                  <rect x="20" y="240" width="160" height="20" fill="#dbeafe" opacity="0.6" />
                  <text x="100" y="253" textAnchor="middle" className="text-[8px]" fill="#1e40af">
                    Hem bar: {spec.hem_bar_pocket_mm}mm
                  </text>
                </>
              )}

              {/* Side allowances */}
              {spec.side_allowance_mm > 0 && (
                <>
                  <rect x="20" y="50" width="15" height="160" fill="#d1fae5" opacity="0.5" />
                  <rect x="165" y="50" width="15" height="160" fill="#d1fae5" opacity="0.5" />
                  <text x="10" y="140" textAnchor="middle" className="text-[7px]" fill="#065f46"
                    transform="rotate(-90, 10, 140)">
                    {spec.side_allowance_mm}mm
                  </text>
                  <text x="190" y="140" textAnchor="middle" className="text-[7px]" fill="#065f46"
                    transform="rotate(90, 190, 140)">
                    {spec.side_allowance_mm}mm
                  </text>
                </>
              )}

              {/* Visible area */}
              <rect
                x={20 + (spec.side_allowance_mm > 0 ? 15 : 0)}
                y={20 + (spec.top_allowance_mm > 0 ? 30 : 0)}
                width={160 - (spec.side_allowance_mm > 0 ? 30 : 0)}
                height={240 - (spec.top_allowance_mm > 0 ? 30 : 0) - (spec.bottom_allowance_mm > 0 ? 30 : 0) - (spec.hem_bar_pocket_mm > 0 ? 20 : 0)}
                fill="#eff6ff" stroke="#3b82f6" strokeWidth="1.5" rx="1"
              />
              <text
                x="100"
                y={20 + (spec.top_allowance_mm > 0 ? 30 : 0) + (240 - (spec.top_allowance_mm > 0 ? 30 : 0) - (spec.bottom_allowance_mm > 0 ? 30 : 0) - (spec.hem_bar_pocket_mm > 0 ? 20 : 0)) / 2}
                textAnchor="middle" className="text-[9px] font-medium" fill="#1d4ed8"
              >
                Visible Area
              </text>

              {/* Safety margin label */}
              {spec.safety_margin_mm > 0 && (
                <text x="100" y="14" textAnchor="middle" className="text-[7px]" fill="#6b7280">
                  +{spec.safety_margin_mm}mm safety
                </text>
              )}
            </svg>
          </div>
        )}

        {/* Dimensions breakdown */}
        <div className="flex-1 space-y-4">
          {orderedHeightMm != null && orderedHeightMm > 0 && (
            <div>
              <h5 className="text-xs font-semibold text-gray-700 mb-2">Cut Dimensions</h5>
              <div className="space-y-1 text-xs text-gray-600">
                <div className="flex justify-between">
                  <span>Ordered height</span><span className="font-mono">{orderedHeightMm} mm</span>
                </div>
                {spec.safety_margin_mm > 0 && <div className="flex justify-between"><span>+ Safety margin</span><span className="font-mono text-amber-600">+{spec.safety_margin_mm} mm</span></div>}
                {spec.top_allowance_mm > 0 && <div className="flex justify-between"><span>+ Top hem</span><span className="font-mono text-amber-600">+{spec.top_allowance_mm} mm</span></div>}
                {spec.bottom_allowance_mm > 0 && <div className="flex justify-between"><span>+ Bottom hem</span><span className="font-mono text-amber-600">+{spec.bottom_allowance_mm} mm</span></div>}
                {spec.hem_bar_pocket_mm > 0 && <div className="flex justify-between"><span>+ Hem bar pocket</span><span className="font-mono text-blue-600">+{spec.hem_bar_pocket_mm} mm</span></div>}
                <div className="flex justify-between border-t border-gray-200 pt-1 font-semibold text-gray-900">
                  <span>Total cut height</span><span className="font-mono">{totalHeight} mm</span>
                </div>
              </div>
              {orderedWidthMm != null && orderedWidthMm > 0 && spec.side_allowance_mm > 0 && (
                <div className="mt-2 space-y-1 text-xs text-gray-600">
                  <div className="flex justify-between"><span>Ordered width</span><span className="font-mono">{orderedWidthMm} mm</span></div>
                  <div className="flex justify-between"><span>+ Side hems (x2)</span><span className="font-mono text-green-600">+{spec.side_allowance_mm * 2} mm</span></div>
                  <div className="flex justify-between border-t border-gray-200 pt-1 font-semibold text-gray-900">
                    <span>Total cut width</span><span className="font-mono">{totalWidth} mm</span>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Additional materials */}
          {spec.additional_materials.length > 0 && (
            <div>
              <h5 className="text-xs font-semibold text-gray-700 mb-2 flex items-center gap-1">
                <Package className="w-3 h-3" /> Required Materials
              </h5>
              <ul className="space-y-1">
                {spec.additional_materials.map((mat, i) => (
                  <li key={i} className="text-xs text-gray-600 flex items-center gap-2">
                    <span className="w-1.5 h-1.5 bg-gray-400 rounded-full flex-shrink-0" />
                    {mat.name} — {mat.qty} {mat.uom}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Notes */}
          {spec.notes && (
            <div className="flex items-start gap-1.5 text-xs text-gray-500 bg-gray-50 p-2 rounded">
              <FileText className="w-3 h-3 mt-0.5 flex-shrink-0" />
              {spec.notes}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
