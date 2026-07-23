/**
 * Generate Quote PDF
 * Same format as Proposal PDF: logo slot (Arquiproducto) top-left, "Quote" + quote_no top-right,
 * Details: Customer, Contact, Address (left) | Date, Valid until, Salesperson (right).
 * Body: same table (#, Area, Position, Description, Measurements, Product type, Qty, Unit Price, Line total) and summary.
 * Logo is always Arquiproducto (passed by caller from /images); no dealer logo link.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatDimensionsForProposalPDF, type DimensionsSource } from '../formatDimensions';
import { formatDate } from '../utils';
import { formatDraperyStyleLabel, formatDraperyTrackDescription } from '../drapery/labels';

export type PDFVariant = 'dealer' | 'client';

export interface QuotePDFLine {
  id: string;
  sku?: string | null;
  catalog_code?: string | null;
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  /** Name of selected drive/motor SKU for operating system line */
  operating_system_sku_name?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  /** Dimensions source for per-panel format (same as Viewer) */
  dimensions_source?: DimensionsSource | null;
  /** Drapery style code (e.g. wave_2.0, pinch_pleat) — size/fullness, not system */
  style_code?: string | null;
  /** Drapery product line / system (e.g. wave_drapery, ripple_fold, pinch_pleat) */
  product_line?: string | null;
  /** True when drapery is configured as track-only (no fabric) */
  track_only?: boolean;
  /** Whether side channel is included in config */
  has_side_channel?: boolean;
  /** Whether bottom channel is included in config */
  has_bottom_channel?: boolean;
  qty: number;
  line_total: number;
  /** Optional: for table "Accessories" column */
  accessories?: string | null;
  CatalogItems?: {
    item_name?: string;
    name?: string;
    sku?: string;
    color?: string | null;
  } | null;
  /** Catalog item display name (when product_type === 'catalog') */
  catalog_name?: string | null;
  /** Catalog item color (when product_type === 'catalog') */
  catalog_color?: string | null;
}

export interface QuotePDFData {
  quote_no: string;
  customer_id: string;
  status: string;
  currency: string;
  /** Project detail description (right box). */
  description?: string | null;
  notes?: string | null;
  /** Snapshot: terms title (for PDF). Preferred over notes. */
  terms_title?: string | null;
  /** Snapshot: terms content (for PDF). Preferred over notes. */
  terms_content?: string | null;
  totals: {
    subtotal: number;
    tax_total: number;
    total: number;
  };
  created_at: string;
}

export interface QuotePDFCustomer {
  customer_name: string;
}

export interface QuotePDFContact {
  contact_name?: string;
  contact_email?: string;
}

