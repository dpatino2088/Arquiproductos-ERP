/**
 * Generate Quote PDF
 * Creates a PDF document similar to the Claroscuro quote format
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

interface QuoteLine {
  id: string;
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  qty: number;
  line_total: number;
  CatalogItems?: {
    item_name?: string;
    sku?: string;
  } | null;
}

interface Quote {
  quote_no: string;
  customer_id: string;
  status: string;
  currency: string;
  notes?: string | null;
  totals: {
    subtotal: number;
    tax_total: number;
    total: number;
  };
  created_at: string;
}

interface Customer {
  customer_name: string;
}

interface Contact {
  contact_name?: string;
}

export function generateQuotePDF(
  quote: Quote,
  customer: Customer | null,
  contact: Contact | null,
  lines: QuoteLine[],
  organizationName: string = 'Arquiproductos'
) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const margin = 20;
  let yPos = margin;

  // Colors
  const primaryColor = [0, 0, 0]; // Black
  const secondaryColor = [128, 128, 128]; // Gray

  // Header Section
  doc.setFontSize(24);
  doc.setFont('helvetica', 'bold');
  doc.text(organizationName.toUpperCase(), margin, yPos);
  yPos += 10;

  doc.setFontSize(16);
  doc.setFont('helvetica', 'normal');
  doc.text('PROPUESTA', margin, yPos);
  yPos += 8;

  // Quote Number
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text(quote.quote_no, pageWidth - margin - doc.getTextWidth(quote.quote_no), yPos - 8);

  // Quote Details
  yPos += 5;
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  
  const details = [
    { label: 'Cliente:', value: customer?.customer_name || 'N/A' },
    { label: 'Fecha:', value: new Date(quote.created_at).toLocaleDateString('es-PA', { year: 'numeric', month: '2-digit', day: '2-digit' }) },
    { label: 'Sitio:', value: customer?.customer_name || 'N/A' },
    { label: 'Validez:', value: '30 Días' },
    { label: 'Descripción:', value: `${quote.quote_no} - ${customer?.customer_name || 'Cotización'}` },
    { label: 'Vendedor:', value: 'Sistema' },
  ];

  details.forEach((detail, index) => {
    if (index % 2 === 0) {
      doc.text(`${detail.label} ${detail.value}`, margin, yPos);
    } else {
      doc.text(`${detail.label} ${detail.value}`, pageWidth / 2, yPos);
      yPos += 6;
    }
  });

  if (details.length % 2 === 1) {
    yPos += 6;
  }

  yPos += 5;

  // Table Data
  const tableData = lines.map((line, index) => {
    const area = line.area || 'N/A';
    const position = line.position || 'N/A';
    const description = [
      line.product_type || 'N/A',
      line.collection_name && line.variant_name 
        ? `${line.collection_name} - ${line.variant_name}`
        : line.collection_name || line.variant_name || '',
      line.drive_type === 'motor' ? 'Motorizada' : line.drive_type === 'manual' ? 'Manual' : '',
      line.width_m && line.height_m 
        ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)} mm`
        : '',
    ].filter(Boolean).join(' | ');

    return [
      area,
      String(index + 1),
      description || 'N/A',
      line.qty.toFixed(2),
      formatCurrency(line.line_total / line.qty, quote.currency),
      formatCurrency(line.line_total, quote.currency),
    ];
  });

  // Generate table
  autoTable(doc, {
    startY: yPos,
    head: [['Área', 'ID', 'Descripción', 'Cantidad', 'Precio Unit', 'Precio Total']],
    body: tableData,
    theme: 'striped',
    headStyles: {
      fillColor: [240, 240, 240],
      textColor: [0, 0, 0],
      fontStyle: 'bold',
      fontSize: 9,
    },
    bodyStyles: {
      fontSize: 8,
    },
    columnStyles: {
      0: { cellWidth: 30 },
      1: { cellWidth: 15 },
      2: { cellWidth: 70 },
      3: { cellWidth: 20, halign: 'right' },
      4: { cellWidth: 25, halign: 'right' },
      5: { cellWidth: 25, halign: 'right' },
    },
    margin: { left: margin, right: margin },
  });

  // Get final Y position after table
  const finalY = (doc as any).lastAutoTable.finalY || yPos + 50;
  yPos = finalY + 10;

  // Summary Section
  const productsTotal = lines.reduce((sum, line) => sum + line.line_total, 0);
  const discount = 0; // TODO: Get from quote if available
  const labor = 0; // TODO: Get from quote if available
  const shipping = 0; // TODO: Get from quote if available
  const subtotal = quote.totals.subtotal || productsTotal;
  const tax = quote.totals.tax_total || 0;
  const total = quote.totals.total || subtotal + tax;

  const summaryData = [
    ['Productos:', formatCurrency(productsTotal, quote.currency)],
    ['Descuento:', formatCurrency(-discount, quote.currency)],
    ['Mano de Obra:', formatCurrency(labor, quote.currency)],
    ['Flete:', formatCurrency(shipping, quote.currency)],
    ['SubTotal:', formatCurrency(subtotal, quote.currency)],
    ['ITBMS:', formatCurrency(tax, quote.currency)],
    ['Gran Total:', formatCurrency(total, quote.currency)],
  ];

  // Summary table
  autoTable(doc, {
    startY: yPos,
    body: summaryData,
    theme: 'plain',
    bodyStyles: {
      fontSize: 9,
    },
    columnStyles: {
      0: { cellWidth: 50, fontStyle: 'bold' },
      1: { cellWidth: 50, halign: 'right', fontStyle: 'bold' },
    },
    margin: { left: pageWidth - 120, right: margin },
  });

  // Check if we need a new page for terms
  const termsY = (doc as any).lastAutoTable.finalY || yPos + 50;
  if (termsY > pageHeight - 80) {
    doc.addPage();
    yPos = margin;
  } else {
    yPos = termsY + 15;
  }

  // Terms and Conditions (simplified)
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text('Términos y Condiciones Generales', margin, yPos);
  yPos += 8;

  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  const terms = [
    `• Cualquier contrato, pago o cheque debe ser emitido a nombre de: ${organizationName.toUpperCase()}`,
    '• La presente propuesta de venta es válida por treinta (30) días hábiles desde su fecha de emisión.',
    '• Se requerirá un abono del sesenta por ciento (60%) del precio de venta total para confirmar el pedido.',
    '• El saldo restante deberá ser pagado contra la entrega de los productos.',
    '• Los tiempos de entrega podrán variar dependiendo del producto.',
  ];

  terms.forEach((term) => {
    const lines = doc.splitTextToSize(term, pageWidth - 2 * margin);
    lines.forEach((line: string) => {
      if (yPos > pageHeight - 30) {
        doc.addPage();
        yPos = margin;
      }
      doc.text(line, margin, yPos);
      yPos += 5;
    });
    yPos += 2;
  });

  // Footer
  const pageCount = (doc as any).internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    doc.text(
      `${i} / ${pageCount}`,
      pageWidth / 2,
      pageHeight - 10,
      { align: 'center' }
    );
  }

  return doc;
}

function formatCurrency(amount: number, currency: string = 'USD'): string {
  return new Intl.NumberFormat('es-PA', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

