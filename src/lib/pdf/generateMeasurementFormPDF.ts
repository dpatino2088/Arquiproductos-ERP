/**
 * Measurement Verification Form PDF — Landscape A4
 * Printable worksheet for field verification of quoted dimensions.
 * Columns: #, Area, Position, Product Type, Description, Quoted (W x H), Verified (blank), Notes
 * Footer: general notes area, verified-by, signature, date.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatDimensionsForProposalPDF, type DimensionsSource } from '../formatDimensions';

export interface MeasurementFormLine {
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  qty: number;
  width_m?: number | null;
  height_m?: number | null;
  dimensions_source?: DimensionsSource | null;
  drive_type?: string | null;
  drive_side?: string | null;
  opening_direction?: string | null;
  installation_type?: string | null;
  installation_location?: string | null;
}

export interface MeasurementFormOptions {
  quote_no: string;
  customer_name?: string | null;
  contact_name?: string | null;
  address?: string | null;
  project_description?: string | null;
  created_at?: string | null;
  logoPngBase64?: string;
  logoWidthPx?: number;
  logoHeightPx?: number;
  dealerName?: string;
}

function fmtDate(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
}

export function generateMeasurementFormPDF(
  lines: MeasurementFormLine[],
  options: MeasurementFormOptions
): jsPDF {
  const doc = new jsPDF({ orientation: 'l', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const mx = 12;
  const mt = 14;
  let y = mt;

  // ── Logo (top-left) ──
  if (options.logoPngBase64) {
    try {
      const slotW = 60;
      const slotH = 16;
      const pxToMm = 25.4 / 72;
      const wMm = (options.logoWidthPx ?? 100) * pxToMm;
      const hMm = (options.logoHeightPx ?? 100) * pxToMm;
      const scale = Math.min(slotW / wMm, slotH / hMm, 1);
      const fmt = options.logoPngBase64.startsWith('data:image/jpeg') ? 'JPEG' : 'PNG';
      doc.addImage(options.logoPngBase64, fmt, mx, y - 4, wMm * scale, hMm * scale);
    } catch { /* ignore */ }
  }

  // ── Title (top-right) ──
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('Measurement Verification Form', pageW - mx, y, { align: 'right' });
  y += 6;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(options.quote_no, pageW - mx, y, { align: 'right' });
  y += 13;

  // ── Info row ──
  const infoY = y;
  const col1X = mx;
  const col2X = mx + 100;
  const col3X = mx + 200;
  const lineH = 4.5;

  doc.setFontSize(8.5);
  const drawField = (label: string, value: string, x: number, row: number) => {
    const fieldY = infoY + row * lineH;
    doc.setFont('helvetica', 'bold');
    doc.text(label, x, fieldY);
    doc.setFont('helvetica', 'normal');
    doc.text(value, x + doc.getTextWidth(label) + 1.5, fieldY);
  };

  drawField('Customer: ', options.customer_name ?? '—', col1X, 0);
  drawField('Contact: ', options.contact_name ?? '—', col1X, 1);
  if (options.project_description) {
    drawField('Project: ', options.project_description, col1X, 2);
  }

  if (options.address) {
    const addrOneLine = options.address.replace(/\n/g, ', ');
    drawField('Project Address: ', addrOneLine, col2X, 0);
  }
  if (options.dealerName) {
    drawField('Dealer: ', options.dealerName, col2X, 1);
  }

  drawField('Date: ', fmtDate(options.created_at) || '___/___/______', col3X, 0);

  const infoRows = options.project_description ? 3 : 2;
  y = infoY + infoRows * lineH + 4;

  // ── Separator ──
  doc.setDrawColor(200);
  doc.setLineWidth(0.3);
  doc.line(mx, y, pageW - mx, y);
  y += 4;

  // ── Table ──
  const cap = (s: string | null | undefined) =>
    s ? s.charAt(0).toUpperCase() + s.slice(1) : '';

  const tableBody = lines.map((line, idx) => {
    const dims = line.dimensions_source
      ? formatDimensionsForProposalPDF(line.dimensions_source)
      : (line.width_m != null && line.height_m != null)
        ? `${Math.round(line.width_m * 1000)} x ${Math.round(line.height_m * 1000)}`
        : '—';

    const desc = [line.collection_name, line.variant_name].filter(Boolean).join(' - ') || '—';

    const driveLabel = line.drive_type === 'motor' ? 'Motorized' : line.drive_type === 'manual' ? 'Manual' : cap(line.drive_type);
    const driveSideLabel = cap(line.drive_side);
    const openingLabel = cap(line.opening_direction);
    const installParts = [cap(line.installation_type), cap(line.installation_location)].filter(Boolean);
    const configLines = [
      driveLabel ? `Drive: ${driveLabel}` : '',
      driveSideLabel ? `Side: ${driveSideLabel}` : '',
      openingLabel ? `Opening: ${openingLabel}` : '',
      installParts.length ? `Install: ${installParts.join(' / ')}` : '',
    ].filter(Boolean).join('\n') || '—';

    return [
      String(idx + 1),
      line.area ?? '—',
      line.position ?? '—',
      line.product_type ?? '—',
      desc,
      configLines,
      String(line.qty),
      dims,
      '',
      '',
    ];
  });

  autoTable(doc, {
    startY: y,
    margin: { left: mx, right: mx },
    rowPageBreak: 'avoid',
    head: [[
      '#',
      'Area',
      'Position',
      'Product Type',
      'Description',
      'Configuration',
      'Qty',
      'Quoted (W x H)',
      'Verified (W x H)',
      'Notes',
    ]],
    body: tableBody,
    theme: 'grid',
    styles: {
      fontSize: 7.5,
      cellPadding: { top: 2.5, bottom: 2.5, left: 1.5, right: 1.5 },
      lineColor: [180, 180, 180],
      lineWidth: 0.25,
      textColor: [50, 50, 50],
      valign: 'middle',
    },
    headStyles: {
      fillColor: [240, 240, 240],
      textColor: [40, 40, 40],
      fontStyle: 'bold',
      fontSize: 7,
      halign: 'center',
    },
    columnStyles: {
      0: { halign: 'center', cellWidth: 8 },
      1: { cellWidth: 24 },
      2: { halign: 'center', cellWidth: 18 },
      3: { cellWidth: 22 },
      4: { cellWidth: 40 },
      5: { cellWidth: 38, fontSize: 6.5 },
      6: { halign: 'center', cellWidth: 10 },
      7: { halign: 'left', cellWidth: 30, cellPadding: { top: 2.5, bottom: 2.5, left: 7, right: 1.5 } },
      8: { halign: 'center', cellWidth: 44 },
      9: { cellWidth: 'auto' },
    },
    didDrawCell: (data) => {
      if (data.section === 'body' && data.column.index === 8) {
        const cell = data.cell;
        const txt = '____________ x ____________';
        doc.setFontSize(7.5);
        doc.setFont('helvetica', 'normal');
        doc.setTextColor(160, 160, 160);
        const txtW = doc.getTextWidth(txt);
        doc.text(txt, cell.x + (cell.width - txtW) / 2, cell.y + cell.height - 4);
        doc.setTextColor(50, 50, 50);
      }
    },
  });

  // ── Footer: Notes, Signature ──
  const finalY = (doc as any).lastAutoTable?.finalY ?? y + 40;
  let footerY = finalY + 8;

  if (footerY > pageH - 45) {
    doc.addPage();
    footerY = mt;
  }

  doc.setFontSize(8.5);
  doc.setFont('helvetica', 'bold');
  doc.text('Notes:', mx, footerY);
  footerY += 2;

  doc.setDrawColor(180);
  doc.setLineWidth(0.2);
  for (let i = 0; i < 4; i++) {
    footerY += 6;
    doc.line(mx, footerY, pageW - mx, footerY);
  }

  footerY += 12;

  const sigColW = (pageW - mx * 2) / 3;
  const drawSigField = (label: string, colIdx: number) => {
    const x = mx + colIdx * sigColW;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text(label, x, footerY);
    doc.setDrawColor(120);
    doc.line(x + doc.getTextWidth(label) + 3, footerY, x + sigColW - 10, footerY);
  };

  drawSigField('Verified by:', 0);
  drawSigField('Signature:', 1);
  drawSigField('Date:', 2);

  return doc;
}
