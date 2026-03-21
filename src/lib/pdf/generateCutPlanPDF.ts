import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import type { CutPlan1DResult } from '../cutOptimizer';
import type { CutPlan2DResult } from '../cutOptimizer2D';

/** jsPDF typings omit some runtime APIs (plugins / newer builds). */
type JsPDFExtras = jsPDF & {
  setLineDashPattern(dashArray: number[], dashPhase: number): void;
  getNumberOfPages(): number;
};

interface CutPlanPDFOptions {
  type: '1d' | '2d';
  title: string;
  subtitle: string;
  sku: string;
  moNumbers: string[];

  stockLengthMm?: number;
  kerfMm?: number;
  result1D?: CutPlan1DResult;

  rollWidthMm?: number;
  rollLengthMm?: number;
  result2D?: CutPlan2DResult;

  moHexColorMap: Record<string, string>;
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
}

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}

const PIECE_COLORS: [number, number, number][] = [
  [59, 130, 246],   // blue
  [16, 185, 129],   // green
  [245, 158, 11],   // amber
  [139, 92, 246],   // purple
  [236, 72, 153],   // pink
  [20, 184, 166],   // teal
  [249, 115, 22],   // orange
  [99, 102, 241],   // indigo
];

function pieceCode(panelIdx: number, dropIdx: number, totalDrops: number): string {
  const letter = String.fromCharCode(65 + (panelIdx % 26));
  if (totalDrops <= 1) return letter;
  return `${letter}.${dropIdx + 1}`;
}

interface TaggedPiece {
  code: string;
  panelIdx: number;
  dropIdx: number;
  totalDrops: number;
  rollIdx: number;
  moNumber: string;
  label: string;
  widthMm: number;
  heightMm: number;
  rotated: boolean;
  moId?: string;
  colorIdx: number;
  isPrimary: boolean;
}

function buildTaggedPieces(result: CutPlan2DResult): TaggedPiece[] {
  const pieces: TaggedPiece[] = [];
  const panelMap = new Map<string, { panelIdx: number; drops: number }>();
  let nextPanel = 0;

  for (const roll of result.rolls) {
    for (const piece of roll.pieces) {
      const baseId = piece.id.replace(/-d\d+$/, '');
      const dropMatch = piece.id.match(/-d(\d+)$/);
      const dropIdx = dropMatch ? parseInt(dropMatch[1], 10) - 1 : 0;

      if (!panelMap.has(baseId)) {
        panelMap.set(baseId, { panelIdx: nextPanel++, drops: 0 });
      }
      const entry = panelMap.get(baseId)!;
      entry.drops = Math.max(entry.drops, dropIdx + 1);
    }
  }

  for (const roll of result.rolls) {
    for (const piece of roll.pieces) {
      const baseId = piece.id.replace(/-d\d+$/, '');
      const dropMatch = piece.id.match(/-d(\d+)$/);
      const dropIdx = dropMatch ? parseInt(dropMatch[1], 10) - 1 : 0;
      const entry = panelMap.get(baseId)!;
      const code = pieceCode(entry.panelIdx, dropIdx, entry.drops);
      const isPrimary = dropIdx === 0;

      pieces.push({
        code,
        panelIdx: entry.panelIdx,
        dropIdx,
        totalDrops: entry.drops,
        rollIdx: roll.index,
        moNumber: piece.moNumber ?? '—',
        label: piece.label ?? '—',
        widthMm: piece.widthMm,
        heightMm: piece.heightMm,
        rotated: piece.rotated,
        moId: piece.moId,
        colorIdx: entry.panelIdx % PIECE_COLORS.length,
        isPrimary,
      });
    }
  }

  return pieces;
}

