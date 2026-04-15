import { useState, useEffect, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFinishedGoods, type FinishedGoodsSOGroup } from '../../hooks/useFinishedGoods';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import StatusBadge from '../../components/shared/StatusBadge';
import { Package, ChevronDown, ChevronRight, Truck, Search, FileText, Lock } from 'lucide-react';
import { formatDate } from '../../lib/utils';
import { withReturnTo } from '../../lib/navigation/returnTo';

type FilterMode = 'ready' | 'delivered' | 'all';

type FinancialInfo = {
  balance_due: number;
  total_paid: number;
  invoice_status: string;
  has_delivery_override: boolean;
};

export default function FinishedGoods() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();
  const { groups, loading, error, refetch } = useFinishedGoods();
  const [filter, setFilter] = useState<FilterMode>('ready');
  const [search, setSearch] = useState('');
  const [expandedSOs, setExpandedSOs] = useState<Set<string>>(new Set());
  const [financialBySoId, setFinancialBySoId] = useState<Record<string, FinancialInfo>>({});

  useEffect(() => {
    const soIds = groups.map(g => g.sales_order_id).filter(Boolean) as string[];
    if (soIds.length === 0) { setFinancialBySoId({}); return; }
    Promise.all([
      supabase
        .from('sales_order_financial_summary')
        .select('sales_order_id, balance_due, total_paid, invoice_status')
        .in('sales_order_id', soIds),
      supabase
        .from('SalesOrders')
        .select('id, total_amount')
        .in('id', soIds),
      supabase
        .from('SalesOrderDeliveryOverrides')
        .select('sales_order_id')
        .in('sales_order_id', soIds)
        .eq('status', 'active')
        .eq('deleted', false),
    ]).then(([summaryRes, soTotalsRes, overrideRes]) => {
      const summaryRows = (summaryRes.data ?? []) as {
        sales_order_id: string;
        balance_due?: number | null;
        total_paid?: number | null;
        invoice_status?: string | null;
      }[];
      const soTotalsRows = (soTotalsRes.data ?? []) as { id: string; total_amount?: number | null }[];
      const overrideRows = (overrideRes.data ?? []) as { sales_order_id: string }[];

      const summaryMap = new Map(summaryRows.map((r) => [r.sales_order_id, r]));
      const soTotalMap = new Map(soTotalsRows.map((r) => [r.id, Number(r.total_amount ?? 0)]));
      const overrideSet = new Set(overrideRows.map((r) => r.sales_order_id));
      const next: Record<string, FinancialInfo> = {};

      soIds.forEach((soId) => {
        const summary = summaryMap.get(soId);
        const fallbackTotal = soTotalMap.get(soId) ?? 0;
        const balanceDue = Number(summary?.balance_due ?? fallbackTotal);
        const totalPaid = Number(summary?.total_paid ?? 0);
        const invoiceStatus = summary?.invoice_status ?? (fallbackTotal > 0 ? 'issued' : 'none');
        next[soId] = {
          balance_due: Math.max(balanceDue, 0),
          total_paid: totalPaid,
          invoice_status: invoiceStatus,
          has_delivery_override: overrideSet.has(soId),
        };
      });

      setFinancialBySoId(next);
    });
  }, [groups]);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
  }, [registerSubmodules, filteredSubmodules]);

  const filteredGroups = useMemo(() => {
    let result = groups;

    if (filter === 'ready') {
      result = result.filter((g) => g.readyProductLines > 0);
    } else if (filter === 'delivered') {
      result = result.filter((g) => g.deliveredProductLines > 0 || g.deliveredAccessories > 0);
    }

    if (search.length >= 2) {
      const q = search.toLowerCase();
      result = result.filter((g) =>
        g.sales_order_no.toLowerCase().includes(q) ||
        (g.dealer_name ?? '').toLowerCase().includes(q) ||
        (g.customer_name ?? '').toLowerCase().includes(q) ||
        g.mos.some(mo => mo.manufacturing_order_no.toLowerCase().includes(q))
      );
    }

    return result;
  }, [groups, filter, search]);

  const toggleExpand = (soId: string) => {
    setExpandedSOs((prev) => {
      const next = new Set(prev);
      if (next.has(soId)) next.delete(soId);
      else next.add(soId);
      return next;
    });
  };

  const readyCount = groups.reduce((s, g) => s + g.readyProductLines, 0);
  const deliveredCount = groups.reduce((s, g) => s + g.deliveredProductLines, 0);

  return (
    <div className="py-6 px-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Finished Goods</h1>
          <p className="text-xs text-gray-500">Products ready for delivery grouped by Sales Order</p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5">
            <span className="inline-block w-2 h-2 rounded-full bg-blue-500" />
            <span className="text-gray-600">{readyCount} ready</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="inline-block w-2 h-2 rounded-full bg-green-500" />
            <span className="text-gray-600">{deliveredCount} delivered</span>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex rounded border border-gray-200 bg-white overflow-hidden shrink-0">
              {([['ready', 'Ready'], ['delivered', 'Delivered'], ['all', 'All']] as const).map(([key, label]) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => setFilter(key)}
                  className={`px-3 py-1 text-sm font-medium border-r last:border-r-0 border-gray-200 ${
                    filter === key ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
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
          </div>
        </div>
      </div>

      {/* Content */}
      {loading ? (
        <div className="animate-pulse space-y-3">
          {[0, 1, 2].map((i) => <div key={i} className="h-20 bg-gray-100 rounded-lg" />)}
        </div>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">{error}</div>
      ) : filteredGroups.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <Package className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">
            {filter === 'ready' ? 'No products ready for delivery' : 'No finished goods found'}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredGroups.map((group) => (
            <FinishedGoodsSOCard
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

function FinishedGoodsSOCard({
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
  const paymentComplete = balanceDue <= 0;
  const hasDeliveryOverride = Boolean(financial?.has_delivery_override);
  const deliveryBlocked = group.hasServiceMOOnly
    ? false
    : !!financial && balanceDue > 0 && !hasDeliveryOverride;
  const paymentLabel = financial
    ? paymentComplete ? 'Paid'
    : financial.total_paid > 0 ? 'Partial Payment'
    : 'Unpaid'
    : null;

  return (
    <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
      <div
        className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50"
        onClick={onToggle}
      >
        <div className="flex items-center gap-3">
          <button type="button" className="text-gray-400">
            {expanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-semibold text-sm text-primary">{group.sales_order_no}</span>
              <span className="text-xs text-gray-500">{group.dealer_name}</span>
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
              <span>{group.mos.length} MO{group.mos.length !== 1 ? 's' : ''}</span>
              {group.totalAccessories > 0 && (
                <span>· {group.totalAccessories} accessor{group.totalAccessories !== 1 ? 'ies' : 'y'}</span>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="text-right">
            <div className="text-xs text-gray-500">
              {group.readyProductLines > 0 && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 font-medium mr-1">
                  {group.readyProductLines} ready
                </span>
              )}
              {group.deliveredProductLines > 0 && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-50 text-green-700 font-medium">
                  {group.deliveredProductLines} delivered
                </span>
              )}
            </div>
          </div>
          {group.readyProductLines > 0 && (
            <button
              type="button"
              disabled={deliveryBlocked}
              onClick={(e) => {
                e.stopPropagation();
                if (deliveryBlocked) return;
                router.navigate(withReturnTo(`/manufacturing/delivery-notes/new?so_id=${group.sales_order_id}`));
              }}
              title={deliveryBlocked ? `Delivery blocked: balance due is $${balanceDue.toFixed(2)}. Financials must settle to 0.00 or issue an override.` : undefined}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg ${
                deliveryBlocked
                  ? 'bg-gray-200 text-gray-500 cursor-not-allowed'
                  : 'text-white bg-primary hover:bg-primary/90'
              }`}
            >
              {deliveryBlocked ? <Lock className="w-3.5 h-3.5" /> : <Truck className="w-3.5 h-3.5" />}
              {deliveryBlocked ? 'Payment Required' : 'Create Delivery'}
            </button>
          )}
        </div>
      </div>

      {expanded && (
        <div className="border-t border-gray-100">
          {/* Product lines grouped by MO */}
          {group.mos.map((mo) => (
            <div key={mo.manufacturing_order_id}>
              <div className="px-4 py-2 bg-gray-50/80 border-b border-gray-100 flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => router.navigate(withReturnTo(`/manufacturing/manufacturing-orders/${mo.manufacturing_order_id}`))}
                  className="text-xs font-semibold text-primary hover:underline"
                >
                  {mo.manufacturing_order_no}
                </button>
                <StatusBadge status={mo.mo_status} type="manufacturing" size="sm" />
              </div>
              <table className="w-full text-sm">
                <tbody>
                  {mo.lines.map((line) => (
                    <tr key={line.line_id} className="border-t border-gray-50 hover:bg-gray-50">
                      <td className="px-4 py-2">
                        <div className="font-medium text-gray-900 text-sm">
                          {line.catalog_item_name ?? line.line_description ?? 'Item'}
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
          ))}

          {/* Accessories section */}
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

          {/* Delivery notes history */}
          {group.deliveredProductLines > 0 && (
            <DeliveryNotesSection soId={group.sales_order_id} />
          )}
        </div>
      )}
    </div>
  );
}

interface DeliveryNoteRef {
  id: string;
  delivery_number: string;
  status: string;
  completed_at: string | null;
  received_by_name: string | null;
}

function DeliveryNotesSection({ soId }: { soId: string }) {
  const [notes, setNotes] = useState<DeliveryNoteRef[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const { data: dns } = await supabase
        .from('DeliveryNotes')
        .select('id, delivery_number, status, completed_at, received_by_name')
        .eq('sales_order_id', soId)
        .eq('deleted', false)
        .in('status', ['completed', 'partial'])
        .order('completed_at', { ascending: false });

      setNotes(dns ?? []);
      setLoading(false);
    })();
  }, [soId]);

  if (loading || notes.length === 0) return null;

  return (
    <div className="px-4 py-2.5 border-t border-gray-100 bg-gray-50/50 flex flex-wrap items-center gap-2">
      <span className="text-xs font-medium text-gray-500 mr-1">Delivery Notes:</span>
      {notes.map((dn) => (
        <button
          key={dn.id}
          type="button"
          onClick={() => router.navigate(withReturnTo(`/manufacturing/delivery-notes/${dn.id}`))}
          className="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 rounded transition"
        >
          <Truck className="w-3 h-3" />
          {dn.delivery_number}
          <span className={`ml-0.5 px-1.5 py-0.5 rounded-full text-[10px] font-medium ${
            dn.status === 'completed' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'
          }`}>
            {dn.status === 'completed' ? 'Complete' : 'Partial'}
          </span>
          {dn.completed_at && (
            <span className="text-gray-400 ml-1">{formatDate(dn.completed_at)}</span>
          )}
        </button>
      ))}
    </div>
  );
}
