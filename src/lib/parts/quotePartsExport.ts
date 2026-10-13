/**
 * Quote part-list Excel export (Manufacturing > Parts).
 *
 * Builds a downloadable workbook with the quoted despiece of a job so
 * purchasing can be projected before any MO exists. Reads quantities from
 * ConfiguredProducts.bom_preview_snapshot (the quoted engineering BOM) and
 * never creates MOs, BOM instances, or touches prices.
 *
 * Fabric is reported BOTH ways:
 *  - linear meters (FabricRule consumption, same figure used for quoting)
 *  - nested roll purchase (same optimize2D nesting the MO purchase uses)
 */

import * as XLSX from 'xlsx';
import { supabase } from '../supabase/client';
import {
  computeNestPurchaseQty,
  rollLengthMmFromCatalog,
  type NestPanelCut,
} from '../fabricNestPurchase';

interface SnapshotItemMeta {
  roll_width_m?: number | null;
  roll_width?: number | null;
  variant_name?: string | null;
  collection_name?: string | null;
}

interface SnapshotItem {
  sku?: string | null;
  name?: string | null;
  role?: string | null;
  uom?: string | null;
  qty?: number | null;
  kind?: string | null; // 'roll' | 'parent' | 'child'
  selected?: boolean | null;
  catalog_item_id?: string | null;
  children?: SnapshotItem[] | null;
  meta?: SnapshotItemMeta | null;
}

interface SnapshotFabricCalc {
  fabric_cut_width_mm?: number | null;
  fabric_cut_height_mm?: number | null;
  consumption_qty?: number | null;
  consumption_uom?: string | null;
  drops?: number | null;
}

interface BomPreviewSnapshot {
  items?: SnapshotItem[] | null;
  totals?: { fabric_calc?: SnapshotFabricCalc | null } | null;
  product_type_id?: string | null;
}

interface QuoteLineRow {
  id: string;
  name: string | null;
  sku: string | null;
  quantity: number | null;
  width_m: number | null;
  height_m: number | null;
  area: string | null;
  position: string | null;
  product_type: string | null;
  product_type_id: string | null;
  custom_category: string | null;
  configured_product_id: string | null;
  collection_name: string | null;
  variant_name: string | null;
  drive_type: string | null;
  sort_order: number | null;
}

interface AggregatedPart {
  key: string;
  catalogItemId: string | null;
  sku: string;
  name: string;
  role: string;
  uom: string;
  qty: number;
  isFabric: boolean;
  rollWidthM: number | null;
  /** cuts for nesting, only populated for fabric parts */
  cuts: NestPanelCut[];
  productTypeIds: Set<string>;
}

function flattenSelectedItems(items: SnapshotItem[] | null | undefined): SnapshotItem[] {
  const out: SnapshotItem[] = [];
  const walk = (list: SnapshotItem[]) => {
    for (const item of list) {
      if (item.selected === false) {continue;}
      out.push(item);
      if (Array.isArray(item.children) && item.children.length > 0) {
        walk(item.children);
      }
    }
  };
  if (Array.isArray(items)) {walk(items);}
  return out;
}

function isFabricItem(item: SnapshotItem): boolean {
  const role = String(item.role ?? '').toLowerCase();
  const kind = String(item.kind ?? '').toLowerCase();
  return kind === 'roll' || role === 'fabric';
}

function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

export interface QuotePartsExportResult {
  ok: boolean;
  error?: string;
}