export function generateCutPlanPDF(opts: CutPlanPDFOptions): jsPDF {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const mx = 12;
  let y = 12;

  // --- Header ---
  const logoSlotW = 50;
  const logoSlotH = 14;
  let logoDrawn = false;
  if (opts.logoPngBase64) {
    try {
      const wPx = opts.logoWidthPx ?? 100;
      const hPx = opts.logoHeightPx ?? 100;
      const pxToMm = 25.4 / 72;
      const wMm = wPx * pxToMm;
      const hMm = hPx * pxToMm;
      const scale = Math.min(logoSlotW / wMm, logoSlotH / hMm, 1);
      const drawW = wMm * scale;
      const drawH = hMm * scale;
      const imgY = y + (logoSlotH - drawH) / 2;
      const fmt = opts.logoPngBase64.startsWith('data:image/jpeg') ? 'JPEG' : 'PNG';
      doc.addImage(opts.logoPngBase64, fmt, mx, imgY, drawW, drawH);
      logoDrawn = true;
    } catch { /* ignore */ }
  }
  if (!logoDrawn) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(14);
    doc.text('ARQUIPRODUCTOS', mx, y + 8);
  }

  const rightX = pageW - mx;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text('CUT PLAN', rightX, y + 4, { align: 'right' });
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100);
  doc.text(opts.type === '1d' ? 'Profile / 1D Optimization' : 'Fabric / 2D Optimization', rightX, y + 9, { align: 'right' });
  doc.text(new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }), rightX, y + 13, { align: 'right' });
  doc.setTextColor(0);

  y += logoSlotH + 4;
  doc.setDrawColor(180);
  doc.setLineWidth(0.4);
  doc.line(mx, y, pageW - mx, y);
  y += 5;

  // --- Material info block (compact 2-column layout) ---
  const materialName = opts.title.replace(new RegExp(`^${opts.sku}\\s*[—–-]\\s*`), '').trim();
  const infoLeft = mx;
  const infoRight = pageW / 2 + 10;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text(opts.sku, infoLeft, y);
  const skuW = doc.getTextWidth(opts.sku);
  if (materialName && materialName !== opts.sku) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(80);
    doc.text(`  ${materialName}`, infoLeft + skuW, y);
    doc.setTextColor(0);
  }

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  if (opts.type === '2d' && opts.rollWidthMm && opts.rollLengthMm) {
    doc.text(`Roll: ${(opts.rollWidthMm / 1000).toFixed(2)}m wide × ${(opts.rollLengthMm / 1000).toFixed(1)}m long`, infoRight, y);
  }
  if (opts.type === '1d' && opts.stockLengthMm) {
    doc.text(`Stock: ${opts.stockLengthMm}mm  ·  Kerf: ${opts.kerfMm ?? 3}mm`, infoRight, y);
  }
  y += 5;

  doc.setFontSize(7.5);
  doc.setTextColor(80);
  const moLine = `MOs: ${opts.moNumbers.join(', ')}`;
  doc.text(moLine, infoLeft, y);

  if (opts.moNumbers.length > 0) {
    let legendX = infoRight;
    const entries = Object.entries(opts.moHexColorMap);
    for (let i = 0; i < opts.moNumbers.length; i++) {
      const moNum = opts.moNumbers[i];
      const color = entries[i] ? hexToRgb(entries[i][1]) : [100, 100, 100] as [number, number, number];
      doc.setFillColor(color[0], color[1], color[2]);
      doc.rect(legendX, y - 2.5, 3, 2.5, 'F');
      legendX += 4;
      doc.setTextColor(60);
      doc.text(moNum, legendX, y);
      legendX += doc.getTextWidth(moNum) + 5;
    }
  }
  doc.setTextColor(0);
  y += 4;

  doc.setDrawColor(210);
  doc.setLineWidth(0.2);
  doc.line(mx, y, pageW - mx, y);
  y += 5;

  // =================== 1D PROFILE BARS ===================
  if (opts.type === '1d' && opts.result1D) {
    const r = opts.result1D;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text(`Efficiency: ${r.efficiencyPct}%  ·  ${r.totalStockUnits} bars  ·  ${r.totalPieces} pieces  ·  Waste: ${(r.totalWasteMm / 1000).toFixed(2)}m`, mx, y);
    y += 6;

    const barAreaW = pageW - mx * 2;
    const barH = 8;
    const barGap = 6;

    for (const bar of r.bars) {
      if (y + barH + barGap > pageH - 15) {
        doc.addPage();
        y = mx;
      }

      doc.setFontSize(6);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(120);
      doc.text(`Bar ${bar.index + 1}   ${(bar.usedMm / 1000).toFixed(2)}/${(bar.stockLengthMm / 1000).toFixed(2)}m   waste: ${(bar.wasteMm / 1000).toFixed(2)}m`, mx, y);
      doc.setTextColor(0);
      y += 3;

      doc.setFillColor(240, 240, 240);
      doc.rect(mx, y, barAreaW, barH, 'F');
      doc.setDrawColor(200);
      doc.rect(mx, y, barAreaW, barH, 'S');

      const scale = barAreaW / Math.max(bar.stockLengthMm, opts.stockLengthMm ?? 5800);

      for (const piece of bar.pieces) {
        const px = mx + piece.positionMm * scale;
        const pw = piece.lengthMm * scale;
        const color = piece.moId && opts.moHexColorMap[piece.moId]
          ? hexToRgb(opts.moHexColorMap[piece.moId])
          : [100, 160, 240] as [number, number, number];
        doc.setFillColor(color[0], color[1], color[2]);
        doc.rect(px, y + 0.5, Math.max(pw, 0.5), barH - 1, 'F');

        if (pw > 8) {
          doc.setFontSize(5);
          doc.setTextColor(255);
          doc.text(`${Math.round(piece.lengthMm)}`, px + pw / 2, y + barH / 2 + 1, { align: 'center' });
          doc.setTextColor(0);
        }
      }

      y += barH + barGap;
    }

    y += 4;
    if (y + 20 > pageH - 15) { doc.addPage(); y = mx; }

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text('Piece Detail', mx, y);
    y += 3;

    const tableRows: (string | number)[][] = [];
    for (const bar of r.bars) {
      for (const piece of bar.pieces) {
        tableRows.push([
          bar.index + 1,
          piece.moNumber ?? '—',
          piece.sku ?? '—',
          piece.label ?? '—',
          Math.round(piece.lengthMm),
          Math.round(piece.positionMm),
        ]);
      }
    }

    autoTable(doc, {
      startY: y,
      margin: { left: mx, right: mx },
      head: [['Bar', 'MO', 'SKU', 'Label', 'Length (mm)', 'Position (mm)']],
      body: tableRows,
      styles: { fontSize: 6.5, cellPadding: 1.5 },
      headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 6.5, halign: 'center' },
      alternateRowStyles: { fillColor: [249, 250, 251] },
      columnStyles: {
        0: { cellWidth: 12, halign: 'center' },
        4: { halign: 'right' },
        5: { halign: 'right' },
      },
    });
  }

  // =================== 2D FABRIC ROLLS ===================
  if (opts.type === '2d' && opts.result2D) {
    const r = opts.result2D;
    const tagged = buildTaggedPieces(r);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text(`Efficiency: ${r.totalEfficiencyPct}%  ·  ${r.totalRolls} roll${r.totalRolls > 1 ? 's' : ''}  ·  ${r.totalPieces} pieces`, mx, y);
    y += 6;

    const maxDrawW = pageW - mx * 2 - 10;
    const rollVisH = 28;

    for (const roll of r.rolls) {
      if (y + rollVisH + 14 > pageH - 15) { doc.addPage(); y = mx; }

      doc.setFontSize(7);
      doc.setFont('helvetica', 'bold');
      doc.text(`Roll ${roll.index + 1}`, mx, y);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.5);
      doc.text(
        `${(roll.widthMm / 1000).toFixed(2)}m × ${(roll.usedLengthMm / 1000).toFixed(1)}m used of ${(roll.lengthMm / 1000).toFixed(1)}m  (waste ${roll.wastePct}%)`,
        mx + 14, y,
      );
      y += 4;

      const scaleH = rollVisH / roll.widthMm;
      const rollDrawW = Math.min(roll.usedLengthMm * scaleH, maxDrawW);
      const scaleW = rollDrawW / Math.max(roll.usedLengthMm, 1);

      const rollX = mx + 10;

      doc.setFillColor(248, 248, 248);
      doc.rect(rollX, y, rollDrawW, rollVisH, 'F');
      doc.setDrawColor(180);
      doc.setLineWidth(0.3);
      doc.rect(rollX, y, rollDrawW, rollVisH, 'S');

      // Roll width label
      doc.setFontSize(5);
      doc.setTextColor(120);
      doc.text(`${(roll.widthMm / 1000).toFixed(2)}m`, rollX - 1, y + rollVisH / 2 + 1, { align: 'right' });
      doc.setTextColor(0);

      const rollPieces = tagged.filter(t => t.rollIdx === roll.index);

      for (const piece of roll.pieces) {
        const px = rollX + piece.y * scaleW;
        const py = y + piece.x * scaleH;
        const pw = piece.heightMm * scaleW;
        const ph = piece.widthMm * scaleH;

        const tp = rollPieces.find(t => t.label === (piece.label ?? '') && t.widthMm === piece.widthMm && t.heightMm === piece.heightMm);
        const color = tp ? PIECE_COLORS[tp.colorIdx] : [59, 130, 246] as [number, number, number];

        doc.setFillColor(color[0], color[1], color[2]);
        doc.rect(px, py, Math.max(pw, 0.3), Math.max(ph, 0.3), 'F');
        doc.setDrawColor(255, 255, 255);
        doc.setLineWidth(0.3);
        doc.rect(px, py, Math.max(pw, 0.3), Math.max(ph, 0.3), 'S');

        if (pw > 8 && ph > 4 && tp) {
          doc.setFontSize(5);
          doc.setTextColor(255);
          doc.setFont('helvetica', 'bold');
          doc.text(tp.code, px + pw / 2, py + ph / 2 + 0.5, { align: 'center' });
          doc.setTextColor(0);
          doc.setFont('helvetica', 'normal');
        }
      }

      doc.setFontSize(5);
      doc.setTextColor(140);
      doc.text('0', rollX, y + rollVisH + 3);
      doc.text(`${(roll.usedLengthMm / 1000).toFixed(1)}m`, rollX + rollDrawW, y + rollVisH + 3, { align: 'right' });
      doc.setTextColor(0);

      y += rollVisH + 10;
    }

    // --- Piece Detail Table ---
    y += 2;
    if (y + 20 > pageH - 15) { doc.addPage(); y = mx; }

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text('Piece Detail', mx, y);
    y += 4;

    tagged.sort((a, b) => a.panelIdx - b.panelIdx || a.dropIdx - b.dropIdx);

    const tableRows: (string | number)[][] = tagged.map(t => [
      t.code,
      t.rollIdx + 1,
      t.moNumber,
      t.isPrimary ? 'Primary' : 'Secondary',
      `${Math.round(t.widthMm)} × ${Math.round(t.heightMm)}`,
      t.rotated ? 'Yes' : '—',
    ]);

    autoTable(doc, {
      startY: y,
      margin: { left: mx, right: mx },
      head: [['Code', 'Roll', 'MO', 'Type', 'Dimensions (mm)', 'Rotated']],
      body: tableRows,
      styles: { fontSize: 6.5, cellPadding: 1.8 },
      headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 7, halign: 'center' },
      alternateRowStyles: { fillColor: [249, 250, 251] },
      columnStyles: {
        0: { cellWidth: 16, halign: 'center', fontStyle: 'bold' },
        1: { cellWidth: 12, halign: 'center' },
        2: { cellWidth: 28 },
        3: { cellWidth: 22, halign: 'center' },
        4: { halign: 'center' },
        5: { cellWidth: 16, halign: 'center' },
      },
      didParseCell(data) {
        if (data.section === 'body' && data.column.index === 0) {
          const code = String(data.cell.raw);
          const panelIdx = code.charCodeAt(0) - 65;
          const rgb = PIECE_COLORS[panelIdx % PIECE_COLORS.length];
          data.cell.styles.textColor = rgb;
        }
        if (data.section === 'body' && data.column.index === 3) {
          const val = String(data.cell.raw);
          if (val === 'Secondary') {
            data.cell.styles.textColor = [180, 120, 0];
            data.cell.styles.fontStyle = 'italic';
          }
        }
      },
    });
  }

  // --- Footer ---
  const totalPages = (doc as any).internal.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    doc.setFontSize(6.5);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(150);
    doc.text(`Cut Plan — ${opts.sku}`, mx, pageH - 6);
    doc.text(`Page ${i} of ${totalPages}`, pageW / 2, pageH - 6, { align: 'center' });
    doc.setTextColor(0);
  }

  return doc;
}

