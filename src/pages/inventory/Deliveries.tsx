import { useState, useEffect, useMemo } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { INVENTORY_SUBMODULES } from './inventorySubmodules';
import { useFinishedGoods, type FinishedGoodsSOGroup } from '../../hooks/useFinishedGoods';
import { useOrganizationContext } from '../../context/OrganizationContext';
import StatusBadge from '../../components/shared/StatusBadge';
import { Package, ChevronDown, ChevronRight, Truck, Search, Lock, Factory, ShoppingCart } from 'lucide-react';
import { formatDate } from '../../lib/utils';
import { withReturnTo } from '../../lib/navigation/returnTo';

type ViewMode = 'to-deliver' | 'history';

type FinancialInfo = {
  balance_due: number;
  total_paid: number;
  invoice_status: string;
  fully_invoiced: boolean;
  delivery_financials_ok: boolean;
  has_delivery_override: boolean;
};

export default function Deliveries() {
  const { registerSubmodules } = useSubmoduleNav();
  // Unified outbound queue: manufactured (CP) + purchased/MTM (supply) + stock.
  const { groups, loading, error } = useFinishedGoods({ includeSupply: true });
  const [view, setView] = useState<ViewMode>('to-deliver');
  const [search, setSearch] = useState('');
  const [expandedSOs, setExpandedSOs] = useState<Set<string>>(new Set());
  const [financialBySoId, setFinancialBySoId] = useState<Record<string, FinancialInfo>>({});

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    const soIds = groups.map((g) => g.sales_order_id).filter(Boolean) as string[];
    if (soIds.length === 0) { setFinancialBySoId({}); return; }
    Promise.all([
      supabase
        .from('sales_order_financial_summary')
        .select('sales_order_id, ar_balance, total_paid, invoice_status, fully_invoiced, delivery_financials_ok')
        .in('sales_order_id', soIds),
      supabase
        .from('SalesOrderDeliveryOverrides')
        .select('sales_order_id')
        .in('sales_order_id', soIds)
        .eq('status', 'active')
        .eq('deleted', false),
    ]).then(([summaryRes, overrideRes]) => {
      const summaryRows = (summaryRes.data ?? []) as {
        sales_order_id: string;
        ar_balance?: number | null;
        total_paid?: number | null;
        invoice_status?: string | null;
        fully_invoiced?: boolean | null;
        delivery_financials_ok?: boolean | null;
      }[];
      const overrideRows = (overrideRes.data ?? []) as { sales_order_id: string }[];
      const summaryMap = new Map(summaryRows.map((r) => [r.sales_order_id, r]));
      const overrideSet = new Set(overrideRows.map((r) => r.sales_order_id));
      const next: Record<string, FinancialInfo> = {};
      soIds.forEach((soId) => {
        const summary = summaryMap.get(soId);
        next[soId] = {
          balance_due: Math.max(Number(summary?.ar_balance ?? 0), 0),
          total_paid: Number(summary?.total_paid ?? 0),
          invoice_status: summary?.invoice_status ?? 'none',
          fully_invoiced: Boolean(summary?.fully_invoiced),
          delivery_financials_ok: Boolean(summary?.delivery_financials_ok),
          has_delivery_override: overrideSet.has(soId),
        };
      });
      setFinancialBySoId(next);
    });
  }, [groups]);

  const readyGroups = useMemo(() => groups.filter((g) => g.readyProductLines > 0), [groups]);

  const filteredGroups = useMemo(() => {
    let result = readyGroups;
    if (search.length >= 2) {
      const q = search.toLowerCase();
      result = result.filter((g) =>
        g.sales_order_no.toLowerCase().includes(q) ||
        (g.dealer_name ?? '').toLowerCase().includes(q) ||
        (g.customer_name ?? '').toLowerCase().includes(q) ||
        g.mos.some((mo) => mo.manufacturing_order_no.toLowerCase().includes(q))
      );
    }
    return result;
  }, [readyGroups, search]);

  const toggleExpand = (soId: string) => {
    setExpandedSOs((prev) => {
      const next = new Set(prev);
      if (next.has(soId)) next.delete(soId);
      else next.add(soId);
      return next;
    });
  };

  const readyCount = readyGroups.reduce((s, g) => s + g.readyProductLines, 0);

  return (
    <div className="py-6 px-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Deliveries</h1>
          <p className="text-xs text-gray-500">
            SOs with allocated / ready lines — ship full or partial. Manufactured, purchased and stock, grouped by Sales Order.
          </p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5">
            <span className="inline-block w-2 h-2 rounded-full bg-blue-500" />
            <span className="text-gray-600">{readyCount} ready to deliver</span>
          </div>
        </div>
      </div>

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex rounded border border-gray-200 bg-white overflow-hidden shrink-0">
              {([['to-deliver', 'To Deliver'], ['history', 'History']] as const).map(([key, label]) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => setView(key)}
                  className={`px-3 py-1 text-sm font-medium border-r last:border-r-0 border-gray-200 ${
                    view === key ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
            {view === 'to-deliver' && (
              <div className="relative flex-1 min-w-[240px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input
                  type="text"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search SO, MO, dealer..."
                  className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                />
              </div>
            )}
          </div>
        </div>
      </div>

      {view === 'history' ? (
        <DeliveryHistory />
      ) : loading ? (
        <div className="animate-pulse space-y-3">
          {[0, 1, 2].map((i) => <div key={i} className="h-20 bg-gray-100 rounded-lg" />)}
        </div>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">{error}</div>
      ) : filteredGroups.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <Package className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">Nothing is ready to deliver right now</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredGroups.map((group) => (
            <DeliverySOCard
              key={group.sales_order_id}
              group={group}
              expanded={expandedSOs.has(group.sales_order_id)}
              onToggle={() => toggleExpand(group.sales_order_id)}
              financial={financialBySoId[group.sales_order_id]}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function OriginBadge({ isSupply }: { isSupply: boolean }) {
  return isSupply ? (
    <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-purple-50 text-purple-700">
      <ShoppingCart className="w-2.5 h-2.5" /> Supply
    </span>
  ) : (
    <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-700">
      <Factory className="w-2.5 h-2.5" /> Manufactured
    </span>
  );
}

function DeliverySOCard({
  group,
  expanded,
  onToggle,
  financial,
}: {
  group: FinishedGoodsSOGroup;
  expanded: boolean;
  onToggle: () => void;
  financial?: FinancialInfo;
}) {
  const balanceDue = Number(financial?.balance_due ?? 0);
  const fullyInvoiced = Boolean(financial?.fully_invoiced);
  const deliveryFinancialsOk = Boolean(financial?.delivery_financials_ok);
  const paymentComplete = balanceDue <= 0;
  const hasDeliveryOverride = Boolean(financial?.has_delivery_override);
  const deliveryBlocked = group.hasServiceMOOnly
    ? false
    : !!financial && !deliveryFinancialsOk && !hasDeliveryOverride;
  const deliveryBlockedTitle = !fullyInvoiced
    ? 'Delivery blocked: the sales order is not fully invoiced.'
    : `Delivery blocked: balance due is $${balanceDue.toFixed(2)}. The sales order must be fully paid or issue an override.`;
  const paymentLabel = financial
    ? paymentComplete ? 'Paid'
    : financial.total_paid > 0 ? 'Partial Payment'
    : 'Unpaid'
    : null;

  const fulfillment = group.fulfillmentStatus;
  const fulfillmentLabel =
    fulfillment === 'partial' ? 'Partial'
    : fulfillment === 'ready_for_delivery' ? 'Ready for delivery'
    : 'Delivered';
  const fulfillmentCls =
    fulfillment === 'partial' ? 'bg-amber-100 text-amber-800'
    : fulfillment === 'ready_for_delivery' ? 'bg-blue-100 text-blue-800'
    : 'bg-green-100 text-green-800';

  const total = group.soDeliverableTotal || group.totalProductLines;
  const ready = group.soDeliverableReady || group.readyProductLines;
  const delivered = group.soDeliverableDelivered || group.deliveredProductLines;
  const pending = group.soDeliverablePending;
  const createLabel =
    fulfillment === 'partial' ? 'Create Partial Delivery' : 'Create Delivery';

  return (
    <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
      <div className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50" onClick={onToggle}>
        <div className="flex items-center gap-3">
          <button type="button" className="text-gray-400">
            {expanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-semibold text-sm text-primary">{group.sales_order_no}</span>
              <span className="text-xs text-gray-500">{group.dealer_name}</span>
              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${fulfillmentCls}`}>
                {fulfillmentLabel}
              </span>
              {paymentLabel && (
                <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                  paymentComplete ? 'bg-green-100 text-green-800' :
                  paymentLabel === 'Partial Payment' ? 'bg-amber-100 text-amber-800' :
                  'bg-red-100 text-red-800'
                }`}>
                  {paymentLabel}
                </span>
              )}
              {hasDeliveryOverride && !paymentComplete && (
                <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                  Financial Override
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
              <span>
                {ready} of {total} ready
                {delivered > 0 ? ` · ${delivered} delivered` : ''}
                {pending > 0 ? ` · ${pending} pending` : ''}
              </span>
              {group.totalAccessories > 0 && (
                <span>· {group.totalAccessories} accessor{group.totalAccessories !== 1 ? 'ies' : 'y'}</span>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            type="button"
            disabled={deliveryBlocked}
            onClick={(e) => {
              e.stopPropagation();
              if (deliveryBlocked) return;
              router.navigate(withReturnTo(`/inventory/deliveries/new?so_id=${group.sales_order_id}`));
            }}
            title={deliveryBlocked ? deliveryBlockedTitle : undefined}
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg ${
              deliveryBlocked
                ? 'bg-gray-200 text-gray-500 cursor-not-allowed'
                : 'text-white bg-primary hover:bg-primary/90'
            }`}
          >
            {deliveryBlocked ? <Lock className="w-3.5 h-3.5" /> : <Truck className="w-3.5 h-3.5" />}
            {deliveryBlocked ? 'Payment Required' : createLabel}
          </button>
        </div>
      </div>

      {expanded && (
        <div className="border-t border-gray-100">
          {group.mos.map((mo) => {
            const isSupply = mo.mo_status === 'supply';
            return (
              <div key={mo.manufacturing_order_id}>
                <div className="px-4 py-2 bg-gray-50/80 border-b border-gray-100 flex items-center gap-2">
                  {isSupply ? (
                    <span className="text-xs font-semibold text-purple-700">Supply / Purchased</span>
                  ) : (
                    <button
                      type="button"
                      onClick={() => router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${mo.manufacturing_order_id}`))}
                      className="text-xs font-semibold text-primary hover:underline"
                    >
                      {mo.manufacturing_order_no}
                    </button>
                  )}
                  {!isSupply && <StatusBadge status={mo.mo_status} type="manufacturing" size="sm" />}
                </div>
                <table className="w-full text-sm">
                  <tbody>
                    {mo.lines.map((line) => (
                      <tr key={line.line_id} className="border-t border-gray-50 hover:bg-gray-50">
                        <td className="px-4 py-2">
                          <div className="flex items-center gap-2">
                            <div className="font-medium text-gray-900 text-sm">
                              {line.catalog_item_name ?? line.line_description ?? 'Item'}
                            </div>
                            <OriginBadge isSupply={isSupply} />
                          </div>
                          {line.catalog_item_sku && (
                            <div className="text-xs text-gray-400 font-mono">{line.catalog_item_sku}</div>
                          )}
                        </td>
                        <td className="px-4 py-2 text-gray-600 text-sm">{line.area ?? '—'}</td>
                        <td className="px-4 py-2 text-center text-gray-600 text-sm">{line.position ?? '—'}</td>
                        <td className="px-4 py-2 text-right tabular-nums text-gray-900">{line.quantity}</td>
                        <td className="px-4 py-2 text-center">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                            line.delivery_status === 'delivered' ? 'bg-green-100 text-green-800' :
                            line.delivery_status === 'ready' ? 'bg-blue-100 text-blue-800' :
                            'bg-gray-100 text-gray-600'
                          }`}>
                            {line.delivery_status === 'delivered' ? 'Delivered' :
                             line.delivery_status === 'ready' ? 'Ready' : 'Pending'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          })}

          {group.accessories.length > 0 && (
            <div>
              <div className="px-4 py-2 bg-amber-50/60 border-b border-gray-100 border-t">
                <span className="text-xs font-semibold text-amber-800">Accessories</span>
              </div>
              <table className="w-full text-sm">
                <tbody>
                  {group.accessories.map((acc) => (
                    <tr key={acc.line_id} className="border-t border-gray-50 hover:bg-gray-50">
                      <td className="px-4 py-2">
                        <div className="font-medium text-gray-900 text-sm">
                          {acc.catalog_item_name ?? acc.line_description ?? 'Accessory'}
                        </div>
                        {acc.catalog_item_sku && (
                          <div className="text-xs text-gray-400 font-mono">{acc.catalog_item_sku}</div>
                        )}
                      </td>
                      <td className="px-4 py-2 text-gray-400 text-sm">—</td>
                      <td className="px-4 py-2 text-center text-gray-400 text-sm">—</td>
                      <td className="px-4 py-2 text-right tabular-nums text-gray-900">{acc.quantity}</td>
                      <td className="px-4 py-2 text-center">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          acc.delivery_status === 'delivered' ? 'bg-green-100 text-green-800' :
                          acc.delivery_status === 'ready' ? 'bg-blue-100 text-blue-800' :
                          'bg-gray-100 text-gray-600'
                        }`}>
                          {acc.delivery_status === 'delivered' ? 'Delivered' :
                           acc.delivery_status === 'ready' ? 'Ready' : 'Pending'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

interface DeliveryNoteRow {
  id: string;
  delivery_number: string;
  status: string;
  completed_at: string | null;
  created_at: string;
  received_by_name: string | null;
  delivered_by_name: string | null;
  sales_order_id: string | null;
  sales_order_no?: string | null;
}

function DeliveryHistory() {
  const { activeOrganizationId } = useOrganizationContext();
  const [notes, setNotes] = useState<DeliveryNoteRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (!activeOrganizationId) { setNotes([]); setLoading(false); return; }
    (async () => {
      setLoading(true);
      const { data: dns } = await supabase
        .from('DeliveryNotes')
        .select('id, delivery_number, status, completed_at, created_at, received_by_name, delivered_by_name, sales_order_id')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        // History shows real deliveries only. Pending drafts are transient and
        // are resumed from the "To Deliver" queue, not listed as history.
        .in('status', ['completed', 'partial'])
        .order('completed_at', { ascending: false, nullsFirst: false })
        .limit(200);
      const rows = (dns ?? []) as DeliveryNoteRow[];
      const soIds = [...new Set(rows.map((r) => r.sales_order_id).filter(Boolean))] as string[];
      let soMap = new Map<string, string>();
      if (soIds.length > 0) {
        const { data: sos } = await supabase.from('SalesOrders').select('id, sales_order_no').in('id', soIds);
        soMap = new Map((sos ?? []).map((s: any) => [s.id, s.sales_order_no]));
      }
      setNotes(rows.map((r) => ({ ...r, sales_order_no: r.sales_order_id ? soMap.get(r.sales_order_id) ?? null : null })));
      setLoading(false);
    })();
  }, [activeOrganizationId]);

  const filtered = useMemo(() => {
    if (search.length < 2) return notes;
    const q = search.toLowerCase();
    return notes.filter((n) =>
      n.delivery_number.toLowerCase().includes(q) ||
      (n.sales_order_no ?? '').toLowerCase().includes(q) ||
      (n.received_by_name ?? '').toLowerCase().includes(q)
    );
  }, [notes, search]);

  if (loading) {
    return (
      <div className="animate-pulse space-y-3">
        {[0, 1, 2].map((i) => <div key={i} className="h-14 bg-gray-100 rounded-lg" />)}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="relative max-w-[320px]">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search delivery, SO, receiver..."
          className="w-full pl-9 pr-3 py-1.5 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <Truck className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">No delivery notes yet</p>
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50/80 text-left text-xs text-gray-500">
                <th className="px-4 py-2 font-medium">Delivery</th>
                <th className="px-4 py-2 font-medium">Sales Order</th>
                <th className="px-4 py-2 font-medium">Received by</th>
                <th className="px-4 py-2 font-medium">Date</th>
                <th className="px-4 py-2 font-medium text-center">Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((dn) => (
                <tr
                  key={dn.id}
                  className="border-t border-gray-100 hover:bg-gray-50 cursor-pointer"
                  onClick={() => router.navigate(withReturnTo(`/inventory/deliveries/${dn.id}`))}
                >
                  <td className="px-4 py-2.5 font-medium text-primary">
                    <span className="inline-flex items-center gap-1.5">
                      <Truck className="w-3.5 h-3.5 text-gray-400" />
                      {dn.delivery_number}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-gray-700">{dn.sales_order_no ?? '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600">{dn.received_by_name ?? '—'}</td>
                  <td className="px-4 py-2.5 text-gray-500">{formatDate(dn.completed_at ?? dn.created_at)}</td>
                  <td className="px-4 py-2.5 text-center">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                      dn.status === 'completed' ? 'bg-green-100 text-green-700' :
                      dn.status === 'partial' ? 'bg-amber-100 text-amber-700' :
                      'bg-gray-100 text-gray-600'
                    }`}>
                      {dn.status === 'completed' ? 'Completed' : dn.status === 'partial' ? 'Partial' : 'Pending'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
