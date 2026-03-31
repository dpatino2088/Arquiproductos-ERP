import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

type JsPDFX = jsPDF & { setLineDashPattern(d: number[], p: number): void };

export interface DraperyWorkOrderData {
  moNumber: string;
  sku: string;
  itemName: string;
  customerName?: string;
  soNumber?: string;
  productName?: string;
  materials?: Array<{ sku: string; item_name: string; component_role: string; qty: number; uom: string }>;
  date: string;

  productWidthMm: number;
  productHeightMm: number;
  cutWidthMm: number;
  cutHeightMm: number;
  rollWidthMm: number;

  rule: {
    tube_wrap_mm: number;
    bottom_wrap_mm: number;
    safety_margin_mm: number;
    top_hem_mm: number;
    bottom_hem_mm: number;
    side_hem_mm: number;
    panel_multiplier: number;
    fullness_factor: number;
    heatseal_price_per_m: number;
    waste_pct: number;
    bottom_bar_wrap_pct: number;
  };

  heatsealDirection: 'horizontal' | 'vertical' | 'none';
}

export function generateDraperyWorkOrderPDF(data: DraperyWorkOrderData): jsPDF {
  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const mx = 10;
  const { rule } = data;
  let y = 10;

  // ── Precompute values ──
  const EDGE_TRIM_MM = 10;
  const usableRollW = data.rollWidthMm > 0 ? data.rollWidthMm - EDGE_TRIM_MM * 2 : 0;
  const numDrops = usableRollW > 0 ? Math.ceil(data.cutWidthMm / usableRollW) : 1;
  const hsDir = data.heatsealDirection;
  const canJoin = hsDir !== 'none' && rule.heatseal_price_per_m > 0;
  const needsJoin = numDrops > 1 && canJoin;
  const notFabricable = numDrops > 1 && hsDir === 'none';
  const lastDropUsed = data.cutWidthMm - (numDrops - 1) * usableRollW;

  const topZones: { label: string; mm: number; color: [number, number, number]; textColor: [number, number, number]; fold: boolean }[] = [];
  if (rule.safety_margin_mm > 0) topZones.push({ label: `Safety +${rule.safety_margin_mm}mm`, mm: rule.safety_margin_mm, color: [254, 243, 199], textColor: [146, 64, 14], fold: false });
  if (rule.tube_wrap_mm > 0) topZones.push({ label: `Tube wrap +${rule.tube_wrap_mm}mm`, mm: rule.tube_wrap_mm, color: [224, 231, 255], textColor: [55, 48, 163], fold: true });
  if (rule.top_hem_mm > 0) topZones.push({ label: `Top hem +${rule.top_hem_mm}mm`, mm: rule.top_hem_mm, color: [209, 250, 229], textColor: [6, 95, 70], fold: true });
  const topMm = topZones.reduce((s, z) => s + z.mm, 0);

  const botZones: typeof topZones = [];
  if (rule.bottom_wrap_mm > 0) botZones.push({ label: `Bottom wrap +${rule.bottom_wrap_mm}mm`, mm: rule.bottom_wrap_mm, color: [224, 231, 255], textColor: [55, 48, 163], fold: true });
  if (rule.bottom_hem_mm > 0) botZones.push({ label: `Bottom hem +${rule.bottom_hem_mm}mm`, mm: rule.bottom_hem_mm, color: [209, 250, 229], textColor: [6, 95, 70], fold: true });
  const botMm = botZones.reduce((s, z) => s + z.mm, 0);
  const visibleMm = data.cutHeightMm - topMm - botMm;
  const hasSideHems = rule.side_hem_mm > 0;

  // ── Header ──
  const styleLabel = data.productName || 'Drapery';
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text(`${data.moNumber} · ${styleLabel} · ${data.productWidthMm}×${data.productHeightMm}mm`, mx, y + 4);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(120);
  doc.text(`${data.sku} — ${data.itemName}`, mx, y + 9);
  doc.setTextColor(0);

  doc.setFontSize(8);
  doc.setTextColor(100);
  const rightInfo: string[] = [];
  if (data.soNumber) rightInfo.push(`SO: ${data.soNumber}`);
  if (data.customerName) rightInfo.push(data.customerName);
  rightInfo.push(data.date);
  doc.text(rightInfo.join('  ·  '), pageW - mx, y + 4, { align: 'right' });
  doc.setTextColor(0);

  y += 12;
  doc.setDrawColor(200);
  doc.setLineWidth(0.3);
  doc.line(mx, y, pageW - mx, y);
  y += 3;

  // ── FLAT PATTERN DIAGRAM (full width) ──
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(100);
  doc.text('FLAT PATTERN', mx, y + 3);
  doc.setTextColor(0);
  y += 6;

  const diagMarginL = 18;
  const diagMarginR = 22;
  const diagMarginB = 12;
  const availDiagW = pageW - mx * 2 - diagMarginL - diagMarginR;
  const maxDiagH = 70;

  const panelRatio = data.cutWidthMm / (data.cutHeightMm || 1);
  let rectW: number, rectH: number;
  if (panelRatio > 1) {
    rectW = Math.min(availDiagW, 160);
    rectH = Math.max(rectW / panelRatio, 25);
  } else {
    rectH = Math.min(maxDiagH, 65);
    rectW = Math.max(rectH * panelRatio, 30);
  }
  if (rectH > maxDiagH) {
    rectH = maxDiagH;
    rectW = Math.max(rectH * panelRatio, 30);
  }

  const diagX = mx + diagMarginL + (availDiagW - rectW) / 2;
  const diagY = y;
  const pxPerMm = rectH / data.cutHeightMm;
  const sideHemPx = hasSideHems ? Math.max(rectW * 0.06, 4) : 0;

  // Outer dashed rect
  doc.setDrawColor(156, 163, 175);
  doc.setLineWidth(0.4);
  (doc as JsPDFX).setLineDashPattern([2, 1.2], 0);
  doc.rect(diagX, diagY, rectW, rectH);
  (doc as JsPDFX).setLineDashPattern([], 0);

  // Top zones
  let zY = diagY;
  for (const z of topZones) {
    const h = z.mm * pxPerMm;
    doc.setFillColor(z.color[0], z.color[1], z.color[2]);
    doc.rect(diagX + 0.3, zY + 0.3, rectW - 0.6, h, 'F');
    if (z.fold) {
      doc.setDrawColor(z.textColor[0], z.textColor[1], z.textColor[2]);
      doc.setLineWidth(0.3);
      (doc as JsPDFX).setLineDashPattern([1.5, 1], 0);
      doc.line(diagX, zY + h, diagX + rectW, zY + h);
      (doc as JsPDFX).setLineDashPattern([], 0);
    }
    if (h > 3) {
      doc.setFontSize(5.5);
      doc.setTextColor(z.textColor[0], z.textColor[1], z.textColor[2]);
      doc.text(z.label, diagX + rectW / 2, zY + h / 2 + 1.2, { align: 'center' });
    }
    zY += h;
  }

  // Visible area
  const visY = diagY + topMm * pxPerMm;
  const visH = visibleMm * pxPerMm;
  doc.setFillColor(239, 246, 255);
  doc.setDrawColor(59, 130, 246);
  doc.setLineWidth(0.5);
  doc.rect(diagX + sideHemPx, visY, rectW - sideHemPx * 2, visH, 'FD');
  doc.setFontSize(7);
  doc.setTextColor(29, 78, 216);
  doc.setFont('helvetica', 'bold');
  doc.text('Visible Area', diagX + rectW / 2, visY + visH / 2 - 2, { align: 'center' });
  doc.setFontSize(6.5);
  doc.text(`${data.productHeightMm}mm`, diagX + rectW / 2, visY + visH / 2 + 2.5, { align: 'center' });
  doc.setFont('helvetica', 'normal');

  // Side hems
  if (hasSideHems) {
    doc.setFillColor(209, 250, 229);
    doc.rect(diagX + 0.3, visY, sideHemPx, visH, 'F');
    doc.rect(diagX + rectW - sideHemPx - 0.3, visY, sideHemPx, visH, 'F');
    doc.setDrawColor(6, 95, 70);
    doc.setLineWidth(0.3);
    (doc as JsPDFX).setLineDashPattern([1, 0.8], 0);
    doc.line(diagX + sideHemPx, visY, diagX + sideHemPx, visY + visH);
    doc.line(diagX + rectW - sideHemPx, visY, diagX + rectW - sideHemPx, visY + visH);
    (doc as JsPDFX).setLineDashPattern([], 0);
    doc.setFontSize(5);
    doc.setTextColor(6, 95, 70);
    doc.text(`${rule.side_hem_mm}mm`, diagX + sideHemPx / 2, visY + visH / 2 + 0.5, { align: 'center', angle: 90 });
  }

  // Bottom zones
  let bY = diagY + rectH - botMm * pxPerMm;
  for (const z of botZones) {
    const h = z.mm * pxPerMm;
    doc.setFillColor(z.color[0], z.color[1], z.color[2]);
    doc.rect(diagX + 0.3, bY + 0.3, rectW - 0.6, h, 'F');
    doc.setDrawColor(z.textColor[0], z.textColor[1], z.textColor[2]);
    doc.setLineWidth(0.3);
    (doc as JsPDFX).setLineDashPattern([1.5, 1], 0);
    doc.line(diagX, bY, diagX + rectW, bY);
    (doc as JsPDFX).setLineDashPattern([], 0);
    if (h > 3) {
      doc.setFontSize(5.5);
      doc.setTextColor(z.textColor[0], z.textColor[1], z.textColor[2]);
      doc.text(z.label, diagX + rectW / 2, bY + h / 2 + 1.2, { align: 'center' });
    }
    bY += h;
  }

  // Costura/join lines
  if (numDrops > 1 && hsDir === 'vertical') {
    for (let i = 1; i < numDrops; i++) {
      const joinX = diagX + ((i * usableRollW) / data.cutWidthMm) * rectW;
      if (joinX >= diagX + rectW) continue;
      doc.setDrawColor(245, 158, 11);
      doc.setLineWidth(0.6);
      (doc as JsPDFX).setLineDashPattern([1, 1.5], 0);
      doc.line(joinX, diagY + 1, joinX, diagY + rectH - 1);
      (doc as JsPDFX).setLineDashPattern([], 0);
      doc.setFontSize(5);
      doc.setTextColor(217, 119, 6);
      doc.setFont('helvetica', 'bold');
      doc.text('COSTURA', joinX, diagY - 1.5, { align: 'center' });
      doc.setFont('helvetica', 'normal');
    }
  }
  if (numDrops > 1 && hsDir === 'horizontal') {
    for (let i = 1; i < numDrops; i++) {
      const dropFromBot = i * usableRollW;
      const remTop = data.cutHeightMm - dropFromBot;
      if (remTop <= 0) continue;
      const joinY2 = diagY + (remTop / data.cutHeightMm) * rectH;
      doc.setDrawColor(245, 158, 11);
      doc.setLineWidth(0.6);
      (doc as JsPDFX).setLineDashPattern([1, 1.5], 0);
      doc.line(diagX + 1, joinY2, diagX + rectW - 1, joinY2);
      (doc as JsPDFX).setLineDashPattern([], 0);
      doc.setFontSize(5);
      doc.setTextColor(217, 119, 6);
      doc.setFont('helvetica', 'bold');
      doc.text('HEATSEAL', diagX + rectW / 2, joinY2 - 1.5, { align: 'center' });
      doc.setFont('helvetica', 'normal');
    }
  }

  // Not fabricable overlay
  if (notFabricable) {
    doc.setFillColor(254, 242, 242);
    doc.setDrawColor(239, 68, 68);
    doc.setLineWidth(0.5);
    const bx = diagX + 4;
    const by2 = diagY + rectH / 2 - 4;
    doc.rect(bx, by2, rectW - 8, 8, 'FD');
    doc.setFontSize(6);
    doc.setTextColor(220, 38, 38);
    doc.setFont('helvetica', 'bold');
    doc.text('EXCEEDS ROLL — NOT FABRICABLE', diagX + rectW / 2, by2 + 5, { align: 'center' });
    doc.setFont('helvetica', 'normal');
  }

  // Right dimension arrow (total drop)
  const arrowX = diagX + rectW + 3;
  doc.setDrawColor(107, 114, 128);
  doc.setLineWidth(0.3);
  doc.line(arrowX, diagY, arrowX, diagY + rectH);
  doc.line(arrowX - 1.5, diagY, arrowX + 1.5, diagY);
  doc.line(arrowX - 1.5, diagY + rectH, arrowX + 1.5, diagY + rectH);
  doc.setFontSize(6.5);
  doc.setTextColor(55, 65, 81);
  doc.setFont('helvetica', 'bold');
  doc.text(`${Math.round(data.cutHeightMm)}mm`, arrowX + 2, diagY + rectH / 2 + 1);
  doc.setFont('helvetica', 'normal');

  // Bottom dimension arrow (panel width)
  const arrowY2 = diagY + rectH + 4;
  doc.setDrawColor(107, 114, 128);
  doc.line(diagX, arrowY2, diagX + rectW, arrowY2);
  doc.line(diagX, arrowY2 - 1.5, diagX, arrowY2 + 1.5);
  doc.line(diagX + rectW, arrowY2 - 1.5, diagX + rectW, arrowY2 + 1.5);
  doc.setFontSize(6.5);
  doc.setTextColor(55, 65, 81);
  doc.setFont('helvetica', 'bold');
  doc.text(`${Math.round(data.cutWidthMm)}mm panel width`, diagX + rectW / 2, arrowY2 + 4.5, { align: 'center' });
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(0);

  y = diagY + rectH + diagMarginB;

  // ── MODEL BANNER ──
  const modelLabel = data.productName?.split('·')[0]?.trim() || 'Drapery';
  const bannerH = 8;
  doc.setFillColor(55, 65, 81);
  doc.rect(mx, y, pageW - mx * 2, bannerH, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.setTextColor(255);
  doc.text(`MODEL:  ${modelLabel.toUpperCase()}`, mx + 4, y + 5.5);
  doc.setTextColor(0);
  y += bannerH + 4;

  // ── DATA SECTION (2-column layout below banner) ──
  doc.setDrawColor(210);
  doc.setLineWidth(0.2);
  doc.line(mx, y, pageW - mx, y);
  y += 3;

  const col1X = mx;
  const gap = 8;
  const colW = (pageW - mx * 2 - gap) / 2;
  const col2X = mx + colW + gap;
  const labelFs = 7.5;
  const valFs = 7.5;
  const lineH = 4.2;
  const sectionTitleFs = 8.5;

  function drawRow(x: number, yPos: number, label: string, value: string, opts?: { valueColor?: [number, number, number]; bold?: boolean; separator?: boolean }) {
    if (opts?.separator) {
      doc.setDrawColor(220);
      doc.setLineWidth(0.15);
      doc.line(x, yPos - 2.5, x + colW, yPos - 2.5);
    }
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(labelFs);
    doc.setTextColor(100);
    doc.text(label, x, yPos);
    doc.setFont('helvetica', opts?.bold ? 'bold' : 'normal');
    doc.setFontSize(valFs);
    const vc = opts?.valueColor ?? [30, 30, 30];
    doc.setTextColor(vc[0], vc[1], vc[2]);
    doc.text(value, x + colW, yPos, { align: 'right' });
    doc.setTextColor(0);
  }

  function drawSectionTitle(x: number, yPos: number, title: string) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(sectionTitleFs);
    doc.setTextColor(55, 65, 81);
    doc.text(title, x, yPos);
    doc.setTextColor(0);
  }

  // ── Left column: Drop Breakdown + Sewing Instructions ──
  let y1 = y;
  drawSectionTitle(col1X, y1, 'DROP BREAKDOWN');
  y1 += 5;
  drawRow(col1X, y1, 'Ordered height', `${data.productHeightMm} mm`, { bold: true });
  y1 += lineH;
  if (rule.tube_wrap_mm > 0) { drawRow(col1X, y1, '+ Tube wrap', `+${rule.tube_wrap_mm} mm`, { valueColor: [55, 48, 163] }); y1 += lineH; }
  if (rule.bottom_wrap_mm > 0) { drawRow(col1X, y1, '+ Bottom wrap', `+${rule.bottom_wrap_mm} mm`, { valueColor: [55, 48, 163] }); y1 += lineH; }
  if (rule.safety_margin_mm > 0) { drawRow(col1X, y1, '+ Safety margin', `+${rule.safety_margin_mm} mm`, { valueColor: [146, 64, 14] }); y1 += lineH; }
  if (rule.top_hem_mm > 0) { drawRow(col1X, y1, '+ Top hem', `+${rule.top_hem_mm} mm`, { valueColor: [6, 95, 70] }); y1 += lineH; }
  if (rule.bottom_hem_mm > 0) { drawRow(col1X, y1, '+ Bottom hem', `+${rule.bottom_hem_mm} mm`, { valueColor: [6, 95, 70] }); y1 += lineH; }
  if (rule.panel_multiplier > 1) { drawRow(col1X, y1, 'x Panel multiplier', `x${rule.panel_multiplier}`, { valueColor: [126, 34, 206] }); y1 += lineH; }
  y1 += 1;
  drawRow(col1X, y1, 'Total drop', `${Math.round(data.cutHeightMm)} mm`, { bold: true, separator: true });
  y1 += lineH + 3;

  // Sewing / Join (left column, below drop)
  if (numDrops > 1 && (needsJoin || notFabricable)) {
    drawSectionTitle(col1X, y1, 'SEWING / JOIN');
    y1 += 5;
    if (needsJoin) {
      let seamM = 0;
      if (hsDir === 'horizontal') seamM = data.cutWidthMm / 1000;
      else seamM = data.cutHeightMm / 1000;
      drawRow(col1X, y1, 'Type', hsDir === 'horizontal' ? 'Heatseal' : 'Costura / Sew');
      y1 += lineH;
      drawRow(col1X, y1, 'Direction', hsDir);
      y1 += lineH;
      drawRow(col1X, y1, `Seam ${hsDir === 'horizontal' ? 'width' : 'height'}`, `${seamM.toFixed(2)} m x ${numDrops - 1}`);
      y1 += lineH;
      drawRow(col1X, y1, 'Primary drop (bottom)', `${Math.round(usableRollW)} mm`, { valueColor: [29, 78, 216], bold: true });
      y1 += lineH;
      drawRow(col1X, y1, 'Secondary drop (top)', `${Math.round(lastDropUsed)} mm`, { valueColor: [146, 64, 14], bold: true });
      y1 += lineH;
    } else {
      doc.setFontSize(7);
      doc.setTextColor(220, 38, 38);
      doc.setFont('helvetica', 'bold');
      doc.text('EXCEEDS ROLL — NO JOIN CONFIGURED', col1X, y1);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(0);
      y1 += lineH;
    }
    y1 += 3;
  }

  // Sewing instructions (left column, below join)
  const hasSewingInfo = rule.top_hem_mm > 0 || rule.bottom_hem_mm > 0 || rule.side_hem_mm > 0;
  if (hasSewingInfo) {
    drawSectionTitle(col1X, y1, 'SEWING INSTRUCTIONS');
    y1 += 5;
    if (rule.top_hem_mm > 0) { drawRow(col1X, y1, 'Top hem fold', `${rule.top_hem_mm} mm`); y1 += lineH; }
    if (rule.bottom_hem_mm > 0) { drawRow(col1X, y1, 'Bottom hem fold', `${rule.bottom_hem_mm} mm`); y1 += lineH; }
    if (rule.side_hem_mm > 0) { drawRow(col1X, y1, 'Side hem fold (each side)', `${rule.side_hem_mm} mm`); y1 += lineH; }
  }

  // Column divider
  const divX = mx + colW + gap / 2;
  doc.setDrawColor(230);
  doc.setLineWidth(0.15);
  doc.line(divX, y - 1, divX, y + 80);

  // ── Right column: Width Breakdown + Waste ──
  let y2 = y;
  drawSectionTitle(col2X, y2, 'WIDTH BREAKDOWN');
  y2 += 5;
  drawRow(col2X, y2, 'Ordered width', `${data.productWidthMm} mm`, { bold: true });
  y2 += lineH;
  if (rule.fullness_factor > 1) { drawRow(col2X, y2, 'x Fullness', `x${rule.fullness_factor}`, { valueColor: [126, 34, 206] }); y2 += lineH; }
  if (hasSideHems) { drawRow(col2X, y2, '+ Side hems (x2)', `+${rule.side_hem_mm * 2} mm`, { valueColor: [6, 95, 70] }); y2 += lineH; }
  y2 += 1;
  drawRow(col2X, y2, 'Panel width', `${Math.round(data.cutWidthMm)} mm`, { bold: true, separator: true });
  y2 += lineH;
  drawRow(col2X, y2, 'Roll width', `${Math.round(data.rollWidthMm)} mm`);
  y2 += lineH;
  drawRow(col2X, y2, '- Edge trim (10mm x 2)', `-${EDGE_TRIM_MM * 2} mm`, { valueColor: [220, 38, 38] });
  y2 += lineH;
  drawRow(col2X, y2, 'Usable roll width', `${Math.round(usableRollW)} mm`, { bold: true });
  y2 += lineH;
  drawRow(col2X, y2, 'Drops needed', `${numDrops}`, { bold: true });
  y2 += lineH + 3;

  // Waste (right column, only if multi-drop)
  if (numDrops > 1) {
    const totalFabricArea = numDrops * data.rollWidthMm * data.cutHeightMm;
    const panelArea = data.cutWidthMm * data.cutHeightMm;
    const trimWaste = totalFabricArea - panelArea;
    const trimPct = totalFabricArea > 0 ? Math.round((trimWaste / totalFabricArea) * 100) : 0;
    drawSectionTitle(col2X, y2, 'WASTE');
    y2 += 5;
    drawRow(col2X, y2, 'Fabric used', `${(totalFabricArea / 1e6).toFixed(2)} m²`);
    y2 += lineH;
    drawRow(col2X, y2, 'Panel area', `${(panelArea / 1e6).toFixed(2)} m²`);
    y2 += lineH;
    drawRow(col2X, y2, 'Trim waste', `${(trimWaste / 1e6).toFixed(2)} m² (${trimPct}%)`, { valueColor: [220, 38, 38], bold: true });
  }

  // Move Y past tallest column
  let dataEndY = Math.max(y1, y2) + 6;

  // ── Materials Table (full width, from WorkOrderTaskLines) ──
  const mats = data.materials ?? [];
  if (mats.length > 0) {
    doc.setDrawColor(210);
    doc.setLineWidth(0.2);
    doc.line(mx, dataEndY, pageW - mx, dataEndY);
    dataEndY += 4;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(sectionTitleFs);
    doc.setTextColor(55, 65, 81);
    doc.text('MATERIALS & COMPONENTS', mx, dataEndY);
    doc.setTextColor(0);
    dataEndY += 3;

    autoTable(doc, {
      startY: dataEndY,
      margin: { left: mx, right: mx },
      head: [['SKU', 'Description', 'Role', 'Qty', 'UOM']],
      body: mats.map(m => [
        m.sku || '—',
        m.item_name || '—',
        m.component_role || '',
        m.uom === 'ea' ? m.qty : m.qty.toFixed(3),
        m.uom,
      ]),
      styles: { fontSize: 7, cellPadding: 1.8 },
      headStyles: { fillColor: [55, 65, 81], textColor: 255, fontStyle: 'bold', fontSize: 7 },
      alternateRowStyles: { fillColor: [249, 250, 251] },
      columnStyles: {
        0: { cellWidth: 30, fontStyle: 'bold' },
        3: { halign: 'right', cellWidth: 16 },
        4: { cellWidth: 14 },
      },
    });

    dataEndY = (doc as any).lastAutoTable?.finalY ?? dataEndY + 20;
    dataEndY += 4;
  }

  // ── Signature Lines ──
  const sigY = Math.min(dataEndY + 8, pageH - 22);
  doc.setDrawColor(180);
  doc.setLineWidth(0.3);
  doc.line(mx, sigY, mx + 55, sigY);
  doc.setFontSize(7);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(120);
  doc.text('Operator Signature', mx, sigY + 4);

  doc.line(pageW - mx - 55, sigY, pageW - mx, sigY);
  doc.text('Date / Time', pageW - mx - 55, sigY + 4);
  doc.setTextColor(0);

  // ── Footer ──
  doc.setFontSize(6);
  doc.setTextColor(160);
  doc.text(`Drapery Work Order — ${data.moNumber} — ${data.sku}`, mx, pageH - 5);
  doc.text('Page 1 of 1', pageW / 2, pageH - 5, { align: 'center' });
  doc.setTextColor(0);

  return doc;
}
