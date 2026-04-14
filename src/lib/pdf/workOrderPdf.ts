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
}

export function generateWorkOrderPDF(data: WorkOrderPDFData): jsPDF {
  // Same visual style family used by Cut/Opticutter PDFs.
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const mx = 12;
  let y = 12;

  const logoSlotH = 14;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(14);
  doc.text('ARQUIPRODUCTOS', mx, y + 8);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text('WORK ORDER', pageWidth - mx, y + 4, { align: 'right' });
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(100);
  doc.text(data.stationName.toUpperCase(), pageWidth - mx, y + 9, { align: 'right' });
  doc.text(data.date, pageWidth - mx, y + 13, { align: 'right' });
  doc.setTextColor(0);

  y += logoSlotH + 4;
  doc.setDrawColor(180);
  doc.setLineWidth(0.4);
  doc.line(mx, y, pageWidth - mx, y);
  y += 5;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.text(data.moNumber, mx, y);
  if (data.stationCode) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    doc.setTextColor(100);
    doc.text(data.stationCode, mx + doc.getTextWidth(data.moNumber) + 3, y);
    doc.setTextColor(0);
  }

  y += 7;
  doc.setFontSize(8);
  const info: [string, string][] = [
    ['Customer', data.customerName],
    ['Product', data.productName],
  ];
  if (data.salesOrderNo) info.push(['SO #', data.salesOrderNo]);

  for (const [label, value] of info) {
    doc.setFont('helvetica', 'bold');
    doc.text(`${label}:`, mx, y);
    doc.setFont('helvetica', 'normal');
    doc.text(value, mx + 24, y);
    y += 5;
  }

  y += 3;

  autoTable(doc, {
    startY: y,
    margin: { left: mx, right: mx },
    head: [['#', 'SKU', 'Description', 'Role', 'Qty', 'UOM', 'Length X (mm)', 'Length Y (mm)']],
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
    styles: { fontSize: 7.5, cellPadding: 1.8 },
    headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 7.5 },
    alternateRowStyles: { fillColor: [249, 250, 251] },
    columnStyles: {
      0: { cellWidth: 9, halign: 'center' },
      4: { halign: 'right' },
      6: { halign: 'right' },
      7: { halign: 'right' },
    },
  });

  const finalY = (doc as any).lastAutoTable?.finalY ?? y + 20;
  const signatureY = finalY + 16;

  doc.setDrawColor(180);
  doc.line(mx, signatureY, mx + 60, signatureY);
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  doc.text('Operator Signature', mx, signatureY + 4);

  doc.line(pageWidth - mx - 60, signatureY, pageWidth - mx, signatureY);
  doc.text('Date / Time', pageWidth - mx - 60, signatureY + 4);

  doc.setFontSize(6.5);
  doc.setTextColor(150);
  doc.text(`Work Order — ${data.moNumber}`, mx, pageHeight - 6);
  doc.text('Page 1 of 1', pageWidth / 2, pageHeight - 6, { align: 'center' });
  doc.setTextColor(0);

  return doc;
}
