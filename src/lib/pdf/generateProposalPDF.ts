/**
 * Generate Proposal PDF
 * Header: dealer logo slot (50mm × 10mm, top-left), proposal number (right).
 * Details: Customer, Contact, Address (label then data below) | Date, Valid until, Seller.
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

export interface ProposalSummaryTotals {
  totalProduct: number;
  discountAmount: number;
  installationAmount: number;
  subtotal: number;
  itbmsAmount: number;
  total: number;
}

export interface GenerateProposalPDFOptions {
  variant: ProposalPDFVariant;
  organizationName?: string;
  /** Dealer logo (from Dealer Detail) – data URL or base64, shown in 50mm × 10mm slot top-left */
  logoPngBase64?: string;
  /** Logo pixel dimensions for aspect-ratio preservation (fit inside 50mm × 10mm) */
  logoWidthPx?: number;
  logoHeightPx?: number;
  /** Customer/site address from DirectoryCustomer */
  customerAddress?: string;
  /** Customer email from DirectoryCustomer (shown below address if present) */
  customerEmail?: string | null;
  /** Customer phone from DirectoryCustomer (shown below address if present) */
  customerPhone?: string | null;
  /** Salesperson name for "Salesperson" field (e.g. "kgonzalez") */
  sellerName?: string;
  /** Use these totals so PDF summary matches Proposal UI (Installation/Discount only when > 0) */
  overrideTotals?: ProposalSummaryTotals;
  /** For Discount label: "Discount (15%)" when set */
  global_discount_pct?: number | null;
  /** For ITBMS label: "ITBMS (7%)" when set */
  itbms_pct?: number | null;
}

export interface ProposalPDFData {
  proposal_no: string;
  status: string;
  currency: string;
  valid_until?: string | null;
  /** Short proposal description (shown below Address in PDF). */
  description?: string | null;
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
  const tableRightMm = marginX;
  const tableUsableWidth = usableWidth;
  let yPos = marginTop;

