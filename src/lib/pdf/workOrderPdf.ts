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
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const mx = 12;
  let y = 14;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.text('WORK ORDER', mx, y);
  doc.setFontSize(11);
  doc.text(data.stationName.toUpperCase(), pageWidth - mx, y, { align: 'right' });

  y += 8;
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text(data.moNumber, mx, y);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  doc.text(data.stationCode, mx + doc.getTextWidth(data.moNumber + '  '), y);
  doc.text(data.date, pageWidth - mx, y, { align: 'right' });

  y += 10;
  doc.setFontSize(9);
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

  y += 4;

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
    styles: { fontSize: 8, cellPadding: 2 },
    headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 8 },
    alternateRowStyles: { fillColor: [249, 250, 251] },
    columnStyles: {
      0: { cellWidth: 8, halign: 'center' },
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

  return doc;
}
