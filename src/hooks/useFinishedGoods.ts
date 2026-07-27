import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FinishedGoodLine {
  line_type: 'product' | 'accessory';
  line_id: string;
  sales_order_id: string | null;
  manufacturing_order_id: string | null;
  manufacturing_order_no: string | null;
  mo_status: string | null;
  organization_id: string;
  delivery_status: string;
  quantity: number;
  delivered_qty: number;
  delivered_at: string | null;
  sales_order_no: string | null;
  dealer_name: string | null;
  customer_name: string | null;
  line_description: string | null;
  product_type: string | null;
  area: string | null;
  position: string | null;
  catalog_item_name: string | null;
  catalog_item_sku: string | null;
  released_at: string | null;
  claim_id: string | null;
}

export interface FinishedGoodsMOGroup {
  manufacturing_order_id: string;
  manufacturing_order_no: string;
  mo_status: string;
  lines: FinishedGoodLine[];
}

/** Outbound fulfillment of the SO (not payment). */
export type SoFulfillmentStatus = 'partial' | 'ready_for_delivery' | 'delivered';

export interface FinishedGoodsSOGroup {
  sales_order_id: string;
  sales_order_no: string;
  dealer_name: string | null;
  customer_name: string | null;
  mos: FinishedGoodsMOGroup[];
  accessories: FinishedGoodLine[];
  totalProductLines: number;
  deliveredProductLines: number;
  readyProductLines: number;
  totalAccessories: number;
  deliveredAccessories: number;
  hasServiceMOOnly: boolean;
  /** All manufacture + supply units on the SO (for Partial vs Ready). */
  soDeliverableTotal: number;
  soDeliverableReady: number;
  soDeliverableDelivered: number;
  soDeliverablePending: number;
  fulfillmentStatus: SoFulfillmentStatus;
}

interface SalesOrderLookupRow {
  id: string;
  sales_order_no: string | null;
  dealer_id: string | null;
  customer_id: string | null;
}

interface CatalogItemLookupRow {
  id: string;
  name: string | null;
  sku: string | null;
}

// Keep legacy export for backward compatibility
export type FinishedGoodsGroup = FinishedGoodsSOGroup;

export interface UseFinishedGoodsOptions {
  /**
   * When true, supply / MTM lines (bought or stocked products with no
   * Manufacturing Order) are folded into the groups so a single outbound
   * queue can dispatch every origin. Finished Goods (manufactured only)
   * leaves this off; the Inventory > Deliveries queue turns it on.
   */
  includeSupply?: boolean;
}

type SoProgress = { total: number; ready: number; delivered: number; pending: number };

function deriveFulfillmentStatus(p: SoProgress): SoFulfillmentStatus {
  if (p.total <= 0) return 'ready_for_delivery';
  if (p.delivered >= p.total && p.ready === 0) return 'delivered';
  // Partial: some ready now while others pending, or mid multi-wave shipment.
  if (p.ready > 0 && p.pending > 0) return 'partial';
  if (p.ready > 0 && p.delivered > 0) return 'partial';
  if (p.pending > 0 && p.delivered > 0) return 'partial';
  if (p.ready > 0) return 'ready_for_delivery';
  return 'delivered';
}

