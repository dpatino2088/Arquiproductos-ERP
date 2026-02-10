/**
 * Generate Proposal PDF
 * Header: company name, type, proposal number, optional dealer logo (top-right).
 * Details: Contact, Customer, Address | Date, Valid until, Seller (no Description).
 * Body: table + summary + terms unchanged.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export type ProposalPDFVariant = 'internal' | 'customer';

/** Line for PDF: matches ProposalDetail viewer body */
export interface ProposalPDFLine {
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  /** Product name or custom description */
  description?: string | null;
  sku?: string | null;
  /** Dimensions string (e.g. "1.2 x 3.2 m") */
  dimensions?: string | null;
  /** True if installation addon present (shows "Install Included") */
  install_included?: boolean;
  /** Internal only: accessories string */
  accessories?: string | null;
  qty: number;
  unit_price: number;
  line_total: number;
}

export interface GenerateProposalPDFOptions {
  variant: ProposalPDFVariant;
  organizationName?: string;
  /** Dealer logo (from Dealer Detail) – data URL or base64 PNG, shown top-right */
  logoPngBase64?: string;
  /** Customer/site address line for "Address" field */
  customerAddress?: string;
  /** Seller name for "Seller" field (e.g. "kgonzalez") */
  sellerName?: string;
}

export interface ProposalPDFData {
  proposal_no: string;
  status: string;
  currency: string;
  valid_until?: string | null;
  notes?: string | null;
  global_discount_pct?: number | null;
  global_fee_amount?: number | null;
  subtotal_amount?: number | null;
  installation_amount?: number | null;
  discount_amount?: number | null;
  itbms_amount?: number | null;
  total_amount?: number | null;
  itbms_pct?: number | null;
  created_at: string;
}

export interface ProposalPDFCustomer {
  customer_name: string;
}

export interface ProposalPDFContact {
  contact_name?: string;
  contact_email?: string;
}