  // Dealer logo slot: 80mm × 20mm, 3mm desde el borde izquierdo (padding)
  const logoSlotW = 80;
  const logoSlotH = 20;
  const logoSlotX = 3;
  const logoSlotY = marginTop - 5;
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
      const imgX = logoSlotX;
      const imgY = logoSlotY + (logoSlotH - drawH) / 2;
      const dataUrl = opts.logoPngBase64;
      const format = dataUrl.startsWith('data:image/jpeg') || dataUrl.startsWith('data:image/jpg') ? 'JPEG' : 'PNG';
      doc.addImage(dataUrl, format, imgX, imgY, drawW, drawH);
      logoDrawn = true;
    } catch {
      try {
        const wPx = opts.logoWidthPx ?? 100;
        const hPx = opts.logoHeightPx ?? 100;
        const pxToMm = 25.4 / 72;
        const wMm = wPx * pxToMm;
        const hMm = hPx * pxToMm;
        const scale = Math.min(logoSlotW / wMm, logoSlotH / hMm, 1);
        const drawW = wMm * scale;
        const drawH = hMm * scale;
        const imgX = logoSlotX;
        const imgY = logoSlotY + (logoSlotH - drawH) / 2;
        doc.addImage(opts.logoPngBase64, 'PNG', imgX, imgY, drawW, drawH);
        logoDrawn = true;
      } catch {
        // ignore invalid image
      }
    }
  }

  // Header: when no logo, leave the slot empty (do not show company name text).

  const headerRightX = pageWidth - marginX;
  doc.setFontSize(10);
  doc.text('Proposal', headerRightX, yPos, { align: 'right' });
  const proposalToNumberGapMm = (7 / 72) * 25.4; // 7px between "Proposal" and number
  const proposalLineHeightMm = (10 / 72) * 25.4;
  doc.setFontSize(14);
  doc.text(proposal.proposal_no, headerRightX, yPos + proposalLineHeightMm + proposalToNumberGapMm, { align: 'right' });

  yPos += logoDrawn ? logoSlotH : 14;

  // Details: Customer, Contact, Address (left) | Date, Valid until, Salesperson (right). 5px interlineado (text-to-text).
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  const spacingPx = 7;
  const spacingMm = (spacingPx / 72) * 25.4;
  const interlinePx = 5;
  const interlineMm = (interlinePx / 72) * 25.4;
  const lineHeightMm = 4;
  const validUntilStr = proposal.valid_until
    ? new Date(proposal.valid_until).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' })
    : '30 days';
  const dateStr = new Date(proposal.created_at).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });

  let leftY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.text('Customer:', marginX, leftY);
  doc.setFont('helvetica', 'normal');
  const customerLabelW = doc.getTextWidth('Customer: ');
  doc.text(customer?.customer_name ?? 'N/A', marginX + customerLabelW + spacingMm, leftY);
  leftY += lineHeightMm + interlineMm;

  doc.setFont('helvetica', 'bold');
  doc.text('Contact:', marginX, leftY);
  doc.setFont('helvetica', 'normal');
  const contactLabelW = doc.getTextWidth('Contact: ');
  doc.text(contact?.contact_name ?? contact?.contact_email ?? 'N/A', marginX + contactLabelW + spacingMm, leftY);
  leftY += lineHeightMm + interlineMm;

  if (opts.customerEmail) {
    doc.setFont('helvetica', 'bold');
    doc.text('Email:', marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.text(opts.customerEmail, marginX + doc.getTextWidth('Email: ') + spacingMm, leftY);
    leftY += lineHeightMm + interlineMm;
  }
  if (opts.customerPhone) {
    doc.setFont('helvetica', 'bold');
    doc.text('Phone:', marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.text(opts.customerPhone, marginX + doc.getTextWidth('Phone: ') + spacingMm, leftY);
    leftY += lineHeightMm + interlineMm;
  }
  leftY += (7 / 96) * 25.4; // 7px space before Address block
  doc.setFont('helvetica', 'bold');
  doc.text('Address', marginX, leftY);
  leftY += lineHeightMm + interlineMm;
  doc.setFont('helvetica', 'normal');
  const addressInterlineMm = (5 / 72) * 25.4; // 5px between address lines
  const addressLineHeightMm = (9 / 72) * 25.4; // line height for 9pt (same as details)
  const addressLines = doc.splitTextToSize(opts.customerAddress ?? 'N/A', usableWidth / 2);
  addressLines.forEach((line: string) => {
    doc.text(line, marginX, leftY);
    leftY += addressLineHeightMm + addressInterlineMm;
  });
  doc.setFontSize(9);
  leftY += 4; // 4mm separation from Address text
  if (proposal.description && String(proposal.description).trim()) {
    doc.setFontSize(9);
    doc.setFont('helvetica', 'bold');
    const descLabel = 'Description: ';
    const descLabelW = doc.getTextWidth(descLabel);
    doc.text(descLabel, marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const descTextWidth = usableWidth / 2 - descLabelW - spacingMm;
    const descLines = doc.splitTextToSize(String(proposal.description).trim(), descTextWidth);
    const descX = marginX + descLabelW + spacingMm;
    descLines.forEach((line: string) => {
      doc.text(line, descX, leftY);
      leftY += addressLineHeightMm + addressInterlineMm;
    });
    leftY += addressInterlineMm;
    doc.setFontSize(9);
  }
  const leftBlockEndY = leftY;

  const detailsRight: Array<{ label: string; value: string }> = [
    { label: 'Date:', value: dateStr },
    { label: 'Valid until:', value: validUntilStr },
    { label: 'Salesperson:', value: opts.sellerName ?? 'System' },
  ];
  const rightEdgeX = pageWidth - marginX;
  let rightY = yPos;
  detailsRight.forEach((row) => {
    doc.setFont('helvetica', 'normal');
    const valueW = doc.getTextWidth(row.value);
    doc.text(row.value, rightEdgeX, rightY, { align: 'right' });
    doc.setFont('helvetica', 'bold');
    doc.text(row.label + ' ', rightEdgeX - valueW - spacingMm, rightY, { align: 'right' });
    rightY += lineHeightMm + interlineMm;
  });

  // Table (grey header bar): 7mm higher so closer to description
  const gapBeforeTableMm = 8 - (10 / 96) * 25.4;
  yPos = Math.max(leftBlockEndY, rightY) + gapBeforeTableMm - 7;

  // Table body: same as ProposalDetail viewer. Full Detail (internal) = with dimensions in description; Without Measurements (customer) = no dimensions.
  const includeMeasurements = variant === 'internal';
  const buildDescriptionCell = (line: ProposalPDFLine): string => {
    const name = line.description || line.product_type || '—';
    const skuPart = line.sku ? ` (${line.sku})` : '';
    const dimsPart =
      includeMeasurements && line.dimensions && line.dimensions.trim() && line.dimensions !== '—'
        ? `\n${line.dimensions}`
        : '';
    const installPart = line.install_included ? '\nInstall Included' : '';
    return `${name}${skuPart}${dimsPart}${installPart}`.trim();
  };

  const tableData = lines.map((line, index) => [
    String(index + 1),
    line.area || '—',
    line.position || '—',
    buildDescriptionCell(line),
    line.product_type ?? '—',
    line.accessories ?? '—',
    String(line.qty),
    formatCurrency(line.unit_price, proposal.currency),
    formatCurrency(line.line_total, proposal.currency),
  ]);

  // Table: same headers as proposal viewer (no all-caps)
  const movePosLeftPx = 7;
  const movePosLeftMm = (movePosLeftPx / 96) * 25.4 + 5;
  const lineTotalShiftRightMm = 10;
  const productTypeAccQtyShiftRightMm = 10;
  const W = {
    n: 8,
    area: 18 - movePosLeftMm,
    pos: 22 + movePosLeftMm,
    desc: 52,
    productType: 22,
    acc: 26,
    qty: 10,
    unit: 24 + lineTotalShiftRightMm - productTypeAccQtyShiftRightMm,
    total: 24,
  };
  const descFlex = tableUsableWidth - (W.n + W.area + W.pos + W.productType + W.acc + W.qty + W.unit + W.total);
  (W as Record<string, number>).desc = Math.max(descFlex, 18);

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'Area', 'Position', 'Description', 'Product type', 'Accessories', 'Qty', 'Unit Price', 'Line total']],
    body: tableData,
    theme: 'plain',
    margin: { left: marginX, right: tableRightMm },
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
        cellWidth: W.desc,
        halign: 'left',
        valign: 'middle',
        overflow: 'linebreak',
        fontSize: 8,
        cellPadding: { top: 5, bottom: 5, left: 3, right: 3 },
        minCellHeight: 22,
      },
      4: { cellWidth: W.productType, halign: 'center', valign: 'middle' },
      5: { cellWidth: W.acc, halign: 'left', valign: 'middle' },
      6: { cellWidth: W.qty, halign: 'right', valign: 'middle' },
      7: { cellWidth: W.unit, halign: 'right', valign: 'middle' },
      8: { cellWidth: W.total, halign: 'right', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 5, right: 5 } },
    },
    didParseCell: (data) => {
      if (data.section === 'head') {
        data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        if (data.column.index === 2) data.cell.styles.halign = 'center';
        if (data.column.index === 6 || data.column.index === 7) data.cell.styles.halign = 'right';
        if (data.column.index === 8) {
          data.cell.styles.halign = 'right';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 5, right: 5 };
        }
      }
      if (data.section === 'body' && data.column.index === 3) {
        const raw = data.cell.raw;
        const text = Array.isArray(raw) ? (raw as string[]).join('\n') : String(raw ?? '');
        const lineCount = (text.match(/\n/g) || []).length + 1;
        const minHeight = Math.max(22, 10 + lineCount * 5);
        data.cell.styles.minCellHeight = minHeight;
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

  // Layout like proposal viewer: Terms and Conditions (left ~2/3) + Summary (right ~1/3)
  const summaryWidth = 62;
  const termsWidth = usableWidth - summaryWidth - 8;
  const summaryLeft = marginX + termsWidth + 8;

  // Terms and Conditions: from proposal.notes (Términos y Condiciones in Proposal)
  const sectionStartY = yPos;
  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.text('Terms and Conditions', marginX, sectionStartY);
  let termsContentY = sectionStartY + 6;
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  const termsText = (proposal.notes && String(proposal.notes).trim()) ? String(proposal.notes).trim() : '';
  if (termsText) {
    const termsLines = doc.splitTextToSize(termsText, termsWidth);
    termsLines.forEach((line: string) => {
      if (termsContentY > pageHeight - marginBottom - 15) {
        doc.addPage();
        termsContentY = marginTop;
      }
      doc.text(line, marginX, termsContentY);
      termsContentY += 4;
    });
  }

  // Summary: same order as Proposal UI – Total Product, Discount (if > 0), Installation (if > 0), Subtotal, ITBMS, Total
  const useOverride = opts.overrideTotals != null;
  const totalProduct = useOverride ? opts.overrideTotals!.totalProduct : lines.reduce((sum, line) => sum + (line.line_total ?? 0), 0);
  const discountAmount = useOverride ? opts.overrideTotals!.discountAmount : (proposal.discount_amount ?? 0);
  const installationAmount = useOverride ? opts.overrideTotals!.installationAmount : (proposal.installation_amount ?? 0);
  const subtotal = useOverride ? opts.overrideTotals!.subtotal : Math.max(totalProduct - discountAmount, 0) + installationAmount;
  const itbmsAmount = useOverride ? opts.overrideTotals!.itbmsAmount : (proposal.itbms_amount ?? 0);
  const total = useOverride ? opts.overrideTotals!.total : (proposal.total_amount ?? subtotal + itbmsAmount);
  // Percent: accept decimal (0.15) or already percent (15); show as "15%"
  const toPctDisplay = (v: number | null | undefined): number | null =>
    v != null ? (v > 0 && v <= 1 ? Math.round(v * 100) : Math.round(v)) : null;
  const discountPctLabel = (() => {
    const n = toPctDisplay(opts.global_discount_pct) ?? toPctDisplay(proposal.global_discount_pct);
    return n != null ? ` (${n}%)` : '';
  })();
  const itbmsPctLabel = (() => {
    const n = toPctDisplay(opts.itbms_pct) ?? toPctDisplay(proposal.itbms_pct);
    return n != null ? ` (${n}%)` : '';
  })();

  const summaryData: [string, string][] = [['Total Product:', formatCurrency(totalProduct, proposal.currency)]];
  if (discountAmount > 0) {
    summaryData.push(['Discount' + discountPctLabel + ':', formatCurrency(-discountAmount, proposal.currency)]);
  }
  if (installationAmount > 0) {
    summaryData.push(['Installation:', formatCurrency(installationAmount, proposal.currency)]);
  }
  summaryData.push(['Subtotal:', formatCurrency(subtotal, proposal.currency)]);
  summaryData.push(['ITBMS' + itbmsPctLabel, formatCurrency(itbmsAmount, proposal.currency)]);
  summaryData.push(['Total:', formatCurrency(total, proposal.currency)]);

  // Summary row spacing: 2mm less between lines (Total Product, Installation, Subtotal, ITBMS, Discount, Total)
  const summaryCellPadding = { top: 1, bottom: 1, left: 2, right: 3 };
  autoTable(doc, {
    startY: sectionStartY,
    body: summaryData,
    theme: 'plain',
    bodyStyles: { fontSize: 9, cellPadding: summaryCellPadding },
    columnStyles: {
      0: { cellWidth: 32, fontStyle: 'bold', cellPadding: summaryCellPadding },
      1: { cellWidth: 28, halign: 'right', fontStyle: 'bold', cellPadding: summaryCellPadding },
    },
    margin: { left: summaryLeft, right: tableRightMm },
    tableWidth: summaryWidth,
    didDrawCell: (data) => {
      // Divider line between ITBMS and Total: same thickness as body table (0.25)
      if (data.section === 'body' && data.row.index === summaryData.length - 1 && data.column.index === 0) {
        const x = Number(data.cell.x);
        const y = Number(data.cell.y);
        const tableW = Number((data as any).table?.width);
        const w = Number.isFinite(tableW) && tableW > 0 ? tableW : summaryWidth;
        if (Number.isFinite(x) && Number.isFinite(y) && Number.isFinite(w)) {
          doc.setDrawColor(200, 200, 200);
          doc.setLineWidth(0.25);
          doc.line(x, y, x + w, y);
        }
      }
    },
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