async function loadSoDeliverableProgress(
  organizationId: string,
  soIds: string[],
): Promise<Map<string, SoProgress>> {
  const map = new Map<string, SoProgress>();
  const bump = (soId: string, status: string) => {
    const cur = map.get(soId) ?? { total: 0, ready: 0, delivered: 0, pending: 0 };
    cur.total += 1;
    if (status === 'ready') cur.ready += 1;
    else if (status === 'delivered') cur.delivered += 1;
    else cur.pending += 1;
    map.set(soId, cur);
  };

  const { data: rpcProgress, error: rpcErr } = await supabase.rpc('get_so_deliverable_progress', {
    p_org_id: organizationId,
    p_so_ids: soIds,
  });
  if (!rpcErr && rpcProgress) {
    for (const row of rpcProgress as {
      sales_order_id: string;
      total_count: number;
      ready_count: number;
      delivered_count: number;
      pending_count: number;
    }[]) {
      map.set(row.sales_order_id, {
        total: Number(row.total_count ?? 0),
        ready: Number(row.ready_count ?? 0),
        delivered: Number(row.delivered_count ?? 0),
        pending: Number(row.pending_count ?? 0),
      });
    }
    return map;
  }

  const { data: ptRows } = await supabase
    .from('ProductTypes')
    .select('code, fulfillment_type')
    .eq('organization_id', organizationId);
  const fromPt = (ptRows ?? [])
    .filter((p: { fulfillment_type: string | null }) => p.fulfillment_type === 'supply_only')
    .map((p: { code: string }) => p.code);
  const supplyCodes = new Set(fromPt.length > 0 ? fromPt : ['catalog', 'service', 'window_film']);

  const { data: moRows } = await supabase
    .from('ManufacturingOrders')
    .select('id, sales_order_id')
    .eq('organization_id', organizationId)
    .eq('deleted', false)
    .in('sales_order_id', soIds);
  const moList = (moRows ?? []) as { id: string; sales_order_id: string }[];
  const moToSo = new Map(moList.map((m) => [m.id, m.sales_order_id]));
  const moIds = moList.map((m) => m.id);

  if (moIds.length > 0) {
    const { data: molRows } = await supabase
      .from('ManufacturingOrderLines')
      .select('id, manufacturing_order_id, delivery_status, sales_order_line_id, SaleOrderLines(product_type)')
      .eq('deleted', false)
      .in('manufacturing_order_id', moIds);
    for (const mol of (molRows ?? []) as {
      manufacturing_order_id: string;
      delivery_status: string | null;
      SaleOrderLines: { product_type: string | null } | { product_type: string | null }[] | null;
    }[]) {
      const sol = Array.isArray(mol.SaleOrderLines) ? mol.SaleOrderLines[0] : mol.SaleOrderLines;
      const pt = sol?.product_type ?? '';
      if (pt && supplyCodes.has(pt)) continue;
      const soId = moToSo.get(mol.manufacturing_order_id);
      if (!soId) continue;
      bump(soId, mol.delivery_status ?? 'pending');
    }
  }

  if (supplyCodes.size > 0) {
    const { data: solRows } = await supabase
      .from('SaleOrderLines')
      .select('id, sales_order_id, delivery_status, product_type')
      .eq('organization_id', organizationId)
      .or('deleted.eq.false,deleted.is.null')
      .in('sales_order_id', soIds)
      .in('product_type', [...supplyCodes])
      .not('catalog_item_id', 'is', null);
    for (const sol of (solRows ?? []) as {
      sales_order_id: string;
      delivery_status: string | null;
    }[]) {
      bump(sol.sales_order_id, sol.delivery_status ?? 'pending');
    }
  }

  return map;
}

