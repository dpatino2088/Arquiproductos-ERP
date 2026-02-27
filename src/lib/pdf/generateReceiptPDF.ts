import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export interface ReceiptPDFHeader {
  receipt_no: string;
  movement_date: string;
  po_number: string;
  vendor_name: string | null;
  warehouse_name: string | null;
}

export interface ReceiptPDFLine {
  sku: string;
  description: string;
  qty: number;
  unit: string;
}

export function generateReceiptPDF(header: ReceiptPDFHeader, lines: ReceiptPDFLine[]): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 12;
  let y = 16;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('RECEIPT', pageWidth - marginX, y, { align: 'right' });
  doc.setFontSize(14);
  doc.text(header.receipt_no || 'DRAFT', pageWidth - marginX, y + 6, { align: 'right' });

  y += 18;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('Receipt Details', marginX, y);
  y += 6;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  const details = [
    ['Date', new Date(header.movement_date).toLocaleDateString()],
    ['PO #', header.po_number || '—'],
    ['Vendor', header.vendor_name || '—'],
    ['Warehouse', header.warehouse_name || '—'],
  ];

  details.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold');
    doc.text(`${label}:`, marginX, y);
    doc.setFont('helvetica', 'normal');
    doc.text(String(value), marginX + 22, y);
    y += 5;
  });

  y += 3;

  autoTable(doc, {
    startY: y,
    margin: { left: marginX, right: marginX },
    head: [['#', 'SKU', 'Description', 'Qty', 'Unit']],
    body: lines.map((line, index) => [
      String(index + 1),
      line.sku || '—',
      line.description || '—',
      Number(line.qty).toFixed(2),
      line.unit || 'ea',
    ]),
    styles: { fontSize: 8, cellPadding: 2 },
    headStyles: { fillColor: [245, 245, 245], textColor: [60, 60, 60], fontStyle: 'bold' },
    columnStyles: {
      0: { cellWidth: 10, halign: 'center' },
      1: { cellWidth: 26 },
      2: { cellWidth: 'auto' },
      3: { cellWidth: 20, halign: 'right' },
      4: { cellWidth: 16, halign: 'center' },
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