export function generateStickersPDF(
  pieces: TaggedPiece[],
  sku: string,
  materialName: string,
): jsPDF {
  const stickerW = 80;
  const stickerH = 40;
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const cols = Math.floor((pageW - 10) / stickerW);
  const rows = Math.floor((pageH - 10) / stickerH);
  const offsetX = (pageW - cols * stickerW) / 2;
  const offsetY = (pageH - rows * stickerH) / 2;

  pieces.forEach((piece, idx) => {
    if (idx > 0 && idx % (cols * rows) === 0) doc.addPage();
    const pageIdx = idx % (cols * rows);
    const col = pageIdx % cols;
    const row = Math.floor(pageIdx / cols);
    const x = offsetX + col * stickerW;
    const y = offsetY + row * stickerH;

    doc.setDrawColor(180);
    doc.setLineWidth(0.3);
    (doc as JsPDFExtras).setLineDashPattern([1, 1], 0);
    doc.rect(x, y, stickerW, stickerH);
    (doc as JsPDFExtras).setLineDashPattern([], 0);

    const rgb = PIECE_COLORS[piece.colorIdx];
    doc.setFillColor(rgb[0], rgb[1], rgb[2]);
    doc.rect(x + 2, y + 2, 14, 14, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.setTextColor(255);
    doc.text(piece.code, x + 9, y + 11, { align: 'center' });
    doc.setTextColor(0);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text(piece.moNumber, x + 19, y + 7);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    doc.text(`${sku} — ${materialName}`, x + 19, y + 11);
    doc.text(`${Math.round(piece.widthMm)} × ${Math.round(piece.heightMm)} mm`, x + 19, y + 15);

    doc.setFontSize(7);
    doc.setFont('helvetica', 'bold');
    const typeLabel = piece.isPrimary ? 'PRIMARY' : 'SECONDARY';
    doc.text(typeLabel, x + 2, y + 22);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6);
    doc.text(`Roll ${piece.rollIdx + 1}  ·  ${piece.rotated ? 'Rotated' : 'No rotation'}`, x + 2, y + 26);

    if (piece.totalDrops > 1) {
      doc.setFontSize(6);
      doc.text(`Drop ${piece.dropIdx + 1} of ${piece.totalDrops}`, x + 2, y + 30);
      const pairCode = piece.isPrimary
        ? pieceCode(piece.panelIdx, 1, piece.totalDrops)
        : pieceCode(piece.panelIdx, 0, piece.totalDrops);
      doc.setFont('helvetica', 'bold');
      doc.text(`Pair: ${pairCode}`, x + 2, y + 34);
    }

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(5.5);
    doc.setTextColor(120);
    doc.text(`${piece.code}`, x + stickerW - 3, y + stickerH - 2, { align: 'right' });
    doc.setTextColor(0);
  });

  return doc;
}

