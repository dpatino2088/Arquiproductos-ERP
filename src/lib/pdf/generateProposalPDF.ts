/**
 * Generate Proposal PDF
 * Header: dealer logo slot (50mm × 10mm, top-left), proposal number (right).
 * Details: Customer, Contact, Address (label then data below) | Date, Valid until, Seller.
 * Body: table + summary + terms unchanged.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatDate } from '../utils';

export type ProposalPDFVariant = 'internal' | 'customer';

/** Line for PDF: matches ProposalDetail viewer body */
export interface ProposalPDFLine {
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  /** Drive system brand/type (e.g. "Manual Vertilux", "Motorize Lutron") */
  drive_system_label?: string | null;
  /** Product name or custom description */
  description?: string | null;
  sku?: string | null;
  /** Dimensions string – internal: Quote-style "1200 x 3000" (mm) per panel; customer: not used */
  dimensions?: string | null;
  /** Panel count – customer variant: shows "1 paño" / "2 paños" / "3 paños" as reference */
  panel_count?: number | null;
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
  taxAmount: number;
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
  /** For Tax label: "Tax (7%)" when set */
  tax_pct?: number | null;
  /** If true, Tax row is hidden (tax exempt) */
  exempt_tax?: boolean;
}

export interface ProposalPDFData {
  proposal_no: string;
  status: string;
  currency: string;
  valid_until?: string | null;
  /** Short proposal description (shown below Address in PDF). */
  description?: string | null;
  notes?: string | null;
  /** Snapshot: terms title (for PDF). Preferred over fixed "Terms and Conditions". */
  terms_title?: string | null;
  /** Snapshot: terms content (for PDF). Preferred over notes. */
  terms_content?: string | null;
  global_discount_pct?: number | null;
  global_fee_amount?: number | null;
  subtotal_amount?: number | null;
  installation_amount?: number | null;
  discount_amount?: number | null;
  tax_amount?: number | null;
  total_amount?: number | null;
  tax_pct?: number | null;
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

