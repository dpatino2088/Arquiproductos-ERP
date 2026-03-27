import jsPDF from 'jspdf';
import QRCode from 'qrcode';

export interface ThermalCutLabel {
  soNumber?: string | null;
  moNumber: string;
  stationCode: 'CUT-PROFILE' | 'CUT-ROLL';
  sku: string;
  itemName?: string | null;
  cutWidthMm?: number | null;
  cutHeightMm?: number | null;
  curtainWidthMm?: number | null;
  curtainHeightMm?: number | null;
  refId?: string | null;
}

const LABEL_W_MM = 101.6;  // 4 inches
const LABEL_H_MM = 25.4;   // 1 inch

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
  const doc = new jsPDF({
    orientation: 'l',
    unit: 'mm',
    format: [LABEL_W_MM, LABEL_H_MM],
  });

  for (let i = 0; i < labels.length; i++) {
    const l = labels[i];
    if (i > 0) doc.addPage([LABEL_W_MM, LABEL_H_MM], 'l');

    const so = trim(l.soNumber ?? '-', 14);
    const mo = trim(l.moNumber ?? '-', 14);
    const sku = trim(l.sku ?? '-', 22);
    const item = trim(l.itemName ?? '', 30);
    const station = l.stationCode === 'CUT-PROFILE' ? 'PROFILE' : 'ROLL';

    const cutStr = l.stationCode === 'CUT-PROFILE'
      ? `CUT: ${mm(l.cutWidthMm)} mm`
      : `CUT: ${mm(l.cutWidthMm)} x ${mm(l.cutHeightMm)} mm`;
    const curtainStr = (l.curtainWidthMm != null || l.curtainHeightMm != null)
      ? `CURTAIN: ${mm(l.curtainWidthMm)} x ${mm(l.curtainHeightMm)} mm`
      : '';

    // QR code (right side)
    const qrPayload = `SO:${so}|MO:${mo}|SKU:${l.sku}|CUT:${mm(l.cutWidthMm)}x${mm(l.cutHeightMm)}`;
    const qrSize = 18;
    const qrX = LABEL_W_MM - qrSize - 2;
    const qrY = (LABEL_H_MM - qrSize) / 2;

    try {
      const qrDataUrl = await QRCode.toDataURL(qrPayload, { width: 200, margin: 1 });
      doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
    } catch {
      doc.setFontSize(5);
      doc.text('QR err', qrX + 2, qrY + 8);
    }

    const maxTextW = qrX - 4;
    let y = 4.5;

    // Row 1: SO | MO | STATION
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7);
    doc.text(`${so}  |  ${mo}  |  ${station}`, 2, y, { maxWidth: maxTextW });
    y += 3.8;

    // Row 2: SKU (prominent)
    doc.setFontSize(9);
    doc.text(sku, 2, y, { maxWidth: maxTextW });
    y += 4.2;

    // Row 3: CUT dimension (bold)
    doc.setFontSize(8);
    doc.text(cutStr, 2, y, { maxWidth: maxTextW });
    y += 3.5;

    // Row 4: CURTAIN dimension
    if (curtainStr) {
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.5);
      doc.text(curtainStr, 2, y, { maxWidth: maxTextW });
      y += 3;
    }

    // Row 5: item name (light)
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(5.5);
    doc.setTextColor(100);
    doc.text(item, 2, y, { maxWidth: maxTextW });
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