interface ConsolidatedCutGroup {
  sku: string;
  itemName: string;
  stockLengthMm: number;
  kerfMm: number;
  result: CutPlan1DResult;
  moHexColorMap: Record<string, string>;
  moNumbers: string[];
}

export function generateConsolidated1DPDF(
  groups: ConsolidatedCutGroup[],
  opts?: { logoPngBase64?: string; logoWidthPx?: number; logoHeightPx?: number },
): jsPDF {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const mx = 12;
  let y = 12;

  const logoSlotW = 50;
  const logoSlotH = 14;
  let logoDrawn = false;
  if (opts?.logoPngBase64) {
    try {
      const wPx = opts.logoWidthPx ?? 100;
      const hPx = opts.logoHeightPx ?? 100;
      const pxToMm = 25.4 / 72;
      const wMm = wPx * pxToMm;
      const hMm = hPx * pxToMm;
      const scale = Math.min(logoSlotW / wMm, logoSlotH / hMm, 1);
      const drawW = wMm * scale;
      const drawH = hMm * scale;
      const imgY = y + (logoSlotH - drawH) / 2;
      const fmt = opts.logoPngBase64.startsWith('data:image/jpeg') ? 'JPEG' : 'PNG';
      doc.addImage(opts.logoPngBase64, fmt, mx, imgY, drawW, drawH);
      logoDrawn = true;
    } catch { /* ignore */ }
  }
  if (!logoDrawn) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(14);
    doc.text('ARQUIPRODUCTOS', mx, y + 8);
  }

  const rightX = pageW - mx;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text('CONSOLIDATED CUT ORDER', rightX, y + 4, { align: 'right' });
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100);
  doc.text('Profile / 1D Optimization — All Materials', rightX, y + 9, { align: 'right' });
  doc.text(new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }), rightX, y + 13, { align: 'right' });
  doc.setTextColor(0);

  y += logoSlotH + 4;
  doc.setDrawColor(180);
  doc.setLineWidth(0.4);
  doc.line(mx, y, pageW - mx, y);
  y += 5;

  // Summary
  const totalBars = groups.reduce((s, g) => s + g.result.totalStockUnits, 0);
  const totalPieces = groups.reduce((s, g) => s + g.result.totalPieces, 0);
  const allMOs = [...new Set(groups.flatMap(g => g.moNumbers))];

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text(`${groups.length} materials  ·  ${totalBars} bars  ·  ${totalPieces} pieces  ·  MOs: ${allMOs.join(', ')}`, mx, y);
  y += 7;

  // Render each SKU group
  for (let gi = 0; gi < groups.length; gi++) {
    const g = groups[gi];
    const r = g.result;

    if (y + 30 > pageH - 15) { doc.addPage(); y = mx; }

    // Section header
    doc.setFillColor(245, 245, 245);
    doc.rect(mx, y - 3, pageW - mx * 2, 10, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text(`${gi + 1}. ${g.sku}`, mx + 2, y + 2);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(80);
    const infoText = `${g.itemName}  ·  Stock: ${(g.stockLengthMm / 1000).toFixed(2)}m  ·  Kerf: ${g.kerfMm}mm  ·  Eff: ${r.efficiencyPct}%  ·  ${r.totalStockUnits} bar${r.totalStockUnits !== 1 ? 's' : ''}  ·  ${r.totalPieces} pc`;
    doc.text(infoText, mx + 2, y + 6);
    doc.setTextColor(0);
    y += 10;

    // MO legend
    if (g.moNumbers.length > 0) {
      let legendX = mx + 2;
      doc.setFontSize(6);
      for (const moNum of g.moNumbers) {
        const moId = Object.entries(g.moHexColorMap).find(([, v]) => {
          const pieces = r.bars.flatMap(b => b.pieces);
          const p = pieces.find(p => p.moNumber === moNum);
          return p?.moId ? g.moHexColorMap[p.moId] === v : false;
        });
        const hex = moId ? moId[1] : '#6b7280';
        const color = hexToRgb(hex);
        doc.setFillColor(color[0], color[1], color[2]);
        doc.rect(legendX, y - 2, 3, 2.5, 'F');
        legendX += 4;
        doc.text(moNum, legendX, y);
        legendX += doc.getTextWidth(moNum) + 4;
      }
      y += 4;
    }

    // Bars
    const barAreaW = pageW - mx * 2;
    const barH = 7;
    const barGap = 5;

    for (const bar of r.bars) {
      if (y + barH + barGap > pageH - 15) { doc.addPage(); y = mx; }

      doc.setFontSize(5.5);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(120);
      doc.text(`Bar ${bar.index + 1}   ${(bar.usedMm / 1000).toFixed(2)}/${(bar.stockLengthMm / 1000).toFixed(2)}m   waste: ${(bar.wasteMm / 1000).toFixed(2)}m`, mx, y);
      doc.setTextColor(0);
      y += 2.5;

      doc.setFillColor(240, 240, 240);
      doc.rect(mx, y, barAreaW, barH, 'F');
      doc.setDrawColor(200);
      doc.rect(mx, y, barAreaW, barH, 'S');

      const scale = barAreaW / Math.max(bar.stockLengthMm, g.stockLengthMm);

      for (const piece of bar.pieces) {
        const px = mx + piece.positionMm * scale;
        const pw = piece.lengthMm * scale;
        const color = piece.moId && g.moHexColorMap[piece.moId]
          ? hexToRgb(g.moHexColorMap[piece.moId])
          : [100, 160, 240] as [number, number, number];
        doc.setFillColor(color[0], color[1], color[2]);
        doc.rect(px, y + 0.5, Math.max(pw, 0.5), barH - 1, 'F');

        if (pw > 8) {
          doc.setFontSize(4.5);
          doc.setTextColor(255);
          doc.text(`${Math.round(piece.lengthMm)}`, px + pw / 2, y + barH / 2 + 0.8, { align: 'center' });
          doc.setTextColor(0);
        }
      }
      y += barH + barGap;
    }

    // Piece table
    y += 2;
    if (y + 15 > pageH - 15) { doc.addPage(); y = mx; }

    const tableRows: (string | number)[][] = [];
    for (const bar of r.bars) {
      for (const piece of bar.pieces) {
        tableRows.push([
          bar.index + 1,
          piece.moNumber ?? '—',
          Math.round(piece.lengthMm),
          Math.round(piece.positionMm),
        ]);
      }
    }

    autoTable(doc, {
      startY: y,
      margin: { left: mx, right: mx },
      head: [['Bar', 'MO', 'Length (mm)', 'Position (mm)']],
      body: tableRows,
      styles: { fontSize: 5.5, cellPadding: 1.2 },
      headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 5.5, halign: 'center' },
      alternateRowStyles: { fillColor: [249, 250, 251] },
      columnStyles: {
        0: { cellWidth: 10, halign: 'center' },
        2: { halign: 'right' },
        3: { halign: 'right' },
      },
    });

    y = (doc as any).lastAutoTable?.finalY ?? y + 20;
    y += 6;

    // Separator between SKU sections
    if (gi < groups.length - 1) {
      if (y + 10 > pageH - 15) { doc.addPage(); y = mx; }
      doc.setDrawColor(200);
      doc.setLineWidth(0.3);
      doc.line(mx, y, pageW - mx, y);
      y += 6;
    }
  }

  // Footer on each page
  const totalPages = (doc as JsPDFExtras).getNumberOfPages();
  for (let p = 1; p <= totalPages; p++) {
    doc.setPage(p);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(5.5);
    doc.setTextColor(150);
    doc.text(`CONSOLIDATED CUT ORDER  ·  Page ${p}/${totalPages}`, pageW / 2, pageH - 5, { align: 'center' });
    doc.setTextColor(0);
  }

  return doc;
}

export { buildTaggedPieces };
export type { TaggedPiece, ConsolidatedCutGroup };
