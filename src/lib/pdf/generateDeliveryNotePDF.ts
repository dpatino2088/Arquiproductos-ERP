/**
 * Generate Delivery Note PDF
 * Layout mirrors Quote PDF: logo top-left, title + number top-right,
 * left block (delivery info), right box (Project Detail style),
 * table matching Quote columns (#, Area, Position, Description, Qty, Status).
 * Signature area at the bottom.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export interface DeliveryNotePDFLine {
  product_name: string;
  area: string | null;
  position: string | null;
  measurements: string | null;
  product_type: string | null;
  qty: number;
  checked: boolean;
}

export interface DeliveryNotePDFData {
  delivery_number: string;
  status: 'completed' | 'partial' | 'pending';
  mo_number: string | null;
  so_number: string | null;
  claim_no: string | null;
  claim_detail: string | null;
  delivered_by: string | null;
  received_by: string | null;
  notes: string | null;
  completed_at: string | null;
  created_at: string;
  checked_count: number;
  total_count: number;
  customer_name: string | null;
  contact_name: string | null;
}

export interface DeliveryNotePDFOptions {
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
  organizationName?: string;
}

function fmtDateTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  return `${day}/${month}/${year}, ${h}:${m}`;
}

export function generateDeliveryNotePDF(
  data: DeliveryNotePDFData,
  lines: DeliveryNotePDFLine[],
  opts: DeliveryNotePDFOptions = {},
): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const marginX = 12;
  const marginTop = 14;
  const marginBottom = 14;
  const usableWidth = pageWidth - marginX * 2;
  const lineH = 4;
  const gap = 2.5;
  let yPos = marginTop;

  // ── Logo / Org name (same as Quote) ──
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
      const fmt = opts.logoPngBase64.startsWith('data:image/jpeg') ? 'JPEG' : 'PNG';
      doc.addImage(opts.logoPngBase64, fmt, marginX, imgY, drawW, drawH);
      logoDrawn = true;
    } catch { /* ignore */ }
  }
  if (!logoDrawn) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text(opts.organizationName ?? 'Arquiproductos', marginX, marginTop + 6);
  }

  // ── Header right: "Delivery Note" + number + badge + details ──
  const headerRightX = pageWidth - marginX;
  const headerLineStep = 5;
  let headerY = yPos;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('Delivery Note', headerRightX, headerY + 2, { align: 'right' });
  headerY += 7;
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text(data.delivery_number, headerRightX, headerY + 2, { align: 'right' });
  headerY += headerLineStep + 5;

  // Status badge inline
  const statusLabel = data.status === 'completed' ? 'COMPLETE' : data.status === 'partial' ? 'PARTIAL' : 'PENDING';
  const badgeColor: [number, number, number] = data.status === 'completed' ? [34, 139, 34] : data.status === 'partial' ? [200, 140, 20] : [150, 150, 150];
  doc.setFontSize(8);
  doc.setFont('helvetica', 'bold');
  const badgeW = doc.getTextWidth(statusLabel) + 6;
  const badgeX = headerRightX - badgeW;
  doc.setFillColor(...badgeColor);
  doc.roundedRect(badgeX, headerY - 3.6, badgeW, 5, 1, 1, 'F');
  doc.setTextColor(255, 255, 255);
  doc.text(statusLabel, badgeX + 3, headerY);
  doc.setTextColor(0, 0, 0);
  headerY += headerLineStep + 2;

  const drawHeaderRow = (label: string, value: string) => {
    doc.setFontSize(9);
    doc.setFont('helvetica', 'normal');
    const valueW = doc.getTextWidth(value);
    doc.text(value, headerRightX, headerY, { align: 'right' });
    doc.setFont('helvetica', 'bold');
    doc.text(label, headerRightX - valueW, headerY, { align: 'right' });
    headerY += headerLineStep;
  };

  const dateStr = fmtDateTime(data.completed_at ?? data.created_at);
  drawHeaderRow('Date: ', dateStr);
  drawHeaderRow('Lines: ', `${data.checked_count} / ${data.total_count} delivered`);

  yPos += logoDrawn ? logoSlotH : 14;

  // ── Left block: Delivery details ──
  const spacingMm = (7 / 72) * 25.4;
  const interlineMm = (5 / 72) * 25.4;

  let leftY = yPos;
  doc.setFontSize(9);

  const drawLeftRow = (label: string, value: string) => {
    doc.setFont('helvetica', 'bold');
    doc.text(label, marginX, leftY);
    doc.setFont('helvetica', 'normal');
    const labelW = doc.getTextWidth(label + ' ');
    doc.text(value, marginX + labelW + spacingMm, leftY);
    leftY += lineH + interlineMm;
  };

  if (data.claim_no) {
    drawLeftRow('Order:', data.claim_no);
    if (data.so_number) drawLeftRow('Original SO:', data.so_number);
  } else if (data.so_number) {
    drawLeftRow('Order:', data.so_number);
  }
  drawLeftRow('Delivered by:', data.delivered_by ?? '—');
  drawLeftRow('Received by:', data.received_by ?? '—');

  if (data.notes && data.notes.trim()) {
    leftY += 2;
    doc.setFont('helvetica', 'bold');
    doc.text('Notes:', marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const noteLabelW = doc.getTextWidth('Notes: ');
    const noteLines = doc.splitTextToSize(data.notes.trim(), usableWidth / 2 - noteLabelW - spacingMm);
    const noteX = marginX + noteLabelW + spacingMm;
    noteLines.forEach((line: string) => {
      doc.text(line, noteX, leftY);
      leftY += lineH;
    });
    doc.setFontSize(9);
  }

  const leftBlockEndY = leftY;

  // ── Right box: Project Detail (same style as Quote) ──
  const boxLeft = marginX + usableWidth / 2 - 3;
  const boxWidth = usableWidth / 2 + 3;
  const boxTopY = yPos + 17;
  const boxRowH = 6;
  const boxLabelX = boxLeft + 3;
  const boxValueX = boxLeft + 28;
  const boxHeight = boxRowH * 3 + 8;
  const boxRadiusMm = 2;
  doc.setDrawColor(140, 140, 140);
  doc.setLineWidth(0.25);
  doc.roundedRect(boxLeft, boxTopY, boxWidth, boxHeight, boxRadiusMm, boxRadiusMm, 'S');
  doc.setDrawColor(0, 0, 0);

  let boxY = boxTopY + 7;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(120, 120, 120);
  doc.text('Project Detail', boxLabelX, boxY);
  doc.setTextColor(0, 0, 0);
  boxY += boxRowH;
  doc.setFont('helvetica', 'bold');
  doc.text('Customer :', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  doc.text(data.customer_name ?? '—', boxValueX, boxY);
  boxY += boxRowH;
  doc.setFont('helvetica', 'bold');
  doc.text('Contact :', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  doc.text(data.contact_name ?? '—', boxValueX, boxY);

  const rightBlockEndY = Math.max(leftBlockEndY, boxTopY + boxHeight);
  yPos = rightBlockEndY + 8;

  // ── Lines table (Quote-style widths: #, Area, Position, Description, Measurements, Product type, Qty, Status) ──
  const W = { n: 7, area: 16, pos: 18, desc: 0, meas: 26, ptype: 27, qty: 12, status: 20 };
  W.desc = usableWidth - W.n - W.area - W.pos - W.meas - W.ptype - W.qty - W.status;

  const tableData = lines.map((l, i) => [
    String(i + 1),
    l.area ?? '—',
    l.position ?? '—',
    l.product_name,
    l.measurements ?? '—',
    l.product_type ?? '—',
    String(l.qty),
    l.checked ? 'Delivered' : 'Pending',
  ]);

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'Area', 'Position', 'Description', 'Measurements', 'Product type', 'Qty', 'Status']],
    body: tableData,
    theme: 'plain',
    margin: { left: marginX, right: marginX },
    rowPageBreak: 'avoid',
    styles: {
      font: 'helvetica',
      fontSize: 8,
      overflow: 'linebreak',
      cellPadding: { top: 3, bottom: 3, left: 2, right: 2 },
    },
    headStyles: {
      fillColor: [245, 245, 245],
      textColor: [60, 60, 60],
      fontStyle: 'bold',
      fontSize: 8,
      overflow: 'linebreak',
      cellPadding: { top: 2, bottom: 2, left: 2, right: 2 },
    },
    bodyStyles: {
      fontSize: 8,
      textColor: [30, 30, 30],
      minCellHeight: 20,
      valign: 'middle',
    },
    columnStyles: {
      0: { cellWidth: W.n, halign: 'center', valign: 'middle', overflow: 'visible' },
      1: { cellWidth: W.area, halign: 'left', valign: 'middle' },
      2: { cellWidth: W.pos, halign: 'center', valign: 'middle' },
      3: {
        cellWidth: W.desc, halign: 'left', valign: 'middle', overflow: 'linebreak',
        fontSize: 8, cellPadding: { top: 4, bottom: 4, left: 4, right: 4 }, minCellHeight: 20,
      },
      4: {
        cellWidth: W.meas, halign: 'left', valign: 'middle', overflow: 'linebreak',
        fontSize: 8, cellPadding: { top: 3, bottom: 3, left: 4, right: 2 }, minCellHeight: 20,
      },
      5: { cellWidth: W.ptype, halign: 'center', valign: 'middle' },
      6: { cellWidth: W.qty, halign: 'center', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 2, right: 2 } },
      7: { cellWidth: W.status, halign: 'center', valign: 'middle' },
    },
    didParseCell: (hookData) => {
      if (hookData.section === 'head') {
        hookData.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        hookData.cell.styles.overflow = 'visible';
        if (hookData.column.index === 3) hookData.cell.styles.cellPadding = { top: 2, bottom: 2, left: 4, right: 2 };
        if (hookData.column.index === 2) hookData.cell.styles.halign = 'center';
        if (hookData.column.index === 4) { hookData.cell.styles.halign = 'center'; hookData.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 }; }
        if (hookData.column.index === 5) hookData.cell.styles.cellPadding = { top: 2, bottom: 2, left: 5, right: 0 };
        if (hookData.column.index === 6) { hookData.cell.styles.halign = 'center'; hookData.cell.styles.cellPadding = { top: 2, bottom: 2, left: 0, right: 2 }; }
        if (hookData.column.index === 7) hookData.cell.styles.halign = 'center';
      }
      if (hookData.section === 'body' && hookData.column.index === 7) {
        const val = hookData.cell.raw as string;
        if (val === 'Delivered') {
          hookData.cell.styles.textColor = [34, 139, 34];
          hookData.cell.styles.fontStyle = 'bold';
        } else {
          hookData.cell.styles.textColor = [200, 60, 60];
        }
      }
      if (hookData.section === 'body' && hookData.column.index === 3) {
        const raw = hookData.cell.raw;
        const text = typeof raw === 'string' ? raw : '';
        if (text.includes('\n')) {
          hookData.cell.text = text.split('\n');
        }
      }
    },
    didDrawCell: (hookData: any) => {
      if (hookData.section !== 'body') return;
      doc.setDrawColor(200, 200, 200);
      doc.setLineWidth(0.25);
      doc.line(hookData.cell.x, hookData.cell.y + hookData.cell.height,
        hookData.cell.x + hookData.cell.width, hookData.cell.y + hookData.cell.height);
    },
    didDrawPage: () => {
      const pageCount = (doc as any).internal.getNumberOfPages();
      const currentPage = (doc as any).internal.getCurrentPageInfo().pageNumber;
      doc.setFontSize(8);
      doc.setFont('helvetica', 'normal');
      doc.text(`${currentPage} / ${pageCount}`, pageWidth / 2, pageHeight - 8, { align: 'center' });
    },
  });

  yPos = (doc as any).lastAutoTable?.finalY ?? yPos + 40;

  // ── Service claim note (before signature) ──
  if (data.claim_detail) {
    yPos += 6;
    doc.setFontSize(8);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(100, 100, 100);
    doc.text('Note:', marginX, yPos);
    doc.setFont('helvetica', 'normal');
    const noteX = marginX + doc.getTextWidth('Note: ') + 1;
    const wrappedLines = doc.splitTextToSize(data.claim_detail, usableWidth - (noteX - marginX));
    wrappedLines.forEach((line: string) => {
      doc.text(line, noteX, yPos);
      yPos += 3.5;
    });
    doc.setTextColor(0, 0, 0);
    doc.setFontSize(9);
  }

  // ── Signature section ──
  const sigY = Math.max(yPos + 14, pageHeight - 60);

  doc.setDrawColor(150, 150, 150);
  doc.setLineWidth(0.3);

  const col1X = marginX;
  const col2X = pageWidth / 2 + 10;
  const sigLineW = usableWidth / 2 - 15;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text('Delivered by', col1X, sigY);
  doc.text('Received by', col2X, sigY);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  if (data.delivered_by) doc.text(data.delivered_by, col1X, sigY + 6);
  if (data.received_by) doc.text(data.received_by, col2X, sigY + 6);

  const sigLineY = sigY + 18;
  doc.line(col1X, sigLineY, col1X + sigLineW, sigLineY);
  doc.line(col2X, sigLineY, col2X + sigLineW, sigLineY);

  doc.setFontSize(7);
  doc.setTextColor(130, 130, 130);
  doc.text('Signature', col1X, sigLineY + 4);
  doc.text('Signature', col2X, sigLineY + 4);

  const dateLineY = sigLineY + 12;
  doc.line(col1X, dateLineY, col1X + sigLineW, dateLineY);
  doc.line(col2X, dateLineY, col2X + sigLineW, dateLineY);
  doc.text('Date', col1X, dateLineY + 4);
  doc.text('Date', col2X, dateLineY + 4);

  doc.setTextColor(0, 0, 0);

  return doc;
}
