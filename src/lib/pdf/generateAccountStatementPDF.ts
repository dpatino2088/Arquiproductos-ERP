/**
 * Generate Account Statement PDF
 * Header: org logo (top-left), "ACCOUNT STATEMENT" + as of date (top-right).
 * Bill To: dealer name, Tax ID, billing address.
 * Statement Details: statement date, period.
 * Summary: total invoiced, total paid, open AR, past due; aging buckets.
 * Table: Date | Type | Reference | Debit | Credit.
 * Footer: page numbers.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export interface StatementPDFDealer {
  dealer_name: string;
  dealer_no: string | null;
  identification_number: string | null;
  billing_address: string;
  email: string | null;
  phone: string | null;
}

export interface StatementPDFSummary {
  total_invoiced_lifetime: number;
  total_paid_lifetime: number;
  open_ar: number;
  past_due_amount: number;
  aging_current: number;
  aging_1_30: number;
  aging_31_60: number;
  aging_61_90: number;
  aging_90_plus: number;
  currency_code: string;
}

export interface StatementPDFLine {
  date: string;
  type: string;
  reference_no: string;
  debit: number;
  credit: number;
}

export interface GenerateStatementPDFOptions {
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
  organizationName?: string;
}

function fmtCurrency(v: number, currency: string): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

export function generateAccountStatementPDF(
  dealer: StatementPDFDealer | null,
  statementDate: string,
  summary: StatementPDFSummary,
  lines: StatementPDFLine[],
  opts: GenerateStatementPDFOptions = {}
): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 12;
  const marginTop = 14;
  const usableWidth = pageWidth - marginX * 2;
  const cur = summary.currency_code || 'USD';
  let yPos = marginTop;

  // Top-left brand slot: logo (preferred) or org name fallback.
  const logoSlotW = 80;
  const logoSlotH = 20;
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
      const imgY = marginTop - 5 + (logoSlotH - drawH) / 2;
      const format = opts.logoPngBase64.startsWith('data:image/jpeg') ? 'JPEG' : 'PNG';
      doc.addImage(opts.logoPngBase64, format, marginX, imgY, drawW, drawH);
      logoDrawn = true;
    } catch { /* ignore */ }
  }
  if (!logoDrawn) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text(opts.organizationName ?? 'Arquiproductos', marginX, marginTop + 6);
  }

  // Header right: "ACCOUNT STATEMENT" + as of date + dealer name
  const headerRightX = pageWidth - marginX;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('ACCOUNT STATEMENT', headerRightX, yPos, { align: 'right' });
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.text(`As of ${new Date(statementDate).toLocaleDateString()}`, headerRightX, yPos + 5, { align: 'right' });
  if (dealer?.dealer_name) {
    doc.text(`Dealer: ${dealer.dealer_name}`, headerRightX, yPos + 10, { align: 'right' });
  }
  yPos += logoSlotH;

  // Details section: Bill To (left) | Statement Details (right)
  doc.setFontSize(9);
  const lineH = 4;
  const gap = 2.5;

  let leftY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Bill To', marginX, leftY);
  leftY += lineH + gap;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');

  if (dealer) {
    doc.setFont('helvetica', 'bold');
    doc.text(dealer.dealer_name, marginX, leftY);
    doc.setFont('helvetica', 'normal');
    leftY += lineH + gap;
    if (dealer.dealer_no) {
      doc.text(`Dealer #: ${dealer.dealer_no}`, marginX, leftY);
      leftY += lineH + gap;
    }
    if (dealer.identification_number) {
      doc.text(`Tax ID: ${dealer.identification_number}`, marginX, leftY);
      leftY += lineH + gap;
    }
    if (dealer.billing_address) {
      const addrLines = doc.splitTextToSize(dealer.billing_address, usableWidth / 2 - 10);
      addrLines.forEach((line: string) => {
        doc.text(line, marginX, leftY);
        leftY += lineH + 1;
      });
      leftY += gap;
    }
    if (dealer.email) {
      doc.text(dealer.email, marginX, leftY);
      leftY += lineH + gap;
    }
    if (dealer.phone) {
      doc.text(dealer.phone, marginX, leftY);
      leftY += lineH + gap;
    }
  } else {
    doc.text('N/A', marginX, leftY);
    leftY += lineH + gap;
  }

  const rightLabelX = pageWidth - marginX - 58;
  const rightValueX = pageWidth - marginX;
  let rightY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Statement Details', rightLabelX, rightY);
  rightY += lineH + gap;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'bold');
  doc.text('Statement Date:', rightLabelX, rightY);
  doc.setFont('helvetica', 'normal');
  doc.text(new Date(statementDate).toLocaleDateString(), rightValueX, rightY, { align: 'right' });
  rightY += lineH + gap;

  yPos = Math.max(leftY, rightY) + 4;

  // Summary section
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Summary', marginX, yPos);
  yPos += lineH + gap;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  const summaryItems = [
    { label: 'Total Invoiced', value: fmtCurrency(summary.total_invoiced_lifetime, cur) },
    { label: 'Total Paid', value: fmtCurrency(summary.total_paid_lifetime, cur) },
    { label: 'Open AR', value: fmtCurrency(summary.open_ar, cur) },
    { label: 'Past Due', value: fmtCurrency(summary.past_due_amount, cur) },
  ];
  const halfWidth = usableWidth / 2;
  summaryItems.forEach((item, i) => {
    const col = i % 2;
    const x = marginX + col * (halfWidth + 4);
    const rowY = yPos + Math.floor(i / 2) * (lineH + gap);
    doc.setFont('helvetica', 'bold');
    doc.text(`${item.label}:`, x, rowY);
    doc.setFont('helvetica', 'normal');
    doc.text(item.value, x + 45, rowY);
  });
  yPos += 2 * (lineH + gap) + 2;

  // Divider line above Aging
  doc.setDrawColor(200, 200, 200);
  doc.setLineWidth(0.3);
  doc.line(marginX, yPos, pageWidth - marginX, yPos);
  yPos += lineH + gap;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text('Aging:', marginX, yPos);
  yPos += lineH + gap;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  const agingItems = [
    { label: 'Current', value: summary.aging_current },
    { label: '1-30', value: summary.aging_1_30 },
    { label: '31-60', value: summary.aging_31_60 },
    { label: '61-90', value: summary.aging_61_90 },
    { label: '90+', value: summary.aging_90_plus },
  ];
  const agingColW = (pageWidth - marginX * 2) / 5;
  const agingLabelY = yPos;
  const agingValueY = yPos + lineH + 2;
  agingItems.forEach((item, i) => {
    const colCenter = marginX + i * agingColW + agingColW / 2;
    doc.text(item.label, colCenter, agingLabelY, { align: 'center' });
    doc.text(fmtCurrency(item.value, cur), colCenter, agingValueY, { align: 'center' });
  });
  yPos += lineH + lineH + 4 + 6;

  // Separator
  doc.setDrawColor(200, 200, 200);
  doc.setLineWidth(0.3);
  doc.line(marginX, yPos, pageWidth - marginX, yPos);
  yPos += 4;

  // Activity table: Date | Type | Reference | Debit | Credit
  const tableColumns = [
    { header: 'Date', dataKey: 'date' },
    { header: 'Type', dataKey: 'type' },
    { header: 'Reference', dataKey: 'reference_no' },
    { header: 'Debit', dataKey: 'debit' },
    { header: 'Credit', dataKey: 'credit' },
  ];

  const tableRows = lines.map((l) => ({
    date: new Date(l.date).toLocaleDateString(),
    type: l.type,
    reference_no: l.reference_no || '—',
    debit: l.debit > 0 ? fmtCurrency(l.debit, cur) : '',
    credit: l.credit > 0 ? fmtCurrency(l.credit, cur) : '',
  }));

  autoTable(doc, {
    startY: yPos,
    head: [tableColumns.map((c) => c.header)],
    body: tableRows.map((r) => tableColumns.map((c) => (r as Record<string, string>)[c.dataKey])),
    margin: { left: marginX, right: marginX },
    theme: 'plain',
    styles: {
      fontSize: 8,
      cellPadding: 2,
      fillColor: [255, 255, 255],
      lineColor: [220, 220, 220],
      lineWidth: { bottom: 0.2 },
    },
    headStyles: {
      fillColor: [245, 245, 245],
      textColor: [60, 60, 60],
      fontStyle: 'bold',
      lineColor: [220, 220, 220],
      lineWidth: { bottom: 0.2 },
    },
    columnStyles: {
      0: { cellWidth: 22, halign: 'left' },
      1: { cellWidth: 28, halign: 'left' },
      2: { cellWidth: 'auto', halign: 'left' },
      3: { cellWidth: 28, halign: 'center', cellPadding: { top: 2, right: 2, bottom: 2, left: 12 } },
      4: { cellWidth: 28, halign: 'center', cellPadding: { top: 2, right: 2, bottom: 2, left: 12 } },
    },
    didParseCell: (hookData) => {
      if (hookData.section === 'head' && hookData.column.index === 3) {
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left: 15 };
      }
      if (hookData.section === 'head' && hookData.column.index === 4) {
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left: 14 };
      }
    },
    didDrawPage: () => {
      const pageCount = (doc as any).internal.getNumberOfPages();
      const currentPage = (doc as any).internal.getCurrentPageInfo().pageNumber;
      doc.setFontSize(8);
      doc.setFont('helvetica', 'normal');
      doc.text(`${currentPage} / ${pageCount}`, pageWidth / 2, doc.internal.pageSize.getHeight() - 8, { align: 'center' });
    },
  });

  return doc;
}
