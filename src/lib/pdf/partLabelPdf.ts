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

const LABEL_W = 80;
const LABEL_H = 50;
const COLS = 2;
const ROWS = 5;
const PAGE_MARGIN_X = 15;
const PAGE_MARGIN_Y = 14;
const GAP_X = 10;
const GAP_Y = 6;

export async function generatePartLabelsPDF(labels: PartLabel[]): Promise<jsPDF> {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const perPage = COLS * ROWS;

  for (let i = 0; i < labels.length; i++) {
    const label = labels[i];
    const pageIdx = Math.floor(i / perPage);
    const posOnPage = i % perPage;
    const col = posOnPage % COLS;
    const row = Math.floor(posOnPage / COLS);

    if (i > 0 && posOnPage === 0) doc.addPage();

    const x = PAGE_MARGIN_X + col * (LABEL_W + GAP_X);
    const y = PAGE_MARGIN_Y + row * (LABEL_H + GAP_Y);

    doc.setDrawColor(200);
    doc.rect(x, y, LABEL_W, LABEL_H);

    const qrPayload = `${label.moNumber}/${label.sku}/${label.lineId}`;
    try {
      const qrDataUrl = await QRCode.toDataURL(qrPayload, { width: 120, margin: 1 });
      doc.addImage(qrDataUrl, 'PNG', x + 2, y + 2, 22, 22);
    } catch {
      doc.setFontSize(6);
      doc.text('QR Error', x + 4, y + 12);
    }

    const textX = x + 26;
    let textY = y + 6;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(10);
    doc.text(label.sku, textX, textY);
    textY += 5;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    const name = label.itemName.length > 30 ? label.itemName.substring(0, 30) + '…' : label.itemName;
    doc.text(name, textX, textY);
    textY += 4;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text(label.cutDimension, textX, textY);
    textY += 4;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    doc.text(`Qty: ${label.qty}`, textX, textY);
    textY += 4;

    const infoY = y + LABEL_H - 8;
    doc.setFontSize(6.5);
    doc.text(label.moNumber, x + 2, infoY);
    doc.text(label.customerName.substring(0, 20), x + 2, infoY + 3);
    doc.text(label.date, x + LABEL_W - 2, infoY + 3, { align: 'right' });
    if (label.soNumber) {
      doc.text(label.soNumber, x + LABEL_W - 2, infoY, { align: 'right' });
    }
  }

  return doc;
}
