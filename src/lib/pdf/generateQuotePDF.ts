/**
 * Generate Quote PDF
 * Same header format as Proposal: logo top-right, company name, quote number,
 * Contact / Customer / Address | Date / Valid until / Seller. Table: #, AREA, POSITION, DESCRIPTION, QTY, UNIT, TOTAL.
 * Supports dealer (prices by tier) and client (MSRP + optional discount) variants.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export type PDFVariant = 'dealer' | 'client';

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
  contact_email?: string;
}

export interface GenerateQuotePDFOptions {
  variant: PDFVariant;
  /** Discount % (0–100) applied to subtotal for client version only */
  clientDiscountPct?: number;
  /** Dealer/org logo – data URL or base64 PNG, top-left */
  logoPngBase64?: string;
  /** Logo width in mm (preserve aspect ratio; if set, logoHeightMm should also be set) */
  logoWidthMm?: number;
  /** Logo height in mm (preserve aspect ratio) */
  logoHeightMm?: number;
  /** Dealer name below logo (left column) */
  dealerName?: string;
  /** Dealer full address below "Address:" (left column) */
  dealerAddress?: string;
  /** Created-by / seller name (left column, below dealer name) */
  sellerName?: string;
  /** Description text (right column, below Customer) */
  description?: string;
}

