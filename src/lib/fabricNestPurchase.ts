/**
 * Nest-based fabric purchase qty for Material Demand / PO.
 * Linear FabricRule qty (bil.qty) remains for quoting/cost only.
 */

import { supabase } from './supabase/client';
import { optimize2D, type FabricPiece } from './cutOptimizer2D';

export interface NestPanelCut {
  bilId: string;
  cutLengthMm: number | null;
  cutHeightMm: number | null;
  productWidthM?: number | null;
  productHeightM?: number | null;
  moId?: string;
  moNumber?: string;
}

export interface FabricPurchaseRow {
  organization_id: string;
  manufacturing_order_id: string;
  catalog_item_id: string;
  nest_used_m: number;
  purchase_waste_pct: number;
  purchase_qty: number;
  uom: string;
  piece_count: number;
  roll_count: number;
  efficiency_pct: number | null;
}

/** Split a panel into roll-width drops (same rules as CutOptimization). */
export function decomposePanelIntoDrops(
  cut: NestPanelCut,
  rollWidthMm: number,
): FabricPiece[] {
  const panelWidthMm = cut.cutLengthMm;
  const dropHeightMm = cut.cutHeightMm;

  const prodW = cut.productWidthM != null ? Math.round(cut.productWidthM * 1000) : null;
  const prodH = cut.productHeightM != null ? Math.round(cut.productHeightM * 1000) : null;

  if (!panelWidthMm || panelWidthMm <= 0 || !dropHeightMm || dropHeightMm <= 0) {
    const w = prodW ?? null;
    const h = prodH ?? null;
    if (!w || !h) return [];
    return [{
      id: `${cut.bilId}-d1`,
      widthMm: Math.min(w, rollWidthMm),
      heightMm: h,
      moId: cut.moId,
      moNumber: cut.moNumber,
      label: `${cut.moNumber ?? ''} · ${w}×${h}mm`,
    }];
  }

  if (panelWidthMm <= rollWidthMm) {
    return [{
      id: `${cut.bilId}-d1`,
      widthMm: panelWidthMm,
      heightMm: dropHeightMm,
      moId: cut.moId,
      moNumber: cut.moNumber,
      label: `${cut.moNumber ?? ''} · ${Math.round(panelWidthMm)}×${Math.round(dropHeightMm)}mm`,
    }];
  }

  const numDrops = Math.ceil(panelWidthMm / rollWidthMm);
  const remainder = panelWidthMm - (numDrops - 1) * rollWidthMm;
  const pieces: FabricPiece[] = [];

  for (let i = 0; i < numDrops; i++) {
    const isLastDrop = i === numDrops - 1;
    const dropW = isLastDrop ? remainder : rollWidthMm;
    pieces.push({
      id: `${cut.bilId}-d${i + 1}`,
      widthMm: dropW,
      heightMm: dropHeightMm,
      moId: cut.moId,
      moNumber: cut.moNumber,
      label: `${cut.moNumber ?? ''} · drop ${i + 1}`,
    });
  }
  return pieces;
}

function roundUpToIncrement(qty: number, increment: number): number {
  if (!Number.isFinite(qty) || qty <= 0) return 0;
  const inc = increment > 0 ? increment : 0.1;
  return Math.ceil(qty / inc - 1e-9) * inc;
}

export function computeNestPurchaseQty(params: {
  cuts: NestPanelCut[];
  rollWidthMm: number;
  rollLengthMm: number;
  allowRotation: boolean;
  purchaseWastePct: number;
  roundToIncrement: number;
}): {
  nestUsedM: number;
  purchaseQty: number;
  pieceCount: number;
  rollCount: number;
  efficiencyPct: number | null;
} {
  const {
    cuts,
    rollWidthMm,
    rollLengthMm,
    allowRotation,
    purchaseWastePct,
    roundToIncrement,
  } = params;

  const pieces = cuts.flatMap((c) => decomposePanelIntoDrops(c, rollWidthMm));
  if (pieces.length === 0 || rollWidthMm <= 0) {
    return { nestUsedM: 0, purchaseQty: 0, pieceCount: 0, rollCount: 0, efficiencyPct: null };
  }

  const result = optimize2D(
    pieces,
    rollWidthMm,
    Math.max(rollLengthMm, 1),
    allowRotation,
  );
  const nestUsedMm = result.rolls.reduce((s, r) => s + r.usedLengthMm, 0);
  const nestUsedM = nestUsedMm / 1000;
  const waste = Number.isFinite(purchaseWastePct) ? Math.max(0, purchaseWastePct) : 0.2;
  const rawPurchase = nestUsedM * (1 + waste);
  const purchaseQty = Math.round(roundUpToIncrement(rawPurchase, roundToIncrement) * 1000) / 1000;

  return {
    nestUsedM: Math.round(nestUsedM * 1000) / 1000,
    purchaseQty,
    pieceCount: result.totalPieces,
    rollCount: result.totalRolls,
    efficiencyPct: result.totalEfficiencyPct,
  };
}

