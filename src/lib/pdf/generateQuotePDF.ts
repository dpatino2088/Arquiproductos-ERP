/**
 * Generate Quote PDF
 * Same format as Proposal PDF: logo slot (Arquiproducto) top-left, "Quote" + quote_no top-right,
 * Details: Customer, Contact, Address (left) | Date, Valid until, Salesperson (right).
 * Body: same table (#, Area, Position, Description, Measurements, Product type, Accessories, Qty, Unit Price, Line total) and summary.
 * Logo is always Arquiproducto (passed by caller from /images); no dealer logo link.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

export type PDFVariant = 'dealer' | 'client';

export interface QuotePDFLine {
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
  /** Optional: for table "Accessories" column */
  accessories?: string | null;
  CatalogItems?: {
    item_name?: string;
    sku?: string;
  } | null;
}

export interface QuotePDFData {
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
  /** ITBMS % for label e.g. "ITBMS (7%)" (0–1 or 0–100) */
  itbms_pct?: number | null;
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
    itbms_pct,
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
  const dateStr = new Date(quote.created_at).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
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
  const descStr = (quote.notes && String(quote.notes).trim()) ? String(quote.notes).trim() : '—';
  doc.setFontSize(9);
  const boxDescLines = doc.splitTextToSize(descStr, boxDescW);
  const boxContentH = 4 + boxRowH * 3 + 4 + Math.max(boxRowH, boxDescLines.length * 4);
  const boxHeight = Math.max(boxRowH * 4 + 4, boxContentH);
  const boxRadiusMm = 2;
  doc.setDrawColor(140, 140, 140); // línea gris
  doc.setLineWidth(0.25);
  doc.roundedRect(boxLeft, boxTopY, boxWidth, boxHeight, boxRadiusMm, boxRadiusMm, 'S');
  doc.setDrawColor(0, 0, 0);

  doc.setFontSize(9);
  let boxY = boxTopY + 7; // contenido 3 mm más abajo dentro del recuadro
  doc.setFont('helvetica', 'bold');
  doc.text('Project', boxLabelX, boxY);
  doc.setFont('helvetica', 'normal');
  doc.text(projectName ?? '—', boxValueX, boxY);
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
  const gapBeforeTableMm = 8 - (10 / 96) * 25.4;
  yPos = rightBlockEndY + gapBeforeTableMm - 7;

  const buildDescription = (line: QuotePDFLine): string => {
    const parts = [
      line.product_type ?? line.CatalogItems?.item_name ?? '—',
      line.collection_name && line.variant_name
        ? `${line.collection_name} - ${line.variant_name}`
        : line.collection_name ?? line.variant_name ?? '',
      line.drive_type === 'motor' ? 'Motorized' : line.drive_type === 'manual' ? 'Manual' : '',
    ].filter(Boolean);
    return parts.join(' | ') || '—';
  };

  const buildMeasurements = (line: QuotePDFLine): string => {
    if (line.width_m != null && line.height_m != null) {
      return `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)}`;
    }
    return '—';
  };

  const movePosLeftPx = 7;
  const movePosLeftMm = (movePosLeftPx / 96) * 25.4 + 5;
  const lineTotalShiftRightMm = 10;
  const productTypeAccQtyShiftRightMm = 10;
  const W = {
    n: 7,
    area: 11, // 5 mm menos para que Position quede 5 mm más a la izquierda
    pos: 18,
    desc: 38,
    measurements: 26,
    productType: 23, // +5 mm para mover Accessories y Qty 5 mm a la derecha
    acc: 20,
    qty: 9,
    unit: 24 + lineTotalShiftRightMm - productTypeAccQtyShiftRightMm,
    total: 22,
  };
  const descFlex = tableUsableWidth - (W.n + W.area + W.pos + W.measurements + W.productType + W.acc + W.qty + W.unit + W.total);
  (W as Record<string, number>).desc = Math.max(descFlex, 23);

