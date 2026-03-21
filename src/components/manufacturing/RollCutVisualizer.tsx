import { useMemo, useState, useCallback, useEffect } from 'react';
import { optimize2D, type FabricPiece, type PlacedFabricPiece, type CutPlan2DResult } from '../../lib/cutOptimizer2D';
import { generateCutPlanPDF, generateStickersPDF, buildTaggedPieces } from '../../lib/pdf/generateCutPlanPDF';
import { Scissors, BarChart3, RotateCw, Printer, Tag } from 'lucide-react';

const MO_COLORS = [
  '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#06b6d4', '#f97316', '#6366f1',
];

interface RollCutVisualizerProps {
  pieces: FabricPiece[];
  rollWidthMm: number;
  rollLengthMm: number;
  onRollDimensionsChange?: (width: number, length: number) => void;
  title?: string;
  subtitle?: string;
  /** Whether the product type allows rotation (from FabricRules). */
  canRotate?: boolean;
  /** Fires when a placed piece is clicked — parent can show PanelCutDetail. */
  onPieceClick?: (piece: PlacedFabricPiece) => void;
}

export default function RollCutVisualizer({
  pieces,
  rollWidthMm: initialWidth,
  rollLengthMm: initialLength,
  onRollDimensionsChange,
  title = 'Fabric Cut Optimization',
  subtitle,
  canRotate = true,
  onPieceClick,
}: RollCutVisualizerProps) {
  const [rollWidthMm, setRollWidthMm] = useState(initialWidth);
  const [rollLengthMm, setRollLengthMm] = useState(initialLength);
  const [allowRotation, setAllowRotation] = useState(false);
  const [selectedPiece, setSelectedPiece] = useState<string | null>(null);

  useEffect(() => { setRollWidthMm(initialWidth); }, [initialWidth]);
  useEffect(() => { setRollLengthMm(initialLength); }, [initialLength]);

  const result: CutPlan2DResult = useMemo(
    () => optimize2D(pieces, rollWidthMm, rollLengthMm, allowRotation),
    [pieces, rollWidthMm, rollLengthMm, allowRotation],
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

  const moNumberMap = useMemo(() => {
    const map: Record<string, string> = {};
    pieces.forEach(p => { if (p.moId && p.moNumber) map[p.moId] = p.moNumber; });
    return map;
  }, [pieces]);

  const handleDimensionChange = (w: number, l: number) => {
    setRollWidthMm(w);
    setRollLengthMm(l);
    onRollDimensionsChange?.(w, l);
  };

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

    const sku = title?.split(' — ')[0] ?? 'Fabric';
    const doc = generateCutPlanPDF({
      type: '2d',
      title: title ?? sku,
      subtitle: subtitle ?? '',
      sku,
      moNumbers: moIds.map(id => moNumberMap[id] ?? id.slice(0, 8)),
      rollWidthMm,
      rollLengthMm,
      result2D: result,
      moHexColorMap: moColorMap,
      logoPngBase64: logoBase64,
      logoWidthPx: logoW,
      logoHeightPx: logoH,
    });
    doc.save(`CutPlan-2D-${sku}.pdf`);
  }, [title, subtitle, moIds, moNumberMap, rollWidthMm, rollLengthMm, result, moColorMap]);

  const handlePrintStickers = useCallback(() => {
    const sku = title?.split(' — ')[0] ?? 'Fabric';
    const materialName = title?.split(' — ')[1] ?? sku;
    const tagged = buildTaggedPieces(result);
    const doc = generateStickersPDF(tagged, sku, materialName);
    doc.save(`Stickers-${sku}.pdf`);
  }, [title, result]);

  if (pieces.length === 0) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
        <Scissors className="w-8 h-8 text-gray-300 mx-auto mb-2" />
        <p className="text-sm text-gray-500">No fabric pieces to optimize</p>
      </div>
    );
  }

  const ROLL_DISPLAY_HEIGHT = 120;

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-200 bg-gray-50 flex items-center justify-between flex-wrap gap-2">
        <div>
          <div className="flex items-center gap-2">
            <Scissors className="w-4 h-4 text-gray-500" />
            <h3 className="text-sm font-semibold text-gray-900">{title}</h3>
          </div>
          {subtitle && <p className="text-[10px] text-gray-400 mt-0.5 ml-6">{subtitle}</p>}
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          <label className="flex items-center gap-1.5 text-xs text-gray-600">
            Width (m)
            <input
              type="text"
              inputMode="decimal"
              value={(rollWidthMm / 1000).toFixed(2)}
              onChange={e => { const v = parseFloat(e.target.value); if (!isNaN(v) && v >= 0.5) handleDimensionChange(Math.round(v * 1000), rollLengthMm); }}
              className="w-20 px-2 py-1 border border-gray-300 rounded text-xs text-right"
            />
          </label>
          <label className="flex items-center gap-1.5 text-xs text-gray-600">
            Length (m)
            <input
              type="text"
              inputMode="decimal"
              value={(rollLengthMm / 1000).toFixed(2)}
              onChange={e => { const v = parseFloat(e.target.value); if (!isNaN(v) && v >= 1) handleDimensionChange(rollWidthMm, Math.round(v * 1000)); }}
              className="w-20 px-2 py-1 border border-gray-300 rounded text-xs text-right"
            />
          </label>
          <button
            type="button"
            onClick={() => canRotate && setAllowRotation(!allowRotation)}
            disabled={!canRotate}
            className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded border ${
              !canRotate
                ? 'bg-red-50 border-red-200 text-red-400 cursor-not-allowed'
                : allowRotation
                  ? 'bg-blue-50 border-blue-300 text-blue-700'
                  : 'bg-white border-gray-300 text-gray-500'
            }`}
            title={canRotate ? 'Allow piece rotation' : 'Rotation not allowed for this product type'}
          >
            <RotateCw className="w-3 h-3" />
            {canRotate ? 'Rotate' : 'No Rotation'}
          </button>
          <button
            type="button"
            onClick={handlePrint}
            className="inline-flex items-center gap-1 text-xs px-2.5 py-1.5 rounded border border-gray-300 bg-white text-gray-600 hover:bg-gray-50"
            title="Print cut plan PDF"
          >
            <Printer className="w-3.5 h-3.5" /> PDF
          </button>
          <button
            type="button"
            onClick={handlePrintStickers}
            className="inline-flex items-center gap-1 text-xs px-2.5 py-1.5 rounded border border-gray-300 bg-white text-gray-600 hover:bg-gray-50"
            title="Print sticker labels for each piece"
          >
            <Tag className="w-3.5 h-3.5" /> Stickers
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-6">
        <div className="flex items-center gap-1.5">
          <BarChart3 className="w-3.5 h-3.5 text-gray-400" />
          <span className="text-xs text-gray-500">Efficiency:</span>
          <span className={`text-xs font-bold ${result.totalEfficiencyPct >= 85 ? 'text-green-600' : result.totalEfficiencyPct >= 70 ? 'text-amber-600' : 'text-red-600'}`}>
            {result.totalEfficiencyPct}%
          </span>
        </div>
        <div className="text-xs text-gray-500">
          <span className="font-medium text-gray-700">{result.totalRolls}</span> roll{result.totalRolls !== 1 ? 's' : ''}
        </div>
        <div className="text-xs text-gray-500">
          <span className="font-medium text-gray-700">{result.totalPieces}</span> pieces
        </div>
        <div className="text-xs text-gray-500">
          Waste: <span className="font-medium text-gray-700">{((result.totalStockArea - result.totalUsedArea) / 1_000_000).toFixed(2)} m²</span>
        </div>
      </div>

      {/* MO legend */}
      {moIds.length > 0 && (
        <div className="px-4 py-2 border-b border-gray-100 flex items-center gap-3 flex-wrap">
          <span className="text-[10px] font-medium text-gray-400 uppercase">MOs:</span>
          {moIds.map(id => (
            <span key={id} className="inline-flex items-center gap-1.5 text-xs text-gray-600">
              <span className="w-3 h-3 rounded" style={{ backgroundColor: moColorMap[id] }} />
              {moNumberMap[id] ?? id.slice(0, 8)}
            </span>
          ))}
        </div>
      )}

      {/* Roll visualizations — HORIZONTAL layout (length→horizontal, width→vertical) */}
      <div className="p-4 space-y-6">
        {result.rolls.map(roll => {
          const scale = ROLL_DISPLAY_HEIGHT / roll.widthMm;
          const displayWidth = Math.max(80, roll.usedLengthMm * scale);
          return (
            <div key={roll.index}>
              <div className="flex items-center gap-2 mb-2">
                <span className="text-xs font-semibold text-gray-700">Roll {roll.index + 1}</span>
                <span className="text-[10px] text-gray-400">
                  {(roll.widthMm / 1000).toFixed(2)}m wide × {(roll.usedLengthMm / 1000).toFixed(1)}m used of {(roll.lengthMm / 1000).toFixed(1)}m
                </span>
                <span className={`text-[10px] font-medium ${roll.wastePct < 15 ? 'text-green-600' : roll.wastePct < 30 ? 'text-amber-600' : 'text-red-500'}`}>
                  waste: {roll.wastePct}%
                </span>
              </div>

              {/* Width label on the left */}
              <div className="flex items-start gap-2">
                <div className="flex flex-col items-center justify-center shrink-0" style={{ height: ROLL_DISPLAY_HEIGHT }}>
                  <span className="text-[9px] text-gray-400 -rotate-90 whitespace-nowrap">
                    {(roll.widthMm / 1000).toFixed(2)}m
                  </span>
                </div>

                <div className="flex-1 overflow-x-auto">
                  <div
                    className="relative bg-gray-100 border border-gray-300 rounded"
                    style={{ width: displayWidth, height: ROLL_DISPLAY_HEIGHT, minWidth: '100%' }}
                  >
                    {roll.pieces.map((piece, i) => {
                      const color = piece.moId ? moColorMap[piece.moId] ?? MO_COLORS[0] : MO_COLORS[0];
                      const isSelected = selectedPiece === piece.id;
                      const pLeft = piece.y * scale;
                      const pTop = piece.x * scale;
                      const pW = piece.heightMm * scale;
                      const pH = piece.widthMm * scale;
                      return (
                        <div
                          key={`${piece.id}-${i}`}
                          className={`absolute border ${isSelected ? 'border-gray-900 border-2 z-10' : 'border-white/60'} rounded-sm flex flex-col items-center justify-center overflow-hidden cursor-pointer transition-all hover:opacity-90`}
                          style={{
                            left: pLeft,
                            top: pTop,
                            width: Math.max(pW, 1),
                            height: Math.max(pH, 1),
                            backgroundColor: color,
                            opacity: 0.85,
                          }}
                          title={`${piece.label ?? piece.id}${piece.rotated ? ' (rotated)' : ''}${piece.moNumber ? `\nMO: ${piece.moNumber}` : ''}\nOn roll: ${Math.round(piece.widthMm)}×${Math.round(piece.heightMm)}mm`}
                          onClick={() => {
                            const nowSelected = isSelected ? null : piece.id;
                            setSelectedPiece(nowSelected);
                            if (nowSelected) onPieceClick?.(piece);
                          }}
                        >
                          {pW > 50 && pH > 24 && (
                            <>
                              <span className="text-[9px] font-semibold text-white truncate px-1 leading-tight">
                                {piece.label ? piece.label.split('·').pop()?.trim() : `${Math.round(piece.widthMm)}×${Math.round(piece.heightMm)}`}
                              </span>
                              <span className="text-[8px] text-white/80 truncate px-1 leading-tight">
                                {piece.moNumber ?? ''}
                              </span>
                            </>
                          )}
                          {pW > 30 && pW <= 50 && pH > 14 && (
                            <span className="text-[8px] font-medium text-white truncate px-0.5">
                              {piece.label ? piece.label.split('·').pop()?.trim() : `${Math.round(piece.widthMm)}×${Math.round(piece.heightMm)}`}
                            </span>
                          )}
                        </div>
                      );
                    })}

                    {/* Waste area indicator */}
                    {roll.usedLengthMm < roll.lengthMm && (
                      <div
                        className="absolute top-0 bottom-0 border-l-2 border-dashed border-gray-300"
                        style={{ left: roll.usedLengthMm * scale }}
                        title={`Remaining: ${((roll.lengthMm - roll.usedLengthMm) / 1000).toFixed(2)}m`}
                      />
                    )}
                  </div>

                  {/* Length axis label */}
                  <div className="flex justify-between mt-1 px-0.5">
                    <span className="text-[9px] text-gray-400">0</span>
                    <span className="text-[9px] text-gray-400">{(roll.usedLengthMm / 1000).toFixed(1)}m used</span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Selected piece detail — only show built-in bar when parent does not handle clicks */}
      {!onPieceClick && selectedPiece && (() => {
        const p = result.rolls.flatMap(r => r.pieces).find(pp => pp.id === selectedPiece);
        if (!p) return null;
        return (
          <div className="px-4 py-3 border-t border-gray-200 bg-blue-50">
            <div className="flex items-center gap-4 text-xs flex-wrap">
              <span className="font-semibold text-gray-700">{p.label ?? p.id}</span>
              <span className="text-gray-500">Cut: {Math.round(p.widthMm)}×{Math.round(p.heightMm)} mm</span>
              {p.rotated && <span className="text-blue-600 font-medium">Rotated</span>}
              {p.moNumber && <span className="text-gray-500">MO: {p.moNumber}</span>}
            </div>
          </div>
        );
      })()}
    </div>
  );
}