export function useFinishedGoods(options?: UseFinishedGoodsOptions) {
  const includeSupply = options?.includeSupply ?? false;
  const { activeOrganizationId } = useOrganizationContext();
  const [groups, setGroups] = useState<FinishedGoodsSOGroup[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!activeOrganizationId) { setGroups([]); return; }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('finished_goods_by_so')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .order('released_at', { ascending: false, nullsFirst: false });
      let linesData: FinishedGoodLine[] = [];
      if (!err) {
        linesData = (data ?? []) as FinishedGoodLine[];
      } else if (err.message?.includes('finished_goods_by_so')) {
        // Fallback for environments where the view migration was not applied yet.
        const { data: molRows, error: molErr } = await supabase
          .from('ManufacturingOrderLines')
          .select(`
            id, manufacturing_order_id, delivery_status, quantity, delivered_qty, delivered_at,
            sales_order_line_id,
            ManufacturingOrders!inner (
              id, organization_id, manufacturing_order_no, status, sales_order_id, released_at, deleted, claim_id
            ),
            SaleOrderLines (
              id, description, product_type, area, position, catalog_item_id
            )
          `)
          .eq('deleted', false)
          .eq('ManufacturingOrders.organization_id', activeOrganizationId)
          .eq('ManufacturingOrders.deleted', false)
          .in('ManufacturingOrders.status', ['ready_for_pickup', 'delivered'])
          .in('delivery_status', ['ready', 'delivered']);
        if (molErr) throw new Error(molErr.message);

        const soIds = [...new Set((molRows ?? []).map((r: any) => r.ManufacturingOrders?.sales_order_id).filter(Boolean))];
        const solCatIds = [...new Set((molRows ?? []).map((r: any) => r.SaleOrderLines?.catalog_item_id).filter(Boolean))];

        const [{ data: soRows }, { data: catRows }, { data: accRows, error: accErr }] = await Promise.all([
          soIds.length > 0
            ? supabase.from('SalesOrders').select('id, sales_order_no, dealer_id, customer_id').in('id', soIds)
            : Promise.resolve({ data: [] as any[] }),
          solCatIds.length > 0
            ? supabase.from('CatalogItems').select('id, name, sku').in('id', solCatIds)
            : Promise.resolve({ data: [] as any[] }),
          supabase
            .from('SaleOrderAccessories')
            .select('id, sales_order_id, organization_id, delivery_status, qty, delivered_qty, delivered_at, catalog_item_id, deleted')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false),
        ]);
        if (accErr && !accErr.message?.includes('SaleOrderAccessories')) throw new Error(accErr.message);

        const dealerIds = [...new Set((soRows ?? []).map((s: any) => s.dealer_id).filter(Boolean))];
        const customerIds = [...new Set((soRows ?? []).map((s: any) => s.customer_id).filter(Boolean))];
        const accCatIds = [...new Set((accRows ?? []).map((a: any) => a.catalog_item_id).filter(Boolean))];
        const allCatIds = [...new Set([...solCatIds, ...accCatIds])];

        const [{ data: dealerRows }, { data: customerRows }, { data: allCatRows }] = await Promise.all([
          dealerIds.length > 0
            ? supabase.from('Dealers').select('id, dealer_name').in('id', dealerIds)
            : Promise.resolve({ data: [] as any[] }),
          customerIds.length > 0
            ? supabase.from('DirectoryCustomers').select('id, customer_name').in('id', customerIds)
            : Promise.resolve({ data: [] as any[] }),
          allCatIds.length > 0
            ? supabase.from('CatalogItems').select('id, name, sku').in('id', allCatIds)
            : Promise.resolve({ data: [] as any[] }),
        ]);

        const typedSoRows = (soRows ?? []) as SalesOrderLookupRow[];
        const soMap = new Map<string, SalesOrderLookupRow>(typedSoRows.map((s) => [s.id, s]));
        const dealerMap = new Map((dealerRows ?? []).map((d: any) => [d.id, d.dealer_name]));
        const customerMap = new Map((customerRows ?? []).map((c: any) => [c.id, c.customer_name]));
        const typedCatRows = ((allCatRows ?? catRows ?? []) as CatalogItemLookupRow[]);
        const catMap = new Map<string, CatalogItemLookupRow>(typedCatRows.map((c) => [c.id, c]));

        const productLines: FinishedGoodLine[] = (molRows ?? []).map((r: any) => {
          const mo = r.ManufacturingOrders;
          const sol = r.SaleOrderLines;
          const so = soMap.get(mo?.sales_order_id);
          const ci = catMap.get(sol?.catalog_item_id);
          return {
            line_type: 'product',
            line_id: r.id,
            sales_order_id: mo?.sales_order_id ?? null,
            manufacturing_order_id: mo?.id ?? null,
            manufacturing_order_no: mo?.manufacturing_order_no ?? null,
            mo_status: mo?.status ?? null,
            organization_id: mo?.organization_id ?? activeOrganizationId,
            delivery_status: r.delivery_status,
            quantity: Number(r.quantity ?? 0),
            delivered_qty: Number(r.delivered_qty ?? 0),
            delivered_at: r.delivered_at ?? null,
            sales_order_no: so?.sales_order_no ?? null,
            dealer_name: so?.dealer_id ? (dealerMap.get(so.dealer_id) ?? null) : null,
            customer_name: so?.customer_id ? (customerMap.get(so.customer_id) ?? null) : null,
            line_description: sol?.description ?? null,
            product_type: sol?.product_type ?? null,
            area: sol?.area ?? null,
            position: sol?.position ?? null,
            catalog_item_name: ci?.name ?? null,
            catalog_item_sku: ci?.sku ?? null,
            released_at: mo?.released_at ?? null,
            claim_id: mo?.claim_id ?? null,
          };
        });

        const accessoryLines: FinishedGoodLine[] = (accRows ?? []).map((a: any) => {
          const so = soMap.get(a.sales_order_id);
          const ci = catMap.get(a.catalog_item_id);
          return {
            line_type: 'accessory',
            line_id: a.id,
            sales_order_id: a.sales_order_id ?? null,
            manufacturing_order_id: null,
            manufacturing_order_no: null,
            mo_status: null,
            organization_id: a.organization_id ?? activeOrganizationId,
            delivery_status: a.delivery_status,
            quantity: Number(a.qty ?? 0),
            delivered_qty: Number(a.delivered_qty ?? 0),
            delivered_at: a.delivered_at ?? null,
            sales_order_no: so?.sales_order_no ?? null,
            dealer_name: so?.dealer_id ? (dealerMap.get(so.dealer_id) ?? null) : null,
            customer_name: so?.customer_id ? (customerMap.get(so.customer_id) ?? null) : null,
            line_description: ci?.name ?? null,
            product_type: null,
            area: null,
            position: null,
            catalog_item_name: ci?.name ?? null,
            catalog_item_sku: ci?.sku ?? null,
            released_at: null,
            claim_id: null,
          };
        });

        linesData = [...productLines, ...accessoryLines].sort((a, b) => {
          const at = a.released_at ?? '';
          const bt = b.released_at ?? '';
          return bt.localeCompare(at);
        });
      } else {
        throw new Error(err.message);
      }

      // Supply / MTM lines ready to ship (even while manufacture is still pending → Partial).
      if (includeSupply) {
        try {
          type SupplyRpcRow = {
            line_id: string;
            sales_order_id: string;
            sales_order_no: string | null;
            dealer_id: string | null;
            dealer_name: string | null;
            customer_id: string | null;
            customer_name: string | null;
            description: string | null;
            product_type: string | null;
            area: string | null;
            position: string | null;
            catalog_item_id: string | null;
            catalog_item_name: string | null;
            catalog_item_sku: string | null;
            quantity: number;
            delivery_status: string;
          };

          let supplyRows: SupplyRpcRow[] = [];
          const { data: rpcRows, error: rpcErr } = await supabase.rpc(
            'get_deliveries_supply_ready_lines',
            { p_org_id: activeOrganizationId },
          );
          if (!rpcErr && rpcRows) {
            supplyRows = rpcRows as SupplyRpcRow[];
          } else {
            // Fallback: direct table reads (pre-RPC environments / cache lag)
            if (rpcErr && import.meta.env.DEV) {
              console.warn('[useFinishedGoods] supply RPC fallback:', rpcErr.message);
            }
            const { data: ptRows } = await supabase
              .from('ProductTypes')
              .select('code')
              .eq('organization_id', activeOrganizationId)
              .eq('fulfillment_type', 'supply_only');
            const codes = (ptRows ?? []).map((p: { code: string }) => p.code);
            const productTypes = codes.length > 0 ? codes : ['catalog', 'service', 'window_film'];
            // SaleOrderLines has delivery_status only (no delivered_qty column).
            const { data: solRows, error: solErr } = await supabase
              .from('SaleOrderLines')
              .select('id, sales_order_id, description, product_type, area, position, catalog_item_id, quantity, delivery_status')
              .eq('organization_id', activeOrganizationId)
              .or('deleted.eq.false,deleted.is.null')
              .in('product_type', productTypes)
              .not('catalog_item_id', 'is', null)
              .in('delivery_status', ['ready', 'delivered']);
            if (solErr) throw solErr;
            const raw = (solRows ?? []) as {
              id: string; sales_order_id: string; description: string | null; product_type: string | null;
              area: string | null; position: string | null; catalog_item_id: string | null;
              quantity: number; delivery_status: string;
            }[];
            const soIds2 = [...new Set(raw.map((r) => r.sales_order_id))];
            const catIds2 = [...new Set(raw.map((r) => r.catalog_item_id).filter(Boolean))] as string[];
            const [{ data: soRows2 }, { data: catRows2 }] = await Promise.all([
              soIds2.length
                ? supabase.from('SalesOrders').select('id, sales_order_no, dealer_id, customer_id').in('id', soIds2)
                : Promise.resolve({ data: [] as SalesOrderLookupRow[] }),
              catIds2.length
                ? supabase.from('CatalogItems').select('id, name, sku').in('id', catIds2)
                : Promise.resolve({ data: [] as CatalogItemLookupRow[] }),
            ]);
            const soRowsT = (soRows2 ?? []) as SalesOrderLookupRow[];
            const dealerIds2 = [...new Set(soRowsT.map((s) => s.dealer_id).filter(Boolean))] as string[];
            const custIds2 = [...new Set(soRowsT.map((s) => s.customer_id).filter(Boolean))] as string[];
            const [{ data: dealerRows2 }, { data: custRows2 }] = await Promise.all([
              dealerIds2.length ? supabase.from('Dealers').select('id, dealer_name').in('id', dealerIds2) : Promise.resolve({ data: [] as any[] }),
              custIds2.length ? supabase.from('DirectoryCustomers').select('id, customer_name').in('id', custIds2) : Promise.resolve({ data: [] as any[] }),
            ]);
            const soMap2 = new Map(soRowsT.map((s) => [s.id, s]));
            const dealerMap2 = new Map<string, string>((dealerRows2 ?? []).map((d: any) => [String(d.id), String(d.dealer_name ?? '')]));
            const custMap2 = new Map<string, string>((custRows2 ?? []).map((c: any) => [String(c.id), String(c.customer_name ?? '')]));
            const catMap2 = new Map(((catRows2 ?? []) as CatalogItemLookupRow[]).map((c) => [c.id, c]));
            supplyRows = raw.map((r) => {
              const so = soMap2.get(r.sales_order_id);
              const ci = r.catalog_item_id ? catMap2.get(r.catalog_item_id) : undefined;
              return {
                line_id: r.id,
                sales_order_id: r.sales_order_id,
                sales_order_no: so?.sales_order_no ?? null,
                dealer_id: so?.dealer_id ?? null,
                dealer_name: so?.dealer_id ? (dealerMap2.get(so.dealer_id) ?? null) : null,
                customer_id: so?.customer_id ?? null,
                customer_name: so?.customer_id ? (custMap2.get(so.customer_id) ?? null) : null,
                description: r.description,
                product_type: r.product_type,
                area: r.area,
                position: r.position,
                catalog_item_id: r.catalog_item_id,
                catalog_item_name: ci?.name ?? null,
                catalog_item_sku: ci?.sku ?? null,
                quantity: r.quantity,
                delivery_status: r.delivery_status,
              };
            });
          }

          const existingIds = new Set(linesData.map((l) => l.line_id));
          for (const r of supplyRows) {
            if (existingIds.has(r.line_id)) continue;
            linesData.push({
              line_type: 'product',
              line_id: r.line_id,
              sales_order_id: r.sales_order_id,
              manufacturing_order_id: `supply:${r.sales_order_id}`,
              manufacturing_order_no: 'Supply',
              mo_status: 'supply',
              organization_id: activeOrganizationId,
              delivery_status: r.delivery_status,
              quantity: Number(r.quantity ?? 0),
              delivered_qty: r.delivery_status === 'delivered' ? Number(r.quantity ?? 0) : 0,
              delivered_at: null,
              sales_order_no: r.sales_order_no,
              dealer_name: r.dealer_name,
              customer_name: r.customer_name,
              line_description: r.description,
              product_type: r.product_type,
              area: r.area,
              position: r.position,
              catalog_item_name: r.catalog_item_name,
              catalog_item_sku: r.catalog_item_sku,
              released_at: null,
              claim_id: null,
            });
          }
          if (import.meta.env.DEV) {
            console.info('[useFinishedGoods] supply ready lines:', supplyRows.length);
          }
        } catch (supplyErr) {
          if (import.meta.env.DEV) {
            console.warn('[useFinishedGoods] supply lines skipped:', supplyErr);
          }
        }
      }

      const bySO = new Map<string, FinishedGoodLine[]>();
      for (const row of linesData) {
        const key = row.sales_order_id ?? '__no_so';
        if (!bySO.has(key)) bySO.set(key, []);
        bySO.get(key)!.push(row);
      }

      const result: FinishedGoodsSOGroup[] = [];
      for (const [soId, lines] of bySO) {
        const firstProduct = lines.find(l => l.line_type === 'product') ?? lines[0];
        const productLines = lines.filter(l => l.line_type === 'product');
        const accessoryLines = lines.filter(l => l.line_type === 'accessory');

        const moMap = new Map<string, FinishedGoodsMOGroup>();
        for (const pl of productLines) {
          const moId = pl.manufacturing_order_id ?? '__unknown';
          if (!moMap.has(moId)) {
            moMap.set(moId, {
              manufacturing_order_id: moId,
              manufacturing_order_no: pl.manufacturing_order_no ?? 'N/A',
              mo_status: pl.mo_status ?? 'unknown',
              lines: [],
            });
          }
          moMap.get(moId)!.lines.push(pl);
        }

        const allProductClaimIds = productLines.map(l => l.claim_id).filter(Boolean);
        const hasServiceMOOnly = allProductClaimIds.length > 0 && allProductClaimIds.length === productLines.length;
        const readyProductLines = productLines.filter(l => l.delivery_status === 'ready').length;
        const deliveredProductLines = productLines.filter(l => l.delivery_status === 'delivered').length;

        result.push({
          sales_order_id: soId,
          sales_order_no: firstProduct.sales_order_no ?? 'N/A',
          dealer_name: firstProduct.dealer_name,
          customer_name: firstProduct.customer_name,
          mos: Array.from(moMap.values()),
          accessories: accessoryLines,
          totalProductLines: productLines.length,
          deliveredProductLines,
          readyProductLines,
          totalAccessories: accessoryLines.length,
          deliveredAccessories: accessoryLines.filter(l => l.delivery_status === 'delivered').length,
          hasServiceMOOnly,
          // Defaults; enriched below with full SO progress when possible.
          soDeliverableTotal: productLines.length,
          soDeliverableReady: readyProductLines,
          soDeliverableDelivered: deliveredProductLines,
          soDeliverablePending: 0,
          fulfillmentStatus:
            deliveredProductLines > 0 && readyProductLines > 0
              ? 'partial'
              : readyProductLines > 0
                ? 'ready_for_delivery'
                : 'delivered',
        });
      }

      // Enrich with full SO progress (manufacture MOLs + supply SOLs) so Partial
      // means "some ready now, others still pending" — enables partial delivery UX.
      const soIdsForProgress = result.map((g) => g.sales_order_id).filter((id) => id && id !== '__no_so');
      if (soIdsForProgress.length > 0) {
        try {
          const progress = await loadSoDeliverableProgress(activeOrganizationId, soIdsForProgress);
          for (const g of result) {
            const p = progress.get(g.sales_order_id);
            if (!p) continue;
            g.soDeliverableTotal = p.total;
            g.soDeliverableReady = p.ready;
            g.soDeliverableDelivered = p.delivered;
            g.soDeliverablePending = p.pending;
            g.fulfillmentStatus = deriveFulfillmentStatus(p);
          }
        } catch {
          // Keep queue defaults if progress lookup fails.
        }
      }

      setGroups(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load finished goods');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, includeSupply]);

  useEffect(() => { fetchData(); }, [fetchData]);

  return { groups, loading, error, refetch: fetchData };
}