  // Dealer logo slot: 80mm × 20mm, aligned with Customer (marginX)
  const logoSlotW = 80;
  const logoSlotH = 20;
  const logoSlotX = marginX;
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
  const proposalToNumberGapMm = (7 / 72) * 25.4;
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
    ? formatDate(proposal.valid_until)
    : '30 days';
  const dateStr = formatDate(proposal.created_at);

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
    const driveLabel = line.drive_system_label
      ? line.drive_system_label
      : (line.drive_type === 'motor' ? 'Motorized' : line.drive_type === 'manual' ? 'Manual' : '');
    const panelLabel = line.panel_count != null && line.panel_count >= 1
      ? (line.panel_count === 1 ? '1 Paño' : `${line.panel_count} Paños`)
      : '';
    const drivePart = driveLabel ? `\n${driveLabel}` : '';
    // Keep Install Included before dimensions so it remains visible on dense internal rows.
    const installPart = line.install_included ? '\nInstall Included' : '';
    let dimsPart = '';
    if (includeMeasurements && line.dimensions && line.dimensions.trim() && line.dimensions !== '—') {
      dimsPart = `\n${line.dimensions}`;
    } else if (!includeMeasurements && panelLabel) {
      // Sin medidas: mostrar cantidad de paños en Description (en vez de medidas)
      dimsPart = `\n${panelLabel}`;
    }
    return `${name}${skuPart}${drivePart}${installPart}${dimsPart}`.trim();
  };

  const tableData = lines.map((line, index) => [
    String(index + 1),
    line.area || '—',
    line.position || '—',
    buildDescriptionCell(line),
    line.product_type ?? '—',
    String(line.qty),
    formatCurrency(line.unit_price, proposal.currency),
    formatCurrency(line.line_total, proposal.currency),
  ]);

  // Table: sin Accessories; Area 5mm más estrecha para mover Position y Description 5mm a la izquierda
  const lineTotalShiftRightMm = 10;
  const W = {
    n: 8,
    area: 21,  // reducido 5mm (26→21) para Position/Description 5mm más a la izq.
    pos: 18,
    desc: 52,
    productType: 24,
    qty: 10,
    // Wider money columns to avoid clipping on amounts > 100,000
    unit: 31,
    total: 30,
  };
  const descFlex = tableUsableWidth - (W.n + W.area + W.pos + W.productType + W.qty + W.unit + W.total);
  (W as Record<string, number>).desc = Math.max(descFlex, 18);

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'Area', 'Position', 'Description', 'Product type', 'Qty', 'Unit Price', 'Line total']],
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
      fillColor: [0, 0, 0],
      textColor: [255, 255, 255],
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
      5: { cellWidth: W.qty, halign: 'right', valign: 'middle' },
      6: { cellWidth: W.unit, halign: 'right', valign: 'middle' },
      7: { cellWidth: W.total, halign: 'right', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 2, right: 2 } },
    },
    didParseCell: (data) => {
      if (data.section === 'head') {
        data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        if (data.column.index === 2) data.cell.styles.halign = 'center';
        if (data.column.index === 5 || data.column.index === 6) data.cell.styles.halign = 'right';
        if (data.column.index === 7) {
          data.cell.styles.halign = 'right';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        }
      }
      if (data.section === 'body' && data.column.index === 3) {
        const raw = data.cell.raw;
        const text = Array.isArray(raw) ? (raw as string[]).join('\n') : String(raw ?? '');
        const descUsableWidth = Math.max(W.desc - 6, 10);
        const wrapped = doc.splitTextToSize(text, descUsableWidth);
        const lineCount = Math.max(1, wrapped.length);
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
  const gapAfterTable = 8;
  const minSpaceForSummaryBlock = 45;
  const spaceLeft = pageHeight - marginBottom - finalY;
  let sectionStartY: number;
  if (spaceLeft < minSpaceForSummaryBlock) {
    doc.addPage();
    sectionStartY = marginTop;
  } else {
    sectionStartY = finalY + gapAfterTable;
  }

  // —— Summary (right) + Notes (left, aligned with summary) ——
  const summaryWidth = 72;
  const summaryLeft = pageWidth - marginX - summaryWidth;

  // Summary rows
  const exemptTax = opts.exempt_tax ?? false;
  const useOverride = opts.overrideTotals != null;
  const totalProduct = useOverride ? opts.overrideTotals!.totalProduct : lines.reduce((sum, line) => sum + (line.line_total ?? 0), 0);
  const discountAmount = useOverride ? opts.overrideTotals!.discountAmount : (proposal.discount_amount ?? 0);
  const installationAmount = useOverride ? opts.overrideTotals!.installationAmount : (proposal.installation_amount ?? 0);
  const subtotal = useOverride ? opts.overrideTotals!.subtotal : Math.max(totalProduct - discountAmount, 0) + installationAmount;
  const taxAmount = exemptTax ? 0 : (useOverride ? opts.overrideTotals!.taxAmount : (proposal.tax_amount ?? 0));
  const total = useOverride ? opts.overrideTotals!.total : (proposal.total_amount ?? subtotal + taxAmount);
  const toPctDisplay = (v: number | null | undefined): number | null =>
    v != null ? (v > 0 && v <= 1 ? Math.round(v * 100) : Math.round(v)) : null;
  const discountPctLabel = (() => {
    const n = toPctDisplay(opts.global_discount_pct) ?? toPctDisplay(proposal.global_discount_pct);
    return n != null ? ` (${n}%)` : '';
  })();
  const taxPctLabel = (() => {
    const n = toPctDisplay(opts.tax_pct) ?? toPctDisplay(proposal.tax_pct);
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
  if (!exemptTax) {
    summaryData.push(['Tax' + taxPctLabel, formatCurrency(taxAmount, proposal.currency)]);
  }
  summaryData.push(['Total:', formatCurrency(total, proposal.currency)]);

  const summaryCellPadding = { top: 1, bottom: 1, left: 2, right: 3 };
  autoTable(doc, {
    startY: sectionStartY,
    body: summaryData,
    theme: 'plain',
    bodyStyles: { fontSize: 9, cellPadding: summaryCellPadding },
    columnStyles: {
      0: { cellWidth: 36, fontStyle: 'bold', cellPadding: summaryCellPadding },
      1: { cellWidth: 34, halign: 'right', fontStyle: 'bold', cellPadding: summaryCellPadding },
    },
    margin: { left: summaryLeft, right: marginX },
    tableWidth: summaryWidth,
    didDrawCell: (data) => {
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

  // Notes: left of summary, aligned at sectionStartY
  const notesText = (proposal.notes && String(proposal.notes).trim()) || '';
  const notesColWidth = summaryLeft - marginX - 8;
  if (notesText) {
    let notesY = sectionStartY;
    doc.setFontSize(9);
    doc.setFont('helvetica', 'bold');
    doc.text('Notes', marginX, notesY);
    notesY += 5;
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    const notesLines = doc.splitTextToSize(notesText, notesColWidth);
    notesLines.forEach((line: string) => {
      doc.text(line, marginX, notesY);
      notesY += 4;
    });
  }

  // —— Terms & Conditions: 30px below Summary final Y, full width ——
  const summaryFinalY = (doc as any).lastAutoTable?.finalY ?? sectionStartY;
  const thirtyPxMm = (30 / 96) * 25.4;
  const extraDropMm = 10;
  let termsStartY = summaryFinalY + thirtyPxMm + extraDropMm;
  if (termsStartY > pageHeight - marginBottom - 20) {
    doc.addPage();
    termsStartY = marginTop;
  }

  const termsText = (proposal.terms_content && String(proposal.terms_content).trim()) || '';
  if (termsText) {
    doc.setFontSize(11);
    doc.setFont('helvetica', 'bold');
    const termsHeading = proposal.terms_title?.trim() || 'Terms and Conditions';
    doc.text(termsHeading, marginX, termsStartY);
    let termsContentY = termsStartY + 6;
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    const termsLines = doc.splitTextToSize(termsText, usableWidth);
    termsLines.forEach((line: string) => {
      if (termsContentY > pageHeight - marginBottom - 15) {
        doc.addPage();
        termsContentY = marginTop;
      }
      doc.text(line, marginX, termsContentY);
      termsContentY += 4;
    });
  }

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