export interface GenerateQuotePDFOptions {
  variant: PDFVariant;
  /** Discount % (0–100) applied to subtotal for client version only */
  clientDiscountPct?: number;
  /** Arquiproducto logo – data URL or base64 PNG (from /images/Arquiproductos.png); no dealer logo link */
  logoPngBase64?: string;
  /** Logo pixel dimensions for aspect-ratio (fit inside 80×20mm slot) */
  logoWidthPx?: number;
  logoHeightPx?: number;
  /** Dealer block (main left block) */
  dealerName?: string;
  dealerNo?: string | null;
  dealerUser?: string | null;
  dealerPhone?: string | null;
  dealerAddress?: string | null;
  /** Short description (shown below Address in left block; label "Notas:") */
  description?: string;
  /** Created-by / seller name (right column) */
  sellerName?: string;
  /** Project/Customer box (right side, bordered): Project, Customer, Contact, Description */
  projectName?: string | null;
  /** Dealer PO / order number */
  poNumber?: string | null;
  /** Tax % for label e.g. "Tax (7%)" (0–1 or 0–100) */
  tax_pct?: number | null;
  /** If true, Tax row is hidden (tax exempt) */
  exempt_tax?: boolean;
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
  quote: QuotePDFData,
  customer: QuotePDFCustomer | null,
  contact: QuotePDFContact | null,
  lines: QuotePDFLine[],
  organizationName: string = 'Arquiproductos',
  options: GenerateQuotePDFOptions = { variant: 'client' }
): jsPDF {
  const {
    variant,
    clientDiscountPct = 0,
    logoPngBase64,
    logoWidthPx = 100,
    logoHeightPx = 100,
    dealerName,
    dealerNo,
    dealerUser,
    dealerPhone,
    dealerAddress,
    description,
    sellerName,
    projectName,
    poNumber,
    tax_pct,
    exempt_tax = false,
  } = options;

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

  // —— Logo slot: alineado con la "C" de Customer (mismo marginX). Arquiproducto only. ——
  const logoSlotW = 80;
  const logoSlotH = 20;
  const logoSlotX = marginX; // mismo padding que "Customer:"
  const logoSlotY = marginTop - 5;
  let logoDrawn = false;
  if (logoPngBase64) {
    try {
      const pxToMm = 25.4 / 72;
      const wMm = logoWidthPx * pxToMm;
      const hMm = logoHeightPx * pxToMm;
      const scale = Math.min(logoSlotW / wMm, logoSlotH / hMm, 1);
      const drawW = wMm * scale;
      const drawH = hMm * scale;
      const imgX = logoSlotX;
      const imgY = logoSlotY + (logoSlotH - drawH) / 2;
      const format = logoPngBase64.startsWith('data:image/jpeg') || logoPngBase64.startsWith('data:image/jpg') ? 'JPEG' : 'PNG';
      doc.addImage(logoPngBase64, format, imgX, imgY, drawW, drawH);
      logoDrawn = true;
    } catch {
      try {
        doc.addImage(logoPngBase64, 'PNG', logoSlotX, logoSlotY + (logoSlotH - 10) / 2, Math.min(logoSlotW, 50), 10);
        logoDrawn = true;
      } catch {
        // ignore invalid image
      }
    }
  }

  // —— Header right: Quote, quote_no, Dealer No, Date, Valid until, Salesperson (como referencia) ——
  const headerRightX = pageWidth - marginX;
  const quoteToNumberGapMm = (7 / 72) * 25.4;
  const quoteLineHeightMm = (10 / 72) * 25.4;
  const headerLineStep = 5;
  let headerY = yPos;
  const quoteBlockOffsetMm = 2; // bajar solo "Quote" y número 2 mm
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('Quote', headerRightX, headerY + quoteBlockOffsetMm, { align: 'right' });
  headerY += quoteLineHeightMm + quoteToNumberGapMm;
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text(quote.quote_no, headerRightX, headerY + quoteBlockOffsetMm, { align: 'right' });
  headerY += headerLineStep + 5; // bajar bloque Dealer No / Date / Valid until / Salesperson 5 mm
  const validUntilStr = '30 days';
  const dateStr = formatDate(quote.created_at);
  const headerFontSize = 9; // etiquetas en negrita, valores mismo tamaño que antes

  const drawHeaderRow = (label: string, value: string) => {
    doc.setFontSize(headerFontSize);
    doc.setFont('helvetica', 'normal');
    const valueW = doc.getTextWidth(value);
    doc.text(value, headerRightX, headerY, { align: 'right' });
    doc.setFont('helvetica', 'bold');
    doc.text(label, headerRightX - valueW, headerY, { align: 'right' });
    headerY += headerLineStep;
  };

  if (dealerNo) {
    drawHeaderRow('Dealer No: ', String(dealerNo));
  }
  drawHeaderRow('Date: ', dateStr);
  drawHeaderRow('Valid until: ', validUntilStr);
  drawHeaderRow('Salesperson: ', sellerName ?? 'System');

  yPos += logoDrawn ? logoSlotH : 14;

  // —— Details. Left: Dealer, Dealer User, Phone, Address, Notas. Right: caja con Project, Customer, Contact, Description. ——
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  const spacingPx = 7;
  const spacingMm = (spacingPx / 72) * 25.4;
  const interlinePx = 5;
  const interlineMm = (interlinePx / 72) * 25.4;
  const lineHeightMm = 4;

  let leftY = yPos;
  doc.setFont('helvetica', 'bold');
  doc.text('Dealer:', marginX, leftY);
  doc.setFont('helvetica', 'normal');
  const dealerLabelW = doc.getTextWidth('Dealer: ');
  doc.text(dealerName ?? 'N/A', marginX + dealerLabelW + spacingMm, leftY);
  leftY += lineHeightMm + interlineMm;

  doc.setFont('helvetica', 'bold');
  doc.text('Dealer User:', marginX, leftY);
  doc.setFont('helvetica', 'normal');
  const dealerUserLabelW = doc.getTextWidth('Dealer User: ');
  doc.text(dealerUser ?? 'N/A', marginX + dealerUserLabelW + spacingMm, leftY);
  leftY += lineHeightMm + interlineMm;

  if (dealerPhone) {
    doc.setFont('helvetica', 'bold');
    doc.text('Phone:', marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.text(dealerPhone, marginX + doc.getTextWidth('Phone: ') + spacingMm, leftY);
    leftY += lineHeightMm + interlineMm;
  }
  leftY += (7 / 96) * 25.4;
  doc.setFont('helvetica', 'bold');
  doc.text('Address', marginX, leftY);
  leftY += lineHeightMm + interlineMm;
  doc.setFont('helvetica', 'normal');
  const addressInterlineMm = (5 / 72) * 25.4;
  const addressLineHeightMm = (9 / 72) * 25.4;
  const addressLines = doc.splitTextToSize(dealerAddress ?? 'N/A', usableWidth / 2);
  addressLines.forEach((line: string) => {
    doc.text(line, marginX, leftY);
    leftY += addressLineHeightMm + addressInterlineMm;
  });
  doc.setFontSize(9);
  leftY += 4;
  if (description && String(description).trim()) {
    doc.setFont('helvetica', 'bold');
    const descLabel = 'Notas: ';
    const descLabelW = doc.getTextWidth(descLabel);
    doc.text(descLabel, marginX, leftY);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const descTextWidth = usableWidth / 2 - descLabelW - spacingMm;
    const descLines = doc.splitTextToSize(String(description).trim(), descTextWidth);
    const descX = marginX + descLabelW + spacingMm;
    descLines.forEach((line: string) => {
      doc.text(line, descX, leftY);
      leftY += addressLineHeightMm + addressInterlineMm;
    });
    leftY += addressInterlineMm;
    doc.setFontSize(9);
  }
  const leftBlockEndY = leftY;

  const boxLeft = marginX + usableWidth / 2 - 3;
  const boxWidth = usableWidth / 2 + 3;
  const boxTopY = yPos + 17; // recuadro 17 mm más abajo
  const boxRowH = 6;
  const boxLabelX = boxLeft + 3;
  const boxValueX = boxLeft + 28;
  const boxDescW = boxWidth - 31;
  const descStr = (quote.description && String(quote.description).trim()) ? String(quote.description).trim() : '—';
  doc.setFontSize(9);
  const boxDescLines = doc.splitTextToSize(descStr, boxDescW);
  const hasPoNumber = poNumber && String(poNumber).trim().length > 0;
  const boxContentH = 4 + boxRowH * 3 + 4 + Math.max(boxRowH, boxDescLines.length * 4);
  const boxHeight = Math.max(boxRowH * 4 + 4, boxContentH);
  const boxRadiusMm = 2;
  doc.setDrawColor(140, 140, 140); // línea gris
  doc.setLineWidth(0.25);
  doc.roundedRect(boxLeft, boxTopY, boxWidth, boxHeight, boxRadiusMm, boxRadiusMm, 'S');
  doc.setDrawColor(0, 0, 0);

  doc.setFontSize(9);
  let boxY = boxTopY + 7;
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(120, 120, 120);
  doc.text('Project Detail', boxLabelX, boxY);
  doc.setTextColor(0, 0, 0);
  if (hasPoNumber) {
    doc.setFont('helvetica', 'bold');
    doc.text(String(poNumber).trim(), boxLeft + boxWidth - 3, boxY, { align: 'right' });
  }
  doc.setFontSize(9);
  boxY += boxRowH;
  doc.setFont('helvetica', 'bold');
  doc.text('Customer :', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  doc.text(customer?.customer_name ?? '—', boxValueX, boxY);
  boxY += boxRowH;
  doc.setFont('helvetica', 'bold');
  doc.text('Contact :', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  doc.text(contact?.contact_name ?? contact?.contact_email ?? '—', boxValueX, boxY);
  boxY += boxRowH;
  doc.setFont('helvetica', 'bold');
  doc.text('Description:', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  boxDescLines.forEach((ln: string) => {
    doc.text(ln, boxValueX, boxY);
    boxY += 4;
  });

  const rightBlockEndY = Math.max(leftBlockEndY, boxTopY + boxHeight);

  // —— Table: same as Proposal (grey header, same columns and columnStyles) ——
  const gapBeforeTableMm = 8;
  yPos = rightBlockEndY + gapBeforeTableMm;

  const buildDescription = (line: QuotePDFLine): string => {
    const skuCode = line.sku?.trim() || '';
    const catalogCode = line.catalog_code?.trim() || line.CatalogItems?.sku?.trim() || '';
    const ptCode = String(line.product_type ?? '').trim().toLowerCase();
    const isCatalog = ptCode === 'catalog';
    const isService = ptCode === 'service';
    const singleCode = isCatalog
      ? (catalogCode || skuCode)
      : (skuCode || catalogCode);
    const codeLine = singleCode || '';

    if (isService) {
      return (line as any).service_name?.trim() || line.sku?.trim() || '—';
    }

    const ptLower = String(line.product_type ?? '').trim().toLowerCase();
    const isDrapery = ptLower === 'drapery' || ptLower.includes('drapery');
    const isDraperyTrackOnly = isDrapery && !!line.track_only;
    const styleLabel = formatDraperyStyleLabel({
      productLine: line.product_line,
      styleCode: line.style_code,
    });
    if (isDraperyTrackOnly) {
      const trackName = formatDraperyTrackDescription({
        productLine: line.product_line,
        styleCode: line.style_code,
      });
      return codeLine ? `${trackName}\n${codeLine}` : trackName;
    }

    // Catalog items: show item name + optional color (no collection/variant/drive)
    if (isCatalog) {
      const catName =
        line.catalog_name?.trim()
        || line.CatalogItems?.item_name?.trim()
        || line.CatalogItems?.name?.trim()
        || '';
      const catColor =
        (line.catalog_color ?? line.CatalogItems?.color ?? '')?.toString().trim() ?? '';
      const sku = line.CatalogItems?.sku?.trim() ?? '';
      const head = catName
        ? (catColor ? `${catName} — ${catColor}` : catName)
        : sku || '—';
      return codeLine ? `${head}\n${codeLine}` : head;
    }

    const collectionVariant =
      line.collection_name && line.variant_name
        ? `${line.collection_name} - ${line.variant_name}`
        : line.collection_name ?? line.variant_name ?? '';
    const operatingSystem =
      line.operating_system_sku_name && line.operating_system_sku_name.trim()
        ? line.operating_system_sku_name.trim()
        : line.drive_type === 'motor'
          ? 'Motorized'
          : line.drive_type === 'manual'
            ? 'Manual'
            : '';
    const lines: string[] = [];
    if (collectionVariant) lines.push(collectionVariant);
    if (isDrapery && styleLabel) lines.push(`Style: ${styleLabel}`);
    if (operatingSystem) lines.push(operatingSystem);
    if (line.has_side_channel === true) lines.push('Side Channel: Yes');
    if (line.has_bottom_channel === true) lines.push('Bottom Channel: Yes');
    if (codeLine) lines.push(codeLine);
    return lines.join('\n') || '—';
  };

  const buildMeasurements = (line: QuotePDFLine): string => {
    const source: DimensionsSource = line.dimensions_source ?? {
      width_m: line.width_m,
      height_m: line.height_m,
    };
    return formatDimensionsForProposalPDF(source);
  };

  const W = {
    n: 7,
    area: 16,
    pos: 18,
    desc: 36,
    measurements: 26,
    productType: 21,
    qty: 11,
    unit: 25,
    total: 26,
  };

  const tableData = lines.map((line, index) => {
    const qty = line.qty || 1;
    const lineTotal =
      variant === 'dealer'
        ? line.line_total
        : clientDiscountPct > 0
          ? line.line_total * (1 - clientDiscountPct / 100)
          : line.line_total;
    const unitPrice = lineTotal / qty;
    const ptLower = String(line.product_type ?? '').trim().toLowerCase();
    const isDraperyTrackOnly =
      (ptLower === 'drapery' || ptLower.includes('drapery')) && !!line.track_only;
    const styleLabel = formatDraperyStyleLabel({
      productLine: line.product_line,
      styleCode: line.style_code,
    });
    const productTypeLabel = isDraperyTrackOnly
      ? (styleLabel ? `Drapery Track (${styleLabel})` : 'Drapery Track')
      : (line.product_type ?? line.CatalogItems?.item_name ?? '—');
    return [
      String(index + 1),
      line.area ?? '—',
      line.position ?? '—',
      buildDescription(line),
      buildMeasurements(line),
      productTypeLabel,
      String(qty),
      formatCurrency(unitPrice, quote.currency),
      formatCurrency(lineTotal, quote.currency),
    ];
  });

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'Area', 'Position', 'Description', 'Measurements', 'Product type', 'Qty', 'Unit Price', 'Line total']],
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
      cellPadding: { top: 2, bottom: 2, left: 2, right: 2 },
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
        cellPadding: { top: 4, bottom: 4, left: 4, right: 4 },
        minCellHeight: 20,
      },
      4: {
        cellWidth: W.measurements,
        halign: 'left',
        valign: 'middle',
        overflow: 'linebreak',
        fontSize: 8,
        cellPadding: { top: 3, bottom: 3, left: 4, right: 2 },
        minCellHeight: 20,
      },
      5: { cellWidth: W.productType, halign: 'center', valign: 'middle' },
      6: { cellWidth: W.qty, halign: 'center', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 0, right: 0 } },
      7: { cellWidth: W.unit, halign: 'right', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 0, right: 2 } },
      8: { cellWidth: W.total, halign: 'right', valign: 'middle', overflow: 'visible', cellPadding: { top: 3, bottom: 3, left: 1, right: 2 } },
    },
    didParseCell: (data: any) => {
      if (data.section === 'head') {
        data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        data.cell.styles.overflow = 'visible';
        if (data.column.index === 3) data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 4, right: 2 }; // Description: +2mm a la derecha
        if (data.column.index === 2) data.cell.styles.halign = 'center';
        if (data.column.index === 4) {
          data.cell.styles.halign = 'center';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        }
        if (data.column.index === 5) { data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 1, right: 0 }; }
        if (data.column.index === 6) { data.cell.styles.halign = 'center'; data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 0, right: 0 }; }
        if (data.column.index === 7) {
          data.cell.styles.halign = 'right';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        }
        if (data.column.index === 8) {
          data.cell.styles.halign = 'right';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        }
      }
      if (data.section === 'body') {
        const raw = data.cell.raw;
        const text = Array.isArray(raw) ? (raw as string[]).join('\n') : String(raw ?? '');
        const lineCount = (text.match(/\n/g) || []).length + 1;
        if (data.column.index === 3) {
          data.cell.styles.minCellHeight = Math.max(20, 8 + Math.min(3, lineCount) * 6);
        } else if (data.column.index === 4) {
          data.cell.styles.halign = 'left';
          data.cell.styles.minCellHeight = Math.max(20, 8 + lineCount * 5);
          if (typeof raw === 'string' && raw.includes('\n')) {
            data.cell.text = raw.split('\n');
          }
        }
      }
    },
    didDrawCell: (data: any) => {
      if (data.section !== 'body') return;
      doc.setDrawColor(200, 200, 200);
      doc.setLineWidth(0.25);
      doc.line(data.cell.x, data.cell.y + data.cell.height, data.cell.x + data.cell.width, data.cell.y + data.cell.height);
    },
  });

  const finalY = (doc as any).lastAutoTable.finalY || yPos + 50;
  const gapAfterTable = 8;
  const minSpaceForSummaryBlock = 45; // heading + summary table + terms start
  const spaceLeft = pageHeight - marginBottom - finalY;
  let sectionStartY: number;
  if (spaceLeft < minSpaceForSummaryBlock) {
    doc.addPage();
    sectionStartY = marginTop;
  } else {
    sectionStartY = finalY + gapAfterTable;
  }

  // —— Terms (left) + Summary (right): same layout as Proposal ——
  const summaryWidth = 62;
  const termsWidth = usableWidth - summaryWidth - 8;
  const summaryLeft = marginX + termsWidth + 8;

  const subtotal = quote.totals?.subtotal ?? lines.reduce((s, l) => s + (l.line_total ?? 0), 0);
  const taxAmount = exempt_tax ? 0 : (quote.totals?.tax_total ?? 0);
  const total = exempt_tax ? subtotal : (quote.totals?.total ?? subtotal + taxAmount);
  const toPctDisplay = (v: number | null | undefined): number | null =>
    v != null ? (v > 0 && v <= 1 ? Math.round(v * 100) : Math.round(v)) : null;
  const taxPctLabel = (() => {
    const n = toPctDisplay(tax_pct);
    return n != null ? ` (${n}%)` : '';
  })();

  const summaryData: [string, string][] = [
    ['Subtotal:', formatCurrency(subtotal, quote.currency)],
    ...(exempt_tax ? [] : [['Tax' + taxPctLabel, formatCurrency(taxAmount, quote.currency)] as [string, string]]),
    ['Total:', formatCurrency(total, quote.currency)],
  ];

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
    didDrawCell: (data: any) => {
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

  // Terms block starts 30px below Summary + extra 10mm.
  const summaryFinalY = (doc as any).lastAutoTable?.finalY ?? sectionStartY;
  const thirtyPxMm = (30 / 96) * 25.4;
  const extraDropMm = 10;
  let termsStartY = summaryFinalY + thirtyPxMm + extraDropMm;
  if (termsStartY > pageHeight - marginBottom - 20) {
    doc.addPage();
    termsStartY = marginTop;
  }

  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  const termsHeading = (quote as { terms_title?: string | null }).terms_title?.trim() || 'Terms and Conditions';
  doc.text(termsHeading, marginX, termsStartY);
  let termsContentY = termsStartY + 6;
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  const termsBody = (quote as { terms_content?: string | null }).terms_content?.trim() || '';
  const termsToUse = termsBody || 'No terms configured.';
  // Full-width terms block under summary to avoid half-column appearance.
  const termsLines = doc.splitTextToSize(termsToUse, usableWidth);
  termsLines.forEach((line: string) => {
    if (termsContentY > pageHeight - marginBottom - 15) {
      doc.addPage();
      termsContentY = marginTop;
    }
    doc.text(line, marginX, termsContentY);
    termsContentY += 4;
  });

  const pageCount = (doc as any).internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    doc.text(`${i} / ${pageCount}`, pageWidth / 2, pageHeight - marginBottom + 4, { align: 'center' });
  }

  return doc;
}
