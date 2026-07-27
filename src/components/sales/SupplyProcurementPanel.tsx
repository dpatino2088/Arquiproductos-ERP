import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useCreatePurchaseOrder } from '../../hooks/usePurchaseOrders';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { Package, Plus, ShoppingCart, Loader2, Link2, CheckCircle2 } from 'lucide-react';

export interface SupplyLine {
  id: string;
  description: string | null;
  quantity: number;
  unit_price: number | null;
  catalog_item_id?: string | null;
}

interface SupplyCatalogItem {
  id: string;
  name: string;
  sku: string;
  cost_exw: number | null;
}

interface POLineRef {
  sales_order_line_id: string | null;
  catalog_item_id: string | null;
  ordered_qty: number;
  received_qty: number;
}

interface OrderedInfo { ordered: number; received: number }

interface Props {
  salesOrderId: string;
  organizationId: string;
  currency: string;
  supplyLines: SupplyLine[];
  onChanged: () => void;
  /** True when the order also has manufactured lines (mixed order). */
  isMixedOrder?: boolean;
}

/**
 * Procurement for supply_only SO lines.
 * - Catalog lines already have catalog_item_id → reserve stock or Order Supply / PO.
 * - Custom lines (no catalog_item_id) → Link a supply product or Create PO, then allocate → Deliveries.
 */
