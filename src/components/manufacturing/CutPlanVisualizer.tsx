import { useMemo, useState, useCallback } from 'react';
import { optimize1D, type CutPiece, type CutPlan1DResult } from '../../lib/cutOptimizer';
import { generateCutPlanPDF } from '../../lib/pdf/generateCutPlanPDF';
import { Scissors, BarChart3, AlertTriangle, Printer } from 'lucide-react';

const MO_COLORS = [
  'bg-blue-400', 'bg-emerald-400', 'bg-amber-400', 'bg-rose-400',
  'bg-purple-400', 'bg-cyan-400', 'bg-orange-400', 'bg-indigo-400',
];

const MO_HEX_COLORS = [
  '#60a5fa', '#34d399', '#fbbf24', '#fb7185',
  '#a78bfa', '#22d3ee', '#fb923c', '#818cf8',
];

interface CutPlanVisualizerProps {
  pieces: CutPiece[];
  stockLengthMm: number;
  onStockLengthChange?: (mm: number) => void;
  title?: string;
  subtitle?: string;
  stockLabel?: string;
}

export default function CutPlanVisualizer({
  pieces,
  stockLengthMm: initialStockLength,
  onStockLengthChange,
  title = 'Profile Cut Optimization',
  subtitle,
  stockLabel = 'Stock (mm)',
}: CutPlanVisualizerProps) {
  const [stockLengthMm, setStockLengthMm] = useState(initialStockLength);
  const [kerfMm, setKerfMm] = useState(3);

  const result: CutPlan1DResult = useMemo(
    () => optimize1D(pieces, stockLengthMm, kerfMm),
    [pieces, stockLengthMm, kerfMm],
  );

  const moIds = useMemo(() => {
    const ids = new Set<string>();
    pieces.forEach(p => { if (p.moId) ids.add(p.moId); });
    return Array.from(ids);
  }, [pieces]);

  const moColorMap = useMemo(() => {
    const map: Record<string, string> = {};
    moIds.forEach((id, i) => { map[id] = MO_COLORS[i % MO_COLORS.length]; });
    return map;
  }, [moIds]);

  const moHexColorMap = useMemo(() => {
    const map: Record<string, string> = {};
    moIds.forEach((id, i) => { map[id] = MO_HEX_COLORS[i % MO_HEX_COLORS.length]; });
    return map;
  }, [moIds]);

  const handleStockChange = (mm: number) => {
    setStockLengthMm(mm);
    onStockLengthChange?.(mm);
  };

  const moNumberMap = useMemo(() => {
    const map: Record<string, string> = {};
    pieces.forEach(p => { if (p.moId && p.moNumber) map[p.moId] = p.moNumber; });
    return map;
  }, [pieces]);

  const handlePrint = useCallback(async () => {
    const logoPaths = ['/images/Arquiproductos.png', '/images/arquiproductos.png', '/images/Arquiproductos.jpg'];
    let logoBase64: string | undefined;
    for (const path of logoPaths) {
      try {
        const res = await fetch(path, { cache: 'no-store' });
        if (!res.ok) continue;
        const blob = await res.blob();
        logoBase64 = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
        if (logoBase64) break;
      } catch { /* ignore */ }
    }

    let logoW = 100, logoH = 100;
    if (logoBase64) {
      const dims = await new Promise<{ w: number; h: number }>(resolve => {
        const img = new Image();
        img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
        img.onerror = () => resolve({ w: 100, h: 100 });
        img.src = logoBase64!;
      });
      logoW = dims.w;
      logoH = dims.h;
    }

    const sku = pieces[0]?.sku ?? 'Unknown';
    const doc = generateCutPlanPDF({
      type: '1d',
      title: title ?? sku,
      subtitle: subtitle ?? '',
      sku,
      moNumbers: moIds.map(id => moNumberMap[id] ?? id.slice(0, 8)),
      stockLengthMm,
      kerfMm,
      result1D: result,
      moHexColorMap: moHexColorMap,
      logoPngBase64: logoBase64,
      logoWidthPx: logoW,
      logoHeightPx: logoH,
    });
    doc.save(`CutPlan-1D-${sku}.pdf`);
  }, [pieces, title, subtitle, moIds, moNumberMap, stockLengthMm, kerfMm, result, moHexColorMap]);

  if (pieces.length === 0) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
        <Scissors className="w-8 h-8 text-gray-300 mx-auto mb-2" />
        <p className="text-sm text-gray-500">No pieces to optimize</p>
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-200 bg-gray-50 flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Scissors className="w-4 h-4 text-gray-500" />
            <h3 className="text-sm font-semibold text-gray-900">{title}</h3>
          </div>
          {subtitle && <p className="text-[10px] text-gray-400 mt-0.5 ml-6">{subtitle}</p>}
        </div>
        <div className="flex items-center gap-4">
          <label className="flex items-center gap-2 text-xs text-gray-600">
            Stock (m)
            <input
              type="text"
              inputMode="decimal"
              value={(stockLengthMm / 1000).toFixed(2)}
              onChange={e => { const v = parseFloat(e.target.value); if (!isNaN(v) && v >= 0.1) handleStockChange(Math.round(v * 1000)); }}
              className="w-20 px-2 py-1 border border-gray-300 rounded text-xs text-right"
            />
          </label>
          <label className="flex items-center gap-2 text-xs text-gray-600">
            Kerf (mm)
            <input
              type="number"
              value={kerfMm}
              onChange={e => setKerfMm(Number(e.target.value))}
              className="w-16 px-2 py-1 border border-gray-300 rounded text-xs"
              min={0}
              max={20}
              step={0.5}
            />
          </label>
          <button
            type="button"
            onClick={handlePrint}
            className="inline-flex items-center gap-1 text-xs px-2.5 py-1.5 rounded border border-gray-300 bg-white text-gray-600 hover:bg-gray-50"
            title="Print cut plan PDF"
          >
            <Printer className="w-3.5 h-3.5" /> PDF
          </button>
        </div>
      </div>

      {/* Summary stats */}
      <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-6">
        <div className="flex items-center gap-1.5">
          <BarChart3 className="w-3.5 h-3.5 text-gray-400" />
          <span className="text-xs text-gray-500">Efficiency:</span>
          <span className={`text-xs font-bold ${result.efficiencyPct >= 90 ? 'text-green-600' : result.efficiencyPct >= 75 ? 'text-amber-600' : 'text-red-600'}`}>
            {result.efficiencyPct}%
          </span>
        </div>
        <div className="text-xs text-gray-500">
          <span className="font-medium text-gray-700">{result.totalStockUnits}</span> {stockLabel?.includes('Roll') ? 'rolls' : 'bars'}
        </div>
        <div className="text-xs text-gray-500">
          <span className="font-medium text-gray-700">{result.totalPieces}</span> pieces
        </div>
        <div className="text-xs text-gray-500">
          Waste: <span className="font-medium text-gray-700">{(result.totalWasteMm / 1000).toFixed(2)} m</span>
        </div>
        {result.bars.some(b => b.pieces.some(p => p.lengthMm > stockLengthMm)) && (
          <div className="flex items-center gap-1 text-xs text-amber-600">
            <AlertTriangle className="w-3.5 h-3.5" /> Oversized pieces
          </div>
        )}
      </div>

      {/* MO legend */}
      {moIds.length > 0 && (
        <div className="px-4 py-2 border-b border-gray-100 flex items-center gap-3 flex-wrap">
          <span className="text-[10px] font-medium text-gray-400 uppercase">MOs:</span>
          {moIds.map(id => (
            <span key={id} className="inline-flex items-center gap-1.5 text-xs text-gray-600">
              <span className={`w-3 h-3 rounded ${moColorMap[id]}`} />
              {moNumberMap[id] ?? id.slice(0, 8)}
            </span>
          ))}
        </div>
      )}

      {/* Bar visualizations */}
      <div className="p-4 space-y-3">
        {result.bars.map(bar => {
          const scale = stockLengthMm > 0 ? 100 / Math.max(bar.stockLengthMm, stockLengthMm) : 1;
          return (
            <div key={bar.index} className="group">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-[10px] font-mono text-gray-400 w-10">{stockLabel?.includes('Roll') ? 'Roll' : 'Bar'} {bar.index + 1}</span>
                <span className="text-[10px] text-gray-400">
                  {(bar.usedMm / 1000).toFixed(2)} / {(bar.stockLengthMm / 1000).toFixed(2)} m
                </span>
                <span className={`text-[10px] font-medium ${bar.wasteMm < 100 ? 'text-green-600' : bar.wasteMm < 500 ? 'text-amber-600' : 'text-red-500'}`}>
                  waste: {(bar.wasteMm / 1000).toFixed(2)} m
                </span>
              </div>
              <div
                className="relative h-8 bg-gray-100 rounded border border-gray-200 overflow-hidden"
                style={{ width: '100%' }}
              >
                {bar.pieces.map((piece, i) => {
                  const left = piece.positionMm * scale;
                  const width = piece.lengthMm * scale;
                  const color = piece.moId ? moColorMap[piece.moId] ?? 'bg-blue-400' : 'bg-blue-400';
                  return (
                    <div
                      key={`${piece.id}-${i}`}
                      className={`absolute top-0.5 bottom-0.5 ${color} rounded-sm flex items-center justify-center overflow-hidden cursor-default transition-opacity group-hover:opacity-90`}
                      style={{ left: `${left}%`, width: `${Math.max(width, 0.5)}%` }}
                      title={`${piece.label ?? piece.sku ?? piece.id}: ${Math.round(piece.lengthMm)} mm${piece.moNumber ? ` (${piece.moNumber})` : ''}`}
                    >
                      {width > 3 && (
                        <span className="text-[9px] font-medium text-white truncate px-1">
                          {Math.round(piece.lengthMm)}
                        </span>
                      )}
                    </div>
                  );
                })}
                {bar.wasteMm > 0 && (
                  <div
                    className="absolute top-0 bottom-0 bg-gray-200/60"
                    style={{
                      left: `${bar.usedMm * scale}%`,
                      width: `${bar.wasteMm * scale}%`,
                    }}
                  />
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
