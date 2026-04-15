import jsPDF from 'jspdf';
import QRCode from 'qrcode';

export interface PartLabel {
  moNumber: string;
  soNumber?: string;
  customerName: string;
  date: string;
  sku: string;
  itemName: string;
  cutDimension: string;
  qty: number;
  lineId: string;
}

// Continuous label stock geometry (mm)
// Each page = one label pitch: 106 wide × 28 tall
// Printable sticker area: 100 × 25, centered
const STOCK_W_MM = 106;
const STOCK_ROW_H_MM = 28;
const STICKER_W_MM = 100;
const STICKER_H_MM = 25;
const STICKER_X_MM = (STOCK_W_MM - STICKER_W_MM) / 2; // 3 mm
const STICKER_Y_MM = (STOCK_ROW_H_MM - STICKER_H_MM) / 2; // 1.5 mm

const PAGE_FORMAT: [number, number] = [STOCK_ROW_H_MM, STOCK_W_MM];

export async function generatePartLabelsPDF(labels: PartLabel[]): Promise<jsPDF> {
  const doc = new jsPDF({ orientation: 'l', unit: 'mm', format: PAGE_FORMAT });

  for (let i = 0; i < labels.length; i++) {
    if (i > 0) doc.addPage(PAGE_FORMAT, 'l');

    const label = labels[i];
    const labelX = STICKER_X_MM;
    const labelY = STICKER_Y_MM;

    const qrPayload = `${label.moNumber}/${label.sku}/${label.lineId}`;
    const qrSize = 18;
    const qrX = labelX + STICKER_W_MM - qrSize - 2;
    const qrY = labelY + (STICKER_H_MM - qrSize) / 2;
    try {
      const qrDataUrl = await QRCode.toDataURL(qrPayload, { width: 220, margin: 1 });
      doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
    } catch {
      doc.setFontSize(5);
      doc.text('QR err', qrX + 2, qrY + 8);
    }

    const maxTextW = qrX - (labelX + 2);
    const so = (label.soNumber ?? '-').slice(0, 14);
    const mo = (label.moNumber ?? '-').slice(0, 14);
    const sku = (label.sku ?? '-').slice(0, 22);
    const cut = (label.cutDimension ?? '-').replace(/^([XY])\s+/i, 'CUT: $1 ');
    const curtain = label.customerName ? `CURTAIN: ${label.customerName}` : '';
    const item = (label.itemName ?? '').slice(0, 30);
    let y = labelY + 3;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7);
    doc.text(`${so}  |  ${mo}  |  PROFILE`, labelX + 2, y, { maxWidth: maxTextW });
    y += 3.8;

    doc.setFontSize(9);
    doc.text(sku, labelX + 2, y, { maxWidth: maxTextW });
    y += 4.2;

    doc.setFontSize(9);
    doc.text(cut, labelX + 2, y, { maxWidth: maxTextW });
    y += 3.5;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    if (curtain) {
      doc.text(curtain.slice(0, 40), labelX + 2, y, { maxWidth: maxTextW });
      y += 3;
    }

    doc.setFontSize(5.5);
    doc.setTextColor(100);
    doc.text(item, labelX + 2, y, { maxWidth: maxTextW });
    doc.setTextColor(0);
  }

  return doc;
}
