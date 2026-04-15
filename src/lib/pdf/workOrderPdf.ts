import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export interface WorkOrderPDFData {
  moNumber: string;
  stationName: string;
  stationCode: string;
  customerName: string;
  productName: string;
  salesOrderNo?: string;
  date: string;
  lines: {
    sku: string;
    description: string;
    role: string;
    qty: number;
    uom: string;
    cutLength: number | null;
    cutWidth: number | null;
  }[];
  isServiceMO?: boolean;
  claimNo?: string;
  moType?: string;
  productSpecs?: {
    widthMm?: number;
    heightMm?: number;
    openingDirection?: string;
    operatingSystem?: string;
    productLine?: string;
    panelCount?: number;
  };
}

export function generateWorkOrderPDF(data: WorkOrderPDFData): jsPDF {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const mx = 14;
  let y = 14;
  const isService = !!data.isServiceMO;

  // ── Header row: company left, doc type + date right ──
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(120);
  doc.text('ARQUIPRODUCTOS', mx, y);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.text(data.date, pageWidth - mx, y, { align: 'right' });
  doc.setTextColor(0);

  y += 6;

  // ── Title row: MO number + station ──
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(14);
  doc.text(data.moNumber, mx, y);

  const subtitle = isService
    ? `${data.stationName.toUpperCase()}  ·  ${data.moType === 'rework' ? 'SERVICE REWORK' : 'REPLACEMENT'}`
    : data.stationName.toUpperCase();
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(100);
  doc.text(subtitle, pageWidth - mx, y, { align: 'right' });
  doc.setTextColor(0);

  y += 4;

  // ── Divider ──
  doc.setDrawColor(200);
  doc.setLineWidth(0.3);
  doc.line(mx, y, pageWidth - mx, y);
  y += 6;

  // ── Info block: two columns ──
  doc.setFontSize(8);
  const leftInfo: [string, string][] = [];
  if (isService && data.claimNo) leftInfo.push(['Claim', data.claimNo]);
  leftInfo.push(['Customer', data.customerName]);
  leftInfo.push(['Product', data.productName]);
  if (data.salesOrderNo) leftInfo.push([isService ? 'Orig. SO' : 'SO', data.salesOrderNo]);

  const specs = data.productSpecs;
  const specLines: [string, string][] = [];
  if (specs) {
    if (specs.widthMm && specs.heightMm) specLines.push(['Size', `${specs.widthMm} × ${specs.heightMm} mm`]);
    if (specs.openingDirection) specLines.push(['Opening', specs.openingDirection.charAt(0).toUpperCase() + specs.openingDirection.slice(1)]);
    if (specs.operatingSystem) specLines.push(['System', specs.operatingSystem.charAt(0).toUpperCase() + specs.operatingSystem.slice(1)]);
    if (specs.panelCount && specs.panelCount > 1) specLines.push(['Stacks', String(specs.panelCount)]);
    if (specs.productLine) specLines.push(['Line', specs.productLine.replace(/_/g, ' ')]);
  }

  const maxRows = Math.max(leftInfo.length, specLines.length);
  const colRight = pageWidth / 2 + 10;
  const labelW = 22;

  for (let i = 0; i < maxRows; i++) {
    if (i < leftInfo.length) {
      const [label, value] = leftInfo[i];
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100);
      doc.text(`${label}:`, mx, y);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(40);
      doc.text(value, mx + labelW, y);
    }
    if (i < specLines.length) {
      const [label, value] = specLines[i];
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(100);
      doc.text(`${label}:`, colRight, y);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(40);
      doc.text(value, colRight + labelW, y);
    }
    y += 4.5;
  }
  doc.setTextColor(0);

  y += 4;

  // ── Materials table ──
  autoTable(doc, {
    startY: y,
    margin: { left: mx, right: mx },
    head: [['#', 'SKU', 'Description', 'Role', 'Qty', 'UOM', 'Cut X (mm)', 'Cut Y (mm)']],
    body: data.lines.map((l, i) => [
      i + 1,
      l.sku || '—',
      l.description || '—',
      l.role || '',
      l.qty,
      l.uom,
      l.cutLength != null ? Math.round(l.cutLength) : '—',
      l.cutWidth != null ? Math.round(l.cutWidth) : '—',
    ]),
    styles: { fontSize: 7.5, cellPadding: 2, textColor: [40, 40, 40], lineColor: [210, 210, 210], lineWidth: 0.2 },
    headStyles: { fillColor: [255, 255, 255], textColor: [30, 30, 30], fontStyle: 'bold', fontSize: 7.5 },
    alternateRowStyles: { fillColor: [250, 250, 250] },
    columnStyles: {
      0: { cellWidth: 9, halign: 'center' },
      4: { halign: 'right' },
      6: { halign: 'right' },
      7: { halign: 'right' },
    },
  });

  const finalY = (doc as any).lastAutoTable?.finalY ?? y + 20;

  // ── Sign-off ──
  const signatureY = finalY + 16;
  doc.setDrawColor(180);

  doc.line(mx, signatureY, mx + 50, signatureY);
  doc.setFontSize(7.5);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100);
  doc.text('Operator', mx, signatureY + 4);

  const midX = pageWidth / 2 - 25;
  doc.line(midX, signatureY, midX + 50, signatureY);
  doc.text('QC', midX, signatureY + 4);

  doc.line(pageWidth - mx - 50, signatureY, pageWidth - mx, signatureY);
  doc.text('Date / Time', pageWidth - mx - 50, signatureY + 4);
  doc.setTextColor(0);

  // ── Footer ──
  doc.setFontSize(6.5);
  doc.setTextColor(160);
  doc.text(`${data.moNumber}  ·  ${data.stationName}`, mx, pageHeight - 6);
  if (isService && data.claimNo) {
    doc.text(data.claimNo, pageWidth / 2, pageHeight - 6, { align: 'center' });
  }
  doc.text('1 / 1', pageWidth - mx, pageHeight - 6, { align: 'right' });
  doc.setTextColor(0);

  return doc;
}