  /** Trunca texto a máximo 2 líneas sin cortar palabras (aprox. 2.2 chars/mm a 8pt). */
  const truncateToTwoLines = (text: string, cellWidthMm: number): string => {
    const s = String(text ?? '').trim() || '—';
    if (!s || s === '—') return s;
    const maxCharsPerLine = Math.max(10, Math.floor(cellWidthMm * 2.2));
    const words = s.split(/\s+/);
    let line1 = '';
    let line2 = '';
    for (const w of words) {
      if (!line1) {
        line1 = w;
        continue;
      }
      const next1 = line1 + ' ' + w;
      if (next1.length <= maxCharsPerLine) {
        line1 = next1;
        continue;
      }
      if (!line2) {
        line2 = w;
        continue;
      }
      const next2 = line2 + ' ' + w;
      if (next2.length <= maxCharsPerLine) {
        line2 = next2;
        continue;
      }
      line2 = line2 + '...';
      break;
    }
    return line2 ? line1 + '\n' + line2 : line1;
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
    return [
      String(index + 1),
      line.area ?? '—',
      line.position ?? '—',
      truncateToTwoLines(buildDescription(line), W.desc),
      buildMeasurements(line),
      line.product_type ?? line.CatalogItems?.item_name ?? '—',
      line.accessories ?? '—',
      String(qty),
      formatCurrency(unitPrice, quote.currency),
      formatCurrency(lineTotal, quote.currency),
    ];
  });

  autoTable(doc, {
    startY: yPos,
    head: [['#', 'Area', 'Position', 'Description', 'Measurements', 'Product type', 'Accessories', 'Qty', 'Unit Price', 'Line total']],
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
        cellPadding: { top: 5, bottom: 5, left: 3, right: 3 },
        minCellHeight: 22,
      },
      4: { cellWidth: W.measurements, halign: 'center', valign: 'middle' },
      5: { cellWidth: W.productType, halign: 'center', valign: 'middle' },
      6: { cellWidth: W.acc, halign: 'left', valign: 'middle' },
      7: { cellWidth: W.qty, halign: 'right', valign: 'middle' },
      8: { cellWidth: W.unit, halign: 'right', valign: 'middle' },
      9: { cellWidth: W.total, halign: 'right', valign: 'middle', cellPadding: { top: 3, bottom: 3, left: 5, right: 5 } },
    },
    didParseCell: (data: any) => {
      if (data.section === 'head') {
        data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 2, right: 2 };
        data.cell.styles.overflow = 'visible'; // header en una sola línea, sin cortar palabras
        if (data.column.index === 2 || data.column.index === 4) data.cell.styles.halign = 'center';
        if (data.column.index === 7 || data.column.index === 8) data.cell.styles.halign = 'right';
        if (data.column.index === 9) {
          data.cell.styles.halign = 'right';
          data.cell.styles.cellPadding = { top: 2, bottom: 2, left: 5, right: 5 };
        }
      }
      if (data.section === 'body' && data.column.index === 3) {
        const raw = data.cell.raw;
        const text = Array.isArray(raw) ? (raw as string[]).join('\n') : String(raw ?? '');
        const lineCount = Math.min(2, (text.match(/\n/g) || []).length + 1);
        data.cell.styles.minCellHeight = Math.max(18, 8 + lineCount * 6);
      }
    },
    didDrawCell: (data: any) => {
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

  // —— Terms (left) + Summary (right): same layout as Proposal ——
  const summaryWidth = 62;
  const termsWidth = usableWidth - summaryWidth - 8;
  const summaryLeft = marginX + termsWidth + 8;
  const sectionStartY = yPos;

  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.text('Terms and Conditions', marginX, sectionStartY);
  let termsContentY = sectionStartY + 6;
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  const termsText = (quote.notes && String(quote.notes).trim()) ? String(quote.notes).trim() : '';
  const defaultTerms = [
    `• Any contract, payment or check must be issued to: ${organizationName.toUpperCase()}`,
    '• This quote is valid for thirty (30) business days from the date of issue.',
    '• A deposit of sixty percent (60%) of the total sale price will be required to confirm the order.',
    '• The remaining balance shall be paid upon delivery of the products.',
    '• Delivery times may vary depending on the product.',
  ].join(' ');
  const termsToUse = termsText || defaultTerms;
  const termsLines = doc.splitTextToSize(termsToUse, termsWidth);
  termsLines.forEach((line: string) => {
    if (termsContentY > pageHeight - marginBottom - 15) {
      doc.addPage();
      termsContentY = marginTop;
    }
    doc.text(line, marginX, termsContentY);
    termsContentY += 4;
  });

  const subtotal = quote.totals?.subtotal ?? lines.reduce((s, l) => s + (l.line_total ?? 0), 0);
  const itbmsAmount = quote.totals?.tax_total ?? 0;
  const total = quote.totals?.total ?? subtotal + itbmsAmount;
  const toPctDisplay = (v: number | null | undefined): number | null =>
    v != null ? (v > 0 && v <= 1 ? Math.round(v * 100) : Math.round(v)) : null;
  const itbmsPctLabel = (() => {
    const n = toPctDisplay(itbms_pct);
    return n != null ? ` (${n}%)` : '';
  })();

  const summaryData: [string, string][] = [
    ['Subtotal:', formatCurrency(subtotal, quote.currency)],
    ['ITBMS' + itbmsPctLabel, formatCurrency(itbmsAmount, quote.currency)],
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

  const pageCount = (doc as any).internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    doc.text(`${i} / ${pageCount}`, pageWidth / 2, pageHeight - marginBottom + 4, { align: 'center' });
  }

  return doc;
}
