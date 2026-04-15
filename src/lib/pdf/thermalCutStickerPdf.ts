import jsPDF from 'jspdf';
import QRCode from 'qrcode';

export interface ThermalCutLabel {
  soNumber?: string | null;
  salesOrderId?: string | null;
  moNumber: string;
  stationCode: 'CUT-PROFILE' | 'CUT-ROLL';
  lineLabel?: string | null;
  dealerName?: string | null;
  sku: string;
  itemName?: string | null;
  cutWidthMm?: number | null;
  cutHeightMm?: number | null;
  curtainWidthMm?: number | null;
  curtainHeightMm?: number | null;
  refId?: string | null;
}

// Continuous stock geometry (mm)
// Each page = one label pitch: 106 wide × 28 tall
// Printable sticker area: 100 × 25, centered
const STOCK_W_MM = 106;
const STOCK_ROW_H_MM = 28;
const STICKER_W_MM = 100;
const STICKER_H_MM = 25;
const STICKER_X_MM = (STOCK_W_MM - STICKER_W_MM) / 2; // 3 mm
const STICKER_Y_MM = (STOCK_ROW_H_MM - STICKER_H_MM) / 2; // 1.5 mm

// jsPDF format: [shortSide, longSide] → landscape makes width = longSide
const PAGE_FORMAT: [number, number] = [STOCK_ROW_H_MM, STOCK_W_MM];

function mm(n?: number | null): string {
  if (n == null || Number.isNaN(Number(n))) return '-';
  return `${Math.round(Number(n))}`;
}

function trim(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 2) + '..';
}

export async function generateThermalCutStickersPDF(
  labels: ThermalCutLabel[],
): Promise<jsPDF> {
  const doc = new jsPDF({ orientation: 'l', unit: 'mm', format: PAGE_FORMAT });

  for (let i = 0; i < labels.length; i++) {
    if (i > 0) doc.addPage(PAGE_FORMAT, 'l');

    const l = labels[i];
    const labelX = STICKER_X_MM;
    const labelY = STICKER_Y_MM;

    const so = trim(l.soNumber ?? '-', 26);
    const mo = trim(l.moNumber ?? '-', 14);
    const woLine = trim(l.lineLabel ?? '-', 8);
    const dealer = trim(l.dealerName ?? '-', 24);
    const sku = trim(l.sku ?? '-', 22);
    const item = trim(l.itemName ?? '', 30);
    const station = l.stationCode === 'CUT-PROFILE' ? 'PROFILE' : 'ROLL';

    const cutStr = l.stationCode === 'CUT-PROFILE'
      ? `CUT: ${mm(l.cutWidthMm)} mm`
      : `CUT: ${mm(l.cutWidthMm)} x ${mm(l.cutHeightMm)} mm`;
    const curtainStr = (l.curtainWidthMm != null || l.curtainHeightMm != null)
      ? `CURTAIN: ${mm(l.curtainWidthMm)} x ${mm(l.curtainHeightMm)} mm`
      : '';

    const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
    const qrPayload = l.salesOrderId && baseUrl
      ? `${baseUrl}/sales/orders/${l.salesOrderId}`
      : `SO:${so}|MO:${mo}|L:${woLine}|SKU:${l.sku}|CUT:${mm(l.cutWidthMm)}x${mm(l.cutHeightMm)}`;
    const qrSize = 18;
    const qrX = labelX + STICKER_W_MM - qrSize - 2;
    const qrY = labelY + (STICKER_H_MM - qrSize) / 2;

    try {
      const qrDataUrl = await QRCode.toDataURL(qrPayload, { width: 200, margin: 1 });
      doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
    } catch {
      doc.setFontSize(5);
      doc.text('QR err', qrX + 2, qrY + 8);
    }

    const maxTextW = qrX - (labelX + 2);
    let y = labelY + 3;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(6.5);
    doc.text(`${so}  |  ${mo}  |  ${woLine}  |  ${station}`, labelX + 2, y, { maxWidth: maxTextW });
    y += 3.4;

    doc.setFontSize(9);
    doc.text(sku, labelX + 2, y, { maxWidth: maxTextW });
    y += 4.2;

    doc.setFontSize(8);
    doc.text(cutStr, labelX + 2, y, { maxWidth: maxTextW });
    y += 3.2;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6);
    doc.text(`DEALER: ${dealer}`, labelX + 2, y, { maxWidth: maxTextW });
    y += 2.8;

    if (curtainStr) {
      doc.setFontSize(5.8);
      doc.text(curtainStr, labelX + 2, y, { maxWidth: maxTextW });
      y += 2.6;
    }

    doc.setFontSize(5.2);
    doc.setTextColor(100);
    doc.text(item, labelX + 2, y, { maxWidth: maxTextW });
    doc.setTextColor(0);
  }

  return doc;
}

export function openThermalStickerPrintWindow(doc: jsPDF): void {
  const blobUrl = doc.output('bloburl');
  const printWindow = window.open(blobUrl as unknown as string, '_blank');
  if (printWindow) {
    printWindow.addEventListener('load', () => {
      setTimeout(() => printWindow.print(), 400);
    });
  }
}