export default function SupplyProcurementPanel({
  salesOrderId,
  organizationId,
  currency,
  supplyLines,
  onChanged,
  isMixedOrder = false,
}: Props) {
  const addNotification = useUIStore((s) => s.addNotification);
  const { createPurchaseOrder, isCreating } = useCreatePurchaseOrder();
  const [reserving, setReserving] = useState(false);

  /** is_supply_product items for the Link modal (custom / special purchase). */
  const [supplyCatalog, setSupplyCatalog] = useState<SupplyCatalogItem[]>([]);
  /** Any CatalogItems already linked on SO lines (sellable catalog or supply product). */
  const [linkedCatalog, setLinkedCatalog] = useState<SupplyCatalogItem[]>([]);
  const [poLines, setPoLines] = useState<POLineRef[]>([]);
  const [reserved, setReserved] = useState<Map<string, number>>(new Map());
  const [loading, setLoading] = useState(true);
  const [reloadKey, setReloadKey] = useState(0);

  const [linkFor, setLinkFor] = useState<SupplyLine | null>(null);

  const reload = useCallback(() => setReloadKey((k) => k + 1), []);

  const linkedIdsKey = useMemo(
    () =>
      [...new Set(supplyLines.map((l) => l.catalog_item_id).filter(Boolean) as string[])]
        .sort()
        .join(','),
    [supplyLines],
  );
  const linkedIds = useMemo(
    () => (linkedIdsKey ? linkedIdsKey.split(',') : []),
    [linkedIdsKey],
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const [supplyCatRes, linkedCatRes, poRes, allocRes] = await Promise.all([
          supabase
            .from('CatalogItems')
            .select('id, name, sku, cost_exw')
            .eq('organization_id', organizationId)
            .eq('is_supply_product', true)
            .eq('is_active', true)
            .order('name', { ascending: true }),
          linkedIds.length > 0
            ? supabase
                .from('CatalogItems')
                .select('id, name, sku, cost_exw')
                .in('id', linkedIds)
            : Promise.resolve({ data: [] as SupplyCatalogItem[] }),
          supabase
            .from('PurchaseOrders')
            .select('id, status, PurchaseOrderLines(sales_order_line_id, catalog_item_id, ordered_qty, received_qty)')
            .eq('reference_type', 'sales_order')
            .eq('reference_id', salesOrderId)
            .neq('status', 'CANCELLED'),
          supabase
            .from('InventoryAllocations')
            .select('catalog_item_id, allocated_qty, status')
            .eq('sales_order_id', salesOrderId)
            .eq('status', 'reserved'),
        ]);
        if (cancelled) return;
        setSupplyCatalog((supplyCatRes.data ?? []) as SupplyCatalogItem[]);
        setLinkedCatalog((linkedCatRes.data ?? []) as SupplyCatalogItem[]);

        const flatLines: POLineRef[] = [];
        for (const po of (poRes.data ?? []) as { PurchaseOrderLines?: POLineRef[] }[]) {
          for (const l of po.PurchaseOrderLines ?? []) flatLines.push(l);
        }
        setPoLines(flatLines);

        const resMap = new Map<string, number>();
        for (const a of (allocRes.data ?? []) as { catalog_item_id: string; allocated_qty: number }[]) {
          resMap.set(a.catalog_item_id, (resMap.get(a.catalog_item_id) ?? 0) + Number(a.allocated_qty ?? 0));
        }
        setReserved(resMap);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [organizationId, salesOrderId, reloadKey, linkedIds]);

  // Ordered/received per SO line. Primary match is by sales_order_line_id (set by
  // "Order Supply"). As a fallback, PO lines linked to this SO at the header level
  // (from the PO screen) without a line reference are matched by catalog_item_id.
  const orderedByLine = useMemo(() => {
    const bySoLine = new Map<string, OrderedInfo>();
    const byCatalogUnlinked = new Map<string, OrderedInfo>();
    for (const l of poLines) {
      const info = { ordered: Number(l.ordered_qty ?? 0), received: Number(l.received_qty ?? 0) };
      if (l.sales_order_line_id) {
        const cur = bySoLine.get(l.sales_order_line_id) ?? { ordered: 0, received: 0 };
        cur.ordered += info.ordered; cur.received += info.received;
        bySoLine.set(l.sales_order_line_id, cur);
      } else if (l.catalog_item_id) {
        const cur = byCatalogUnlinked.get(l.catalog_item_id) ?? { ordered: 0, received: 0 };
        cur.ordered += info.ordered; cur.received += info.received;
        byCatalogUnlinked.set(l.catalog_item_id, cur);
      }
    }
    const result = new Map<string, OrderedInfo>();
    for (const l of supplyLines) {
      const direct = bySoLine.get(l.id);
      if (direct) { result.set(l.id, direct); continue; }
      if (l.catalog_item_id) {
        const fallback = byCatalogUnlinked.get(l.catalog_item_id);
        if (fallback) result.set(l.id, fallback);
      }
    }
    return result;
  }, [poLines, supplyLines]);

  const catalogById = useMemo(() => {
    const m = new Map<string, SupplyCatalogItem>();
    for (const c of linkedCatalog) m.set(c.id, c);
    for (const c of supplyCatalog) m.set(c.id, c);
    return m;
  }, [linkedCatalog, supplyCatalog]);

  // Lines that are linked to a supply product but not yet fully on order.
  const linesToOrder = useMemo(() => {
    return supplyLines.filter((l) => {
      if (!l.catalog_item_id) return false;
      const ordered = orderedByLine.get(l.id)?.ordered ?? 0;
      return ordered < Number(l.quantity ?? 0) - 1e-6;
    });
  }, [supplyLines, orderedByLine]);

  const handleOrderSupply = useCallback(async () => {
    if (linesToOrder.length === 0) return;
    try {
      const { data: wh } = await supabase
        .from('Warehouses')
        .select('id')
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle();
      if (!wh?.id) {
        addNotification({ type: 'error', title: 'No warehouse', message: 'Create a warehouse before ordering supply items.' });
        return;
      }

      const lines = linesToOrder.map((l) => {
        const ordered = orderedByLine.get(l.id)?.ordered ?? 0;
        const remaining = Math.max(0, Number(l.quantity ?? 0) - ordered);
        const ci = l.catalog_item_id ? catalogById.get(l.catalog_item_id) : undefined;
        return {
          catalog_item_id: l.catalog_item_id ?? null,
          ordered_qty: remaining,
          unit_cost: Number(ci?.cost_exw ?? 0),
          description: l.description ?? ci?.name ?? null,
          sales_order_line_id: l.id,
          allocation_type: 'stock' as const,
        };
      });

      const po = await createPurchaseOrder({
        warehouse_id: wh.id as string,
        status: 'DRAFT',
        reference_type: 'sales_order',
        reference_id: salesOrderId,
        lines,
      });

      addNotification({ type: 'success', title: 'Purchase Order created', message: 'A draft PO for the supply items was created. Add the vendor and confirm it.' });
      reload();
      onChanged();
      if (po?.id) router.navigate(withReturnTo(`/inventory/purchase-orders/${po.id}`));
    } catch (e) {
      addNotification({ type: 'error', title: 'Could not create PO', message: e instanceof Error ? e.message : 'Unknown error' });
    }
  }, [linesToOrder, orderedByLine, catalogById, organizationId, salesOrderId, createPurchaseOrder, addNotification, reload, onChanged]);

  // Linked lines that still need stock reserved (available stock will be capped by the RPC).
  const linesToReserve = useMemo(() => {
    return supplyLines.filter((l) => {
      if (!l.catalog_item_id) return false;
      const reservedQty = reserved.get(l.catalog_item_id) ?? 0;
      return reservedQty < Number(l.quantity ?? 0) - 1e-6;
    });
  }, [supplyLines, reserved]);

  const handleReserveStock = useCallback(async () => {
    if (linesToReserve.length === 0) return;
    setReserving(true);
    try {
      const { data: wh } = await supabase
        .from('Warehouses')
        .select('id')
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle();
      if (!wh?.id) {
        addNotification({ type: 'error', title: 'No warehouse', message: 'Create a warehouse first.' });
        return;
      }
      const items = linesToReserve.map((l) => {
        const reservedQty = l.catalog_item_id ? (reserved.get(l.catalog_item_id) ?? 0) : 0;
        return { catalog_item_id: l.catalog_item_id, qty: Math.max(0, Number(l.quantity ?? 0) - reservedQty) };
      });
      const { error } = await supabase.rpc('allocate_inventory_to_so', {
        p_org_id: organizationId,
        p_warehouse_id: wh.id as string,
        p_sales_order_id: salesOrderId,
        p_items: items,
      });
      if (error) throw error;
      addNotification({ type: 'success', title: 'Stock reserved', message: 'Available stock was reserved to this order. Items still short need a PO.' });
      reload();
      onChanged();
    } catch (e) {
      addNotification({ type: 'error', title: 'Could not reserve stock', message: e instanceof Error ? e.message : 'Unknown error' });
    } finally {
      setReserving(false);
    }
  }, [linesToReserve, reserved, organizationId, salesOrderId, addNotification, reload, onChanged]);

  // A line still needs purchasing only if it is neither already on order nor
  // already reserved/received to cover its quantity.
  const needsProcurement = useMemo(() => {
    return supplyLines.some((l) => {
      const qty = Number(l.quantity ?? 0);
      const ordered = orderedByLine.get(l.id)?.ordered ?? 0;
      const reservedQty = l.catalog_item_id ? (reserved.get(l.catalog_item_id) ?? 0) : 0;
      return reservedQty < qty - 1e-6 && ordered < qty - 1e-6;
    });
  }, [supplyLines, orderedByLine, reserved]);

  if (supplyLines.length === 0) return null;

  return (
    <div className="rounded-lg border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
        <div className="flex items-center gap-2">
          <Package className="w-4 h-4 text-blue-600" />
          <h3 className="text-sm font-semibold text-gray-900">Procurement (Supply)</h3>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleReserveStock}
            disabled={reserving || linesToReserve.length === 0}
            title={linesToReserve.length === 0 ? 'Nothing to reserve' : 'Reserve available stock from the warehouse to this order'}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {reserving ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
            Reserve stock
          </button>
          <button
            type="button"
            onClick={() => router.navigate(withReturnTo(`/inventory/purchase-orders/new?so_id=${salesOrderId}`))}
            disabled={!needsProcurement}
            title={needsProcurement ? 'Open a new Purchase Order already linked to this Sales Order' : 'All supply items are already ordered or received'}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <Plus className="w-4 h-4" /> Create PO
          </button>
          <button
            type="button"
            onClick={handleOrderSupply}
            disabled={isCreating || linesToOrder.length === 0}
            title={
              linesToOrder.length === 0
                ? 'Catalog lines: use Reserve stock if available, or Create PO. Custom lines: link a product first.'
                : 'Create a draft PO for catalog/supply items still short'
            }
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium bg-primary text-white hover:bg-primary/90 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {isCreating ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShoppingCart className="w-4 h-4" />}
            Order Supply
          </button>
        </div>
      </div>

      <div className="px-4 py-2.5 border-b border-gray-100 bg-blue-50/40 text-xs text-gray-600 leading-relaxed">
        {isMixedOrder
          ? 'This order mixes manufactured and supply items. Manufactured lines ship from Manufacturing; supply items below are fulfilled here. '
          : ''}
        <span className="font-medium">Catalog</span> lines already have a product — reserve from stock (when paid) or buy via PO, then they go to Deliveries.{' '}
        <span className="font-medium">Custom</span> lines need a linked supply product and a PO; once received and allocated, they go to Deliveries.
      </div>

      {loading ? (
        <div className="px-4 py-6 text-sm text-gray-500 flex items-center gap-2">
          <Loader2 className="w-4 h-4 animate-spin" /> Loading procurement status…
        </div>
      ) : (
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-4 py-2 text-left font-medium text-gray-600">Line</th>
              <th className="px-4 py-2 text-left font-medium text-gray-600">Product</th>
              <th className="px-4 py-2 text-right font-medium text-gray-600">Qty</th>
              <th className="px-4 py-2 text-right font-medium text-gray-600">On order</th>
              <th className="px-4 py-2 text-right font-medium text-gray-600">Reserved</th>
              <th className="px-4 py-2 text-left font-medium text-gray-600">Status</th>
            </tr>
          </thead>
          <tbody>
            {supplyLines.map((l) => {
              const ci = l.catalog_item_id ? catalogById.get(l.catalog_item_id) : undefined;
              const ordered = orderedByLine.get(l.id)?.ordered ?? 0;
              const received = orderedByLine.get(l.id)?.received ?? 0;
              const reservedQty = l.catalog_item_id ? (reserved.get(l.catalog_item_id) ?? 0) : 0;
              const qty = Number(l.quantity ?? 0);
              let status: { label: string; cls: string };
              if (!l.catalog_item_id) status = { label: 'Custom — link product', cls: 'bg-gray-100 text-gray-600' };
              else if (reservedQty >= qty - 1e-6) status = { label: 'Ready to deliver', cls: 'bg-green-50 text-green-700' };
              else if (received > 0) status = { label: 'Received', cls: 'bg-emerald-50 text-emerald-700' };
              else if (ordered >= qty - 1e-6) status = { label: 'On order', cls: 'bg-amber-50 text-amber-700' };
              else status = { label: 'Needs stock or PO', cls: 'bg-orange-50 text-orange-700' };
              return (
                <tr key={l.id} className="border-t">
                  <td className="px-4 py-3 text-gray-900">{l.description ?? '—'}</td>
                  <td className="px-4 py-3">
                    {l.catalog_item_id && ci ? (
                      <div>
                        <div className="text-gray-900 flex items-center gap-1">
                          <CheckCircle2 className="w-3.5 h-3.5 text-green-600" /> {ci.name}
                        </div>
                        <div className="text-xs text-gray-500">{ci.sku}</div>
                      </div>
                    ) : l.catalog_item_id ? (
                      <div className="text-xs text-gray-500">Catalog linked</div>
                    ) : (
                      <button
                        type="button"
                        onClick={() => setLinkFor(l)}
                        className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium border border-gray-300 text-gray-700 hover:bg-gray-50"
                        title="Custom item: link a supply product, then create a PO"
                      >
                        <Link2 className="w-3.5 h-3.5" /> Link custom / supply product
                      </button>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-700">{qty}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-700">{ordered || '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-700">{reservedQty || '—'}</td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${status.cls}`}>{status.label}</span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}

      {linkFor && (
        <LinkSupplyProductModal
          line={linkFor}
          organizationId={organizationId}
          currency={currency}
          existing={supplyCatalog}
          onClose={() => setLinkFor(null)}
          onLinked={() => { setLinkFor(null); reload(); onChanged(); }}
        />
      )}
    </div>
  );
}

interface LinkModalProps {
  line: SupplyLine;
  organizationId: string;
  currency: string;
  existing: SupplyCatalogItem[];
  onClose: () => void;
  onLinked: () => void;
}

function LinkSupplyProductModal({ line, organizationId, currency, existing, onClose, onLinked }: LinkModalProps) {
  const addNotification = useUIStore((s) => s.addNotification);
  const [mode, setMode] = useState<'existing' | 'new'>(existing.length > 0 ? 'existing' : 'new');
  const [selectedId, setSelectedId] = useState<string>('');
  const [name, setName] = useState<string>(line.description ?? '');
  const [sku, setSku] = useState<string>('');
  const [cost, setCost] = useState<string>('');
  const [saving, setSaving] = useState(false);

  const linkLineToItem = async (catalogItemId: string) => {
    const { error } = await supabase
      .from('SaleOrderLines')
      .update({ catalog_item_id: catalogItemId, updated_at: new Date().toISOString() })
      .eq('id', line.id);
    if (error) throw error;
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      let catalogItemId = selectedId;
      if (mode === 'new') {
        if (!name.trim()) {
          addNotification({ type: 'error', title: 'Name required', message: 'Enter a product name.' });
          setSaving(false);
          return;
        }
        const finalSku = (sku.trim() || `SUP-${Date.now().toString(36).toUpperCase()}`);
        const { data: created, error: createErr } = await supabase
          .from('CatalogItems')
          .insert({
            organization_id: organizationId,
            name: name.trim(),
            sku: finalSku,
            unit_of_measure: 'ea',
            measure_basis: 'unit',
            is_supply_product: true,
            is_active: true,
            cost_exw: cost.trim() ? Number(cost) : 0,
          })
          .select('id')
          .single();
        if (createErr) throw createErr;
        catalogItemId = created.id as string;
      }
      if (!catalogItemId) {
        addNotification({ type: 'error', title: 'Select a product', message: 'Choose an existing supply product or create a new one.' });
        setSaving(false);
        return;
      }
      await linkLineToItem(catalogItemId);
      addNotification({ type: 'success', title: 'Linked', message: 'Supply product linked to the order line.' });
      onLinked();
    } catch (e) {
      addNotification({ type: 'error', title: 'Could not link product', message: e instanceof Error ? e.message : 'Unknown error' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="w-full max-w-md rounded-lg bg-white shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="px-5 py-4 border-b">
          <h3 className="text-base font-semibold text-gray-900">Link custom / supply product</h3>
          <p className="text-xs text-gray-500 mt-0.5">
            For custom lines only (no catalog SKU). Catalog products are already linked on the SO line.
          </p>
          <p className="text-xs text-gray-400 mt-1">{line.description ?? 'Order line'}</p>
        </div>
        <div className="px-5 py-4 space-y-4">
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setMode('existing')}
              disabled={existing.length === 0}
              className={`flex-1 px-3 py-1.5 rounded-md text-sm font-medium border ${mode === 'existing' ? 'border-primary text-primary bg-primary/5' : 'border-gray-300 text-gray-600'} disabled:opacity-40`}
            >
              Existing
            </button>
            <button
              type="button"
              onClick={() => setMode('new')}
              className={`flex-1 px-3 py-1.5 rounded-md text-sm font-medium border ${mode === 'new' ? 'border-primary text-primary bg-primary/5' : 'border-gray-300 text-gray-600'}`}
            >
              <Plus className="w-3.5 h-3.5 inline -mt-0.5 mr-1" /> New product
            </button>
          </div>

          {mode === 'existing' ? (
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Supply product</label>
              <select
                value={selectedId}
                onChange={(e) => setSelectedId(e.target.value)}
                className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">Select a product…</option>
                {existing.map((c) => (
                  <option key={c.id} value={c.id}>{c.name} ({c.sku})</option>
                ))}
              </select>
            </div>
          ) : (
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Product name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm" placeholder="e.g. Cortina de Madera 1000x2000" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">SKU (optional)</label>
                  <input value={sku} onChange={(e) => setSku(e.target.value)} className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm" placeholder="Auto" />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Purchase cost ({currency})</label>
                  <input value={cost} onChange={(e) => setCost(e.target.value)} inputMode="decimal" className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm" placeholder="0.00" />
                </div>
              </div>
              <p className="text-xs text-gray-400">This creates a supply product (special purchase catalog). It won't appear in the sellable dealer catalog.</p>
            </div>
          )}
        </div>
        <div className="px-5 py-3 border-t flex justify-end gap-2">
          <button type="button" onClick={onClose} className="px-3 py-1.5 rounded-md text-sm text-gray-600 hover:bg-gray-50">Cancel</button>
          <button type="button" onClick={handleSave} disabled={saving} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium bg-primary text-white hover:bg-primary/90 disabled:opacity-50">
            {saving && <Loader2 className="w-4 h-4 animate-spin" />} Link
          </button>
        </div>
      </div>
    </div>
  );
}
