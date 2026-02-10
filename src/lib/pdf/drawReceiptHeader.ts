/**
 * Receipt-style PDF header (Stripe/Cursor style).
 * A4 portrait, measures in mm. Used by Proposal and Quote PDFs.
 */

import type jsPDF from 'jspdf';

export type ReceiptHeaderData = {
  title?: string;
  invoiceNumber: string;
  receiptNumber: string;
  datePaidLong: string;

  leftTitle: string;
  leftLines: string[];

  billToTitle?: string;
  billToName: string;
  billToLines: string[];

  paidLine: string;
  cycleLine: string;

  logoPngBase64?: string;
};

const MARGIN = 14;
const LOGO_SIZE_MM = 18;
const ROW_Y1 = 40;
const ROW_GAP = 6;
const LABELS_X = 14;
const VALUES_X = 58;
const ADDRESSES_START_Y = 66;
const LINE_GAP = 5;
const LEFT_COL_X = 14;
const RIGHT_COL_X = 110;
const PAID_Y = 118;
const CYCLE_Y = 128;
const HEADER_BOTTOM_Y = 136;

/**
 * Draws the receipt-style header. Returns the Y (mm) where the table should start.
 */
export function drawReceiptHeader(doc: jsPDF, data: ReceiptHeaderData): number {
  const pageW = doc.internal.pageSize.getWidth();

  // Logo (top-right)
  const logoX = pageW - MARGIN - LOGO_SIZE_MM;
  const logoY = MARGIN;
  if (data.logoPngBase64) {
    try {
      doc.addImage(data.logoPngBase64, 'PNG', logoX, logoY, LOGO_SIZE_MM, LOGO_SIZE_MM);
    } catch {
      // ignore if image fails (e.g. invalid base64)
    }
  }

  // Title
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(24);
  doc.text(data.title ?? 'Receipt', MARGIN, 26);

  // Invoice / Receipt / Date paid rows
  const rows: Array<[string, string]> = [
    ['Invoice number', data.invoiceNumber],
    ['Receipt number', data.receiptNumber],
    ['Date paid', data.datePaidLong],
  ];

  doc.setFontSize(10);
  rows.forEach(([label, value], i) => {
    const y = ROW_Y1 + i * ROW_GAP;
    doc.setFont('helvetica', 'bold');
    doc.text(label, LABELS_X, y);
    doc.setFont('helvetica', 'normal');
    doc.text(value, VALUES_X, y);
  });

  // Address blocks (2 columns)
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text(data.leftTitle, LEFT_COL_X, ADDRESSES_START_Y);

  doc.setFont('helvetica', 'normal');
  data.leftLines.forEach((line, idx) => {
    doc.text(line, LEFT_COL_X, ADDRESSES_START_Y + (idx + 1) * LINE_GAP);
  });

  doc.setFont('helvetica', 'bold');
  doc.text(data.billToTitle ?? 'Bill to', RIGHT_COL_X, ADDRESSES_START_Y);

  doc.setFont('helvetica', 'normal');
  const billToAll = [data.billToName, ...data.billToLines];
  billToAll.forEach((line, idx) => {
    doc.text(line, RIGHT_COL_X, ADDRESSES_START_Y + (idx + 1) * LINE_GAP);
  });

  // Paid line
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  doc.text(data.paidLine, MARGIN, PAID_Y);

  // Cycle line
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.text(data.cycleLine, MARGIN, CYCLE_Y);

  return HEADER_BOTTOM_Y;
}

/** Mock header data for testing (e.g. in dev or storybook). Set logoPngBase64 if you have a PNG. */
export const MOCK_RECEIPT_HEADER_DATA: ReceiptHeaderData = {
  title: 'Receipt',
  invoiceNumber: 'VVWKSGIA-0013',
  receiptNumber: '2130-6989',
  datePaidLong: 'February 3, 2026',
  leftTitle: 'ARQUIPRODUCTOS',
  leftLines: [
    '801 West End Avenue',
    'New York, New York 10025',
    'United States',
    '+1 831-425-9504',
    'hi@example.com',
  ],
  billToTitle: 'Bill to',
  billToName: 'Customer Name',
  billToLines: ['Ciudad de Panama', 'Panama', 'Panama', 'customer@example.com'],
  paidLine: '$107.39 paid on February 3, 2026',
  cycleLine: 'Proposal for Customer Name',
};
