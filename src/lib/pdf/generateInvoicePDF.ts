/**
 * Generate Invoice PDF
 * Header: dealer logo (top-left), "INVOICE" + number (top-right).
 * Bill To: dealer name, Tax ID, billing address.
 * Invoice Details: issue date, due date, SO reference.
 * Table: lines (description, qty, unit price, total).
 * Summary: subtotal, tax, total, paid, balance due.
 * Footer: page numbers.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatDate } from '../utils';

export interface InvoicePDFLine {
  description: string;
  qty: number;
  unit_price: number;
  line_subtotal: number;
}

export interface InvoicePDFData {
  invoice_number: string;
  status: string;
  issue_date: string;
  due_date: string | null;
  currency_code: string;
  subtotal: number;
  tax_total: number;
  total: number;
  total_paid: number;
  balance_due: number;
  notes: string | null;
  sales_order_no: string | null;
}

export interface InvoicePDFDealer {
  dealer_name: string;
  dealer_no: string | null;
  identification_number: string | null;
  billing_address: string;
  email: string | null;
  phone: string | null;
}

export interface GenerateInvoicePDFOptions {
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
  organizationName?: string;
}

function fmtCurrency(v: number, currency: string): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

export function generateInvoicePDF(
  invoice: InvoicePDFData,
  dealer: InvoicePDFDealer | null,
  lines: InvoicePDFLine[],
  opts: GenerateInvoicePDFOptions = {}
): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 12;
  const marginTop = 14;
  const usableWidth = pageWidth - marginX * 2;
  const cur = invoice.currency_code || 'USD';
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

  // Header right: "INVOICE" + number
  const headerRightX = pageWidth - marginX;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('INVOICE', headerRightX, yPos, { align: 'right' });
  doc.setFontSize(14);
  doc.text(invoice.invoice_number, headerRightX, yPos + 6, { align: 'right' });

  yPos += logoSlotH;

  // Details section: Bill To (left) | Invoice Info (right)
  doc.setFontSize(9);
  const lineH = 4;
  const gap = 2.5;

  // Left: Bill To
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

  // Right: Invoice details (anchored to right margin under invoice number)
  const rightLabelX = pageWidth - marginX - 58;
  const rightValueX = pageWidth - marginX;
  let rightY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Invoice Details', rightLabelX, rightY);
  rightY += lineH + gap;
  doc.setFontSize(9);

  const detailItems = [
    { label: 'Issue Date', value: formatDate(invoice.issue_date) },
    ...(invoice.due_date ? [{ label: 'Due Date', value: formatDate(invoice.due_date) }] : []),
    ...(invoice.sales_order_no ? [{ label: 'Sales Order', value: invoice.sales_order_no }] : []),
    { label: 'Status', value: invoice.status.charAt(0).toUpperCase() + invoice.status.slice(1) },
  ];

  for (const item of detailItems) {
    doc.setFont('helvetica', 'bold');
    doc.text(`${item.label}:`, rightLabelX, rightY);
    doc.setFont('helvetica', 'normal');
    doc.text(item.value, rightValueX, rightY, { align: 'right' });
    rightY += lineH + gap;
  }

  yPos = Math.max(leftY, rightY) + 4;

  // Separator
  doc.setDrawColor(200, 200, 200);
  doc.setLineWidth(0.3);
  doc.line(marginX, yPos, pageWidth - marginX, yPos);
  yPos += 4;

  // Lines table
  const tableColumns = [
    { header: '#', dataKey: 'num' },
    { header: 'Description', dataKey: 'description' },
    { header: 'Qty', dataKey: 'qty' },
    { header: 'Unit Price', dataKey: 'unit_price' },
    { header: 'Total', dataKey: 'line_subtotal' },
  ];

  const tableRows = lines.map((l, i) => ({
    num: String(i + 1),
    description: l.description,
    qty: String(l.qty),
    unit_price: fmtCurrency(l.unit_price, cur),
    line_subtotal: fmtCurrency(l.line_subtotal, cur),
  }));

  autoTable(doc, {
    startY: yPos,
    head: [tableColumns.map((c) => c.header)],
    body: tableRows.map((r) => tableColumns.map((c) => (r as any)[c.dataKey])),
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
    alternateRowStyles: {
      fillColor: [255, 255, 255],
    },
    didParseCell: (hookData) => {
      if (hookData.section === 'head' && [0, 2, 3, 4].includes(hookData.column.index)) {
        hookData.cell.styles.halign = 'left';
        const left =
          hookData.column.index === 0 ? 4 :
          hookData.column.index === 2 ? 5 :
          hookData.column.index === 4 ? 14.5 : 7;
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left };
      }
      if (hookData.section === 'body' && hookData.column.index === 4) {
        hookData.cell.styles.halign = 'left';
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left: 11.5 };
      }
    },
    columnStyles: {
      0: { cellWidth: 10, halign: 'center' },
      1: { cellWidth: 'auto' },
      2: { cellWidth: 15, halign: 'center' },
      3: { cellWidth: 25, halign: 'center' },
      4: { cellWidth: 25, halign: 'center' },
    },
    didDrawPage: () => {
      const pageCount = (doc as any).internal.getNumberOfPages();
      const currentPage = (doc as any).internal.getCurrentPageInfo().pageNumber;
      doc.setFontSize(8);
      doc.setFont('helvetica', 'normal');
      doc.text(`${currentPage} / ${pageCount}`, pageWidth / 2, doc.internal.pageSize.getHeight() - 8, { align: 'center' });
    },
  });

  yPos = (doc as any).lastAutoTable?.finalY ?? yPos + 40;
  yPos += 16;

  // Summary table (right-aligned)
  const summaryX = pageWidth - marginX - 56;
  const summaryValueX = pageWidth - marginX - 3;
  const summaryItems = [
    { label: 'Subtotal', value: fmtCurrency(invoice.subtotal, cur), bold: false },
    { label: 'Tax', value: fmtCurrency(invoice.tax_total, cur), bold: false },
    { label: 'Total', value: fmtCurrency(invoice.total, cur), bold: true },
    { label: 'Paid', value: fmtCurrency(invoice.total_paid, cur), bold: false },
    { label: 'Balance Due', value: fmtCurrency(invoice.balance_due, cur), bold: true },
  ];
  const summaryLineH = 3.2;
  const summaryGap = 1.8;
  const summaryBoldTopGap = 2.6;

  for (const item of summaryItems) {
    if (item.bold) {
      doc.setDrawColor(200, 200, 200);
      doc.line(summaryX - 2.5, yPos - 1.4, summaryValueX + 2.5, yPos - 1.4);
      yPos += summaryBoldTopGap;
    }
    doc.setFont('helvetica', item.bold ? 'bold' : 'normal');
    doc.setFontSize(9);
    doc.text(item.label, summaryX, yPos);
    doc.text(item.value, summaryValueX, yPos, { align: 'right' });
    yPos += summaryLineH + summaryGap;
  }

  // Notes
  if (invoice.notes) {
    yPos += 6;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text('Notes', marginX, yPos);
    yPos += lineH + gap;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const noteLines = doc.splitTextToSize(invoice.notes, usableWidth);
    noteLines.forEach((line: string) => {
      doc.text(line, marginX, yPos);
      yPos += 3.5;
    });
  }

  return doc;
}