function rollLengthMmFromCatalog(ci?: {
  roll_length_value?: number | null;
  roll_length_uom?: string | null;
  stock_length_mm?: number | null;
} | null): number {
  if (!ci) return 27400;
  const v = ci.roll_length_value != null ? Number(ci.roll_length_value) : null;
  const uom = (ci.roll_length_uom ?? '').toLowerCase();
  if (v != null && v > 0) {
    if (uom === 'yd') return v * 914.4;
    if (uom === 'm') return v * 1000;
    if (uom === 'ft') return v * 304.8;
  }
  if (ci.stock_length_mm != null && Number(ci.stock_length_mm) > 0) {
    return Number(ci.stock_length_mm);
  }
  return 27400;
}

/**
 * Recompute and persist nest-based purchase qty for all fabric SKUs on an MO.
 * Call after BOM generation and when Cut Plan refreshes.
 */
export async function recomputeMoFabricPurchase(moId: string): Promise<{ ok: boolean; rows: number; error?: string }> {
  if (!moId) return { ok: false, rows: 0, error: 'Missing manufacturing order id' };

  type MoRow = { id: string; organization_id: string; manufacturing_order_no: string | null };
  type BiRow = { id: string; sales_order_line_id: string | null };
  type BilRow = {
    id: string;
    bom_instance_id: string;
    resolved_part_id: string | null;
    part_role: string | null;
    cut_length_mm: number | null;
    cut_height_mm: number | null;
  };
  type CatalogRow = {
    id: string;
    roll_width_m: number | null;
    roll_length_value: number | null;
    roll_length_uom: string | null;
    stock_length_mm: number | null;
  };
  type SolRow = {
    id: string;
    product_type_id: string | null;
    configured_product_id: string | null;
    width_m?: number | null;
    height_m?: number | null;
  };

  const { data: moRaw, error: moErr } = await supabase
    .from('ManufacturingOrders')
    .select('id, organization_id, manufacturing_order_no')
    .eq('id', moId)
    .maybeSingle();
  const mo = moRaw as MoRow | null;
  if (moErr || !mo) {
    return { ok: false, rows: 0, error: moErr?.message ?? 'MO not found' };
  }

  const { data: instancesRaw, error: biErr } = await supabase
    .from('BOMInstances')
    .select('id, sales_order_line_id')
    .eq('manufacturing_order_id', moId)
    .eq('deleted', false);
  if (biErr) return { ok: false, rows: 0, error: biErr.message };
  const instances = (instancesRaw ?? []) as BiRow[];
  if (!instances.length) return { ok: true, rows: 0 };

  const instanceIds = instances.map((i: BiRow) => i.id);
  const solIds = [...new Set(instances.map((i: BiRow) => i.sales_order_line_id).filter(Boolean))] as string[];

  const { data: linesRaw, error: bilErr } = await supabase
    .from('BOMInstanceLines')
    .select('id, bom_instance_id, resolved_part_id, part_role, cut_length_mm, cut_height_mm, excluded, deleted')
    .in('bom_instance_id', instanceIds)
    .eq('deleted', false)
    .eq('excluded', false);
  if (bilErr) return { ok: false, rows: 0, error: bilErr.message };
  const lines = (linesRaw ?? []) as BilRow[];

  const fabricLines = lines.filter(
    (l: BilRow) => l.resolved_part_id && String(l.part_role ?? '').toLowerCase() === 'fabric',
  );
  if (fabricLines.length === 0) {
    await supabase
      .from('ManufacturingOrderFabricPurchase')
      .delete()
      .eq('manufacturing_order_id', moId);
    return { ok: true, rows: 0 };
  }

  const catalogIds = [...new Set(fabricLines.map((l: BilRow) => l.resolved_part_id as string))];
  const { data: catalogItemsRaw, error: ciErr } = await supabase
    .from('CatalogItems')
    .select('id, roll_width_m, roll_length_value, roll_length_uom, stock_length_mm')
    .in('id', catalogIds);
  if (ciErr) return { ok: false, rows: 0, error: ciErr.message };
  const catalogMap = new Map((catalogItemsRaw as CatalogRow[] | null ?? []).map((c) => [c.id, c]));

  // Product type per SOL for FabricRules (rotation / purchase_waste)
  const productTypeBySol = new Map<string, string>();
  if (solIds.length > 0) {
    const { data: solsRaw } = await supabase
      .from('SaleOrderLines')
      .select('id, product_type_id, configured_product_id')
      .in('id', solIds);
    const sols = (solsRaw ?? []) as SolRow[];
    const cpIds = [...new Set(sols.map((s) => s.configured_product_id).filter(Boolean))] as string[];
    const cpTypeMap = new Map<string, string>();
    if (cpIds.length > 0) {
      const { data: cpsRaw } = await supabase
        .from('ConfiguredProducts')
        .select('id, product_type_id')
        .in('id', cpIds);
      for (const c of (cpsRaw ?? []) as Array<{ id: string; product_type_id: string | null }>) {
        if (c.product_type_id) cpTypeMap.set(c.id, c.product_type_id);
      }
    }
    for (const s of sols) {
      const pt = s.product_type_id || (s.configured_product_id ? cpTypeMap.get(s.configured_product_id) : null);
      if (pt) productTypeBySol.set(s.id, pt);
    }
  }

  const instanceSolMap = new Map(instances.map((i: BiRow) => [i.id, i.sales_order_line_id]));
  const productTypeIds = [...new Set(productTypeBySol.values())];

  const ruleByPt = new Map<string, { allow_rotation: boolean; purchase_waste_pct: number; round_to_increment: number }>();
  if (productTypeIds.length > 0) {
    const { data: rulesRaw } = await supabase
      .from('FabricRules')
      .select('product_type_id, allow_rotation, purchase_waste_pct, round_to_increment, is_active')
      .eq('organization_id', mo.organization_id)
      .eq('is_active', true)
      .in('product_type_id', productTypeIds);
    for (const r of (rulesRaw ?? []) as Array<{
      product_type_id: string;
      allow_rotation: boolean | null;
      purchase_waste_pct: number | null;
      round_to_increment: number | null;
    }>) {
      ruleByPt.set(r.product_type_id, {
        allow_rotation: r.allow_rotation !== false,
        purchase_waste_pct: Number(r.purchase_waste_pct ?? 0.2),
        round_to_increment: Number(r.round_to_increment ?? 0.1),
      });
    }
  }

  type DimRow = { id: string; width_m: number | null; height_m: number | null };
  let solDims: DimRow[] = [];
  if (solIds.length > 0) {
    const { data: solDimsRaw } = await supabase
      .from('SaleOrderLines')
      .select('id, width_m, height_m')
      .in('id', solIds);
    solDims = (solDimsRaw ?? []) as DimRow[];
  }
  const dimsBySol = new Map(solDims.map((s) => [s.id, s]));

  type Group = {
    catalogItemId: string;
    cuts: NestPanelCut[];
    productTypeIds: Set<string>;
  };
  const groups = new Map<string, Group>();

  for (const line of fabricLines) {
    const catalogItemId = line.resolved_part_id as string;
    const solId = instanceSolMap.get(line.bom_instance_id) ?? null;
    const dims = solId ? dimsBySol.get(solId) : undefined;
    const pt = solId ? productTypeBySol.get(solId) : undefined;
    let g = groups.get(catalogItemId);
    if (!g) {
      g = { catalogItemId, cuts: [], productTypeIds: new Set() };
      groups.set(catalogItemId, g);
    }
    if (pt) g.productTypeIds.add(pt);
    g.cuts.push({
      bilId: line.id,
      cutLengthMm: line.cut_length_mm != null ? Number(line.cut_length_mm) : null,
      cutHeightMm: line.cut_height_mm != null ? Number(line.cut_height_mm) : null,
      productWidthM: dims?.width_m != null ? Number(dims.width_m) : null,
      productHeightM: dims?.height_m != null ? Number(dims.height_m) : null,
      moId: mo.id,
      moNumber: mo.manufacturing_order_no ?? undefined,
    });
  }

  const rows: FabricPurchaseRow[] = [];
  const now = new Date().toISOString();

  for (const g of groups.values()) {
    const ci = catalogMap.get(g.catalogItemId);
    const rollWidthMm = ((ci?.roll_width_m != null ? Number(ci.roll_width_m) : 2.8) || 2.8) * 1000;
    const rollLengthMm = rollLengthMmFromCatalog(ci);

    let allowRotation = true;
    let purchaseWastePct = 0.2;
    let roundToIncrement = 0.1;
    for (const pt of g.productTypeIds) {
      const rule = ruleByPt.get(pt);
      if (!rule) continue;
      if (!rule.allow_rotation) allowRotation = false;
      purchaseWastePct = rule.purchase_waste_pct;
      roundToIncrement = rule.round_to_increment;
    }

    const computed = computeNestPurchaseQty({
      cuts: g.cuts,
      rollWidthMm,
      rollLengthMm,
      allowRotation,
      purchaseWastePct,
      roundToIncrement,
    });

    if (computed.purchaseQty <= 0 && computed.nestUsedM <= 0) continue;

    rows.push({
      organization_id: mo.organization_id,
      manufacturing_order_id: moId,
      catalog_item_id: g.catalogItemId,
      nest_used_m: computed.nestUsedM,
      purchase_waste_pct: purchaseWastePct,
      purchase_qty: computed.purchaseQty,
      uom: 'm',
      piece_count: computed.pieceCount,
      roll_count: computed.rollCount,
      efficiency_pct: computed.efficiencyPct,
    });
  }

  // Replace all fabric purchase rows for this MO
  const { error: delErr } = await supabase
    .from('ManufacturingOrderFabricPurchase')
    .delete()
    .eq('manufacturing_order_id', moId);
  if (delErr) return { ok: false, rows: 0, error: delErr.message };

  if (rows.length === 0) return { ok: true, rows: 0 };

  const { error: upsertErr } = await supabase
    .from('ManufacturingOrderFabricPurchase')
    .insert(rows.map((r) => ({ ...r, updated_at: now })));
  if (upsertErr) return { ok: false, rows: 0, error: upsertErr.message };

  return { ok: true, rows: rows.length };
}
