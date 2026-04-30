/**
 * Generate Purchase Order PDF
 * Header: "PURCHASE ORDER" + PO number (top-right).
 * Vendor Info: name, address, contact, payment/delivery terms.
 * PO Details: expected date, status, currency, reference.
 * Table: lines (#, SKU, Description, Qty, Unit Cost, Line Total).
 * Summary: subtotal, total.
 * Notes section.
 * Footer: page numbers.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatDate } from '../utils';

export interface POPDFLine {
  sku: string;
  description: string;
  qty: number;
  unit: string;
  unit_cost: number;
  line_total: number;
}

export interface POPDFData {
  po_number: string;
  status: string;
  expected_date: string | null;
  currency: string;
  subtotal: number;
  total: number;
  notes: string | null;
  allocation_summary: string | null;
  ship_to_address: string | null;
}

export interface POPDFVendor {
  name: string;
  email: string | null;
  phone: string | null;
  address: string;
  payment_terms: string | null;
  delivery_terms: string | null;
}

export interface GeneratePOPDFOptions {
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
  organizationName?: string;
}

function fmtCurrency(v: number, currency: string): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

export function generatePurchaseOrderPDF(
  po: POPDFData,
  vendor: POPDFVendor | null,
  lines: POPDFLine[],
  opts: GeneratePOPDFOptions = {}
): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 12;
  const marginTop = 14;
  const usableWidth = pageWidth - marginX * 2;
  const cur = po.currency || 'USD';
  let yPos = marginTop;

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

  const headerRightX = pageWidth - marginX;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('PURCHASE ORDER', headerRightX, yPos, { align: 'right' });
  doc.setFontSize(14);
  doc.text(po.po_number, headerRightX, yPos + 6, { align: 'right' });

  yPos += logoSlotH;

  const lineH = 4;
  const gap = 2.5;

  // Left: Vendor Info
  let leftY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Vendor', marginX, leftY);
  leftY += lineH + gap;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');

  if (vendor) {
    doc.setFont('helvetica', 'bold');
    doc.text(vendor.name, marginX, leftY);
    doc.setFont('helvetica', 'normal');
    leftY += lineH + gap;
    if (vendor.address) {
      const addrLines = doc.splitTextToSize(vendor.address, usableWidth / 2 - 10);
      addrLines.forEach((line: string) => {
        doc.text(line, marginX, leftY);
        leftY += lineH + 1;
      });
      leftY += gap;
    }
    if (vendor.email) {
      doc.text(vendor.email, marginX, leftY);
      leftY += lineH + gap;
    }
    if (vendor.phone) {
      doc.text(vendor.phone, marginX, leftY);
      leftY += lineH + gap;
    }
    if (vendor.payment_terms) {
      doc.text(`Payment Terms: ${vendor.payment_terms}`, marginX, leftY);
      leftY += lineH + gap;
    }
    if (vendor.delivery_terms) {
      doc.text(`Delivery Terms: ${vendor.delivery_terms}`, marginX, leftY);
      leftY += lineH + gap;
    }
  } else {
    doc.text('N/A', marginX, leftY);
    leftY += lineH + gap;
  }

  // Right: PO details (anchored to right margin under PO number)
  const rightLabelX = pageWidth - marginX - 58;
  const rightValueX = pageWidth - marginX;
  let rightY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('PO Details', rightLabelX, rightY);
  rightY += lineH + gap;
  doc.setFontSize(9);

  const detailItems = [
    { label: 'Status', value: po.status.charAt(0).toUpperCase() + po.status.slice(1).toLowerCase() },
    ...(po.expected_date ? [{ label: 'Expected Date', value: formatDate(po.expected_date) }] : []),
    { label: 'Currency', value: po.currency },
    ...(po.allocation_summary ? [{ label: 'Allocation', value: po.allocation_summary }] : []),
    ...(po.ship_to_address ? [{ label: 'Ship To', value: po.ship_to_address }] : []),
  ];

  for (const item of detailItems) {
    if (item.label === 'Allocation' || item.label === 'Ship To') {
      doc.setFont('helvetica', 'bold');
      doc.text(`${item.label}:`, rightLabelX, rightY);
      rightY += lineH + 1;
      doc.setFont('helvetica', 'normal');
      const allocationLines = doc.splitTextToSize(item.value, pageWidth - marginX - rightLabelX);
      allocationLines.forEach((line: string) => {
        doc.text(line, rightLabelX, rightY);
        rightY += lineH + 1;
      });
      rightY += gap;
      continue;
    }
    doc.setFont('helvetica', 'bold');
    doc.text(`${item.label}:`, rightLabelX, rightY);
    doc.setFont('helvetica', 'normal');
    doc.text(item.value, rightValueX, rightY, { align: 'right' });
    rightY += lineH + gap;
  }

  yPos = Math.max(leftY, rightY) + 4;

  doc.setDrawColor(200, 200, 200);
  doc.setLineWidth(0.3);
  doc.line(marginX, yPos, pageWidth - marginX, yPos);
  yPos += 4;

  const tableColumns = [
    { header: '#', dataKey: 'num' },
    { header: 'SKU', dataKey: 'sku' },
    { header: 'Description', dataKey: 'description' },
    { header: 'Qty', dataKey: 'qty' },
    { header: 'Unit', dataKey: 'unit' },
    { header: 'Unit Cost', dataKey: 'unit_cost' },
    { header: 'Total', dataKey: 'total' },
  ];

  const tableRows = lines.map((l, i) => ({
    num: String(i + 1),
    sku: l.sku || '—',
    description: l.description || '—',
    qty: String(l.qty),
    unit: l.unit || 'ea',
    unit_cost: fmtCurrency(l.unit_cost, cur),
    total: fmtCurrency(l.line_total, cur),
  }));

  autoTable(doc, {
    startY: yPos,
    head: [tableColumns.map(c => c.header)],
    body: tableRows.map(r => tableColumns.map(c => (r as Record<string, string>)[c.dataKey])),
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
      if (hookData.section === 'head' && [0, 3, 4, 5, 6].includes(hookData.column.index)) {
        hookData.cell.styles.halign = 'left';
        const left =
          hookData.column.index === 0 ? 4 :
          hookData.column.index === 3 ? 5 :
          hookData.column.index === 4 ? 4 :
          hookData.column.index === 6 ? 14.5 : 7;
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left };
      }
      if (hookData.section === 'body' && hookData.column.index === 6) {
        hookData.cell.styles.halign = 'left';
        hookData.cell.styles.cellPadding = { top: 2, right: 2, bottom: 2, left: 11.5 };
      }
    },
    columnStyles: {
      0: { cellWidth: 10, halign: 'center' },
      1: { cellWidth: 35 },
      2: { cellWidth: 'auto' },
      3: { cellWidth: 15, halign: 'center' },
      4: { cellWidth: 14, halign: 'center' },
      5: { cellWidth: 25, halign: 'center' },
      6: { cellWidth: 25, halign: 'center' },
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

  const summaryX = pageWidth - marginX - 56;
  const summaryValueX = pageWidth - marginX - 3;
  const summaryItems = [
    { label: 'Subtotal', value: fmtCurrency(po.subtotal, cur), bold: false },
    { label: 'Total', value: fmtCurrency(po.total, cur), bold: true },
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

  if (po.notes) {
    yPos += 6;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text('Notes', marginX, yPos);
    yPos += lineH + gap;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const noteLines = doc.splitTextToSize(po.notes, usableWidth);
    noteLines.forEach((line: string) => {
      doc.text(line, marginX, yPos);
      yPos += 3.5;
    });
  }

  return doc;
}