export function generateProposalPDF(
  proposal: ProposalPDFData,
  customer: ProposalPDFCustomer | null,
  contact: ProposalPDFContact | null,
  lines: ProposalPDFLine[],
  organizationNameOrOptions: string | GenerateProposalPDFOptions = 'Arquiproductos'
): jsPDF {
  const opts =
    typeof organizationNameOrOptions === 'object'
      ? organizationNameOrOptions
      : { variant: 'customer' as ProposalPDFVariant, organizationName: organizationNameOrOptions };
  const variant = opts.variant ?? 'customer';
  const organizationName = opts.organizationName ?? 'Arquiproductos';

  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const marginX = 12;
  const marginTop = 14;
  const marginBottom = 14;
  const usableWidth = pageWidth - marginX * 2;
  let yPos = marginTop;

  // Logo (top-right, from Dealer Detail)
  const logoSizeMm = 18;
  const logoX = pageWidth - marginX - logoSizeMm;
  const logoY = marginTop;
  if (opts.logoPngBase64) {
    try {
      doc.addImage(opts.logoPngBase64, 'PNG', logoX, logoY, logoSizeMm, logoSizeMm);
    } catch {
      // ignore invalid image
    }
  }

  // Header: company name (left), proposal number (right)
  doc.setFontSize(20);
  doc.setFont('helvetica', 'bold');
  doc.text(organizationName.toUpperCase(), marginX, yPos);

  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text(proposal.proposal_no, pageWidth - marginX, yPos, { align: 'right' });

  doc.setFontSize(12);
  doc.setFont('helvetica', 'normal');
  doc.text(variant === 'internal' ? 'PROPOSAL (INTERNAL)' : 'CUSTOMER PROPOSAL', marginX, yPos + 7);

  yPos += 14;

  // Details: Contact, Customer, Address (left) | Date, Valid until, Seller (right) – no Description
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  const validUntilStr = proposal.valid_until
    ? new Date(proposal.valid_until).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' })
    : '30 days';
  const dateStr = new Date(proposal.created_at).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
  const detailsLeft: Array<{ label: string; value: string }> = [
    { label: 'Contact:', value: contact?.contact_name ?? contact?.contact_email ?? 'N/A' },
    { label: 'Customer:', value: customer?.customer_name ?? 'N/A' },
    { label: 'Address:', value: opts.customerAddress ?? 'N/A' },
  ];
  const detailsRight: Array<{ label: string; value: string }> = [
    { label: 'Date:', value: dateStr },
    { label: 'Valid until:', value: validUntilStr },
    { label: 'Seller:', value: opts.sellerName ?? 'System' },
  ];
  const maxRows = Math.max(detailsLeft.length, detailsRight.length);
  for (let i = 0; i < maxRows; i++) {
    const y = yPos + i * 5;
    if (detailsLeft[i]) {
      doc.setFont('helvetica', 'bold');
      doc.text(detailsLeft[i].label, marginX, y);
      doc.setFont('helvetica', 'normal');
      doc.text(detailsLeft[i].value, marginX + doc.getTextWidth(detailsLeft[i].label + ' '), y);
    }
    if (detailsRight[i]) {
      doc.setFont('helvetica', 'bold');
      doc.text(detailsRight[i].label, pageWidth / 2, y);
      doc.setFont('helvetica', 'normal');
      doc.text(detailsRight[i].value, pageWidth / 2 + doc.getTextWidth(detailsRight[i].label + ' '), y);
    }
  }
  yPos += maxRows * 5 + 8;

  // Table body: same structure as ProposalDetail viewer (#, Area, Position, Description/Product, Qty, Base/Unit price, Line total)
  const buildDescriptionCell = (line: ProposalPDFLine): string => {
    const name = line.description || line.product_type || '—';
    const skuPart = line.sku ? ` (${line.sku})` : '';
    const dimsPart = line.dimensions ? `\n${line.dimensions}` : '';
    const installPart = line.install_included ? '\nInstall Included' : '';
    return `${name}${skuPart}${dimsPart}${installPart}`.trim();
  };

  const tableData = lines.map((line, index) => [
    String(index + 1),
    line.area || '—',
    line.position || '—',
    buildDescriptionCell(line),
    String(line.qty),
    formatCurrency(line.unit_price, proposal.currency),
    formatCurrency(line.line_total, proposal.currency),
  ]);

  // Tabla: anchos que suman usableWidth exacto, header sin wrap, padding derecho correcto
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
    didParseCell: (data) => {
      if (data.section === 'head') {
        data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
      }
    },
    didDrawCell: (data) => {
      if (data.section !== 'body') return;
      doc.setDrawColor(200, 200, 200);
      doc.setLineWidth(0.25);
      const x = data.cell.x;
      const y = data.cell.y + data.cell.height;
      doc.line(x, y, x + data.cell.width, y);
    },
  });

  const finalY = (doc as any).lastAutoTable.finalY || yPos + 50;
  yPos = finalY + 10;

  // Summary: Subtotal (material), Discount, Instalación, ITBMS, Total
  const subtotal = proposal.subtotal_amount ?? lines.reduce((sum, line) => sum + line.line_total, 0);
  const installationAmount = proposal.installation_amount ?? 0;
  const discountAmount = proposal.discount_amount ?? 0;
  const itbmsAmount = proposal.itbms_amount ?? 0;
  const total = proposal.total_amount ?? (subtotal - discountAmount + installationAmount + itbmsAmount);

  const summaryData: [string, string][] = [['Subtotal:', formatCurrency(subtotal, proposal.currency)]];
  if (discountAmount > 0) {
    summaryData.push(['Discount:', formatCurrency(-discountAmount, proposal.currency)]);
  }
  if (installationAmount > 0) {
    summaryData.push(['Instalación:', formatCurrency(installationAmount, proposal.currency)]);
  }
  summaryData.push(['ITBMS' + (proposal.itbms_pct != null ? ` (${Math.round(proposal.itbms_pct * 100)}%)` : ''), formatCurrency(itbmsAmount, proposal.currency)]);
  summaryData.push(['Total:', formatCurrency(total, proposal.currency)]);

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

  // Terms (English)
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

function formatCurrency(amount: number, currency: string = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}