function formatCurrency(amount: number, currency: string = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function generateQuotePDF(
  quote: Quote,
  customer: Customer | null,
  contact: Contact | null,
  lines: QuoteLine[],
  organizationName: string = 'Arquiproductos',
  options: GenerateQuotePDFOptions = { variant: 'client' }
) {
  const { variant, clientDiscountPct = 0, logoPngBase64, logoWidthMm, logoHeightMm, dealerName, dealerAddress, sellerName, description } = options;
  const isDealer = variant === 'dealer';

  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const marginX = 12;
  const marginTop = 14;
  const marginBottom = 14;
  const usableWidth = pageWidth - marginX * 2;
  const valueX = pageWidth - marginX;
  const labelX = valueX - 58;
  let yPos = marginTop;

  // —— LEFT COLUMN: Logo (top-left), Dealer name, Created by, Address (dealer) ——
  const logoMaxMm = 18;
  const logoW = logoWidthMm ?? logoMaxMm;
  const logoH = logoHeightMm ?? logoMaxMm;
  const logoX = marginX;
  const logoY = marginTop;
  if (logoPngBase64) {
    try {
      const logoFormat = /data:image\/jpe?g/i.test(logoPngBase64) ? 'JPEG' : 'PNG';
      doc.addImage(logoPngBase64, logoFormat, logoX, logoY, logoW, logoH);
    } catch {
      // ignore invalid image
    }
  } else {
    doc.setDrawColor(200, 200, 200);
    doc.setLineWidth(0.2);
    doc.rect(logoX, logoY, logoW, logoH);
  }
  let leftY = logoY + logoH + 4;
  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.text(dealerName ?? organizationName, marginX, leftY);
  leftY += 5;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.text(`Created by: ${sellerName ?? 'System'}`, marginX, leftY);
  leftY += 5;
  doc.setFont('helvetica', 'bold');
  doc.text('Address:', marginX, leftY);
  doc.setFont('helvetica', 'normal');
  const addressStr = dealerAddress ?? '—';
  const addressLines = doc.splitTextToSize(addressStr, 55);
  addressLines.forEach((line: string, i: number) => {
    doc.text(line, marginX, leftY + 4 + i * 4);
  });
  const leftBlockEnd = leftY + 4 + addressLines.length * 4 + 6;

  // —— RIGHT COLUMN: Quote number (top right), Date, Valid, Contact, Customer, Description ——
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text(quote.quote_no, pageWidth - marginX, yPos, { align: 'right' });
  doc.setFontSize(12);
  doc.setFont('helvetica', 'normal');
  doc.text(isDealer ? 'PROPUESTA DEALER' : 'PROPUESTA CLIENTE', pageWidth - marginX, yPos + 6, { align: 'right' });
  let rightY = yPos + 14;
  const dateStr = new Date(quote.created_at).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
  const detailsRight: Array<{ label: string; value: string }> = [
    { label: 'Date:', value: dateStr },
    { label: 'Valid:', value: '30 days' },
    { label: 'Contact:', value: contact?.contact_name ?? contact?.contact_email ?? 'N/A' },
    { label: 'Customer:', value: customer?.customer_name ?? 'N/A' },
    { label: 'Description:', value: description ?? quote.notes ?? '—' },
  ];
  doc.setFontSize(9);
  const gapValidContactMm = 10; // 1 cm entre Valid y Contact
  detailsRight.forEach((row, index) => {
    if (index === 2) rightY += gapValidContactMm;
    doc.setFont('helvetica', 'bold');
    doc.text(row.label, labelX, rightY, { align: 'right' });
    doc.setFont('helvetica', 'normal');
    const valLines = doc.splitTextToSize(row.value, 52);
    valLines.forEach((line: string, i: number) => {
      doc.text(line, valueX, rightY + i * 4, { align: 'right' });
    });
    rightY += 4 + (valLines.length - 1) * 4 + 3;
  });
  const rightBlockEnd = rightY + 4;

  yPos = Math.max(leftBlockEnd, rightBlockEnd) + 6;

  // Table: same structure as Proposal (#, AREA, POSITION, DESCRIPTION / PRODUCT, QTY, BASE/UNIT PRICE, LINE TOTAL)
  const buildDescription = (line: QuoteLine): string => {
    const parts = [
      line.product_type ?? line.CatalogItems?.item_name ?? '—',
      line.collection_name && line.variant_name
        ? `${line.collection_name} - ${line.variant_name}`
        : line.collection_name ?? line.variant_name ?? '',
      line.drive_type === 'motor' ? 'Motorized' : line.drive_type === 'manual' ? 'Manual' : '',
      line.width_m != null && line.height_m != null
        ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)}`
        : '',
    ].filter(Boolean);
    return parts.join(' | ') || '—';
  };

  const tableData = lines.map((line, index) => {
    const qty = line.qty || 1;
    const unitPrice = line.line_total / qty;
    const lineTotal =
      variant === 'dealer'
        ? line.line_total
        : clientDiscountPct > 0
          ? line.line_total * (1 - clientDiscountPct / 100)
          : line.line_total;
    const unitForDisplay = lineTotal / qty;
    return [
      String(index + 1),
      line.area ?? '—',
      line.position ?? '—',
      buildDescription(line),
      String(qty),
      formatCurrency(unitForDisplay, quote.currency),
      formatCurrency(lineTotal, quote.currency),
    ];
  });

  const W = {
    n: 9,
    area: 25,
    pos: 20,
    desc: usableWidth - (9 + 25 + 20 + 12 + 28 + 28),
    qty: 12,
    unit: 28,
    total: 28,
  };

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'AREA', 'POSITION', 'DESCRIPTION / PRODUCT', 'QTY', 'BASE/UNIT PRICE', 'LINE TOTAL']],
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
      overflow: 'hidden',
    },
    bodyStyles: {
      fontSize: 8,
      textColor: [30, 30, 30],
      minCellHeight: 18,
      valign: 'middle',
    },
    columnStyles: {
      0: { cellWidth: W.n, halign: 'center', valign: 'middle', overflow: 'visible' },
      1: { cellWidth: W.area, halign: 'left', valign: 'middle' },
      2: { cellWidth: W.pos, halign: 'center', valign: 'middle' },
      3: { cellWidth: W.desc, halign: 'left', valign: 'middle' },
      4: { cellWidth: W.qty, halign: 'right', valign: 'middle' },
      5: { cellWidth: W.unit, halign: 'right', valign: 'middle' },
      6: { cellWidth: W.total, halign: 'right', valign: 'middle' },
    },
  });

  const finalY = (doc as any).lastAutoTable.finalY || yPos + 50;
  yPos = finalY + 10;

  // Summary (same style as Proposal)
  const productsTotal = lines.reduce((sum, line) => sum + line.line_total, 0);
  const discountAmount =
    !isDealer && clientDiscountPct > 0 ? productsTotal * (clientDiscountPct / 100) : 0;
  const subtotal = productsTotal - discountAmount;
  const tax = quote.totals?.tax_total ?? 0;
  const total = quote.totals?.total ?? subtotal + tax;

  const summaryData: [string, string][] = [['Subtotal:', formatCurrency(subtotal, quote.currency)]];
  if (discountAmount > 0) {
    summaryData.push(['Discount:', formatCurrency(-discountAmount, quote.currency)]);
  }
  summaryData.push(['ITBMS', formatCurrency(tax, quote.currency)]);
  summaryData.push(['Total:', formatCurrency(total, quote.currency)]);

  autoTable(doc, {
    startY: yPos,
    body: summaryData,
    theme: 'plain',
    bodyStyles: { fontSize: 9 },
    columnStyles: {
      0: { cellWidth: 50, fontStyle: 'bold' },
      1: { cellWidth: 50, halign: 'right', fontStyle: 'bold' },
    },
    margin: { left: pageWidth - 120, right: marginX },
  });

  let termsY = (doc as any).lastAutoTable.finalY || yPos + 50;
  if (termsY > pageHeight - marginBottom - 60) {
    doc.addPage();
    yPos = marginTop;
  } else {
    yPos = termsY + 15;
  }

  // Terms (same as Proposal, English)
  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.text('Terms and Conditions', marginX, yPos);
  yPos += 7;
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  const terms = [
    `• Any contract, payment or check must be issued to: ${organizationName.toUpperCase()}`,
    '• This proposal is valid for thirty (30) business days from the date of issue.',
    '• A deposit of sixty percent (60%) of the total sale price will be required to confirm the order.',
    '• The remaining balance shall be paid upon delivery of the products.',
    '• Delivery times may vary depending on the product.',
  ];
  terms.forEach((term) => {
    const splitLines = doc.splitTextToSize(term, pageWidth - 2 * marginX);
    splitLines.forEach((line: string) => {
      if (yPos > pageHeight - marginBottom - 20) {
        doc.addPage();
        yPos = marginTop;
      }
      doc.text(line, marginX, yPos);
      yPos += 4;
    });
    yPos += 1;
  });

  // Footer
  const pageCount = (doc as any).internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    doc.text(`${i} / ${pageCount}`, pageWidth / 2, pageHeight - marginBottom + 4, { align: 'center' });
  }

  return doc;
}
