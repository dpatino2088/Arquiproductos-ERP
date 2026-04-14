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

const LABEL_W_MM = 101.6; // 4"
const LABEL_H_MM = 25.4;  // 1"

export async function generatePartLabelsPDF(labels: PartLabel[]): Promise<jsPDF> {
  const doc = new jsPDF({
    orientation: 'landscape',
    unit: 'mm',
    format: [LABEL_W_MM, LABEL_H_MM],
  });

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    if (i > 0) doc.addPage([LABEL_W_MM, LABEL_H_MM], 'landscape');

    const qrPayload = `${label.moNumber}/${label.sku}/${label.lineId}`;
    const qrSize = 18;
    const qrX = LABEL_W_MM - qrSize - 2;
    const qrY = (LABEL_H_MM - qrSize) / 2;
    try {
      const qrDataUrl = await QRCode.toDataURL(qrPayload, { width: 220, margin: 1 });
      doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
    } catch {
      doc.setFontSize(5);
      doc.text('QR err', qrX + 2, qrY + 8);
    }

    const maxTextW = qrX - 4;
    const so = (label.soNumber ?? '-').slice(0, 14);
    const mo = (label.moNumber ?? '-').slice(0, 14);
    const sku = (label.sku ?? '-').slice(0, 22);
    const cut = (label.cutDimension ?? '-').replace(/^([XY])\s+/i, 'CUT: $1 ');
    const curtain = label.customerName ? `CURTAIN: ${label.customerName}` : '';
    const item = (label.itemName ?? '').slice(0, 30);
    let y = 4.5;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7);
    doc.text(`${so}  |  ${mo}  |  PROFILE`, 2, y, { maxWidth: maxTextW });
    y += 3.8;

    doc.setFontSize(9);
    doc.text(sku, 2, y, { maxWidth: maxTextW });
    y += 4.2;

    doc.setFontSize(9);
    doc.text(cut, 2, y, { maxWidth: maxTextW });
    y += 3.5;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    if (curtain) {
      doc.text(curtain.slice(0, 40), 2, y, { maxWidth: maxTextW });
      y += 3;
    }

    doc.setFontSize(5.5);
    doc.setTextColor(100);
    doc.text(item, 2, y, { maxWidth: maxTextW });
    doc.setTextColor(0);
  }

  return doc;
}