export async function exportQuotePartsExcel(quoteId: string): Promise<QuotePartsExportResult> {
  try {
    const { data: quoteRaw, error: quoteErr } = await supabase
      .from('Quotes')
      .select('id, organization_id, quote_no, status, created_at, dealer_id, customer_id, version_no, is_version')
      .eq('id', quoteId)
      .maybeSingle();
    if (quoteErr || !quoteRaw) {
      return { ok: false, error: quoteErr?.message ?? 'Quote not found' };
    }
    const quote = quoteRaw as {
      id: string;
      organization_id: string;
      quote_no: string | null;
      status: string | null;
      created_at: string | null;
      dealer_id: string | null;
      customer_id: string | null;
      version_no: number | null;
      is_version: boolean | null;
    };

    const [dealerRes, customerRes, linesRes, soRes] = await Promise.all([
      quote.dealer_id
        ? supabase.from('Dealers').select('id, dealer_name').eq('id', quote.dealer_id).maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      quote.customer_id
        ? supabase.from('DirectoryCustomers').select('id, customer_name').eq('id', quote.customer_id).maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      supabase
        .from('QuoteLines')
        .select('id, name, sku, quantity, width_m, height_m, area, position, product_type, product_type_id, custom_category, configured_product_id, collection_name, variant_name, drive_type, sort_order')
        .eq('quote_id', quoteId)
        .order('sort_order', { ascending: true, nullsFirst: false }),
      supabase
        .from('SalesOrders')
        .select('id, sales_order_no')
        .eq('quote_id', quoteId)
        .eq('deleted', false),
    ]);

    if (linesRes.error) {return { ok: false, error: linesRes.error.message };}
    const lines = (linesRes.data ?? []) as QuoteLineRow[];
    if (lines.length === 0) {return { ok: false, error: 'This quote has no lines to export' };}

    const dealerName = (dealerRes.data as { dealer_name?: string | null } | null)?.dealer_name ?? null;
    const customerName = (customerRes.data as { customer_name?: string | null } | null)?.customer_name ?? null;
    const salesOrders = (soRes.data ?? []) as { id: string; sales_order_no: string | null }[];

    // MOs linked through the SO — only to warn that production substitutions
    // are not reflected in this quoted despiece.
    let moNumbers: string[] = [];
    if (salesOrders.length > 0) {
      const { data: moRows } = await supabase
        .from('ManufacturingOrders')
        .select('id, manufacturing_order_no, sales_order_id')
        .in('sales_order_id', salesOrders.map((s) => s.id))
        .eq('deleted', false);
      moNumbers = ((moRows ?? []) as { manufacturing_order_no: string | null }[])
        .map((m) => m.manufacturing_order_no)
        .filter(Boolean) as string[];
    }

    const configuredLines = lines.filter((l) => l.configured_product_id);
    const customLines = lines.filter((l) => !l.configured_product_id);

    const cpIds = [...new Set(configuredLines.map((l) => l.configured_product_id as string))];
    const snapshotByCp = new Map<string, BomPreviewSnapshot>();
    if (cpIds.length > 0) {
      const { data: cpRows, error: cpErr } = await supabase
        .from('ConfiguredProducts')
        .select('id, bom_preview_snapshot')
        .in('id', cpIds);
      if (cpErr) {return { ok: false, error: cpErr.message };}
      for (const row of (cpRows ?? []) as { id: string; bom_preview_snapshot: BomPreviewSnapshot | null }[]) {
        if (row.bom_preview_snapshot) {snapshotByCp.set(row.id, row.bom_preview_snapshot);}
      }
    }

    // ------- Aggregate parts per SKU across every configured line -------
    const parts = new Map<string, AggregatedPart>();
    const linesWithoutSnapshot: QuoteLineRow[] = [];

    for (const line of configuredLines) {
      const snapshot = snapshotByCp.get(line.configured_product_id as string);
      if (!snapshot || !Array.isArray(snapshot.items) || snapshot.items.length === 0) {
        linesWithoutSnapshot.push(line);
        continue;
      }
      const lineQty = Math.max(Number(line.quantity ?? 1), 1);
      const fabricCalc = snapshot.totals?.fabric_calc ?? null;
      let fabricCalcUsed = false;

      for (const item of flattenSelectedItems(snapshot.items)) {
        const unitQty = Number(item.qty ?? 0);
        if (!Number.isFinite(unitQty) || unitQty <= 0) {continue;}
        const sku = String(item.sku ?? '').trim();
        const key = item.catalog_item_id ?? (sku || `${item.name ?? 'part'}|${item.role ?? ''}`);

        let part = parts.get(key);
        if (!part) {
          part = {
            key,
            catalogItemId: item.catalog_item_id ?? null,
            sku: sku || '—',
            name: String(item.name ?? '').trim() || '—',
            role: String(item.role ?? '').trim(),
            uom: String(item.uom ?? 'ea').trim() || 'ea',
            qty: 0,
            isFabric: isFabricItem(item),
            rollWidthM: null,
            cuts: [],
            productTypeIds: new Set<string>(),
          };
          parts.set(key, part);
        }
        part.qty += unitQty * lineQty;
        const ptId = line.product_type_id ?? snapshot.product_type_id ?? null;
        if (ptId) {part.productTypeIds.add(ptId);}

        if (part.isFabric) {
          const metaRollWidth = Number(item.meta?.roll_width_m ?? item.meta?.roll_width ?? 0);
          if (metaRollWidth > 0 && part.rollWidthM === null) {part.rollWidthM = metaRollWidth;}

          // One nest cut per product unit. The first fabric item of the line
          // uses fabric_calc dims (full cut incl. fullness/hems); any other
          // roll item falls back to product WxH.
          const useCalc = !fabricCalcUsed
            && fabricCalc !== null
            && Number(fabricCalc.fabric_cut_width_mm ?? 0) > 0
            && Number(fabricCalc.fabric_cut_height_mm ?? 0) > 0;
          if (useCalc) {fabricCalcUsed = true;}
          for (let u = 0; u < lineQty; u++) {
            part.cuts.push({
              bilId: `${line.id}-${part.key}-${u}`,
              cutLengthMm: useCalc ? Number(fabricCalc?.fabric_cut_width_mm) : null,
              cutHeightMm: useCalc ? Number(fabricCalc?.fabric_cut_height_mm) : null,
              productWidthM: line.width_m !== null ? Number(line.width_m) : null,
              productHeightM: line.height_m !== null ? Number(line.height_m) : null,
            });
          }
        }
      }
    }

    // ------- Fabric nesting (same engine as the MO purchase) -------
    const fabricParts = [...parts.values()].filter((p) => p.isFabric && p.cuts.length > 0);
    const fabricCatalogIds = [...new Set(fabricParts.map((p) => p.catalogItemId).filter(Boolean))] as string[];

    interface FabricCatalogRow {
      id: string;
      roll_width_m: number | null;
      roll_length_value: number | null;
      roll_length_uom: string | null;
      stock_length_mm: number | null;
    }
    const catalogMap = new Map<string, FabricCatalogRow>();
    if (fabricCatalogIds.length > 0) {
      const { data: ciRows } = await supabase
        .from('CatalogItems')
        .select('id, roll_width_m, roll_length_value, roll_length_uom, stock_length_mm')
        .in('id', fabricCatalogIds);
      for (const ci of (ciRows ?? []) as FabricCatalogRow[]) {
        catalogMap.set(ci.id, ci);
      }
    }

    const fabricProductTypeIds = [...new Set(fabricParts.flatMap((p) => [...p.productTypeIds]))];
    const ruleByPt = new Map<string, { allow_rotation: boolean; purchase_waste_pct: number; round_to_increment: number }>();
    if (fabricProductTypeIds.length > 0) {
      const { data: rulesRaw } = await supabase
        .from('FabricRules')
        .select('product_type_id, allow_rotation, purchase_waste_pct, round_to_increment, is_active')
        .eq('organization_id', quote.organization_id)
        .eq('is_active', true)
        .in('product_type_id', fabricProductTypeIds);
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

    const nestByPartKey = new Map<string, { nestUsedM: number; purchaseQty: number; rollCount: number; pieceCount: number }>();
    for (const part of fabricParts) {
      const ci = part.catalogItemId ? catalogMap.get(part.catalogItemId) : undefined;
      const rollWidthM = part.rollWidthM ?? (ci && ci.roll_width_m !== null ? Number(ci.roll_width_m) : null) ?? 2.8;
      const rollWidthMm = (rollWidthM > 0 ? rollWidthM : 2.8) * 1000;
      const rollLengthMm = rollLengthMmFromCatalog(ci);

      let allowRotation = true;
      let purchaseWastePct = 0.2;
      let roundToIncrement = 0.1;
      for (const pt of part.productTypeIds) {
        const rule = ruleByPt.get(pt);
        if (!rule) {continue;}
        if (!rule.allow_rotation) {allowRotation = false;}
        purchaseWastePct = rule.purchase_waste_pct;
        roundToIncrement = rule.round_to_increment;
      }

      const computed = computeNestPurchaseQty({
        cuts: part.cuts,
        rollWidthMm,
        rollLengthMm,
        allowRotation,
        purchaseWastePct,
        roundToIncrement,
      });
      nestByPartKey.set(part.key, {
        nestUsedM: computed.nestUsedM,
        purchaseQty: computed.purchaseQty,
        rollCount: computed.rollCount,
        pieceCount: computed.pieceCount,
      });
    }

    // ------- Workbook -------
    const quoteNo = quote.quote_no ?? quote.id.slice(0, 8);
    const soLabel = salesOrders.map((s) => s.sales_order_no).filter(Boolean).join(', ') || '—';
    const createdAt = quote.created_at ? new Date(quote.created_at).toLocaleDateString() : '—';

    const headerRows: (string | number | null)[][] = [
      ['Part List (quoted despiece)'],
      ['Quote', quoteNo],
      ['Status', quote.status ?? '—'],
      ['Created', createdAt],
      ['Dealer', dealerName ?? '—'],
      ['Customer', customerName ?? '—'],
      ['Sales Order', soLabel],
    ];
    if (moNumbers.length > 0) {
      headerRows.push([
        'Note',
        `Manufacturing order(s) ${moNumbers.join(', ')} exist for this job. This file reflects the QUOTED part list; substitutions made in production are not included.`,
      ]);
    }
    headerRows.push([]);

    const partColumns = [
      'SKU',
      'Description',
      'Role',
      'UOM',
      'Qty (quoted)',
      'Fabric: linear m',
      'Fabric: nested purchase (m)',
      'Fabric: rolls',
    ];
    const sortedParts = [...parts.values()].sort((a, b) => {
      if (a.isFabric !== b.isFabric) {return a.isFabric ? -1 : 1;}
      return a.sku.localeCompare(b.sku);
    });
    const partRows = sortedParts.map((p) => {
      const nest = nestByPartKey.get(p.key);
      return [
        p.sku,
        p.name,
        p.role || '—',
        p.uom,
        round3(p.qty),
        p.isFabric ? round3(p.qty) : null,
        p.isFabric && nest ? nest.purchaseQty : null,
        p.isFabric && nest ? nest.rollCount : null,
      ];
    });
    const partsSheet = XLSX.utils.aoa_to_sheet([...headerRows, partColumns, ...partRows]);
    partsSheet['!cols'] = [
      { wch: 18 }, { wch: 42 }, { wch: 14 }, { wch: 6 }, { wch: 12 }, { wch: 14 }, { wch: 22 }, { wch: 12 },
    ];

    const detailColumns = [
      '#',
      'Product',
      'Type',
      'Area',
      'Position',
      'Width (m)',
      'Height (m)',
      'Qty',
      'Collection',
      'Variant',
      'Drive',
      'Part list',
    ];
    const detailRows = lines.map((l, idx) => [
      idx + 1,
      l.name ?? l.sku ?? '—',
      l.product_type ?? (l.configured_product_id ? '—' : (l.custom_category ?? 'Custom')),
      l.area ?? '—',
      l.position ?? '—',
      l.width_m !== null ? Number(l.width_m) : null,
      l.height_m !== null ? Number(l.height_m) : null,
      Number(l.quantity ?? 1),
      l.collection_name ?? '—',
      l.variant_name ?? '—',
      l.drive_type ?? '—',
      l.configured_product_id
        ? (snapshotByCp.has(l.configured_product_id) ? 'Yes' : 'No snapshot')
        : 'No (custom)',
    ]);
    const detailSheet = XLSX.utils.aoa_to_sheet([detailColumns, ...detailRows]);
    detailSheet['!cols'] = [
      { wch: 4 }, { wch: 38 }, { wch: 18 }, { wch: 14 }, { wch: 12 }, { wch: 10 }, { wch: 10 },
      { wch: 6 }, { wch: 20 }, { wch: 20 }, { wch: 12 }, { wch: 12 },
    ];

    const customColumns = ['#', 'Description', 'Category', 'Area', 'Position', 'Width (m)', 'Height (m)', 'Qty'];
    const customRows = customLines.map((l, idx) => [
      idx + 1,
      l.name ?? l.sku ?? '—',
      l.custom_category ?? l.product_type ?? 'Custom',
      l.area ?? '—',
      l.position ?? '—',
      l.width_m !== null ? Number(l.width_m) : null,
      l.height_m !== null ? Number(l.height_m) : null,
      Number(l.quantity ?? 1),
    ]);
    const customSheet = XLSX.utils.aoa_to_sheet(
      customRows.length > 0
        ? [customColumns, ...customRows]
        : [customColumns, ['—', 'No custom lines on this quote', null, null, null, null, null, null]],
    );
    customSheet['!cols'] = [
      { wch: 4 }, { wch: 42 }, { wch: 18 }, { wch: 14 }, { wch: 12 }, { wch: 10 }, { wch: 10 }, { wch: 6 },
    ];

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, partsSheet, 'Parts');
    XLSX.utils.book_append_sheet(wb, detailSheet, 'Lines');
    XLSX.utils.book_append_sheet(wb, customSheet, 'Custom (no parts)');

    const safeQuoteNo = quoteNo.replace(/[^\w.-]+/g, '_');
    XLSX.writeFile(wb, `PartList_${safeQuoteNo}.xlsx`);

    if (linesWithoutSnapshot.length > 0) {
      return {
        ok: true,
        error: `${linesWithoutSnapshot.length} configured line(s) have no engineering snapshot and were listed without parts`,
      };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Export failed' };
  }
}
